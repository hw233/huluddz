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


local function is_lianzha(cards)
	local ncards = #cards
	if ncards < 8 or ncards%4 ~= 0 then
		return
	end
	-- 这个属于炸弹(N星炸)
	if V(cards[1]) == V(cards[#cards]) then
		return
	end

	-- 去掉癞子不能有王
	if king_count(cards) > 0 then
		return
	end

	-- 同样数值的牌不能超过4张
	if helper.have_samecard_over_of(cards, 4) then
		return
	end

	local value_num = get_value_num(cards)
	local nzhadan = ncards//4

	local r = {}

	-- `3` .. `K`
	local lianzha_check_f = true
	local num1_i = 1
	for i=1,0xd - nzhadan do
		local num = value_num[i] or 0
		num1_i = i
		if num1 == 4 then
			for j=1,nzhadan-1 do
				local num2 = value_num[i+j] or 0
				if num2 ~= 4 then
					lianzha_check_f = false 
					break
				end
			end
		end
	end

	if lianzha_check_f then
		local value_cards = get_value_cards(cards)
		table.insert(r, {type = TYPE.zhadan, weight = COMB(num1_i, helper.ZHADAN["star_4_" .. nzhadan].weight), cards = CLIENT and value_cards or nil})	
	end
	

	-- if #r > 2 then
	-- 	r = {r[1], r[#r]}
	-- end

	-- for i,t in ipairs(r) do
	-- 	t.cards = CLIENT and client_cards(t.weight & 0xf) or nil
	-- end

	return #r > 0 and r or nil
end

return is_lianzha