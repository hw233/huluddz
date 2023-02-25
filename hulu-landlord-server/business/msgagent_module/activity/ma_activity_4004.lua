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
local AdvType = {
    Yaoyiyao=30,
}

local ma_obj = {
    id = 4004,
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    eventx.listen(EventxEnum.UserNewDay, function ()
        local uAct = ma_useractivity.getUserActData(ma_obj.id)
        local data4004 = uAct.data4004 or {count = 0}
        if data4004.count > 0 then
            data4004.count = 0
            ma_useractivity.setUserActData(ma_obj.id, uAct)
        end
    end)

    eventx.listen(EventxEnum.AdvertLook, function (sdata, args)
        if not sdata then
            return
        end
        local _type = sdata.type
        if _type == AdvType.Yaoyiyao then
            local sData = objx.getChance(datax.shake_discount, function (value)
                return value.weight
            end)
            local Proto = {id = sData.store_id}
            ma_data.send_push('SyncAct4004', Proto)
        end
    end)
end


--#region 核心部分

--#endregion

REQUEST_New.Act4004 = function ()
    if not ma_useractivity.isOpen(ma_obj.id) then
        return RET_VAL.NotOpen_9
    end

    local uAct = ma_useractivity.getUserActData(ma_obj.id)
    local data4004 = uAct.data4004 or {count = 0}
    if data4004.count >= datax.globalCfg[107002].val then
        return RET_VAL.Fail_2
    end

    local sData = objx.getChance(datax.shake_discount, function (value)
        return value.weight
    end)

    if not sData then
        return RET_VAL.ERROR_3
    end

    data4004.count = data4004.count + 1
    uAct.data4004 = data4004
    ma_useractivity.setUserActData(ma_obj.id, uAct)

    return RET_VAL.Succeed_1, {id = sData.store_id}
end


return ma_obj