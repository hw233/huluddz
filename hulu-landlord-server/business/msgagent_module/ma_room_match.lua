--ma_room_match
local ma_room_match = {}
--房间匹配
require "define"
local skynet = require "skynet"
local ma_data = require "ma_data"
local place_config = require "cfg/place_config"
local request = {}
ma_data.match_time = 0

function ma_room_match.get_choose_box_value( box )
    for _,b in ipairs(box) do
        if b.is_choose == true then
            return b.value
        end
    end
end

function ma_room_match.clear_match_time()
    ma_data.match_time = 0
end

function ma_room_match.set_matching(matching)
    ma_data.matching = matching
end

function ma_room_match.match_interval_check()
    local current_time = os.time()
    if current_time - ma_data.match_time <= 2 then
        return false
    end
    ma_data.match_time = current_time
    return true
end

--获取玩家信息
--modify by qc 2021.8.3 加入好牌开局开关
function ma_room_match.get_player_info(place_id,game_id,place_type,address,luck_start_ct)
    local player = {}
    -- ma_hall_rankinglist.get_action_num()
    local markNum = ma_data.db_info.markNum or 0
    if ma_data.db_info.gold < 1000000000 then
        markNum = 0
    elseif ((ma_data.db_info.bankgold or 0) + ma_data.db_info.gold) > 5000000000 and 
        ma_data.db_info.gold > 1000000000 and markNum ~= 1 then
        markNum = 2
    end
    if game_id ~= 1 and game_id ~= 2 and game_id ~= 3 and game_id ~= 4 and
        game_id ~= 8 and game_id ~= 9 and markNum ~= 1 then
        markNum = 0
    end
    local db_info = {nickname=ma_data.db_info.nickname,headimgurl=ma_data.db_info.headimgurl,sex=ma_data.db_info.sex,
            gold=ma_data.db_info.gold,diamond=ma_data.db_info.diamond,playinfo=ma_data.db_info.playinfo,
            hall_frame=ma_data.db_info.hall_frame,id=ma_data.db_info.id,half_photo = ma_data.db_info.half_photo
            ,isNew = ma_data.db_info.playinfo.total,
            headframe = ma_data.get_picture_frame(ma_data.db_info.backpack),
            human_drees = ma_data.get_human_drees_goods(ma_data.db_info.backpack),
            noRedNum = (ma_data.db_info.playinfo.noRedNum or 0),
            seg_prestige = ma_data.db_info.hall_frame.seg_prestige,
            petCoin = ma_data.get_goods_num(100012),
            markNum = markNum,
            matchMark = ma_data.db_info.matchMark or {},
            backpack = ma_data.db_info.backpack,
            viplv = ma_data.db_info.viplv,
            viphu = ma_data.get_vip_ability("huaward")  -- vip胡加成
            }
    player.place_id = place_id and place_type
    player.game_id = game_id
    player.address  =address
    player.agent = ma_data.my_agent
    player.dbinfo = db_info--ma_data.db_info
    player.id = ma_data.my_id
    player.prestige=ma_data.db_info.hall_frame.prestige
    player.luck_start_ct = luck_start_ct
    return player
end

