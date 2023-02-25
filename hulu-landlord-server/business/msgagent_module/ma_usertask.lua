local skynet = require "skynet"

local ma_data = require "ma_data"
local ma_usertaskrecord = require "ma_usertaskrecord"
local ma_useritem = require "ma_useritem"

local objx = require "objx"
local create_dbx = require "dbx"
local eventx = require "eventx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"
local activity_task = require "activity.ma_activity_task"
local ma_user_txz = require "ma_user_txz"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
local cfg_task = require "cfg.cfg_task"
local cfg_treasure = require "cfg.cfg_task_treasure_chest"

--#endregion

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo
local usertask = nil

local CType = {
    Task = 0,
    Act = 1
}

local ma_obj = {
    dateTypeArr = {},
    dataGroupObj = {},
    dataTypeGroupObj = {},
    treasureTypeGroupArr = {}
}

ma_obj.initCfg = function ()
    for key, sData in pairs(cfg_task) do
        sData.id = tostring(key)
        ma_obj.dateTypeArr[tostring(sData.date_type)] = true

        local group = tostring(sData.task_group)
        local groupArr = ma_obj.dataGroupObj[group]
        if not groupArr then
            groupArr = {}
            ma_obj.dataGroupObj[group] = groupArr
        end
        table.insert(groupArr, sData)

        local typeGroupArr = ma_obj.dataTypeGroupObj[sData.task_type]
        if not typeGroupArr then
            typeGroupArr = {}
            ma_obj.dataTypeGroupObj[sData.task_type] = typeGroupArr
        end
        table.insert(typeGroupArr, sData)

    end
    ma_obj.dateTypeArr = table.keys(ma_obj.dateTypeArr)

    for key, sData in pairs(cfg_treasure) do
        sData.id = key
        sData.idStr = tostring(key)
        local typeGroupArr = ma_obj.treasureTypeGroupArr[sData.task_type]
        if not typeGroupArr then
            typeGroupArr = {}
            ma_obj.treasureTypeGroupArr[sData.task_type] = typeGroupArr
        end
        table.insert(typeGroupArr, sData)
    end

end

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.initCfg()

    local obj = dbx.get(TableNameArr.UserTask, userInfo.id)
    if not obj then
        obj = {
            id = userInfo.id,
            dataTable = {},
        }
        for i, type in ipairs(ma_obj.dateTypeArr) do
            obj.dataTable[type] = {
                count = 0, -- 计次
                record = {},
                state = {},
                treasureObj = {}, -- 这个字段后添加的，所以检查下
                actRecord = {},
            }
        end

        dbx.add(TableNameArr.UserTask, obj)
    else
        for i, type in ipairs(ma_obj.dateTypeArr) do
            local isUpdate = false

            local typeData = obj.dataTable[type]
            if not typeData then
                typeData = {
                    count = 0, -- 计次
                    record = {},
                    state = {},
                    treasureObj = {},
                    actRecord = {},
                }
                obj.dataTable[type] = typeData
                isUpdate = true
            end

            if not typeData.treasureObj then
                typeData.treasureObj = {}
                isUpdate = true
            end

            if not typeData.actRecord then
                typeData.actRecord = {}
                isUpdate = true
            end

            -- --重置已有的活动
            -- for _, _task_group in pairs(activity_task.GetValidTaskGroup()) do
            --     if activity_task.IsOpenByTaskGroup(_task_group) then
            --         if typeData.actRecordCreateAt[_task_group] > 0 and 
            --             typeData.actRecordCreateAt[_task_group] < activity_task.GeActOpenTimeByTaskGroup(_task_group) then
            --             isUpdate = true
            --             for _act_task_group, _ in pairs(typeData.actRecord) do
            --                 if _act_task_group == _task_group then
            --                     typeData.actRecord[_act_task_group] = {}
            --                 end
            --             end
            --             typeData.actRecordCreateAt[_task_group] = os.time()
            --         end
            --     end
            -- end

            if isUpdate then
                dbx.update(TableNameArr.UserTask, userInfo.id, { ["dataTable." .. type] = typeData })
            end
        end
    end
    usertask = obj.dataTable
    ma_usertaskrecord.init()

    eventx.listen(EventxEnum.UserNewDay, function ()
        ma_obj.resetDateTask(DateType.Day)
    end)

    eventx.listen(EventxEnum.UserNewWeek, function ()
        ma_obj.resetDateTask(DateType.Week)
    end)

    eventx.listen(EventxEnum.UserNewMonth, function ()
        ma_obj.resetDateTask(DateType.Month)
    end)

    ---------活动事件，当活动开启的时候触发
    eventx.listen(EventxEnum.ActOpenExent, function (args)
        if not args  then
            return
        end
        --初始化活动任务
        ma_obj.initActData(args.actId)
    end)

    ---------活动事件，当活动关闭的时候触发
    eventx.listen(EventxEnum.ActCloseExent, function (args)
        if not args  then
            return
        end
    end)

    -------测试
    -- ma_obj.initActData(1001)
    -- ma_obj.initActData(1002)
    -- ma_obj.addVal(6, 5)
    -- ma_obj.setVal(6, 3)
    -- ma_obj.getDataArr()
    -- ma_obj.getDataArr(1001)
