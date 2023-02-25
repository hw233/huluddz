local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local cjson = require "cjson"
local ec = require "eventcenter"

local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)

local httpc = require "http.httpc"
httpc.timeout = 1000

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data


CMD.buy_suc = function (data)
    local ret = CMD.PayFinish(data)
    if ret.ok and data.purchaseToken then
        pcall(function ()
            local orderId = data.out_trade_no
            local pre_order = dbx.get(TableNameArr.UserPayOrderPre, {id = orderId})
            if pre_order then
                skynet.logd("huaweistart")
                -- local status, body = httpc.request("POST", "127.0.0.1:" .. skynet.getenv("http_server2_port"), "/game.html", nil, nil, cjson.encode({
                local status, body = httpc.request("POST", "game.jytx123.cn", "/server_test_pay", nil, nil, cjson.encode({
                    cmd = "HuaweiConfirm",
                    args = {purchaseToken = data.purchaseToken, productId = pre_order.product_id}
                }))
                skynet.loge("huawei", status, body)
            end
        end)
    end
    return ret
end

CMD.process_buy_suc = CMD.buy_suc

--CMD.process_buy_suc = CMD.PayFinish