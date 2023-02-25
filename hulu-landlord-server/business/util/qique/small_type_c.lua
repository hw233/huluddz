local tool = require "util.qique.qique_tool"
-- local Qqpbl = require "util.qique.multiple_type_c"



prints = function ( ... )
	-- body
end

local tableCom = {
	zuhe = tool.zuhe
}

local M = {}


function removebyvalue(array, value, removeall)
 	local c, i, max = 0, 1, #array
    while i <= max do
        if (array[i] & 0xff) == (value & 0xff) then -- TODO：这里 & 0xff 好像没任何作用？？？
            table.remove(array, i)
            c = c + 1
            i = i - 1
            max = max - 1
            if not removeall then break end
        end
        i = i + 1
    end
    return c
end

--- 在参数1中将所有与参数2中包含的牌移除
---@param cards any
---@param r_cards any
---@return any
function cardsreduction(cards, r_cards)
	local rlist = table.clone(r_cards)
	for k, v in pairs(rlist) do
		removebyvalue(cards, v)
	end
	return cards
end

------------------------------------------
--推断胡牌
function is_same_infer(cards)
	return tool.infer_cards_same(cards)	
end

function is_flush_infer(cards)
	return tool.infer_cards_flush(cards)	
end

Small_type_infer = {
	["two_s"]  = {fnc = is_same_infer},
	["three_f"]  = {fnc = is_flush_infer},
	["three_s"]  = {fnc = is_same_infer},
	["four_f"]  = {fnc = is_flush_infer},
	["four_s"]  = {fnc = is_same_infer},
	["five_f"]  = {fnc = is_flush_infer},
	["five_s"]  = {fnc = is_same_infer},
	["six_f"]  = {fnc = is_flush_infer},
	["six_s"]  = {fnc = is_same_infer},
	["eight_f"]  = {fnc = is_flush_infer},
	["eight_s"]  = {fnc = is_same_infer},
}


------------------------------------------

function is_same(cards,type)
	local isSame = tool.is_same(cards)
	if #cards == Small_type[type].num and isSame then
		return {cards = cards,type =Small_type[type].type}
	end
end

function is_flush(cards,type)
	local isflush = tool.is_flush(cards)
	if #cards == Small_type[type].num and isflush then
		return {cards = cards,type =Small_type[type].type}
	end
end

function is_eight_s(cards)
	return is_same(cards,11)
end

function is_eight_f(cards)
	return is_flush(cards,10)
end

function is_six_s(cards)
	return is_same(cards,9)
end

function is_six_f(cards)
	return is_flush(cards,8)
end

function is_five_s(cards)
	return is_same(cards,7)
end

function is_five_f(cards)
	return is_flush(cards,6)
end

function is_four_s(cards)
	return is_same(cards,5)
end

function is_four_f(cards)
	return is_flush(cards,4)
end

function is_three_s(cards)
	return is_same(cards,3)
end

function is_three_f(cards)
	return is_flush(cards,2)
end

function is_two_s(cards)
	return is_same(cards,1)
end


Small_type = {
	[1] = {type = "two_s",	 num = 2,	fnc = is_two_s},
	[2] = {type = "three_f", num = 3,	fnc = is_three_f},
	[3] = {type = "three_s", num = 3,	fnc = is_three_s},
	[4] = {type = "four_f",	 num = 4,	fnc = is_four_f},
	[5] = {type = "four_s",	 num = 4,	fnc = is_four_s},
	[6] = {type = "five_f",	 num = 5,	fnc = is_five_f},
	[7]	= {type = "five_s",	 num = 5,	fnc = is_five_s},
	[8] = {type = "six_f",	 num = 6,	fnc = is_six_f},
	[9]	= {type = "six_s",	 num = 6,	fnc = is_six_s},
	[10] = {type = "eight_f", num = 8,	fnc = is_eight_f},
	[11] = {type = "eight_s", num = 8,	fnc = is_eight_s},
}

local Next_type = {
	[6] = 2,
	[5] = 3,
	[4] = 2,
	[3] = 3,
	[2] = 2,
}

--- 在 cards 中穷举出所有符合 num 数量的牌型，然后使用 fnc 判断这些牌型是否满足条件，满足则加入 resultList 中
---@param cards any
---@param fnc any
---@param resultList any
---@param num any
---@return any
function All_take_num(cards, fnc, resultList, num)
	local cardlist = tableCom.zuhe(cards, num)
	for k, list in pairs(cardlist) do
		local result = fnc(list)
		if result then
			if resultList then
				table.insert(resultList, result)
			else
				return result
			end
		end
	end
end

