
local skynet = require "skynet"
local cjson = require "cjson"
local crypt = require "skynet.crypt"
local objx = require "objx"
require "table_util"

local ma_obj = {}

ma_obj.login = function (openid, sdk, param)

    local ret = false
    local baseObj = {}
    baseObj.os = param.os
    baseObj.sdk = param.sdk
    baseObj.channel = param.channel
    baseObj.ip = param.ip

    local setObj = {}

    if sdk == "test" then
        ret = true
    else
        if sdk == "yyb" then
            local passwordStr = crypt.base64decode(param.password)
            local token = cjson.decode(passwordStr)
            param.password = token.token
            param.subSdk = token.subSdk

            baseObj.subSdk = token.subSdk

            setObj.subSdk = token.subSdk
        end
        -- ret = skynet.call("httpclient", "lua", "auth_token", sdk, param)
        ret = skynet.call("httpclient", "lua", "auth_token_self", sdk, param)
    end

    local user
    if ret then
        user = skynet.call("db_manager", "lua", "GetUserInfoData", openid, baseObj, true)
        if not user then
            user = skynet.call("db_manager", "lua", "NewUserInfoData", openid, baseObj, setObj)
        end
    else
        skynet.loge("Login error!", openid, sdk, table.tostr(param))
    end
    return user
end

return ma_obj