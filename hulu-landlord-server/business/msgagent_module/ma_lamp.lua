local skynet = require "skynet"
local ma_data = require "ma_data"
local timer = require "timer"
local COLL = require "config/collections"
local cmd =  {}
local request = {}
local M = {}

local function notice(lamp)
    ma_data.send_push(
    'server_notice',
    {what = lamp.msg,num = (lamp.num or 1),atOnce = (lamp.atOnce or false),
        effects = (lamp.effects or 0), currLive = (lamp.currLive or 1)})
end

function M:send_lamps()
    table.sort(self.lamps, function(lamp_1, lamp_2)
        return lamp_1.currLive < lamp_2.currLive
    end)
    for _, lamp in ipairs(self.lamps) do
        notice(lamp)
    end
end

local function init()
    local now = os.time()
    M.lamps = skynet.call(get_db_mgr(), "lua", "find_all", 
    COLL.LAMP, {beginTime = {["$lt"] = now}, endTime = {["$gt"] = now}, give_up = 0}) or {}
    table.print("lamps =>", M.lamps)
    timer.create(10, function()
        M:send_lamps()
    end, 1)
end

function M.init(REQUEST, CMD)
    print('===================初始化走马灯信息============================')
    if request then
        table.connect(REQUEST, request)
    end
    if cmd then
        table.connect(CMD, cmd)
    end
    init()
end

ma_data.ma_lamp = M
return M