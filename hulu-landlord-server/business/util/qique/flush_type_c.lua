local tool = require "util.qique.qique_tool"
local M = {}

local flush_type = {
	[8] = {type = "eight_f"},
	[7] = {type = "nil"},
	[6] = {type = "six_f"},
	[5] = {type = "five_f"},
	[4] = {type = "four_f"},
	[3] = {type = "three_f"},
}

function M.Calculate(all_cards,leperslong)	
	local colors = tool.get_same_color(all_cards)

	local card_types = {}

	for color,c_cards in pairs(colors) do
		local values = tool.get_value_cards(c_cards)

		local isHaveTwo = false

		local setValues = function (i,isTwo)
			if values[i] then
				local xq_mark = 0
				local lx_list = {}

				if isTwo and values[i][2] then
					table.insert(lx_list,values[i][2])
				else
					table.insert(lx_list,values[i][1])
				end

				if not isHaveTwo then
					isHaveTwo = #values[i] == 2
				end
				
				for j=1,13-i do
					if values[i+j] then
						if isTwo and values[i+j][2] then
							table.insert(lx_list,values[i+j][2])
						else
							table.insert(lx_list,values[i+j][1])
						end
					else
						if #lx_list > 0 then
							xq_mark =  xq_mark + 1
						end

						if xq_mark >leperslong then
							lx_list = {}
							xq_mark = 0
						end
					end

					if #lx_list + xq_mark > 2 then
						local list = {}
						list.leperNum = xq_mark
						list.cards = table.clone(lx_list)
						list.type = flush_type[#list.cards+list.leperNum].type
						table.insert(card_types,list)	
					end

					if #lx_list >= 2 and xq_mark == 0 then
						for k=1,leperslong do
							local list = {}
							list.leperNum = k
							list.cards = table.clone(lx_list)
							list.type = flush_type[#list.cards+list.leperNum].type
							table.insert(card_types,list)	
						end
					end
				end

				local xq_mark = 0
				local lx_list = {}

				if isTwo and values[i][2] then
					table.insert(lx_list,values[i][2])
				else
					table.insert(lx_list,values[i][1])
				end

				for j=i-1,1,-1 do
					if values[j] then
						if isTwo and values[j][2] then
							table.insert(lx_list,values[j][2])
						else
							table.insert(lx_list,values[j][1])
						end
					else
						if #lx_list > 0 then
							xq_mark =  xq_mark + 1
						end

						if xq_mark >leperslong then
							lx_list = {}
							xq_mark = 0
						end
					end

					if #lx_list + xq_mark > 2 then
						local list = {}
						list.leperNum = xq_mark
						list.cards = table.clone(lx_list)
						list.type = flush_type[#list.cards+list.leperNum].type
						table.insert(card_types,list)	
					end

					if #lx_list >= 2 and xq_mark == 0 then
						for k=1,leperslong do
							local list = {}
							list.leperNum = k
							list.cards = table.clone(lx_list)
							list.type = flush_type[#list.cards+list.leperNum].type
							table.insert(card_types,list)	
						end
					end
				end
			end
		end
		
		for i=1,13 do
			setValues(i)
		end

		if isHaveTwo then
			for i=1,13 do
				setValues(i,true)
			end
		end

	end

	local Lack_list = {}

	if leperslong >= 2 then
		for k,v in pairs(all_cards) do
			for i=2,leperslong do
				local list = {}
				list.leperNum = i
				list.cards = {v}
				local key = i + 1
				list.type = flush_type[key].type
				Lack_list[key] = Lack_list[key] or {}
				table.insert(Lack_list[key],list)
			end
		end
	end

	for k,v in ipairs(card_types) do
		--prints("78",tool.PrintCards(v.cards),v.leperNum)
		if v.leperNum == 0 then
			local key = #v.cards
			Lack_list[key] = Lack_list[key] or {}
			table.insert(Lack_list[key],v)
			for i=1,leperslong do
				local list2 = {}
				list2.leperNum = i	
				list2.cards = table.clone(v.cards)
				list2.type = flush_type[#list2.cards+list2.leperNum].type
				local key = #v.cards+v.leperNum
				Lack_list[key] = Lack_list[key] or {}
				table.insert(Lack_list[key],v)
			end

			for i=1,#v.cards do
		   		local list3 = {}
		   		list3.cards = table.clone(v.cards)
		   		removebyvalue(list3.cards,v.cards[i])
		    	list3.leperNum = 1
		    	local key = #list3.cards+list3.leperNum
		   		list3.type = flush_type[key].type
				Lack_list[key] = Lack_list[key] or {}
				--prints("tt",tool.PrintCards(list3.cards),list3.leperNum)
				table.insert(Lack_list[key],list3)

				if leperslong > 1 then
					for j=2,leperslong do
						local list1 = table.clone(list3)
						list1.leperNum = j
						local key = #list1.cards+list1.leperNum
		   				list1.type = flush_type[key].type
						Lack_list[key] = Lack_list[key] or {}
						table.insert(Lack_list[key],list1)
					end
				end
			end
		else
			local key = #v.cards+v.leperNum
			Lack_list[key] = Lack_list[key] or {}
			table.insert(Lack_list[key],v)

			if leperslong > v.leperNum then
				for i=1,#v.cards do
		   			local list3 = {}
		   			list3.cards = table.clone(v.cards)
		   			removebyvalue(list3.cards,v.cards[i])
		    		list3.leperNum = v.leperNum + 1
		    		local key = #list3.cards+list3.leperNum
		   			list3.type = flush_type[key].type
					Lack_list[key] = Lack_list[key] or {}
					--prints("tt",tool.PrintCards(list3.cards),list3.leperNum)
					table.insert(Lack_list[key],list3)
				end
			end
		end
	end

	-- prints("Lack_list",Lack_list[6])

	-- for k,s in pairs(Lack_list) do
	-- 	prints("---------k-",k)
	-- 	for z,v in pairs(s) do
	-- 		prints(tool.PrintCards(v.cards),v.leperNum)
	-- 	end
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

local function fill_leypes(card_type,hu_list)

	local fill = function (list,s,e)
		for i=s,e do
			table.insert(list.cards,M.lepers_all[i])
		end
		list.type = flush_type[#list.cards].type
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

	if Lack_list[5] and Lack_list[3] then
		TowMach(Lack_list[5],kv_list,hu_list_same,3)
	end

	if Lack_list[4] and #Lack_list[4]>1 then
		TowMach(Lack_list[4],kv_list,hu_list_same,4)
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