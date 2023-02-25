--消息订阅服务
local skynet = require "skynet"


local subscriber = {}
local command = {}


local function match(event, pattern)
    for k,v in pairs(pattern) do
        if event[k] ~= v then
            return false
        end
    end
    return true
end


function command.SUB(source, id, pattern)
	subscriber[source..id] = {source = source, id = id, pattern = pattern}
end

function command.UNSUB(source, id)
	subscriber[source..id] = nil
end

function command.PUB(source, event)
	for _,u in pairs(subscriber) do
		if match(event, u.pattern) then
			local ok = pcall(skynet.send, u.source, 'WIND_EVENT', u.id, event)
			if not ok then
				command.UNSUB(u.source, u.id)
			end
		end
	end
end

skynet.register_protocol {
    name = "WIND_EVENT",
    id = 255,
    pack = skynet.pack
}


skynet.start(function ()
    skynet.dispatch("lua", function(_,source, cmd, ...)
        local f = command[cmd]
        if session == 0 then
            f(source, ...)
        else
            skynet.ret(skynet.pack(f(source, ...)))
        end
    end)
end)