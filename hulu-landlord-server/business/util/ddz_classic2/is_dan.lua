local helper = require "util.ddz_classic.helper"

local CLIENT = helper.CLIENT
local TYPE = helper.TYPE
local V = helper.V
local get_value_num = helper.get_value_num
local get_value_cards = helper.get_value_cards


local function is_dan(cards)
	local ncards = #cards
	if ncards >1 then
		return
	end

	local r = {}
	local card_dan = cards[1]
	
	for i=1,0xd do	
		if i == V(card_dan) then			
			table.insert(r, {type = TYPE.dan, weight = i ,cards = CLIENT and cards or nil })
			break
		end		
	end

	return #r > 0 and r or nil
end

return is_dan