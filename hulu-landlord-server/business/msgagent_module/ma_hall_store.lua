
local skynet = require "skynet"
local cluster = require "skynet.cluster"
local cjson = require "cjson"
local ma_data = require "ma_data"
local mall_conf = require "cfg.cfg_mall"
-- local active_conf = require "conftbl.active"
local httpc = require "http.httpc"
local ma_month_card = require "ma_month_card"
local ma_day_comsume = require "ma_day_comsume"
local cfg_items = require "cfg.cfg_items"
local wx_sdk = require "sdk.wx_sdk"
local request = {}
local cmd = {}
local M = {}

httpc.timeout = 500 -- 超时时间 5s

function request:mall_data()
    local r = {}
    for id,item in pairs(ma_data.mall_data.mall) do
        item.today_buyc = M.today_buyc(id)
        table.insert(r, item)
    end
    return {data = r}
end

function M.today_buyc(mall_id)
    local goods_pack = mall_conf[mall_id]
    local refresh_time = 5*60*60
    local mall = ma_data.mall_data.mall[tostring(mall_id)]
    if mall then
        local today = os.date("%Y%m%d", os.time() - refresh_time)
        if today ~= os.date("%Y%m%d", mall.last_buy_time - refresh_time) then
            return 0
        else
            return mall.today_buyc
        end
    else
        return 0
    end
end

-- 钻石购买 金币/道具
function request:diamond_buy_goods()
    self.num = self.num or 1

    if self.num < 1 or self.num > 1000000 then
        return {result = 1}
    end
    print("diamond_buy_goods", self.num, self.mall_id)
    local goods_pack = mall_conf[self.mall_id]
    local goods_list = goods_pack and goods_pack.content
    local price = goods_pack.price
    local priceType = 0
    if goods_pack.activityid == WEALTH_GOD_ID then
        local Godmall_id = ma_data.ma_hall_active.getPriceAndAward()
        if mall_conf[Godmall_id].coin_type ~= 2 then
            return {result = 4}
        end
    end

    if ma_data.db_info.diamond < price*self.num then
        print('=============================钻石不足,',ma_data.db_info.diamond,price,self.num)
        return {result = 2}
    end

    local limit_err = ma_data.ma_hall_order.check_mall_limit(self.mall_id, self.num)
    if 0 ~= limit_err then
        print('=============================购买限制,',limit_err,self.mall_id, self.num)
        return {result = 3}
    end


    if self.num > 1 then
        goods_list = goods_list_mul(goods_list, self.num)
    end
    ma_data.add_goods_list(goods_list, GOODS_WAY_DIAMOND_BUY, "钻石购买获得")


    ma_data.add_diamond(-price*self.num, GOODS_WAY_DIAMOND_BUY, "钻石购买消耗")
    M.update_mall_buyc(self.mall_id, self.num)

    ma_data.send_push("buy_suc", {
        mall_id = self.mall_id,
        goods_list = goods_list,
        msgbox = 1
    })

    -- add log
    skynet.call(get_db_mgr(), "lua", "insert", "diamond_buy_log", {
        pid = ma_data.my_id,
        mall_id = self.mall_id,
        num = self.num,
        time = os.time()
    })
    if goods_pack.activityid == WEALTH_GOD_ID then
        ma_data.ma_hall_active.updatePriceAndAward()
    end
    return {result = 0}
end

