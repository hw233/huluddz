local helper = require "util.ddz_leper.helper"

local CLIENT = helper.CLIENT
local C = helper.C
local V = helper.V
local TYPE = helper.TYPE
local COMB = helper.COMB
local remove_lepers = helper.remove_lepers
local get_value_num = helper.get_value_num
local get_value_cards = helper.get_value_cards


local function is_sandaiyi(cards)
	local ncards = #cards
	if ncards ~= 4 then
		return
	end

	-- 硬炸
	if V(cards[1]) == V(cards[4]) then
		return
	end

	local lepers = remove_lepers(cards)
	local nleper = #lepers

	-- 4癞子炸
	if nleper == 4 then
		return
	end

	local value_num = get_value_num(cards)

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
		append_three(start_v)

		-- append other cards or sup-leprosy
		for v,cardlist in pairs(value_cards) do
			table.append(cli_cards, cardlist)
		end

		-- 多出的癞子不要与主体重复
		if #lepers > 0 then
			local min_v = start_v == 0x1 and 0x2 or 0x1 
			table.append(cli_cards, COMB(lepers, min_v))
		end

		return cli_cards
	end


	local r = {}

	for i=1,0xd do
		local num = value_num[i] or 0
		local need = num >= 3 and 0 or (3 - num)
		if nleper >= need then
			table.insert(r, {type = TYPE.sandaiyi, weight = i})
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


return is_sandaiyi