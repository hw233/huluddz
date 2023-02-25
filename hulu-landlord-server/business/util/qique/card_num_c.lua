local tool = require "util.qique.qique_tool"

local M = {}


local function is_in_cards(cards,card)
	for k,v in pairs(cards) do
		if v == card then
			return true
		end
	end
	return false
end

local all_mark = 0xee  --测试的标值数

function M.is_slh_type(hu_cards)
	table.sort( hu_cards, function (a,b)
		return #a.cards > #b.cards
	end )

	if hu_cards[1].type == "five_f" and hu_cards[2].type == "three_f" then
		local lepers,no_lepers = tool.remove_lepers2(hu_cards[1].cards)
		local lepers2,no_lepers2 = tool.remove_lepers2(hu_cards[2].cards)
		if #lepers >= 1 and tool.is_tb1_in_tab2(no_lepers2,no_lepers) then
			tool.card_sort(hu_cards[1].cards)
			tool.card_sort(hu_cards[2].cards)
			table.insert(hu_cards[2].cards,table.remove(hu_cards[1].cards,5))
			hu_cards[1].type = "four_f"
			hu_cards[2].type = "four_f"
		end
	elseif hu_cards[1].type == "five_s" and hu_cards[2].type == "three_s" then
		local lepers,no_lepers = tool.remove_lepers2(hu_cards[1].cards)
		local lepers2,no_lepers2 = tool.remove_lepers2(hu_cards[2].cards)

		if #no_lepers2 == 0 or #no_lepers == 0 then
			return
		end

		local start_c = tool.V(no_lepers[1]) - tool.V(no_lepers2[1])

		if #lepers >= 1 and math.abs(start_c) == 1 then
			tool.card_sort(hu_cards[1].cards)
			tool.card_sort(hu_cards[2].cards)
			table.insert(hu_cards[2].cards,table.remove(hu_cards[1].cards,5))
			hu_cards[1].type = "four_s"
			hu_cards[2].type = "four_s"
		end
	elseif hu_cards[1].type == "four_s" and hu_cards[2].type == "two_s" then
		local lepers,no_lepers = tool.remove_lepers2(hu_cards[1].cards)
		local lepers2,no_lepers2 = tool.remove_lepers2(hu_cards[2].cards)
		local lepers3,no_lepers3 = tool.remove_lepers2(hu_cards[3].cards)

		if #no_lepers2 == 0 or  #no_lepers3 == 0 or #no_lepers == 0 then
			return
		end

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

	elseif hu_cards[1].type == "three_s" and hu_cards[2].type == "three_s" then
		local lepers,no_lepers = tool.remove_lepers2(hu_cards[1].cards)
		local lepers2,no_lepers2 = tool.remove_lepers2(hu_cards[2].cards)
		local lepers3,no_lepers3 = tool.remove_lepers2(hu_cards[3].cards)

		if #lepers ~= 1 or  #lepers2 ~= 1  then
			return
		end

		local start_c1 = math.abs(tool.V(no_lepers[1]) - tool.V(no_lepers3[1]))
		local start_c2 = math.abs(tool.V(no_lepers2[1]) - tool.V(no_lepers3[1]))

		if  start_c1 == 1 or start_c2 == 1  then
			local num = start_c2 == 1 and 1 or 2
			tool.card_sort(hu_cards[num].cards)
	
			table.insert(hu_cards[3].cards,table.remove(hu_cards[num].cards,3))
			hu_cards[3].type = "three_s"
			hu_cards[num].type = "two_s"
		end
	end
end

function M.NoResidueInsert(cardtype,hu_cards)

	if not is_in_cards(cardtype.cards,all_mark) then return end

	if cardtype.type == "two_s" or cardtype.type =="three_s" or cardtype.type =="four_s" 
		or cardtype.type =="five_s" or cardtype.type =="six_s" or cardtype.type =="eight_s" then
		tool.card_sort(cardtype.cards)
		table.insert(hu_cards,tool.V(cardtype.cards[1])+0xe0)
	else

	
			-- local str = "{ "
			-- str = str..tool.PrintCards(cardtype.cards).." "
			
			-- str = str.." }"

			-- local all_cards = {}
			
	

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
				--table.insert(all_cards,card)
				lack_num = lack_num + 1
			end
		end

		local fillNum = #lepers - lack_num

		for i=1,fillNum do
			if tool.V(no_lepers[1])-i > 0 then
				table.insert(hu_cards,no_lepers[1]-i)
				--table.insert(all_cards,no_lepers[1]-i)
			end
			if tool.V(no_lepers[1])+i < 13 then
				table.insert(hu_cards,no_lepers[long_no_le]+i)
				--table.insert(all_cards,no_lepers[long_no_le]+i)
			end
		end

		-- prints(str,tool.PrintCards(all_cards))
	end
end

return M