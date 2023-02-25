--
-- 排行榜  [段位 身价  奢华 宠物 看广告]
--
local skynet = require "skynet"
local timer = require "timer"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
local cfg_rank_grade = require "cfg.cfg_rank_grade"
local timer = require "timer"
require "pub_util"
local NODE_NAME = skynet.getenv "node_name"
local COLL = require "config/collections"

local playerInfo = {}
local ranklist_setting = nil
local rank_list = {prestige={},worth={},luxury={},pet_level={},watch_ads={}}
local rank_id_mac = {prestige={},worth={},luxury={},pet_level={},watch_ads={}}
local first_id_mac = {prestige={},worth={},luxury={},pet_level={},watch_ads={}}
local rank_cal_interval = 60  --排行榜刷新周期
local rank_cal_left_time = rank_cal_interval
local max_rank_grade_id = 0
--赛季配置id 100000
--雀神榜,身价,家园,宠物,看视频
function CMD.inject(filePath)
    require(filePath)
end

--玩家胜利了
--id 玩家id
function CMD.update_prestige(id,prestige,seg_prestige,nickname,headimgurl,headframe)
    --print('============玩家胜利了==========',id,prestige,seg_prestige,nickname,headimgurl,headframe)
    if not playerInfo[id] then
        local rank_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.RANKLIST_DATA, {id = id},
                    {_id=false,id=true,prestige=true,seg_prestige=true,
                    worth=true,luxury=true,pet_level=true,nickname=true,headimgurl=true,headframe=true})
        if not rank_data then
            rank_data = {id=id, prestige=prestige,seg_prestige=seg_prestige,t1=os.time(),worth=0,t2=os.time(),luxury=0,t3=os.time(),pet_level=0,watch_ads=0,t4=os.time(),nickname=nickname,
                        headimgurl=headimgurl,headframe=headframe,t=os.time()}
            skynet.call(get_db_mgr(),"lua","insert",COLL.RANKLIST_DATA,rank_data)
        else
            rank_data.prestige = prestige
            rank_data.nickname = nickname
            rank_data.headimgurl = headimgurl
            rank_data.headframe = headframe
            rank_data.seg_prestige = seg_prestige
            skynet.call(get_db_mgr(),"lua","update",COLL.RANKLIST_DATA,{id=id},{prestige=prestige,nickname = nickname,
                                                    headimgurl = headimgurl,headframe = headframe,seg_prestige=seg_prestige})
        end
        playerInfo[id] = rank_data
    else
        playerInfo[id].prestige = prestige
        playerInfo[id].nickname = nickname
        playerInfo[id].headimgurl = headimgurl
        playerInfo[id].headframe = headframe
        playerInfo[id].seg_prestige = seg_prestige
        skynet.call(get_db_mgr(),"lua","update",COLL.RANKLIST_DATA,{id=id},{prestige=prestige,nickname = nickname,
                                                    headimgurl = headimgurl,headframe = headframe,seg_prestige=seg_prestige})
    end

    -- if playerInfo[id].prestige > first_id_mac.prestige[1].prestige then
    --     local automsg = {[1]=nickname,[2]=pet_name}
    --     skynet.send("services_mgr", "lua", "activeNotice",2,1,automsg)
    -- end
end

function CMD.update_headframe(id,headframe)
    local rank_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.RANKLIST_DATA, {id = id},{_id=false,id=true,headframe=true})
    if rank_data then
        skynet.call(get_db_mgr(),"lua","update",COLL.RANKLIST_DATA,{id=id},{headframe=headframe})
    end
    local rank2_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.RANKTWO_DATA, {id = id},{_id=false,id=true,headframe=true})
    if rank2_data then
        skynet.call(get_db_mgr(),"lua","update",COLL.RANKTWO_DATA,{id=id},{headframe=headframe})
    end
    local rankL_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.LONGRANK_DATA, {id = id},{_id=false,id=true,headframe=true})
    if rankL_data then
        skynet.call(get_db_mgr(),"lua","update",COLL.LONGRANK_DATA,{id=id},{headframe=headframe})
    end
