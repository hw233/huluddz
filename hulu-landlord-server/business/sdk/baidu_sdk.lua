local crypt = require "skynet.crypt"
local sign_util = require "utils.sign_util"

local skynet = require "skynet"
require "BaseFunc"
local httpc = require "http.httpc"
local cjson = require "cjson"
local md5 = require "md5"

local M = {}


M.app_id = "25437749"
M.app_key = "A03K49pWbEt3Zm1CH7z0xBAQ" --
M.app_secret = "68v2zq2gNNzKfl6MAATq4wmdnCRGG7Yl"
M.URL = "https://mg.baidu.com/member-union/game/cploginstatequery?"
M.HOST = "mg.baidu.com"


function M.MD5(accessToken)
	return md5.sumhexa(M.app_id..accessToken..M.app_secret)
end

function M.auth_token(args)
    --{"os":"android","country":"","server":"xyserver_dev","version":"1.0.1_1.1.64",
    
    --"password":"f087f97b26db4a85a255c78b0f17faec-e68612305e16da17573eaf9873231845-20220121094432-034c574eb53ea63c3bf8a9abaa6873a9-5621a13877749bcfc9c944800bd779fc-745c7b3997b86331d474982add768416",
    --"channel":"huluddz_baidu","user":"013217db267443d7ad6ec80434bdd861","sdk":"baidu"} 

	local accessToken = args.password
	local uid = args.user
	skynet.logd("uid=[", uid, "]accessToken=[", accessToken,"]")

	local sign = M.MD5(accessToken)

    local url = M.URL.."AppID="..M.app_id.."&AccessToken="..accessToken.."&Sign="..sign
    -- local status, results = httpc.post(M.HOST, url)
    local status, results = httpc.get(M.HOST, url)
    --{"AppID":"25437749","Content":"eyJVSUQiOiIwMTMyMTdkYjI2NzQ0M2Q3YWQ2ZWM4MDQzNGJkZDg2MSJ9","ResultMsg":"AccessToken合法有效","Sign":"e0a6cc601c8f6ea00f71315e1e8993d4","ResultCode":"1"}
    if status ~= 200 then
        return false
    end

    local result
    if results then
        result = cjson.decode(results)
    end
    if not result or tostring(result.ResultCode) ~= "1" then
        skynet.logd("status:", status, "result=", results)
        return false
    end

	if result and tostring(result.ResultCode) == "1" then
		return true
	end
	return false
end

return M