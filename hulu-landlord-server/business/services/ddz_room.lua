local skynet = require "skynet"

local game = ...
local room = require(string.format("game.%s.main", game))


skynet.error("game room start ================", game)

skynet.start(function()
    skynet.dispatch("lua", function(_,_, cmd, ...)
    	skynet.ret(skynet.pack(room(cmd, ...)))
    end)
end)