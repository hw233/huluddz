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


local function is_liandui(cards)
	local ncards = #cards
	if ncards < 6 or ncards%2 ~= 0 then
		return
	end

	local ndui = ncards//2

	if find_value(cards, 0xd) or king_count(cards) > 0 then
		return
	end

	local min_v = MIN_V(cards)
	local max_v = MAX_V(cards)
	if max_v - min_v >= ndui then
		return
	end

	-- 同样数值的牌不能超过2张
	if helper.have_samecard_over_of(cards, 2) then
		return
	end

	return {{type = TYPE.liandui, weight = V(cards[1]), cards = CLIENT and cards or nil}}
	
end


return is_liandui