end

function ma_obj.ActTaskIdListByTaskType(date_type, task_type)
    local taskIdList = {}
    local taskGroupList = {}
    task_type = tostring(task_type)
    for _task_type, _cfg_list in pairs(ma_obj.dataTypeGroupObj) do
        if task_type ==  tostring(_task_type)  then
            for key, _cfg in pairs(_cfg_list) do
                if _cfg.count_type == CType.Act and date_type == tostring(_cfg.date_type) then
                    taskIdList[_cfg.id] = true
                    taskGroupList[_cfg.task_group] = true
                end
            end
        end
    end

    return taskIdList, taskGroupList
end

function ma_obj.initActData(actId)
    if not usertask then
        return
    end

    actId = tostring(actId)
    for date_type, _dataTable in pairs(usertask) do
        if _dataTable then
            local actTaskIdList, taskGroupList = ma_obj.ActTaskIdListByTaskType(date_type, actId)
            if next(actTaskIdList) then
                _dataTable.actRecord[actId] = {}
                for task_group, value in pairs(taskGroupList) do
                    _dataTable.actRecord[actId][tostring(task_group)] = 0
                end

                for _task_id, value in pairs(actTaskIdList) do
                    if _dataTable.state[_task_id] then
                        _dataTable.state[_task_id] = TaskState.Default
                    end
                end
                dbx.update(TableNameArr.UserTask, userInfo.id, { ["dataTable." .. date_type] = _dataTable })
            end
        end
    end
end

--#region 核心部分

---comment
---@param idArr table int[]
ma_obj.syncDataArr = function (idArr)
    local datas = {}
    for index, id in ipairs(idArr) do
        datas[id] = ma_obj.get(id)
    end
    ma_common.send_myclient_sure("SyncUserTask", {datas = datas})
end

---comment
---@param id number
---@param sData table
---@return table
ma_obj.get = function (id, sData)
    if not sData then
        sData = cfg_task[id]
    end
    local ret = nil
    if sData then
        local typeData = usertask[tostring(sData.date_type)]
        if typeData then
            local state = typeData.state[sData.id] or TaskState.Default
            local count_type = sData.count_type
            if count_type == CType.Task then
                local val = typeData.record[tostring(sData.task_group)] or 0
                if val > 0 or state ~= TaskState.Default then
                    ret = {id = sData.id, val = val, state = state}
                end
            elseif count_type == CType.Act then
                local act_id = tostring(sData.task_type)
                local actRecordTable = typeData.actRecord[act_id]
                if actRecordTable then
                    local val =  actRecordTable[tostring(sData.task_group)] or 0
                    if val > 0 or state ~= TaskState.Default then
                        ret = {id = sData.id, val = val, state = state}
                    end
                end
            end
        end
    end
    return ret
end

