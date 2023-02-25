local skynet = require "skynet"
local ma_data = require "ma_data"
local cfg_rank_grade = require "cfg.cfg_rank_grade"
local cfg_global = require "cfg.cfg_global"
local COLLECTIONS = require "config/collections"
local cfg_items = require "cfg.cfg_items"
local request = {}
local cmd = {}
local M = {}
--获取名人堂
function request:get_hall_frame_info()
    local setting = skynet.call("ranklist_mgr","lua","get_setting")
    return {t=ma_data.db_info.hall_frame.t,prestige=ma_data.db_info.hall_frame.prestige,
            award_status=ma_data.db_info.hall_frame.award_status,max_prestige=ma_data.db_info.hall_frame.max_prestige,
            erank = ma_data.db_info.hall_frame.erank,seg_prestige=ma_data.db_info.hall_frame.seg_prestige,
            currLv = setting.settle,winc = ma_data.db_info.hall_frame.winc,total = ma_data.db_info.hall_frame.total,
            count = (ma_data.db_info.hall_frame.count or cfg_global[1].rank_num),
            buy_count = (ma_data.db_info.hall_frame.buy_count or 0)}
end

--获取好友声望值
--self.list 好友id列表
function request:hall_frame_get_fri_prestige()
    return {list = skynet.call("ranklist_mgr","lua","get_fri_rank_info",self.list) or {}}
end

--获取排行榜
--self.start --开始位置
--self.num --获取条数
function request:hall_frame_get_list()
    return {list = skynet.call("ranklist_mgr","lua","get_rank_list","prestige",self.start,self.num) or {}}
end

--获取玩家名人堂详细信息
--self.id 用户id
function request:hall_frame_get_detail_info()
    local rank,prestige,seg_prestige = skynet.call("ranklist_mgr","lua", "get_rank",self.name,self.id)
    local userInfo = skynet.call(get_db_mgr(),"lua","find_one",COLLECTIONS.USER,{id=self.id},{backpack=true,sex=true,
        hall_frame=true})
    if not userInfo then
        return {}
    end
    local humandress = ma_data.get_human_drees_goods(userInfo.backpack)
    local petdress = ma_data.get_pet_drees_goods(userInfo.backpack)
    return {rank=rank,prestige=userInfo.hall_frame.prestige,hdress=humandress,pdress=petdress,sex=sex,
            seg_prestige=userInfo.hall_frame.seg_prestige,max_prestige=userInfo.hall_frame.max_prestige,
            total = userInfo.hall_frame.total,winc = userInfo.hall_frame.winc}
end

--领取段位奖励
--self.award_id 奖励ID
function request:hall_frame_get_award()
    print('===================领取段位奖励=====',self.award_id)
    local awardItem = cfg_rank_grade[self.award_id]
    if (not awardItem) or (not awardItem.award) then
        --奖励不存啊
        return {result = 1}
    end
    if awardItem.prestige > ma_data.db_info.hall_frame.max_prestige then
        --未达到领取条件
        return {result = 2}
    end
    if is_award_getted(ma_data.db_info.hall_frame.award_status,awardItem.award_num) then
        --奖励已经领取过了
        return {result = 3}
    end
    local award = awardItem.award
    ma_data.add_goods_list(award,GOODS_WAY_HALL_FRAME_SEG,"名人堂段位奖励")
    set_award_getted(ma_data.db_info.hall_frame,"award_status",awardItem.award_num)
    ma_data.send_push("buy_suc", {
        goods_list = award,
        msgbox = 1
    })
    M.flush()
    print("hall_frame_get_award",award_status)
    return {result = 0,award_status=ma_data.db_info.hall_frame.award_status}
end

--获取荣耀信息
function request:get_honor()
    -- print('======================get_honor==============',self.pid)
    -- table.print(ma_data.lastRankInfo)
    local setting = skynet.call("ranklist_mgr","lua","get_setting")
    table.print(setting)
    if self.pid == ma_data.my_id and ma_data.lastRankInfo then
        return {tking = ma_data.lastRankInfo.tking,frame = ma_data.lastRankInfo.frame,currLv = setting.settle}
    elseif self.pid then
        local lastRankInfo = skynet.call(get_db_mgr(), "lua", "find_one", COLLECTIONS.LASTRANK_DATA, {pid = self.pid})
        if not lastRankInfo then
            lastRankInfo = {}
            lastRankInfo.pid = self.pid
            lastRankInfo.tking = {[1]=0,[2]=0,[3]=0}
            lastRankInfo.frame = {}
        end
        if self.pid == ma_data.my_id then
            ma_data.lastRankInfo = lastRankInfo
        end
        return {tking = lastRankInfo.tking,frame = lastRankInfo.frame,currLv = setting.settle}
    end
