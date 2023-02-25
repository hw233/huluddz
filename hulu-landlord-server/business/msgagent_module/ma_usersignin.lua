local skynet = require "skynet"

local ma_data      = require "ma_data"
local Bag          = require "ma_useritem"
local ma_common    = require "ma_common"
local GlobalCfg	   = require "ma_global_cfg"

local datax = require "datax"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)

local cfgSignIn = require "cfg.cfg_sign_in"
local cfgRune   = require "cfg.cfg_rune"
local arrayx = require "arrayx"
local COLL = require "config/collections"
local eventx = require "eventx"
local uid = nil; 
local AdvType = {
    Luck3Bei=1, 
    LuckBuqian=2, 
}

local CMD, REQUEST_New = {}, {}
local userInfo = ma_data.userInfo

----------------------------------------------
local ma_obj = {

    -- patchcount                   -- 本月补签次数
    -- video3count                  -- 今天video3倍签到次数， 一天一次
    -- signlog = {}                 -- 签到记录
    -- progressawardtakelog = {}    -- 进度奖领取记录
    -- optime                       -- 操作time
    mData = {},

    isLoaded = false;       --是否已加载
}



function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    uid = ma_data.db_info.id
    ma_obj.InitData()
    ma_obj.LoadData()

    eventx.listen(EventxEnum.AdvertLook, function (sdata, args)
        if not sdata or not args then
            return
        end
        local _type = sdata.type
        if _type == AdvType.Luck3Bei or _type == AdvType.LuckBuqian then
            local new_args = {}
            new_args.patchday = tonumber(args.patchday)
            if args.ispatch == "true" then
                new_args.ispatch = true
            else
                new_args.ispatch = false
            end
    
            if args.isvideo3 == "true" then
                new_args.isvideo3 = true
                local curr_date = os.date("%Y%m%d")
                new_args.patchday = curr_date.day
            else
                new_args.isvideo3 = false
            end
    
            local _, Proto = REQUEST_New.SignIn_Sign(new_args)
            ma_data.send_push('SyncSignIn_Sign', Proto)
        end

    end)

end

function ma_obj.InitData()
    ma_obj.mData = {}
    ma_obj.mData.patchcount = 0
    ma_obj.mData.video3count = 0
    ma_obj.mData.signlog = {}
    ma_obj.mData.progressawardtakelog = {}
    ma_obj.mData.optime = os.time()
    ma_obj.mData.video3At = ma_obj.mData.optime
end

function ma_obj.LoadData()
    if ma_obj.isLoaded then return end

    ma_obj.InitData()
    ma_obj.LoadFromDB()

    ma_obj.isLoaded = true
end


function ma_obj.LoadFromDB()
    print("................Sign in LoadFromDB")
    local selectObj = { uid = uid }
    local data = dbx.get(COLL.UserSignInTable, selectObj)
    if data then
        --print_tb(data)
        ma_obj.mData.patchcount  = data.patchcount
        ma_obj.mData.video3count = data.video3count
        ma_obj.mData.signlog     = data.signlog
        ma_obj.mData.progressawardtakelog = data.progressawardtakelog
        ma_obj.mData.optime = 0
        if data.optime then
            ma_obj.mData.optime = data.optime
        end
        if data.video3At then
            ma_obj.mData.video3At = data.video3At
        end
    else
        -- add
        local d = { uid = uid, }
        table.connect(d, ma_obj.mData)
        --print("------------------add to db")
        --print_tb(d)
        dbx.add(COLL.UserSignInTable, d)
    end
end


function ma_obj.IsSigned(day)
    for i, v in pairs(ma_obj.mData.signlog) do
        if day == v then return true end
    end

    return false
end

function ma_obj.IsTaked(awardid)
    for i, v in pairs(ma_obj.mData.progressawardtakelog) do
        if awardid == v then return true end
    end

    return false
end


