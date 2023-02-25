local skynet = require "skynet"
local objx = require "objx"
local arrayx   = require "arrayx"
local roomData = require "roomData"
local helper = require "game.sevensparrow.helper"


--[[
	0. 初始豆子
	1. 赢
		大于初始豆子 每个人赢当前豆子
		小于初始豆子 最多 赢初始豆子
]]

return function (Player)

	-- 小结算并获取账单
	function Player:checkout_and_bills(cardType, multiple)
		local bills = {}
		local recharging = false

		local over = self.room:check_over()

		local goldWin = 0
		local winGoldMax = self.room:getWinGoldMax(self, multiple)

		for _,p in ipairs(self.room.players) do
			if p.id ~= self.id and p:gameing() then
				local goldLost = math.min(p.gold, winGoldMax)
				p:add_gold(-goldLost)
				if p.gold == 0 then
					p.count_bankrupt = p.count_bankrupt + 1
				end
				table.insert(bills, {id = p.id, win_gold = -goldLost, gold = p.gold, tag = p.gold == 0 and "bankrupt" or "", cardType = cardType, multiple = multiple})
				goldWin = goldWin + goldLost

				if not over and p.gold == 0 then
					recharging = true
					skynet.fork(function ()
						skynet.sleep(20)
						p:please_recharge()
					end)
				end
			end
		end

		self:add_gold(goldWin)
		table.insert(bills, {id = self.id, win_gold = goldWin, gold = self.gold ,tag = "", cardType = cardType, multiple = multiple})
		return bills, recharging
	end

	function Player:ssw_exit()
		skynet.logd("ssw_exit =========================", self.id)
		if self.status ~= PlayerState_QQP.Watching then
			return RET_VAL.Fail_2
		end

		local result = nil
		if self.room.status ~= RoomState_QQP.Ended then
			result = self.room:gameOverInfo()
		end
		self.room:radio("ssw_p_exit", {pid = self.id, overInfo = result})
		self.status = PlayerState_QQP.Exited
		self.subscriber.unsub()
		self.subscriber2.unsub()
		return RET_VAL.Succeed_1
	end



	function Player:ssw_not_giveup()
		assert(self.status == PlayerState_QQP.Recharging, self.id .. self.status)
		self.status = PlayerState_QQP.Waiting
		self:clear_clock()

		self.room:radio("ssw_p_giveup", {pid = self.id, giveup = false})
		
		if self.room:getRechargeingNum() == 0 then
			self.room:next_one_take(self.room.last_hu_player)
		end
	end


	function Player:ssw_giveup()
		skynet.logd("ssw_giveup..............." .. self.id)
		assert(self.status == PlayerState_QQP.Recharging, self.id .. self.status)
		self:clear_clock()
		self.status = PlayerState_QQP.Watching
		self.room:radio("ssw_p_giveup", {pid = self.id, giveup = true})

		-- 如果只剩一个玩家了就结束游戏
		if self.room:count_watching_or_exited() == 3 then
			skynet.sleep(50)
			self.room:gameover()
		else
			if self.room:getRechargeingNum() == 0 then
				self.room:next_one_take(self.room.last_hu_player)
			end
		end
	end


	function Player:ssw_hu()
		assert(self.status == PlayerState_QQP.Playing, self.id .. self.status)
		local type, multiple = self:check_hu()
		assert(type)

		local eventArr = self:getHuEventArr(type)
		local eventMultiple = math.max(1, table.sum(eventArr, function (key, value)
			return roomData.multipleInfo[value]
		end))

		local flower_multiple = self:get_flowers_multiple()
		multiple = multiple * eventMultiple * flower_multiple

		-- 花满园 策划说这个特效时机移到拿牌时了
		local removeNum = table.removebyvalue(eventArr, helper.HuEventType.HuaManYuan)
		local eventIdArr = arrayx.select(eventArr, function (key, value)
			return helper.getEventId(value)
		end)

		local one = table.remove(self.cards)
		table.insert(self.hu_cards, one)
		self:clear_clock()
		self.status = PlayerState_QQP.Waiting

		local bills, recharging = self:checkout_and_bills(type, multiple)

		self.room.last_hu_player = self
		self.room:insert_bills(bills)
		self.room:radio("ssw_p_hu", {
			pid = self.id, card = one, cardtype = type, multiple = multiple, events = eventIdArr, bills = bills, over = over, eventArr = eventArr})

		if not recharging then
			--胡牌 客户端播放等待时间
			local waitTime = roomData.getRoomDelayTime("hu")
			table.insert(eventArr, 1, type)
			local eventTime = roomData.getRoomEffectDelayTime(self.skin, eventArr)
			waitTime = waitTime + eventTime
			skynet.sleep(waitTime)

			self.room:next_one_take(self)
		end
	end


	function Player:ssw_playcard(params)
		assert(self.status == PlayerState_QQP.Playing, self.id .. self.status)
		local card = assert(params.card)

		if #self.hu_cards > 0 then
			assert(card == self.cards[#self.cards])
		end

		assert(self:find_and_remove(card), string.format("not found card 0x%x in player(%s).cards", card, self.id))
		self:clear_clock()
		self.status = PlayerState_QQP.Waiting

		self.room:on_player_playcard(self, card)
		self.room:radio("ssw_p_playcard", {pid = self.id, card = card})

		--出牌 客户端播放等待时间
		skynet.sleep(roomData.getRoomDelayTime("play_card"))

		self.room:next_one_take(self)
	end

	function Player:ssw_takecard(params)
		assert(self.status == PlayerState_QQP.Takeing, self.id .. self.status)
		local from_pool = params.from_pool and true or false
		if not from_pool then
			assert(params.card)
		end

		local ok, card, flowers = self.room:takeCard(params.card)
		if not ok then
			if params.card then
				skynet.loge(string.format("not found card 0x%x in room.selectional_cards", params.card))
			else
				skynet.loge(string.format("room.pool length of 0"))
			end
			return
		end

		self.status = PlayerState_QQP.Waiting
		if card then
			table.insert(self.cards, card)
		end
		local isHuaManYuan = self:is_huamanyuan()
		table.append(self.flowers, flowers)
		isHuaManYuan = not isHuaManYuan and self:is_huamanyuan()

		local eventArr = {}
		if isHuaManYuan then
			table.insert(eventArr, helper.HuEventType.HuaManYuan)
		end

		local timeleft = self:clear_clock()
		self.round = self.round + 1
		self.from_pool = from_pool

		for _,p in ipairs(self.room.players) do
			p:send_push("ssw_p_takecard", {
				pid = self.id,
				from_pool = from_pool,
				card = (from_pool == false or p.id == self.id) and card or nil,
				flowers = flowers,
				events = table.select(eventArr, function (key, value)
					return helper.getEventId(value)
				end),
				eventArr = eventArr
			})
		end

		--摸牌 客户端播放等待时间
		local waitTime = roomData.getRoomDelayTime("take_card")
		local flowerTime = next(flowers) and (roomData.getRoomDelayTime("take_card_flower") * #flowers) or 0
		local eventTime = roomData.getRoomEffectDelayTime(self.skin, events)
		waitTime = waitTime + flowerTime + eventTime
		skynet.sleep(waitTime)

		-- 拿到的全是2
		if #self.cards == 7 then
			self.room:gameover()
		else
			self:please_playcard(timeleft)
		end
	end


	function Player:cancel_trusteeship()
		if self.is_trusteeship == false then
			skynet.error(self.id .. " already canceled trusteeship!")
		end
		self.is_trusteeship = false
		self.room:radio("p_cancel_trusteeship", {pid = self.id})
	end


	function Player:trusteeship()
		if self.is_trusteeship then
			skynet.loge("trusteeship error!", self.id, self.is_trusteeship)
			return
		end
		self.is_trusteeship = true
		self.room:radio("p_trusteeship", {pid = self.id})

		self:trusteeshipAction(self.status)
	end

	return Player
end