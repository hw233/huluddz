local tool = require "util.qique.qique_tool"
local mc = require "util.qique.multiple_type_c"
local sc = require "util.qique.small_type_c"
local qx_card_c = require "util/qique/qx_card_c"
local objx = require "objx"


local C = tool.C
local V = tool.V
local is_leper = tool.is_leper


local qique = {
	C = C,
	V = V,
	is_leper = is_leper
}



function qique.find_least(cards)
	local list, other = sc.seven_c(cards)
	if other and #other > 0 then
		return other[1]
	else
		table.sort(list, function (a, b)
			return #a.cards < #b.cards
		end)
		return list[1].cards[1]
	end
end


function qique.cards_count(cards)
	local cc = {}
	local laizi = 0
	for i,card in ipairs(cards) do
		if is_leper(card) then
			laizi = laizi + 1
		else
			local c = C(card)
			local v = V(card)
			cc[v] = cc[v] or {}
			cc[v][c] = (cc[v][c] or 0) + 1
		end
	end
	return cc, laizi
end


function qique.max_ting(hand)
	return qique.check_hu(hand, 0x5e)
end

-- 旧版检查胡
-- function qique.check_hu(cards, one)
-- 	assert(one)
-- 	local result ,tmp_all_hu_cards = sc.eight_c(cards, one)
-- 	if not result then
-- 		print("can't hu ",table.concat(cards,","),one)
-- 		return
-- 	end
	

-- 	--最大倍率
-- 	local max_mul = {mul =0,card =0,type}
-- 	--遍历所有倍率取最高的倍率的组合
-- 	for k,v in pairs(tmp_all_hu_cards) do
-- 		-- print("check hu " , #hu_cards_tmp , v.type ,table.concat(q.cards,","))
-- 		local type,mul = M.get_multiple(v)
-- 		-- print(string.format(" type %s, mul %d ",type,mul))
-- 		-- table.print(hu_cards_tmp)
-- 		--最大胡牌，倍率
-- 		if max_mul.mul <mul then
-- 			max_mul.mul = mul  
-- 			max_mul.card = card    
-- 			max_mul.type = type                  
-- 		end
-- 	end

-- 	return max_mul.type, max_mul.mul
-- end

function qique.check_hu(cards, one)
	assert(one)

	local arr = qx_card_c.getMatchCardTypeArr(cards)
	if not next(arr) then
		print("can't hu ", table.concat(cards, ","), one)
		return
	end

	arr = table.where(arr, function (key, value)
		return value.card == one or (tool.V(value.card) == tool.V(one) and tool.C(value.card) == tool.C(one))
	end)

	--最大倍率
	local max_mul = {multiple = 0, card = 0, type = nil}
	--遍历所有倍率取最高的倍率的组合
	for k, value in pairs(arr) do
		if max_mul.multiple < value.multiple then
			max_mul.type = value.type
			max_mul.multiple = value.multiple
			max_mul.card = value.card
		end
	end

	return max_mul.type, max_mul.multiple
end

function qique.is_flower(card)
	return V(card) == 0xd
end


local function copy_and_remove_leper(cards)
	local cards2 = table.copy(cards)

	local laizi = 0
	for i=#cards2,1,-1 do
		if is_leper(cards2[i]) then
			laizi = laizi + 1
			table.remove(cards2, i)
		end
	end

	return cards2, laizi
end


-- 同一种花色
function qique.is_qingyise(cards)
	cards = copy_and_remove_leper(cards)

	local c = C(cards[1])
	for _,card in ipairs(cards) do
		if C(card) ~= c then 
			return false
		end
	end
	return true
end



return qique