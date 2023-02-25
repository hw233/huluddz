local helper = require "util.ddz_leper.helper"

local CLIENT = helper.CLIENT
local C = helper.C
local V = helper.V
local TYPE = helper.TYPE
local COMB = helper.COMB
local ZHADAN = helper.ZHADAN
local remove_lepers = helper.remove_lepers
local king_count = helper.king_count



local function is_zhadan(cards)
	local ncards = #cards
	if ncards < 4 then
		return
	end

	local lepers = remove_lepers(cards)
	local nleper = #lepers

	-- 去掉癞子不能有王
	if king_count(cards) > 0 then
		return
	end

	local function client_cards(v)
		lepers = COMB(lepers, v)
		table.append(lepers, cards)
		return lepers
	end


	-- TODO: 这里应该是癞子炸(如果是n张一样的癞子 则是纯n癞子炸)
	assert(nleper ~= ncards)


	-- 软炸 硬炸 5星 6星
	if #cards == 1 or V(cards[1]) == V(cards[#cards]) then
		local zhadan_weight
		if ncards == 4 then
			if nleper == 0 then
				zhadan_weight = ZHADAN.yingzha.weight
			else
				zhadan_weight = ZHADAN.ruanzha.weight
			end
		elseif ncards == 5 then
			zhadan_weight = ZHADAN.star_5.weight
		elseif ncards == 6 then
			zhadan_weight = ZHADAN.star_6.weight
		else
			error("invalid cards num:", ncards)
		end

		return {{type = TYPE.zhadan, weight = COMB(V(cards[1]), zhadan_weight), cards = CLIENT and client_cards(V(cards[1])) or nil}}
	end
end



return is_zhadan