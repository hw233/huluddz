local skynet = require "skynet"
local ma_data = require "ma_data"
local dailytask_conf = require "cfg.rw_cfg_daily_task"
local COLLECTIONS = require "config/collections"
local cfg_lucky_award = require "cfg.cfg_lucky_award"
require "table_util"
local request = {}
local cmd = {}

local M = {}
local function check_task(n, ttype)
    for id, item in pairs(dailytask_conf) do
        if item.type == ttype and n >= item.maxnum then
            M.finish_task(tostring(id))
        end
    end
end
function M.flush()
    skynet.call(get_db_mgr(), "lua", "update", COLLECTIONS.TASK, {pid = ma_data.my_id}, {dailytask = ma_data.dailytask,ads_data = ma_data.ads_data})
end

local function get_num_of_task(id, state)
    local dailytask = ma_data.dailytask
    local taskConf = dailytask_conf[id]
    local activity = M.get_active_value()
    if taskConf.type == TASK_DAY_T_ACTIVE then
        return state == TASK_NOT_FINISHED and activity or taskConf.maxnum
    end
    return state == TASK_NOT_FINISHED and (dailytask.gamec[tostring(taskConf.type)] or 0) or taskConf.maxnum
end

function request:dailytask()
    M.check_day_change()
    local r = {}

    for id,taskconf in pairs(dailytask_conf) do
        if taskconf.type ~= TASK_DAY_T_ACTIVE then
            local state = ma_data.dailytask.task[tostring(id)] or TASK_NOT_FINISHED
            table.insert(r, {
                id = id,
                num = get_num_of_task(id, state),
                state = state,
            })
        end
    end

    return {tasks = r, dice_num = ma_data.dailytask.dice_num or 0}
end

--获取当前活跃度
function M.get_active_value()
    local ret = 0
    for task_id,state in pairs(ma_data.dailytask.task) do
        if state == TASK_RECEIVED then
            local cfg = dailytask_conf[tonumber(task_id)]
            ret = ret + cfg.get_activity
        end
    end
    return ret
end

function M.get_award_key()
    if ma_data.db_info.os == "ios" then
        return "award_Ios"
    end
    return "award_Android"
end

function M.receive_dailytask_reward(id,Double)
    M.check_day_change()
    local task_id = tostring(math.floor(assert(id)))
    local state = ma_data.dailytask.task[task_id]
    local cfg = dailytask_conf[id]
    if cfg.type == TASK_DAY_T_ACTIVE and state ~= TASK_RECEIVED then
        local activity = M.get_active_value()
        if activity >= cfg.activity then
            state = TASK_FINISHED
        end
    end
    if cfg.type == TASK_DAY_T_MRT_AD and state ~= TASK_RECEIVED then 
        state = TASK_FINISHED
    end
    print('============任务完成============',task_id,ma_data.dailytask.task[task_id])

    if  ma_data.dailytask.task[task_id] == TASK_RECEIVED then
        --已经领取过
        return {result = 1, id = id, dice_num = ma_data.dailytask.dice_num or 0}
    elseif state == TASK_FINISHED then
        local award_key = M.get_award_key()
        local awards = table.clone(cfg[award_key])
        if cfg.type == TASK_DAY_T_MRT_AD then
            local maxNum = 0
            local num = 0
            local index = 1
            for _, award in ipairs(awards)do
                maxNum = maxNum + award.rate
            end
            local randNum = math.random(1, maxNum)
            print("ranNum =>", randNum, ";maxNum =>", maxNum)
            for i,award in ipairs(awards) do
                num = num + award.rate
                index = i
                if num >= randNum then
                    break
                end
            end
            print("index =>", index)
            local award = awards[index]
            local goods_list = {award}
            ma_data.dailytask.task[task_id] = TASK_RECEIVED
            ma_data.add_goods_list(goods_list, GOODS_WAY_TASK_AWARD, "完成任务奖励 " .. id)
            ma_data.send_push('buy_suc', {goods_list = goods_list})
        else
            --看视频双倍领取金币
            if Double then
                currency_numX2(awards)
            end
            ma_data.add_goods_list(awards, GOODS_WAY_TASK_AWARD, "完成任务奖励 " .. id)
            ma_data.send_push('buy_suc', {goods_list = awards})
            ma_data.dailytask.task[task_id] = TASK_RECEIVED
            --自动领取骰子
            local activity = M.get_active_value()
            for id, item in pairs(dailytask_conf) do
                if item.type == TASK_DAY_T_ACTIVE and activity >= item.activity then
                    local tmpTaskId = tostring(id)
                    if ma_data.dailytask.task[tmpTaskId] ~= TASK_RECEIVED then
                        ma_data.dailytask.dice_num = (ma_data.dailytask.dice_num or 0) + 1
                        ma_data.dailytask.task[tmpTaskId] = TASK_RECEIVED
                    end
                end
            end
        end

        M.flush()
        return {result = 0, id = id, dice_num = ma_data.dailytask.dice_num or 0}
    else
        --未达到领取
        return {result = 2, id = id, dice_num = ma_data.dailytask.dice_num or 0}
    end
