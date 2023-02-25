local skynet = require "skynet"
local crypt = require "skynet.crypt"
require "BaseFunc"
local httpc = require "http.httpc"
local cjson = require "cjson"
local M = {}


M.app_id = "30693625"

M.app_key = "fd139d8b25b14f0c90d672467c6d13d0"

M.app_secret = "519de68b5aa64b8f90bf82227de2bfb1"

function M.login_params(token)
	local req_params = string.format(
		"oauthConsumerKey=%s&oauthToken=%s&oauthSignatureMethod=HMAC-SHA1&oauthTimestamp=%s&oauthNonce=%s&oauthVersion=1.0&",
		string.urlencode(M.app_key),
		string.urlencode(token),
		string.urlencode(tostring(os.time())),
		string.urlencode(tostring(math.random(1000000000, 9999999999)))
	)

	local sign = crypt.hmac_sha1(M.app_secret.."&", req_params)
	sign = string.urlencode(crypt.base64encode(sign))
	return req_params,sign
end

function M.check_resp(args)
	if tonumber(args.resultCode) == 200 then
		return true, args
	else
		return false, args.resultMsg
	end
end


-- function LuaUtils.EncodeURL(s)
--     s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
--     --# 空格变成+
--     return string.gsub(s, " ", "+")
-- end

-- function M.decodeURI(s)
--     s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
--     return s
-- end

-- function M.encodeURI(s)
--     s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
--     return string.gsub(s, " ", "+")
-- end


function M.GetBaseStrAndSign(token)
	local req_params = string.format(
		"oauthConsumerKey=%s&oauthToken=%s&oauthSignatureMethod=HMAC-SHA1&oauthTimestamp=%s&oauthNonce=%s&oauthVersion=1.0&",
		string.urlencode(M.app_key),
		string.urlencode(token),
		string.urlencode(tostring(os.time())),
		string.urlencode(tostring(math.random(1000000000, 9999999999)))
	)
	local sign = crypt.hmac_sha1(M.app_secret.."&", req_params)
	sign = string.urlencode(crypt.base64encode(sign))
	return req_params, sign
end

function M.auth_token(args)
	local outh_data = args
	local ssoid = args.user
	local token = args.password

	local base_str, sign = M.GetBaseStrAndSign(token) 
	local url = "https://iopen.game.oppomobile.com/sdkopen/user/fileIdInfo?fileId="..ssoid.."&token="..string.urlencode(token)
	local headers = {
		["Content-Type"] = "application/json;charset=UTF-8",
		["param"] = base_str,
		["oauthSignature"] =sign 
	}
	local rec = {} 

	local status, results = httpc.request("GET",  "iopen.game.oppomobile.com", url, rec,headers)
	if status ~= 200 then
		return false
	end

	local result
    if results then
        result = cjson.decode(results)
    end
    if result and result.resultCode == "200" then
		local _loginToken = result["loginToken"]
		local _ssoid = result["ssoid"]
		if  _ssoid == ssoid then
			return true
		end
    end
     

	local log = string.format("auth_token::args","base_str=[", base_str ,"], sign=[", sign,"], status=[", status, "], result=[", result,"]")
	skynet.logd(log)
	return false
end

return M
