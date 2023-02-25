local skynet = require "skynet"
local Room = require "game.sevensparrow.Room"


local room
local command = {}


function command.init(id, conf, players)
	room = Room:new():init(id, conf, players)
end


function command.PlayerRequest(id, name, args)
	table.insert(room.actions, {id, name, args})

	local ok, result = pcall(room.playerRequest, room, id, name, args)
	if not ok then
		skynet.loge("Room PlayerRequest error!", id, name, result)
		result = RET_VAL.ERROR_3
	end
	return result
end



return function (cmd, ...)
	local f = assert(command[cmd], cmd)
	return f(...)
end