local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local websocket = require "websocket.server"
local snax = require "skynet.snax"
local crypt = require "skynet.crypt"
local httpc = require "http.httpc"
local cjson = require "cjson"
local table = table
local string = string
local assert = assert


local gateways = {
	'127.0.0.1:8001',
	'127.0.0.1:8002',
}

--[[

Protocol:

	line (\n) based text protocol

	1. Server->Client : base64(8bytes random challenge)
	2. Client->Server : base64(8bytes handshake client key)
	3. Server: Gen a 8bytes handshake server key
	4. Server->Client : base64(DH-Exchange(server key))
	5. Server/Client secret := DH-Secret(client key/server key)
	6. Client->Server : base64(HMAC(challenge, secret))
	7. Client->Server : DES(secret, base64(token))
	8. Server : call auth_handler(token) -> server, uid (A user defined method)
	9. Server : call login_handler(server, uid, secret) ->subid (A user defined method)
	10. Server->Client : 200 base64(subid)

Error Code:
	400 Bad Request . challenge failed
	401 Unauthorized . unauthorized by auth_handler
	403 Forbidden . login_handler failed
	406 Not Acceptable . already in login (disallow multi login)

Success:
	200 base64(subid)
]]

local socket_error = {}
local function assert_socket(service, v, fd)
	if v then
		return v
	else
		skynet.error(string.format("%s failed: socket (fd = %d) closed", service, fd))
		error(socket_error)
	end
end

local function write(service, fd, text)
	-- assert_socket(service, websocket.write(fd, text), fd)
	-- print("write",text)
	websocket.write(fd, text)
end

local function launch_slave(auth_handler,command_handler)
	local function auth(fd, addr, etoken)
		-- local challenge = crypt.randomkey()
		-- write("auth", fd, crypt.base64encode(challenge))
		-- local secret = challenge
		-- local etoken = assert_socket("auth", websocket.read(fd),fd)

		local host = skynet.getenv("login_server_addr")  --"127.0.0.1:6001"
		local url = "/"
		local recvheader = {}
		local header = {["Content-Type"] = "application/json"}
		local body = {cmd="auth",args={token=etoken,addr=addr}}
		table.print(body)
		body = cjson.encode(body)
		-- print(body)
		local ok, resp_body = httpc.request("POST", host, url, recvheader, header, body)
		if ok ~= 200 then
			return false
		end
		print("wsloginserver",ok,resp_body)
		assert(resp_body)
		resp_body = cjson.decode(resp_body)
		-- print(resp_body.server, resp_body.openid, resp_body.utoken, resp_body.id, resp_body.sdk)
		return ok == 200, resp_body.server, resp_body.openid, secret, resp_body.utoken, resp_body.id, resp_body.sdk
	end

	local function ret_pack(ok, err, ...)
		if ok then
			return skynet.pack(err, ...)
		else
			if err == socket_error then
				return skynet.pack(nil, "socket error")
			else
				return skynet.pack(false, err)
			end
		end
	end

	local function auth_fd(fd,protocol,addr,etoken)
		-- skynet.error(string.format("connect from %s (fd = %d)", addr, fd))
		-- websocket.start(fd,protocol,addr)	-- may raise error here
		local msg, len = ret_pack(pcall(auth, fd, addr, etoken))
		-- websocket.abandon(fd)	-- never raise error here
		return msg, len
	end


	skynet.dispatch("lua", function(_,source,command, ...)
		if type(command) == "string" then 
			local args = { ... }
	        if command == "lua" then
	            command = args[1]
	            table.remove(args, 1)
	        end
	        skynet.ret(skynet.pack(command_handler(command, table.unpack(args))))
        else
        	local ok, msg, len = pcall(auth_fd,command,...)
			if ok then
				skynet.ret(msg,len)
			else
				skynet.ret(skynet.pack(false, msg))
			end
        end

		

	end)
end

local user_login = {}

