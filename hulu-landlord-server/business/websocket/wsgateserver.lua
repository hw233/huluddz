local skynet = require "skynet"
-- local netpack = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"
local websocket = require "http.websocket"
local socket = require "skynet.socket"

local gateserver = {}

local socket_id	-- listen socket
local queue		-- message queue
local maxclient	-- max client
local client_number = 0
-- local CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })
local CMD = {}
local nodelay = false

local connection = {}

function gateserver.openclient(fd)
	-- if connection[fd] then
	-- 	socketdriver.start(fd)
	-- end
end

function gateserver.closeclient(fd)
	local c = connection[fd]
	if c then
		connection[fd] = false
		websocket.close(fd)
	end
end

function gateserver.start(handler)
	local MSG = {}

	assert(handler.message)
	assert(handler.connect)

	function CMD.open( source, conf )
		assert(not socket_id)


		local address = conf.address or "0.0.0.0"
		local port = assert(conf.port)
		local protocol = conf.protocol or "ws"
		maxclient = conf.maxclient or 1024
		nodelay = conf.nodelay
	    socket_id = socket.listen(address, port)
	    skynet.error(string.format("Listen websocket port:%s protocol:%s,maxclient", port, protocol,maxclient))
	    socket.start(socket_id, function(fd, addr)
			local ok,err = pcall(websocket.accept,fd, MSG, protocol, addr)
			if not ok then
				skynet.error(err)
				socket.close(fd)
			end
	        
	    end)
	    if handler.open then
			return handler.open(source, conf)
		end
	end

	function CMD.close()
		socket.close(socket_id)
	end

	function MSG.connect(fd)
		print("ws connect from: " .. tostring(fd))
		if client_number >= maxclient then
			socket.close(fd)
			return
		end
		if nodelay then
			socket.nodelay(fd)
		end

		client_number = client_number + 1
		
		connection[fd] = true
		handler.connect(fd, websocket.addrinfo(fd))
	end

	function MSG.handshake(fd, header, url)
	    local addr = websocket.addrinfo(fd)
	    -- print("ws handshake from: " .. tostring(fd), "url", url, "addr:", addr)
	    -- print("----header-----")
	    -- for k,v in pairs(header) do
	    --     print(k,v)
	    -- end
	    -- print("--------------")
	end

	function MSG.message(fd, msg)
		-- print("ws message from: " .. tostring(fd), msg.."\n")
		local sz = #msg

	    if connection[fd] then
			handler.message(fd, msg, sz)
		else
			skynet.error(string.format("Drop message from fd (%d) : %s", fd, msg))
		end
	end

	function MSG.ping(fd)
	    -- print("ws ping from: " .. tostring(fd) .. "\n")
	end

	function MSG.pong(fd)
	    -- print("ws pong from: " .. tostring(fd))
	end

	local function close_fd(fd)
		local c = connection[fd]
		if c ~= nil then
			connection[fd] = nil
			client_number = client_number - 1
		end
	end

	function MSG.close(fd, code, reason)

		if handler.disconnect then
			handler.disconnect(fd)
		end
		close_fd(fd)

	end

	function MSG.error(fd)
	   
		if handler.error then
			handler.error(fd, msg)
		end
		close_fd(fd)

	end

	function MSG.warning(fd, size)
		if handler.warning then
			handler.warning(fd, size)
		end
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