-- 金币购买 道具
function request:gold_buy_goods()
    self.num = self.num or 1

    if self.num < 1 or self.num > 1000000 then
        return {result = 1}
    end
    print("gold_buy_goods", self.num, self.mall_id)
    local goods_pack = mall_conf[self.mall_id]
    local goods_list = goods_pack and goods_pack.content
    local xixi_price = goods_pack.xixi_price
    local priceType = 0
    if goods_pack.activityid == WEALTH_GOD_ID then
        local Godmall_id = ma_data.ma_hall_active.getPriceAndAward()
        if mall_conf[Godmall_id].coin_type ~= 3 then
            return {result = 4}
        end
    end
    if xixi_price == 0 then
        return {result = 4}
    end
    if ma_data.db_info.gold < xixi_price*self.num then
        print('=============================金币不足,',ma_data.db_info.gold,xixi_price,self.num)
        return {result = 2}
    end

    local limit_err = ma_data.ma_hall_order.check_mall_limit(self.mall_id, self.num)
    if 0 ~= limit_err then
        print('=============================购买限制,',limit_err,self.mall_id, self.num)
        return {result = 3}
    end

    if self.num > 1 then
        goods_list = goods_list_mul(goods_list, self.num)
    end
    ma_data.add_goods_list(goods_list, GOODS_WAY_GOLD_BUY, "金币购买获得")


    ma_data.add_gold(-xixi_price*self.num, GOODS_WAY_GOLD_BUY, "金币购买消耗")
    M.update_mall_buyc(self.mall_id, self.num)

    ma_data.send_push("buy_suc", {
        mall_id = self.mall_id,
        goods_list = goods_list,
        msgbox = 1
    })
    if goods_pack.activityid == WEALTH_GOD_ID then
        ma_data.ma_hall_active.updatePriceAndAward()
    end
    return {result = 0}
end

-- 购买并赠送好友道具(单个)
function request:give_firend_diamond_goods()
    -- 可赠送物品数量为1
    local num = 1
    if num < 1 or num > 1000000 then
        return {result = 1}
    end

    local my_currency_num = 0
    -- 赠送只有砖石，但是万一呢
    local currency_id = DIAMOND_ID

    print("give_firend_goods", num, self.mall_id,currency_id)
    local goods_pack = mall_conf[self.mall_id]
    local goods_list = goods_pack.content
    print()
    if DIAMOND_ID == currency_id then
        print("钻石")
        my_currency_num = ma_data.db_info.diamond
    elseif CLOTHING_CURRENCY_ID ==currency_id then
        print("服饰币")
        my_currency_num = ma_data.get_goods_num(CLOTHING_CURRENCY_ID)
    else
        return {result = 5}
    end


    print("检测购买是否满足条件")
    print("货币数量，需要数量",my_currency_num,goods_pack.price*num)
    if my_currency_num < goods_pack.price*num then
        print('=============================货币不足,',my_currency_num,goods_pack.price,num)
        return {result = 2}
    end

    local limit_err = ma_data.ma_hall_order.check_mall_limit(self.mall_id, num)
    if 0 ~= limit_err then
        print('=============================购买限制,',limit_err,self.mall_id, num)
        return {result = 3}
    end
    if num > 1 then
        goods_list = goods_list_mul(goods_list, num)
    end
    ma_data.add_goods_list({{id = currency_id,num = -(goods_pack.price*num)}},GOODS_WAY_GIVE_FRIEND,"赠送好友消耗")
    return {result = 4}
end

-- 记录购买商品信息 (次数 时间 当日购买次数 ...)
function M.update_mall_buyc(mall_id, num)
    local refresh_time = 5*60*60            -- 早上5点刷新
    local mall = ma_data.mall_data.mall
    local id = tostring(mall_id)
    num = num or 1

    local today = os.date("%Y%m%d")
    mall[id] = mall[id] or {id = mall_id, buyc = 0, last_buy_time = 0}
    mall[id].buyc = mall[id].buyc + num

    if today ~= os.date("%Y%m%d", mall[id].last_buy_time - refresh_time) then
        mall[id].today_buyc = 0
    end
    mall[id].today_buyc  = mall[id].today_buyc + num
    mall[id].last_buy_time = os.time()

    skynet.call(get_db_mgr(), "lua", "update", "mall", {pid = ma_data.my_id}, {["data.mall"] = mall})

    --推送给前端
     ma_data.send_push("sync_mall_data_item", {
        mall_data = mall[id]
    })
end

