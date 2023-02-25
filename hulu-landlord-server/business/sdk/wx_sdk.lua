--微信SDK
require "BaseFunc"
require "table_util"
local sign_util = require "utils.sign_util"
local datacenter = require "skynet.datacenter"
local httpc = require "http.httpc"
local cjson = require "cjson"
local skynet = require "skynet"
local md5 = require "md5"
local sha256 = require "sha256"
local M = {}


M.app_id = "wx25cf004542a6a423"
M.app_secret = "fb798aab2bdbcd7cae31c64952c63b32"

--QQ 原生小程序  （废弃）
--M.host = "https://api.q.qq.com"



--QQ minigame 2021
M.host = "https://api.weixin.qq.com"

M.url_code2Session = "/sns/jscode2session?appid=%s&secret=%s&js_code=%s&grant_type=authorization_code"
M.url_checkSessionKey = "/wxa/checksession?access_token=%s&signature=%s&openid=%s&sig_method=hmac_sha256"
M.url_getAccessToken = "/cgi-bin/token?grant_type=client_credential&appid=%s&secret=%s"

M.sdk = "wx"
M.midas_url_pre1 = "https://api.weixin.qq.com/cgi-bin/midas"
M.app_key_sandbox = "ZKYJfCSjZcB7kJ9Pnhvw9p6kxfUDk8iq" --沙箱米大师支付key
M.app_key = "FdQRQS1hTUCkdDfOOxYtPQ7WFk8o9CdE" --现网米大师支付key
M.offer_id = "1450030041"


function M.get_mds_getbalance_url(sandbox)
	local sandbox_url = sandbox and "/sandbox" or ""
	local access_token = datacenter.get("wx_sdk", "access_token")
	return M.midas_url_pre1..sandbox_url.."/getbalance?access_token="..access_token
end

function M.get_mds_pay_url(sandbox)
	local sandbox_url = sandbox and "/sandbox" or ""
	local access_token = datacenter.get("wx_sdk", "access_token")
	return M.midas_url_pre1..sandbox_url.."/pay?access_token="..access_token
end

function M.get_mds_cancelpay_url(sandbox)
	local sandbox_url = sandbox and "/sandbox" or ""
	local access_token = datacenter.get("wx_sdk", "access_token")
	return M.midas_url_pre1..sandbox_url.."/cancelpay?access_token="..access_token
end


function M.update_access_token(token, expires_in)
	local expire_time = os.time() + expires_in - 60
	datacenter.set("wx_sdk", "access_token", token)
	datacenter.set("wx_sdk", "expires_in", expire_time) --提前60s去刷新
	print("update_access_token access_token =>", token, "; expire_time =>", os.date("%c", expire_time))
end


function M.get_app_id()
	return M.app_id
end

--QQ小游戏 APP sign
function M.get_app_sign()
	return md5.sumhexa(M.app_id..M.app_secret)
end

function M.access_token_vaild()
	local token = datacenter.get("wx_sdk", "access_token")
	local expires_in = datacenter.get("wx_sdk", "expires_in")
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

--QQ验签
function M.sign_qq_sdk(t)
	local tt = sign_util.sort_tbl_by_key(t)
	local base_str = sign_util.sign_table2str(tt)
	base_str = base_str .. M.app_secret
	-- print("base_str =",base_str)	
	local sign= md5.sumhexa(base_str)
	-- print("sign =",sign)
	return sign
end

function M.sign_midas(t,sandbox,urlmethod)
	local tt = sign_util.sort_tbl_by_key(t)
	local stringA = sign_util.sign_table2str(tt)
	local sandbox_url = sandbox and "/sandbox" or ""
	local stringSignTemp=stringA.."&org_loc=/cgi-bin/midas"..sandbox_url.."/"..urlmethod.."&method=POST&secret="
	local app_key
	if sandbox then
		app_key = M.app_key_sandbox
	else
		app_key = M.app_key 
	end	
	stringSignTemp = stringSignTemp..app_key
	print("stringSignTemp =",stringSignTemp)	
	local sign= sha256.hmac_sha256(app_key, stringSignTemp)
	print("sha256 sign =",sign)	
	return sign
end

function M.auth_token(args)
	local args_new = {}
	args_new.token = args.password
	args_new.openid = args.user

	local auth_url = 'https://api.weixin.qq.com/sns/auth?access_token='..args_new.token..'&openid='..args_new.openid
	local status, results = httpc.get("https://api.weixin.qq.com", auth_url)
	skynet.logd("status:", status, "result=", results)
	local result
	if results then
		result = cjson.decode(results)
	end
	if result and result.errcode == 0 then
		return true
	end
	return false
end

return M