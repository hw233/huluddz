local MjHandle = require "game/tools/MjHandle"
require "config/GameConst"

local M = {}

local function meetThreeNeedJoker(cardsCount,jokerCount)
    local needCount = 0
    local cc = {}
    for k, v in pairs(cardsCount) do
        if k >= 31 and k <= 37 and v % 3 ~= 0 then
            local need = 3 - v % 3
            needCount = needCount + need
        end 
        cc[k] = v
    end

    for i = 1, 29 do
        local v = cc[i]
        if v ~= nil and v > 0 then
            if v >= 3 then v = v - 3 end
            if cc[i + 1] == nil then cc[i + 1] = 0 end
            if cc[i + 2] == nil then cc[i + 2] = 0 end
            if cc[i + 1] < v or cc[i + 2] < v then
                local need = 0
                if v == 1 then
                    if (i + 1) % 10 == 0 then
                        need = 2
                    else
                        if cc[i + 1] == 0 then
                            need = need + 1 
                        end
                        if cc[i + 2] == 0 then
                            need = need + 1
                        end
                    end
                   
                    if (i + 1) % 10 ~= 0 then
                        if cc[i + 1] >= 1 then cc[i + 1] = cc[i + 1] - 1 end
                        if cc[i + 2] >= 1 then cc[i + 2] = cc[i + 2] - 1 end
                    end
                else
                    if cc[i + 1] < v then
                        need = need + v - cc[i + 1]
                    end
                    if cc[i + 2] < v then
                        need = need + v - cc[i + 2] 
                    end
                    local upToThree = false
                    if need > 1 then
                        need = 1
                        upToThree = true
                    end
                   
                    if upToThree == false then
                        if cc[i + 1] > 2 then cc[i + 1] = cc[i + 1] - 2 else cc[i + 1] = 0 end
                        if cc[i + 2] > 2 then cc[i + 2] = cc[i + 2] - 2 else cc[i + 2] = 0 end
                    end
                end
                needCount = needCount + need
            else
                cc[i + 1] = cc[i + 1] - v
                cc[i + 2] = cc[i + 2] - v
            end
            cc[i] = 0
        end
    end
    return needCount
end


local function HuNeedJoker(cards,jokerCount)
    --听手牌中已经有四张的情况
  
    for i=1,30 do
        if cards[i] and cards[i] >= 5 then
            return false
        end
    end

    local lastNeedJoker = 14
    for i = 1, 30 do
        local result = false
        local need = 0
        if cards[i] ~= nil then
            if cards[i] >= 2 then
                cards[i] = cards[i] - 2
                need = meetThreeNeedJoker(cards)
                cards[i] = cards[i] + 2

                if need == 0 then
                    return need
                elseif need < lastNeedJoker then
                    lastNeedJoker = need
                end
            elseif cards[i] > 0  then
                cards[i] = 0
                need = meetThreeNeedJoker(cards)
                cards[i] = 1
                if need+1 < lastNeedJoker then
                    lastNeedJoker = need + 1
                end  
            end
        end
    end

    lastNeedJoker = lastNeedJoker - jokerCount

    print("====debug qc==== HuNeedJoker :",lastNeedJoker)
    table.print(cards)
    return lastNeedJoker

end


-- 求在cards取count数量的id的组合
local function Combination(cards,count)
    print("====debug qc==== Combination cards ids:")
    table.print(cards)
    

    local cardsGroup = {}
    local bitset = {}
    local length = #cards

    local move = function (bitset,num,endIndex)
        for j = 1,num - 1 do
            bitset[j] = 1
        end
        for j = num,endIndex do
            bitset[j] = 0
        end
    end

    local getCards = function (bitset,count)
        local t = {}
        local c = 0
        for j,bit in ipairs(bitset) do
            if bit == 1 then
                c = c + 1
                table.insert(t,cards[j])
            end
            if c == count then
                table.insert(cardsGroup,t)
                break
            end
        end
    end

    for i=1,length do
        if i <= count then
            bitset[i] = 1
        else
            bitset[i] = 0
        end
    end
    getCards(bitset,count)

    while true do
        --local j = 0   -- 每次循环都重新从1开始，查找bitset[]中的“10”对。
        local num = 0 -- 用于统计找到第一个“10”对之前总共出现的“1”的数目。
        local index = length
        for i=1,length - 1 do
            if bitset[i] == 1 then
                num = num + 1
                if bitset[i+1] == 0 then
                    bitset[i] = 0
                    bitset[i+1] = 1
                    move(bitset,num,i)
                    index = i
                    break
                end
            end
        end

        if index < length then
            getCards(bitset,count)
        else
            break
        end
    end

    return cardsGroup
end

