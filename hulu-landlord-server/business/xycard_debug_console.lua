local skynet = require "skynet"
local codecache = require "skynet.codecache"
local core = require "skynet.core"
local socket = require "skynet.socket"
local snax = require "skynet.snax"
local memory = require "skynet.memory"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local cluster = require "skynet.cluster"
local arg = table.pack(...)
assert(arg.n <= 2)
local ip = (arg.n == 2 and arg[1] or "127.0.0.1")
local port = tonumber(arg[arg.n])

local COMMAND = {}
local COMMANDX = {}

local test_clients = {}

local function format_table(t)
	local index = {}
	for k in pairs(t) do
		table.insert(index, k)
	end
	table.sort(index, function(a, b) return tostring(a) < tostring(b) end)
	local result = {}
	for _,v in ipairs(index) do
		table.insert(result, string.format("%s:%s",v,tostring(t[v])))
	end
	return table.concat(result,"\t")
end

function COMMAND.find_room_by_playerid(id)
	-- local agent_mgr = snax.queryservice("agent_mgr")
	
	
	local room_id = skynet.call("agent_mgr", "lua", "find_room_by_playerid", id)
	-- local room_id = cluster.call("agent_mgr", "agent_mgr", "lua", "find_room_by_playerid", id)
	-- local room_id = agent_mgr.req.find_room_by_playerid(id)

	if room_id then
		local S = 'room_id'..room_id
		return S
	else
		return "can't find room"
	end
end

function COMMAND.dissolve_room(id)
	local room = skynet.call("agent_mgr", "lua", "find_room", id)

	if room then
		skynet.send(room, "lua", "compel_dissolve_room")
		return "ok"
	else
		return "can't find room"
	end
end

local function dump_line(print, key, value)
	if type(value) == "table" then
		print(key, format_table(value))
	else
		print(key,tostring(value))
	end
end

local function dump_list(print, list)
	local index = {}
	for k in pairs(list) do
		table.insert(index, k)
	end
	table.sort(index, function(a, b) return tostring(a) < tostring(b) end)
	for _,v in ipairs(index) do
		dump_line(print, v, list[v])
	end
end

local function split_cmdline(cmdline)
	local split = {}
	for i in string.gmatch(cmdline, "%S+") do
		table.insert(split,i)
	end
	return split
end

local function docmd(cmdline, print, fd)
	local split = split_cmdline(cmdline)
	local command = split[1]
	local cmd = COMMAND[command]
	local ok, list
	if cmd then
		ok, list = pcall(cmd, table.unpack(split,2))
	else
		cmd = COMMANDX[command]
		if cmd then
			split.fd = fd
			split[1] = cmdline
			ok, list = pcall(cmd, split)
		else
			print("Invalid command, type help for command list")
		end
	end

	if ok then
		if list then
			if type(list) == "string" then
				print(list)
			else
				dump_list(print, list)
			end
		end
		print("<CMD OK>")
	else
		print(list)
		print("<CMD Error>")
	end
end

local function console_main_loop(stdin, print)
	print("Welcome to skynet console")
	skynet.error(stdin, "connected")
	local ok, err = pcall(function()
		while true do
			local cmdline = socket.readline(stdin, "\n")
			if not cmdline then
				break
			end
			if cmdline:sub(1,4) == "GET " then
				-- http
				local code, url = httpd.read_request(sockethelper.readfunc(stdin, cmdline.. "\n"), 8192)
				local cmdline = url:sub(2):gsub("/"," ")
				docmd(cmdline, print, stdin)
				break
			end
			if cmdline ~= "" then
				docmd(cmdline, print, stdin)
			end
		end
	end)
	if not ok then
		skynet.error(stdin, err)
	end
	skynet.error(stdin, "disconnected")
	socket.close(stdin)
end

skynet.start(function()
	local listen_socket = socket.listen (ip, port)
	skynet.error("Start debug console at " .. ip .. ":" .. port)
	socket.start(listen_socket , function(id, addr)
		local function print(...)
			local t = { ... }
			for k,v in ipairs(t) do
				t[k] = tostring(v)
			end
			socket.write(id, table.concat(t,"\t"))
			socket.write(id, "\n")
		end
		socket.start(id)
		skynet.fork(console_main_loop, id , print)
	end)
end)

