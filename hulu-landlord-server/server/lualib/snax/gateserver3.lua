local skynet = require "skynet"
local anysocket = require "anysocket"
local gateserver = {}

local maxclient	-- max client
local listen_socket
local client_number = 0
local CMD = {}
local nodelay = false

local connection = {}

function gateserver.openclient(fd)
	if connection[fd] then
		anysocket.start(fd)
	end
end

function gateserver.closeclient(fd)
	local c = connection[fd]
	if c then
		print("gateserver.closeclient",fd)
		connection[fd] = false
		anysocket.close(fd)
		print("gateserver.closeclient end",fd)
	end
end

function gateserver.start(handler, protocol)
	local MSG = {}
	anysocket.init(protocol)
	assert(handler.message)
	assert(handler.connect)

	function CMD.open( source, conf )
		local address = conf.address or "0.0.0.0"
		local port = assert(conf.port)
		maxclient = conf.maxclient or 1024
		nodelay = conf.nodelay
		skynet.error(string.format("Listen on %s:%d", address, port))
		listen_socket = anysocket.listen(address, port, MSG)
	    print("gateserver start-------------------handler.open : ",handler.open)
	    if handler.open then
			return handler.open(source, conf)
		end
	end

	function CMD.close()
		anysocket.close(listen_socket)
	end

	function MSG.open(fd, msg)
		print("MSG.open ===",fd,msg , client_number , maxclient)
		if client_number >= maxclient then
			anysocket.close(fd)
			return
		end
		if nodelay then
			anysocket.nodelay(fd)
		end

		client_number = client_number + 1
		connection[fd] = true
		handler.connect(fd, msg)
	end

	function MSG.message(fd, msg)
		print("MSG.message ===",fd, msg)
		local sz = #msg
	    if connection[fd] then
			handler.message(fd, msg, sz)
		else
			skynet.error(string.format("Drop message from fd (%d) : %s", fd, msg))
		end
	end

	local function close_fd(fd)
		local c = connection[fd]
		if c ~= nil then
			connection[fd] = nil
			client_number = client_number - 1
		end
	end

	function MSG.close(fd)
		if handler.disconnect then
			handler.disconnect(fd)
		end
		close_fd(fd)
	end

	function MSG.error(fd)
		if handler.error then
			handler.error(fd)
		end
		close_fd(fd)
	end

	skynet.start(function()
		skynet.dispatch("lua", function (_, address, cmd, ...)
			local args = { ... }
	        if cmd == "lua" then
	            cmd = args[1]
	            table.remove(args, 1)
	        end
			local f = CMD[cmd]
			if f then
				skynet.ret(skynet.pack(f(address, table.unpack(args))))
			else
				skynet.ret(skynet.pack(handler.command(cmd, address, table.unpack(args))))
			end
		end)
	end)
end

return gateserver
