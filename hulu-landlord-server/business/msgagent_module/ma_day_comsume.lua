local skynet = require "skynet"
local ma_data = require "ma_data"
local COLLECTIONS = require "config/collections"
require "xy_tools"
local M = {}
local request = {}
local cmd = {}

--获取钻石连续消费记录
function request:diamond_ccomsume_data()
    M.refresh_data_check()
    return ma_data.db_info.d_diamond_c
end

--领取每日钻石连续消费奖励
--self.index 领取奖励索引
function request:diamond_ccomsume_award()
    M.refresh_data_check()
    if self.index <= 0  then
        return {result = 1}
    end
    if is_award_getted(ma_data.db_info.d_diamond_c.status, self.index) then
        return {result = 2}
    end
    local cfg = cfg_daily_consume[self.index]
    if not cfg then
        return {result = 1}
    end
    if ma_data.db_info.d_diamond_c.num < cfg.num then
        return {result = 3}
    end
    local award = cfg.awards

    set_award_getted(ma_data.db_info.d_diamond_c, "status", self.index)
    ma_data.add_goods_list(award,GOODS_WAY_DDIAMOND,tostring(self.index))
    -- table.print(ma_data.db_info.d_diamond_c)

    skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {d_diamond_c=ma_data.db_info.d_diamond_c})
    ma_data.send_push('buy_suc', {goods_list = award, msgbox = 1})
    return {result = 0, index = self.index}
end

--钻石消耗提醒
function M.comsume_diamond(num)
    if not check_same_day(ma_data.db_info.d_diamond_c.t) then
        ma_data.db_info.d_diamond_c.num = 0
        ma_data.db_info.d_diamond_c.status = 0
        ma_data.db_info.d_diamond_c.t = os.time()
    end
    ma_data.db_info.d_diamond_c.num = ma_data.db_info.d_diamond_c.num + num
    skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {d_diamond_c=ma_data.db_info.d_diamond_c})
    ma_data.send_push("sync_diamond_ccomsume_data", ma_data.db_info.d_diamond_c)
end

--积累充值奖励数据
function request:tdiamond_award_data()
    return {tdiamond = ma_data.db_info.all_diamond,status=ma_data.db_info.tdiamond_award.status}
end


--日连续充值消费记录
function request:recharge_ccomsume_data()
    M.refresh_data_check()
    return ma_data.db_info.d_fee_c
end

--领取日充值连续消费奖励
--self.index 领取奖励索引
function request:recharge_ccomsume_award()
    M.refresh_data_check()
    if self.index <= 0 then
        return {result = 1}
    end
    local cfg = cfg_daily_award[self.index]
    if not cfg then
        return {result = 1}
    end
    if self.index > ma_data.db_info.d_fee_c.num then
        return {result = 2}
    end
    if is_award_getted(ma_data.db_info.d_fee_c.status, self.index) then
        return {result = 3}
    end
    local award = cfg.award
    set_award_getted(ma_data.db_info.d_fee_c, "status", self.index)
    ma_data.add_goods_list(award,GOODS_WAY_DCHARGE,tostring(self.index))
    skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {d_fee_c=ma_data.db_info.d_fee_c})
    ma_data.send_push('buy_suc', {goods_list = award, msgbox = 1})
    return {result = 0, index = self.index}
end

function M.recharge_notify()
    M.refresh_data_check()
    local d_fee_c = ma_data.db_info.d_fee_c
    if (not check_same_day(d_fee_c.t)) and d_fee_c.num < 7 then
        d_fee_c.num = d_fee_c.num + 1
        d_fee_c.t = os.time()
        --通知客服端
        skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {d_fee_c=ma_data.db_info.d_fee_c})
        ma_data.send_push("sync_recharge_ccomsume_data", ma_data.db_info.d_fee_c)
    end
    ma_data.send_push("sync_all_fee", {all_diamond = ma_data.db_info.all_diamond})        
end

--对局宝箱数据更新
function request:match_box_data()
    M.refresh_data_check()
    return ma_data.db_info.match_box
end

