local tool = require "util.qique.qique_tool"

local function is_four_pairs(Cards)
	local lepers,no_lepers = tool.remove_lepers(cards)
	local vlue = tool.get_value_cards(no_lepers)
	local lack_num = 0

	for k,v in pairs(vlue) do
		if #v > 2 then
			return 	
		end

		if v == 1 then 
			lack_num = lack_num + 1
		end
	end

	if lack_num >#lepers then
		return 
	end

	local sendcards = {}

	for k,v in pairs(vlue) do
		local list = {}	
		table.insert(list,v[1])

		if #v == 2 then
			table.insert(list,v[2])
		else
			table.insert(list,table.remove(lepers,1))
		end
		table.insert(sendcards,list)
	end

	return sendcards
end

return is_four_pairs