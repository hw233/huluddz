local skynet = require "skynet"
local eventx = require "eventx"
local ec = require "eventcenter"
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

-- local globalId = 0
local cfg_data = {
}

local TitleStatus = {
    Unknown = 0,
    Own = 5, --已拥有
    Using = 10, --使用中
    -- Expire = 15, --已过期
}
local AchType = {
    Type1 = 1, --游戏生涯
    Type2 = 2, --精彩瞬间
    Type3 = 3, --趣味时刻
}

local ma_obj = {
    id = 0,
    Data = nil,
    SFlag = false
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.id = userInfo.id
    ma_obj:initListen()
    -- ma_obj:load() --加载数据
    -- ma_obj:refresh() --刷新
end


function ma_obj:CreateRecord()
    local data = {
        TitleList = {}, --称号列表
        AchList = {}, --成就值
        LoginAt = {}, --连续登陆
        PlayData = {conWin = 0, lastConwin = 0, lastSign = 0, conLose = 0, hisDoubleMax = 0, hisConWinMax = 0, hisClearPlayer = 0, hisSpringNum = 0}, --连胜连败纪录
    }
    return data
end

function ma_obj:load()
    self.SFlag = false
    if not self.Data  then
        -- 获取所有请求者uid
        local data = dbx.find_one(TableNameArr.UserAchievement, self.id)
        if not data then
            self.Data = self:CreateRecord()
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
        dbx.update_add(TableNameArr.UserAchievement, self.id, self.Data)
    end
end

function ma_obj:refresh()
    local currentAt = os.time()
    for _, _titleD in pairs(self.Data.TitleList) do
        if _titleD.status == TitleStatus.Using or _titleD.status == TitleStatus.Own then
            if _titleD.expAt ~= -1 and currentAt.expAt < currentAt then
                if _titleD.status == TitleStatus.Using then
                    eventx.call(EventxEnum.UserUseTitle, {id = _titleD.id, isUp = false})
                end
                _titleD.status = TitleStatus.Unknown
                self.SFlag = true
            end
        end
    end
end


function ma_obj:initListen()
    eventx.listen(EventxEnum.UserOnline, function ()
        self:load()
        self:refresh()
        
        local curr_date = os.date("%Y%m%d")
        local curr_date_year = tonumber(string.sub(curr_date,1,4))  
        local curr_date_month = tonumber(string.sub(curr_date,5,6)) 
        local curr_date_day = tonumber(string.sub(curr_date,7,8)) 
        local yesterday = os.date("%Y%m%d", os.time({day=curr_date_day-1,month=curr_date_month,year=curr_date_year}))
        if self.Data.LoginAt[curr_date] then
            return
        end
        if not self.Data.LoginAt[yesterday] then
            self.Data.LoginAt = {}
        end
        self.Data.LoginAt[curr_date] = true
        self.SFlag = true
        local dayNum = 0
        for key, value in pairs(self.Data.LoginAt) do
            dayNum = dayNum + 1
        end

        eventx.call(EventxEnum.UserLoginContinue, dayNum)
        self:save()
    end)

    eventx.listen(EventxEnum.RoomGameOver, function (gameType, eventObj)
        if not eventObj then 
            return
        end
        self:load()
        self:refresh()
        self:GameWin(eventObj.isWin)

        --清空对手
        if eventObj.playerDataOtherArr then
            for _, otherData in pairs(eventObj.playerDataOtherArr) do
                if otherData.tag == RoomPlayerOverTag.Broke then --破产
                    self.Data.PlayData.hisClearPlayer = (self.Data.PlayData.hisClearPlayer or 0) + 1
                end
            end
        end


        if (eventObj.playerData.multiple or 0) > (self.Data.PlayData.hisDoubleMax or 0) then
            self.Data.PlayData.hisDoubleMax = eventObj.playerData.multiple
        end

        self:save()
    end)

    eventx.listen(EventxEnum.AddAchievement, function (args)
        --local args = {id = id, addValue = addValue}
        self:load()
        self:refresh()

        local sumValue = 0
        for _id, _data in pairs(self.Data.AchList) do
            if _data then
                sumValue = sumValue + (_data.val or 0)
            end
        end

        local cfgTitleList = datax.title
        for _, _cfg_data in pairs(cfgTitleList) do
            if _cfg_data.title_group == 1 then
                if _cfg_data.need_points <= sumValue then
                    if not self:checkTitle(tostring(_cfg_data.id)) then
                        self:addTitile(_cfg_data.id, -1)
                    end
                end
            end
        end
        self:save()

        --推送客户端
        local proto =  self:GetProto()
        ma_data.send_push('SyncAchievent', proto)

        skynet.call("ranklistmanager", "lua", "update_cj",
            userInfo.id, userInfo.nickname, userInfo.head, userInfo.headFrame, sumValue, args.addValue, userInfo.title)
    end)

    --
    eventx.listen(EventxEnum.ProtectWinStreak, function (args)
        self:load()
        self:refresh()
        self:ProtoLastConWin()
        self:save()
    end)

    ec.sub({type = EventCenterEnum.RoomGameSpring, id = userInfo.id}, function (eventObj)
        self:load()
        self:refresh()
        self.Data.PlayData.hisSpringNum = (self.Data.PlayData.hisSpringNum or 0) + 1
        self.SFlag = true
        self:save()
    end)

end

function ma_obj:checkTitle(id)
    local actData = self.Data.TitleList[id]
    if actData then
       return true
    end
    return false
end

function ma_obj:GameWin(isWin)

    if not self.Data.PlayData then
        self.Data.PlayData = {conWin = 0, lastWin = false, conLose = 0}
    end

    if isWin then
        if not self.Data.PlayData.lastWin then
            self.Data.PlayData.conWin = 0
        end

        self.Data.PlayData.lastWin = true
        self.Data.PlayData.conWin = self.Data.PlayData.conWin + 1

        --连胜保护要用到该字段
        if not self.Data.PlayData.lastConwin then
            self.Data.PlayData.lastConwin = 0
        end
        self.Data.PlayData.lastConwin = self.Data.PlayData.conWin
        --连胜保护要用到该字段end

        if (self.Data.PlayData.hisConWinMax or 0) < self.Data.PlayData.conWin then
            self.Data.PlayData.hisConWinMax = self.Data.PlayData.conWin
        end
        self.Data.PlayData.conLose = 0
        if self.Data.PlayData.conWin >= 10 then
            eventx.call(EventxEnum.UserConWinOrLose, isWin, self.Data.PlayData.conWin)
        end
    else
        if self.Data.PlayData.lastWin then
            self.Data.PlayData.conLose = 0
        end

        self.Data.PlayData.lastWin = false
        self.Data.PlayData.conLose = self.Data.PlayData.conLose + 1
        self.Data.PlayData.conWin = 0
        if self.Data.PlayData.conLose >= 10 then
            eventx.call(EventxEnum.UserConWinOrLose, isWin, self.Data.PlayData.conLose)
        end
    end
    self.SFlag = true
end

--添加成就值
function ma_obj:addAchievement(id, addValue)
    id = tostring(id)

    local actData = self.Data.AchList[id]
    if not actData then
        actData = {id = id, val = 0 }
        self.Data.AchList[id] = actData
    end
    actData.val = actData.val + addValue
    if actData.val < 0 then
        actData.val = 0
    end
    self.SFlag = true
    self:save()

    local args = {id = id, addValue = addValue, val = actData.val}
    eventx.call(EventxEnum.AddAchievement, args)
end

--添加称号
function ma_obj:addTitile(id, expireAt)
    id = tostring(id)
    local titleData = self.Data.TitleList[id]
    if not titleData then
        titleData = {id = id, status = TitleStatus.Unknown, expAt = 0}
        self.Data.TitleList[id] = titleData
    elseif titleData.expAt == -1 then --永久道具不可以重复添加
        return
    end
 
    titleData.status = TitleStatus.Own
    local currentTime = os.time()
    if expireAt == -1 then
        titleData.expAt = -1
    elseif titleData.expAt <= currentTime then
        titleData.expAt = currentTime + expireAt
    else
        titleData.expAt = titleData.expAt + expireAt
    end
    self.SFlag = true
    self:save()
end

--使用称号
function ma_obj:UseTitile(id, isUp)
    id = tostring(id)
    local titleData = self.Data.TitleList[id]
    if isUp then
        if not titleData then
            return false
        end

        if titleData.status ~= TitleStatus.Own then
            return false
        end
    end

    for _, _titleD in pairs(self.Data.TitleList) do
        if _titleD.status == TitleStatus.Using then
            _titleD.status = TitleStatus.Own
        end
    end

    if isUp then
        titleData.status = TitleStatus.Using
    end
    self.SFlag = true
    self:save()
    eventx.call(EventxEnum.UserUseTitle, {id = id, isUp = isUp})
    return true
end

function ma_obj:loadAndAddAchievement(id, addValue)
    self:load()
    self:refresh()
    self:addAchievement(id, addValue)
    self:save()
end

function ma_obj:loadAndAddTitle(id, expireAt)
    self:load()
    self:refresh()
    self:addTitile(id, expireAt)
    self:save()
end

function ma_obj:ProtoLastConWin()
    if self.Data.PlayData.lastConwin and self.Data.PlayData.lastConwin > 0  then
        self.Data.PlayData.conWin = self.Data.PlayData.lastConwin
        self.Data.PlayData.lastWin = true
        self.SFlag = true
    end
end

function ma_obj:GetProto()
    local proto = {}
    proto.AchDataList = {}

    local index = 1
    for key, _data in pairs(ma_obj.Data.AchList) do
        proto.AchDataList[index] = _data
        index = index + 1
    end
    proto.AchiTitleDataList = {}
    index = 1
    for key, _data in pairs(ma_obj.Data.TitleList) do
        proto.AchiTitleDataList[index] = _data
        index = index + 1
    end

    proto.AchPlayerData = self.Data.PlayData
    return proto
end

REQUEST_New.GetAchievent = function (args)
    ma_obj:load()
    ma_obj:refresh()
    ma_obj:save()

    local proto =  ma_obj:GetProto()
    return RET_VAL.Succeed_1, proto
end

REQUEST_New.UseAchieventTitle = function (args)
    if  not args or not args.titleId then
        return  RET_VAL.Fail_2
    end

    --领取任务
    if args.taskId and tonumber(args.taskId) > 0 then
        eventx.call(EventxEnum.TaskReward, tonumber(args.taskId))
    end

    ma_obj:load()
    ma_obj:refresh()
    if not ma_obj:UseTitile(args.titleId, args.UpOrDown == 0) then
        return RET_VAL.ERROR_3
    end

    ma_obj:save()
    local proto =  ma_obj:GetProto()
    proto.titleId = args.titleId
    if args.UpOrDown == 1 then
        proto.titleId = "0"
    end
    return RET_VAL.Succeed_1, proto
end

-- 36 -- 37 -- 38 -- 39 -- 40 -- 41 -- 42 -- 43 -- 44 -- 45 -- 46
-- 47 -- 49 -- 52 -- 53 -- 54 -- 55 -- 56 -- 57 -- 58 -- 59 -- 60
-- 61 -- 62 -- 63 -- 64 -- 65 -- 66 -- 67 -- 68 -- 69 -- 70 -- 71
-- 72 -- 73 -- 74 -- 75 -- 76 -- 77 -- 78


return ma_obj