--
-- 千王争霸
-- 洪福齐天
--
local skynet = require "skynet"
local xy_cmd = require "xy_cmd"
require "pub_util"
local CMD = xy_cmd.xy_cmd
local COLL = require "config/collections"
local booster_setting = nil
local cfg_lucky_award = require "cfg.cfg_lucky_award"
local cfg_global = require "cfg.cfg_global"
local luck_num = {}
--赛季配置id 100000
--分服可能需要做http的形式
function CMD.inject(filePath)
    require(filePath)
end

function CMD.get_setting()
    return booster_setting
end

function CMD.buy_booster(id,nickname,headimgurl,count,headframe)
    local list = booster_setting.week_rank.list
    local findOwn = false

    for i = 1, 3 do
        if list[i].id == id then
            list[i].count = count
            list[i].headframe = headframe
            findOwn = true
            break
        end
    end
    if not findOwn then
        if list[3].count < count then
            list[3] = {id = id, nickname=nickname,headimgurl=headimgurl,count = count,headframe = headframe}
        end
    end

    table.sort(list,function(a,b)
        return a.count > b.count
    end)
    local currLv = CMD.get_award_level()
    booster_setting.buy_count = booster_setting.buy_count + 1
    local nextLv = CMD.get_award_level()
    if currLv ~= nextLv then
        local automsg = {[1]=nextLv}
        skynet.send("services_mgr", "lua", "activeNotice", 5, 1, automsg)
    end
    skynet.call(get_db_mgr(),"lua","update",COLL.SETTING,{id="booster_setting"},{week_rank=booster_setting.week_rank,
        buy_count=booster_setting.buy_count})
end

function CMD.get_award_level()
    local cfg = cfg_global[1]
    local buy_count = CMD.get_total_count()
    for index,count in ipairs(cfg.lucky_award) do
        if count >= buy_count then
            return index
        end
    end
    if buy_count < cfg.lucky_award[1] then
        return 1
    end
    return #(cfg.lucky_award)
end

function CMD.get_total_count()
    return booster_setting.buy_count + math.floor((os.time() - booster_setting.t) / (3600))*cfg_global[1].lucky_num
end

--award_type
function CMD.get_award(award_type,id,nickname,headimgurl)
    local ret = nil
    local awardLevel = CMD.get_award_level()
    if award_type == 1 then
        if #(booster_setting.award_info[1]) < 2 then
            --全服通知
            ret = cfg_lucky_award[award_type]["award"..awardLevel]
        end
    elseif award_type == 2 then
        if #(booster_setting.award_info[2]) < 4 then
            ret = cfg_lucky_award[award_type]["award"..awardLevel]
        end
    elseif award_type == 3 then
        if #(booster_setting.award_info[3]) < 8 then
            ret = cfg_lucky_award[award_type]["award"..awardLevel]
        end
    elseif award_type == 4 then
        if #(booster_setting.award_info[4]) < 16 then
            ret = cfg_lucky_award[award_type]["award"..awardLevel]
        end
    end
    if ret then
        table.insert(booster_setting.award_info[award_type],{id=id,nickname=nickname,headimgurl=headimgurl,award_type=award_type})
        skynet.call(get_db_mgr(),"lua","update",COLL.SETTING,{id="booster_setting"},{award_info=booster_setting.award_info})
    end
    return ret
end

function CMD.get_award_info()
    return booster_setting.award_info[1],booster_setting.award_info[2],booster_setting.award_info[3],booster_setting.award_info[4]
end

--获取排行榜信息
function CMD.get_rank_list()
    return booster_setting.week_rank.list
end

