local util = require "util.ddz_classic"
local M = {
    mapValue = {},
    initFlag = false,

    HandCardMaxLen = 20,
    MinCardsValue = -25,
    MaxCardsValue = 106,

	Card_Num_3 = 1,
	Card_Num_4 = 2,
	Card_Num_5 = 3,
	Card_Num_6 = 4,
	Card_Num_7 = 5,
	Card_Num_8 = 6,
	Card_Num_9 = 7,
	Card_Num_10 = 8,
	Card_Num_J = 9,
	Card_Num_Q = 10,
	Card_Num_K = 11,
	Card_Num_A = 12,
	Card_Num_2_13 = 13,
	Card_Num_SJ = 14,
	Card_Num_BJ = 15,

    NetType_Null = 0,
	NetType_One = 1,
	NetType_Two = 2,
	NetType_Three = 3,
	NetType_ThreeOne = 4,
	NetType_ThreeTwo = 5,
	NetType_FourOne = 6,
	NetType_FourTwo = 7,
	NetType_Single = 8,
	NetType_DoubleSingle = 9,
	NetType_Plane = 10,
	NetType_PlaneOne = 11,
	NetType_PlaneTwo = 12,
	NetType_FourFour = 13,
	NetType_Bomb4 = 14,
	NetType_Rocket = 100,

    card_calculate_count_limit = 10,
}

function M:InitMap()
    if not self.initFlag then
        self.initFlag = true
        self.mapValue[0x11], self.mapValue[0x21], self.mapValue[0x31], self.mapValue[0x41] = 1,  1,  1,  1
        self.mapValue[0x12], self.mapValue[0x22], self.mapValue[0x32], self.mapValue[0x42] = 2,  2,  2,  2
        self.mapValue[0x13], self.mapValue[0x23], self.mapValue[0x33], self.mapValue[0x43] = 3,  3,  3,  3
        self.mapValue[0x14], self.mapValue[0x24], self.mapValue[0x34], self.mapValue[0x44] = 4,  4,  4,  4
    
        self.mapValue[0x15], self.mapValue[0x25], self.mapValue[0x35], self.mapValue[0x45] = 5,  5,  5,  5
        self.mapValue[0x16], self.mapValue[0x26], self.mapValue[0x36], self.mapValue[0x46] = 6,  6,  6,  6
        self.mapValue[0x17], self.mapValue[0x27], self.mapValue[0x37], self.mapValue[0x47] = 7,  7,  7,  7
        self.mapValue[0x18], self.mapValue[0x28], self.mapValue[0x38], self.mapValue[0x48] = 8,  8,  8,  8
    
        self.mapValue[0x19], self.mapValue[0x29], self.mapValue[0x39], self.mapValue[0x49] = 9,  9,  9,  9
        self.mapValue[0x1a], self.mapValue[0x2a], self.mapValue[0x3a], self.mapValue[0x4a] = 10, 10, 10, 10
        self.mapValue[0x1b], self.mapValue[0x2b], self.mapValue[0x3b], self.mapValue[0x4b] = 11, 11, 11, 11
        self.mapValue[0x1c], self.mapValue[0x2c], self.mapValue[0x3c], self.mapValue[0x4c] = 12, 12, 12, 12
    
        self.mapValue[0x1d], self.mapValue[0x2d], self.mapValue[0x3d], self.mapValue[0x4d] = 13, 13, 13, 13
    
        self.mapValue[0x5e], self.mapValue[0x5f] = 14, 15
    end
end

function M:CardArrayToCard54(cardArray)
    -- { 65, 49, 17, 34, 50, 18, 19, 51, 35 } ♠3♥3♦3 ♣4♥4♦4 ♦5♥5♣5
    local array = {}
    local index = 1
    for _, _card in pairs(cardArray) do
        array[index] = self.mapValue[_card]
        index= index + 1
    end
    return array
end
function M:CardArrayToCard54Map(cardArray)
    -- { 65, 49, 17, 34, 50, 18, 19, 51, 35 } ♠3♥3♦3 ♣4♥4♦4 ♦5♥5♣5
    local arrayMap = {}
    local count = 0
    local array = {}
    for _, _card in pairs(cardArray) do
        count= count + 1
        array[count] = self.mapValue[_card]
        arrayMap[self.mapValue[_card]] = (arrayMap[self.mapValue[_card]] or 0) + 1
    end
    return arrayMap, array, count
end

function M:Card54ToCardArray(Card54Array, cardArray)
    local array = {}
    local cardMapTemp = {}

    local index = 1

    for _, _cardValue in pairs(Card54Array) do
        for _, _card in pairs(cardArray) do
            if _card == _cardValue + 16 then
                if not cardMapTemp[_card] then
                    cardMapTemp[_card] = true
                    array[index] = _card
                    index = index + 1
                    break
                end
            end
            
            if _card == _cardValue + 32 then
                if not cardMapTemp[_card] then
                    cardMapTemp[_card] = true
                    array[index] = _card
                    index = index + 1
                    break
                end
            end
            if _card == _cardValue + 48 then
                if not cardMapTemp[_card] then
                    cardMapTemp[_card] = true
                    array[index] = _card
                    index = index + 1
                    break
                end
            end

            if _card == _cardValue + 64 then
                if not cardMapTemp[_card] then
                    cardMapTemp[_card] = true
                    array[index] = _card
                    index = index + 1
                    break
                end
            end

            if _cardValue == 14 and _card == 0x5e then
                if not cardMapTemp[_card] then
                    cardMapTemp[_card] = true
                    array[index] = _card
                    index = index + 1
                    break
                end
            end

            if _cardValue == 15 and _card == 0x5f  then
                if not cardMapTemp[_card] then
                    cardMapTemp[_card] = true
                    array[index] = _card
                    index = index + 1
                    break
                end
            end
        end
    end

    return array
end

function M:printTable(cardArray)
    local s = ""
    for _, value in pairs(cardArray) do
        s = s ..", "..value 
    end
    -- print(s)
    return s
end

function M:GetHandCardWeight(hand_card_data, out_card_list, debugData)
    hand_card_data.OutputCardType = {}
    hand_card_data.OutputCardType.CardValueList = {}
    local hand_card_weight = {}
    hand_card_weight.CardValueList = {}
    hand_card_weight.SumValue = 0
    hand_card_weight.NeedRound = 0
    if hand_card_data.HandCardCount == 0 then
        hand_card_weight.SumValue = 0
        hand_card_weight.NeedRound = 0
        return hand_card_weight, out_card_list
    end

    -- print("GetHandCardWeight--------")
    local card_group_data = self:LastOutCardData(hand_card_data.CardValueList)
    if card_group_data.Type ~= M.NetType_Null then
        hand_card_weight.SumValue = card_group_data.Value
        hand_card_weight.NeedRound = 1

        if out_card_list then
            table.insert(out_card_list, card_group_data)
        end
        return hand_card_weight, out_card_list
    end 

    if not M:GetOutPutCardList(hand_card_data, debugData) then
        hand_card_weight.SumValue = 0
        hand_card_weight.NeedRound = 0
        return hand_card_weight, out_card_list
    end
    -- print("GetHandCardWeight:---hand_card_data, ", self:pTable(hand_card_data))

    local out_put_card_type_temp = {}
    out_put_card_type_temp.CardValueList = {}
    out_put_card_type_temp.Type = hand_card_data.OutputCardType.Type
    out_put_card_type_temp.Value = hand_card_data.OutputCardType.Value
    out_put_card_type_temp.Count = hand_card_data.OutputCardType.Count
    out_put_card_type_temp.MaxCard = hand_card_data.OutputCardType.MaxCard
    for _, _card_value in pairs(hand_card_data.OutputCardType.CardValueList) do
        table.insert(out_put_card_type_temp.CardValueList, _card_value)
    end

    if not hand_card_data.OutputCardType.Type or hand_card_data.OutputCardType.Type == M.NetType_Null then
        print("OutputCardType ERROR! debugData=", self:pTable(debugData), ", hand_card_data=", self:pTable(hand_card_data))
        debugData.num = debugData.numLimit
    end

    for _, _card_value in pairs(out_put_card_type_temp.CardValueList) do
        hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 1
    end

    hand_card_data.HandCardCount = hand_card_data.HandCardCount - out_put_card_type_temp.Count

    debugData.num = debugData.num + 1
    if debugData.num >= debugData.numLimit  then
        hand_card_weight.SumValue = 0
        hand_card_weight.NeedRound = 17
        return hand_card_weight, out_card_list
    end

    local hand_card_weight_temp
    hand_card_weight_temp, out_card_list = self:GetHandCardWeight(hand_card_data, out_card_list, debugData)
    for _, _card_value in pairs(out_put_card_type_temp.CardValueList) do
        hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 1
    end

    hand_card_data.HandCardCount = hand_card_data.HandCardCount + out_put_card_type_temp.Count
    if out_card_list then
        table.insert(out_card_list, out_put_card_type_temp)
    end

    hand_card_weight.SumValue = out_put_card_type_temp.Value + hand_card_weight_temp.SumValue
    hand_card_weight.NeedRound = hand_card_weight_temp.NeedRound + 1
    return hand_card_weight, out_card_list
end