--模糊匹配
function request:fuzzy_matching()
    ma_data.otherPetInfo = nil
    if ma_data.server_will_shutdown then
        ma_data.send_push('fuzzy_matching_err',{e_info = ERROR_INFO.Server_will_shutdown})
        ma_room_match.clear_match_time()
        return
    end
    local curr_time = os.time()
    if ma_data.db_info.forbid_time and ma_data.db_info.forbid_time > curr_time then
        ma_data.send_push('fuzzy_matching_err',{e_info = ERROR_INFO.STATE_ERROR})
        return
    end
    -- 在房间中
    if ma_data.my_room or not ma_room_match.match_interval_check() then
        ma_data.send_push('fuzzy_matching_err',{e_info = ERROR_INFO.Already_in_room})
        return 
    end
    if self.game_id or self.place_id then
        local place_type =  self.game_id * 100 + (self.place_id or 1)
        local rConf = place_config[self.game_id][self.place_id]
        print('===================加入匹配==============',self.game_id,self.place_id,ma_data.my_id)
        if rConf.stype == 4 then
            ma_data.send_push('fuzzy_matching_err',{e_info = ERROR_INFO.STATE_ERROR})
            return
        -- elseif rConf.stype == 3 then
        --     if not ma_data.ma_hall_frame.checkCanPlay() then
        --         ma_data.send_push('fuzzy_matching_err',{e_info = ERROR_INFO.STATE_ERROR})
        --         ma_room_match.clear_match_time()
        --         return
        --     end
        elseif rConf.stype == 2 then
            if ma_data.get_goods_num(100012) < rConf.need_min then
                 ma_data.send_push("fuzzy_matching_err",{e_info = ERROR_INFO.gold_not_enough})
                 ma_room_match.clear_match_time()
                return
            end
            if rConf.need_max ~= 0 and ma_data.get_goods_num(100012) > rConf.need_max then
                ma_data.send_push('fuzzy_matching_err',{e_info = ERROR_INFO.more_gold})
                ma_room_match.clear_match_time()
                return
            end
        else
            -- 金币不满足最低要求
            if ma_data.db_info.gold < rConf.need_min then
                 ma_data.send_push("fuzzy_matching_err",{e_info = ERROR_INFO.gold_not_enough})
                 ma_room_match.clear_match_time()
                return
            end
            if rConf.need_max ~= 0 and ma_data.db_info.gold > rConf.need_max then
                ma_data.send_push('fuzzy_matching_err',{e_info = ERROR_INFO.more_gold})
                ma_room_match.clear_match_time()
                return
            end
        end
        local luck_start_ct = 0
        if self.luck_start then
            --取得 广告 好牌统计次数 (tims % 3) + 1
            local ads_data = ma_data.ma_task.get_ads_data()
            local ads_num = ads_data.all[AD_SCENE_NAME.luck_card] and ads_data.all[AD_SCENE_NAME.luck_card][2]
            if ads_num then
                luck_start_ct = (ads_num % 3) + 1 
                print("====debug qc 好牌广告统计 传入参数  === luck_start_ct " ,ma_data.my_id,ads_num,luck_start_ct)
            end
        end
        local player = ma_room_match.get_player_info(self.place_id,self.game_id,place_type,self.address,luck_start_ct)
        ma_room_match.set_matching(true)
        skynet.send("matching_mgr","lua", "fuzzy_matching", player)
    end
end


--2v2模式匹配
--teaminfo详情
function request:matching2v2()
    print('===================matching2v2==============',ma_data.my_id,self.teamid)
    if ma_data.my_id ~= self.teamid then
        ma_data.send_push('matching2v2_err',{e_info = ERROR_INFO.TEAM_ERROR})
        ma_room_match.clear_match_time()
        return {e_info = 1}
    end
    ma_data.otherPetInfo = nil
    if ma_data.server_will_shutdown then
        ma_data.send_push('matching2v2_err',{e_info = ERROR_INFO.Server_will_shutdown})
        ma_room_match.clear_match_time()
        return  {e_info = 2}
    end
    local curr_time = os.time()
    if ma_data.db_info.forbid_time and ma_data.db_info.forbid_time > curr_time then
        ma_data.send_push('matching2v2_err',{e_info = ERROR_INFO.STATE_ERROR})
        return  {e_info = 3}
    end
    -- 在房间中
    if ma_data.my_room or not ma_room_match.match_interval_check() then
        ma_data.send_push('matching2v2_err',{e_info = ERROR_INFO.Already_in_room})
        return  {e_info = 4}
    end

    local teaminfo = skynet.call('team2v2_mgr',"lua","get_teaminfo",ma_data.my_id)
    if teaminfo == nil then
        ma_data.send_push('matching2v2_err',{e_info = ERROR_INFO.TEAM_ERROR})
        return  {e_info = 5}
    end            

    --队友信息 可能空
    local team_member = teaminfo.team_member[2]    
    local agent_member
    if team_member ~= nil then
        agent_member =  skynet.call("agent_mgr", "lua", "find_agent", team_member)
    end

    if teaminfo.gameid or teaminfo.placeid then
        local place_type =  teaminfo.gameid * 100 + (teaminfo.placeid or 1)
        local rConf = place_config[teaminfo.gameid][teaminfo.placeid]
        print('===================加入2v2匹配==============',ma_data.my_id)
        if rConf.stype == 4 then
            ma_data.send_push('matching2v2_err',{e_info = ERROR_INFO.STATE_ERROR})
            return  
        elseif rConf.stype == 2 then
            if ma_data.get_goods_num(100012) < rConf.need_min then
                 ma_data.send_push("matching2v2_err",{e_info = ERROR_INFO.gold_not_enough})
                 ma_room_match.clear_match_time()
                return  {e_info = 5}
            end
            if rConf.need_max ~= 0 and ma_data.get_goods_num(100012) > rConf.need_max then
                ma_data.send_push('matching2v2_err',{e_info = ERROR_INFO.more_gold})
                ma_room_match.clear_match_time()
                return {e_info = 5}
            end
        else
                
            -- 金币不满足最低要求
            -- print("===debug qc====  master 匹配金币检验 ",ma_data.db_info.gold)
            if ma_data.db_info.gold < rConf.need_min then
                print("===debug qc====  master 金币不足")
                 ma_data.send_push("matching2v2_err",{e_info = ERROR_INFO.gold_not_enough})
                 if agent_member then
                    skynet.call(agent_member, "lua", "send_push", "matching2v2_err",{e_info = ERROR_INFO.gold_not_enough})
                 end
                 ma_room_match.clear_match_time()
                return {e_info = 6}
            end           
                
            if agent_member then
                local member_gold = skynet.call(agent_member,"lua","get_db_gold")
                -- print("===debug qc====  memeber 匹配金币检验",member_gold)
                --队友金币判断
                if member_gold < rConf.need_min then
                    print("===debug qc====  memeber 金币不足")
                    ma_data.send_push("matching2v2_err",{e_info = ERROR_INFO.gold_not_enough})
                    skynet.call(agent_member, "lua", "send_push", "matching2v2_err",{e_info = ERROR_INFO.gold_not_enough})
                    ma_room_match.clear_match_time()
                    return {e_info = 7}
                end
            end                     
            --取消上限判断
            -- if rConf.need_max ~= 0 and ma_data.db_info.gold > rConf.need_max then
            --     ma_data.send_push('matching2v2_err',{e_info = ERROR_INFO.more_gold})
            --     ma_room_match.clear_match_time()
            --     return
            -- end

        end
        local ret = skynet.call("team2v2_mgr", "lua", "Start_match2v2",ma_data.my_id,self.teamid)
        if not ret then            
            ma_data.send_push('matching2v2_err',{e_info = ERROR_INFO.TEAM_ERROR})--team操作失败
            print("===debug qc====  team 匹配操作失败")
            return {e_info = 8}
        end

        local player = ma_room_match.get_player_info(teaminfo.placeid,teaminfo.gameid,place_type,self.address)
        ma_room_match.set_matching(true)
        
        local player_member
        --取得队友匹配player
        if agent_member then
            player_member = skynet.call(agent_member,"lua","get_player_info",teaminfo.placeid,teaminfo.gameid,place_type)
        end

        --房主2v2匹配 提交teamid 人数
        print("====debug qc==== team2v2_set_match 开始匹配了",self.teamid)
        skynet.send("matching_mgr","lua", "matching_qc2v2", {player,player_member},self.teamid,teaminfo.team_member)

        return {e_info = 0}
    end
    return {e_info = 9}
