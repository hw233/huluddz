local skynet = require "skynet"
local queue = require "skynet.queue"
local PendingQueue = queue()

local ma_data       = require "ma_data"
local ma_useritem   = require "ma_useritem"
local ma_userhero   = nil
local ma_userrune   = nil

local datax = require "datax"
local eventx = require "eventx"
local objx = require "objx"
local arrayx = require "arrayx"
local timex = require "timex"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"
local ec = require "eventcenter"
local common = require "common_mothed"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
--#endregion

local CMD, REQUEST_New = {}, {}
-- 后续写服务间调用接口时命名方式以 CMD_ 开头， 如 CMD_Open

local userInfo = ma_data.userInfo

local ma_obj = {
}


function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)
    

    ma_obj.initRequire()
    ma_obj.initListen()
end

ma_obj.initRequire = function ()
    ma_userhero   = require "ma_userhero"
    ma_userrune   = require "ma_userrune"
end


ma_obj.initListen = function ()
    eventx.listen(EventxEnum.UserOnline, function ()
        -- 为测试服处理
        -- if userInfo.diamond ~= ma_useritem.num(ItemID.Diamond) or userInfo.gold ~= ma_useritem.num(ItemID.Gold) then
        --     userInfo.diamond = ma_useritem.num(ItemID.Diamond)
        --     userInfo.gold = ma_useritem.num(ItemID.Gold)
        --     dbx.update(TableNameArr.User, userInfo.id, {diamond = userInfo.diamond, gold = userInfo.gold})
        -- end

        if userInfo.area == userInfo.openid then
            userInfo.area = nil
        end
 
        userInfo.winCountSum = userInfo.winCountSum or 0

    end, eventx.EventPriority.Before)

    eventx.listen(EventxEnum.UserNewDay, function ()
        ma_common.pushCollecter("UserDayLogin", os.time())

        userInfo.loginDays = userInfo.loginDays + 1
        userInfo.payDay = 0

        dbx.update(TableNameArr.User, userInfo.id, {loginDays = userInfo.loginDays, payDay = userInfo.payDay})
    end, eventx.EventPriority.Before)

    eventx.listen(EventxEnum.UserNewMonth, function ()
        userInfo.payMonth = 0

        dbx.update(TableNameArr.User, userInfo.id, {payMonth = userInfo.payMonth})
    end, eventx.EventPriority.Before)

    local valVersionKey = "2021.12.31 01:48"    -- 数值版本
    eventx.listen(EventxEnum.UserOnline, function ()
        if userInfo.lv <= 0 then
            userInfo.lv = 1
        end

        if userInfo.valVersionKey ~= valVersionKey then
            userInfo.valVersionKey = valVersionKey
            dbx.update(TableNameArr.User, userInfo.id, {valVersionKey = userInfo.valVersionKey})

            if userInfo.exp > 0 then
                userInfo.exp = userInfo.exp * 4
                ma_obj.computeLv()
            end
        end

        local ok, seasonData = pcall(skynet.call, "user_season", "lua", "GetSeasonData")
        if ok then
            ma_obj.checkTitleOver(seasonData)
        end
        ma_obj.computeLv()

    end, eventx.EventPriority.Before)

    eventx.listen(EventxEnum.UserOnline, function ()
        skynet.fork(function ()
            skynet.sleep(10)
            ma_obj.computePendingDataEvent()
        end)
        skynet.fork(function ()
            skynet.sleep(100)
            skynet.call("mail_manager", "lua", "ComputeMailGlobal", userInfo.id, userInfo.channel, userInfo.firstLoginDt)
        end)
    end, eventx.EventPriority.Before)

    eventx.listen(EventxEnum.UserItemUpdate, function (itemId, sData, nowNum, oldNum, changeVal)
        if itemId == ItemID.LvExp then
            ma_obj.computeLv()
        end
    end)

    eventx.listen(EventxEnum.UserUseTitle, function (args)
        ma_obj.SetTitle(args)
    end)

    ec.sub({type = "UserSeasonUpdate"}, function (event)
        ma_obj.checkTitleOver(event.data)
    end)

end


--#region 核心部分

--- 为写 CMD 指令时方便增加的， 其他地方不建议使用， 不然不好搜索
---@param key any
ma_obj.updateVal = function (key)
    dbx.update(TableNameArr.User, userInfo.id, { [key] = userInfo[key] })
end


