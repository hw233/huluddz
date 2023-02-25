local skynet = require "skynet"
local helper = require "game.ddz.helper"
local ec = require "eventcenter"
local cft_marquee = require "conftbl_ddz.marquee"

return function (Room)

	function Room:exit()
		skynet.call("room_mgr", "lua", "room_exit", self.id)
		skynet.exit()
	end

	function Room:gameover(winner)
		self.status = RoomState_DDZ.Ended
		local spring = self:is_spring(winner)
		if spring then
			self.multiple.spring = 2
			self:sync_multiple()
		end

		local bills = self:game_bills(winner)

		for _,b in ipairs(bills) do
			local p = self:find_player(b.id)
			p.gold = p.gold + b.win_gold
			b.gold = p.gold

			if b.multiple > 10000000 and self.conf.roomtype >= 3 then
				local text = cft_marquee[self.conf.roomtype-2].contents
				ec.pub{type = "immediate_horselamp", text = string.format(text, p.nick, b.multiple), times = 1, lv = HORSELAMP_LV.game_multiple}
			end
		end

		self:radio("gameover", {
			bills = bills,
			spring = spring,
			conf = self.conf,
			top = self:game_top()
		})
		self:exit()
	end

	function Room:game_start_play()
		self.status = RoomState_DDZ.Playing
		local landlord = self:find_landlord()
		landlord:please_playcard("first")
	end

	function Room:game_start_double_cap()
		self.status = RoomState_DDZ.DoubleCaping
		for _,p in ipairs(self.players) do
			p:please_double_cap()
		end
	end

	local function dump_cards(cards)
		local s = " {"
		for i,c in ipairs(cards) do
			s = s .. string.format("%#x", c) .. ", "
		end
		s = s:sub(1, #s-2) .. "}"
		return s
	end

	function Room:dump_player_cards()
		for _,p in ipairs(self.players) do
			skynet.error(p.id, dump_cards(p.cards))
		end
	end
	

	function Room:game_start_double(landlord)
		self.status = RoomState_DDZ.Doubleing
		landlord.is_landlord = true
		for i,v in ipairs(self.bottom_cards) do
			table.insert(landlord.cards, v)
		end
		landlord:sort_cards()

		-- self:dump_player_cards()

		self.multiple.bottom_cards = helper.bottom_cards_multiple(self.bottom_cards)
		self:radio("determine_landlord", {landlord_id = landlord.id, bottom_cards = self.bottom_cards, multiple = self.multiple.bottom_cards})

		self:sync_multiple()
		skynet.sleep(100)
		for _,p in ipairs(self.players) do
			p:please_double()
		end
	end

	function Room:game_start_overlord_rob_landlord()
		local function get_overlords()
			local overlords = {}
			for _,p in ipairs(self.players) do
				if p.last_action.name == "call_landlord" or p.last_action.name == "rob_landlord" then
					table.insert(overlords, p)
				end
			end
			assert(#overlords >= 2, #overlords)
			return overlords
		end

		self.status = RoomState_DDZ.OverlordRobLandlord
		
		local overlords = get_overlords()
		for _,p in ipairs(self.players) do
			p:please_overlord_rob_landlord(table.find_one(overlords, p))
		end
	end


	function Room:game_start_rob_landlord(p)
		self.status = RoomState_DDZ.RobLandlord
		p:please_rob_landlord()
	end

	function Room:game_start_call_landlord()
		self.status = RoomState_DDZ.CallLandlord

		local function find_showcardx5_players()
			local players = {}
			for i,p in ipairs(self.players) do
				if p.showcardx5 then
					table.insert(players, p)
				end
			end
			return players
		end

		local showcardx5_players = find_showcardx5_players()
		local current

		if #showcardx5_players > 0 then
			current = showcardx5_players[math.random(1, #showcardx5_players)]
		else
			current = self.players[math.random(1, #self.players)]
		end

		for _,p in ipairs(self.players) do
			if p ~= current then
				p.status = PlayerState_DDZ.Waiting
			end
		end
		current:please_call_landlord()
	end

	function Room:game_start_dealcard()
		self.status = RoomState_DDZ.DealCard
		self.startcount = self.startcount + 1
		local cards_1, cards_2, cards_3, bottom_cards = helper.dealcard(self.conf.gametype, self.players[1].gamec)
		self.players[1].cards = cards_1
		self.players[2].cards = cards_2
		self.players[3].cards = cards_3
		self.bottom_cards = bottom_cards

		-- for game record
		local function other_player_cards(me)
			local others = {}
			for _,p in ipairs(self.players) do
				if p ~= me then
					table.insert(others, {pid = p.id, cards = p.cards})
				end
			end
			return others
		end

		for _,p in ipairs(self.players) do
			p.last_action = {}
			p.is_showcard = false

			p.status = PlayerState_DDZ.DealCard
			p:send_push("game_start_dealcard", {cards = p.cards, others = other_player_cards(p)})
			p:sort_cards()
		end

		
		self.multiple.showcard = 1
		self.multiple.rob_landlord = 1
		
		-- 明牌开始 * 5
		for _,p in ipairs(self.players) do
			if p.showcardx5 then
				p.is_showcard = true
				self:radio("p_showcard", {pid = p.id, cards = p.cards})
				self.multiple.showcard = self.multiple.showcard * 5
				self:sync_multiple()
			end
		end

		-- 5秒后进入叫地主阶段
		skynet.timeout(500, function ()
			self:game_start_call_landlord()
		end)
	end

	function Room:game_deduction_room_ticket()
		local conf = self:realconf()

		for i,p in ipairs(self.players) do
			p:deduction_room_ticket(conf.cost)
		end
	end


	return Room
end