local skynet = require "skynet"

local ma_data = require "ma_data"
local ma_useritem = require "ma_useritem"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local eventx = require "eventx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
local matchserver = false
--#endregion

local me

local request, cmd = {}, {}

local userInfo = ma_data.userInfo

local ma_obj = {}

function ma_obj.init(REQUEST,CMD)
    if request then
        table.connect(REQUEST,request)
    end
    if cmd then
        table.connect(CMD,cmd)
    end

end

-------room request  注册 room 对局消息

-- local function request_room(f, name, args)
--     if me.room then
--         local ok, result = pcall(f, me.room, "lua", "PlayerRequest", me.id, name, args)
--         if ok then
--             return result
--         else
--             skynet.error("request_room error:", name, result)
--         end
--     else
--         skynet.error("invalid request, not in room", name)
--     end
-- end

-- local REQ_ROOM = {
--     "room_info", "card_recorder",
--     "ready", "cancel_ready", "leave",
--     "mute", "check_bottom_card",
--     "ssw_room_info", "ssw_card_recorder"
-- }

-- local SEND_ROOM = {
--     "game_report",
--     "trusteeship", "cancel_trusteeship",
--     "GameChat",
--     "showcard", "call_landlord", "rob_landlord", "overlord_rob_landlord", "double", "double_cap", "playcard",
--     "ssw_takecard", "ssw_playcard", "ssw_hu", "ssw_giveup", "ssw_exit","ssw_praise"
-- }

-- for _,name in ipairs(REQ_ROOM) do
--     request[name] = function (self)
--         return request_room(skynet.call, name, self)
--     end
-- end


-- for _,name in ipairs(SEND_ROOM) do
--     request[name] = function (self)
--         request_room(skynet.send, name, self)
--     end
-- end


---测试方法 读取固定对局数据
--modify by qc 2021.9.17 读取最近的对局记录。以最近一次对局为准。兼容 七雀牌+经典斗地主
function request:get_game_record()
    local record_qqp = skynet.call("db_mgr_rec", "lua", "day_rec_find_all", TableNameArr.RECORD_7, {pid = ma_data.my_id},nil,{end_time = -1},1)
    local record_classic = skynet.call("db_mgr_rec", "lua", "day_rec_find_all", TableNameArr.RECORD_DDZ, {pid = ma_data.my_id},nil,{end_time = -1},1)
    
    assert(record_qqp or record_classic,"record is nil!!?")
    -- assert(#record_qqp>0 ,"record len error?")
    -- assert(#record_classic>0 ,"record len error?")

    local end_time_qqp = #record_qqp>0 and record_qqp[1].end_time or  0
    local end_time_classic = #record_classic>0 and record_classic[1].end_time or  0
    local ret_record = end_time_qqp > end_time_classic and record_qqp[1] or record_classic[1]
    -- print("get_game_record find 1 ",record[1].end_time)
    return {game_recod = ret_record.content}
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------


return ma_obj