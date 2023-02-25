
local helper = require "util.ddz_classic.helper"
local parse = require "util.ddz_classic.parse"


local isClient = helper.isClient
local CardType = helper.CardType
local CardSubType = helper.CardSubType


local function parseCardTypeTwo(cards)
	local ret = {}
	local v1 = helper.V(cards[1])
	local v2 = helper.V(cards[2])
	if v1 == 0xe and v2 == 0xf then
		return {{type = CardType.zhadan, weight = helper.COMB(0, helper.BombInfoData.wangzha.weight), 
			cards = isClient and cards or nil, subtype = CardSubType.wangzha}}
	end
	if v1 == v2 then
		table.insert(ret, {type = CardType.dui, weight = v1, cards = isClient and cards or nil})
	end
	return ret
end

local function parseCardTypeThree(cards)
	local ret = {}
	if (helper.V(cards[1]) == helper.V(cards[#cards])) then
		table.insert(ret, {type = CardType.tuple, weight = helper.V(cards[1]), cards = isClient and cards or nil})
	end
	return ret
end

local function parseCardTypeFour(cards)
	local ret = {}
	local t1 = parse.isZhaDan(table.copy(cards))
	local t2 = parse.isSanDaiYi(table.copy(cards))
	if t1 then
		table.append(ret, t1)
	end
	if t2 then
		table.append(ret, t2)
	end
	return ret
end

local parseCardTypeOtherFuncArr = {
	--parse.isZhaDan, -- 3人斗地主不需要，在 parseCardTypeFour 中已经判断了
	parse.isSanDaiYiDui,
	parse.isSiDaiEr,
	parse.isSiDaiLiangDui,
	parse.isShunZi,
	parse.isLianDui,
	parse.isFeiJiBuDai,
	parse.isFeiJiDaiDan,
	parse.isFeiJiDaiDui,
	--parse.isLianZha5x2, -- 3人斗地主不需要
	parse.isLianZha4xN,
}

local function parseCardTypeOther(cards)
	local ret = {}
	local arr
	for _, func in ipairs(parseCardTypeOtherFuncArr) do
		arr = func(table.copy(cards))
		if arr then
			table.append(ret, arr)
		end
	end
	return ret
end

--- 解析牌型，返回所有匹配牌型
---@param cards table
---@return table Array 返回 nil 表示无匹配牌型
helper.parseCardType = function (cards)
	cards = helper.cardSort(table.copy(cards))
	local num = #cards

    local ret

	if num == 1 then
		ret = {{type = CardType.dan, weight = helper.V(cards[1]), cards = isClient and cards or nil}}
	elseif num == 2 then
		ret = parseCardTypeTwo(cards)
	elseif num == 3 then
		ret = parseCardTypeThree(cards)
	elseif num == 4 then
		ret = parseCardTypeFour(cards)
	else
		ret = parseCardTypeOther(cards)
	end

    if ret and #ret <= 0 then
        ret = nil
	else
		for index, value in ipairs(ret) do
			if not value.subtype then
				value.subtype = value.type
			end
		end
    end
    return ret
end

--- 解析牌型, 这个只返回一个牌型
---@param cards table
---@return table Object 返回 nil 表示无匹配牌型
helper.parseCardTypeOnly = function (cards)
	local arr = helper.parseCardType(cards)
	if arr then
		local obj = arr[1]
		obj.cards = cards
		return obj
	end
end

helper.checkCardType = function (cards, type, weight)
	local arr = helper.parseCardType(cards)
	for _, obj in ipairs(arr) do
		if obj.type == type and obj.weight == weight then
			return true
		end
	end
	return false
end

local needCheckLength = {
	[CardType.shunzi] = true,
	[CardType.liandui] = true,
	[CardType.feiji_budai] = true,
	[CardType.feiji_daidan] = true,
	[CardType.feiji_daidui] = true,
}

helper.compareCardType = function (cardTypeObj1, cardTypeObj2)
	local cards1, type1, weight1 = cardTypeObj1.cards, cardTypeObj1.type, cardTypeObj1.weight
	local cards2, type2, weight2 = cardTypeObj2.cards, cardTypeObj2.type, cardTypeObj2.weight
	assert(helper.checkCardType(cards1, type1, weight1))
	assert(helper.checkCardType(cards2, type2, weight2))

	if type1 == CardType.zhadan and type2 ~= CardType.zhadan then
		return true
	elseif type1 ~= CardType.zhadan and type2 == CardType.zhadan then
		return false
	elseif type1 == CardType.zhadan and type2 == CardType.zhadan then
		return weight1 > weight2
	else
		if type1 == type2 and weight1 > weight2 then
			if needCheckLength[type1] then
				if #cards1 ~= #cards2 then
					return false
				end
			end
			return true
		end
	end
end


return helper