ma_obj.getDataArr = function (taskType)
    local result, treasureArrRet = {}, {}

    if taskType then
        local arr = ma_obj.dataTypeGroupObj[taskType]
        local treasureArr = ma_obj.treasureTypeGroupArr[taskType]
        if arr then
            for index, sData in ipairs(arr) do
                local typeData = usertask[tostring(sData.date_type)]
                if typeData then
                    local state = typeData.state[sData.id] or TaskState.Default
                    local count_type = sData.count_type
                    if count_type == CType.Task then
                        local val = typeData.record[tostring(sData.task_group)] or 0
                        if val > 0 or state ~= TaskState.Default then
                            result[sData.id] = {id = sData.id, val = val,state = state }
                        end
                    elseif count_type == CType.Act then
                        local act_id = tostring(sData.task_type)
                        local actRecordTable = typeData.actRecord[act_id]
                        if actRecordTable then
                            local val = actRecordTable[tostring(sData.task_group)] or 0
                            if val > 0 or state ~= TaskState.Default then
                                result[sData.id] = {id = sData.id,val = val,state = state}
                            end
                        end
                    end
                end
            end
        end
        if treasureArr then
            for index, sData in ipairs(treasureArr) do
                local typeData = usertask[tostring(sData.date_type)]
                if typeData then
                    local isGet = typeData.treasureObj[sData.idStr]
                    if isGet then
                        table.insert(treasureArrRet, sData.id)
                    end
                end
            end
        end
    else
        for key, typeData in pairs(usertask) do
            for group, val in pairs(typeData.record) do
                local arr = ma_obj.dataGroupObj[group]
                if arr then
                    for index, sData in ipairs(arr) do
                        if sData.count_type == CType.Task then
                            local state = typeData.state[sData.id] or TaskState.Default
                            if val > 0 or state ~= TaskState.Default then
                                result[sData.id] = {id = sData.id,val = val,state = state}
                            end
                        end
                    end
                end
            end

            --获取活动数据
            for _task_type1, actRecordTable in pairs(typeData.actRecord) do
                for _task_group, val in pairs(actRecordTable) do
                    for _task_type2, _task_cfg_list in pairs(ma_obj.dataTypeGroupObj) do
                        if _task_type1 == tostring(_task_type2)then
                            for key, _task_cfg in pairs(_task_cfg_list) do
                                if _task_cfg.count_type == CType.Act  and _task_group == _task_cfg.task_group  then
                                    local state = typeData.state[_task_cfg.id] or TaskState.Default
                                    if val > 0 or state ~= TaskState.Default then
                                        result[_task_cfg.id] = {id = _task_cfg.id,val = val,state = state}
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return result, treasureArrRet
end

ma_obj.getNextTaskID = function (id)
    local sData = cfg_task[id]
    if not sData or sData.next_task == false then
        return nil
    elseif sData.next_task == nil then
        local nextObj = table.first(cfg_task, function (id, sData)
            return sData.parent_task == id
        end)
        if nextObj then
            sData.next_task = tonumber(nextObj.id)
        else
            sData.next_task = false
            return nil
        end
    end
    return sData.next_task
end

-- ma_obj.addTask = function (id)
--     local sData = cfg_task[id]
--     if not sData then
--         return false
--     end

--     local data = usertask[sData.date_type]
--     local state = data.state[id]
--     if not state then
--         state = TaskState.Default
--     end
--     return true
-- end

---comment
---@param dateType any
---@return boolean
ma_obj.resetDateTask = function (dateType)
    local data = usertask[tostring(dateType)]
    if not data then
        return false
    end

    if next(data.record) or next(data.state) then
        data.record = {}
        data.actRecord = {}
        data.state = {}
        data.treasureObj = {}
        dbx.update(TableNameArr.UserTask, userInfo.id, {
            ["dataTable." .. dateType .. ".record"]         = data.record,
            ["dataTable." .. dateType .. ".actRecord"]      = data.actRecord,
            ["dataTable." .. dateType .. ".state"]          = data.state,
            ["dataTable." .. dateType .. ".treasureObj"]    = data.treasureObj,
        })

        if dateType == DateType.Day then
            local itemId = 10008
            ma_useritem.remove(itemId, ma_useritem.num(itemId), "ResetDateTask_重置任务", false)
        elseif dateType == DateType.Week then
            local itemId = 10009
            ma_useritem.remove(itemId, ma_useritem.num(itemId), "ResetDateTask_重置任务", false)
        end
    end

    ma_common.send_myclient("ResetUserTask", {dateType = dateType})

    return true
end

---comment
---@param id number
---@return boolean
ma_obj.resetTask = function (id)
    local sData = cfg_task[id]
    if not sData then
        return false
    end

    local data = usertask[tostring(sData.date_type)]
    if not data then
        return false
    end

    local count_type = sData.count_type
    if count_type == CType.Task then
        local num = data.record[tostring(sData.task_group)] or 0
        local dirty = ma_obj._resetTaskState(sData, data, num)
        if dirty then
            dbx.update(TableNameArr.UserTask, userInfo.id, { ["dataTable." .. sData.date_type .. ".state." .. id] = data.state[id] })
        end
    elseif count_type == CType.Act then
        local act_id = sData.task_type
        local actRecordTable = data.actRecord[act_id]
        if actRecordTable then
            local num = actRecordTable[tostring(sData.task_group)] or 0
            local dirty = ma_obj._resetTaskState(sData, data, num)
            if dirty then
                dbx.update(TableNameArr.UserTask, userInfo.id, { ["dataTable." .. sData.date_type .. ".state." .. id] = data.state[id] })
            end
        end

    end

    return true
