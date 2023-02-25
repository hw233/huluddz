local crypt = require "skynet.crypt"
local sign_util = require "utils.sign_util"

local skynet = require "skynet"
require "BaseFunc"
local httpc = require "http.httpc"
local cjson = require "cjson"

local M = {}


M.app_id = "2882303761520120142"
M.app_key = "5382012077142" --
M.app_secret = "/Y+wnmDzvawMxHhUj/UL1g=="
M.URL = "https://mis.migc.xiaomi.com/api/biz/service/loginvalidate?"
M.HOST = "mis.migc.xiaomi.com"
-- --POST https://mis.migc.xiaomi.com/api/biz/service/loginvalidate
-- appId=2882303761517239138&session=1nlfxuAGmZk9IR2L&uid=100010&signature=b560b14efb18ee2eb8f85e51c5f7c11f697abcfc
-- --

-- 11:52
-- AppID：
-- 2882303761520120142 
-- AppKey：
-- 5382012077142 
-- AppSecret：
-- /Y+wnmDzvawMxHhUj/UL1g== 


function M.sign(t)
	local tt = sign_util.sort_tbl_by_key(t)
	local base_str = sign_util.sign_table2str(tt)
	local sign = crypt.hmac_sha1(M.app_secret, base_str)

	local r = ""
	for i=1,#sign do
		local b = sign:sub(i, i)
		local c = string.format("%02x", string.byte(b))
		r = r..c
	end

	return r
end

function M.auth_token(args)
	local session = args.password
	local uid = args.user
	skynet.logd("uid=[", uid, "]session=[", session,"]")
	-- local params = "appId="..M.app_id.."&session="..session.."&uid="..uid.."&signature="..signature

	local param = {
		appId= M.app_id,
		session=session,
		uid = uid
	}
	param.signature = M.sign(param)

    local status, results = httpc.post(M.HOST, "/api/biz/service/loginvalidate", param)
    local result
    if results then
        result = cjson.decode(results)
    end
    if not result or result.errcode ~= 200 then
        skynet.logd("status:", status, "result=", results)
        return false
    end

	if result and result.errcode == 200 then
		return true
	end
    
    -- local data = result["data"]
    -- skynet.logd("status:", status, "resulresultst=", results)
    -- if data and data["openid"] == ssoid then
    --     return true
    -- end
    
	-- local params = "appId="..M.app_id.."&session="..session.."&uid="..uid --.."&signature="..signature
	-- params = params.."&signature="..param.signature
    -- local recHeader = {}
    -- local Headers = {
    --     ["Content-Type"] = "application/x-www-form-urlencoded",
    -- }
    -- local status, result = httpc.request("POST",  M.HOST, "/api/biz/service/loginvalidate", recHeader, Headers, params)
	return false
end

-- 状态码:
-- 200 验证正确
-- 1515 appId 错误(注意格式问题:比如appId必须是数字以及是否没传)
-- 1516 uid 错误
-- 1520 session 错误
-- 1525 signature 错误
-- 4002 appid, uid, session 不匹配(常见为session过期)

-- | adult | 可选 | 用户实名标识:
-- 406 非身份证实名方式
-- 407 实名认证通过，年龄大于18岁
-- 408 实名认证通过，年龄小于18岁
-- 409 未进行实名认证 |age|可选|用户年龄 例如：

-- { "errcode": 200,"adult":409 }

return M