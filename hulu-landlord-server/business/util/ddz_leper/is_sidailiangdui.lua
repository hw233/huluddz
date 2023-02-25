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


local function is_sidailiangdui(cards)
	local ncards = #cards
	if ncards ~= 8 then
		return
	end
	if V(cards[1]) == V(cards[8]) then
		return
	end

	local lepers = remove_lepers(cards)
	local nlepers = #lepers
	local value_num = get_value_num(cards)

	local function client_cards(start_v)
		local cards = table.copy(cards)
		local lepers = table.copy(lepers)
		local value_cards = get_value_cards(cards)
		local cli_cards = {}
		local vcards = value_cards[start_v]
		local need = vcards and (#vcards >= 4 and 0 or 4 - #vcards) or 4

		if need > 0 then
			table.append(cli_cards, COMB(table.splice(lepers, #lepers - need + 1, #lepers), start_v))
		end
		if vcards then
			table.append(cli_cards, table.splice(vcards, 1, 4 - need))
		end

		-- append other cards and sup-leprosy(`3`)
		for v,cardlist in pairs(value_cards) do
			if #cardlist%2 ~= 0 then
				table.insert(cli_cards, COMB(table.remove(lepers, #lepers), v))
			end
			table.append(cli_cards, cardlist)
		end

		if #lepers > 0 then
			assert(#lepers%2 == 0)
			local min_v = start_v ~= 0x1 and 0x1 or 0x2
			table.append(cli_cards, COMB(lepers, min_v))
		end

		return cli_cards
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

	for i=1,0xd  do
		local num = value_num[i] or 0
		local need = (num >= 4) and 0 or (4 - num)
		
		if nlepers >= need then
			local value_num = table.copy(value_num)
			if value_num[i] then
				value_num[i] = value_num[i] - (4 - need) 
			end
			if other_cards_is_two_pair(value_num, nlepers - need) then
				table.insert(r, {type = TYPE.sidailiangdui, weight = i})
			end
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


return is_sidailiangdui