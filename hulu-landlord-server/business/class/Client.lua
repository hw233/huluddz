--单元测试 TestLogin

package.cpath = "luaclib/?.so"

local socket = require "client.socket"
local websocket = require "http.websocket"
local crypt = require "client.crypt"
local cjson = require "cjson"
-- local sproto = require "sproto"
-- local proto = (require "protos.xycard_proto")

if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

function string.split(str, delimiter)
    if str==nil or str=='' or delimiter==nil then
        return nil
    end
    
    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
            table.insert(result, match)
    end
    return result
end

local function _dump(t)  
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => ".."{")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print("{")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end

local function dump( ... )
	local tbls = {...}
	for _,t in ipairs(tbls) do
		_dump(t)
	end
end


return function (ip, login_port, game_port, openid, transform)
	local cacheSessions = {}
	local CMD = {}

	local session = 0
	local my_id = 0
	local last = ""
	local text = "echo"
	local index = 0
	local fd, host, request


	local function writeline(fd, text)
		socket.send(fd, text .. "\n")
	end

	local function unpack_line(text)
		local from = text:find("\n", 1, true)
		if from then
			return text:sub(1, from-1), text:sub(from+1)
		end
		return nil, text
	end

	local function unpack_f(f)
		local function try_recv(fd, last)
			local result
			result, last = f(last)
			if result then
				return result, last
			end
			local r = socket.recv(fd)
			if not r then
				return nil, last
			end
			
			
			if r == "" then
				error "Server closed"
			end
			-- r = r .. "\n"
			return f(last .. r)
		end

		return function()
			while true do
				local result
				result, last = try_recv(fd, last)
				if result then
					return result
				end
				socket.usleep(100)
			end
		end
	end


	local function encode_token(token)
		return cjson.encode {
			user = token.user,
			server = token.server,
			password = token.pass,
			version = token.ver,
			os = "pc",
			channel = "test"
		}
	end


	local function recv_response(v)
		local size = #v - 5
		local content, ok, session = string.unpack("c"..tostring(size).."B>I4", v)
		return ok ~=0 , content, session
	end

	local function unpack_package(text)
		local size = #text
		if size < 2 then
			return nil, text
		end
		local s = text:byte(1) * 256 + text:byte(2)
		if size < s+2 then
			return nil, text
		end

		return text:sub(3,2+s), text:sub(3+s)
	end

	local readpackage = unpack_f(unpack_package)

	local function send_package(fd, pack)
		local package = string.pack(">s2", pack)
		socket.send(fd, package)
	end


	local function recv_package(last)
		if not fd then return end
		local result
		result, last = unpack_package(last)
		if result then
			return result, last
		end
		local r = socket.recv(fd)
		if not r then
			return nil, last
		end

		if r == "" then
			error "Server closed"
		end
		return unpack_package(last .. r)
	end


	local function send_request(name, args)
		session = session + 1
		local v = request(name, args, session)
		local size = #v --+ 4
		local package = string.pack(">I2", size)..v--..string.pack(">I4", session)
		-- cacheSessions[session] = name
		-- print("send ================= ", package)
		socket.send(fd, package)
	end

	local function print_request(name, args)
		if name == "heartbeat" then
			send_request("heartbeat")
		else 
			dump("Server Push: " .. tostring(name), args)
		end
	end

	local function print_response(session, args)

		local name = cacheSessions[session]
		if name == "heartbeat" then
		else
			dump("Server Response: " .. tostring(name), args)
		end
	end

	local function print_package(t, ...)
		if t == "REQUEST" then
			local name = ...
			if name ~= 'byebye' then
				-- send_request("send_session")
			end
			print_request(...)
		else
			assert(t == "RESPONSE")
			print_response(...)
		end
	end

	local connected = false

	function dispatch_package()
		while true do
			local v
			v, last = recv_package(last)
			if not v then
				break
			else
				-- print("vvvvvvvvvvvvvvvvvvvvvvv", v, last)
			end
			if not connected then
				if v == "200 OK" then
					connected = true
					-- send_request("send_session")
					-- send_request("send_session")
					-- send_request("send_session")
				else
					print(v)
				end
			else
				-- local session = string.unpack(">I4", v, -4)
				-- v = v:sub(1,-5)

				print_package(host:dispatch(v))
			end
			
		end
	end

	local function connect(openid)
		index = index + 1
		fd = assert(socket.connect(ip, login_port))
		last = ""

		local readline = unpack_f(unpack_line)
			
		local challenge = crypt.base64decode(readline())
		local clientkey = crypt.randomkey()
		writeline(fd, crypt.base64encode(crypt.dhexchange(clientkey)))
		local secret = crypt.dhsecret(crypt.base64decode(readline()), clientkey)
		local hmac = crypt.hmac64(challenge, secret)
		writeline(fd, crypt.base64encode(hmac))
		local token = {
			server = "xyserver_asmj",
			user = openid,
			pass = "123",
			ver  = 'nbbb',
		}

		local etoken = crypt.desencode(secret, encode_token(token))
		local b = crypt.base64encode(etoken)
		writeline(fd, crypt.base64encode(etoken))

		local result = readline()
		local code = tonumber(string.sub(result, 1, 3))
		assert(code == 200)
		socket.close(fd)
		local subid = crypt.base64decode(string.sub(result, 5))

		fd = assert(socket.connect(ip, game_port))

		local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid), index)
		local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)
		send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))
	end


	--------------------------------------------------------------------------
	-- start
	--------------------------------------------------------------------------
	-- host = sprotoloader.load(2):host "package"
	-- request = host:attach(sprotoloader.load(1))
	-- host = sproto.new(proto.s2c):host "package"
	-- request = host:attach(sproto.new(proto.c2s))
	connect(openid)

	-- socket.usleep(1000)


	-- while true do
	-- 	dispatch_package()
	-- 	local cmd = string.split(socket.readstdin(), " ")
	-- 	if cmd then
	-- 		local name, args = transform(table.unpack(cmd))
	-- 		send_request(name, args or {})
	-- 	else
	-- 		socket.usleep(1000)
	-- 	end
	-- end

end