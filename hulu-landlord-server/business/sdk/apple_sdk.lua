local skynet = require "skynet"
local mycrypt = require "utils.mycrypt"
local crypt = require "skynet.crypt"
local cjson = require "cjson"
local httpc = require "http.httpc"

local M = {}

M.URL = "https://appleid.apple.com/auth/keys"
M.HOST = "https://appleid.apple.com"
function M.safe_base64decode(str)
	local remainder = #str % 4
	if remainder and remainder ~= 0 then
		local padlen = 4 - remainder
		str = str .. string.rep("=",padlen)
	end

	str = string.gsub(str,'-', '+')
	return string.gsub(str,'_', '/')
end

function M.check_resp(body,data)
	local pub_key = body.key
	local token = data.token

	local sign_content,sig = string.match(token,"(.+)%.(.+)")
	
	sig = M.safe_base64decode(sig)


	local ret,err = mycrypt.process_check(sign_content, sig, pub_key, 'SHA256')
    
    if ret ~= 0 then
        skynet.error("验签失败:",err,sign_type)
        return false,"sign error"
    end
    return ret  == 0
end

function M.check_resp_Ex(key,token)
	local pub_key = key
	local token = token
	local sign_content,sig = string.match(token,"(.+)%.(.+)")
	sig = M.safe_base64decode(sig)
	local ret,err = mycrypt.process_check(sign_content, sig, pub_key, 'SHA256')
    if ret ~= 0 then
        skynet.error("验签失败:err=[",err)
        return false
    end
    return ret  == 0
end


function M.auth_token(args)
	local token = args.password
	local args_new = {}
	args_new.token = token
	args_new.what = "auth_token"
	args_new.sdk = "apple"--args.dk
	
	local status, body = httpc.post("127.0.0.1:8080", "/auth_token_or_userinfo", args_new)
	if status == 200 then
		local result
		if body then
			result = cjson.decode(body)
		end
		local pub_key = result["key"]
		if M.check_resp_Ex(pub_key, token) then
			return true
		end
	end

	return false
end

return M