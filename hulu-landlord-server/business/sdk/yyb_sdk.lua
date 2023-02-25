local md5 = require "md5"
local crypt = require "skynet.crypt"
local sign_util = require "utils.sign_util"

local skynet = require "skynet"
require "BaseFunc"
local httpc = require "http.httpc"
local cjson = require "cjson"

local M = {}
-- 包名 com.tencent.tmgp.xun.huluddz
-- APP ID 1112149082
-- APP KEY guWbeEHRNH2VUt3Q # 也是沙箱appkey
-- APP KEY fq9VpJCCtWTr0oVI8Y1AxtDqqWpml2kQ # 现网支付用的appkey
M.qq_appid = "1112149082"
M.qq_appkey = "guWbeEHRNH2VUt3Q"


M.wechat_appid = "wx8f74f153d1480ec1" 
M.wechat_appkey = "198e77773951644aae29a6424def6b10"


M.midas_appid = ""
M.midas_appkey = ""  --正式服: j5LDIcdloKUiwj5SQKSTuOkc7jX6OcaS sGZKDYfVeDQEQJHq


-- 【正式环境】https://ysdk.qq.com/auth/qq_check_token
-- 【测试环境】https://ysdktest.qq.com/auth/qq_check_token
M.URL_qq = "https://ysdk.qq.com/auth/qq_check_token"
M.HOST_qq = "ysdk.qq.com"

-- 【正式环境】https://ysdk.qq.com/auth/wx_check_token
-- 【测试环境】https://ysdktest.qq.com/auth/wx_check_token
M.URL_wechat = "https://ysdk.qq.com/auth/wx_check_token"
M.HOST_wechat = "ysdk.qq.com"
-- 由appid对应的appkey,连接上timestamp参数，md5加密而成32位小写的字符串。访问手Q的接口就是使用手Q的appkey,访问微信的接口就是使用微信的appkey
-- sig = md5 ( appkey + timestamp ) "+"表示两个字符串的连接符，不要将"+"放入md5加密串中。

function M.login_sign(appkey, now)
	return md5.sumhexa(appkey..now)
end


function M.check_resp(t)
	if tonumber(t.ret) == 0 then
		return true, t
	else
		return false, t.msg
	end
end


function M.auth_token(inArgs)
	local args = inArgs
	-- local openid = "2E8BE71B6B6711576D34D4E42AFDB98D"
	-- local token = "DE01485036B8D7E72DA3A391D178234D"
	-- local find_char_index = string.find(args.password, "_", -3)
	-- if not find_char_index then
	-- 	find_char_index = string.find(args.password, "_", -7)
	-- 	if not find_char_index then
	-- 		return false
	-- 	end
	-- end

	-- local _token = string.sub(args.password, 1, find_char_index-1)
	-- local sub_sdk = string.sub(args.password, find_char_index+1, -1)

	if args.subSdk == "wechat" then
		return M.auth_token_wechat(args)
	end

	local openid = args.user
	local token = args.password
	local timestamp = os.time()
	local sign = M.login_sign(M.qq_appkey, timestamp)
	local url = string.format("%s?timestamp=%s&appid=%s&sig=%s&openid=%s&openkey=%s",
		M.URL_qq, timestamp, M.qq_appid, sign, openid, token)
    local status, results = httpc.get(M.HOST_qq, url)
	skynet.logd("status:", status, "result=", results)
    local result
    if results then
        result = cjson.decode(results)
    end
    if result and result.ret == 0 then
        return true
    end
     
	-- local params = "appId="..M.app_id.."&session="..session.."&uid="..uid --.."&signature="..signature
	-- params = params.."&signature="..param.signature
    -- local recHeader = {}
    -- local Headers = {
    --     ["Content-Type"] = "application/x-www-form-urlencoded",
    -- }
    -- local status, result = httpc.request("POST",  M.HOST, "/api/biz/service/loginvalidate", recHeader, Headers, params)
	-- return result
	skynet.logd("openid:[", openid, "token:[", token, "]status:[", status, "]result=[", results, "]")
	return false
end
function M.auth_token_wechat(args)
	-- local openid = "oHlND6J1tM7KHZgYeIkMrCR2SrzY"
	-- local token = "52_47VzYNBu4Cdtao7UyFlj2vy5pCJrxFIjkvlZoxbFu7hZRh-XY4USQZSvqHrnuALDOLHhnFTPpID9UAzjn5X7TsqEEnxW5YxmbXNO_MuZ5w8"

	local openid = args.user
	local token = args.password
	local timestamp = os.time()
	local sign = M.login_sign(M.wechat_appkey, timestamp)
	local url = string.format("%s?timestamp=%s&appid=%s&sig=%s&openid=%s&openkey=%s",
		M.URL_wechat, timestamp, M.wechat_appid, sign, openid, token)
    local status, results = httpc.get(M.HOST_wechat, url)
	skynet.logd("status:", status, "result=", results)
    local result
    if results then
        result = cjson.decode(results)
    end
    if result and result.ret == 0 then
        return true
    end

	skynet.logd("openid:[", openid, "token:[", token, "]status:[", status, "]result=[", results, "]")
	-- local params = "appId="..M.app_id.."&session="..session.."&uid="..uid --.."&signature="..signature
	-- params = params.."&signature="..param.signature
    -- local recHeader = {}
    -- local Headers = {
    --     ["Content-Type"] = "application/x-www-form-urlencoded",
    -- }
    -- local status, result = httpc.request("POST",  M.HOST, "/api/biz/service/loginvalidate", recHeader, Headers, params)
	-- return result
	return false
end

-- local url = string.format(
-- 	"http://ysdk.qq.com%s?timestamp=%s&appid=%s&sig=%s&openid=%s&openkey=%s",
-- 	self.url,
-- 	self.timestamp,
-- 	self.appid,
-- 	self.sign,
-- 	self.openid,
-- 	self.token
-- )
-- return httpc:request_uri(url)

-- ret	返回码 0：正确，其它：失败
-- msg	ret非0，则表示“错误码，错误提示”
return M