local skynet = require "skynet"
local httpc = require "http.httpc"
local cjson = require "cjson"

local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)

local ma_data = require "ma_data"
local ma_user = require "ma_user"

require "define"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local xy_cmd 				= require "xy_cmd"

local REQUEST_New = xy_cmd.REQUEST_New


local userInfo = ma_data.userInfo

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

print("end")
-- inject :00000020 inject/activity_mgr_inject.lua