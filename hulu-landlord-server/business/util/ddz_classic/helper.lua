
--经典斗地主
local helper = {
	isClient = false, -- 算法是否为客户端使用
}

helper.CardType = {
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

-- 子类型，目前主要是特效时间使用
helper.CardSubType = {
	shunzi 			= "shunzi",
	tongtianshun 	= "tongtianshun",

	feiji 			= "feiji",
	super_feiji 	= "super_feiji",

	yingzha 		= "yingzha",
	wangzha 		= "wangzha",
	star_4_2 		= "star_4_2",
	star_4_3 		= "star_4_3",
	star_4_4 		= "star_4_4",
	star_4_5 		= "star_4_5",
}

-- 客户端枚举值
helper.ClientCardType = {
	dan = "dan",            -- 单牌
	dui = "dui",            -- 对牌
	tuple = "tuple",           -- 三张
	sandaiyi = "sandaiyi",         -- 三带一
	sandaiyidui = "sandaiyidui",     -- 三带一对
	shunzi = "shunzi",           -- 顺子
	liandui = "liandui",         -- 连对
	feiji_budai = "feiji_budai",     -- 飞机不带
	feiji_daidan = "feiji_daidan",     -- 飞机带单
	feiji_daidui = "feiji_daidui",     -- 飞机带对
	sidaier = "sidaier",         -- 四带二
	sidailiangdui = "sidailiangdui",  -- 四带两对
	zhadan = "zhadan",          -- 炸弹
  
	tongtianshun = "tongtianshun",    -- 通天顺
	feiji_2_top = "feiji_2_top",  --飞机向上飞
	feiji_l_2_r = "feiji_l_2_r", --飞机从左往右
	feiji_r_2_l = "feiji_r_2_l", --飞机从右往左
	feiji_idle = "feiji_idle", --飞机从右往左
	super_feiji_2_top = "super_feiji_2_top",
	super_feiji_l_2_r = "super_feiji_l_2_r",
	super_feiji_r_2_l = "super_feiji_r_2_l",
	super_feiji_idle = "super_feiji_idle",
	wangzha = "wangzha",    -- 王炸
	yingzha = "yingzha",    -- 普通炸弹
	star_4_2 = "star_4_2",    -- 2连炸
	star_4_3 = "star_4_3",    -- 3连炸
	star_4_4 = "star_4_4",    -- 4连炸
	star_4_5 = "star_4_5",    -- 5连炸
	zhadanyazhi = "zhadanyazhi",    -- 5连炸
	chuntian = "chuntian",    -- 春天
	fanchun = "fanchun",    -- 反春
  }

-- 炸弹权重  其中 multiple 没用了，走配置表了
-- 硬炸 < 王炸 < 5星炸 < 2连炸 < 6星炸 < 5星2连 < 3连炸 < 4连炸 < 5 连炸
helper.BombInfoData = {
	ruanzha = 	{weight = 1, multiple = 2},  -- 软炸 没癞子= 无效
	yingzha = 	{weight = 2, multiple = 2},
	wangzha = 	{weight = 3, multiple = 4},
	star_5 = 	{weight = 4, multiple = 4},
	star_4_2 = 	{weight = 5, multiple = 8},		-- (4星)2连炸
	star_6 = 	{weight = 6, multiple = 10},
	star_4_3 = 	{weight = 7, multiple = 12},
	star_5_2 = 	{weight = 8, multiple = 20}, 	-- 5星2连炸
	star_4_4 = 	{weight = 9, multiple = 36},
	star_4_5 = 	{weight = 10, multiple = 108}
}

-- 权重 - key
helper._BombWeightToKey = {}
for key, value in pairs(helper.BombInfoData) do
	helper._BombWeightToKey[value.weight] = key
end

helper.getBombType = function (weight)
	return helper._BombWeightToKey[weight >> 8]
end

helper.getBombInfo = function (weight)
	return helper.BombInfoData[helper.getBombType(weight)]
end


helper.C = function (card)
	card = card & 0xff
	local c = (card >> 4) % 5
	if c == 0 then
		return 5
	else
		return c
	end
end

helper.V = function (card)
	return card & 0x0f
end

helper.COMB = function (card, tv)
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

helper.is2 = function (card)
	return helper.V(card) == 0xd
end

helper.isA = function (card)
	return helper.V(card) == 0xc
end

helper.isKing = function (card)
	return helper.V(card) >= 0xe
end

helper.getKingCount = function (cards)
	local n = 0
	for _, v in ipairs(cards) do
		if helper.isKing(v) then
			n = n + 1
		end
	end
	return n
end

helper.cardSort = function (cards)
	table.sort(cards, function (a, b)
		local va = helper.V(a)
		local vb = helper.V(b)
		if va == vb then
			return helper.C(a) < helper.C(b)
		else
			return va < vb
		end
	end)
	return cards
end

--- 获取牌组中各面值数量
---@param cards any
---@return table
helper.getValueNumObj = function (cards)
	local ret, len = {}, 0
	local v, num
	for i, card in ipairs(cards) do
		v = helper.V(card)
		num = ret[v]
		if not num then
			num = 0
			len = len + 1
		end
		ret[v] = num + 1
	end
	return ret, len
end

--- 按牌组中各面值分组
---@param cards any
---@return table
helper.groupByValue = function (cards)
	local ret, len = {}, 0
	local v, arr
	for i, card in ipairs(cards) do
		v = helper.V(card)
		arr = ret[v]
		if not arr then
			arr = {}
			ret[v] = arr
			len = len + 1
		end
		table.insert(arr, card)
	end
	return ret, len
end

--移除王
helper.removeKing = function (cards)
	local kings = {}
	for i=#cards,1,-1 do
		if helper.isKing(cards[i]) then
			table.insert(kings, table.remove(cards, i))
		end
	end
	return kings
end


return helper