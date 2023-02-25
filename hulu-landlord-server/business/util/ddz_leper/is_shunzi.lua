local helper = require "util.ddz_leper.helper"

local CLIENT = helper.CLIENT
local C = helper.C
local V = helper.V
local TYPE = helper.TYPE
local COMB = helper.COMB
local remove_lepers = helper.remove_lepers
local get_value_num = helper.get_value_num
local get_value_cards = helper.get_value_cards
local king_count = helper.king_count
local find_value = helper.find_value

local MIN_V = helper.MIN_V
local MAX_V = helper.MAX_V


local function have_samevalue_card(cards)
	local tmp = {}
	for _,card in ipairs(cards) do
		local v = V(card)
		if tmp[v] then
			return true
		else
			tmp[v] = true
		end
	end
	return false
end


local function is_shunzi(cards)
	local ncards = #cards
	if ncards < 5 then
		return
	end

	local lepers = remove_lepers(cards)
	local nlepers = #lepers

	if find_value(cards, 0xd) or king_count(cards) > 0 then
		return
	end

	local min_v = MIN_V(cards)
	local max_v = MAX_V(cards)
	if max_v - min_v >= ncards then
		return
	end

	if have_samevalue_card(cards) then
		return
	end

	-- 癞子炸除外
	if nlepers == ncards then
		return
	end

	if nlepers == 0 then
		return {{type = TYPE.shunzi, weight = V(cards[1]), cards = CLIENT and cards or nil}}
	end

	local function client_cards(start_v)
		local cards = table.copy(cards)
		local lepers = table.copy(lepers)
		local value_cards = get_value_cards(cards)
		
		local cli_cards = {}
		for i=start_v+ncards-1,start_v,-1 do
			if value_cards[i] then
				table.insert(cli_cards, value_cards[i][1])
			else
				table.insert(cli_cards, COMB(table.remove(lepers, #lepers), i))
			end
		end
		return cli_cards
	end

	local value_num = get_value_num(cards)

	local r = {}
	-- `3` .. `K`
	for i=1,0xd - ncards do
		local num = value_num[i] or 0
		local need = num == 1 and 0 or 1
		for j=1,ncards-1 do
			local num2 = value_num[i+j] or 0
			need = need + ((num2 == 1) and 0 or 1)
		end

		if nlepers >= need then
			table.insert(r, {type = TYPE.shunzi, weight = i})
		end
	end

	if #r > 2 then
		r = {r[1], r[#r]}
	end

	for i,t in ipairs(r) do
		t.cards = CLIENT and client_cards(t.weight) or nil
	end

	return #r > 0 and r or nil
end


return is_shunzi