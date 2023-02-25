local skynet = require "skynet"
local eventx = require "eventx"

local ma_data = require "ma_data"
local objx = require "objx"
local datax = require "datax"
local create_dbx = require "dbx"
local ma_userhero = require "ma_userhero"
local cfg_items = require "cfg.cfg_items"
local ma_useritem   = require "ma_useritem"
local ma_common = require "ma_common"
local ma_useractivity = require "activity.ma_useractivity"

local dbx = create_dbx(get_db_manager)

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local globalId = 17000200
local cfg_data = {
    actId = 4008
}

function cfg_data.getCfg()
    local _cfg = ma_useractivity.getActData(cfg_data.actId)
    if not _cfg or not _cfg.open then
        return nil
    end
    local cAt = os.time()
    if not (cAt >= _cfg.startDt and cAt <= _cfg.endDt) then
        return nil
    end

    return _cfg
end

local StatusReward = {
    Unknown = 0,
    Normal = 1,
    Senior = 2,
    NormalAndSenior = 3,
}

local RewardType = {
    Normal = 1,
    Senior = 2,
    NormalAndSenior = 3,
}
local ma_obj = {

}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)
    ma_obj.uid = userInfo.id

    local _cfgData = datax.globalCfg[globalId]
    if _cfgData then
    end

    ma_obj:initListen()
end

function ma_obj:LoadAndCheckGameOverEmailAndCheckOpen()
    self:CheckAndUpdateOpen()
    local _cfg = cfg_data.getCfg()
    if not _cfg then
        return false
    end

    if not self:HasData()  then
        return false
    end

    local cAt = os.time()
    return cAt >= self.Data.startAt and cAt <= self.Data.endAt
end

function ma_obj:initListen()

    eventx.listen(EventxEnum.UserStoreBuy, function (sData, num, rewardInfo)
        if not sData then
            return
        end
        if sData.id == StorIdEm.StoreTxzGold or sData.id == StorIdEm.StoreTxzChaoGold_1 or sData.id == StorIdEm.StoreTxzChaoGold_2 then
            if not ma_obj:LoadAndCheckGameOverEmailAndCheckOpen() then
                return
            end
            -- self:load()
            -- self:refresh()
            self:addStory(sData.id)
            self:save()

            if sData.id == StorIdEm.StoreTxzGold then
                eventx.call(EventxEnum.DWAnnounce, {annId=AnnounceIdEm.TxzGold, nickname=userInfo.nickname})
            elseif sData.id == StorIdEm.StoreTxzChaoGold_1 or sData.id == StorIdEm.StoreTxzChaoGold_2 then
                local itemNameList = {}
                local itemname = ""
                for key, item in pairs(sData.otherGift) do --rewards
                    local itemCfg = datax.items[item.id]
                    if itemCfg then
                        table.insert(itemNameList, itemCfg.name)
                        itemname = itemCfg.name
                    end
                end
                eventx.call(EventxEnum.DWAnnounce, {annId=AnnounceIdEm.TxzBoJinGold, nickname=userInfo.nickname, itemname=itemname})
            end
        end
    end)

    eventx.listen(EventxEnum.UserOnline, function ()
        if not ma_obj:LoadAndCheckGameOverEmailAndCheckOpen() then
            return
        end
        -- self:load()
        -- self:refresh()
        --如果有奖励，发放邮件奖励
        if self:CheckOver() then
            --发放奖励
            self:RewardToEmail()
        end

        self:save()
    end, eventx.EventPriority.Before)

    ---------活动事件，当活动开启的时候触发
    -- eventx.listen(EventxEnum.ActOpenExent, function (args)
    --     self:ActOpenExent(args)
    -- end)

    -- eventx.listen(EventxEnum.TaskReward, function (args)
    --     if not args  then
    --         return
    --     end
    --     self:ActOpenExent()
    --     if self:Open() then
    --         local addValue = 0
    --         self:load()
    --         self:refresh()
    --         --初始化活动任务
    --         self:addExp(addValue)
    --         self:save()
    --     end
    -- end)

end

function  ma_obj:CheckAndUpdateOpen(args)
    self:load()
    self:refresh()
    if self:CheckOver() then
        --发放奖励
        self:RewardToEmail()
        self:save()
    end

    local _cfg = cfg_data.getCfg()
    if not _cfg then
        return
    end

    local startAt = _cfg.startDt
    local endAt = _cfg.endDt
    if not (self.Data and self.Data.startAt and self.Data.startAt == startAt and self.Data.endAt and self.Data.endAt == endAt) then
        self:UpdateActivityTime(startAt, endAt)
    end
    --初始化活动任务
    self:save()
