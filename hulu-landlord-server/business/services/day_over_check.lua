--
-- 隔日刷新客户端logintime
--
local skynet = require "skynet"
local timer = require "timer"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
local timer = require "timer"
local NODE_NAME = skynet.getenv "node_name"
local ref_time = os.time()

------------------test1 专用文件


require "pub_util"
function CMD.inject(filePath)
    require(filePath)
end


function CMD.time_tick_op()
    if not check_same_day(ref_time) then
        ref_time = os.time()
        skynet.fork(function()
            skynet.sleep(3000)
            skynet.send("agent_mgr", "lua", "notice2agent", "update_login_time")
        end)
    end
end

function CMD.time_tick()
    skynet.timeout(100, CMD.time_tick)
    CMD.time_tick_op()
end


skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
    skynet.timeout(100, CMD.time_tick)

end)