function M:LastOutCardData(src_card_value_list)
    -- print("LastOutCardData:src_card_value_list=", M:pTable(src_card_value_list))
    local card_count = 0
    local card_value_list = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
    for _card_value, _card_value_count in pairs(src_card_value_list) do
        -- print("_card_value=", _card_value, ", _card_value_count=", _card_value_count)
        if _card_value_count > 0 then
            card_value_list[_card_value] = (card_value_list[_card_value] or 0) + _card_value_count
            card_count = card_count + _card_value_count
        end
    end

    local lastCardGroupData = {}
    lastCardGroupData.Count = card_count
    lastCardGroupData.CardValueList = {}
    -- print("----------------------------------------------------")
    for _card_value, _card_count in pairs(card_value_list) do
        -- print("-----------_card_count=", _card_count, "----000")
        for i = 1, _card_count, 1 do
            -- print("-----------", _card_value, "----000", self:pTable(card_value_list))
            table.insert(lastCardGroupData.CardValueList, _card_value)
        end
    end

    if card_count >= 1 and card_count <= 3 then
        local prov = 0
		local sum_value = 0

        for _card_value, _card_count in pairs(card_value_list) do
            if _card_count == card_count then
                prov = prov + 1
                sum_value = _card_value + 3 - 10
                lastCardGroupData.MaxCard = _card_value
            end
        end

        if prov == 1 then
            if card_count == 1 then
                lastCardGroupData.Type = M.NetType_One
            elseif card_count == 2 then
                lastCardGroupData.Type = M.NetType_Two
            elseif card_count == 3 then
                lastCardGroupData.Type = M.NetType_Three
            end
            lastCardGroupData.Value = sum_value
            return lastCardGroupData
        end
    end

    if card_count == 4 or card_count == 5 then
        local prov_bomb = 0
		local prov_three = 0
		local prov = 0
		local prov_double = 0
		local sum_value = 0
        for _card_value, _card_count in pairs(card_value_list) do
            if _card_count == 3 then
                prov_three = prov_three + 1
                sum_value = _card_value + 3 - 10
                lastCardGroupData.MaxCard = _card_value
            elseif _card_count == 1 then
                prov = prov + 1
            elseif _card_count == 2 then
                prov_double = prov_double + 1
            elseif _card_count == card_count then
                prov_bomb = prov_bomb + 1
                sum_value = _card_value + 7
                lastCardGroupData.MaxCard = _card_value
            end
        end

        if prov_three == 1 then
            if prov == 1 then
                lastCardGroupData.Type = M.NetType_ThreeOne
                lastCardGroupData.Value = sum_value
                lastCardGroupData.CardValueList = {}
                for _card_value, _card_count in pairs(card_value_list) do
                    if _card_count > 0 then
                        if _card_count >= 3 then
                            for i = 1, _card_count, 1 do
                                table.insert(lastCardGroupData.CardValueList, _card_value)
                            end
                        end
                    end
                end

                for _card_value, _card_count in pairs(card_value_list) do
                    if _card_count > 0  then
                        if _card_count < 3 then
                            for i = 1, _card_count, 1 do
                                table.insert(lastCardGroupData.CardValueList, _card_value)
                            end
                        end
                    end
                end

                return lastCardGroupData
            elseif prov_double == 2 then
                lastCardGroupData.Type = M.NetType_ThreeTwo
                lastCardGroupData.Value = sum_value
                for  _card_value, _card_count in pairs(card_value_list) do
                    if _card_count >= 3 then
                        for i = 1, _card_count, 1 do
                            table.insert(lastCardGroupData.CardValueList, _card_value)
                        end
                    end
                end

                for  _card_value, _card_count in pairs(card_value_list) do
                    if _card_count < 3 then
                        for i = 1, _card_count, 1 do
                            table.insert(lastCardGroupData.CardValueList, _card_value)
                        end
                    end
                end

                return lastCardGroupData
            end
        elseif prov_bomb == 1 then
            lastCardGroupData.Type = M.NetType_Bomb4
			lastCardGroupData.Value = sum_value
			return lastCardGroupData
        end
    end

    if card_count == 6 or card_count == 8 then
        local prov_four = 0
		local prov_1 = 0
		local prov_2 = 0
		local sum_value = 0
        for _card_value, _card_count in pairs(card_value_list) do
            if _card_value>= M.Card_Num_SJ then
                lastCardGroupData.Type = M.NetType_Null
                return lastCardGroupData
            end

            if _card_count == 4 then
                prov_four = prov_four + 1
                sum_value = _card_value / 2
                lastCardGroupData.MaxCard = _card_value
            elseif _card_count == 1 then
                prov_1 = prov_1 + 1
            elseif _card_count == 2 then
                prov_2 = prov_2 + 2
                prov_1 = prov_1 + 2
            end
            
        end

        if prov_four == 1 then
            if prov_1 == 2 then
                lastCardGroupData.Type = M.NetType_FourTwo
                lastCardGroupData.Value = sum_value
                lastCardGroupData.CardValueList = {}
                for  _card_value, _card_count in pairs(card_value_list) do
                    if _card_count >= 4 then
                        for i = 1, _card_count, 1 do
                            table.insert(lastCardGroupData.CardValueList, _card_value)
                        end
                    end
                end

                for  _card_value, _card_count in pairs(card_value_list) do
                    if _card_count < 4 then
                        for i = 1, _card_count, 1 do
                            table.insert(lastCardGroupData.CardValueList, _card_value)
                        end
                    end
                end

                return lastCardGroupData
            elseif prov_2 == 4 then
                lastCardGroupData.Type = M.NetType_FourFour
                lastCardGroupData.Value = sum_value
                lastCardGroupData.CardValueList = {}
                for  _card_value, _card_count in pairs(card_value_list) do
                    if _card_count >= 4 then
                        for i = 1, _card_count, 1 do
                            table.insert(lastCardGroupData.CardValueList, _card_value)
                        end
                    end
                end

                for  _card_value, _card_count in pairs(card_value_list) do
                    if _card_count < 4 then
                        for i = 1, _card_count, 1 do
                            table.insert(lastCardGroupData.CardValueList, _card_value)
                        end
                    end
                end

                return lastCardGroupData
            end
        end
    end

    if card_count == 2 then
        local sum_value = 0
        if card_value_list[M.Card_Num_SJ] == 1 and card_value_list[M.Card_Num_BJ] == 1 then
            sum_value = 20
            lastCardGroupData.MaxCard = M.Card_Num_BJ
            lastCardGroupData.Type = M.NetType_Rocket
            lastCardGroupData.Value = sum_value
            return lastCardGroupData
        end
    end

    if card_count >= 5 then
        local prov = 0
		local sum_value = 0
		local card_value_temp = 0
        for _card_value, _card_count in pairs(card_value_list) do
            if _card_value ~= M.Card_Num_SJ and _card_value ~= M.Card_Num_BJ then
                if _card_count == 1 then
                    card_value_temp = _card_value
                    prov = prov + 1
                else
                    if prov ~= 0 then
                        break
                    end
                end
            end
        end

        sum_value = card_value_temp - 6
        if prov == card_count then
            lastCardGroupData.MaxCard = card_value_temp
            lastCardGroupData.Type = M.NetType_Single
            lastCardGroupData.Value = sum_value
            return lastCardGroupData
        end
    end

    if card_count >= 6 then
        local prov = 0
		local sum_value = 0
		local card_value_temp = 0
        for _card_value, _card_count in pairs(card_value_list) do
            if _card_value ~= M.Card_Num_SJ and _card_value ~= M.Card_Num_BJ then
                if _card_count == 2 then
                    card_value_temp = _card_value
                    prov = prov + 1
                else
                    if prov ~= 0 then
                        break
                    end
                end
            end
        end

        sum_value = card_value_temp - 6
        if prov * 2 == card_count then
            lastCardGroupData.MaxCard = card_value_temp
            lastCardGroupData.Type = M.NetType_DoubleSingle
            lastCardGroupData.Value = sum_value
            return lastCardGroupData
        end
    end

    if card_count >= 6 then
        local cardGroupData = self:CheckPlane(card_value_list)
        if cardGroupData.Type ~= M.NetType_Null then
            return cardGroupData
        end
    end


    lastCardGroupData.Type = M.NetType_Null
    return lastCardGroupData
end

