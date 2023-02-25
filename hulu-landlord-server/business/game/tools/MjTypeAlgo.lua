require "config/GameConst"
local Algo = require "game/tools/MjAlgo"
local MjHandle = require "game/tools/MjHandle"
local skynet = require "skynet"
local M = class("MjTypeAlgo")

local cfg_hu_const = require "cfg/cfg_hu"
local cfg_card_const = require "cfg/cfg_card"
local cfg_hu = cfg_hu_const
local cfg_card = cfg_card_const

local CT_FUNC = {
    Shibaluohan     = "GetGangCount",
    Shierjinchai    = "GetGangCount",
    Shuangminggang  = "GetGangCount",
    Sanjiegao       = "GetContKeziCount",   
    Sijiegao        = "GetContKeziCount",
    Shuanganke      = "GetContKeziCount",
    Sananke         = "GetContKeziCount",
    Sianke          = "GetContKeziCount", 
    Kanzhang        = "Bianzhang",
    Lianqidui       = "Qidui",
    Longqidui       = "Qidui",
}

local XiXiLaoWhiteList = {
    [CARD_TYPE.Bianzhang]      = true,
    [CARD_TYPE.Kanzhang]       = true,
    [CARD_TYPE.Duanyaojiu]     = true,
    [CARD_TYPE.Qishoujiao]     = true,
    [CARD_TYPE.Daigen]         = true,
}

local ClientWhiteList = {
    [CARD_TYPE.Bianzhang]      = true,
    [CARD_TYPE.Kanzhang]       = true,
    [CARD_TYPE.Juezhang]       = true,
    [CARD_TYPE.Duanyaojiu]     = true,
    [CARD_TYPE.Qishoujiao]     = true,
    [CARD_TYPE.Daigen]         = true,
}

function M:ctor()
    
end

