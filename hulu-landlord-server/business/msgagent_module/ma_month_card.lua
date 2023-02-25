local skynet = require "skynet"
local ma_data = require "ma_data"

local COLLECTIONS = require "config/collections"
local aop = require "aop"
local module_state = aop.helper:make_state("ma_month_card")
local request = aop.helper:make_interface_tbl(module_state)
local M = {}
local cmd = {}

--判断月卡剩余领取次数
local function cal_month_card_left_count()
    local month_card = ma_data.db_info.month_card
    if month_card.type <= 0 then
        return 0
    end
    local end_time = month_card.begin_time + month_card.total_day * ONE_DAY
    if os.time() > end_time or check_same_day_2(end_time, month_card.get_time) or month_card.get_time > end_time then
        return 0
    end
    local reftime = os.time()
    if check_same_day(month_card.get_time) then
        --以一天后开始计算领取次数
        reftime = month_card.get_time + ONE_DAY
    end
    if reftime > end_time then
        --加一天的时间多了
        if check_same_day_2(month_card.get_time, reftime) then
            return 1
        else
            return 0
        end
    end
    local leftCount = 0
    leftCount = math.floor((end_time - reftime) / ONE_DAY)
    if not check_same_day_2(reftime + leftCount * ONE_DAY, end_time) then
        leftCount = leftCount + 1
    end
    return leftCount
end

function request:get_award()
    local leftCount = cal_month_card_left_count()
    --未拥有月卡
    if ma_data.db_info.month_card.type <= 0 then
        return {result = 1}
    end
    --当前月卡已领完
    if leftCount <= 0 then
        return {result = 2}
    end
    local month_card = ma_data.db_info.month_card
    --当天月卡已领取
    if check_same_day_2(month_card.get_time,os.time()) then
        return {result = 3}
    end
    month_card.get_time = os.time()
    local awards = cfg_month_card["month_award"..month_card.type]
    table.print(awards)
    ma_data.add_goods_list(awards,GOODS_WAY_MONTH_AWARD,"月卡奖励")
    ma_data.send_push("buy_suc", {
        goods_list = awards,
        msgbox = 1
    })
    M.flush()
    return {result = 0, get_time=month_card.get_time}
end

-- 月卡购买/升级奖励
function M.buy_card_awards(cardType)
    local awards = cfg_month_card["award"..cardType]
    table.print(awards)
    ma_data.add_goods_list(awards,GOODS_WAY_MONTH_CARD_UPGRADE,"购买/升级月卡领取")
    ma_data.send_push("buy_suc", {
        goods_list = awards,
        msgbox = 1
    })
end

function M.on_buy_card(cardType)
    if not M.can_buy_month_card(cardType) then
        --写入数据看库,玩家购买月卡失败
        skynet.call(get_db_mgr(),"lua","insert",COLLECTIONS.ERROR_LOG,{id=ma_data.my_id,nickname=ma_data.db_info.nickname,error_info="购买月卡出错,与已有月卡冲突,购买月卡类型 = " .. cardType,create_time = os.time()})
        return 
    end
    local newCard = true
    local month_card = ma_data.db_info.month_card
    
    if month_card.type > 0 then
        local end_time = month_card.begin_time + month_card.total_day * ONE_DAY
        if end_time > os.time() then
            newCard = false
        end
    end
    if newCard then
        local t = os.date("*t",time or os.time())
        -- return os.time {year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0}
        month_card.total_day = 30
        month_card.type = cardType
        month_card.begin_time = os.time {year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0}--os.time()
        month_card.get_time = 0
    else
        month_card.total_day = month_card.total_day + 30
    end
    -- 初次购买/续费 月卡成功就给奖励
    M.buy_card_awards(cardType)
    ma_data.send_push("month_card_update", {data = month_card})
    M.flush()
end

function M.get_cur_card_info()
    return cal_month_card_left_count(), ma_data.db_info.month_card.type
end

--判断月卡是否能买
function M.can_buy_month_card(cardType)
    local month_card = ma_data.db_info.month_card
    print('==============月卡购买===',cardType,month_card.type,month_card.begin_time,month_card.total_day)
    if month_card.type <= 0 then
        return true
    end
    local end_time = month_card.begin_time + month_card.total_day * ONE_DAY
    if os.time() >= end_time then
        return true
    end
    if cardType == month_card.type then
        return true
    end
    return false
end

--获取当前月卡类型
function M.get_type()
    local month_card = ma_data.db_info.month_card
    if month_card.type <= 0 then
        return 0
    end
    local end_time = month_card.begin_time + month_card.total_day * ONE_DAY
    if os.time() >= end_time then
        return 0
    end
    return month_card.type
end

--月卡是否激活状态
function M.is_month_card_active()
    local month_card = ma_data.db_info.month_card
    if month_card.type <=0 or (os.time() > (month_card.begin_time + month_card.total_day * ONE_DAY)) then
        return false
    end
    return true
end

--月卡升级
--self.type --目前等级
function request:month_card_upgrade()
    local leftCount = cal_month_card_left_count()
    if leftCount <= 0 then
        return {result = 1}
    end
    if ma_data.db_info.month_card.type >= MONTH_CARD_TYPE_GIANT then
        return {result = 2}
    end
    if self.type < ma_data.db_info.month_card.type then
        return {result = 3}
    end
    local month_card = ma_data.db_info.month_card
    local cfgName = "plebs" .. month_card.type
    cfgName = cfgName .. self.type
    local needGoods = cfg_month_card[cfgName][1]
    local needGoodsId = needGoods.id
    local needGoodsNum = needGoods.num * leftCount
    if ma_data.get_goods_num(needGoodsId) < needGoodsNum then
        return {result = 4}
    end
    ma_data.add_goods_list({{id = needGoodsId, num = -needGoodsNum}},GOODS_WAY_MONTH_CARD_UPGRADE,"月卡升级",false)
    -- 月卡升级成功就给奖励
    M.buy_card_awards(self.type)
    -- month_card.total_day = month_card.total_day + 30
    month_card.type = self.type
    M.flush()

    return {result = 0, data = ma_data.db_info.month_card}
end

function request:month_data()
    return { result = 0, data = ma_data.db_info.month_card}
end

function M.flush()
    skynet.send(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id}, {month_card=ma_data.db_info.month_card})
end

local cfg_conf = require "cfg_conf"
local function init_state()
    local subtype = 1001
    local tbl_match = {subtype = subtype}
    local conf = skynet.call(cfg_conf.DB_MGR, "lua", "find_one", cfg_conf.COLL.ACTIVITY_CONF, tbl_match)
    print("ma_month_card conf =>", table.tostr(conf))
    module_state.init(conf)
end

function M.on_conf_update()
    init_state()
end

local function init()
    ma_data.follow_conf(M, cfg_conf.COLL.ACTIVITY_CONF)
    init_state()
    if not ma_data.db_info.month_card then
        ma_data.db_info.month_card = {total_day=0,type=0,begin_time=0,get_time = 0}
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


ma_data.ma_month_card = M

return M