end

function cmd.receive_dailytask_reward(id)
    local Double = true
    local tmpTbl = M.receive_dailytask_reward(id,Double)
    ma_data.send_push('receive_dailytask_reward',tmpTbl)
end

function request:receive_dailytask_reward()
    return M.receive_dailytask_reward(self.id,self.Double)
end

local aop = require "aop"
local boost_module_state = aop.helper:make_state("booster_module")
local boost_request = aop.helper:make_interface_tbl(boost_module_state)
local booster_interface = aop.helper:make_interface_tbl(boost_module_state)

--获取助力礼包贡献榜
function boost_request:get_booster_rank_list()
    local total_count = skynet.call("booster_mgr","lua","get_total_count")
    local level = skynet.call("booster_mgr","lua","get_award_level")
    return {list = skynet.call("booster_mgr","lua","get_rank_list"),level = level,total_count = total_count,
                    buy_count = ma_data.db_info.booster_bag_rank.buy_count, result = 0}
end

function boost_request:get_booster_info()
    local total_count = skynet.call("booster_mgr","lua","get_total_count")
    local level = skynet.call("booster_mgr","lua","get_award_level")
    local award1,award2,award3,award4 = skynet.call("booster_mgr","lua","get_award_info")
    return {level = level,total_count = total_count,list1=award1,list2=award2,list3=award3,list4=award4, result = 0}
end

--掷骰子
function boost_request:roll_daily_task_dice()
    if ma_data.dailytask.dice_num <= 0 then
        --骰子不够
        return {result=1}
    end

    local list = {}
    local mustHave = false
    list,mustHave = skynet.call("booster_mgr","lua","giveBestAward")
    if #list <= 0 then
        for i = 1, 5 do
            table.insert(list,math.random(1,6))
        end
    end

    table.sort(list, function ( a,b )
            return a > b
        end)

    local dice_type = 5
    local award
    if list[1] == list[2] and list[2] == list[3] and list[3] == list[4] and list[4] == list[5] then
        --豹子3
        dice_type = 1
        if math.random(10000) > cfg_lucky_award[dice_type].probability and not mustHave then
            dice_type = 5
            list[1] = 1
            list[2] = 2
        end
    elseif list[1] == (list[2] + 1) and list[2] == (list[3] + 1) and list[3] == (list[4] + 1) and list[4] == (list[5] + 1) then
        --顺子
        dice_type = 2
        if math.random(10000) > cfg_lucky_award[dice_type].probability and not mustHave then
            dice_type = 5
            list[1] = 1
            list[2] = 1
        end
    elseif (list[2] == list[3] and list[3] == list[4] and list[4] == list[5]) or 
            (list[1] == list[2] and list[2] == list[3] and list[3] == list[4]) then
        --小豹子
        dice_type = 3
        if math.random(10000) > cfg_lucky_award[dice_type].probability and not mustHave then
            dice_type = 5
            list[1] = 1
            list[2] = 2
            list[3] = 3
        end
    elseif ((list[1] == list[2] and list[2] == list[3]) and (list[4] == list[5])) or 
            (list[1] == list[2] and (list[3] == list[4] and list[4] == list[5])) then
        --3+2
        dice_type = 4
        if math.random(10000) > cfg_lucky_award[dice_type].probability and not mustHave then
            dice_type = 5
            list[1] = 1
            list[2] = 2
            list[3] = 3
        end
    end

    if dice_type == 5 then
        --阳光普照奖
        local awardIndex = skynet.call("booster_mgr","lua","get_award_level")
        award = cfg_lucky_award[dice_type]["award"..awardIndex]
    else
        --正常领奖
        award = skynet.call("booster_mgr", "lua", "get_award",dice_type,ma_data.my_id,ma_data.db_info.nickname,
                    ma_data.db_info.headimgurl)
    end
    if not award then
        return {result = 2,dice_type = dice_type,list=list}
    end
    ma_data.dailytask.dice_num = ma_data.dailytask.dice_num - 1
    ma_data.add_goods_list(award,GOODS_WAY_BOOSTER,"助力礼包掷骰子奖励 " .. dice_type)
    ma_data.send_push("buy_suc", {
        goods_list = award,
        msgbox = 3
    })

    if dice_type >= 1 and dice_type <= 4 then
        local automsg = {[1] = ma_data.db_info.nickname}
        --skynet.send("services_mgr", "lua", "activeNotice",10,dice_type,automsg)
    end
    M.flush()
    
    return {result = 0, list = list, dice_type = dice_type}
