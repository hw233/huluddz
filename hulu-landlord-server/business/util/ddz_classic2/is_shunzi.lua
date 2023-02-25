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
local check_flush = helper.check_flush

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
		
	if check_flush(cards,0) then
		return {{type = TYPE.shunzi, weight = V(cards[1]), cards = CLIENT and cards or nil}}
	end

	return nil
end


return is_shunzi