local skynet = require "skynet"
-- local uniqueid = require "wind.uniqueid"
local ec = require "eventcenter"

local xy_cmd 				= require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

local room = {}
ServerData.room = room


local function count_real_player(players)
	local n = 0
	for i, p in ipairs(players) do
		if not p.robot then
			n = n + 1
		end
	end
	return n
end

function CMD.create_room(conf, players)
	-- local id = uniqueid.gen("roomid")
	local id =  skynet.call("agent_mgr", "lua", "GetRoomId")
	local addr = skynet.newservice("ddz_room", GameType.GetGameRoomDicPath(conf.gametype))

	skynet.call(addr, "lua", "init", id, conf, players)
	room[id] = {addr = addr, id = id, conf = conf}

	--ec.pub{type = "room_create", id = id, conf = conf, playerNum = count_real_player(players)}
	ec.pub{type = "room_create", id = id, conf = conf, playerNum = conf.max_player}
	return id
end

function CMD.join_room(roomid, p)
	local addr = room[roomid] and room[roomid].addr
	if addr then
		return skynet.call(addr, "lua", "join", p)
	else
		return false
	end
end


function CMD.room_exit(roomid)
	local r = assert(room[roomid])
	ec.pub{type = "room_exit", id = r.id, conf = r.conf}
	room[roomid] = nil
end


CMD.inject = function (filePath)
    require(filePath)
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, cmd, ...)
    	local f = CMD[cmd]
		skynet.ret(skynet.pack(f(...)))
    end)
end)