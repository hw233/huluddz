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
local dbx = create_dbx(get_db_manager)

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local globalId = 110002
local cfg_data = {
    switch_on_off = true, --是否开启，true开启，false 关闭
    luck1_system_free_num_limit=1, --每日系统免费次数限制
    luck10_system_free_num_limit=0, --每日系统免费次数限制
    daily_take_num_limit=9999, --每日抽取限制
    add_luck_step = 10,
    luck_to_good_baoxiang_limit=300, --幸运者300送限定盲盒
    lucktype1_consume_diamond=10,
    lucktype10_consume_diamond=90,


    luck1adv_to_free_num_step = 5,--1连抽 看多少次广告送一次免抽次数
    luck1adv_free_num_limit = 9999,--1连抽 每日广告免费次数限制

    luck10adv_to_free_num_step = 5,--10连抽 看多少次广告送一次免抽次数
    luck10adv_free_num_limit = 9999,--10连抽 每日广告免费次数限制

    luck10adv_con_day_num = 5,--连续看广告几天送10连抽
}


local LockBXType = {
    LockBXTypeUnknown = 0,
    LockBXType1 = 1,
    LockBXType10 = 2,
}

local LockBXCosumeType = {
    Unknown = 0,
    SystemFree = 1,
    Adv = 2,
    Diamond = 3,
}

local LockBXBoxType = {
    Unknown = 0,
    Type1001 = 1001,
    Type1002 = 1002,
}


local RefreshTime = {
    Hour = 0,
    Min = 0,
    Sec = 0,
    Offset = 0,
}

local AdvType = {
    Luck1=7,
    Luck10=8,
}


