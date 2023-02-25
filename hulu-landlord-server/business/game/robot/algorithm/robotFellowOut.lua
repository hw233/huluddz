local robot = require "game.robot.algorithm.robot"
local util = require "util.ddz_classic"
local M = {}

function M:GetSimplifyHandCardWeight(hand_card_data, debugData)
    if hand_card_data.HandCardCount > robot.card_calculate_count_limit then
        local hand_card_data1 = {}
        hand_card_data1.CardValueList = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
        hand_card_data1.HandCardCount = 0

        local hand_card_data2 = {}
        hand_card_data2.CardValueList = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
        hand_card_data2.HandCardCount = 0

        for _card_value, _count in pairs(hand_card_data.CardValueList) do
            if _count > 0 then
                if hand_card_data1.HandCardCount < robot.card_calculate_count_limit then
                    hand_card_data1.CardValueList[_card_value] = _count
                    hand_card_data1.HandCardCount = hand_card_data1.HandCardCount + _count
                else
                    hand_card_data2.CardValueList[_card_value] = _count
                    hand_card_data2.HandCardCount = hand_card_data2.HandCardCount + _count
                end
            end
        end

        local card_weight, _ = robot:GetHandCardWeight(hand_card_data1, nil, debugData)
        local card_weight_temp, _ = robot:GetHandCardWeight(hand_card_data2, nil, debugData)

        card_weight.SumValue = card_weight.SumValue + card_weight_temp.SumValue
        card_weight.NeedRound = card_weight.NeedRound + card_weight_temp.NeedRound
        return card_weight
    end

    local card_weight, _ = robot:GetHandCardWeight(hand_card_data, nil, debugData)
    return card_weight
end