local function accept(conf, s, fd, protocol, addr)

	skynet.error(string.format("connect from %s (fd = %d)", addr, fd))	
	websocket.start(fd,protocol,addr)
	local challenge = crypt.randomkey()
	skynet.error("crypt-wsloginserver-137",challenge)
	write("auth", fd, crypt.base64encode(challenge))
	local secret = challenge
	local etoken = assert_socket("auth", websocket.read(fd),fd)

	-- call slave auth
	local ok, server, uid, secret, token, id,sdk = skynet.call(s, "lua",  fd, protocol, addr,etoken)

	print("accept",ok, server, uid, secret, token, id,sdk)
	-- slave will accept(start) fd, so we can write to fd later

	-- websocket.restart(fd,protocol,addr)

	if not ok then
		if ok ~= nil then
			write("response 401", fd, "401 Unauthorized")
		end
		error(server)
	end
	if not conf.multilogin then
		if user_login[uid] then
			write("response 406", fd, "406 Not Acceptable")
			error(string.format("User %s is already login", uid))
		end

		user_login[uid] = true
	end
	local ok, err = pcall(conf.login_handler, server, uid, secret, addr, token, id,sdk)
	-- unlock login
	user_login[uid] = nil
	if ok then
		err = err or ""
		id = tonumber(id) -- or string.byte(id:sub(#id, #id)) -- 游客沒有分配 ID
		local ipAddr = "wsagent_ip" .. (math.floor(id%(skynet.getenv("wsagent_num"))) + 1)
		local ipPort = skynet.getenv("start_wsgate_port") + get_user_gate_index(id)
		ipAddr = skynet.getenv(ipAddr)
		skynet.error("crypt-wsloginserver-174",err .. " " .. uid .. " " .. ipAddr .. " " .. ipPort)
		write("response 200", fd,  "200 "..crypt.base64encode(err .. " " .. uid .. " " .. ipAddr .. " " .. ipPort))
	else
		write("response 403", fd,  "403 Forbidden")
		error(err)
	end
end

local function launch_master(conf)
	local instance = conf.instance or 8
	assert(instance > 0)
	local host = conf.host or "0.0.0.0"
	local port = assert(tonumber(conf.port))
	local slave = {}
	local balance = 1

	skynet.dispatch("lua", function(_,source,command, ...)
		local args = { ... }
        if command == "lua" then
            command = args[1]
            table.remove(args, 1)
        end

		skynet.ret(skynet.pack(conf.command_handler(command, table.unpack(args))))

	end)
	for i=1,instance do
		table.insert(slave, skynet.newservice(SERVICE_NAME,conf.port,conf.protocol,conf.loginpath))
	end

	skynet.error(string.format("login server listen at : %s %d", host, port))
	local id = socket.listen(host, port)
	local protocol = conf.protocol or "ws"
	socket.start(id , function(fd, addr)
		local s = slave[balance]
		balance = balance + 1
		if balance > #slave then
			balance = 1
		end
		local ok, err = pcall(accept, conf, s, fd, protocol, addr)
		if not ok then
			if err ~= socket_error then
				skynet.error(string.format("invalid client (fd = %d) error = %s", fd, err))
			end
		end
		websocket.close(fd)	
	end)
end

local function login(conf)
	local name = "." .. (conf.name or "wslogin")
	skynet.start(function()
		
		local loginmaster = skynet.localname(name)
		if loginmaster then
			local auth_handler = assert(conf.auth_handler)
			local command_handler = assert(conf.command_handler)
			launch_master = nil
			conf = nil
			skynet.call(loginmaster, 'lua', 'launch_logind', skynet.self())
			launch_slave(auth_handler,command_handler)
		else
			launch_slave = nil
			conf.auth_handler = nil
			assert(conf.login_handler)
			assert(conf.command_handler)
			skynet.register(name)
			launch_master(conf)
		end
	end)
end

return login
