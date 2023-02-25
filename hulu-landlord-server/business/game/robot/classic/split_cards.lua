local util = require "util.ddz_classic"

local CardType = util.CardType
local COMB = util.COMB
local BombInfoData = util.BombInfoData
local V = util.V


-- 普通炸弹 或 5星炸
local function find_all_zhadan(value_cards, lepers)
	local zhadan_list = {}
	for v,cards in pairs(value_cards) do
		if #cards == 4 then
			if #lepers > 0 then
				local leper = table.remove(lepers, 1)
				table.insert(cards, 1, COMB(leper, v))

				table.insert(zhadan_list, {
					type = CardType.zhadan,
					weight = COMB(v, BombInfoData.star_5.weight),
					cards = cards
				})
			else
				table.insert(zhadan_list, {
					type = CardType.zhadan,
					weight = COMB(v, BombInfoData.yingzha.weight),
					cards = cards
				})
			end
			value_cards[v] = nil
		end
	end
	return zhadan_list
end

--[[
	连续3张 >= 2 (如果剩余牌够的话)
]]
local function find_all_threeX(value_cards)
	local list = {}
	for i=1,0xd do
		local c1 = value_cards[i]

		if c1 and #c1 == 3 then
			local tmp = table.splice(c1, 1, 3)
			value_cards[i] = nil 

			if i < 0xc then
				for j=i+1,0xc do
					local c2 = value_cards[j]
					if c2 and #c2 == 3 then
						table.append(tmp, table.splice(c2, 1, 3))
						value_cards[j] = nil
					else
						break
					end
				end
			end
			table.insert(list, tmp)
		end
	end
	return list
end


local function find_all_liandui(value_cards)
	local list = {}
	for i=1,0xa do
		local vc1 = value_cards[i]
		local vc2 = value_cards[i+1]
		local vc3 = value_cards[i+2]
		if vc1 and vc2 and vc3 and #vc1 == 2 and #vc2 == 2 and #vc3 == 2 then
			local tmp = {}
			table.append(tmp, table.splice(vc1, 1, 2))
			table.append(tmp, table.splice(vc2, 1, 2))
			table.append(tmp, table.splice(vc3, 1, 2))
			value_cards[i] = nil
			value_cards[i+1] = nil
			value_cards[i+2] = nil

			if (i+2) < 0xc then
				for j=i+3,0xc do
					local vc4 = value_cards[j]
					if vc4 and #vc4 == 2 then
						table.append(tmp, table.splice(vc4, 1, 2))
						value_cards[j] = nil
					else
						break
					end
				end
			end
			table.insert(list, {
				type = CardType.liandui,
				weight = i,
				cards = tmp
			})
		end
	end

	return list
end

local function remove_empty(value_cards, i)
	if value_cards[i] and not next(value_cards[i]) then
		value_cards[i] = nil
	end
end


local function find_all_shunzi(value_cards)
	local list = {}
	for i=1,0x8 do
		local vc1 = value_cards[i]
		local vc2 = value_cards[i+1]
		local vc3 = value_cards[i+2]
		local vc4 = value_cards[i+3]
		local vc5 = value_cards[i+4]

		if vc1 and vc2 and vc3 and vc4 and vc5 then
			if #vc1 > 0 and #vc2 > 0 and #vc3 > 0 and #vc4 > 0 and #vc5 > 0 then

				local tmp = {}
				table.insert(tmp, table.remove(vc1, 1))
				table.insert(tmp, table.remove(vc2, 1))
				table.insert(tmp, table.remove(vc3, 1))
				table.insert(tmp, table.remove(vc4, 1))
				table.insert(tmp, table.remove(vc5, 1))

				remove_empty(value_cards, i)
				remove_empty(value_cards, i+1)
				remove_empty(value_cards, i+2)
				remove_empty(value_cards, i+3)
				remove_empty(value_cards, i+4)

				if (i+4) < 0xc then
					for j=i+5,0xc do
						local vc6 = value_cards[j]
						if vc6 then
							table.insert(tmp, table.remove(vc6, 1))
							remove_empty(value_cards, j)
						else
							break
						end
					end
				end
				table.insert(list, {
					type = CardType.shunzi,
					weight = i,
					cards = tmp
				})
			end
		end
	end

	return list
end



local function find_all_duiX(value_cards)
	local list = {}
	for v,cards in pairs(value_cards) do
		if #cards == 2 then
			table.insert(list, cards)
			value_cards[v] = nil
		end
	end

	table.sort(list, function(a, b)
		return V(a[1]) < V(b[1])
	end)
	return list
end


local function find_all_danX(value_cards, lepers)
	local list = {}
	for v,cards in pairs(value_cards) do
		if #cards == 1 then
			table.insert(list, cards)
			value_cards[v] = nil
		end
	end

	for _,card in ipairs(lepers) do
		table.insert(list, {card})
	end

	table.sort(list, function(a, b)
		return V(a[1]) < V(b[1])
	end)
	return list
end

--[[
	1. 双王(存在就当王炸),
	2. 炸弹(保底2个)
	3. 飞机本体 (原牌)
	4. 拆连队
	5. 拆顺子
	6. 拆对子	(原牌)
	7. 单牌 		(原牌)
]]
local function split_cards(cards)
	local type_list = {}
	local three_list
	local dui_list = {}
	local dan_list = {}


	cards = table.copy(cards)
	local kings = util.removeKing(cards)
	local nkings = #kings
	local value_cards = util.groupByValue(cards)
	local lepers = {} --空的癞子组

	-- 1. 双王(存在就当王炸),
	if nkings == 2 then
		table.insert(type_list, {type = CardType.zhadan, weight = COMB(0, BombInfoData.wangzha.weight), cards = kings})
		kings = {}
	end

	-- 2. 炸弹(保底2个)
	-- local leper = nkings > 0 and lepers[1] or nil
	table.append(type_list, find_all_zhadan(value_cards, lepers))



	-- 3. 拆飞机本体
	three_list = find_all_threeX(value_cards)

	-- 4.拆连队
	table.append(type_list, find_all_liandui(value_cards))

	-- 5.拆顺子
	table.append(type_list, find_all_shunzi(value_cards))

	table.sort(type_list, function (a, b)
		return a.weight < b.weight
	end)

	-- 6.拆对子
	dui_list = find_all_duiX(value_cards)

	-- 7.单牌
	dan_list = find_all_danX(value_cards, kings)

	return type_list, three_list, dui_list, dan_list
end



return split_cards