end

--- 模块内部使用，检查后只修改内存里的值，没有数据库操作
---@param sData table
---@param data table
---@param num number
---@return boolean
ma_obj._resetTaskState = function (sData, data, num)
    local ret = false
    local oldState = data.state[sData.id] or TaskState.Default

    if num >= sData.targets then
        if oldState ~= TaskState.Finish then
            data.state[sData.id] = TaskState.Finish
            ret = true
        end
    elseif oldState ~= TaskState.Default then
        data.state[sData.id] = TaskState.Default
        ret = true
    end
    return ret
end

--- 模块内部使用，检查后只修改内存里的值，没有数据库操作
---@param group string
---@param dateType number
---@param num number
---@return boolean 返回 true 表示有修改
ma_obj._checkTaskGroupState = function (group, dateType, num)
    local ret = false

    local arr = ma_obj.dataGroupObj[group]
    if not arr then
        return ret
    end

    local syncIdArr = {}

    local data = usertask[tostring(dateType)]
    for index, sData in ipairs(arr) do
        if sData.date_type == dateType then
            
            -- local parent = cfg_task[sData.parent_task]
            -- if not parent or data.state[parent.id] == TaskState.Finish then
            --     local state = data.state[sData.id]
            --     if state == TaskState.Default and num >= sData.targets then
            --         data.state[sData.id] = TaskState.Finish
            --         ret = true
            --     end
            -- end

            local state = data.state[sData.id] or TaskState.Default
            if state == TaskState.Default and num >= sData.targets then
                data.state[sData.id] = TaskState.Finish
                table.insert(syncIdArr, tonumber(sData.id))
                ret = true
            end
        end
    end

    if ret then
        ma_obj.syncDataArr(syncIdArr)
    end

    return ret
end

---comment
---@param group integer
---@param dateType? integer
---@return integer
ma_obj.getVal = function (group, dateType)
    dateType = dateType or DateType.Forever
    local data = usertask[tostring(dateType)]
    return data and (data.record[tostring(group)] or 0) or 0
end

---comment
---@param group string
---@param num number
ma_obj.addVal = function (group, num)
    if num > 0 then
        group = tostring(group)

        local updateData = {}
        for index, dateType in ipairs(ma_obj.dateTypeArr) do
            local data = usertask[dateType]
            if data then
                local nowNum = (data.record[group] or 0) + num
                data.record[group] = nowNum
                local upGroupMap = {}
                for _task_group, _task_cfg_list in pairs(ma_obj.dataGroupObj) do
                    for key, _task_cfg in pairs(_task_cfg_list) do
                        if _task_group == group and _task_cfg.count_type == CType.Act and dateType == tostring(_task_cfg.date_type) then
                            local act_id = tostring(_task_cfg.task_type)
                            local actRecordTable = data.actRecord[act_id] or {}
                            if actRecordTable[group] and not upGroupMap[group]  then
                                upGroupMap[group] = true
                                local actNowNum = (actRecordTable[group] or 0) + num
                                actRecordTable[group] = actNowNum
                                updateData["dataTable." .. dateType .. ".actRecord." .. act_id] = actRecordTable
                            end
                        end 
                    end 
                end
                
                local dirty = ma_obj._checkTaskGroupState(group, tonumber(dateType), nowNum)
                updateData["dataTable." .. dateType .. ".record." .. group] = nowNum
                if dirty then
                    updateData["dataTable." .. dateType .. ".state"] = data.state
                end

                -- local updateData = { ["dataTable." .. dateType .. ".record." .. group] = nowNum }
                -- if dirty then
                --     updateData["dataTable." .. dateType .. ".state"] = data.state
                -- end
                -- dbx.update(TableNameArr.UserTask, userInfo.id, updateData)
            end
        end
        dbx.update(TableNameArr.UserTask, userInfo.id, updateData)
    
        -- 添加后计数类型 后续再处理
    end
end