--领取对局宝箱奖励
--self.index --领取第几项奖励
function request:match_box_award()
    if self.index <= 0 then
        return {result = 1}
    end
    local cfg = cfg_game_award[self.index]
    if not cfg then
        return {result = 1}
    end

    if is_award_getted(ma_data.db_info.match_box.status, self.index) then
        return {result = 2}
    end
    if ma_data.db_info.match_box.num < cfg.num then
        return {result = 3}
    end
    local award = cfg.award
    set_award_getted(ma_data.db_info.match_box, "status", self.index)
    local month_type = ma_data.ma_month_card.get_type()
    local fanNum = cfg_month_card["multiple"..month_type]
    if month_type > 0 then
        award = goods_list_mul(award,(fanNum/10000))
    end

    --vip加成系数   
    local vip_ability = ma_data.get_vip_ability("matchAward")
    --  print("VIP加成前",vip_ability)
    --  table.print(rewards)
    award = goods_list_mul(award,vip_ability / 10000)
    --  print("VIP加成后")
    --  table.print(rewards)

    ma_data.add_goods_list(award, GOODS_WAY_MATCH_BOX, tostring(self.index))

    skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {match_box=ma_data.db_info.match_box})
    ma_data.send_push('buy_suc', {goods_list = award, msgbox = 1})

    --记录数据
    for i,info in ipairs(award) do
        if info.id == COIN_ID then
            skynet.send('pay_info_mgr','lua','update_operation_info',nil,'matchBox',info.num)
            break
        end
    end
    return {result = 0, index = self.index}
end

function M.small_game_over()
     M.refresh_data_check()
     local match_box = ma_data.db_info.match_box
     match_box.num = match_box.num + 1
     skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {match_box=ma_data.db_info.match_box})
     ma_data.send_push("sync_match_box", ma_data.db_info.match_box)
end

function M.refresh_data_check()
    local syncData = {}
    local sync = false
    if not check_same_day(ma_data.db_info.d_diamond_c.t) then
        ma_data.db_info.d_diamond_c = {num=0,status=0,t=os.time()}
        syncData.d_diamond_c = ma_data.db_info.d_diamond_c
        sync = true
        -- skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {d_diamond_c=ma_data.db_info.d_diamond_c})
    end
    if not check_same_day(ma_data.db_info.match_box.t) then
        ma_data.db_info.match_box = {num=0,status=0,t=os.time()}
        syncData.match_box = ma_data.db_info.match_box
        sync = true
        -- skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {d_diamond_c=ma_data.db_info.d_diamond_c})
    end
    local d_fee_c = ma_data.db_info.d_fee_c
    local twoDayInterval = (os.time() > (d_fee_c.t + ONE_DAY)) and (not check_same_day(d_fee_c.t + ONE_DAY))
    if d_fee_c.t > 0 and (twoDayInterval or (d_fee_c.num >= 7 and (not check_same_day(d_fee_c.t))))then
    -- if not check_same_day(d_fee_c.t) then
        --间隔一天以上
        ma_data.db_info.d_fee_c = {num=0,status=0,t=0}
        syncData.d_fee_c = ma_data.db_info.d_fee_c
        sync = true
        -- skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {d_fee_c=ma_data.db_info.d_fee_c})
    end
    if sync then
        skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {syncData=syncData})
    end
end


local function init()
    if not ma_data.db_info.all_diamond then
        ma_data.db_info.all_diamond =0
    end
    if not ma_data.db_info.tdiamond_award then
        ma_data.db_info.tdiamond_award = {status=0}
    end
    if not ma_data.db_info.d_diamond_c then
        ma_data.db_info.d_diamond_c = {num=0,status=0,t=os.time()}
    end
    if not ma_data.db_info.d_fee_c then
        ma_data.db_info.d_fee_c = {num=0,status=0,t=0}
    end
    if not ma_data.db_info.match_box then
        ma_data.db_info.match_box = {num=0,status=0,t=os.time()}
    end
    M.refresh_data_check()
end

function M.init(REQUEST, CMD)
    if request then
        table.connect(REQUEST, request)
    end
    if cmd then
        table.connect(CMD, cmd)
    end
    init()
end

ma_data.ma_day_comsume = M

return M