function ma_obj.IsNextMonth()
    local m    = os.date("%m", ma_obj.mData.optime)
    local curm = os.date("%m", os.time())
    if m ~= curm then 
        return true
    else 
        return false 
    end
end

-- 进入下一个月
function ma_obj.NextMonth()
    print("------------------signin NextMonth")
    -- 其他处理

    -- 重置数据
    ma_obj.InitData()
    dbx.update(COLL.UserSignInTable, { uid = uid }, ma_obj.mData )
end

function ma_obj.IsNextDay()
    if not ma_obj.mData then
        return false
    end

    local video3At = os.date("%Y%m%d", ma_obj.mData.video3At or 0)
    local curAt = os.date("%Y%m%d", os.time())
    return video3At ~= curAt
end

-- 进入下一天
function ma_obj.NextDay()
    -- print("------------------signin NextDay")
    -- 重置数据
    if ma_obj.mData then
        ma_obj.mData.video3count = 0
        ma_obj.mData.video3At = os.time()
        dbx.update(COLL.UserSignInTable, { uid = uid }, ma_obj.mData )
    end
end


------------------------------------------------
-- 获取相关信息
REQUEST_New.SignIn_GetInfo = function()
    ma_obj.LoadData();

    if ma_obj.IsNextMonth() then 
        ma_obj.NextMonth();
    end
    if ma_obj.IsNextDay() then
        ma_obj.NextDay()
    end

    local ret = {e_info=RET_VAL.Succeed_1}
    table.connect(ret, ma_obj.mData)
    return ret
    --return RET_VAL.Succeed_1, ma_obj.mData
end



-- 签到
REQUEST_New.SignIn_Sign = function(args)
    if ma_obj.isLoaded == false then
        return RET_VAL.ERROR_3, {msg="load data first"}
    end

    if ma_obj.IsNextMonth() then 
        ma_obj.NextMonth();
        -- send SignIn_GetInfo to client
        return RET_VAL.ERROR_3, {msg="net month"}
    end

    local ispatch = args.ispatch
    local isvideo3 = args.isvideo3
    local patchday = args.patchday

    local day = tonumber(os.date("%d", os.time()))
    local mult  = 1       -- 奖励倍数

    if ispatch then
        -- check patch count
        local maxct = GlobalCfg.getValue(106001).val
        if ma_obj.mData.patchcount >= maxct then
            return RET_VAL.Fail_2, {msg="max patchcount"}
        end

        if not patchday or patchday<0 or patchday >= day then
            return RET_VAL.ERROR_3, {msg="error patch day"..tostring(patchday)}
        end
        
        -- 是否已签过
        if ma_obj.IsSigned(patchday) then
            return RET_VAL.Exists_4, {msg="already signed"}
        end

        day = patchday
        ma_obj.mData.patchcount = ma_obj.mData.patchcount+1
        table.insert(ma_obj.mData.signlog, day)

    else
        if isvideo3 then
            --今天是否签过, 普通签过后才可以 video3倍签
            if ma_obj.IsSigned(day) == false then
                return RET_VAL.NotExists_5, {msg="donot normal sign"}
            end

            -- 是否已经3倍签
            local v3ct = ma_obj.mData.video3count
            if v3ct >=1 then
                return RET_VAL.NoUse_8, {msg="video3 >=1"}
            end

            mult = 3
            ma_obj.mData.video3count = v3ct + 1

        else   -- 当天签到
            -- 今天是否签过
            if ma_obj.IsSigned(day) then
                return RET_VAL.Exists_4, {msg="already signed"}
            end

            table.insert(ma_obj.mData.signlog, day)
        end
    end
    --print("------------", day)
    --print_tb(cfgSignIn[day])
    --print("-------------")
    --print_tb(ma_obj.mData)
    -- update db
    local selectObj = { uid = uid }
    local ret = dbx.update(COLL.UserSignInTable, selectObj, ma_obj.mData )
    --print_tb(ret)

    -- 计算 vip, 符文 加成
    local awards = table.clone(cfgSignIn[day].sign_rewards)
    local xxdIdx = 0
    for i, item in pairs(awards) do
        if item.id == 10002 then 
            xxdIdx = i;
            break;
        end
    end

    if xxdIdx >0 then

        local xxdnum = awards[xxdIdx].num

        -- vip 嘻嘻豆加成 10002
        local viplv = 0
        local vipadd = ma_common.getVipCfg().sign_in_add
        awards[xxdIdx].num = awards[xxdIdx].num + math.floor(xxdnum*vipadd/10000)

        -- 符文 嘻嘻豆加成  打卡符文50009  -- 需要符文模块配合，后面再完善
        -- local cfgr = cfgRune[50009]
        -- local runelv = 0
        -- local runebase = cfgr.rune_basal_value.value
        -- local runeadd  = runebase + cfgr.rune_level_value.value * runelv
        -- awards[xxdIdx].num = awards[xxdIdx].num + math.floor(xxdnum*runeadd/10000)


    end

    -- add item to bag
    local rewardInfo = {}
    local sendDataArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Default)
    Bag.addList(awards, mult, "SignIn_Sign_签到获得", sendDataArr)
    -- Bag.addList(awards, mult, "SignIn_Sign_签到获得", sendDataArr)

    --加成
    local bonusObj = userInfo.bonusObj or {}
    if bonusObj.rune then
        local goldRate = (bonusObj.rune[BonusType.SignInGold] or 0)
        if goldRate > 0 then
            local goldItem = arrayx.find(awards, function (index, value)
                return value.id == ItemID.Gold
            end)
            if goldItem then
                goldItem.num = goldItem.num * goldRate // 10000
                if goldItem.num > 0 then
                    local runeAddItemArr = ma_common.getShowRewardArr(rewardInfo, ShowRewardFrom.Rune)
                    Bag.addList({goldItem}, 1, "SignIn_Sign_签到获得符文加成", runeAddItemArr)
                end
            end

        end
    end

    -- 客户端需求，延后，不能被引导挡住
    if next(rewardInfo) then
        skynet.fork(function ()
            ma_common.showReward(rewardInfo)
        end)
    end
    return RET_VAL.Succeed_1, {msg="ok", signday=day, isvideo3=isvideo3}