end

function CMD.delete_forbid_player(id)
    for _,rankTbl in pairs(rank_list) do
        for i,p_Info in ipairs(rankTbl) do
            if p_Info.id == id then
                table.remove(rankTbl,i)
                break
            end
        end
    end

    for _,rankTbl in pairs(rank_id_mac) do
        rankTbl[id] = nil
    end
    playerInfo[id] = nil
    skynet.call("db_mgr_del", "lua", "delete", COLL.RANKLIST_DATA,{id=id})
end

--身价排行榜
function CMD.update_worth(id,worth,nickname,headimgurl,headframe)
    --print('============身价排行榜==========',id,worth,nickname,headimgurl,headframe)
    if not playerInfo[id] then
        local rank_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.RANKLIST_DATA, {id = id},
                    {_id=false,id=true,prestige=true,worth=true,luxury=true,pet_level=true,nickname=true,headimgurl=true,headframe=true})
        if not rank_data then
            rank_data = {id=id, prestige=0,t1=os.time(),worth=worth,t2=os.time(),luxury=0,t3=os.time(),pet_level=0,watch_ads=0,t4=os.time(),nickname=nickname,
                        headimgurl=headimgurl,headframe=headframe,t=os.time()}
            skynet.call(get_db_mgr(),"lua","insert",COLL.RANKLIST_DATA,rank_data)
        end
        playerInfo[id] = rank_data
    else
        playerInfo[id].worth = worth
        skynet.call(get_db_mgr(),"lua","update",COLL.RANKLIST_DATA,{id=id},{worth=worth})
    end
    if not first_id_mac.worth[1] or (playerInfo[id].worth > first_id_mac.worth[1].worth 
        and first_id_mac.worth[1].id ~= id) then
        local automsg = {[1]=nickname}
        first_id_mac.worth[1] = {id = id,nickname = nickname,headimgurl = headimgurl,worth = worth}
        --skynet.send("services_mgr", "lua", "activeNotice",5,1,automsg)
    end
end

--奢华度排行榜
function CMD.update_luxury(id,luxury,nickname,headimgurl,headframe)
    --print('============奢华度排行榜==========',id,luxury,nickname,headimgurl,headframe)
    if not playerInfo[id] then
        local rank_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.RANKLIST_DATA, {id = id},
                    {_id=false,id=true,prestige=true,worth=true,luxury=true,pet_level=true,nickname=true,headimgurl=true,headframe=true})
        if not rank_data then
            rank_data = {id=id, prestige=0,t1=os.time(),worth=0,t2=os.time(),luxury=luxury,t3=os.time(),pet_level=0,watch_ads=0,t4=os.time(),nickname=nickname,
                        headimgurl=headimgurl,headframe=headframe,t=os.time()}
            skynet.call(get_db_mgr(),"lua","insert",COLL.RANKLIST_DATA,rank_data)
        end
        playerInfo[id] = rank_data
    else
        playerInfo[id].luxury = luxury
        skynet.call(get_db_mgr(),"lua","update",COLL.RANKLIST_DATA,{id=id},{luxury=luxury,t3=os.time()})
    end
    if not first_id_mac.luxury[1] or (playerInfo[id].luxury > first_id_mac.luxury[1].luxury
    and first_id_mac.luxury[1].id ~= id) then
        local automsg = {[1]=nickname}
        first_id_mac.luxury[1] = {id = id,nickname = nickname,headimgurl = headimgurl,luxury = luxury}
        --skynet.send("services_mgr", "lua", "activeNotice",6,1,automsg)
    end
end