ma_obj.computeLv = function ()
    local ok, err = pcall(function ()
        local oldLv = userInfo.lv

        local sData = datax.titleRewards[userInfo.lv]
        if not sData then
            return
        end

        if userInfo.exp < sData.exp then
            for i = oldLv, 0, -1 do
                sData = datax.titleRewards[i]
                userInfo.lv = sData.level
                if not sData or userInfo.exp >= sData.exp then
                    break;
                end
            end
        elseif userInfo.exp > sData.exp then
            local len = table.nums(datax.titleRewards)
            for i = oldLv + 1, len, 1 do
                sData = datax.titleRewards[i]
                if not sData or userInfo.exp < sData.exp then
                    break;
                end
                userInfo.lv = sData.level
            end
        end

        local sDataMax = table.max(datax.titleRewards, function (key, value)
            return value.level
        end)
        if userInfo.lv >= sDataMax.level - 1 then
            local ok, ret = pcall(skynet.call, "user_season", "lua", "UpdateUserExp", userInfo.id, userInfo.exp)
            if ok then
                local lv = ret and sDataMax.level or (sDataMax.level - 1)
                userInfo.lv = lv
            end
        end

        local updateData = {lv = userInfo.lv, exp = userInfo.exp}

        local oldlvMax = userInfo.lvMax or 0
        if not userInfo.expMax or userInfo.exp > userInfo.expMax then
            if (userInfo.lvMax or 0) < userInfo.lv then
                userInfo.lvMax = userInfo.lv
                updateData.lvMax = userInfo.lvMax
            end
            userInfo.expMax = userInfo.exp
            updateData.expMax = userInfo.expMax
        end

        local oldlvSeasonMax = userInfo.lvSeasonMax or 0
        if not userInfo.expSeasonMax or userInfo.exp > userInfo.expSeasonMax then
            if (userInfo.lvSeasonMax or 0) < userInfo.lv then
                userInfo.lvSeasonMax = userInfo.lv
                updateData.lvSeasonMax = userInfo.lvSeasonMax
            end
            userInfo.expSeasonMax = userInfo.exp
            updateData.expSeasonMax = userInfo.expSeasonMax
        end

        dbx.update(TableNameArr.User, userInfo.id, updateData)

        --刷新段位--天下第一
        local upBase = oldLv ~= userInfo.lv or userInfo.lvMax ~= oldlvMax or oldlvSeasonMax ~= userInfo.lvSeasonMax
        ma_obj.UpdateTianxiaDiyi(updateData, upBase)
    end)


    if not ok then
        skynet.loge("computeLv error!", err)
    end
end


ma_obj.UpdateTianxiaDiyi = function (updateData, upBase)
    if userInfo.lv ~= 38 then
        if upBase then
            ma_common.updateUserBase(userInfo.id, updateData)
        end

        if updateData then
            ma_common.send_myclient("SyncUserLv", updateData)
        end
        return
    end
    local myrank = skynet.call("ranklistmanager", "lua", "get_user_rankinfo",
        userInfo.id, "dw", type == RankType.Month, userInfo.nickname,userInfo.head, userInfo.headFrame)
    if myrank and myrank.rank <= 100 and  myrank.rank > 0 then
        userInfo.lv = 39
        local updateData = {lv = userInfo.lv}
        if userInfo.lvMax < userInfo.lv then
            userInfo.lvMax = userInfo.lv
            updateData.lvMax = userInfo.lvMax
        end
        if userInfo.lvSeasonMax < userInfo.lv then
            userInfo.lvSeasonMax = userInfo.lv
            updateData.lvSeasonMax = userInfo.lvSeasonMax
        end

        dbx.update(TableNameArr.User, userInfo.id, updateData)
        ma_common.updateUserBase(userInfo.id, updateData)
        ma_common.send_myclient("SyncUserLv", updateData)
        skynet.call("ranklistmanager", "lua", "update_dw", 
            userInfo.id, userInfo.nickname, userInfo.head, userInfo.headFrame, userInfo.exp, 0, userInfo.lv, 1)
    else
        if upBase then
            ma_common.updateUserBase(userInfo.id, updateData)
        end
        if updateData then
            ma_common.send_myclient("SyncUserLv", updateData)
        end
    end
end

