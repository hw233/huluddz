local skynet    = require "skynet"
local cjson     = require "cjson"

local ma_data           = require "ma_data"
local ma_user 			= require "ma_user"
local ma_userroom       = require "ma_userroom"
local ma_useritem       = require "ma_useritem"
local ma_userfriend     = require "ma_userfriend"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local eventx = require "eventx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
--#endregion

local REQUEST_New, CMD = {}, {}
local PlayerToRoomMessagePre = {} -- 玩家发送到房间的消息提前处理
local PlayerToRoomMessageAfter = {} -- 玩家发送到房间的消息返回后处理
local RoomToPlayerMessagePre = {} -- 房间发送到玩家的消息提前处理

local userInfo = ma_data.userInfo

local ma_obj = {
    CallRoomRequestNameArr = {
        mute = "mute",
        ssw_room_info = "ssw_room_info",
        ssw_card_recorder = "ssw_card_recorder",
        ssw_exit = "ssw_exit",
    },
    SendRoomRequestNameArr = {
        game_report = "game_report",
        trusteeship = "trusteeship",
        cancel_trusteeship = "cancel_trusteeship",
        GameChat = "GameChat",

        ssw_takecard = "ssw_takecard",
        ssw_playcard = "ssw_playcard",
        ssw_hu = "ssw_hu",
        ssw_giveup = "ssw_giveup",
    },
    PlayerToRoomMessagePre = PlayerToRoomMessagePre,
    PlayerToRoomMessageAfter = PlayerToRoomMessageAfter,
    RoomToPlayerMessagePre = RoomToPlayerMessagePre,

}


function ma_obj.init(cmd, request_new)
    for key, value in pairs(ma_obj.CallRoomRequestNameArr) do
        ma_userroom.addRequestHander(REQUEST_New, key, value, skynet.call, ma_obj.requestHanderPre, ma_obj.requestHanderAfter)
    end

    for key, value in pairs(ma_obj.SendRoomRequestNameArr) do
        ma_userroom.addRequestHander(REQUEST_New, key, value, skynet.send, ma_obj.requestHanderPre)
    end

    table.tryMerge(request_new, REQUEST_New)
    table.tryMerge(cmd, CMD)

    ma_obj.initLinsten()
end

ma_obj.initLinsten = function ()
    eventx.listen(EventxEnum.RoomPlayerMessage, function (source, name, args)
        local func = RoomToPlayerMessagePre[name]
        if func then
            func(args)
        end
    end)
end


--#region 核心部分

ma_obj.requestHanderPre = function (mothedName, args)
    local func = PlayerToRoomMessagePre[mothedName]
    if func then
        return func(args)
    end
end

ma_obj.requestHanderAfter = function (mothedName, result)
    local func = PlayerToRoomMessageAfter[mothedName]
    if func then
        return func(result)
    end
end

--#endregion


PlayerToRoomMessageAfter.ssw_room_info = function (result)
    ma_data.roomConnect = true
end

RoomToPlayerMessagePre.ssw_match_ok = function (args)
    ma_userroom.roomGameRecordStart(args.room.conf.gametype, args.room.conf.roomtype)

    eventx.call(EventxEnum.RoomGameStar, GameType.SevenSparrow)
end

RoomToPlayerMessagePre.ssw_gamestart = function (args)
    if args.players then
        for key, player in pairs(args.players) do
            if player.id == userInfo.id then
                eventx.call(EventxEnum.RoomGameDealCard, GameType.SevenSparrow, {cards = player.cards})
            end
        end
    end
end

RoomToPlayerMessagePre.ssw_please_recharge = function (args)
    if args.pid == userInfo.id then
        eventx.call(EventxEnum.RoomGameLostGold, args.goldBrokeLast)
	end
end

RoomToPlayerMessagePre.ssw_p_exit = function (args)
	if args.pid == userInfo.id then
        local overInfo = args.overInfo
        if overInfo then
            ma_obj.gameOver(overInfo)
        end
	end
    args.overInfo = nil
end

RoomToPlayerMessagePre.ssw_p_takecard = function (args)
    if args.pid == userInfo.id then
		eventx.call(EventxEnum.RoomGameTake_QQP, args.eventArr)
	end
end

RoomToPlayerMessagePre.ssw_p_hu = function (args)
	if args.pid == userInfo.id then
		eventx.call(EventxEnum.RoomGameHu_QQP, args.cardtype, args.multiple, args.eventArr)
	end
end