function M:PassiveOutCard(card_group_data, hand_card_data, debugData)
    hand_card_data.OutputCardType = {}
    hand_card_data.OutputCardType.CardValueList = {}

    local best_card_group_data = robot:GetNewGroupData(robot.NetType_Null, 0, 0)
    if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
        if hand_card_data.HandCardCount <= robot.card_calculate_count_limit then
            hand_card_data.CardValueList[robot.Card_Num_BJ] = hand_card_data.CardValueList[robot.Card_Num_BJ] - 1
            hand_card_data.CardValueList[robot.Card_Num_SJ] = hand_card_data.CardValueList[robot.Card_Num_SJ] - 1
            hand_card_data.HandCardCount = hand_card_data.HandCardCount - 2

            local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
            hand_card_data.CardValueList[robot.Card_Num_BJ] = hand_card_data.CardValueList[robot.Card_Num_BJ] + 1
            hand_card_data.CardValueList[robot.Card_Num_SJ] = hand_card_data.CardValueList[robot.Card_Num_SJ] + 1
            hand_card_data.HandCardCount = hand_card_data.HandCardCount + 2

            if hand_card_weight_temp.NeedRound == 1 then
                robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
                table.insert( best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert( best_card_group_data.CardValueList, robot.Card_Num_SJ)
                robot:PutOutCardList(hand_card_data, best_card_group_data)
                return hand_card_data.OutputCardType
            end
        end
    end

    if card_group_data.Type < robot.NetType_Bomb4 then
        local card_group_data_temp = robot:LastOutCardData(hand_card_data.CardValueList)
        if card_group_data_temp.Type ~= robot.NetType_Null then
            if card_group_data_temp.Type == card_group_data.Type and card_group_data_temp.MaxCard > card_group_data.MaxCard then
                best_card_group_data.Type = card_group_data_temp.Type
                best_card_group_data.Count = card_group_data_temp.Count
                best_card_group_data.MaxCard = card_group_data_temp.MaxCard
                best_card_group_data.Value = card_group_data_temp.Value
                for _, _card_value in pairs(card_group_data_temp.CardValueList) do
                    table.insert(best_card_group_data.CardValueList, _card_value) 
                end
                robot:PutOutCardList(hand_card_data, best_card_group_data)
                return hand_card_data.OutputCardType
            elseif card_group_data_temp.Type == robot.NetType_Bomb4 or card_group_data_temp.Type == robot.NetType_Rocket then
                best_card_group_data.Type = card_group_data_temp.Type
                best_card_group_data.Count = card_group_data_temp.Count
                best_card_group_data.MaxCard = card_group_data_temp.MaxCard
                best_card_group_data.Value = card_group_data_temp.Value
                for _, _card_value in pairs(card_group_data_temp.CardValueList) do
                    table.insert(best_card_group_data.CardValueList, _card_value)
                end
                robot:PutOutCardList(hand_card_data, best_card_group_data)
                return hand_card_data.OutputCardType
            end
        end
    end

    if card_group_data.Type == robot.NetType_One then
        local best_hand_card_weight = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
        best_hand_card_weight.NeedRound = best_hand_card_weight.NeedRound + 1
        local best_max_card_value = -1
        local passed = true

        for _card_value = card_group_data.MaxCard + 1, robot.Card_Num_BJ, 1 do
            if hand_card_data.CardValueList[_card_value] > 0 and hand_card_data.CardValueList[_card_value] < 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 1
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 1
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 1
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 1
                if (best_hand_card_weight.SumValue-(best_hand_card_weight.NeedRound*7)) <= (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_One, best_max_card_value, 1)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

        for _card_value = 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4
                if hand_card_weight_temp.SumValue > 0 then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                    break
                end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, best_max_card_value, 4)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

        if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
            if best_hand_card_weight.SumValue > 20 then
                robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
                best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
                robot:PutOutCardList(hand_card_data, best_card_group_data)
                return hand_card_data.OutputCardType
            end
        end

        return hand_card_data.OutputCardType
    elseif card_group_data.Type == robot.NetType_Two then
        local best_hand_card_weight = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
        hand_card_data.NeedRound = (hand_card_data.NeedRound or 0) + 1
        local best_max_card_value = -1
        local passed = true
        -- for _card_value := card_group_data.MaxCard + 1; _card_value < 15; _card_value++ {
        for _card_value = card_group_data.MaxCard + 1, robot.Card_Num_BJ, 1 do
            if hand_card_data.CardValueList[_card_value] >= 2 and hand_card_data.CardValueList[_card_value] < 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 2
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 2
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 2
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 2

                if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) <= (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Two, best_max_card_value, 2)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

        for _card_value = 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4
                if hand_card_weight_temp.SumValue > 0 then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                    break
                end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, best_max_card_value, 4)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

        if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
            if best_hand_card_weight.SumValue > 20 then
                robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket,robot.Card_Num_BJ, 2)
                best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
                robot:PutOutCardList(hand_card_data, best_card_group_data)
                return hand_card_data.OutputCardType
            end
        end
        return hand_card_data.OutputCardType
    elseif card_group_data.Type == robot.NetType_Three then
        local best_hand_card_weight = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
        hand_card_data.NeedRound = (hand_card_data.NeedRound or 0) + 1
        local best_max_card_value = -1
        local passed = true
        for _card_value = card_group_data.MaxCard + 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 3 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 3
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 3
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 3
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 3
                if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) <= (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Three, best_max_card_value, 3)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

        for _card_value = 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4
                if hand_card_weight_temp.SumValue > 0 then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                    break
			    end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, best_max_card_value, 4)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

		--出王炸
		if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
			if best_hand_card_weight.SumValue > 20 then
				robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
				best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
				robot:PutOutCardList(hand_card_data, best_card_group_data)
				return hand_card_data.OutputCardType
            end
		end
    elseif card_group_data.Type == robot.NetType_ThreeOne then
        local best_hand_card_weight = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
        hand_card_data.NeedRound = (hand_card_data.NeedRound or 0) + 1
        local best_max_card_value = -1
        local  tmp_1 = 0
        local passed = true

        for _card_value1 = card_group_data.MaxCard + 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value1] == 3 then
                for _card_value2 = 1, robot.Card_Num_BJ, 1 do
                    if hand_card_data.CardValueList[_card_value2] > 0 and _card_value1 ~= _card_value2 then
                        hand_card_data.CardValueList[_card_value1] = hand_card_data.CardValueList[_card_value1] - 3
            			hand_card_data.CardValueList[_card_value2] = hand_card_data.CardValueList[_card_value2] - 1
            			hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
            			local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                        hand_card_data.CardValueList[_card_value1] = hand_card_data.CardValueList[_card_value1] + 3
            			hand_card_data.CardValueList[_card_value2] = hand_card_data.CardValueList[_card_value2] + 1
            			hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4

                        --  //选取总权值-轮次*7值最高的策略  因为我们认为剩余的手牌需要n次控手的机会才能出完，若轮次牌型很大（如炸弹） 则其-7的价值也会为正
            			if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) <= (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
            				best_hand_card_weight = hand_card_weight_temp
            				best_max_card_value = _card_value1
            				tmp_1 = _card_value2
            				passed = false
                        end
                    end
                end
            end
        end


		if not passed then
			robot:UpdateGroupData(best_card_group_data, robot.NetType_ThreeOne, best_max_card_value, 4)
			best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, tmp_1)

			robot:PutOutCardList(hand_card_data, best_card_group_data)
			return hand_card_data.OutputCardType
		end

        for _card_value = 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4
                if hand_card_weight_temp.SumValue > 0 then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                    break
			    end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, best_max_card_value, 4)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

		--出王炸
		if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
			if best_hand_card_weight.SumValue > 20 then
				robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
				best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
				robot:PutOutCardList(hand_card_data, best_card_group_data)
				return hand_card_data.OutputCardType
            end
		end

		return hand_card_data.OutputCardType
    elseif card_group_data.Type == robot.NetType_ThreeTwo then

		local best_hand_card_weight = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
		best_hand_card_weight.NeedRound = best_hand_card_weight.NeedRound + 1
		local best_max_card_value = -1
		local tmp_1 = 0
		local passed = true
        for _card_value1 = card_group_data.MaxCard + 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value1] == 3 then
                for _card_value2 = 1, robot.Card_Num_2_13, 1 do
                    if hand_card_data.CardValueList[_card_value2] > 1 and _card_value1 ~= _card_value2 then
                        hand_card_data.CardValueList[_card_value1] = hand_card_data.CardValueList[_card_value1] - 3
            			hand_card_data.CardValueList[_card_value2] = hand_card_data.CardValueList[_card_value2] - 2
            			hand_card_data.HandCardCount = hand_card_data.HandCardCount - 5
            			local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                        hand_card_data.CardValueList[_card_value1] = hand_card_data.CardValueList[_card_value1] + 3
            			hand_card_data.CardValueList[_card_value2] = hand_card_data.CardValueList[_card_value2] + 2
            			hand_card_data.HandCardCount = hand_card_data.HandCardCount + 5

                        --  //选取总权值-轮次*7值最高的策略  因为我们认为剩余的手牌需要n次控手的机会才能出完，若轮次牌型很大（如炸弹） 则其-7的价值也会为正
            			if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) <= (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
            				best_hand_card_weight = hand_card_weight_temp
            				best_max_card_value = _card_value1
            				tmp_1 = _card_value2
            				passed = false
                        end
                    end
                end
            end
        end


		if not passed then
			robot:UpdateGroupData(best_card_group_data, robot.NetType_ThreeTwo, best_max_card_value, 5)
			best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, tmp_1)
            table.insert(best_card_group_data.CardValueList, tmp_1)
			robot:PutOutCardList(hand_card_data, best_card_group_data)
			return hand_card_data.OutputCardType
		end

        for _card_value = 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4
                if hand_card_weight_temp.SumValue > 0 then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                    break
			    end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, best_max_card_value, 4)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

		--出王炸
		if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
			if best_hand_card_weight.SumValue > 20 then
				robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
				best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
				robot:PutOutCardList(hand_card_data, best_card_group_data)
				return hand_card_data.OutputCardType
            end
		end

		return hand_card_data.OutputCardType
    elseif card_group_data.Type == robot.NetType_Single then
        local best_hand_card_weight = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
		best_hand_card_weight.NeedRound = best_hand_card_weight.NeedRound + 1
		local best_max_card_value = -1
		local best_start_card_value = -1
		local best_end_card_value = -1
		local passed = true
		local prov = 0
		local start_i = 0
		local end_i = 0
		local length = card_group_data.Count
        for _card_value_1 = card_group_data.MaxCard - length + 2, robot.Card_Num_A, 1 do
            if hand_card_data.CardValueList[_card_value_1] > 0 then
                prov = prov + 1
            else
                prov = 0
            end
            if prov >= length then
                start_i = _card_value_1 - length + 1
                end_i = _card_value_1
                for index = start_i, end_i, 1 do
                    hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] - 1
                end
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - card_group_data.Count
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                for index = start_i, end_i, 1 do
                    hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] + 1
                end
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + card_group_data.Count
				if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) <= (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
					best_hand_card_weight = hand_card_weight_temp
					best_max_card_value = end_i
					best_start_card_value = start_i
					best_end_card_value = end_i
					passed = false
				end
            end
        end

        if not passed then
			robot:UpdateGroupData(best_card_group_data, robot.NetType_Single, best_max_card_value, card_group_data.Count)
			best_card_group_data.CardValueList = {}
            for _card_value_2 = best_start_card_value, best_end_card_value, 1 do
                table.insert(best_card_group_data.CardValueList, _card_value_2)
            end
			robot:PutOutCardList(hand_card_data, best_card_group_data)
			return hand_card_data.OutputCardType
		end

        for _card_value = 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4
                if hand_card_weight_temp.SumValue > 0 then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                    break
			    end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, best_max_card_value, 4)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

		--出王炸
		if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
			if best_hand_card_weight.SumValue > 20 then
				robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
				best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
				robot:PutOutCardList(hand_card_data, best_card_group_data)
				return hand_card_data.OutputCardType
            end
		end
		return hand_card_data.OutputCardType
    elseif card_group_data.Type == robot.NetType_DoubleSingle then
        local best_hand_card_weight = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
		best_hand_card_weight.NeedRound = best_hand_card_weight.NeedRound + 1
		local best_max_card_value = -1
		local best_start_card_value = -1
		local best_end_card_value = -1
		local passed = true
		local prov = 0
		local start_i = 0
		local end_i = 0
		local length = card_group_data.Count / 2
        for _card_value_1 = card_group_data.MaxCard - length + 2, robot.Card_Num_A, 1 do
            if hand_card_data.CardValueList[_card_value_1] > 1 then
                prov = prov + 1
            else
                prov = 0
            end
            if prov >= length then
                start_i = _card_value_1 - length + 1
                end_i = _card_value_1
                for index = start_i, end_i, 1 do
                    hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] - 2
                end
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - card_group_data.Count
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                for index = start_i, end_i, 1 do
                    hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] + 2
                end
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + card_group_data.Count
				if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) <= (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
					best_hand_card_weight = hand_card_weight_temp
					best_max_card_value = end_i
					best_start_card_value = start_i
					best_end_card_value = end_i
					passed = false
				end
            end
        end

        if not passed then
			robot:UpdateGroupData(best_card_group_data, robot.NetType_DoubleSingle, best_max_card_value, card_group_data.Count)
			best_card_group_data.CardValueList = {}
            for _card_value_2 = best_start_card_value, best_end_card_value, 1 do
                table.insert(best_card_group_data.CardValueList, _card_value_2)
                table.insert(best_card_group_data.CardValueList, _card_value_2)
            end
			robot:PutOutCardList(hand_card_data, best_card_group_data)
			return hand_card_data.OutputCardType
		end

        for _card_value = 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4
                if hand_card_weight_temp.SumValue > 0 then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                    break
			    end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, best_max_card_value, 4)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

		--出王炸
		if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
			if best_hand_card_weight.SumValue > 20 then
				robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
				best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
				robot:PutOutCardList(hand_card_data, best_card_group_data)
				return hand_card_data.OutputCardType
            end
		end
		return hand_card_data.OutputCardType
    elseif card_group_data.Type == robot.NetType_Plane then
		local best_hand_card_weight = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
		best_hand_card_weight.NeedRound = best_hand_card_weight.NeedRound  + 1
		local best_max_card_value = -1
		local  best_start_card_value = -1
		local  best_end_card_value = -1
		local  passed = true
		local  prov = 0
		local  start_i = 0
		local  end_i = 0
		local  length = card_group_data.Count / 3

        for _card_value_1 = card_group_data.MaxCard - length + 2, robot.Card_Num_A, 1 do
            if hand_card_data.CardValueList[_card_value_1] > 2 then
                prov = prov + 1
            else
                prov = 0
            end

            if prov >= length then
				start_i = _card_value_1 - length + 1
                end_i = _card_value_1
                for index = start_i, end_i, 1 do
                    hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] - 3
                end
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - card_group_data.Count
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                for index = start_i, end_i, 1 do
                    hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] + 3
                end
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + card_group_data.Count
                if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) <= (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
					best_hand_card_weight = hand_card_weight_temp
					best_max_card_value = end_i
					best_start_card_value = start_i
					best_end_card_value = end_i
					passed = false
				end
            end
        end

		if not passed then
			robot:UpdateGroupData(best_card_group_data, robot.NetType_Plane, best_max_card_value, card_group_data.Count)
			best_card_group_data.CardValueList = {}
            for _card_value_2 = best_start_card_value, best_end_card_value, 1 do
                table.insert(best_card_group_data.CardValueList, _card_value_2)
                table.insert(best_card_group_data.CardValueList, _card_value_2)
                table.insert(best_card_group_data.CardValueList, _card_value_2)
            end
			robot:PutOutCardList(hand_card_data, best_card_group_data)
			return hand_card_data.OutputCardType
		end

        for _card_value = 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4
                if hand_card_weight_temp.SumValue > 0 then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                    break
			    end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, best_max_card_value, 4)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

		--出王炸
		if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
			if best_hand_card_weight.SumValue > 20 then
				robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
				best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
				robot:PutOutCardList(hand_card_data, best_card_group_data)
				return hand_card_data.OutputCardType
            end
		end
		return hand_card_data.OutputCardType
    elseif card_group_data.Type == robot.NetType_PlaneOne then
		local best_hand_card_weight = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
		best_hand_card_weight.NeedRound = best_hand_card_weight.NeedRound + 1
        local best_max_card_value = -1
		local best_end_card_value = -1
		local best_start_card_value = -1
		local prov = 0
		local start_i = 0
		local end_i = 0
		local length = card_group_data.Count / 4

		local tmp1 = 0
		local tmp2 = 0
		local tmp3 = 0
		local tmp4 = 0
		local passed = true
        for _card_value_1 = card_group_data.MaxCard - length + 2, robot.Card_Num_A, 1 do
            if hand_card_data.CardValueList[_card_value_1] > 2 then
				prov = prov + 1
			else
				prov = 0
            end

            if prov >= length then
                end_i = _card_value_1
				start_i = _card_value_1 - length + 1
                for index = start_i, end_i, 1 do
                    hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] - 3
                end
				hand_card_data.HandCardCount = hand_card_data.HandCardCount - card_group_data.Count

                if length == 2 then
                    for _card_value_2 = 1, robot.Card_Num_BJ, 1 do
                        if hand_card_data.CardValueList[_card_value_2] > 0 then
                            hand_card_data.CardValueList[_card_value_2] = hand_card_data.CardValueList[_card_value_2] - 1
                            for _card_value_3 = 1, robot.Card_Num_BJ, 1 do
                                if hand_card_data.CardValueList[_card_value_3] > 0 then
                                    hand_card_data.CardValueList[_card_value_3] = hand_card_data.CardValueList[_card_value_3] - 1
                                    local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                                    hand_card_data.CardValueList[_card_value_3] = hand_card_data.CardValueList[_card_value_3] + 1
                                    if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) < (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
                                        best_hand_card_weight = hand_card_weight_temp
                                        best_end_card_value = end_i
                                        best_max_card_value = end_i
                                        best_start_card_value = start_i
                                        tmp1 = _card_value_2
                                        tmp2 = _card_value_3
                                        passed = false
                                    end
                                end
                            end
                            hand_card_data.CardValueList[_card_value_2] = hand_card_data.CardValueList[_card_value_2] + 1
                        end
                    end
                elseif length == 3 then
                    for _card_value_2 = 1, robot.Card_Num_BJ, 1 do
                        if hand_card_data.CardValueList[_card_value_2] > 0 then
                            hand_card_data.CardValueList[_card_value_2] = hand_card_data.CardValueList[_card_value_2] - 1

                            for _card_value_3 = 1, robot.Card_Num_BJ, 1 do
                                if hand_card_data.CardValueList[_card_value_3] > 0 then
                                    hand_card_data.CardValueList[_card_value_3] = hand_card_data.CardValueList[_card_value_3] - 1
                                    
                                    for _card_value_4 = 1, robot.Card_Num_BJ, 1 do
                                        if hand_card_data.CardValueList[_card_value_4] > 0 then
                                            hand_card_data.CardValueList[_card_value_4] = hand_card_data.CardValueList[_card_value_4] - 1
                                            local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                                            hand_card_data.CardValueList[_card_value_4] = hand_card_data.CardValueList[_card_value_4] + 1
                                            if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) < (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
												best_hand_card_weight = hand_card_weight_temp
												best_end_card_value = end_i
												best_max_card_value = end_i
												best_start_card_value = start_i
												tmp1 = _card_value_2
												tmp2 = _card_value_3
												tmp3 = _card_value_4
												passed = false
											end
                                        end
                                    end
                                    hand_card_data.CardValueList[_card_value_3] = hand_card_data.CardValueList[_card_value_3] + 1
                                end
                            end
                            hand_card_data.CardValueList[_card_value_2] = hand_card_data.CardValueList[_card_value_2] + 1
                        end
                    end
                elseif length == 4 then
                    for _card_value_2 = 1, robot.Card_Num_BJ, 1 do
                        if hand_card_data.CardValueList[_card_value_2] > 0 then
                            hand_card_data.CardValueList[_card_value_2] = hand_card_data.CardValueList[_card_value_2] - 1
                            for _card_value_3 = 1, robot.Card_Num_BJ, 1 do
                                if hand_card_data.CardValueList[_card_value_3] > 0 then
                                    hand_card_data.CardValueList[_card_value_3] = hand_card_data.CardValueList[_card_value_3] - 1
                                    for _card_value_4 = 1, robot.Card_Num_BJ, 1 do
                                        if hand_card_data.CardValueList[_card_value_4] > 0 then
                                            hand_card_data.CardValueList[_card_value_4] = hand_card_data.CardValueList[_card_value_4] - 1
                                            for _card_value_5 = 1, robot.Card_Num_BJ, 1 do
                                                if hand_card_data.CardValueList[_card_value_5] > 0 then
                                                    hand_card_data.CardValueList[_card_value_5] = hand_card_data.CardValueList[_card_value_5] - 1
                                                    local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                                                    hand_card_data.CardValueList[_card_value_5] = hand_card_data.CardValueList[_card_value_5] + 1
                                                    if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) < (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
														best_hand_card_weight = hand_card_weight_temp
														best_end_card_value = end_i
														best_max_card_value = end_i
														best_start_card_value = start_i
														tmp1 = _card_value_2
														tmp2 = _card_value_3
														tmp3 = _card_value_4
														tmp4 = _card_value_5
														passed = false
													end
                                                end
                                            end
                                            hand_card_data.CardValueList[_card_value_4] = hand_card_data.CardValueList[_card_value_4] + 1
                                        end
                                    end
                                    hand_card_data.CardValueList[_card_value_3] = hand_card_data.CardValueList[_card_value_3] + 1
                                end
                            end
                            hand_card_data.CardValueList[_card_value_2] = hand_card_data.CardValueList[_card_value_2] + 1
                        end
                    end
                end

                for index = start_i, end_i, 1 do
                    hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] + 3
                end
				hand_card_data.HandCardCount = hand_card_data.HandCardCount + card_group_data.Count
            end
        end

		if not passed then
			robot:UpdateGroupData(best_card_group_data, robot.NetType_PlaneOne, best_max_card_value, card_group_data.Count)
			best_card_group_data.CardValueList = {}
            for _card_value = best_start_card_value, best_end_card_value, 1 do
                table.insert(best_card_group_data.CardValueList, _card_value)
                table.insert(best_card_group_data.CardValueList, _card_value)
                table.insert(best_card_group_data.CardValueList, _card_value)
            end
			if length == 2 then
                table.insert(best_card_group_data.CardValueList, tmp1)
                table.insert(best_card_group_data.CardValueList, tmp2)
			elseif length == 3 then
                table.insert(best_card_group_data.CardValueList, tmp1)
                table.insert(best_card_group_data.CardValueList, tmp2)
                table.insert(best_card_group_data.CardValueList, tmp3)
			elseif length == 4 then
				table.insert(best_card_group_data.CardValueList, tmp1)
                table.insert(best_card_group_data.CardValueList, tmp2)
                table.insert(best_card_group_data.CardValueList, tmp3)
                table.insert(best_card_group_data.CardValueList, tmp4)
            end
			robot:PutOutCardList(hand_card_data, best_card_group_data)
			return hand_card_data.OutputCardType
		end

        for _card_value = 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4
                if hand_card_weight_temp.SumValue > 0 then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                    break
			    end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, best_max_card_value, 4)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

		--出王炸
		if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
			if best_hand_card_weight.SumValue > 20 then
				robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
				best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
				robot:PutOutCardList(hand_card_data, best_card_group_data)
				return hand_card_data.OutputCardType
            end
		end
		return hand_card_data.OutputCardType
    elseif card_group_data.Type == robot.NetType_PlaneTwo then
        local best_hand_card_weight = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
		best_hand_card_weight.NeedRound = best_hand_card_weight.NeedRound + 1
		local best_max_card_value = -1
		local best_start_card_value = -1
		local best_end_card_value = -1
		local prov = 0
		local start_i = 0
		local end_i = 0
		local length = card_group_data.Count / 5

		local tmp1 = 0
		local tmp2 = 0
		local tmp3 = 0
		local tmp4 = 0
		local passed = true

        for _card_value_1 = card_group_data.MaxCard - length + 2, robot.Card_Num_A, 1 do
            if hand_card_data.CardValueList[_card_value_1] > 2 then
				prov = prov + 1
			else
				prov = 0
            end

            if prov >= length then
                end_i = _card_value_1
				start_i = _card_value_1 - length + 1
                for index = start_i, end_i, 1 do
                    hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] - 3
                end
				hand_card_data.HandCardCount = hand_card_data.HandCardCount - card_group_data.Count

                if length == 2 then
                    for _card_value_2 = 1, robot.Card_Num_2_13, 1 do
                        if hand_card_data.CardValueList[_card_value_2] > 1 then
                            hand_card_data.CardValueList[_card_value_2] = hand_card_data.CardValueList[_card_value_2] - 2
                            for _card_value_3 = 1, robot.Card_Num_2_13, 1 do
                                if hand_card_data.CardValueList[_card_value_3] > 1 then
                                    hand_card_data.CardValueList[_card_value_3] = hand_card_data.CardValueList[_card_value_3] - 2
                                    local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                                    hand_card_data.CardValueList[_card_value_3] = hand_card_data.CardValueList[_card_value_3] + 2
                                    if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) < (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
                                        best_hand_card_weight = hand_card_weight_temp
                                        best_end_card_value = end_i
                                        best_max_card_value = end_i
                                        best_start_card_value = start_i
                                        tmp1 = _card_value_2
                                        tmp2 = _card_value_3
                                        passed = false
                                    end
                                end
                            end
                            hand_card_data.CardValueList[_card_value_2] = hand_card_data.CardValueList[_card_value_2] + 2
                        end
                    end
                elseif length == 3 then
                    for _card_value_2 = 1, robot.Card_Num_2_13, 1 do
                        if hand_card_data.CardValueList[_card_value_2] > 1 then
                            hand_card_data.CardValueList[_card_value_2] = hand_card_data.CardValueList[_card_value_2] - 2

                            for _card_value_3 = 1, robot.Card_Num_2_13, 1 do
                                if hand_card_data.CardValueList[_card_value_3] > 1 then
                                    hand_card_data.CardValueList[_card_value_3] = hand_card_data.CardValueList[_card_value_3] - 2
                                    
                                    for _card_value_4 = 1, robot.Card_Num_2_13, 1 do
                                        if hand_card_data.CardValueList[_card_value_4] > 1 then
                                            hand_card_data.CardValueList[_card_value_4] = hand_card_data.CardValueList[_card_value_4] - 2
                                            local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                                            hand_card_data.CardValueList[_card_value_4] = hand_card_data.CardValueList[_card_value_4] + 2
                                            if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) < (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
												best_hand_card_weight = hand_card_weight_temp
												best_end_card_value = end_i
												best_max_card_value = end_i
												best_start_card_value = start_i
												tmp1 = _card_value_2
												tmp2 = _card_value_3
												tmp3 = _card_value_4
												passed = false
											end
                                        end
                                    end
                                    hand_card_data.CardValueList[_card_value_3] = hand_card_data.CardValueList[_card_value_3] + 2
                                end
                            end
                            hand_card_data.CardValueList[_card_value_2] = hand_card_data.CardValueList[_card_value_2] + 2
                        end
                    end
                elseif length == 4 then
                    for _card_value_2 = 1, robot.Card_Num_2_13, 1 do
                        if hand_card_data.CardValueList[_card_value_2] > 1 then
                            hand_card_data.CardValueList[_card_value_2] = hand_card_data.CardValueList[_card_value_2] - 2
                            for _card_value_3 = 1, robot.Card_Num_2_13, 1 do
                                if hand_card_data.CardValueList[_card_value_3] > 1 then
                                    hand_card_data.CardValueList[_card_value_3] = hand_card_data.CardValueList[_card_value_3] - 2
                                    for _card_value_4 = 1, robot.Card_Num_2_13, 1 do
                                        if hand_card_data.CardValueList[_card_value_4] > 1 then
                                            hand_card_data.CardValueList[_card_value_4] = hand_card_data.CardValueList[_card_value_4] - 2
                                            for _card_value_5 = 1, robot.Card_Num_2_13, 1 do
                                                if hand_card_data.CardValueList[_card_value_5] > 1 then
                                                    hand_card_data.CardValueList[_card_value_5] = hand_card_data.CardValueList[_card_value_5] - 2
                                                    local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                                                    hand_card_data.CardValueList[_card_value_5] = hand_card_data.CardValueList[_card_value_5] + 2
                                                    if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) < (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
														best_hand_card_weight = hand_card_weight_temp
														best_end_card_value = end_i
														best_max_card_value = end_i
														best_start_card_value = start_i
														tmp1 = _card_value_2
														tmp2 = _card_value_3
														tmp3 = _card_value_4
														tmp4 = _card_value_5
														passed = false
													end
                                                end
                                            end
                                            hand_card_data.CardValueList[_card_value_4] = hand_card_data.CardValueList[_card_value_4] + 2
                                        end
                                    end
                                    hand_card_data.CardValueList[_card_value_3] = hand_card_data.CardValueList[_card_value_3] + 2
                                end
                            end
                            hand_card_data.CardValueList[_card_value_2] = hand_card_data.CardValueList[_card_value_2] + 2
                        end
                    end
                end

                for index = start_i, end_i, 1 do
                    hand_card_data.CardValueList[index] = hand_card_data.CardValueList[index] + 3
                end
				hand_card_data.HandCardCount = hand_card_data.HandCardCount + card_group_data.Count
            end
        end

        if not passed then
			robot:UpdateGroupData(best_card_group_data, robot.NetType_PlaneOne, best_max_card_value, card_group_data.Count)
			best_card_group_data.CardValueList = {}
            for _card_value = best_start_card_value, best_end_card_value, 1 do
                table.insert(best_card_group_data.CardValueList, _card_value)
                table.insert(best_card_group_data.CardValueList, _card_value)
                table.insert(best_card_group_data.CardValueList, _card_value)
            end
			if length == 2 then
                table.insert(best_card_group_data.CardValueList, tmp1)
                table.insert(best_card_group_data.CardValueList, tmp1)
                table.insert(best_card_group_data.CardValueList, tmp2)
                table.insert(best_card_group_data.CardValueList, tmp2)
			elseif length == 3 then
                table.insert(best_card_group_data.CardValueList, tmp1)
                table.insert(best_card_group_data.CardValueList, tmp1)
                table.insert(best_card_group_data.CardValueList, tmp2)
                table.insert(best_card_group_data.CardValueList, tmp2)
                table.insert(best_card_group_data.CardValueList, tmp3)
                table.insert(best_card_group_data.CardValueList, tmp3)
			elseif length == 4 then
				table.insert(best_card_group_data.CardValueList, tmp1)
                table.insert(best_card_group_data.CardValueList, tmp1)
                table.insert(best_card_group_data.CardValueList, tmp2)
                table.insert(best_card_group_data.CardValueList, tmp2)
                table.insert(best_card_group_data.CardValueList, tmp3)
                table.insert(best_card_group_data.CardValueList, tmp3)
                table.insert(best_card_group_data.CardValueList, tmp4)
                table.insert(best_card_group_data.CardValueList, tmp4)
            end
			robot:PutOutCardList(hand_card_data, best_card_group_data)
			return hand_card_data.OutputCardType
		end

        for _card_value = 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4
                if hand_card_weight_temp.SumValue > 0 then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                    break
			    end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, best_max_card_value, 4)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

		--出王炸
		if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
			if best_hand_card_weight.SumValue > 20 then
				robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
				best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
				robot:PutOutCardList(hand_card_data, best_card_group_data)
				return hand_card_data.OutputCardType
            end
		end
		return hand_card_data.OutputCardType
    elseif card_group_data.Type == robot.NetType_FourTwo then
        local best_hand_card_weight = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
		best_hand_card_weight.NeedRound = best_hand_card_weight.NeedRound + 1
		local best_max_card_value = -1
		local tmp_1 = 0
		local tmp_2 = 0
		local passed = true
        for _card_value1 = card_group_data.MaxCard + 1, robot.Card_Num_2_13, 1 do
			if hand_card_data.CardValueList[_card_value1] == 4 then
                hand_card_data.CardValueList[_card_value1] = hand_card_data.CardValueList[_card_value1] - 4
                for _card_value2 = 1, robot.Card_Num_BJ, 1 do
                    if hand_card_data.CardValueList[_card_value2] > 0 then
                        hand_card_data.CardValueList[_card_value2] = hand_card_data.CardValueList[_card_value2] - 1
                        for _card_value3 = _card_value2, robot.Card_Num_BJ, 1 do
                            if hand_card_data.CardValueList[_card_value3] > 0 then
                                hand_card_data.CardValueList[_card_value3] = hand_card_data.CardValueList[_card_value3] - 1
                                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 6
                                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                                hand_card_data.CardValueList[_card_value3] = hand_card_data.CardValueList[_card_value3] + 1
                                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 6
                                if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) < (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
                                    best_hand_card_weight = hand_card_weight_temp
                                    best_max_card_value = _card_value1
                                    tmp_1 = _card_value2
                                    tmp_2 = _card_value3
                                    passed = false
                                end
                            end
                        end
    
                        hand_card_data.CardValueList[_card_value2] = hand_card_data.CardValueList[_card_value2] + 1
                    end
                end
                hand_card_data.CardValueList[_card_value1] = hand_card_data.CardValueList[_card_value1] + 4
            end

		end


        if not passed then
			robot:UpdateGroupData(best_card_group_data, robot.NetType_FourTwo, best_max_card_value, 8)
			best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)

            table.insert(best_card_group_data.CardValueList, tmp_1)
            table.insert(best_card_group_data.CardValueList, tmp_2)
			robot:PutOutCardList(hand_card_data, best_card_group_data)
			return hand_card_data.OutputCardType
		end

        for _card_value = 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4
                if hand_card_weight_temp.SumValue > 0 then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                    break
			    end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, best_max_card_value, 4)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

		--出王炸
		if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
			if best_hand_card_weight.SumValue > 20 then
				robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
				best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
				robot:PutOutCardList(hand_card_data, best_card_group_data)
				return hand_card_data.OutputCardType
            end
		end
		return hand_card_data.OutputCardType
    elseif card_group_data.Type == robot.NetType_FourFour then
        local best_hand_card_weight = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
		best_hand_card_weight.NeedRound = best_hand_card_weight.NeedRound + 1
		local best_max_card_value = -1
		local tmp_1 = 0
		local tmp_2 = 0
		local passed = true

        if best_hand_card_weight.SumValue > 14 then
            for _card_value = 1, robot.Card_Num_2_13, 1 do
				if hand_card_data.CardValueList[_card_value] == 4 then
                    robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, _card_value, 4)
                    best_card_group_data.CardValueList = {}
                    table.insert(best_card_group_data.CardValueList, _card_value)
                    table.insert(best_card_group_data.CardValueList, _card_value)
                    table.insert(best_card_group_data.CardValueList, _card_value)
                    table.insert(best_card_group_data.CardValueList, _card_value)
                    robot:PutOutCardList(hand_card_data, best_card_group_data)
                    return hand_card_data.OutputCardType
                end
			end

			-- //出王炸
			if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
				robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
				best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
				robot:PutOutCardList(hand_card_data, best_card_group_data)
				return hand_card_data.OutputCardType
			end
		end

        for _card_value1 = card_group_data.MaxCard + 1, robot.Card_Num_2_13, 1 do
			if hand_card_data.CardValueList[_card_value1] == 4 then
                hand_card_data.CardValueList[_card_value1] = hand_card_data.CardValueList[_card_value1] - 4
                for _card_value2 = 1, robot.Card_Num_2_13, 1 do
                    if hand_card_data.CardValueList[_card_value2] > 1 then
                        hand_card_data.CardValueList[_card_value2] = hand_card_data.CardValueList[_card_value2] - 2
                        for _card_value3 = _card_value2 + 1, robot.Card_Num_2_13, 1 do
                            if hand_card_data.CardValueList[_card_value3] > 1 then
                                hand_card_data.CardValueList[_card_value3] = hand_card_data.CardValueList[_card_value3] - 2
                                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 8
                                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                                hand_card_data.CardValueList[_card_value3] = hand_card_data.CardValueList[_card_value3] + 2
                                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 8
                                if (best_hand_card_weight.SumValue - (best_hand_card_weight.NeedRound * 7)) < (hand_card_weight_temp.SumValue - (hand_card_weight_temp.NeedRound * 7)) then
                                    best_hand_card_weight = hand_card_weight_temp
                                    best_max_card_value = _card_value1
                                    tmp_1 = _card_value2
                                    tmp_2 = _card_value3
                                    passed = false
                                end
                            end
                        end
                        hand_card_data.CardValueList[_card_value2] = hand_card_data.CardValueList[_card_value2] + 2
                    end
                end
                hand_card_data.CardValueList[_card_value1] = hand_card_data.CardValueList[_card_value1] + 4
            end
		end

        if not passed then
			robot:UpdateGroupData(best_card_group_data, robot.NetType_FourFour, best_max_card_value, 8)
			best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)

            table.insert(best_card_group_data.CardValueList, tmp_1)
            table.insert(best_card_group_data.CardValueList, tmp_1)
            table.insert(best_card_group_data.CardValueList, tmp_2)
            table.insert(best_card_group_data.CardValueList, tmp_2)
			robot:PutOutCardList(hand_card_data, best_card_group_data)
			return hand_card_data.OutputCardType
		end

        for _card_value = 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] - 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount - 4
                local hand_card_weight_temp = self:GetSimplifyHandCardWeight(hand_card_data, debugData)
                hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 4
                hand_card_data.HandCardCount = hand_card_data.HandCardCount + 4
                if hand_card_weight_temp.SumValue > 0 then
                    best_hand_card_weight = hand_card_weight_temp
                    best_max_card_value = _card_value
                    passed = false
                    break
			    end
            end
        end

        if not passed then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, best_max_card_value, 4)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            table.insert(best_card_group_data.CardValueList, best_max_card_value)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
        end

		--出王炸
		if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
			if best_hand_card_weight.SumValue > 20 then
				robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
				best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
                table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
				robot:PutOutCardList(hand_card_data, best_card_group_data)
				return hand_card_data.OutputCardType
            end
		end
		return hand_card_data.OutputCardType
    elseif card_group_data.Type == robot.NetType_Bomb4 then
        for _card_value = card_group_data.MaxCard + 1, robot.Card_Num_2_13, 1 do
            if hand_card_data.CardValueList[_card_value] == 4 then
                robot:UpdateGroupData(best_card_group_data, robot.NetType_Bomb4, _card_value, 4)
                best_card_group_data.CardValueList = {}
                table.insert(best_card_group_data.CardValueList, _card_value)
                table.insert(best_card_group_data.CardValueList, _card_value)
                table.insert(best_card_group_data.CardValueList, _card_value)
                table.insert(best_card_group_data.CardValueList, _card_value)
                robot:PutOutCardList(hand_card_data, best_card_group_data)
                return hand_card_data.OutputCardType
            end
        end

        --出王炸
		if hand_card_data.CardValueList[robot.Card_Num_BJ] > 0 and hand_card_data.CardValueList[robot.Card_Num_SJ] > 0 then
            robot:UpdateGroupData(best_card_group_data, robot.NetType_Rocket, robot.Card_Num_BJ, 2)
            best_card_group_data.CardValueList = {}
            table.insert(best_card_group_data.CardValueList, robot.Card_Num_BJ)
            table.insert(best_card_group_data.CardValueList, robot.Card_Num_SJ)
            robot:PutOutCardList(hand_card_data, best_card_group_data)
            return hand_card_data.OutputCardType
		end

        return hand_card_data.OutputCardType
    elseif card_group_data.Type == robot.NetType_Rocket then
        return hand_card_data.OutputCardType
    end

    robot:PutOutCardList(hand_card_data, best_card_group_data)
	return hand_card_data.OutputCardType
