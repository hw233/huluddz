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


local function is_feiji_daidan(cards)
	local ncards = #cards
	if ncards < 8 or ncards%4 ~= 0 then
		return
	end
	local value_num = get_value_num(cards)

	local nthree = ncards//4

	print("nthree",ncards,nthree)

	local r = {}
	-- `3` .. `K`
	local feiji_check_f = true
	local num1_i = 1
	for i=1,0xd - nthree do
		local num1 = value_num[i] or 0
		num1_i = i
		if num1 == 3 then
			for j=1,nthree-1 do
				print(j,i,i+j,value_num[i+j])
				local num2 = value_num[i+j] or 0
				if num2 ~= 3 then
					feiji_check_f = false 
					break
				end
			end
			break
		end
	end
	
	
	print("feiji_check_f",feiji_check_f)
	if feiji_check_f then
		local value_cards = get_value_cards(cards)
		table.insert(r, {type = TYPE.feiji_daidan, weight = num1_i,cards = CLIENT and value_cards or nil})
	end

	-- if #r > 2 then
	-- 	r = {r[1], r[#r]}
	-- end

	-- for i,t in ipairs(r) do
	-- 	t.cards = CLIENT and client_cards(t.weight) or nil
	-- end

	return #r > 0 and r or nil
end


return is_feiji_daidan