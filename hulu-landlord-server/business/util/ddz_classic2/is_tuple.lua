local helper = require "util.ddz_classic.helper"

local CLIENT = helper.CLIENT
local C = helper.C
local V = helper.V
local TYPE = helper.TYPE
local COMB = helper.COMB
local get_value_num = helper.get_value_num
local get_value_cards = helper.get_value_cards


local function is_tuple(cards)
	local ncards = #cards
	if ncards ~= 3 then
		return
	end
	
	local value_num = get_value_num(cards)

	local r = {}

	for i=1,0xd do
		local num = value_num[i] or 0
		if num == 3 then
			table.insert(r, {type = TYPE.is_tuple, weight = i ,cards =CLIENT and cards or nil })
			break
		end		
	end

	return #r > 0 and r or nil
end

return is_tuple