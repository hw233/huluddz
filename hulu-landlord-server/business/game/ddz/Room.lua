local skynet = require "skynet"
local ec = require "eventcenter"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local common = require "common_mothed"

local util = require "util.ddz_classic"
require "roomEnum"
local roomData = require "roomData"
roomData.setGameType(GameType.NoShuffle)
local helper = require "game.ddz3.helper"
local Player = require "game.ddz.Player"
local matchserver = false


local roomObj = {
    id = nil,
    startDt = nil,
    endDt = nil,
    conf = nil,
    cfgData = nil,
    state = RoomState_DDZ.Readying,
    players = {},
    bottomCards = {},
    dealCardCount = 0, -- 发牌次数， 每局最多重新发牌3次

    actionIndex = 1, -- 当前活动玩家索引

    firstId = nil, -- 首出id

    multiple = {
		init = 1,
		showCard = 1, 				-- 明牌
        callLandlord = 1,           -- 叫地主
		robLandlord = 1, 			-- 抢地主
		bottomCard = 1,				-- 底牌
		bomb = 1, 					-- 炸弹
		spring = 1, 				-- 春天
		springReverse = 1, 			-- 反春天
        skill = 1,                  -- 技能
	},

    firstCallLandlordPlayer = nil,
    landlordPlayer = nil,
}

local RoomExtend = require "game.ddz.RoomExtend"
RoomExtend(roomObj)

roomObj.init = function (id, conf, players)
    roomObj.id = id
    roomObj.startDt = os.time()
    roomObj.conf = conf

    roomObj.newUserCardCfgIdArr = table.first(players, function (key, value)
        return value.newUserCardCfgIdArr
    end)
    roomObj.newUserCardCfgIdArr = roomObj.newUserCardCfgIdArr and roomObj.newUserCardCfgIdArr.newUserCardCfgIdArr or nil
    roomObj.newUserCardCfg  = nil

    roomObj.cfgData = datax.roomGroup[conf.gametype][conf.roomtype]
    roomObj.init = roomObj.cfgData.room_ratio

	if matchserver then
        skynet.loge("matchserver not allowed!!")
        for index, player in ipairs(players) do
            roomObj.players[player.fixed_chair] = Player.new(roomObj, player, player.fixed_chair)
        end
	else
        for index, player in ipairs(players) do
            roomObj.players[index] = Player.new(roomObj, player, index)
        end
	end

    roomObj.action(RoomState_DDZ.ReadyOk)

	roomObj.action(RoomState_DDZ.DealCard)
end

roomObj.dealCard = function ()
    roomObj.dealCardCount = roomObj.dealCardCount + 1
    roomObj.multiple.showCard = 1
    roomObj.multiple.callLandlord = 1
    roomObj.multiple.robLandlord = 1

    roomObj.newUserCardCfg = roomObj.newUserCardCfgIdArr and datax.init_cards[roomObj.conf.gametype][roomObj.newUserCardCfgIdArr[math.random(1, table.nums(roomObj.newUserCardCfgIdArr))]]

    local cards_1, cards_2, cards_3, bottomCards, firstId = helper.dealcard(roomObj.conf.gametype, roomObj.players[1].gamec, roomObj.players, roomObj.newUserCardCfg)
    roomObj.bottomCards = bottomCards
    roomObj.players[1]:dealCard(cards_1)
    roomObj.players[2]:dealCard(cards_2)
    roomObj.players[3]:dealCard(cards_3)

    roomObj.firstId = firstId
end

roomObj.setLandlord = function (player, delayTime)
    roomObj.landlordPlayer = player
    player:setLandlord()

    if roomObj.newUserCardCfg then
        roomObj.sendToAgentAll("NewUserCardCfgUse", roomObj.newUserCardCfg.id)
    end

    if delayTime then
        skynet.sleep(delayTime)
    end

    local multiple = helper.getBottomCardMultiple(roomObj.bottomCards)
    roomObj.addMultiple(RoomMultipleKey.BottomCard, multiple, player.id)
    roomObj.sendToPlayerAll("RoomLandlordSet_C", {id = player.id, bottomCards = roomObj.bottomCards, multiple = multiple})

    skynet.sleep(roomData.getRoomDelayTime("SetLandlordWaite"))

    roomObj.action(RoomState_DDZ.Doubleing, player)
end


