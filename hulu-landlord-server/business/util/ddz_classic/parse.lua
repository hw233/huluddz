local helper = require "util.ddz_classic.helper"

local isClient = helper.isClient
local CardType = helper.CardType
local CardSubType = helper.CardSubType
local BombInfoData = helper.BombInfoData

local parse = {}

parse.isZhaDan = function (cards)
    local num = #cards
	if num >= 4 then
		-- 硬炸 5星 6星
        if helper.V(cards[1]) == helper.V(cards[num]) then
            local bombInfo
            if num == 4 then
                bombInfo = BombInfoData.yingzha
            elseif num == 5 then
                bombInfo = BombInfoData.star_5
            elseif num == 6 then
                bombInfo = BombInfoData.star_6
            else
                error("invalid cards num:", num)
            end

            return {{type = CardType.zhadan, weight = helper.COMB(helper.V(cards[1]), bombInfo.weight), 
				cards = isClient and cards or nil, subtype = CardSubType.yingzha}}
        end
	end
end

parse.isSanDaiYi = function (cards)
	local ncards = #cards
	if ncards == 4 then
		-- 硬炸 或 2 != 3
        if helper.V(cards[1]) == helper.V(cards[4]) or helper.V(cards[2]) ~= helper.V(cards[3]) then
            return
        end

        local valueNumObj = helper.getValueNumObj(cards)
        local ret = {}

        for key, value in pairs(valueNumObj) do
            if value == 3 then
                table.insert(ret, {type = CardType.sandaiyi, weight = key , cards = isClient and cards or nil})
                break
            end
        end

        return ret
	end
end

--- 三带一对
---@param cards table
---@return any
parse.isSanDaiYiDui = function (cards)
	local ncards = #cards
	if ncards == 5 then

        if helper.V(cards[1]) ~= helper.V(cards[2]) then
            return
        end

		if helper.getKingCount(cards) > 0 then
            return
        end

        local ret = {}

        local groupData = helper.groupByValue(cards)
        local arr2, arr3
        for key, arr in pairs(groupData) do
            local len = #arr
            if len == 2 then
                arr2 = arr
            elseif len == 3 then
                arr3 = arr
            end
        end

        if arr2 and arr3 then
            table.insert(ret, {type = CardType.sandaiyidui, weight = helper.V(arr3[1]), cards = isClient and arr3 or nil})
        end

        return ret
	end
end

--- 四带二
---@param cards table
---@return table
parse.isSiDaiEr = function (cards)
	local num = #cards
	if num == 6 then
		if helper.V(cards[1]) == helper.V(cards[6]) then
            return
        end

        if helper.V(cards[3]) ~= helper.V(cards[4]) then
            return
        end

        local ret = {}

        local groupData = helper.groupByValue(cards)
        local arr4
        for key, arr in pairs(groupData) do
            local len = #arr
            if len > 4 then -- 同样数值的牌不能超过4张
                break
            elseif len == 4 then
                arr4 = arr
                break
            end
        end

        if arr4 then
            table.insert(ret, {type = CardType.sidaier, weight = helper.V(arr4[1]), cards = isClient and arr4 or nil})
        end

        return ret
	end
end

--- 四带两对
---@param cards table
---@return table
parse.isSiDaiLiangDui = function (cards)
	local num = #cards
	if num ~= 8 then
		return
	end

	if helper.V(cards[1]) == helper.V(cards[8]) then
		return
	end

    if helper.V(cards[1]) ~= helper.V(cards[2]) and helper.V(cards[7]) ~= helper.V(cards[8]) then
        return
    end

    local groupData, len = helper.groupByValue(cards)

    if len < 2 then --至少3种组合 错， 4444 66 66 可以的
        return
	elseif len == 2 then
		if helper.V(cards[1]) + 1 == helper.V(cards[8]) and not helper.is2(cards[8]) then	--不能为连炸, 但可为 a-2
			return
		end
    end

    local ret = {}

	local arr4, arr4Count, duiCount = nil, 0, 0
	for key, arr in pairs(groupData) do
        local len = #arr
        if len > 4 then -- 同样数值的牌不能超过4张
            break
        elseif len == 2 then
            duiCount = duiCount + 1
        elseif len == 4 then
			arr4Count = arr4Count + 1
			if not arr4 or arr[1] > arr4[1] then
				arr4 = arr
			end
        end
    end

    if arr4 and (arr4Count == 2 or duiCount == 2) then
        table.insert(ret, {type = CardType.sidailiangdui, weight = helper.V(arr4[1]), cards = isClient and groupData or nil})
    end

    return ret
