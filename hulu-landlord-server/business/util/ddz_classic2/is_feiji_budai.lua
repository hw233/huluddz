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

local MIN_V = helper.MIN_V
local MAX_V = helper.MAX_V


local function is_feiji_budai(cards)
	local ncards = #cards
	if ncards < 6 or ncards%3 ~= 0 then
		return
	end

	local nthree = ncards//3

	if find_value(cards, 0xd) or king_count(cards) > 0 then
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

	return {{type = TYPE.feiji_budai, weight = V(cards[1]), cards = CLIENT and cards or nil}}	
end


return is_feiji_budai