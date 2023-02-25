local skynet = require "skynet"
local snax = require "skynet.snax"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local httpc = require "http.httpc"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local cjson = require "cjson"
local table = table
local string = string
local cluster = require "skynet.cluster"
local md5 = require "md5"
local timer = require "timer"
-- local duoyou_sdk = require "config/duoyou_sdk"

require "table_util"

local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
ServerData.agent = {}

local mode, httpserver, SERVER_ID = ...

function CMD.inject(filePath)
	print("httpserver inject ", filePath)
    require(filePath)
    if mode ~= "agent" then
    	for _,agent in pairs(ServerData.agent) do
    		skynet.send(agent, "lua", "inject", filePath)
    	end
    end
end


if mode == "agent" then

function CMD.roleinfo(channel,body)
	local ok,data = pcall(urllib.parse_query,body)
	if not ok then
		skynet.error("parse_query error",body)
		return false,{state_code = 400} -- 其他错误
	end

	if channel == "duoyou" then
		skynet.error("channel error : douyou is gone!")
		return false,{state_code = 400} -- 其他错误
		-- if not duoyou_sdk:openapi_sign(data) then
		-- 	skynet.error("sign error")
		-- 	return false,{state_code = 400} -- 其他错误
		-- end
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

function CMD.response(id, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end

function CMD.handle_socket(id)
	socket.start(id)

	-- limit request body size to 8192 (you can pass nil to unlimit)
	local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
	if code then
		if code ~= 200 then
			CMD.response(id, code)
		else
			-- 获取命令
			local _,channel,cmd,body = string.match(url,'/(.+)/(.+)/(.+)%?(.+)')
			local func = CMD[cmd]
			-- _,body = string.match(body,"(.*)%??(.*)")
			
			if not func then
				socket.close(id)
				return
			end

			
			local res,data = func(channel,body)

			if data then
				data = cjson.encode(data)
			end

			if res then
				CMD.response(id,code,data)
			else
				CMD.response(id,code,data)
			end
		end
	else
		if url == sockethelper.socket_error then
			skynet.error("socket closed")
		else
			skynet.error(url)
		end
	end
	socket.close(id)
end

skynet.start(function()

	skynet.dispatch("lua", function(session, source, command, ...)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(...)))
	end)
end)

else

skynet.start(function()

	local httpserver = skynet.self()
	for i= 1, 5 do
		ServerData.agent[i] = skynet.newservice(SERVICE_NAME, "agent", httpserver, i)
	end
	local balance = 1
	local port = skynet.getenv("http_channel_port") or 13016
	local id = socket.listen("127.0.0.1", port)
	skynet.error("Listen http_channel port:" .. port)

	skynet.dispatch("lua", function(session, source, command, ...)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(...)))
	end)

	socket.start(id , function(id, addr)
		skynet.error(string.format("httpserver:[%s] %s connected, pass it to agent :%08x",os.date(),addr, ServerData.agent[balance]))
		skynet.send(ServerData.agent[balance], "lua", "handle_socket", id)
		balance = balance + 1
		if balance > #ServerData.agent then
			balance = 1
		end
	end)
end)

end