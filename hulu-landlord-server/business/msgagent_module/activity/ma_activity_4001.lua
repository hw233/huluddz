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
    id = 4001,
    giftIdArr = {}
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    for key, value in pairs(datax.bust_gift) do
        ma_obj.giftIdArr[value.store_id] = true
    end

    eventx.listen(EventxEnum.RoomGameLostGold, function (goldChange)
        if goldChange and ma_useractivity.isOpen(ma_obj.id) then
            local val = goldChange
            local arr = arrayx.orderBy(datax.bust_gift, function (obj)
                return obj.trigger_amount
            end)
            local sData = arrayx.find(arr, function (index, value)
                return val <= value.trigger_amount
            end)
            sData = sData or arr[#arr]
            
            if sData then
                ma_useractivity.openTriggerAct(ma_obj.id, function (uAct)
                    uAct.startDt = os.time()
                    uAct.endDt = timex.addHours(uAct.startDt, 2)
                    uAct.data4001 = {id = sData.id, isBuy = false, gold = (val * sData.return_ratio) // 10000}
                end)
            end
        end
    end)

    eventx.listen(EventxEnum.UserStoreBuy, function (sData, num, rewardInfo)
        if ma_obj.giftIdArr[sData.id] and ma_useractivity.isOpen(ma_obj.id) then
            local uAct = ma_useractivity.getUserActData(ma_obj.id)
            if uAct and uAct.data4001 and not uAct.data4001.isBuy then
                local giftCfg = datax.bust_gift[uAct.data4001.id]
                if giftCfg and giftCfg.store_id == sData.id then
                    if uAct.data4001.gold and uAct.data4001.gold > 0 then
                        local sendDataArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Default)
                        ma_useritem.add(ItemID.Gold, uAct.data4001.gold, "Activity" .. ma_obj.id .. "_破产礼包返还", sendDataArr)
                    end
                    ma_useractivity.stopAct(ma_obj.id, function (uAct)
                        uAct.isBuy = true
                    end)
                end
            end
        end
    end)

end


--#region 核心部分

--#endregion


return ma_obj