local skynet = require "skynet"
local datax  = require "datax"

local ma_data = require "ma_data"
local ma_useritem = require "ma_useritem"
local ma_useractivity = require "activity.ma_useractivity"

local objx = require "objx"
local arrayx = require "arrayx"
local eventx = require "eventx"
local timex = require "timex"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
--#endregion

local REQUEST_New = {}
local CMD = {}

local userInfo = ma_data.userInfo

local act_cfg = {
    actTimeDic = {},
    actList = {}
}

local ma_obj = {

}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.load()
    eventx.listen(EventxEnum.UserNewDay, function ()
        ma_obj.load()
    end)
end

function ma_obj.load()
    -- local list = {}
    -- for _, _cfg_data in pairs(datax.activity) do
    --     list[_cfg_data.id] = _cfg_data
    -- end
    -- act_cfg.actList = {}
    -- act_cfg.actList = list
end

function ma_obj.CheckTimeInRange(start_time, end_time)
    if not start_time or not end_time then
        return false
    end
    local current_time = os.time()
    return current_time >= start_time and current_time <= end_time
end

function ma_obj.IsOpen(act_id)
    local actTimeCfg = ma_obj.actTimeDic[act_id]
    if not actTimeCfg then
        return false
    end
    return ma_obj.CheckTimeInRange(actTimeCfg.start_time, actTimeCfg.end_time)
end

function ma_obj.GetActTime(act_id)
    local actTimeCfg = ma_obj.actTimeDic[act_id]
    if not actTimeCfg then
        return 0
    end
    return actTimeCfg.start_time
end

function ma_obj.GetValidTaskGroup()
    local groupList = {}
    local index = 1
    for key, act_cfg in pairs(act_cfg.actList) do
        if ma_obj.IsOpen(act_cfg.id) then
            groupList[index] = act_cfg.task_group
            index = index + 1
        end
    end
    return groupList
end

function ma_obj.IsOpenByTaskGroup(task_group)
    for key, act_cfg in pairs(act_cfg.actList) do
        if act_cfg.task_group == task_group and ma_obj.IsOpen(act_cfg.id) then
            return true
        end
    end
    return false
end

function ma_obj.GetActOpenTimeByTaskGroup(task_group)
    for key, act_cfg in pairs(act_cfg.actList) do
        if act_cfg.task_group == task_group then
            return ma_obj.GetActTime(act_cfg.id)
        end
    end
    return 0
end

function ma_obj.GetActIdByTaskGroupId(task_group)
    for key, act_cfg in pairs(act_cfg.actList) do
        if act_cfg.task_group == task_group then
            return act_cfg.id
        end
    end
    return 0
end

-- function ma_obj.GetActIdList()
--     return act_cfg.actList
-- end

return ma_obj