end

--检测能不能进入游戏
function M.checkCanPlay()
    if not ma_data.db_info.hall_frame.count then
        return true
    end
    if ma_data.db_info.hall_frame.count <= 0 then
        return false
    end
    return true
end

--检测日更新
function M.check_reset_day()
    -- if not ma_data.db_info.hall_frame.dayt or not check_same_day(ma_data.db_info.hall_frame.dayt) then
    --     ma_data.db_info.hall_frame.buy_count = 0
    --     ma_data.db_info.hall_frame.count = cfg_global[1].rank_num
    --     ma_data.db_info.hall_frame.dayt = os.time()
    --     M.flush()
    -- end
end

--购买次数
function request:BuyFramePlayCount()
    -- M.check_reset_day()
    -- local monthcardType = ma_data.ma_month_card.get_type()
    -- local max_buy_count = cfg_month_card[1]["rank"..monthcardType] or 1
    -- if max_buy_count <= 0 then
    --     return {result = 1}
    -- end
    -- if (ma_data.db_info.hall_frame.buy_count or 0) < max_buy_count then
    --     local needGoods = cfg_global[1].rank_pay
    --     if ma_data.db_info.diamond  < needGoods.num then
    --         return {result = 3}
    --     end
    --     ma_data.add_diamond(-needGoods.num, GOODS_WAY_DIAMOND_BUY, "钻石购买名人堂次数")
    --     ma_data.db_info.hall_frame.buy_count = (ma_data.db_info.hall_frame.buy_count or 0) + 1
    --     ma_data.db_info.hall_frame.count =  (ma_data.db_info.hall_frame.count or cfg_global[1].rank_num) + 1
    --     M.flush()
    --     return {result = 0, buy_count = ma_data.db_info.hall_frame.buy_count,count=ma_data.db_info.hall_frame.count}
    -- end
    return {result = 4}
end

function M.get_seg_by_prestige(prestige)
    local max_id = nil
    for id,item in pairs(cfg_rank_grade) do
        if item.prestige >=0 and item.prestige <= prestige then
            if (not max_id) or (id > max_id) then
                max_id = id
            end
        end
    end
    return max_id or 100001
end

--结算声望
--prestige --变化的声望
function M.hall_frame_settle(prestige)
    M.check_reset()
    table.print(ma_data.db_info.hall_frame)
   
    ma_data.db_info.hall_frame.prestige = ma_data.db_info.hall_frame.prestige + prestige
    if ma_data.db_info.hall_frame.prestige < 0 then
        ma_data.db_info.hall_frame.prestige = 0
    end

    if ma_data.db_info.hall_frame.prestige > ma_data.db_info.hall_frame.max_prestige then
        ma_data.db_info.hall_frame.max_prestige = ma_data.db_info.hall_frame.prestige
    end
    local tmpSeg = M.get_seg_by_prestige(ma_data.db_info.hall_frame.prestige)
    local curSeg = M.get_seg_by_prestige(ma_data.db_info.hall_frame.seg_prestige)
    --相同段位分数增减
    if ma_data.db_info.hall_frame.prestige > ma_data.db_info.hall_frame.seg_prestige then
        ma_data.db_info.hall_frame.seg_prestige = ma_data.db_info.hall_frame.prestige
    else
        if cfg_rank_grade[curSeg].down_star > 0 and cfg_rank_grade[curSeg].down_lv > 0 then
            if cfg_rank_grade[tmpSeg].down_star > 0 and cfg_rank_grade[tmpSeg].down_lv > 0 then
                ma_data.db_info.hall_frame.seg_prestige = ma_data.db_info.hall_frame.prestige
            else
                ma_data.db_info.hall_frame.seg_prestige = cfg_rank_grade[100011].prestige
            end
        elseif cfg_rank_grade[curSeg].down_star > 0 and cfg_rank_grade[curSeg].down_lv == 0 then
            --有星星增减，无段位增减
            if cfg_rank_grade[tmpSeg].down_star == 0 then
                 ma_data.db_info.hall_frame.seg_prestige = cfg_rank_grade[100006].prestige
            else
                ma_data.db_info.hall_frame.seg_prestige = ma_data.db_info.hall_frame.prestige
            end
        elseif cfg_rank_grade[curSeg].down_lv == 0 and cfg_rank_grade[curSeg].down_star == 0 then
            --有段位有星级保护
            ma_data.db_info.hall_frame.seg_prestige = cfg_rank_grade[curSeg].prestige
        end
    end
   
    
    if prestige > 0 then
        ma_data.db_info.hall_frame.winc = ma_data.db_info.hall_frame.winc + 1
        if curSeg ~= tmpSeg and tmpSeg >= 100021
            and cfg_rank_grade[curSeg].level ~= cfg_rank_grade[tmpSeg].level then
            local automsg = {[1]=ma_data.db_info.nickname}
            skynet.send("services_mgr", "lua", "activeNotice",1,(cfg_rank_grade[tmpSeg].level - 4),automsg)
        end
    end
    ma_data.db_info.hall_frame.total = ma_data.db_info.hall_frame.total + 1
    --储存游戏数据（我的ID，输赢，总局数，最高分数）
    print('==========================变化的数据=========',ma_data.my_id,ma_data.db_info.hall_frame.prestige,
            ma_data.db_info.hall_frame.seg_prestige)
    --更新排行榜数据
    if not ma_data.db_info.markNum or ma_data.db_info.markNum ~= 3 then
        skynet.call("ranklist_mgr","lua","update_prestige",ma_data.my_id,ma_data.db_info.hall_frame.prestige,
                ma_data.db_info.hall_frame.seg_prestige,
                ma_data.db_info.nickname,ma_data.db_info.headimgurl,ma_data.get_picture_frame(ma_data.db_info.backpack))
    end
    M.flush()
    curSeg = M.get_seg_by_prestige(ma_data.db_info.hall_frame.seg_prestige)
    ma_data.ma_spread.addGradingLv(cfg_rank_grade[curSeg].level)
    return curSeg
