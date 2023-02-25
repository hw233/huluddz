local skynet = require "skynet"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local M = {}
local common_event_index    = 1000000000
local error_event_index     = 2000000000
M.events = {
    ["common_event_begin"]  = common_event_index,
    ["click_button"]        = common_event_index + 1,
    ["error_event_begin"]   = error_event_index,
}

function M:map(label)
    return self.events[label]
end

function M:do_collect(event, mgr)
    local id = self:map(event.label)
    if id then
        event.id = id
        event.label = nil
        local numid = math.floor(event.numid)
        event.numid = tostring(numid)
        print("id=", id, ";mgr=", mgr)
        skynet.send(mgr, "lua", "write_record", TableNameArr.CHANNEL_DATA, event)
        return true
    end
    skynet.logw("throw event label=", event.label)
    return false
end

return M