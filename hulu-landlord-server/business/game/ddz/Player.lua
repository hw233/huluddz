local skynet = require "skynet"
local datax = require "datax"
local objx = require "objx"
local ec = require "eventcenter"
local timer = require "timer"
local Robot = require "game.robot.classic.Robot"

local Player = require "game.ddz.PlayerAction"({})
Player = require "game.base.PlayerMethodBase"(Player)
Player = class("Player", Player)


function Player:ctor(roomObj, userObj, pos)
    self.state = PlayerState_DDZ.Waiting
    self.roomObj = roomObj
    self.userObj = userObj
    local base = skynet.call(userObj.addr, "lua", "RoomUserInfoGet", roomObj.conf.gametype, roomObj.conf.roomtype)
    table.merge(self.userObj, base)

    self.id = self.userObj.id
	self.pos = pos
    self.cards = {}
    self.playedCards = {} -- 已出的牌
    self.playCount = 0 -- 出牌次数
    self.clock = 0
    self.lastAction = nil
    self.actionQueue = {}
    self.playCardCount = 0
    self.isUser = not userObj.robot
    self.robotAgent = nil -- 托管时用的机器人代理

    self.playCardState = PlayCardState_DDZ.Default

    self.isShowcard = false
    --self.showcardx5 = showcardx5 and true or false 	-- 明牌开始 * 5
    self.isTrusteeship = false --是否托管
    self.isLandlord = false

    for i,v in pairs(base) do
        print(i,v)
    end
    self.skillId = datax.fashion[base.skin].skill_id
    self.skillCfg = datax.skill[self.skillId]
    self.skillBuffCfg = datax.skillBuff[self.skillId][base.heroSkillLv]
    self.heroSkillRate = (base.heroSkillRate or 0) + (self.skillBuffCfg and self.skillBuffCfg.trigger_probability or 0)
    self.skillState = false

    self.doubleAction = nil
	self.doubleMultiple = nil --加倍倍数
	self.doubleMaxAction = nil
	self.doubleMaxMultiple = nil --封顶加倍倍数

    self.bottomCards = {}       -- 已获取的底牌信息
	self.useCardRecord = userObj.useCardRecord or false    -- 如果自动使用了就为真
    self.banChat = false

	self.cancel_timer = function ()
	end
end

function Player:dealCard(cards)
    self.lastAction = nil
    self.actionQueue = {}
    self.isShowcard = false
    self.bottomCards = {}
    self.cards = cards
    --self:sortCards()
end

function Player:sortCards()
    table.sort(self.cards, function (a, b)
        return a&0xf > b&0xf
    end)
end

function Player:setLandlord()
    self.isLandlord = true
    for i, v in ipairs(self.roomObj.bottomCards) do
        table.insert(self.cards, v)
    end
    self:sortCards()
    self.robotAgent.setLandlord(self.roomObj.bottomCards)
end

local TIME = {
    [PlayerState_DDZ.CallLandlord] = 10,
    [PlayerState_DDZ.RobLandlord] = 10,
    [PlayerState_DDZ.Doubleing] = 5,
    [PlayerState_DDZ.DoubleMax] = 8,
    [PlayerState_DDZ.Playing] = 20,
}

function Player:GetLeftCardNum()
    local leftCardNum = 17
    if self.isLandlord then
        leftCardNum = 20
    end
    for _, out_data in pairs(self.playedCards) do
        for _, _card in pairs(out_data.cards) do
            leftCardNum = leftCardNum - 1
        end
    end
    return leftCardNum
end

function Player:GetLeftCards()
    local leftCards = {}
    local flag = true
    for _, _card_value1 in pairs(self.cards) do
        flag = true
        for _, out_data  in pairs(self.playedCards) do
            for _, _card_value2 in pairs(out_data.cards) do
                if _card_value1 == _card_value2 then
                  flag = false
                  break
                end
            end

            if not flag then
                break
            end
        end
        if flag then
            table.insert(leftCards, _card_value1)
        end
    end

    return leftCards
end

function Player:GetRoomData()
    local roomData = {pList = {}}
    for _index1, _p in pairs(self.roomObj.players) do
        local p_data = {id=_p.id, leftCardNum = _p:GetLeftCardNum(), jipaiqi = {}, isLandlord = _p.isLandlord, leftCards = _p:GetLeftCards()}
        if _p.id == self.id then
            roomData.index = _index1
            roomData.curentId = _p.id
        end
        for _index2, _p in pairs(self.roomObj.players) do
            if _index1 ~= _index2 then
                for key, _card_value_3 in pairs(_p:GetLeftCards()) do
                    table.insert(p_data.jipaiqi, _card_value_3)
                end
            end
        end
        roomData.pList[_index1] = p_data
    end

    return roomData
end

