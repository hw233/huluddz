local skynet = require "skynet"

local ma_data           = require "ma_data"
local ma_useritem       = require "ma_useritem"
local ma_userfriend     = require "ma_userfriend"
local ma_globalCfg		= require "ma_global_cfg"

local datax = require "datax"
local objx = require "objx"
local timex = require "timex"
local arrayx = require "arrayx"
local eventx = require "eventx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"
local common = require "common_mothed"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
local cfg_gourd = require "cfg.cfg_gourd_vine"
--#endregion
local AdvType = {
    ZaoCan=14,
    ZhongCan=15,
    WanCan=16,
}

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local ma_obj = {
    lvReward = nil,
    fixedTimeReward = nil,
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    -- TODO：先注释，调试时在消除注释
    if not userInfo.gourdLv then
        userInfo.gourdLv = 1
        userInfo.gourdExp = 0
        dbx.update(TableNameArr.User, userInfo.id, {gourdLv = userInfo.gourdLv, gourdExp = userInfo.gourdExp})
    end

    local versionsKey   = "2021.12.31 01:48"
    local valVersionKey = "2021.12.31 01:48"    -- 数值版本
    local obj = dbx.get(TableNameArr.UserGourd, userInfo.id) or {}
    if obj.versionsKey ~= versionsKey then
        obj.versionsKey = versionsKey

        if obj.valVersionKey ~= valVersionKey then
            obj.valVersionKey = valVersionKey
            ma_obj._valVersionUpdate()
        end

        obj.id = userInfo.id
        obj.lvReward = obj.lvReward or {}                           --等级奖励记录  格式：{["1"]={vip=true}}  有值就代表已领取普通奖励，而VIP奖励需要标记
        obj.fixedTimeReward = obj.fixedTimeReward or {}             --定点补给记录    格式：{1,2,3}  数组，有其索引位置就代表已领取

        obj.lastGetWaterRewardDt = obj.lastGetWaterRewardDt or 0    -- 上次领取水分补给的时刻
        obj.getWaterTimes = obj.getWaterTimes or 0                  -- 已连续几日领取水分补给

        obj.loosenSoilO2ValDayMy    = obj.loosenSoilO2ValDayMy or 0        -- 今日贡献氧气
        obj.loosenSoilBoxRecord     = obj.loosenSoilBoxRecord or {}     -- 松土宝箱记录

        obj.friendHelpApplyRecord   = obj.friendHelpApplyRecord or {} -- 邀请好友助产记录

        obj.pickFruitNumDay = obj.pickFruitNumDay or 0      -- 摘取别人豆子数量(日)
        obj.pickFruitCountDay  = obj.pickFruitCountDay or 0       -- 摘豆累计次数/天
        obj.pickFruitFreeCountDay  = obj.pickFruitFreeCountDay or 0       -- 免费偷取陌生人果实次数（日）
        obj.pickFruitRecord = obj.pickFruitRecord or {}     -- 摘豆记录/天


        obj.collectUserRecord = obj.collectUserRecord or {}

        obj.gourdLv = userInfo.gourdLv
        dbx.update_add(TableNameArr.UserGourd, userInfo.id, obj)
    end

    table.merge(ma_obj, obj)

    eventx.listen(EventxEnum.UserNewDay, function ()
        local updateObj = {}

        if next(ma_obj.fixedTimeReward) then
            ma_obj.fixedTimeReward = {}
            updateObj.fixedTimeReward = ma_obj.fixedTimeReward
        end

        ma_obj.loosenSoilO2ValDayMy = 0
        ma_obj.loosenSoilBoxRecord = {}
        updateObj.loosenSoilO2ValDayMy = ma_obj.loosenSoilO2ValDayMy
        updateObj.loosenSoilBoxRecord = ma_obj.loosenSoilBoxRecord

        ma_obj.friendHelpApplyRecord = {}
        updateObj.friendHelpApplyRecord = ma_obj.friendHelpApplyRecord

        ma_obj.pickFruitNumDay = 0
        ma_obj.pickFruitCountDay = 0
        ma_obj.pickFruitFreeCountDay = 0
        ma_obj.pickFruitRecord = {}
        updateObj.pickFruitNumDay = ma_obj.pickFruitNumDay
        updateObj.pickFruitCountDay = ma_obj.pickFruitCountDay
        updateObj.pickFruitFreeCountDay = ma_obj.pickFruitFreeCountDay
        updateObj.pickFruitRecord = ma_obj.pickFruitRecord

        dbx.update(TableNameArr.UserGourd, userInfo.id, updateObj)
    end)

    eventx.listen(EventxEnum.UserVipUpLv, function ()
        ma_obj.VipLvRewardAll()
        skynet.send("user_gourd", "lua", "UpdateData", userInfo.id, {vip = userInfo.vip})
    end)

    eventx.listen(EventxEnum.AdvertLook, function (args)
        if not args then
            return
        end

        local _type = args.type
        if _type == AdvType.ZaoCan or _type == AdvType.ZhongCan or _type == AdvType.WanCan then
            local param = {}
            if _type == AdvType.ZaoCan then
                param.index = 1
            elseif _type == AdvType.ZhongCan then
                param.index = 2
            elseif _type == AdvType.WanCan then
                param.index = 3
            end
            if param.index then
                REQUEST_New.GourdFixedTimeReward(param, true)
            end
        end
    end)

    eventx.listen(EventxEnum.UserBonusDataChange, function ()
        if userInfo.bonusObj then
            skynet.send("user_gourd", "lua", "UpdateData", userInfo.id, {bonusObj = userInfo.bonusObj})
        end
    end)

    skynet.fork(function ()
        skynet.send("user_gourd", "lua", "UpdateData", userInfo.id, {gourdLv = userInfo.gourdLv, vip = userInfo.vip})
    end)

end


--#region 核心部分

ma_obj.getOtherData = function (id)
    return skynet.call("user_gourd", "lua", "GetData", id)
end

--- 获取等级奖励
ma_obj.getLvReward = function (sendDataArr)
    local reward = {}
    local rewardVip = {}

    for key, sData in pairs(cfg_gourd) do
        if sData.level <= userInfo.gourdLv then
            local levelStr = tostring(sData.level)
            local data = ma_obj.lvReward[levelStr]
            if not data then
                table.append(reward, sData.level_rewards)
                data = {level = levelStr}
                ma_obj.lvReward[levelStr] = data
            end

            if not data.vip and userInfo.vip > 0 then
                table.append(rewardVip, sData.vip_level_rewards)
                data.vip = true
            end
        end
    end

    if next(reward) or next(rewardVip) then
        dbx.update(TableNameArr.UserGourd, userInfo.id, {lvReward = ma_obj.lvReward})
    end

    ma_useritem.addList(reward, 1, "GourdLvReward_葫芦藤等级奖励", sendDataArr)
    ma_useritem.addList(rewardVip, 1, "GourdVipLvReward_葫芦藤Vip等级奖励", sendDataArr)
end

-- 获取vip奖励列表
ma_obj.VipLvRewardAll = function ()
    local ErrorCode = RET_VAL.Succeed_1
    local rewardVips = {}
    for _, sData in pairs(cfg_gourd) do
        if sData.level <= userInfo.gourdLv then
            local data = ma_obj.lvReward[tostring(sData.level)]
            if data and not data.vip and userInfo.vip > 0 then
                table.append(rewardVips, sData.vip_level_rewards)
                data.vip = true
            end
        end
    end

    --更新数据库
    if next(rewardVips) then
        dbx.update(TableNameArr.UserGourd, userInfo.id, {lvReward = ma_obj.lvReward})
    end

    if next(rewardVips) then
        ---添加邮件，策划表中已配置的邮件
        ma_common.addMail(userInfo.id, 5001, "GourdVipLvRewardAll_葫芦藤_VIP额外奖励", nil, rewardVips)
    end
    return ErrorCode
end

ma_obj._valVersionUpdate = function ()
    if userInfo.gourdExp <= 0 then
        return
    end

    userInfo.gourdExp = userInfo.gourdExp * 5
    local maxLv = table.maxNum(cfg_gourd, function (key, value)
        return value.level
    end)
    for i = userInfo.gourdLv, (maxLv - 1) do
        local data = cfg_gourd[i + 1]
        if data and userInfo.gourdExp >= data.cost[1].num then
            userInfo.gourdLv = data.level
        else
            break;
        end
    end
    dbx.update(TableNameArr.User, userInfo.id, {gourdLv = userInfo.gourdLv, gourdExp = userInfo.gourdExp})
end

--#endregion

REQUEST_New.GetGourdData = function (args)
    local id = args.id
    if id == userInfo.id then
        id = nil
    end

    local data = ma_obj.getOtherData(id or userInfo.id)

    local ret = {}
    if not id then
        ret.lvReward = ma_obj.lvReward
        ret.fixedTimeReward = ma_obj.fixedTimeReward
        ret.lastGetWaterRewardDt = ma_obj.lastGetWaterRewardDt
        ret.getWaterTimes = ma_obj.getWaterTimes
        
        ret.loosenSoilO2ValDayMy = ma_obj.loosenSoilO2ValDayMy
        ret.loosenSoilBoxRecord = ma_obj.loosenSoilBoxRecord

        ret.friendHelpApplyRecord = ma_obj.friendHelpApplyRecord

        ret.pickFruitNumDay = ma_obj.pickFruitNumDay
        ret.pickFruitCountDay = ma_obj.pickFruitCountDay
        ret.pickFruitFreeCountDay = ma_obj.pickFruitFreeCountDay
        ret.pickFruitRecord = ma_obj.pickFruitRecord

        ret.collectUserRecord = ma_obj.collectUserRecord
    end

    table.merge(ret, data)

    ret.loosenSoilCount = id and data.loosenSoilRecord[userInfo.id]
    ret.loosenSoilBoxArr = id and ma_obj.loosenSoilBoxRecord[id]

    ret.data = id and ma_common.getUserBase(id) or ma_common.toUserBase(userInfo)

    common.handleUserBaseArr(ret.friendHelpArr)

    return ret
end

REQUEST_New.GourdWatering = function (args)
    local num = args.num

    local sData = cfg_gourd[userInfo.gourdLv]
    if not sData or num <= 0 then
        return RET_VAL.ERROR_3
    end

    if not cfg_gourd[userInfo.gourdLv + 1] then
        return RET_VAL.NotExists_5
    end

    if num < ma_globalCfg.getNumber(103006) then
        return RET_VAL.NoUse_8
    end

    local itemId = sData.cost[1].id
    if not ma_useritem.remove(itemId, num, "GourdWatering_葫芦藤浇水") then
        return RET_VAL.Lack_6
    end

    userInfo.gourdExp = userInfo.gourdExp + num

    local sendDataArr = {}
    local oldLv = userInfo.gourdLv
    local maxLv = table.maxNum(cfg_gourd, function (key, value)
        return value.level
    end)
    for i = userInfo.gourdLv, (maxLv - 1) do
        local data = cfg_gourd[i + 1]
        if data and userInfo.gourdExp >= data.cost[1].num then
            userInfo.gourdLv = data.level
            ma_obj.getLvReward(sendDataArr)
        else
            break;
        end
    end

    dbx.update(TableNameArr.User, userInfo.id, {gourdLv = userInfo.gourdLv, gourdExp = userInfo.gourdExp})

    ma_common.updateUserBase(userInfo.id, {gourdLv = userInfo.gourdLv, gourdExp = userInfo.gourdExp})

    skynet.send("user_gourd", "lua", "UpdateData", userInfo.id, {gourdLv = userInfo.gourdLv})

    eventx.call(EventxEnum.GourdWatering, num)

    skynet.call("ranklistmanager", "lua", "update_hlt", 
        userInfo.id, userInfo.nickname, userInfo.head, userInfo.headFrame, userInfo.gourdExp, num)

    -- 客户端需求，延后，不能被引导挡住
    if next(sendDataArr) then
        skynet.fork(function ()
            ma_common.showReward(sendDataArr)
        end)
    end

    return RET_VAL.Succeed_1, {gourdLv = userInfo.gourdLv, gourdExp = userInfo.gourdExp, oldLv = oldLv}
end

-- 配牌服设置使用
CMD.SetUserGourdLv = function (source, lv)
    local sData = cfg_gourd[lv]
    if not sData then
        return false
    end

    userInfo.gourdExp = sData.cost[1].num
    userInfo.gourdLv = lv
    ma_obj.getLvReward()

    local updateData = {gourdLv = userInfo.gourdLv, gourdExp = userInfo.gourdExp}
    dbx.update(TableNameArr.User, userInfo.id, updateData)

    ma_common.updateUserBase(userInfo.id, updateData)

    skynet.call("user_gourd", "lua", "UpdateData", userInfo.id, {gourdLv = userInfo.gourdLv})

    ma_common.send_myclient("SyncUserData_GM", {data = updateData})
end

REQUEST_New.GourdGetWaterReward = function ()
    local sData = ma_globalCfg.getValue(103009)

    local now = os.time()
    if timex.equalsDay(now, ma_obj.lastGetWaterRewardDt) then
        return RET_VAL.Exists_4
    end
    
    if timex.equalsDay(timex.addDays(ma_obj.lastGetWaterRewardDt, 1), now) then
        ma_obj.getWaterTimes = ma_obj.getWaterTimes + 1
    else
        ma_obj.getWaterTimes = 1
    end
    ma_obj.lastGetWaterRewardDt = now

    local updateData = {lastGetWaterRewardDt = ma_obj.lastGetWaterRewardDt, getWaterTimes = ma_obj.getWaterTimes}
    dbx.update(TableNameArr.UserGourd, userInfo.id, updateData)

    local num = sData.val
    if ma_obj.getWaterTimes >= sData.times then
        num = sData.val7
    end

    local rewardInfo = {}
    local sendDataArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Default)
    ma_useritem.add(ItemID.GourdWater, num, "GourdGetWaterReward_葫芦藤水分补给", sendDataArr)
    
    local bonusObj = userInfo.bonusObj or {}
    if bonusObj.rune then
        local goldRate = bonusObj.rune[BonusType.GourdWaterDay] or 0
        if goldRate > 0 then
            num = num * goldRate // 10000
            if num > 0 then
                local runeAddItemArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Rune)
                ma_useritem.add(ItemID.GourdWater, num, "GourdGetWaterReward_葫芦藤水分补给", runeAddItemArr)
            end
        end
    end

    ma_common.showReward(rewardInfo)

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.GourdFixedTimeReward = function (args, isAdvert)
    local index = args.index

    local cfgArr = ma_globalCfg.getValue(103008)
    local sData = cfgArr[index]
    if not sData then
        return RET_VAL.ERROR_3
    end

    if arrayx.findVal(ma_obj.fixedTimeReward, index) then
        return RET_VAL.Exists_4
    end

    if not isAdvert then
        local hour = tonumber(os.date("%H"))
        if hour < sData.low or hour > sData.heig then
            return RET_VAL.NotOpen_9
        end
    end

    table.insert(ma_obj.fixedTimeReward, index)

    local updateData = {fixedTimeReward = ma_obj.fixedTimeReward}
    dbx.update(TableNameArr.UserGourd, userInfo.id, updateData)

    local rewardInfo = {}
    local sendDataArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Default)
    ma_useritem.addList(sData.item, 1, "GourdFixedTimeReward_葫芦藤定点奖励", sendDataArr)

    -- if userInfo.vip > 0 then
    --     ma_useritem.addList(sData.vipItem, 1, "GourdFixedTimeReward_葫芦藤定点奖励", sendDataArr)
    -- end

    -- vip 加成
    local vipCfg = ma_common.getVipCfg()
    if vipCfg.gourd_vine_meals_add > 0 then
        local goldItem = arrayx.find(sData.item, function (index, value)
            return value.id == ItemID.Gold
        end)
        if goldItem then
            local num = goldItem.num * vipCfg.gourd_vine_meals_add // 10000
            if num > 0 then
                local addItemArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Vip)
                ma_useritem.add(ItemID.Gold, num, "GourdFixedTimeReward_葫芦藤定点奖励VIP加成", addItemArr)
            end
        end
    end

    ma_common.showReward(rewardInfo)

    if isAdvert then
        --推送客户端 SyncGourdFixedTimeReward
        ma_data.send_push('SyncGourdFixedTimeReward', updateData)
    end

    return RET_VAL.Succeed_1, updateData