end

--更新游戏次数
function M.update_play_num()
    ma_data.db_info.hall_frame.count = (ma_data.db_info.hall_frame.count or cfg_global[1].rank_num) - 1
    M.flush()
end
--各种加成系数
function M.frame_buff_num()
    local goods = ma_data.get_human_drees_goods()
    local ret = 1
    print('============各种加成系数==============')
    table.print(goods)
    for _,dress in ipairs(goods) do
        local tmpCfg = cfg_items[dress.id]
        ret = ret + tmpCfg.prestige / 10000
    end
    return ret
end

--段位奖励重新发放
function M.reload_LV_award()
    --print('============段位奖励重新发放===========',ma_data.db_info.hall_frame.t)
    if ma_data.db_info.hall_frame.t <= 1606791600 then
        --print('============段位奖励重新发放xxxxxxxxx===========')
        --数据库寻找历史战绩
        local lastRankInfo = skynet.call(get_db_mgr(), "lua", "find_one", COLLECTIONS.LASTRANK_DATA, {pid = ma_data.my_id})
        local fiveInfo = nil
        if lastRankInfo then
            for i,info in ipairs(lastRankInfo.frame) do
                if info.sportsLv == 5 then
                    fiveInfo = info
                    break
                end
            end
        end
        --print('====================段位奖励重新发放111')
        if not fiveInfo then
            return
        end
        local max_prestige = fiveInfo.max_prestige
        local tempText = 'rank_award'..5
        local max_id = nil
        for id,item in pairs(cfg_rank_grade) do
            if item[tempText] and item.prestige <= max_prestige then
                if (not max_id) or (id > max_id) then
                    max_id = id
                end
            end
        end
        --print('====================段位奖励重新发放222222',max_id)
        if max_id then
            local award = cfg_rank_grade[max_id][tempText]
            local mail =  {
            title = "赛季奖励",
            content = [[恭喜您！上个赛季雀神名人堂获得最高段位<font color="#ff0000">]]
                     .. cfg_rank_grade[max_id].grade_name ..
                      [[</font>，获得如下奖励请及时领取。]],
            attachment = award,
            mail_type = MAIL_TYPE_OTHER,
            mail_stype = MAIL_STYPE_AWARD,
            -- friend_name = ma_data.db_info.nickname,
            -- friend_head = ma_data.db_info.headimgurl
            }
            skynet.call("mail_mgr", "lua", "send_mail", ma_data.my_id, mail)
        end
        ma_data.db_info.hall_frame.t = os.time()
        M.flush()
    end