function M:CheckPlane(card_value_list)
    -- print("CheckPlane=", M:pTable(card_value_list))
    for _card_value1, _ in pairs(card_value_list) do
        if card_value_list[_card_value1] > 2 then
            local prov = 0
            for _card_value2, _ in pairs(card_value_list) do
                if _card_value2 == M.Card_Num_2_13 then
                    break
                end

                if card_value_list[_card_value2] > 2 then
                    prov = prov + 1
                else
                    break
                end

                if prov == 2 or prov == 3 or prov == 4 or prov == 5 or prov == 6 then
                    local _card_value3 = _card_value1
                    for _card_value3 = _card_value3, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] - 3
                    end

                    local left_card_count = 0
                    for _card_value, _ in pairs(card_value_list) do
                        if card_value_list[_card_value] > 0 then
                            left_card_count = left_card_count + 1
                            break
                        end
                    end

                    if left_card_count == 0 then
                        local last_card_group_data = self:GetNewGroupData(M.NetType_Plane, _card_value3, prov * 3)
                        for _card_value4 = _card_value1, _card_value2, 1 do
                            table.insert(last_card_group_data.CardValueList, _card_value4)
                            table.insert(last_card_group_data.CardValueList, _card_value4)
                            table.insert(last_card_group_data.CardValueList, _card_value4)
                        end
                        return last_card_group_data
                    end
                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] + 3
                    end
                end
            end
        end

        if card_value_list[_card_value1] > 2 then
            local prov = 0
            for _card_value2, _ in pairs(card_value_list) do
                if _card_value2 == M.Card_Num_2_13 then
                    break
                end
                if card_value_list[_card_value2] > 2 then
                    prov = prov + 1
                else
                    break
                end

                if prov == 2 then
                    local _card_value3 = _card_value1
                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] - 3
                    end

                    for _card_value_tmp1, _ in pairs(card_value_list) do
                        if card_value_list[_card_value_tmp1] > 0 then
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] - 1
                            for _card_value_tmp2, _ in pairs(card_value_list) do
                                if card_value_list[_card_value_tmp2] > 0 then
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] - 1
        
                                    local left_card_count = 0
                                    for _card_value_count, _ in pairs(card_value_list) do
                                        if card_value_list[_card_value_count] > 0 then
                                            left_card_count = left_card_count + 1
                                            break
                                        end
                                    end

                                    if left_card_count == 0 then
                                        local last_card_group_data = self:GetNewGroupData(M.NetType_PlaneOne, _card_value3, prov*4)
                                        for _card_value4 = _card_value1, _card_value2, 1 do
                                            table.insert(last_card_group_data.CardValueList, _card_value4)
                                            table.insert(last_card_group_data.CardValueList, _card_value4)
                                            table.insert(last_card_group_data.CardValueList, _card_value4)
                                        end
                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp1)
                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp2)
                                        return last_card_group_data
                                    end
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] + 1
                                end
                            end
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] + 1
                        end
                    end

                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] + 3
                    end
                end

                if prov == 3 then
                    local _card_value3 = _card_value1
                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] - 3
                    end

                    for _card_value_tmp1, _ in pairs(card_value_list) do
                        if card_value_list[_card_value_tmp1] > 0 then
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] - 1
                            for _card_value_tmp2, _ in pairs(card_value_list) do
                                if card_value_list[_card_value_tmp2] > 0 then
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] - 1

                                    for _card_value_tmp3, _ in pairs(card_value_list) do
                                        if card_value_list[_card_value_tmp3] > 0 then
                                            card_value_list[_card_value_tmp3] = card_value_list[_card_value_tmp3] - 1
                                            local left_card_count = 0
                                            for _card_value_count, _ in pairs(card_value_list) do
                                                if card_value_list[_card_value_count] > 0 then
                                                    left_card_count = left_card_count + 1
                                                    break
                                                end
                                            end
        
                                            if left_card_count == 0 then
                                                local last_card_group_data = self:GetNewGroupData(M.NetType_PlaneOne, _card_value3, prov*4)
                                                for _card_value4 = _card_value1, _card_value2, 1 do
                                                    table.insert(last_card_group_data.CardValueList, _card_value4)
                                                    table.insert(last_card_group_data.CardValueList, _card_value4)
                                                    table.insert(last_card_group_data.CardValueList, _card_value4)
                                                end
                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp1)
                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp2)
                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp3)
                                                return last_card_group_data
                                            end
                                            card_value_list[_card_value_tmp3] = card_value_list[_card_value_tmp3] + 1
                                        end
                                    end
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] + 1
                                end
                            end
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] + 1
                        end
                    end

                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] + 3
                    end
                end

                if prov == 4 then
                    local _card_value3 = _card_value1
                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] - 3
                    end

                    for _card_value_tmp1, _ in pairs(card_value_list) do
                        if card_value_list[_card_value_tmp1] > 0 then
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] - 1
                            for _card_value_tmp2, _ in pairs(card_value_list) do
                                if card_value_list[_card_value_tmp2] > 0 then
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] - 1

                                    for _card_value_tmp3, _ in pairs(card_value_list) do
                                        if card_value_list[_card_value_tmp3] > 0 then
                                            card_value_list[_card_value_tmp3] = card_value_list[_card_value_tmp3] - 1


                                            for _card_value_tmp4, _ in pairs(card_value_list) do
                                                if card_value_list[_card_value_tmp4] > 0 then
                                                    card_value_list[_card_value_tmp4] = card_value_list[_card_value_tmp4] - 1
                                                    local left_card_count = 0
                                                    for _card_value_count, _ in pairs(card_value_list) do
                                                        if card_value_list[_card_value_count] > 0 then
                                                            left_card_count = left_card_count + 1
                                                            break
                                                        end
                                                    end
                
                                                    if left_card_count == 0 then
                                                        local last_card_group_data = self:GetNewGroupData(M.NetType_PlaneOne, _card_value3, prov*4)
                                                        for _card_value4 = _card_value1, _card_value2, 1 do
                                                            table.insert(last_card_group_data.CardValueList, _card_value4)
                                                            table.insert(last_card_group_data.CardValueList, _card_value4)
                                                            table.insert(last_card_group_data.CardValueList, _card_value4)
                                                        end
                                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp1)
                                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp2)
                                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp3)
                                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp4)
                                                        return last_card_group_data
                                                    end
                                                    card_value_list[_card_value_tmp4] = card_value_list[_card_value_tmp4] + 1
                                                end
                                            end

                                            card_value_list[_card_value_tmp3] = card_value_list[_card_value_tmp3] + 1
                                        end
                                    end
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] + 1
                                end
                            end
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] + 1
                        end
                    end

                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] + 3
                    end
                end

                if prov == 5 then
                    local _card_value3 = _card_value1
                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] - 3
                    end

                    for _card_value_tmp1, _ in pairs(card_value_list) do
                        if card_value_list[_card_value_tmp1] > 0 then
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] - 1
                            for _card_value_tmp2, _ in pairs(card_value_list) do
                                if card_value_list[_card_value_tmp2] > 0 then
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] - 1

                                    for _card_value_tmp3, _ in pairs(card_value_list) do
                                        if card_value_list[_card_value_tmp3] > 0 then
                                            card_value_list[_card_value_tmp3] = card_value_list[_card_value_tmp3] - 1


                                            for _card_value_tmp4, _ in pairs(card_value_list) do
                                                if card_value_list[_card_value_tmp4] > 0 then
                                                    card_value_list[_card_value_tmp4] = card_value_list[_card_value_tmp4] - 1

                                                    for _card_value_tmp5, _ in pairs(card_value_list) do
                                                        if card_value_list[_card_value_tmp5] > 0 then
                                                            card_value_list[_card_value_tmp5] = card_value_list[_card_value_tmp5] - 1
                                                            local left_card_count = 0
                                                            for _card_value_count, _ in pairs(card_value_list) do
                                                                if card_value_list[_card_value_count] > 0 then
                                                                    left_card_count = left_card_count + 1
                                                                    break
                                                                end
                                                            end
                        
                                                            if left_card_count == 0 then
                                                                local last_card_group_data = self:GetNewGroupData(M.NetType_PlaneOne, _card_value3, prov*4)
                                                                for _card_value4 = _card_value1, _card_value2, 1 do
                                                                    table.insert(last_card_group_data.CardValueList, _card_value4)
                                                                    table.insert(last_card_group_data.CardValueList, _card_value4)
                                                                    table.insert(last_card_group_data.CardValueList, _card_value4)
                                                                end
                                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp1)
                                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp2)
                                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp3)
                                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp4)
                                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp5)
                                                                return last_card_group_data
                                                            end
                                                            card_value_list[_card_value_tmp5] = card_value_list[_card_value_tmp5] + 1
                                                        end
                                                    end

                                                    card_value_list[_card_value_tmp4] = card_value_list[_card_value_tmp4] + 1
                                                end
                                            end

                                            card_value_list[_card_value_tmp3] = card_value_list[_card_value_tmp3] + 1
                                        end
                                    end
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] + 1
                                end
                            end
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] + 1
                        end
                    end

                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] + 3
                    end
                end
            end
        end

        if card_value_list[_card_value1] > 2 then
            local prov = 0
            for _card_value2, _ in pairs(card_value_list) do
                if _card_value2 == M.Card_Num_2_13 then
                    break
                end
                if card_value_list[_card_value2] > 2 then
                    prov = prov + 1
                else
                    break
                end

                if prov == 2 then
                    local _card_value3 = _card_value1
                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] - 3
                    end

                    for _card_value_tmp1, _ in pairs(card_value_list) do
                        if card_value_list[_card_value_tmp1] > 1 then
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] - 2
                            for _card_value_tmp2, _ in pairs(card_value_list) do
                                if card_value_list[_card_value_tmp2] > 1 then
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] - 2
        
                                    local left_card_count = 0
                                    for _card_value_count, _ in pairs(card_value_list) do
                                        if card_value_list[_card_value_count] > 0 then
                                            left_card_count = left_card_count + 1
                                            break
                                        end
                                    end

                                    if left_card_count == 0 then
                                        local last_card_group_data = self:GetNewGroupData(M.NetType_PlaneTwo, _card_value3, prov*5)
                                        for _card_value4 = _card_value1, _card_value2, 1 do
                                            table.insert(last_card_group_data.CardValueList, _card_value4)
                                            table.insert(last_card_group_data.CardValueList, _card_value4)
                                            table.insert(last_card_group_data.CardValueList, _card_value4)
                                        end
                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp1)
                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp1)
                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp2)
                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp2)
                                        return last_card_group_data
                                    end
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] + 2
                                end
                            end
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] + 2
                        end
                    end

                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] + 3
                    end
                end
                if prov == 3 then
                    local _card_value3 = _card_value1
                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] - 3
                    end

                    for _card_value_tmp1, _ in pairs(card_value_list) do
                        if card_value_list[_card_value_tmp1] > 1 then
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] - 2
                            for _card_value_tmp2, _ in pairs(card_value_list) do
                                if card_value_list[_card_value_tmp2] > 1 then
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] - 2

                                    for _card_value_tmp3, _ in pairs(card_value_list) do
                                        if card_value_list[_card_value_tmp3] > 1 then
                                            card_value_list[_card_value_tmp3] = card_value_list[_card_value_tmp3] - 2
                                            local left_card_count = 0
                                            for _card_value_count, _ in pairs(card_value_list) do
                                                if card_value_list[_card_value_count] > 0 then
                                                    left_card_count = left_card_count + 1
                                                    break
                                                end
                                            end
        
                                            if left_card_count == 0 then
                                                local last_card_group_data = self:GetNewGroupData(M.NetType_PlaneTwo, _card_value3, prov*5)
                                                for _card_value4 = _card_value1, _card_value2, 1 do
                                                    table.insert(last_card_group_data.CardValueList, _card_value4)
                                                    table.insert(last_card_group_data.CardValueList, _card_value4)
                                                    table.insert(last_card_group_data.CardValueList, _card_value4)
                                                end
                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp1)
                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp1)
                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp2)
                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp2)
                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp3)
                                                table.insert(last_card_group_data.CardValueList, _card_value_tmp3)
                                                return last_card_group_data
                                            end
                                            card_value_list[_card_value_tmp3] = card_value_list[_card_value_tmp3] + 2
                                        end
                                    end
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] + 2
                                end
                            end
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] + 2
                        end
                    end

                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] + 3
                    end
                end

                if prov == 4 then
                    local _card_value3 = _card_value1
                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] - 3
                    end

                    for _card_value_tmp1, _ in pairs(card_value_list) do
                        if card_value_list[_card_value_tmp1] > 1 then
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] - 2
                            for _card_value_tmp2, _ in pairs(card_value_list) do
                                if card_value_list[_card_value_tmp2] > 1 then
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] - 2

                                    for _card_value_tmp3, _ in pairs(card_value_list) do
                                        if card_value_list[_card_value_tmp3] > 1 then
                                            card_value_list[_card_value_tmp3] = card_value_list[_card_value_tmp3] - 2


                                            for _card_value_tmp4, _ in pairs(card_value_list) do
                                                if card_value_list[_card_value_tmp4] > 1 then
                                                    card_value_list[_card_value_tmp4] = card_value_list[_card_value_tmp4] - 2
                                                    local left_card_count = 0
                                                    for _card_value_count, _ in pairs(card_value_list) do
                                                        if card_value_list[_card_value_count] > 0 then
                                                            left_card_count = left_card_count + 1
                                                            break
                                                        end
                                                    end
                
                                                    if left_card_count == 0 then
                                                        local last_card_group_data = self:GetNewGroupData(M.NetType_PlaneTwo, _card_value3, prov*5)
                                                        for _card_value4 = _card_value1, _card_value2, 1 do
                                                            table.insert(last_card_group_data.CardValueList, _card_value4)
                                                            table.insert(last_card_group_data.CardValueList, _card_value4)
                                                            table.insert(last_card_group_data.CardValueList, _card_value4)
                                                        end
                                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp1)
                                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp1)
                                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp2)
                                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp2)
                                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp3)
                                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp3)
                                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp4)
                                                        table.insert(last_card_group_data.CardValueList, _card_value_tmp4)
                                                        return last_card_group_data
                                                    end
                                                    card_value_list[_card_value_tmp4] = card_value_list[_card_value_tmp4] + 2
                                                end
                                            end

                                            card_value_list[_card_value_tmp3] = card_value_list[_card_value_tmp3] + 2
                                        end
                                    end
                                    card_value_list[_card_value_tmp2] = card_value_list[_card_value_tmp2] + 2
                                end
                            end
                            card_value_list[_card_value_tmp1] = card_value_list[_card_value_tmp1] + 2
                        end
                    end

                    for _card_value3 = _card_value1, _card_value2, 1 do
                        card_value_list[_card_value3] = card_value_list[_card_value3] + 3
                    end
                end
            end
        end
    end

    local lastCardGroupData = {}
 	lastCardGroupData.CardValueList = {}
	lastCardGroupData.Type = M.NetType_Null
	return lastCardGroupData
