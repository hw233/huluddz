local skynet = require "skynet"
local ma_data = require "ma_data"
local COLLECTIONS = require "config/collections"
local cmd = {}
local aop = require "aop"
local module_state = aop.helper:make_state("ma_month_sign")
local request = aop.helper:make_interface_tbl(module_state)
local M = {}

function M.refresh_data()
    ma_data.db_info.month_sign.status = 0
    ma_data.db_info.month_sign.c_award = 0
    ma_data.db_info.month_sign.mtime = os.time()
    M.flush()
end


function M.flush()
    skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {month_sign=ma_data.db_info.month_sign})
end

--连续签到一个月奖励发放
function M.full_month_award()
    local preContinueDays = 0
    local continueDays = 0
    local year,month = os.date("%Y", os.time()), os.date("%m", os.time())+1 -- 正常是获取服务器给的时间来算
    local dayAmount = os.date("%d", os.time({year=year, month=month, day=0})) -- 获取当月天数
    dayAmount = tonumber(dayAmount)
    --配置表配置的是31天的奖励
    for index = 1,dayAmount do
        if is_award_getted(ma_data.db_info.month_sign.status, index) then
            continueDays = continueDays + 1
        else
            if continueDays >= 7 and continueDays > preContinueDays then
                preContinueDays = continueDays
            end
            continueDays = 0
        end
    end
    if continueDays < preContinueDays then
        continueDays = preContinueDays
    end
    if continueDays == dayAmount then
        local rewards = cfg_month_sign[35].award
        if rewards then
            ma_data.add_goods_list(rewards, GOODS_WAY_M_SIGN_CONTINUE_AWARD, "连续签到奖励")
        end
    end
end

--获取签到数据
function request:sign_data()
	if not check_same_month(ma_data.db_info.month_sign.mtime) then
        --非当月
        M.refresh_data()
    end
    return {result = 0, c_award = ma_data.db_info.month_sign.c_award, status = ma_data.db_info.month_sign.status}
end

--补签
--self.day --补签第几天的
function request:endorsement()
    --不能补签当天
    if not check_same_month(ma_data.db_info.month_sign.mtime) then
        M.refresh_data()
    end
    local curday = tonumber(os.date("%d",os.time()))
    if self.day == curday then
        return {result = 1}
    end
    local year,month = os.date("%Y", os.time()), os.date("%m", os.time())+1 -- 正常是获取服务器给的时间来算
    local dayAmount = os.date("%d", os.time({year=year, month=month, day=0})) -- 获取当月天数
    dayAmount = tonumber(dayAmount)
    --没有这个天数
    if self.day < 0 or self.day > dayAmount then
        return {result = 2}
    end
    --已经签到过
    if is_award_getted(ma_data.db_info.month_sign.status, self.day) then
        return {result = 3}
    end
    local needGoods = cfg_month_sign[self.day].complement_sign

    --补签道具不足
    if needGoods==nil then
        return {result = 4}
    end
    --适应配置表结构问题
    needGoods = needGoods[1]
    if ma_data.get_goods_num(needGoods.id) < needGoods.num then
        return {result = 4}
    end
    ma_data.add_goods_list({{id = needGoods.id, num = -needGoods.num}},GOODS_WAY_M_SIGN_ENDORSEMENT,"月签到补签消耗")
    local rewards = cfg_month_sign[self.day].award
    
    set_award_getted(ma_data.db_info.month_sign,"status",self.day)
    
    -- local month_card_type = ma_data.ma_month_card.get_type()
    -- if month_card_type > 0 then
    --     local key = "multiple" .. month_card_type
    --     rewards = goods_list_mul(rewards,cfg_month_sign[self.day][key] / 10000)
    -- end

    --vip加成系数   
    local vip_ability = ma_data.get_vip_ability("sign30")
    -- print("VIP加成前",vip_ability)
    -- table.print(rewards)
    rewards = goods_list_mul(rewards,vip_ability / 10000)

    ma_data.add_goods_list(rewards, GOODS_WAY_M_SIGN_ENDORSEMENT, "月签到补签奖励")
    ma_data.send_push("buy_suc", {
        goods_list = rewards,
        msgbox = 1
    })
    M.flush()
    M.full_month_award()
    return {result = 0, day = self.day}
end