end

-- 施肥
REQUEST_New.GourdFertilizer = function (args)
    local num = args.num
    if not num then
        return RET_VAL.ERROR_3
    end

    if num < ma_globalCfg.getNumber(103010) then
        return RET_VAL.NoUse_8
    end

    local data = ma_obj.getOtherData(userInfo.id)
    local sData = cfg_gourd[userInfo.gourdLv]
    --local addNum = math.min(data.fertilizerNum + ma_globalCfg.getNumber(103002), sData.unlock_num) - data.fertilizerNum
    local addNum = math.min(ma_globalCfg.getNumber(103002), sData.unlock_num)

    if data.fertilizerNum >= 100 then
        return RET_VAL.Fail_2
    end

    if not ma_useritem.remove(ItemID.GourdFertilizer, num, "GourdFertilizer_葫芦藤施肥") then
        return RET_VAL.Lack_6
    end

    local fertilizerNum = skynet.call("user_gourd", "lua", "Fertilizer", userInfo.id, addNum)

    eventx.call(EventxEnum.GourdFertilizer, num)

    return RET_VAL.Succeed_1, {fertilizerNum = fertilizerNum, fertilizerNumAdd = addNum}
end

-- 松土
REQUEST_New.GourdLoosenSoil = function (args)
    local id, isHoe = args.id, not not args.isHoe
    if not id then
        return RET_VAL.ERROR_3
    end

    local cfgObj = ma_globalCfg.getValue(103012)

    local data = ma_obj.getOtherData(userInfo.id)
    if not data then
        return RET_VAL.ERROR_3
    end

    local loosenSoilRecord = data.loosenSoilRecord
    if loosenSoilRecord[id] and (loosenSoilRecord[id] or 0) >= cfgObj.val then
        return RET_VAL.NoUse_8
    end

    local hoeCfg = datax.globalCfg[103018]
    if isHoe and not ma_useritem.remove(hoeCfg.cost.id, hoeCfg.cost.num, "GourdLoosenSoil_葫芦藤松土") then
        return RET_VAL.Lack_6
    end

    local now = os.time()
    local boxCfgObj = ma_globalCfg.getValue(103014)
    local rate = boxCfgObj.rate
    local o2RangeObj = {low = cfgObj.low, heig = cfgObj.heig}

    if isHoe then
        rate = hoeCfg.boxRate
        o2RangeObj = hoeCfg.oxygenRange
    end

    local updateData = {}
    local boxObjArr, boxObj
    if math.random(1, 10000) <= rate then
        --local boxRecord = {["id"] = {{endDt=100},{endDt=110}}}
        boxObjArr = ma_obj.loosenSoilBoxRecord[id] or {}
        boxObj = {id = objx.getUid_Time(), endDt = now + boxCfgObj.time, isOpen = false, rewardArr = nil}
        table.insert(boxObjArr, boxObj)

        ma_obj.loosenSoilBoxRecord[id] = boxObjArr
        updateData["loosenSoilBoxRecord." .. id] = boxObjArr
    end

    local o2Val = math.random(o2RangeObj.low, o2RangeObj.heig)
    local retObj = skynet.call("user_gourd", "lua", "LoosenSoil", id, userInfo.id, o2Val, boxObj)

    retObj.loosenSoilBoxArr = boxObjArr

    ma_obj.loosenSoilO2ValDayMy = ma_obj.loosenSoilO2ValDayMy + o2Val
    updateData.loosenSoilO2ValDayMy = ma_obj.loosenSoilO2ValDayMy
    dbx.update(TableNameArr.UserGourd, userInfo.id, updateData)

    eventx.call(EventxEnum.GourdLoosenSoil, o2Val)

    retObj.isHoe = args.isHoe

    return RET_VAL.Succeed_1, retObj