end

--- 顺子
---@param cards table
---@return table
parse.isShunZi = function (cards)
	local num = #cards
	if num < 5 then
		return
	end

	local dic = {}
	local cardVal, minVal, maxVal, lastVal
	for index, card in ipairs(cards) do
		cardVal = helper.V(card)

		if lastVal and cardVal ~= lastVal + 1 then
			return
		end

		if dic[cardVal] then
			return
		end

		if helper.isKing(card) or helper.is2(card) then
			return
		end

		dic[cardVal] = true

		if not minVal or cardVal < minVal then
			minVal = cardVal
		end

		if not maxVal or cardVal > maxVal then
			maxVal = cardVal
		end

		lastVal = cardVal
	end

	if maxVal - minVal >= num then
		return
	end

	return {{type = CardType.shunzi, weight = helper.V(cards[1]), 
		cards = helper.isClient and cards or nil, subtype = helper.isA(maxVal) and CardSubType.tongtianshun or CardSubType.shunzi}}
end

--- 连对
---@param cards table
---@return table
parse.isLianDui = function (cards)
	local num = #cards
	if num < 6 or num % 2 ~= 0 then
		return
	end

	local duiNum = num // 2
	local dic = {}
	local cardVal, minVal, maxVal
	for index, card in ipairs(cards) do
		cardVal = helper.V(card)

		if helper.isKing(card) or helper.is2(card) then
			return
		end

		dic[cardVal] = (dic[cardVal] or 0) + 1

		if dic[cardVal] > 2 then
			return
		end

		if not minVal or cardVal < minVal then
			minVal = cardVal
		end

		if not maxVal or cardVal > maxVal then
			maxVal = cardVal
		end
	end

	if maxVal - minVal >= duiNum then
		return
	end

	return {{type = CardType.liandui, weight = helper.V(cards[1]), cards = helper.isClient and cards or nil}}
end

--- 飞机不带
---@param cards table
---@return table
parse.isFeiJiBuDai = function (cards)
	local num = #cards
	if num < 6 or num % 3 ~= 0 then
		return
	end

	local threeNum = num // 3
	local dic = {}
	local cardVal, minVal, maxVal
	for index, card in ipairs(cards) do
		cardVal = helper.V(card)

		if helper.isKing(card) or helper.is2(card) then
			return
		end

		dic[cardVal] = (dic[cardVal] or 0) + 1

		if dic[cardVal] > 3 then
			return
		end

		if not minVal or cardVal < minVal then
			minVal = cardVal
		end

		if not maxVal or cardVal > maxVal then
			maxVal = cardVal
		end
	end

	if maxVal - minVal >= threeNum then
		return
	end

	return {{type = CardType.feiji_budai, weight = helper.V(cards[1]), cards = helper.isClient and cards or nil}}
end