--钻石购买金币
function request:diamond_buy_gold()
    print("mall_id", self.mall_id)
    local goods_pack = mall_conf[self.mall_id]

    local goods = goods_pack.content[1]             -- 金币
    if not goods_pack then
        return {error_num = ERROR_INFO.Goods_error}
    end
    if ma_data.db_info.diamond < goods_pack.price then
        return {error_num = ERROR_INFO.diamond_not_enough}
    end

    ma_data.add_diamond(-goods_pack.price, "diamond_buy_gold")
    ma_data.add_gold(goods.num, "diamond_buy_gold")

    ma_data.send_push("buy_suc", {
        mall_id = self.mall_id,
        goods_list = {goods},
        msgbox = 1
    })

    return {result = true}
end

-- 返回服饰币数量
function request:get_clothing_currency_num()
    local ret = ma_data.get_goods_num(CLOTHING_CURRENCY_ID)
    return {result = ret}
end

-- 
function request:open_gift()
    local ret = ma_data.open_the_gift(self.gift_id,self.num,self.gift_award)
    return {result = ret}
end

-- 用服饰币购买装扮
function request:clothing_currency_buy()
    self.num = self.num or 1

    if self.num < 1 or self.num > 1000000 then
        return {result = 1}
    end
    print("clothing_currency_buy", self.num, self.mall_id)
    local goods_pack = mall_conf[self.mall_id]
    local goods_list = goods_pack.content
    local clothing_currency = ma_data.get_goods_num(CLOTHING_CURRENCY_ID)
    if clothing_currency < goods_pack.price*self.num then
        print('=============================服饰币不足,',ma_data.db_info.gold,goods_pack.price,self.num)
        return {result = 2}
    end

    local limit_err = ma_data.ma_hall_order.check_mall_limit(self.mall_id, self.num)
    if 0 ~= limit_err then
        print('=============================购买限制,',limit_err,self.mall_id, self.num)
        return {result = 3}
    end

    if self.num > 1 then
        goods_list = goods_list_mul(goods_list, self.num)
    end

    ma_data.add_goods_list(goods_list, GOODS_WAY_CLOTHING_CURRENCY, "服饰币购买获得")


    ma_data.add_goods_list({{id = CLOTHING_CURRENCY_ID,num = -(goods_pack.price*self.num)}},GOODS_WAY_CLOTHING_CURRENCY,"服饰币购买消耗")
    M.update_mall_buyc(self.mall_id, self.num)

    ma_data.send_push("buy_suc", {
        mall_id = self.mall_id,
        goods_list = goods_list,
        msgbox = 1
    })

    return {result = 0}
end

function request:apple_pay_suc2()
    print("apple_pay_suc2 =======================",self.orderNumber,self.receipt_data)
    assert(self.orderNumber)
    if self.orderNumber == "(null)," then
        print("err order --------------")
        return
    end

    -- local order = skynet.call(get_db_mgr(), "lua", "find_one", COLL.ORDER,{out_trade_no = self.orderNumber})
    -- if not order then
    --     order = skynet.call(get_db_mgr(), "lua", "find_one", COLL.ORDER_SANDBOX,{out_trade_no = self.orderNumber})
    -- end
    -- if order then
    --     skynet.error("apple order done :",self.orderNumber,order.transaction_id)
    --     ma_data.send_push("apple_pay_suc",{
    --         result = 1,
    --         transactionId = order.transaction_id or "",
    --         orderNumber = self.orderNumber,
    --         sign = self.receipt_data,
    --     })
    --     return
    -- end

    

    skynet.fork(function()
        local pub_url = skynet.getenv("pub_server_url")

        local body = cjson.encode {
            cmd = "apple_pay_suc",
            args = {
                gameid = skynet.getenv "gameid",
                out_trade_no = self.orderNumber,
                receipt_data = self.receipt_data,
                pid         = ma_data.my_id,
                notify_url  = skynet.getenv("apple_err_url"),
            }
        }

        httpc.request("POST", pub_url, '/public.action', nil, nil, body)

    end)

end