end

function M:GetOutPutCardList(hand_card_data, debugData)
    -- print("GetOutPutCardList:hand_card_data=", M:pTable(hand_card_data))
    hand_card_data.OutputCardType = {}
    hand_card_data.OutputCardType.CardValueList = {}
    local last_card_group_data = self:LastOutCardData(hand_card_data.CardValueList)
    if not last_card_group_data.Type and
        last_card_group_data.Type ~= M.NetType_Null and
        last_card_group_data.Type ~= M.NetType_FourTwo and
        last_card_group_data.Type ~= M.NetType_FourFour then
        self:PutOutCardList(hand_card_data, last_card_group_data)
        return true
    end

    local best_hand_card_weight = {}
    best_hand_card_weight.NeedRound = 20
    best_hand_card_weight.SumValue = M.MinCardsValue
    best_hand_card_weight.NeedRound = best_hand_card_weight.NeedRound + 1
    local best_card_group_data = self:GetNewGroupData(M.NetType_Null, 0, 0)

    if (hand_card_data.CardValueList[M.Card_Num_BJ] or 0) > 0 and (hand_card_data.CardValueList[M.Card_Num_SJ] or 0) > 0 then
        hand_card_data.CardValueList[M.Card_Num_BJ] = hand_card_data.CardValueList[M.Card_Num_BJ] - 1
        hand_card_data.CardValueList[M.Card_Num_SJ] = hand_card_data.CardValueList[M.Card_Num_SJ] - 1
        hand_card_data.HandCardCount = hand_card_data.HandCardCount - 2
        local hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
        hand_card_data.CardValueList[M.Card_Num_BJ] = hand_card_data.CardValueList[M.Card_Num_BJ] + 1
        hand_card_data.CardValueList[M.Card_Num_SJ] = hand_card_data.CardValueList[M.Card_Num_SJ] + 1
        hand_card_data.HandCardCount = hand_card_data.HandCardCount + 2
        if hand_card_weight.NeedRound == 1 then
            self:UpdateGroupData(best_card_group_data, M.NetType_Rocket, M.Card_Num_BJ, 2)
            table.insert(best_card_group_data.CardValueList, M.Card_Num_BJ)
            table.insert(best_card_group_data.CardValueList, M.Card_Num_SJ)
            self:PutOutCardList(hand_card_data, best_card_group_data)
            return true
        end
    end

    for card_value_1 = 1, 13, 1 do
        if (hand_card_data.CardValueList[card_value_1] or 0) < 4 then
            if (hand_card_data.CardValueList[card_value_1] or 0) > 2 then
                local prov = 0
                local card_value_2 = card_value_1
                for card_value_2 = card_value_2, 12, 1 do
                    if card_value_2 == M.Card_Num_2_13 then
                        break
                    end

                    if hand_card_data.CardValueList[card_value_2] > 2 then
                        prov = prov + 1
                    else
                        break
                    end

                    if prov == 4 then
                        for card_value_3 = card_value_1, card_value_2, 1 do
                            hand_card_data.CardValueList[card_value_3] = hand_card_data.CardValueList[card_value_3] - 3
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount - prov * 4

                        for card_value_temp_1 = 1, 15, 1 do
                            if (hand_card_data.CardValueList[card_value_temp_1] or 0) > 0 then
                                hand_card_data.CardValueList[card_value_temp_1] = hand_card_data.CardValueList[card_value_temp_1] - 1
                                for card_value_temp_2 = card_value_temp_1, 15, 1 do
                                    if (hand_card_data.CardValueList[card_value_temp_2] or 0) > 0 then
                                        hand_card_data.CardValueList[card_value_temp_2] = hand_card_data.CardValueList[card_value_temp_2] - 1
                                        for card_value_temp_3 = 1, 15, 1 do
                                            if (hand_card_data.CardValueList[card_value_temp_3] or 0) > 0 then
                                                hand_card_data.CardValueList[card_value_temp_3] = hand_card_data.CardValueList[card_value_temp_3] - 1
                                                for card_value_temp_4 = 1, 15, 1 do
                                                    if (hand_card_data.CardValueList[card_value_temp_4] or 0) > 0 then
                                                        hand_card_data.CardValueList[card_value_temp_4] = hand_card_data.CardValueList[card_value_temp_4] - 1

                                                        local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                                                        if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound * 7) < (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound * 7) then
                                                            best_hand_card_weight = temp_hand_card_weight
                                                            self:UpdateGroupData(best_card_group_data, M.NetType_PlaneOne, card_value_2, prov * 4)
                                                            best_card_group_data.CardValueList = {}
                                                            for _card_value = best_card_group_data.MaxCard - (best_card_group_data.Count / 4) + 1, best_card_group_data.MaxCard, 1 do
                                                                table.insert(best_card_group_data.CardValueList, _card_value)
                                                                table.insert(best_card_group_data.CardValueList, _card_value)
                                                                table.insert(best_card_group_data.CardValueList, _card_value)
                                                            end
                                                            table.insert(best_card_group_data.CardValueList, card_value_temp_1)
                                                            table.insert(best_card_group_data.CardValueList, card_value_temp_2)
                                                            table.insert(best_card_group_data.CardValueList, card_value_temp_3)
                                                            table.insert(best_card_group_data.CardValueList, card_value_temp_4)
                                                        end
                                                        hand_card_data.CardValueList[card_value_temp_4] = hand_card_data.CardValueList[card_value_temp_4] + 1
                                                    end
                                                end
                                                hand_card_data.CardValueList[card_value_temp_3] = hand_card_data.CardValueList[card_value_temp_3] + 1
                                            end
                                        end
                                        hand_card_data.CardValueList[card_value_temp_2] = hand_card_data.CardValueList[card_value_temp_2] + 1
                                    end
                                end
                                hand_card_data.CardValueList[card_value_temp_1] = hand_card_data.CardValueList[card_value_temp_1] + 1
                            end
                        end


                        for card_value_3 = card_value_1, card_value_2, 1 do
                            hand_card_data.CardValueList[card_value_3] = hand_card_data.CardValueList[card_value_3] + 3
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount + prov * 4
                    end

                    if prov == 3 then
                        for card_value_3 = card_value_1, card_value_2, 1 do
                            hand_card_data.CardValueList[card_value_3] = hand_card_data.CardValueList[card_value_3] - 3
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount - prov * 4

                        for card_value_temp_1 = 1, 15, 1 do
                            if (hand_card_data.CardValueList[card_value_temp_1] or 0) > 0 then
                                hand_card_data.CardValueList[card_value_temp_1] = hand_card_data.CardValueList[card_value_temp_1] - 1
                                for card_value_temp_2 = card_value_temp_1, 15, 1 do
                                    if (hand_card_data.CardValueList[card_value_temp_2] or 0) > 0 then
                                        hand_card_data.CardValueList[card_value_temp_2] = hand_card_data.CardValueList[card_value_temp_2] - 1
                                        for card_value_temp_3 = 1, 15, 1 do
                                            if (hand_card_data.CardValueList[card_value_temp_3] or 0) > 0 then
                                                hand_card_data.CardValueList[card_value_temp_3] = hand_card_data.CardValueList[card_value_temp_3] - 1
                                                local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                                                if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound * 7) < (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound * 7) then
                                                    best_hand_card_weight = temp_hand_card_weight
                                                    self:UpdateGroupData(best_card_group_data, M.NetType_PlaneOne, card_value_2, prov * 4)
                                                    best_card_group_data.CardValueList = {}
                                                    for _card_value = best_card_group_data.MaxCard - (best_card_group_data.Count / 4) + 1, best_card_group_data.MaxCard, 1 do
                                                        table.insert(best_card_group_data.CardValueList, _card_value)
                                                        table.insert(best_card_group_data.CardValueList, _card_value)
                                                        table.insert(best_card_group_data.CardValueList, _card_value)
                                                    end
                                                    table.insert(best_card_group_data.CardValueList, card_value_temp_1)
                                                    table.insert(best_card_group_data.CardValueList, card_value_temp_2)
                                                    table.insert(best_card_group_data.CardValueList, card_value_temp_3)
                                                end
                                                hand_card_data.CardValueList[card_value_temp_3] = hand_card_data.CardValueList[card_value_temp_3] + 1
                                            end
                                        end
                                        hand_card_data.CardValueList[card_value_temp_2] = hand_card_data.CardValueList[card_value_temp_2] + 1
                                    end
                                end
                                hand_card_data.CardValueList[card_value_temp_1] = hand_card_data.CardValueList[card_value_temp_1] + 1
                            end
                        end


                        for card_value_3 = card_value_1, card_value_2, 1 do
                            hand_card_data.CardValueList[card_value_3] = hand_card_data.CardValueList[card_value_3] + 3
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount + prov * 4
                    end

                    if prov == 2 then
                        for card_value_3 = card_value_1, card_value_2, 1 do
                            hand_card_data.CardValueList[card_value_3] = hand_card_data.CardValueList[card_value_3] - 3
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount - prov * 4

                        for card_value_temp_1 = 1, 15, 1 do
                            if (hand_card_data.CardValueList[card_value_temp_1] or 0) > 0 then
                                hand_card_data.CardValueList[card_value_temp_1] = hand_card_data.CardValueList[card_value_temp_1] - 1
                                for card_value_temp_2 = card_value_temp_1, 15, 1 do
                                    if (hand_card_data.CardValueList[card_value_temp_2] or 0) > 0 then
                                        hand_card_data.CardValueList[card_value_temp_2] = hand_card_data.CardValueList[card_value_temp_2] - 1
                                        local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                                        if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound * 7) < (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound * 7) then
                                            best_hand_card_weight = temp_hand_card_weight
                                            self:UpdateGroupData(best_card_group_data, M.NetType_PlaneOne, card_value_2, prov * 4)
                                            best_card_group_data.CardValueList = {}
                                            for _card_value = best_card_group_data.MaxCard - (best_card_group_data.Count / 4) + 1, best_card_group_data.MaxCard, 1 do
                                                table.insert(best_card_group_data.CardValueList, _card_value)
                                                table.insert(best_card_group_data.CardValueList, _card_value)
                                                table.insert(best_card_group_data.CardValueList, _card_value)
                                            end
                                            table.insert(best_card_group_data.CardValueList, card_value_temp_1)
                                            table.insert(best_card_group_data.CardValueList, card_value_temp_2)
                                        end
                                        hand_card_data.CardValueList[card_value_temp_2] = hand_card_data.CardValueList[card_value_temp_2] + 1
                                    end
                                end
                                hand_card_data.CardValueList[card_value_temp_1] = hand_card_data.CardValueList[card_value_temp_1] + 1
                            end
                        end


                        for card_value_3 = card_value_1, card_value_2, 1 do
                            hand_card_data.CardValueList[card_value_3] = hand_card_data.CardValueList[card_value_3] + 3
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount + prov * 4
                    end
                end
            end

            if (hand_card_data.CardValueList[card_value_1] or 0) > 2 then
                local prov = 0
                local card_value_2 = card_value_1
                for card_value_2 = card_value_2, 12, 1 do
                    if card_value_2 == M.Card_Num_2_13 then
                        break
                    end

                    if hand_card_data.CardValueList[card_value_2] > 2 then
                        prov = prov + 1
                    else
                        break
                    end

                    if prov == 3 then
                        for card_value_3 = card_value_1, card_value_2, 1 do
                            hand_card_data.CardValueList[card_value_3] = hand_card_data.CardValueList[card_value_3] - 3
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount - prov * 5
               
                        for card_value_temp_1 = 1, 13, 1 do
                            if hand_card_data.CardValueList[card_value_temp_1] > 1 then
                                hand_card_data.CardValueList[card_value_temp_1] = hand_card_data.CardValueList[card_value_temp_1] - 2
                                for card_value_temp_2 = card_value_temp_1, 13, 1 do
                                    if hand_card_data.CardValueList[card_value_temp_2] > 1 then
                                        hand_card_data.CardValueList[card_value_temp_2] = hand_card_data.CardValueList[card_value_temp_2] - 2
                                        for card_value_temp_3 = 1, 13, 1 do
                                            if hand_card_data.CardValueList[card_value_temp_3] > 1 then
                                                hand_card_data.CardValueList[card_value_temp_3] = hand_card_data.CardValueList[card_value_temp_3] - 2
                                                local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                                                if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound * 7) < (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound * 7) then
                                                    best_hand_card_weight = temp_hand_card_weight
                                                    self:UpdateGroupData(best_card_group_data, M.NetType_PlaneTwo, card_value_2, prov * 5)
                                                    best_card_group_data.CardValueList = {}
                                                    for _card_value = best_card_group_data.MaxCard - (best_card_group_data.Count / 5) + 1, best_card_group_data.MaxCard, 1 do
                                                        table.insert(best_card_group_data.CardValueList, _card_value)
                                                        table.insert(best_card_group_data.CardValueList, _card_value)
                                                        table.insert(best_card_group_data.CardValueList, _card_value)
                                                    end
                                                    table.insert(best_card_group_data.CardValueList, card_value_temp_1)
                                                    table.insert(best_card_group_data.CardValueList, card_value_temp_1)
                                                    table.insert(best_card_group_data.CardValueList, card_value_temp_2)
                                                    table.insert(best_card_group_data.CardValueList, card_value_temp_2)
                                                    table.insert(best_card_group_data.CardValueList, card_value_temp_3)
                                                    table.insert(best_card_group_data.CardValueList, card_value_temp_3)
                                                end
                                                hand_card_data.CardValueList[card_value_temp_3] = hand_card_data.CardValueList[card_value_temp_3] + 2
                                            end
                                        end
                                        hand_card_data.CardValueList[card_value_temp_2] = hand_card_data.CardValueList[card_value_temp_2] + 2
                                    end
                                end
                                hand_card_data.CardValueList[card_value_temp_1] = hand_card_data.CardValueList[card_value_temp_1] + 2
                            end
                        end

                        for card_value_3 = card_value_1, card_value_2, 1 do
                            hand_card_data.CardValueList[card_value_3] = hand_card_data.CardValueList[card_value_3] + 3
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount + prov * 5
                    end

                    if prov == 2 then
                        for card_value_3 = card_value_1, card_value_2, 1 do
                            hand_card_data.CardValueList[card_value_3] = hand_card_data.CardValueList[card_value_3] - 3
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount - prov * 5
               
                        for card_value_temp_1 = 1, 13, 1 do
                            if hand_card_data.CardValueList[card_value_temp_1] > 1 then
                                hand_card_data.CardValueList[card_value_temp_1] = hand_card_data.CardValueList[card_value_temp_1] - 2
                                for card_value_temp_2 = card_value_temp_1, 13, 1 do
                                    if hand_card_data.CardValueList[card_value_temp_2] > 1 then
                                        hand_card_data.CardValueList[card_value_temp_2] = hand_card_data.CardValueList[card_value_temp_2] - 2
                                        local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                                        if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound * 7) < (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound * 7) then
                                            best_hand_card_weight = temp_hand_card_weight
                                            self:UpdateGroupData(best_card_group_data, M.NetType_PlaneTwo, card_value_2, prov * 5)
                                            best_card_group_data.CardValueList = {}
                                            for _card_value = best_card_group_data.MaxCard - (best_card_group_data.Count / 5) + 1, best_card_group_data.MaxCard, 1 do
                                                table.insert(best_card_group_data.CardValueList, _card_value)
                                                table.insert(best_card_group_data.CardValueList, _card_value)
                                                table.insert(best_card_group_data.CardValueList, _card_value)
                                            end
                                            table.insert(best_card_group_data.CardValueList, card_value_temp_1)
                                            table.insert(best_card_group_data.CardValueList, card_value_temp_1)
                                            table.insert(best_card_group_data.CardValueList, card_value_temp_2)
                                            table.insert(best_card_group_data.CardValueList, card_value_temp_2)
                                        end
                                        hand_card_data.CardValueList[card_value_temp_2] = hand_card_data.CardValueList[card_value_temp_2] + 2
                                    end
                                end
                                hand_card_data.CardValueList[card_value_temp_1] = hand_card_data.CardValueList[card_value_temp_1] + 2
                            end
                        end

                        for card_value_3 = card_value_1, card_value_2, 1 do
                            hand_card_data.CardValueList[card_value_3] = hand_card_data.CardValueList[card_value_3] + 3
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount + prov * 5
                    end
                end
            end

            if (hand_card_data.CardValueList[card_value_1] or 0) > 2 then
                hand_card_data.CardValueList[card_value_1] = hand_card_data.CardValueList[card_value_1] - 3
                for card_value_2 = 1, 15, 1 do
                    if (hand_card_data.CardValueList[card_value_2] or 0) > 0 then
                        hand_card_data.CardValueList[card_value_2] = hand_card_data.CardValueList[card_value_2] - 1
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                        local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                        hand_card_data.CardValueList[card_value_2] = hand_card_data.CardValueList[card_value_2] + 1
                        hand_card_data.HandCardCount =hand_card_data.HandCardCount + 4

                        -- print("temp_hand_card_weight", temp_hand_card_weight)
                        if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound*7) < (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound*7) then
                            best_hand_card_weight = temp_hand_card_weight
                            self:UpdateGroupData(best_card_group_data, M.NetType_ThreeOne, card_value_1, 4)
                            best_card_group_data.CardValueList = {}
                            table.insert(best_card_group_data.CardValueList, card_value_1)
                            table.insert(best_card_group_data.CardValueList, card_value_1)
                            table.insert(best_card_group_data.CardValueList, card_value_1)
                            table.insert(best_card_group_data.CardValueList, card_value_2)
                        end
                    end
                end
                hand_card_data.CardValueList[card_value_1] = hand_card_data.CardValueList[card_value_1] + 3
            end

            if (hand_card_data.CardValueList[card_value_1] or 0) > 2 then
                hand_card_data.CardValueList[card_value_1] = hand_card_data.CardValueList[card_value_1] - 3
                for card_value_2 = 1, 13, 1 do
                    if (hand_card_data.CardValueList[card_value_2] or 0) > 1 then
                        hand_card_data.CardValueList[card_value_2] = hand_card_data.CardValueList[card_value_2] - 2
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount - 5
                        local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                        hand_card_data.CardValueList[card_value_2] = hand_card_data.CardValueList[card_value_2] + 2
                        hand_card_data.HandCardCount =hand_card_data.HandCardCount + 5

                        if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound*7) < (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound*7) then
                            best_hand_card_weight = temp_hand_card_weight
                            self:UpdateGroupData(best_card_group_data, M.NetType_ThreeTwo, card_value_1, 5)
                            best_card_group_data.CardValueList = {}
                            table.insert(best_card_group_data.CardValueList, card_value_1)
                            table.insert(best_card_group_data.CardValueList, card_value_1)
                            table.insert(best_card_group_data.CardValueList, card_value_1)
                            table.insert(best_card_group_data.CardValueList, card_value_2)
                            table.insert(best_card_group_data.CardValueList, card_value_2)
                        end
                    end
                end
                hand_card_data.CardValueList[card_value_1] = hand_card_data.CardValueList[card_value_1] + 3
            end
        end
    end

    for _card_value_1 = 1, 13, 1 do
        if (hand_card_data.CardValueList[_card_value_1] or 0) > 0 and (hand_card_data.CardValueList[_card_value_1] or 0) < 4 then
            if hand_card_data.CardValueList[_card_value_1] >= 1 then
                hand_card_data.CardValueList[_card_value_1] = hand_card_data.CardValueList[_card_value_1] - 1
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 1

                local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                hand_card_data.CardValueList[_card_value_1] = hand_card_data.CardValueList[_card_value_1] + 1
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 1

                if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound*7) <= (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound*7) then
                    best_hand_card_weight = temp_hand_card_weight
                    self:UpdateGroupData(best_card_group_data, M.NetType_One, _card_value_1, 1)
                end
            end

            if (hand_card_data.CardValueList[_card_value_1] or 0) >= 2 then
                hand_card_data.CardValueList[_card_value_1] = hand_card_data.CardValueList[_card_value_1] - 2
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 2

                local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                hand_card_data.CardValueList[_card_value_1] = hand_card_data.CardValueList[_card_value_1] + 2
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 2

                if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound*7) <= (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound*7) then
                    best_hand_card_weight = temp_hand_card_weight
                    self:UpdateGroupData(best_card_group_data, M.NetType_Two, _card_value_1, 2)
                end
            end

            if (hand_card_data.CardValueList[_card_value_1] or 0) >= 3 then
                hand_card_data.CardValueList[_card_value_1] = hand_card_data.CardValueList[_card_value_1] - 3
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 3

                local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                hand_card_data.CardValueList[_card_value_1] = hand_card_data.CardValueList[_card_value_1] + 3
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 3

                if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound*7) <= (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound*7) then
                    best_hand_card_weight = temp_hand_card_weight
                    self:UpdateGroupData(best_card_group_data, M.NetType_Three, _card_value_1, 3)
                end
            end

            if (hand_card_data.CardValueList[_card_value_1] or 0) >= 1 then
                local prov = 0
                for _card_value_2 = _card_value_1, 12, 1 do
                    if (hand_card_data.CardValueList[_card_value_2]or 0) >= 1 then
                        prov = prov + 1
                    else
                        break
                    end

                    if prov >= 5 then
                        for index = _card_value_1, _card_value_2, 1 do
                            hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] - 1
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount - prov
                        local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                        for index = _card_value_1, _card_value_2, 1 do
                            hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] + 1
                        end 
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount + prov

                        if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound*7) <= (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound*7) then
                            best_hand_card_weight = temp_hand_card_weight
                            self:UpdateGroupData(best_card_group_data, M.NetType_Single, _card_value_2, prov)
                        end
                    end

                end

            end

            if (hand_card_data.CardValueList[_card_value_1] or 0) >= 2 then
                local prov = 0
                for _card_value_2 = _card_value_1, 12, 1 do
                    if (hand_card_data.CardValueList[_card_value_2] or 0) >= 2 then
                        prov = prov + 1
                    else
                        break
                    end

                    if prov >= 3 then
                        for index = _card_value_1, _card_value_2, 1 do
                            hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] - 2
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount - prov*2
                        local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                        for index = _card_value_1, _card_value_2, 1 do
                            hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] + 2
                        end 
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount + prov*2

                        if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound*7) <= (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound*7) then
                            best_hand_card_weight = temp_hand_card_weight
                            self:UpdateGroupData(best_card_group_data, M.NetType_DoubleSingle, _card_value_2, prov*2)
                        end
                    end
                end
            end

            if (hand_card_data.CardValueList[_card_value_1] or 0) >= 3 then
                local prov = 0
                for _card_value_2 = _card_value_1, 12, 1 do
                    if hand_card_data.CardValueList[_card_value_2] >= 3 then
                        prov = prov + 1
                    else
                        break
                    end

                    if prov >= 2 then
                        for index = _card_value_1, _card_value_2, 1 do
                            hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] - 3
                        end
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount - prov*3
                        
                        local temp_hand_card_weight, _ = self:GetHandCardWeight(hand_card_data, nil, debugData)
                        for index = _card_value_1, _card_value_2, 1 do
                            hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] + 3
                        end 
                        hand_card_data.HandCardCount = hand_card_data.HandCardCount + prov*3

                        if (best_hand_card_weight.SumValue - best_hand_card_weight.NeedRound*7) <= (temp_hand_card_weight.SumValue - temp_hand_card_weight.NeedRound*7) then
                            best_hand_card_weight = temp_hand_card_weight
                            self:UpdateGroupData(best_card_group_data, M.NetType_Plane, _card_value_2, prov*3)
                        end
                    end
                end
            end

            if best_card_group_data.Type == M.NetType_One then
                best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, best_card_group_data.MaxCard)
                self:PutOutCardList(hand_card_data, best_card_group_data)
                return true
            elseif best_card_group_data.Type == M.NetType_Two then
                best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, best_card_group_data.MaxCard)
                table.insert(best_card_group_data.CardValueList, best_card_group_data.MaxCard)
                self:PutOutCardList(hand_card_data, best_card_group_data)
                return true
            elseif best_card_group_data.Type == M.NetType_Three then
                best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, best_card_group_data.MaxCard)
                table.insert(best_card_group_data.CardValueList, best_card_group_data.MaxCard)
                table.insert(best_card_group_data.CardValueList, best_card_group_data.MaxCard)
                self:PutOutCardList(hand_card_data, best_card_group_data)
                return true          
            elseif best_card_group_data.Type == M.NetType_Single then
                best_card_group_data.CardValueList = {}
                for _card_value_3 = best_card_group_data.MaxCard - best_card_group_data.Count + 1, best_card_group_data.MaxCard, 1 do
                    table.insert(best_card_group_data.CardValueList, _card_value_3)
                end
                self:PutOutCardList(hand_card_data, best_card_group_data)
                return true
            elseif best_card_group_data.Type == M.NetType_DoubleSingle then
                best_card_group_data.CardValueList = {}
                for _card_value_3 = best_card_group_data.MaxCard - best_card_group_data.Count/2 + 1, best_card_group_data.MaxCard, 1 do
                    table.insert(best_card_group_data.CardValueList, _card_value_3)
                    table.insert(best_card_group_data.CardValueList, _card_value_3)
                end
                self:PutOutCardList(hand_card_data, best_card_group_data)
                return true
            elseif best_card_group_data.Type == M.NetType_Plane then
                best_card_group_data.CardValueList = {}
                for _card_value_3 = best_card_group_data.MaxCard - best_card_group_data.Count/3 + 1, best_card_group_data.MaxCard, 1 do
                    table.insert(best_card_group_data.CardValueList, _card_value_3)
                    table.insert(best_card_group_data.CardValueList, _card_value_3)
                    table.insert(best_card_group_data.CardValueList, _card_value_3)
                end
                self:PutOutCardList(hand_card_data, best_card_group_data)
                return true
            elseif best_card_group_data.Type == M.NetType_ThreeOne then
                self:PutOutCardList(hand_card_data, best_card_group_data)
                return true
            elseif best_card_group_data.Type == M.NetType_ThreeTwo then
                self:PutOutCardList(hand_card_data, best_card_group_data)
                return true
            elseif best_card_group_data.Type == M.NetType_PlaneOne then
                self:PutOutCardList(hand_card_data, best_card_group_data)
                return true    
            elseif best_card_group_data.Type == M.NetType_PlaneTwo then
                self:PutOutCardList(hand_card_data, best_card_group_data)
                return true                    
            end
        end
    end

    if (hand_card_data.CardValueList[M.Card_Num_SJ] or 0) == 1 and (hand_card_data.CardValueList[M.Card_Num_BJ] or 0) == 0 then
        self:UpdateGroupData(best_card_group_data, M.NetType_One, M.Card_Num_SJ, 1)
        best_card_group_data.CardValueList = {}
        table.insert(best_card_group_data.CardValueList, M.Card_Num_SJ)
        self:PutOutCardList(hand_card_data, best_card_group_data)
        return true
    elseif (hand_card_data.CardValueList[M.Card_Num_BJ] or 0) == 1 and (hand_card_data.CardValueList[M.Card_Num_SJ] or 0) == 0 then
        self:UpdateGroupData(best_card_group_data, M.NetType_One, M.Card_Num_BJ, 1)
        best_card_group_data.CardValueList = {}
        table.insert(best_card_group_data.CardValueList, M.Card_Num_BJ)
        self:PutOutCardList(hand_card_data, best_card_group_data)
        return true
    end

    for _card_value_2 = 1, 13, 1 do
        if (hand_card_data.CardValueList[_card_value_2] or 0) > 3 then
            self:UpdateGroupData(best_card_group_data, M.NetType_Bomb4, _card_value_2, 4)
            table.insert(best_card_group_data.CardValueList, _card_value_2)
            table.insert(best_card_group_data.CardValueList, _card_value_2)
            table.insert(best_card_group_data.CardValueList, _card_value_2)
            table.insert(best_card_group_data.CardValueList, _card_value_2)
            self:PutOutCardList(hand_card_data, best_card_group_data)
            return true
        end
    end

    self:UpdateGroupData(best_card_group_data, M.NetType_Null, 0, 0)
    self:PutOutCardList(hand_card_data, best_card_group_data)
    return true
