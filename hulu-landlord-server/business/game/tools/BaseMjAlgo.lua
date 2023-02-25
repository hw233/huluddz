require "config/GameConst"
require "table_util"
local Algo = require "game/tools/MjAlgo"
local MjHandle = require "game/tools/MjHandle"

local M = class("BaseMjAlgo")

function M:ctor()
    
end

-- 是否需要检查地七对
function M:IsCheckLandQidui(cards,jokerCount,peng)
    -- PS 暂时没有地七对
    -- if #cards + jokerCount == 11 and #peng == 1 then
    --     local cardId = MjHandle:TrsfomId(peng[1].cards[1])
    --     return cardId == cards[#cards]
    -- else
    --     return false
    -- end

    return false
end

-- 检查龙七对
function M:CheckSpecialQidui(cards)
    local len = #cards
    local last_card = cards[len]
    len = len - 1

    local count = 1
    for i=1,len do
        if cards[i] == last_card then
            count = count + 1
        end
    end

    return count == 4
end

--检测清一色，在胡牌的基础上
function M:CheckUniform(card,handList,pengs,gangs) 
    local firstType
    if card then
        firstType = math.ceil(card/4/9)
    else
        firstType = math.ceil(handList[1]/4/9)
    end
    for i,v in pairs(handList) do 
        if firstType ~= math.ceil(v/4/9) then
            return false
        end
    end
    if gangs then
        for i,gang in ipairs(gangs) do
            if firstType ~= math.ceil(gang.cards[1]/4/9) then
                return false
            end
        end
    end
    if pengs then
        for i,pong in ipairs(pengs) do
            if firstType ~= math.ceil(pong.cards[1]/4/9) then
                return false
            end
        end
    end
    return true
end

-- 在胡牌的基础上检测大对子
function M:CheckHightPair(disposeCards)  
    local cardsCount = MjHandle:CardsCount(disposeCards)
    local doubleCardCount = 0
    for id,num in pairs(cardsCount) do
        if num == 1 or num == 4 then
            return false
        elseif num == 2 then
            doubleCardCount = doubleCardCount + 1
            if doubleCardCount == 2 then
                return false
            end
        end
    end

    return true
end
-- 获取胡牌时牌型
function M:GetCardType(game,player,card,cc,huC)--,hand,card,peng,gang)
    -- local cardType = CARD_TYPE.No_hu
    -- local isCheckLand = self:IsCheckLandQidui(cards,jokerCount,peng)
    local cards,jokerCount = MjHandle:TrsfomIds(player.hand,card,game.joker)
    local qidui,num = Algo.checkQidui(cards,jokerCount,cc,huC)

    return qidui or Algo.checkHu(cards, jokerCount,cc,huC)
end

-- 流局时,检查胡
function M:CheckHuInDeuce(cc,huCard,huC,isJoker,jCount,cardsLen)
    return Algo.checkQiduiComp(cc,jCount)
        or Algo.checkHu(nil,jCount,cc,huCard,cardsLen)
end

function M:GetAllTing(game,player)
    local cards, jokerCount = MjHandle:TrsfomIds(player.hand,nil,game.joker)

    local ting = {}
    local count = #cards
    for i = 1,29 do
        if i%10 ~= 0 then
            cards[count + 1] = i
            local cc = MjHandle:CardsCount(cards)
            -- local tempCardType = self:GetCardType(cards,jokerCount,hand,nil,pengs,gangs)
            -- if tempCardType > CARD_TYPE.No_hu then
            --     table.insert(ting,i)
            -- end
            if self:GetCardType(game,player,nil,cc,i) then
                table.insert(ting,i)
            end
        end
    end
    return ting
end

function M:IsTing(game,player)
    local cards, jokerCount = MjHandle:TrsfomIds(player.hand,nil,game.joker)

    local ting = {}
    local count = #cards
    for i = 1,29 do
        if i%10 ~= 0 then
            cards[count + 1] = i
            local cc = MjHandle:CardsCount(cards)
            -- local tempCardType = self:GetCardType(cards,jokerCount,hand,nil,pengs,gangs)
            -- if tempCardType > CARD_TYPE.No_hu then
            --     return true
            -- end
            local tempI = MjHandle:RestoreId(i)
            if self:GetCardType(game,player,tempI,cc,i) then
                return true
            end
        end
    end
    return false
end

function M:GetTingNum(game,player)
    local ting = self:GetAllTing(game,player)
    return #ting
end

function M:RemoveCards(hand,index)
    local residueCards = {}
    for i,mj in ipairs(hand) do
        if i~= index then
            table.insert(residueCards,mj)
        end
    end

    return residueCards
end

function M:FindInHand(hand,card)
    for i,id in ipairs(hand) do
        if MjHandle:CardsEq(id,card) then
            return id
        end
    end
    return false
end

-- 暗杠,碰 条件
function M:PengCondition(p,cid)
    return true
end

function M:GangCondition(game,p,cid)
    return true
end

-- 获取碰牌
function M:GetPeng(game,player, card )
    if MjHandle:IsJoker(card,game.joker) then
        return 
    end

    local hand = MjHandle:CardsSort(table.clone(player.hand))
    local t = {}
    for _,id in ipairs(hand) do
        if self:PengCondition(player,id) and MjHandle:CardsEq(id, card) then
            
            table.insert(t, id)
        end
    end

    if #t >= 2 then
        return {card1 = t[1], card2 = t[2]}
    end
