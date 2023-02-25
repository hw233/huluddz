local helper = require "util.ddz_classic.helper"

local CLIENT = helper.CLIENT
local C = helper.C
local V = helper.V
local TYPE = helper.TYPE
local COMB = helper.COMB
local get_value_num = helper.get_value_num
local get_value_cards = helper.get_value_cards
local king_count = helper.king_count
local find_value = helper.find_value


local zha_star_num =5 --5星炸

local function is_5x2lianzha(cards)
	local ncards = #cards
	if ncards ~= 10 then
		return
	end

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

	local r = {}

	local value_cards = get_value_cards(cards)

	for i=1,0xd - nzhadan do
		local num1 = value_num[i] or 0
		if num1 == zha_star_num then		
			local num2 = value_num[i+1] or 0
			if num2 == zha_star_num then
				--2个连续5星炸
				table.insert(r, {type = TYPE.zhadan, weight = COMB(i, helper.ZHADAN.star_5_2.weight),cards = CLIENT and value_cards or nil})
			end		
		end
	end

	if #r > 2 then
		r = {r[1], r[#r]}
	end	

	return #r > 0 and r or nil
end

return is_5x2lianzha