end
--重置检测
function M.check_reset()
    M.check_reset_day()
    --print('======================重置检测====================',ma_data.db_info.hall_frame.t)
    M.reload_LV_award()
    local setting = skynet.call("ranklist_mgr","lua","get_setting")
    if not check_same_month(ma_data.db_info.hall_frame.t) then
        skynet.fork(function()
            skynet.sleep(math.random(1,20))
        
            local db_frame = skynet.call(get_db_mgr(),"lua","find_one",COLLECTIONS.USER,{id = ma_data.my_id},{_id = false,hall_frame = true})
            if db_frame then
                ma_data.db_info.hall_frame = db_frame.hall_frame
            end
            --赛季结束
            --print('==================赛季结束===============================',ma_data.my_id)
            --table.print(ma_data.db_info.hall_frame)
            local tempText = 'rank_award'..math.floor(setting.settle - 1)
            if ma_data.db_info.hall_frame.max_prestige > 0 then
                --print('=====================赛季结束奖励============',tempText)
                --发送赛季奖励
                local max_prestige = ma_data.db_info.hall_frame.max_prestige
                local max_id = nil
                for id,item in pairs(cfg_rank_grade) do
                    --print('===============赛季结束==',item[tempText],item.prestige,max_prestige)
                    if item[tempText] and item.prestige <= max_prestige then
                        --print('===============赛季结束==',max_id,id,max_id)
                        if (not max_id) or (id > max_id) then
                            max_id = id
                        end
                    end
                end
                --print('=====================max_id===================',max_id)
                if max_id then
                    local award = cfg_rank_grade[max_id][tempText]
                    local mail =  {
                    title = "赛季奖励",
                    content = [["恭喜您！上个赛季雀神名人堂获得最高段位<font color="#ff0000">"]]
                                .. cfg_rank_grade[max_id].grade_name ..
                                [[</font>，获得如下奖励请及时领取]],
                    attachment = award,
                    mail_type = MAIL_TYPE_OTHER,
                    mail_stype = MAIL_STYPE_AWARD,
                    -- friend_name = ma_data.db_info.nickname,
                    -- friend_head = ma_data.db_info.headimgurl
                    }
                    skynet.call("mail_mgr", "lua", "send_mail", ma_data.my_id, mail)
                end
            end
            local frame_info = {max_prestige = ma_data.db_info.hall_frame.max_prestige,
                                winc = ma_data.db_info.hall_frame.winc,
                                total = ma_data.db_info.hall_frame.total,
                                erank = ma_data.db_info.hall_frame.erank
                                }
            if frame_info.total and frame_info.total > 0 then
                M.insertLastRank(frame_info)
            end
            ma_data.db_info.hall_frame.t = os.time()
            ma_data.db_info.hall_frame.seg_prestige = 1000
            ma_data.db_info.hall_frame.award_status = 0
            ma_data.db_info.hall_frame.max_prestige = 1000
            ma_data.db_info.hall_frame.winc = 0
            ma_data.db_info.hall_frame.total = 0
            if ma_data.db_info.hall_frame.erank > 50 or ma_data.db_info.hall_frame.erank == 0 then
                ma_data.db_info.hall_frame.erank = 0
                ma_data.db_info.hall_frame.prestige = 1000
            end
            M.flush()
            --雀神奖励
            if ma_data.db_info.hall_frame.erank > 0 and ma_data.db_info.hall_frame.erank <= 50 and M.get_seg_by_prestige(ma_data.db_info.hall_frame.prestige) >= 100035 then
                --发送雀神奖励
                local erank = ma_data.db_info.hall_frame.erank
                local award = nil 
                for _,awardItem in ipairs(cfg_win_game_award) do
                    if erank >= awardItem.ranking[1] and erank <= awardItem.ranking[2] then
                        award = awardItem.award
                    end
                end 
                local mail =  {
                        title = "雀神奖励",
                        content = [[恭喜您！上个赛季雀神名人堂获得
                                <font color="#ff0000">雀神</font>称号，
                            获得如下奖励请及时领取。]],
                        attachment = award,
                        mail_type = MAIL_TYPE_OTHER,
                        mail_stype = MAIL_STYPE_AWARD,
                        -- friend_name = ma_data.db_info.nickname,
                        -- friend_head = ma_data.db_info.headimgurl
                        }
                skynet.call("mail_mgr", "lua", "send_mail", ma_data.my_id, mail)
            end
            if ma_data.db_info.hall_frame.erank > 0 then
                ma_data.db_info.hall_frame.erank = 0
                ma_data.db_info.hall_frame.eprestige = 0
                ma_data.db_info.hall_frame.prestige = 1000
                M.flush()
            end
        --print('==================赛季结束2===============================',ma_data.my_id)
        --table.print(ma_data.db_info.hall_frame)
        end)
    end
end

function M.flush()
    skynet.call(get_db_mgr(), "lua", "update", COLLECTIONS.USER, {id = ma_data.my_id},{hall_frame=ma_data.db_info.hall_frame})
end

function M.insertLastRank(frame_info,erank)
    local lastRankInfo = skynet.call(get_db_mgr(), "lua", "find_one", COLLECTIONS.LASTRANK_DATA, {pid = ma_data.my_id})
    local setting = skynet.call("ranklist_mgr","lua","get_setting")
    if not lastRankInfo then
        lastRankInfo = {}
        lastRankInfo.pid = ma_data.my_id
        lastRankInfo.tking = {[1]=0,[2]=0,[3]=0}
        lastRankInfo.frame = {}
        --skynet.error('xxxxxxxxxxxxxxxxxxsssssssss',erank)
        if erank and lastRankInfo.tking[erank]then
            lastRankInfo.tking[erank] = (lastRankInfo.tking[erank] or 0) + 1
        end
        if frame_info then
            print('=================录入赛季===========================')
            table.print(setting)
            frame_info.sportsLv = setting.settle - 1
            table.insert(lastRankInfo.frame,frame_info)
        end
        skynet.call(get_db_mgr(), "lua", "insert", COLLECTIONS.LASTRANK_DATA,lastRankInfo)
    else
        if erank and erank <= 3 then 
            if not lastRankInfo.tking[erank] then
                lastRankInfo.tking = {[1]=0,[2]=0,[3]=0}
            end
            lastRankInfo.tking[erank] = (lastRankInfo.tking[erank] or 0) + 1
        end

        if frame_info then
            if not lastRankInfo.frame then
                lastRankInfo.frame = {}
            end
            print('=================录入赛季新===========================')
            table.print(setting)
            frame_info.sportsLv = setting.settle - 1
            table.insert(lastRankInfo.frame,frame_info)
        end
        skynet.call(get_db_mgr(), "lua", "update", COLLECTIONS.LASTRANK_DATA, {pid = ma_data.my_id},lastRankInfo)
    end
    ma_data.lastRankInfo = lastRankInfo
end

function M.reload_lastRankInfo()
    local lastRankTbls = skynet.call(get_db_mgr(), "lua", "find_all", COLLECTIONS.LASTRANK_DATA, {pid = ma_data.my_id})
    if lastRankTbls and #lastRankTbls > 1 then
        local tempTbl = {}
        tempTbl.pid = ma_data.my_id
        tempTbl.tking = {[1]=0,[2]=0,[3]=0}
        tempTbl.frame = {}
        for _,Info in ipairs(lastRankTbls) do
            if Info.frame then
                for i,v in ipairs(Info.frame) do
                    table.insert(tempTbl.frame,v)
                end
            end
            if Info.tking then
                for i=1,3 do
                    tempTbl.tking[i] = tempTbl.tking[i] + (Info.tking[i] or 0)
                end
            end
        end
        ma_data.lastRankInfo = tempTbl
        skynet.call("db_mgr_del", "lua", "delete", COLLECTIONS.LASTRANK_DATA, {pid = ma_data.my_id})
        skynet.call(get_db_mgr(), "lua", "insert", COLLECTIONS.LASTRANK_DATA, tempTbl)
    end
end

function M.load()
    --print('===============创建hall_frame==========')
    if not ma_data.db_info.hall_frame then
        --print('===============创建hall_frame2222==========')
        ma_data.db_info.hall_frame = {}
        ma_data.db_info.hall_frame.t = os.time()
        ma_data.db_info.hall_frame.prestige = 1000
        ma_data.db_info.hall_frame.seg_prestige = 1000
        ma_data.db_info.hall_frame.erank = 0
        ma_data.db_info.hall_frame.award_status = 0
        ma_data.db_info.hall_frame.max_prestige = 1000
        ma_data.db_info.hall_frame.eprestige = 0
        ma_data.db_info.hall_frame.winc = 0
        ma_data.db_info.hall_frame.total = 0
    end
    M.reload_lastRankInfo()
    --table.print(ma_data.db_info.hall_frame)
    M.check_reset()
    --测试排行榜数据
    --skynet.call("ranklist_mgr","lua","update_prestige",ma_data.my_id,math.random(100,1000),ma_data.db_info.nickname,ma_data.db_info.headimgurl)
end

function M.init(REQUEST, CMD)
    if request then
        table.connect(REQUEST, request)
    end
    if cmd then
        table.connect(CMD, cmd)
    end
    M.load()
end
ma_data.ma_hall_frame = M
return M
