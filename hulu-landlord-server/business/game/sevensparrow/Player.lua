local skynet = require "skynet"
local datax = require "datax"
local objx = require "objx"
local roomData      = require "roomData"
local arrayx        = require "arrayx"
local common 		= require "common_mothed"

local ec = require "eventcenter"
local PlayerAction = require "game.sevensparrow.PlayerAction"
local PlayerActionEx = require "game.sevensparrow.PlayerActionEx"
local PlayerPlease = require "game.sevensparrow.PlayerPlease"
local PlayerRequest = require "game.sevensparrow.PlayerRequest"
local Player = PlayerRequest(PlayerPlease(PlayerActionEx(PlayerAction{})))

local util = require "util.qique"
local helper = require "game.sevensparrow.helper"

--[[
	o: {
		id = "123456", 		-- user id
		addr = 0x123456 	-- agent addr
	}
]]
function Player:new(o)
	o = o or {}
	self.__index = self
	setmetatable(o, self)
	return o
end


function Player:init(room, chair)
	self.room = room
	self.chair = chair
	self.status = PlayerState_QQP.ReadyOk 	-- "ready_ok", "waiting", "takeing", "playing", "recharging"(破产后充值中), "watching"(放弃后观战中), "exited"
	self.clock = 0
	self.cards = {}
	self.last_action = {}
	self.flowers = {} 		-- 花牌 `2`
	self.hu_cards = {} 		-- 胡的牌
	self.round = 0 			-- 自己行动次数
	self.is_first = false
	self.is_trusteeship = false
	self.fixed_events = {}
	self.fixed_eventIdArr = {}
	self.goldInit = self.gold
	self.goldBrokeLast = 0 -- 上次破产额度

	self.count_bankrupt = 0

	local base = skynet.call(self.addr, "lua", "RoomUserInfoGet", self.room.conf.gametype, self.room.conf.roomtype)
	table.merge(self, base)

	self.skillId = datax.fashion[base.skin].skill_id
	self.skillCfg = datax.skill[self.skillId]
	self.skillBuffCfg = datax.skillBuff[datax.fashion[base.skin].skill_id][base.heroSkillLv]
	self.heroSkillRate = (base.heroSkillRate or 0) + (self.skillBuffCfg and self.skillBuffCfg.trigger_probability or 0)
	self.skillState = arrayx.findVal(self.skillCfg.game_id, self.room.conf.gametype) and math.random(1, 10000) <= self.heroSkillRate

	self.useCardRecord = self.useCardRecord or false	-- 如果自动使用了就为真
	self.banChat = false

	self.isUser = not self.robot

	if self.effectTimeCfg then
		self.effectTimeCfg = table.toObject(self.effectTimeCfg, function (key, value)
			return key
		end, function (key, value)
			return value.value
		end)
		roomData.setDelayTimeDataTest(self.effectTimeCfg)
	end

	self.cancel_timer = function ()
	end

	self.subscriber = ec.sub({type = "player_add_gold", pid = self.id}, function (e)
		self.gold = e.now
		self.room:radio2other("sync_player_gold", {pid = e.pid, gold = e.now}, self.id)
		if self.status == PlayerState_QQP.Recharging and self.gold > 0 then
			self:ssw_not_giveup()
		end
	end)

	local delay_map = {}

	self.subscriber2 = ec.sub({type = "player_order", pid = self.id}, function (e)
		if self.status == PlayerState_QQP.Recharging and not delay_map[self.count_bankrupt] then
			delay_map[self.count_bankrupt] = 1
			local timeleft = self:clear_clock()
			self:please_recharge(timeleft + 10)
		end
	end)

	return self
end

function Player:find_and_remove(card)
	for i,v in ipairs(self.cards) do
		if v == card then
			return table.remove(self.cards, i)
		end
	end
end