end


-- //地主剩一张牌，在我下手：  除非队友出牌足够大，否则尽量用大牌跟； （只针对单张；其他牌型除非我都是对子，只有一张单牌）,本次出的是单张
function M:AIFellowtOut1(card_out_group, roomData)
    if robot:NextIsTeammate(roomData) or robot:GetNextCardCount(roomData) ~= 1 then
        return nil, false
    end

    if card_out_group.Type ~= robot.NetType_One then
        return nil, false
    end

    --如果是地主
    if roomData.pList[roomData.index].isLandlord then
        return nil, false
    end

    local jipaiqiList = robot:CardsToCardValueList(roomData.pList[roomData.index].jipaiqi)

    -- 	//记牌器
	local firend_max_is_max_card = true
	local poker_record_max_card_value = -1
	local poker_record_jocker_num = 0

    for _card_value, _count in pairs(jipaiqiList) do
        if _count > 0  then
            if _card_value >= robot.Card_Num_SJ then
                poker_record_jocker_num = poker_record_jocker_num + 1
            end

            if _card_value > card_out_group.MaxCard then
                firend_max_is_max_card = false
            end

            if _card_value > poker_record_max_card_value then
    			poker_record_max_card_value = _card_value
    		end
        end
    end

    if robot:IsTeammateById(roomData.lastPlayerId, roomData) and firend_max_is_max_card then
        return nil, true
    end

    local max_card_value = 0
    local cardValueList = robot:CardsToCardValueList(roomData.pList[roomData.index].leftCards)
    for _card_value, _card_count in pairs(cardValueList) do
        if _card_count == 1 then
             if max_card_value < _card_value then
                 max_card_value = _card_value
             end
        end
    end

    if max_card_value >= poker_record_max_card_value and max_card_value > card_out_group.MaxCard then
        local outCards = {}
        outCards.Type = robot.NetType_One
        outCards.MaxCard = max_card_value
        outCards.Count = 1
        outCards.CardValueList = {}
        table.insert(outCards.CardValueList, max_card_value)
        return outCards, false
    end

    local chai_max_card_value = -1
    for _card_value, _card_count in pairs(cardValueList) do
        if _card_count >= 2 and _card_count < 4 then
            if _card_value > chai_max_card_value then
                chai_max_card_value = _card_value
            end
        end
    end


    if chai_max_card_value > max_card_value then
        max_card_value = chai_max_card_value
    end

    if max_card_value >= poker_record_max_card_value and max_card_value > card_out_group.MaxCard then
        local outCards = {}
        outCards.Type = robot.NetType_One
        outCards.MaxCard = max_card_value
        outCards.Count = 1
        outCards.CardValueList = {}
        table.insert(outCards.CardValueList, max_card_value)
        return outCards, false
    end

    for _card_value, _card_count in pairs(cardValueList) do
        if _card_count == 4 then
            local outCards = {}
            outCards.Type = robot.NetType_Bomb4
            outCards.MaxCard = _card_value
            outCards.Count = 4
            outCards.CardValueList = {}
            table.insert(outCards.CardValueList, _card_value)
            table.insert(outCards.CardValueList, _card_value)
            table.insert(outCards.CardValueList, _card_value)
            table.insert(outCards.CardValueList, _card_value)
            return outCards, false
        end
    end

    if poker_record_jocker_num > 1 then
        local outCards = {}
        outCards.Type = robot.NetType_Rocket
        outCards.MaxCard = robot.Card_Num_BJ
        outCards.Count = 2
        outCards.CardValueList = {}
        table.insert(outCards.CardValueList, robot.Card_Num_BJ)
        table.insert(outCards.CardValueList, robot.Card_Num_SJ)
		return outCards, false
	end

    if max_card_value > card_out_group.MaxCard then
        local outCards = {}
        outCards.Type = robot.NetType_One
        outCards.MaxCard = max_card_value
        outCards.Count = 1
        outCards.CardValueList = {}
        table.insert(outCards.CardValueList, max_card_value)
		return outCards, false
	end
	return nil, false
