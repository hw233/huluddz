local skynet = require "skynet"
local httpc = require "http.httpc"
httpc.timeout = 500 -- 超时时间 5s
local cjson = require "cjson"
local eventx = require "eventx"

local ma_data = require "ma_data"
local ma_userstore = require "ma_userstore"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
--#endregion

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local ma_obj = {
    
}

-- ma_obj.loadDatas = function ()
--     if not ma_obj.rewardRecord then
--         local versionsKey = "2021.11.25 20:19"
--         local obj = dbx.get(TableNameArr.UserRoomData, userInfo.id) or {}
--         if obj.versionsKey ~= versionsKey then
--             obj.versionsKey = versionsKey
    
--             obj.id = userInfo.id
--             obj.rewardRecord = obj.rewardRecord or {}
    
--             dbx.update_add(TableNameArr.UserRoomData, userInfo.id, obj)
--         end
--         ma_obj.rewardRecord = obj.rewardRecord
--     end
-- end

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    --ma_obj.loadDatas()

    eventx.listen(EventxEnum.UserNewPendingData, function (_type, arr, delDataArr)
        if _type == PendingDataType.PayFinish then
            for index, value in ipairs(arr) do
                table.insert(delDataArr, value)
                ma_userstore.buy(value.data.storeId, 1, false, value.data.orderId)

                CMD.PayFinish(nil, RET_VAL.Succeed_1, value.data)
            end
        end
    end)
end


--#region 核心部分

--#endregion


REQUEST_New.PayOrderGet = function (args)
    local storeId, platform = args.storeId, args.platform
    -- platform:wxpay,alipay,oppopay,vivopay,qihoopay,lenovopay,baidupay,xyxpay

    local sData = datax.store[storeId]
    if not sData then
        return RET_VAL.ERROR_3
    end

    if platform ~= "Gm" and skynet.getenv("env") == "debug" then
        skynet.fork(function()
            skynet.send("web_gm", "lua", "UserPay", {
                id      = userInfo.id,
                storeId = storeId,
            })
            -- local status, body = httpc.request("POST", "127.0.0.1:" .. skynet.getenv("http_server2_port"), "/game.html", nil, nil, cjson.encode({
            --     cmd = "UserPay",
            --     args = {
            --         id      = userInfo.id,
            --         storeId = storeId,
            --     }
            -- }))
        end)
        return RET_VAL.Succeed_1
    end

    local price = sData.price * 100

    local product_id = sData.product_id

    local res
    if platform == "Gm" then
        res = {}
        res.orderId = skynet.call("httpclient", "lua", "get_order_num")
        -- res.orderStr = ""
    else

        local param = {
            cmd = platform,
            args = table.clone(args)
        }
        param.args.gameid       = skynet.getenv("gameid")
        param.args.pid          = userInfo.id
        param.args.mall_id      = storeId
        param.args.price        = price
        param.args.product_name = sData.name
        param.args.subSdk       = userInfo.subSdk -- 应用宝支付--> qq,wx 登录区分

        for key, value in pairs(args) do
            param.args[key] = value
        end

        local need_openid_cl = {
            vivopay = true,         -- vivo 支付
            yybpay  = true,         -- 应用宝
            vivoadpay = true, 
            xyxpay = true,          -- 233小游戏
            kuaishoupay = true,     -- 快手
            qihoopcpay = true,      -- 360
            swjoypay    = true,     -- 顺网
            ninegamepay = true,     -- 九游
            tiktokpay = true,       -- 抖音

        }

        if platform == "applepay" then
            -- pre_order.product_name = sData.name
            param.args.product_id = sData.product_id
        elseif platform == "huaweipay" then
            param.args.product_id = sData.hw_shop_id
            product_id = sData.hw_shop_id
        elseif platform == "kuaishoupay" then
            param.args.channel_id = userInfo.ks_bind_channel
            param.args.nickname = userInfo.nickname
            param.args.ip = userInfo.ipLast
        elseif platform == "qihoopcpay" then -- 360(奇虎)pc端
            param.args.server_id = string.upper(userInfo.server_id)
        elseif platform == "sand_wxpay" or platform == "sand_alipay" or platform == "minpay" then
            param.args.ip = userInfo.ipLast
        end
        if need_openid_cl[platform] then
            param.args.openid = userInfo.openid
        end

        local pub_url = skynet.getenv("pub_server_url")
        local status
        skynet.logd("PayOrderGet Post", cjson.encode(param))
        status, res = httpc.request("POST", pub_url, '/public.action', nil, nil, cjson.encode(param))
        if status == 200 then
            res = cjson.decode(res)
            -- if res.result == 1 then
            --     return RET_VAL.NoUse_8
            -- end
            -- res.out_trade_no = res.out_trade_no or res.orderNumber -- 订单号
            res.orderId = res.out_trade_no or res.orderNumber -- 订单号 之前订单号字段为 out_trade_no
            res.orderStr = res.orderStr
        else
            return RET_VAL.Fail_2
        end
    end

    local orderData = {
        id          = res.orderId,
        storeId     = storeId,
        product_id  = product_id,
        uId         = userInfo.id,
        openid      = userInfo.openid,
        price       = price,
        time        = os.time(),
        os          = userInfo.os,
        ip          = userInfo.ip,
        platform    = platform,
        state       = 0,
        orderStr    = res.orderStr,
    }
    dbx.add(TableNameArr.UserPayOrderPre, orderData)

    res.id = orderData.id
    res.storeId = orderData.storeId
    res.price = orderData.price
    res.platform = orderData.platform
    -- res.result = 0
    res.extra_info = res.id .. "_" .. price
    res.pay_amount = price

    return RET_VAL.Succeed_1, res
end


REQUEST_New.PaySucceed = function (args)
    skynet.logd("PaySucceed start", table.tostr(args))
    local orderId, platform = args.orderId, args.platform

    if orderId == "(null)," then
        skynet.loge("PaySucceed param error", orderId)
        return RET_VAL.ERROR_3
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

    local cmdMap = {
        applepay = "apple_pay_suc",
        huaweipay = "huaweipay_suc",
    }

    local cmd = cmdMap[platform]
    if cmd then
        if not orderId then
            skynet.logd("PaySucceed orderId is empty")
        end
        local receipt_data = args.receipt_data
        skynet.fork(function()
            local body = {
                cmd = cmd,
                args = {
                    pid             = userInfo.id,
                    gameid          = skynet.getenv("gameid"),
                    out_trade_no    = orderId,
                    receipt_data    = receipt_data,
                    notify_url      = skynet.getenv("apple_err_url"),
                }
            }
            local pub_url = skynet.getenv("pub_server_url")
            httpc.request("POST", pub_url, '/public.action', nil, nil, cjson.encode(body))
        end)
    end

    return RET_VAL.Succeed_1
end

CMD.PayOrderGet = function (source, storeId, platform)
    return REQUEST_New.PayOrderGet({
        storeId = storeId,
        platform = platform,
    })
end

CMD.PayFinish = function (source, e_info, data)
    -- orderId, transaction_id, sign

    data.e_info = e_info
    if e_info == RET_VAL.Succeed_1 and not data.result then
        data.result = 0
    end
    ma_common.send_myclient_sure("PayFinish", data)
end

return ma_obj