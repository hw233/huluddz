local skynet = require "skynet"
local eventx = require "eventx"

local ma_data = require "ma_data"
local ma_useritem = require "ma_useritem"
local GlobalCfg	   = require "ma_global_cfg"

local objx = require "objx"
local arrayx = require "arrayx"
local timex = require "timex"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"
local common = require "common_mothed"
local ma_user = require "ma_user"

require "define"
require "table_util"

local COLL = require "config/collections"
local TableNameArr = COLL

--#region 配置表 require
local cfg_friend_vaule = require "cfg.cfg_friend_vaule"
--#endregion

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local ma_obj = {
    lastFindDt = 0,
    recentGameFriendDatas = nil,
    
    MaxFriend = 100,
    MaxApply = 100,

    OpAgree  = 1,
    OpRefuse = 2,
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)


    local versionsKey = "2021.11.16 21:13"
    local obj = dbx.get(TableNameArr.UserFriendOther, userInfo.id) or {}
    if obj.versionsKey ~= versionsKey then
        obj.versionsKey = versionsKey

        obj.id = userInfo.id
        obj.chatDatas = obj.chatDatas or {}
        obj.recentGameFriendDatas = obj.recentGameFriendDatas or {}

        dbx.update_add(TableNameArr.UserFriendOther, userInfo.id, obj)
    end
    ma_obj.recentGameFriendDatas = obj.recentGameFriendDatas

    local obj = dbx.get(TableNameArr.UserFriendChat, userInfo.id, { id = true })
    if not obj then
        obj = {
            id = userInfo.id,
            data = {},
        }
        dbx.add(TableNameArr.UserFriendChat, obj)
    else

    end

    eventx.listen(EventxEnum.UserNewDay, function ()
        
    end)

    eventx.listen(EventxEnum.UserOnline, function ()
        ma_obj.FriendGiftAndNewApply({uid=userInfo.id})
    end)

    ma_obj.LoadData()
end


function ma_obj.LoadData()

    if not userInfo.location_open then
        local obj = {
            location_open    = false,
            location_sex     = 0,
            auto_gift        = true,
            not_accept_apply = false
        }
        table.connect(userInfo, obj)
        dbx.update(TableNameArr.USER, userInfo.id, obj)
    end

end

function ma_obj.UpdateGetGiftNum(reward_num)
    local current_time = os.time()
    function GetRefreshTime()
        local curr_date = os.date("%Y%m%d")
        local curr_date_year = tonumber(string.sub(curr_date,1,4))  
        local curr_date_month = tonumber(string.sub(curr_date,5,6)) 
        local curr_date_day = tonumber(string.sub(curr_date,7,8)) 

        local refresh_time = os.time({day=curr_date_day,month=curr_date_month,year=curr_date_year, hour = 5})
        if refresh_time < current_time then
            refresh_time = os.time({day=curr_date_day+1,month=curr_date_month,year=curr_date_year, hour = 5})
        end
        return refresh_time
    end

    local save = false
    local friend_gift_num = userInfo.friend_gift_num or 0
    local friend_gift_reset_at = userInfo.friend_gift_reset_at or 0
    if current_time > friend_gift_reset_at then
        friend_gift_num = 0
        friend_gift_reset_at = GetRefreshTime()
        save = true
    end

    if reward_num > 0 then
        friend_gift_num = friend_gift_num + reward_num
        save = true
    end
    if save then
        local updateD = {friend_gift_num=friend_gift_num, friend_gift_reset_at=friend_gift_reset_at}
        table.connect(userInfo, updateD)
        dbx.update(TableNameArr.USER, userInfo.id, updateD)
    end

    return {friend_gift_num=friend_gift_num, friend_gift_reset_at=friend_gift_reset_at}
end

function ma_obj.CheckGetGiftLimit()
    local maxgetgift = GlobalCfg.getValue(102001).val
    if userInfo.vip > 0 then
        maxgetgift = GlobalCfg.getValue(102005).val
    end

    local friend_gift_num = userInfo.friend_gift_num or 0
    return friend_gift_num >= maxgetgift
end
--#region 核心部分

ma_obj.toOnlineState = function(obj)
    return obj.online and (obj.roomState == UserRoomState.Gameing and 2 or 1) or 0
end

ma_obj.get_friend = function (fid)
    return dbx.get(TableNameArr.UserFriend, {id = userInfo.id, uId = fid})
