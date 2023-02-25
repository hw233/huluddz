local skynet = require "skynet"

local ma_data = require "ma_data"
local ma_useritem = require "ma_useritem"

local datax  = require "datax"
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
local cfg_items = require "cfg.cfg_items"
--#endregion

local REQUEST_New = {}
local CMD = {}

local userInfo = ma_data.userInfo

local ma_obj = {
    datas = nil,
    showDatas = nil,

    ShowEnum = {
        HotSale = 2, -- 热销
    }
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.loadDatas()

    eventx.listen(EventxEnum.UserNewDay, function ()
        ma_obj.reset(DateType.Day)

        ma_obj.resetTypeData(ma_obj.ShowEnum.HotSale, timex.addDays(timex.getDayZero(), 1))
    end)

    eventx.listen(EventxEnum.UserNewWeek, function ()
        ma_obj.reset(DateType.Week)
    end)

    eventx.listen(EventxEnum.UserNewMonth, function ()
        ma_obj.reset(DateType.Month)
    end)

    eventx.listen(EventxEnum.UserOnline, function ()
        if not ma_obj.getTypeData(ma_obj.ShowEnum.HotSale) then
            ma_obj.resetTypeData(ma_obj.ShowEnum.HotSale, timex.addDays(timex.getDayZero(), 1))
        end
    end)

    -- eventx.listen(EventxEnum.UserTimeEnd, function (timeType, currentTime, param)
    --     if param.showType then
    --         local data = ma_obj.getTypeData(param.showType)
    --         if data then
    --             -- 需要获取下一次更新时间
    --             --ma_obj.resetTypeData(param.showType, )
    --         end
    --     end
    -- end)
end


--#region 核心部分

ma_obj.loadDatas = function ()
    if not ma_obj.datas or not ma_obj.showDatas then
        local obj = dbx.get(TableNameArr.UserStore, userInfo.id)
        if not obj then
            obj = {
                id = userInfo.id,
                dataTable = {},
                showDatas = {},
            }
            dbx.add(TableNameArr.UserStore, obj)
        end
        ma_obj.datas = obj.dataTable
        ma_obj.showDatas = obj.showDatas
    end
end

---comment
---@param id number
---@return table
ma_obj.get = function (id)
    local sData = datax.store[id]
    if not sData then
        return nil
    end
    local typeDatas = ma_obj.datas[tostring(sData.buyLimitType)]
    if not typeDatas then
        return nil
    end
    return typeDatas[tostring(id)]
end

ma_obj.syncData = function (data)
    ma_common.send_myclient("SyncUserStore", {data = data})
end

---comment
---@param id number
---@param num number
---@param endDt number 结束时间
ma_obj.add = function (id, num, endDt)
    local sData = datax.store[id]
    id = tostring(id)
    local typeStr = tostring(sData.buyLimitType)
    local typeDatas = ma_obj.datas[typeStr]
    if not typeDatas then
        typeDatas = {}
        ma_obj.datas[typeStr] = typeDatas
    end

    local data = typeDatas[id]
    if not data then
        data = {
            id = id,
            num = 0,
            endDt = nil,
        }
        typeDatas[id] = data
    end
    data.num = data.num + num
    data.endDt = endDt

    dbx.update(TableNameArr.UserStore, userInfo.id, {["dataTable." .. typeStr .. "." .. id] = data})

    ma_obj.syncData(data)

    return data
end

--- 重置日期限购的数据
---@param dateType number
ma_obj.reset = function (dateType)
    local dateTypeStr = tostring(dateType)
    if ma_obj.datas[dateTypeStr] then
        ma_obj.datas[dateTypeStr] = nil

        dbx.del_field(TableNameArr.UserStore, userInfo.id, {["dataTable." .. dateType] = ""})

        ma_common.send_myclient("SyncUserStore", {type = tonumber(dateType)})
    end
end

---comment
---@param id number
---@param num number
---@param notShow boolean
---@return boolean
ma_obj.buy = function (id, num, notShow, orderId)
    local sData = datax.store[id]
    if not sData or num <= 0 then
        skynet.loge("buy error", id, num)
        return false
    end

    -- if sData.buyLimit > 0 then
    --     ma_obj.add(id, num)
    -- end
    local uData = ma_obj.add(id, num)
    local doubleNum = 0
    if sData.isFirstDouble == 1 and uData.num - num == 0  then
        doubleNum = 1
    end

    local rewardInfo = {}
    local sendDataArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Default)

    local from = "StoreBuy" .. sData.show_type .. "_商城购买";
    ma_useritem.addList(sData.rewards, num + doubleNum, from, sendDataArr)

    if doubleNum == 0 and sData.otherGift then
        ma_useritem.addList(sData.otherGift, num, from, sendDataArr)
    end

    --如果是钻石或者RMB充值 计算符文加成
    if id == ItemID.Diamond or sData.costId == 0 then
        local bonusObj = userInfo.bonusObj or {}
        if bonusObj.rune then
            local goldRate = (bonusObj.rune[BonusType.PayGold] or 0)
            if goldRate > 0 then
                local goldItem = arrayx.find(sData.rewards, function (index, value)
                    return value.id == ItemID.Gold
                end)
                if goldItem then
                    goldItem.num = goldItem.num * goldRate // 10000
                    if goldItem.num > 0 then
                        local runeAddItemArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Rune)
                        ma_useritem.addList({goldItem}, 1, from.."符文加成", runeAddItemArr)
                    end
                end
            end
        end
    end
    ---------------------

    if sData.costId == 0 then
        local price = sData.price * 100

        userInfo.payDay = userInfo.payDay or 0

        local isFirst, isFirstDay = userInfo.pay <= 0, userInfo.payDay <= 0
        userInfo.pay = userInfo.pay + price
        userInfo.payDay = userInfo.payDay + price
        userInfo.payMonth = userInfo.payMonth + price

        dbx.update(TableNameArr.User, userInfo.id, {pay = userInfo.pay, payMonth = userInfo.payMonth})

        eventx.call(EventxEnum.UserPay, price)

        ma_common.pushCollecter("UserPay", os.time(), id, price, orderId, {
            firstLoginDt = userInfo.firstLoginDt,
            isFirst = isFirst,
            isFirstDay = isFirstDay,
        })

       

    end

    eventx.call(EventxEnum.UserStoreBuy, sData, num, rewardInfo)

    if not notShow then
        ma_common.showReward(rewardInfo)
    end

    return true
