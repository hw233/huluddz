local tool = require "util.qique.qique_tool"


local Type = {
	[1] = "2+2+2+2",
	[2] = "3+3+2",
	[3] = "4+2+2",
	[4] = "6+2",
	[5] = "8"
}

local Small_type = {
	[1] = two_s,
	[2] = three_f,
	[3] = three_s,
	[4] = four_f,
	[5] = four_s,
	[6] = six_f,
	[7]	= six_s,
	[8] = eight_f,
	[9] = eight_s,
}

local Calculate = {}

function s_type(cards,s_card)

end
--每种花色》=2才有机会胡同花顺
function cards_order(cards)
	local lepers,no_lepers = tool.remove_lepers(cards)
	local value = tool.get_value_cards(no_lepers)
	local c_value = tool.get_same_color(cards)
	
end