local skynet = require "skynet"
local crypt = require "skynet.crypt"
require "BaseFunc"
local httpc = require "http.httpc"
local cjson = require "cjson"

local M = {}
M.app_id = "105526878"
M.app_key = "49284dab762fc27fba22a331403be5d3" --账号
M.page_name = "com.xunyou.huludoudizhu.vivo"
M.Cp_ID = "e4e5beccf9629742975c"
M.URL = "https://joint-account.vivo.com.cn/cp/user/auth"
M.HOST = "joint-account.vivo.com.cn"
function M.auth_token(args)
	local ssoid = args.user
	local token = args.password
	skynet.logd("ssoid=[", ssoid , "]", "token=[", token, "]")
    local status, results = httpc.post(M.HOST, "/cp/user/auth", {opentoken = token})
    if status == 200 then
        local result
        if results then
            result = cjson.decode(results)
        end
        if not result or result.retcode ~= 0 then
            skynet.logd("status:", status, "result=", results)
            return false
        end
        
        local data = result["data"]
        if data and data["openid"] == ssoid then
            return true
        end
    end
    return false
end

return M