end

function M:PutOutCardList(hand_card_data, card_group_data)
    hand_card_data.OutputCardType = {}
    hand_card_data.OutputCardType.CardValueList = {}
    hand_card_data.OutputCardType.Type = card_group_data.Type
	hand_card_data.OutputCardType.Value = card_group_data.Value
	hand_card_data.OutputCardType.Count = card_group_data.Count
	hand_card_data.OutputCardType.MaxCard = card_group_data.MaxCard
    for _, _card_value in pairs(card_group_data.CardValueList) do
        table.insert(hand_card_data.OutputCardType.CardValueList, _card_value)
    end
end

function M:GetCardWeight(card_type, max_card_value)
    if card_type == M.NetType_Null then
        return 0
    elseif card_type == M.NetType_One then
        return max_card_value - 7
    elseif card_type == M.NetType_Two then
        return max_card_value - 7
    elseif card_type == M.NetType_Single then
        return max_card_value - 6
    elseif card_type == M.NetType_DoubleSingle then
        return max_card_value - 6
    elseif card_type == M.NetType_Three then
        return max_card_value - 7
    elseif card_type == M.NetType_ThreeOne then
        return max_card_value - 7
    elseif card_type == M.NetType_ThreeTwo then
        return max_card_value - 7
    elseif card_type == M.NetType_Plane then
        return (max_card_value + 1) / 2
    elseif card_type == M.NetType_PlaneOne then
        return (max_card_value + 1) / 2
    elseif card_type == M.NetType_PlaneTwo then
        return (max_card_value + 1) / 2
    elseif card_type == M.NetType_FourTwo then
        return max_card_value / 2
    elseif card_type == M.NetType_FourFour then
        return max_card_value / 2
    elseif card_type == M.NetType_Bomb4 then
        return max_card_value + 7
    elseif card_type == M.NetType_Rocket then
        return 20
    end

    return 0