function Player:auto_play()
	if self:check_hu() then
		self:ssw_hu()
	else
		-- 打出最后一张(暂时)
		local card = self.cards[#self.cards]
		self:ssw_playcard({card = card})
	end
end


-- 默认从牌堆中摸一张
function Player:auto_take()

	local function find_hu_card()
		local list = {}
		for i,card in ipairs(self.room.selectional_cards) do
			if util.is_leper(card) then
				return card
			end
			local type, multiple = util.check_hu(self.cards, card)
			if type then
				table.insert(list, {card = card, multiple = multiple})
			end
		end
		if #list > 0 then
			table.sort(list, function (a, b)
				return a.multiple > b.multiple
			end)
			return list[1].card
		end
	end

	local card = find_hu_card()
	if card then
		self:ssw_takecard({from_pool = false, card = card})
	else
		self:ssw_takecard({from_pool = true})
	end
end

function Player:trusteeshipAction(status)
	if status == PlayerState_QQP.Takeing then
		-- self:clear_clock()
		self:auto_take()
	elseif status == PlayerState_QQP.Playing then
		-- self:clear_clock()
		self:auto_play()
	elseif status == PlayerState_QQP.Recharging then
		-- self:clear_clock()
		self:ssw_giveup()
	end
end

function Player:getHuEventArr(type)
	local events = {}

	local addEvent = function (event, isFixed)
		table.insert(events, event)
		if isFixed and not arrayx.findVal(self.fixed_events, event) then
			table.insert(self.fixed_events, event)
			self.fixed_eventIdArr = arrayx.select(self.fixed_events, function (key, value)
				return helper.getEventId(value)
			end)
		end
	end

	local HuEventType = helper.HuEventType
	if self.from_pool then
		addEvent(HuEventType.ZiMo)	-- 策划需求，自摸提前
	end

	table.append(events, self.fixed_events)

	-- if self.round == 1 then
	-- 	addEvent(HuEventType.TianHu, true)
	-- elseif self.round == 2 and not arrayx.findVal(events, HuEventType.TianHu) then
	-- 	addEvent(HuEventType.DiHu, true)
	-- end
	-- 天胡由首轮胡牌都算天胡 改为 首轮且首出玩家胡牌算天胡
	-- 地胡由第二轮胡牌都算地胡 改为 第一轮且非首出胡牌算地胡
	if self.round == 1 then
		addEvent(self.room.first_one == self.id and HuEventType.TianHu or HuEventType.DiHu, true)
	end

	if self.from_pool and #self.room.pool == 0 then
		addEvent(HuEventType.Fishmoon)
	end

	if util.is_qingyise(self.cards) and type ~= "tonghuashun" and type ~= "shuanglonghui" then
		addEvent(HuEventType.QingYiSe)
	end

	if self:is_huamanyuan() then
		addEvent(HuEventType.HuaManYuan)
	end

	return events
end

function Player:is_huamanyuan()
	local tmp = {true, true, true, true}
	for _,card in ipairs(self.flowers) do
		tmp[util.C(card)] = nil
	end
	return next(tmp) == nil
end



function Player:get_flowers_multiple()
	local n = #self.flowers
	--modify by qc 2021.9.15 花的倍率调整 幂
	local mul = 1
	for i = 1, n do
		mul = mul * (roomData.multipleInfo["flower"] or 2)
	end
	return mul
end



function Player:check_hu()
	local cards = table.slice(self.cards, 1, 7)
	local one = assert(self.cards[8])
	return util.check_hu(cards, one)
end


function Player:sendToAgent(name, args)
	local ok, err = pcall(skynet.send, self.addr, "lua", name, args)
    if not ok then
        skynet.loge("Room sendToAgent error!", name, table.tostr(args), err)
    end
end

function Player:send_push(name, args)

	-- local on = {}

	-- function on.match_ok()
	-- 	self.agent = Robot(args.room, self.id)
	-- end

	-- function on.game_start_dealcard()
	-- 	self.agent.init_handcards(table.copy(args.cards))
	-- end

	-- function on.determine_landlord()
	-- 	self.agent.determine_landlord(args.landlord_id, table.copy(args.bottom_cards))
	-- end

	-- function on.p_playcard()
	-- 	self.agent.p_playcard(args.pid, args.pass, args.playedcards and table.copy(args.playedcards))
	-- end

	-- local f = on[name]
	-- if f then
	-- 	f()
	-- end
	if self.status ~= PlayerState_QQP.Exited or not self.isUser then
		local ok, err = pcall(skynet.send, self.addr, "lua", "RoomPlayerMessage", name, args)
		if not ok then
			skynet.loge("send_push", name, err)
		end
	end
end


function Player:gameing()
	return self.status ~= PlayerState_QQP.Watching and self.status ~= PlayerState_QQP.Exited
end


function Player:move_flowers_from_hand()
	local flowers = self:find_and_remove_flowers()
	if #flowers > 0 then
		table.append(self.flowers, flowers)
	end
end



function Player:find_and_remove_flowers()
	local flowers = {}

	for i=#self.cards,1,-1 do
		if util.V(self.cards[i]) == 0xd then
			table.insert(flowers, table.remove(self.cards, i))
		end
	end

	return flowers
end



function Player:sort_cards()
    table.sort(self.cards, function (a, b)
        return a&0xf > b&0xf
    end)
end


function Player:deduction_room_ticket(ticket)
	self.gold = self.gold - ticket
	self:sendToAgent("RoomMatchOkCostHandler", ticket)

	if self.robot then
		self.room:radio2other("sync_player_gold", {pid = self.id, gold = self.gold}, self.id)
	end
end


function Player:set_last_action(name, playedcards)
	self.last_action.name = name
	self.last_action.playedcards = playedcards
end


function Player:clear_clock()
	self.room:add_action(self.id, "clear_clock", self.clock)
	local clock = self.clock
	self.cancel_timer()
	self.clock = 0
	return clock
end


function Player:SyncRoomData(params)
	local id = params.id
	if id == ItemID.Gold then
		self.gold = params.num
		self.room:radio2other("sync_player_gold", {pid = self.id, gold = self.gold}, self.id)
		if self.status == PlayerState_QQP.Recharging and self.gold > 0 then
			self:ssw_not_giveup()
		end
	end
end

function Player:add_gold(num, from)
	from = from or "RoomQQP_七雀牌对局"
	assert(self.gold + num >= 0)

	if self.robot then
		self.gold = self.gold + num
	else
		local ret, curNum
		if num > 0 then
			ret, curNum = common.addItem(self.addr, ItemID.Gold, num, from)
		else
			ret, curNum = common.removeItem(self.addr, ItemID.Gold, math.abs(num), from, true, true)
		end

		if ret then
			self.gold = curNum
		else
			skynet.loge("RoomQQP add_gold error!", self.addr, self.gold, num)

			self.gold = self.gold + num
			self.room:radio2other("sync_player_gold", {pid = self.id, gold = self.gold}, self.id)
		end
		-- local ok, gold = pcall(skynet.call, self.addr, "lua", "room_add_gold", num, desc)
		-- if ok then
		-- 	self.gold = gold
		-- else
		-- 	self.gold = self.gold + num
		-- 	self.room:radio2other("sync_player_gold", {pid = self.id, gold = self.gold}, self.id)
		-- end
	end
	return self.gold
end


return Player