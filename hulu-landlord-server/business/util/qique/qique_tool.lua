local tool = {}

--取花色 1副牌 1,2,3,4,5
function C(card)
	card = card & 0xff
	local c = (card>>4)%5
	if c == 0 then
		return 5
	else
		return c
	end
end

--以数值取牌 (4色)
function infer_card_V(v)
	return {v | 0x10, v | 0x20, v | 0x30, v | 0x40}
end

--取面值
function V(card)
	return card & 0x0f
end


--取花色 2副牌
function TV(card)
	return card >> 8
end

function is_leper(card)
	return V(card) >= 0xe
end

function tool.remove_lepers(cards)
	local lepers = {}
	local no_lepers = {}
	local long = #cards
	
	for i=1,long do
		
		local card = cards[i]
		
		if is_leper(card) then
			table.insert(lepers,card)
		else
			table.insert(no_lepers,card)
		end
	end
	
	return lepers,no_lepers
end

function tool.get_value_cards(cards)
	local value_cards = {}
	for i,card in ipairs(cards) do
		local v = V(card)
		value_cards[v] = value_cards[v] or {}
		table.insert(value_cards[v], card)
	end
	return value_cards
end

function tool.card_sort(cards)
	table.sort(cards,function (a,b)
		return V(a)<V(b)
	end)
end

function tool.is_flush(cards)
	if #cards < 3 then
		return
	end

	local lepers,no_lepers = tool.remove_lepers(cards)
	local v = tool.get_value_cards(no_lepers)

	if #no_lepers == 0 then
		return true
	end

	if #no_lepers>1 then
		for k,v in pairs(no_lepers) do
			if C(v) ~=C(no_lepers[1]) then
				return false
			end
		end
	end
	tool.card_sort(no_lepers)

	local long_no_le = #no_lepers
	local lack_num = 0

	for i= V(no_lepers[1]),V(no_lepers[long_no_le]) do
		
		if v[i] and #v[i]>1 then
			return false
		end

		if not v[i] then
			lack_num = lack_num + 1
		end
	end
	
	if lack_num > #lepers then
		return false
	end

	return true
end

function tool.is_flush_two(cards)
	if V(cards[1])>V(cards[2]) then
		cards[1],cards[2] = cards[2],cards[1]
	end	

	if V(cards[2])-V(cards[1]) == 1 and C(cards[1])==C(cards[2]) then
		return true
	end
	return false
end

--得到同花色
function tool.get_same_color(cards)
	local list = {}

	for k,card in pairs(cards) do
		local c = C(card)
		c = c>5 and c-5 or c
		list[c] = list[c] or {}
		table.insert(list[c],card)
	end
	return list
end

--得到同花色顺子
function tool.get_flush(cards)
	local sc_cards = tool.get_same_color(cards)
	local list = {}

	for k,v in pairs(sc_cards) do
		print(i)
	end
end

function tool.is_same(cards)
	if #cards < 2 then
		return false
	end

	local lepers,no_lepers = tool.remove_lepers(cards)
	local v = tool.get_value_cards(no_lepers)

	if #no_lepers>1 then
		for k,v in pairs(no_lepers) do
			if V(v) ~=V(no_lepers[1]) then
				return false
			end
		end
	end

	return true
end

function tool.is_tb1_in_tab2(tb1,tb2)

	for k,v1 in pairs(tb1) do
		local same = false
		for j,v2 in pairs(tb2) do
			if V(v1) == V(v2) then
				same = true
				break
			end
		end

		if not same then
			return false
		end
	end

	return true
end
--是否为花牌
function tool.isHuaPai(card)
	return V(card) == 0x0d
end
--去除花牌
function tool.noHua(cards)
	for i=#cards,1,-1 do
		v = cards[i]
		if tool.isHuaPai(v) then
			table.remove(cards,i)
		end
	end
end

tool.C = C
tool.V = V
tool.is_leper = is_leper


--反推癞子可代替的牌
--前提是已经同花
function tool.infer_cards_flush(cards)
	local lepers,no_lepers = tool.remove_lepers(cards)
	if #lepers==0 or #no_lepers ==0 then
		return {}
	end

	--table.print(no_lepers)

	local v = tool.get_value_cards(no_lepers)
	local color =  no_lepers[1] & 0xf0
	tool.card_sort(no_lepers)

	local long_no_le = #no_lepers
	local lack_num = 0

	local leper_v = {}
	for i= V(no_lepers[1]),V(no_lepers[long_no_le]) do		
		if not v[i] then		
			table.insert(leper_v, color | i) --按照同色补癞子牌
			lack_num = lack_num +1
		end		
	end
	
	local lepers_remain = #lepers - lack_num
	--print("infer_cards_flush 剩余 lepers ",lepers_remain)
	
	if  lepers_remain > 0 then
		--向下取顺子
		--print("infer_cards_flush.no_lepers: ")
		
		for i = no_lepers[1]-1, no_lepers[1] - lepers_remain,-1 do
			--下中断
			if  V(i) == 0x00 then
				break
			else
				table.insert(leper_v,i)
			end
		end
		--向上取顺子
		for i = no_lepers[long_no_le]+1, no_lepers[long_no_le] + lepers_remain do			
			--上中断
			if V(i) == 0x0d then
				break			
			else
				table.insert(leper_v,i)
			end
		end
	end
	local any_cards = {}
	for i,v in pairs(leper_v) do
		table.insert(any_cards,v)
	end	
	return any_cards
end


--反推癞子可代替的同值牌面
function tool.infer_cards_same(cards)
	local lepers,no_lepers = tool.remove_lepers(cards)	
	if #lepers==0 or #no_lepers ==0 then
		return {}
	end
	
	local any_cards = infer_card_V(V(no_lepers[1]))
	return any_cards	
end

function tool.zuhe(atable, n)
    if n > #atable then
        return {}
    end

    local len = #atable
    local meta = {}
    -- init meta data
    for i=1, len do
        if i <= n then
            table.insert(meta, 1)
        else
            table.insert(meta, 0)
        end
    end

    local result = {}

    -- 记录一次组合
    local tmp = {}
    for i=1, len do
        if meta[i] == 1 then
            table.insert(tmp, atable[i])
        end
    end
    table.insert(result, tmp)

    while true do

        local zero_count = 0
        for i=1, len-n do
            if meta[i] == 0 then
                zero_count = zero_count + 1
            else
                break
            end
        end

        if zero_count == len-n then
            break
        end

        local idx
        for j=1, len-1 do

            if meta[j]==1 and meta[j+1] == 0 then
                meta[j], meta[j+1] = meta[j+1], meta[j]
                idx = j
                break
            end
        end

        local k = idx-1
        local count = 0
        while count <= k do
            for i=k, 2, -1 do
                if meta[i] == 1 then
                    meta[i], meta[i-1] = meta[i-1], meta[i]
                end
            end
            count = count + 1
        end

        local tmp = {}
        for i=1, len do
            if meta[i] == 1 then
                table.insert(tmp, atable[i])
            end
        end
        table.insert(result, tmp)
    end

    return result
end

return tool