--领取连续签到奖励
--self.day (1:7天连续签到奖励,2:14天连续签到奖励,3:21天连续签到奖励,4:一个月连续签到奖励)
function request:get_continue_award()
    --print("get_continue_award", self.day)
    if not check_same_month(ma_data.db_info.month_sign.mtime) then
        M.refresh_data()
    end
    if self.day < 1 or self.day > 3 then
        return {result = 1,c_award = ma_data.db_info.month_sign.c_award}
    end
    local preContinueDays = 0
    local continueDays = 0
    local year,month = os.date("%Y", os.time()), os.date("%m", os.time())+1 -- 正常是获取服务器给的时间来算
    local dayAmount = os.date("%d", os.time({year=year, month=month, day=0})) -- 获取当月天数
    dayAmount = tonumber(dayAmount)
    --配置表配置的是31天的奖励
    for index = 1,dayAmount do
        if is_award_getted(ma_data.db_info.month_sign.status, index) then
            continueDays = continueDays + 1
        else
            if continueDays >= 7 and continueDays > preContinueDays then
                preContinueDays = continueDays
            end
            continueDays = 0
        end
    end
    if continueDays < preContinueDays then
        continueDays = preContinueDays
    end
    if continueDays < self.day * 7 then
        return {result = 2,c_award = ma_data.db_info.month_sign.c_award}
    end

    if is_award_getted(ma_data.db_info.month_sign.c_award, self.day) then
        return {result = 3,c_award = ma_data.db_info.month_sign.c_award}
    end
    set_award_getted(ma_data.db_info.month_sign,"c_award",self.day)
    --配置表中31天之后的奖励是连续签到的奖励
    local rewards = cfg_month_sign[31 + self.day].award
    if rewards then
        ma_data.add_goods_list(rewards, GOODS_WAY_M_SIGN_CONTINUE_AWARD, "连续签到奖励")
        ma_data.send_push("buy_suc", {
            goods_list = rewards,
            msgbox = 1
        })
    end

    -- if self.day == dayAmount then
    --     local rewards = cfg_month_sign[35].award
    --     if rewards then
    --         ma_data.add_goods_list(rewards, GOODS_WAY_M_SIGN_CONTINUE_AWARD, "连续签到奖励")
    --         ma_data.send_push("buy_suc", {
    --             goods_list = rewards,
    --             msgbox = 1
    --         })
    --     end
    -- end
    M.flush()
    return {result = 0, day=self.day,c_award = ma_data.db_info.month_sign.c_award}
end

function M.sign(day,Double)
    --print("M.sign ",day,Double)
    if not check_same_month(ma_data.db_info.month_sign.mtime) then
        M.refresh_data()
    end
    --与今天是否同一个
    local curday = tonumber(os.date("%d",os.time()))
    if day ~= curday then
        return {result = 1}
    end

    local year,month = os.date("%Y", os.time()), os.date("%m", os.time())+1 -- 正常是获取服务器给的时间来算
    local dayAmount = os.date("%d", os.time({year=year, month=month, day=0})) -- 获取当月天数
    dayAmount = tonumber(dayAmount)
    --没有这个天数
    if day < 0 or day > dayAmount then
        return {result = 2}
    end

    --已经签到过
    if is_award_getted(ma_data.db_info.month_sign.status, day) then
    
        return {result = 3}
    end

    local rewards = cfg_month_sign[day].award
    set_award_getted(ma_data.db_info.month_sign,"status",day)
    -- local month_card_type = ma_data.ma_month_card.get_type()
    -- if month_card_type > 0 then
    --     local key = "multiple" .. month_card_type
    --     rewards = goods_list_mul(rewards,cfg_month_sign[day][key] / 10000)
    -- end

    --vip加成系数   
    local vip_ability = ma_data.get_vip_ability("sign30")
    -- print("VIP加成前",vip_ability)
    -- table.print(rewards)
    rewards = goods_list_mul(rewards,vip_ability / 10000)
    -- print("VIP加成后")
    -- table.print(rewards)

    --看视频双倍领取金币
    if Double then
        currency_numX2(rewards)
    end
    ma_data.add_goods_list(rewards, GOODS_WAY_M_SIGN_AWARD, "月签到奖励")
    ma_data.send_push("buy_suc", {
        goods_list = rewards,
        msgbox = 1
    })
    M.flush()
    M.full_month_award()
    return {result = 0, day = day}
end

function cmd.sign(day)
    local Double = true
    local tmpTbl = M.sign(day,Double)
     ma_data.send_push('sign',tmpTbl)
end

--签到
--self.day 第几天签到
function request:sign()
    return M.sign(self.day,self.Double)
end

local cfg_conf = require "cfg_conf"
local function init_state()
    local subtype = 2001
    local tbl_match = {subtype = subtype}
    local conf = skynet.call(cfg_conf.DB_MGR, "lua", "find_one", cfg_conf.COLL.ACTIVITY_CONF, tbl_match)    
    print("ma_month_sign conf =>",  table.tostr(conf))
    module_state.init(conf)
end

function M.on_conf_update()
    init_state()
end

local function init()
    ma_data.follow_conf(M, cfg_conf.COLL.ACTIVITY_CONF)
    init_state()
    if not ma_data.db_info.month_sign then
        ma_data.db_info.month_sign = {}
        ma_data.db_info.month_sign.status = 0
        ma_data.db_info.month_sign.c_award = 0
        ma_data.db_info.month_sign.mtime = os.time()
    end
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
ma_data.ma_month_sign = M
return M