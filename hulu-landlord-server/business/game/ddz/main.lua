local skynet = require "skynet"
local roomObj = require "game.ddz.Room"
local timer = require "timer"
local cs = (require "skynet.queue")()

local CMD = {}

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


CMD.init = function (id, conf, players)
	roomObj.init(id, conf, players)
end

CMD.PlayerRequest = function (id, name, args)
	local ok, result = pcall(roomObj.playerRequest, id, name, args)
	if not ok then
		skynet.loge("Room PlayerRequest error!", id, name, result)
		result = RET_VAL.ERROR_3
	end
	return result
end

return function (cmd, ...)
	local args = {...}
	local func = assert(CMD[cmd], cmd)

	return cs(function ()
		return func(table.unpack(args))
	end)
end