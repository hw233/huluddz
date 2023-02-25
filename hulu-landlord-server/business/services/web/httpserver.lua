local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local cjson = require "cjson"
local ec = require "eventcenter"

local objx = require "objx"
require "table_util"

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

ServerData.CMD = {}
ServerData.agentMap = {}
ServerData.port = nil
ServerData.httpModulePath = nil

ServerData.moduleDatas = {}

function CMD.inject(filePath)
	skynet.logd("httpserver inject ", filePath)
    require(filePath)
    if ServerData.port then
		for _, agent in pairs(ServerData.agentMap) do
			skynet.send(agent, "lua", "inject", filePath)
		end
    end
end

ServerData.CMD.init = function (port, httpModulePath)
    ServerData.port = port
    ServerData.httpModulePath = httpModulePath

    if port then
        local mainAddr = skynet.self()
        for i = 1, 5 do
            ServerData.agentMap[i] = skynet.newservice(SERVICE_NAME)
            skynet.call(ServerData.agentMap[i], "lua", "init", nil, httpModulePath, mainAddr, i)
        end
        local balance = 1
        local fd = socket.listen("0.0.0.0", port)
        skynet.logd("Listen web port:" .. port, httpModulePath)
    
        socket.start(fd , function(id, addr)
            skynet.logd(string.format("[%s] %s connected, pass it to agent :%08x", os.date(), addr, ServerData.agentMap[balance]))
            skynet.send(ServerData.agentMap[balance], "lua", "handle_socket", id)
            balance = balance + 1
            if balance > #ServerData.agentMap then
                balance = 1
            end
        end)
    end

    local moduleFunc = require(httpModulePath)
    moduleFunc(CMD, #ServerData.agentMap > 0 and ServerData.agentMap or nil)
end

ServerData.CMD.response = function (id, ...)
    local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        skynet.logd(string.format("fd = %d, %s", id, err))
    end
end

ServerData.CMD.handle_socket = function (id)
    socket.start(id)

    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
    if code then
        if code ~= 200 then
            ServerData.CMD.response(id, code)
        else
            -- local path, query = urllib.parse(url)

            if url ~= '/php.action' and url ~= '/realphp.action' and url ~= '/h5php.action' and url ~= "/game.html"
                or #body == 0 then
                    
                skynet.loge("invalid client from:", url)
                socket.close(id)
                return
            end

            skynet.logd("http handle start: =>", body)
            local json = cjson.decode(body)
            assert(CMD[json.cmd])
            local func = CMD[json.cmd]
            assert(type(json.args) == 'table')

            local rs = func(json.args, header)
            rs = cjson.encode(rs)

            skynet.logd("http handle end: =>", rs)

            ServerData.CMD.response(id, code, rs)
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
    skynet.dispatch("lua", function(_, _, command, ...)
        local func = assert(ServerData.CMD[command] or CMD[command])
        skynet.ret(skynet.pack(func(...)))
    end)
end)