end

function ma_obj:CreateRecord(startAt, endAt)
    local Data = {
        lv = 1,
        exp = 0,
        storyIdList = {}, --商城购买列表
        lvList = {}, --领取奖励列表
        -- endData = {}, --活动结束后，玩家的数据
        startAt = startAt,
        endAt = endAt,
        emailAt = 0,
    }
    return Data
end

function ma_obj:UpdateActivityTime(startAt, endAt)
    self.Data = self:CreateRecord(startAt, endAt)
    self.SFlag = true
end

function ma_obj:RewardToEmail()
    local args = {lv = 0}
    if (self.Data.emailAt or 0) > 0 then
        return
    end
    local _code, rNormalList, rSeniorList = self:rewardList(args)
    if _code ~= RET_VAL.Succeed_1 then
        return
    end

    local endAt = self.Data.endAt or 0

    self.Data = {}
    self.SFlag = true
    local currentAt = os.time()
    local diff = (currentAt - endAt) / 86400
    if diff > 30 then
        return
    end
    self.Data.emailAt = currentAt
    -- 发放邮件
    if next(rNormalList) then
        local rNormalListTemp = {}
        for _, _list in pairs(rNormalList) do
            table.insertto(rNormalListTemp, _list)
        end

        for _, _list in pairs(rSeniorList) do
            table.insertto(rNormalListTemp, _list)
        end
        ma_common.addMail(userInfo.id, 6001, "通行证奖励领取", nil, rNormalListTemp)
    end
    -- if next(rSeniorList) then
    --     local rSeniorListTemp = {}
    --     for _, _list in pairs(rSeniorList) do
    --         table.insertto(rSeniorListTemp, _list)
    --     end
    --     ma_common.addMail(userInfo.id, 6001, "通行证金卡奖励领取", nil, rSeniorListTemp)
    -- end

end

function ma_obj:HasData()
    return self.Data.lv
end

function ma_obj:CheckOver()
    if not self:HasData() then
        return false
    end

    if self.Data.endAt < 1640966400 then
        return false
    end

    return os.time() > self.Data.endAt
end

function ma_obj:refresh()

end

function ma_obj:load()
    self.SFlag = false
    if not self.Data  then
        local data = dbx.find_one(TableNameArr.UserTXZRecord, self.uid)
        if not data then
            self.Data = {}
            self.SFlag = true
            self:save()
        else
            self.Data = data
        end
    end
end

function ma_obj:save()
    if self.SFlag then
        self.SFlag = false
        dbx.update_add(TableNameArr.UserTXZRecord, self.uid, self.Data)
    end
end

function ma_obj:addExp(addValue)
    self.Data.exp = self.Data.exp + addValue
    local oldLv = self.Data.lv
    local maxlv = oldLv
    for _, _cfg in pairs(datax.passcheck) do
        if _cfg.ex <= self.Data.exp then
            if maxlv < _cfg.level then
                maxlv = _cfg.level
            end
        end
    end

    if maxlv > self.Data.lv  then
        self.Data.lv = maxlv
    end

    -- 推送升级
    local Proto = {}
    Proto.oldLv = oldLv
    Proto.txzData = self:GetProto()
    ma_data.send_push('SyncTxzUpLv', Proto)

    self.SFlag = true
end

function ma_obj:GetCfgByLv(lv)
    local cfg
    for _, _cfg in pairs(datax.passcheck) do
        if _cfg.level == lv then
            cfg = _cfg
            break
        end
    end
    return cfg
end

function ma_obj:addStory(id)
    for _id, _ in pairs(self.Data.storyIdList) do
        if _id == id then
            return
        end
    end
    table.insert(self.Data.storyIdList, id)
    self.SFlag = true

    local Proto = {}
    Proto.goldId = id
    ma_data.send_push('SyncTxzGoldId', Proto)
end