--- 飞机带单
---@param cards table
---@return table
parse.isFeiJiDaiDan = function (cards)
	local num = #cards
	if num < 8 or num % 4 ~= 0 then
		return
	end

	local threeNum = num // 4
	local groupData, len = helper.groupByValue(cards)

    if len < threeNum + 1 then --至少(飞机数量 + 1)种组合
        return
    end

	local maxVal
	for key, arr in pairs(groupData) do
		if #arr >= 3 then
			if (not maxVal or maxVal < key) and groupData[key - 1] then
				maxVal = key
			end
		end
	end

	if not maxVal then
		return
	end

	local isFeiJi = true
	for j = 1, threeNum - 1 do
		local arr2 = groupData[maxVal - j]
		local len2 = arr2 and #arr2 or 0
		if len2 < 3 then
			isFeiJi = false
			break
		end
	end

	if not isFeiJi then
		return
	end

	local minVal = maxVal - (threeNum - 1)
	-- 3333 444 555 666 777 权重应该是 4，不是3
	-- 3333 4444 5556		也是飞机带单

	return {{type = CardType.feiji_daidan, weight = minVal, cards = helper.isClient and groupData or nil}}
end

--- 飞机带对
---@param cards table
---@return table
parse.isFeiJiDaiDui = function (cards)
	local num = #cards
	if num < 10 or num % 5 ~= 0 then
		return
	end

	local threeNum = num // 5
	local groupData, len = helper.groupByValue(cards)

	--至少4种组合    333 444 5555 也可以
	if len < 3 then
        return
    end

	local isFeiJi = false
	local weight = 1
	for i=1, 0xd - threeNum do
		local arr = groupData[i]
		local len = arr and #arr or 0

		weight = i
		if len == 3 then
			isFeiJi = true
			for j = 1, threeNum - 1 do
				local arr2 = groupData[i + j]
				local len2 = arr2 and #arr2 or 0

				if len2 ~= 3 then
					isFeiJi = false
					break
				end
			end
			break
		end
	end

	if not isFeiJi then
		return
	end

    for key, arr in pairs(groupData) do
        local len = #arr

		if len == 3 then
		elseif len % 2 ~= 0 then
			return
		end
    end

	return {{type = CardType.feiji_daidui, weight = weight, cards = helper.isClient and groupData or nil}}
end

--- 连炸
---@param cards table
---@return table
parse.isLianZha5x2 = function (cards)
	local num = #cards
	if num ~= 10 then
		return
	end

	if helper.V(cards[1]) == helper.V(cards[num]) then
		return
	end

	local groupData, len = helper.groupByValue(cards)

    if len == 2 then --2种组合
        return
    end

	local star5Num = 5
	-- 3 - k
	for i = 1, 0xb do
		local arr = groupData[i]
		local len = arr and #arr or 0

		if len == star5Num then
			local arr2 = groupData[i]
			local len2 = arr2 and #arr2 or 0

			if len2 ~= star5Num then
				--2个连续5星炸
				return {{type = CardType.zhadan, weight = helper.COMB(i, BombInfoData.star_5_2.weight), cards = helper.isClient and groupData or nil}}
			end
		end
	end
end

--- 连炸 4星 * N
---@param cards table
---@return table
parse.isLianZha4xN = function (cards)
	local num = #cards
	if num < 8 or num % 4 ~= 0 then
	-- if num ~= 8 or num % 4 ~= 0 then -- 首个版本只支持2连炸
		return
	end

	if helper.V(cards[1]) == helper.V(cards[num]) then
		return
	end

	local zhadanNum = num // 4
	local groupData, len = helper.groupByValue(cards)

    if len < 2 then -- 至少2种组合
        return
    end

	local star4Num = 4

	local isLianZha = false
	local weight = 1
	for i=1, 0xd - zhadanNum do
		local arr = groupData[i]
		local len = arr and #arr or 0

		weight = i
		if len == star4Num then
			isLianZha = true
			for j = 1, zhadanNum - 1 do
				local arr2 = groupData[i + j]
				local len2 = arr2 and #arr2 or 0

				if len2 ~= star4Num then
					isLianZha = false
					break
				end
			end
			break --  TODO：这儿要加个break，不然有bug
		end
	end

	if not isLianZha then
		return
	end

	return {{type = CardType.zhadan, weight = helper.COMB(weight, BombInfoData["star_4_" .. zhadanNum].weight), 
		cards = helper.isClient and groupData or nil, subtype = CardSubType["star_4_" .. zhadanNum]}}
end

return parse