end

-- 开启宝箱
REQUEST_New.GourdLoosenSoilBoxOpen = function (args)
    local id, index = args.id, args.index
    if not id or not index then
        return RET_VAL.ERROR_3
    end

    local boxObjArr = ma_obj.loosenSoilBoxRecord[id] or {}
    local boxObj = boxObjArr[index]
    if not boxObj then
        return RET_VAL.NotExists_5
    end

    if os.time() > boxObj.endDt then
        return RET_VAL.NoUse_8
    end

    local boxCfgObj = ma_globalCfg.getValue(103014)
    if not ma_useritem.remove(boxCfgObj.cost.id, boxCfgObj.cost.num, "GourdLoosenSoilBoxOpen_开启宝箱") then
        return RET_VAL.Lack_6
    end

    boxObj.isOpen = true
    boxObj.rewardArr = {}
    --table.remove(boxObjArr, index)

    local updateData = {["loosenSoilBoxRecord." .. id] = boxObjArr}

    local rewardArr = ma_globalCfg.getValue(103013)
    local o2RangeObj = ma_globalCfg.getValue(103015)

    local reward = objx.getChance(rewardArr, function (value)
        return value.weight
    end)
    ma_useritem.add(reward.id, reward.num, "GourdLoosenSoilBoxOpen_开启宝箱", boxObj.rewardArr)
    ma_common.showReward(boxObj.rewardArr)

    local o2Val = math.random(o2RangeObj.low, o2RangeObj.heig)
    local retObj = skynet.call("user_gourd", "lua", "AddO2", id, userInfo.id, o2Val, true, boxObj)

    retObj.loosenSoilBoxArr = boxObjArr

    ma_obj.loosenSoilO2ValDayMy = ma_obj.loosenSoilO2ValDayMy + o2Val
    updateData.loosenSoilO2ValDayMy = ma_obj.loosenSoilO2ValDayMy
    dbx.update(TableNameArr.UserGourd, userInfo.id, updateData)

    return RET_VAL.Succeed_1, retObj
