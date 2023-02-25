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


local function is_feiji_daidui(cards)
	local ncards = #cards
	if ncards < 10 or ncards%5 ~= 0 then
		return
	end
	local value_num = get_value_num(cards)

	local nthree = ncards//5

	-- 减去飞机主体后的牌的信息
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
	local feiji_check_f = true
	local num1_i = 1
	for i=1,0xd - nthree do
		local num1 = value_num[i] or 0
		num1_i = i
		if num1 == 3 then
			for j=1,nthree-1 do
				local num2 = value_num[i+j] or 0
				if num2 ~= 3 then
					feiji_check_f = false 
					break
				end
			end
			break
		end
	end
		
	if feiji_check_f then
		--减去飞机主体
		for k = num1_i , num1_i + nthree-1 do
			if value_num[k] then
				value_num[k] = value_num[k] - 3
			end
		end

		if other_cards_is_pairs(value_num, 0) then
			local value_cards = get_value_cards(cards)
			table.insert(r, {type = TYPE.feiji_daidui, weight = num1_i,cards = CLIENT and value_cards or nil})			
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


return is_feiji_daidui