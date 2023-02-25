require "BaseFunc"
require "table_util"
local sign_util = require "utils.sign_util"
local datacenter = require "skynet.datacenter"
local md5 = require "md5"
local M = {}


M.app_id = "1111901165"
M.app_secret = "R5URRZ3RvRqGBz86Ua51S8"

--QQ 原生小程序  （废弃）
--M.host = "https://api.q.qq.com"



--QQ minigame 2021
M.host = "https://cps.qianqiankeji.xyz"
M.sdk = "qq_minigame"

-- function M.login_params(code)
-- 	local fmt = "/sns/jscode2session?appid=%s&secret=%s&js_code=%s&grant_type=authorization_code"
-- 	local str = string.format(fmt, M.app_id, M.app_secret, code)
-- 	return str
-- end

-- function M.access_token_param()
-- 	local fmt = "/api/getToken?grant_type=client_credential&appid=%s&secret=%s"
-- 	local str = string.format(fmt, M.app_id, M.app_secret)
-- 	return str
-- end

function M.update_access_token(token, expires_in)
	local expire_time = expires_in - 60
	datacenter.set("qq_sdk", "access_token", token)
	datacenter.set("qq_sdk", "expires_in", expire_time) --提前60s去刷新
	print("update_access_token access_token =>", token, "; expire_time =>", os.date("%c", expire_time))
end

function M.get_host()
	return M.host
end

function M.get_app_id()
	return M.app_id
end

--QQ小游戏 APP sign
function M.get_app_sign()
	return md5.sumhexa(M.app_id..M.app_secret)
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



--QQ minigame 2021 接口

--第三方支付 验签 qq minigame
function M.payapi_sign(t)	
	local sign = t.sign
	t.sign = nil --清除
	local cur_sign = M.sign_qq_sdk(t)
	t.sign = sign --还原
	return sign ==  cur_sign
end


function M.sign_qq_sdk(t)
	local tt = sign_util.sort_tbl_by_key(t)
	local base_str = sign_util.sign_table2str(tt)
	base_str = base_str .. M.app_secret
	-- print("base_str =",base_str)	
	local sign= md5.sumhexa(base_str)
	-- print("sign =",sign)
	return sign
end

return M