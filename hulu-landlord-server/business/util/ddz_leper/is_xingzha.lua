local helper = require "util.ddz_leper.helper"

local CLIENT = helper.CLIENT
local C = helper.C
local V = helper.V
local TYPE = helper.TYPE
local COMB = helper.COMB
local remove_lepers = helper.remove_lepers
local get_value_num = helper.get_value_num
local get_value_cards = helper.get_value_cards
local king_count = helper.king_count
local find_value = helper.find_value


local function is_xingzha(star, cards, lepers)
	local nlepers = #lepers
	local ncards = #cards + nlepers

	if ncards%star ~= 0 then
		return
	end

	if helper.have_samecard_over_of(cards, star) then
		return
	end

	local value_num = get_value_num(cards)
	local nzhadan = ncards//star

	-- 连炸中不能有2
	if nzhadan > 1 and value_num[0xd] then
		return
	end

	local function client_cards(start_v)
		local cards = table.copy(cards)
		local lepers = table.copy(lepers)
		local value_cards = get_value_cards(cards)

		local cli_cards = {}
		for i = start_v + nzhadan - 1, start_v, -1 do
			local vcards = value_cards[i]
			local need = vcards and (star - #vcards) or star

			if need > 0 then
				table.append(cli_cards, COMB(table.splice(lepers, #lepers-need+1, #lepers), i))
			end

			if vcards then
				table.append(cli_cards, vcards)
			end
		end
		return cli_cards
	end

	for i=0xd-nzhadan+1,1,-1 do
		local num = value_num[i] or 0
		local need = num >= star and 0 or (star - num)
		for j=1,nzhadan-1 do
			local num2 = value_num[i+j] or 0
			need = need + ((num2 >= star) and 0 or (star - num2))
		end

		if nlepers >= need then
			return {type = TYPE.zhadan, soft = nlepers > 0, weight = COMB(i, helper.WEIGHT["star_"..star.."_"..nzhadan]), cards = CLIENT and client_cards(i) or nil}
		end
	end
end




return function(cards)
	cards = table.copy(cards)
	local lepers = remove_lepers(cards)

	local list = {}

	for star=4,8 do
		local r = is_xingzha(star, cards, lepers)
		if r then
			table.insert(list, r)
		end
	end

	if #list > 0 then
		table.sort(list, function (a, b)
			return a.weight > b.weight
		end)
		return list[1]
	end
end