function COMMAND.help()
	return {
		help = "This help message",
		list = "List all the service",
		stat = "Dump all stats",
		info = "info address : get service infomation",
		exit = "exit address : kill a lua service",
		kill = "kill address : kill service",
		mem = "mem : show memory status",
		gc = "gc : force every lua service do garbage collect",
		start = "lanuch a new lua service",
		snax = "lanuch a new snax service",
		clearcache = "clear lua code cache",
		service = "List unique service",
		task = "task address : show service task detail",
		inject = "inject address luascript.lua",
		server_inject = "server_inject server_name filename";
		logon = "logon address",
		logoff = "logoff address",
		log = "launch a new lua service with log",
		debug = "debug address : debug a lua service",
		signal = "signal address sig",
		cmem = "Show C memory info",
		shrtbl = "Show shared short string table info",
		ping = "ping address",
		call = "call address ...",
		test = "test cmd for chenhw"
	}
end

function COMMAND.clearcache()
	codecache.clear()
end

function COMMAND.start(...)
	local ok, addr = pcall(skynet.newservice, ...)
	if ok then
		if addr then
			return { [skynet.address(addr)] = ... }
		else
			return "Exit"
		end
	else
		return "Failed"
	end
end

function COMMAND.log(...)
	local ok, addr = pcall(skynet.call, ".launcher", "lua", "LOGLAUNCH", "snlua", ...)
	if ok then
		if addr then
			return { [skynet.address(addr)] = ... }
		else
			return "Failed"
		end
	else
		return "Failed"
	end
end

function COMMAND.snax(...)
	local ok, s = pcall(snax.newservice, ...)
	if ok then
		local addr = s.handle
		return { [skynet.address(addr)] = ... }
	else
		return "Failed"
	end
end

function COMMAND.service()
	return skynet.call("SERVICE", "lua", "LIST")
end

local function adjust_address(address)
	if address:sub(1,1) ~= ":" then
		address = assert(tonumber("0x" .. address), "Need an address") | (skynet.harbor(skynet.self()) << 24)
	end
	return address
end

function COMMAND.list()
	return skynet.call(".launcher", "lua", "LIST")
end

function COMMAND.stat()
	return skynet.call(".launcher", "lua", "STAT")
end

function COMMAND.mem()
	return skynet.call(".launcher", "lua", "MEM")
end

function COMMAND.kill(address)
	return skynet.call(".launcher", "lua", "KILL", address)
end

function COMMAND.test(address, cmd, ...)
	if address then
		address = tonumber(string.sub(address, 2), 16)
	end
	local cmd0, cmd1, cmd2 = string.match(cmd, "(%S-)%.(%S-)%.(%S+)")

	if cmd1 == "accept" then
		cmd1 = "post"
	elseif cmd1 == "response" then
		cmd1 = "req"
	end
	local t = snax.bind(address, cmd0)
	return {result = t.req.forbid_user(...)}
end