function Player:setActionState(state)
    self.state = state

    if state == PlayerState_DDZ.Waiting then
        return
    elseif state == PlayerState_DDZ.ReadyOk then
        self.robotAgent = Robot(self.roomObj, self.id)
        self:sendToPlayer("RoomMatchOk_C", self:GetRoomInfo())
        -- 扣除门票消耗
        self:sendToAgent("RoomMatchOkCostHandler", self.roomObj.cfgData.cost)
    elseif state == PlayerState_DDZ.DealCard then
        self.robotAgent.init_handcards(table.copy(self.cards))
        self:sendToPlayer("RoomDealCard_C", {cards = self.cards})
        self:sortCards()
    else
        local time = TIME[state]
        if not time then
            skynet.loge("setActionState error!", state)
            return
        end

        local trusteeship = true
        if state == PlayerState_DDZ.Doubleing or state == PlayerState_DDZ.DoubleMax then
            trusteeship = false
        end

        self.clock = time
        self.roomObj.sendToPlayerAll("RoomPleasePlayerAction_C", {id = self.id, state = state, clock = time, playCardState = self.playCardState, roomData = self:GetRoomData()})

        local trusteeshipCheckTime = 2
        self.clock = self.clock - trusteeshipCheckTime

        local trusteeshipTime = math.random(12, 20)
        self.cancel_timer = timer.create(10, function ()
            trusteeshipTime = trusteeshipTime - 1
            if trusteeshipTime <= 0 and self.isTrusteeship then
                self:trusteeshipAction(state)
            end
        end, 10 * trusteeshipCheckTime, function ()
            self.clock = math.ceil(self.clock)
            self.cancel_timer = timer.create(100, function ()
                self.clock = self.clock - 1
            end, self.clock, function ()
                if trusteeship then
                    self:SetTrusteeship({isTrusteeship = true})
                else
                    self:trusteeshipAction(state)
                end
            end)
        end)

        -- if self.isTrusteeship then
        --     -- -- 
        --     -- self.state = PlayerState_DDZ.Waiting
        --     -- skynet.sleep(100)
        --     -- self.state = state

        --     -- self.roomObj.sendToPlayerAll("RoomPleasePlayerAction_C", {id = self.id, state = state, clock = time, playCardState = self.playCardState})
        --     -- self:trusteeshipAction(state)
        -- else
        --     self.clock = time
        --     self.roomObj.sendToPlayerAll("RoomPleasePlayerAction_C", {id = self.id, state = state, clock = time, playCardState = self.playCardState})

        --     self.cancel_timer = timer.create(100, function ()
        --         self.clock = self.clock - 1
        --     end, self.clock, function ()
        --         if trusteeship then
        --             self:SetTrusteeship({isTrusteeship = true})
        --         end
        --         self:trusteeshipAction(state)
        --     end)
        -- end
    end
end

function Player:trusteeshipAction(state)
    if state == PlayerState_DDZ.CallLandlord then
        self:CallLandlord({type = PlayerAction_DDZ.NotCall})
    elseif state == PlayerState_DDZ.RobLandlord then
        self:RobLandlord({type = PlayerAction_DDZ.NotRob})
    elseif state == PlayerState_DDZ.Doubleing then
        self:Double({type = PlayerAction_DDZ.NotDouble})
    elseif state == PlayerState_DDZ.DoubleMax then
        self:DoubleMax({type = PlayerAction_DDZ.NotDoubleMax})
    elseif state == PlayerState_DDZ.Playing then
        self:autoPlay()
    end
end

function Player:addAction(action)
	self.lastAction = action
    table.insert(self.actionQueue, action)
end

function Player:setPlayCardState(state)
	self.playCardState = state
end

function Player:autoPlay()
    -- local can_pass = self.playCardState == "normal"

	-- if can_pass then
	-- 	self:playcard{pass = true}
	-- else
	-- 	local card = self.cards[#self.cards]
	-- 	self:playcard{pass = false, playedcards = {type = "dan", weight = util.V(card), cards = {card}}}
	-- end

    local result = nil
    local roomData = nil
    if false then
        roomData = self:GetRoomData()
    end

    if self.roomObj.lastPlayCardObj then
        if roomData then
            roomData.lastPlayerId = self.roomObj.lastPlayCardObj.id
            roomData.lastPlayerCard = self.roomObj.lastPlayCardObj.playCardObj
        end
        result = self.robotAgent.getPlayCardObj(self.playCardState, 
            self.roomObj.lastPlayCardObj.isLandlord == self.isLandlord, 
            self.roomObj.lastPlayCardObj.playCardObj, roomData)
    else
        result = self.robotAgent.getPlayCardObj(self.playCardState, nil, nil, roomData)
    end
    
	local param = {
		type = result.pass and PlayerAction_DDZ.Pass or PlayerAction_DDZ.PlayCard,
		playCardObj = result.playedcards
	}
	self:PlayCard(param)
end

function Player:clearClock()
	self.cancel_timer()
	self.clock = 0
end

function Player:sendToPlayer(name, args)
	local ok, err = pcall(skynet.send, self.userObj.addr, "lua", "RoomPlayerMessage", name, args)
    if not ok then
        skynet.loge("Room sendToPlayer error!", name, table.tostr(args), err)
    end
end

function Player:sendToAgent(name, args)
	local ok, err = pcall(skynet.send, self.userObj.addr, "lua", name, args)
    if not ok then
        skynet.loge("Room sendToAgent error!", name, table.tostr(args), err)
    end
end

function Player:getMultiple()
    local multiple = 1
    for k, v in pairs(self.roomObj.multiple) do
        multiple = multiple * v
    end

    local landlord = self.roomObj.landlordPlayer
    if landlord then
        multiple = multiple * (landlord.doubleMultiple or 1) * (landlord.doubleMaxMultiple or 1) -- 地主的加倍算房间加倍

        if self.isLandlord then
            local otherMultiple = 0
            local arr = self.roomObj.getFarmerArr()
            for index, value in ipairs(arr) do
                otherMultiple = otherMultiple + (value.doubleMultiple or 1) * (value.doubleMaxMultiple or 1)
            end
            multiple = multiple * otherMultiple --为地主时两农名加倍倍数和算公共加倍
        else
            multiple = multiple * (self.doubleMultiple or 1) * (self.doubleMaxMultiple or 1)
        end
    end
	return multiple
end

function Player:syncMultiple(multipleKey, multipleVal, id)
	self:sendToPlayer("RoomSyncMultiple_C", {multiple = self:getMultiple(), key = multipleKey, val = multipleVal, id = id})
end

return Player