end

function M:AIFellowtOut2(card_out_group, out_card_group, next_out_card_group_list, roomData)
    -- robot:pTable("length=", #next_out_card_group_list,"next_out_card_group_list=", next_out_card_group_list)
    if out_card_group.Count == robot:GetCardCountByIndex(roomData.index, roomData) then
        return out_card_group
    end

    local shouNum = #next_out_card_group_list
    if shouNum <= 3 then
        local leftNum = roomData.pList[roomData.index].leftCardNum
        local _leftNumTemp = 0
        for key, _out_data in pairs(next_out_card_group_list) do
            _leftNumTemp = _leftNumTemp + _out_data.Count
        end

        if leftNum ~= _leftNumTemp then
            return nil
        end

        local left_card_value_list = robot:CardsToCardValueList(roomData.pList[roomData.index].leftCards)
        local card_value_list = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
        for _card_value, _count in pairs(left_card_value_list) do
            if _count > 0 then
                card_value_list[_card_value] = (card_value_list[_card_value] or 0) + _count
            end
        end

        for _card_value1, _ in pairs(card_value_list) do
            if card_value_list[_card_value1] == 4 then
                local bomb_card_value1 = 0
                local bomb_card_value2 = 0
                local bomb_card_value3 = 0
                local prov = 0
                for _card_value2 = _card_value1, robot.Card_Num_A, 1 do
                    if card_value_list[_card_value2] == 4 then
                        prov = prov + 1
                        if bomb_card_value1 == 0 then
                            bomb_card_value1 = _card_value2
                        elseif bomb_card_value2 == 0 then
                            bomb_card_value2 = _card_value2
                        elseif bomb_card_value3 == 0 then
                            bomb_card_value3 = _card_value2
                        end
                    else
                        break
                    end
                end

                if true or leftNum == prov * 4 then
                    if prov == 2 then --2连炸
                        if card_out_group.Type < robot.NetType_Bomb4 or 
                            (card_out_group.Type == robot.NetType_Bomb4 and card_out_group.Count < 8) or 
                            (card_out_group.Type == robot.NetType_Bomb4 and card_out_group.Count == 8 and card_out_group.MaxCard < bomb_card_value2) then
                            local outCards = {}
                            outCards.Type = robot.NetType_Bomb4
                            outCards.MaxCard = bomb_card_value2
                            outCards.Count = prov * 4
                            outCards.CardValueList = {}
                            table.insert(outCards.CardValueList, bomb_card_value1)
                            table.insert(outCards.CardValueList, bomb_card_value1)
                            table.insert(outCards.CardValueList, bomb_card_value1)
                            table.insert(outCards.CardValueList, bomb_card_value1)
                            table.insert(outCards.CardValueList, bomb_card_value2)
                            table.insert(outCards.CardValueList, bomb_card_value2)
                            table.insert(outCards.CardValueList, bomb_card_value2)
                            table.insert(outCards.CardValueList, bomb_card_value2)
                            return outCards
                        end
                    elseif prov == 3 then --3连炸
                        if card_out_group.Type < robot.NetType_Bomb4 or 
                        (card_out_group.Type == robot.NetType_Bomb4 and card_out_group.Count < 12) or 
                        (card_out_group.Type == robot.NetType_Bomb4 and card_out_group.Count == 12 and card_out_group.MaxCard < bomb_card_value3) then
                            local outCards = {}
                            outCards.Type = robot.NetType_Bomb4
                            outCards.MaxCard = bomb_card_value3
                            outCards.Count = prov * 4
                            outCards.CardValueList = {}
                            table.insert(outCards.CardValueList, bomb_card_value1)
                            table.insert(outCards.CardValueList, bomb_card_value1)
                            table.insert(outCards.CardValueList, bomb_card_value1)
                            table.insert(outCards.CardValueList, bomb_card_value1)
                            table.insert(outCards.CardValueList, bomb_card_value2)
                            table.insert(outCards.CardValueList, bomb_card_value2)
                            table.insert(outCards.CardValueList, bomb_card_value2)
                            table.insert(outCards.CardValueList, bomb_card_value2)
                            table.insert(outCards.CardValueList, bomb_card_value3)
                            table.insert(outCards.CardValueList, bomb_card_value3)
                            table.insert(outCards.CardValueList, bomb_card_value3)
                            table.insert(outCards.CardValueList, bomb_card_value3)
                            return outCards
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- //地主剩一张牌，在我下手：除非队友出牌足够大，否则尽量用大牌跟； （只针对单张；其他牌型除非我都是对子，只有一张单牌）,本次出的不是单张
function M:AIFellowtOut3(card_out_group, next_out_card_group_list, roomData)
    if robot:NextIsTeammate(roomData) or robot:GetNextCardCount(roomData) ~= 1 then
        return false
    end

    if card_out_group.Type == robot.NetType_One then
        return false
    end

    local jipaiqiList = robot:CardsToCardValueList(roomData.pList[roomData.index].jipaiqi)

    -- 	//记牌器
    local single_card_value_list = {}
    if #next_out_card_group_list > 0 then
        for _, _out_card_group in pairs(next_out_card_group_list) do
            if _out_card_group == robot.NetType_One then
                table.insert(single_card_value_list, _out_card_group.MaxCard)
            end
        end
    end

    if #single_card_value_list > 0 then
        local check_small_single_count = 0
        for _, _card_value1 in pairs(single_card_value_list) do
            for _card_value2, _count in pairs(jipaiqiList) do
                if _count > 0  then
                    if _card_value1 < _card_value2 then
                        check_small_single_count = check_small_single_count + 1
                    end
                end
            end
        end

        if check_small_single_count > 1 then
            return true
        end
    end

    return false
end

-- //地主剩一张牌，在我上手：队友出其他牌型，除非我跟牌后都是非单张牌型，且只有一张以下小于记牌器的单牌才跟牌，否则不跟；
function M:AIFellowtOut3_2(card_out_group, next_out_card_group_list, roomData)
    if robot:GetLandlordCardCount(roomData) ~= 1 or not robot:NextIsTeammate(roomData) then
        return false
    end

    if card_out_group.Type == robot.NetType_One then
        return false
    end

    local jipaiqiList = robot:CardsToCardValueList(roomData.pList[roomData.index].jipaiqi)
    local have_max_card_group = {}
    if #next_out_card_group_list > 0 then
        for _, _out_card_group in pairs(next_out_card_group_list) do

			if (_out_card_group.Type == card_out_group.Type and _out_card_group.Count == card_out_group.Count and _out_card_group.MaxCard > card_out_group.MaxCard) or
				(_out_card_group.Type >= robot.NetType_Bomb4 and _out_card_group.Type > card_out_group.Type) then
                    have_max_card_group.Count = _out_card_group.Count
                    have_max_card_group.MaxCard = _out_card_group.MaxCard
                    have_max_card_group.Type = _out_card_group.Type
                    have_max_card_group.Value = _out_card_group.Value
                    have_max_card_group.CardValueList = {}
                    table.insertto(have_max_card_group.CardValueList, _out_card_group.CardValueList)
                    break
				break
            end
		end
    end

    if not have_max_card_group.Type or have_max_card_group.Type == robot.NetType_Null then
        return true
    end

	local single_count = 0
	local min_single_card_value1 = 100
    local min_single_card_value2 = 100
	for _, _out_card_group in pairs(next_out_card_group_list) do
		if _out_card_group.Type == robot.NetType_One then
			single_count =single_count + 1
			if single_count >= 2 and min_single_card_value1 > _out_card_group.MaxCard then
				min_single_card_value1 = _out_card_group.MaxCard
                if min_single_card_value2 ~= min_single_card_value1 then
                    min_single_card_value2 = min_single_card_value1
                end
            end
		end
	end

    local min_count = 0
	if single_count > 1 then
        for _card_value, _count in pairs(jipaiqiList) do
			if _count > 0 then
                if _card_value > min_single_card_value1 then
                   min_count = min_count + 1
                elseif _card_value > min_single_card_value2 then
                    min_count = min_count + 2
                end
                if min_count >= 2 then
                    break
                end
            end
		end
	end

    if min_count >= 2 then
        return true
    end

	return false


end

-- //队友下手，且只有一张牌，我有＜10的牌：  和记牌器比有绝对大牌（顺子,连对, 飞机不比较），出最大的牌，如需带牌则带倒数第二大的单张或对子；否则正常算法跟牌；
function M:AIFellowtOut4(card_out_group, roomData)
    if robot:NextIsTeammate(roomData) or robot:GetNextCardCount(roomData) ~= 1 then
        return nil
    end

    if card_out_group.Type == robot.NetType_Rocket then
        return nil
    end

	local small_card_value = -1
	local small_not_chai_three_card_value = -1
	local max_bomb_card_value = -1
	local max_dan_card_value = -1
	local max_duizi_card_value = -1
	local max_three_card_value = -1
    local cardValueList = robot:CardsToCardValueList(roomData.pList[roomData.index].leftCards)
    for _card_value, _count in pairs(cardValueList) do
        if _count > 0 then
    		if small_not_chai_three_card_value == -1 or small_not_chai_three_card_value > _card_value then
    			small_not_chai_three_card_value = _card_value
    		end

    		if _count < 3 then
    			if small_card_value == -1 or small_card_value < _card_value then
    				small_card_value = _card_value
    			end
    		end

    		if _count == 1 then
    			if max_dan_card_value == -1 or max_dan_card_value < _card_value then
    				max_dan_card_value = _card_value
    			end
    		end

    		if _count == 2 then
    			if max_duizi_card_value == -1 or max_duizi_card_value < _card_value then
    				max_duizi_card_value = _card_value
    			end
    		end

    		if _count == 3 then
    			if max_three_card_value == -1 or max_three_card_value < _card_value then
    				max_three_card_value = _card_value
    			end
    		end

    		if _count == 4 then
    			if max_bomb_card_value < _card_value then
    				max_bomb_card_value = _card_value
    			end
    		end
        end
    end

	if small_not_chai_three_card_value >= robot.Card_Num_10 then
		return nil
    end

	if card_out_group.Type == robot.NetType_Bomb4 and card_out_group.MaxCard > max_bomb_card_value then
		return nil
    end

    local jipaiqiList = robot:CardsToCardValueList(roomData.pList[roomData.index].jipaiqi)

	local poker_record_max_bomb_card_value = -1
	local poker_record_max_three_card_value = -1
	local poker_record_max_duizi_card_value = -1
	local poker_record_max_dan_card_value = -1
    for _card_value, _count in pairs(jipaiqiList) do
		if _count > 0 then
            if _count >= 1 then
                if poker_record_max_duizi_card_value < _card_value then
                    poker_record_max_duizi_card_value = _card_value
                end
            end

            if _count >= 2 then
                if poker_record_max_duizi_card_value < _card_value then
                    poker_record_max_duizi_card_value = _card_value
                end
            end

            if _count >= 3 then
                if poker_record_max_three_card_value < _card_value then
                    poker_record_max_three_card_value = _card_value
                end
            end

            if _count == 4 then
                if poker_record_max_bomb_card_value < _card_value then
                    poker_record_max_bomb_card_value = _card_value
                end
            end
        end
	end

	-- //是否有最大炸弹
	if max_bomb_card_value > poker_record_max_bomb_card_value then
        local outCards = {}
        outCards.Type = robot.NetType_Bomb4
        outCards.MaxCard = max_bomb_card_value
        outCards.Count = 4
        outCards.CardValueList = {}
        table.insert(outCards.CardValueList, max_bomb_card_value)
        table.insert(outCards.CardValueList, max_bomb_card_value)
        table.insert(outCards.CardValueList, max_bomb_card_value)
        table.insert(outCards.CardValueList, max_bomb_card_value)
		return outCards
	end

	if poker_record_max_bomb_card_value > 0 then
		return nil
	end

	if card_out_group.Type == robot.NetType_One then
		if max_dan_card_value >= poker_record_max_dan_card_value and max_dan_card_value > card_out_group.MaxCard then
            local outCards = {}
            outCards.Type = card_out_group.Type
            outCards.MaxCard = max_dan_card_value
            outCards.Count = 1
            outCards.CardValueList = {}
            table.insert(outCards.CardValueList, max_dan_card_value)
			return outCards
        end
		return nil
	elseif card_out_group.Type == robot.NetType_Two then
		if max_duizi_card_value >= poker_record_max_duizi_card_value and max_duizi_card_value > card_out_group.MaxCard then
            local outCards = {}
            outCards.Type = card_out_group.Type
            outCards.MaxCard = max_duizi_card_value
            outCards.Count = 2
            outCards.CardValueList = {}
            table.insert(outCards.CardValueList, max_duizi_card_value)
            table.insert(outCards.CardValueList, max_duizi_card_value)

			return outCards
        end
		return nil
    elseif card_out_group.Type == robot.NetType_Three then
        if max_three_card_value >= poker_record_max_three_card_value and max_three_card_value > card_out_group.MaxCard then
            local outCards = {}
            outCards.Type = card_out_group.Type
            outCards.MaxCard = max_three_card_value
            outCards.Count = 3
            outCards.CardValueList = {}
            table.insert(outCards.CardValueList, max_three_card_value)
            table.insert(outCards.CardValueList, max_three_card_value)
            table.insert(outCards.CardValueList, max_three_card_value)
            return outCards
        end
        return nil
    elseif card_out_group.Type == robot.NetType_ThreeOne then
		if max_three_card_value >= poker_record_max_three_card_value and max_three_card_value > card_out_group.MaxCard then
            local tmp_Val = {}
            for _card_value, _count in pairs(cardValueList) do
                tmp_Val[_card_value] = _count
            end
            if tmp_Val[max_three_card_value] then
                tmp_Val[max_three_card_value] = tmp_Val[max_three_card_value] - 3
            end

			if small_card_value == max_three_card_value then
				if small_not_chai_three_card_value ~= -1 then
					tmp_Val[small_not_chai_three_card_value] = tmp_Val[small_not_chai_three_card_value] - 1
                end
			else
				if max_three_card_value ~= -1 then
					tmp_Val[max_three_card_value] = tmp_Val[max_three_card_value] - 1
                end
			end

			local dai_card_value = -1
            for _card_value, _count in pairs(tmp_Val) do
				if _count > 0 then
                    if dai_card_value == -1 or dai_card_value > _card_value then
                        dai_card_value = _card_value
                    end
                end
			end

            local outCards = {}
            outCards.Type = card_out_group.Type
            outCards.MaxCard = max_three_card_value
            outCards.Count = 4
            outCards.CardValueList = {}
            table.insert(outCards.CardValueList, max_three_card_value)
            table.insert(outCards.CardValueList, max_three_card_value)
            table.insert(outCards.CardValueList, max_three_card_value)
            table.insert(outCards.CardValueList, dai_card_value)
            return outCards
		end
		return nil
    elseif card_out_group.Type == robot.NetType_ThreeTwo then
        if max_three_card_value >= poker_record_max_three_card_value and max_three_card_value > card_out_group.MaxCard then
            local tmp_Val = {}
            for _card_value, _count in pairs(cardValueList) do
                tmp_Val[_card_value] = _count
            end
            if tmp_Val[max_three_card_value] then
                tmp_Val[max_three_card_value] = tmp_Val[max_three_card_value] - 3
            end

            if small_card_value == max_three_card_value then
                if small_not_chai_three_card_value ~= -1 then
                    tmp_Val[small_not_chai_three_card_value] = tmp_Val[small_not_chai_three_card_value] - 1
                end
            else 
                if max_three_card_value ~= -1 then
                    tmp_Val[max_three_card_value] = tmp_Val[max_three_card_value] - 1
                end
            end

            local dai_card_value = -1
            for _card_value, _count in pairs(tmp_Val) do
                if _count >= 2 then
                    if dai_card_value == -1 or dai_card_value > _card_value then
                        dai_card_value = _card_value
                    end
                end
            end

            local outCards = {}
            outCards.Type = card_out_group.Type
            outCards.MaxCard = max_three_card_value
            outCards.Count = 5
            outCards.CardValueList = {}
            table.insert(outCards.CardValueList, max_three_card_value)
            table.insert(outCards.CardValueList, max_three_card_value)
            table.insert(outCards.CardValueList, max_three_card_value)
            table.insert(outCards.CardValueList, dai_card_value)
            table.insert(outCards.CardValueList, dai_card_value)
            return outCards
        end
        return nil
	end
    return nil
end

-- //农民剩1张牌，我是地主：单张跟绝对大单，或炸弹，否则从大到小跟；
function M:AIFellowtOut5(card_out_group, roomData)
    if not roomData.pList[roomData.index].isLandlord then
        return nil
    end

    if robot:GetPreCardCount(roomData) ~= 1 and robot:GetNextCardCount(roomData) ~= 1 then
        return nil
    end

    if card_out_group.Type ~= robot.NetType_One then
        return nil
    end
    local out_max_card_value = card_out_group.MaxCard

	local max_bomb_card_value = -1
	local max_dan_card_value = -1
	local max_chai_dan_card_value = -1

    local cardValueList = robot:CardsToCardValueList(roomData.pList[roomData.index].leftCards)
    for _card_value, _count in pairs(cardValueList) do
        if _count > 0 then
            if _count == 1 then
                if not (cardValueList[robot.Card_Num_SJ] and cardValueList[robot.Card_Num_SJ] > 0 and
                    cardValueList[robot.Card_Num_BJ] and cardValueList[robot.Card_Num_BJ] > 0 and _card_value >= robot.Card_Num_SJ)then
                    if max_dan_card_value == -1 or max_dan_card_value < _card_value then
                        max_dan_card_value = _card_value
                    end
                end
            end

            if _count == 1 or _count == 2 or _count == 3 then
                if max_chai_dan_card_value == -1 or max_chai_dan_card_value < _card_value then
                    max_chai_dan_card_value = _card_value
                end
            end

            if _count == 4 then
                if max_bomb_card_value < _card_value then
                    max_bomb_card_value = _card_value
                end
            end
        end
    end

    local jipaiqiList = robot:CardsToCardValueList(roomData.pList[roomData.index].jipaiqi)

    -- 	//记录记牌器最大的炸弹等牌
	local poker_record_max_bomb_card_value = -1
	local poker_record_max_dan_card_value = -1
    for _card_value, _count in pairs(jipaiqiList) do
		if _count > 0 then
            if poker_record_max_dan_card_value < _card_value then
                poker_record_max_dan_card_value = _card_value
            end

            if _count == 4 then
                if poker_record_max_bomb_card_value < _card_value then
                    poker_record_max_bomb_card_value = _card_value
                end
            end
		end
	end

    --有绝对大单跟单张
	if max_dan_card_value > out_max_card_value and max_dan_card_value >= poker_record_max_dan_card_value then
        local outCards = {}
        outCards.Type = card_out_group.NetType_One
        outCards.MaxCard = max_dan_card_value
        outCards.CardValueList = {}
        table.insert(outCards.CardValueList, max_dan_card_value)
        outCards.Count = #outCards.CardValueList
        return outCards
	end

-- 	//有最大炸弹,跟炸弹
	if max_bomb_card_value > poker_record_max_bomb_card_value then
        local outCards = {}
        outCards.Type = card_out_group.NetType_Bomb4
        outCards.MaxCard = max_bomb_card_value
        outCards.CardValueList = {}
        table.insert(outCards.CardValueList, max_bomb_card_value)
        table.insert(outCards.CardValueList, max_bomb_card_value)
        table.insert(outCards.CardValueList, max_bomb_card_value)
        table.insert(outCards.CardValueList, max_bomb_card_value)
        outCards.Count = #outCards.CardValueList
        return outCards
    end

    if cardValueList[robot.Card_Num_SJ] and cardValueList[robot.Card_Num_SJ] > 0 and
        cardValueList[robot.Card_Num_BJ] and cardValueList[robot.Card_Num_BJ] > 0 then
        local outCards = {}
        outCards.Type = card_out_group.NetType_Rocket
        outCards.MaxCard = max_bomb_card_value
        outCards.CardValueList = {}
        table.insert(outCards.CardValueList, robot.Card_Num_BJ)
        table.insert(outCards.CardValueList, robot.Card_Num_SJ)
        outCards.Count = #outCards.CardValueList
        return outCards
    end
end

-- //如果是队友的牌：  小牌跟，大牌不跟；（大牌：牌分值≥0；小牌：牌分值＜0）
function M:AIDefaultFellowtOut5(card_out_group, current_card_out_group, roomData)
    -- print("AIDefaultFellowtOut5---------start")
    if not robot:IsTeammateById(roomData.lastPlayerId, roomData) then
        return false
    end

	local card_weight = robot:GetCardWeight(card_out_group.Type, card_out_group.MaxCard)
    -- print("AIDefaultFellowtOut5---------card_weight=", card_weight)
	if card_weight >= 0 then
		return true
    end

	if current_card_out_group.Type and current_card_out_group.Type >= robot.NetType_Bomb4 then
		return true
    end

	return false

end


-- //如果是地主的牌：跟牌是顺子、飞机、连对这类，跟
-- //如果是地主的牌：我要动用炸弹，如果他的牌还有很多，出的又不是王和2之类，不跟；（牌数≥10）
-- //如果是地主的牌：他的牌很少，跟。（牌数≤10）
function M:AIDefaultFellowtOut6(card_out_group, current_out_group, roomData)
    if not robot:IsLandlorderById(roomData.lastPlayerId, roomData) then
        return false
    end

	if card_out_group.Type == robot.NetType_FourTwo or card_out_group.Type == robot.NetType_FourTwo or card_out_group.Type == robot.NetType_Single or
		card_out_group.Type == robot.NetType_DoubleSingle or card_out_group.Type == robot.NetType_Plane or card_out_group.Type == robot.NetType_PlaneOne or
		card_out_group.Type == robot.NetType_PlaneTwo or card_out_group.Type == robot.NetType_FourFour or card_out_group.Type == robot.NetType_Bomb4 then
		return false
    end

-- 	//如果是地主的牌：我要动用炸弹，如果他的牌还有很多，出的又不是王和2之类，不跟；（牌数≥10）
	if current_out_group.Type == robot.NetType_Bomb4 and (robot:GetLandlordCardCount(roomData) > 15 and card_out_group.MaxCard < robot.Card_Num_10) then
		return true
    end

	return false

end

function M:FollowForceOut(last_out_card_group, roomData)
    if robot:IsTeammateById(roomData.lastPlayerId, roomData) then
        return nil
    end

    if robot:GetCardCountById(roomData.lastPlayerId, roomData) > 10 then
        return nil
    end

    local cardValueList = robot:CardsToCardValueList(roomData.pList[roomData.index].leftCards)
    for _card_value, _count in pairs(cardValueList) do
        if _count == 4 then
    		if (last_out_card_group.Type == robot.NetType_Bomb4 and _card_value > last_out_card_group.MaxCard) or
    			last_out_card_group.Type < robot.NetType_Bomb4 then
                local outCards = {}
                outCards.Type = robot.NetType_Bomb4
                outCards.MaxCard = _card_value
                outCards.CardValueList = {}
                table.insert(outCards.CardValueList, robot._card_value)
                table.insert(outCards.CardValueList, robot._card_value)
                table.insert(outCards.CardValueList, robot._card_value)
                table.insert(outCards.CardValueList, robot._card_value)
                outCards.Count = #outCards.CardValueList
                return outCards
    		end
        end
    end
    return nil
end

function M:CheckFollowOver(out_card_group, roomData)
	if out_card_group ~= nil and out_card_group.Type ~= robot.NetType_Null then
		if out_card_group.Count == robot:GetCardCountByIndex(roomData.index) then
			return true
        end
	end
	return false
end

function M:FollowOutCard(roomData)
    local passed = true
	local hand_card_data = {}
	hand_card_data.CardValueList = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	hand_card_data.HandCardCount = 0
    if not roomData then
        robot:print(0, 0, "【Follow_0】:FollowOutCard:roomData is nil")
        return passed
    end

    local cPlayer = roomData.pList[roomData.index]
    if not cPlayer then
        robot:print(0, roomData.lastPlayerId,"【Follow_1】:FollowOutCard:cPlayer is nil")
        return passed
    end
    robot:InitMap()
    local _cardValueList = robot:CardArrayToCard54(cPlayer.leftCards)
    for _, _card_value in pairs(_cardValueList) do
        hand_card_data.HandCardCount = hand_card_data.HandCardCount + 1
        hand_card_data.CardValueList[_card_value] = hand_card_data.CardValueList[_card_value] + 1
    end

    local out = {}
    -- print("robotAi:FollowOutCard:lastPlayerCardObj=", robot:pTable(roomData.lastPlayerCard))
	local last_out_card_group = self:TransCardData(roomData.lastPlayerCard)
    if not last_out_card_group then
        robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_2】:FollowOutCard:last_out_card_group is nil, lastPlayerCard=", robot:pTable(roomData.lastPlayerCard))    
        passed = true
        return passed
    end
    -- print("robotAi:FollowOutCard:last_out_card_group=", robot:pTable(last_out_card_group))
    local _need_passed = false
    -- 	//地主剩一张牌，在我下手：  除非队友出牌足够大，否则尽量用大牌跟； （只针对单张；其他牌型除非我都是对子，只有一张单牌）,本次出的是单张
    out, _need_passed = self:AIFellowtOut1(last_out_card_group, roomData)
    if _need_passed then
        passed = true
        if out then
            robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_3】:FollowOutCard::AIFellowtOut1:passed=", passed, ", out=", robot:pTable(out))
        else
            robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_4】:FollowOutCard::AIFellowtOut1:passed=", passed, ", out is nil")
        end
        return passed, out
    elseif out then
        passed = false
        robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_5】:FollowOutCard::AIFellowtOut1:passed=", passed, ", out=", robot:pTable(out))
        return passed, out
    end

	local beginAt = os.time()
    robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_6】:FollowOutCard:last_out_card_group=", robot:pTable(last_out_card_group), ", hand_card_data=", robot:pTable(hand_card_data))
    local debugData = {num=0, numLimit=100000}
	local out_card_group = self:PassiveOutCard(last_out_card_group, hand_card_data, debugData)
	local endAt = os.time()
    robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_7】:FollowOutCard::FollowOutCard:consumeTime=<", endAt-beginAt, ">毫秒, out_card_group=", robot:pTable(out_card_group), 
        "--------", "debugData=", robot:pTable(debugData))
	if out_card_group and out_card_group.Type == robot.NetType_Null then
		passed = true
		local force_out = self:FollowForceOut(last_out_card_group, roomData)
		if force_out and force_out.Returntype ~= robot.NetType_Null then
			passed = false
			return force_out, passed
        end
		return passed, out
	end

    local next_out_card_group_list = robot:FirstOutCard(_cardValueList)
