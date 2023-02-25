local skynet = require "skynet"
local eventx = require "eventx"

local ma_data = require "ma_data"
local ma_useritem = require "ma_useritem"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
--#endregion

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo
local AdvType = {
    RuneExpBookType = 5,
    SkillExpBookType = 6,
    AdvChoujiangType=3,
}

local ma_obj = {
    datas = nil,
    startDt = 0,
}

ma_obj.loadDatas = function ()
    if not ma_obj.datas then
        local obj = dbx.get(TableNameArr.UserAdvert, userInfo.id)
        if not obj then
            obj = {
                id = userInfo.id,
                datas = {},
            }
            dbx.add(TableNameArr.UserAdvert, obj)
        end
        ma_obj.datas = obj.datas
    end
end

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.loadDatas()

    eventx.listen(EventxEnum.UserNewDay, function ()
        ma_obj.reset(DateType.Day)
    end)

    eventx.listen(EventxEnum.UserNewWeek, function ()
        ma_obj.reset(DateType.Week)
    end)

    eventx.listen(EventxEnum.UserNewMonth, function ()
        ma_obj.reset(DateType.Month)
    end)

end


--#region 核心部分

ma_obj.syncData = function (data)
    ma_common.send_myclient("SyncUserAdvertData", {data = data})
end

ma_obj.get = function (_type, dateType)
    if not dateType then
        dateType = DateType.Forever
    end

    local datas = ma_obj.datas[tostring(dateType)]
    return datas and datas[tostring(_type)] or nil
end

ma_obj.add = function (_type, num)
    _type = tostring(_type)

    local datas, updateData = nil, {}
    for key, dateType in pairs(DateType) do
        dateType = tostring(dateType)
        datas = ma_obj.datas[dateType] or {}

        local obj = datas[_type] or {key = _type, num = 0}
        obj.num = obj.num + num
        datas[_type] = obj

        ma_obj.datas[dateType] = datas

        updateData["datas." .. dateType .. "." .. _type] = obj

        if tonumber(dateType) == DateType.Day then
            ma_obj.syncData(obj)
        end
    end
    dbx.update(TableNameArr.UserAdvert, userInfo.id, updateData)
    return ma_obj.datas
end

ma_obj.reset = function (dateType)
    dateType = tostring(dateType)
    ma_obj.datas[dateType] = {}
    dbx.update(TableNameArr.UserAdvert, userInfo.id, {["datas." .. dateType] = ma_obj.datas[dateType]})
end

ma_obj.getNum = function (_type, dateType)
    local uData = ma_obj.get(_type, dateType)
    return uData and uData.num or 0
end


ma_obj.finish = function (_type, param)
    param = table.toObject(param or {}, nil, function (key, value)
        return value.value
    end)

    local groupDatas = table.groupBy(datax.ad_rewards, function (key, value)
        return value.type
    end)
    local arr = groupDatas[_type]
    if not arr or #arr <= 0 then
        return RET_VAL.ERROR_3
    end

    local sData = arr[1]
    if sData.dayLimit > 0 and ma_obj.getNum(_type, DateType.Day) >= sData.dayLimit then
        return RET_VAL.Fail_2
    end

    local advDataDic =  ma_obj.add(_type, 1)
    sData = objx.getChance(arr, function (value)
        return value.weight
    end)

    local rewardInfo = {}
    local sendDataArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Default)

    if next(sData.reward) then
        local _reward = {}
        _reward.id = sData.reward.id
        _reward.num = sData.reward.num or 0
        
        ma_useritem.addList({_reward}, 1, "CmdGetAdvertReward_Cmd获取广告奖励", sendDataArr)

        if AdvType.AdvChoujiangType == _type then
            local _reward_jiacheng = {}
            _reward_jiacheng.id = _reward.id
            _reward_jiacheng.num = 0

            local today_num = 0
            local dayDic = advDataDic[tostring(DateType.Day)]
            if advDataDic and dayDic then
                today_num = dayDic[tostring(_type)].num or 0
            end

            if today_num > 0 then
                local _cfgGData = datax.globalCfg[108001]
                if _cfgGData then
                    local cfgtemp = nil
                    for key, _cfg in pairs(_cfgGData) do
                        if today_num == _cfg.num then
                            cfgtemp = _cfg
                            break
                        elseif _cfg.num < today_num then
                            cfgtemp = _cfg
                        end
                    end
                    _reward_jiacheng.num = _reward.num * cfgtemp.addRatio // 10000
                end
            end
            ma_useritem.addList({_reward_jiacheng}, 1, "CmdGetAdvertReward_Cmd获取广告奖励加成获得", sendDataArr)
        end

        local _reward_jiacheng = ma_obj.getMoodAddReward(_type, _reward.id, _reward.num)
        if _reward_jiacheng.num > 0 then
            local moodRewardDataArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Mood)
            ma_useritem.add(_reward_jiacheng.id, _reward_jiacheng.num, "CmdGetAdvertReward_Cmd获取广告奖励加成获得", moodRewardDataArr)
        end
    end

    if sData.randReward.id then
        local num = math.random(sData.randReward.min, sData.randReward.max)

        local _rand_reward = {}
        _rand_reward.id = sData.randReward.id
        _rand_reward.num = num
        ma_useritem.add(_rand_reward.id, _rand_reward.num, "CmdGetAdvertReward_Cmd获取广告奖励", sendDataArr)

        local _reward_jiacheng = ma_obj.getMoodAddReward(_type, _rand_reward.id, _rand_reward.num)
        if _reward_jiacheng.num > 0 then
            local moodRewardDataArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Mood)
            ma_useritem.add(_reward_jiacheng.id, _reward_jiacheng.num, "CmdGetAdvertReward_Cmd获取广告奖励加成获得", moodRewardDataArr)
        end
    end

    ma_common.showReward(rewardInfo)

    eventx.call(EventxEnum.AdvertLook, sData, param)

    return RET_VAL.Succeed_1
end

ma_obj.getMoodAddReward = function (_type, id, num)
    local reward = {id = id, num = 0}
    if AdvType.RuneExpBookType == _type or AdvType.SkillExpBookType == _type then
        local bonusObj = userInfo.bonusObj or {}
        if bonusObj.mood then
            if AdvType.RuneExpBookType == _type then
                local _rate = (bonusObj.mood[BonusType.RuneExpBook] or 0)
                if _rate > 0 then
                    reward.num = math.max(num * _rate // 10000, 1)
                end
            elseif AdvType.SkillExpBookType == _type then
                local _rate = (bonusObj.mood[BonusType.SkillExpBook] or 0)
                if _rate > 0 then
                    reward.num = math.max(num * _rate // 10000, 1)
                end
            end
        end
    end
    return reward
end

--#endregion

REQUEST_New.GetUserAdvertDatas = function (args)
    -- 初始化一下
    local datasDay = ma_obj.datas[tostring(DateType.Day)] or {}

    local datas
    if args.typeArr then
        datas = {}
        for index, _type in ipairs(args.typeArr) do
            _type = tostring(_type)
            datas[_type] = datasDay[_type]
        end
    else
        datas = datasDay
    end
    return {datas = datas}
end

REQUEST_New.AdvertStart = function (args)
    ma_obj.startDt = os.time()
    return RET_VAL.Succeed_1
end

REQUEST_New.AdvertFinish = function (args)
    if os.time() - ma_obj.startDt < 0 then
        return RET_VAL.Exists_4
    end

    return ma_obj.finish(args.type, args.param)
end


return ma_obj