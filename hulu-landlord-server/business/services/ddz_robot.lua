local skynet = require "skynet"

local robotId, gametype, roomtype, gameSubType = ...;
gametype = math.tointeger(gametype);
roomtype = math.tointeger(roomtype);

local robot

skynet.start(function()
    robot = (require("game.robot." .. GameType.GetGameRobotDicPath(gametype)))(robotId, gametype, roomtype, gameSubType)

    skynet.dispatch("lua", function(session, source, cmd, ...)
		skynet.ret(skynet.pack(robot(source, cmd, ...)))
    end)
end)