--宠物段位排行榜
function CMD.update_pet_level(id,pet_level,nickname,headimgurl,pet_name,headframe)
    --print('============c宠物段位提升==========',id,pet_level,nickname,headimgurl,pet_name,headframe)
    if not playerInfo[id] then
        local rank_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.RANKLIST_DATA, {id = id},
                    {_id=false,id=true,prestige=true,worth=true,luxury=true,pet_level=true,nickname=true,headimgurl=true,headframe=true})
        if not rank_data then
            rank_data = {id=id, prestige=0,t1=os.time(),worth=0,t2=os.time(),luxury=0,t3=os.time(),pet_level=pet_level,watch_ads=0,t4=os.time(),nickname=nickname,
                        headimgurl=headimgurl,headframe=headframe,t=os.time()}
            skynet.call(get_db_mgr(),"lua","insert",COLL.RANKLIST_DATA,rank_data)
        end
        playerInfo[id] = rank_data
    else
        playerInfo[id].pet_level = pet_level
        playerInfo[id].nickname = nickname
        playerInfo[id].headimgurl = headimgurl
        playerInfo[id].pet_name = pet_name
        playerInfo[id].headframe = headframe

        skynet.call(get_db_mgr(),"lua","update",COLL.RANKLIST_DATA,{id=id},{pet_level=pet_level,t4=os.time(),nickname = nickname,headimgurl = headimgurl,headframe = headframe,pet_name = pet_name})
    end
    print(first_id_mac.pet_level,first_id_mac.pet_level[1])
    if not first_id_mac.pet_level[1] or (playerInfo[id].pet_level > first_id_mac.pet_level[1].pet_level
        and first_id_mac.pet_level[1].id ~= id) then
        local automsg = {[1]=nickname,[2]=pet_name}
        first_id_mac.pet_level[1] = {id = id,nickname = nickname,headimgurl = headimgurl,pet_level = pet_level}
        --skynet.send("services_mgr", "lua", "activeNotice",7,1,automsg)
    end
end


--看广告排行更新
function CMD.update_watch_ads(id,watch_ads,nickname,headimgurl,headframe)
    print('============看广告排行 add===========',id,watch_ads,nickname ,playerInfo[id])
    if not playerInfo[id] then
        local rank_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.RANKLIST_DATA, {id = id},
                    {_id=false,id=true,watch_ads=true,nickname=true,headimgurl=true,headframe=true})
        if not rank_data then
            rank_data = {id=id, prestige=0,t1=os.time(),worth=0,t2=os.time(),luxury=0,t3=os.time(),pet_level=0,watch_ads=watch_ads,t4=os.time(),nickname=nickname,
                        headimgurl=headimgurl,headframe=headframe,t=os.time()}
            skynet.call(get_db_mgr(),"lua","insert",COLL.RANKLIST_DATA,rank_data)
        end
        playerInfo[id] = rank_data
    else
        playerInfo[id].watch_ads = watch_ads
        skynet.call(get_db_mgr(),"lua","update",COLL.RANKLIST_DATA,{id=id},{watch_ads=watch_ads,t4=os.time(),nickname = nickname,headimgurl=headimgurl,headframe=headframe})
        print("插入广告更新排行榜")
    end
    print(first_id_mac.watch_ads,first_id_mac.watch_ads[1])
    if not first_id_mac.watch_ads[1] or (playerInfo[id].watch_ads > first_id_mac.watch_ads[1].watch_ads
        and first_id_mac.watch_ads[1].id ~= id) then
        first_id_mac.watch_ads[1] = {id = id,watch_ads = watch_ads,headimgurl = headimgurl}
        print("更新榜1")
    end
end