function M:TrsfomCards(card,count)
    local c = MjHandle:TrsfomId(card)
    local original = c
    local color = (c//10 + 1)
    c = count * 10 ^ (9 - c % 10)
    return c,color,original
end

function M:InsertCardType(index,cName)
    -- self.cardTypes[index][cName] = true
    table.insert(self.cardTypes[index],cName)
end

function M:SetCPGGroups(pack)
    local gPGroups = {} -- 杠碰 组
    local insertPGs = function(card,count)
        local c,color,original = self:TrsfomCards(card,count)
        gPGroups[color] = gPGroups[color] or {}
        table.insert(gPGroups[color],c)
        
        pack.allCc[original] = (pack.allCc[original] or 0) + count
    end

   
    if pack.pengs and #pack.pengs > 0 then
        for _,p in ipairs(pack.pengs) do
            insertPGs(p.cards[1],3)
        end
    end

    if pack.gangs and #pack.gangs > 0 then
        for _,g in ipairs(pack.gangs) do
            insertPGs(g.cards[1],4)
        end
    end

    local insertChis = function(card)
        local c1,color,original  = self:TrsfomCards(card,1)
        pack.allCc[original]    = (pack.allCc[original] or 0) + 1
        return c1,color
    end

    local chiGroups = {} -- 吃 组 
    if pack.chis and #pack.chis > 0 then
        for _,chi in ipairs(chis) do
            local c = 0
            local c1,color = insertChis(chi.cards[1])
            c = c + c1
            c1,color       = insertChis(chi.cards[2])
            c = c + c1
            c1,color       = insertChis(chi.cards[3])
            c = c + c1

            chiGroups[color] = chiGroups[color]  or {}
            table.insert(chiGroups[color],c)
        end
    end

    pack.gPGroups = gPGroups
    pack.chiGroups = chiGroups
end

-- 胡牌后检查牌型
-- 结构
--[[
    
    game = {
        joker = {112},
        wall  = {108}, -- 牌池剩余牌(除 所有玩家手牌/吃/碰/杠/胡/出牌)
        wallLen = 1,   -- 剩余牌池数量  wall 和 wallLen 参数 2选1
    }

    p = {
        wall  = {[1] = 3,[5] = 4,}, -- 牌池剩余牌(除 自身手牌/吃/碰/杠/胡/出牌)
                                    -- 1,2,3,4 表示 一条(1) = 3
        hand  = {17,14,16,12,29,15,11,13,28,11,27}, -- 手牌,与服务器一致 1-112
        gangs = {{cards = {24,24,24,24}}},       -- 杠
        pengs = {{cards = {17,17,17}},{cards = {16,16,16}},{cards = {2,2,2}}}, -- 碰
        chis  = {{cards = {1,5,9}}},
        changeHand  = true,  -- 起手叫标记(true 表示不是起手叫)
    }

    huArgs = {
        huCard = 8, -- 胡的牌
    }
--]]
-- pengs = {{}}
function M:GetCardTypeCombo(game,p,huArgs,executeType,whiteList)
    local cards,jokerCount = MjHandle:TrsfomIds(p.hand,huArgs.huCard,game.joker)
    local pack = {}
    pack.jCount = jokerCount
    pack.huCard = huArgs.huCard
    pack.cardsLen = #cards + pack.jCount
    pack.cc = MjHandle:CardsCount(cards)
    pack.allCc = table.clone(pack.cc)
    pack.gangs = p.gangs
    pack.pengs = p.pengs
    pack.chis = p.chis
    pack.fromTail = huArgs.fromTail
    pack.beFromType = huArgs.beFromType
    pack.joker  = game.joker
    pack.residueWall = p.wall
    pack.wallLen = game.wallLen and game.wallLen or #game.wall
    pack.changeHand = p.changeHand
    -- pack.yetHu      = true
    -- table.print(cards)
    -- print("====debug qc==== GetCardTypeCombo 1")
    -- table.print(pack)
    pack.jokerCc = {} -- 计算 ”带根“ 用
    if jokerCount > 0 then
        local isExist = false
        for _,v in ipairs(p.hand) do
            if MjHandle:IsJoker(v,game.joker) then
                v = MjHandle:TrsfomId(v)
                pack.jokerCc[v] = (pack.jokerCc[v] or 0) + 1
            end

            if v == huArgs.huCard then
                isExist = true
            end
        end
        local v = huArgs.huCard 
        if not isExist and v and MjHandle:IsJoker(v,game.joker) then

            v = MjHandle:TrsfomId(v)
            pack.jokerCc[v] = (pack.jokerCc[v] or 0) + 1
        end
    end

    -- 设置手牌
    local cardGroups = {}
    for _,cid in ipairs(cards) do
        local color = cid//10 + 1
        cid = 10 ^ (9 - cid % 10)
        cardGroups[color] = (cardGroups[color] or 0) + cid
    end
    pack.cardGroups = cardGroups
    -- 设置 吃,碰 杠
    self:SetCPGGroups(pack)

    pack.huGroups = Algo.checkHuCombo(pack.cc,pack.jCount)

    -- print("====debug qc==== GetCardTypeCombo 2")
    -- table.print(pack)
    -- 初始化牌型存储
    self.cardTypes = {}
    for i=1,#pack.huGroups do
        self.cardTypes[i] = {}
    end
    self.globalTypes = {}

    

    self:Execute(pack,executeType,whiteList)
    -- print("====debug qc==== GetCardTypeCombo 3")
    -- table.print(self.cardTypes)
    -- table.print(self.globalTypes)
    -- 计算最大分值
    return self:GetCardTypeMaxMul()--,pack
end

-- 获取全部类型
function M:GetColorCount(pack)
    if pack.colorCount and not pack.isDeuce  then
        return pack.colorCount,pack.color
    end

    local colorCount = 0
    local color
    for i=1,3 do
        local start = (i-1) * 10
        for j=start+1,start+9 do
            if pack.allCc[j] and pack.allCc[j] > 0 then
                colorCount = colorCount + 1
                color = i
                break
            end
        end
    end

    pack.colorCount = colorCount
    pack.color = color
    return colorCount,color

end

-- 检查龙七对
function M:SetLongqidui(pack,num)
    return num >= 1
end

-- 连七对
function M:SetLianqidui(pack)
    local count = 0
    local rCount = pack.jCount
    local start = false
    for i=1,30 do
        local v = pack.cc[i] or 0
        if not start and  v > 0 then
            start = true
        end
        if start then 
            if v > 2 or v + rCount < 2 then 
                return 
            end
            local need = 2 - v
            if rCount >= need then
                rCount = rCount - need
                count = count  + 1
            else
                return
            end
        end

        -- if count + rCount // 2 == 7 then
        if count == 7 then
            return true
        end
    end
end
-- 七对
function M:Qidui(pack)
    if pack.cardsLen ~= 14 then
        return 
    end

    -- 七对插入表尾
    local len = #pack.huGroups
    local huCards = pack.huGroups[len]
    -- 7 表示七个组合,1 表示表首位插入癞子数,共表长度8
    if not huCards or #huCards + huCards[1]//2 ~= 7+1 then 
        return
    end
    local qidui,num = Algo.checkQiduiComp(pack.cc,pack.jCount,MjHandle:TrsfomId(pack.huCard))
    if qidui then
        local cName = CARD_TYPE.Qidui
        if self:SetLongqidui(pack,num) then
            cName = CARD_TYPE.Longqidui            
        end

        -- 连七对
        self:GetColorCount(pack)
        if pack.colorCount == 1 and self:SetLianqidui(pack) then
            cName = CARD_TYPE.Lianqidui
        end

        self:InsertCardType(len,cName)

    end
end

function M:Pinghu(pack)
    -- if pack.yetHu then
    self.globalTypes[CARD_TYPE.Pinghu] = true        
    -- end
end

-- 缺一门
function M:Queyimen(pack)
    self:GetColorCount(pack)

    if pack.colorCount == 2 then

        self.globalTypes[CARD_TYPE.Queyimen] = true
    end
    
end

--检测清一色，在胡牌的基础上
function M:Qingyise(pack)
    -- -- 存在 癞子,则不是清一色
    -- if pack.jCount and pack.jCount ~= 0 then
    --     return false
    -- end

    self:GetColorCount(pack)

    if pack.colorCount == 1 then
        -- self.globalTypes[CARD_TYPE.Qingyise] = true
        for i,_ in ipairs(pack.huGroups) do
            self:InsertCardType(i,CARD_TYPE.Qingyise)
        end
    end                       

    return pack.colorCount == 1
end


-- 金钩钩
function M:Jingougou(pack)
    if pack.cardsLen == 2 then
        self.globalTypes[CARD_TYPE.Jingougou] = true
    end
end

-- 双明杠,十二金钗,十八罗汉
function M:GetGangCount(pack)
    local gangCount = pack.gangs and #pack.gangs or 0
    if gangCount < 2 then
        return
    end
    local cName = CARD_TYPE.Shuangminggang
    if gangCount == 3 then
        cName = CARD_TYPE.Shierjinchai
    elseif gangCount == 4 then
        cName = CARD_TYPE.Shibaluohan
    end

    self.globalTypes[cName] = true
end

-- 在胡牌的基础上检测大对子
function M:Duiduipeng(pack)
    if pack.chis and #pack.chis > 0 then
        return
    end

    for i,huCards in ipairs(pack.huGroups) do
        local isExist = true
        for j=2,#huCards - 1 do -- 首 为剩余癞子数,尾 为将
            local cType = huCards[j] // 10^9 % 10
            if cType ~= Algo.CTYPE.Kezi then
                isExist = false
                break
            end
        end
        if isExist then
            self:InsertCardType(i,CARD_TYPE.Duiduipeng)
        end
    end
end

-- 获取玩家牌同色节(三张或四张相同的牌)连续数 PS:三节高,四节高
-- 获取玩家刻子数
function M:GetContKeziCount(pack)
    local pgsByColor = {}
    for color,pgs in pairs(pack.gPGroups) do
        pgsByColor[color] = pgsByColor[color] or 0
        for _,pg in ipairs(pgs) do
            pgsByColor[color] = pgsByColor[color] + pg
        end
    end

    for i,huCards in ipairs(pack.huGroups) do
        local keziCount = 0
        local t = {}
        for i=2,#huCards - 1 do -- 首 为剩余癞子数,尾 为将
            local c = huCards[i]
            local color = c // 10^11
            local cType = c // 10^9 % 10
            if cType == Algo.CTYPE.Kezi then -- 刻子
                t[color] = t[color] and t[color] + c % 10^9 or c % 10^9
                keziCount = keziCount + 1
            end
        end

        -- 暗刻数
        if keziCount >= 2 then
            local cName = CARD_TYPE.Shuanganke
            if keziCount == 3 then
                cName = CARD_TYPE.Sananke
            elseif keziCount == 4 then
                cName = CARD_TYPE.Sianke
            end

            self:InsertCardType(i,cName)

        end

        -- 一色 三节高/四节高
        local maxLen = 0
        -- for k,_ in pairs(t) do
        for k=1,3 do
            t[k] = (t[k] or 0) + (pgsByColor[k] or 0)
            local len = string.match(t[k],"[34][34]+")
            -- print("====debug qc====1  三节高？ ",t[k],len)            
            if len then
                len = #len
                if len > 2 and len > maxLen then
                    maxLen = len
                end
            end
        end

        if maxLen > 2 then
            local cName = maxLen == 4 and CARD_TYPE.Sijiegao or CARD_TYPE.Sanjiegao
            self:InsertCardType(i,cName)
        end
    end
end

-- 一条龙
function M:Yitiaolong(pack)
    local chiIds = 0
    for _,chis in pairs(pack.chiGroups) do
        for _,chi in ipairs(chis) do
            chiIds = chiIds + chi
        end
    end

    for i,huCards in ipairs(pack.huGroups) do
        local keziCount = 0
        local card = 0
        for i=2,#huCards-1 do -- 首 为剩余癞子数,尾 为将
            local c = huCards[i]
            local color = c // 10^11        -- 花色
            local cType = c // 10^9 % 10    -- 类型

            if cType == Algo.CTYPE.Shunzi then
                card = card + c % 10^9
            end
        end

        -- 加上吃
        card = card + chiIds

        local diff = card - 111111111
        if diff == 0 or diff == 111 * 10^(#tostring(diff) - 5) then
            -- 5 因为 card 整数后加了 “.0”两个字符
            self:InsertCardType(i,CARD_TYPE.Yitiaolong)
        end
    end
end

function M:GetBianzhang(card)
    card = card % 10
    if card == 3 or card == 7 then
        return CARD_TYPE.Bianzhang
    elseif card == 2 or card == 5 or card == 8 then
        return CARD_TYPE.Kanzhang
    end
end

-- 青龙
function M:Qinglong(pack)
    local noNeedByColor = {}
    for i =1,3 do
        local chis = pack.chiGroups[i]
        if chis then
            for _,chi in ipairs(chis) do
                local start
                if chi == 111 then
                    start = 7
                elseif chi  == 111000 then
                    start = 4
                elseif chi == 111000000 then
                    start = 1
                end

                if start then
                    noNeedByColor[i] = noNeedByColor[i] or {}
                    for n = start,start + 2 do
                        noNeedByColor[i][n] = true
                    end
                end
            end
        end
    end

    local n
    for i=1,3 do
        local need = 0
        local isExist = true
        local cc = table.clone(pack.cc)
        for j=1,9 do
            n = (i-1)*10 + j
            if not noNeedByColor[n] then
                if j%3 == 1 
                    and (not cc[n] or cc[n] == 0)
                    and (not cc[n+1] or cc[n+1] == 0)
                    and (not cc[n+2] or cc[n+2] == 0) then
                        isExist = false
                        break
                end

                if not cc[n] or cc[n] == 0 then
                    need = need + 1
                    if need > pack.jCount then
                        isExist = false
                        break
                    end
                else
                    cc[n] = cc[n] - 1
                end
            end
        end
        if isExist and need <= pack.jCount then
            local cardTypes = {CARD_TYPE.Qinglong,CARD_TYPE.Laoshaopei}
            local huC = MjHandle:TrsfomId(pack.huCard)
            local huColor = MjHandle:GetCardColor(pack.huCard)
            local residue = pack.jCount - need
            local isJoker = MjHandle:IsJoker(pack.huCard,pack.joker)
            local groups = Algo.checkHuCombo(cc,residue)
            if groups and #groups > 0 then
                local cName = self:Bianzhang(pack,groups)
                if not cName and huColor == i then
                    huC = huC % 10
                    cName = self:GetBianzhang(huC)
                elseif isJoker then
                    if residue ~= pack.jCount then
                        for j=1,9 do
                            n = (i-1)*10 + j
                            if not noNeedByColor[n] then
                                if not pack.cc[n] or pack.cc[n] == 0 then
                                    cName = self:GetBianzhang(n)
                                    if cName then break end
                                end
                            end
                        end
                    end

                    if not cName then
                        for _,g in ipairs(groups) do
                            for j=2,#g do -- 首 为剩余癞子数
                                local c = g[j]
                                huC = c % 10^11 // 10^10
                                if huC ~= 0 then
                                    color = c // 10^11
                                    if color == i then
                                        cName = self:GetBianzhang(huC)
                                    end
                                end

                                if cName then break end
                            end
                            if cName then break end
                        end
                    end
                end
                if cName then
                    table.insert(cardTypes,cName)
                end

                self:GetColorCount(pack)
                if pack.colorCount == 1 then -- 单独添加清一色
                    table.insert(cardTypes,CARD_TYPE.Qingyise)
                end
                table.insert(self.cardTypes,cardTypes)

                break
            end
        end
    end
end
-- 获取边张,坎张在一色双龙会
function M:GetBzInYsslh(pack)
    local isJoker = MjHandle:IsJoker(pack.huCard,pack.joker)
    local huC = MjHandle:TrsfomId(pack.huCard)
    local cName
    if not isJoker then
        huC = huC % 10
        if huC == 3 or huC == 7 then
            cName = CARD_TYPE.Bianzhang
        elseif huC == 2 or huC == 8 then
            cName = CARD_TYPE.Kanzhang
        end
    else
        local n = (pack.color - 1) * 10
        for i= n + 1,n+9 do
            v = pack.allCc[n]
            n = i % 10

            if (n == 3 or n == 7) and (not v or v < 2) then
                cName = CARD_TYPE.Bianzhang
                break
            elseif (n==2 or n == 8) and (not v or v < 2) then
                cName = CARD_TYPE.Kanzhang
                break
            end
        end
    end
    return cName
end


-- 九莲宝灯
function M:Jiulianbaodeng(pack)
    if self:GetColorCount(pack) ~= 1 then
        return
    end

    local expect = 311111113

    local color,card = next(pack.cardGroups)
    if not card then
        return
    end

    local diff = card - 311111113
    if diff ~= 10^(#string.format("%d",diff) - 1) and pack.jCount == 0 then
        return
    end

    local need = 0
    local isMayQl = true -- 可能存在清龙
    local isMayKz = false -- 可能存在坎张
    for i=(color -1)*10+1,(color -1)*10 + 9 do
        local j = i % 10
        local n = 1
        if j == 1 or j == 9 then
            n = 3
        end
        local v = pack.cc[i] or 0

        diff = v - n
        if diff < 0 then
            need = need - diff
        end

        if n ~= 3 and v >= 2 then
            isMayQl = false
        end

        if j == 5 and v == 1 then
            isMayKz = true
        end
    end

    if need > pack.jCount then
        return
    end

    local cardTypes = {CARD_TYPE.Jiulianbaodeng,CARD_TYPE.Qingyise}


    -- 老少配,青龙
    local isJoker = MjHandle:IsJoker(pack.huCard,pack.joker)
    local huC = MjHandle:TrsfomId(pack.huCard) % 10
    if not isJoker then
        if huC == 1 or huC == 9 then
            table.insert(cardTypes,CARD_TYPE.Qinglong)
            table.insert(cardTypes,CARD_TYPE.Laoshaopei)
        end
    else
        if pack.jCount - need > 0 and isMayQl then
            table.insert(cardTypes,CARD_TYPE.Qinglong)
            table.insert(cardTypes,CARD_TYPE.Laoshaopei)
        end

    end
   

    local cName 
    if not isJoker then
        if huC == 3 or huC == 7 then
            cName = CARD_TYPE.Bianzhang
        elseif huC == 2 or huC == 8 then
            cName = CARD_TYPE.Kanzhang
        elseif huC == 5 and isMayKz then
            cName = CARD_TYPE.Kanzhang
        end
    else
        local n = (pack.color - 1) * 10
        for i= n + 1,n+9 do
            v = pack.allCc[n]
            n = i % 10
            if (n == 3 or n == 7) and (not v or v < 2) then
                cName = CARD_TYPE.Bianzhang
                break
            elseif (n==2 or n == 8) and (not v or v < 2) then
                cName = CARD_TYPE.Kanzhang
                break
            elseif n == 5 and (not v or v == 0) then
                cName = CARD_TYPE.Kanzhang
                break
            end
        end
    end
    local superposition = cfg_hu[CARD_TYPE.Jiulianbaodeng].superposition
    if cName and superposition and superposition[cName] then
        table.insert(cardTypes,cName)
    end

    table.insert(self.cardTypes,cardTypes)
end

function M:CheckEveryCards(pack,cName,cont)
    for _,chis in pairs(pack.chiGroups) do
        for _,c in ipairs(chis) do
            if cont(c) then
                return false
            end
        end
    end

    for _,pgs in pairs(pack.gPGroups) do
        for _,c in ipairs(pgs) do
            if cont(c) then
                return false
            end
        end
    end

    for i,huCards in ipairs(pack.huGroups) do
        if huCards[1] == 0 then -- 和牌后,癞子组合后,剩余0
            local isExist = true
            for j=2,#huCards do -- 首 为剩余癞子数,尾 为将
                local c = huCards[j] % 10^9
                if cont(c) then
                    isExist = false
                    break
                end
            end
            if isExist then
                self:InsertCardType(i,cName)
            end
        end
    end
end

-- 小于五
function M:Xiaoyuwu(pack)
    local cont = function(c)
        return c % 100000 ~= 0
    end
    self:CheckEveryCards(pack,CARD_TYPE.Xiaoyuwu,cont)
end

-- 大于五
function M:Dayuwu(pack)
    local cont = function(c)
        return 10000 <= c
    end
    self:CheckEveryCards(pack,CARD_TYPE.Dayuwu,cont)
end

-- 全带五
function M:Quandaiwu(pack)
    local cont = function(c)
        return c // 10000 % 10 == 0
    end
    self:CheckEveryCards(pack,CARD_TYPE.Quandaiwu,cont)
end

-- 全带幺
function M:Quandaiyao(pack)
    local cont = function(c)
        return c // (10^8) == 0 and c % 10 == 0
    end
    self:CheckEveryCards(pack,CARD_TYPE.Quandaiyao,cont)
end

-- 断幺九
function M:Duanyaojiu(pack)
    local cont = function(c)
        return c // (10^8) ~= 0 or c % 10 ~= 0
    end
    self:CheckEveryCards(pack,CARD_TYPE.Duanyaojiu,cont)
end

--清幺九
function M:Qingyaojiu(pack)
    local cont = function(c)
        return c % (10^8) ~= 0  and c >= 10
    end
    self:CheckEveryCards(pack,CARD_TYPE.Qingyaojiu,cont)
end

-- 老少配
-- 有同种花色的 123 ,789 的两幅顺子,其他不限
function M:Laoshaopei(pack)
    local chisByColor = {}
    for color,chis in pairs(pack.chiGroups) do
        chisByColor[color] = 0
        for _,chi in ipairs(chis) do
            chisByColor[color] = chisByColor[color] + chi
        end
    end


    for i,huCards in ipairs(pack.huGroups) do
        local keziCount = 0
        local t = {}
        for i=2,#huCards - 1 do -- 首 为剩余癞子数,尾 为将
            local c = huCards[i]
            local color = c // 10^11
            local cType = c // 10^9 % 10
            if cType == Algo.CTYPE.Shunzi then -- 顺子
                t[color] = t[color] and t[color] + c % 10^9 or c % 10^9
                keziCount = keziCount + 1
            end 
        end

        -- for k,_ in pairs(t) do
        for k=1,3 do
            t[k] = (t[k] or 0) + (chisByColor[k] or 0)
            if t[k] // 10^6 >= 111 and t[k] % 10^3 >= 111 and not string.match(string.format("%d",t[k] % 10^3),"0+") then
                self:InsertCardType(i,CARD_TYPE.Laoshaopei)
                break
            end
        end
    end
end

-- 全双刻
function M:Quanshuangke(pack)
    if pack.chis and #pack.chis > 0 then
        return
    end

    local keziCount = pack.gangs and #pack.gangs or 0
    keziCount = keziCount + (pack.pengs and #pack.pengs or 0)

    for i,_ in pairs(pack.allCc) do
        local v = i % 2
        if v ~= 0 then
            return false
        end
    end

    for i,huCards in ipairs(pack.huGroups) do
        if huCards[1] == 0 then -- 和牌后,癞子组合后,剩余0
            local isExist = true
            for i=2,#huCards - 1 do -- 首 为剩余癞子数,尾 为将
                local cType = huCards[i] // 10^9 % 10
                if cType ~= Algo.CTYPE.Kezi then
                    isExist = false
                    break
                end 
            end
            if isExist then
                self:InsertCardType(i,CARD_TYPE.Quanshuangke)
            end
        end

    end
end

-- 一色双龙会
function M:Yiseshuanglonghui(pack)
    self:GetColorCount(pack)
    if pack.colorCount ~= 1 or pack.cardsLen < 14 then
        return
    end
    -- 一色双龙会不存在4,6
    if pack.allCc[4] or pack.allCc[6]
        or pack.allCc[14] or pack.allCc[16]
        or pack.allCc[24] or pack.allCc[26] then
        return
    end

    local expect = 222020222
    local _,card = next(pack.cardGroups)

    if not card or (card ~= expect and pack.jCount == 0) then
        return
    end

    if string.match(card,"[34]") then
        return 
    end
    
    local cardTypes = {CARD_TYPE.Yiseshuanglonghui}
    local superposition = cfg_hu[CARD_TYPE.Yiseshuanglonghui].superposition
    for k,v in pairs(superposition) do
        if cfg_hu[k].type == 1 then
            table.insert(cardTypes,k)
        end
    end

    local cName = self:GetBzInYsslh(pack)

    if cName and superposition[cName] then
        table.insert(cardTypes,cName)
    end
    table.insert(self.cardTypes,cardTypes)
end

-- 带根
function M:Daigen(pack)
    local count = 0

    for i,v in pairs(pack.allCc) do
        v = v + (pack.jokerCc[i] or 0)
        if v == 4 then
            count = count + 1
        end
    end
    for _,v in pairs(pack.jokerCc) do
        if v == 4 then
            count = count + 1
        end
    end

    self.daiGenCount = count
end

-- 边张/坎张
function M:Bianzhang(pack,huGroups)
    local isJoker = MjHandle:IsJoker(pack.huCard,pack.joker)

    local huC = MjHandle:TrsfomId(pack.huCard)
    huC = 10^(9 - huC % 10)
    local huColor = MjHandle:GetCardColor(pack.huCard)
    for i,huCards in ipairs(huGroups or pack.huGroups) do
        local cName        
        for i=2,#huCards - 1 do -- 首 为剩余癞子数,尾 为将
            local c = huCards[i]
            local cType = c // 10^9 % 10    -- 类型
            local color = c // 10^11
            local original = c % 10^9
            if cType == Algo.CTYPE.Shunzi and (huColor == color or isJoker ) then
                if isJoker then
                    huC = c % 10^11 // 10^10
                    if huC ~= 0 then
                        huC = 10^(9 - huC % 10)
                    end
                end
                if huC ~= 0 then
                    c = c % 10^9 - huC
                    if c == 11 or c == 110000000 then
                        cName = CARD_TYPE.Bianzhang
                        break
                    elseif c == 101 * 10^(#tostring(original) - 5) then
                        -- 5 因为 original 整数后加了 “.0”两个字符
                        cName = CARD_TYPE.Kanzhang
                        break
                    end
                end
            end
        end

        if cName and not huGroups then
            self:InsertCardType(i,cName)
        elseif cName then
            return cName
        end
    end

end


-- 绝张
function M:Juezhang(pack)
    local huC = MjHandle:TrsfomId(pack.huCard)
    if not pack.residueWall[huC] or pack.residueWall[huC] <= 0 then
        self.globalTypes[CARD_TYPE.Juezhang] = true
        return true
    end
end

function M:CheckMenQing(pack)
    if pack.cardsLen == 14 then
        return true
    end

    if pack.pengs and #pack.pengs ~= 0 then
        return false
    end

    if pack.chis and #pack.chis ~= 0 then
        return false
    end

    for _,gang in ipairs(pack.gangs) do
        if gang.type ~= ActionType.AGang then
            return false
        end
    end

    return true
end

-- 门清
function M:Menqing(pack)
    if pack.beFromType ~= BE_FROM_TYPE.Deal then
        if self:CheckMenQing(pack) then
            self.globalTypes[CARD_TYPE.Menqing] = true
            return true
        end
    end
end

-- 不求人
function M:Buqiuren(pack)
    if pack.beFromType == BE_FROM_TYPE.Deal then
        if self:CheckMenQing(pack) then
            self.globalTypes[CARD_TYPE.Buqiuren] = true
            return true
        end
    end
end

-- 全求人
function M:Quanqiuren(pack)
    if pack.cardsLen == 2 and pack.beFromType ~= BE_FROM_TYPE.Deal then
        local isExist = false
        if pack.gangs then 
            for _,g in ipairs(pack.gangs) do
                if g.type == ActionType.AGang then
                    isExist = true
                end
            end
        end
        if not isExist then
            self.globalTypes[CARD_TYPE.Quanqiuren] = true
            return true 
        end
    end
end


-- 海底捞月
function M:Haidilaoyue(pack)
    if pack.wallLen == 0 and pack.beFromType == BE_FROM_TYPE.Deal then
        self.globalTypes[CARD_TYPE.Haidilaoyue] = true
    end
end

-- 妙手回春
function M:Miaoshouhuichun(pack)
    if pack.wallLen == 0 and pack.beFromType ~= BE_FROM_TYPE.Deal then
        self.globalTypes[CARD_TYPE.Miaoshouhuichun] = true
    end
end

-- 起手叫
function M:Qishoujiao(pack)
    if not pack.changeHand then
        self.globalTypes[CARD_TYPE.Qishoujiao] = true
    end
end

function M:IsAllGangOps(opList)
    for i=1,#opList-1 do
        op = opList[i]
        if not MjHandle:OperationIsGang(op) then
            return false
        end
    end

    return true
end

function M:GetHuTypeMul(game,player,huArgs)
    local beFromType = huArgs.beFromType

    local huTypes = {}

    if beFromType == BE_FROM_TYPE.Deal then
        -- huType = HU_TYPE.Zi_mo
        table.insert(huTypes,HU_TYPE.Zi_mo)
        if #player.yetOpList == 1 then -- 含有胡的操作
            -- 庄家为天胡，闲家为地胡
            -- local hType = game.banker == player and HU_TYPE.Born or HU_TYPE.Lack_Born 
            -- table.insert(huTypes,hType)

            -- modify by qc 2021.8.11 闲家地胡条件 吃胡庄家第一张牌才算 。此处只剩天胡
            if game.banker == player then
                table.insert(huTypes,HU_TYPE.Born)
            else
                skynet.loge("此处不算地胡咯！！")
            end
           
        end
    elseif beFromType == BE_FROM_TYPE.Ping then
        table.insert(huTypes,HU_TYPE.Ping_hu)
        if game.currentPlayer == game.banker
            and self:IsAllGangOps(game.banker.yetOpList) then

            table.insert(huTypes,HU_TYPE.Lack_Born)
        end

        local len = #game.lastPlayer.yetOpList
        -- 杠为热炮
        local lastOp = game.lastPlayer.penultimateOp
        if MjHandle:OperationIsGang(lastOp) then
            table.insert(huTypes,HU_TYPE.Re_Pao)
        end
        
    elseif beFromType == BE_FROM_TYPE.Gang then
        table.insert(huTypes,HU_TYPE.RobKong)
    end

    if huArgs.fromTail then -- 杠上花
        -- huType = HU_TYPE.Flower
        table.insert(huTypes,HU_TYPE.Flower)
    end

    local mul = 1
    for i,v in ipairs(huTypes) do
        mul = mul * cfg_hu[v].num
    end

    return huTypes,mul
end

-- 客户端获取番型
function M:GetMulByClient(game,player,huArgs)
    local mul,index = self:GetCardTypeCombo(game,player,huArgs,1,ClientWhiteList)
    if index == 0 then
        return
    end
    if self.daiGenCount and self.daiGenCount > 0 then
        mul = mul * cfg_hu[CARD_TYPE.Daigen].num ^ self.daiGenCount
    end
    return mul,index
end

function M:CountDaiGenMul(mul,index)
    local cardTypes = self.cardTypes[index]
    for i=#cardTypes,1,-1 do
        if cardTypes[i] == 0 then
            table.remove(cardTypes,i)
        end
    end
    -- 插入 根  
    -- 番数mul 2^带根 幂
    if self.daiGenCount and self.daiGenCount > 0 then
        mul = mul * (cfg_hu[CARD_TYPE.Daigen].num ^ self.daiGenCount)
        table.insert(cardTypes,CARD_TYPE.Daigen)
    end
    return mul,cardTypes
end

-- 获取胡牌类型
function M:GetHuTypeCombo(game,player,huArgs) --card,fromTail,beFromType)
    local mul,index = self:GetCardTypeCombo(game,player,huArgs)
    if index == 0 then
        return
    end



    local huTypes,huMul = self:GetHuTypeMul(game,player,huArgs)

    local cardTypes
    mul,cardTypes = self:CountDaiGenMul(mul,index)
    
    -- 插入 胡类型
    for i,v in ipairs(huTypes) do
        table.insert(cardTypes,v)
    end

    -- 计算番数
    -- for k,_ in pairs(self.globalTypes) do
    --     mul = mul * cfg_hu[k].num
    -- end

    mul = mul * huMul

    return {
                cTypes      = cardTypes,
                mul         = mul,
                daiGenCount = self.daiGenCount,
                huTypes      = huTypes,
        }
    
end

-- 流局胡牌类型
function M:GetCardTypeInDeuce(game,p,myAlgo)
    local cards,jokerCount = MjHandle:TrsfomIds(p.hand,nil,game.joker)
    local pack = {}
    pack.jCount = jokerCount
    pack.cc = MjHandle:CardsCount(cards)
    pack.allCc = table.clone(pack.cc)
    pack.gangs = p.gangs
    pack.pengs = p.pengs
    pack.chis = p.chis
    pack.cardsLen = #cards + pack.jCount + 1
    pack.joker  = game.joker
    pack.changeHand = p.changeHand
    pack.isDeuce = true

    pack.jokerCc = {} -- 计算 ”带根“ 用
    if jokerCount > 0 then
        for _,v in ipairs(p.hand) do
            if MjHandle:IsJoker(v,game.joker) then
                v = MjHandle:TrsfomId(v)
                pack.jokerCc[v] = (pack.jokerCc[v] or 0) + 1
            end
        end
    end

    -- 设置手牌
    local cardGroups = {}
    for _,cid in ipairs(cards) do
        local color = cid//10 + 1
        cid = 10 ^ (9 - cid % 10)
        cardGroups[color] = (cardGroups[color] or 0) + cid
    end
    pack.cardGroups = cardGroups

    -- 设置 吃,碰 杠
    self:SetCPGGroups(pack)

    local allMaxMul = 0
    local maxCardType = 0
    local huInfo = {}
    for i = 1,31 do
        if i%10 ~= 0 and ((i//10)+1) ~= p.discardType then
            

            
            pack.huCard = MjHandle:RestoreId(i)
            local isJoker = MjHandle:IsJoker(pack.huCard,game.joker)
            local jCount = pack.jCount
            local v = 10 ^(9-i%10)
            local color = i//10 + 1
            if not isJoker then
                pack.cc[i] = (pack.cc[i] or 0) + 1
                pack.allCc[i] = (pack.allCc[i] or 0) + 1
                cardGroups[color] = (cardGroups[color] or 0) + v
            else
                jCount = jCount + 1
                pack.jokerCc[i] = (pack.jokerCc[i] or 0) + 1
            end
            
            if myAlgo:CheckHuInDeuce(pack.cc,pack.huCard,i,isJoker,
                                jCount,pack.cardsLen - jCount) then
                local tempHuInfo = {}
                tempHuInfo.mjid = pack.huCard
                pack.huGroups = Algo.checkHuCombo(pack.cc,jCount)
                if pack.huGroups then
                    -- 初始化牌型存储
                    self.cardTypes = {}
                    for i=1,#pack.huGroups do
                        self.cardTypes[i] = {}
                    end

                    self.globalTypes = {}

                    self:Execute(pack,1,XiXiLaoWhiteList)

                    for k,_ in pairs(self.globalTypes) do
                        for _,cts in ipairs(self.cardTypes) do
                            table.insert(cts,k)
                        end
                    end

                    local maxMul = 0
                    local cardType = 0
                    local huConf
                    for _,cts in ipairs(self.cardTypes) do

                        for j=#cts,1,-1 do
                            cardType = cts[j]
                            huConf = cfg_hu[cardType]
                            if self.canVerValue[cardType] and huConf.type == 1 then
                                local mul = huConf.num
                                if mul > maxMul then
                                    maxMul = mul
                                end
                            end
                        end
                    end

                    if maxMul > allMaxMul then
                        allMaxMul = maxMul
                        maxCardType = cardType
                    end

                    local mul,index = self:GetCardTypeMaxMulComp()
                    local cardTypes 
                    mul,cardTypes = self:CountDaiGenMul(mul,index)
                    tempHuInfo.rate = mul
                    tempHuInfo.types = cardTypes
                    table.insert(huInfo,tempHuInfo)
                end
            end

            if not isJoker then
                pack.cc[i] = pack.cc[i] - 1
                pack.allCc[i] = pack.allCc[i] - 1
                cardGroups[color] = cardGroups[color] - v
            else
                pack.jokerCc[i] = (pack.jokerCc[i] or 0) - 1
            end
        end
    end

    return allMaxMul,maxCardType,huInfo
end

-- 执行番型方法
function M:Execute(pack,t,whiteList)
    for k,v in pairs(self.executeFName) do
        if not t or t == cfg_hu[v].type or (whiteList and whiteList[v]) then
            M[k](M,pack)
        end
    end
end

-- 删除无效的番型
function M:DelUseless()
    -- 剔除不用的番型
    for _,cts in ipairs(self.cardTypes) do
        -- 按照番型从小到大排序
        table.sort(cts,function(a,b)
            if cfg_hu[a].type ~= cfg_hu[b].type then
                return cfg_hu[a].type > cfg_hu[b].type
            elseif cfg_hu[a].num ~= cfg_hu[b].num then
                return cfg_hu[a].num < cfg_hu[b].num
            else
                return a < b
            end
        end)

        -- 剔除不能验证的番型
        for i=#cts, 1, -1 do
            local v = cts[i]
            if not self.canVerValue[v] then
                cts[i] = 0
            else
                local super = cfg_hu[v].superposition
                if super then
                    for j=i-1,1,-1 do
                        if (not super[cts[j]] and cfg_hu[cts[j]].type ~= 2 )or not self.canVerValue[v] then
                            cts[j] = 0 
                        end
                    end
                else
                    for j=i-1,1,-1 do
                        if cfg_hu[cts[j]].type ~= 2 then
                            cts[j] = 0
                        end
                    end
                end
                break               
            end
        end
    end
end

function M:GetCardTypeMaxMulComp()
    self:DelUseless()
    if not self.cardTypes or #self.cardTypes <= 0 then
        skynet.error('==============cardTypes nil')
    end
    -- 计算最大番数
    local maxMul = 0
    local maxCardIndex = 0
    for i,cts in ipairs(self.cardTypes) do
        local mul = 1
        for _,v in ipairs(cts) do
            if v ~= 0 then
                mul = mul * cfg_hu[v].num
            end
        end
        if mul > maxMul then
            maxMul = mul
            maxCardIndex = i
        end
    end


    return maxMul,maxCardIndex
end
-- 获取最大牌型分数
function M:GetCardTypeMaxMul()

    for k,_ in pairs(self.globalTypes) do
        for _,cts in ipairs(self.cardTypes) do
            table.insert(cts,k)
        end
    end

    
    return self:GetCardTypeMaxMulComp()
end

function M:Init(gameId)
    cfg_hu = table.clone(cfg_hu_const)
    cfg_card = table.clone(cfg_card_const)

    local gameId = gameId // 100
    local conf = cfg_card[gameId].card -- 需要检测的类型

    CT_KEY = {}
    for key,v in pairs(CARD_TYPE) do
        CT_KEY[v] = key
    end

    -- 初始化能验证的番型
    self.canVer = {}
    self.canVerValue = {}
    for _,v in ipairs(conf) do
        local key = CT_KEY[v]
        if key then
            self.canVer[CT_KEY[v]] = v
            self.canVerValue[v] = v   
        end

    end

    -- 需要执行的方法,因为部分牌型一起验证,去除重复验证
    self.executeFName = {}
    for k,v in pairs(self.canVer) do
        if M[k] then
            self.executeFName[k] = v
        elseif CT_FUNC[k] then
            self.executeFName[CT_FUNC[k]] = v
        else
            assert(false,"not func " .. k)
        end
    end

    -- 初始化番型 对应的 番数
    for _,v in ipairs(cfg_hu) do
        if v.superposition then
            local super = {}
            for _,c in ipairs(v.superposition) do
                super[c] = c
            end
            v.superposition = super
        end
    end

end

return M