end

function booster_interface.buy_booster()
    ma_data.db_info.booster_bag_rank.buy_count = ma_data.db_info.booster_bag_rank.buy_count + 1
    skynet.call("booster_mgr","lua","buy_booster",ma_data.my_id,ma_data.db_info.nickname,ma_data.db_info.headimgurl,ma_data.db_info.booster_bag_rank.buy_count,ma_data.get_picture_frame(ma_data.db_info.backpack))
    skynet.call(get_db_mgr(),"lua","update",COLLECTIONS.USER,{id=ma_data.my_id},{booster_bag_rank=ma_data.db_info.booster_bag_rank})
end

table.connect(request, boost_request)
table.connect(M, booster_interface)

local cfg_conf = require "cfg_conf"
local function init_booster_module()
    local subtype = 1003
    local tbl_match = {subtype = subtype}
    local conf = skynet.call(cfg_conf.DB_MGR, "lua", "find_one", cfg_conf.COLL.ACTIVITY_CONF)
    table.print("booster_module conf =>", conf)
    boost_module_state.init(conf)
end

function M.add_task_count(ttype)
    M.check_day_change()
    local dailytask = ma_data.dailytask
    dailytask.gamec[tostring(ttype)] = (dailytask.gamec[tostring(ttype)] or 0) + 1
    check_task(dailytask.gamec[tostring(ttype)], ttype)
    M.flush()
end

--胡的番型
function M.hu_fan(fanNum,cap)
    if fanNum >= 64 and (cap >= 64 or cap == 0) then
        -- local dailytask = ma_data.dailytask
        -- dailytask.gamec.fan = (dailytask.gamec.fan or 0) + 1
        -- check_task(dailytask.gamec.fan, TASK_DSY_T_FAN)
        -- M.flush()
        M.add_task_count(TASK_DSY_T_FAN)
    end
    if fanNum >= 512 and (cap >= 512 or cap == 0) then
        -- local dailytask = ma_data.dailytask
        -- dailytask.gamec.fan = (dailytask.gamec.fan or 0) + 1
        -- check_task(dailytask.gamec.fan, TASK_DSY_T_FAN)
        -- M.flush()
        M.add_task_count(TASK_DAY_T_FAN_512)
    end
end

function M.small_game_over(club_type, win)
    M.check_day_change()
    
    local dailytask = ma_data.dailytask

    dailytask.gamec.all = dailytask.gamec.all + 1
    -- check_task(dailytask.gamec.all, TASK_DAY_T_ANY_COIN_WIN)
    if win then
        dailytask.gamec.win = dailytask.gamec.win + 1
        -- check_task(dailytask.gamec.win, TASK_DAY_T_ANY_COIN_MATCH)
    end

    M.flush()
end


function M.finish_task(task_id, meta)
    local state = ma_data.dailytask.task[task_id]
    if not state then
        ma_data.dailytask.task[task_id] = TASK_FINISHED
        ma_data.send_push("task_done",{task_id=tonumber(task_id)})
        M.flush()
    end
