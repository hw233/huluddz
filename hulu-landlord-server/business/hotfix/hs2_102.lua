local skynet = require "skynet"
local xy_cmd = require "xy_cmd"
local urllib = require "http.url"
local duoyou_sdk = require "config/duoyou_sdk"

local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data


function CMD.roleinfo(channel,body)
	local ok,data = pcall(urllib.parse_query,body)
	if not ok then
		skynet.error("parse_query error",body)
		return false,{state_code = 400} -- 其他错误
	end

	if channel == "duoyou" then
		if not duoyou_sdk:openapi_sign(data) then
			skynet.error("sign error")
			return false,{state_code = 400} -- 其他错误
		end
	else
		skynet.error("channel not found")
		return false,{state_code = 400} -- 其他错误
	end
	if not data.idfa then
		skynet.error("args error")
		return false,{state_code = 400} -- 其他错误
	end

	local user = skynet.call(get_db_mgr(),"lua","find_one",COLL.USER,{phone_idfa = data.idfa})

	if not user then
		return false,{state_code = 300} -- 角色找不到
	end

	if user.channel ~= "duoyou_ios" then
		skynet.send(get_db_mgr(),"lua","update",COLL.USER,{id = user.id},{channel = "duoyou_ios"})
		local userAgent = skynet.call('agent_mgr','lua','find_player',user.id)
		if userAgent then
			pcall(skynet.call, agent, "lua", "admin_update_channel","duoyou_ios")
		end
	end

	-- 查找背包中的 话费券
	local huafeiquan = 0
	if user.backpack then
		for _,v in ipairs(user.backpack) do
			if v.id == "100009" then
				huafeiquan = v.num
				break
			end
		end
	end

	return true, {
		state_code = 200,
		role_info = {
	        role_id = user.id,
	        server_id = 1,
	        role_name = user.nickname,
	        role_level = 0,
	        role_pay = user.all_fee,
	        role_vip = 0,
	        role_payamount = user.all_fee,
	        role_gold = user.gold + (user.bankgold or 0),
	        role_huafeiquan = huafeiquan,
	        update_time = os.date("%Y-%m-%d %H:%M:%S",user.last_time),
	    },
	    role_data = {
            role_get_key1 = user.dyGameNum or 0,
            time_pay_amount = user.all_fee,
            start_time = data.start_time,
            end_time = data.end_time
        }
	} 
end