local tool = require "util.qique.qique_tool"
local same_type_c = require "util.qique.same_type_c"
local flush_type_c = require "util.qique.flush_type_c"

local M = {}

local same_type = {
	[8] = {type = "eight_s"},
	[6] = {type = "six_s"},
	[5] = {type = "five_s"},
	[4] = {type = "four_s"},
	[3] = {type = "three_s"},
	[2] = {type = "two_s"},
}

local flush_type = {
	[8] = {type = "eight_f"},
	[6] = {type = "six_f"},
	[5] = {type = "five_f"},
	[4] = {type = "four_f"},
	[3] = {type = "three_f"},
}


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


local function TowMach(list,kvlist,hu_list,twokey)
	for k,v in pairs(list) do
		local key = M.all_card_key - v.num
		if kvlist[key] and  kvlist[key][twokey] then
			local list = {}
			table.insert(list,v)
			table.insert(list,kvlist[key][twokey])
			if not M.Is_all_cardtypes(list) then
				table.insert(hu_list,list)
			end
		end
	end
end

local function getMarklist(marknum)
		local list = {}
		for i=1,8 do
			if BITGET(marknum,i) == 1 then
				table.insert(list,M.key_lies[i])
			end
		end
		return list
	end

-- local function ThrthrTwo2(list,key1,key2,kvlist,hu_list)
-- 	for k,card_type in pairs(list) do
-- 		local all_key = M.all_card_key - card_type.num
-- 		local numList = getMarklist(all_key)

-- 		local quLong = math.floor(#list/2)

-- 		local takein = function (type1,type2)
-- 			local list = {}
-- 			table.insert(list,card_type)
-- 			table.insert(list,type1)
-- 			table.insert(list,type2)
-- 			if not M.Is_all_cardtypes(list) then
-- 				table.insert(hu_list,list)
-- 			end
-- 		end

-- 		for i=1,quLong do
-- 			local clist = tableCom.zuhe(numList,i)

-- 			for z,mlist in pairs(clist) do
-- 				local mark = 0
-- 				for j=1,#mlist  do
-- 					mark = mark + mlist[j]
-- 				end
			
-- 				local mark2 = all_key-mark

-- 				if kvlist[mark] and kvlist[mark2] then
-- 					if kvlist[mark][key1] and kvlist[mark2][key2] then
-- 						takein(kvlist[mark][key1],kvlist[mark2][key2])
-- 					elseif kvlist[mark][key2] and kvlist[mark2][key1] then
-- 						takein(kvlist[mark][key2],kvlist[mark2][key1])
-- 					end
-- 				end
-- 			end
-- 		end

-- 	end
-- end

local function ThrthrTwo(list,key1,key2,hu_list,isflush)

	local Calcu = isflush and flush_type_c or same_type_c

	for k,card_type in pairs(list) do
		local all_key = M.all_card_key - card_type.num
		local cards = M.cardsreduction(table.clone(M.no_lepers_cards),card_type.cards)
		local same_list = Calcu.Calculate(cards,#M.lepers_all-card_type.leperNum)

		-- if key1 == 3 and key2 == 3 and isflush then
		-- 	prints("===tool",key1,key2,tool.PrintCards(card_type.cards))
		-- 	for e,a in pairs(same_list[3]) do
		-- 		prints("===ss",tool.PrintCards(a.cards),a.leperNum)
		-- 	end
		-- end
		
		if same_list[key1] and same_list[key2] and (key1 == key2 and #same_list[key2]>1 or true) then
			local kv_same_list = {}
			M.set_mark(same_list)
			M.set_kv_list(kv_same_list,same_list)
			for z,type1 in pairs(same_list[key1]) do
				local key = all_key - type1.num
				-- prints("----",tool.PrintCards(type1.cards),kv_same_list[key])
				if kv_same_list[key] and kv_same_list[key][key2]  then
					local list = {}
					table.insert(list,card_type)
					table.insert(list,type1)
					table.insert(list,kv_same_list[key][key2])
					if not M.Is_all_cardtypes(list) then
						table.insert(hu_list,list)
					end
				end
			end
		end
	end
end

local function fill_leypes(card_type,hu_list)

	local fill = function (list,s,e)
		for i=s,e do
			table.insert(list.cards,M.lepers_all[i])
		end
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

function M.all_same_C(same_list,kv_same_list,flush_list,kv_flush_list,hu_list)

	local hu_list_same = {}
	

	if flush_list[6] and same_list[2] then
		TowMach(flush_list[6],kv_same_list,hu_list_same,2)
	end

	if same_list[5] and flush_list[3] then
		TowMach(same_list[5],kv_flush_list,hu_list_same,3)
	end

	if flush_list[5] and same_list[3] then
		TowMach(flush_list[5],kv_same_list,hu_list_same,3)
	end

	if same_list[4] and flush_list[4] then
		TowMach(flush_list[4],kv_same_list,hu_list_same,4)
	end

	if flush_list[4] and same_list[2] and #same_list[2]>1 then
		 ThrthrTwo(flush_list[4],2,2,hu_list_same)
		--ThrthrTwo2(flush_list[4],22,kv_same_list,hu_list_same)
	end

	if same_list[3] and flush_list[3] and same_list[2] then
		 ThrthrTwo(flush_list[3],3,2,hu_list_same)
		--ThrthrTwo2(flush_list[3],3,2,kv_same_list,hu_list_same)
	end

	if flush_list[3] and #flush_list[3]>2 and same_list[2] then
		 ThrthrTwo(same_list[2],3,3,hu_list_same,true)
		--ThrthrTwo2(same_list[3],3,3,kv_flush_list,hu_list_same)
	end

	-- prints("same_list",same_list[2])

	-- for k,v in pairs(same_list[2]) do
	-- 	prints(tool.PrintCards(v.cards))
	-- end

	for k,v in pairs(hu_list_same) do
		fill_leypes(v,hu_list)
	end
	-- prints(#hu_list)
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