function ma_obj:GetBuyLvConsumeItems(lv)
    local lvRange = lv - self.Data.lv
    if lvRange <= 0 then
        return RET_VAL.NotExists_5
    end

    local consumeList = {}
    local consumeMap = {}
    for upLv = 1, lvRange, 1 do
        local _cfg = self:GetCfgByLv(self.Data.lv + upLv)
        if not _cfg then
            break
        end

        for _, _item in pairs(_cfg.diam) do
            consumeMap[_item.id] = (consumeMap[_item.id] or 0) + _item.num
        end
    end

    for id, num in pairs(consumeMap) do
        table.insert(consumeList, {id = id, num = num})
    end

    if #consumeList == 0 then
        return RET_VAL.NotExists_5
    end

    return RET_VAL.Succeed_1, consumeList
end

function ma_obj:BuyLvByDiamond(lv)
    local cfg = self:GetCfgByLv(lv)
    if not cfg then
        return RET_VAL.NoUse_8
    end

    local _code, consumeList = self:GetBuyLvConsumeItems(lv)
    if _code ~= RET_VAL.Succeed_1 then
        return _code
    end

    --钻石
    if not ma_useritem.removeList(consumeList, 1, "钻石购买通行证等级"..lv) then
        return RET_VAL.Lack_6
    end

    local oldExp = self.Data.exp
    self.Data.exp = cfg.ex
    local oldLv = self.Data.lv
    local oldCfg = self:GetCfgByLv(oldLv)
    if oldCfg then
        self.Data.exp = self.Data.exp + oldExp - oldCfg.ex
    end

    self.Data.lv = lv
    self.SFlag = true

    -- 推送升级
    local Proto = {}
    Proto.oldLv = oldLv
    Proto.txzData = self:GetProto()
    ma_data.send_push('SyncTxzUpLv', Proto)
    return RET_VAL.Succeed_1
end

function ma_obj:checkReward(lv, type)
    if not self:LvList(lv) then
        return true
    end

    if self:LvList(lv) == StatusReward.NormalAndSenior then
        return false
    elseif type == RewardType.NormalAndSenior and self:LvList(lv) ~= StatusReward.NormalAndSenior then
        return true
    end

    if self:LvList(lv) ~= StatusReward.NormalAndSenior then
        if type == RewardType.Normal and self:LvList(lv) ~= StatusReward.Normal then
            return true
        elseif type == RewardType.Senior and self:LvList(lv) ~= StatusReward.Senior then
            return true
        end
    end
    return false
end

function ma_obj:LvList(lv)
    return self.Data.lvList[tostring(lv)]
end

function ma_obj:SetLvStatus(lv, status)
    self.Data.lvList[tostring(lv)] = status
end

function ma_obj:reward(rLv, type, rNormalList, rSeniorList)
    if self.Data.lv < rLv then
        return RET_VAL.Lack_6
    end

    local rlvCfg
    for _, _cfg in pairs(datax.passcheck) do
        if _cfg.level == rLv then
            rlvCfg = _cfg
            break
        end
    end
    if not rlvCfg then
        return RET_VAL.NotExists_5
    end

    if not self:checkReward(rLv, type) then
        return RET_VAL.Lack_6
    end

    if type == RewardType.Normal then
        table.insert(rNormalList, rlvCfg.award)
        if not self:LvList(rLv) then
            self:SetLvStatus(rLv, StatusReward.Normal)
        elseif self:LvList(rLv) == StatusReward.Senior then
            self:SetLvStatus(rLv, StatusReward.NormalAndSenior)
        else
            return RET_VAL.NoUse_8
        end
    elseif type == RewardType.Senior then
        table.insert(rSeniorList, rlvCfg.senior_award)
        if not self:LvList(rLv) then
            self:SetLvStatus(rLv, StatusReward.Senior)
        elseif self:LvList(rLv) == StatusReward.Normal then
            self:SetLvStatus(rLv, StatusReward.NormalAndSenior)
        else
            return RET_VAL.NoUse_8
        end
    elseif type == RewardType.NormalAndSenior then
        if self:LvList(rLv) ~= StatusReward.Normal then
            table.insert(rNormalList, rlvCfg.award)
        end

        if self:LvList(rLv) ~= StatusReward.Senior then
            table.insert(rSeniorList, rlvCfg.senior_award)
        end
        if not self:LvList(rLv) or self:LvList(rLv) ~= StatusReward.NormalAndSenior  then
            self:SetLvStatus(rLv, StatusReward.NormalAndSenior)
        else
            return RET_VAL.NoUse_8
        end
    end
    self.SFlag = true
end