end


--领取进度奖励
REQUEST_New.SignIn_TakeProgressAward = function(args)

    if ma_obj.IsNextMonth() then 
        ma_obj.NextMonth();
        -- send SignIn_GetInfo to client
        return RET_VAL.ERROR_3, {msg="net month"}
    end

    if ma_obj.isLoaded == false then
        return RET_VAL.ERROR_3, {msg="load data first"}
    end

    local awardid = args.awardid

    if not awardid or awardid < 1 or awardid >#cfgSignIn then
        return RET_VAL.ERROR_3, {msg="param error"}
    end

    if #cfgSignIn[awardid].continuous_sign_rewards < 1 then
        return RET_VAL.Fail_2, {msg="no award"}
    end

    -- 签到天数不够
    if #ma_obj.mData.signlog < awardid then
        return RET_VAL.Lack_6, {msg="sign not enough"}
    end

    -- 是否领取过
    if ma_obj.IsTaked(awardid) then
        return RET_VAL.Exists_4, {msg="already taked"}
    end

    table.insert(ma_obj.mData.progressawardtakelog, awardid)
    -- update db
    local selectObj = { uid = uid }
    dbx.update(COLL.UserSignInTable, selectObj, ma_obj.mData )

    -- add item to bag
    local sendDataArr = {}
    Bag.addList(cfgSignIn[awardid].continuous_sign_rewards, 1, "SignIn_TakeProgressAward_签到进度奖励", sendDataArr)
    ma_common.showReward(sendDataArr)

    return RET_VAL.Succeed_1, {msg="ok", awardid=awardid}
end

-------------------------------------------------
return ma_obj