--fri_list:好友id列表
function CMD.get_fri_rank_info(fri_list)
    local ret = {}
    local allIn = {}
    for _,id in ipairs(fri_list) do
        if playerInfo[id] then
            local frank = {}
            for k,v in pairs(rank_id_mac) do
                if v[id] then
                    local tempTbl = {rankName=k,rank=v[id].rank}
                    table.insert(frank,tempTbl)
                end
            end
            table.insert(ret,{id=playerInfo[id].id,prestige=playerInfo[id].prestige,worth=playerInfo[id].worth,luxury=
                        playerInfo[id].luxury,pet_level=playerInfo[id].pet_level,nickname=playerInfo[id].nickname,
                        headimgurl=playerInfo[id].headimgurl,headframe=playerInfo[id].headframe,frank=frank,
                        seg_prestige=playerInfo[id].seg_prestige})
        else
            table.insert(allIn, id)
        end
    end
    if #allIn > 0 then
        local infos = skynet.call(get_db_mgr(),"lua", "find_all", COLL.RANKLIST_DATA, {id={["$in"] = allIn}},{_id=false,id=true,
                    prestige=true,worth=true,luxury=true,pet_level=true,nickname=true,headimgurl=true,headframe=true,seg_prestige=true}) or {}
        for _,item in ipairs(infos) do
            playerInfo[item.id] = item
            local frank = {}
            for k,v in pairs(rank_id_mac) do
                if v[item.id] then
                    local tempTbl = {rankName=k,rank=v[item.id].rank}
                    table.insert(frank,tempTbl)
                end
            end
            table.insert(ret,{id=item.id,prestige=item.prestige,worth=item.worth,luxury=item.luxury,pet_level=item.pet_level,
                nickname=item.nickname,headimgurl=item.headimgurl,headframe=item.headframe,frank=frank,seg_prestige=item.seg_prestige})
        end
    end
    return ret
end

function CMD.get_setting()
    return ranklist_setting
end

--获取自身排名
function CMD.get_rank(name,id)
    local rank = -1
    local value = 0
    local value2
    if rank_id_mac[name] and rank_id_mac[name][id] then
        rank = rank_id_mac[name][id].rank
        value = rank_id_mac[name][id].data[name]
        value2 = rank_id_mac[name][id].data['seg_'..name]
    end
    if playerInfo[id] then
        value = playerInfo[id][name]
        value2 = playerInfo[id]['seg_'..name]
    end
    return rank,value,value2
end

function CMD.get_rank_list(name, start, num)
    if start > 100 or start <= 0 then
        return nil
    end
    if num > 100 then
        num = 100
    end
    
    local max_index = start + num - 1
    local ret = {}
    for i = start, max_index do
        if rank_list[name][i] then
            table.insert(ret,rank_list[name][i])
        end
    end
    if #ret < 1 then
        return nil
    end
    return ret
end

function CMD.refreshRank()
    -- print("===refreshRank====",os.time())
    --段位
    rank_list.prestige = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKLIST_DATA,
            {t={["$gte"] = ranklist_setting.t}, prestige={["$gt"] = 0}},
            {_id = false, id=true, prestige = true, nickname=true, headimgurl=true,headframe=true,seg_prestige=true},
            {{prestige = -1,}}, 100) or {}
    rank_id_mac.prestige = {}
    for rank,data in ipairs(rank_list.prestige) do
        rank_id_mac.prestige[data.id] = {rank=rank,data=data}
        if rank == 1 then
            first_id_mac.prestige[rank] = data
        end
    end

    --身价
    rank_list.worth = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKLIST_DATA, {t={["$gte"] = ranklist_setting.t}}, 
            {_id = false, id=true, worth = true, nickname=true, headimgurl=true,headframe=true}, {{worth = -1,}}, 100) or {}
    rank_id_mac.worth = {}
    for rank,data in ipairs(rank_list.worth) do
        rank_id_mac.worth[data.id] = {rank=rank,data=data}
        if rank == 1 then
            first_id_mac.worth[rank] = data
        end
    end

    --奢华度
    rank_list.luxury = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKLIST_DATA, {t={["$gte"] = ranklist_setting.t}}, 
            {_id = false, id=true, luxury = true, nickname=true, headimgurl=true,headframe=true}, {{luxury = -1,}}, 100) or {}
    rank_id_mac.luxury = {}
    for rank,data in ipairs(rank_list.luxury) do
        rank_id_mac.luxury[data.id] = {rank=rank,data=data}
        if rank == 1 then
            first_id_mac.luxury[rank] = data
        end
    end

    --宠物段位排行榜
    rank_list.pet_level = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKLIST_DATA, {t={["$gte"] = ranklist_setting.t}}, 
            {_id = false, id=true, pet_level = true, nickname=true, headimgurl=true,headframe=true}, {{pet_level = -1,}}, 100) or {}
    rank_id_mac.pet_level = {}
    for rank,data in ipairs(rank_list.pet_level) do
        rank_id_mac.pet_level[data.id] = {rank=rank,data=data}
        if rank == 1 then
            first_id_mac.pet_level[rank] = data
        end
    end

    --看广告榜单
    rank_list.watch_ads = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKLIST_DATA, {t={["$gte"] = ranklist_setting.t}}, 
        {_id = false, id=true, watch_ads = true, nickname=true, headimgurl=true,headframe=true}, {{watch_ads = -1,}}, 20) or {}
    rank_id_mac.watch_ads = {}
    for rank,data in ipairs(rank_list.watch_ads) do
        rank_id_mac.watch_ads[data.id] = {rank=rank,data=data}
        if rank == 1 then
            first_id_mac.watch_ads[rank] = data
        end
    end
