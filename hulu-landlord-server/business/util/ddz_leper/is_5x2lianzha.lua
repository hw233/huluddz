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


local function is_5x2lianzha(cards)
	local ncards = #cards
	if ncards ~= 10 then
		return
	end

	local lepers = remove_lepers(cards)
	local nlepers = #lepers

	-- 这个属于炸弹(N星炸)
	if V(cards[1]) == V(cards[#cards]) then
		return
	end

	-- 去掉癞子不能有王
	if king_count(cards) > 0 then
		return
	end

	if helper.have_samecard_over_of(cards, 5) then
		return
	end

	local value_num = get_value_num(cards)
	local nzhadan = 2

	local function client_cards(start_v)
		local cards = table.copy(cards)
		local lepers = table.copy(lepers)
		local value_cards = get_value_cards(cards)

		local cli_cards = {}
		for i = start_v, start_v + nzhadan - 1 do
			local vcards = value_cards[i]
			local need = vcards and (5 - #vcards) or 5

			if need > 0 then
				table.append(cli_cards, COMB(table.splice(lepers, #lepers-need+1, #lepers), i))
			end

			if vcards then
				table.append(cli_cards, vcards)
			end
		end
		return cli_cards
	end


	local r = {}

	for i=1,0xd - nzhadan do
		local num = value_num[i] or 0
		local need = num >= 5 and 0 or (5 - num)
		for j=1,nzhadan-1 do
			local num2 = value_num[i+j] or 0
			need = need + ((num2 >= 5) and 0 or (5 - num2))
		end

		if nlepers >= need then
			table.insert(r, {type = TYPE.zhadan, weight = COMB(i, helper.ZHADAN.star_5_2.weight)})
		end
	end

	if #r > 2 then
		r = {r[1], r[#r]}
	end

	for i,t in ipairs(r) do
		t.cards = CLIENT and client_cards(t.weight & 0xf) or nil
	end

	return #r > 0 and r or nil
end

return is_5x2lianzha