end

-- 获取明杠
function M:GetMGang(game,player,card)
    if #game.wall <= 0 then
        return
    end

    if MjHandle:IsJoker(card,game.joker) then
        return
    end

    local t = {}
    for _,id in ipairs(player.hand) do
        if MjHandle:CardsEq(id,card) then
            table.insert(t,card)
        end
    end
    if #t == 3 and self:GangCondition(game,player,t[1]) then
        return {{card = t[1],type = ActionType.MGang}}
    end
end

-- 获取补杠
function M:GetBGangs(game,player,card)
    print("pengs =", table.tostr(player.pengs))
    print("pengs =", table.tostr(player.hand))
    print("passGangs =", table.tostr(player.passGangs))
    local gangs = {}
    local hand = player.hand
    for _,peng in ipairs(player.pengs) do
        local id = self:FindInHand(hand,peng.cards[1])
        if id and not player.passGangs[MjHandle:TrsfomId(id)]
            and self:GangCondition(game,player,id) then
            local pack = {
                card    = id,
                type    = ActionType.BGang,
            }

            -- 补杠时,不是最新的一张牌肯定是憨包杠
            if not MjHandle:CardsEq(card,hand[#hand]) then
                pack.flag = ActionType.HGang
            end
            
            table.insert(gangs,pack)
        end
    end
    print("gangs =", table.tostr(gangs))
    return gangs
end

-- 获取暗杠，补杠
function M:GetABGangs(game,player,card)
    if #game.wall <= 0 then
        return
    end
    local gangs = {}
    local hand = MjHandle:CardsSort(table.clone(player.hand))
    print("hand =", table.tostr(hand))
    print("joker =", game.joker)
    print("passGangs =", table.tostr(player.passGangs))
    for i=1,#hand-3,1 do
        if MjHandle:CardsEq(hand[i],hand[i+1],hand[i+2],hand[i+3])
            and not MjHandle:IsJoker(hand[i],game.joker)
            and not player.passGangs[MjHandle:TrsfomId(hand[i])]
            and self:GangCondition(game,player,hand[i]) then
                local pack = {
                    card = hand[i],
                    type = ActionType.AGang
                }
                if card and not MjHandle:CardsEq(card,hand[i]) then
                    pack.flag = ActionType.HGang
                end

                table.insert(gangs,pack)

        end
    end
    print("gangs =", table.tostr(gangs))
    table.extend(gangs,self:GetBGangs(game,player,card))

    return gangs

end

-- 获取暗杠补杠条件
function M:CheckABGangsCond(game,player,card)
    return true
end

-- 在发牌时，获取操作
function M:GetDealTip(game,player,card,fromTail)
    local gangs =  self:GetABGangs(game,player,card)
 
    local tips = {}
    if self:GetCardType(game,player) then
        local pack = {op = ActionType.Hu}
        local args = {
            -- cardType = cardType,
            -- huType   = huType,
            fromTail = fromTail,
            beFromType = BE_FROM_TYPE.Deal
        }
        pack.args = args
        table.insert(tips,pack)
    end

    if gangs and #gangs > 0 then
        local pack = {op = ActionType.Gang,args = {gangs = gangs}}
        table.insert(tips,pack)
    end

    if #tips > 0  then
        table.insert(tips,{op = ActionType.Cancel})
        return tips
    else
        return false
    end
end


function M:GetBGangTip(game,player,card)
    if not self:GetCardType(game,player,card) then
        return false
    end

   

    local tips = {}
    local pack = {op = ActionType.Hu}
    local args = {
        huCard = card,
        -- fromTail = fromTail,
        beFromType = BE_FROM_TYPE.Gang,
    }
    pack.args = args
    table.insert(tips,pack)

    if #tips > 0 then
        table.insert(tips,{op = ActionType.Cancel})
        return tips
    else
        return false
    end
end

function M:GetOtherTip(game,player,card)
    local pengs,gangs
    if not player.tellTing then
        pengs = self:GetPeng(game,player,card)
        gangs = self:GetMGang(game,player,card)
    end
    local cardType,huType,huState
    local tips = {}
    
    if self:GetCardType(game,player,card) then
        local pack = {op = ActionType.Hu}
        local args = {
            -- fromTail = false,
            huCard = card,
            beFromType = BE_FROM_TYPE.Ping
        }
        pack.args = args
        table.insert(tips,pack)
    end

    if gangs then
        local pack = {op = ActionType.Gang,args = {gangs = gangs}}
        table.insert(tips,pack)
    end

    if pengs then
        local pack = {op = ActionType.Peng,args ={peng = pengs}}
        table.insert(tips,pack)
    end

    if #tips > 0 then
        table.insert(tips,{op = ActionType.Cancel})
        return tips
    else
        return false
    end
end

function M:GetTipAfterEatPeng(game,player)
    local gangs = self:GetABGangs(game,player)

    if gangs and #gangs > 0 then
        local tips = {}
        local pack = {op = ActionType.Gang,args = {gangs = gangs}}
        table.insert(tips,pack)
        table.insert(tips,{op = ActionType.Cancel})
        return tips
    end
end

return M