end


--获取房间人数
--self.room_count 房间数量
function request:get_room_player_count()
    local player_count = {}
    for i=1,self.room_count do
        player_count[i] = math.random(MIN_PLAYER_COUNT,MAX_PLAYER_COUNT)
    end

    return {player_count = player_count}
end

--移除匹配队列
function request:remove_matching()
	local result = skynet.call('matching_mgr',"lua","remove_matching",ma_data.my_id)
	ma_room_match.clear_match_time()
    if result then
        ma_room_match.set_matching(false)
    end
    return {result = result}
end

--移除2v2匹配
function request:cancel_matching2v2()
    local teaminfo = skynet.call('team2v2_mgr',"lua","get_teaminfo",ma_data.my_id)
    if teaminfo == nil then
        ma_data.send_push('fuzzy_matching_err',{e_info = ERROR_INFO.TEAM_ERROR})
        return 5
    end

    local ret = skynet.call('team2v2_mgr',"lua","Cancel_match2v2",ma_data.my_id,ma_data.my_id)
    print("====debug qc==== Cancel_match2v2 取消匹配结果",ret)
    if not ret then
        ma_data.send_push('matching2v2_err',{e_info = ERROR_INFO.TEAM_ERROR})--team操作失败
        print("===debug qc==== team 取消匹配操作失败")
        return 8
    end

    -- --队友信息 可能空
    -- local team_member = teaminfo.team_member[2]    
    -- local agent_member
    -- if team_member ~= nil then
    --     agent_member =  skynet.call("agent_mgr", "lua", "find_agent", team_member)
    -- end
    -- --通知队友取消匹配
    -- if agent_member then
    --     skynet.call(agent_member,"lua","remove_matching2v2",ma_data.my_id)
    -- end

    print("====debug qc==== team2v2_set_match 取消匹配了",ma_data.my_id)
    local result = skynet.call('matching_mgr',"lua","remove_matching2v2",ma_data.my_id)
	ma_room_match.clear_match_time()
    if result then
        ma_room_match.set_matching(false)
    end
    return 0
end

---------------------------------------------------------------------------
--开房间
-- 加入房间设置
function ma_room_match.join_room_limit(needGlv)
    if ma_data.server_will_shutdown or ma_data.forbid_create_room then
        ma_data.send_push('joinresult', {result = false, e_info = ERROR_INFO.Server_will_shutdown})
        return false
    end

    if ma_data.my_room then
        ma_data.send_push('joinresult', {result = false, e_info = ERROR_INFO.Already_in_room})
        return false
    end
    return true