end

---comment
---@param id number
---@param num number
---@param notShow boolean
---@return integer
ma_obj.buyStore = function (id, num, notShow)
    if not id or not num then
        return RET_VAL.ERROR_3
    end
    local idStr = tostring(id)

    if num < 1 or num > 999 then
        return RET_VAL.Fail_2
    end

    local sData = datax.store[id]
    if not sData or not cfg_items[sData.costId] then
        return RET_VAL.ERROR_3;
    end

    -- if userInfo.vip < sData.vipLv then
    --     return RET_VAL.Mis7;
    -- end

    if userInfo.pay < sData.need_cumulative_recharge then
        return RET_VAL.NotOpen_9
    end

    if sData.buyLimit > 0 then
        if num > sData.buyLimit then
            return RET_VAL.NoUse_8;
        end

        local uData = ma_obj.get(id)
        if uData then
            if uData.num >= sData.buyLimit or uData.num + num > sData.buyLimit then
                return RET_VAL.NoUse_8;
            end
        end
    end

    local showDatas = ma_obj.getTypeData(sData.show_type)
    if showDatas and not table.first(showDatas.arr, function (key, value)
        return value == id
    end) then
        return RET_VAL.NotExists_5
    end

    -- var canBuy = Val.Success;
    -- eventx.Request(MsgxType.ShopBuy, user, sData, num, ref canBuy);
    --if (canBuy != Val.Success) return canBuy;

    local from = "ShopBuy" .. sData.show_type .. "_商城购买";

    if not ma_useritem.remove(sData.costId, sData.price * num, from) then
        return RET_VAL.Lack_6
    end

    if not ma_obj.buy(id, num, notShow) then
        return RET_VAL.ERROR_3
    end

    return RET_VAL.Succeed_1
end


ma_obj.getTypeData = function (showType)
    return ma_obj.showDatas[tostring(showType)];
end

--- 重置指定 show_type 中的显示道具
---@param showType number
---@param endDt number
ma_obj.resetTypeData = function (showType, endDt)
    local showTypeStr = tostring(showType)
    if showType == ma_obj.ShowEnum.HotSale then -- 热销
        local sDataArr = table.where(datax.store, function (key, value)
            value.id = key
            return value.show_type == showType
        end)
        local groupData = table.groupBy(sDataArr, function (key, value)
            return value.position
        end)
        local arr = table.select(groupData, function (key, arr)
            local sData = objx.getChance(arr, function (value)
                return value.weight
            end)
            return sData.id
        end)

        local data = {
            showType = showType,
            arr = arr,
            endDt = endDt,
        }
        ma_obj.showDatas[showTypeStr] = data

        dbx.update(TableNameArr.UserStore, userInfo.id, {["showDatas." .. showTypeStr] = data})

        for index, id in ipairs(arr) do
            ma_obj.add(id, 0, endDt)
        end

    else
        return
    end
    ma_common.send_myclient("SyncUserStore", {showType = showType})
end

--#endregion

REQUEST_New.GetUserStoreDatas = function ()
    local ret = {
        datas = {},
        showDatas = {},
    }
    for key, obj in pairs(ma_obj.datas) do
        for key, value in pairs(obj) do
            ret.datas[key] = value
        end
    end
    for key, data in pairs(ma_obj.showDatas) do
        ret.showDatas[data.showType] = data
    end
    return ret
end

REQUEST_New.StoreBuy = function (args)
    local id, num = args.id, args.num
    return ma_obj.buyStore(id, num)
end

-- REQUEST_New.StoreRefresh = function (args)
--     local _type = args.type
--     if not _type then
--         return RET_VAL.ERROR_3
--     end


--     return RET_VAL.Succeed_1
-- end


CMD.UserStoreBuy = function (source, id, num, notShow)
    return ma_obj.buyStore(id, num, notShow)
end


return ma_obj