roomObj.action = function (state, player)
    roomObj.state = state
    if player then
        roomObj.setActionPlayerIndex(player.pos)
    else
        player = roomObj.getActionPlayer()
    end

    if state == RoomState_DDZ.ReadyOk then
        for index, player in ipairs(roomObj.players) do
            player:setActionState(PlayerState_DDZ.ReadyOk)
        end
    elseif state == RoomState_DDZ.DealCard then
        roomObj.dealCard()
        for index, player in ipairs(roomObj.players) do
            player:setActionState(PlayerState_DDZ.DealCard)

            if arrayx.findVal(player.skillCfg.game_id, roomObj.conf.gametype) and math.random(1, 10000) <= player.heroSkillRate then
                player.skillState = true
                roomObj.sendToPlayerAll("RoomSyncPlayerData_C", {id = player.id, skillState = player.skillState})
            end
        end

        -- 明牌开始 * 5
        -- for _,p in ipairs(self.players) do
        --     if p.showcardx5 then
        --         p.is_showcard = true
        --         self:radio("p_showcard", {pid = p.id, cards = p.cards})
        --         self.multiple.showcard = self.multiple.showcard * 5
        --         self:sync_multiple()
        --     end
        -- end

        skynet.timeout(roomData.getRoomDelayTime("DealCardWaite"), function ()
            for _, player in ipairs(roomObj.players) do
                player:setActionState(PlayerState_DDZ.Waiting)
            end

            -- 得到首发玩家
            local arr = roomObj.players

            -- local showcardx5_players = {}
            -- for i, p in ipairs(roomObj.players) do
            --     if p.showcardx5 then
            --         table.insert(showcardx5_players, p)
            --     end
            -- end
            -- if #showcardx5_players > 0 then
            --     arr = showcardx5_players
            -- end

            local current = arr[math.random(1, #arr)]
            if roomObj.firstId then
                local firstPlayer = arrayx.find(arr, function (index, value)
                    return value.id == roomObj.firstId
                end)
                if firstPlayer then
                    current = firstPlayer
                end
            end
            roomObj.action(RoomState_DDZ.CallLandlord, current)
        end)

    elseif state == RoomState_DDZ.CallLandlord then
        player:setActionState(PlayerState_DDZ.CallLandlord)
    elseif state == RoomState_DDZ.RobLandlord then
        player:setActionState(PlayerState_DDZ.RobLandlord)
    elseif state == RoomState_DDZ.Doubleing then
        for index, player in ipairs(roomObj.players) do
            player:setActionState(PlayerState_DDZ.Doubleing)
        end
    elseif state == RoomState_DDZ.DoubleMax then
        for index, player in ipairs(roomObj.players) do
            player:setActionState(PlayerState_DDZ.DoubleMax)
        end
    elseif state == RoomState_DDZ.Playing then
        if not roomObj.lastPlayCardObj then
            player:setPlayCardState(PlayCardState_DDZ.First)
        else
            player:setPlayCardState(player.id == roomObj.lastPlayCardObj.id and PlayCardState_DDZ.Play or PlayCardState_DDZ.Normal)
        end
        player:setActionState(PlayerState_DDZ.Playing)
    elseif state == RoomState_DDZ.Ended then
        -- 春天
        if player.isLandlord then
            local arr = roomObj.getFarmerArr()
            if not table.first(arr, function (key, value)
                return value.playCount > 0
            end) then
                roomObj.addMultiple(RoomMultipleKey.Spring, nil, player.id)
                ec.pub({type = EventCenterEnum.RoomGameSpring, id = player.id})
            end
        else
            if roomObj.landlordPlayer.playCount == 1 then
                roomObj.addMultiple(RoomMultipleKey.SpringReverse, nil, player.id)
            end
        end

        roomObj.gameover(player)
    end
end

roomObj.actionEnd = function (player, actionType)
    local state = roomObj.state
    roomObj.setActionPlayerIndex(player.pos)

    if state == RoomState_DDZ.CallLandlord then
        local nextPlayer = roomObj.getActionPlayerNext()
        if player.lastAction == PlayerAction_DDZ.CallLandlord then
            roomObj.firstCallLandlordPlayer = player -- 第一个叫地主的Player

            if nextPlayer.lastAction == nil then
                roomObj.action(RoomState_DDZ.RobLandlord, nextPlayer)
            else
                -- 如果前2人没有抢地主，直接进入加倍阶段
                roomObj.setLandlord(player)
            end
        else
            if nextPlayer.lastAction == nil then
                roomObj.action(RoomState_DDZ.CallLandlord, nextPlayer)
            elseif roomObj.dealCardCount >= 3 then
                -- TODO：第三轮都不叫，直接设置第一家为地主
                roomObj.setLandlord(nextPlayer)
            else
                -- local showcardx5_player = self.room:find_an_showcardx5_player()
                -- if showcardx5_player then
                --     self.room:game_start_double(showcardx5_player)
                -- else
                --     self.room:game_start_dealcard()
                -- end
                roomObj.action(RoomState_DDZ.DealCard)
            end
        end
    elseif state == RoomState_DDZ.RobLandlord then
		if roomObj.conf.gametype == GameType.NoShuffle then
            local nextPlayer = roomObj.getActionPlayerNext()
            if not nextPlayer.lastAction then
                roomObj.action(RoomState_DDZ.RobLandlord, nextPlayer)
            else
                local lastLastAction = player.actionQueue[#player.actionQueue - 1]
                if (lastLastAction == PlayerAction_DDZ.CallLandlord or lastLastAction == PlayerAction_DDZ.RobLandlord) and actionType == PlayerAction_DDZ.RobLandlord then
                    -- 霸王抢 叫地主后被别人抢地主，然后叫地主的再次抢地主进入霸王抢地主阶段
                    -- roomObj.action(RoomState_DDZ.RobLandlord)

                    -- 临时做法，直接设置为地主
                    roomObj.setLandlord(player)
                else
                    for i = 1, 10 do
                        if nextPlayer.lastAction == PlayerAction_DDZ.NotCall or nextPlayer.lastAction == PlayerAction_DDZ.NotRob then
                            roomObj.setActionPlayerIndex(nextPlayer.pos)
                            nextPlayer = roomObj.getActionPlayerNext()
                        else
                            break;
                        end
                    end
    
                    if nextPlayer == player then
                        roomObj.setLandlord(player)
                    else
                        local arr = arrayx.where(roomObj.players, function (i, value)
                            return value.lastAction == PlayerAction_DDZ.CallLandlord or value.lastAction == PlayerAction_DDZ.RobLandlord
                        end)
                        local len = #arr
                        if len <= 0 then
                            skynet.loge("RobLandlord error!")
                        end
    
                        if len == 1 then
                            roomObj.setLandlord(arr[1])
                        else
                            roomObj.action(RoomState_DDZ.RobLandlord, nextPlayer)
                        end
                    end
                end
            end
		end
    elseif state == RoomState_DDZ.Doubleing then
        local isEnd = not table.first(roomObj.players, function (key, value)
            return not value.doubleMultiple
        end)
        if isEnd then
            skynet.fork(function ()
                skynet.sleep(roomData.getRoomDelayTime("DoubleingWaite"))
                roomObj.action(RoomState_DDZ.DoubleMax)
			end)
        end
    elseif state == RoomState_DDZ.DoubleMax then
        local isEnd = not table.first(roomObj.players, function (key, value)
            return not value.doubleMaxMultiple
        end)
        if isEnd then
            skynet.fork(function ()
				skynet.sleep(roomData.getRoomDelayTime("DoubleMaxWaite"))
                roomObj.action(RoomState_DDZ.Playing, roomObj.landlordPlayer)
			end)
        end
    elseif state == RoomState_DDZ.Playing then
        if #player.cards == 0 then
            skynet.timeout(20, function ()
                roomObj.action(RoomState_DDZ.Ended, player)
            end)
        else
            skynet.sleep(50)
            local nextPlayer = roomObj.getActionPlayerNext()
            nextPlayer:setPlayCardState(nextPlayer.id == roomObj.lastPlayCardObj.id and PlayCardState_DDZ.Play or PlayCardState_DDZ.Normal)
            roomObj.action(RoomState_DDZ.Playing, nextPlayer)
        end
    end
end

roomObj.actionStopAll = function ()
    for index, player in ipairs(roomObj.players) do
        player:clearClock()
        player:setActionState(PlayerState_DDZ.Waiting)
    end
end

roomObj.playerRequest = function (id, name, args)
    local player = roomObj.getPlayer(id)
    local func = player[name]
    local result = func(player, args)

    if result then
        skynet.logd("RoomPlayerRequest : ", result, id, name, player.state)
    end

    return result
end

roomObj.sendToPlayerAll = function (name, args)
    for index, player in ipairs(roomObj.players) do
        player:sendToPlayer(name, args)
    end
end

roomObj.sendToAgentAll = function (name, args)
    for index, player in ipairs(roomObj.players) do
        player:sendToAgent(name, args)
    end
end

roomObj.addMultiple = function (multipleKey, multipleVal, id)
    multipleVal = multipleVal or roomData.multipleInfo[multipleKey]
    if roomObj.multiple[multipleKey] then
        roomObj.multiple[multipleKey] = roomObj.multiple[multipleKey] * multipleVal
    end
    roomObj.syncMultiple(multipleKey, multipleVal, id)
end

roomObj.syncMultiple = function (multipleKey, multipleVal, id)
	for _, player in ipairs(roomObj.players) do
		player:syncMultiple(multipleKey, multipleVal, id)
	end
end

roomObj.gameover = function (winPlayer)

    roomObj.endDt = os.time()

    local rewardMax = roomObj.cfgData.capped_num < 0 and roomObj.cfgData.capped_num or roomObj.getMultipleMax()

    --#region

    local datas, landlord, farmers = {}, nil, {}
    for _, player in ipairs(roomObj.players) do
        local multiple = player:getMultiple()
        local isWin = player.isLandlord == winPlayer.isLandlord
        local data = {
            id = player.id,
            data = common.toUserBase(player.userObj),

            multiple = multiple,
            cards = player.cards,
            isWin = isWin,
            isLast = player.id == winPlayer.id,
            isLandlord = player.isLandlord,
            playCardCount = player.playCardCount,

            gold = player.userObj.gold,
            goldChange = 0,
            goldBrokeLast = 0,
            tag = RoomPlayerOverTag.Default,

            doubleMultiple = (player.doubleMultiple or 1) * (player.doubleMaxMultiple or 1),
            doubleAction = player.doubleAction,
            doubleMaxAction = player.doubleMaxAction,

            heroId = player.userObj.heroId,
        }
		datas[player.id] = data

        if player.isLandlord then
            landlord = data
        else
            farmers[player.id] = data
        end
	end

    local goldChangeSum = 0
    for key, farmer in pairs(farmers) do
        farmer.goldBase = roomObj.cfgData.difen * farmer.multiple
        farmer.goldOld = farmer.gold
        farmer.goldMax = rewardMax
        --farmer.goldReal = objx.round(landlord.gold * farmer.multiple / landlord.multiple)
        farmer.goldRealNum = landlord.gold / landlord.multiple * farmer.multiple
        farmer.goldReal = math.floor(farmer.goldRealNum) -- 策划说改为向下取整，给地主留一颗豆子，解决0.5颗豆子四舍五入的问题   后续这颗豆子给系统吃掉

        --farmer.goldChange = math.min(farmer.goldBase, rewardMax < 0 and farmer.goldBase or rewardMax, farmer.isWin and farmer.goldReal or farmer.gold)
        farmer.goldChange = math.min(farmer.goldBase, rewardMax < 0 and farmer.goldBase or rewardMax, farmer.goldReal, farmer.gold)
        goldChangeSum = goldChangeSum + farmer.goldChange

        if farmer.goldChange == rewardMax then
            farmer.tag = RoomPlayerOverTag.Max
        end

        if not farmer.isWin and farmer.goldChange == farmer.goldOld then
            farmer.tag = RoomPlayerOverTag.Broke
        end

        farmer.goldChange = farmer.goldChange * (farmer.isWin and 1 or -1)
        farmer.gold = farmer.gold + farmer.goldChange
    end

    -- 系统吃掉1颗豆子
    if not landlord.isWin and (landlord.gold - goldChangeSum == 1) then
        local goldRealNumSum = math.ceil(table.sum(farmers, function (key, value)
            return value.goldRealNum
        end))
        if goldRealNumSum >= landlord.gold then
            if goldRealNumSum - landlord.gold > 1 then
                skynet.loge("ddz gameover error!", datas)
            end
            goldChangeSum = goldChangeSum + 1
        end
    end

    landlord.goldOld = landlord.gold
    landlord.goldChange = goldChangeSum * (landlord.isWin and 1 or -1)
    landlord.gold = landlord.gold + landlord.goldChange

    local tag = RoomPlayerOverTag.Default
    if not table.first(farmers, function (key, value)
        return value.tag ~= RoomPlayerOverTag.Max
    end) then
        tag = RoomPlayerOverTag.Max
    end
    if not landlord.isWin and landlord.gold <= 1 then
        tag = RoomPlayerOverTag.Broke
    end
    landlord.tag = tag


    for key, data in pairs(datas) do
        if not data.isWin then
            data.goldBrokeLast = data.goldChange
        end
    end

    --#endregion

    local roomMultiple = table.toObject(roomObj.multiple, nil, function (key, value)
        return {key = key, value = tostring(value)}
    end)

    roomObj.sendToPlayerAll("RoomGameOver_C", {
        roomInfo = {
            id          = roomObj.id,
            gameType    = roomObj.cfgData.game_id,
            roomLevel   = roomObj.cfgData.room_type,
            startDt     = roomObj.startDt,
            endDt       = roomObj.endDt,
        },
        datas = datas,
        roomMultiple = roomMultiple,
    })

    skynet.call("ddz_room_mgr", "lua", "room_exit", roomObj.id)
    skynet.exit()
end

return roomObj