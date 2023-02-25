local skynet = require "skynet"
local eventx = require "eventx"

local ma_data = require "ma_data"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
--#endregion

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local ma_obj = {
    rewardRecord = nil,
}

ma_obj.loadDatas = function ()
    if not ma_obj.rewardRecord then
        local versionsKey = "2021.11.25 20:19"
        local obj = dbx.get(TableNameArr.UserRoomData, userInfo.id) or {}
        if obj.versionsKey ~= versionsKey then
            obj.versionsKey = versionsKey
    
            obj.id = userInfo.id
            obj.rewardRecord = obj.rewardRecord or {}
    
            dbx.update_add(TableNameArr.UserRoomData, userInfo.id, obj)
        end
        ma_obj.rewardRecord = obj.rewardRecord
    end
end

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.loadDatas()

    eventx.listen(EventxEnum.UserNewDay, function ()
        ma_obj.resetRewardRecord(DateType.Day)
    end)

    eventx.listen(EventxEnum.RoomGameReward, function (gameType, roomLevel, rewardArr)
        skynet.logd("RoomGameReward Start")--临时记录查bug
    end, eventx.EventPriority.Before)

    eventx.listen(EventxEnum.RoomGameReward, function (gameType, roomLevel, rewardArr)
        skynet.logd("RoomGameReward 1")--临时记录查bug
        ma_obj.addRewardRecord(rewardArr, gameType, roomLevel)
        skynet.logd("RoomGameReward 1")--临时记录查bug
    end)

    eventx.listen(EventxEnum.RoomGameReward, function (gameType, roomLevel, rewardArr)
        skynet.logd("RoomGameReward End")
    end, eventx.EventPriority.After)

    
    
end


--#region 核心部分

ma_obj.addRewardRecord = function (itemArr, gameType, roomLevel)
    local datas, updateData = nil, {}
    for index, itemObj in ipairs(itemArr) do
        local itemId, num = tostring(itemObj.id), itemObj.num

        local dateType = tostring(DateType.Day)
        datas = ma_obj.rewardRecord[dateType] or {}
        ma_obj.rewardRecord[dateType] = datas
    
        local id = gameType .. "_" .. roomLevel
        local gameDatas = datas[id] or {}
        datas[id] = gameDatas
        
        gameDatas[itemId] = (gameDatas[itemId] or 0) + num
    
        updateData["rewardRecord." .. dateType .. "." .. id .. "." .. itemId] = gameDatas[itemId]
    end
    dbx.update(TableNameArr.UserRoomData, userInfo.id, updateData)
end

ma_obj.resetRewardRecord = function (dateType)
    dateType = tostring(dateType)
    ma_obj.rewardRecord[dateType] = {}
    dbx.update(TableNameArr.UserRoomData, userInfo.id, {["rewardRecord." .. dateType] = ma_obj.rewardRecord[dateType]})
end

ma_obj.getRewardNum = function (itemId, gameType, roomLevel)
    local dateType = DateType.Day
    local datas = ma_obj.rewardRecord[tostring(dateType)]

    local id = gameType .. "_" .. roomLevel
    local gameDatas = datas and datas[id] or nil

    return gameDatas and gameDatas[tostring(itemId)] or 0
end

--#endregion


return ma_obj