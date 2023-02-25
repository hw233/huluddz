local M = {}

function M:Shuffle(cards)
	local len = #cards
	for i = 1, len do
        local index = math.random(1, len)
        local temp = cards[i]
        cards[i] = cards[index]
        cards[index] = temp
    end
    return cards
end

return M