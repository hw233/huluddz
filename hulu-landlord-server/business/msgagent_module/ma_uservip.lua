local skynet = require "skynet"
local eventx = require "eventx"

local datax  = require "datax"

local ma_data   = require "ma_data"
local ma_useritem       = require "ma_useritem"
local ma_common = require "ma_common"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local COLL = require "config/collections"
local cfgVip      = require "cfg.cfg_vip"
local cfgVipStore = require "cfg.cfg_vip_store"


local uid = nil
local userInfo = ma_data.userInfo

local CMD, REQUEST_New = {}, {}
local M = {}

----------------------------------------------
function M.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    uid      = userInfo.id

    M.InitData()
end


function M.InitData()

    M.isdebug = false

    if not userInfo.viplv_xl then
        userInfo.viplv_xl = 0
        dbx.update(COLL.USER, userInfo.id, {viplv_xl=userInfo.viplv_xl})
    end

    M.info = {
        vipexp   = userInfo.vipExp,
        viplv_xl = userInfo.viplv_xl,
        dayaward = {
            viplv    = 0,
            taketime = 0,
        }
    }

    local info = dbx.get(COLL.UserVipDayAward, {uid=userInfo.id}, {_id=false})
    if info then
        M.info.dayaward = info
    end

    eventx.listen(EventxEnum.UserOnline, function ()
        M.AddExp(0)
    end, eventx.EventPriority.Before)

    eventx.listen(EventxEnum.UserPay, function (num)
        M.AddExp(num / 10)
    end)
end

-- 根据exp 计算vip等级
function M.calculate_viplv(exp)
    local lv  = 0

    if cfgVip then
        for i, cfg in pairs(cfgVip) do
            if exp >= cfg.exp then
                lv = cfg.vip_level
            else break end
        end
    end

    return lv
end


-- 增加vip经验
function M.AddExp(val)
    if not val or val <0  or val >100000 then
        return false
    end

    userInfo.vipExp = userInfo.vipExp + val
    
    local old_vip = userInfo.vip
    userInfo.vip = M.calculate_viplv(userInfo.vipExp)
    dbx.update(COLL.USER, uid, {vip=userInfo.vip, vipExp=userInfo.vipExp})
    ma_common.updateUserBase(uid, {vip=userInfo.vip, vipExp=userInfo.vipExp})

    if old_vip < userInfo.vip then
        for i = old_vip + 1, userInfo.vip do
            local vipCfg = datax.vipGroup[i]
            if vipCfg and next(vipCfg.vip_avatar or {}) then
                ma_useritem.addList(vipCfg.vip_avatar, 1, "VipUp_VIP升级")
                ma_common.addMail(userInfo.id, 3001, "VipUp_VIP升级")
            end
        end

        --触发事件领取葫芦藤未领取的额外奖励
        eventx.call(EventxEnum.UserVipUpLv)
    end

    local Proto = {}
    Proto.vipinfo = {}
    Proto.vipinfo.exp = userInfo.vipExp
    Proto.vipinfo.level = userInfo.vip
    ma_data.send_push('SyncUserVipData', Proto)
    return true
end

-- 设置虚拟vip等级
function M.SetVipLv_XL(val)
    if not val or val <0 then
        return false
    end

    userInfo.viplv_xl = val
    dbx.update(COLL.UESR, uid, {viplv_xl=val})

    return true
end

function M.get_refresh_time()
    local d = os.date("*t", os.time())
    local refresh_h = 0
    if d.hour < refresh_h then
        return os.time({year=d.year, month=d.month, day=d.day-1, hour=refresh_h, min=0, sec=0})
    end
    return os.time({year=d.year, month=d.month, day=d.day, hour=refresh_h, min=0, sec=0})
end

function M.is_taked_dayaward()
    local dayaward = M.info.dayaward
    if userInfo.vip > 0 then
        local refresh_time = M.get_refresh_time()

        if dayaward.taketime < refresh_time then
            return false
        elseif dayaward.viplv < userInfo.vip then  -- 玩家vip升级了
            return false
        end

        return true
    end

    return false
end


