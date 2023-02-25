local helper = require "util.ddz_classic.helper"

local is_zhadan = require "util.ddz_classic.is_zhadan"
local is_sandaiyi = require "util.ddz_classic.is_sandaiyi"

local is_sandaiyidui = require "util.ddz_classic.is_sandaiyidui"
local is_sidaier = require "util.ddz_classic.is_sidaier"
local is_sidailiangdui = require "util.ddz_classic.is_sidailiangdui"
local is_shunzi = require "util.ddz_classic.is_shunzi"
local is_liandui = require "util.ddz_classic.is_liandui"
local is_feiji_budai = require "util.ddz_classic.is_feiji_budai"
local is_feiji_daidan = require "util.ddz_classic.is_feiji_daidan"
local is_feiji_daidui = require "util.ddz_classic.is_feiji_daidui"
local is_lianzha = require "util.ddz_classic.is_lianzha"
local is_5x2lianzha = require "util.ddz_classic.is_5x2lianzha"



local M = table.copy(helper)

local CLIENT = helper.CLIENT
local TYPE = helper.TYPE
local C = helper.C
local V = helper.V
local COMB = helper.COMB


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
	if v1 == 0xe and v2 == 0xf then
		return {{type = TYPE.zhadan, weight = COMB(0, helper.ZHADAN.wangzha.weight), cards = CLIENT and cards or nil}}
	end

	if v1 == v2 then
		table.insert(r, {type = TYPE.dui, weight = v1, cards = CLIENT and cards or nil})
	end

	return #r > 0 and r or nil
end


local function three_cards_type(cards)
	local r = {}

	if (V(cards[1]) == V(cards[#cards])) then
		local weight = V(cards[1])
		table.insert(r, {type = TYPE.tuple, weight = weight, cards = CLIENT and cards or nil})
	end

	return r
end


local function four_cards_type(cards)
	local r = {}
	local t1 = is_zhadan(table.copy(cards))
	local t2 = is_sandaiyi(table.copy(cards))
	if t1 then
		table.append(r, t1)
	end
	if t2 then
		table.append(r, t2)
	end
	return #r > 0 and r or nil
end


local function over_4_cards_type(cards)
	local funcs = {
		is_zhadan,-- 5炸  3人斗地主不会触发
		is_sandaiyidui,--5
		is_sidaier,--6  4444 大王小王   TODO：先允许带王
		is_sidailiangdui,--4444 33 55 or 4444 55 55 
		is_shunzi,-- TODO： 同天顺是否独立为类型，是否加倍数
		is_liandui,-- 最小3个组合
		is_feiji_budai, -- 两种组合
		is_feiji_daidan, -- 最小3种组合 333444_5_6  333444_5_5
		is_feiji_daidui, -- 最小3种组合 333444_55_66 or 333444_55_55
		is_5x2lianzha, -- 5炸 3人斗地主不会触发
		is_lianzha, -- 
	}

	local r = {}
	for _,f in ipairs(funcs) do
		t = f(table.copy(cards))
		if t then
			table.append(r, t)
		end
	end
	return #r > 0 and r or false
end


function M.card_types(cards)
	cards = sort_cards(table.copy(cards))
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
			return true
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

--  硬炸 < 王炸 < 5星炸 < 2连炸 < 6星炸 < 5星2连 < 3连炸 < 4连炸 < 5 连炸
function M.gt(c1, c2)
	local cards1, type1, weight1 = c1.cards, c1.type, c1.weight
	local cards2, type2, weight2 = c2.cards, c2.type, c2.weight
	assert(M.check_type(cards1, type1, weight1))
	assert(M.check_type(cards2, type2, weight2))

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


return M