local function GetSingleCount(cards)
    local len = #cards
    local isCont = false -- 连续的
    table.sort(cards)
    for i=1,len - 1 do
        if MjHandle:CardsEq(cards[i],cards[i+1]) then
            len = len - (not isCont and 2 or 1)
            isCont = true
        else
            isCont = false
        end
    end
    return len
end



local function GetExchangeCardsComp2021(cards,count)    
    print("====debug qc==== GetExchangeCardsComp cards ids: count",count )
    table.sort(cards)
    table.print(cards)

    --查找补缺卡牌 对cards进行 简单的句子分组 找到count单牌即返回
    --参考字符串模式匹配算法
    local sentence_count =0
    local sentence_cards = {}
    local tmp_1_cards 
    local tmp_2_cards 
    local ret_cards ={}

    local function clearTmp()
        sentence_count = 0
        tmp_1_cards =nil
        tmp_2_cards =nil
    end

    for i,v in ipairs(cards) do
        if not tmp_1_cards then
            tmp_1_cards = v
        elseif v == tmp_1_cards then
            if not tmp_2_cards then
                table.insert(sentence_cards,{tmp_1_cards,tmp_2_cards,v})--刻子
                clearTmp()
            else
                tmp_2_cards = v
            end            
        elseif v == tmp_1_cards + 1 then        
            tmp_2_cards = v
        elseif tmp_2_cards and v == tmp_2_cards + 1 then
            --顺子1句
            table.insert(sentence_cards,{tmp_1_cards,tmp_2_cards,v})
            clearTmp()
        elseif tmp_2_cards then
            table.insert(sentence_cards,{tmp_1_cards,tmp_2_cards})--对子
            clearTmp()
            tmp_1_cards = v
        else
            --v跟 tmp_1_cards 毫无关系
            table.insert(ret_cards,tmp_1_cards)
            tmp_1_cards = v
        end
    end

    --最后一张
    if tmp_1_cards then
        table.insert(ret_cards,tmp_1_cards)
    end


    print("====debug qc==== 匹配拆分牌组 :")
    table.print(sentence_cards)
    table.print(ret_cards)

    if #ret_cards >= count then
        return table.slice(ret_cards,1,count)
    else
        local tmp_ret = table.slice(sentence_cards[1],1,count-#ret_cards)
        table.insert(ret_cards,tmp_ret)
        return ret_cards
    end    
end


local function GetExchangeCardsComp(cards,count)
    
    print("====debug qc==== GetExchangeCardsComp cards ids:")
    table.print(cards)

    local cardsGroup = Combination(cards,count)
    -- print("====debug qc==== cardsGroup cards ids:")
    -- table.print(cardsGroup)

    local maxNeed = 0
    local maxGroup = {}
    for _,ids in ipairs(cardsGroup) do
        local need = HuNeedJoker(MjHandle:CardsCount(ids),0)
       
        if need > maxNeed then
            maxGroup = {ids}
            maxNeed = need
        elseif need == maxNeed then
            table.insert(maxGroup,ids)
        end
    end

    table.sort(maxGroup,function(a,b)
        return GetSingleCount(a) > GetSingleCount(b)
    end)

    table.print(maxGroup)
    return maxGroup[1]
end



--拉取少数花色的牌 排序返回
local function CardsClassify2021(hand,count)
    local cTypes = {}
    count = count or 0
    for _,id in ipairs(hand) do
        local t = MjHandle:GetCardColor(id)
        if t <= DiscardType.Crak then
            cTypes[t] = cTypes[t] or {}
            table.insert(cTypes[t],id)
        end
    end
    
    --颜色排序 低到高
    local colorLen ={}
    for t,cards in pairs(cTypes) do
        colorLen[t] = #cards
    end    
    
    local minCTypes = {}
    
    while count>0 do
        local minColor =0
        local minLen = 99
        for t,cardsLen in pairs(colorLen) do
            if minLen > cardsLen and cardsLen>0 then
                minLen = cardsLen
                minColor = t
            end
        end
        table.insert(minCTypes,minColor)
        colorLen[minColor] = 0
        count = count - minLen
    end

    return cTypes,minCTypes
end


--换三张可异色2021版本
function M:GetExchangeCards2021(hand,count)
    print("====debug qc==== 换三张算法 GetExchangeCards2021:")
    table.print(hand)

    local cTypes,minCTypes = CardsClassify2021(hand,count)

    print("====debug qc==== 换三张算法 minCTypes:")
    table.print(minCTypes)

    local Ids ={}
    local doCards ={}
    local doCount = 0
    local ctypesIdx =0 
    for i,t in ipairs(minCTypes) do
        table.insert(doCards,cTypes[t])
        doCount = doCount + #cTypes[t]
        if doCount >= count then
            break
        else
            ctypesIdx = i    
        end
    end

    --刚好少色 >= 需求数
    --todo 优化  2个少色相当的情况 换3张最优情况 未处理
    if doCount >= count then
        local t1 = {}
        table.expand(doCards,t1)
        print("====debug qc==== 换三张算法 table.expand 同色 ")
        table.print(doCards)
        table.print(t1)
        return table.slice(t1,1,count)
    end

    
    --按排序补数进来
    for i=1,ctypesIdx do
        local h,j = MjHandle:TrsfomIds(doCards[i])
        Ids = table.extend(Ids, h)
    end  
    local Count_2 = count - #Ids
    table.print(Ids)
    print("====debug qc==== 换三张算法 doCards: ctypesIdx" ,ctypesIdx)
    table.print(doCards)
    local h,j = MjHandle:TrsfomIds(doCards[ctypesIdx+1])
    local newIds = GetExchangeCardsComp2021(h,Count_2)
    table.print(newIds)
    Ids = table.extend(Ids, newIds)

    print("====debug qc==== 换三张算法 ids:")
    table.print(Ids)

    local cards = {}
    local exists = {}
    for _,cid in ipairs(hand) do
        if not exists[cid] then
            local v = MjHandle:TrsfomId(cid)
            for i=1,#Ids do
                if v == Ids[i] then
                    table.insert(cards,cid)
                    table.remove(Ids,i)
                    exists[cid] = true
                    break
                end
            end
        end
    end
    return cards
end

local function CardsClassify(hand,count)
    local cTypes = {}
    count = count or 0
    for _,id in ipairs(hand) do
        local t = MjHandle:GetCardColor(id)
        if t <= DiscardType.Crak then
            cTypes[t] = cTypes[t] or {}
            table.insert(cTypes[t],id)
        end
    end

    print("====debug qc==== CardsClassify cTypes:")
    table.print(cTypes)

    local minCTypes = {}
    local minLen = 15 --庄家手牌最大长度15 张
    for t,cards in pairs(cTypes) do
        local len = #cards
        if len >= count then
            if len < minLen then
                minCTypes = {t}
                minLen = len
            elseif len == minLen then
                table.insert(minCTypes,t)
            end
        end
    end

    return cTypes,minCTypes
end


--换三张逻辑
function M:GetExchangeCards(hand,count)
    local cTypes,minCTypes = CardsClassify(hand,count)

    print("====debug qc==== 换三张算法 minCTypes:")
    table.print(minCTypes)

    local len = #minCTypes
    local Ids
    if len == 1 then
        local cards = cTypes[minCTypes[1]]
        if #cards == count then
            return cards
        else
            Ids = GetExchangeCardsComp(MjHandle:TrsfomIds(cards),count)
        end
        print("====debug qc====  ids = 1:")
    else
        local cards1 = MjHandle:TrsfomIds(cTypes[minCTypes[1]])
        local cards2 = MjHandle:TrsfomIds(cTypes[minCTypes[2]])
        local need1 = HuNeedJoker(MjHandle:CardsCount(cards1),0)
        local need2 = HuNeedJoker(MjHandle:CardsCount(cards2),0)
     
        local cards 

        if need1 > need2 then
            cards = cards1
        elseif need1 < need2 then
            cards = cards2
        else 
            if GetSingleCount(cards1) < GetSingleCount(cards2) then
                cards = cards2
            else
                cards = cards1
            end
        end

        Ids = GetExchangeCardsComp(cards,count)
        print("====debug qc====  ids = 2:")
    end

    print("====debug qc==== 换三张算法 ids:")
    table.print(Ids)

    local cards = {}
    local exists = {}
    for _,cid in ipairs(hand) do
        if not exists[cid] then
            local v = MjHandle:TrsfomId(cid)
            for i=1,#Ids do
                if v == Ids[i] then
                    table.insert(cards,cid)
                    table.remove(Ids,i)
                    exists[cid] = true
                    break
                end
            end
        end
    end
    return cards
end

function M:GetDiscardType(hand)
    local cTypes,minCTypes = CardsClassify(hand)

    for k,v in pairs(DiscardType) do
        if v ~= DiscardType.None then
            if not cTypes[v] then

                return v
            end
        end
    end

    if #minCTypes == 1 then

        return minCTypes[1]
    else
        local cards1 = MjHandle:TrsfomIds(cTypes[minCTypes[1]])
        local cards2 = MjHandle:TrsfomIds(cTypes[minCTypes[2]])
        local need1 = HuNeedJoker(MjHandle:CardsCount(cards1),0)
        local need2 = HuNeedJoker(MjHandle:CardsCount(cards2),0)
     
        local cards 

        if need1 > need2 then
            return minCTypes[1]
        elseif need1 < need2 then
            return minCTypes[2]
        else 
            if GetSingleCount(cards1) < GetSingleCount(cards2) then
                return minCTypes[2]
            else
                return minCTypes[1]
            end
        end
    end
end

return M