local ma_obj = {
    uid = 0,
    Data = nil,
    SFlag = false
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.uid = userInfo.id

    local _cfgData = datax.globalCfg[globalId]
    if _cfgData then
        cfg_data.switch_on_off =  _cfgData.switch_on_off or cfg_data.switch_on_off
        cfg_data.luck1_system_free_num_limit =  _cfgData.system_free_num_limit or cfg_data.luck1_system_free_num_limit
        cfg_data.luck_to_good_baoxiang_limit =  _cfgData.luck_to_good_baoxiang_limit or cfg_data.luck_to_good_baoxiang_limit
        cfg_data.lucktype1_consume_diamond =  _cfgData.lucktype1_diamond
        cfg_data.lucktype10_consume_diamond =  _cfgData.lucktype10_diamond
    end
    ma_obj:getAdvRewardCfg()

    ma_obj:load() --加载数据
    ma_obj:refresh() --刷新
    ma_obj:initListen() --刷新事件
end

function ma_obj:getAdvRewardCfg()
    local groupDatas = table.groupBy(datax.ad_rewards, function (key, value)
        return value.type
    end)
    local cfgArray = groupDatas[AdvType.Luck1]
    if  cfgArray and #cfgArray > 0 then
        local cfg = cfgArray[1]
        if cfg.dayLimit == -1 then
            cfg_data.luck1adv_free_num_limit = 9999
        else 
            cfg_data.luck1adv_free_num_limit = cfg.dayLimit
        end

        local _param = cfg.param
        if _param  and _param.val then
            cfg_data.luck1adv_to_free_num_step = _param.val
        end
    end

    local cfgArray = groupDatas[AdvType.Luck10]
    if  cfgArray and #cfgArray > 0 then
        local cfg = cfgArray[1]
        local _param = cfg.param
        if _param and _param.adWatch then --连续5天，每天至少看5次广告，送一次十连抽
            cfg_data.luck10adv_free_num_limit = _param.adWatch
            cfg_data.luck10adv_con_day_num = _param.consecutiveDays
        end
    end
end

function ma_obj:initListen()
    eventx.listen(EventxEnum.AdvertLook, function (args)
        if not args then
            return
        end

        if self.Data then
            local _type = args.type
            if _type == AdvType.Luck1 or _type == AdvType.Luck10 then
                self:refresh()
                self:addAdvNum()
                self:save()
            end
        end
    end)
end


function ma_obj:refresh()
    if not self.Data or not self.Data.NextRefreshTime or self.Data.NextRefreshTime < os.time()  then
        self:ResetDailyData()
    end
end

function ma_obj:getArrayLength(array)
    if not array then
        return 0
    end

    local length = 0
    for _, _num in pairs(array) do
        if _num >=5 then
            length = length + 1
        end
    end
    return length
end

--获取剩余时间
function ma_obj:GetNextRefreshTime() 
    local current_time = os.time()
    local curr_date = os.date("%Y%m%d")
    local curr_date_year = tonumber(string.sub(curr_date,1,4))  
    local curr_date_month = tonumber(string.sub(curr_date,5,6)) 
    local curr_date_day = tonumber(string.sub(curr_date,7,8)) 

    -- timex.addHours(timex.addDays(timex.getDayZero(), 1), 5)

    local refresh_time = self.Data.NextRefreshTime or 0
    if refresh_time < current_time then
        local refresh_time = os.time({day=curr_date_day,month=curr_date_month,year=curr_date_year, hour = RefreshTime.Hour-RefreshTime.Offset})
        if refresh_time < current_time then
            refresh_time = os.time({day=curr_date_day+1,month=curr_date_month,year=curr_date_year, hour = RefreshTime.Hour-RefreshTime.Offset})
        end
        self.Data.NextRefreshTime = refresh_time
    end

    --  local remain_time = refresh_time - current_time
    --  skynet.logd("takeLuckBaoxiang::GetTimeRemaining:key=", "[", remain_time, "]", "[", refresh_time, "]")
     return self.Data.NextRefreshTime
end

function ma_obj:ResetDailyData()
    self.SFlag = true
    if not self.Data then
        self.Data = {}
    end

    if not self.Data.Lucky1Data then
        self.Data.Lucky1Data = {}
    end

    if not self.Data.Lucky10Data then
        self.Data.Lucky10Data = {}
    end

    if not self.Data.LuckValue then
        self.Data.LuckValue = 0
    end

    self.Data.NextRefreshTime = self:GetNextRefreshTime()
 
    self.Data.AdvNum = 0 --看广告次数

    --连续广告次数刷新列表
    local curr_date = os.date("%Y%m%d")
    if not self.Data.LastAdvTime then
        self.Data.LastAdvTime = {} --最近看广告的时间列表
        self.Data.LastAdvTime[curr_date] = 0
    end

    local curr_date_year = tonumber(string.sub(curr_date,1,4))  
    local curr_date_month = tonumber(string.sub(curr_date,5,6)) 
    local curr_date_day = tonumber(string.sub(curr_date,7,8)) 
    local yesterday1 = os.date("%Y%m%d", os.time({day=curr_date_day-1,month=curr_date_month,year=curr_date_year}))
    if self.Data.LastAdvTime[yesterday1] and self.Data.LastAdvTime[yesterday1] < cfg_data.luck10adv_to_free_num_step then
        local currant_adv_num = self.Data.LastAdvTime[curr_date] or 0
        self.Data.LastAdvTime = {} --最近看广告的时间列表
        self.Data.LastAdvTime[curr_date] = currant_adv_num
    end

    self.Data.Lucky1Data.SystemFreeNum = cfg_data.luck1_system_free_num_limit
    self.Data.Lucky1Data.AdvFreeNumLimit = cfg_data.luck1adv_free_num_limit
    self.Data.Lucky1Data.AdvFreeNum = 0 --看广告赠送的抽奖次数
    self.Data.Lucky1Data.TodayTakeNum = 0

    self.Data.Lucky10Data.SystemFreeNum = cfg_data.luck10_system_free_num_limit
    self.Data.Lucky10Data.AdvFreeNumLimit = cfg_data.luck10adv_free_num_limit
    self.Data.Lucky10Data.AdvFreeNum = 0 --看广告赠送的抽奖次数
    self.Data.Lucky10Data.AdvFreeNumTime = 0 --看广告赠送的抽奖次数的时间
    self.Data.Lucky10Data.TodayTakeNum = 0
end

function ma_obj:load()
    self.SFlag = false
    if not self.Data  then
        -- 获取所有请求者uid
        -- local selector = { uid = self.uid }
        local data = dbx.find_one(TableNameArr.UserLuckBaoxiangRecord, self.uid)
        if not data then
            self:refresh()
            self:save()
        else 
            self.Data = data
        end
    end
end

function ma_obj:save()
    if self.SFlag then
        self.SFlag = false
        dbx.update_add(TableNameArr.UserLuckBaoxiangRecord, self.uid, self.Data)
    end
end
 
function ma_obj:GetLuckValue() 
    return self.Data.LuckValue
end

function ma_obj:getAdvFreeNum(luckType) 
    if LockBXType.LockBXType1 == luckType then
        return self.Data.Lucky1Data.AdvFreeNum
    elseif  LockBXType.LockBXType10 == luckType then
        return self.Data.Lucky10Data.AdvFreeNum
    end
    return 0
end

function ma_obj:addAdvNum()  
    self.SFlag = true
    self.Data.AdvNum = self.Data.AdvNum + 1

    if self.Data.AdvNum % cfg_data.luck1adv_to_free_num_step == 0 then
        if self.Data.Lucky1Data.AdvFreeNumLimit > 0 then
            self.Data.Lucky1Data.AdvFreeNum = self.Data.Lucky1Data.AdvFreeNum + 1
            self.Data.Lucky1Data.AdvFreeNumLimit = self.Data.Lucky1Data.AdvFreeNumLimit - 1
        end
    end

    -- //连续3天且每天在幸运忙盒看5次广告，获取1次免费十连抽
    local curr_date = os.date("%Y%m%d")
    local curr_date_year = tonumber(string.sub(curr_date,1,4))  
    local curr_date_month = tonumber(string.sub(curr_date,5,6)) 
    local curr_date_day = tonumber(string.sub(curr_date,7,8)) 


    local lastAdvFreeNumDay =  os.date("%Y%m%d",self.Data.Lucky10Data.AdvFreeNumTime or 0)
    if not (lastAdvFreeNumDay == curr_date) then
        if not self.Data.LastAdvTime[curr_date] then
            self.Data.LastAdvTime[curr_date] = 1
        else 
            self.Data.LastAdvTime[curr_date] = self.Data.LastAdvTime[curr_date] + 1
        end
    end
    
    local today_num = self.Data.LastAdvTime[curr_date] or 0
    local yesterday = os.date("%Y%m%d", os.time({day=curr_date_day-1,month=curr_date_month,year=curr_date_year}))
    local yesterdaynum = self.Data.LastAdvTime[yesterday] or 0

    if yesterdaynum < cfg_data.luck10adv_to_free_num_step then
        self.Data.LastAdvTime = {}
        self.Data.LastAdvTime[curr_date] = today_num
    end

    local LastAdvTimeLength = self:getArrayLength(self.Data.LastAdvTime)
    if today_num >= cfg_data.luck10adv_to_free_num_step then
        local con_flag = true
        if LastAdvTimeLength  < cfg_data.luck10adv_con_day_num then
            con_flag = false
        else 
            for i = 1, LastAdvTimeLength, 1 do
                local yesterdaytemp = os.date("%Y%m%d", os.time({day=curr_date_day-i+1,month=curr_date_month,year=curr_date_year}))
                local yesterdaynumtemp = self.Data.LastAdvTime[yesterdaytemp] or 0
                if yesterdaynumtemp < cfg_data.luck10adv_to_free_num_step then
                    con_flag = false
                    break
                end
            end
        end
        if con_flag == true then
            if self.Data.Lucky10Data.AdvFreeNumLimit > 0 then
                self.Data.Lucky10Data.AdvFreeNum = self.Data.Lucky10Data.AdvFreeNum + 1
                self.Data.Lucky10Data.AdvFreeNumTime = os.time()
                self.Data.Lucky10Data.AdvFreeNumLimit = self.Data.Lucky10Data.AdvFreeNumLimit - 1
                self.Data.LastAdvTime = {}
            end
        end
    end

    -- skynet.logd("takeLuckBaoxiang::addAdvNum:date=", "[", curr_date, "]", "[", yesterday1, "]", "[", yesterday1, "]")
    local Proto = {}
    Proto.luckinfo = {}
    Proto.luckinfo = self:LuckInfoToProto(self:GetLuckInfo())
    ma_data.send_push('PushTakeLuckBaoxiang', Proto)
    return true
end

function ma_obj:addLuckValue(upValue) 
    self.Data.LuckValue = self.Data.LuckValue + upValue
    if self.Data.LuckValue < 0 then
        self.Data.LuckValue = 0
    end
    self.SFlag = true
end

function ma_obj:_GetRandomItem(not_exists_arry)
    skynet.logd("0_GetRandomItem::not_exists_arry", table.tostr(not_exists_arry))
    local lucky_blind_box_cfg = datax.lucky_blind_box
    local lucky_blind_box_items_cfg = datax.lucky_blind_box_items

    local item = nil
    local rand_reward_box = nil
    if self:GetLuckValue() >= cfg_data.luck_to_good_baoxiang_limit then
        for _, lucky_blind_box in pairs(lucky_blind_box_cfg) do
            if lucky_blind_box.type_id == LockBXBoxType.Type1002 then
                rand_reward_box = lucky_blind_box
                self:addLuckValue(-self:GetLuckValue())
                break
            end
        end
    end

    if not rand_reward_box then
        rand_reward_box = objx.getChance(lucky_blind_box_cfg, function (value) return value.weight end)
    end
    -- skynet.logd("1_GetRandomItem:id",userInfo.id, "rand_reward_box" , table.tostr(rand_reward_box))

    if rand_reward_box then
        -- skynet.logd("rand_reward_box::", table.tostr(rand_reward_box))
        local reward_box_array = {}
        local has_hero_flag = false
        --将存在的英雄的选项排除掉
        if not_exists_arry then
            for key, data in pairs(lucky_blind_box_items_cfg) do
                has_hero_flag = false
                if data.type_id == rand_reward_box.type_id then
                    for _, item_data in pairs(data.items_num) do
                        for _heroId, _ in pairs(not_exists_arry) do
                            local heroId = self:ItemIdToHeroId(item_data.id)
                            if heroId > 0 and tostring(heroId) == _heroId then
                                has_hero_flag = true
                                skynet.logd("11_GetRandomItem:id",userInfo.id, "heroId" , heroId)
                                break
                            end
                        end
                        if has_hero_flag then
                            break
                        end
                    end

                    if not has_hero_flag then
                        reward_box_array[key] = data
                    end
                end
    
            end
        end

        -- skynet.logd("2_GetRandomItem:id",userInfo.id, "reward_box_array" , table.tostr(reward_box_array))
        --抽到的物品
        item = objx.getChance(reward_box_array, function (value) return value.weight end)
    end
    
    -- skynet.logd("item::", table.tostr(item))
    skynet.logd("1end_GetRandomItem:id",userInfo.id, "item" , table.tostr(item))
    return item
end
 
function ma_obj:HeroIdToItemId()

end

function ma_obj:GetRandomItem(num)
    --获取已经存在的英雄
    local NotlimitHeros, _ = ma_userhero.getUseHeroList()
    skynet.logd("0GetRandomItem:id",userInfo.id, "NotlimitHeros" , table.tostr(NotlimitHeros))
    local exists_heros_array = {}
    if NotlimitHeros then
        for key, value in pairs(NotlimitHeros) do
            exists_heros_array[tostring(key)] = tostring(key)
        end
    end
    -------------------------

    local  result_item_array = {}
    for i = 1, num, 1 do
        local rand_item = self:_GetRandomItem(exists_heros_array)
        if rand_item then
            if rand_item.type_id == LockBXBoxType.Type1001 then
                self:addLuckValue(cfg_data.add_luck_step)
            end
    
            skynet.logd("1GetRandomItemrand_item =", i, "rand_item", table.tostr(rand_item),"exists_heros_array=", table.tostr(exists_heros_array))
            --将抽到的英雄插入到已经存在的英雄列表
            for key, item_data in pairs(rand_item.items_num) do
                local heroId = self:ItemIdToHeroId(item_data.id)
                if heroId > 0 then
                    exists_heros_array[tostring(heroId)] = tostring(heroId)
                end
                if rand_item.announce_id and rand_item.announce_id > 0 then
                    local itemCfg = datax.items[item_data.id]
                    if itemCfg then
                        eventx.call(EventxEnum.DWAnnounce, {annId=rand_item.announce_id, nickname=userInfo.nickname, itemname=itemCfg.name})
                    end
                end
            end

            result_item_array[i] = rand_item
        end
    end

    return result_item_array

end

function ma_obj:ItemIdToHeroId(itemId)
    local item = datax.items[itemId]
    if item and item.group == "HeroBox" then
        local heroId = 0
        if item.param then
            for key, _data in pairs(item.param) do
                heroId = _data.id
                return heroId
            end
        end
    end
    return 0
end

--消耗
function ma_obj:cosume(luckType)

    if self.Data.Lucky1Data.TodayTakeNum + self.Data.Lucky10Data.TodayTakeNum*10 >= cfg_data.daily_take_num_limit then
        return RET_VAL.ERROR_3
    end

    local ConsumeType = LockBXCosumeType.Unknown
    if LockBXType.LockBXType1 == luckType then
        if self.Data.Lucky1Data.SystemFreeNum > 0 then --系统免费次数
            self.Data.Lucky1Data.SystemFreeNum = self.Data.Lucky1Data.SystemFreeNum - 1
            self.Data.Lucky1Data.TodayTakeNum = self.Data.Lucky1Data.TodayTakeNum + 1
            self.SFlag = true
            ConsumeType = LockBXCosumeType.SystemFree
        elseif self.Data.Lucky1Data.AdvFreeNum > 0 then --广告免费次数
            self.Data.Lucky1Data.AdvFreeNum = self.Data.Lucky1Data.AdvFreeNum - 1
            self.Data.Lucky1Data.TodayTakeNum = self.Data.Lucky1Data.TodayTakeNum + 1
            self.SFlag = true
            ConsumeType = LockBXCosumeType.Adv
        else 
            --钻石
            if ma_useritem.remove(ItemID.Diamond, cfg_data.lucktype1_consume_diamond, "抽幸运宝箱消耗钻石") then
                self.Data.Lucky1Data.TodayTakeNum = self.Data.Lucky1Data.TodayTakeNum + 1
                self.SFlag = true
                ConsumeType = LockBXCosumeType.Diamond 
            end
        end

    elseif LockBXType.LockBXType10 == luckType then
        if self.Data.Lucky10Data.SystemFreeNum > 0 then --系统免费次数
            self.Data.Lucky10Data.SystemFreeNum = self.Data.Lucky10Data.SystemFreeNum - 1
            self.Data.Lucky10Data.TodayTakeNum = self.Data.Lucky10Data.TodayTakeNum + 1
            self.SFlag = true
            ConsumeType = LockBXCosumeType.SystemFree
        elseif self.Data.Lucky10Data.AdvFreeNum > 0 then --广告免费次数
            self.Data.Lucky10Data.AdvFreeNum = self.Data.Lucky10Data.AdvFreeNum - 1
            self.Data.Lucky10Data.TodayTakeNum = self.Data.Lucky10Data.TodayTakeNum + 1
            self.SFlag = true
            ConsumeType = LockBXCosumeType.Adv
        else 
            --钻石
            if ma_useritem.remove(ItemID.Diamond, cfg_data.lucktype10_consume_diamond, "抽幸运宝箱消耗钻石") then
                self.Data.Lucky10Data.TodayTakeNum = self.Data.Lucky10Data.TodayTakeNum + 1
                self.SFlag = true
                ConsumeType = LockBXCosumeType.Diamond
            end
        end
    end

    if ConsumeType == LockBXCosumeType.Unknown then
        return RET_VAL.Lack_6
    end

    return RET_VAL.Succeed_1
end
 
function ma_obj:takeLuckBaoxiang(luckType)
    local consume_code = self:cosume(luckType)
    if consume_code ~= RET_VAL.Succeed_1 then
        return consume_code
    end
    
    local rand_num = 1
    if LockBXType.LockBXType10 == luckType then
        rand_num = 10
    end
    local box_items = self:GetRandomItem(rand_num)
    self:save()

    local prptoRewardBoxItem = {}
    local itemArray = {}
    local itemIndex = 0
    local rewardBoxItemIndex = 0
    for _, box_item in pairs(box_items) do
        local _PrptoRewardBoxItem = {}
        _PrptoRewardBoxItem.type_id = box_item.type_id
        _PrptoRewardBoxItem.items = {}
        local rewardItemIndex = 0
        for _, item in pairs(box_item.items_num) do
            itemIndex = itemIndex + 1
            itemArray[itemIndex] = item
            rewardItemIndex = rewardItemIndex + 1
            _PrptoRewardBoxItem.items[rewardItemIndex] = item
        end

        rewardBoxItemIndex = rewardBoxItemIndex + 1
        prptoRewardBoxItem[rewardBoxItemIndex] = _PrptoRewardBoxItem
    end

    -- 加入背包
    local sendDataArr = {}
    ma_useritem.addList(itemArray, 1, "幸运宝箱" .. luckType .. "抽取奖励", sendDataArr)
    ma_common.showReward(sendDataArr)
    ----
    -- for key, box_item in pairs(box_items) do
    --     skynet.logd("takeLuckBaoxiang::box_items:key=", key, "[", table.tostr(box_item), "]")
    -- end
    
    -- skynet.logd("takeLuckBaoxiang::prptoTakeLuckBaoxiang:key=", "[", table.tostr(prptoRewardBoxItem), "]")
    return  RET_VAL.Succeed_1, prptoRewardBoxItem
end

function ma_obj:GetLuckInfo() 
    return self.Data
end


function ma_obj:LuckInfoToProto(luckInfo) 
    local prptoTakeLuckInfo = {}
    prptoTakeLuckInfo.lucky1 = {}
    prptoTakeLuckInfo.lucky10 = {}
    if luckInfo then
        prptoTakeLuckInfo.luckvalue = luckInfo.LuckValue
        prptoTakeLuckInfo.nextrefreshtime = luckInfo.NextRefreshTime
        prptoTakeLuckInfo.advnum = luckInfo.AdvNum

        local advcontdaynum = self:getArrayLength(luckInfo.LastAdvTime)
        -- if advcontdaynum > 0 then
        --     advcontdaynum = advcontdaynum
        --     if advcontdaynum == cfg_data.luck10adv_con_day_num then
        --         advcontdaynum = advcontdaynum
        --         local curr_date = os.date("%Y%m%d")
        --         local today_num = self.Data.LastAdvTime[curr_date] or 0
        --         if today_num >= cfg_data.luck10adv_to_free_num_step then
        --             advcontdaynum = advcontdaynum + 1 
        --         elseif today_num > 0 then
        --             advcontdaynum = advcontdaynum - 1
        --         end
        --     end
        -- end
        prptoTakeLuckInfo.advcontdaynum = advcontdaynum

        prptoTakeLuckInfo.lucky1.systemfreenum = luckInfo.Lucky1Data.SystemFreeNum
        prptoTakeLuckInfo.lucky1.advfreenumlimit = luckInfo.Lucky1Data.AdvFreeNumLimit
        prptoTakeLuckInfo.lucky1.advfreenum = luckInfo.Lucky1Data.AdvFreeNum
        prptoTakeLuckInfo.lucky1.todaytakenum = luckInfo.Lucky1Data.TodayTakeNum

        prptoTakeLuckInfo.lucky10.systemfreenum = luckInfo.Lucky10Data.SystemFreeNum
        prptoTakeLuckInfo.lucky10.advfreenumlimit = luckInfo.Lucky10Data.AdvFreeNumLimit
        prptoTakeLuckInfo.lucky10.advfreenum = luckInfo.Lucky10Data.AdvFreeNum
        prptoTakeLuckInfo.lucky10.todaytakenum = luckInfo.Lucky10Data.TodayTakeNum
    end
    return prptoTakeLuckInfo
end

REQUEST_New.GetTakeLuckBaoxiang = function (args)
    if not cfg_data.switch_on_off then
        return RET_VAL.NotOpen_9
    end
    local Proto = {}
    Proto.luckinfo = {}
    ma_obj:refresh()
    ma_obj:save()
    Proto.luckinfo = ma_obj:LuckInfoToProto(ma_obj:GetLuckInfo())
    return RET_VAL.Succeed_1, Proto
end


REQUEST_New.TakeLuckBaoxiang = function (args)
    if not cfg_data.switch_on_off then
        return RET_VAL.NotOpen_9
    end
    if  not args then
        return  RET_VAL.Empty_7, {}
    end
    local Proto = {}
    Proto.rewardboxitems = {}
    Proto.luckinfo = {}

    ma_obj:refresh()
    ma_obj:save()
    local ResultCode, rewardboxitems = ma_obj:takeLuckBaoxiang(args.lucktype)
    Proto.rewardboxitems = rewardboxitems
    Proto.luckinfo = ma_obj:LuckInfoToProto(ma_obj:GetLuckInfo())
    skynet.logd("takeLuckBaoxiang::", ma_obj.uid, "ResultCode:", ResultCode, "[", table.tostr(Proto), "]")
    return ResultCode, Proto
end

REQUEST_New.TakeLuckBaoxiangTest = function (args)
    if  not args then
        return  RET_VAL.Empty_7, {}
    end

    if args.type==0 then
        ma_obj:refresh()
        ma_obj:addAdvNum()
        ma_obj:save()
    elseif args.type ==1 then
        ma_obj:refresh()
        ma_obj:ResetDailyData()
        ma_obj:save()
    elseif args.type == 2 then
        ma_obj:refresh()
        ma_obj:save()
        ma_obj:GetNextRefreshTime()
    elseif args.type == 1001 then
        eventx.call(EventxEnum.ActOpenExent, {actId=args.type})
    elseif args.type == 1002 then
        eventx.call(EventxEnum.ActOpenExent, {actId=args.type})
    elseif args.type == 3 then
        local check_args = {}
        check_args.uid = "1000001"
        check_args.name = ""
        check_args.cardId = ""
        local Authtion = AuthenticationPower.Power1
        local AuthenticationId = check_args.cardId
        local _err_code, r_status, r_pi  = skynet.call("real_name", "lua", "CheckRealName", check_args)
        if _err_code == RET_VAL.Succeed_1 then
            skynet.logd("TakeLuckBaoxiangTest::", ma_obj.uid, "r_status:[", r_status, "], r_pi=[", r_pi, "]")
        end
    elseif args.type == 4008 then
        eventx.call(EventxEnum.ActOpenExent, {actId=args.type})
    end

    return RET_VAL.Succeed_1
end

return ma_obj