local skynet = require "skynet"
local util = require "util.ddz_leper"
local cft_marquee = require "conftbl_ddz.marquee"
local cft_store = require "conftbl_ddz.store"
local ec = require "eventcenter"
local cft_vip = require "conftbl_ddz.vip"


local function dump_cards(cards)
	local s = " {"
	for i,c in ipairs(cards) do
		s = s .. string.format("%#x", c) .. ", "
	end
	s = s:sub(1, #s-2) .. "}"
	return s
end



return function (Player)

	function Player:playcard(params)

		local pass = params.pass
		local playedcards = params.playedcards
		local cards = playedcards and playedcards.cards

		-- dump("playcard: " ..self.id .. (cards and dump_cards(cards) or ": pass" ))

		assert(self.status == PlayerState_DDZ.Playing)
		if pass then
			assert(self.playstatus == "normal")
		else
			assert(cards)
			assert(util.card_types(cards), playedcards.type)
			if self.playstatus == "normal" and not util.gt(playedcards, self.room.last_play.playedcards) then
				error("card is too small")
			end
			for _,card in ipairs(cards) do
				assert(table.find_one(self.cards, card & 0xff))
			end
		end

		local function next_one_play()
			skynet.sleep(50)
			local p = self.room:next_player(self)
			p:please_playcard(p.id == self.room.last_play.id and "mustplay" or "normal")
		end

		local function remove_from_hand()
			local function remove(card)
				for i,c in ipairs(self.cards) do
					if c == (card & 0xff) then
						return table.remove(self.cards, i)
					end
				end
			end

			for _,v in ipairs(cards) do
				remove(v)
			end
		end

		self.status = PlayerState_DDZ.Waiting
		if pass then
			self:set_last_action("pass")
		else
			table.insert(self.played_cards, playedcards)
			self:set_last_action("playcard", playedcards)
		end
		self:clear_clock()

		if pass then
			self.room:radio("p_playcard", {pid = self.id, pass = true})
			next_one_play()
		else
			self.playcount = self.playcount + 1
			self.room.last_play = {id = self.id, playedcards = playedcards}
			self.room:radio("p_playcard", {pid = self.id, playedcards = playedcards, pass = false})
			self.room:on_player_playcard(self, playedcards)

			if playedcards.type == "zhadan" and self.room.conf.roomtype >= 2 then
				local zhadan = util.zhadan_type(playedcards.weight)
				if zhadan == "star_4_4" then
					local text = cft_marquee[4 + self.room.conf.roomtype-2].contents
					ec.pub{type = "immediate_horselamp", text = string.format(text, self.nick), times = 1, lv = HORSELAMP_LV.game_lianzha_4}
				elseif zhadan == "star_4_5" then
					local text = cft_marquee[9 - (self.room.conf.roomtype-2)].contents
					ec.pub{type = "immediate_horselamp", text = string.format(text, self.nick), times = 1, lv = HORSELAMP_LV.game_lianzha_5}
				end
			end
			
			remove_from_hand()

			if #self.cards == 0 then
				skynet.timeout(20, function ()
					self.room:gameover(self)
				end)
			else
				next_one_play()
			end
		end
	end

	function Player:double_cap(params)
		local multiple = assert(params.multiple)
		assert(self.status == PlayerState_DDZ.DoubleMax)
		assert(multiple == 1 or multiple == 4)

		local ok, use_diamond
		if multiple == 4 then
			if self.have_yearcard then
				-- pass
			else
				ok, use_diamond = self:sub_item_or_diamond("fd_fanbei", self:real_price("fd_fanbei_diamond"))
				assert(ok)	
			end
		end

		self.status = PlayerState_DDZ.Waiting
		self:set_last_action("double_cap_"..math.tointeger(multiple))
		self.double_cap_multiple = multiple
		self:clear_clock()

		local top = multiple > 1 and self.room:game_top() or nil
		self.room:radio("p_double_cap", {pid = self.id, multiple = multiple, top = top, use_diamond = use_diamond})
		self.room:on_player_double_cap(self, multiple)

		if self.room:all_double_cap() then
			skynet.fork(function ()
				skynet.sleep(30)
				self.room:game_start_play()
			end)
		end
	end


	function Player:double(params)
		local multiple = assert(params.multiple)
		assert(self.status == PlayerState_DDZ.Doubleing, self.status .. self.id)
		assert(multiple == 1 or multiple == 2 or multiple == 4)

		local ok, use_diamond
		if multiple == 4 then
			if self.have_yearcard then
				-- pass
			else
				ok, use_diamond = self:sub_item_or_diamond("cj_jiabei", self:real_price("cj_jiabei_diamond"))
				assert(ok)
			end
		end

		self.status = PlayerState_DDZ.Waiting
		self:set_last_action("double_"..math.tointeger(multiple))
		self.double_multiple = multiple
		self:clear_clock()

		self.room:radio("p_double", {pid = self.id, multiple = multiple, use_diamond = use_diamond})
		self.room:on_player_double(self, multiple)

		if self.room:all_double() then
			skynet.fork(function ()
				skynet.sleep(30)
				self.room:game_start_double_cap()
			end)
		end
	end

	local function rob_count(self)
		local n = 1
		for _,p in ipairs(self.room.players) do
			if p.last_action.name == "rob_landlord" then
				n = n + 1
			end
		end
		return n
	end

	function Player:overlord_rob_landlord()
		if self.room.status == PlayerState_DDZ.OverlordRobLandlord then
			local ok, use_diamond

			if self.have_yearcard then
				-- pass
			else
				ok, use_diamond = self:sub_item_or_diamond("bawangka", self:real_price("bawangka_diamond"))
				assert(ok)
			end
			self.room:radio("p_overlord_rob_landlord", {pid = self.id, use_diamond = use_diamond})
			self.room:on_player_overlord_rob_landlord()
			skynet.sleep(150)
			self.room:game_start_double(self)
		end
	end

	-- 没人霸王抢, 叫地主的为地主
	function Player:overlord_rob_landlord_timeout()
		
		-- local function last_rob_landlord_player()
		-- 	local caller = self.room:find_call_landlord_player()
		-- 	local front = self.room:front_player(caller)
		-- 	return front.last_action.name == "rob_landlord" and front or self.room:front_player(front)
		-- end

		if self.room.status == PlayerState_DDZ.OverlordRobLandlord then
			self.room:game_start_double(self.room:find_call_landlord_player())
		end
	end

	function Player:rob_landlord(params)
		local rob = params.rob
		assert(self.status == PlayerState_DDZ.RobLandlord)
		local last_action = self.last_action.name
		self.status = PlayerState_DDZ.Waiting
		self:set_last_action(rob and "rob_landlord" or "not_rob")

		self:clear_clock()
		self.room:radio("p_rob_landlord", {pid = self.id, rob = rob, nrob = rob_count(self)})

		local function next_rob_player(p)
			for i=1,2 do
				p = self.room:next_player(p)
				if p.last_action.name == "call_landlord" then
					return p
				end
			end
		end

		if rob then
			self.room:on_player_rob_landlord()
		end

		--[[
			下一个人是否需要 抢地主 操作 ()
				是 => 请抢地主
				否 => {
					叫地主 / 抢地主的 进入霸王抢
					没有抢地主的, 叫地主的 成为地主
				}
		]]
		if self.room.conf.gametype == GAMETYPE("classic") then
			if last_action == "call_landlord" then
				if rob then
					self.room:game_start_overlord_rob_landlord()
				else
					local front = self.room:front_player(self)
					local landlord = front.last_action.name == "rob_landlord" and front or self.room:front_player(front)
					assert(landlord.last_action.name == "rob_landlord")
					self.room:game_start_double(landlord)
				end
			else
				local next_one = self.room:next_player(self)

				-- 下一个玩家已经操作过了
				if next_one.last_action.name then
					local caller = self.room:find_call_landlord_player()

					if self.room:have_rob_player() then
						caller:please_rob_landlord()
					else
						self.room:game_start_double(caller)
					end
				else
					next_one:please_rob_landlord()
				end
			end
		else
			-- classic
			-- TODO
		end
	end

	function Player:call_landlord(params)
		local call = params.call
		assert(self.status == PlayerState_DDZ.CallLandlord, self.status)
		self.status = PlayerState_DDZ.Waiting
		if call then
			self.first_call = true
		end
		self:set_last_action(call and "call_landlord" or "not_call")
		self:clear_clock()
		self.room:radio("p_call_landlord", {pid = self.id, call = call})
		
		local next_one = self.room:next_player(self)
		
		if call then
			if next_one.last_action.name == nil then
				self.room:game_start_rob_landlord(next_one)
			else
				self.room:game_start_double(self)
			end
		else
			if next_one.last_action.name == nil then
				next_one:please_call_landlord()
			else
				if self.room.startcount == 3 then
					self.room:game_start_double(next_one)
				else
					local showcardx5_player = self.room:find_an_showcardx5_player()
					if showcardx5_player then
						self.room:game_start_double(showcardx5_player)
					else
						self.room:game_start_dealcard()
					end
				end
			end
		end
	end

	function Player:real_price(id)
		local price = cft_store[COMMID(id)].price
		local vip = cft_vip[self.realvip]

		if not vip then
			return price
		end

		if id == "cj_jiabei_diamond" then
			return math.ceil(price * vip.double_discount/10)
		elseif id == "fd_fanbei_diamond" then
			return math.ceil(price * vip.hinghdouble_discount/10)
		elseif id == "bawangka_diamond" then
			return math.ceil(price * vip.overlord_discount/10)
		else
			return price
		end
	end

	function Player:showcard()
		assert(self.is_showcard == false)

		if self.status == PlayerState_DDZ.DealCard then
			self.room:on_player_showcard(3)
		elseif self.status == PlayerState_DDZ.Playing and self.playstatus == "first" then
			self.room:on_player_showcard(2)
		else
			error("invalid action showcard, p.status =" .. tostring(self.status))
		end

		self.is_showcard = true
		self.room:radio("p_showcard", {pid = self.id, cards = self.cards})
	end

	function Player:cancel_trusteeship()
		-- assert(self.is_trusteeship == true)
		if self.is_trusteeship == false then
			skynet.error(self.id .. " already canceled trusteeship!")
		end
		self.is_trusteeship = false
		self.room:radio("p_cancel_trusteeship", {pid = self.id})
	end

	function Player:trusteeship()
		assert(self.is_trusteeship == false)
		self.is_trusteeship = true
		self.room:radio("p_trusteeship", {pid = self.id})

		if self.status == PlayerState_DDZ.CallLandlord then
			self:clear_clock()
			self:call_landlord{call = false}
		elseif self.status == PlayerState_DDZ.RobLandlord then
			self:clear_clock()
			self:rob_landlord{rob = false}
		elseif self.status == PlayerState_DDZ.Doubleing then
			self:clear_clock()
			self:double{multiple = 1}
		elseif self.status == PlayerState_DDZ.Playing then
			self:clear_clock()
			self:auto_play()
		end
	end

	return Player
end