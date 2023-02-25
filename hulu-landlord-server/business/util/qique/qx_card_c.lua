
local tool = require "util.qique.qique_tool"
local Qqpbl = require "util.qique.multiple_type_c"

local same_type_c = require "util.qique.same_type_c"
local flush_type_c = require "util.qique.flush_type_c"
local same_flush_c = require "util.qique.same_flush_c"
local card_num_c = require "util.qique.card_num_c"


local mObj = {
	card_key = {},
	all_card_types = {},
	all_card_key = 0,
	lepers_all = {},
	no_lepers_cards = {},
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


local function is_in_cards(cards,card)
	for k,v in pairs(cards) do
		if v == card then
			return true
		end
	end
	return false
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

function cardsreduction(cards,r_cards)
	local rlist = table.clone(r_cards)
	for k,v in pairs(rlist) do
		removebyvalue(cards,v)
	end
	return cards
end



local key_lies = {
	[1] = 1,
	[2] = 2,
	[3] = 4,
	[4] = 8,
	[5] = 16,
	[6] = 32,
	[7] = 64,
	[8] = 128,
}

local function Set_mark_num(reslus)
	for k,v in pairs(reslus) do
		local num = 0 
		for z,card in pairs(v.cards) do
			num = num + mObj.card_key[card]
		end
		v.num = num
	end
end 

local function set_mark(list)
	for k,v in pairs(list) do
		local isC = {}
		for i=#v,1,-1 do

			if not isC[v[i].num] then
				local num = 0 
				for z,card in pairs(v[i].cards) do
					num = num + mObj.card_key[card]
				end
				v[i].num = num
				isC[v[i].num] = true
			else
				table.remove(v,i)
			end
		end
	end
end

local function set_kv_list(kvlist,list)
	for k,v in pairs(list) do
		for _,c_type in pairs(v) do
			kvlist[c_type.num] = kvlist[c_type.num] or {}
			kvlist[c_type.num][#c_type.cards+c_type.leperNum] = c_type
		end
	end
end


local function Is_all_cardtypes(list)
	table.sort(list,function (a,b)
		return a.num > b.num
	end)
	local key = ""
	
	for k,v in ipairs(list) do
		key = key ..v.num..v.type
	end

	if mObj.all_card_types[key] then
		return true
	else
		mObj.all_card_types[key] = true
		return false
	end

 	return mObj.all_card_types[key]
end

local all_mark = 0xee  --测试的标值数


function mObj.Is_eight(cards,hu_types)
	local isSame = tool.is_same(cards)
	local isflush = tool.is_flush(cards)

	if isSame then
		local list = {{cards = cards, type = "eight_s"}}
		table.insert(hu_types,list)
	elseif isflush then
		local list =  {{cards = cards, type = "eight_f"}}
		table.insert(hu_types,list)
	end
end

function mObj.Init_Calce(list)
	for k,v in ipairs(list) do
		v.key_lies = key_lies
		v.all_card_key = mObj.all_card_key
		v.Set_mark_num = Set_mark_num
		v.InsertTable = InsertTable
		v.lepers_all = mObj.lepers_all
		v.InsertTable = InsertTable
		v.no_lepers_cards = table.clone(mObj.no_lepers_cards)
		v.cardsreduction = cardsreduction
		v.set_mark = set_mark
		v.set_kv_list = set_kv_list
		v.all_card_types = mObj.all_card_types
		v.Is_all_cardtypes = Is_all_cardtypes
	end
end

function mObj.Calculate(cards)
	mObj.card_key = {}
	mObj.all_card_types = {}
	mObj.all_card_key = 0

	local lepers, no_lepers = tool.remove_lepers(cards)
	mObj.lepers_all = lepers
	mObj.no_lepers_cards = no_lepers

	for k,v in ipairs(no_lepers) do
		mObj.card_key[v] = key_lies[k]
		mObj.all_card_key = mObj.all_card_key + key_lies[k]
	end

	table.insert(mObj.lepers_all, all_mark)
	table.sort(mObj.lepers_all, function(a, b)
		return a > b
	end )

	mObj.Init_Calce({same_type_c, flush_type_c, same_flush_c})

	-- local values = tool.get_value_cards(no_lepers)
	-- local colors = tool.get_same_color(no_lepers)

	-- 同点数
	local same_list = same_type_c.Calculate(no_lepers, #mObj.lepers_all)
	-- 同花顺-同花色顺子
	local flush_list = flush_type_c.Calculate(no_lepers, #mObj.lepers_all)


	local kv_same_list, kv_flush_list = {}, {}

	set_mark(same_list) --设置标记去重
	set_kv_list(kv_same_list, same_list)
	set_mark(flush_list)
	set_kv_list(kv_flush_list, flush_list)

	local hu_type_lack = {}

	local eitht_cards = table.clone(cards)
	table.insert(eitht_cards,all_mark)

	mObj.Is_eight(eitht_cards,hu_type_lack)

	same_type_c.all_same_C(same_list,kv_same_list,hu_type_lack)
	flush_type_c.all_same_C(flush_list,kv_flush_list,hu_type_lack)
	same_flush_c.all_same_C(same_list,kv_same_list,flush_list,kv_flush_list,hu_type_lack)
	
	-- 得到所有的可胡牌型
	local hu_cards = {}
	
	for k,v in ipairs(hu_type_lack) do
		local list = {}
		list.type_card = v
		list.cards = {}
		for index,cardType in pairs(v) do
			card_num_c.NoResidueInsert(cardType,list.cards)
		end
		table.insert(hu_cards,list)
	end

	if #hu_cards == 0 then
		return {}
	end

	local hu_cards3 = {}--映射下可胡牌型倍率
	for k,v in ipairs(hu_cards) do
		local key_index = nil

		for index,cardtype in pairs(v.type_card) do
			if is_in_cards(cardtype.cards, all_mark) then
				key_index = index
			end
		end

		for _,card in pairs(v.cards) do
			local list = {}
			list.type_card = table.clone(v.type_card)
			removebyvalue(list.type_card[key_index].cards,all_mark)
			table.insert(list.type_card[key_index].cards,card)
				
			local type, multiple = Qqpbl.get_multiple(list.type_card)
			list.type = type
			list.multiple = multiple
			list.card = card

			-- local str = "{ "
			-- for _,card in pairs(list.type_card)  do
			-- 	str = str..tool.PrintCards(card.cards).." "
			-- end
			-- str = str.." }"
			-- if list.multiple == 40 then
			-- 	prints(str,key_index,list.multiple,tool.PrintCards{card})
			-- end

			table.insert(hu_cards3, list)
		end
	end

	table.sort(hu_cards3,function (a,b)
		return a.multiple < b.multiple
	end)

	local hu_cards4 = {}
	local hu_cards2 = {}

	-- 可胡的牌不是王，就加入到 hu_cards2
	for k,v in ipairs(hu_cards3) do
		local card = v.card
		if (card&0x0f)< 14 then
			if (card>>4) == 14 then
				for i=1,4 do
					local _card = tool.V(card)+(i<<4)
					hu_cards2[_card] = v.multiple		
					hu_cards4[_card] = {
						multiple = v.multiple,
						type = v.type,
						card = _card,
					}
				end
			else
				local _card = tool.V(card)+(tool.C(card)<<4)
				hu_cards2[_card] = v.multiple
				hu_cards4[_card] = {
					multiple = v.multiple,
					type = v.type,
					card = _card,
				}
			end
		end
	end

	local hu_cards5 = {}
	hu_cards = {}

	for k,v in pairs(hu_cards2) do
		local list = {}
		list.card = k
		list.multiple = v
		table.insert(hu_cards,list)
	end
	for key, value in pairs(hu_cards4) do
		table.insert(hu_cards5, value)
	end

	table.sort(hu_cards,function (a,b)
		return a.multiple > b.multiple
	end)

	if #hu_cards >0 then
		local list,list2 = {},{}
		list.multiple = hu_cards[1].multiple
		list.card = 0x5e
		list2.multiple = hu_cards[1].multiple
		list2.card = 0x5f
		table.insert(hu_cards,list)
		table.insert(hu_cards,list2)

		table.insert(hu_cards5, {
			type = hu_cards5[1].type,
			multiple = hu_cards5[1].multiple,
			card = 0x5e,
		})
		table.insert(hu_cards5, {
			type = hu_cards5[1].type,
			multiple = hu_cards5[1].multiple,
			card = 0x5f,
		})
	end

	table.sort(hu_cards,function (a,b)
		return a.multiple > b.multiple
	end)

	table.sort(hu_cards5, function (a, b)
		return a.multiple > b.multiple
	end)

	--return hu_cards
	return hu_cards5

end

function mObj.getMatchCardTypeArr(cards)
	mObj.card_key = {}
	mObj.all_card_types = {}
	mObj.all_card_key = 0

	local lepers, no_lepers = tool.remove_lepers(cards)
	mObj.lepers_all = lepers
	mObj.no_lepers_cards = no_lepers

	for k,v in ipairs(no_lepers) do
		mObj.card_key[v] = key_lies[k]
		mObj.all_card_key = mObj.all_card_key + key_lies[k]
	end

	table.insert(mObj.lepers_all, all_mark)
	table.sort(mObj.lepers_all, function(a, b)
		return a > b
	end )

	mObj.Init_Calce({same_type_c, flush_type_c, same_flush_c})

	-- local values = tool.get_value_cards(no_lepers)
	-- local colors = tool.get_same_color(no_lepers)

	-- 同点数
	local same_list = same_type_c.Calculate(no_lepers, #mObj.lepers_all)
	-- 同花顺-同花色顺子
	local flush_list = flush_type_c.Calculate(no_lepers, #mObj.lepers_all)


	local kv_same_list, kv_flush_list = {}, {}

	set_mark(same_list) --设置标记去重
	set_kv_list(kv_same_list, same_list)
	set_mark(flush_list)
	set_kv_list(kv_flush_list, flush_list)

	local hu_type_lack = {}

	local eitht_cards = table.clone(cards)
	table.insert(eitht_cards,all_mark)

	mObj.Is_eight(eitht_cards,hu_type_lack)

	same_type_c.all_same_C(same_list,kv_same_list,hu_type_lack)
	flush_type_c.all_same_C(flush_list,kv_flush_list,hu_type_lack)
	same_flush_c.all_same_C(same_list,kv_same_list,flush_list,kv_flush_list,hu_type_lack)
	
	-- 得到所有的可胡牌型
	local hu_cards = {}
	
	for k,v in ipairs(hu_type_lack) do
		local list = {}
		list.type_card = v
		list.cards = {}
		for index,cardType in pairs(v) do
			card_num_c.NoResidueInsert(cardType, list.cards)
		end
		table.insert(hu_cards,list)
	end

	if #hu_cards == 0 then
		return {}
	end

	local hu_cards3 = {}--映射下可胡牌型倍率
	for k,v in ipairs(hu_cards) do
		local key_index = nil

		for index, cardtype in pairs(v.type_card) do
			if is_in_cards(cardtype.cards, all_mark) then
				key_index = index
				break;
			end
		end

		for _,card in pairs(v.cards) do
			local list = {}
			list.type_card = table.clone(v.type_card)
			removebyvalue(list.type_card[key_index].cards, all_mark)
			table.insert(list.type_card[key_index].cards, card)
				
			local type, multiple = Qqpbl.get_multiple(list.type_card)
			list.type = type
			list.multiple = multiple
			list.card = card

			table.insert(hu_cards3, list)
		end
	end

	-- 大倍率在后，后面遍历时将小倍率覆盖
	table.sort(hu_cards3,function (a,b)
		return a.multiple < b.multiple
	end)

	local hu_cards2 = {}

	-- 可胡的牌不是王，就加入到 hu_cards2
	for k,v in ipairs(hu_cards3) do
		local card = v.card
		if (card&0x0f)< 14 then
			if (card>>4) == 14 then
				for i=1,4 do
					local _card = tool.V(card)+(i<<4)
					hu_cards2[_card] = {
						multiple = v.multiple,
						type = v.type,
						card = _card,
					}
				end
			else
				local _card = tool.V(card)+(tool.C(card)<<4)
				hu_cards2[_card] = {
					multiple = v.multiple,
					type = v.type,
					card = _card,
				}
			end
		end
	end

	hu_cards = {}
	for key, value in pairs(hu_cards2) do
		table.insert(hu_cards, value)
	end
	table.sort(hu_cards,function (a,b)
		return a.multiple > b.multiple
	end)

	if #hu_cards > 0 then
		table.insert(hu_cards, 1, {
			type = hu_cards[1].type,
			multiple = hu_cards[1].multiple,
			card = 0x5e,
		})
		table.insert(hu_cards, 1, {
			type = hu_cards[1].type,
			multiple = hu_cards[1].multiple,
			card = 0x5f,
		})
	end

	return hu_cards
end

return mObj