function cards_type_c(cards,fun_num)
	fun_num = fun_num or 11

	for i=fun_num,1,-1 do
		local info = Small_type[i]
		if #cards >= info.num then
			local result = nil
			if #cards == info.num then
				result = info.fnc(table.clone(cards))

				if result then
					return result
				end
			else
				local z_calculate = function (s_cards)
					local c_cards = s_cards
					return info.fnc(c_cards)
				end

				local f_calculate = function (s_cards)
					local c_cards = cardsreduction(table.clone(cards),s_cards)
					return info.fnc(c_cards)
				end

				local r_num = #cards - info.num 
				local c_num = r_num <= info.num and r_num or info.num
				local s_fnc = r_num <= info.num and f_calculate or z_calculate
				if c_num == 1 then
					result = All_take_num(cards,s_fnc,nil,1)
				elseif c_num == 2 then
					result = All_take_num(cards,s_fnc,nil,2)
				elseif c_num == 3 then
					result = All_take_num(cards,s_fnc,nil,3)
				elseif c_num == 4 then
					result = All_take_num(cards,s_fnc,nil,4)
				end

				if result then
					return result
				end
			end
		end
	end
end

function Hu_type_c(cards)
	local resultList = {}

	for i = 11, 1, -1 do
		local info = Small_type[i]
		if #cards >= info.num then
			local result = nil
			if #cards == info.num then
				result = info.fnc(cards)
				table.insert(resultList,result)
			else
				-- 判断参数牌型是否匹配
				local z_calculate = function (s_cards)
					local c_cards = s_cards
					return info.fnc(c_cards)
				end
				-- 判断全部牌中除参数牌之外的部分是否匹配
				local f_calculate = function (s_cards)
					local c_cards = cardsreduction(table.clone(cards), s_cards)
					return info.fnc(c_cards)
				end

				-- 这边的意思是 优先用组合函数穷举出数量小的牌型组合，然后牌堆中除了这些组合之外的牌就是 数量多的牌型组合，  是优化才这么做的么？？？ 直接缓存组合不更好么？
				local r_num = #cards - info.num
				local c_num = r_num <= info.num and r_num or info.num
				local s_fnc = r_num <= info.num and f_calculate or z_calculate
				if c_num == 1 then
					All_take_num(cards, s_fnc, resultList, 1)
				elseif c_num == 2 then
					All_take_num(cards, s_fnc, resultList, 2)
				elseif c_num == 3 then
					All_take_num(cards, s_fnc, resultList, 3)
				elseif c_num == 4 then
					All_take_num(cards, s_fnc, resultList, 4)
				end
			end
		end
	end
	return resultList
end


function M.PrintCardOne(one)
	local Values = {"3","4","5","6","7","8","9","10","J","Q","K","A","2","小王","大王"}
	--local Colors = {"黑桃","红心","梅花","方块",""}
	local Colors = {"方块","梅花","红心","黑桃",""}
	return ""..Colors[tool.C(one)]..Values[tool.V(one)]
end

function PrintCards(list)
	local Values = {"3","4","5","6","7","8","9","10","J","Q","K","A","2","小王","大王"}
	--local Colors = {"黑桃","红心","梅花","方块",""}
	local Colors = {"方块","梅花","红心","黑桃",""}

	local str = "{ "
	for k,v in pairs(list) do
		str = str.." "..Colors[tool.C(v)]..Values[tool.V(v)].." "
	end
	str = str.." }"
	return str
end