function CMD.time_tick_op()
    if not check_same_day(booster_setting.award_t) then
        --跨天重置奖励
        booster_setting.award_t = os.time()
        booster_setting.award_info = {[1] = {},[2]={},[3]={},[4]={}}
        skynet.call(get_db_mgr(),"lua","update",COLL.SETTING,{id="booster_setting"},{award_t=booster_setting.award_t,
                award_info=booster_setting.award_info})
    end

    if not check_same_week(booster_setting.week_rank.t) then
        --排行榜奖励
        booster_setting.week_rank = {t=os.time(),list={[1]={id=0,count=0},[2]={id=0,count=0},[3]={id=0,count=0}}}
        skynet.call(get_db_mgr(),"lua","update",COLL.SETTING,{id="booster_setting"},{week_rank=booster_setting.week_rank})
        --设置奖励状态
        local list = booster_setting.week_rank.list
        booster_setting.week_rank = {t=os.time(),list={[1]={id=0,count=0},[2]={id=0,count=0},[3]={id=0,count=0}}}
        for rank,item in ipairs(list) do
            if tonumber(item.id) > 0 then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=item.id},{["booster_bag_rank.rank"] = rank})
                --通知agent
            end
        end
        skynet.call(get_db_mgr(),"lua","update",COLL.SETTING,{id="booster_setting"},{week_rank=booster_setting.week_rank})
    end
end

local function get_list(list_id)
    local list = {}
    if list_id == 1 then
        list = {1,1,1,1,1}
    elseif list_id == 2 then
        list = {1,2,3,4,5}
    elseif list_id == 3 then
        list = {1,1,1,1,5}
    elseif list_id == 4 then
        list = {1,1,1,2,2}
    end
    return list
end
--大奖必中
function CMD.giveBestAward()
    local list = {}
    local mustHave = false
    for i=1,#luck_num do
        if luck_num[i] >= cfg_lucky_num[i].num then
            luck_num[i] = 0
            list = get_list(i)
            mustHave = true
            break
        end
    end
    for i=1,#luck_num do
        luck_num[i] = luck_num[i] + 1
    end
    return list,mustHave
end

function CMD.time_tick()
    skynet.timeout(100, CMD.time_tick)
    CMD.time_tick_op()
end

function CMD.init()
    booster_setting = skynet.call(get_db_mgr(), "lua", "find_one", COLL.SETTING, {id = "booster_setting"},
                                            {_id=false,t=true,award_t=true,buy_count=true,award_info=true,week_rank=true})
    if not booster_setting then
        booster_setting = {}
        booster_setting.id = "booster_setting"
        booster_setting.t = os.time()
        booster_setting.award_t = os.time()
        booster_setting.buy_count = 0
        booster_setting.award_info = {[1] = {},[2]={},[3]={},[4]={}}
        booster_setting.week_rank = {t=os.time(),list={[1]={id=0,count=0},[2]={id=0,count=0},[3]={id=0,count=0}}}
        skynet.call(get_db_mgr(),"lua","insert",COLL.SETTING,booster_setting)
    end
    if not check_same_day(booster_setting.award_t) then
        --跨天重置奖励
        booster_setting.award_t = os.time()
        booster_setting.award_info = {[1] = {},[2]={},[3]={},[4]={}}
        skynet.call(get_db_mgr(),"lua","update",COLL.SETTING,{id="booster_setting"},{award_t=booster_setting.award_t,
                award_info=booster_setting.award_info})
    end
    --排行榜奖励
    if not check_same_week(booster_setting.week_rank.t) then
        booster_setting.week_rank = {t=os.time(),list={[1]={id=0,count=0},[2]={id=0,count=0},[3]={id=0,count=0}}}
        skynet.call(get_db_mgr(),"lua","update",COLL.SETTING,{id="booster_setting"},{week_rank=booster_setting.week_rank})
        --设置奖励状态
        local list = booster_setting.week_rank.list
        booster_setting.week_rank = {t=os.time(),list={[1]={id=0,count=0},[2]={id=0,count=0},[3]={id=0,count=0}}}
        for rank,item in ipairs(list) do
            if tonumber(item.id) > 0 then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=item.id},{["booster_bag_rank.rank"] = rank})
                --通知agent
            end
        end
        skynet.call(get_db_mgr(),"lua","update",COLL.SETTING,{id="booster_setting"},{week_rank=booster_setting.week_rank})
    end

    --初始化luck_num
    luck_num = {0,0,0,0}
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
    CMD.init()
    skynet.timeout(100, CMD.time_tick)
end)