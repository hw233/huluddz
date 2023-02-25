local helper = require "util.ddz_classic.helper"

local CLIENT = helper.CLIENT
local C = helper.C
local V = helper.V
local TYPE = helper.TYPE
local COMB = helper.COMB
local ZHADAN = helper.ZHADAN


local function is_zhadan(cards)
	local ncards = #cards
	if ncards < 4 then
		return
	end

	-- 硬炸 5星 6星
	if V(cards[1]) == V(cards[#cards]) then
		local zhadan_weight
		if ncards == 4 then			
			zhadan_weight = ZHADAN.yingzha.weight		
		elseif ncards == 5 then
			zhadan_weight = ZHADAN.star_5.weight
		elseif ncards == 6 then
			zhadan_weight = ZHADAN.star_6.weight
		else
			error("invalid cards num:", ncards)
		end

		return {{type = TYPE.zhadan, weight = COMB(V(cards[1]), zhadan_weight), cards = CLIENT and cards or nil}}
	end
end



return is_zhadan