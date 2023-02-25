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

local MIN_V = helper.MIN_V
local MAX_V = helper.MAX_V


local function is_feiji_daidan(cards)
	local ncards = #cards
	if ncards < 8 or ncards%4 ~= 0 then
		return
	end
	local lepers = remove_lepers(cards)
	local nlepers = #lepers
	local value_num = get_value_num(cards)

	local nthree = ncards//4

	local function client_cards(start_v)
		local cards = table.copy(cards)
		local lepers = table.copy(lepers)
		local value_cards = get_value_cards(cards)
		local cli_cards = {}


		local function append_three(v)
			local vcards = value_cards[v]
			local need = vcards and (#vcards >= 3 and 0 or 3 - #vcards) or 3

			if need > 0 then
				table.append(cli_cards, COMB(table.splice(lepers, #lepers - need + 1, #lepers), v))
			end
			if vcards then
				table.append(cli_cards, table.splice(vcards, 1, 3 - need))
			end
		end

		-- append main body
		for v=start_v+nthree-1,start_v,-1 do
			append_three(v)
		end

		-- append other cards and sup-leprosy(`3`)
		for v,cardlist in pairs(value_cards) do
			table.append(cli_cards, cardlist)
		end
		if #lepers > 0 then
			local min_v = start_v ~= 0x1 and 0x1 or (start_v + nthree)
			table.append(cli_cards, COMB(lepers, min_v))
		end

		return cli_cards
	end


	local r = {}
	-- `3` .. `K`
	for i=1,0xd - nthree do
		local num = value_num[i] or 0
		local need = num >= 3 and 0 or (3 - num)
		for j=1,nthree-1 do
			local num2 = value_num[i+j] or 0
			need = need + ((num2 >= 3) and 0 or (3 - num2))
		end

		if nlepers >= need then
			table.insert(r, {type = TYPE.feiji_daidan, weight = i})
		end
	end

	if #r > 2 then
		r = {r[1], r[#r]}
	end

	for i,t in ipairs(r) do
		t.cards = CLIENT and client_cards(t.weight) or nil
	end

	return #r > 0 and r or nil
end


return is_feiji_daidan