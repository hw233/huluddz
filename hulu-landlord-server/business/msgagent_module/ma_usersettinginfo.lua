local skynet = require "skynet"

local ma_data = require "ma_data"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local uid = nil; 

local CMD, REQUEST_New = {}, {}

--------------------------------------
local ma_obj = {
    -- 音乐, 音效, 震动, 音效2, 智能选牌, 消息推送, 位置显示
    item = {false, false, false, false, false, false, false};
    isLoaded = false;       --是否已加载
}

--------------------------------------
function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    uid = ma_data.db_info.id
end

function ma_obj.LoadData()
    if ma_obj.isLoaded then return end

    ma_obj.LoadFromDB()

    ma_obj.isLoaded = true
end

function ma_obj.LoadFromDB()
    local selectObj = { uid = uid }
    local data = dbx.get(TableNameArr.UserSettingInfoTable, selectObj)
    if not data then  -- add to db
        local d = { uid = uid, item = ma_obj.item, }
        dbx.add(TableNameArr.UserSettingInfoTable, d)
    else
        ma_obj.item = data.item
    end
end

-- 初始化  
-- load player settinginfo from db


-- GetSettingInfo
REQUEST_New.GetSettingInfo = function()
    ma_obj.LoadData()

    return RET_VAL.Succeed_1, { item=ma_obj.item }
end

-- SetSettingInfo
REQUEST_New.SetSettingInfo = function(args)
    ma_obj.LoadData()
    
    assert(table.nums(args.item)<20)
    ma_obj.item = args.item;
    -- write db
    local selectObj = { uid = uid }
    dbx.update(TableNameArr.UserSettingInfoTable, selectObj, { item=ma_obj.item } )

    return RET_VAL.Succeed_1
end


return ma_obj