end

function M.init_watch_ad(dailytask)
    print('初始化视频观看=====================')
    dailytask.watch_adac = 0
    dailytask.watch_Ntime = 0
    dailytask.today_click = false
    -- for i=1,#ad_conf do
    --     dailytask.watch_adaw[i] = 0
    -- end
    return dailytask
end

--观看幸运转盘 奖励
function M.watch_ad_award()
    local award_id = 0
    local tempRand = math.random(1,10000)
    local allRate = 0
    print('==============',tempRand)
    for i,awardId in ipairs(ad_conf) do
        allRate = allRate + awardId.rate
        if tempRand <= allRate then
            award_id = i
            break
        end
    end
    if ad_conf[award_id] then
        local award_info = ad_conf[award_id].award
        ma_data.add_goods_list(award_info, GOODS_WAY_AD, "观看广告获得")
        ma_data.dailytask.watch_adac = ma_data.dailytask.watch_adac + 1
        ma_data.dailytask.watch_Ntime = os.time() + 5  --广告播放间隔时间 drawaward_adtime
        M.flush()
        return true,award_id
    end
    return false,award_id
end

function M.update_today_click()
    ma_data.dailytask.today_click = true
    M.flush()
end
function M.gen_init_dailytask_data()
    local today = os.date("%Y%m%d")

    local dailytask = {
        day = today,
        task = {},          -- 任务 ID 对应的状态 {'3': DT_STATE.FINISED, ...}
        -- meta = {},          -- 一些额外信息, 比如任务3 购买的道具ID
        gamec = {
            all = 0,        -- 所有游戏次数
            win = 0,         -- 赢的游戏次数
            give = 0,    --赠送好友豆子次数
            zm = 0,      --自摸
            dream = 0,   --梦想时光机次数
            fan = 0,       --大番型
        },
        dice_num = 0,   --拥有的骰子数量
       
        -- watch_adc = 0,      -- 观看视频次数
    }
    dailytask = M.init_watch_ad(dailytask)
    return dailytask
end


--对外提供广告统计
function M.get_ads_data()
    M.check_day_change()
    return ma_data.ads_data
end