end

function M:UpdateGroupData(new_card_group_data, card_type, max_card_value, count)
	new_card_group_data.Type = card_type
	new_card_group_data.MaxCard = max_card_value
	new_card_group_data.Count = count
    if card_type == M.NetType_Null then
        new_card_group_data.Value = 0
    elseif card_type == M.NetType_One then
        new_card_group_data.Value = max_card_value - 7
    elseif card_type == M.NetType_Two then
        new_card_group_data.Value = max_card_value - 7
    elseif card_type == M.NetType_Single then
        new_card_group_data.Value = max_card_value - 6
    elseif card_type == M.NetType_DoubleSingle then
        new_card_group_data.Value = max_card_value - 6
    elseif card_type == M.NetType_Three then
        new_card_group_data.Value = max_card_value - 7
    elseif card_type == M.NetType_ThreeOne then
        new_card_group_data.Value = max_card_value - 7
    elseif card_type == M.NetType_ThreeTwo then
        new_card_group_data.Value = max_card_value - 7
    elseif card_type == M.NetType_Plane then
        new_card_group_data.Value = (max_card_value + 1) / 2
    elseif card_type == M.NetType_PlaneOne then
        new_card_group_data.Value = (max_card_value + 1) / 2
    elseif card_type == M.NetType_PlaneTwo then
        new_card_group_data.Value = (max_card_value + 1) / 2
    elseif card_type == M.NetType_FourTwo then
        new_card_group_data.Value = max_card_value / 2
    elseif card_type == M.NetType_FourFour then
        new_card_group_data.Value = max_card_value / 2
    elseif card_type == M.NetType_Bomb4 then
        new_card_group_data.Value = max_card_value + 7
    elseif card_type == M.NetType_Rocket then
        new_card_group_data.Value = 20
    else
        new_card_group_data.Value = 0
    end
    new_card_group_data.Value = new_card_group_data.Value - 1
    return new_card_group_data
