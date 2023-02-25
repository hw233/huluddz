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
local common = require "common_mothed"
local timex = require "timex"
local ma_useractivity = require "activity.ma_useractivity"
local dbx = create_dbx(get_db_manager)

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

-- local globalId = 150001
local cfg_data = {
    DayNum = 0,
    actId = 4009,
}

function cfg_data.GetCfg()
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

-- function cfg_data.GetDayNum()
--     -- local current_time = timex.getDayZero(cfg_data.endAt)
--     -- local diff_time = current_time - cfg_data.startAt
--     -- local num = math.ceil(timex.toDays(diff_time))

--     local num = #datax.sign_in_7
--     return num
-- end


local SignStatus = {
    NoSign = 0,   --不可领奖
    Sign = 1,     --可领奖
    DiamSign = 2, --可钻石领奖
    Reward = 3, --已领奖
}

local SignType = {
    Normal = 0,
    Diam = 1
}
-- local cacheFlag = true

local ma_obj = {
    uid = 0,
    Data = nil,
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.uid = userInfo.id

    -- local _cfgData = datax.globalCfg[globalId]
    -- if _cfgData then
    --     cfg_data.DayNum = _cfgData.val
    -- end

    -- if cacheFlag then
    --     ma_obj:load() --加载数据
    --     ma_obj:refresh() --刷新
    --     ma_obj:save()
    -- end

    eventx.listen(EventxEnum.UserNewDay, function ()
        ma_obj:load() --加载数据
        ma_obj:refresh() --刷新
        ma_obj:save()
    end)

    -- eventx.listen(EventxEnum.UserOnline, function (sData, uData)
    --     -- if not ma_obj:CheckOpen() then
    --     --     return
    --     -- end
    --     -- add code
    -- end, eventx.EventPriority.After)

end

function ma_obj:CreateRecord(startAt, endAt)
    local data = {}
    data.list = {}
    data.refresh = 0
    data.startAt = startAt
    data.endAt = endAt
    local diff_day_num = self:GetDayDiff(timex.getDayZero(data.startAt)) + 1

    if datax.sign_in_7 then
        for index, _ in pairs(datax.sign_in_7) do
            data.list[index] = {Status=SignStatus.NoSign}
        end
    end
    return data
end

function ma_obj:GetDayDiff(old_time)
    local current_time = timex.getDayZero(os.time())
    local diff_time = current_time - old_time
    return math.ceil(timex.toDays(diff_time))
end

function ma_obj:HasSiginIndex()
    if self.Data then
        for _index, _sigin_data in pairs(self.Data.list) do
            if _sigin_data.Status == SignStatus.Sign then
                return true
            end
        end
    end
    return false
end

function ma_obj:refresh()

    if self.Data and self:GetDayDiff(timex.getDayZero(self.Data.refresh or 0)) > 0 then
        self.Data.refresh = os.time()
        local diff_day_num = self:GetDayDiff(timex.getDayZero(self.Data.startAt)) + 1
        if diff_day_num < cfg_data.DayNum then
            if not self:HasSiginIndex() then --如果没有可以领取的签到奖励
                for _index, _sign_data in pairs(self.Data.list) do
                    if _index <= diff_day_num then
                        if _sign_data.Status == SignStatus.NoSign then
                            _sign_data.Status = SignStatus.Sign
                            self.SFlag = true
                            break
                        end
                    end
                end
            end
        elseif diff_day_num == cfg_data.DayNum then
            for _, _sign_data in pairs(self.Data.list) do
                if _sign_data.Status == SignStatus.NoSign or _sign_data.Status == SignStatus.Sign  then
                    _sign_data.Status = SignStatus.DiamSign
                    self.SFlag = true
                end
            end
        end
    end
end

function ma_obj:load()
    self.SFlag = false
    if not self.Data  then
        local data = dbx.find_one(TableNameArr.UserSignRecord, self.uid)
        if not data then
            self.Data = self:CreateRecord(0,0)
        else
            self.Data = data
        end
        self.SFlag = true
    end
end

function ma_obj:save()
    if self.SFlag then
        self.SFlag = false
        dbx.update_add(TableNameArr.UserSignRecord, self.uid, self.Data)
    end
end

function ma_obj:Sign(args)
    ma_obj:load()
    ma_obj:refresh()
    ma_obj:save()
end

function ma_obj:GetCurrentIndex()
    local CurrentIndex = 0
    if not self.Data then
        return CurrentIndex
    end

    for _index, _s_data in pairs(self.Data.list) do
        if _s_data.Status == SignStatus.Sign then
            return _index
        elseif _s_data.Status == SignStatus.Reward then
            CurrentIndex = _index
        end
    end

    return CurrentIndex
end

function ma_obj:CheckCanReward(stype, index)
    if not self.Data then
        return false
    end

    if index <= 0 or index > #self.Data.list then
        return false
    end

    local day_data = self.Data.list[index]
    if not day_data then
        return false
    end

    if stype == SignType.Normal and day_data.Status == SignStatus.Sign then
        return true
    elseif stype == SignType.Diam and day_data.Status == SignStatus.DiamSign then
        return true
    end
    return false
end

function ma_obj:Reward(stype, index)
    if self.Data then
        if index <= #self.Data.list then
            local day_data = self.Data.list[index]
            if day_data then
                if stype == SignType.Normal then
                    if day_data.Status == SignStatus.Sign then
                        day_data.Status = SignStatus.Reward
                        self.SFlag = true
                        return RET_VAL.Succeed_1
                    end
                elseif stype == SignType.Diam then
                    if day_data.Status == SignStatus.DiamSign then
                        day_data.Status = SignStatus.Reward
                        self.SFlag = true
                        return RET_VAL.Succeed_1
                    end
                end
            end
        end
    end
    return RET_VAL.NotExists_5
end

function ma_obj:DataToProto(index, data)
    if not data then
        return {}
    end

    local proto = {}
    proto.status = data.Status
    return proto
end

function ma_obj:CheckAndUpdateOpen()
    local _cfg = cfg_data.GetCfg()
    if not _cfg then
        return
    end

    cfg_data.DayNum = (#datax.sign_in_7 or 0) + 1--cfg_data:GetDayNum()

    self:load()
    self:refresh()
    if self:CheckOver() then
        -- add code
    end

    if not (self.Data and self.Data.startAt and self.Data.startAt == _cfg.startDt and self.Data.endAt and self.Data.endAt == _cfg.endDt) then
        --初始化活动任务
        self:UpdateActivityTime(_cfg.startDt, _cfg.endDt)
    end
    self:save()
end

function ma_obj:UpdateActivityTime(startAt, endAt)
    self.Data = self:CreateRecord(startAt, endAt)
    self.SFlag = true
end

function ma_obj:CheckOver()
    if not self.Data then
        return false
    end

    if not self.Data or self.Data.endAt < 1640966400 then
        return false
    end

    local currentAt = os.time()
    return self.Data and self.Data.endAt < currentAt
end

function ma_obj:CheckOpen()
    self:CheckAndUpdateOpen()

    local _cfg = cfg_data.GetCfg()
    if not _cfg then
        return false
    end

    local cAt = os.time()
    return self.Data and cAt >= self.Data.startAt and cAt <= self.Data.endAt
end

-- function ma_obj:WriteRecord(index, signtype)
--     ma_common.write_record(TableNameArr.UserSign14Record_REC, index, signtype)
-- end

REQUEST_New.GetSign7 = function (args)
    if not ma_obj:CheckOpen() then
        return RET_VAL.NotOpen_9
    end

    ma_obj:load()
    ma_obj:refresh()
    ma_obj:save()

    local proto_data = {}
    proto_data.signdatalist = {}
    proto_data.currentindex = ma_obj:GetCurrentIndex()
    if ma_obj.Data then
        for _index, _day_data in pairs(ma_obj.Data.list) do
            proto_data.signdatalist[_index] = ma_obj:DataToProto(_index, _day_data)
        end
    end
    return RET_VAL.Succeed_1, proto_data
end

REQUEST_New.RewardSign7 = function (args)
    if not args or not args.signtype or not args.index then
        return RET_VAL.Default_0
    end

    if not ma_obj:CheckOpen() then
        return RET_VAL.NotOpen_9
    end

    ma_obj:load()
    ma_obj:refresh()
    ma_obj:save()

    -- 扣取钻石
    local cfg =  datax.sign_in_7[args.index]
    if not cfg then
        return RET_VAL.Default_0
    end

    if not ma_obj:CheckCanReward(args.signtype,args.index) then
        return RET_VAL.NotExists_5
    end
 
    if args.signtype == SignType.Diam then
        local consumeItems = cfg.diamonds
        if not consumeItems then
            return RET_VAL.Other_10
        end
        if not ma_useritem.removeList(consumeItems, 1, "7天连续登录签到奖励消耗") then
            return RET_VAL.Lack_6
        end
    end


    if not ma_obj:Reward(args.signtype, args.index) then
        return RET_VAL.NotExists_5
    end

    ma_obj:save()

    eventx.call(EventxEnum.WriteLog, UserLogKey.riqi, UserLogKey.goumaicishujilu, tostring(args.index), UserLogKey.xiaofeirenshu, tostring(args.signtype or 0)) 
    -- if args.signtype == SignType.Diam then
    --     ma_obj:WriteRecord(args.index, args.signtype)
    -- end

    -- //添加奖励到玩家身上
    local _reward_items = cfg.rewards
    local sendDataArr = {}
    ma_useritem.addList(_reward_items, 1, "7天连续登录签到奖励", sendDataArr)
    ma_common.showReward(sendDataArr)
    local proto_data = {}
    proto_data.currentindex = ma_obj:GetCurrentIndex()
    proto_data.index = args.index
    if ma_obj.Data then
        proto_data.signdata = ma_obj:DataToProto(args.index, ma_obj.Data.list[args.index]) 
    end
    return RET_VAL.Succeed_1, proto_data
end



return ma_obj