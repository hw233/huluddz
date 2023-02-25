require "config/GameConst"
local ShuffleHandle = require("game/tools/Shuffle")

local M = {}

function M:OperationIsGang(op)
	if op == ActionType.BGang then
		return true
	elseif op == ActionType.AGang then
		return true
	elseif op == ActionType.MGang then
		return true
	elseif op == ActionType.HGang then
		return true
	end
	return false
end

function M:IsJoker(card,jokers)
	if not jokers then return end

	for _,joker in ipairs(jokers) do
		if self:CardsEq(card,joker) then
			return true
		end
	end
end

--格式化牌面 
--1-9 11-19 21-29 ...
function M:TrsfomId(id)
	local v = math.ceil(id%36/4)
	if v == 0 then v = 9 end
	return math.floor((id-1)/36)*10 + v
end

--获取数值大小
function M:getCardValue(Cid)
	local CNum = self:TrsfomId(Cid)
	return CNum%10
end

function M:TrsfomIds(hand,one,jokers)
	local cards = {}
	local jokerCount = 0
	for _,v in ipairs(hand) do
		if self:IsJoker(v,jokers) then
			jokerCount = jokerCount + 1
		else
			table.insert(cards, self:TrsfomId(v))
		end
	end
	if one then
		if self:IsJoker(one,jokers) then
			jokerCount = jokerCount + 1
		else
			table.insert(cards, self:TrsfomId(one))
		end
	end

	return cards,jokerCount
end

function M:RestoreId(disposeId)
	local convertId = disposeId - math.floor(disposeId/10)
	return convertId*4
end

function M:CardsCount(cards)
    local cardsCount = {}
    for k, v in pairs(cards) do cardsCount[v] = (cardsCount[v] or 0) + 1 end
    return cardsCount
end

function M:CardsEq(...)
	local cards = {...}
	if #cards < 2 then
		return false
	end
	assert(#cards >= 2, "compare card with nil.")

	for i=1,#cards-1 do
		if math.ceil(cards[i]/4) ~= math.ceil(cards[i+1]/4) then
			return false
		end
	end

	return true
end

function M:CardsSort(Cards )
	table.sort( Cards, function ( a, b )
		return a < b
	end )
	return Cards
end

function M:GetCardColor(card)
	if card <= 36 then
		return CARD_COLOR.Bamboo
	elseif card <= 72 then
		return CARD_COLOR.Dot
	elseif card <= 108 then
		return CARD_COLOR.Character
	elseif card <= 136 then
		return CARD_COLOR.Honor
	elseif card <= 144 then
		return CARD_COLOR.Flower
	end
end

-----------2021.8------------

--好牌开局概率
-- 1 9张同种牌，剩余牌为另外2种
-- 2 开局1红中
function M:GetGoodHandByCt(ct)
	local tmp = GOOD_HAND_CFG[ct]
	local rand = math.random(1,100)
	if rand <= tmp[1] then
		return 1
	else
		return 2
	end
end

--定制工具牌堆。非实际牌堆
--wall2list = {{条},{筒},{万},{中}}
function M:GetWall2ListNew()
	local wall2list = {{},{},{},{}}
	for i=1,112 do
		table.insert(wall2list[M:GetCardColor(i)],i)
	end
	--子牌堆洗牌
	for p,q in ipairs(wall2list) do
		q = ShuffleHandle:Shuffle(q)
	end
	print("====debug qc 定制牌堆初始化==== ")
	table.print(wall2list)
	return wall2list
end

--返回剩余牌堆
function M:GetWallFromList(wall2list)
	local wall = {}
	for _,w in ipairs(wall2list) do
		for t,card in pairs(w) do
			table.insert(wall ,card)
		end
	end
	return wall
end

--更复杂的随机做牌器
function M:GetGoodHandByType(type,wall2list)
	local hands = {}
	
	if type ==1 then
		-- 1 9张同种牌，剩余4牌为另外2种

		--先定花色
		local color = 0
		while color == 0 do
			local rand_color = math.random(1,3)
			--挑选更多颜色的牌
			if #wall2list[rand_color] > 18 then
				color = rand_color
			end
		end

		--装入9张牌
		for i=1,9 do
			table.insert(hands ,table.remove(wall2list[color],1))
		end

		--反选颜色
		local tmp_colors ={CARD_COLOR.Bamboo,CARD_COLOR.Dot,CARD_COLOR.Character}
		for p,c in pairs(tmp_colors) do
			if color == c then
				table.remove(tmp_colors,p)
				break
			end
		end

		--随机其他2颜色 4张
		for rd =1,4 do
			local color_2 = tmp_colors[math.random(1,2)]
			table.insert(hands ,table.remove(wall2list[color_2],1))
		end
		assert(#hands == 13 ,"GetGoodHandByType hands type1 len error!")

	else
		-- 2 开局1红中
		local wall_cell = wall2list[CARD_COLOR.Honor]
		assert(#wall_cell >=1,"GetGoodHandByType type2 zhong error!")	
		table.insert(hands,table.remove(wall_cell,1))			
		
	end
	return hands,wall2list
end

return M