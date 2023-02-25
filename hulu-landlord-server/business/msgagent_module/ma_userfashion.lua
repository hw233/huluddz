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
    if not ma_obj.rewardRecord then
        local versionsKey = "2021.11.30 16:56"
        local obj = dbx.get(TableNameArr.UserFashion, userInfo.id) or {}
        if obj.versionsKey ~= versionsKey then
            obj.versionsKey = versionsKey
    
            obj.id = userInfo.id
            obj.datas = obj.datas or {}
    
            dbx.update_add(TableNameArr.UserFashion, userInfo.id, obj)
        end
        ma_obj.datas = obj.datas
    end
end

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.loadDatas()
    
end


--#region 核心部分

ma_obj.getDatas = function (_type)
    return ma_obj.datas[tostring(_type)] or {}
end

ma_obj.get = function (_type, id)
    local datas = ma_obj.datas[tostring(_type)]
    return datas and datas[tonumber(id)] or nil
end

ma_obj.syncData = function (data)
    ma_common.send_myclient("SyncUserFashion", {data = data})
end

ma_obj.add = function (_type, id)
    _type = tostring(_type)
    local typeData = ma_obj.datas[_type]
    if not typeData then
        typeData = {type = tonumber(_type), datas = {}}
        ma_obj.datas[_type] = typeData
    end

    id = tostring(id)
    local data = typeData.datas[id]
    if not data then
        data = {id = tonumber(id), type = tonumber(_type), endDt = nil}
        typeData.datas[id] = data

        dbx.update(TableNameArr.UserFashion, userInfo.id, {["datas." .. _type .. ".datas." .. id] = data})

        ma_obj.syncData(data)
    end
end


--#endregion

REQUEST_New.GetUserFashionDatas = function (args)
    local _type = args.type
    local datas

    if _type then
        datas = {ma_obj.datas[tostring(_type)]}
    else
        datas = ma_obj.datas
    end
    return {type = _type, datas = datas}
end


return ma_obj