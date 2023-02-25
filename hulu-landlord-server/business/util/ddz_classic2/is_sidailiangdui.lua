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


local function is_sidailiangdui(cards)
	local ncards = #cards
	if ncards ~= 8 then
		return
	end
	if V(cards[1]) == V(cards[8]) then
		return
	end

	-- 同样数值的牌不能超过4张
	if helper.have_samecard_over_of(cards, 4) then
		return
	end

	local value_num = get_value_num(cards)
	local value_cards = get_value_cards(cards)

	--至少3种组合吧
	if #value_cards<3 then
		-- print("至少3种组合吧")
		return
	end

	local function other_cards_is_two_pair(value_num, supleprosy)

		local function count_pairs()
			local c = 0
			for v,num in pairs(value_num) do
				c = c + num//2
			end
			return c
		end

		if supleprosy >= 2 then
			return true
		end

		if supleprosy + count_pairs() == 2 then
			return true
		end
	end

	local r = {}
	-- `3` .. `K`
	local sidaier_check = true
	local num1_i = 1
	for i=1,0xd  do
		local num = value_num[i] or 0
		num1_i = i
		if num == 4 then		
			value_num = table.copy(value_num)
			value_num[i] = value_num[i] - 4 
			if other_cards_is_two_pair(value_num, 0) then
				
				table.insert(r, {type = TYPE.sidailiangdui, weight = i,cards = CLIENT and value_cards or nil})
			end
		end		
	end

	-- if #r > 2 then
	-- 	r = {r[1], r[#r]}
	-- end

	-- for i,t in ipairs(r) do
	-- 	t.cards = CLIENT and client_cards(t.weight) or nil
	-- end

	return #r > 0 and r or nil
end 


return is_sidailiangdui