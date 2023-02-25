--单元测试 TestLogin + sproto + ddz玩法

package.cpath = "luaclib/?.so"
package.path = "../business/sproto/?.lua;lualib/?.lua;../business/?.lua;../business/utils/?.lua;"

local sc = require "util/qique/small_type_c"

local socket = require "client.socket"
local crypt = require "client.crypt"
local cjson = require "cjson"

local proto = require "proto"
local sproto = require "sproto"
require "lfs"
require "lua_utils"
require "table_util"

--初始化服务器选择
local SERVER =2
local LOGIN_IP = "8.136.209.81"
local LOGIN_PORT = "15001"
local GATE_PORT = "15011"

if SERVER == 3 then
	LOGIN_IP = "1.15.31.185"
	LOGIN_PORT = "15001"
	GATE_PORT = "15011"
elseif SERVER == 2 then
	LOGIN_IP = "8.133.185.84"
	LOGIN_PORT = "16001"
	GATE_PORT = "16011"
elseif SERVER == 4 then
	LOGIN_IP = "1.15.31.185"
	LOGIN_PORT = "16001"
	GATE_PORT = "16011"
end


--初始化sproto 描述文件
--读取s2c协议写入
local function writeFile(path, str)
    local f = assert(io.open(path, 'w'))
    f:write(str)
    f:close()
end

-- writeFile("../business/bin/proto_c2s",proto.c2s)
-- writeFile("../business/bin/proto_s2c",proto.s2c)


local host = sproto.new(proto.s2c):host "package"
local request = host:attach(sproto.new(proto.c2s))

if _VERSION ~= "Lua 5.4" then
	error "Use lua 5.4"
end
print("connect logind")

local fd 

---------临时变量------------
local text = "echo"
local index = 1

local idStr ,uidStr,subIdStr

local CHECK_TIME = 0.05
local DISCONNECT_TIME = 5
local HEART_BEAT_INTERVAL = 5

local curObj
local fd
local logined
local connectingToMs
local connected
local unpack_func
local session
local cacheSessions
local last
local curServerIP, curServerPort
local curRetryTime

local serverVersion
local versionChecked

local challenge, secret, result
local clientkey
local subid
local token

local reconnect

local local_appVersion
local need_download_scriptBundle, need_downlaod_resBundle
local target_scriptVersion, target_resVersion

local cur_push_index
local data_send_buff

local white_list = {['get_server_time'] = true} -- 不阻塞的协议

-- 重连尝试次数
local tryReconnectTimes


------------socket方法----------------
--socket 按行读写---
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

local last = ""

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
			-- print("Server closed")
			error "Server closed"
		end
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

local readline = unpack_f(unpack_line)

local token = {
	server = "xyserver_dev",
	pass = "123",
	ver  = "nbbb",
	channel = "hlddz_test",
	os = "pc",
	user = "?qc123"
}


function str_split(str, delimiter)
    if str==nil or str=='' or delimiter==nil then
        return nil
    end
    
    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
            table.insert(result, match)
    end
    return result
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


--2字节大端包体 登录gameserver用
local function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	socket.send(fd, package)
end





---第一次登录
----- connect to loginServer
local function login()	

	--连接login端口
	fd = assert(socket.connect(LOGIN_IP, LOGIN_PORT))

	if not challenge then
		-- 1. Server->Client : base64(8bytes random challenge)
		local t = readline()	
		challenge = crypt.base64decode(t)
		print("readline challenge...  ",challenge)
		clientkey = crypt.randomkey()
		-- 2. Client->Server : base64(8bytes handshake client key)
		writeline(fd, crypt.base64encode(crypt.dhexchange(clientkey)))
	end	

	if not secret then
		-- 4. Server->Client : base64(DH-Exchange(server key))
		local serverkey = readline()
		print("serverkey .. " ,serverkey)
		-- 5. Server/Client secret := DH-Secret(client key/server key)
		secret = crypt.dhsecret(crypt.base64decode(serverkey), clientkey)

		-- 6. Client->Server : base64(HMAC(challenge, secret))
		local hmac = crypt.hmac64(challenge, secret)
		writeline(fd, crypt.base64encode(hmac))		

	end

	-- 7. Client->Server : DES(secret, base64(token))
	local baseJson = cjson.encode(token)
	print("baseJson is ", baseJson)
	local etoken = crypt.desencode(secret, baseJson)
	writeline(fd, crypt.base64encode(etoken))

	-- 10. Server->Client : 200 base64(subid)
	print("readline ...  ")
	local result = readline()
	print(result)
	-- 服务端返回字符串 "200 MTEgP3FjMTIz" 
	-- 提取前部code 200 返回有效
	local code = tonumber(string.sub(result, 3, 5))
	print("code " .. code)
	assert(code == 200)
	socket.close(fd)

	uidStr = token.user
	subIdStr = crypt.base64decode(string.sub(result, 7))

	print("login ok, subid=", subIdStr)
	
	idStr = str_split(subid, " ")
	-- uidStr = idStr[2]

	print("uidStr "..uidStr)
	print("subIdStr "..subIdStr)

