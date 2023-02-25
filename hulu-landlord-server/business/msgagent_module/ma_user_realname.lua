local skynet = require "skynet"
local ma_data       = require "ma_data" 
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"
local eventx = require "eventx"
require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
--#endregion

local CMD, REQUEST_New = {}, {}
-- 后续写服务间调用接口时命名方式以 CMD_ 开头， 如 CMD_Open

local userInfo = ma_data.userInfo
local xunyou_channel = "huluddz"

local ma_obj = {
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)
    eventx.listen(EventxEnum.UserOnline, function ()
        if userInfo.channel ~= xunyou_channel then
            ma_obj.SetAuthtionOtherPlat()
        end

    end, eventx.EventPriority.Before)
end

--獲取年齡
function ma_obj.get_user_age(idcard)
    local dt = os.date("*t", os.time())
    local year = tonumber(idcard:sub(7,10))
    local month = tonumber(idcard:sub(11,12))
    local day = tonumber(idcard:sub(13,14))
    local user_age = dt.year - year

    if month == dt.month and day > dt.day then
        user_age = user_age - 1
    elseif month > dt.month then
        user_age = user_age - 1
    end

    return user_age
end

function ma_obj.SetAuthtionOtherPlat()
    if not userInfo.Authtion or userInfo.Authtion == AuthenticationPower.Unknown then
        userInfo.Authtion = AuthenticationPower.Power4
        local updateData = {Authtion = userInfo.Authtion}
        dbx.update(TableNameArr.User, userInfo.id, updateData)
        ma_common.updateUserBase(userInfo.id, updateData)
    end
end



-- --[[
-- -- 实名认证接口

-- 接口调用地址：https://api.wlc.nppa.gov.cn/idcard/authentication/check

-- 接口请求方式：POST

-- 接口理论响应时间：300ms

-- 报文超时时间（TIMESTAMPS）：5s

-- 客户端接口超时时间（建议）：5s

-- 接口限流：100 QPS（超出后会被限流 1 分钟）
-- --]]
-- function CMD.check_realname(args)
-- 	-- 大于请求限制
-- 	if CMD.req_overdrive("check") then
-- 		return RN_ERR.OVERDRIVE -- 请求过载
-- 	end
	
-- 	local req = {
-- 		data = cjson.encode({
-- 			ai = args.ai or CMD.gen_ai(args.pid,args.rn_auth_count),
-- 			name = args.name,
-- 			idNum = args.idcard,
-- 		}),
-- 		secret = rn_conf.secret
-- 	}

-- 	-- 请求加密数据
-- 	local ok,status,data = pcall(httpc.post,"127.0.0.1:80","/cipher",req)


-- 	if not ok or status ~= 200 or not data then
-- 		skynet.error("request nginx cipher error!")
-- 		return RN_ERR.ENC_ERR 	-- 数据加密错误
-- 	end

-- 	data = string.trim(data)

-- 	local data = cjson.encode({data = data})

-- 	local header = CMD.get_header(data)
	
-- 	-- local status,body = CMD.post_string("https://api.wlc.nppa.gov.cn",
-- 	-- 						"/idcard/authentication/check",data,nil,header)

-- 	local ok,status,body = pcall(CMD.post_string,"127.0.0.1:80","/check_realname",data,nil,header)


-- 	--  测试调试地址
-- 	--https://wlc.nppa.gov.cn/test/authentication/check/
-- 	--local status,body = CMD.post_string("https://wlc.nppa.gov.cn",
-- 	--						"/test/authentication/check/MrePpm",data,nil,header)


-- 	-- TODO 结果处理
-- 	if status ~= 200 or not ok then
-- 		return RN_ERR.REQ_ERR
-- 	end

-- 	body = cjson.decode(body)

-- 	if body.errcode == 0 then
-- 		local result = body.data.result
-- 		-- 认证中,存储参数,方便后期查询
-- 		if result.status == 1 then
-- 			CMD.set_inauth_data(args)
-- 		end
-- 		return RN_ERR.SUCC,result
-- 	elseif body.errcode == 2004 then
-- 		CMD.set_inauth_data(args)
-- 	else
-- 		skynet.error("check_realname error :",cjson.encode(body),args.ai or CMD.gen_ai(args.pid,args.rn_auth_count))
-- 	end
-- end

function ma_obj.Authentication(args) 
    if true then
        userInfo.Authtion = AuthenticationPower.Power3 --成年
        userInfo.AuthtionId = args.Id
        userInfo.AuthtionType = AuthenticationTypeEm.identityCard
        local updateData = {Authtion = userInfo.Authtion, AuthtionId = userInfo.AuthtionId, AuthtionType = userInfo.AuthtionType}
        dbx.update(TableNameArr.User, userInfo.id, updateData)
        ma_common.updateUserBase(userInfo.id, updateData)
        return AuthenticationPower.Power3
    end
    local errCode = RET_VAL.Other_10
    if not args or not args.AuthenticationType or not args.Id or not args.Name then
        return errCode
    end

    local AuthenticationType = args.AuthenticationType
    local AuthenticationId = args.Id
    
    if AuthenticationType == AuthenticationTypeEm.identityCard then --身份证实名认证
        local Authtion = AuthenticationPower.Unknown --认证中
        if true then
            local check_args = {}
            check_args.uid = userInfo.id
            check_args.name = args.Name
            check_args.cardId = args.Id
            local _err_code, r_status, r_pi  = skynet.call("real_name", "lua", "CheckRealName", check_args)
            if _err_code == RET_VAL.Succeed_1 then
                if r_status == 0  then --认证成功
                    if ma_obj.get_user_age(AuthenticationId) < 18 then
                        Authtion = AuthenticationPower.Power2 --未成年
                    else 
                        Authtion = AuthenticationPower.Power3 --成年
                    end
                    errCode = RET_VAL.Succeed_1
                elseif r_status == 1 then --认证中
                    Authtion = AuthenticationPower.Power1 --认证中
                    errCode = RET_VAL.Succeed_1
                end
            end
        else
            Authtion = AuthenticationPower.Power1 --认证中
            if ma_obj.get_user_age(AuthenticationId) < 18 then
                Authtion = AuthenticationPower.Power2 --未成年
            else 
                Authtion = AuthenticationPower.Power3 --成年
            end
            errCode = RET_VAL.Succeed_1
        end
        userInfo.Authtion = Authtion
        userInfo.AuthtionId = AuthenticationId
        userInfo.AuthtionType = AuthenticationType

        local updateData = {Authtion = Authtion, AuthtionId = AuthenticationId, AuthtionType = AuthenticationType}
        dbx.update(TableNameArr.User, userInfo.id, updateData)
        ma_common.updateUserBase(userInfo.id, updateData)
    end

    return  errCode
end

REQUEST_New.Authentication = function (args)
    if not args or not args.AuthenticationType or not args.Id or not args.Name then
        return RET_VAL.Fail_2
    end

    local errCode = ma_obj.Authentication(args)
    local proto = {}
    proto.Authentication = userInfo.Authtion--没有实名认证
    return errCode, proto
end

return  ma_obj