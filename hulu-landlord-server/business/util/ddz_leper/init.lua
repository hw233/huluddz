local helper = require "util.ddz_leper.helper"

local is_sandaiyi = require "util.ddz_leper.is_sandaiyi"
local is_sandaiyidui = require "util.ddz_leper.is_sandaiyidui"
local is_sidaier = require "util.ddz_leper.is_sidaier"
local is_sidailiangdui = require "util.ddz_leper.is_sidailiangdui"
local is_shunzi = require "util.ddz_leper.is_shunzi"
local is_liandui = require "util.ddz_leper.is_liandui"
local is_feiji_budai = require "util.ddz_leper.is_feiji_budai"
local is_feiji_daidan = require "util.ddz_leper.is_feiji_daidan"
local is_feiji_daidui = require "util.ddz_leper.is_feiji_daidui"

local is_laizizha = require "util.ddz_leper.is_laizizha"
local is_xingzha = require "util.ddz_leper.is_xingzha"


local M = helper.init("ddz")

local CLIENT = helper.CLIENT
local TYPE = helper.TYPE
local C = helper.C
local V = helper.V
local COMB = helper.COMB
local king_count = helper.king_count


local function DIVISION(n)
	return n>>8, n&0xff
end

local function sort_cards(cards)
	table.sort(cards, function (a, b)
		local va = V(a)
		local vb = V(b)
		if va == vb then
			return C(a) < C(b)
		else
			return va < vb
		end
	end)
	return cards
end


local function two_cards_type(cards)
	local r = {}
	local v1 = V(cards[1])
	local v2 = V(cards[2])

	local lepers = M.remove_lepers(cards)
	local nlepers = #lepers

	if nlepers == 2 then
		error("should be laiziha_2")
	else
		-- 普通牌中不能有王
		if king_count(cards) == 0 then
			if nlepers == 1 then
				local weight = V(cards[1])
				table.insert(r, {type = TYPE.dui, weight = weight, cards = CLIENT and {COMB(lepers[1], weight), cards[1]} or nil})
			elseif v1 == v2 then
				table.insert(r, {type = TYPE.dui, weight = v1, cards = CLIENT and cards or nil})
			end
		end
	end

	return #r > 0 and r or nil
end


local function three_cards_type(cards)
	local r = {}
	local lepers = M.remove_lepers(cards)
	local nlepers = #lepers

	local function client_cards(w)
		local cli_cards = COMB(lepers, w)
		table.append(cli_cards, cards)
		return cli_cards
	end

	-- 去掉癞子后不能有王
	if king_count(cards) > 0 then
		return
	end
	if nlepers == 3 then
		error("should be laiziha_3")
	else
		if nlepers == 2 or (V(cards[1]) == V(cards[#cards])) then
			local weight = V(cards[1])
			table.insert(r, {type = TYPE.tuple, weight = weight, cards = CLIENT and client_cards(weight) or nil})
		end
	end

	return r
end


local function four_cards_type(cards)
	return is_sandaiyi(table.copy(cards))
end


local function over_4_cards_type(cards)
	local funcs = {
		is_sandaiyidui,
		is_sidaier,
		is_sidailiangdui,
		is_shunzi,
		is_liandui,
		is_feiji_budai,
		is_feiji_daidan,
		is_feiji_daidui,
	}

	local r = {}
	for _,f in ipairs(funcs) do
		local t = f(table.copy(cards))
		if t then
			table.append(r, t)
		end
	end
	return #r > 0 and r or false
end


local function is_zhadan(cards)
	return is_laizizha(cards) or is_xingzha(cards)
end


function M.card_types(cards)
	if not cards or #cards == 0 then
		print("ddz_leper.card_types get invalid arguments")
		return
	end
	
	cards = sort_cards(table.copy(cards))
	local zhadan = is_zhadan(cards)
	if zhadan then
		local result = {zhadan}

		-- 333 W 也是三带1
		local types = four_cards_type(cards)
		if types then
			table.append(result, types)
		end
		return result
	end

	local ncards = #cards
	if ncards == 1 then
		return {{type = TYPE.dan, weight = V(cards[1]), cards = CLIENT and cards or nil}}
	elseif ncards == 2 then
		return two_cards_type(cards)
	elseif ncards == 3 then
		return three_cards_type(cards)
	elseif ncards == 4 then
		return four_cards_type(cards)
	else
		return over_4_cards_type(cards)
	end
end

function M.check_type(cards, type, weight)
	local types = M.card_types(cards)
	for _,t in ipairs(types) do
		if t.type == type and t.weight == weight then
			return t
		end
	end
	return false
end


local need_check_length = {
	shunzi = true,
	liandui = true,
	feiji_budai = true,
	feiji_daidan = true,
	feiji_daidui = true
}

-- 软炸 < 硬炸 < 王炸 < 5星炸 < 2连炸 < 6星炸 < 5星2连 < 3连炸 < 4连炸 < 5 连炸
function M.gt(c1, c2)
	local cards1, type1, weight1 = c1.cards, c1.type, c1.weight
	local cards2, type2, weight2 = c2.cards, c2.type, c2.weight
	c1 = assert(M.check_type(cards1, type1, weight1))
	c2 = assert(M.check_type(cards2, type2, weight2))

	if type1 == TYPE.zhadan and type2 ~= TYPE.zhadan then
		return true
	end

	if type1 ~= TYPE.zhadan and type2 == TYPE.zhadan then
		return false
	end

	if type1 ~= TYPE.zhadan and type2 ~= TYPE.zhadan then
		if type1 == type2 and weight1 > weight2 then
			if need_check_length[type1] then
				if #cards1 ~= #cards2 then
					return false
				end
			end
			return true
		end
	end

	if type1 == TYPE.zhadan and type2 == TYPE.zhadan then
		return weight1 > weight2
	end
end


function M.same_card(card, card2)
	return C(card) == C(card2) and V(card) == V(card2)
end


return M