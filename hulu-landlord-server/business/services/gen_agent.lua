local skynet = require "skynet"
local CMD = {}
local msgagent_pre_load = {}


function  CMD.get_a_agent(...)
    if #msgagent_pre_load > 0 then
        local ret = msgagent_pre_load[1]
        table.remove(msgagent_pre_load)
        return ret
    end
    
    return skynet.newservice("msgagent",...)
end


local function pre_load()
    for i = 1, 200 do
        table.insert(msgagent_pre_load, skynet.newservice("msgagent"))
    end
end

skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    skynet.dispatch("lua", function(session, source, command, ...)
        local args = { ... }
        if command == "lua" then
            command = args[1]
            table.remove(args, 1)
        end
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(table.unpack(args))))
    end)
    -- pre_load()
end)