end

-- 邀请好友助产
REQUEST_New.GourdFriendHelpApply = function (args)
    local id = args.id
    if not id then
        return RET_VAL.ERROR_3
    end

    local now = os.time()
    local cfgData = ma_globalCfg.getValue(103016)
    local applyData = ma_obj.friendHelpApplyRecord[id]
    if applyData and now - applyData.lastDt < cfgData.applyInterval then
        return RET_VAL.Other_10
    end

    local data = ma_obj.getOtherData(userInfo.id)
    if not data then
        return RET_VAL.ERROR_3
    end

    if #data.friendHelpArr >= cfgData.numMax then
        return RET_VAL.Fail_2
    end

    if arrayx.findVal(data.friendHelpArr, id) then
        return RET_VAL.Exists_4
    end

    if not ma_userfriend.get(id) then
        return RET_VAL.NotExists_5
    end

    ma_obj.friendHelpApplyRecord[id] = {id = id, lastDt = now}
    dbx.update(TableNameArr.UserGourd, userInfo.id, {["friendHelpApplyRecord." .. id] = ma_obj.friendHelpApplyRecord[id]})

    -- 有id区分记录，无需在 usergourd服务中进行
    -- 需要被邀请记录么？  有消息不就行了？

    -- TODO: 发邀请消息  先发送个临时消息

    ma_common.send_client(id, "GourdFriendHelpApply_C", {data = ma_common.toUserBase(userInfo)})

    return RET_VAL.Succeed_1, {data = ma_obj.friendHelpApplyRecord[id]}
