local skynet = require "skynet"

local objx = require "objx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local common = require "common_mothed"
local httpc = require "http.httpc"
httpc.timeout = 1000
local crypt = require "skynet.crypt"
local queue = require "skynet.queue"
local cs = queue()
local huawei_sdk = require "sdk.huawei_sdk"

require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

return function (CMD, agentMap)
    local moduleDatas = ServerData.moduleDatas

    moduleDatas.huaweiObj = {}


    --购买成功 第三方回调 QQ用  VX不用
    CMD.PayFinish1 = function (data)
        skynet.logd("PayFinish start ", table.tostr(data))

        local ret = {code = 0, message = "fail"}

        --todo 等待wx支付回调
        --验签sign 根据sdk规则验签
        -- local retCode = 1 --验签失败	
        -- if not wx_sdk.payapi_sign(data) then
        --     return {code=retCode,message="sign error"}
        -- end

        local pay_status = tonumber(data.pay_status)
        if pay_status ~= 1 then
            ret.code = 3 --支付状态未完成
            ret.message = "pay_status  error"
            return ret
        end

        local orderId = data.order_sn
        --local transaction_id = data.transaction_id

        local pre_order = dbx.get(TableNameArr.UserPayOrderPre, {id = orderId})
        if not pre_order then
            ret.code = 2--订单不存在
            ret.message = "not exits order"
            return ret
        end

        skynet.logd("PayFinish pre_order => ", table.tostr(pre_order))

        if pre_order.state == 1 then
            ret.code = 1 --已完成订单 但是按照sdk要求 返回成功
            ret.message = "success"
            return ret
        end

        local extra_info = data.extra_info
        if extra_info ~= nil and extra_info ~= pre_order.id .. "_" .. math.tointeger(data.pay_amount) then
            ret.code = 4 --参数不匹配
            ret.message = "extra_info  error"
            return ret
        end

        dbx.update(TableNameArr.UserPayOrderPre, pre_order, {state = 1})


        local storeId = pre_order.storeId
        -- local coll_name = data.sandbox ~= "sandbox" and COLL.ORDER or COLL.ORDER_SANDBOX
        local tableName = TableNameArr.UserPayOrder

        common.pushUserPendingData(PendingDataType.PayFinish, pre_order.uId, {
            storeId = storeId,
            orderId = orderId,
        })

        local userInfo = dbx.get(TableNameArr.User, pre_order.uId)
        dbx.add(tableName, {
            id          = pre_order.id,
            storeId     = storeId,
            uId         = pre_order.uId,

            nickname    = userInfo.nickname,
            registerDt  = userInfo.firstLoginDt,
            isFirstPay  = userInfo.pay <= 0,
            channel     = userInfo.channel,
            --transaction_id = transaction_id,
            price       = pre_order.price,
            time        = os.time(),
            os          = pre_order.os,
            platform    = pre_order.platform,
        })

        ret.code = 1
        ret.message = "success"
        return ret
    end

    CMD.PayFinish = function (data)
        skynet.logd("PayFinish start ", table.tostr(data))

        local ret = {ok = false, code = 0, message = "fail"}

        local orderId = data.out_trade_no
        local transaction_id = data.transaction_id

        local pre_order = dbx.get(TableNameArr.UserPayOrderPre, {id = orderId})
        if not pre_order then
            ret.ok = false
            ret.code = 2--订单不存在
            ret.message = "not exits order"
            return ret
        end

        if pre_order.id ~= orderId then
            ret.ok = false
            ret.code = 4--订单id不匹配
            ret.message = "order mismatching"
            return ret
        end

        local pre_orderStr = table.tostr(pre_order)
        skynet.logd("PayFinish 1 => ", pre_orderStr)

        -- 新版华为支付,在发货前,先通知消耗
        if pre_order.platform == "huaweipay" and data.purchaseToken then
            if not CMD.HuaweiConfirm({purchaseToken = data.purchaseToken, productId = pre_order.product_id}) then
                dbx.add(TableNameArr.UserPayOrderFail, pre_order)
            end
        end

        local tableName = data.sandbox ~= "sandbox" and TableNameArr.UserPayOrder or TableNameArr.UserPayOrderSandBox
        local finishPayOrder = dbx.get(tableName, {transaction_id = transaction_id})
        if finishPayOrder then
            if pre_order.platform == "applepay" then
                common.send_useragent(data.pid or pre_order.uId, "PayFinish", RET_VAL.Succeed_1, data)
            end
            ret.ok = true
            ret.code = 5--订单已完成
            ret.message = "order finish"
            return ret
        end

        if pre_order.state == 1 then
            ret.ok = true
            ret.code = 1 --已完成订单 但是按照sdk要求 返回成功
            ret.message = "PayOrderPre state success"
            return ret
        end

        skynet.logd("PayFinish 2 => ", pre_orderStr)

        dbx.update(TableNameArr.UserPayOrderPre, pre_order, {state = 1})

        skynet.logd("PayFinish 3 => ", pre_orderStr)
        local storeId = pre_order.storeId

        common.pushUserPendingData(PendingDataType.PayFinish, pre_order.uId, {
            storeId = storeId,
            orderId = orderId,
            platform = pre_order.platform,
            transaction_id = transaction_id,
            sign = data.sign,
        })
        skynet.logd("PayFinish 4 => ", pre_orderStr)

        local userInfo = dbx.get(TableNameArr.User, pre_order.uId)
        dbx.add(tableName, {
            id          = pre_order.id,
            storeId     = storeId,
            uId         = pre_order.uId,

            nickname    = userInfo.nickname,
            registerDt  = userInfo.firstLoginDt,
            isFirstPay  = userInfo.pay <= 0,
            channel     = userInfo.channel,
            transaction_id = transaction_id,
            price       = pre_order.price,
            time        = os.time(),
            os          = pre_order.os,
            platform    = pre_order.platform,
        })

        skynet.logd("PayFinish end => ", pre_orderStr)

        ret.ok = true
        ret.code = 1
        ret.message = "success"
        return ret
    end

    CMD.buy_suc = CMD.PayFinish

    CMD.process_buy_suc = CMD.PayFinish

    CMD.apple_order_res = function (data)
        if not data.platform then
            data.platform = "applepay"
        end
        common.send_useragent(data.pid, "PayFinish", RET_VAL.ERROR_3, data)
    end

    CMD.HuaweiConfirm = function (args)
        local isGet = false
        for i = 1, 3 do
            if isGet or not moduleDatas.huaweiObj.authorization or not moduleDatas.huaweiObj.expires_in or os.time() > moduleDatas.huaweiObj.expires_in then
                moduleDatas.huaweiObj.authorization, moduleDatas.huaweiObj.expires_in = skynet.call("web_sdk", "lua", "HuaweiATGet")
            end
            local ret = huawei_sdk.confirm({purchaseToken = args.purchaseToken, productId = args.productId}, moduleDatas.huaweiObj.authorization)
            if ret then
                return true
            elseif ret == false then
                return false
            else
                isGet = true
            end
        end
        return false
    end

    CMD.HuaweiATGet = function ()
        if not moduleDatas.huaweiObj.authorization or not moduleDatas.huaweiObj.expires_in or os.time() > moduleDatas.huaweiObj.expires_in then
            cs(function ()
                if not moduleDatas.huaweiObj.authorization or not moduleDatas.huaweiObj.access_token or 
                    not moduleDatas.huaweiObj.expires_in or os.time() >= moduleDatas.huaweiObj.expires_in then

                    local ok, access_token, expires_in
                    for i = 1, 3 do
                        ok, access_token, expires_in = huawei_sdk.access_token()
                        if ok then
                            break
                        else
                            skynet.sleep(500)
                        end
                    end

                    if ok then
                        moduleDatas.huaweiObj.access_token = access_token
                        moduleDatas.huaweiObj.expires_in = os.time() + expires_in - 5

                        local str = "APPAT:" .. access_token
		                local authorization = "Basic " .. crypt.base64encode(str)

                        moduleDatas.huaweiObj.authorization = authorization

                        skynet.logd("huawei authorization:", moduleDatas.huaweiObj.authorization, moduleDatas.huaweiObj.access_token, moduleDatas.huaweiObj.expires_in)
                    end
                end
            end)
        end
        return moduleDatas.huaweiObj.authorization, moduleDatas.huaweiObj.expires_in
    end





    --QQ红包提现异步回调
    function CMD.bh_send_suc(data)
        --验签sign 根据sdk规则验签
        local retCode = 1 --验签失败
        -- print("type data" ,type(data))
        print('====================bh_send_suc=========', table.tostr(data))
        table.print(data)

        --更新数据记录
        if data~=nil and data.out_trade_no then
            local record = {				
                state = 1,               
                comp_time = nil,         --审核完成时间
                recive_time = nil,       --用户领取时间
            }
        
            if data.type == "hb" then
                record.state = 3 --订单状态 1已领取，2 审核中,3审核通过未领取
                record.comp_time = data.create_time
            elseif data.type == "hb_notify" then
                record.state = 1 
                record.recive_time = data.create_time
            end
        
            skynet.send(get_db_mgr(), "lua", "update_qq_hb_withdrawal",data.out_trade_no,record)
        else
            skynet.loge("===bh_send_suc=== error! rsp data is nil !")
        end	

        --默认成功返回
        retCode=0
        return {code=retCode,message="success"}
    end

    -- 穿山甲广告回调成功
    function CMD.pangle_succ(data)
        local isExits = skynet.call(get_db_mgr(), "lua", "rec_find_one", COLL.PANGLE_REC, {trans_id = data.trans_id})
        
        if isExits and not data.pid then
            return {ok = true}
        end

        local p_agent = skynet.call("agent_mgr", "lua", "GetPlayerAgent", data.pid)

        if p_agent then
            skynet.call(p_agent, 'lua', 'video_ad_report', data.trans_id,data.reward_name)
        else
            skynet.call(get_db_mgr(), "lua", "push", COLL.USER, {id = data.pid}, "pangle_suc_packs", {
                trans_id = data.trans_id,
                reward_name = data.reward_name,
            })
        end

        local p = skynet.call(get_db_mgr(), "lua", "get_user_info", data.pid)

        if not p then
            return {ok = true}
        end
        -- 插入记录
        skynet.send(get_db_mgr(), "lua", "rec_insert", COLL.PANGLE_REC, {
            pid = p.id,
            nickname = p.nick_name,
            channel = p.channel,
            trans_id = data.trans_id,
            reward_name = data.reward_name,
            time_end = os.time(),
        })

        return {ok = true}
    end


end