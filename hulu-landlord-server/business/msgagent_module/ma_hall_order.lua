
local skynet = require "skynet"
local datacenter = require "skynet.datacenter"
local cjson = require "cjson"
local httpc = require "http.httpc"
--local goods = require "shopItems_config"

local ma_data = require "ma_data"
local ma_hall_store = require "ma_hall_store"
local mall_conf = require "cfg.cfg_mall"
local ma_month_card = require "ma_month_card"

httpc.timeout = 500 -- 超时时间 5s

require "table_util"
require "wx_util"
require "define"
local request = {}
local M = {}

local function month_card_order_check(mall_id)
    --系统维护期间不能支付
   if skynet.call("global_status", "lua", "is_server_will_shutdown") then
      return 1
   end
   local cfg = mall_conf[mall_id]
   if cfg.type == BAG_TYPE_MONTN_CARD then
       if not ma_month_card.can_buy_month_card(cfg.quality) then
            return 2
       end
   end
   return 0
end

function M.check_mall_limit(mall_id, buy_num)
    
    local goods_pack = mall_conf[mall_id]
    if not goods_pack then
        return 3 --商品不存在
    end
    local mall = ma_data.mall_data.mall[tostring(mall_id)]

    if mall then
        if goods_pack.limit ~= -1 and mall.buyc + buy_num > goods_pack.limit then
            print("check_mall_limit1", mall.buyc,buy_num,goods_pack.limit)
            return 4 --购买商品超过限制
        end
        if goods_pack.day_limit ~= -1 and ma_hall_store.today_buyc(mall_id) + buy_num > goods_pack.day_limit then
            print("check_mall_limit2", mall.buyc, buy_num, goods_pack.day_limit)
            return 4 --购买商品超过限制
        end
    end
    if goods_pack.activityid == WEALTH_GOD_ID then
        local Godmall_id = ma_data.ma_hall_active.getPriceAndAward()
        if mall_id ~= Godmall_id then
            skynet.error("WEALTH_GOD_ID,act_select_error")
            return 3
        end
    end

    if goods_pack.activityid == ACT_SELECT_ID then
        --甄选活动id由用户配置
        print('甄选活动id由用户配置ma_hall_order',goods_pack.activityid,goods_pack.giftid)
        local tmp_goods_list = ma_data.ma_hall_active.get_select_act_awards(goods_pack.activityid,goods_pack.giftid)
        if not tmp_goods_list then
            return 7 --自选未完成
        end
    end

    return 0
end

function M.check_order_request(mall_id)
    local ret = month_card_order_check(mall_id) 
    if 0 ~= ret then
        return ret
    end
    ret = M.check_mall_limit(mall_id, 1)
    if 0 ~= ret then
        return ret
    end
    return ret
end

function M.apply_order(args)
    args.platform = args.plat
    args.plat = nil
    local cmd = args.platform
    local invalid_result = M.check_order_request(args.mall_id)
    --print('apply_order', args.mall_id,invalid_result)
    if 0 ~= invalid_result then
        return {result = invalid_result}
    end
    --print('apply_order', skynet.getenv "unneed_money" ,type(skynet.getenv "unneed_money"))

    --如果购买的是月卡，需要与当前月卡一致才能购买


    if skynet.getenv "unneed_money" == "true" then
        ma_hall_store.buy_suc(args.mall_id)
        print('unneed_money return 0')
        return {result = 0}
    end

    local goods_pack = mall_conf[args.mall_id]
    
    local price = goods_pack.price
    local canbuy,err = ma_data.ma_realname.can_buy(price)
    if not canbuy then
        print('ma_realname return err',err)
        return {result = err}
    end
    
    price = price * 100

    local pre_order = {
        price        = price,
        mall_id      = args.mall_id,
        pid          = ma_data.my_id,
        time         = os.time(),
        os           = ma_data.db_info.os,
        platform     = cmd,
        uid          = ma_data.db_info.openid
    }

    local body = {
        cmd = cmd,
        args = {
            gameid = skynet.getenv "gameid",
            -- platform = cmd,
            price = price,
            -- mall_id = args.mall_id,
            product_name = goods_pack.name,
            -- version = args.version, -- app 支付sdk版本,可能nil
            pid     = ma_data.my_id,
            subSdk  = ma_data.db_info.subSdk, -- 应用宝支付--> qq,wx 登录区分
        }
    }

    for k,v in pairs(args) do
        body.args[k] = v
    end


    if cmd == "qqminisdk" then
        body.args.openid = ma_data.db_info.openid
        body.args.product_id = goods_pack.product_id
        body.args.nickname = ma_data.db_info.nickname
        body.args.session_key = ma_data.session_key --datacenter.get("qq_sdk", "access_token")
        body.args.access_token = datacenter.get("qq_sdk", "access_token")
    elseif cmd == "wxsdk" then
        --todo 等待实现wx支付
    else
        skynet.loge(" ====== get_order cmd is error "..cmd)
    end
    

    --旧 从 pub_server_url配置去取得订单号的流程
    body = cjson.encode(body)
    print("qqminisdk  get order body :",body)
    -- local pub_url = skynet.getenv("pub_server_url")
    -- local status, res = httpc.request("POST", pub_url, '/public.action', nil, nil, body)
    -- if status == 200 then
    --     res = cjson.decode(res)
    --     if res.out_trade_no then
    --         res.out_trade_no = res.out_trade_no or res.orderNumber
    --         pre_order.out_trade_no = res.out_trade_no
    --         skynet.logi("res =>", table.tostr(res), ";pre_order =>", table.tostr(pre_order))
    --         pre_order.platform = res.plat or cmd
    --         --pre_order.pf = args.pf
    --         skynet.send(get_db_mgr(), "lua", "insert_pre_order", pre_order)
    --         res.plat = res.plat or cmd
    --         res.price = price
    --         res.result = 0
    --     else
    --         res.result = 5
    --     end
    --     return res
    -- else
    --     --下单失败
    --     return {result = 5}
    -- end

    --新 从自己httpclinet取得订单号  modify by qc 2021.7.7
    local orderNo = skynet.call("httpclient", "lua", "get_order_num")

    local res = {}
    res.out_trade_no = orderNo
    pre_order.out_trade_no = res.out_trade_no
    skynet.logi("res =>", table.tostr(res), ";pre_order =>", table.tostr(pre_order))
    pre_order.platform = res.plat or cmd
    --pre_order.pf = args.pf
    skynet.send(get_db_mgr(), "lua", "insert_pre_order", pre_order)
    res.plat = res.plat or cmd
    res.price = price
    res.mall_id = pre_order.mall_id
    res.result = 0
    res.extra_info = res.out_trade_no.."_"..(price/100)
  
    return res
   
end

-- -- 微信下单
-- function request:order()
--     -- return M.apply_order(self,"wx_order")
--     local res = M.apply_order(self,"wx_order")
--     table.print(res)
--     return res
-- end

-- -- 支付宝下单
-- function request:ali_order()
  
--     return M.apply_order(self,"ali_order","alipay")

-- end

-- function request:apple_order()
--    return M.apply_order(self,"apple_order","applepay")
-- end

-- function request:oppo_order()
--     return M.apply_order(self,"oppo_order","oppopay")
-- end

function request:get_order()
    assert(self.plat)
    local res = M.apply_order(self)
    --table.print(res)
    return  res
end

function M.init(REQUEST,CMD)
    if request then
        table.connect(REQUEST,request)
    end
    if cmd then
        table.connect(CMD,cmd)
    end
end

ma_data.ma_hall_order = M

return M
