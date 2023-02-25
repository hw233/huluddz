local skynet = require "skynet"

local httpc = require "http.httpc"
local dns = require "skynet.dns"
local cjson = require "cjson"

local server_conf = require "server_conf"
local xy_cmd = require "xy_cmd"
local mall_conf = require "cfg/cfg_mall"
local oppo_sdk = require "config/oppo_sdk"
local huawei_sdk = require "config/huawei_sdk"
local yyb_sdk 	= require "config/yyb_sdk"
local qihoo_sdk	= require "config/qihoo_sdk"
local apple_sdk = require "config/apple_sdk"

require "pub_util"
require "wx_util"
require "ali_util"

require "base.BaseFunc"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

function CMD.auth_token(sdk, args)
	args.what = "auth_token"
	args.sdk = sdk

	local status, body = httpc.post("127.0.0.1:80", "/auth_token_or_userinfo", args)
	print(status, body)

	if status == 200 then
		local ok, t = pcall(cjson.decode, body)
		if ok then
			if sdk == 'wechat' then
				if t.errmsg == 'ok' then
					return true
				else
					return false, t.errmsg
				end
			elseif sdk == 'oppo' then
				return oppo_sdk.check_resp(t)
			elseif sdk == 'vivo' or sdk == "vivoad" then
				if tonumber(t.retcode) == 0 then
					return true, t.data
				else
					return false, t.retcode
				end
			elseif sdk == "huawei" then
				return huawei_sdk.check_resp(t)
			elseif sdk == "yyb" then
				return yyb_sdk.check_resp(t)
			elseif sdk == "qihoo" then
				return qihoo_sdk.check_resp(t)
			elseif sdk == "apple" then
				return apple_sdk.check_resp(t,args)
			end
		else
			return false, t
		end
	end
	return false, 'status ~= 200'
end