--米大师余额查询
function M.midas_getBalance(openid,env)
    local body = {            
        openid = openid,
        appid = wx_sdk.app_id,
        offer_id = wx_sdk.offer_id,
        ts     =  os.time(),
        zone_id  = "1",   
        pf = "android",
    }
    local sign = wx_sdk.sign_midas(body,env==1,"getbalance")
    body.sig = sign    

    local sandbox_url = wx_sdk.get_mds_getbalance_url(env==1)
    local post_body = cjson.encode(body)
    local status,midas_wallet = httpc.request("POST", wx_sdk.host,sandbox_url, nil, nil, post_body)
    if status == 200 then
        midas_wallet = cjson.decode(midas_wallet)
        table.print(midas_wallet)
        if midas_wallet.errcode ==0 then
            --mds查询成功
            print("midas_getBalance succ ")
            return midas_wallet
        else
            skynet.loge("errcode =>", midas_wallet.errcode, ";msg =>", midas_wallet.errmsg)
        end
    else
        skynet.loge("midas getbalance err")
    end
end

--米大师支付
function M.midas_pay(openid,env,amt,remark,billno_time)    
    local body = {            
        openid = openid,
        appid = wx_sdk.app_id,
        offer_id = wx_sdk.offer_id,
        ts     =  billno_time,
        zone_id  = "1",   
        pf = "android",  
        amt = amt,
        app_remark = remark
    }

    --拼接一个订单号
    body.bill_no = body.openid..billno_time

    local sign = wx_sdk.sign_midas(body,env==1,"pay")
    body.sig = sign

    local sandbox_url = wx_sdk.get_mds_pay_url(env==1)
    local post_body = cjson.encode(body)
    local status,pat_ret = httpc.request("POST", wx_sdk.host,sandbox_url, nil, nil, post_body)
    if status == 200 then
        pat_ret = cjson.decode(pat_ret)
        table.print(pat_ret)
        if pat_ret.errcode ==0 then
            print("midas_pay succ ")                      
            return true
        else
            skynet.loge("errcode =>", pat_ret.errcode, ";msg =>", pat_ret.errmsg)
        end
    else
        skynet.loge("midas getbalance err")
    end
end

--todo 根据remark更新对应模块统计次数
function M.pay_back_remark(remark)
    --print("====debug qc==== pay_back_remark remark: ",remark)
end

function request:midas_pay()
    print("midas_pay =======================",self.mall_id,self.amt,self.env,self.remark)
    assert(self.mall_id and self.amt,"midas_pay assert failed")

    local product = mall_conf[self.mall_id]
    assert(product,"midas_pay assert product failed")    

    --配置表价格检验
    if product.price*10 ~= self.amt then
        ma_data.send_push("midas_pay_back",{
            result = 3 --商品不存在
        })
        return
    end
    -- local openid = "o74Xp5NspizbB2T6yR__ExyUbzjo" 
    local openid = ma_data.db_info.openid 

    skynet.fork(function()
        --查询midas余额
        local midas_wallet = M.midas_getBalance(openid,self.env)
        if midas_wallet ~=nil then
            print("米大师 余额查询====成功 钻石 :" ,midas_wallet.balance )
            if midas_wallet.balance < self.amt then
                ma_data.send_push("midas_pay_back",{
                    result = 6 --余额不足，支付失败
                })
                return
            end
            --米大师 pay 扣款流程
            local billno_time = os.time()  --订单时间用来确定唯一订单号

            
            local pre_order = {
                price        = product.price,
                mall_id      = self.mall_id,
                pid          = ma_data.my_id,
                time         = billno_time,
                os           = ma_data.db_info.os,
                platform     = wx_sdk.sdk,
                uid          = openid,    
                status       = 0       --订单状态     
            }
            pre_order.out_trade_no = openid..billno_time

            local pay_succ = false
            local timeout_count = 0
            while not pay_succ and timeout_count<5  do    
                print(" =====开始米大师pay  ",timeout_count)        
                local pay_succ = M.midas_pay(openid,self.env,self.amt,self.remark,billno_time)
                if pay_succ then
                    
                    --插入订单记录
                    pre_order.status = 2
                    skynet.logi("res =>", table.tostr(res), ";pre_order =>", table.tostr(pre_order))
                    skynet.send(get_db_mgr(), "lua", "insert_pre_order", pre_order)

                    --发放购买的游戏道具
                    local sandbox = env ==1 and "sandbox" or nil
                    M.buy_suc( self.mall_id, sandbox,pre_order.out_trade_no)

                    ma_data.send_push("midas_pay_back",{
                        result = 0               
                    })

                    --根据self.remark 场景值 处理不同功能模块依赖的购买成功统计次数
                    --M.pay_back_remark(self.remark)
                    return           
                end
                print(" pay 查询失败 等待10s 继续")
                --等待10s
                skynet.sleep(1000) 
                timeout_count = timeout_count +1
            end

            --插入失败订单
            print(" pay 订单失败 插入订单记录")
            skynet.logi("res =>", table.tostr(res), ";pre_order =>", table.tostr(pre_order))
            skynet.send(get_db_mgr(), "lua", "insert_pre_order", pre_order)

            ma_data.send_push("midas_pay_back",{
                result = 5 --下单失败
            })
            return

         
        else
            print("米大师 余额查询====失败")
            ma_data.send_push("midas_pay_back",{
                result = 1
            })
        end
       
    end)