ma_obj.checkTitleOver = function (seasonData)
    -- 重置段位及段位奖励
    if not userInfo.seasonId and userInfo.lv <= 1 then
        userInfo.seasonId = seasonData.id
        dbx.update(TableNameArr.User, userInfo.id, {seasonId = userInfo.seasonId})
    elseif userInfo.seasonId ~= seasonData.id then
        local sDataMax = table.max(datax.titleRewards, function (key, value)
            return value.level
        end)

        local oldSeasonId = userInfo.seasonId
        local oldLv = userInfo.lv
        if oldSeasonId and oldLv >= sDataMax.level then
            local ok, data = pcall(skynet.call, "user_season", "lua", "GetRankUser", oldSeasonId, userInfo.id)
            if ok and not data then
                oldLv = oldLv - 1
            end
        end
        local oldLvRewardRecord = userInfo.lvRewardRecord or {}
        local sDataOld = datax.titleRewards[oldLv]
        local sData = datax.titleRewards[sDataOld.end_lv]

        userInfo.seasonId = seasonData.id
        userInfo.lv = sData and sData.level or 1
        local oldExp = userInfo.exp or 0
        userInfo.exp = sData and sData.exp or 0
        local expadd = userInfo.exp - oldExp
        userInfo.lvSeasonMax = 1
        userInfo.expSeasonMax = 0
        ma_obj.computeLv()
        userInfo.lvRewardRecord = {}
        dbx.update(TableNameArr.User, userInfo.id, {seasonId = userInfo.seasonId, lvRewardRecord = userInfo.lvRewardRecord})
        
        local mailRewardArr = {}
        for i = 1, oldLv do
            sData = datax.titleRewards[i]
            if sData and next(sData.level_up_rewards) and not oldLvRewardRecord[tostring(sData.id)] then
                table.append(mailRewardArr, sData.level_up_rewards)
            end
        end
        if next(mailRewardArr) then
            ma_common.addMail(userInfo.id, 4, "段位奖励补发", {"1"}, mailRewardArr)
        end
        if next(sDataOld.rewards) then
            ma_common.addMail(userInfo.id, 5, "段位结算", {"1", sDataOld.name}, sDataOld.rewards)--TODO:需要补充赛季
        end

        skynet.timeout(200, function ()
            ma_common.send_myclient_sure("LvReset_C", {oldLv = oldLv, newLv = userInfo.lv, lvRewardRecord = userInfo.lvRewardRecord, 
                seasonId = seasonData.id, startDt = seasonData.startDt, endDt = seasonData.endDt})
        end)

        skynet.call("ranklistmanager", "lua", "update_dw", 
            userInfo.id, userInfo.nickname, userInfo.head, userInfo.headFrame, userInfo.exp, expadd, userInfo.lv, userInfo.lv-oldLv)
    end

    --刷新段位--天下第一
    ma_obj.UpdateTianxiaDiyi()
  
end


--- 重新计算加成
ma_obj.computeBonus = function ()
    ma_userhero.computeBonus()
    ma_userrune.computeBonus()
end


---添加对局记录（战绩）
---@param id string
---@param gameType number
---@param isWin boolean
---@param startDt number
---@param endDt number
---@param otherData table {playerType = nil, multiple = 0, cardType = ""}
ma_obj.addGameRecord = function (id, gameType, roomLevel, isWin, startDt, endDt, otherData)
    if not otherData.multiple then
        otherData.multiple = 0
    end

    local gameTypeStr = tostring(gameType)
    userInfo.roomGameCountObj = userInfo.roomGameCountObj or {}
    local roomGameCountObj = userInfo.roomGameCountObj[gameTypeStr] or {key = gameTypeStr, num = 0, obj = {}}
    userInfo.roomGameCountObj[gameTypeStr] = roomGameCountObj
    roomGameCountObj.num = roomGameCountObj.num + 1

    local roomLevelStr = tostring(roomLevel)
    roomGameCountObj.obj = roomGameCountObj.obj or {}
    roomGameCountObj.obj[roomLevelStr] = (roomGameCountObj.obj[roomLevelStr] or 0) + 1

    if isWin then
        userInfo.winCountSum = (userInfo.winCountSum or 0) + 1
        roomGameCountObj.winCountSum = (roomGameCountObj.winCountSum or 0) + 1
    end

    local arr = dbx.find(TableNameArr.UserGameRecord, {uId = userInfo.id}, nil, 20, {startDt = -1})
    local obj = {
        id = id,
        uId = userInfo.id,
        gameType = gameType,
        roomLevel = roomLevel,
        isWin = not not isWin,
        startDt = startDt,
        endDt = endDt,
        -- playerType = playerType,
        -- multiple = otherData.multiple, -- 几倍
    }
    table.merge(obj, otherData)
    dbx.add(TableNameArr.UserGameRecord, obj)

    table.insert(arr, obj)
    userInfo.winCountSum_20 = table.sum(arr, function (key, value)
        return value.isWin and 1 or 0
    end)
    userInfo.gameCountSum = (userInfo.gameCountSum or 0)+ 1

    dbx.update(TableNameArr.User, userInfo.id, {
        gameCountSum = userInfo.gameCountSum,
        winCountSum = userInfo.winCountSum,
        winCountSum_20 = userInfo.winCountSum_20,
        ["roomGameCountObj." .. gameType] = roomGameCountObj
    })

    ma_common.send_myclient("SyncUserRoomGame", {
        gameCountSum = userInfo.gameCountSum, 
        winCountSum = userInfo.winCountSum,  
        winCountSum_20 = userInfo.winCountSum_20
    })
