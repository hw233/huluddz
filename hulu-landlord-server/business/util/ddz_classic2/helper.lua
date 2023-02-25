--经典斗地主
local helper = {
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
	},

	-- 炸弹权重
	-- 硬炸 < 王炸 < 5星炸 < 2连炸 < 6星炸 < 5星2连 < 3连炸 < 4连炸 < 5 连炸
	ZHADAN = {
		ruanzha = 	{weight = 1, multiple = 2},  -- 软炸 没癞子= 无效
		yingzha = 	{weight = 2, multiple = 2},
		wangzha = 	{weight = 3, multiple = 2},
		star_5 = 	{weight = 4, multiple = 4},
		star_4_2 = 	{weight = 5, multiple = 6},		-- (4星)2连炸
		star_6 = 	{weight = 6, multiple = 10},
		star_4_3 = 	{weight = 7, multiple = 18},
		star_5_2 = 	{weight = 8, multiple = 20}, 	-- 5星2连炸
		star_4_4 = 	{weight = 9, multiple = 48},
		star_4_5 = 	{weight = 10, multiple = 108}
	}
}

local zhadan_msg = {}
for k,v in pairs(helper.ZHADAN) do
	zhadan_msg[v.weight] = k
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


function helper.zhadan_weight(typename)
	local t = assert(helper.ZHADAN[typename], typename)
	return t.weight
end

function helper.zhadan_type(weight)
	return zhadan_msg[weight >> 8]
end

function helper.zhadan_multiple(weight)
	local name = assert(helper.zhadan_type(weight))
	local t = helper.ZHADAN[name]
	return t.multiple
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

function helper.is_king(card)
	return V(card) >= 0xe
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

--已排序卡牌验证是递增顺子
--可以使用leperk补位
function helper.check_flush(cards,leperk_num)
	local len = #cards
	if len <3 then
		return false
	end

	local need = 0
	local tmp_v = V(cards[1])
	local i=2
	while i<=len do
		if tmp_v + 1 == V(cards[i]) then			
			--通过
			i = i + 1
		elseif leperk_num > need then
			--癞子补位
			need = need + 1
			--回退 i
		else 
			return false
		end
		tmp_v = tmp_v + 1		
	end
	
	return true
end

--移除王
function helper.remove_lepers(cards)
	local kings = {}
	for i=#cards,1,-1 do
		if helper.is_king(cards[i]) then
			table.insert(kings, table.remove(cards, i))
		end
	end
	return kings
end


return helper