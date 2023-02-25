local function VI(list)
	for i,v in ipairs(list) do
		list[v] = i
	end
	return list
end

local helper = {
	game = nil,
	CLIENT = true,
	TYPE = {
		dan = "dan",						-- 单牌
		dui = "dui",						-- 对牌
		tuple = "tuple", 					-- 三张
		sandaiyi = "sandaiyi", 				-- 三带一
		sandaiyidui = "sandaiyidui", 		-- 三带一对
		shunzi = "shunzi", 					-- 顺子
		liandui = "liandui", 				-- 连对
		feiji_budai = "feiji_budai", 		-- 飞机不带
		feiji_daidan = "feiji_daidan", 		-- 飞机带单
		feiji_daidui = "feiji_daidui", 		-- 飞机带对
		sidaier = "sidaier", 				-- 四带二
		sidailiangdui = "sidailiangdui",	-- 四带两对
		zhadan = "zhadan",					-- 炸弹
	}
}


function helper.init(name)
	if name == "ddz" then
		helper.ZHADAN = {
			laizizha_2 = 2,

			star_4_1 = 2,
			star_4_2 = 6,
			star_4_3 = 18,
			star_4_4 = 48,
			star_4_5 = 108,

			star_5_1 = 4,
			star_5_2 = 20,

			star_6_1 = 10,
		}
		helper.WEIGHT = VI{
			"star_4_1",
			"laizizha_2",
			"star_5_1",
			"star_4_2",
			"star_6_1",
			"star_4_3",
			"star_5_2",
			"star_4_4",
			"star_4_5"
		}
	else
		assert(name == "ddz4")
		helper.ZHADAN = {
			laizizha_2 = 2,
			laizizha_3 = 4,
			laizizha_4 = 5,

			star_4_1 = 2,
			star_4_2 = 3,
			star_4_3 = 4,
			star_4_4 = 6,
			star_4_5 = 7,
			star_4_6 = 8,

			star_5_1 = 3,
			star_5_2 = 4,
			star_5_3 = 5,
			star_5_4 = 7,
			star_5_5 = 10,

			star_6_1 = 3,
			star_6_2 = 5,
			star_6_3 = 6,
			star_6_4 = 8,

			star_7_1 = 3,
			star_7_2 = 6,
			star_7_3 = 7,

			star_8_1 = 4,
			star_8_2 = 6,
			star_8_3 = 8,	
		}
		helper.WEIGHT = VI{
			"star_4_1",
			"laizizha_2",
			"star_5_1",
			"star_4_2",
			"star_6_1",
			"star_7_1",
			"laizizha_3",
			"star_5_2",
			"star_4_3",
			"star_8_1",
			"laizizha_4",
			"star_6_2",
			"star_5_3",
			"star_4_4",
			"star_7_2",
			"star_8_2",
			"star_6_3",
			"star_4_5",
			"star_5_4",
			"star_7_3",
			"star_4_6",
			"star_6_4",
			"star_8_3",
			"star_5_5",
		}
	end
	helper.game = name
	return helper
end


-- base
function helper.C(card)
	card = card & 0xff
	local c = (card>>4)%5
	if c == 0 then
		return 5
	else
		return c
	end
end

function helper.V(card)
	return card&0x0f
end

-- Transformed Value (癞子变身后的 value)
function helper.TV(card)
	return card >> 8
end

function helper.zhadan_weight(typename)
	return helper.WEIGHT[typename]
end

function helper.zhadan_type(weight)
	return helper.WEIGHT[weight >> 8]
end

function helper.zhadan_multiple(weight)
	local name = assert(helper.zhadan_type(weight))
	return helper.ZHADAN[name]
end


function helper.COMB(card, tv)
	if type(card) == "number" then
		return (tv << 8) + card
	else
		-- cardlist
		card = table.copy(card)
		for i,c in ipairs(card) do
			card[i] = (tv << 8) + c
		end
		return card
	end
end


-- ex
local C = helper.C
local V = helper.V


function helper.MIN_V(cards)
	local min = cards[1]
	local min_v = V(cards[1])

	for _,card in ipairs(cards) do
		if V(card) < min_v then
			min = card
			min_v = V(card)
		end
	end
	return min_v
end

function helper.MAX_V(cards)
	local max = cards[1]
	local max_v = V(cards[1])

	for _,card in ipairs(cards) do
		if V(card) > max_v then
			max = card
			max_v = V(card)
		end
	end
	return max_v
end


function helper.is_leper(card)
	return V(card) >= 0xe
end


function helper.is_king(card)
	return V(card) >= 0xe
end

-- 大小王是癞子
function helper.leperk_count(cards)
	local n = 0
	for _,v in ipairs(cards) do
		if helper.is_leper(v) then
			n = n + 1
		end
	end
	return n
end


function helper.king_count(cards)
	local n = 0
	for _,v in ipairs(cards) do
		if helper.is_king(v) then
			n = n + 1
		end
	end
	return n
end

function helper.remove_lepers(cards)
	local lepers = {}
	for i=#cards,1,-1 do
		if helper.is_leper(cards[i]) then
			table.insert(lepers, table.remove(cards, i))
		end
	end
	return lepers
end


function helper.get_value_num(cards)
	local value_num = {}
	local v
	for i,card in ipairs(cards) do
		v = V(card)
		value_num[v] = (value_num[v] or 0) + 1
	end
	return value_num
end


function helper.get_value_cards(cards)
	local value_cards = {}
	for i,card in ipairs(cards) do
		local v = V(card)
		value_cards[v] = value_cards[v] or {}
		table.insert(value_cards[v], card)
	end
	return value_cards
end

function helper.find_value(cards, v)
	for _,card in ipairs(cards) do
		if V(card) == v then
			return card
		end
	end
end

function helper.have_samecard_over_of(cards, max_num)
	local v = V(cards[1])
	local n = 1
	for i=2,#cards do
		local card = cards[i]
		if V(card) == v then
			n = n + 1
			if n == max_num + 1 then
				return true
			end
		else
			v = V(card)
			n = 1
		end
	end
	return false
end

function helper.client_sort(cards)
	table.sort(cards, function (a, b)
		local v1 = V(a)
		local v2 = V(b)
		if v1 ~= v2 then
			return v1 > v2
		else
			return C(a) < C(b)
		end
	end)
	return cards
end


return helper