RoomToPlayerMessagePre.ssw_gameover = function (args)
    ma_obj.gameOver(args)
end

ma_obj.gameOver = function (args)
    ma_userroom.exitRoom()

    local roomInfo = args.roomInfo

    local sData = datax.roomGroup[roomInfo.gameType][roomInfo.roomLevel]
    local playerData = table.first(args.datas, function (key, value)
		return value.id == userInfo.id
	end)
    if not sData or not playerData then
        skynet.loge("ssw_gameover error!")
        return
    end

	local isWin = playerData.goldChange >= 0

    local info = args.info or {}
	args.info = info

	info.isWin = isWin
	info.lvOld = userInfo.lv
	info.expOld = userInfo.exp
    info.rewardInfo = {}
    info.lvExpAddRateObj = nil
    info.rewardLimitFrom = nil

    -- 普通奖励
    local rewardArr, runeAddItemArr, moodAddItemArr = {}, {}, {}
    local from = string.format("RoomGameOver_%s_%s_对局结算", roomInfo.gameType, roomInfo.roomLevel)
    if isWin then
        table.append(rewardArr, table.clone(sData.reward))
    else
        table.append(rewardArr, table.clone(sData.rewardFail))
    end

    info.rewardLimitFrom = ma_userroom.gameRewardHandler(sData, isWin, rewardArr, runeAddItemArr, moodAddItemArr)

    local sendDataArr = ma_common.getShowRewardArr(info.rewardInfo, ShowRewardFrom.Default)
    ma_useritem.addList(rewardArr, 1, from, sendDataArr)

    if next(moodAddItemArr) then
        local moodRewardArr = ma_common.getShowRewardArr(info.rewardInfo, ShowRewardFrom.Mood)
        ma_useritem.addList(moodAddItemArr, 1, from, moodRewardArr)
    end

    table.append(rewardArr, moodAddItemArr)
    eventx.call(EventxEnum.RoomGameReward, roomInfo.gameType, roomInfo.roomLevel, rewardArr)


    info.lvExpAddRateObj, info.lvExpProtect = ma_userroom.gameLvCompute(isWin, from, sendDataArr)

	info.lv = userInfo.lv
	info.exp = userInfo.exp

    ma_userroom.lastDeductExp = info.expOld - userInfo.exp
    ma_userroom.lastDeductExp = ma_userroom.lastDeductExp > 0 and ma_userroom.lastDeductExp or 0
    
    -- 更新段位排行榜
    local expadd = userInfo.exp - info.expOld
    skynet.call("ranklistmanager", "lua", "update_dw", 
        userInfo.id, userInfo.nickname, userInfo.head, userInfo.headFrame, userInfo.exp, expadd, userInfo.lv, userInfo.lv-info.lvOld)
    if expadd > 0 then
        if userInfo.lv-info.lvOld > 0 and userInfo.lv == userInfo.lvSeasonMax  then
            ma_user.UpdateSessionDuanwei(ma_common.toUserBase(userInfo))
        end
    end

	ma_user.addGameRecord(roomInfo.id, roomInfo.gameType, roomInfo.roomLevel, isWin, roomInfo.startDt, roomInfo.endDt, {
        cardType = playerData.cardTypeMax,
        multiple = playerData.multipleMax,
        goldSum = playerData.goldChange,
    })

    ma_userroom.roomGameRecordEnd(roomInfo.id, userInfo.id, roomInfo.startDt, roomInfo.endDt, isWin)

    local arr = table.where(args.datas, function (key, value)
        return value.id ~= userInfo.id
    end)
    ma_userfriend.addRecentGameFriend(table.select(arr, function (key, value)
        return {
            id          = value.id,
            data        = value.data,
            playerType  = 0
        }
    end), roomInfo.gameType, roomInfo.roomLevel, roomInfo.startDt)

    if not isWin then
        local goldBrokeLast = math.abs(playerData.goldBrokeLast or 0)
        if goldBrokeLast > 0 then
            eventx.call(EventxEnum.RoomGameLostGold, goldBrokeLast)
        end
    end

    local eventObj = {
        gameType            = roomInfo.gameType,
        roomLevel           = roomInfo.roomLevel,
        heroId              = playerData.heroId,
        isWin               = isWin,
        goldChange          = math.abs(playerData.goldChange),
        playerData          = playerData,
        playerDataOtherArr  = arr,
    }
    eventx.call(EventxEnum.RoomGameOver, roomInfo.gameType, eventObj)
end


return ma_obj