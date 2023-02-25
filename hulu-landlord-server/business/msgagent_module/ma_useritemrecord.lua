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
    datas = nil,
}

ma_obj.loadDatas = function ()
    if not ma_obj.datas then
        local obj = dbx.get(TableNameArr.UserItemRecord, userInfo.id)
        if not obj then
            obj = {
                id = userInfo.id,
                dataTable = {},
            }
            dbx.add(TableNameArr.UserItemRecord, obj)
        end
        ma_obj.datas = obj.dataTable
    end
end


function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.loadDatas()

    eventx.listen(EventxEnum.UserItemUpdate, function (itemId, sData, nowNum, oldNum, changeVal)
        if changeVal <= 0 then
            return
        end
        if itemId == ItemID.RuneExp then
            ma_obj.add(itemId, changeVal)
        end
    end)

    eventx.listen(EventxEnum.UserNewDay, function ()
        ma_obj.reset(DateType.Day)
    end)

    eventx.listen(EventxEnum.UserNewWeek, function ()
        ma_obj.reset(DateType.Week)
    end)

    eventx.listen(EventxEnum.UserNewMonth, function ()
        ma_obj.reset(DateType.Month)
    end)

end


--#region 核心部分

ma_obj.add = function (itemId, num)
    itemId = tostring(itemId)

    local datas, updateData = nil, {}
    for key, dateType in pairs(DateType) do
        dateType = tostring(dateType)
        datas = ma_obj.datas[dateType] or {}
        datas[itemId] = (datas[itemId] or 0) + num

        ma_obj.datas[dateType] = datas
        updateData["dataTable." .. dateType .. "." .. itemId] = datas[itemId]
    end
    dbx.update(TableNameArr.UserItemRecord, userInfo.id, updateData)
end

ma_obj.reset = function (dateType)
    dateType = tostring(dateType)
    ma_obj.datas[dateType] = {}
    dbx.update(TableNameArr.UserItemRecord, userInfo.id, {["dataTable." .. dateType] = ma_obj.datas[dateType]})
end

ma_obj.getNum = function (itemId, dateType)
    if not dateType then
        dateType = DateType.Forever
    end

    local datas = ma_obj.datas[tostring(dateType)]
    return datas and datas[tostring(itemId)] or 0
end

--#endregion


return ma_obj