end

-- 好友助产
REQUEST_New.GourdFriendHelp = function (args)
    local id = args.id
    if not id then
        return RET_VAL.ERROR_3
    end

    if not ma_userfriend.get(id) then
        return RET_VAL.NotExists_5
    end

    local ok, friendHelpData = skynet.call("user_gourd", "lua", "FriendHelp", id, userInfo.id, ma_common.toUserBase(userInfo))
    if not ok then
        return RET_VAL.NoUse_8
    end

    local sendDataArr = {}
    local cfgData = ma_globalCfg.getValue(103016)
    ma_useritem.add(cfgData.reward.id, cfgData.reward.num, "GourdFriendHelp_好友助产奖励", sendDataArr)
    ma_common.showReward(sendDataArr)

    common.send_client(id, "GourdFriendHelp_C", {data = friendHelpData})

    return RET_VAL.Succeed_1
end

-- 摘豆
REQUEST_New.GourdPickFruit = function (args)
    local retObj = {uId = args.uId}
    local uId, id, fruitId = args.uId, args.id, args.fruitId
    if not uId then
        return RET_VAL.ERROR_3
    end

    local isMe = false
    local ret, rewardArr, gourdPosData, recordArr
    if uId == userInfo.id then
        isMe = true
        ret, rewardArr, gourdPosData = skynet.call("user_gourd", "lua", "PickFruit", uId, userInfo.id, id, fruitId)
        if ret ~= RET_VAL.Succeed_1 then
            return ret, retObj -- 前端需要
        end
    else
        local cfgData = ma_globalCfg.getValue(103004)
        if userInfo.gourdLv < cfgData.unlockLv then
            return RET_VAL.NotOpen_9
        end

        recordArr = ma_obj.pickFruitRecord[uId]
        if not recordArr then
            recordArr = {
                id = uId,
                count = 0,
                pickNum = 0,
                arr = {},
            }
            ma_obj.pickFruitRecord[uId] = recordArr
        end

        if arrayx.findVal(recordArr.arr, fruitId) then
            return RET_VAL.Exists_4
        end

        if recordArr.count >= cfgData.countMax then
            return RET_VAL.Empty_7
        end

        if ma_obj.pickFruitCountDay >= cfgData.countSumMax then
            return RET_VAL.Fail_2
        end

        local costArr = nil
        local isFree = false
        if not ma_userfriend.get(uId) then
            local costCfg = ma_globalCfg.getValue(103005)
            if ma_obj.pickFruitFreeCountDay >= costCfg.freeNum then
                costArr = {costCfg.cost}
                if not ma_useritem.has(costArr, 1) then
                    return RET_VAL.Lack_6
                end
            else
                isFree = true
            end
        end

        ret, rewardArr, gourdPosData = skynet.call("user_gourd", "lua", "PickFruit", uId, userInfo.id, id, fruitId, not not costArr)
        if ret ~= RET_VAL.Succeed_1 then
            return ret, retObj -- 前端需要
        end

        if costArr then
            ma_useritem.removeList(costArr, 1, "GourdPickFruit_摘豆")
        end

        ma_obj.pickFruitNumDay = ma_obj.pickFruitNumDay + 1
        ma_obj.pickFruitCountDay = ma_obj.pickFruitCountDay + 1
        ma_obj.pickFruitFreeCountDay = ma_obj.pickFruitFreeCountDay + (isFree and 1 or 0)
        table.insert(recordArr.arr, id)
        recordArr.count = recordArr.count + 1
        dbx.update(TableNameArr.UserGourd, userInfo.id, {
            pickFruitRecord = ma_obj.pickFruitRecord, 
            pickFruitCountDay = ma_obj.pickFruitCountDay, 
            pickFruitFreeCountDay = ma_obj.pickFruitFreeCountDay, 
            pickFruitNumDay = ma_obj.pickFruitNumDay
        })
    end

    local goldNum = table.sum(rewardArr, function (key, value)
        return value.id == ItemID.Gold and value.num or 0
    end)
    local goldRewardArr = table.where(rewardArr, function (key, value)
        return value.id == ItemID.Gold
    end)
    rewardArr = table.where(rewardArr, function (key, value)
        return value.id ~= ItemID.Gold
    end)

    ma_useritem.addList(goldRewardArr, 1, "GourdPickFruit_摘豆")
    -- if isMe then
    --     ma_obj.FruitOtherRewardHandler(goldRewardArr)
    -- end

    if next(rewardArr) then
        local rewardInfo = {}
        local sendDataArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Default)
        ma_useritem.addList(rewardArr, 1, "GourdPickFruit_摘豆", sendDataArr)
        ma_common.showReward(rewardInfo)
    end

    --完成任务
    eventx.call(EventxEnum.GourdPickFruit, isMe)

    retObj.data = gourdPosData
    retObj.record = recordArr
    retObj.pickFruitFreeCountDay = ma_obj.pickFruitFreeCountDay
    retObj.fruitId = fruitId
    retObj.goldNum = goldNum

    return RET_VAL.Succeed_1, retObj
