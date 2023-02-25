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


local function is_feiji_budai(cards)
	local ncards = #cards
	if ncards < 6 or ncards%3 ~= 0 then
		return
	end

	local nthree = ncards//3
	local lepers = remove_lepers(cards)
	local nlepers = #lepers

	if find_value(cards, 0xd) or king_count(cards) > 0 then
		return
	end

	-- 癞子炸除外
	if nlepers == ncards then
		return
	end

	local min_v = MIN_V(cards)
	local max_v = MAX_V(cards)
	if max_v - min_v >= nthree then
		return
	end

	-- 同样数值的牌不能超过3张
	if helper.have_samecard_over_of(cards, 3) then
		return
	end

	if nlepers == 0 then
		return {{type = TYPE.feiji_budai, weight = V(cards[1]), cards = CLIENT and helper.client_sort(cards) or nil}}
	end

	local function client_cards(start_v)
		local cards = table.copy(cards)
		local lepers = table.copy(lepers)
		local value_cards = get_value_cards(cards)

		local cli_cards = {}
		for i = start_v + nthree - 1, start_v, -1 do
			local vcards = value_cards[i]
			local need = vcards and (#vcards >= 3 and 0 or 3 - #vcards) or 3

			if need > 0 then
				table.append(cli_cards, COMB(table.splice(lepers, #lepers-need+1, #lepers), i))
			end

			if vcards then
				table.append(cli_cards, vcards)
			end
		end
		return cli_cards
	end

	local value_num = get_value_num(cards)


	local r = {}
	-- `3` .. `K`
	for i=1,0xd - nthree do
		local num = value_num[i] or 0
		local need = 3 - num
		for j=1,nthree-1 do
			local num2 = value_num[i+j] or 0
			need = need + (3 - num2)
		end

		if nlepers >= need then
			table.insert(r, {type = TYPE.feiji_budai, weight = i})
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


return is_feiji_budai