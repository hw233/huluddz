local msgserver = require "snax.msgserver"
local skynet = require "skynet"
local socketdriver = require "skynet.socketdriver"
-- local netpack = require "skynet.netpack"
-- local crypt = require "skynet.crypt"

local server = {}
local users = {}
local username_map = {}
local internal_id = 0
local gen_agent_index = 1
local gen_agent_table = {}
local servername
local protocol = ...

-- 玩家登出后 未回收的agent
local function get_a_agent( )
	local gen_index = gen_agent_index
	gen_agent_index = gen_agent_index + 1
	if gen_agent_index > #gen_agent_table then
		gen_agent_index = 1
	end
	return skynet.call(gen_agent_table[gen_index], "lua", "get_a_agent", protocol)
end

-- login server disallow multi login, so login_handler never be reentry
-- call by login server
-- 9.2 Server : call login_handler(server, uid, secret) ->subid (A user defined method)
--function server.login_handler(uid, secret, ip, token, sdk, osv,session_key)
function server.login_handler(uid, param, ip)
	skynet.logd(string.format("%s login_handler", uid))
	local u = users[uid]
	if u and not u.islogout then
		error(string.format("%s is already login", uid))
	end
	internal_id = internal_id + 1
	local id = internal_id	-- don't use internal_id directly
	local username = msgserver.username(uid, id, servername)
	if not u then
		u = {}
	end
	u.username = username
	u.uid = uid
	u.subid = id
	u.secret = param.secret
	u.token = param.token
	u.sdk = param.sdk
	u.os = param.os
	u.session_key = param.session_key
	u.agent = u.agent
	u.islogout = true

	-- trash subid (no used)
	ip = string.match(ip, "(.+):")
	u.ip = ip

	users[uid] = u
	username_map[username] = u
	msgserver.login(username, param.secret)
	skynet.logd(string.format("%s is login succ! username %s ", uid, username))
	return id
end

function server.send_push_handler(fd, package)
	-- print("send_push_handler",package)
	socketdriver.send(fd, package)
	-- anysocket.send(fd, package, "binary")
	return true
end


function server.close_msgserver_handler(uid, subid)
	--print("-----------close_handler----------------------------")
	local u = users[uid]

	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username)
		msgserver.close_msgserver(u.username)
		users[uid] = nil
		username_map[u.username] = nil
	end
end

--用户认证(创建用户)
function server.create_msgagent_handler(username, fd)
	local u = username_map[username]
	if not u.agent or u.islogout then
		if not u.agent then
			u.agent = get_a_agent()
		end
		u.islogout = false
		return skynet.call(u.agent, "lua", "login", u.uid, {
			subid = u.subid,
			secret = u.secret,
			ip = u.ip,
			token = u.token,
			sdk = u.sdk,
			os = u.os,
			session_key = u.session_key
		}, fd)
	else
		skynet.send(u.agent, "lua", "reconnect", fd)
	end
end

-- call by agent
function server.logout_handler(uid, subid)
	skynet.logd(string.format("logout_handler uid %s, subid %s", uid, subid))
	local u = users[uid]
	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username, "u.username = " .. username)
		msgserver.logout(u.username)
		u.islogout = true
		username_map[u.username] = nil

		--pcall(skynet.call, u.agent, "lua", "exit") -- 这边代理不销毁了，相应的代理销毁时要告诉 gate
	end
	-- 不管 gate 有没有都要向 login 发送
	skynet.call("logind", "lua", "logout", uid, subid)
end

-- call by login server
function server.kick_handler(uid, subid)
	skynet.logd("kick user uid=", uid, ";subid=", subid)
	local u = users[uid]
	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username)
		-- NOTICE: logout may call skynet.exit, so you should use pcall.
		if not u.agent then
			server.logout_handler(uid, subid)
		end
		pcall(skynet.call, u.agent, "lua", "logout")
	else
		skynet.call("logind", "lua", "logout", uid, subid)
	end
end

function server.agentexit_handler(uid, subid, agent)
	skynet.logd("agentexit user uid=", uid, ";subid=", subid)
	local u = users[uid]
	if u then
		if u.agent == agent then
			--u.agent = nil
			users[uid] = nil
		else
			skynet.loge("agentexit error! uid=", uid, ";agent=", agent)
		end
	end
end

-- call by self (when socket disconnect)
function server.disconnect_handler(username)
	local u = username_map[username]
	if u then
		pcall(skynet.call, u.agent, "lua", "afk")
	end
end

function server.init_handler(username, fd)
	print("-----------init_handler----------------------------")
	local u = username_map[username]
	skynet.call(u.agent, 'lua', 'init', fd)
end

-- call by self (when recv a request from client)
function server.request_handler(username, msg)
	-- print("-----------request_handler----------------------------username ",username,msg)
	local u = username_map[username]
	-- print("request_handler  u.agent ",msg,type(msg),u.agent)
	-- return skynet.tostring(skynet.rawcall(u.agent, "client", msg)) -- TODO:太坑了
	skynet.rawsend(u.agent, "client", msg)
end

-- call by self (when gate open)
function server.register_handler(name)
	local gen_agent_num = math.max(1, math.floor(skynet.getenv("thread") / 2))
	for i = 1, gen_agent_num do
		table.insert(gen_agent_table, skynet.newservice("gen_agent"))
	end

	servername = name
end
---gated -> msgserver -> gateserver & msagent
msgserver.start(server, protocol)

