local skynet = require "skynet"
local gateserver = require "websocket.wsgateserver"
local netpack = require "skynet.netpack"
local crypt = require "skynet.crypt"
local websocket = require "http.websocket"
local httpc = require "http.httpc"
local cjson = require "cjson"
local assert = assert
local b64encode = crypt.base64encode
local b64decode = crypt.base64decode

--[[

Protocol:

	All the number type is big-endian

	Shakehands (The first package)

	Client -> Server :

	base64(uid)@base64(server)#base64(subid):index:base64(hmac)

	Server -> Client

	XXX ErrorCode
		405 Forbidden
		404 User Not Found
		403 Index Expired
		401 Unauthorized
		400 Bad Request
		200 OK

	Req-Resp

	Client -> Server : Request
		word size (Not include self)
		string content (size-4)
		dword session

	Server -> Client : Response
		word size (Not include self)
		string content (size-5)
		byte ok (1 is ok, 0 is error)
		dword session

API:
	server.userid(username)
		return uid, subid, server

	server.username(uid, subid, server)
		return username

	server.login(username, secret)
		update user secret

	server.logout(username)
		user logout

	server.ip(username)
		return ip when connection establish, or nil

	server.start(conf)
		start server

Supported skynet command:
	kick username (may used by loginserver)
	login username secret  (used by loginserver)
	logout username (used by agent)

Config for server.start:
	conf.expired_number : the number of the response message cached after sending out (default is 128)
	conf.login_handler(uid, secret) -> subid : the function when a new user login, alloc a subid for it. (may call by login server)
	conf.logout_handler(uid, subid) : the functon when a user logout. (may call by agent)
	conf.kick_handler(uid, subid) : the functon when a user logout. (may call by login server)
	conf.request_handler(username, session, msg) : the function when recv a new request.
	conf.register_handler(servername) : call when gate open
	conf.disconnect_handler(username) : call when a connection disconnect (afk)
]]

local server = {}

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	--pack = skynet.pack
}

local user_online = {}
local handshake = {}
local connection = {}

function server.userid(username)
	-- base64(uid)@base64(server)#base64(subid)
	local uid, servername, subid = username:match "([^@]*)@([^#]*)#(.*)"
	skynet.error("crypt-wsmsgserver-96",uid,subid,servername)
	return b64decode(uid), b64decode(subid), b64decode(servername)
end

function server.username(uid, subid, servername)
	skynet.error("crypt-wsmsgserver-100",uid,servername,tostring(subid))
	return string.format("%s@%s#%s", b64encode(uid), b64encode(servername), b64encode(tostring(subid)))
end

function server.logout(username)
	local u = user_online[username]
	user_online[username] = nil

	local fd = u.fd
	if fd then
		gateserver.closeclient(fd)
		connection[fd] = nil
	end
end

function server.login(username, secret)
	print("server.login")
	assert(user_online[username] == nil)
	user_online[username] = {
		secret = secret,
		version = 0,
		index = 0,
		username = username,
		response = {},	-- response cache
	}
end

function server.ip(username)
	local u = user_online[username]
	if u and u.fd then
		return u.ip
	end
end

