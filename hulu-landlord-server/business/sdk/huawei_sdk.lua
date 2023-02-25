
local skynet = require "skynet"
local mycrypt = require "utils.mycrypt"
local sign_util = require "utils.sign_util"
local httpc = require "http.httpc"
local cjson = require "cjson"

local M = {}

M.appid = "105055175"
M.cpId = "2850086000536207950"
M.prv_key = [[
-----BEGIN RSA PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDoQlZILZHKNxQcXEI8eN7VG30A9vuSnKooT08wNFAozET4HMOCTQJ3h6CEVRHi+PG+WuQ435SIBK4bzJcDZfS0u9aLOyuM3+gd2OBbKZWK8Z4/gfR1Mn1Q7Qln1+ky1IzNgSrrkgqn2GouLWFfH70MZL79ek0WF4gpWsaVt9j8hd2vyJ/MXxGjpRxVnAjrNXIw682M6mJIH03oKeTuDuzRYwi/rxyjk4hNA7go4AYk2vgTuuAJ9wvMl8LhLF0iJJ0lAHAtj0JVXcz5ZUefFOFz7tJLOLKIsRRvN38lnsYnMwYmpueNKsHqjEgD2ZPsaEYdqiSAZoD7boWi3/nn5OEdAgMBAAECggEAFIXgF+qm6kZpqYPhenR3xD70kcRBQJhFVOCFL84/kwtRwNbR0864PBWo8miN9w9mVRq09e2Ts10ugVhXs74rnFjIwW7OD1mtqg2C7atEAo4NHLGAB2cZua/oV9u1SH+NnY8fWseB14kBAOmTpBMq4lB4q+9FpoEX0AesaohfTRjgAIxRrBYom+cCLZoA0wDFr1sDZOntsTAQAlG79jyI3Y2tLQ8knqngB0kCwKl19U5hWBe5ME2rNOGKVm0RJLPxO4GDfXwQmMtgqKed7Adfr6x5+teZdoWZR68zoqqijihx4tUl+BEijwDDh675RaGWRWu5Cjykni90DagY+pKL5QKBgQD2IGGmCqwmInjsyqlEc2o0gBMsBC7FLSTqM0loHLZ5lBeDNW3/DK3OfqfIrCmI7FVG8+XbJv11POJkmSAiL9Zp/M9LPzy5T3aAu/k+iZj17+Tal+p5EVZKKx56Kxjo3h+ZDdSEI+/N+rQZo+eW/GdoRy5J9evRq6coza7Mm+GUSwKBgQDxk4sgdrAaq5VkyN+mwsk4pUcGl+z3MXIi4gXrBqL6VKgDfwMFBOfRLytwc7q/8FFpOT90ulr/LIUsav9L+ee7YbdEXKMqEttuMGnBZYdtIJEqnLwQb+zbcygJGHukk9+R6KKcHlb/EiJsr6vsM2FfrAu5vdEowSpUmwJ3fXTvNwKBgQDZ/mg+pmk/BX1RTVaKuCazBVT1wWajYY62mGJGAlhkapRAtEwOgG5Y3LlC9al8CsalJ1TIvEn1Us26CB376Z7hFPeNUB86inUNJHBnwXtnKOjr623TeVWSL4q47f8MEeCusR8vQp0dNRXbN97hTgFQzOrkuxn5BS3y5+oQc2hi7QKBgQC98uCDXy+rWN04CQZqbmCgDL0jPxRRbeyr5wL2QRqnMSeG0DjEmo3YmnlSi3z87O5miWAO3XUtjYkNWvhwegiu+u+KbjjRnVAyfRi6u6VXtjLOybzKQ+d+yjZhqIGX77nsVXp+vRB0sYKl6R+Ksv/OpU3293zdyb0KF3RCFkB60wKBgQDrq4aWy/goq3gbWzjKBc68zl42siDdZ/GNR/HQtjqb/umnQSWq/uRuQMs+Trk0KmStVgHLbYB1GELU5txzE66aYQksnbRodlBYMafz+G/n8yyb84pY12yk49qvigB2Lh8tGYtkqBnCwmf4+2NpOCl2te3n6RfJ2cwRhM/j00uEUg==
-----END RSA PRIVATE KEY-----
]]


