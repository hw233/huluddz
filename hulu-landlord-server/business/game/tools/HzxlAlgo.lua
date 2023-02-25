local Parent = require("game/tools/BaseMjAlgo")

local M = class("HzxlAlgo",Parent)
local MjHandle = require("game/tools/MjHandle")

function M:ctor()
    M.super.ctor(self)
end

function M:CheckHuLimit(cc,huC)
    if cc[huC] then
        cc[huC] = cc[huC] - 1
    end
    local res = true
    if (not cc[huC] or cc[huC] <= 0) 
        and (not cc[huC + 1] or cc[huC + 1] <= 0) 
        and (huC % 10 >= 8 or not cc[huC + 2] or cc[huC + 2] <= 0) 
        and (huC % 10 <= 2 or not cc[huC - 2] or cc[huC - 2] <= 0) 
        and (not cc[huC - 1] or cc[huC - 1] <= 0) then

        --前后五张都没有肯定不能胡
        res = false
    end

    if cc[huC] then
        cc[huC] = cc[huC] + 1
    end

    return res
end

function M:GetCardType(game,player,card)
    -- 缺一门,没结束不能算胡
    if not player:DiscardEnd() then
        --print("GetHuType,DiscardEnd",player:DiscardEnd())
        return
    end
    -- 缺一门,不算胡
    if card and MjHandle:GetCardColor(card) == player.discardType then
        return
    end

    -- -- 
    local cards,jokerCount = MjHandle:TrsfomIds(player.hand,card,game.joker)
    local len = #cards
    local huC = card or player:GetLastCard()
    local isJoker = MjHandle:IsJoker(huC,game.joker)
    if len == 0 and jokerCount == 2 then
        return true
    elseif len == 1 and not isJoker then
        -- 单独一张癞子 只能胡 癞子
        return
    end
    
    if not isJoker then
        huC = MjHandle:TrsfomId(huC)
        local cc = MjHandle:CardsCount(cards)

        if not self:CheckHuLimit(cc,huC) then
            return false
        end
    end

    return M.super.GetCardType(self,game,player,card,cc,huC)
end

function M:GetAllTing(game,player)
    local cards, jokerCount = MjHandle:TrsfomIds(player.hand,nil,game.joker)

    local ting = {}
    local count = #cards
    for i = 1,29 do
        if i%10 ~= 0 then
            local card = MjHandle:RestoreId(i)
            if self:GetCardType(game,player,card) then
                table.insert(ting,i)
            end
        end
    end
    return ting
end

-- 流局时,检查胡
function M:CheckHuInDeuce(cc,huCard,huC,isJoker,jCount,cardsLen)
    if cardsLen == 0 and jokerCount == 2 then
        return true
    elseif cardsLen == 1 and not isJoker then
        return 
    end
    if not isJoker then
        if not self:CheckHuLimit(cc,huC) then
            return false
        end
    end

    return M.super.CheckHuInDeuce(self,cc,huCard,huC,isJoker,jCount,cardsLen)
end

-- 碰 条件检查
function M:PengCondition(p,cid)
    return p.discardType ~= MjHandle:GetCardColor(cid) and not p.yetXlHu
end

-- 杠 条件检查
function M:GangCondition(game,p,cid)
    if p.discardType == MjHandle:GetCardColor(cid) then
        return false
    end
    local result = true
    if p.yetXlHu then -- 如果胡过，需要检查不能改变已胡牌型
        local pHand = p.hand
        local hand = table.clone(pHand)
        for i=#hand,1,-1 do
            local  card = hand[i]
            if MjHandle:CardsEq(card,cid) then
                table.remove(hand,i)
            end
        end
        p.hand = hand
        for _,v in ipairs(p.xlHuCards) do
                     
            if not self:GetCardType(game,p,v.huCard) then
                result = false
            end
        end
        p.hand = pHand
    end

    return result
end

function M:ExistHuOp(tips)
    if not tips then
        return
    end
    for _,op in ipairs(tips) do
        if op.op == ActionType.Hu then
            return true
        end
    end
end

function M:RemoveCancelOp(player,tips)
    if tips and player.yetXlHu then
        if self:ExistHuOp(tips) then
            for _,op in ipairs(tips) do
                if op.op == ActionType.Cancel then
                    table.remove(tips,_)
                    break
                end
            end
        end
    end
end

function M:GetDealTip(game,player,card,fromTail)
    local tips = M.super.GetDealTip(self,game,player,card,fromTail)
    self:RemoveCancelOp(player,tips)
    return tips
end

function M:GetOtherTip(game,player,card)
    local tips = M.super.GetOtherTip(self,game,player,card)
    self:RemoveCancelOp(player,tips)
    return tips
end

function M:GetBGangTip(game,player,card)
    local tips = M.super.GetBGangTip(self,game,player,card)
    self:RemoveCancelOp(player,tips)
    return tips
end


return M