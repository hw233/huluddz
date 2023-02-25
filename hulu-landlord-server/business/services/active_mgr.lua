--
-- 千王争霸
--
local skynet = require "skynet"
local timer = require "timer"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
local NODE_NAME = skynet.getenv "node_name"
local COLL = require "config/collections"
local active_info = nil
local active_ret_info = nil
--赛季配置id 100000

function CMD.inject(filePath)
    require(filePath)
end

function CMD.get_active_info()
    return active_ret_info
end

function CMD.update_active_info()
    active_info = skynet.call(get_db_mgr(), "lua", "find_one", COLL.SETTING, {id = "active_info"})
    active_ret_info = {}
    active_info.data = active_info.data or {}
    for id,info in pairs(active_info.data) do
        table.insert(active_ret_info, {id=tonumber(id),st=info.st,et=info.et})
    end
end

function CMD.time_tick()
    skynet.timeout(100, CMD.time_tick)
    CMD.update_active_info()
end

--test
local function test()
    active_info.data["2"] = {st=1590030888,et=1590894888}
    skynet.call(get_db_mgr(), "lua", "update", COLL.SETTING, {id = "active_info"},{data = active_info.data}) 
end

function CMD.init()
    active_info = skynet.call(get_db_mgr(), "lua", "find_one", COLL.SETTING, {id = "active_info"}) 
    print("active_mgr init")
    if not active_info then
        print("active_mgr new ")
        active_info = {}
        active_info.id = "active_info"
        active_info.data = {} --["id"] = {active_info}
        skynet.call(get_db_mgr(), "lua", "insert", COLL.SETTING, active_info) 
    end
    -- test()
    active_ret_info = {}
    for id,info in pairs(active_info.data) do
        table.insert(active_ret_info, {id=tonumber(id),st=info.st,et=info.et})
    end
end



skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
    CMD.init()
    skynet.timeout(100, CMD.time_tick)
end)