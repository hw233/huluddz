local skynet = require "skynet"
local ma_data = require "ma_data"
local ma_month_card = require "ma_month_card"
local cfg_global = require "cfg.cfg_global"
local COLLECTIONS = require "config/collections"
local M = {}
local aop = require "aop"
local module_state = aop.helper:make_state("ma_growth_plan")
local request = aop.helper:make_interface_tbl(module_state)
local cmd = {}

function M.flush()
    skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {growth_plan=ma_data.db_info.growth_plan})
end

--激活成长计划
--月卡条件替换成vip2
function request:growth_plan_active()
    local viplv = ma_data.get_vip()
    if viplv < 2 then
        return {result = 1}
    end
    --判断消耗是否足够
    local cfg = cfg_global[1]
    local needGoodsId = cfg.plan_need.id
    local needGoodsNum = cfg.plan_need.num
    if ma_data.get_goods_num(needGoodsId) < needGoodsNum then
        return {result = 2}
    end
    ma_data.add_goods_list({{id = needGoodsId, num = -needGoodsNum}},GOODS_WAY_GROWTH_ACTIVE,"成功计划激活消耗")
    ma_data.db_info.growth_plan.active = true

    M.flush()
    return {result = 0, data = ma_data.db_info.growth_plan}
end

--领取奖励
--self.index 奖励项
function request:get_growth_plan_award()
    --成长计划未激活
    if not ma_data.db_info.growth_plan.active then
        print("未激活")
        return {result = 1}
    end
    local cfg = cfg_growth_plan[self.index]
    if not cfg then
        print("奖励不存在")
        return {result = 2}
    end
    if ma_data.db_info.growth_plan.win_count < cfg.maxnum then
        print("未达到领取条件")
        return {result = 3}
    end
    
    if is_award_getted(ma_data.db_info.growth_plan.award_status,self.index) then
        print("奖励已领取")
        return {result = 4}
    end

    print("成功领取奖励")
    local awards = cfg_growth_plan[self.index].award
    local goods_list = {}
    table.insert(goods_list,{id = awards.id,num = awards.num})
    ma_data.add_goods_list(goods_list,GOODS_WAY_GROWTH_AWARD,"成长计划奖励 " .. self.index)

    set_award_getted(ma_data.db_info.growth_plan,"award_status",self.index)
    ma_data.send_push("buy_suc", {
        goods_list = goods_list,
        msgbox = 1
    })
    M.flush()
    return {result = 0, index = self.index}
end

function request:get_growth_plan_data()
    return {result = 0, data = ma_data.db_info.growth_plan}
end

--游戏胜利
function M.game_wind()
    ma_data.db_info.growth_plan.win_count = ma_data.db_info.growth_plan.win_count + 1
    skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {growth_plan=ma_data.db_info.growth_plan})
    ma_data.send_push("sync_growth_plan_info", {
        data = ma_data.db_info.growth_plan
    })
end

local cfg_conf = require "cfg_conf"
local function init_state()
    local subtype = 1002
    local tbl_match = {subtype = subtype}
    local conf = skynet.call(cfg_conf.DB_MGR, "lua", "find_one", cfg_conf.COLL.ACTIVITY_CONF, tbl_match)
    print("ma_growth_plan conf =>",  table.tostr(conf))
    module_state.init(conf)
end

function M.on_conf_update()
    init_state()
end

local function init()
    init_state()
    if not ma_data.db_info.growth_plan then
        ma_data.db_info.growth_plan = {active = false, win_count = 0, award_status = 0}
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

ma_data.ma_growth_plan = M

return M