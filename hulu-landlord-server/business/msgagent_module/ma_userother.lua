local skynet = require "skynet"

local ma_data = require "ma_data"

-- local objx = require "objx"
-- local arrayx = require "arrayx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
--local ma_common = require "ma_common"

-- require "define"
-- require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
--#endregion

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local ma_obj = {
    userOther = nil
}

ma_obj.initCfg = function ()
    
end

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.initCfg()

    local obj = dbx.get(TableNameArr.UserOther, userInfo.id)
    if not obj then
        obj = {
            id = userInfo.id,
        }
        dbx.add(TableNameArr.UserOther, obj)
    end
    ma_obj.userOther = obj

end


--#region 核心部分

ma_obj.keyEnum = {
    newYear = "newYear",
    newMonth = "newMonth",
    newWeek = "newWeek",
    newDay = "newDay",
    newMinutes = "newMinutes",
}

---comment
---@param key string
---@return any
ma_obj.get = function (key)
    return ma_obj.userOther[key]
end

---comment
---@param key string
---@param value any
ma_obj.set = function (key, value)
    ma_obj.userOther[key] = value
    dbx.update(TableNameArr.UserOther, userInfo.id, {[key] = value})
end

--#endregion


return ma_obj