end


---第二次登录
----- connect to game server
local function login2Gate()
	print("connect gated")
	
	--连接game端口
	fd = assert(socket.connect(LOGIN_IP, GATE_PORT))
	last = ""
	
	local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(uidStr), crypt.base64encode(token.server),crypt.base64encode(subIdStr) , index)
	local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)
	
	print("send gated "..handshake)
	
	send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))
	index = index + 1

	print(readpackage())

end

local function reconnect()
	
	--重连
	index = index + 1

	print("connect again")
	fd = assert(socket.connect("127.0.0.1", 15011))
	last = ""

	local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(uidStr), crypt.base64encode(token.server),crypt.base64encode(subIdStr) , index)
	--local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)

	send_package(fd, handshake)

	print(readpackage())

end


---sproto 收发输出 start---------

local function recv_package(last)
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

local session = 0


----注意sproto消息构成方式
local function send_request(name, args)
	session = session + 1
	local v = request(name, args, session)
	local size = #v + 4
	local package = string.pack(">I2", size)..v..string.pack(">I4", session)
	socket.send(fd, package)
	print("Request:", session , name)
	return v, session
end

local last = ""

--本地handler fun列表
local room_recv_fun 
local round_count = 0

local function print_request(name, args)
	print("REQUEST", name)
	--handler对局事件
	if room_recv_fun[name] then
		round_count = round_count + 1
		room_recv_fun[name](args)
	else
		if args then
			for k,v in pairs(args) do
				print(k,v)
			end
		end
	end
	
end

local function print_response(session, args)
	print("RESPONSE", session)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_package(t, ...)
	if t == "REQUEST" then
		print_request(...)
	else
		assert(t == "RESPONSE")
		print_response(...)
	end
end

local function dispatch_package()
	while true do
		local v
		v, last = recv_package(last)
		if not v then
			break
		end

		print_package(host:dispatch(v))
	end
end


----------------------------------------------
--- 对局数据
local cards_hand = {}
local cards_flower = {}
local pool_num = 0
local pool_select = {}
local player_me 
local my_id = "1000001"

local hu_cards ={}

---log 切片
local function printCurrRound()
	print("当前牌桌 :========= round " ,round_count)
	print("手牌:",table.tostr(cards_hand))
	print(sc.PrintCards(cards_hand))
	print("选派区:",table.tostr(pool_select))
	print(sc.PrintCards(pool_select))
	print("牌堆剩余:",pool_num)
	print("胡牌区:",table.tostr(hu_cards))
	print(sc.PrintCards(hu_cards))
	print("花牌区:",table.tostr(cards_flower))
	print(sc.PrintCards(cards_flower))
end