-- 	//算出手牌最佳组合模式，至少N-1手大于记牌器的牌组，其中一手大于上家的牌组可以压住当前牌： 则跟牌。
	out = self:AIFellowtOut2(last_out_card_group, out_card_group, next_out_card_group_list, roomData)
	if out and out.Type ~= robot.NetType_Null then
		passed = false
        if out then
            robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_61】:FollowOutCard::AIFellowtOut2:passed=", passed, ", out=", robot:pTable(out))
        else
            robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_71】:FollowOutCard::AIFellowtOut2:passed=", passed, ", out is nil")
        end
        return passed, out
	end

    if not robot:IsLandlorderById(roomData.lastPlayerId, roomData) then
        --地主剩一张牌，在我下手：  除非队友出牌足够大，否则尽量用大牌跟； （只针对单张；其他牌型除非我都是对子，只有一张单牌）,本次出的不是单张
		_need_passed = self:AIFellowtOut3(last_out_card_group, next_out_card_group_list, roomData)
		if _need_passed then
			passed = true
			if out then
                robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_8】:FollowOutCard::AIFellowtOut3:passed=", passed, ", out=", robot:pTable(out))
			else
                robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_9】:FollowOutCard::AIFellowtOut3:passed=", passed, ", out is nil")
            end
			return passed, out
		end

        --地主剩一张牌，在我上手：队友出其他牌型，除非我跟牌后都是非单张牌型，且只有一张以下小于记牌器的单牌才跟牌，否则不跟；
		_need_passed = self:AIFellowtOut3_2(last_out_card_group, next_out_card_group_list, roomData)
		if _need_passed then
			passed = true
			if out then
                robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_10】:FollowOutCard::AIFellowtOut3_2:passed=", passed, ", out=", robot:pTable(out))
			else
                robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_11】:FollowOutCard::AIFellowtOut3_2:passed=", passed, ", out is nil")
            end
			return passed, out
		end
    end

    -- 	//队友下手，且只有一张牌，我有＜10的牌：  和记牌器比有绝对大牌（顺子,连对, 飞机不比较），出最大的牌，如需带牌则带倒数第二大的单张或对子；否则正常算法跟牌；
	out = self:AIFellowtOut4(last_out_card_group, roomData)
	if out and out.Type ~= robot.NetType_Null then
		passed = false
        if out then
            robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_12】:FollowOutCard::AIFellowtOut4:passed=", passed, ", out=", robot:pTable(out))
        else
            robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_13】:FollowOutCard::AIFellowtOut4:passed=", passed, ", out is nil")
        end
        return passed, out
	end

    -- 	//农民剩1张牌，我是地主：单张跟绝对大单，或炸弹，否则从大到小跟；
	out = self:AIFellowtOut5(last_out_card_group, roomData)
	if out and out.Returntype ~= robot.NetType_Null then
		passed = false
        if out then
            robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_14】:FollowOutCard::AIFellowtOut5:passed=", passed, ", out=", robot:pTable(out))
        else
            robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_15】:FollowOutCard::AIFellowtOut5:passed=", passed, ", out is nil")
        end
        return passed, out
	end


