local skynet = require "skynet"
local queue = require "skynet.queue"
local timer = require "lualib/timer"

require "config.define"

local gameName = ...
local path = "game.".. gameName ..".room.Game"
local game = require(path)
game = game.new()

local lock = queue()

local old_print = skynet.make_logger(1, 3)
print = function(...)
    local p = game.currentPlayer or {}
    local id = p.id or 0
    local header = string.format("gid = %s;nid = %s;", tostring(game.id), tostring(id))
    old_print(header, ...)
end

skynet.start(function()
    timer.set_lock(lock)
    skynet.dispatch("lua", function(session, source, cmd, ...)

        local args = {...}
        if cmd == 'lua' then
            cmd = table.remove(args, 1)
        end

        lock(function ()
            table.insert(game.cmdList,{cmd = cmd,time = os.date("%H:%M:%S"),args = args})
            game:AutoDissolve(cmd)
            skynet.ret(game:OnExecute(cmd, table.unpack(args)))
        end)
    end)
end)