end

ma_obj.FruitOtherRewardHandler = function (rewardArr, rewardInfo)
    local bonusObj = userInfo.bonusObj or {}
    if bonusObj.rune then
        local goldRate = bonusObj.rune[BonusType.GourdGoldBase] or 0
        if goldRate > 0 then
            for index, itemObj in ipairs(rewardArr) do
                if itemObj.id == ItemID.Gold then
                    local num = itemObj and (itemObj.num * goldRate // 10000) or 0
                    if num > 0 then
                        ma_useritem.add(ItemID.Gold, num, "GourdPickFruit_摘豆")
                    end
                end
            end
            -- local itemObj = arrayx.find(rewardArr, function (index, value)
            --     return value.id == ItemID.Gold
            -- end)
            -- local num = itemObj and (itemObj.num * goldRate // 10000) or 0
            -- if num > 0 then
            --     local runeAddItemArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Rune)
            --     ma_useritem.add(ItemID.Gold, num, "GourdPickFruit_摘豆", runeAddItemArr)
            -- end
        end
    end
end

REQUEST_New.GourdPickFruitQuick = function (args)
    if not args.type then
        return RET_VAL.ERROR_3
    end

    local rewardArr = skynet.call("user_gourd", "lua", "PickFruitQuick", userInfo.id, args.type)
    if not next(rewardArr) then
        return RET_VAL.Empty_7
    end

    local goldRewardArr = table.where(rewardArr, function (key, value)
        return value.id == ItemID.Gold
    end)
    rewardArr = table.where(rewardArr, function (key, value)
        return value.id ~= ItemID.Gold
    end)

    ma_useritem.addList(goldRewardArr, 1, "GourdPickFruitQuick_一键摘豆")

    -- ma_obj.FruitOtherRewardHandler(goldRewardArr)

    if next(rewardArr) then
        local rewardInfo = {}
        local sendDataArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Default)
        ma_useritem.addList(rewardArr, 1, "GourdPickFruitQuick_一键摘豆", sendDataArr)
        ma_common.showReward(rewardInfo)
    end

    -- local rewardInfo = {}
    -- local sendDataArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Default)
    -- ma_useritem.addList(rewardArr, 1, "GourdPickFruitQuick_一键摘豆", sendDataArr)
   --完成任务
   eventx.call(EventxEnum.GourdPickFruit, true)
    -- ma_obj.FruitOtherRewardHandler(rewardArr, rewardInfo)

    -- ma_common.showReward(rewardInfo)

    return RET_VAL.Succeed_1
