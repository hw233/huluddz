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
    cfgData = nil,
    datas = nil,
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    -- local obj = dbx.get(TableNameArr.UserActivityData, userInfo.id)
    -- if not obj then
    --     obj = {
    --         id = userInfo.id,
    --         datas = {},
    --     }
    --     dbx.add(TableNameArr.UserActivityData, obj)
    -- end
    -- ma_obj.datas = {}
    
    ma_obj.initListen()
end

ma_obj.initListen = function ()

    eventx.listen(EventxEnum.UserDataGet, function (data)
        data.gameFuncDatas = ma_obj.datas
    end)

    ma_obj.updateDatas()
    ec.sub({type = EventCenterEnum.GameFunc}, function ()
        ma_obj.updateDatas()
        ma_obj.syncDatas(ma_obj.datas)
    end)
    
end

--#region 核心部分

ma_obj.syncDatas = function (datas)
    ma_common.send_myclient("SyncGameFuncData", {datas = datas})
end

ma_obj.updateDatas = function ()
    ma_obj.cfgData = skynet.call("game_func_mgr", "lua", "GetData")
    local datas = {}
    for key, value in pairs(ma_obj.cfgData) do
        datas[key] = ma_obj.getData(key)
    end
    ma_obj.datas = datas
end

ma_obj.getData = function (id)
    id = tostring(id)
    local ret = nil
    local data = ma_obj.cfgData[id]
    if data then
        ret = table.clone(data)
        if data.open and data.channelCloseArr and arrayx.findVal(data.channelCloseArr, userInfo.channel) then
            ret.open = false
        end
    end
    return ret
end


ma_obj.isOpen = function (id)
    id = tostring(id)
    local data = ma_obj.cfgData[id]
    return data and data.open or false
end


--#endregion


REQUEST_New.GetGameFuncDatas = function (args)
    local datas
    if args.idArr then
        datas = {}
        for index, id in ipairs(args.idArr) do
            datas[id] = ma_obj.datas[id]
        end
    else
        datas = ma_obj.datas
    end
    return {datas = datas}
end



return ma_obj