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

local ma_obj = {
    id = 4007,
    itemIdMap = {}
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    for key, value in pairs(datax.month_cards) do
        ma_obj.itemIdMap[value.item_id] = key
    end

    eventx.listen(EventxEnum.UserNewDay, function ()
        for itemId, value in pairs(ma_obj.itemIdMap) do
            if ma_useritem.has({{id = itemId, num = 1}}, 1, true) then
                local sData = datax.month_cards[value]
                if sData then
                    ma_common.addMail(userInfo.id, sData.mail_id, "Act4007_" .. sData.id .. "_月卡每日奖励", nil, sData.dilly_rewards)
                end
            end
        end
    end)

end


--#region 核心部分

--#endregion


return ma_obj