---comment
---@param group string
---@param num any
ma_obj.setVal = function (group, num)
    group = tostring(group)
    local updateData = {}
    local have_up = false
    for index, dateType in ipairs(ma_obj.dateTypeArr) do
        local data = usertask[dateType]
        if data then
            data.record[group] = num
            updateData["dataTable." .. dateType .. ".record." .. group] = num
            have_up = true

            local upGroupMap = {}
            for _task_group, _task_cfg_list in pairs(ma_obj.dataGroupObj) do
                for key, _task_cfg in pairs(_task_cfg_list) do
                    if _task_group == group and _task_cfg.count_type == CType.Act and dateType == tostring(_task_cfg.date_type) then
                        local act_id = tostring(_task_cfg.task_type)
                        local actRecordTable = data.actRecord[act_id] or {}
                        if actRecordTable[group] and not upGroupMap[group]  then
                            upGroupMap[group] = true
                            actRecordTable[group] = num
                            updateData["dataTable." .. dateType .. ".actRecord." .. act_id] = actRecordTable
                        end 
                    end
                end
            end

            if have_up then
                local dirty = ma_obj._checkTaskGroupState(group, tonumber(dateType), num)
                if dirty then
                    updateData["dataTable." .. dateType .. ".state"] = data.state
                end
            end
            -- local updateData = { ["dataTable." .. dateType .. ".record." .. group] = num }
            -- if dirty then
            --     updateData["dataTable." .. dateType .. ".state"] = data.state
            -- end
            -- dbx.update(TableNameArr.UserTask, userInfo.id, updateData)
        end
    end

    if have_up then
        dbx.update(TableNameArr.UserTask, userInfo.id, updateData)
    end
    -- 添加后计数类型 后续再处理
end

---获取任务奖励
---@param id number
---@return integer 枚举值，不为 RET_VAL.Succeed_1 则表示失败
ma_obj.getItem = function (id, is_show_reward)
    local sData = cfg_task[id]
    if not sData then
        return RET_VAL.ERROR_3
    end

    local data = usertask[tostring(sData.date_type)]
    if not data then
        return RET_VAL.ERROR_3
    end

    local state = data.state[sData.id]
    if state ~= TaskState.Finish then
        return RET_VAL.Lack_6
    end

    local parent = cfg_task[sData.parent_task]
    if parent then
        local parentState = data.state[parent.id]
        if parentState == TaskState.Default then
            return RET_VAL.NotOpen_9
        end
    end

    data.state[sData.id] = TaskState.Get
    dbx.update(TableNameArr.UserTask, userInfo.id, { ["dataTable." .. sData.date_type .. ".state." .. sData.id] = data.state[sData.id] })

    local sendDataArr = {}
    ma_useritem.addList(sData.rewards, 1, "GetTaskItem_" .. sData.task_type .. "_领取任务奖励", sendDataArr)

    --通行证奖励
    if sData.rewards_txz and  next(sData.rewards_txz) then
        if ma_user_txz:LoadAndCheckGameOverEmailAndCheckOpen() then
            --添加通行证奖励
            ma_useritem.addList(sData.rewards_txz, 1, "GetTaskItem_" .. sData.task_type .. "_领取任务奖励_通行证经验奖励", sendDataArr)
        end
    end

    if is_show_reward then
        ma_common.showReward(sendDataArr)
    end

    return RET_VAL.Succeed_1, {id = id}
end

ma_obj.getTreasureItem = function (id)
    local sData = cfg_treasure[id]
    if not sData then
        return RET_VAL.ERROR_3
    end

    if not ma_useritem.has(sData.need_activity, 1, false) then
        return RET_VAL.Lack_6
    end

    --local data = usertask[tostring(sData.task_type)]
    local data = usertask[tostring(sData.date_type)] -- 先改为使用时间类型
    if not data or not data.treasureObj then
        return RET_VAL.ERROR_3
    end

    if data.treasureObj[sData.idStr] then
        return RET_VAL.Exists_4
    end

    data.treasureObj[sData.idStr] = true
    dbx.update(TableNameArr.UserTask, userInfo.id, { ["dataTable." .. sData.date_type .. ".treasureObj." .. id] = true })

    local sendDataArr = {}
    ma_useritem.addList(sData.rewards, 1, "GetTaskTreasureItem_" .. sData.date_type .. "_领取活跃度宝箱", sendDataArr)
    ma_common.showReward(sendDataArr)

    return RET_VAL.Succeed_1, {id = id}
end

--#endregion


REQUEST_New.GetUserTaskDatas = function (args)
    local datas, treasureArr = ma_obj.getDataArr(args.taskType)

    return {taskType = args.taskType, datas = datas, treasureArr = treasureArr }
end

REQUEST_New.GetTaskItem = function (args)
    return ma_obj.getItem(args.id, true)
end

REQUEST_New.GetTaskTreasureItem = function (args)
    return ma_obj.getTreasureItem(args.id)
end


return ma_obj