end

function cmd.apple_buy_suc(source,transaction_id,orderNumber,sign)
    ma_data.send_push("apple_pay_suc",{
        result = 0,
        transactionId = transaction_id,
        orderNumber = orderNumber,
        sign        = sign,
    })
end

function cmd.apple_pay_err(source,result,sign,transaction_id)
    ma_data.send_push("apple_pay_suc",{
        result          = result,
        sign            = sign,
        transactionId   = transaction_id,
    })
end

function M.apple_buy_suc(transaction_id,orderNumber,sign)
    cmd.apple_buy_suc(nil,transaction_id,orderNumber,sign)
end

local function on_buy_special_mall(mall_id)
    local cfg = mall_conf[mall_id]
    if cfg.type == BAG_TYPE_MONTN_CARD then
        ma_month_card.on_buy_card(cfg.quality)
    elseif cfg.top_type == BAG_TOP_TYPE_BANK then
        --银行处理
        ma_data.ma_hall_bank.get_bank_update(mall_id)
    end
end

local function on_buy_extra_func_mall(mall_id)
    local cfg = mall_conf[mall_id]
    print("on_buy_extra_func_mall", cfg.top_type, cfg.type)
    if cfg.top_type == BAG_TOP_TYPE_LUGGAGE_PROPS and cfg.type == BAG_TYPE_BOOSTER then
        ma_data.ma_task.buy_booster()
    end
end

