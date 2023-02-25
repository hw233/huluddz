local skynet = require "skynet"
local Room = require "game.ddz.Room"
local timer = require "timer"
local cs = (require "skynet.queue")()

do
	local timer_create = timer.create

	function timer.create(delay, func, iteration, on_end)
		local function lock(f)
			return function (...)
				local args = {...}
				cs(function ()
					f(table.unpack(args))
				end)
			end
		end
		return timer_create(delay, lock(func), iteration, lock(on_end))
	end
end

local room
local command = {}


function command.init(id, conf, players)
	room = Room:new():init(id, conf, players)
end


function command.PlayerRequest(pid, name, args)
	local p = assert(room:find_player(pid))
	local f = p[name]
	local ok, res = pcall(f, p, args)
	if ok then
		return res
	else
		skynet.error("invalid request,", res)
		return {err = SYSTEM_ERROR.argument}
	end
end

return function (cmd, ...)
	local args = {...}
	local f = assert(command[cmd], cmd)

	return cs(function ()
		return f(table.unpack(args))
	end)
end