local skynet = require "skynet"
local cjson = require "cjson"
local login = require "snax.loginserver"
local loginsdk = require "loginsdk"

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

-- protocol -->  websocket / tcp (默认tcp)
local protocol = ...

require "pub_util"

local istcp = not protocol or protocol == "tcp"

local server = {
	host = "0.0.0.0",
	port = istcp and skynet.getenv("logind_port") or
				skynet.getenv("wslogind_port"),--8001,
	multilogin = false,	-- disallow multilogin
	name = istcp and "login_master" or "wslogin_master",
	protocol = protocol,
	instance = 2,--loginserver数量
}

local loginds = {}


local server_list = {}
local user_online = {}

local function is_tourist_user(openid)
	local flag = string.sub(openid,1,1)
	return flag == '@' or flag == '?'
end

-- 8. Server : call auth_handler(token) -> server, uid (A user defined method)
function server.auth_handler(token, ip)
	ip = ip:match("(.+):(.+)")

	skynet.logd("auth_handler", token)
	local info = cjson.decode(token)

	if is_tourist_user(info.user) then
		info.sdk = "test"
	end

	local openid	= info.user
	local password	= info.password
	local os		= info.os
	local sdk		= info.sdk
	local channel	= info.channel
	assert(os and sdk and channel and openid, "login params assert fail")
	info.ip = ip
	--local user = skynet.call("web_sdk", "lua", "Login", openid, info.sdk, info)
	local user = loginsdk.login(openid, info.sdk, info)
	assert(user)
	skynet.logd("server.auth_handler =>", user.openid, user.id, user.session_key)
	return {
		server 		= info.server,
		openid 		= user.openid,
		pass 		= user.pass,
		uid			= user.id,
		sdk			= info.sdk,
		os			= info.os,
		session_key	= user.session_key,
	}
end

-- 9.1 Server : call login_handler(server, uid, secret) ->subid (A user defined method)
--function server.login_handler(server, uid, secret, addr, pass, id, sdk, osv, session_key)
function server.login_handler(server, openid, param, addr)
	-- print('\n>>>>>>login_handler start:', os.time())
	-- print(string.format("%s@%s is login \n", uid, server))
	-- print("login_handler")
	-- local gameserver = assert(server_list[server], "Unknown server")
	-- only one can login, because disallow multilogin
	-- print("login_handler", server, uid, secret, addr, pass, id)
	-- print(get_user_gate(id))

	local uid = param.uid
	local gate = istcp and get_user_gate(uid) or get_user_wsgate(uid)
	skynet.logd("server login_handler", istcp, uid, gate)
	local last = user_online[openid]
	if last then
		assert(gate)
		skynet.call(gate, "lua", "kick", openid, last.subid)
		-- cluster.call(get_user_cluster(id), gameserver, "lua", "kick", uid, last.subid)
	end
	if user_online[openid] then
		skynet.loge(string.format("user %s is already online", openid))
	end
	-- print("login_handler",get_user_cluster(id))
	local preTime = skynet.now()
	-- local subid = tostring(cluster.call(get_user_cluster(id), gameserver, "lua", "login", uid, secret, addr, pass))
	-- print("login_handler1",get_user_cluster(id), skynet.now() - preTime)
	skynet.logd("gate=", gate, ";openid=", openid , ";secret= ", param.secret,"\n")
	
	--9.2 Server : call login_handler(server, openid, secret) ->subid (A user defined method)
	local subid = tostring(skynet.call(gate, "lua", "login", openid, param, addr))

	user_online[openid] = { address = gate, subid = subid , server = server}

	local ret = {
		subid = subid,
		gateIp = "",
		gatePort = skynet.getenv("gate_port" .. 1),
	}
	ret = cjson.encode(ret)
	skynet.logd(">>>>>>login_handler end:", os.time(), ret)
	return ret
end


function CMD.shutdown( )
	for i,logind in ipairs(loginds) do
		skynet.kill(logind)
	end
	skynet.fork(function ( )
		skynet.sleep(1)
		skynet.error(get_ftime().." Has kill all logind, login_master exit.")
		skynet.exit()
	end)
end

function CMD.launch_logind( logind_agent )
	table.insert(loginds, logind_agent)
end

function CMD.register_gate(server, address)
	server_list[server] = address
end

function CMD.logout(uid, subid)
	local u = user_online[uid]
	if u then
		-- print(string.format("%s@%s is logout", uid, u.server))
		user_online[uid] = nil
	end
end

function CMD.inject(filePath)
    require(filePath)
end

function server.command_handler(command, ...)
	local f = assert(CMD[command])
	return f(...)
end

--loginserver.login
login(server, protocol)
