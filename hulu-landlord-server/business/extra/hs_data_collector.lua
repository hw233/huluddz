local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local cjson = require "cjson"
local collector = require "extra.collector"
local string = string
require "table_util"
local agents = {}

local mode, protocol, mgr = ...
protocol = protocol or "http"
local SERVICE_NAME = "hs_data_collector"
local CMD = {}
function CMD.inject(filePath)
	print("httpserver inject ", filePath)
    require(filePath)
    if mode ~= "agent" then
       for _,agent in pairs(agents) do
            skynet.send(agent, "lua", "inject", filePath)
        end
    end
end


if mode == "agent" then
function CMD.response(id, write, ...)
	local ok, err = httpd.write_response(write, ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end

local SSLCTX_SERVER = nil
local function gen_interface(protocol, fd)
	if protocol == "http" then
		return {
			init = nil,
			close = nil,
			read = sockethelper.readfunc(fd),
			write = sockethelper.writefunc(fd),
		}
	elseif protocol == "https" then
		local tls = require "http.tlshelper"
		if not SSLCTX_SERVER then
			SSLCTX_SERVER = tls.newctx()
			-- gen cert and key
			-- openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout lebinwl.com.key -out lebinwl.com.pem
			local certfile = skynet.getenv("certfile") or "./lebinwl.com.pem"
			local keyfile = skynet.getenv("keyfile") or "./lebinwl.com.key"
			print(certfile, keyfile)
			SSLCTX_SERVER:set_cert(certfile, keyfile)
		end
		local tls_ctx = tls.newtls("server", SSLCTX_SERVER)
		return {
			init = tls.init_responsefunc(fd, tls_ctx),
			close = tls.closefunc(tls_ctx),
			read = tls.readfunc(fd, tls_ctx),
			write = tls.writefunc(fd, tls_ctx),
		}
	else
		error(string.format("Invalid protocol: %s", protocol))
	end
end

function CMD.handle_socket(id)
	print("id=", id)
	socket.start(id)
	print("protocol=", protocol)

	local interface = gen_interface(protocol, id)
	if interface.init then
		interface.init()
	end
	-- limit request body size to 8192 (you can pass nil to unlimit)
	print("start read_request")
	local code, url, method, header, body = httpd.read_request(interface.read, 8192)
	print("code=", code, ";url=", url, ";method=", method, ";body=", body)
	if code then
		if code ~= 200 then
			CMD.response(id, interface.write, code)
		else
			if url == "/api_collector" then
				local events = cjson.decode(body)
				for _, event in ipairs(events) do
					event.receive_time = os.time()
					collector:do_collect(event, mgr)
				end
			else
				skynet.logw("unsupport api request name=", url)
			end
			CMD.response(id, interface.write, code)
		end
	else
		if url == sockethelper.socket_error then
			skynet.error("socket closed")
		else
			skynet.error(url)
		end
	end
	socket.close(id)
	if interface.close then
		interface.close()
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_, _, command, ...)
		print("command=", command)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(...)))
	end)
end)

else

skynet.start(function()
	local mgr = "db_mgr_client"
    local agent_count = 20
	for i = 1, agent_count do
		agents[i] = skynet.newservice(SERVICE_NAME, "agent", "https", mgr)
	end
	local balance = 1
	local port = skynet.getenv("hs_data_collector_port")
	print("hs_data_collector_port=", port)
	local id = socket.listen("0.0.0.0", port)

	skynet.dispatch("lua", function(_, _, command, ...)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(...)))
	end)

	socket.start(id , function(socket_id, addr)
		skynet.logi(string.format("hs_data_collector:[%s] %s connected, pass it to agent :%08x",os.date(),addr, agents[balance]))
		skynet.send(agents[balance], "lua", "handle_socket", socket_id)
		balance = balance + 1
		if balance > #agents then
			balance = 1
		end
	end)
end)

end