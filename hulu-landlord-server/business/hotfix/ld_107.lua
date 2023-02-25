local skynet = require "skynet"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
local cjson = require "cjson"
local crypt = require "skynet.crypt"
local apple_sdk = require "config.apple_sdk"
local auth =  ServerData.auth



-- 第三方渠道登陆,如oppo
local function get_3rd_dbinfo(openid,ip,sdk,base,...)
	local u = skynet.call("db_manager", "lua", "GetUserInfoData", openid,ip,true)
	if not u then
		u = skynet.call("db_manager", "lua", "register_3rd", openid, ip, sdk,base,...)
	end
	return u
end

-- apple 苹果
function auth.apple(openid,token,ip,base)
	local header,payload,sign = string.match(token,"(.+)%.(.+)%.(.+)")
	payload = crypt.base64decode(apple_sdk.safe_base64decode(payload))
	payload = cjson.decode(payload)
	assert(payload.sub == openid,"user id different")

	-- token 有效期10 分钟
	print("apple",os.time() + 24*3600,payload.exp,os.time() + 24*3600 - payload.exp)
	assert(os.time() + 24*3600 - payload.exp <= 60 * 10,"token timeout" )


	local ok, t = skynet.call("httpclient", "lua", "auth_token", "apple", {token = token})
	assert(ok,t)

	return get_3rd_dbinfo(openid,ip,"apple",base)
end