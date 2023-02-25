--
-- 处理来自后台的消息
--

local skynet = require "skynet"
local ma_data = require "ma_data"

local cmd = {}
local M = {}

function cmd:admin_have_new_mail()
    ma_data.send_push("have_new_mail")
end

function cmd:admin_update_channel(channel)
    ma_data.db_info.channel = channel
end

function cmd:admin_change_entity(currEntity)
    print('================cmd:admin_change_entity')
    table.print(currEntity)
    ma_data.ma_hall_entity.exchange_entity_over(currEntity)
end

function cmd:admin_set_player_forbid(time, reason,forbidBeginTime,forbidUserid,forbidUserName)
    ma_data.db_info.forbid_time = time
    ma_data.db_info.forbid_reason = reason
    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, {forbid_time = time, forbid_reason = reason,
                                                                            forbidBeginTime = forbidBeginTime,
                                                                            forbidUserid = forbidUserid,
                                                                            forbidUserName = forbidUserName})
    print("set_player_forbid =========", time, reason)
    ma_data.send_push("sync_forbid", {forbid_time = forbid_time,forbid_reason=forbid_reason})
end

--玩家身上添加标记
function cmd:admin_set_player_markNum(markNum)
    ma_data.db_info.markNum = markNum
    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, {markNum = markNum})
    --ma_data.send_push("sync_markNum", {markNum = markNum})
end

function cmd:admin_binding_xixi(result)
    ma_data.db_info.binding_xixi = result
    ma_data.send_push("sync_binding_xixi", {binding_xixi = ma_data.db_info.binding_xixi})
end

function cmd:admin_set_player_invalid_headimg(invalid_headimg)
    ma_data.db_info.invalid_headimg = invalid_headimg
    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, {invalid_headimg = invalid_headimg})
    ma_data.send_push("sync_invalid_headimg", {invalid_headimg = invalid_headimg})
end


function cmd:admin_update_user_diamond(num)
    local add_num = num - ma_data.db_info.diamond
    ma_data.add_diamond(add_num, "admin_update",nil,nil,true)
    return true
end


function cmd:admin_update_user_gold(num)
    local add_num = num - ma_data.db_info.gold
    ma_data.add_gold(add_num, "admin_update",nil,nil,true)
    return true
end

function M.init(REQUEST, CMD)
    if request then
        table.connect(REQUEST, request)
    end
    if cmd then
        table.connect(CMD, cmd)
    end
end

ma_data.ma_admin = M
return M