-- M.prv_key = "MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDoQlZILZHKNxQcXEI8eN7VG30A9vuSnKooT08wNFAozET4HMOCTQJ3h6CEVRHi+PG+WuQ435SIBK4bzJcDZfS0u9aLOyuM3+gd2OBbKZWK8Z4/gfR1Mn1Q7Qln1+ky1IzNgSrrkgqn2GouLWFfH70MZL79ek0WF4gpWsaVt9j8hd2vyJ/MXxGjpRxVnAjrNXIw682M6mJIH03oKeTuDuzRYwi/rxyjk4hNA7go4AYk2vgTuuAJ9wvMl8LhLF0iJJ0lAHAtj0JVXcz5ZUefFOFz7tJLOLKIsRRvN38lnsYnMwYmpueNKsHqjEgD2ZPsaEYdqiSAZoD7boWi3/nn5OEdAgMBAAECggEAFIXgF+qm6kZpqYPhenR3xD70kcRBQJhFVOCFL84/kwtRwNbR0864PBWo8miN9w9mVRq09e2Ts10ugVhXs74rnFjIwW7OD1mtqg2C7atEAo4NHLGAB2cZua/oV9u1SH+NnY8fWseB14kBAOmTpBMq4lB4q+9FpoEX0AesaohfTRjgAIxRrBYom+cCLZoA0wDFr1sDZOntsTAQAlG79jyI3Y2tLQ8knqngB0kCwKl19U5hWBe5ME2rNOGKVm0RJLPxO4GDfXwQmMtgqKed7Adfr6x5+teZdoWZR68zoqqijihx4tUl+BEijwDDh675RaGWRWu5Cjykni90DagY+pKL5QKBgQD2IGGmCqwmInjsyqlEc2o0gBMsBC7FLSTqM0loHLZ5lBeDNW3/DK3OfqfIrCmI7FVG8+XbJv11POJkmSAiL9Zp/M9LPzy5T3aAu/k+iZj17+Tal+p5EVZKKx56Kxjo3h+ZDdSEI+/N+rQZo+eW/GdoRy5J9evRq6coza7Mm+GUSwKBgQDxk4sgdrAaq5VkyN+mwsk4pUcGl+z3MXIi4gXrBqL6VKgDfwMFBOfRLytwc7q/8FFpOT90ulr/LIUsav9L+ee7YbdEXKMqEttuMGnBZYdtIJEqnLwQb+zbcygJGHukk9+R6KKcHlb/EiJsr6vsM2FfrAu5vdEowSpUmwJ3fXTvNwKBgQDZ/mg+pmk/BX1RTVaKuCazBVT1wWajYY62mGJGAlhkapRAtEwOgG5Y3LlC9al8CsalJ1TIvEn1Us26CB376Z7hFPeNUB86inUNJHBnwXtnKOjr623TeVWSL4q47f8MEeCusR8vQp0dNRXbN97hTgFQzOrkuxn5BS3y5+oQc2hi7QKBgQC98uCDXy+rWN04CQZqbmCgDL0jPxRRbeyr5wL2QRqnMSeG0DjEmo3YmnlSi3z87O5miWAO3XUtjYkNWvhwegiu+u+KbjjRnVAyfRi6u6VXtjLOybzKQ+d+yjZhqIGX77nsVXp+vRB0sYKl6R+Ksv/OpU3293zdyb0KF3RCFkB60wKBgQDrq4aWy/goq3gbWzjKBc68zl42siDdZ/GNR/HQtjqb/umnQSWq/uRuQMs+Trk0KmStVgHLbYB1GELU5txzE66aYQksnbRodlBYMafz+G/n8yyb84pY12yk49qvigB2Lh8tGYtkqBnCwmf4+2NpOCl2te3n6RfJ2cwRhM/j00uEUg=="
M.pub_key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6EJWSC2RyjcUHFxCPHje1Rt9APb7kpyqKE9PMDRQKMxE+BzDgk0Cd4eghFUR4vjxvlrkON+UiASuG8yXA2X0tLvWizsrjN/oHdjgWymVivGeP4H0dTJ9UO0JZ9fpMtSMzYEq65IKp9hqLi1hXx+9DGS+/XpNFheIKVrGlbfY/IXdr8ifzF8Ro6UcVZwI6zVyMOvNjOpiSB9N6Cnk7g7s0WMIv68co5OITQO4KOAGJNr4E7rgCfcLzJfC4SxdIiSdJQBwLY9CVV3M+WVHnxThc+7SSziyiLEUbzd/JZ7GJzMGJqbnjSrB6oxIA9mT7GhGHaokgGaA+26Fot/55+ThHQIDAQAB"
M.appSecret = "993bb397fa0c9162d44e27fe28f307a9d7299a40bd2047ba1768afc92d00635f"
M.URL = "/rest.php?nsp_fmt=JSON&nsp_svc=huawei.oauth2.user.getTokenInfo"
M.HOST = "https://oauth-api.cloud.huawei.com"

M.RootUrl = "https://orders-drcn.iap.hicloud.com"
M.TokenUrl = "https://oauth-login.cloud.huawei.com"

