require "table_util"

local CTYPE = {
    Shunzi = 5,
    Kezi   = 6,
    Jiang  = 0,
}

local function cardsCount(cards)
    local cardsCount = {}
    for k, v in pairs(cards) do cardsCount[v] = (cardsCount[v] or 0) + 1 end
    return cardsCount
end

local function checkMeetThree(cardsCount, laiziCount,huCard)
    local cc = {}
    for k, v in pairs(cardsCount) do
        if k >= 31 and k <= 37 and v % 3 ~= 0 then
            local needLaizi = 3 - v % 3
            if laiziCount < needLaizi then return false end
            laiziCount = laiziCount - needLaizi
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
                local needLaizi = 0
                if v == 1 then
                    if cc[i + 1] == 0 then needLaizi = needLaizi + 1 end
                    if cc[i + 2] == 0 then needLaizi = needLaizi + 1 end
                    if (i + 1) % 10 == 0 then needLaizi = 2 end
                    if needLaizi > laiziCount then return false end
                    laiziCount = laiziCount - needLaizi
                    if (i + 1) % 10 ~= 0 then
                        if cc[i + 1] >= 1 then cc[i + 1] = cc[i + 1] - 1 end
                        if cc[i + 2] >= 1 then cc[i + 2] = cc[i + 2] - 1 end
                    end
                     if i == huCard and needLaizi == 2 then
                        --胡牌必须和其他一张牌靠在一起
                        return false
                    end
                else
                    if cc[i + 1] < v then needLaizi = needLaizi + v - cc[i + 1] end
                    if cc[i + 2] < v then needLaizi = needLaizi + v - cc[i + 2] end
                    local upToThree = false
                    if needLaizi > 1 then
                        needLaizi = 1
                        upToThree = true
                    end
                    if laiziCount < needLaizi then return false end
                    laiziCount = laiziCount - needLaizi
                    if upToThree == false then
                        if cc[i + 1] > 2 then cc[i + 1] = cc[i + 1] - 2 else cc[i + 1] = 0 end
                        if cc[i + 2] > 2 then cc[i + 2] = cc[i + 2] - 2 else cc[i + 2] = 0 end
                    end
                end
            else
                cc[i + 1] = cc[i + 1] - v
                cc[i + 2] = cc[i + 2] - v
            end
            cc[i] = 0
        end
    end
    return true,laiziCount
end

