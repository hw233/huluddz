local helper = require "util.ddz_classic.helper"

local CLIENT = helper.CLIENT
local C = helper.C
local V = helper.V
local TYPE = helper.TYPE
local COMB = helper.COMB
local get_value_num = helper.get_value_num
local get_value_cards = helper.get_value_cards
local king_count = helper.king_count


local function is_sandaiyidui(cards)
	local ncards = #cards
	if ncards ~= 5 then
		return
	end

	if king_count(cards) > 0 then
		return
	end

	local value_num = get_value_num(cards)

	local function other_cards_is_pairs(value_num, supleprosy)
		for v,n in pairs(value_num) do
			if n%2 ~= 0 then
				supleprosy = supleprosy - 1
				if supleprosy < 0 then
					return false
				end
			end
		end
		return true
	end

	local r = {}

	-- `3` .. `K`
	local flush3_check_f = true
	for i=1,0xd do
		local num = value_num[i] or 0
		if num == 3 then
			--移除3张主体
			local value_num = table.copy(value_num)
			if value_num[i] then
				value_num[i] = value_num[i] - 3
				if other_cards_is_pairs(value_num,0) then
					local value_cards = get_value_cards(cards)
					table.insert(r, {type = TYPE.sandaiyidui, weight = i,cards = CLIENT and value_cards[i] or nil})
				end
			end
		end
	end

	-- if #r > 2 then
	-- 	r = {r[1], r[#r]}
	-- end

	return #r > 0 and r or nil
end


return is_sandaiyidui