function server.start(conf)
	local expired_number = conf.expired_number or 128

	local handler = {}

	local CMD = {
		login = assert(conf.login_handler),
		logout = assert(conf.logout_handler),
		kick = assert(conf.kick_handler),
		send_push = assert(conf.send_push_handler)
	}

	function handler.command(cmd, source, ...)
		local f = assert(CMD[cmd])
		return f(...)
	end

	function handler.open(source, gateconf)
		local servername = assert(gateconf.servername)
		return conf.register_handler(servername)
	end

	function handler.connect(fd, addr)
		handshake[fd] = addr
		-- gateserver.openclient(fd)
	end

	function handler.disconnect(fd)
		handshake[fd] = nil
		local c = connection[fd]
		if c then
			c.fd = nil
			connection[fd] = nil
			if conf.disconnect_handler then
				conf.disconnect_handler(c.username)
			end
		end
	end

	handler.error = handler.disconnect

	-- atomic , no yield
	local function do_auth(fd, message, addr)
		-- local username, index, hmac = string.match(message, "([^:]*):([^:]*):([^:]*)")

		local username, index, hmac = string.match(message, "([^:]*):([^:]*)")

		local u = user_online[username]
		if u == nil then
			return "404 User Not Found"
		end
		local idx = assert(tonumber(index))
		-- hmac = b64decode(hmac)

		if idx <= u.version then
			return "403 Index Expired"
		end
		local text = string.format("%s:%s", username, index)
		-- local v = crypt.hmac_hash(u.secret, text)	-- equivalent to crypt.hmac64(crypt.hashkey(text), u.secret)
		-- if v ~= hmac then
		-- 	return "401 Unauthorized"
		-- end
		print("这里创建了agent")
		local ok,forbidTime = conf.create_msgagent_handler(username, fd)

		if ok and type(forbidTime) == "number" then
			return "Fail|" .. tostring(forbidTime)
		end
		u.version = idx
		u.fd = fd
		u.ip = addr
		connection[fd] = u
	end
	-- local _temp_openid = {
	-- 	[1] = "nil",
	-- 	[2] = "nil",
	-- 	[3] = "?js602",
	-- }
	-- local _temp_count = 0
	local function auth(fd, addr, msg)
		-- local init_handler = assert(conf.init_handler)
		
		--认证服
		local host = skynet.getenv("login_server_addr")  --"127.0.0.1:6001"
		local url = "/"
		local recvheader = {}
		local header = {["Content-Type"] = "application/json"}
		local body = {cmd="auth",args={token=msg,addr=addr}}
		print("untourist", skynet.getenv("untourist"))
		skynet.error("crypt-wsmsgserver-217",msg)
		local info = cjson.decode(crypt.base64decode(msg))
		table.print(info)
		--[[
			--微端登录
			{
				[model] => "test"
				[pass] => "123"
				[user] => "olwFQxL2yCnkLphcO5itG0oXUmoc"
				[version] => "1.12.22042301"
				[access_token] => "59_CIxO0QsODAkPgvaKaR3kfudLgBnNeYAQimKwCZOGASHQXkybUlzCNdpQQZt0bKr3xF4kbcVNb_Z5uDDximBVDmAVIN7E_0JVIbD-oaXfv1w"
				[os] => "pc"
				[server] => "xyserver_asmj"
				[channel] => "wd"
				[ver] => "nbbb"
			}
		]]
		local flag = string.sub(info.user,1,1)
		if not info.sdk and not (flag == '@' or flag == '?') then
			print("untourist1")
			websocket.write(fd, "403")
			--有问题前端自动会断开
			gateserver.closeclient(fd)
			return;
		end 

		if skynet.getenv("untourist") == "true" then
			print("untourist2")
			if flag == '@' or flag == '?' then
				print("untourist3",info.user)
				local playerExist = skynet.call(".db_mgr","lua","is_player_exist",info.user)
				if not playerExist then
					print("untourist4")
					websocket.write(fd, "402")
					--有问题前端自动会断开
					gateserver.closeclient(fd)
					return;
				end
			end
		end

		print("wsmsgserver auth",host,url)
		-- table.print(body)
		body = cjson.encode(body)
		-- print(body)
		local ok, resp_body = skynet.call("httpclient", "lua", "post", host, url, recvheader, header, body)--httpc.request("POST", host, url, recvheader, header, body)
		-- if ok ~= 200 then
		-- 	return false
		-- end
		skynet.error(ok,resp_body)

		


		-- print(resp_body.server, resp_body.openid, resp_body.utoken, resp_body.id, resp_body.sdk)
		-- return ok == 200, resp_body.server, resp_body.openid, secret, resp_body.utoken, resp_body.id, resp_body.sdk
		if ok == 200 then
			websocket.write(fd, "200 OK")
			resp_body = cjson.decode(resp_body)
			pcall(conf.kick_handler,resp_body.id)
			pcall(conf.login_handler,resp_body.id,addr)
			local u = user_online[resp_body.id]
			-- _temp_count = _temp_count + 1
			-- resp_body.openid = _temp_openid[_temp_count]--这里是测试代码，重连三次后登录成功
			local ok = conf.create_msgagent_handler(resp_body.id, resp_body.openid, fd, resp_body.session_key, info)
			if not ok then
				--如果创建agent失败，或者调用login失败，玩家将永远无法正常登录，
				--复现方法，修改openid为错误数据即可
				websocket.write(fd, "401")
				gateserver.closeclient(fd)
				conf.logout_handler(resp_body.id)
				skynet.error("创建agent失败，error",resp_body.id, resp_body.openid)
				return
			end
			u.version = idx
			u.fd = fd
			u.ip = addr
			connection[fd] = u
			
		else
			print("write 401");
			websocket.write(fd, "401")
			--有问题前端自动会断开
			gateserver.closeclient(fd)
		end

		-- local ok, result = pcall(do_auth, fd, msg, addr)
		-- if not ok then
		-- 	skynet.error(result)
		-- 	result = "400 Bad Request"
		-- end
		
		-- local close = result ~= nil

		-- if result == nil then
		-- 	result = "200 OK"
		-- end
	
		-- websocket.write(fd, result)

		-- if close then
		-- 	gateserver.closeclient(fd)
		-- end
	end

	local request_handler = assert(conf.request_handler)

	-- u.response is a struct { return_fd , response, version, index }
	local function retire_response(u)
		if u.index >= expired_number * 2 then
			local max = 0
			local response = u.response
			for k,p in pairs(response) do
				if p[1] == nil then
					-- request complete, check expired
					if p[4] < expired_number then
						response[k] = nil
					else
						p[4] = p[4] - expired_number
						if p[4] > max then
							max = p[4]
						end
					end
				end
			end
			u.index = max + 1
		end
	end

	local function do_request(fd, message)
		local u = assert(connection[fd], "invalid fd")

		pcall(conf.request_handler, u.username, message)
	end
	


	local function request(fd, msg, sz)
		local message = netpack.tostring(msg, #msg)
		message = msg
		local ok, err = pcall(do_request, fd, message)
		-- local ok, err = pcall(do_request, fd, msg)
		-- not atomic, may yield
		if not ok then
			-- skynet.error(string.format("Invalid package %s : %s", err, msg))
			skynet.error(string.format("Invalid package %s : %s", err, message))
			if connection[fd] then
				gateserver.closeclient(fd)
			end
		end
	end

	function handler.message(fd, msg)

		local addr = handshake[fd]
		if addr then
			auth(fd,addr,msg)
			handshake[fd] = nil
		else
			request(fd, msg, sz)
		end
	end

	return gateserver.start(handler)
end

return server
