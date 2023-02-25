require "BaseFunc"
require "table_util"
local datacenter = require "skynet.datacenter"
local M = {}


M.app_id = "1111589589"
M.app_secret = "T9dFP4VZ7fywDMt5"
M.host = "https://mgc.meituan.com"

function M.login_params()
	return "/mgc/gateway/api/v3/mg/jscode2session"
end

function M.access_token_param()
	local fmt = "/api/getToken?grant_type=client_credential&appid=%s&secret=%s"
	local str = string.format(fmt, M.app_id, M.app_secret)
	return str
end

function M.update_access_token(token, expires_in)
	local expire_time = os.time() + expires_in - 10 * 60
	datacenter.set("qq_sdk", "access_token", token)
	datacenter.set("qq_sdk", "expires_in", expire_time) --提前10分钟去刷新
	print("update_access_token access_token =>", token, "; expire_time =>", os.date("%c", expire_time))
end

function M.get_host()
	return M.host
end

function M.access_token_vaild()
	local token = datacenter.get("qq_sdk", "access_token")
	local expires_in = datacenter.get("qq_sdk", "expires_in")
	return token ~= nil and expires_in > os.time()
end

function M.check_resp(args)
	if tonumber(args.resultCode) == 200 then
		return true, args
	else
		return false, args.resultMsg
	end
end

function M.create_login_func(appid, secret)
    return function(...)
        local code = ...

    end,
    function(...)

    end
end


return M