-- vip商店购买, 现金购买 对sdk开放
function M.buy_item(args)
    local obj = {
        uid      = userInfo.id,
        goodsid  = 0,
        store_id = 0,
        buytime  = os.time(),
        ret      = RET_VAL.ERROR_3,
    }

    local goodsid = args.id
    if not goodsid then 
        obj.ret = RET_VAL.ERROR_3
        dbx.add(COLL.UserVipStoreBuy, obj)
        return obj.ret
    end
    obj.goodsid = goodsid

    -- cfg_vip_store
    local cfgvs = cfgVipStore[goodsid] 
    if not cfgvs then 
        obj.ret = RET_VAL.Other_10
        dbx.add(COLL.UserVipStoreBuy, obj)
        return obj.ret
    end
    obj.store_id = cfgvs.store_id

    local cfgs = datax.store[cfgvs.store_id]
    if not cfgs then 
        obj.ret = RET_VAL.Other_11
        dbx.add(COLL.UserVipStoreBuy, obj)
        return obj.ret
    end

    -- vip等级不够
    if userInfo.vip < cfgvs.need_vip_level then
        obj.ret = RET_VAL.Other_12
        dbx.add(COLL.UserVipStoreBuy, obj)
        return obj.ret
    end

    local t = 0
    if cfgvs.is_daily_times==1 then
        t = M.get_refresh_time()
    end

    -- 我已购买的次数
    local selector = { uid=userInfo.id, goodsid=goodsid, buytime={["$gte"] = t}}
    local buydatas = dbx.find(COLL.UserVipStoreBuy, selector, {_id=false})
    local buyct    = buydatas and #buydatas or 0

    if buyct >= cfgvs.buy_times then    -- 超过购买次数
        obj.ret = RET_VAL.Other_13
        dbx.add(COLL.UserVipStoreBuy, obj)
        return obj.ret
    end

    -- 人民币购买

    -- add item
    local sendDataArr = {}
    ma_useritem.addList(cfgs.rewards, 1, "Vip_BuyItem_vip商店购买", sendDataArr)
    ma_common.showReward(sendDataArr)

    obj.ret = RET_VAL.Succeed_1
    dbx.add(COLL.UserVipStoreBuy, obj)
    
    return obj.ret
end


----------------------------------------
-- 获取 vip 数据
REQUEST_New.Vip_GetInfo = function()
    local ret = {
        vipexp   = userInfo.vipExp,
        viplv_xl = userInfo.viplv_xl,
        istaked  = false,
        buycount = {}
    }

    -- 每日奖励
    ret.istaked = M.is_taked_dayaward()

    -- vip商店购买
    for i,cfg in pairs(cfgVipStore) do
        local t = 0
        if cfg.is_daily_times==1 then
            t = M.get_refresh_time()
        end
        local selector = { uid=userInfo.id, goodsid=cfg.id, buytime={["$gte"]=t} }
        local buydatas = dbx.find(COLL.UserVipStoreBuy, selector, {_id=false})
        local buyct = buydatas and #buydatas or 0
        table.insert(ret.buycount, buyct)
    end

    return RET_VAL.Succeed_1, ret
end


-- 测试接口  加vip经验
REQUEST_New.TestVip_AddExp = function(args)
    local val = args.val or 0

    if M.isdebug then
        return RET_VAL.Fail_2
    end

    local fok = M.AddExp(val)
    return RET_VAL.Succeed_1, { msg = "ok", vipexp = userInfo.vipexp, viplv = userInfo.vip}
end


--领取vip每日奖励
REQUEST_New.Vip_GetDayAward = function()

    if userInfo.vip<1 then
        return RET_VAL.ERROR_3
    end

    if M.is_taked_dayaward() then
        return RET_VAL.Fail_2
    end

    local dayaward = M.info.dayaward
    dayaward.viplv    = userInfo.vip
    dayaward.taketime = os.time()
    dbx.update_add(COLL.UserVipDayAward, {uid=userInfo.id}, M.info.dayaward)

    -- 发奖励
    local cfg = cfgVip[userInfo.vip+1]
    if cfg then
        local sendDataArr = {}
        ma_useritem.addList(cfg.daily_rewards, 1, "SVip_GetDayAward_vip每日奖励", sendDataArr)
        ma_common.showReward(sendDataArr)
    end

    return RET_VAL.Succeed_1
end


-- vip商店购买, 测试接口
REQUEST_New.TestVip_BuyItem = function(args)

    if M.isdebug then 
        return M.buy_item(args)
    end

    return RET_VAL.Fail_2
end


CMD.SetVip = function (source, vip)
    local sData = datax.vipGroup[vip]
    if not sData then
        return false
    end

    userInfo.vipExp = sData.exp

    M.AddExp(0)

    return true
end

-----------------------------------------
return M
