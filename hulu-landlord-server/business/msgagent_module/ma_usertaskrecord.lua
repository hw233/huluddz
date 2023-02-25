local skynet = require "skynet"
local ec = require "eventcenter"
local eventx = require "eventx"
local cardx  = require "cardx"

local ma_data       = require "ma_data"
local ma_usertask   = nil
local ma_userhero   = require "ma_userhero"

local objx = require "objx"
-- local create_dbx = require "dbx"
-- local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"
local util      = require "util.ddz_classic"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local userInfo = ma_data.userInfo

local ma_obj = {}

ma_obj.init =function ()
    ma_usertask = require "ma_usertask"

    ma_obj.inifListen()
end

ma_obj.inifListen = function ()

    eventx.listen(EventxEnum.UserNewDay, function ()
        ma_usertask.addVal(48, 1)
    end)

    eventx.listen(EventxEnum.AdvertLook, function ()
        ma_usertask.addVal(1, 1)

        ma_usertask.addVal(50, 1)
    end)

    eventx.listen(EventxEnum.UserGiftSend, function ()
        ma_usertask.addVal(2, 1)
    end)

    eventx.listen(EventxEnum.RoomGameStar, function (gameType)
        ma_usertask.addVal(3, 1)
        if gameType == GameType.SevenSparrow then
            ma_usertask.addVal(19, 1)
        elseif gameType == GameType.NoShuffle then
            ma_usertask.addVal(20, 1)
        end

        local skin = userInfo.skin or 0
        if HeroId.JiangDaohai == skin then
            ma_usertask.addVal(9, 1)
        end
    end)

    eventx.listen(EventxEnum.RoomGameDealCard, function (gameType, obj)
        local cards = obj.cards
        local c, v
        local kingNum = 0
        local flowerObj = {}
        local maxVal = 0
        local cardMap = {}
        for key, card in pairs(cards) do
            kingNum = kingNum + (cardx.isKing(card) and 1 or 0)
            c = cardx.getC(card)
            v = cardx.getV(card)
            flowerObj[c] = (flowerObj[c] or 0) + 1
            maxVal = math.max(maxVal, v)
            cardMap[v] = (cardMap[v] or 0) + 1
        end

        if gameType == GameType.SevenSparrow then
            if kingNum >= 4 then
                ma_usertask.addVal(65, 1)
            end
        elseif gameType == GameType.NoShuffle then
            if (cardMap[CardVal.V_A] or 0) >= 4 and (cardMap[CardVal.V_2]or 0) >= 4
                and (cardMap[CardVal.V_SJocker & 0x0f] or 0) >= 1 and (cardMap[CardVal.V_BJocker & 0x0f]or 0) >= 1 then
                    ma_usertask.addVal(66, 1)
            end

            if maxVal <= CardVal.V_9 then
                ma_usertask.addVal(70, 1)
            end

            if not flowerObj[CardColor.Spade] and not flowerObj[CardColor.Club] then
                ma_usertask.addVal(67, 1)
            elseif not flowerObj[CardColor.Hearts] and not flowerObj[CardColor.Diamond] then
                ma_usertask.addVal(68, 1)
            end
        end
    end)

    eventx.listen(EventxEnum.RoomPlayerMessage, function (source, name, args)
        if name == "RoomEmoticonSend_C" then
            if args.fromId == userInfo.id then
                ma_usertask.addVal(8, 1)
            end
        end
    end)

    eventx.listen(EventxEnum.RoomPlayerAction, function (gameType, type, playCardObj)
        if gameType == GameType.NoShuffle then
            if type == PlayerAction_DDZ.RobLandlord then
                ma_usertask.addVal(4, 1)
            elseif type == PlayerAction_DDZ.PlayCard then
                if playCardObj.type == util.CardType.zhadan then
                    ma_usertask.addVal(5, 1)
                    local bombType = util.getBombType(playCardObj.weight)
                    if string.find(bombType, "star") == 1 then
                        ma_usertask.addVal(6, 1)
                    end
                end
            end
        end
    end)

    eventx.listen(EventxEnum.RoomGameOver, function (gameType, eventObj)
        local playerData = eventObj.playerData
        if eventObj.isWin then
            ma_usertask.addVal(51, 1)
            if playerData.isLandlord then
                ma_usertask.addVal(58, 1)
            else
                ma_usertask.addVal(59, 1)
            end
        end

        if playerData.isLandlord then
            ma_usertask.addVal(36, 1)
        end

        if eventObj.isWin and playerData.playCardCount == 1 and #playerData.cards == 0 then
            ma_usertask.addVal(69, 1)
        end
    end)

    eventx.listen(EventxEnum.RoomGameOver, function (gameType, eventObj)
        if not eventObj then
            return
        end

        --清空对手3次
        if eventObj.playerDataOtherArr then
            for _, otherData in pairs(eventObj.playerDataOtherArr) do
                if otherData.tag == RoomPlayerOverTag.Broke then --破产
                    ma_usertask.addVal(32, 1)
                end
            end
        end

        --输赢任务进度更新
        if eventObj.goldChange > 0 then
            if eventObj.isWin then
                ma_usertask.addVal(57, eventObj.goldChange)
            end
            if eventObj.goldChange >= 5000000000 then
                if eventObj.isWin then
                    ma_usertask.addVal(63, 1)
                else
                    ma_usertask.addVal(61, 1)
                end
                if eventObj.goldChange >= 10000000000 then
                    if eventObj.isWin then
                        ma_usertask.addVal(64, 1)
                    else
                        ma_usertask.addVal(62, 1)
                    end
                end
            end
        end

        if (eventObj.playerData.multiple or 0) > 100000 then
            ma_usertask.addVal(60, 1)
        end

        if eventObj.roomMultiple  then
            if eventObj.roomMultiple.springReverse then
                if tonumber(eventObj.roomMultiple.springReverse.value) == 2 then --反春天 
                    if eventObj.isWin then --反春天
                        ma_usertask.addVal(52, 1)
                    else --被反春天
                        ma_usertask.addVal(53, 1)
                    end
                end
            end
        end

        if eventObj.playerData.tag == RoomPlayerOverTag.Broke then
            ma_usertask.addVal(71, 1)
        end
    end)

    eventx.listen(EventxEnum.RoomGameReward, function (gameType, roomLevel, rewardArr)
        skynet.logd("RoomGameReward 2")--临时记录查bug
        for index, itemObj in ipairs(rewardArr) do
            if itemObj.id == ItemID.GourdWater then
                ma_usertask.addVal(14, itemObj.num)
            elseif itemObj.id == ItemID.RuneExp then
                ma_usertask.addVal(15, itemObj.num)
            end
        end
        skynet.logd("RoomGameReward 2")--临时记录查bug
    end)

    eventx.listen(EventxEnum.RoomGameTake_QQP, function (eventArr)
        if eventArr then
            for key, value in pairs(eventArr) do
                ma_usertask.addVal("qqp_" .. value, 1)
            end
        end
    end)

    eventx.listen(EventxEnum.RoomGameHu_QQP, function (cardtype, multiple, eventArr)
        ma_usertask.addVal(41, 1)

        ma_usertask.addVal("qqp_" .. cardtype, 1)
        for key, value in pairs(eventArr) do
            ma_usertask.addVal("qqp_" .. value, 1)
        end
    end)

    ec.sub({type = EventCenterEnum.HeroSkillUse, id = userInfo.id}, function (eventObj)
        ma_usertask.addVal(10, 1)
    end)

    ec.sub({type = EventCenterEnum.RoomGameSpring, id = userInfo.id}, function (eventObj)
        ma_usertask.addVal(7, 1)
    end)


    --{type = EventCenterEnum.RoomGameDouble, id = self.id, doubleAction = self.doubleAction, doubleMultiple = self.doubleMultiple}
    ec.sub({type = EventCenterEnum.RoomGameDouble, id = userInfo.id}, function (eventObj)
        if eventObj.doubleAction == PlayerAction_DDZ.Double_2 then
            ma_usertask.addVal(37, 1)
        elseif eventObj.doubleAction == PlayerAction_DDZ.Double_4 then
            ma_usertask.addVal(38, 1)
        end
    end)

    ec.sub({type = EventCenterEnum.RoomGameDoubleMax, id = userInfo.id}, function (eventObj)
        if eventObj.doubleMaxAction == PlayerAction_DDZ.DoubleMax then
            ma_usertask.addVal(39, 1)
        end
    end)

    -- 延后到重置后再添加
    eventx.listen(EventxEnum.UserOnline, function (sData, uData)
        ma_usertask.setVal(21, table.nums(ma_userhero.getDatas()))
    end, eventx.EventPriority.After)

    eventx.listen(EventxEnum.UserHeroAdd, function (sData, uData)
        if uData.notLimit then
            ma_usertask.addVal(21, 1)
        end
    end)

    eventx.listen(EventxEnum.HeroSkillUp, function (uData)
        ma_usertask.addVal(12, 1)
    end)

    eventx.listen(EventxEnum.HeroMoodUp, function (uData)
        if uData.moodLv >= 3 then
            ma_usertask.addVal(11, 1)
        end
    end)

    eventx.listen(EventxEnum.RuneAdd, function (sData, uData)
        ma_usertask.addVal(22, 1)

        if sData.rune_quality == 5 then
            ma_usertask.addVal(24, 1)
        elseif sData.rune_quality == 4 then
            ma_usertask.addVal(25, 1)
        elseif sData.rune_quality == 3 then
            ma_usertask.addVal(26, 1)
        elseif sData.rune_quality == 2 then
            ma_usertask.addVal(27, 1)
        end
    end)

    eventx.listen(EventxEnum.RuneLvUp, function (uData, num)
        ma_usertask.addVal(17, num)

        if uData.lv > ma_usertask.getVal(23) then
            ma_usertask.setVal(23, uData.lv)
        end
    end)

    eventx.listen(EventxEnum.UserPay, function (num)
        ma_usertask.addVal(18, math.ceil(num/100))
    end)

    eventx.listen(EventxEnum.GourdWatering, function (num)
        ma_usertask.addVal(13, 1)

        ma_usertask.addVal(29, num)
    end)

    eventx.listen(EventxEnum.GourdFertilizer, function (addNum)
        ma_usertask.addVal(34, 1)
        ma_usertask.addVal(35, addNum)
    end)

    eventx.listen(EventxEnum.GourdLoosenSoil, function ()
        ma_usertask.addVal(31, 1)
    end)

    eventx.listen(EventxEnum.GourdPickFruit, function (is_self)
        if is_self == nil then
            return
        end

        if is_self then
            ma_usertask.addVal(33, 1)
        else 
            ma_usertask.addVal(30, 1)
        end
    end)

    eventx.listen(EventxEnum.TaskReward, function (taskId)
        if not taskId then
            return
        end
        ma_usertask.getItem(taskId)
    end)

    eventx.listen(EventxEnum.UserRq, function ()
        ma_usertask.addVal(54, 1)
    end)

    eventx.listen(EventxEnum.UserDz, function ()
        ma_usertask.addVal(55, 1)
    end)

    eventx.listen(EventxEnum.UserBDz, function ()
        ma_usertask.addVal(65, 1)
    end)

    eventx.listen(EventxEnum.UserLoginContinue, function (num)
        ma_usertask.setVal(49, num)
    end)

    eventx.listen(EventxEnum.UserConWinOrLose, function (isWin, num)
        if isWin then
            ma_usertask.setVal(72, num)
        else
            ma_usertask.setVal(73, num)
        end
    end)
    
end


return ma_obj