-- 	//兜底策略
-- 	//如果是队友的牌, 不使用炸弹：  小牌跟，大牌不跟；（大牌：牌分值≥0；小牌：牌分值＜0）
	_need_passed = self:AIDefaultFellowtOut5(last_out_card_group, out_card_group, roomData)
	if _need_passed then
		passed = true
        if out then
            robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_16】:FollowOutCard::AIDefaultFellowtOut5:passed=", passed, ", out=", robot:pTable(out))
        else
            robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_17】:FollowOutCard::AIDefaultFellowtOut5:passed=", passed, ", out is nil")
        end
        return passed, out
	end

    -- 	//如果是地主的牌：跟牌是顺子、飞机、连对这类，跟
-- 	//如果是地主的牌：我要动用炸弹，如果他的牌还有很多，出的又不是王和2之类，不跟；（牌数≥10）
-- 	//如果是地主的牌：他的牌很少，跟。（牌数≤10）
	_need_passed = self:AIDefaultFellowtOut6(last_out_card_group, out_card_group, roomData)
	if _need_passed then
		passed = true
        if out then
            robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_18】:FollowOutCard::AIDefaultFellowtOut6:passed=", passed, ", out=", robot:pTable(out))
        else
            robot:print(cPlayer.id, roomData.lastPlayerId,"【Follow_19】:FollowOutCard::AIDefaultFellowtOut6:passed=", passed, ", out is nil")
        end
        return passed, out
	end

    passed = true
    if out_card_group and out_card_group.Type and out_card_group.Type ~= robot.NetType_Null then
        passed = false
    end
    robot:print(cPlayer.id, roomData.lastPlayerId, "【Follow_20】:FollowOutCard::AIDefaultFellowtOut6:passed=", passed, ", out=", robot:pTable(out_card_group))
	return passed, out_card_group