--{ads_data {{day="20210706",today={scenename = {start,end}},all={scenename = {start,end}}}}
function M.gen_init_ads_data_self()
    local today = os.date("%Y%m%d")
    print(" ======gen_init_ads_data_self 初始化====")
    if ma_data.ads_data ==nil then
        ma_data.ads_data ={
            day = today,
            today = {}, -- 每日重置的 scenename = {start,end}... 默认{0,0}
            all = {}, --总计 scenename = {start,end}... 默认{0,0}
            watch_adc_all = 0,      -- 总的观看视频次数
        }
    else
        ma_data.ads_data.day = today
        ma_data.ads_data.today = {}
    end
    -- table.print(ma_data.ads_data)
end

function M.check_day_change()
    local today = os.date("%Y%m%d")
    if ma_data.dailytask.day ~= today then
        ma_data.dailytask = M.gen_init_dailytask_data()
        M.gen_init_ads_data_self()
        M.flush()
    end
end


--获取广告次数统计
--{1,2},{3,4}
function M.get_watch_count(sceneName,only_day)
    if sceneName~=nil then
        return {ma_data.ads_data.today[sceneName],ma_data.ads_data.all[sceneName]}
    end
    
    if only_day then
        local ret = {0,0}
        for i,item in pairs(ma_data.ads_data.today) do
            ret[1] = ret[1]+ item[1]
            ret[2] = ret[2]+ item[2]
        end
        return ret
    else
        local ret = {0,0}
        for i,item in pairs(ma_data.ads_data.all) do
            ret[1] = ret[1]+ item[1]
            ret[2] = ret[2]+ item[2]
        end
        return ret
    end
end

--通用广告播放数量统计
function M.submit_ads_cell(scene_name,type)
    local bPlaySucc = type == 2
    if ma_data.ads_data.today[scene_name] ==nil then
        ma_data.ads_data.today[scene_name] ={0,0}
    end
    if ma_data.ads_data.all[scene_name] ==nil then
        ma_data.ads_data.all[scene_name] ={0,0}
    end

    if bPlaySucc then
        ma_data.ads_data.today[scene_name][2] =  ma_data.ads_data.today[scene_name][2] + 1
        ma_data.ads_data.all[scene_name][2] =  ma_data.ads_data.all[scene_name][2] + 1
        ma_data.ads_data.watch_adc_all = ma_data.ads_data.watch_adc_all+1
        -- local rank,value,value2= skynet.call("ranklist_mgr","lua","get_rank","watch_ads",ma_data.my_id)
        -- print(" 我的广告播放次数 ",rank,value,value2)
        -- --排行榜统计自己的次数 并提排行榜
        -- skynet.call("ranklist_mgr","lua","update_watch_ads",ma_data.my_id,value+1,
        --     ma_data.db_info.nickname,ma_data.db_info.headimgurl,ma_data.get_picture_frame(ma_data.db_info.backpack))
    else
        ma_data.ads_data.today[scene_name][1] =  ma_data.ads_data.today[scene_name][1] + 1
        ma_data.ads_data.all[scene_name][1] =  ma_data.ads_data.all[scene_name][1] + 1
    end   
    M.flush()
    -- print("===table ma_data.ads_data ===")
    -- table.print(ma_data.ads_data)
    -- print("===table Get_watch_count(nil,true)===")
    -- table.print(M.get_watch_count(nil,true))
    -- table.print(M.get_watch_count(nil,false))
end

--上报广告场景统计 start
function M.watch_ads_start(scene_name)
   M.submit_ads_cell(scene_name,1)
end

--上报广告场景统计 end
function M.watch_ads_succ(scene_name)
    M.submit_ads_cell(scene_name,2)
end


local function load_dailytask_data()
    local t = skynet.call(get_db_mgr(), "lua", "find_one", COLLECTIONS.TASK, {pid = ma_data.my_id}, 
        {dailytask = true,_id=false})
    return t and t.dailytask
end

local function load_ads_data()
    local t = skynet.call(get_db_mgr(), "lua", "find_one", COLLECTIONS.TASK, {pid = ma_data.my_id}, 
        {dailytask = false,_id=false})
    return t and t.ads_data
end

function M.on_conf_update()
    init_booster_module()
end

local function init()
    ma_data.follow_conf(M, cfg_conf.COLL.ACTIVITY_CONF)
    init_booster_module()

    ma_data.dailytask = load_dailytask_data()
    ma_data.ads_data = load_ads_data()
    if not ma_data.db_info.booster_bag_rank then
        ma_data.db_info.booster_bag_rank = {t=os.time(),rank=0,buy_count=0}
    end
    if not ma_data.dailytask then
        ma_data.dailytask = M.gen_init_dailytask_data()
        skynet.call(get_db_mgr(), "lua", "insert", COLLECTIONS.TASK, {pid = ma_data.my_id, dailytask = ma_data.dailytask})
    end
    if not ma_data.ads_data then
        M.gen_init_ads_data_self()
        skynet.call(get_db_mgr(), "lua", "update", COLLECTIONS.TASK, {pid = ma_data.my_id}, {ads_data = ma_data.ads_data})
    end
    M.check_day_change()
    if not ma_data.dailytask.watch_adac then
        ma_data.dailytask = M.init_watch_ad(ma_data.dailytask)
    end
    --助力全服礼包排行榜奖励
    if not check_same_week(ma_data.db_info.booster_bag_rank.t) then
        if ma_data.db_info.booster_bag_rank.rank > 0 then
            --发放排行榜奖励
            local award = cfg_contribute[ma_data.db_info.booster_bag_rank.rank].award
                local mail =  {
                title = "贡献榜奖励",
                content = [[恭喜您，上周在助力全服礼包中排名第<font color="#ff0000">]]
                            .. ma_data.db_info.booster_bag_rank.rank ..
                            [[</font>名，获得如下奖励请及时领取。]],
                attachment = award,
                mail_type = MAIL_TYPE_OTHER,
                mail_stype = MAIL_STYPE_AWARD,
                }
        skynet.call("mail_mgr", "lua", "send_mail", ma_data.my_id, mail)
        end
        ma_data.db_info.booster_bag_rank = {t=os.time(),rank=0,buy_count=0}
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

ma_data.ma_task = M
return M