end

--加入房间
function ma_room_match.join_room_complete(room_id,address,password)
    local room,info = skynet.call('agent_mgr','lua','find_room',room_id)
    if room then
        if info.place_nature == 'friend' then
            -- if info.password then
            --     if not password or info.password ~= password then
            --         ma_data.send_push('joinresult', {result = false,e_info = ERROR_INFO.Error_password})
            --         return
            --     end
            -- end
           local need_gold = friend_gold_config[info.needGlv].need_gold

            if ma_data.db_info.gold < need_gold then
                ma_data.send_push('joinresult', {result = false,e_info = ERROR_INFO.gold_not_enough,needGlv = info.needGlv})
                return
            end
            -- local insure_lv = ma_data.ma_people_insure.get_my_insures_lv()
            skynet.send(room, "lua", "join", ma_data.my_id, ma_data.my_agent, ma_data.db_info, address,ma_data.title_info)
        else
            ma_data.send_push('joinresult', {result = false,e_info = ERROR_INFO.Not_friend})
        end
    else
        --print('==============================房间不存在',ERROR_INFO.Room_not_find)
        ma_data.send_push('joinresult',{result = false,e_info = ERROR_INFO.Room_not_find})
    end
end
-- 玩家加入房间
function request:join_room()
    --print('========================room_id=================',self.room_id,self.address)
    if ma_room_match.join_room_limit() then
        ma_room_match.join_room_complete(self.room_id,self.address,self.password)
    end
end


--创建房间
function ma_room_match.create_room_complete(pattern,place_nature,needGlv,password)
    if ma_data.server_will_shutdown or ma_data.forbid_create_room then
        return {result = false, e_info = ERROR_INFO.Server_will_shutdown}
    end

    if ma_data.my_room then
        return {result = false, e_info = ERROR_INFO.Already_in_room}
    end

    if ma_data.db_info.diamond < 1 then
        return {result = false, e_info = ERROR_INFO.diamond_not_enough}
    end
    local need_gold = friend_gold_config[needGlv].need_gold

    if ma_data.db_info.gold < need_gold then
        return {result = false, e_info = ERROR_INFO.gold_not_enough}
    end
    
    local conf = {
        owner = ma_data.my_id,
        owner_name = ma_data.db_info.nickname,
        pattern = pattern,
        playernum = pattern.player_num,
        team_num = pattern.team_num,
        place_id = 3,
        real_name = pattern.real_name,
        clubid   = pattern.real_name,
        place_nature = place_nature,
        needGlv = needGlv
    }

    for i,op in ipairs(conf.pattern.option) do
        if op.real_name == 'playMethod' then  
            conf.playmethod = {}
            for i,box in ipairs(op.box) do
                if box.is_choose then
                    conf.playmethod[box.real_name] = true
                end
            end
        else
            conf[op.real_name] = ma_room_match.get_choose_box_value(op.box)
        end
    end
    local room_id, room_server = skynet.call("agent_mgr", "lua", "create_room",conf,pattern.real_name,3,place_nature,password)
    if room_server then
        -- local insure_lv = ma_data.ma_people_insure.get_my_insures_lv()
        skynet.send(room_server, "lua", "join", ma_data.my_id,ma_data.my_agent,ma_data.db_info, ma_data.address,ma_data.title_info) 
    end
    return {result = true,room_id = room_id,place_type = pattern.real_name,place_nature = place_nature}
end

--创建朋友局房间
function request:create_room_friend()
    local result = ma_room_match.create_room_complete(self.pattern,self.place_nature,self.needGlv,self.password)
    return result
end

--创建2v2房间
-- function request:create_room_2v2()
--     local result = ma_room_match.create_room_complete(self.pattern,self.place_nature,self.needGlv,self.password)
--     return result
-- end

-- -- 玩家加入2v2房间
-- function request:join_room_2v2()
--     --print('========================room_id=================',self.room_id,self.address)
--     if ma_room_match.join_room_limit() then
--         ma_room_match.join_room_complete(self.room_id,self.address,self.password)
--     end
-- end

--获取房间列表
function request:get_friend_rooms()
    local room_infos = skynet.call('agent_mgr','lua','get_friend_rooms',self.room_id)
    return {room_infos = room_infos}
end

--更改房间密码
function request:change_password()
    local result = skynet.call('agent_mgr','lua','change_password',ma_data.my_id,self.room_id,self.password)
    return result
end
---------------------------------------------------------------------------
---------------------------------------------------------------------------
function ma_room_match.init(REQUEST,CMD)
    if request then
        table.connect(REQUEST,request)
    end
    if cmd then
        table.connect(CMD,cmd)
    end
end

return ma_room_match