end

--out_data= {playedcards={cards={1=19, 2=67, 3=35, 4=51, }, weight=515, type=zhadan, }, pass=false, }
function M:FollowOutCardEx(roomData)
    local pass, outData
    xpcall(function (...) 
                pass, outData =  self:FollowOutCard(roomData)
            end,
            function ()
                local cPlayer = roomData.pList[roomData.index]
                local id = 0
                if cPlayer then
                    id = cPlayer.id
                end
                self:print(id, roomData.lastPlayerId, "【first_xpcall】:roomData=", M:pTable(roomData), "traceback=", debug.traceback())
            end,
    roomData)

    if pass == nil then
        return nil
    end

    local outCardData = {}
    outCardData.pass = pass

    local cPlayer = roomData.pList[roomData.index]
    if not cPlayer then
        outCardData.pass = true
        robot:print(0, roomData.lastPlayerId, "【Follow】FollowOutCardEx0:cPlayer is nil, outCardData=", robot:pTable(outCardData), ", error!!!!!!!!!!!!!!!!")
        return outCardData
    end

    if outCardData.pass then
        robot:print(cPlayer.id, roomData.lastPlayerId, "【Follow】FollowOutCardEx1:outData=", robot:pTable(outData), ", outCardData=", robot:pTable(outCardData))
        return outCardData
    end

    if outData and outData.Type ~= robot.NetType_Null then
        local outCardArray = robot:Card54ToCardArray(outData.CardValueList, cPlayer.leftCards)
        -- local outCardData = {}
        ---- weight={cards={1=51, 2=19, 3=67, }, type=tuple, subtype=tuple, weight=3, }, }
        outCardData.playedcards = util.parseCardTypeOnly(outCardArray)
        if outCardData.playedcards and next(outCardData.playedcards) then
            robot:print(cPlayer.id, roomData.lastPlayerId, "【Follow】FollowOutCardEx2:outCardData=", robot:pTable(outCardData), ", cardArray=", robot:pTable(cPlayer.leftCards))
            return outCardData
        end
    end

    robot:print(cPlayer.id, roomData.lastPlayerId, "【Follow】FollowOutCardEx3:outData=", robot:pTable(outData), ", outCardData=", robot:pTable(outCardData), "")
    return nil