function ma_obj:ValidType(type)
    if type == RewardType.Normal then
        return type
    elseif type == RewardType.Senior or type == RewardType.NormalAndSenior then
        if self:HasGold() then
            return type
        else
            return RewardType.Normal
        end
    end
    return RewardType.Normal
end

function ma_obj:HasGold()
    local flag = false
    for _, _storyId in pairs(self.Data.storyIdList) do
        if _storyId == StorIdEm.StoreTxzGold or _storyId == StorIdEm.StoreTxzChaoGold_1 or _storyId == StorIdEm.StoreTxzChaoGold_2 then
            flag = true
            break
        end
    end
    return flag
end

function ma_obj:rewardList(args)
    local startRLv = args.lv or 0
    local endRLv = args.lv or 0
    local type = args.type

    if startRLv == 0 then
        type = RewardType.NormalAndSenior
    end
    type = self:ValidType(type)

    if startRLv == 0 then
        startRLv = 1
        endRLv = self.Data.lv
    end

    if startRLv > self.Data.lv then
        return RET_VAL.Empty_7
    end

    local rNormalList = {}
    local rSeniorList = {}

    for _lv = startRLv, endRLv, 1 do
        if self:checkReward(_lv, type) then
            self:reward(_lv, type, rNormalList, rSeniorList)
        end
    end

    if not next(rNormalList) and not next(rSeniorList) then
        return RET_VAL.NoUse_8
    end

    return RET_VAL.Succeed_1, rNormalList, rSeniorList
end

function ma_obj:GetProto()
    local proto = {}
    proto.lv = self.Data.lv
    proto.exp = self.Data.exp
    proto.lvRewardList = {}
    for lv, status in pairs(self.Data.lvList) do
        local _rewardData = {lv = tonumber(lv) , status = status}
        table.insert(proto.lvRewardList, _rewardData)
    end
    return proto
end

function ma_obj:loadAndAddTxzExp(id, num)
    if not ma_obj:LoadAndCheckGameOverEmailAndCheckOpen() then
        return RET_VAL.NotOpen_9
    end
    -- self:load()
    -- self:refresh()
    self:addExp(num)
    self:save()
end

REQUEST_New.GetTxzData = function (args)
    if not ma_obj:LoadAndCheckGameOverEmailAndCheckOpen() then
        return RET_VAL.NotOpen_9
    end
    -- ma_obj:load()
    -- ma_obj:refresh()
    ma_obj:save()
    local proto = {}
    proto.txzData = ma_obj:GetProto()
    return RET_VAL.Succeed_1, proto
end

REQUEST_New.TxzBuyLvByDiamond = function (args)
    if not args or not args.lv then
        return RET_VAL.ERROR_3
    end
    if not ma_obj:LoadAndCheckGameOverEmailAndCheckOpen() then
        return RET_VAL.NotOpen_9
    end
    -- ma_obj:load()
    -- ma_obj:refresh()
    local _code = ma_obj:BuyLvByDiamond(args.lv)
    ma_obj:save()
    local proto = {}
    proto.txzData = ma_obj:GetProto()
    return _code, proto
end

REQUEST_New.TxzReward = function (args)
    if not args then
        return RET_VAL.ERROR_3
    end

    if not ma_obj:LoadAndCheckGameOverEmailAndCheckOpen() then
        return RET_VAL.NotOpen_9
    end
    -- ma_obj:load()
    -- ma_obj:refresh()

    if RewardType.Senior == args.type then
        if not ma_obj:HasGold() then
            return RET_VAL.Empty_7
        end
    end

    local _code, rNormalList, rSeniorList = ma_obj:rewardList(args)
    if _code ~= RET_VAL.Succeed_1 then
        return _code
    end
    ma_obj:save()

    local sendDataArr = {}
    --发放奖励
    if next(rNormalList) then
        for _, _list in pairs(rNormalList) do
            ma_useritem.addList(_list, 1, "通行证" .. "奖励, args="..table.tostr(args), sendDataArr)
        end
    end

    if next(rSeniorList) then
        for _, _list in pairs(rSeniorList) do
            ma_useritem.addList(_list, 1, "通行证" .. "金卡奖励, args="..table.tostr(args), sendDataArr)
        end
    end

    if next(sendDataArr) then
        ma_common.showReward(sendDataArr)
    end
    local proto = {}
    proto.txzData = ma_obj:GetProto()
    return RET_VAL.Succeed_1, proto
end

return ma_obj