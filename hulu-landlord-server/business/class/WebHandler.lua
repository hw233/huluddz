local skynet = require "skynet"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local socket = require "skynet.socket"
local cjson = require "cjson"


local function HOST(ip)
	if string.find(ip, ':') then
		return string.match(ip, "(.+):(.+)")
	else
		return ip
	end
end

local function response(id, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
	socket.close(id)
end


local function handle_socket(id, handler)

	socket.start(id)
	local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)

	if code then
		if code ~= 200 then
			return response(id, code)
		else
			local ok, data = pcall(cjson.decode, body)

			if not ok then
				skynet.error("http json decode failure \""..tostring(body).."\"")
				return response(id, code,  cjson.encode{ ok = false, err = "json decode failure"})
			end

			if type(data) ~= 'table' then
				return response(id, code, cjson.encode{ ok = false, err = 'invalid request:' .. tostring(data) })
			end

			local cmd, args = data[1], data[2] or {}
			args.ip = HOST(header.host)

			local f = handler[cmd]
			if not f then
				return response(id, code, cjson.encode{ ok = false, err = 'invalid request:' .. tostring(cmd) })
			else
				local ok, r = pcall(f, args)
				if not ok then
					return response(id, code, cjson.encode{ ok = false, err = 'server error:' .. tostring(r) })
				else
					assert(type(r) == 'table', 'you must return a table')
					r.ok = true
					return response(id, code, cjson.encode(r))
				end
			end
		end
	else
		if url == sockethelper.socket_error then
			skynet.error("socket closed")
		else
			skynet.error(url)
		end
	end
end


return function (handler)
	return function (id)
		handle_socket(id, handler)
	end
end