end

---@param args any
---comment
ma_obj.UpdateFriendGiftAndNewApplyToDB = function (args)
    if not args or not args.uid then
        return
    end

    -- 写入数据库
    local updateData = {}
    if args.HasNewFriend ~= nil and updateData.HasNewFriend ~= args.HasNewFriend then
        updateData.HasNewFriend = args.HasNewFriend
    end

    if args.HasFriendGift ~= nil and updateData.HasFriendGift ~= args.HasFriendGift then
        updateData.HasFriendGift = args.HasFriendGift
    end

    if next(updateData) then
        dbx.update(TableNameArr.User, args.uid, updateData)
    end
end

--ma_common.toUserBase(uinfo)
ma_obj.UpdateSessionDuanwei = function (user_base_data)
    common.UpdateSessionDuanwei(dbx, user_base_data, "dw_up")
    -- if not user_base_data then
    --     return
    -- end
    
    -- local MinLv = DWLv_DouHuang_min
    -- local lv = user_base_data.lv
    -- if lv < MinLv then
    --     return
    -- end

    -- local sessionDWDataDB = dbx.find_one(TableNameArr.UserSessionDataRecord, user_base_data.id)
    -- local upFlag = false
    -- local IsFirst = false
    -- local sessionDWData = sessionDWDataDB or {}
    -- if sessionDWData.seasonId ~= sessionDWDataDB.seasonId then
    --     sessionDWData = {}
    --     sessionDWData.seasonId = sessionDWDataDB.seasonId
    --     upFlag = true
    -- end

    -- if not sessionDWData[lv] then
    --     sessionDWData[lv].num = 1
    --     sessionDWData[lv].lastAt = os.time()
    --     upFlag = true
    --     IsFirst = true
    -- else 
    --     sessionDWData[lv].num = sessionDWData[lv].num + 1
    --     sessionDWData[lv].lastAt = os.time()
    --     upFlag = true
    -- end

    -- if upFlag then
    --     local updateData = {sessionDWData = sessionDWData}
    --     dbx.update(TableNameArr.UserSessionDataRecord, user_base_data.id, updateData)

    --     if IsFirst then
    --         local rank = 0
    --         if lv >= DWLv_DouDi_min then
    --             local rank_data = common.get_user_rankinfo(user_base_data.id,"dw", true, user_base_data.nickname, user_base_data.head, user_base_data.headframe)
    --             if rank_data then
    --                 rank = rank_data.rank
    --             end
    --         end
    --         eventx.call(EventxEnum.DWAnnounce, {annId = AnnounceIdEm.GetDWAnnounceId(lv, rank)})
    --     end
    -- end
end

ma_obj.computePendingDataEvent = function (isDelayCheck)
    PendingQueue(function ()
        local arr = dbx.find(TableNameArr.UserPendingData, {id = userInfo.id})
        if #arr > 0 then
            local delDataArr = {}
            local groupObj = table.groupBy(arr, function (key, value)
                return value.type
            end)
            for _type, arr in pairs(groupObj) do
                arr = arrayx.orderBy(arr, function (obj)
                    return obj.dt
                end)
                eventx.call(EventxEnum.UserNewPendingData, _type, arr, delDataArr)
            end

            dbx.delMany(TableNameArr.UserPendingData, "_id", arrayx.select(delDataArr, function (index, value)
                return value._id
            end))
        elseif isDelayCheck then
            skynet.sleep(50)
            ma_obj.computePendingDataEvent()
        end
    end)
end

ma_obj.SetTitle = function (args)
    if not args then
        return RET_VAL.ERROR_3
    end

    if args.isUp then
        userInfo.title =  tonumber(args.id) or 0
    else 
        userInfo.title = 0
    end

    local updateData = {title = userInfo.title}
    dbx.update(TableNameArr.User, userInfo.id, updateData)
    ma_common.updateUserBase(userInfo.id, updateData)
    skynet.call("ranklistmanager", "lua", "update_cj",
        userInfo.id, userInfo.nickname, userInfo.head, userInfo.headFrame, 0, 0, userInfo.title)
    return RET_VAL.Succeed_1, updateData