end

function M:TransCardData(data)
    local cardValueMap, cardValueList, count = robot:CardArrayToCard54Map(data.cards)
    if data.type == "dan" then
        local last_out_card_group = {}
        last_out_card_group.Type = robot.NetType_One
        last_out_card_group.CardValueList = cardValueList
        last_out_card_group.Count = count
        if last_out_card_group.Count > 0 then
            for _card_value, _count in pairs(cardValueMap) do
                if _count >= 1 then
                    last_out_card_group.MaxCard = _card_value
                    break
                end
            end
            return last_out_card_group
        end
    elseif data.type == "dui" then
        local last_out_card_group = {}
        last_out_card_group.Type = robot.NetType_Two
        last_out_card_group.CardValueList = cardValueList
        last_out_card_group.Count = count
        if last_out_card_group.Count > 0 then
            for _card_value, _count in pairs(cardValueMap) do
                if _count >= 2 then
                    last_out_card_group.MaxCard = _card_value
                    break
                end
            end
            return last_out_card_group
        end
    elseif data.type == "tuple"  then
        local last_out_card_group = {}
        last_out_card_group.Type = robot.NetType_Three
        last_out_card_group.CardValueList = cardValueList
        last_out_card_group.Count = count
        if last_out_card_group.Count > 0 then
            for _card_value, _count in pairs(cardValueMap) do
                if _count >= 3 then
                    last_out_card_group.MaxCard = _card_value
                    break
                end
            end
            return last_out_card_group
        end
    elseif data.type == "sandaiyi" then
        local last_out_card_group = {}
        last_out_card_group.Type = robot.NetType_ThreeOne
        last_out_card_group.CardValueList = cardValueList
        last_out_card_group.Count = count
        if last_out_card_group.Count > 0 then
            for _card_value, _count in pairs(cardValueMap) do
                if _count >= 3 then
                    last_out_card_group.MaxCard = _card_value
                    break
                end
            end
            return last_out_card_group
        end
    elseif data.type == "sandaiyidui"  then
        local last_out_card_group = {}
        last_out_card_group.Type = robot.NetType_ThreeTwo
        last_out_card_group.CardValueList = cardValueList
        last_out_card_group.Count = count
        if last_out_card_group.Count > 0 then
            for _card_value, _count in pairs(cardValueMap) do
                if _count >= 3 then
                    last_out_card_group.MaxCard = _card_value
                    break
                end
            end
            return last_out_card_group
        end
    elseif data.type == "shunzi" then
        local last_out_card_group = {}
        last_out_card_group.Type = robot.NetType_Single
        last_out_card_group.CardValueList = cardValueList
        last_out_card_group.Count = count
        if last_out_card_group.Count > 0 then
            local max_card_value = 0
            for _card_value, _count in pairs(cardValueMap) do
                if _count > 0 then
                    if _card_value > max_card_value then
                        max_card_value = _card_value
                    end
                end
            end
            last_out_card_group.MaxCard = max_card_value

            return last_out_card_group
        end
    elseif data.type == "liandui" then
        local last_out_card_group = {}
        last_out_card_group.Type = robot.NetType_DoubleSingle
        last_out_card_group.CardValueList = cardValueList
        last_out_card_group.Count = count
        if last_out_card_group.Count > 0 then
            local max_card_value = 0
            for _card_value, _count in pairs(cardValueMap) do
                if _count > 1 then
                    if _card_value > max_card_value then
                        max_card_value = _card_value
                    end
                end
            end
            last_out_card_group.MaxCard = max_card_value

            return last_out_card_group
        end
    elseif data.type == "feiji_budai" then
        local last_out_card_group = {}
        last_out_card_group.Type = robot.NetType_Plane
        last_out_card_group.CardValueList = cardValueList
        last_out_card_group.Count = count
        if last_out_card_group.Count > 0 then
            local max_card_value = 0
            for _card_value, _count in pairs(cardValueMap) do
                if _count >= 3 then
                    if _card_value > max_card_value then
                        max_card_value = _card_value
                    end
                end
            end
            last_out_card_group.MaxCard = max_card_value

            return last_out_card_group
        end
    elseif data.type == "feiji_daidan" then
        local last_out_card_group = {}
        last_out_card_group.Type = robot.NetType_PlaneOne
        last_out_card_group.CardValueList = cardValueList
        last_out_card_group.Count = count
        if last_out_card_group.Count > 0 then
            local max_card_value = 0
            for _card_value, _count in pairs(cardValueMap) do
                if _count >= 3 then
                    if _card_value > max_card_value then
                        max_card_value = _card_value
                    end
                end
            end
            last_out_card_group.MaxCard = max_card_value

            return last_out_card_group
        end
    elseif data.type == "feiji_daidui" then
        local last_out_card_group = {}
        last_out_card_group.Type = robot.NetType_PlaneTwo
        last_out_card_group.CardValueList = cardValueList
        last_out_card_group.Count = count
        if last_out_card_group.Count > 0 then
            local max_card_value = 0
            for _card_value, _count in pairs(cardValueMap) do
                if _count >= 3 then
                    if _card_value > max_card_value then
                        max_card_value = _card_value
                    end
                end
            end
            last_out_card_group.MaxCard = max_card_value

            return last_out_card_group
        end
    elseif data.type == "sidaier" then
        local last_out_card_group = {}
        last_out_card_group.Type = robot.NetType_FourTwo
        last_out_card_group.CardValueList = cardValueList
        last_out_card_group.Count = count
        if last_out_card_group.Count > 0 then
            for _card_value, _count in pairs(cardValueMap) do
                if _count >= 4 then
                    last_out_card_group.MaxCard = _card_value
                    return last_out_card_group
                end
            end
        end
    elseif data.type == "sidailiangdui" then
        local last_out_card_group = {}
        last_out_card_group.Type = robot.NetType_FourFour
        last_out_card_group.CardValueList = cardValueList
        last_out_card_group.Count = count
        if last_out_card_group.Count > 0 then
            for _card_value, _count in pairs(cardValueMap) do
                if _count >= 4 then
                    last_out_card_group.MaxCard = _card_value
                    return last_out_card_group
                end
            end
        end
    elseif data.type == "zhadan"then
        if data.subtype == "wangzha" then
            local last_out_card_group = {}
            last_out_card_group.Type = robot.NetType_Rocket
            last_out_card_group.CardValueList = cardValueList
            last_out_card_group.Count = count
            if last_out_card_group.Count > 0 then
                last_out_card_group.MaxCard = robot.Card_Num_BJ
                return last_out_card_group
            end
        elseif data.subtype == "yingzha" then
            local last_out_card_group = {}
            last_out_card_group.Type = robot.NetType_Bomb4
            last_out_card_group.CardValueList = cardValueList
            last_out_card_group.Count = count
            if last_out_card_group.Count > 0 then
                for _card_value, _count in pairs(cardValueMap) do
                    if _count >= 4 then
                        last_out_card_group.MaxCard = _card_value
                        return last_out_card_group
                    end
                end
            end
        end
    end
    return nil
end

return M