end

ma_obj.get = ma_obj.get_friend

ma_obj.update = function (fid, updateObj)
    dbx.update(TableNameArr.UserFriend, {id = userInfo.id, uId = fid}, updateObj)
end

ma_obj.getDataArr = function (fields)
    local arr = dbx.find(TableNameArr.UserFriend, {id = userInfo.id}, fields)
    return arr
end

ma_obj.syncData = function (data)
    ma_common.send_myclient("SyncUserFriend", {data = data})
end

ma_obj.add = function (id)
    local selector = {id = id, uId = userInfo.id}
    local obj = dbx.get(TableNameArr.UserFriend, selector)
    if obj then
        return false
    end

    local target = ma_common.getUserBase(id, {online = true, offlineDt = true})
    obj = { 
        id = id,
        uId = userInfo.id,
        data = ma_common.toUserBase(userInfo),
        onlineState = ma_obj.toOnlineState(userInfo),
        offlineDt = userInfo.offlineDt,
        friendVal = 0,
        friendLv = 0,
        isSendGift = false,
        giftIndex = 0,
        addtime = os.time()     -- 加好友的时间
    }
    dbx.add(TableNameArr.UserFriend, obj)

    local obj1 = clone(obj)
    obj1.id = userInfo.id
    obj1.uId = id
    obj1.data = ma_common.toUserBase(target)
    obj1.onlineState = ma_obj.toOnlineState(target)
    obj1.offlineDt = target.offlineDt
    dbx.add(TableNameArr.UserFriend, obj1)

    ma_obj.syncData(obj)
    return true
end

ma_obj.remove = function (id)
    local selector = { id = id, uId = userInfo.id }
    local obj = dbx.get(TableNameArr.UserFriend, selector)
    if not obj then
        return false
    end

    dbx.del(TableNameArr.UserFriend, selector)
    dbx.del(TableNameArr.UserFriend, { id = userInfo.id, uId = id })

    return true
end


ma_obj.apply = function (id, fromType)
    if not id or not fromType  or id == userInfo.id then
        return false, RET_VAL.ERROR_3
    end

    local target = dbx.get(TableNameArr.User, id, { _id = false}) or common.getRobotInfo(id)
    if not target then
        return false, RET_VAL.Empty_7
    end

    ------------------------------
    -- 已经是好友
    local fd = dbx.get(TableNameArr.UserFriend, { id = userInfo.id, uId=id }, {id=true})
    if fd then
        return false, RET_VAL.Other_16
    end

    -- 最多100个好友， 超过则不能再申请
    local fds = dbx.find(TableNameArr.UserFriend, { uId = userInfo.id }, {id=true})
    if fds and #fds >= ma_obj.MaxFriend then
        return false, RET_VAL.Other_15
    end

    -- 不接受好友申请, zc
    if target.not_accept_apply or target.isRobot then
        return false, RET_VAL.Other_10
    end
  
    -- target 最多只能有100条申请  zc
    local applys = dbx.find(TableNameArr.UserFriendApply, {id=id}, {id=true})
    if applys and #applys>=ma_obj.MaxApply then
        return false, RET_VAL.Other_11   -- 对方申请列表已满
    end
  
    -- 每天最多申请100次   zc
    local d = os.date("*t", os.time())
    local t = os.time({year=d.year, month=d.month, day=d.day, hour=0, min=0, sec=0})
    local sele = { uId = userInfo.id, dt={["$gt"] = t}}
    local myapplys = dbx.find(TableNameArr.UserFriendApply, sele, {uId=true})
    if myapplys and #myapplys>=ma_obj.MaxApply then
        return false, RET_VAL.Other_12
    end

    -- 我在对方黑名单，申请失败
    local sel1 = {uid=id, blackuid=userInfo.id}
    local obj1 = dbx.get(TableNameArr.UserFriendBlackListTable, sel1, {blackuid=true})
    if obj1 then
        return false, RET_VAL.Other_13
    end

    -- 对方在我的黑名单，不能申请
    local sel2 = {uid=userInfo.id, blackuid=id}
    local obj2 = dbx.get(TableNameArr.UserFriendBlackListTable, sel2, {blackuid=true})
    if obj2 then
        return false, RET_VAL.Other_14
    end

    local selector = {uId = id, id = userInfo.id}
    local obj = dbx.get(TableNameArr.UserFriendApply, selector)
    if obj then
        return false, RET_VAL.Other_17
    end

    --------------------------------
     -- 已经申请过， 且对方未处理, 不能重复申请
    local now = os.time()

    selector = { uId = userInfo.id, id = id }
    obj = dbx.get(TableNameArr.UserFriendApply, selector)
    if not obj then
        obj = {
            uId = userInfo.id,
            id = id,
        }
    else
        if timex.equalsDay(now, obj.dt) then
            return false, RET_VAL.Exists_4  -- 今天已申请
        end
    end
  
    -----------------
    obj.data = ma_common.toUserBase(userInfo)
    obj.targetData = ma_common.toUserBase(target)
    obj.type = 0
    obj.fromType = fromType
    obj.dt = os.time()

    dbx.update_add(TableNameArr.UserFriendApply, selector, obj)

    if not common.call_useragent(obj.targetData.id, "FriendGiftAndNewApply", {uid=obj.targetData.id, targetId=userInfo.id, HasNewFriend = true}) then
        ma_obj.FriendGiftAndNewApply({uid=obj.targetData.id, targetId=userInfo.id, HasNewFriend = true})
    end

    if fromType == FriendFromType.RecentRoom then
        -- TODO:

    end

    return true, RET_VAL.Succeed_1