function M.login_sign(data)
	local tt = sign_util.sort_tbl_by_key(data)
	local base_str = sign_util.sign_table2str(tt)
    local sign = mycrypt.process_signature(base_str, M.prv_key, "SHA256")

    return sign
end

function M.check_resp(t)
	if tonumber(t.rtnCode) == 0 then
		return true, t
	else
		return false, t.rtnCode
	end
end

function M.GetAccountApptouch() 
	local access_token = "CwF2IPcZn/vjpo42GxaAKIJDZ6B2NYx5eyoKZ7DGWV4I481B4A7DSCFVIWGKtBa9TT+LZ5uqlKCgfIrFvP6wI8NUGm5Hu6ZEHjen5hLDMOJZ"
	local open_id = "MDFAMTA1MDU1MTc1QGNlNjY0OGE1Yzc1Y2VkYWJhNmYwNGM1ZjhhZmEzMjRjQGM1YzE5ZDA0MjAyMDgzYjg4YTliaZjEzZDRlY2Q1N2FkY2U3ZGNiaZjM0MGM2NTU4YzcxMjY0ZDMyZTA"
	-- 
	local url1 = "https://openrs-api.cloud.huawei.com.cn/openrs/1.0/router?clientId="..M.appid
	local host = "https://openrs-api.cloud.huawei.com.cn"
	-- local parameter = {clientId=M.app_id}
	-- local status1, results1 = httpc.post(M.HOST, url1, parameter)
    -- if status1 == 200 then

	-- end

	local headers = {
		["Content-Type"] = "application/json;charset=UTF-8",
		["clientId"] = M.appid,
		-- carrierId=600&clientId=xxx
	}
	local  services={"oauth.apptouch","account.apptouch"}
	local body = {
		services = {"oauth.apptouch","account.apptouch"}
	}

	body = cjson.encode(body)

	local rec = {} 

	local status_url, result_url = httpc.request("POST", host, url1, rec,headers, body)
	if status_url == 200 then
		local result
		if result_url then
			result = cjson.decode(result_url)
		end
		-- https://oauth-api-at-dra.platform.dbankcloud.com/rest.php?nsp_fmt=JSON&nsp_svc=huawei.oauth2.user.getTokenInfo
		-- https://oauth-api-at-dra.platform.dbankcloud.com/rest.php?nsp_fmt=JSON&nsp_svc=huawei.oauth2.user.getTokenInfo
		-- 
		local resultCode = result["resultCode"]
		if resultCode == 0 then
			local servicesList = result["services"]
			for key, _service_list in pairs(servicesList) do
				for key, _service in pairs(_service_list) do
					local _token = _service.token
					local _tokeninfo = _service.tokeninfo
					if _tokeninfo then
						local url_x = _tokeninfo .. M.URLEx

						if true then
							local status, results = httpc.post("https://oauth-api.cloud.huawei.com",url_x , {access_token = access_token, open_id = "OPENID"})
							if status == 200 then
								local result
								if results then
									result = cjson.decode(results)
								end
								local result_open_id = result["open_id"]
								if open_id == result_open_id then
									return true
								end
							end
						end
					end
	
				end

			end

		end

	end
end
function M.auth_token(args) 
	local access_token = args.password
	local open_id = args.user
	local status, results = httpc.post(M.HOST, M.URL, {access_token = access_token, open_id = "OPENID"})
	if status == 200 then
		local result
		if results then
			result = cjson.decode(results)
		end
		local result_open_id = result["open_id"]
		if open_id == result_open_id then
			return true
		end
	end

	return false
end

---comment
---@return boolean
---@return any access_token
---@return any expires_in
M.access_token = function ()
	local status, body = httpc.post(M.TokenUrl, "/oauth2/v3/token", {
		grant_type = "client_credentials",
		client_id = M.appid,
		client_secret = M.appSecret
	})
	if status == 200 then
		local ret = cjson.decode(body)
		return true, ret.access_token, ret.expires_in
	else
		return false, body
	end
end

---comment
---@param data any
---@param authorization any
---@return boolean ret nil：重新获取authorization， true：成功 false：失败
M.confirm = function (data, authorization)
	local header = {
		["content-type"] = "application/json; charset=UTF-8",
		["Authorization"] = authorization
	}

	local status, body = httpc.request("POST", M.RootUrl, "/applications/v2/purchases/confirm", nil, header, cjson.encode(data))
	if status == 200 then
		local ret = cjson.decode(body)
		if ret.responseCode == "0" then
			return true
		else
			skynet.loge("huawei_confirm error:", body)
			return false
		end
	else
		skynet.loge("huawei_confirm network error", status, body)
		return nil
	end
end


return M