end

function CMD.time_count_down()
    -- body
end

function CMD.time_tick_op()
    if not check_same_month(ranklist_setting.t) then
        ranklist_setting.t = os.time()
        ranklist_setting.settle = ranklist_setting.settle + 1
        CMD.refreshRank()
        --设置奖励状态
       for id,item in pairs(rank_id_mac.prestige) do
            if item.rank <= 50 and (item.data.prestige > cfg_rank_grade[max_rank_grade_id].prestige) then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=id},{["hall_frame.erank"] = item.rank,["hall_frame.eprestige"]=item.data.prestige})
            end
        end
        
        skynet.call("db_mgr_del", "lua", "delete", COLL.RANKLIST_DATA, {t={["$lt"] = ranklist_setting.t}})
        skynet.call(get_db_mgr(),"lua","update",COLL.SETTING,{id="ranklist_setting"},ranklist_setting)
        -- rank_list.prestige = {}
        -- rank_id_mac.prestige = {}
        rank_list = {prestige={},worth={},luxury={},pet_level={},watch_ads={}}
        rank_id_mac = {prestige={},worth={},luxury={},pet_level={},watch_ads={}}
        first_id_mac = {prestige={},worth={},luxury={},pet_level={},watch_ads={}}
        playerInfo = {}
    end
    rank_cal_left_time = rank_cal_left_time - 1
    if rank_cal_left_time <= 0 then
        rank_cal_left_time = rank_cal_interval
        CMD.refreshRank()
        if #rank_list < 100 then
            --小于五千人10秒钟刷新一次
            rank_cal_left_time = 10
        end
    end
end

function CMD.time_tick()
    skynet.timeout(100, CMD.time_tick)
    CMD.time_tick_op()
end

--判断某个月是否已经结算过
-- function CMD.is_settled(t)
--     if check_same_month_p2(t, hall_frame_setting.t) then
--         return true
--     end
--     return 
-- end