end

CMD.PendingDataEvent = function (source)
    ma_obj.computePendingDataEvent(true)
end

CMD.SeasonLvUpdate = function ()
    
end


REQUEST_New.GetLvReward = function (args)
    local idArr = args.idArr
    if not idArr then
        return RET_VAL.ERROR_3
    end

    local lvRewardRecord = userInfo.lvRewardRecord
    if not lvRewardRecord then
        lvRewardRecord = {}
        userInfo.lvRewardRecord = lvRewardRecord
        dbx.update(TableNameArr.User, userInfo.id, { ["lvRewardRecord"] = lvRewardRecord })
    end

    for index, id in ipairs(idArr) do
        local sData = datax.titleRewards[id]
        if not sData then
            return RET_VAL.ERROR_3
        end

        if userInfo.lv < sData.level then
            if userInfo.lvSeasonMax < sData.level then
                return RET_VAL.Lack_6
            end
        end

        if not next(sData.level_up_rewards) then
            return RET_VAL.ERROR_3
        end

        if lvRewardRecord[tostring(id)] then
            return RET_VAL.Exists_4
        end
    end

    local sendDataArr = {}

    for index, id in ipairs(idArr) do
        local sData = datax.titleRewards[id]

        id = tostring(id)
        lvRewardRecord[id] = { key = id }
        dbx.update(TableNameArr.User, userInfo.id, { ["lvRewardRecord." .. id] = lvRewardRecord[id] })

        ma_useritem.addList(sData.level_up_rewards, 1, "GetLvReward_段位奖励", sendDataArr)
    end

    ma_common.showReward(sendDataArr)

    return RET_VAL.Succeed_1, { lvRewardRecord = lvRewardRecord }
end

REQUEST_New.GetGameRecordArr = function (args)
    local id = args.id
    if not id then
        id = userInfo.id
    end

    local num, maxNum = 5, 20

    local arr = dbx.find(TableNameArr.UserGameRecord, {uId = id}, nil, maxNum + 1, {startDt = -1})
    if #arr > maxNum then
        dbx.del(TableNameArr.UserGameRecord, {uId = id, startDt = {["$lte"] = arr[#arr].startDt}})
    end

    return {arr = arr}
end

REQUEST_New.GameRecordShowSet = function (args)
    userInfo.isCloseShowGameRecord = args.isCloseShowGameRecord

    local updateData = {isCloseShowGameRecord = userInfo.isCloseShowGameRecord}
    dbx.update(TableNameArr.User, userInfo.id, updateData)
    return updateData
end

REQUEST_New.SetGuideObj = function (args)
    if not args.key then
        return RET_VAL.ERROR_3
    end

    userInfo.guideObj = userInfo.guideObj or {}
    userInfo.guideObj[args.key] = args

    local updateData = {guideObj = userInfo.guideObj}
    dbx.update(TableNameArr.User, userInfo.id, updateData)

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.GuideRewardGet = function (args)
    if userInfo.guideRewardQQP == 1 then
        return RET_VAL.Fail_2
    end

    userInfo.guideRewardQQP = 1
    local updateData = {guideRewardQQP = userInfo.guideRewardQQP}
    dbx.update(TableNameArr.User, userInfo.id, updateData)

    local rewardInfo = {}
    local sendDataArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Default)
    ma_useritem.addList(datax.globalCfg[170001], 1, "GuideRewardGet_领取引导奖励", sendDataArr)

    updateData.reward = rewardInfo

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.GetUserBonusObj = function ()
    local ret = {}

    for key, value in pairs(userInfo.bonusObj) do
        ret[key] = objx.toKeyNumPair(value)
    end

    return ret
end

REQUEST_New.UserCDKReward = function (args)
    if not args then
        return RET_VAL.ERROR_3
    end
    args.uId = userInfo.id
    args.channel = userInfo.channel
    args.isNew = false
    local regitDate =  os.date("%Y%m%d", userInfo.firstLoginDt)
    local currentDate =  os.date("%Y%m%d")
    if regitDate == currentDate then
        args.isNew = true 
    end

    local errCode, rewardList = common.UserCDKReward(args)
    if errCode == RET_VAL.Succeed_1 then
        -- 加入背包
        local sendDataArr = {}
        ma_useritem.addList(rewardList, 1, "CDK领取", sendDataArr)
        ma_common.showReward(sendDataArr)
    end
    return errCode
end


return ma_obj