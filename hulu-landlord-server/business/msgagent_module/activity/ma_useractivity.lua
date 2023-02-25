local skynet = require "skynet"

local ma_data = require "ma_data"
local ma_useritem = require "ma_useritem"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local eventx = require "eventx"
local timex = require "timex"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"
local ec = require "eventcenter"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
--#endregion

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local ma_obj = {
    actDataCfg = nil,
    actDatas = nil,
    datas = nil,

    uMap = {[4001] = true}
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    local obj = dbx.get(TableNameArr.UserActivityData, userInfo.id)
    if not obj then
        obj = {
            id = userInfo.id,
            datas = {},
        }
        dbx.add(TableNameArr.UserActivityData, obj)
    end
    ma_obj.datas = obj.datas
    
    ma_obj.initListen()
end

ma_obj.initListen = function ()

    ma_obj.updateActDatas()
    ec.sub({type = "reloadActiveConfig"}, function ()
        ma_obj.updateActDatas()
        ma_obj.syncActDatas(ma_obj.actDatas)
    end)
    
end

--#region 核心部分

ma_obj.syncActDatas = function (datas)
    ma_common.send_myclient("SyncActivityData", {datas = datas})
end

ma_obj.syncUserActData = function (id)
    id = tostring(id)
    local uAct = ma_obj.datas[id]
    if uAct then
        if ma_obj.uMap[uAct.id] then
            local actData = ma_obj.getActData(id)
            ma_obj.actDatas[id] = actData
            ma_obj.syncActDatas({actData})
        end
        ma_common.send_myclient("SyncUserActivityData", {datas = {uAct}})
    end
end

ma_obj.updateActDatas = function ()
    ma_obj.actDataCfg = ma_common.getActData()
    local actDatas = {}
    for key, value in pairs(ma_obj.actDataCfg) do
        actDatas[key] = ma_obj.getActData(key)
    end
    ma_obj.actDatas = actDatas
end

ma_obj.getActData = function (id)
    id = tostring(id)
    local ret = nil
    local data = ma_obj.actDataCfg[id]
    if data then
        ret = table.clone(data)
        if data.open and ma_obj.uMap[data.id] then
            local uData = ma_obj.getUserActData(id)
            if uData then
                ret.startDt = uData.startDt or ret.startDt
                ret.endDt = uData.endDt or ret.endDt
                ret.open = uData.open
            else
                ret.open = false
            end
        end
    end
    return ret
end

ma_obj.getUserActData = function (id)
    return ma_obj.datas[tostring(id)] or {id = tonumber(id), startDt = 0, endDt = 0, open = false}
end

ma_obj.setUserActData = function (id, data)
    id = tostring(id)
    ma_obj.datas[id] = data
    dbx.update(TableNameArr.UserActivityData, userInfo.id, {["datas." .. id] = data})

    ma_obj.syncUserActData(id)
end



ma_obj.isOpen = function (id)
    id = tostring(id)
    local data = ma_obj.actDataCfg[id]
    return data and data.open or false
end

ma_obj.openTriggerAct = function (id, func)
    --local now = os.time()
    local uData = ma_obj.getUserActData(id)
    --if (now < uData.startDt or now >= uData.endDt) and func then
    if func then
        func(uData)
        uData.open = true
        ma_obj.setUserActData(id, uData)
        return true
    end
    return false
end

ma_obj.stopAct = function (id, func)
    local uData = ma_obj.getUserActData(id)
    if func then
        func(uData)
    end
    uData.open = false
    ma_obj.setUserActData(id, uData)
end

--#endregion


REQUEST_New.GetActivityDatas = function (args)
    local datas
    if args.idArr then
        datas = {}
        for index, id in ipairs(args.idArr) do
            datas[id] = ma_obj.actDatas[id]
        end
    else
        datas = ma_obj.actDatas
    end
    return {datas = datas}
end

REQUEST_New.GetUserActivityDatas = function (args)
    local datas
    if args.idArr then
        datas = {}
        for index, id in ipairs(args.idArr) do
            datas = ma_obj.datas[tostring(id)]
        end
    else
        datas = ma_obj.datas
    end
    return {datas = datas}
end



return ma_obj