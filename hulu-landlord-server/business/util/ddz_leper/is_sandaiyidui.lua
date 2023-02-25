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


local function is_sandaiyidui(cards)
	local ncards = #cards
	if ncards ~= 5 then
		return
	end

	local lepers = remove_lepers(cards)
	local nleper = #lepers

	-- 5癞子炸
	if nleper == 5 then
		return
	end

	if king_count(cards) > 0 then
		return
	end

	local value_num = get_value_num(cards)

	local function client_cards(start_v)
		local cards = table.copy(cards)
		local lepers = table.copy(lepers)
		local value_cards = get_value_cards(cards)
		local cli_cards = {}

		local function clear_empty()
			for k,v in pairs(value_cards) do
				if not next(v) then
					value_cards[k] = nil
				end
			end
		end

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
		append_three(start_v)
		clear_empty()

		-- append other cards or sup-leprosy
		if #lepers == 2 then
			local min_v = start_v == 0x1 and 0x2 or 0x1
			table.append(cli_cards, COMB(lepers, min_v))
		else
			local v, cardlist = next(value_cards)
			table.append(cli_cards, COMB(lepers, v))
			table.append(cli_cards, cardlist)
		end

		return cli_cards
	end

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

	for i=1,0xd do
		local num = value_num[i] or 0
		local need = num >= 3 and 0 or (3 - num)
		if nleper >= need then
			local value_num = table.copy(value_num)
			if value_num[i] then
				value_num[i] = value_num[i] - (3 - need)
			end
			if other_cards_is_pairs(value_num, nleper-need) then
				table.insert(r, {type = TYPE.sandaiyidui, weight = i})
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


return is_sandaiyidui