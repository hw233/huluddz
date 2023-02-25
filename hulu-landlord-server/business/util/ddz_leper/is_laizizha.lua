local helper = require "util.ddz_leper.helper"

local CLIENT = helper.CLIENT
local C = helper.C
local V = helper.V
local TYPE = helper.TYPE
local COMB = helper.COMB
local remove_lepers = helper.remove_lepers
local get_value_num = helper.get_value_num
local get_value_cards = helper.get_value_cards
local leperk_count = helper.leperk_count
local find_value = helper.find_value


-- N王炸
local function is_laizizha(cards)
	local ncards = #cards
	local nlepers = leperk_count(cards)

	if ncards == nlepers and ncards >= 2 then
		return {
			type = TYPE.zhadan, 
			weight = COMB(0, helper.WEIGHT["laizizha_"..nlepers]),
			cards = CLIENT and cards or nil
		}
	end
end



return is_laizizha