--购买成功
function cmd.buy_suc(_, mall_id,sandbox,orderNo)
    local goods_pack = mall_conf[mall_id]
    local goods_list = table.clone(goods_pack.content)
    local price = goods_pack.price
    local now = os.time()
    if goods_pack.activityid == ACT_SELECT_ID then
        --甄选活动id由用户配置
        print('甄选活动id由用户配置ma_hall_store',goods_pack.activityid,goods_pack.giftid)
        local tmp_goods_list = ma_data.ma_hall_active.get_select_act_awards(goods_pack.activityid,goods_pack.giftid)
        if tmp_goods_list then
            goods_list = tmp_goods_list
        else
            skynet.error("act_select_error")
        end
    -- elseif goods_pack.activityid == WEALTH_GOD_ID then
    --     local Godmall_id = ma_data.ma_hall_active.getPriceAndAward()
    --     if mall_conf[Godmall_id].coin_type ~= 4 then
    --         skynet.error("WEALTH_GOD_ID,act_select_error")
    --     end
    end

    --金额乘算倍率系数coefficient 货币类附送比例
    if goods_list and goods_pack.first_double == 1 then
        local m = ma_data.mall_data.mall[tostring(mall_id)]
        if not m or m.buyc == 0 then
            goods_list = goods_list_mul(goods_list, 2)
        elseif goods_pack.coefficient > 0 then
            goods_list = goods_list_mul(goods_list, (1+goods_pack.coefficient/10000))
        end
    elseif goods_list and goods_pack.coefficient > 0 then
        goods_list = goods_list_mul(goods_list, (1+goods_pack.coefficient/10000))
    end

    if goods_list then
        ma_data.add_goods_list(goods_list, GOODS_WAY_MALL, '商城购买')
        --附带功能,比如助力礼包之类
        on_buy_extra_func_mall(mall_id)

        print("=======================================")
        table.print({
            goods_list = goods_list or {},
            mall_id = mall_id,
            msgbox = 1,
            out_trade_no = orderNo,
            price = price,
        })
        ma_data.send_push('buy_suc', {
            goods_list = goods_list or {},
            mall_id = mall_id,
            msgbox = 1,
            out_trade_no = orderNo,
            price = price,
        })
    else
        on_buy_special_mall(mall_id)
    end
    

    if sandbox ~= "sandbox" then
        -- 渠道数据收集
        local realy_today = os.date("%Y%m%d")
        skynet.send("cd_collecter", "lua", "charge",
            ma_data.db_info.channel,
            "basegame",
            price,
            os.date("%Y%m%d", ma_data.db_info.firstLoginDt) == realy_today,
            ma_data.db_info.all_fee == 0,
            (not ma_data.db_info.last_recharge_time) or (os.date("%Y%m%d", ma_data.db_info.last_recharge_time) ~= realy_today),
            ma_data.db_info.firstLoginDt
        )
        skynet.send("pay_info_mgr","lua","charge",ma_data.db_info.channel,mall_id,price)
    end
    if goods_pack.activityid == WEALTH_GOD_ID then
        ma_data.ma_hall_active.updatePriceAndAward()
    end
    -- update db_info
    ma_data.db_info.all_fee = (ma_data.db_info.all_fee or 0) + price
    
     -- 防沉迷系统 记录月累计充值
    local month = os.date("%Y%m")
    local lastMonth =  os.date("%Y%m", ma_data.db_info.last_recharge_time)
    if (not ma_data.db_info.last_recharge_time) or os.date("%Y%m", ma_data.db_info.last_recharge_time) ~= month then
        ma_data.db_info.month_fee = 0
    end

    ma_data.db_info.month_fee = ma_data.db_info.month_fee + price

    ma_data.db_info.all_diamond = ma_data.db_info.all_diamond + (goods_pack.recharge or 0)
    --增加vip富豪点
    local vip_point = ma_data.find_goods(VIP_POINT)
    local goods = {id = VIP_POINT, num = goods_pack.recharge}
    ma_data.add_goods(goods,GOODS_WAY_DIAMOND_BUY,"充值VIP富豪点增加",nil,true)
    ma_data.update_viplv()
    
    ma_data.db_info.last_recharge_time = now
    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id},{
        all_fee = ma_data.db_info.all_fee,
        all_diamond = ma_data.db_info.all_diamond,
        last_recharge_time = now,
        month_fee = ma_data.db_info.month_fee
    })
    if goods_pack.recharge > 0 then

        --根据配置开关vip功能
        if skynet.getenv "vip_switch" == "true" then
           --viplv更新
            ma_data.update_viplv()
        end
       
    end

    
    ma_day_comsume.recharge_notify()
    -- 记录购买商品信息 (次数 时间 当日购买次数 ...)
    M.update_mall_buyc(mall_id)
    ma_data.ma_spread.addPayNum()

    --天赐豪礼购买S2C
    ma_data.ma_hall_active.buy_succ_spree(mall_id)

    --首充礼包购买S2c
    ma_data.ma_hall_active.First_charge_Check(mall_id)
end

function M.buy_suc( ... )
    cmd.buy_suc(nil, ...)
end

local function load_mall_data()
    local t = skynet.call(get_db_mgr(), "lua", "find_one", "mall", {pid = ma_data.my_id}, {pid = false, _id = false})
    return t and t.data
end

local function init()
    ma_data.mall_data = load_mall_data()    -- 玩家购买信息统计
    if not ma_data.mall_data then
        ma_data.mall_data = {mall = {}}
        skynet.call(get_db_mgr(), "lua", "insert", "mall", {pid = ma_data.my_id, data = ma_data.mall_data})
    end
end


function M.init(REQUEST,CMD)
    if request then
        table.connect(REQUEST,request)
    end
    if cmd then
        table.connect(CMD,cmd)
    end
    init()
end

return M