-- huCard -- 癞子 血流时,需要传递.
-- 癞子血流,有癞子胡任意牌时 ,只能胡能组成一句的牌
local function checkHu(cards, laizi,cc,huCard,cardsLen)
    if (cardsLen or #cards) == 0 and laizi == 2 then return true end
    cc = cc or cardsCount(cards or {})

    if laizi == 0 then --排除没有癞子的情况下，听手牌中已经有四张的情况
        for i=1,37 do
            if cc[i] and cc[i] >= 5 then
                return false
            end
        end
    end

    for i = 1, 37 do
        if cc[i] ~= nil and cc[i] > 0 then
            if cc[i] >= 2 then
                cc[i] = cc[i] - 2 
                if checkMeetThree(cc, laizi,huCard) then 
                    cc[i] = cc[i] + 2
                    return true 
                end
                cc[i] = cc[i] + 2
            else
                if laizi > 0 then
                    cc[i] = 0
                    laizi = laizi - 1
                    local r,residueLaizi = checkMeetThree(cc, laizi,huCard)
                    -- if checkMeetThree(cc, laizi,huCard) then return true end
                    if r and (i ~= huCard or residueLaizi > 0) then
                        cc[i] = 1
                        return true
                    end

                    laizi = laizi + 1
                    cc[i] = 1
                end
            end
        end
    end

    if laizi >= 2 then
        laizi = laizi - 2
        if checkMeetThree(cc, laizi,huCard) then return true end
        laizi = laizi + 2
    end

    if laizi > 0 then
        for i = 1, 37 do
            if cc[i] ~= nil and cc[i] > 0 then
                if cc[i] >= 2 then
                    cc[i] = cc[i] - 1
                    laizi = laizi - 1
                    if checkMeetThree(cc, laizi,huCard) then 
                        cc[i] = cc[i] + 2
                        return true 
                    end
                    cc[i] = cc[i] + 1
                    laizi = laizi + 1
                end
            end
        end
    end

    return false
end

local function checkTing(cards, laizi, checkHu,checkQidui)
    local result = {}
    local count = #cards
    for i = 1, 37 do
        if i % 10 ~= 0 then
            cards[count + 1] = i
            if checkHu(cards, laizi) then
                result[#result + 1] = i
            end
            if checkQidui and checkQidui(cards,laizi) then
                result[#result + 1] = i
            end
        end
    end
    cards[count + 1] = nil
    return result
end

-------------------------------------------------------------
local function addBranchs(result,branchs,rJoker)
    local groups = {result}
    if not branchs or #branchs == 0 then
        table.insert(result,1,rJoker)
        return groups
    end

    for _,b in ipairs(branchs) do
        local b1 = b % 10^9 * 9 + b - 3*10^10
        for i=#groups,1,-1 do
            local r = groups[i]
            local clone = table.clone(r)
            table.insert(r,1,b)         --插入首位, 最后为将
            table.insert(clone,1,b1)

            table.insert(groups,clone)
        end
    end

    for _,r in ipairs(groups) do -- 在数组首位标记牌,癞子数
        table.insert(r,1,rJoker)
    end

    return groups
end

local function addBranchsReverse(result,branchs,rJoker)
    local groups = {result}
    if not branchs or #branchs == 0 then
        table.insert(result,1,rJoker)
        return groups
    end

    for _,b in ipairs(branchs) do
        local b1 = b - b % 10^9 / 10 * 9  + 3*10^10
        for i=#groups,1,-1 do
            local r = groups[i]
            local clone = table.clone(r)
            table.insert(r,1,b)         --插入首位, 最后为将
            table.insert(clone,1,b1)

            table.insert(groups,clone)
        end
    end

    for _,r in ipairs(groups) do -- 在数组首位标记牌,癞子数
        table.insert(r,1,rJoker)
    end

    return groups
end

-- 最大获取癞子数
-- 最大刻字统计
local function checkMeetKeziGreed(cardsCount,laiziCount)
    local result = {}
    local cc = {}

    for k, v in pairs(cardsCount) do
        if k >= 31 and k <= 37 and v % 3 ~= 0 then return nil end 
        cc[k] = v
    end

     for i = 1, 29 do
        local v = cc[i]
        if v ~= nil and v > 0 then
            local color = (i//10 + 1) * 10^11
            -- 1     6   000300000
            -- 花色  刻子
            -- -------- 0 将  5 连子 6 刻子
            if v >= 3 then 
                v = v - 3 
                -- table.insert(result, {i, i, i})
                -- // 比 math.ceil 快
                local r = color + CTYPE.Kezi * 10^9
                table.insert(result,r + 3 * 10^(9 - i % 10))
            end

            if v > 0 and v + laiziCount >= 3 then
                local need = 3 - v
                v = 0
                laiziCount = laiziCount - need
                local r = color +  10 ^ (9 - i % 10)
                r = (r - color) * 3 + color + CTYPE.Kezi * 10^9
                r = r + (i%10) * 10^10  -- 癞子 -- 转换数
                table.insert(result,r)
            elseif v > 0 then
                return
            end

        end

    end

    if laiziCount == 3 then
        local i = 31
        local color = (i//10 + 1) * 10^11
        local r = color + 2 * 10^(9 - i % 10)
        table.insert(result,r)
        laiziCount = laiziCount - 3
    end


    return result,nil,laiziCount
end

--获取句子
local function checkMeetThreeCombo(cardsCount, laiziCount,checkOut)
    local result = checkOut and checkOut.result or {}
    local cc = checkOut and checkOut.cc or {}
    local branchs = checkOut and checkOut.branchs or {}
    laiziCount = checkOut and checkOut.laiziCount or laiziCount
    local waitCheckout
    if not checkOut then
        for k, v in pairs(cardsCount) do
            if k >= 31 and k <= 37 and v % 3 ~= 0 then return nil end 
            cc[k] = v
        end
    end
    for i = 1, 29 do
        local v = cc[i]
        if v ~= nil and v > 0 then
            local color = (i//10 + 1) * 10^11
            -- 1     6   000300000
            -- 花色  刻子
            -- -------- 0 将  5 连子 6 刻子
            if v >= 3 then 
                v = v - 3 
                -- table.insert(result, {i, i, i})
                -- // 比 math.ceil 快
                local r = color + CTYPE.Kezi * 10^9
                table.insert(result,r + 3 * 10^(9 - i % 10))
            end
            if cc[i + 1] == nil then cc[i + 1] = 0 end
            if cc[i + 2] == nil then cc[i + 2] = 0 end
            if cc[i + 1] < v or cc[i + 2] < v then
                local needLaizi = 0
                if v == 1 then
                    local r = color +  10 ^ (9 - i % 10)
                    local branch
                    if (i + 1) % 10 == 0 or (cc[i + 1] == cc[i + 2] and cc[i+1] == 0) then 
                        needLaizi = 2 
                        r = (r - color) * 3 + color + CTYPE.Kezi * 10^9
                        r = r + (i%10) * 10^10  -- 癞子 -- 转换数
                        -- branch = r
                    else
                        r = r + CTYPE.Shunzi * 10^9 
                        if cc[i+2] ~= 0 then
                            r = r + 10 ^ (9 - (i+1)%10)
                            r = r + 10 ^ (9 - (i+2)%10)
                            if cc[i+1] == 0 then
                                needLaizi = needLaizi + 1 
                                r = r + (i%10+1) * 10^10  -- 癞子 -- 转换数
                            end
                        elseif cc[i+1] ~= 0 and cc[i+2] == 0 then
                            needLaizi = needLaizi + 1 

                            r = r + 10 ^ (9 - (i+1)%10)
                            if (i+2)%10 == 0 then
                                r = r + 10 ^ (9 - (i-1)%10)
                                r = r + ((i-1)%10) * 10^10  -- 癞子 -- 转换数
                            else
                                r = r + 10 ^ (9 - (i+2)%10)
                                r = r + ((i+2)%10) * 10^10   -- 癞子 -- 转换数
                                if i % 10 ~= 1 then
                                    branch = r
                                end

                            end
                        end
                    end

                    if needLaizi > laiziCount then return nil end
                    laiziCount = laiziCount - needLaizi
                    if (i + 1) % 10 ~= 0 then
                        if cc[i + 1] >= 1 then cc[i + 1] = cc[i + 1] - 1 end
                        if cc[i + 2] >= 1 then cc[i + 2] = cc[i + 2] - 1 end
                    end
                    if not branch then
                        table.insert(result,r)
                    else
                        table.insert(branchs,branch)
                    end
                else
                    local r1 = color +  10 ^ (9 - i % 10)
                    local r2 = r1
                    local branch
                    local upToThree = false
                    -- 77-8-9-2红中,裁剪掉 7-8-9,7-8-9 情况
                    if (i+1)% 10 == 0 or cc[i+1] + cc[i+2] < v*2-1 or cc[i+1] == 0 or cc[i+2] == 0 then
                        upToThree = true
                        needLaizi = 1
                        color = color + CTYPE.Kezi * 10^9
                        r1 = (r1 %10^9) * 3 + color
                        r1 = r1 + (i%10) * 10^10  -- 癞子 -- 转换数
                        r2 = nil
                    else
                        r1 = r1 + CTYPE.Shunzi * 10^9

                        r1 = r1 + 10 ^ (9 - (i+1)%10)
                        r1 = r1 + 10 ^ (9 - (i+2)%10)

                        r2 = r1

                        if cc[i+1] > cc[i+2] then
                            r2 = r2 + ((i+2)%10) * 10^10
                            if i % 10 ~= 1 then
                                branch = r2
                            end
                        else
                            r1 = r1 + ((i+1)%10) * 10^10
                        end
                        needLaizi = 1 -- 上面已经判断了 cc[i+1] ~= cc[i+2]
                    end

                    if laiziCount < needLaizi then return nil end
                    laiziCount = laiziCount - needLaizi
                    if upToThree == false then
                        if cc[i + 1] > 2 then cc[i + 1] = cc[i + 1] - 2 else cc[i + 1] = 0 end
                        if cc[i + 2] > 2 then cc[i + 2] = cc[i + 2] - 2 else cc[i + 2] = 0 end
                    end
                    table.insert(result,r1)
                    if r2 and not branch then
                        table.insert(result,r2)
                    end

                    if branch then table.insert(branchs,branch) end

                end
            else
                if cc[i+1] + cc[i+2] + v + laiziCount >= 9 then

                    waitCheckout = {}
                    waitCheckout.cc = table.clone(cc)
                    waitCheckout.result = table.clone(result)

                    local need = 0
                    for j=i,i+2 do
                        local diff = 3 - cc[j]
                        local color = (j//10 + 1) * 10^11
                        local r
                        if diff > 0 then
                            r = color +  10 ^ (9 - j % 10)
                            r = (r - color) * 3 + color + CTYPE.Kezi * 10^9
                            r = r + (j%10) * 10^10
                            need = need + diff
                            waitCheckout.cc[j] = 0
                        else
                            r = color + CTYPE.Kezi * 10^9
                            r = r + 3 * 10^(9 - j % 10)
                            
                            waitCheckout.cc[j] = -diff
                        end

                         table.insert(waitCheckout.result,r)
                    end
                    waitCheckout.laiziCount = laiziCount - need
                    waitCheckout.branchs = table.clone(branchs)
                end

                cc[i + 1] = cc[i + 1] - v
                cc[i + 2] = cc[i + 2] - v
                local r = color +  10 ^ (9 - i % 10) + CTYPE.Shunzi * 10^9
                r = r + 10 ^ (9 - (i+1)%10)
                r = r + 10 ^ (9 - (i+2)%10)
                for n=1,v do
                    table.insert(result,r)
                end
            end
            cc[i] = 0
        end
    end
    return result,branchs,laiziCount,waitCheckout
end

local function checkMeetThreeComboReverse(cardsCount, laiziCount)
    local result = {}
    local cc = {}
    local branchs = {}
    
    for k, v in pairs(cardsCount) do
        if k >= 31 and k <= 37 and v % 3 ~= 0 then return nil end 
        cc[k] = v
    end
    for i = 29, 1,-1 do
        local v = cc[i]
        if v ~= nil and v > 0 then
            local color = (i//10 + 1) * 10^11
            -- 1     6   000300000
            -- 花色  刻子
            -- -------- 0 将  5 连子 6 刻子
            if v >= 3 then 
                v = v - 3 
                -- table.insert(result, {i, i, i})
                -- // 比 math.ceil 快
                local r = color + CTYPE.Kezi * 10^9
                table.insert(result,r + 3 * 10^(9 - i % 10))
            end
            if cc[i - 1] == nil then cc[i - 1] = 0 end
            if cc[i - 2] == nil then cc[i - 2] = 0 end
            if cc[i - 1] < v or cc[i - 2] < v then
                local needLaizi = 0
                if v == 1 then
                    local r = color +  10 ^ (9 - i % 10)
                    local branch
                    if (i - 1) % 10 == 0 or (cc[i - 1] == cc[i - 2] and cc[i-1] == 0) then 
                        needLaizi = 2 
                        r = (r - color) * 3 + color + CTYPE.Kezi * 10^9
                        r = r + (i%10) * 10^10  -- 癞子 -- 转换数
                        -- branch = r
                    else
                        r = r + CTYPE.Shunzi * 10^9
                        if cc[i-2] ~= 0 then
                            r = r + 10 ^ (9 - (i-1)%10)
                            r = r + 10 ^ (9 - (i-2)%10)
                            if cc[i-1] == 0 then
                                needLaizi = needLaizi + 1 
                                r = r + (i%10-1) * 10^10  -- 癞子 -- 转换数
                            end
                        elseif cc[i-1] ~= 0 and cc[i-2] == 0 then
                            needLaizi = needLaizi + 1 

                            r = r + 10 ^ (9 - (i-1)%10)
                            if (i-2)%10 == 0 then
                                r = r + 10 ^ (9 - (i+1)%10)
                                r = r + ((i+1)%10) * 10^10  -- 癞子 -- 转换数
                            else
                                r = r + 10 ^ (9 - (i-2)%10)
                                r = r + ((i-2)%10) * 10^10   -- 癞子 -- 转换数
                                if i % 10 ~= 9 then
                                    branch = r
                                end

                            end
                        end
                    end

                    if needLaizi > laiziCount then return nil end
                    laiziCount = laiziCount - needLaizi
                    if (i - 1) % 10 ~= 0 then
                        if cc[i - 1] >= 1 then cc[i - 1] = cc[i - 1] - 1 end
                        if cc[i - 2] >= 1 then cc[i - 2] = cc[i - 2] - 1 end
                    end
                    if not branch then
                        table.insert(result,r)
                    else
                        table.insert(branchs,branch)
                    end
                else
                    local r1 = color +  10 ^ (9 - i % 10)
                    local r2 = r1
                    local branch
                    local upToThree = false
                    -- 77-8-2红中,裁剪掉 7-8-9,7-8-9 情况
                    if (i-1)% 10 == 0 or cc[i-1] + cc[i-2] < v*2-1 or cc[i-1] == 0 or cc[i-2] == 0 then
                        upToThree = true
                        needLaizi = 1
                        color = color + CTYPE.Kezi * 10^9
                        r1 = (r1 %10^9) * 3 + color
                        r1 = r1 + (i%10) * 10^10  -- 癞子 -- 转换数
                        r2 = nil
                    else
                        r1 = r1 + CTYPE.Shunzi * 10^9

                        r1 = r1 + 10 ^ (9 - (i-1)%10)
                        r1 = r1 + 10 ^ (9 - (i-2)%10)

                        r2 = r1

                        if cc[i-1] > cc[i-2] then
                            r2 = r2 + ((i-2)%10) * 10^10
                            if i % 10 ~= 9 then
                                branch = r2
                            end
                        else
                            r1 = r1 + ((i-1)%10) * 10^10
                        end
                        needLaizi = 1 -- 上面已经判断了 cc[i+1] ~= cc[i+2]
                    end

                    if laiziCount < needLaizi then return nil end
                    laiziCount = laiziCount - needLaizi
                    if upToThree == false then
                        if cc[i - 1] > 2 then cc[i - 1] = cc[i - 1] - 2 else cc[i - 1] = 0 end
                        if cc[i - 2] > 2 then cc[i - 2] = cc[i - 2] - 2 else cc[i - 2] = 0 end
                    end
                    table.insert(result,r1)
                    if r2 and not branch then
                        table.insert(result,r2)
                    end

                    if branch then table.insert(branchs,branch) end

                end
            else
                cc[i - 1] = cc[i - 1] - v
                cc[i - 2] = cc[i - 2] - v
                local r = color +  10 ^ (9 - i % 10) + CTYPE.Shunzi * 10^9
                r = r + 10 ^ (9 - (i-1)%10)
                r = r + 10 ^ (9 - (i-2)%10)
                for n=1,v do
                    table.insert(result,r)
                end
            end
            cc[i] = 0
        end
    end
    return result,branchs,laiziCount
end



local function inList(x, lst)
    for _, c in ipairs(lst) do
        if x == c then return true end
    end
    return false
end

local function splitX(cards, xlist)
    local cl = {}
    local nx = 0
    for _, c in ipairs(cards) do
        if inList(c, xlist) then
            nx = nx + 1
        else
            table.insert(cl, c)
        end
    end
    return cl, nx
end

local function cloneListExclude(cards, idx)
    local rs = {}
    for k,v in pairs(cards) do
        if k ~= idx then rs[#rs + 1] = v end
    end
    return rs
end

local function checkQiduiComp(cc,laizi,huCard)
    local long,len = 0,0
    for c, n in pairs(cc) do
        if n == 1 and huCard == c then
            return false
        end
        if (n // 2) * 2 ~= n then 
            if laizi > 0 then 
                laizi = laizi - 1
            else 
                return false
            end
        end
        if n > 2 then 
            long = long + 1
            len = len + 2
        elseif n > 0 then
            len = len + 1
        end
    end
    if len + laizi // 2 ~= 7 then
        return false
    end

    if long == 0 and laizi > 0 then
        long = long + 1
    end
    return true, long
end

local function checkQidui(handList,laizi,cc,huCard)
    if #handList + laizi ~= 14 then return false end
    cc = cc or cardsCount(handList)

    return checkQiduiComp(cc,laizi,huCard)
end

local function checkHuCombo(cc, laizi)
    -- local cc = cardsCount(cards)
    local groups = {}
    local count = 0
    for i = 1, 37 do
        if cc[i] and cc[i] > 0 then
            count = count + cc[i]
            if cc[i] >= 2 then
                cc[i] = cc[i] - 2 
                local result,branchs,rLaizi,waitCheckout = checkMeetKeziGreed(cc,laizi)
                if not result then
                    result,branchs,rLaizi,waitCheckout = checkMeetThreeCombo(cc, laizi) 
                    if result then
                        local color = (i//10 + 1) * 10^11
                        table.insert(result,color + 2 * 10^(9 - i % 10))
                        table.extend(groups,addBranchs(result,branchs,rLaizi))
                        if waitCheckout then
                            local result,branchs,rLaizi = checkMeetThreeCombo(cc,laizi,waitCheckout)
                            if result then
                                table.insert(result,color + 2 * 10^(9 - i % 10))
                                table.extend(groups,addBranchs(result,branchs,rLaizi))
                            end
                        end
                        result,branchs,rLaizi = checkMeetThreeComboReverse(cc, laizi)
                        if result then
                            
                            table.insert(result,color + 2 * 10^(9 - i % 10))
                            table.extend(groups,addBranchsReverse(result,branchs,rLaizi))
                        end
                    end
                else
                    local color = (i//10 + 1) * 10^11
                    table.insert(result,color + 2 * 10^(9 - i % 10))
                    table.extend(groups,addBranchs(result,branchs,rLaizi))
                end
                cc[i] = cc[i] + 2
            else
                if laizi > 0 then
                    cc[i] = 0
                    laizi = laizi - 1
                    local result,branchs,rLaizi,waitCheckout = checkMeetKeziGreed(cc,laizi)
                    if not result then
                        result,branchs,rLaizi,waitCheckout = checkMeetThreeCombo(cc, laizi)
                        if result then 
                            local color = (i//10 + 1) * 10^11
                            color = color + (i%10) * 10^10  -- 癞子 -- 转换数
                            table.insert(result,color + 2 * 10^(9 - i % 10))
                            table.extend(groups,addBranchs(result,branchs,rLaizi))
                            if waitCheckout then
                                local result,branchs,rLaizi = checkMeetThreeCombo(cc,laizi,waitCheckout)
                                if result then
                                    table.insert(result,color + 2 * 10^(9 - i % 10))
                                    table.extend(groups,addBranchs(result,branchs,rLaizi))
                                end
                            end
                            result,branchs,rLaizi = checkMeetThreeComboReverse(cc, laizi)
                            if result then
                                table.insert(result,color + 2 * 10^(9 - i % 10))
                                table.extend(groups,addBranchsReverse(result,branchs,rLaizi))
                            end
                        end
                    else
                        local color = (i//10 + 1) * 10^11
                        color = color + (i%10) * 10^10  -- 癞子 -- 转换数
                        table.insert(result,color + 2 * 10^(9 - i % 10))
                        table.extend(groups,addBranchs(result,branchs,rLaizi))
                    end
                    laizi = laizi + 1
                    cc[i] = 1
                end
            end
        end
    end

    if count == 0 and (laizi == 2 or laizi == 5) then
        local i = 31
        local color = (i//10 + 1) * 10^11
        local result = {color + 2 * 10^(9 - i % 10)}
        if laizi == 5 then
            table.insert(result,1,color + CTYPE.Kezi*10^9 + 3*10^(9 - i % 10))
        end
        table.insert(groups,result)
    end

    if laizi >= 2 then
        laizi = laizi - 2
        local result,branchs,rLaizi,waitCheckout = checkMeetKeziGreed(cc,laizi)
        if result then
            local color = (31//10 + 1) * 10^11
            table.insert(result,color + 2 * 10^(9 - 31 % 10))
            table.extend(groups,addBranchs(result,branchs,rLaizi))
        end
        laizi = laizi + 2
    end

    if checkQiduiComp(cc,laizi) then
        local result = {}
        for i,n in pairs(cc) do
            if n > 0 then
                local color = (i//10 + 1) * 10^11
                table.insert(result,color + 2 * 10^(9 - i % 10))
                if n > 2 then
                    table.insert(result,color + 2 * 10^(9 - i % 10))
                end
                laizi = laizi - (n % 2)
            end
        end
        table.insert(result,1,laizi)
        table.insert(groups,result)
    end

    return groups
end

local algo = {
    checkMeetThree = checkMeetThree,
    cardsCount = cardsCount,
    checkHu = checkHu,
    checkTing = checkTing,
    checkQidui = checkQidui,
    checkQiduiComp = checkQiduiComp,
    checkMeetThreeCombo = checkMeetThreeCombo,
    checkHuCombo = checkHuCombo,
    checkQiduiComp = checkQiduiComp,

    cloneListExclude = cloneListExclude,
    splitX = splitX,
    inList = inList,

    CTYPE = CTYPE,
}

return algo
