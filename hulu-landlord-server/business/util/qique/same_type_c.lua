
local tool = require "util.qique.qique_tool"

local M = {}

local same_type = {
	[8] = {type = "eight_s"},
	[7] = {type = "nil"},
	[6] = {type = "six_s"},
	[5] = {type = "five_s"},
	[4] = {type = "four_s"},
	[3] = {type = "three_s"},
	[2] = {type = "two_s"},
}

local function InsertTable(t1,t2,long)
	long = long or #t2

	local index = 0

	for _,v in pairs(t2) do
		if index < long then
			table.insert(t1,v)
			index = index + 1
		end
	end
end

local function removebyvalue( array,value,removeall)
 	local c, i, max = 0, 1, #array
    while i <= max do
        if array[i] == value then
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



function M.Calculate(all_cards,leperslong)

	local values = tool.get_value_cards(all_cards)

	local card_types = {}

	local layer_one_types = {}

	local haved_cards = {}

	for k,v in pairs(values) do
		local long = #v

		if long > 1 then
			local list = {}
			list.leperNum = 0
			list.cards = table.clone(v)
			list.type = same_type[#list.cards+list.leperNum].type
			table.insert(card_types,list)
			
			if long > 2 then
				table.insert(layer_one_types,v)
			end
		end

		for i=1,leperslong do
			local list = {}
			list.leperNum = i
			list.cards = table.clone(v)

			list.type = same_type[#list.cards+list.leperNum].type
			table.insert(card_types,list)
			
			if long == 1 then
				table.insert(haved_cards,v[1])
				-- prints("--------one_types",tool.PrintCards({v[1]}))
			end
		end
	end

	for k,v in pairs(layer_one_types) do
		for i=1,#v do
			local list = {}
		    list.cards = table.clone(v)
		    list.leperNum = 0
		   	removebyvalue(list.cards,v[i])
		   	list.type = same_type[#list.cards+list.leperNum].type
		   	table.insert(card_types,list)

		   	local list2 = {}
		   	list2.cards = {v[i]}
		   	list2.leperNum = 1
		   	list2.type = same_type[#list2.cards+list2.leperNum].type
		   	table.insert(card_types,list2)
		   	table.insert(haved_cards,v[i])
		 	 -- prints("--------layer_one_types",tool.PrintCards({v[i]}))
		   	for j=1,leperslong do
		   		local list3 = {}
		   	 	list3.cards = table.clone(list.cards)
		    	list3.leperNum = j
		   		list3.type = same_type[#list3.cards+list3.leperNum].type
		   		table.insert(card_types,list3)
		   	end
		end
		if #v == 4 then
		  	local twolist = tool.zuhe(v,2)
		  	for _,cards in pairs(twolist) do
				local list = {}
	   			list.cards = cards
	   			list.leperNum = 0
	   			list.type = same_type[#list.cards+list.leperNum].type
	   			table.insert(card_types,list)
		   		for j=1,leperslong do
		   			local list3 = {}
		   	 		list3.cards = table.clone(list.cards)
		    		list3.leperNum = j
		   			list3.type = same_type[#list3.cards+list3.leperNum].type
		   			table.insert(card_types,list3)
		   		end
	   		end
	   	end
	end

	local one_cards = M.cardsreduction(table.clone(all_cards),haved_cards)
	-- prints("--------one_cards",tool.PrintCards(one_cards))
	for k,v in pairs(one_cards) do
		local list = {}
		list.cards = {v}
		list.leperNum = 1
		list.type = same_type[#list.cards+list.leperNum].type
		table.insert(card_types,list)
	end

	local Lack_list = {}

	for k,v in ipairs(card_types) do
		if v.leperNum == 0 then
			local key = #v.cards
			Lack_list[key] = Lack_list[key] or {}
			table.insert(Lack_list[key],v)
		else
			local key = #v.cards + v.leperNum
			Lack_list[key] = Lack_list[key] or {}
			table.insert(Lack_list[key],v)
		end
	end

	-- prints("Lack_list",Lack_list[2])

	-- for k,v in pairs(Lack_list[2]) do
	-- 	prints(tool.PrintCards(v.cards))
	-- end

	return Lack_list
end

local function TowMach(list,kvlist,hu_list,twokey)

	for k,v in pairs(list) do
		local key = M.all_card_key - v.num
		if kvlist[key] and  kvlist[key][twokey]  then
			local list = {}
			table.insert(list,v)
			table.insert(list,kvlist[key][twokey])
			if not M.Is_all_cardtypes(list) then
				table.insert(hu_list,list)
			end
		end
	end
end

local function ThreeMach(list,kvlist,hu_list,noteKey)
	local twolist = tool.zuhe(list,2)
	-- prints("#twolist",#twolist)
	for k,v in pairs(twolist) do
		local key = M.all_card_key - v[1].num - v[2].num
		if kvlist[key]  and kvlist[key][noteKey] then
			local list = {}
			M.InsertTable(list,v)
			table.insert(list,kvlist[key][noteKey])

			if not M.Is_all_cardtypes(list) then
				table.insert(hu_list,list)
			end
		end
	end
end

local function FourMach(list,kvlist,hu_list)
	local threelist = tool.zuhe(list,3)
	-- prints("#threelist",#threelist)
	local isCu = {}
	for k,v in pairs(threelist) do
		local key = M.all_card_key - v[1].num - v[2].num - v[3].num
		if kvlist[key] and not isCu[key] and kvlist[key][2] then
			isCu[v[1].num] = true
			isCu[v[2].num] = true
			isCu[v[3].num] = true
			isCu[key] = true

			local list = {}
			M.InsertTable(list,v)
			table.insert(list,kvlist[key][2])
			table.insert(hu_list,list)
		end
	end
end

local function fill_leypes(card_type,hu_list)

	local fill = function (list,s,e)
		for i=s,e do
			table.insert(list.cards,M.lepers_all[i])
		end
		-- prints(tool.PrintCards(list.cards),tool.PrintCards(M.lepers_all),s,e)
		list.type = same_type[#list.cards].type
	end

	local exchange_fill = function (card_type,key)
		card_type[1],card_type[key] = card_type[key],card_type[1]

		local index = 0
		for k,v in ipairs(card_type) do
			if v.leperNum > 0 then
				fill(v,index+1,index+v.leperNum)
				index = index + v.leperNum
			end
		end
		table.insert(hu_list,card_type)
	end

	local card_zu = function (card_type)
		for k,v in pairs(card_type) do
			if v.leperNum > 0 then
				local cardtypes = table.clone(card_type)
				exchange_fill(cardtypes,k)
			end
		end
	end

	card_zu(card_type)
end

function M.all_same_C(Lack_list,kv_list,hu_list)
	local hu_list_same = {}

	if Lack_list[6] and Lack_list[2] then
		TowMach(Lack_list[6],kv_list,hu_list_same,2)
	end

	if Lack_list[5] and Lack_list[3] then
		TowMach(Lack_list[5],kv_list,hu_list_same,3)
	end

	if Lack_list[4] and #Lack_list[4]>1 then
		TowMach(Lack_list[4],kv_list,hu_list_same,4)
	end

	if Lack_list[4] and Lack_list[2] and #Lack_list[2]>1 then
		ThreeMach(Lack_list[2],kv_list,hu_list_same,4)
	end

	if Lack_list[2] and Lack_list[3] and #Lack_list[3]>1 then
		ThreeMach(Lack_list[3],kv_list,hu_list_same,2)
	end

	if Lack_list[2] and #Lack_list[2]>3 then
		FourMach(Lack_list[2],kv_list,hu_list_same)
	end

	for k,v in pairs(hu_list_same) do
		fill_leypes(v,hu_list)
	end


	-- for k,v in ipairs(hu_list) do
	-- 	local str = "{ "
	-- 	for _,card in pairs(v)  do
	-- 		str = str..tool.PrintCards(card.cards).." "
	-- 	end
	-- 	str = str.." }"
	-- 	prints(str)
	-- end
end

return M