function M.seven_c(cards)
	local sendCards = table.clone(cards)
	local card_c = {}
	while(#sendCards ~= 0) do
		local result = cards_type_c(sendCards)
		if result then
			sendCards = cardsreduction(sendCards,result.cards)
			table.insert(card_c,result)
		else
			break
		end
	end
	return card_c,sendCards
end

function is_in_cards(cards,card)
	for k,v in pairs(cards) do
		if v == card then
			return true
		end
	end
	return false
end

function is_slh_type(hu_cards)
	if hu_cards[1].type == "five_f" and hu_cards[2].type == "three_f" then
		local lepers,no_lepers = tool.remove_lepers(hu_cards[1].cards)
		local lepers2,no_lepers2 = tool.remove_lepers(hu_cards[2].cards)
		if #lepers >= 1 and tool.is_tb1_in_tab2(no_lepers2,no_lepers) then
			tool.card_sort(hu_cards[1].cards)
			tool.card_sort(hu_cards[2].cards)
			table.insert(hu_cards[2].cards,table.remove(hu_cards[1].cards,5))
			hu_cards[1].type = "four_f"
			hu_cards[2].type = "four_f"
		end
		print("强行变成双龙会? f")
	end

	if hu_cards[1].type == "five_s" and hu_cards[2].type == "three_s" then
		local lepers,no_lepers = tool.remove_lepers(hu_cards[1].cards)
		local lepers2,no_lepers2 = tool.remove_lepers(hu_cards[2].cards)
		local start_c = tool.V(no_lepers[1]) - tool.V(no_lepers2[1])

		if #lepers >= 1 and math.abs(start_c) == 1 then
			tool.card_sort(hu_cards[1].cards)
			tool.card_sort(hu_cards[2].cards)
			table.insert(hu_cards[2].cards,table.remove(hu_cards[1].cards,5))
			hu_cards[1].type = "four_s"
			hu_cards[2].type = "four_s"
		end
		print("强行变成双龙会? s")
	end

	if hu_cards[1].type == "four_s" and hu_cards[2].type == "two_s" then
		local lepers,no_lepers = tool.remove_lepers(hu_cards[1].cards)
		local lepers2,no_lepers2 = tool.remove_lepers(hu_cards[2].cards)
		local lepers3,no_lepers3 = tool.remove_lepers(hu_cards[3].cards)
		
		local start_c = math.abs(tool.V(no_lepers[1]) - tool.V(no_lepers2[1]))
		local start_c2 = math.abs(tool.V(no_lepers[1]) - tool.V(no_lepers3[1]))

		if #lepers >= 1 and (start_c == 1 or start_c2 == 1) then
			local num = start_c == 1 and 2 or 3

			tool.card_sort(hu_cards[1].cards)
			tool.card_sort(hu_cards[num].cards)
			table.insert(hu_cards[num].cards,table.remove(hu_cards[1].cards,4))
			hu_cards[1].type = "three_s"
			hu_cards[num].type = "three_s"
		end
	end
end

--七雀牌 胡牌番型计算
--cards手牌，card胡牌
function M.eight_c(cards, card)
	local sendCards = table.clone(cards)
	table.insert(sendCards, card)

	table.sort(sendCards, function (a, b)
		local va = tool.V(a)
		local vb = tool.V(b)
		if va == vb then
			return tool.C(a) < tool.C(b)
		else
			return va > vb
		end
	end)
	-- print("eight_c 胡牌推算",PrintCards(sendCards))
	local hu_cards = {}

	local resultList = Hu_type_c(sendCards)

	local residue_fun = function (e_cards,fun_num)
		local card_c = {}
		while(#e_cards ~= 0) do
			local result = cards_type_c(e_cards,fun_num)
			if result then
				e_cards = cardsreduction(e_cards,result.cards)
				table.insert(card_c,result)
			else
				break
			end
		end
		return card_c,e_cards
	end

	local residue_funAll = function (e_cards,fun_num)
		local allResult = Hu_type_c(e_cards,fun_num)

		for k,v in ipairs(allResult) do
			local list = cardsreduction(table.clone(e_cards),v.cards)
			local selfList,residue = residue_fun(list,Next_type[#v.cards])
			
			if #residue == 0 then
				table.insert(selfList,v)
				return 	selfList,residue
			end
		end
		return {},e_cards
	end

	local isJiang = function (can_hu_cards)
		for k,v in pairs(can_hu_cards) do
			if is_in_cards(v.cards,card) then
				local lepers,no_lepers = tool.remove_lepers(v.cards)
				if #lepers == (#v.cards - 1) then
					if tool.V(card)<=0x0d then
						return false
					end
				end
			end
		end
		return true
	end


	local tmp_all_hu_cards = {}
	for k,v in ipairs(resultList) do
		local list = cardsreduction(table.clone(sendCards),v.cards)
		local selfList,residue = residue_funAll(list,Next_type[#v.cards])
		table.insert(selfList,v)

		if #residue == 0 and isJiang(selfList) then	
			table.insert(tmp_all_hu_cards,selfList)	
			if #hu_cards == 0 then
				hu_cards = selfList
			end				
			-- break
		end
	end

	if #hu_cards == 0 then
		return 
	end

	-- print("推算结果结果",hu_cards)
	table.sort( hu_cards,function (a,b)
		return #a.cards>#b.cards
	end)

	-- is_slh_type(hu_cards) --是否为双龙汇

	return hu_cards , tmp_all_hu_cards
end

local all_mark = 0xee  --测试的标值数

function M.NoResidueInsert(cardtype,hu_cards)

	if not is_in_cards(cardtype.cards,all_mark) then return end

	if cardtype.type == "two_s" or cardtype.type =="three_s" or cardtype.type =="four_s" 
		or cardtype.type =="five_s" or cardtype.type =="six_s" or cardtype.type =="eight_s" then
		tool.card_sort(cardtype.cards)
		table.insert(hu_cards,tool.V(cardtype.cards[1])+0xe0)
	else
		local lepers,no_lepers = tool.remove_lepers(cardtype.cards)
		local v = tool.get_value_cards(no_lepers)
		
		if #no_lepers == 0 then
			return
		end

		tool.card_sort(no_lepers)
		
		local long_no_le = #no_lepers
		local lack_num = 0
		
		for i= tool.V(no_lepers[1]),tool.V(no_lepers[long_no_le]) do
			if v[i] and #v[i]>1 then
				return false
			end
			if not v[i] then
				local card = (no_lepers[1]&0xf0)+i
				table.insert(hu_cards,card)
				lack_num = lack_num + 1
			end
		end

		local fillNum = #lepers - lack_num

		for i=1,fillNum do
			if tool.V(no_lepers[1])-i > 0 then
				table.insert(hu_cards,no_lepers[1]-i)
			end
			if tool.V(no_lepers[1])+i < 13 then
				table.insert(hu_cards,no_lepers[long_no_le]+i)
			end
		end
	end
end

M.removebyvalue = removebyvalue
M.cardsreduction = cardsreduction
M.PrintCards = PrintCards
M.tableCom = tableCom
M.Hu_type_c = Hu_type_c
return M