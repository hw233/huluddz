local skynet = require "skynet"

local ma_data = require "ma_data"
local ma_userother = require "ma_userother"
local ma_userhero = require "ma_userhero"

local objx = require "objx"
local arrayx = require "arrayx"
local eventx = require "eventx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
--#endregion

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local ma_obj = {
    datas = nil
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    eventx.listen(EventxEnum.UserHeroAdd, function (sData, uData)
        ma_obj.add(sData.id)
    end)

    eventx.listen(EventxEnum.RoomGameReward, function (gameType, roomLevel, rewardArr)
        skynet.logd("RoomGameReward 3")--临时记录查bug
        for index, itemObj in ipairs(rewardArr) do
            if itemObj.id == ItemID.RuneExp then
                ma_obj.AddExpBook(userInfo.skin, itemObj.num)
            end
        end
        skynet.logd("RoomGameReward 3")--临时记录查bug
    end)

    -- 每周重置
    eventx.listen(EventxEnum.UserNewWeek, function (sData, uData)
        local datas = ma_obj.getDatas()
        for key, data in pairs(datas) do
            data.ljexp_week = 0
        end
        dbx.update(TableNameArr.UserHeroGet, userInfo.id, {["dataTable"] = datas})
    end)

end


--#region 核心部分

ma_obj.getDatas = function ()
    if not ma_obj.datas then
        local obj = dbx.get(TableNameArr.UserHeroGet, userInfo.id)
        if not obj then
            obj = {
                id = userInfo.id,
                dataTable = {},
            }
            ma_obj.datas = obj.dataTable

            for key, uHero in pairs(ma_userhero.getDatas()) do
                ma_obj._add(uHero.sId)
            end

            dbx.add(TableNameArr.UserHeroGet, obj)
        end
        ma_obj.datas = obj.dataTable
    end
    return ma_obj.datas
end

--- 模块内部使用
ma_obj._add = function (id)
    id = tostring(id)

    local data = ma_obj.datas[id]
    if not data then
        data = {
            id = id,
        }
        ma_obj.datas[id] = data

        return true, data
    end
    return false
end

ma_obj.add = function (id)
    local datas = ma_obj.getDatas()
    local isAdd, data = ma_obj._add(id)

    if isAdd then
        dbx.update(TableNameArr.UserHeroGet, userInfo.id, {["dataTable." .. id] = data})
    end
end

--- 通过这个获取指定id英雄是否已获取
---@param id string
---@return table
ma_obj.get = function (id)
    id = tostring(id)

    local datas = ma_obj.getDatas()
    return datas[id]
end

--#endregion

-- 累计经验书num
function ma_obj.GetLJExpBook(id)
    local data = ma_obj.get(id)
    if not data then return 0 end

    return data.ljexp or 0
end

-- 周累计经验书num
function ma_obj.GetLJExpBook_Week(id)
    local data = ma_obj.get(id)
    if not data then return 0 end

    return data.ljexp_week or 0
end


function ma_obj.AddExpBook(id, num)
    local data = ma_obj.get(id)
    if data then
        data.ljexp = data.ljexp or 0
        data.ljexp = data.ljexp + num

        data.ljexp_week = data.ljexp_week or 0
        data.ljexp_week = data.ljexp_week + num
        dbx.update(TableNameArr.UserHeroGet, userInfo.id, {["dataTable." .. id] = data})
    end
end

----------------------------
-- 
REQUEST_New.GetUserHeroDatasExt = function()
    ma_obj.getDatas()
    return RET_VAL.Succeed_1, {datas=ma_obj.datas}
end

REQUEST_New.Test_AddExpBook = function(args)
    local heroid = args.heroid
    local num    = args.num
    ma_obj.AddExpBook(heroid, num)
    return RET_VAL.Succeed_1, {datas=ma_obj.datas}
end


---------------------------

return ma_obj