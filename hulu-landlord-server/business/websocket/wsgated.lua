local msgserver = require "websocket.wsmsgserver"
local crypt = require "skynet.crypt"
local skynet = require "skynet"
-- local loginservice = tonumber(...)
local websocket = require "http.websocket"

local server = {}
local users = {}
local username_map = {}
local internal_id = 0
local gen_agent_index = 1
local gen_agent_table = {}
-- 玩家登出后 未回收的agent
local pool = {}
local function get_a_agent( )
	-- if #pool > 0 then
	-- 	return table.remove(pool,1)
	-- else
		-- skynet.fork(function ( )
		-- 	for i=1,100 do
		-- 		local agent = skynet.newservice "msgagent"
		-- 		table.insert(pool, agent)
		-- 	end
		-- end)
		-- return skynet.newservice "msgagent"
	-- end
	local gen_index = gen_agent_index
	gen_agent_index = gen_agent_index + 1
	if gen_agent_index > #gen_agent_table then
		gen_agent_index = 1
	end
	return skynet.call(gen_agent_table[gen_index], "lua", "get_a_agent","websocket")
end

-- login server disallow multi login, so login_handler never be reentry
-- call by login server
function server.login_handler(uid,ip)--, secret, ip, token,sdk)
	-- print("-----------login_handler----------------------------")
	-- skynet.error("login_handler")
	print("login_handler")
	if users[uid] then
		error(string.format("%s is already login", uid))
	end
	-- print("server.login_handler", uid)
	-- print(aa + 1)
	internal_id = internal_id + 1
	local id = internal_id	-- don't use internal_id directly
	local username = uid--msgserver.username(uid, id, servername)

	-- you can use a pool to alloc new agent
	-- print("login_handler1")
	-- local agent = get_a_agent()
	

	-- print("login_handler2", agent)
	local u = {
		username = username,
		-- agent = agent,
		uid = uid,
		subid = id,
		secret = secret,
		token = token,
		sdk   = sdk,
	}
	-- trash subid (no used)
	ip = string.match(ip, "(.+):")
	u.ip = ip

	users[uid] = u

	username_map[username] = u
	print("login_handler1")
	msgserver.login(username, secret)
	print("login_handler2")
	-- print("server.login_handler", uid)
	-- you should return unique subid
	return id
end

function server.send_push_handler(fd, package)
	-- print("send_push_handler",fd)
	return websocket.write(fd, package,"binary")

	-- return websocket.write(fd, package)
end


function server.close_msgserver_handler(uid)
	local u = users[uid]

	if u then
		local username = uid--msgserver.username(uid, subid, servername)
		assert(u.username == username)
		msgserver.close_msgserver(u.username)
		users[uid] = nil
		username_map[u.username] = nil
	end
end

--用户认证(创建用户)
function server.create_msgagent_handler(username, openid, fd, session_key, info)
	-- print("----------create_msgagent_handler-----------------------",username,openid,fd,session_key)
	local u = username_map[username]
	if u.agent then
		--断线重连 todo:
		skynet.send(u.agent, "lua", "set_fd", fd)
		return true
	else
		local ok,agent = pcall(get_a_agent)
		if not ok then
			skynet.error("create agent error",agent)
			return false
		end
		u.agent = agent
		-- print("fd",fd)
		local ok,err = pcall(skynet.call,agent, "lua", "login", openid, u.ip, fd, session_key, info)
		if not ok then
			skynet.error("agent login error",err)
			return false
		end
		return true,err--err是封禁时间
	end
end

-- call by agent
function server.logout_handler(uid)--(uid, subid)
	-- print("-----------logout_handler----------------------------")
	local u = users[uid]
	if u then
		local username = uid--msgserver.username(uid, subid, servername)
		assert(u.username == username)
		msgserver.logout(u.username)
		users[uid] = nil
		username_map[u.username] = nil

		-- cluster.call("logind", loginservice, "lua", "logout",uid, subid)
		-- skynet.call("wslogind", "lua", "logout",uid, subid)
		-- skynet.call(loginservice, "lua", "logout",uid, subid)

		-- if #pool < server_conf.max_client * 0.5 then
		-- 	table.insert(pool, u.agent)
		-- else
		pcall(skynet.call, u.agent, "lua", "exit")
		-- end
	end
end

-- call by login server
function server.kick_handler(uid)--, subid)
	local u = users[uid]
	print("准备杀死旧agent1")
	if u then
		print("准备杀死旧agent2")
		local username = uid--msgserver.username(uid, subid, servername)
		assert(u.username == username)
		-- NOTICE: logout may call skynet.exit, so you should use pcall.

		if not u.agent then
			server.logout_handler(uid, subid)
		end
		pcall(skynet.call, u.agent, "lua", "logout",1)
	else
		-- cluster.call("logind", ".login_master", "lua", "logout",uid, subid)
		-- skynet.call("wslogind", "lua", "logout",uid, subid)
	end
end

-- call by self (when socket disconnect)
function server.disconnect_handler(username)
	-- print("-----------disconnect_handler----------------------------")
	local u = username_map[username]
	if u then
		-- skynet.call(u.agent, "lua", "afk")
		pcall(skynet.call, u.agent, "lua", "afk")
	end
end

function server.init_handler(username, fd)
	local u = username_map[username]
	skynet.call(u.agent, 'lua', 'init', fd)
end

-- call by self (when recv a request from client)
function server.request_handler(username, msg)
	-- print("-----------request_handler----------------------------")
	-- print("request_handler1111111",msg,type(msg))
	local u = username_map[username]
	-- skynet.rawcall(u.agent, "client", "rtest")
	-- print("request_handler22222222",msg,type(msg))
	-- skynet.rawsend(u.agent, "client", "rtest")
	if u then
		skynet.rawsend(u.agent, "client", skynet.pack(msg))--msg)
	end
	-- skynet.send(u.agent,"lua","client_send",msg)
	-- return skynet.tostring(skynet.rawcall(u.agent, "client", msg))
end

-- call by self (when gate open)
function server.register_handler(name)
	local gen_agent_num = math.max(1, math.floor(skynet.getenv("thread") / 2))
	for i = 1, gen_agent_num do
		table.insert(gen_agent_table, skynet.newservice("gen_agent"))
	end

	servername = name
	if skynet.getenv("is_agent_server") then
		-- print("-----------register_handler----------------------------")
		-- cluster.call("logind", ".login_master", "lua", "register_gate", servername, skynet.self())
	end
end

msgserver.start(server)