end


ma_obj.FriendGiftAndNewApply = function (args)
    if args.uid == userInfo.id then
        if args.HasNewFriend ~= nil and userInfo.HasNewFriend ~= args.HasNewFriend then
            userInfo.HasNewFriend = args.HasNewFriend
        end
        if args.HasFriendGift ~= nil and userInfo.HasFriendGift ~= args.HasFriendGift  then
            userInfo.HasFriendGift = args.HasFriendGift
        end
        
        --如果玩家今日收礼限制，不显示收礼红点
        if ma_obj.CheckGetGiftLimit() then
            if userInfo.HasFriendGift then
                userInfo.HasFriendGift = false
            end
            
            if args.HasFriendGift then
                args.HasFriendGift = false
            end
        end

        -- 发送消息
        if userInfo.HasNewFriend or userInfo.HasFriendGift then
            local syncData =  {}
            syncData.HasNewFriend = userInfo.HasNewFriend
            syncData.HasFriendGift = userInfo.HasFriendGift
            -- ma_data.send_push('SyncFriendGiftAndNewApply', syncData)
            ma_common.send_myclient_sure('SyncFriendGiftAndNewApply', syncData)
        end
    end

    ma_user.UpdateFriendGiftAndNewApplyToDB(args)
end


---comment
---@param dataArr table {{id = "", data = {}, playerType = 0}}
---@param gameType number
---@param roomLevel number
---@param dt number
ma_obj.addRecentGameFriend = function (dataArr, gameType, roomLevel, dt)
    local recentGameFriendDatas = ma_obj.recentGameFriendDatas
    local len = table.nums(recentGameFriendDatas)

    if len > 26 then
        local arr = arrayx.orderBy(table.toArray(recentGameFriendDatas), function (obj)
            return -obj.dt
        end)
        arr = arrayx.slice(arr, 1, 5 + #dataArr)

        local updateData = {}
        for index, value in ipairs(arr) do
            recentGameFriendDatas[value.id] = nil
            updateData["recentGameFriendDatas." .. value.id] = true
        end
        dbx.del_field(TableNameArr.UserFriendOther, userInfo.id, updateData)
    end

    local updateData = {}
    for key, data in pairs(dataArr) do
        local obj = {}
        obj.id = data.id
        obj.data = data.data
        obj.gameType = gameType
        obj.roomLevel = roomLevel
        obj.playerType = data.playerType
        obj.dt = dt

        recentGameFriendDatas[obj.id] = obj
        updateData["recentGameFriendDatas." .. obj.id] = obj
    end

    dbx.update(TableNameArr.UserFriendOther, userInfo.id, updateData)
end

ma_obj.checkResetGift = function ()
    local refresh_time = ma_obj.get_refresh_time()
    local select_data = {tarid=userInfo.id, gifttime={["$lt"] = refresh_time}}

    local del_dbgifts = dbx.find(TableNameArr.UserFriendGift, select_data)
    for i, d in pairs(del_dbgifts) do
        ma_obj.update(d.uid, {giftIndex = 0})
    end
    dbx.del(TableNameArr.UserFriendGift, {tarid=userInfo.id, gifttime={["$lt"] = refresh_time}})
end
--#endregion
function CMD.FriendGiftAndNewApply(_,args)
	ma_obj.FriendGiftAndNewApply(args)
end

REQUEST_New.GetUserFriendDatas = function ()
    ma_obj.checkResetGift()
    local refresh_time = ma_obj.get_refresh_time()
    local dbgifts = dbx.find(TableNameArr.UserFriendGift, {uid=userInfo.id, gifttime={["$gte"] = refresh_time}})
    
    local gifts = {}
    for i, d in pairs(dbgifts) do
        gifts[d.tarid] = true
    end

    local arr = dbx.find(TableNameArr.UserFriend, {id = userInfo.id}, {_id=false})

    local idArr = arrayx.select(arr, function (key, value)
        return value.uId
    end)
    local userArr = ma_common.getUserBaseArr(idArr)
    for i, uData in pairs(arr) do
        local issend = gifts[uData.uId] or false
        if uData.isSendGift ~= issend then
            uData.isSendGift = issend
            dbx.update(TableNameArr.UserFriend, {id = userInfo.id, uId = uData.uId}, {isSendGift=issend})
        end

        local dataBase = userArr[uData.uId]
        uData.data = dataBase or uData.data
        if dataBase then
            uData.onlineState = ma_obj.toOnlineState(dataBase)
            uData.offlineDt   = dataBase.offlineDt
        end
    end

    ma_obj.UpdateGetGiftNum(0)

    return {datas = arr}
end

REQUEST_New.GetUserRecentGameFriendDatas = function ()
    local datas = ma_obj.recentGameFriendDatas
    local idArr = arrayx.select(datas, function (key, value)
        return value.id
    end)
    local userArr = ma_common.getUserBaseArr(idArr)
    for index, value in pairs(datas) do
        value.data = userArr[value.id] or value.data
        value.isApply = not not dbx.get(TableNameArr.UserFriendApply, {uId = userInfo.id, id = value.id})
    end
    return {datas = datas}
end

REQUEST_New.FriendFind = function (args)
    local id = args.id

    if not id or id == userInfo.id then
        return RET_VAL.ERROR_3
    end

    local now = os.time()
    if now - ma_obj.lastFindDt < 5 then
        return RET_VAL.Fail_2
    end

    local user = dbx.get(TableNameArr.User, id)
    if not user then
        return RET_VAL.NotExists_5
    end

    local result = {}
    local data = ma_common.toUserBase(user)
    result.data = data
    result.onlineDt  = user.onlineDt
    result.offlineDt = user.offlineDt
    
    local targetPlayer = ma_common.getUserBase(id, {online = true, offlineDt = true})
    result.offlineDt = user.offlineDt
    if targetPlayer and targetPlayer.online then
        result.offlineDt = 0
    end

    result.isApply   = 0
    local target = dbx.get(TableNameArr.UserFriendApply, {uId = userInfo.id, id = id})
    if target then
        if timex.equalsDay(now, target.dt) then
            result.isApply = 1
        end
    end

    local fd = dbx.get(TableNameArr.UserFriend, {id = userInfo.id, uId = id })
    if fd then
        result.isApply = 2
    end

    return RET_VAL.Succeed_1, result
end

-- 获取我发起的申请好友的数据
REQUEST_New.GetUserFriendApplyDatas = function ()
    local arr = dbx.find(TableNameArr.UserFriendApply, {uId = userInfo.id}, nil, 100, {dt = -1})
    for i, v in pairs(arr) do
        v.data = v.targetData
    end
    return {datas = arr}
end

REQUEST_New.FriendRemove = function (args)
    ma_obj.remove(args.id)
    return RET_VAL.Succeed_1, args
end

REQUEST_New.ResetFriendGiftAndNewApply = function (args)
    if not args then
        return RET_VAL.Succeed_1, args
    end

    -- ma_obj.FriendGiftAndNewApply(args)
    local data = {uid=userInfo.id}
    if args.type == 1 then
        data.HasNewFriend = false
        ma_obj.FriendGiftAndNewApply(data)
    elseif args.type == 2 then
        data.HasFriendGift = false
        ma_obj.FriendGiftAndNewApply(data)
    end
    return RET_VAL.Succeed_1, data
end


REQUEST_New.FriendApply = function (args)
    local ok, val = ma_obj.apply(args.id, args.fromType)
    return val, {id=args.id}
end

REQUEST_New.FriendApplyHandler = function (args)
    local askIds  = args.idArr  -- 请求者uid
    local op      = args.type   -- 1同意，2忽略
    local isAll   = args.isAll

    if not op == ma_obj.OpAgree and not op == ma_obj.OpRefuse then
        return RET_VAL.ERROR_3
    end

    if not isAll and (not askIds or #askIds<1) then 
        return RET_VAL.ERROR_3
    end

    if isAll then
        -- 获取所有请求者uid
        local selector = { id = userInfo.id, type=0 }
        local askers = dbx.find(TableNameArr.UserFriendApply, selector, {uId=true})
        askIds = {}
        for i, v in pairs(askers) do
            table.insert(askIds,v.uId)
        end

    elseif askIds then
        -- 检测 type状态s
        for i, askid in ipairs(askIds) do
            local selector = { uId = askid, id = userInfo.id, type=0 }
            local target = dbx.get(TableNameArr.UserFriendApply, selector)
            if not target then
                return RET_VAL.NotExists_5
            end
        end
    end

    local myfct = 0
    if op == ma_obj.OpAgree  then
        -- 自己好友数  最多100个好友
        local datas = dbx.find(TableNameArr.UserFriend, { id = userInfo.id }, {id=true})
        if datas then myfct=#datas end
        --print("..............fct1:",myfct)

        if myfct >= ma_obj.MaxFriend then
            return RET_VAL.Other_10
        end
    end

    local doAskIds = {}

    if op == ma_obj.OpAgree then  -- 通过
        for i, askid in ipairs(askIds) do
            local fd = dbx.find(TableNameArr.UserFriend, { id =userInfo.id, uId=askid},{id=true})
            --table.print(fd)
            if fd and #fd>0 then
                -- 已经是好友了(这种情况:A申请B, B也申请A, A通过)
                local selector = { uId = askid, id = userInfo.id }
                dbx.del(TableNameArr.UserFriendApply, selector)
                table.insert(doAskIds, askid)
            else
                -- 对方的好友数
                local fct = 0
                local datas = dbx.find(TableNameArr.UserFriend, { id = askid }, {id=true})
                if datas then fct=#datas end
                --print("..............fct2:",fct)

                if fct < ma_obj.MaxFriend then
                    if ma_obj.add(askid) then 
                        local selector = { uId = askid, id = userInfo.id }
                        dbx.del(TableNameArr.UserFriendApply, selector)
                        table.insert(doAskIds, askid)
                        myfct = myfct+1 
                        if myfct >= ma_obj.MaxFriend then break end
                    end 
                end
            end
        end

    else -- 忽略
        doAskIds = askIds
        for i, askid in ipairs(askIds) do
            local selector = { uId = askid, id = userInfo.id }
            dbx.del(TableNameArr.UserFriendApply, selector)
        end
    end

    return RET_VAL.Succeed_1, {idArr=doAskIds, type=op, isAll=isAll}
end

function ma_obj.is_today(t)
    local now = os.time()
    local y,m,d = os.date("%y", now), os.date("%m",now), os.date("%d",now)
    local tt = os.time({year=y, month=m, day=d,hour="5"})
    if t >= tt then
        return true
    else 
        return false
    end
end

function ma_obj.get_refresh_time()
    local d = os.date("*t", os.time())
    local refresh_h = 0
    if d.hour < refresh_h then
        return os.time({year=d.year, month=d.month, day=d.day-1, hour=refresh_h, min=0, sec=0})
    end
    return os.time({year=d.year, month=d.month, day=d.day, hour=refresh_h, min=0, sec=0})
end

local function SendGift(fid, giftidx)
    local myid = userInfo.id
    local data = skynet.call("friend_manager", "lua", "FriendExpAdd", myid, fid, 1)

    data.isSendGift = true

    dbx.add(TableNameArr.UserFriendGift, {uid=myid, tarid=fid, gifttime=os.time()})
    dbx.update(TableNameArr.UserFriend, {id = myid, uId = fid}, {isSendGift=true})
    dbx.update(TableNameArr.UserFriend, {id = fid, uId = myid}, {giftIndex=giftidx})

    if not common.call_useragent(fid, "FriendGiftAndNewApply", {uid=fid, targetId=myid, HasFriendGift = true}) then
        ma_obj.FriendGiftAndNewApply({uid=fid, targetId=myid, HasFriendGift = true})
    end

    ma_obj.syncData(data)
end

-- 给好友送礼
-- gifttime 记录 UserFriendGift表， 防止送完之后再加，再送
REQUEST_New.FriendSendGift = function (args)
    local id, index = args.id, args.index

    local refresh_time  = ma_obj.get_refresh_time()
    -- 是否为好友
    local target = ma_obj.get_friend(id)
    if not target then
        return RET_VAL.NotExists_5
    end

    -- 已赠送
    local dbgift = dbx.get(TableNameArr.UserFriendGift, {uid=userInfo.id, tarid =id})
    if dbgift then
        if dbgift.gifttime >= refresh_time  then
            --print("---------------gifttime:",today5h, target.gifttime)
            return RET_VAL.Fail_2
        end
    end

    -- 检测今天总赠送次数
    local maxgift = GlobalCfg.getValue(102001).val
    if userInfo.vip > 0 then
        maxgift = GlobalCfg.getValue(102005).val
    end

    local sel = {uid = userInfo.id, gifttime={["$gt"] = refresh_time}}
    local arrtoday = dbx.find(TableNameArr.UserFriendGift, sel, {tarid=true})
    if arrtoday and #arrtoday >= maxgift then
        return RET_VAL.Other_10
    end


    local cfg = table.toObject(cfg_friend_vaule, function (key, value)
        return value.level
    end)
    local sData = cfg[target.friendLv]
    if not sData or not sData.unlock_items[index] then
        return RET_VAL.NoUse_8
    end
 
    SendGift(id, index)

    return RET_VAL.Succeed_1, {id=args.id}
end


function ma_obj.CheckAutoGift(refresh_time)
    if not userInfo.auto_gift then 
        return false, 0
    end

    -- 检测今天总赠送次数
    local maxgift = GlobalCfg.getValue(102001).val
    if userInfo.vip > 0 then
        maxgift = GlobalCfg.getValue(102005).val
    end

    local sel = {uid = userInfo.id, gifttime={["$gt"] = refresh_time}}
    local arrtoday = dbx.find(TableNameArr.UserFriendGift, sel, {uid=true})
    local left = maxgift - #arrtoday
    if left<1 then
        return false, 0
    end

    return true, left
end


REQUEST_New.FriendGetGift = function (args)
    local fids = args.idArr
    if not fids then 
        return RET_VAL.ERROR_3
    end

    local fdArr = {}
    for i, fid in pairs(fids) do
        local fd = ma_obj.get_friend(fid)
        if not fd then 
            return RET_VAL.NotExists_5
        end

        if fd.giftIndex == 0 then
            return RET_VAL.Other_9    -- 没有礼物
        end

        table.insert(fdArr, fd)
    end

    -- 获取配置
    local cfgFV = table.toObject(cfg_friend_vaule, function (key, value)
        return value.level
    end)
    if not cfgFV then
        return RET_VAL.ERROR_3 
    end
    --print_tb(cfgFV)

    if ma_obj.CheckGetGiftLimit() then
        return RET_VAL.Other_10
    end

    local takeIds = {}
    local giftArr = {}
    for i, fd in pairs(fdArr) do
        local cfg = cfgFV[fd.friendLv]
        if cfg and cfg.unlock_items and cfg.unlock_items[fd.giftIndex] then
            local gift = cfg.unlock_items[fd.giftIndex]
            table.insert(giftArr, gift)
            table.insert(takeIds, fd.uId)
            ma_obj.update(fd.uId, {giftIndex = 0})
            skynet.call("friend_manager", "lua", "FriendExpAdd", userInfo.id, fd.uId, 1)
        end
    end

    ma_obj.UpdateGetGiftNum(1)

    if #giftArr>0 then
        local sendDataArr = {}
        ma_useritem.addList(giftArr, 1, "FriendGetGift_领取好友礼物", sendDataArr)
        ma_common.showReward(sendDataArr)
    end

    -- 自动回礼
    local refresh_time = ma_obj.get_refresh_time()
    local autogift, left = ma_obj.CheckAutoGift(refresh_time)
    if autogift then
        for i, fd in pairs(fdArr) do
            if left<1 then break end

            local uid = userInfo.id
            local dbgift = dbx.get(TableNameArr.UserFriendGift, {uid=userInfo.id, tarid =fd.uId})
            if not dbgift or dbgift.gifttime < refresh_time then
                SendGift(fd.uId, fd.giftIndex)
                left = left-1
            end
        end
    end

    return RET_VAL.Succeed_1,{idArr=takeIds}
end

-- 聊天记录数据结构
-- local data = {
--     id = userInfo.id,
--     data = {
--         ["friendId"] = {
--             ["20211028"] = {
--                 ["1"] = {}, -- 每条消息
--                 ["2"] = {},
--             }
--         }
--     }
-- }

REQUEST_New.GetUserFriendChatDatas = function (args)
    local id = args.id

    local obj = dbx.get(TableNameArr.UserFriendChat, id, { ["data." .. id] = true })
    local data = {}
    for key, value in pairs(obj.data[id]) do
        data[key] = value
    end

    return {datas = data}
end

REQUEST_New.FriendChat = function (args)
    local id, content = args.id, args.content

    local to = ma_obj.get_friend(id)
    if not to then
        return RET_VAL.NotExists_5
    end

    --TODO:屏蔽字处理

    
    local obj = {
        id = objx.getUid_Time(),
        from = userInfo.id,
        content = content,
        dt = os.time()
    }
    dbx.update(TableNameArr.UserFriendChat, userInfo.id, { [ "data." .. id .. "." .. os.date("%Y%m%d") .. "." .. obj.id ] = obj })
    dbx.update(TableNameArr.UserFriendChat, id, { [ "data." .. userInfo.id .. "." .. os.date("%Y%m%d") .. "." .. obj.id ] = obj })

    --ma_common.send_client(id, "", { data = obj })

    return RET_VAL.Succeed_1
end

--设置不再接受好友申请     
REQUEST_New.Friend_SetNotAcceptFriendApply = function (args)
    local notaccept =  args.notaccept
    if notaccept == nil then notaccept = false end

    if userInfo.not_accept_apply ~= notaccept then
        userInfo.not_accept_apply = notaccept
        dbx.update(TableNameArr.USER, userInfo.id, {not_accept_apply=notaccept})
    end

    return RET_VAL.Succeed_1, {notaccept=notaccept}
end

-- 获取黑名单
REQUEST_New.Friend_GetBlackList = function ()

    local arr = dbx.find(TableNameArr.UserFriendBlackListTable, {uid = userInfo.id}, nil, 100)

    -- 查询玩家状态
    for i,v in pairs(arr) do
        local tar = dbx.get(TableNameArr.USER, {id=v.blackuid},{online=true, offlineDt=true} )
        if tar then 
            v.onlineState = tar.online and 1 or 0
            v.offlineDt   = tar.offlineDt
        end
    end
    return { datas = arr}
end


-- 拉黑好友
REQUEST_New.Friend_AddBlackList = function (args)
    local blackuid = args.blackuid

    if not blackuid then
        return RET_VAL.ERROR_3, {msg="no black uid"}
    end

    -- 是否有这个player
    local tar = dbx.get(TableNameArr.User, {id=blackuid}, {_id=false}) or common.getRobotInfo(blackuid)
    if not tar then
        return RET_VAL.ERROR_3, {msg="no player"}
    end

    -- 如果是好友，先解除好友关系
    ma_obj.remove(blackuid)

    -- add to blacklist
    local obj = {}
    obj.uid      = userInfo.id
    obj.blackuid = blackuid
    obj.blackdata   = ma_common.toUserBase(tar)
    obj.onlineState = tar.online and 1 or 0
    obj.offlineDt   = tar.offlineDt
    dbx.add(TableNameArr.UserFriendBlackListTable, obj)

    dbx.del(TableNameArr.UserFriendApply, {id = blackuid, uId=userInfo.id})
    return RET_VAL.Succeed_1, {msg="ok", newblack=obj}
end


-- 从黑名单移除     
REQUEST_New.Friend_RemoveBlackList = function (args)
    local blackuid         = args.blackuid
    local friendapply      = args.friendapply

    if not blackuid or  friendapply==nil then 
        return RET_VAL.ERROR_3, {msg="error param"}
    end

    dbx.del(TableNameArr.UserFriendBlackListTable, { uid = userInfo.id, blackuid = blackuid })

    -- 好友申请
    local ret = {
        e_info = RET_VAL.Succeed_1,
        msg = "ok",
        blackuid=blackuid,
        friendapply=args.friendapply
    }

    if friendapply then
        local ok, val = ma_obj.apply(blackuid, FriendFromType.Other)

        ret.e_info = val
        if not ok then
            ret.msg = "apply friend fail"
        end
    end

    return ret
end


--设置手机定位   
REQUEST_New.Friend_OpenPhoneLocation = function (args)
    local open = args.open
    local sex  = args.sex
    
    if open==nil or sex==nil or sex<0 or sex>2 then
        return RET_VAL.ERROR_3, {msg="error param"}
    end

    userInfo.location_open = open
    userInfo.location_sex  = sex
    dbx.update(TableNameArr.USER, userInfo.id, {location_open=open, location_sex=sex})

    return RET_VAL.Succeed_1, {msg="ok", open=open, sex=sex}
end



function Include_V(tb, val)
    for k,v in pairs(tb) do
        if v == val then return true end
    end
    return false
end

-- 获取同城附近玩家
REQUEST_New.Friend_GetNearbyPlayers = function ()

    -- 定位未开启
    if not userInfo.location_open then
        return RET_VAL.ERROR_3, {msg="location is closed" }
    end

--    local selector = {
--         location_open = true,
--         locale_city   = userInfo.locale_city,
--     }

    local selector = {initSet = true}
    if userInfo.location_sex ~= 0 then
        selector.gender = userInfo.location_sex
    end

    local sorter = {}
    local arrNearby = dbx.find(TableNameArr.USER, selector, nil, 200, sorter)


    -- 获取所有好友id
    local friends = dbx.find(TableNameArr.UserFriend, { uId = userInfo.id }, {id=true})
    local fids = {}     
    for i, v in pairs(friends) do
        table.insert(fids, v.id)
    end 

    -- 获取所有已申请id
    local applydatas = dbx.find(TableNameArr.UserFriendApply, {uId = userInfo.id}, {id=true}, 100)
    local applyids = {}
    for i, v in pairs(applydatas) do
        table.insert(applyids, v.id)
    end

    -- 排除掉已经是好友的
    local nearby = {}
    if fids and arrNearby then
        for i, uinfo in pairs(arrNearby) do
            if not Include_V(fids, uinfo.id) then
                if math.random(1, 100)<30 then 

                    local roomGameCountObj = table.max(uinfo.roomGameCountObj or {}, function (key, value)
                        return value.num
                    end)

                    local p = {}
                    p.uid            = uinfo.id
                    p.data           = ma_common.toUserBase(uinfo)
                    p.locale_city    = "杭州"    --uinfo.locale_city
                    p.isApply        = Include_V(applyids, uinfo.id)
                    p.distance       = 100 + math.random(500, 5000)
                    p.game           = roomGameCountObj and tonumber(roomGameCountObj.key) or GameType.SevenSparrow
                    table.insert(nearby, p)

                    if #nearby >10 then break end
                end
            end
        end
    end

    return RET_VAL.Succeed_1, {msg="ok", datas=nearby }
end

-- 获取向我申请好友的数据
REQUEST_New.Friend_GetApplyToMeDatas = function ()
    local arr = dbx.find(TableNameArr.UserFriendApply, {id = userInfo.id}, {_id=false}, 100, {dt = -1})
    local idArr = arrayx.select(arr, function (key, value)
        return value.uId
    end)

    local userArr = ma_common.getUserBaseArr(idArr)

    for i, uData in pairs(arr) do 
        local dataBase = userArr[uData.uId]
        uData.data = dataBase or uData.data
        if dataBase then
            uData.onlineState = ma_obj.toOnlineState(dataBase)
            uData.offlineDt   = dataBase.offlineDt
        end
    end
    return {datas = arr}
end


-- 获取好友系统相关设置
REQUEST_New.Friend_GetSettingInfo = function ()
    local obj = {}
    obj.auto_gift        = userInfo.auto_gift
    obj.not_accept_apply = userInfo.not_accept_apply
    obj.location_open    = userInfo.location_open
    obj.location_sex     = userInfo.location_sex

    return RET_VAL.Succeed_1, obj
end

-- 设置自动答谢
REQUEST_New.Friend_SetAutoGift = function (args)
    local auto = args.auto

    if not auto then auto=false end

    if userInfo.auto_gift ~= auto then
        userInfo.auto_gift = auto
        dbx.update(TableNameArr.USER, userInfo.id, {auto_gift=auto})
    end
    
    return RET_VAL.Succeed_1, {auto=auto}
end

return ma_obj