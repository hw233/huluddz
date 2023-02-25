local tool = require "util.qique.qique_tool"
local roomData = require "roomData"
roomData.setGameType(GameType.SevenSparrow)

local M = {}

local function is_two_s(cards_type)
	tool.card_sort(cards_type[1].cards)
	tool.card_sort(cards_type[2].cards)

	local start_c = tool.V(cards_type[1].cards[1]) - tool.V(cards_type[2].cards[1])

	if math.abs(start_c) == 1 then
		return true
	end
end

--同数值
local function is_same_v(cards_type)
	tool.card_sort(cards_type[1].cards)
	tool.card_sort(cards_type[2].cards)
 
	local lepers,no_lepers = tool.remove_lepers(cards_type[1].cards)
	local lepers2,no_lepers2 = tool.remove_lepers(cards_type[2].cards)
	if #no_lepers>#no_lepers2 then
		return tool.is_tb1_in_tab2(no_lepers2,no_lepers)
	else
		return tool.is_tb1_in_tab2(no_lepers,no_lepers2)
	end
end

--同色同数值
local function is_ths_f(cards_type)
	tool.card_sort(cards_type[1].cards)
	tool.card_sort(cards_type[2].cards)
 
	local color_b =	(tool.C(cards_type[1].cards[1]) == tool.C(cards_type[2].cards[1]))
	if color_b then
		local lepers,no_lepers = tool.remove_lepers(cards_type[1].cards)
		local lepers2,no_lepers2 = tool.remove_lepers(cards_type[2].cards)
		if #no_lepers>#no_lepers2 then
		   return tool.is_tb1_in_tab2(no_lepers2,no_lepers)
		else
		   return tool.is_tb1_in_tab2(no_lepers,no_lepers2)
		end
	end
end

function One_num_c(cards_type)
	if cards_type[1].type == "eight_s" then --星炸胡
		return "baxingzha"
	elseif cards_type[1].type == "eight_f" then --一条龙
		return "tonghuashun"
	end
end

function Two_num_c(cards_type)
	if #cards_type[1].cards == 6 then --6+2
		return "6+2"
	elseif #cards_type[1].cards == 5 then --5+3
		return "5+3"
	elseif cards_type[1].type == "four_s" and cards_type[2].type == "four_s" and is_two_s(cards_type) then	--连炸胡
		return "lianzhahu"
	-- modify by qc 2021.9.23 双龙会不需要同花色,需要同数值
	elseif cards_type[1].type == "four_f" and cards_type[2].type == "four_f" and is_same_v(cards_type) then	--双龙汇
		return "shuanglonghui"
	elseif #cards_type[1].cards == 4 then	--4+4
		return "4+4"
	end
end

function Three_num_c(cards_type)
	if cards_type[1].type == "three_s" and cards_type[2].type == "three_s" and is_two_s(cards_type) then --飞机胡
		return "feijihu"	
	-- modify by qc 2021.9.23 3连对不需要同花色,需要同数值
	-- 2022.1.24 星科需求调整为同色同数值
	elseif cards_type[1].type == "three_f" and cards_type[2].type == "three_f" and is_ths_f(cards_type) then	--三连对
		return "sanliandui"
	elseif #cards_type[1].cards == 4 then --4+2+2
		return "4+2+2"
	elseif #cards_type[1].cards == 3 then
		return "3+3+2"
	end
end


local function cards_type(st)
	table.sort(st, function (a,b)
		return #a.cards > #b.cards
	end )

	if #st == 1 then 
		return One_num_c(st)
	elseif #st == 2 then 
		return Two_num_c(st)
	elseif #st == 3 then 
		return Three_num_c(st)
	elseif #st == 4 then	--2+2+2+2
		return "2+2+2+2"
	end
end


local multiple = {
	["baxingzha"] = 18888,
	["tonghuashun"] = 6000,

	["6+2"] = 3600,
	["5+3"] = 2400,
	["shuanglonghui"] = 2400,
	["lianzhahu"] = 2400,
	["4+4"] = 1800,

	["feijihu"] = 1200,
	["sanliandui"] = 1200,
	["4+2+2"] = 1600,
	["3+3+2"] = 800,

	["2+2+2+2"] = 500,
}

for key, value in pairs(multiple) do
	multiple[key] = roomData.multipleInfo[key]
end

--get 番型倍率
--参数 result = sc.eight_c(cards, one)
function M.get_multiple(result)
	-- table.print(result)
	if result then
		local type = cards_type(result)
		if not type then
			dump('~~~~~~~~~~~~~~~~~~~~~~~~~~~ check_hu ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~', cards, one)
		end
		--print(" check_hu succ",type)
		-- print("get_multiple :" ,type,assert(multiple[type]))
		return type, assert(multiple[type])
	else
		--print(" check_hu failed")
	end
end

return M