end

function M:GetNewGroupData(card_type, max_card_value, count)
    local new_card_group_data = {}
    new_card_group_data.CardValueList = {}
    self:UpdateGroupData(new_card_group_data, card_type, max_card_value, count)
    return new_card_group_data
end

function M:FirstOutCard(_cardValueList)

    -- print("_cardValueList=", self:pTable(_cardValueList))
    local src_card_value_list = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
    for _, _cardValue in pairs(_cardValueList) do
        src_card_value_list[_cardValue] = src_card_value_list[_cardValue] + 1
    end

    -- print("FirstOutCard:src_card_value_list=",  M:pTable(src_card_value_list))
    local hand_card_data = {}
    hand_card_data.CardValueList = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
    hand_card_data.HandCardCount = 0
    for _card_value, _count in pairs(src_card_value_list) do
        if _count > 0 then
            hand_card_data.HandCardCount = hand_card_data.HandCardCount + _count
            hand_card_data.CardValueList[_card_value] = _count
            if hand_card_data.HandCardCount >= self.card_calculate_count_limit then
                break
            end
        end
    end

    local beginTime = os.time()
    local card_out_temp = {}
    local debugData = {num=0, numLimit = 100000}
    local _, card_out_list = self:GetHandCardWeight(hand_card_data, card_out_temp, debugData)
    local endTime = os.time()
    self:print(0, 0, "【first】:FirstOutCard::consume time: ".. endTime - beginTime, "debugData=",  self:pTable(debugData))
    return card_out_list
end

function M:pTable(list)
    if not list then
        return nil
    end
    local s = "{"
    for key, value in pairs(list) do
        if type(value) == "table" then
            s = s ..key.. "="..self:pTable(value)..", "
        else
            s = s ..key.. "="..tostring(value)..", "
        end
    end
    s = s .. "}"
    return s
end

function M:TransType(type)
    if type == M.NetType_One then
        return "dan"
    elseif type == M.NetType_Two then
        return "dui"
    elseif type == M.NetType_Three then
        return "tuple"
    elseif type == M.NetType_ThreeOne then
        return "sandaiyi"
    elseif type == M.NetType_ThreeTwo then
        return "sandaiyidui"
    elseif type == M.NetType_Single then
        return "shunzi"
    elseif type == M.NetType_DoubleSingle then
        return "liandui"
    elseif type == M.NetType_Plane then
        return "feiji_budai"
    elseif type == M.NetType_PlaneOne then
        return "feiji_daidan"
    elseif type == M.NetType_PlaneTwo then
        return "feiji_daidui"
    elseif type == M.NetType_FourTwo then
        return "sidaier"
    elseif type == M.NetType_FourFour then
        return "sidailiangdui"
    elseif type == M.NetType_Bomb4 then
        return "zhadan"
    elseif type == M.NetType_Rocket then
        return "wangzha"
    end
end

function M:NextIsTeammate(roomData)
    if roomData.pList[roomData.index].isLandlord then
        return false
    end

    local nextIndex = roomData.index + 1 
    if nextIndex > 3 then
        nextIndex = 1
    end

    if roomData.pList[nextIndex].isLandlord then
        return false
    end

    return true
end

function M:GetNextCardCount(roomData)
    local nextIndex = roomData.index + 1 
    if nextIndex > 3 then
        nextIndex = 1
    end

    return self:GetCardCountByIndex(nextIndex, roomData)
end

function M:AIFirstOut3(card_out_list, roomData)
    local valid_index = #card_out_list
    if self:NextIsTeammate(roomData) or self:GetNextCardCount(roomData) ~= 2 then
        return nil
    end

    if card_out_list[valid_index].Type ~= M.NetType_Two then
        return card_out_list[valid_index]
    end

    local _out_list
    for _index = valid_index, 1, -1 do
        _out_list = card_out_list[_index]
        if _out_list.Type ~= M.NetType_Two
            or _out_list.Type ~= M.NetType_FourTwo
            or _out_list.Type ~= M.NetType_FourFour then
                return _out_list
            end
    end

    local max_card = M.Card_Num_3
    local bomb_card = -1
    local pair_count = 0
    local three_card_count = 0

    local isAllDuiFlag = true
    for _, _card_group_data in pairs(card_out_list) do
        if _card_group_data.MaxCard > max_card then
            max_card = _card_group_data.MaxCard
        end

        if _card_group_data.Type >= M.NetType_Bomb4 then
            bomb_card = _card_group_data.MaxCard
        end

        if _card_group_data.Type == M.NetType_Two then
            pair_count = pair_count + 1
        end

        if _card_group_data.Type > M.NetType_Two then
            three_card_count = three_card_count + 1
        end
        
        if _card_group_data.Type ~= M.NetType_Two then
            isAllDuiFlag = false
        end
    end

    if pair_count >= valid_index - three_card_count - 1 then
        local max_flag = true
        if bomb_card == -1 then
            -- local jipaiqiList = roomData.pList[roomData.index].jipaiqi
            local jipaiqiList = self:CardsToCardValueList(roomData.pList[roomData.index].jipaiqi)
            for _card_value, _count in pairs(jipaiqiList) do
                if _count > 0 then
                    if _card_value > max_card then
                        max_flag = false
                    end
                end
            end
        end

        --出最小单牌
        if max_flag then
            local _out_list = {}
            _out_list.Type = M.NetType_One
            _out_list.Count = card_out_list[valid_index].Count
            _out_list.CardValueList = card_out_list[valid_index].CardValueList
            return _out_list
        end

    end

    if isAllDuiFlag and valid_index > 1 then
        return card_out_list[valid_index-1]
    end

    return nil
end

function M:AIFirstOut4(card_out_list, roomData)
    if not self:NextIsTeammate(roomData) then
        return nil
    end

    if self:GetNextCardCount(roomData) ~= 1 then
        return nil
    end

    local valid_index = #card_out_list
    if card_out_list[valid_index].Type == M.NetType_One and card_out_list[valid_index].MaxCard < M.Card_Num_10 then
        return card_out_list[valid_index]
    end

    local min_card = -1
    for _, _card_value1 in pairs(roomData.pList[roomData.index].leftCards) do
        if min_card == -1 then
            min_card = _card_value1
        else 
            if _card_value1 < min_card then
                min_card = _card_value1
            end
        end
    end

    if min_card < M.Card_Num_10 then
        local _out_list = {}
        _out_list.Type = M.NetType_One
        _out_list.Count = 1
        _out_list.CardValueList = {min_card}
        return _out_list
    end

    return nil
end

function M:GetLandlordCardCount(roomData)
    for _, _p in pairs(roomData.pList) do
        if _p.isLandlord then
            return _p.leftCardNum
        end
    end

    return 0
end

function M:GetPreCardCount(roomData)
    local prevIndex = roomData.index - 1
    if prevIndex <= 0 then
        prevIndex = 3
    end
    return self:GetCardCountByIndex(prevIndex, roomData)
end

function M:GetCardCountByIndex(index, roomData)
    if not roomData.pList[index] then
        return 0
    end
    return roomData.pList[index].leftCardNum
end

function M:GetCardCountById(id, roomData)
    local index = 0
    for _index, _p in pairs(roomData.pList) do
        if _p.id == id then
            index = _index
            break
        end
    end
    return self:GetCardCountByIndex(index, roomData)
end

function M:IsLandlorderById(id, roomData)
    for _, _p in pairs(roomData.pList) do
        if _p.id == id and _p.isLandlord then
            return true
        end
    end

    return false
end

function M:NextIsLandlord(roomData)
    local nextIndex = roomData.index + 1
    if nextIndex > 3 then
        nextIndex = 1
    end

    return roomData.pList[nextIndex].isLandlord
end

function M:PrevIsLandlord(roomData)
    local prevIndex = roomData.index - 1
    if prevIndex <= 0 then
        prevIndex = 3
    end
    return roomData.pList[prevIndex].isLandlord
end