---对局fun
function ssw_gamestart(args)
	pool_select = args.selectional_cards
	pool_num = args.pool_num
	for	_,p in ipairs(args.players) do
		PrintTable(p)
		if p.id == my_id then
			cards_hand = p.cards
			if p.cards_flower then
				cards_flower = p.cards_flower
			end			
		end
	end
	assert(#cards_hand > 0,"ssw_gamestart error! ")
	print("发牌 ssw_gamestart ")	
	printCurrRound()
end

function ssw_gameover(args)	
	print("gameover ssw_gamestart ")	
end

function ssw_p_takecard(args)
	print(args.pid ," 抽到牌 ssw_p_takecard ")
	if args.from_pool then
		pool_num = pool_num - 1		
		pool_num = pool_num - (not args.flowers == nil and #args.flowers or 0)
	else
		--移出选牌区
		for i,v in ipairs(pool_select) do 
			if v == args.card then
				table.remove(pool_select,i)
				break
			end
		end
	end
	if args.pid == my_id then
		table.insert(cards_hand,args.card)
		if args.flowers then
			cards = table.extend(cards_flower,args.flowers)
		end		
		printCurrRound()
	end	
end

function ssw_p_playcard(args)
	print(args.pid ," 打出牌 ssw_p_takecard ",args.card)	
	--加入选派去 顶替
	if #pool_select >=3 then
		table.remove(pool_select,1)
	end
	table.insert(pool_select,args.card)

	if args.pid == my_id then
		for i = 1, #cards_hand do
			if cards_hand[i] == args.card then
				table.remove(cards_hand,i)
				break
			end
		end
		printCurrRound()
	end	
end

function ssw_p_hu(args)
	print(args.pid ," 胡牌 ssw_p_hu ",args.card,args.cardtype)
	if args.pid == my_id then
		for i = 1, #cards_hand do
			if cards_hand[i] == args.card then
				table.remove(cards_hand,i)
				table.insert(hu_cards,args.card)
				break
			end
		end			
		printCurrRound()
	end
end

function ssw_p_giveup(args)
	print(args.pid ," 放弃了 ssw_p_giveup ",args.giveup)
end

function ssw_please_takecard(args)
	if args.pid == my_id then
		print(args.pid ," 请你抽牌 ssw_please_takecard ",args.first)		
		printCurrRound()
	end
end

--注册hanlder
room_recv_fun = {
	ssw_gamestart = ssw_gamestart,
	ssw_gameover = ssw_gameover,
	-- "ssw_p_swapcard" = ssw_p_swapcard,
	ssw_p_takecard = ssw_p_takecard,
	ssw_p_playcard = ssw_p_playcard,
	ssw_p_hu = ssw_p_hu,
	ssw_p_giveup = ssw_p_giveup,
	ssw_please_takecard = ssw_please_takecard
}

local function toboolean(x)
	return x and (x == "true" or x == "on")
end


-------------sproto 收发输出 end---------

---------------------------------------------------------
---Main
---------------------------------------------------------

--登录step1
login()
--登录step2
login2Gate()



--主动断线
-- print("disconnect")
-- socket.close(fd)

--模拟重连
--reconnect()
	
print("login suc ...")

print("start sproto...")

--测试发送sproto消息handshake
--应当返回  Welcome to skynet, I will send heartbeat every 5 sec.
send_request("c2s_handshake")
-- send_request("set", { what = "hello", value = "world" })

local heartbeat_ct =0

while true do
	--读取服务端socket消息
	dispatch_package()
	--读取 客户端键盘输入
	local input_code = socket.readstdin()
	if input_code then
			local inputArray = Split(input_code, " ")
			PrintTable(inputArray)
			local cmd = inputArray[1];
			print("cmd "..cmd)
			if cmd == "quit" then
					send_request("c2s_quit")
			elseif cmd == "get" then
					print("get " .. inputArray[2])
					send_request("c2s_get", { what = inputArray[2] })
			elseif cmd == "set" then
					print(string.format("set key: %s ,value: %s",inputArray[2],inputArray[3]))
					send_request("c2s_set", { what = inputArray[2],value = inputArray[3] })
			elseif cmd =="servertime" then
				print("servertime")
				send_request("c2s_servertime")
			elseif cmd =="userinfo" then
				print("get_user_info ")
				send_request("GetUserInfo")
			elseif cmd == "getgamerec" then
				print("get_game_record : ")
				send_request("get_game_record")
			---托管
			elseif cmd == "trust" then
				print("trusteeship : ")
				send_request("trusteeship")
			elseif cmd == "cancle" then
				print("cancel_trusteeship : ")
				send_request("cancel_trusteeship")	
			-----对局打牌交互
			elseif cmd == "play" then
				print("ssw_playcard : ",inputArray[2])
				send_request("ssw_playcard",{card = tonumber(inputArray[2])})
			elseif cmd == "hu" then
				print("ssw_hu : ")
				send_request("ssw_hu")
			elseif cmd == "take" then
				print("ssw_takecard : ",inputArray[2],inputArray[3])
				send_request("ssw_takecard",{from_pool = inputArray[2] == "true",card = inputArray[3]})
			else
					print("输入cmd 不对 那发送心跳吧")
					send_request("heartbeat")
			end

			-- --客户端 心跳
			if round_count%10 ==0 then
				send_request("heartbeat")
			end
	else
			socket.usleep(100)

			-- --客户端 心跳
			-- heartbeat_ct = heartbeat_ct + 1 
			-- if heartbeat_ct >50 then
			-- 	heartbeat_ct = heartbeat_ct-50
			-- 	send_request("heartbeat")
			-- end
	end	

	
end


--主动关闭socket
print("disconnect")
print("login test over!")
-- socket.close(fd)
