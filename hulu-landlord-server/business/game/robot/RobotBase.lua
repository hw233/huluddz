local skynet = require "skynet"
local ec = require "eventcenter"
-- local datax = require "datax"
-- local objx    = require "objx"
-- local common = require "common_mothed"

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

local ret = {
    CMD = CMD,
    ServerData = ServerData
}

ServerData.robotId = nil
ServerData.gametype = nil
ServerData.roomtype = nil
ServerData.gameSubType = nil

ServerData.setData = function (robotId, gametype, roomtype, gameSubType)
    ServerData.robotId = robotId
    ServerData.gametype = gametype
    ServerData.roomtype = roomtype
    ServerData.gameSubType = gameSubType
end

ServerData.exitRobot = function (goldWin)
    goldWin = goldWin or 0
    ec.pub{type = "robot_gameover", robotId = ServerData.robotId, goldWin = goldWin}
    skynet.exit()
end


CMD.exitRobot = function (source)
    ServerData.exitRobot()
end

return ret