function CMD.init()
    for id,_ in pairs(cfg_rank_grade) do
        if id > max_rank_grade_id then
            max_rank_grade_id = id
        end
    end

    ranklist_setting = skynet.call(get_db_mgr(), "lua", "find_one", COLL.SETTING, {id = "ranklist_setting"},
                                            {_id=false,t=true,settle=true})
    if not ranklist_setting then
        ranklist_setting = {}
        ranklist_setting.id = "ranklist_setting"
        ranklist_setting.t = os.time()
        ranklist_setting.settle = 1
        skynet.call(get_db_mgr(),"lua","insert",COLL.SETTING,ranklist_setting)
    end

    --段位
    rank_list.prestige = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKLIST_DATA, 
        {t={["$gte"] = ranklist_setting.t},prestige={["$gt"] = 0}},
        {_id = false, id=true, prestige = true,seg_prestige=true, nickname=true, headimgurl=true,headframe=true},
        {{prestige = -1,}}, 100) or {}
    rank_id_mac.prestige = {}
    for rank,data in ipairs(rank_list.prestige) do
        rank_id_mac.prestige[data.id] = {rank=rank,data=data}
        if rank == 1 then
            first_id_mac.prestige[rank] = data
        end
    end

    --身价
    rank_list.worth = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKLIST_DATA, {t={["$gte"] = ranklist_setting.t}}, 
            {_id = false, id=true, worth = true, nickname=true, headimgurl=true,headframe=true}, {{worth = -1,}}, 100) or {}
    rank_id_mac.worth = {}
    for rank,data in ipairs(rank_list.worth) do
        rank_id_mac.worth[data.id] = {rank=rank,data=data}
        if rank == 1 then
            first_id_mac.worth[rank] = data
        end
    end

    --奢华度
    rank_list.luxury = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKLIST_DATA, {t={["$gte"] = ranklist_setting.t}}, 
            {_id = false, id=true, luxury = true, nickname=true, headimgurl=true,headframe=true}, {{luxury = -1,}}, 100) or {}
    rank_id_mac.luxury = {}
    for rank,data in ipairs(rank_list.luxury) do
        rank_id_mac.luxury[data.id] = {rank=rank,data=data}
        if rank == 1 then
            first_id_mac.luxury[rank] = data
        end
    end

    --宠物段位排行榜
    rank_list.pet_level = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKLIST_DATA, {t={["$gte"] = ranklist_setting.t}}, 
            {_id = false, id=true, pet_level = true, nickname=true, headimgurl=true,headframe=true}, {{pet_level = -1,}}, 100) or {}
    rank_id_mac.pet_level = {}
    for rank,data in ipairs(rank_list.pet_level) do
        rank_id_mac.pet_level[data.id] = {rank=rank,data=data}
        if rank == 1 then
            first_id_mac.pet_level[rank] = data
        end
    end

    --看广告排行
    rank_list.watch_ads = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKLIST_DATA, {t={["$gte"] = ranklist_setting.t}}, 
        {_id = false, id=true, watch_ads = true, nickname=true, headimgurl=true,headframe=true}, {{watch_ads = -1,}}, 20) or {}
    rank_id_mac.watch_ads = {}
    for rank,data in ipairs(rank_list.watch_ads) do
        rank_id_mac.watch_ads[data.id] = {rank=rank,data=data}
        if rank == 1 then
            first_id_mac.watch_ads[rank] = data
        end
    end

    if not check_same_month(ranklist_setting.t) then
        print('===================发奖==========================')
        ranklist_setting.settle = ranklist_setting.settle + 1
        --设置奖励状态
        for id,item in pairs(rank_id_mac.prestige) do
            if item.rank <= 50 and (item.data.prestige > cfg_rank_grade[max_rank_grade_id].prestige) then
                print("rank",item.rank)
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=id},{["hall_frame.erank"] = item.rank,["hall_frame.eprestige"]=item.data.prestige})
            end
        end
        ranklist_setting.t = os.time()
        skynet.call("db_mgr_del", "lua", "delete", COLL.RANKLIST_DATA, {t={["$lt"] = ranklist_setting.t}})
        skynet.call(get_db_mgr(),"lua","update",COLL.SETTING,{id="ranklist_setting"},ranklist_setting)
        -- rank_list.prestige = {}
        -- rank_id_mac.prestige = {}
        rank_list = {prestige={},worth={},luxury={},pet_level={},watch_ads={}}
        rank_id_mac = {prestige={},worth={},luxury={},pet_level={},watch_ads={}}
        first_id_mac = {prestige={},worth={},luxury={},pet_level={},watch_ads={}}
        playerInfo = {}
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
    CMD.init()
    skynet.timeout(100, CMD.time_tick)
end)