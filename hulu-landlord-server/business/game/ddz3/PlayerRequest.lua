local SHOW_BOTTOM_CARDS_STATUS = {"doubleing", "playing", "ended"}
local CHECK_BOTTOM_CARDS_STATUS = {"dealcard", "call_landlord", "rob_landlord", "overlord_rob_landlord"}


return function (Player)

	function Player:check_bottom_card(params)
		assert(params.index >= 1 and params.index <= #self.room.bottom_cards)
		assert(self:sub_item("toushika"))
		assert(table.find_one(CHECK_BOTTOM_CARDS_STATUS, self.room.status))
		return {card = self.room.bottom_cards[params.index]}
	end

	function Player:card_recorder()
		if self.room.status ~= "playing" then
			return {err = GAME_ERROR.room_no_in_playing}
		end

		if self.useCardRecord == false then
			if not self:check_backpack("jipaiqi_tian") then
				assert(self:sub_item("jipaiqi_chang"))
			end
			self.useCardRecord = true
		end
		
		local cards = {}
		for _,p in ipairs(self.room.players) do
			if p.id ~= self.id then
				for _,c in ipairs(p.cards) do
					table.insert(cards, c)
				end
			end
		end
		return {cards = cards}
	end


	function Player:room_info()
		local room = self.room
		local info = {
			id = room.id,
			conf = room.conf,
			status = room.status,
			bottom_cards = table.find_one(SHOW_BOTTOM_CARDS_STATUS, room.status) and room.bottom_cards or {},
			bottom_cards_multiple = room.multiple.bottom_cards,
			players = {}
		}

		for _,p in ipairs(room.players) do
			local t = {
				id = p.id,
				nick = p.nick,
				head = p.head,
				gold = p.gold,
				gender = p.gender,

				showcardx5 = p.showcardx5,
				chair = p.chair,
				status = p.status,
				playstatus = p.playstatus,
				clock = p.clock,
				is_trusteeship = p.is_trusteeship,
				is_showcard = p.is_showcard,
				is_landlord = p.is_landlord,
				last_action = p.last_action,
				double_multiple = p.double_multiple,
				cardnum = #p.cards,
				cards = (p.id == self.id or p.showcard) and p.cards or {},
				muted = p.muted,
				title = p.title,
				vip = p.vip,
				played_cards = p.played_cards,
				useCardRecord = p.useCardRecord,
				cardBg = p.cardBg,
				sceneBg = p.sceneBg,
				tableClothBg = p.tableClothBg,
			}

			-- 自己独有属性
			if p.id == self.id then
				t.game_multiple = p:game_multiple()
			end

			table.insert(info.players, t)
		end

		return {room = info}
	end

	return Player
end