function COMMAND.gen_test_client(client_count,room_type)
	client_count = tonumber(client_count)
	if not client_count or client_count <= 0 or not room_type then
		return
	end
	local length = #test_clients
	-- local curLength = 0
	-- local function clientFun()
	-- 	for i = 1, 30 do
	-- 		test_clients[#test_clients + 1] = skynet.newservice("client",i,room_type)
	-- 		curLength = curLength + 1
	-- 		if curLength >= length then
	-- 			break
	-- 		end
	-- 	end
	-- 	skynet.timeout(1,clientFun)
	-- end
	-- skynet.timeout(1,clientFun)
	for i = length + 1,length + client_count  do
		test_clients[i] = skynet.newservice("client",i,room_type)
		-- if i%100 == 0 then
		skynet.sleep(1)
		-- end
	end

end

function COMMAND.close_all_client()
	for _,client in ipairs(test_clients) do
		skynet.send(client,"lua","exit")
	end
end

-- function COMMAND.xytest(cmd, ...)
-- 	-- xytest db_mgr.post.reloadCode
-- 	-- xytest db_mgr.req.make_user_test 575081 0
-- 	-- xytest user_mgr.req.notice_will_down
-- 	local cmd0, cmd1, cmd2 = string.match(cmd, "(%S-)%.(%S-)%.(%S+)")
-- 	print(cmd0, cmd1, cmd2)
-- 	local curService = snax.queryservice(cmd0)
-- 	if cmd1 == "post" then
-- 		curService[cmd1][cmd2](...)
-- 		return {result = "ok"}
-- 	else
-- 		return {result = curService[cmd1][cmd2](...)}
-- 	end
-- end
function COMMAND.xytest(name, cmd, ...)
	local curService = snax.queryservice(name)
	local cmd1, cmd2 = string.match(cmd, "(%S+)%.(%S+)")
	if cmd1 == "accept" then
		cmd1 = "post"
	elseif cmd1 == "response" then
		cmd1 = "req"
	end
	return {curService[cmd1][cmd2](...)}
end

function COMMAND.execute_skynet(name,cmd,...)
	print(name,type(name),cmd)
	return {skynet.call(name,'lua',cmd,...)}
end

function COMMAND.gc()
	return skynet.call(".launcher", "lua", "GC")
end

function COMMAND.exit(address)
	skynet.send(adjust_address(address), "debug", "EXIT")
end

function COMMAND.inject(address, filename)
	-- inject :00000026 xycard_server_dev/inject/inject_msgagent.lua
	address = adjust_address(address)
	local f = io.open(filename, "rb")
	if not f then
		return "Can't open " .. filename
	end
	local source = f:read "*a"
	f:close()
	local ok, output = skynet.call(address, "debug", "RUN", source, filename)
	if ok == false then
		error(output)
	end
	return output
end

function COMMAND.server_inject(serverName, injectFile,injectFuncName)
	injectFuncName = injectFuncName or "inject"
	-- print("server_inject", serverName, injectFile)
	skynet.send(serverName, "lua", injectFuncName, injectFile)
end

function COMMAND.ser_inject_addr(address,injectFile,injectFuncName)
	address = adjust_address(address)
	print("address = ",address,type(address))
	injectFuncName = injectFuncName or "inject"

	skynet.send(address, "lua", injectFuncName, injectFile)
end

function COMMAND.snax_hotfix(snax_name,filename)
	local f = io.open(filename,'rb')
	if not f then
		return "Can't open " .. filename
	end
	local source = f:read "*a"
	f:close()
	local s = snax.queryservice(snax_name)
	snax.hotfix(s,source)
end

function COMMAND.task(address)
	address = adjust_address(address)
	return skynet.call(address,"debug","TASK")
end

function COMMAND.info(address, ...)
	address = adjust_address(address)
	return skynet.call(address,"debug","INFO", ...)
end

function COMMANDX.debug(cmd)
	local address = adjust_address(cmd[2])
	local agent = skynet.newservice "debug_agent"
	local stop
	local term_co = coroutine.running()
	local function forward_cmd()
		repeat
			-- notice :  It's a bad practice to call socket.readline from two threads (this one and console_main_loop), be careful.
			skynet.call(agent, "lua", "ping")	-- detect agent alive, if agent exit, raise error
			local cmdline = socket.readline(cmd.fd, "\n")
			cmdline = cmdline and cmdline:gsub("(.*)\r$", "%1")
			if not cmdline then
				skynet.send(agent, "lua", "cmd", "cont")
				break
			end
			skynet.send(agent, "lua", "cmd", cmdline)
		until stop or cmdline == "cont"
	end
	skynet.fork(function()
		pcall(forward_cmd)
		skynet.wakeup(term_co)
	end)
	local ok, err = skynet.call(agent, "lua", "start", address, cmd.fd)
	stop = true
	-- wait for fork coroutine exit.
	skynet.wait(term_co)

	if not ok then
		error(err)
	end
end

function COMMAND.logon(address)
	address = adjust_address(address)
	core.command("LOGON", skynet.address(address))
end

function COMMAND.logoff(address)
	address = adjust_address(address)
	core.command("LOGOFF", skynet.address(address))
end

function COMMAND.signal(address, sig)
	address = skynet.address(adjust_address(address))
	if sig then
		core.command("SIGNAL", string.format("%s %d",address,sig))
	else
		core.command("SIGNAL", address)
	end
end

function COMMAND.cmem()
	local info = memory.info()
	local tmp = {}
	for k,v in pairs(info) do
		tmp[skynet.address(k)] = v
	end
	tmp.total = memory.total()
	tmp.block = memory.block()

	return tmp
end

function COMMAND.shrtbl()
	local n, total, longest, space = memory.ssinfo()
	return { n = n, total = total, longest = longest, space = space }
end

function COMMAND.ping(address)
	address = adjust_address(address)
	local ti = skynet.now()
	skynet.call(address, "debug", "PING")
	ti = skynet.now() - ti
	return tostring(ti)
end

-- 暂时废弃
-- function COMMANDX.reload_proto()
-- 	skynet.call("xy_protoloader", "lua", "reload")
-- end

function COMMANDX.call(cmd)
	local address = adjust_address(cmd[2])
	local cmdline = assert(cmd[1]:match("%S+%s+%S+%s(.+)") , "need arguments")
	local args_func = assert(load("return " .. cmdline, "debug console", "t", {}), "Invalid arguments")
	local args = table.pack(pcall(args_func))
	if not args[1] then
		error(args[2])
	end
	local rets = table.pack(skynet.call(address, "lua", table.unpack(args, 2, args.n)))
	return rets
end
