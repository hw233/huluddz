local skynet = require "skynet"
local datax = require "datax"
local ec = require "eventcenter"

local xy_cmd 				= require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

--[[
	gameInfoArr = {
		[1] = {
			{id = 1, num = 100, playerNum = 3},
			{id = 2, num = 200, playerNum = 4},
		},
		[2] = {
		}
	}
]]
local gameInfoArr = {}
local roomNum = {}

ServerData.gameInfoArr = gameInfoArr
ServerData.roomNum = roomNum

ServerData.init = function ()
	for gameType, arr in pairs(datax.roomGroup) do
		gameInfoArr[gameType] = {}
		for roomLevel, sData in pairs(arr) do
			gameInfoArr[gameType][roomLevel] = {
				id = sData.id,
				gameType = gameType,
				roomLevel = roomLevel,
				num = 0,
				playerNum = 0,
			}
		end
	end

	ec.sub({type = "room_create"}, function (e)
		local room = gameInfoArr[e.conf.gametype][e.conf.roomtype]
		room.num = room.num + 1
		room.playerNum = room.playerNum + e.playerNum
		roomNum[e.id] = e.playerNum
	end)

	ec.sub({type = "room_exit"}, function (e)
		local room = gameInfoArr[e.conf.gametype][e.conf.roomtype]
		room.num = room.num - 1
		room.playerNum = room.playerNum - (roomNum[e.id] or 0)
		roomNum[e.id] = nil
	end)
end


function CMD.GetDatas()
	return gameInfoArr
end

function CMD.GetData(gametype)
	return gameInfoArr[gametype]
end


CMD.inject = function (filePath)
    require(filePath)
end

skynet.start(function ()
    skynet.dispatch("lua", function(_,_, cmd, ...)
    	local f = CMD[cmd]
		skynet.ret(skynet.pack(f(...)))
    end)
    ServerData.init()
end)