end

REQUEST_New.GourdActionRecordGet = function (args)
    local _type, isMe, isLook = args.type, args.isMe, args.isLook

    if not table.first(GourdActionType, function (key, value)
        return value == _type
    end) then
        return RET_VAL.ERROR_3
    end

    local selector = {type = _type}
    if isMe then
        isLook = false
        selector.id = userInfo.id
    else
        selector.toId = userInfo.id
    end
    local arr = dbx.find(TableNameArr.UserGourdAction, selector, nil, 30, {dayDt = -1})

    local idKey = isMe and "toId" or "id"
    local idArr = arrayx.select(arr, function (key, value)
        return value[idKey]
    end)
    local userArr = ma_common.getUserBaseArr(idArr)
    for index, value in ipairs(arr) do
        value.data = userArr[value[idKey]]
        if isLook then
            value.isLook = isLook
        end
    end

    if isLook and #arr > 0 then
        dbx.update(TableNameArr.UserGourdAction, selector, {isLook = true}, true)

        selector.type = nil
        selector.dayDt = arr[#arr].dayDt - 1
        dbx.del(TableNameArr.UserGourdAction, selector)
    end

    return RET_VAL.Succeed_1, {type = _type, isMe = isMe, arr = arr}
end

REQUEST_New.GourdCollectUser = function (args)
    local id, _type = args.id, args.type
    if not id or not _type then
        return RET_VAL.ERROR_3
    end

    local uData = ma_obj.collectUserRecord[id]
    if _type == 1 then
        if uData then
            return RET_VAL.Exists_4
        end

        local data = ma_common.getUserBase(id)
        if not data then
            return RET_VAL.Fail_2
        end
    
        uData = {}
        uData.id = id
        uData.data = data
        uData.startDt = os.time()
        ma_obj.collectUserRecord[id] = uData
    
        dbx.update(TableNameArr.UserGourd, userInfo.id, {["collectUserRecord." .. id] = uData})

    elseif _type == 2 then
        if not uData then
            return RET_VAL.NotExists_5
        end

        ma_obj.collectUserRecord[id] = nil

        dbx.del_field(TableNameArr.UserGourd, userInfo.id, {["collectUserRecord." .. id] = true})

    else
        return RET_VAL.ERROR_3
    end

    return RET_VAL.Succeed_1, {type = _type, data = uData}
end


REQUEST_New.GourdNearbyUserGet = function ()
    local arr = dbx.find(TableNameArr.User, {}, {id = true}, 50, {onLineDt = 1})

    local friends = ma_userfriend.getDataArr({uId = true})
    friends = table.toObject(friends, function (key, value)
        return value.uId
    end)

    local retArr = {}
    if arr and friends then
        for index, value in ipairs(arr) do
            if math.random(1, 100) < 50 and not friends[value.id] then
                table.insert(retArr, {id = value.id})
            end

            if #retArr > 20 then
                break
            end
        end
    end

    common.handleUserBaseArr(retArr)
    for index, value in ipairs(retArr) do
        value.onlineState = ma_userfriend.toOnlineState(value.data)
    end

    return RET_VAL.Succeed_1, {arr = retArr}
end

return ma_obj