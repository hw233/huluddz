local skynet = require "skynet"
local qqp_algo = require "util.qique"

local room_disable_tiandi = {
	[1] = 80,
	[2] = 70,
	[3] = 60,
	[4] = 50
}


local function dump_cards(cards)
	local s = " {"
	for i,c in ipairs(cards) do
		s = s .. string.format("%#x", c) .. ", "
	end
	s = s:sub(1, #s-2) .. "}"
	skynet.error(s)
end


local function Robot(room, myid, send_request)

	local hand = {}
	local hu_cards = {}
	local round = 0
	local giveup = false

	local function remove_from(t, item)
		for i,v in ipairs(t) do
			if v == item then
				return table.remove(t, i)
			end
		end
	end


	local self = {}


	local function find_leper_or_hu_card()
		local list = {}
		for i,card in ipairs(room.selectional_cards) do
			if qqp_algo.is_leper(card) then
				return card
			end
			local type, multiple = qqp_algo.check_hu(hand, card)
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

	function self.please_takecard(pid)
		if pid == myid then

			-- 机器人随机等待拿牌时间
			skynet.sleep(math.random(100, 150))

			local card = find_leper_or_hu_card()
			send_request("ssw_takecard", {from_pool = card == nil, card = card})
		end
	end



	function self.p_hu(pid, card, bills, over)

		local function my_bill()
			for i,b in ipairs(bills) do
				if b.id == myid then
					return b
				end
			end
		end

		if pid == myid then
			remove_from(hand, card)
			table.insert(hu_cards, card)
		elseif not over and not giveup then
			local bill = my_bill()
			if bill.tag == "bankrupt" then
				skynet.sleep(math.random(150, 350))
				send_request("ssw_giveup")
				giveup = true
			end
		end
	end


	function self.p_playcard(pid, card)
		table.insert(room.selectional_cards, 1, card)
		if #room.selectional_cards == 4 then
			room.selectional_cards[4] = nil
		end

		if pid == myid then
			remove_from(hand, card)
		end
	end


	local function count_item(t)
		local n = 0
		for k,v in pairs(t) do
			n = n + v
		end
		return n
	end


	local function find_single_card()

		local function find(c, v)
			for _,card in ipairs(hand) do
				if qqp_algo.C(card) == c and qqp_algo.V(card) == v then
					return card
				end
			end
		end

		local function count_value(v)
			local n = 0
			for _,card in ipairs(hand) do
				if qqp_algo.V(card) == v then
					n = n + 1
				end
			end
			return n
		end

		-- 孤牌
		for _,card in ipairs(hand) do
			local c = qqp_algo.C(card)
			local v = qqp_algo.V(card)
			local n = count_value(v)

			if not qqp_algo.is_leper(card) and n == 1 and not find(c, v-1) and not find(c, v+1) then
				return card
			end
		end

		-- 找边张
		for _,card in ipairs(hand) do
			local c = qqp_algo.C(card)
			local v = qqp_algo.V(card)
			local n = count_value(v)

			if n == 1 and not qqp_algo.is_leper(card) then
				if find(c, v-1) and not find(c, v+1) then
					return card
				elseif not find(c, v-1) and find(c, v+1) then
					return card
				end
			end
		end


		skynet.error("======================================")
		dump_cards(hand)
		error("not found find_single_card")
	end


	local function play_which_one()
		-- skynet.error("====================================== 》》》")
		-- dump_cards(hand)
		-- skynet.error("====================================== 》》》")

		return qqp_algo.find_least(hand)
		--[[
		local results = {}
		for i=1,8 do
			local cards = table.copy(hand)
			local one = table.remove(cards, i)
			local type, multiple = qqp_algo.max_ting(cards)
			if type then
				table.insert(results, {one = one, multiple = multiple})
			end
		end

		if #results > 0 then
			table.sort( results, function (a, b)
				return a.multiple > b.multiple
			end )

			-- skynet.error("====================================== one", string.format("0x%x", results[1].one))
			return results[1].one
		else
			return find_single_card()
		end]]
	end

	local function disable_tiandi()
		local n = room_disable_tiandi[room.conf.roomtype]
		return math.random(1, 100) <= n
	end

	function self.auto_play(id, waite_time)

		if id ~= myid then
			return
		end
		
		--等待出牌时间
		waite_time = waite_time and waite_time or 150
		skynet.sleep(math.random(waite_time, waite_time + 150))

		local can_hu = qqp_algo.check_hu(table.slice(hand, 1, 7), hand[8])

		if can_hu and round == 1 and room.conf.roomtype > 1 and disable_tiandi() then
			can_hu = false
			skynet.error("robot disable tianhu or dihu ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
		end

		if can_hu then
			send_request("ssw_hu")
		else
			if #hu_cards > 0 then
				send_request("ssw_playcard", {card = hand[#hand]})
			else
				-- 看打出哪张牌听的牌多就打出哪张
				-- 如果打出谁都不能听牌就打出一个孤牌
				local one = play_which_one()
				-- skynet.error("play_which_one ==========", string.format("0x%x", one))

				send_request("ssw_playcard", {card = one})
			end
		end
	end


	function self.p_takecard(pid, from_pool, card,flowers)
		if not from_pool then
			remove_from(room.selectional_cards, card)
		end

		if pid == myid then
			round = round + 1
			table.insert(hand, card)
		end
	end


	function self.gamestart(selectional_cards, players)
		room.selectional_cards = selectional_cards
		for _,p in ipairs(players) do
			if p.id == myid then
				hand = p.cards
			end
		end
		assert(#hand > 0)
	end


	return self
end


return Robot