function M:IsTeammateByIndex(index, roomData)
    if roomData.pList[roomData.index].isLandlord then
        return false
    end

    if roomData.pList[index].isLandlord then
        return false
    end

    return true
end

function M:IsTeammateById(id, roomData)
    if roomData.pList[roomData.index].isLandlord then
        return false
    end

    local index = 0
    for _index, _p in pairs(roomData.pList) do
        if _p.id == id then
            index = _index
            break
        end
    end

    return self:IsTeammateByIndex(index, roomData)
end

function M:CardsToCardValueList(cards)
    local cardValue = 0
    local cardValueMap = {}
    for _, _card in pairs(cards) do
        cardValue = self.mapValue[_card]
        if cardValue then
            cardValueMap[cardValue] = (cardValueMap[cardValue] or 0) + 1
        end
    end
    return cardValueMap
end

function M:AIFirstOut5(card_out_list, roomData)
    if self:GetLandlordCardCount(roomData) ~= 1 or roomData.pList[roomData.index].isLandlord then
        return nil
    end

    local valid_index = #card_out_list
    if card_out_list[valid_index].Type ~= M.NetType_One then
        if card_out_list[valid_index].Type == M.NetType_PlaneTwo then
            local dan_card_value_count = 0
            local min_card_value = -1
            for _, _card_out_group in pairs(card_out_list) do
                if _card_out_group.Type == M.NetType_One then
                    dan_card_value_count = dan_card_value_count + 1
                    if min_card_value == -1 or _card_out_group.MaxCard < min_card_value then
                        min_card_value = _card_out_group.MaxCard
                    end
                end
            end

            if dan_card_value_count > 1 then
                local _out_list = {}
                _out_list.Type = M.NetType_PlaneOne
                _out_list.Count = 4
                _out_list.CardValueList = {}
                table.insert( _out_list.CardValueList, card_out_list[valid_index].MaxCard)
                table.insert( _out_list.CardValueList, card_out_list[valid_index].MaxCard)
                table.insert( _out_list.CardValueList, card_out_list[valid_index].MaxCard)
                table.insert( _out_list.CardValueList, min_card_value)
                return _out_list
            end
        end

        return card_out_list[valid_index]
    end

    if self:NextIsLandlord(roomData) then
        for _index = valid_index, 1, -1 do
            local _card_out_group = card_out_list[_index]
            if _card_out_group.Type ~= M.NetType_One then
                return _card_out_group
            end
        end
    elseif self:PrevIsLandlord(roomData) then
        local sing_count = 0
        for _index = valid_index, 1, -1 do
            local _card_out_group = card_out_list[_index]
            if _card_out_group.Type ~= M.NetType_One and _card_out_group.MaxCard < M.Card_Num_A then
                sing_count = sing_count + 1
            end
        end

        local jipaiqiList = self:CardsToCardValueList(roomData.pList[roomData.index].jipaiqi)
   		local max_card_value = -1
		local max_pair_card_value = -1
        for _card_value, _count in pairs(jipaiqiList) do
            if _count > 0  then
                if _card_value > max_card_value then
                    max_card_value = _card_value
                end

                if _count >= 2 and _card_value > max_pair_card_value then
                    max_pair_card_value = _card_value
                end
            end
        end

        if sing_count >= 2 then
            local cardValueList = self:CardsToCardValueList(roomData.pList[roomData.index].leftCards)
            for _card_value, _card_count in pairs(cardValueList) do
                if _card_count == 2 then
                    if max_pair_card_value > _card_value then
                        local _out_list = {}
                        _out_list.Type = M.NetType_Two
                        _out_list.Count = 2
                        _out_list.CardValueList = {}
                        table.insert( _out_list.CardValueList, _card_value)
                        table.insert( _out_list.CardValueList, _card_value)
                        return _out_list
                    end
                end
            end
        end

        for _index = valid_index, 1, -1 do
            local _card_out_group = card_out_list[_index]
            if _card_out_group.Type ~= M.NetType_One then
                return _card_out_group
            end
        end
    end

    local max_card_value = 0
    local cardValueList = self:CardsToCardValueList(roomData.pList[roomData.index].leftCards)
    for _card_value, _card_count in pairs(cardValueList) do
        if _card_count == 1 then
             if max_card_value < _card_value then
                 max_card_value = _card_value
             end
        end
    end

    if max_card_value > 0 then
        local _out_list = {}
        _out_list.Type = M.NetType_One
        _out_list.Count = 1
        _out_list.CardValueList = {}
        table.insert( _out_list.CardValueList, max_card_value)
        return _out_list
    end

    return nil
end

function M:AIFirstOut6(card_out_list, roomData)
    if not roomData.pList[roomData.index].isLandlord then
        return
    end

    if self:GetPreCardCount(roomData)  ~= 1 and self:GetNextCardCount(roomData) ~= 1 then
        return
    end

    local valid_index = #card_out_list
    if card_out_list[valid_index].Type ~= M.NetType_One then
        return card_out_list[valid_index]
    end

    for _index = valid_index, 1, -1 do
        if card_out_list[_index] ~= M.NetType_One then
            return card_out_list[_index]
        end
    end

    local max_card_value = 0
    local cardValueList = self:CardsToCardValueList(roomData.pList[roomData.index].leftCards)
    for _card_value, _card_count in pairs(cardValueList) do
        if _card_count == 1 then
             if max_card_value < _card_value then
                 max_card_value = _card_value
             end
        end
    end

    if max_card_value > 0 then
        local _out_list = {}
        _out_list.Type = M.NetType_One
        _out_list.Count = 1
        _out_list.CardValueList = {}
        table.insert( _out_list.CardValueList, max_card_value)
        return _out_list
    end

    return nil
end

function M:GetFirstOutCard(roomData)
    if not roomData then
        return nil
    end
    local cPlayer = roomData.pList[roomData.index]
    if not cPlayer then
        return nil
    end
    self:InitMap()
    local _cardValueList = self:CardArrayToCard54(cPlayer.leftCards)
    local first_data_list = self:FirstOutCard(_cardValueList)
    if first_data_list then
        local validIndex = #first_data_list
        if validIndex > 0 then
            local first_data = first_data_list[validIndex]
            if validIndex == 1 then
                self:print(cPlayer.id, roomData.lastPlayerId, "【first_0】:AIFirstOut0:first_data=", M:pTable(first_data), ", cardArray=", M:pTable(cPlayer.leftCards))
                return first_data

                -- local outCardArray = self:Card54ToCardArray(first_data.CardValueList, cPlayer.leftCards)
                -- local wdata = util.parseCardTypeOnly(outCardArray)
                -- if wdata then
                --     self:print(cPlayer.id, roomData.lastPlayerId, "【first_0】:AIFirstOut0:CardValueList=", M:pTable(first_data),"outCardData=", M:pTable(wdata), ", cardArray=", M:pTable(cPlayer.leftCards))
                --     return wdata
                -- end
            end

            local first_data3 = self:AIFirstOut3(first_data_list, roomData)
            if first_data3 and first_data3.Type ~= M.NetType_Null  then
                self:print(cPlayer.id, roomData.lastPlayerId, "【first_1】:AIFirstOut3:first_data=", M:pTable(first_data3), "roomData=", self:pTable(roomData))
                return first_data3
            end

            local first_data4 = self:AIFirstOut4(first_data_list, roomData)
            if first_data4 and first_data4.Type ~= M.NetType_Null  then
                self:print(cPlayer.id, roomData.lastPlayerId, "【first_2】:AIFirstOut4:first_data=", M:pTable(first_data4), "roomData=", self:pTable(roomData))
                return first_data4
            end

            local first_data5 = self:AIFirstOut5(first_data_list, roomData)
            if first_data5 and first_data5.Type ~= M.NetType_Null  then
                self:print(cPlayer.id, roomData.lastPlayerId, "【first_3】:AIFirstOut5:first_data=", M:pTable(first_data5), "roomData=", self:pTable(roomData))
                return first_data5
            end

            local first_data6 = self:AIFirstOut6(first_data_list, roomData)
            if first_data6 and first_data6.Type ~= M.NetType_Null  then
                self:print(cPlayer.id, roomData.lastPlayerId, "【first_4】:AIFirstOut6:first_data=", M:pTable(first_data6), "roomData=", self:pTable(roomData))
                return first_data6
            end
            self:print(cPlayer.id, roomData.lastPlayerId, "【first_5】:AIFirstOut:end=", M:pTable(first_data), ", cardArray=", M:pTable(cPlayer.leftCards))
            -- local outCardArray = self:Card54ToCardArray(first_data.CardValueList, cPlayer.leftCards)
            -- local wdata = util.parseCardTypeOnly(outCardArray)
            -- if wdata then
            --     self:print(cPlayer.id, roomData.lastPlayerId, "【first_5】:AIFirstOut:end=", M:pTable(first_data),"outCardData=", M:pTable(wdata), ", cardArray=", M:pTable(cPlayer.leftCards))
            --     return wdata
            -- end
            return first_data
        end
    end
    self:print(cPlayer.id, roomData.lastPlayerId, "【first_6】:AIFirstOut:end error!!!!!!!!!!!!!!!")
    return nil
end

function M:GetFirstOutCardEx(roomData)
    local outData
    local cPlayer = roomData.pList[roomData.index]
    if not cPlayer then
        return nil
    end

    xpcall(function (...)
        outData = self:GetFirstOutCard(roomData)
    end,
    function ()
        self:print(cPlayer.id, roomData.lastPlayerId, "【first_xpcall】:roomData=", M:pTable(roomData), "traceback=", debug.traceback())
    end,
    roomData)

    if outData and outData.Type ~= self.NetType_Null then
        local outCardArray = self:Card54ToCardArray(outData.CardValueList, cPlayer.leftCards)
        local wdata = util.parseCardTypeOnly(outCardArray)
        if wdata then
            self:print(cPlayer.id, roomData.lastPlayerId, "【first_end】:outData=", M:pTable(outData), ", outCardData=", M:pTable(wdata), ", cardArray=", M:pTable(cPlayer.leftCards))
            return wdata
        end
    end
    self:print(cPlayer.id, roomData.lastPlayerId, "【first_end】: error, !!!!!!!!")
    return nil
end

function M:print(id, last_id, s,...)
    local _s = "【robotAi】:curentId=" .. (id or 0)..", lastPlayerId="..(last_id or 0)
    print(_s, s, ...)
end


return M