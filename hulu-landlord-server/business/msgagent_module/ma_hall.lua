require "define"
require "pub_util"
local ma_hall = {}
local skynet = require "skynet"
local ma_data = require "ma_data"
local httpc = require "http.httpc"
local crypt = require "skynet.crypt"
local cjson = require "cjson"
local ma_hall_order = require "msgagent_module.ma_hall_order"
local ma_hall_store = require "msgagent_module.ma_hall_store"
local ma_hall_mail = require "msgagent_module.ma_hall_mail"
local ma_lamp = require "msgagent_module.ma_lamp"
local ma_hall_ranklist = require "msgagent_module.ma_hall_ranklist"
local ma_hall_active = require "msgagent_module.ma_hall_active"
local ma_admin = require "msgagent_module.ma_admin"
local ma_share = require "msgagent_module.ma_share"
local ma_dress      =   require "ma_dress"
local ma_month_card = require "ma_month_card"
local ma_growth_plan = require "ma_growth_plan"
local ma_day_comsume = require "ma_day_comsume"
local ma_seven_day_sign = require "ma_seven_day_sign"
local ma_common = require "ma_common"
local ma_hall_frame = require "ma_hall_frame"
local ma_heilao = require "ma_heilao"
local ma_spread = require "ma_spread"
local ma_hall_bank = require "ma_hall_bank"
local ma_team2v2 = require "ma_team2v2"
local timer = require "timer"


local ma_hall_entity = require "ma_hall_entity"
local place_config = (require "cfg.place_config")
--local cfg_game_type = (require "cfg.cfg_global")[1].game_type
--local certification = (require "cfg.cfg_global")[1].certification

-- local xixi_reward_prixbasic = (require "cfg.cfg_global")[1].prixbasic --嘻嘻大奖初始值 5000
-- local xixi_reward_prixlimit = (require "cfg.cfg_global")[1].prixlimit --嘻嘻大奖封顶值 100
-- local xixi_reward_prixVexpCount = (require "cfg.cfg_global")[1].prixVexpCount --嘻嘻大奖每日富豪点限次
-- local xixi_reward_prixVexpGoods = ((require "cfg.cfg_global")[1].prixVexpNum or {})[1] --嘻嘻大奖富豪点奖励 {{id=110002,num=5}},

--local match_num = (require "cfg.cfg_global")[1].match_num
--local filter_sensitive_words = require "utils.filter_sensitive_words"
local get_vc_phone, verify_code, last_get_verify_time
local main_node = (skynet.getenv "node") == "main"
local main_node_host = skynet.getenv "main_node_host"
local COLL = require "config/collections"

local request = {}
local cmd = {}

local loadstring = rawget(_G, "loadstring") or load


--截取字符串
--begin_str 初始值
--temp_str 截取值
local function get_sub_str(begin_str,temp_str)
    local frist,second = string.find(begin_str,temp_str)
    if frist==nil or second == nil then
        return nil
    end
    
    begin_str = string.sub(begin_str,second+1)
    frist,second = string.find(begin_str,"\"")
    return string.sub(begin_str,1,second-1),begin_str
end

--判断多余表
--date_table 原始表
--temp_table 插入表
local function is_extra_table(date_table,temp_table)

    local is_extra = false
    for _, v in pairs(date_table) do
        --去掉多余以及非节假日
        -- if v.date == temp_table.date then
        if v.date == temp_table.date or temp_table.status == "2" then
            is_extra = true
            break
        end
    end

    if not is_extra then
        table.insert(date_table, temp_table)
    end

end

--判断是不是当前年
function ma_hall.not_cur_year(date,old_date)
    -- print("not_cur_year***",string.sub(date,1,4),string.sub(old_date,1,4))
    if string.sub(date,1,4) ~= string.sub(old_date,1,4) then
        return true
    end
    return false
end

--判断法定节假日
function ma_hall.is_holiday()

    local date = os.date("%Y-%m-%d")
    if not ma_data.db_info.holiday or ma_hall.not_cur_year(date,ma_data.db_info.holiday[1].date) then
        ma_data.db_info.holiday = ma_hall.set_holiday()
    end

    -- return ma_data.db_info.holiday
    local holiday = ma_data.db_info.holiday

    -- local date = os.date("%Y-%m-%d")
    -- local date = "2020-10-1"

    for k, v in pairs(holiday) do
        if v.date == date then
            return true
        end
    end

    return false
end

--设置法定节假日
function ma_hall.set_holiday()
    local date = os.date("%Y年%m月")
    -- print("date:",date)
    local status, body = httpc.get("opendata.baidu.com", "/api.php?query="..date.."&resource_id=6018&format=json")

    local _,end_len_head = string.find(body,"holiday")
    local begin_len_tail,_ = string.find(body,"holidaylist")
    
    local find_str = string.sub(body,end_len_head+1,begin_len_tail-1)

    local date_table = {}
    local date_str = ""
    local status_str = ""

    while true do
        date_str,find_str = get_sub_str(find_str,"\"date\":\"")
        if not date_str then
            break
        end

        status_str,find_str = get_sub_str(find_str,"\"status\":\"")

        is_extra_table(date_table, {
            date = date_str,
            status = status_str,
        })
    end

    return date_table

end

--初始化模式的数据
local function initGameInfo(gameTypec)
    for i,typeId in ipairs(cfg_game_type) do
        if not gameTypec[typeId] then
            gameTypec[typeId] = {winc=0,total=0,maxCtype = 0,maxNum = 0,cards = {}}
        end
    end
    return gameTypec
end

--更新玩家游戏局数/最大番型，牌型等
function ma_hall.updateGameNum(place_id,is_win,noRedNum,matchMarkId)
    local gameId = place_id // 100
    local placeId = place_id % 100
    if place_config[gameId][placeId].stype == 4 then
        return
    end
    local gameType = place_config[gameId][placeId].type
    if not ma_data.db_info.playinfo.gameTypec[gameType] then
        ma_data.db_info.playinfo.gameTypec = initGameInfo(ma_data.db_info.playinfo.gameTypec)
    end
    local currGame = ma_data.db_info.playinfo.gameTypec[gameType]
    ma_data.db_info.playinfo.total = ma_data.db_info.playinfo.total + 1
    if ma_data.db_info.playinfo.total >= 5 then
        ma_data.ma_hall_active.finish_new_player_task(2)
    end
    currGame.total = currGame.total + 1
    ma_data.db_info.playinfo.noRedNum = noRedNum
    if is_win then
        currGame.winc = currGame.winc + 1
        ma_data.db_info.playinfo.winc = ma_data.db_info.playinfo.winc + 1
    end
    ma_data.ma_spread.addGameNum()

    --添加匹配限制
    if not ma_data.db_info.matchMark then
        ma_data.db_info.matchMark = {}
    end
    if matchMarkId then
        table.insert(ma_data.db_info.matchMark,matchMarkId)
        if #ma_data.db_info.matchMark > (match_num or 3) then
            for i=(#ma_data.db_info.matchMark - (match_num or 3)),1,-1 do
                table.remove(ma_data.db_info.matchMark,i)
            end
        end
    end
    -- print('====updateGameNum更新===========',gameId,placeId,place_config[gameId][placeId].stype,place_config[gameId][placeId].des,
    --         ma_data.db_info.dyGameNum,ma_data.db_info.channel)
    if (ma_data.db_info.channel == 'hzmjlx_duoyou' or ma_data.db_info.channel == 'duoyou_ios') and gameId == 1 then
        ma_data.db_info.dyGameNum2 = (ma_data.db_info.dyGameNum2 or 0) + 1
    end

    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, {playinfo = ma_data.db_info.playinfo,
                                                                            matchMark = ma_data.db_info.matchMark,
                                                                            dyGameNum2 = ma_data.db_info.dyGameNum2})
end

--更新玩家最大番数，番型，牌型
function ma_hall.updateMaxCard(place_id,cardsInfo,cap)
    local gameId = place_id // 100
    local placeId = place_id % 100
    local gameType = place_config[gameId][placeId].type
    if not ma_data.db_info.playinfo.gameTypec[gameType] then
        ma_data.db_info.playinfo.gameTypec = initGameInfo(ma_data.db_info.playinfo.gameTypec)
    end
    local currGame = ma_data.db_info.playinfo.gameTypec[gameType]
    if cap ~= 0 and cardsInfo.FanNum > cap then
        cardsInfo.FanNum = cap
    end
    if cardsInfo.FanNum > currGame.maxNum then
        local pack = {}
        pack.hand = cardsInfo.hand
        pack.pengs = cardsInfo.pengs
        pack.gangs = cardsInfo.gangs
        pack.huCard = cardsInfo.huCard
        currGame.cards = pack
        currGame.maxNum = cardsInfo.FanNum
    end

    for i,ctype in ipairs(cardsInfo.cTypes) do
        if not cfg_hu[currGame.maxCtype] and cfg_hu[ctype].type == 1 then
            currGame.maxCtype = ctype
        elseif cfg_hu[ctype].type == 1 and cfg_hu[ctype].num > cfg_hu[currGame.maxCtype].num then
            currGame.maxCtype = ctype
        end
    end

    --更新到数据库
    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, {playinfo = ma_data.db_info.playinfo})
end

--
--获取个人信息
function request:get_myself_info()
    return {playinfo = ma_data.db_info.playinfo}
end

function request:title_info()
    return {info = ma_data.title_info}
end

--新手引导
function request:fin_guide()
    local guide_id = self.guide_id
    local guide_value = self.guide_value
    assert(guide_id and guide_value , "fin_guide 参数异常")

    local ret ={e_info = 2}
    local guide_info = ma_data.db_info.guide_info

    --引导id只增不减
    if guide_value<= guide_info[guide_id] then
        ret.e_info = 1
        ret.guide_info = guide_info
        
    else
        guide_info[guide_id] = guide_value
        ret.e_info = 0
        ret.guide_info = guide_info
        --更新db
        skynet.send(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id,{guide_info = guide_info})
    end

    return ret
end

--处理scene_name 后续发放奖励逻辑
--ret 成功返回  out 是否外部统一发放 video_ad_report_1
function ma_hall.viedo_ad_reward(scene_name)     
    local ret 
    local out = true
    if scene_name == AD_SCENE_NAME.MajongGod_Win then
        --麻神祝福
        ret = ma_hall.get_mj_god_reward(1)
    elseif scene_name == AD_SCENE_NAME.MajongGod_Lose then        
        --麻神庇佑
        ret = ma_hall.get_mj_god_reward(2)
    elseif scene_name == AD_SCENE_NAME.xixiReward then        
        --嘻嘻大奖看视频 领奖
        ret = ma_hall.watch_xixi_reward_video()        
    elseif scene_name == AD_SCENE_NAME.draw_luck then        
        --幸运转盘
        ma_hall.video_ad_report()
        out = false
    elseif scene_name == AD_SCENE_NAME.luck_card then        
        --好牌开局
        ret = true
        out = false
    elseif scene_name == AD_SCENE_NAME.pick_card_gift then        
        --翻拍豪礼
        ret = ma_hall.reward_pick_card_gift()
        out = false
    else
        skynet.logi("====debug qc==== viedo_ad_reward 未使用的 scene_name ",scene_name)
    end
    print("====debug qc==== viedo_ad_reward scene_name ",scene_namem,ret)
    return ret ,out
end

--嘻嘻大奖 get
function request:get_xixi_reward_info()
    local rank,value,value2= skynet.call("ranklist_mgr","lua","get_rank","watch_ads",ma_data.my_id)
    print("====debug qc==== 我的广告播放次数统计 ",rank,value,value2)
    return {watchXixiTimes = value}
end

function ma_hall.watch_xixi_reward_video()
    local rank,value,value2= skynet.call("ranklist_mgr","lua","get_rank","watch_ads",ma_data.my_id)
    print("====debug qc==== 嘻嘻大奖广告次数 ",rank,value)
    
    --次数封顶
    local pack ={e_info = 0,watchXixiTimes = value}

    if value > xixi_reward_prixlimit then
        value = xixi_reward_prixlimit
    end

    --按照当前次数发奖励  

    --计算奖励
    local value_x = value // 10
    local value_y = value % 10
    local reward_num = xixi_reward_prixbasic + value_x*500*(1+value_x) + (1+value_x)*value_y*100
    print("====debug qc==== 理论奖励 ",value_x,value_y,reward_num)
    pack.gold_num = reward_num
    ma_data.add_gold(reward_num,GOODS_WAY_XIXI_BIG_REWARD,"嘻嘻大奖",nil,true)
    ma_data.send_push("buy_suc", {
        goods_list = {{id = COIN_ID,num = reward_num}},
        msgbox = 1
    })
    ma_data.send_push("watch_xixi_reward_vedio", pack)    
    return true
end


function request:get_xixi_reward_rank()

    local rank_list = skynet.call("ranklist_mgr","lua","get_rank_list","watch_ads",1,20) or {}

    local rank,value,value2 = skynet.call("ranklist_mgr","lua","get_rank","watch_ads",ma_data.my_id) 

    local pack_list = {}
    for _,data in ipairs(rank_list) do
        table.insert(pack_list,{
            id = data.id,
            nickname = data.nickname,
            count = data.watch_ads
        })
    end

    -- print("====debug qc==== 嘻嘻大奖排行榜 ")
    -- table.print(pack_list)

    return {list = pack_list, 
                myRank = rank,
                myCount = value}
end


--wx通用版本任意广告播放统计
function ma_hall.video_ad_report_wx(scene_name)
    local rank,value,value2= skynet.call("ranklist_mgr","lua","get_rank","watch_ads",ma_data.my_id)
    print("====debug qc==== 我的广告播放次数统计 ",rank,value,value2)
    --排行榜统计自己的次数 并提交排行榜 嘻嘻大奖
    if scene_name == "xixiReward" then
        skynet.call("ranklist_mgr","lua","update_watch_ads",ma_data.my_id,value+1,
        ma_data.db_info.nickname,ma_data.db_info.headimgurl,ma_data.get_picture_frame(ma_data.db_info.backpack))    
    end

    --发放每日vip点数     
   
    local goods ={id = VIP_POINT,num = VIP_POINT_ADS}
    local ads_data = ma_data.ma_task.get_ads_data()
    local vp_cell,delta 
    --嘻嘻大奖  按次数判断 +5 还是 +2 **奖励是配置表cfg_global[1].prixVexpNum
    if scene_name == "xixiReward" and ads_data.today.xixiReward[2] < xixi_reward_prixVexpCount then
        goods = xixi_reward_prixVexpGoods   
        vp_cell,delta = ma_data.add_vp_daily("xixi_gift",goods.num)
    else
        vp_cell,delta = ma_data.add_vp_daily("watch_any_ads",goods.num)
    end
    
    if delta>0 then
        goods.num = delta --修正点数上限
        ma_data.add_goods(goods,GOODS_WAY_AD,"VIP富豪点每日任意视频",nil,true)    
        ma_data.update_viplv()
    end
    print("====debug qc==== video_ad_report_wx === ",scene_name)
    local ret,out = ma_hall.viedo_ad_reward(scene_name)
    if out then
        ma_data.send_push('video_ad_report_1',{scene_name = scene_name,e_info = ret and 0 or 1})  
    end
    
end

--翻拍豪礼
function ma_hall.reward_pick_card_gift()
    local pack = ma_data.ma_hall_active.reward_cardsgift()
    if not pack then
        --领取失败
        ma_data.send_push('video_ad_report_1',{e_info =1,result = false,scene_name = AD_SCENE_NAME.pick_card_gift})
        return
    end    
    ma_data.send_push('video_ad_report_1',{e_info =0,result = true,scene_name = AD_SCENE_NAME.pick_card_gift,pick_card = pack})

end

--幸运转盘 播放成功返回
function ma_hall.video_ad_report(trans_id,reward_name)
    if (ma_data.dailytask.watch_Ntime and 
        ma_data.dailytask.watch_Ntime > os.time()) or
        ma_data.dailytask.watch_adac >= 20 then
        ma_data.send_push('video_ad_report_1',{endTime = ma_data.dailytask.watch_Ntime,result = false,e_info =1,scene_name = AD_SCENE_NAME.draw_luck,watch_adac = ma_data.dailytask.watch_adac})
        return
    end
    local result,award_id = ma_data.ma_task.watch_ad_award()
    -- print(result,award_id,ma_data.dailytask.watch_Ntime)
    ma_data.send_push('video_ad_report_1',{award_id = award_id,
                                            endTime = ma_data.dailytask.watch_Ntime,
                                            watch_adac = ma_data.dailytask.watch_adac,
                                            result = result,
                                            scene_name = AD_SCENE_NAME.draw_luck,
                                            e_info =0})
    if ma_data.dailytask.watch_adac == 1 then
        skynet.send('game_info_mgr','lua','add_look_over_num')
    end
    ma_data.ma_task.add_task_count(TASK_DAY_T_HLDB)
end



--开始播放广告
function request:begin_look_ad()
    
    if not ma_data.dailytask.today_click then
        skynet.send('game_info_mgr','lua','add_click_num')
        ma_data.ma_task.update_today_click()
    end
    --base分支统计个人广告播放次数
    --{ads_data {{day={scenename = {start,end}},all={scenename = {start,end}}}}
    ma_data.ma_task.watch_ads_start(self.scene_name)
end

--上报广告完成
function request:video_ad_report()
    ma_data.ma_task.check_day_change()
    ma_hall.video_ad_report_wx(self.scene_name)
    ma_data.ma_task.watch_ads_succ(self.scene_name)
    ma_data.ma_task.add_task_count(TASK_DAY_T_ANY_ADS)
end

function cmd.video_ad_report(_,trans_id,reward_name)
    ma_data.ma_task.check_day_change()
    local tempTbl = {}
    if reward_name then
        print(crypt.base64decode(reward_name))
        tempTbl = cjson.decode(crypt.base64decode(reward_name))
    end
    if tempTbl.Type then 
        if tempTbl.Type == 1 then
            local tmpTbl = ma_data.ma_month_sign.sign(tempTbl.Index,true)
            ma_data.send_push('sign',tmpTbl) 
        elseif tempTbl.Type == 2 then
            local tmpTbl = ma_data.ma_seven_day_sign.seven_sign(tempTbl.Index,true)
            ma_data.send_push('seven_sign',tmpTbl)
        elseif tempTbl.Type == 3 then
            local tmpTbl = ma_data.ma_hall_active.get_intAward_award(tempTbl.Index,true)
            ma_data.send_push('get_intAward_award',tmpTbl)
        elseif tempTbl.Type == 4 then
            local tmpTbl = ma_data.ma_task.receive_dailytask_reward(tempTbl.Index,true)
            table.print(tmpTbl)
            ma_data.send_push('receive_dailytask_reward',tmpTbl)
        end
    else
        ma_hall.video_ad_report(trans_id,reward_name)
    end  
end

function request:get_ad_info()
     ma_data.ma_task.check_day_change()
    return {watch_adac = ma_data.dailytask.watch_adac,endTime = ma_data.dailytask.watch_Ntime}
end

-- 获取验证码
function request:phone_ver_code()
    --print("phone_ver_code================", self.phone)

    if not self.phone then
        return {result = false,e_info = 1}
    end
    if not self.phone:match("1%d%d%d%d%d%d%d%d%d%d") then
        return {result = false,e_info = 1}
    end
    local time = os.time()
    if last_get_verify_time and time - last_get_verify_time < 59 then
        return {result = false,e_info = 2} --  两次请求时间小于 60s
    end
    verify_code = tostring(math.random(100000,999999))
    last_get_verify_time = os.time()
    get_vc_phone = self.phone
    skynet.send("httpclient", "lua", "get_verify_code", self.phone, verify_code)

    return {result = true}
end

function request:bind_phone()
    if not verify_code or not last_get_verify_time or not get_vc_phone then
        return {result = false,e_info = 1} -- 没有获取过验证码
    end
    if os.time() - last_get_verify_time > 90 then
        return {result = false,e_info = 2} -- 验证码超时,请重新获取
    end
    if not self.code or self.code ~= verify_code then
        return {result = false,e_info = 3} -- 验证码不正确
    end
    if ma_data.db_info.phone then
        return {result = false,e_info = 4} -- 已经绑定
    end
    ma_data.db_info.phone = get_vc_phone
    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, {phone = ma_data.db_info.phone})

    skynet.call("mail_mgr", "lua", "send_mail", ma_data.my_id, {
        title = "绑定手机号有礼",
        content = "亲爱的用户，您的手机号已经绑定成功！小小礼物不成敬意，感谢您对游戏的大力支持！",
        attachment = {
            {id = GOODS_GOLD_ID, num = 200000}
        }
    })
    return {result = true}
end

--获取其他玩家信息
--self.user_id  玩家ID
-- function ma_hall.get_other_info(id)
function request:get_other_info()
    --print("get_other_info",self.user_id,type(self.user_id))
    local id = self.user_id

    print('===============获取其他玩家信息',self.user_id)
    local other_data = skynet.call(get_db_mgr(), "lua", "find_one","user",
        {id = id},{_id=false,id=true,nickname=true,headimgurl=true,last_time=true,sex = true,gold=true,playinfo = true,
            backpack=true})
    if not other_data then
        return {}
    end

    other_data.headframe = ma_data.get_picture_frame(other_data.backpack)
    other_data.human_drees = ma_data.get_human_drees_goods(other_data.backpack)

    return {db_info = other_data}
end


-- 获取服务器时间
function request:get_server_time()
    return {time = os.time()}
end

-- 获取配置
function request:get_phone_info()
    --print('============获取配置===========',self.phone_name,self.phone_os,self.phone_version)
    skynet.send('mail_mgr','lua','set_phone_info',self.phone_name)
    ma_data.db_info.phone_name = self.phone_name
    ma_data.db_info.phone_os = self.phone_os
    ma_data.db_info.phone_version = self.phone_version
    ma_data.db_info.phone_idfa = self.phone_idfa
    skynet.send(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id,{phone_name = ma_data.db_info.phone_name,
                                                                        phone_os = ma_data.db_info.phone_os,
                                                                        phone_version = ma_data.db_info.phone_version,
                                                                        phone_idfa = ma_data.db_info.phone_idfa})
end

function request:send_channel()
    skynet.error('user_id,===========loginTime,=================channel  '..ma_data.my_id..','..ma_data.db_info.loginTime..','..self.channel)
    if ma_data.db_info.loginTime == 1 then
        ma_data.db_info.channel = self.channel
        skynet.send(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id,{channel = ma_data.db_info.channel})
    end
end

function request:submit_message()
    local ret = skynet.call(get_db_mgr(), "lua", "find_all", COLL.MESSAGE, {pid = ma_data.my_id}, 
                      {_id = false,time=true}, {{time = -1}}, 1)
    local curr_time = os.time()
    if ret and #ret > 0 and (curr_time - ret[1].time) < 600 then
        return {result = false,curr_time = ret[1].time}
    else
        skynet.call(get_db_mgr(), "lua", "insert", COLL.MESSAGE, {
            pid = ma_data.my_id,
            message = self.message,
            time = curr_time
        })
        return {result = true,curr_time = curr_time}
    end
end

-- 跑马灯
function request:horse_lamp( )
    local horse_lamp = skynet.call(get_db_mgr(), "lua", "find_one", COLL.LAMP)
    local msg = horse_lamp and horse_lamp.msg
    if msg == '' then
        msg = nil
    end

    return {horse_lamp = msg}
end
--连接检查
function request:connect_check()
    return {result = true}
end

function request:set_sex()
    ma_data.db_info.sex = self.sex
    skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {sex = self.sex})

    return {result = 0, sex = self.sex}
end

local cfg_conf = require "cfg_conf"
--请求活动列表
function request:get_activity_list()
    local list = skynet.call(cfg_conf.DB_MGR,'lua','get_conf', cfg_conf.COLL.ACTIVITY_CONF, {}, fields)
    local arr = {}
    for _, l in pairs(list) do 
        table.insert(arr, l)
    end
    --print("list =>", table.tostr(arr))
    return {result = 0, list = arr}
end

function request:use_goods()
    local use = self.use
    local ret = ma_data.use_goods(self.goods_id, use)
    return {result = ret,goods_id = self.goods_id}
end

--测试方法 增加金币
function request:gm_gold()
    local goldnum = self.goldnum
    local type = self.type
    local env = skynet.getenv("env")
	env = env or "publish"
	if not (env == "debug" or env == "local")then
		return
	end
    
    if type== 1 then
        --防止扣到负数
        if goldnum<0 then
            goldnum = math.max(goldnum,-ma_data.db_info.gold)
        end
        ma_data.add_gold(goldnum, GOLD_WS_ADMIN, "GM方法增加gold")
        return {result = 0,num = ma_data.db_info.gold }
    elseif type== 2 then
        if goldnum<0 then
            goldnum = math.max(goldnum,-ma_data.db_info.diamond)
        end
        ma_data.add_diamond(goldnum, GOLD_WS_ADMIN, "GM方法增加diamond")
        return {result = 0,num = ma_data.db_info.diamond }
    end
    return {result = 1 }
end

--测试方法 购买钻石商品 支付成功
function request:gm_pay()
    print("===================gm_pay=====================")
    local mall_id = self.mall_id
    local env = skynet.getenv("env")
    env = env or "publish"
    if not (env == "debug" or env == "local")then
        return
    end
    --暂时只处理 商城充值的商品200036~200043
    if (mall_id >= 200036 and mall_id <= 200043)   --商城充值钻石
        or (mall_id >= 500207 and  mall_id <= 500218) --首充礼包 + 天赐豪礼
        or (mall_id ==200080 or mall_id ==200081) --助力礼包
        or  (mall_id >= 500201 or mall_id <=500205)  then --保险库
            
        ma_hall_store.buy_suc(mall_id,"sandbox","out_trade_no")
        return {result = 0,diamond = ma_data.db_info.diamond ,all_diamond = ma_data.db_info.all_diamond }
    else
        return {result = 1 }
    end
    return {result = 1 }
end

--判断屏蔽字
--self.content  文本内容
--self.type     判断方式 1:有屏蔽字就返回 2.返回去除屏蔽字的内容
-- function ma_hall.filter_sensitive_words( content,type )
function request:filter_sensitive_words( ... )
    local content = self.content
    local type = self.type
    --print("filter_sensitive_words***")

    local get_result = filter_sensitive_words(content,type)
    if get_result == true then
        return { result = 1 }
    end

    return { result = 0, content = get_result }

end 

----------------------------------------------------------------------
----------------------------------------------------------------------
--招财猫

function ma_hall.lucky_cat_flush ()
    --print("写入数据库")
    skynet.call(get_db_mgr(), "lua", "update", COLL.ACTIVITY_DATA, {id = ma_data.my_id},{["lucky_cat"] = ma_data.lucky_cat})
end

--modify by qc 2021.7.2 招财猫最大次数与VIP等级关联
function ma_hall.lucky_cat_check_day()
    local today = os.date("%Y%m%d")
    local month_card_type = ma_month_card.get_type()
    local max_play_times = ma_data.get_vip_ability("luckyCatCount")  or 10
   
    local data = skynet.call(get_db_mgr(), "lua", "find_one",COLL.ACTIVITY_DATA,{id = ma_data.my_id},{_id=false,lucky_cat=true}) or {}
    if data.lucky_cat ~= nil then
        -- print("招财猫同步的数据")
        data = data.lucky_cat
        ma_data.lucky_cat.day = data.day
        ma_data.lucky_cat.all_times = max_play_times
        ma_data.lucky_cat.pay_count = data.pay_count
    end


    if ma_data.lucky_cat.day ~= today or ma_data.lucky_cat == nil then
        --print("更新招财猫")
        ma_data.lucky_cat.day = today
        ma_data.lucky_cat.all_times = max_play_times
        ma_data.lucky_cat.pay_count = 0
        ma_hall.lucky_cat_flush()
    end
end


--[[ 测试权重概率分布
local function TestCommon_RandFromTbl()
    --测试概率分布 start
    local rate_result ={}
    local TbRates ={}
    --根据viplv 重组概率分布表
    for i,v in pairs(lucky_cat_conf) do
        local vXrateName = "v10rate"
        if v[vXrateName] and v[vXrateName]>0 then  
            table.insert(TbRates,{ rate = v[vXrateName] ,mult = v.mult })         
        end
    end

    print("====debug qc==== lucky_cat_gold : rate table")
    table.print(TbRates)

    --概率分布随机
    for i=1,100000 do
        local id = Common_RandFromTbl(TbRates)
        if not rate_result[id] then
            rate_result[id] =1
        end
        rate_result[id] = rate_result[id] + 1
    end

    table.print(rate_result)

    --测试概率分布 end
end
]]

function request:lucky_cat()
    --print("刷新招财猫数据")
    ma_hall.lucky_cat_check_day()
    local lc = {}
    lc.pay_count = ma_data.lucky_cat.pay_count
    lc.all_times = ma_data.lucky_cat.all_times  
    lc.play_times = ma_data.lucky_cat.pay_count
    return lc
end

-- 当前获得金币 钻石 * 返利 * LUCK_CAT_BASE
-- modify by qc 2021.8.4 新版招财猫倍率随机 vip10连额外算法
local function lucky_cat_gold(pay_count,price,be_crit)
    local multiple = 0  -- 返利倍率
    local viplv = ma_data.get_vip()
    local TbRates = {}
    local start_idx = LUCK_CAT_VIP_SET[viplv+1]

    --根据viplv 重组概率分布表
    for i,v in pairs(lucky_cat_conf) do
        --viplv 修剪低档数据
        if be_crit and i< start_idx then
            goto continue
        end

        local vXrateName = "v"..viplv.."rate"        
        if v[vXrateName] and v[vXrateName]>0 then  
            table.insert(TbRates,{ rate = v[vXrateName] ,mult = v.mult })         
        end     
        ::continue::
    end

    -- print("====debug qc==== lucky_cat_gold : rate table")
    -- table.print(TbRates)

    --概率分布随机
    local id = Common_RandFromTbl(TbRates)
    -- print("====debug qc==== lucky_cat_gold : rate-mult is " ,TbRates[id].mult)


    local multiple = TbRates[id].mult    
    local final_gold =  price * multiple * LUCK_CAT_BASE    

    return {multiple = multiple, gold = final_gold}                                                              
end

--modify by qc 2021.7.2 取消与月卡关联。享受VIP等级加成
function request:lucky_cat_play()
    --print("===========lucky_cat_play")
    local times = self.play_type
    local mul = self.mul or 1   

    ma_hall.lucky_cat_check_day()
    if times ~=1 and times ~=10 then
        return {result = false, e_info = 2}
    end

    local lucky_cat = ma_data.lucky_cat
    local max_play_times = ma_data.get_vip_ability("luckyCatCount")  or 10 --补初始化
    local price = mul * times * 10
    local award_gold = 0
    local results = {}
    if times == 1 then
        lucky_cat.pay_count = lucky_cat.pay_count + times        
        if max_play_times < lucky_cat.pay_count then
            return {result = false, e_info = 3}
        end
        -- if mul 不符合vip等级 then
        --     return {result = false, e_info = 2}
        -- end        
        if max_play_times < lucky_cat.pay_count then
            return {result = false, e_info = 3}
        end
        local result = lucky_cat_gold(lucky_cat.pay_count,price)
        results[1] = result
        award_gold = result.gold
        --print("招财猫金币数")
        --print(result.gold)
    else
        if ma_data.db_info.diamond < price then
            return {result = false, e_info = 1}
        end
        --print("招财猫"..times.."连金币数")
        for i=1,times do
            lucky_cat.pay_count = lucky_cat.pay_count + 1
            local b_crit =false
            if i==10 then
                b_crit = true
            end
            local result = lucky_cat_gold(lucky_cat.pay_count,price/times,b_crit)
            table.insert(results, result)
            --print(result.gold)
            award_gold = award_gold + result.gold
        end
    end

    ma_data.add_goods_list({{id = COIN_ID, num = award_gold}, {id = DIAMOND_ID, num = -price}},GOODS_WAY_LUCKY_CAT,"lucky_cat_gold") 
    -- ma_data.lucky_cat.pay_count = ma_data.lucky_cat.pay_count + times
    ma_hall.lucky_cat_flush()
    return {
        result = true,
        award_gold = award_gold,
        award_records = results,
        play_times = ma_data.lucky_cat.pay_count,
        all_times = ma_data.lucky_cat.all_times
    }
end
----------------------------------------------------------------------
----------------------------------------------------------------------
--设置半身像
function request:change_half_photo()
    --print('================半身像=================')
    if ma_data.db_info.half_photo then
        ma_data.db_info.half_photo = false
    else
        ma_data.db_info.half_photo = true
    end

    skynet.send(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id,{half_photo = ma_data.db_info.half_photo})

    if ma_data.my_room then
        skynet.send(ma_data.my_room, "lua", "change_half_photo",ma_data.my_id,ma_data.db_info.half_photo)
    end
    return {half_photo = ma_data.db_info.half_photo}
end

--设置昵称头像
function request:change_nickname_headimgurl()
    if self.changeType == 0 then    --3方登录初始化 设置头像 跟昵称
        if not self.nickname then
            return {result = 2}
        end
        if not self.headimgurl then
            return {result = 2}
        end
        ma_data.db_info.nickname = self.nickname
        ma_data.db_info.headimgurl = self.headimgurl
        skynet.send(get_db_mgr(),'lua','update_userinfo',ma_data.my_id,{nickname = ma_data.db_info.nickname})
        skynet.send(get_db_mgr(),'lua','update_userinfo',ma_data.my_id,{headimgurl = ma_data.db_info.headimgurl})
        return {result = 0,nickname = self.nickname, headimgurl = self.headimgurl}
    elseif self.changeType == 1 then    --付钱修改昵称
        if not self.nickname then
            return {result = 2}
        end
        if not ma_data.db_info.cn_num then
            ma_data.db_info.nickname = self.nickname
            ma_data.db_info.cn_num = 1
        else
            if ma_data.db_info.diamond < 1000 then
                return {result = 1}
            end
            ma_data.db_info.nickname = self.nickname
            ma_data.db_info.cn_num = ma_data.db_info.cn_num + 1
            ma_data.add_diamond(-1000, GOODS_WAY_DIAMOND_BUY, "更改昵称消耗")
        end
        skynet.send(get_db_mgr(),'lua','update_userinfo',ma_data.my_id,{nickname = ma_data.db_info.nickname,
                                                                        cn_num = ma_data.db_info.cn_num})
        return {result = 0,nickname = self.nickname,cn_num = ma_data.db_info.cn_num}
    else
        if not self.headimgurl then
            return {result = 2}
        end
        ma_data.db_info.headimgurl = self.headimgurl
        skynet.send(get_db_mgr(),'lua','update_userinfo',ma_data.my_id,{headimgurl = ma_data.db_info.headimgurl})
        return {result = 0,headimgurl = self.headimgurl}
    end
end
----------------------------------------------------------------------
--举报他人
function request:tip_off_other()
    --self.other_id,self.report
    local tempTbl = {
        informer = ma_data.my_id,
        other_id = self.other_id,
        reportType = self.reportType,
        content = self.content
    }
    skynet.call(get_db_mgr(), "lua", "insert", COLL.REPORT,tempTbl)
    return {result = true}
end

----------------------------------------------------------------------
--银行
--获取银行信息
--已废弃
function request:get_gold_bank()
    return {gold = ma_data.db_info.gold,bankgold = (ma_data.db_info.bankgold or 0)}
end

--存储取出金币
function request:get_set_bankGold()
    --self.goldNum 存储的金额，self.getSet 存取，true/false
    -- local month_type = ma_data.ma_month_card.get_type()
    if not self.goldNum or self.goldNum%1000000 ~= 0 then
        return {result = false,errorid = 2}
    end
    --print('=================存钱==========================')
    if self.getSet then
        if self.goldNum > ma_data.db_info.gold then
            return {result = false,errorid = 1}
        end
        -- if month_type ~= 8 then
        --     return {result = false,errorid = 3}
        -- end
        ma_data.add_gold(-self.goldNum, GOLDBANK, "银行存取")
        ma_data.add_bankgold(self.goldNum, GOLDBANK,"银行存取")
    else
        --print('=================取钱==========================')
        if self.goldNum > ma_data.db_info.bankgold then
            return {result = false,errorid = 1}
        end
        ma_data.add_gold(self.goldNum, GOLDBANK, "银行存取")
        ma_data.add_bankgold(-self.goldNum, GOLDBANK,"银行存取")
    end

    return {result = true,bankgold = ma_data.db_info.bankgold}
end
----------------------------------------------------------------------
----------------------------------------------------------------------
--存储玩家的流水
--随机一个麻神祝福/庇佑数值并初始化到战斗记录tempTbl中
function ma_hall.saveRecord(placeId,isWin,playerIO,handCards,win_gold,rankScore)
    --print('=============战绩储存=============',placeId,isWin,playerIO,handCards,win_gold,rankScore)
    --print('============战绩流水==============',#playerIO)
    if placeId == 1505 then
        return
    end
    local game_record_info = skynet.call(get_db_mgr(), "lua", "find_one",COLL.GAME_REC, {pid=ma_data.my_id}, 
            {_id = false, pid=true, game_record=true})
    --print('=============战绩存存2222')
    --table.print(game_record_info)
    local tempTbl = {}
    tempTbl.placeId = placeId
    tempTbl.isWin = isWin
    tempTbl.playerIO = playerIO
    tempTbl.handCards = handCards
    tempTbl.time = os.time()
    tempTbl.win_gold = win_gold
    tempTbl.rankScore = rankScore

    --todo 麻神祝福/庇佑数据初始化
    if win_gold ~= 0 then        
        local gameid = placeId // 100
        local placeid = placeId % 100
        print("====debug qc==== 麻神祝福 初始化 1",gameid,placeid)
        local tpl_mg = place_config[gameid][placeid]
        assert(tpl_mg , "麻神祝福 cfg 读取失败！")

        if isWin then
            tempTbl.mg_gold_type = 1
            --初步计算金额 = 玩家本局获得收益 985000 * 默认比例 0.2
            --最终金额 = MAX(祝福下限4000,MIN(初步计算金额,祝福上限 500000))
            --弹出概率 = 最终金额/本局获得收益/默认比例
            local score_step1 = win_gold * tpl_mg.bless_percent /10000
            local score_step2 = math.max(tpl_mg.bless_min,math.min(score_step1,tpl_mg.bless_max))
            local _rand = math.ceil(score_step2 *100 / score_step1 ) -- _rand %           
            local randTime =  math.max(0,math.min(_rand,100))
            print("====debug qc==== 随机概率",randTime ,"%")
            if randTime>50 then
                tempTbl.mg_status = MJ_GOD_STATUS.OK
                tempTbl.mg_gold_num = score_step2
            else
                tempTbl.mg_status = MJ_GOD_STATUS.NONE
            end        
        else
            tempTbl.mg_gold_type = 2
            --触发条件 输钱额度>protect_value or 输钱比例 > tpl_mg.protect_percent/10000
            --最终金额 = MAX(祝福下限4000,MIN(初步计算金额,祝福上限 500000))
            --弹出概率 = 最终金额/本局获得收益/默认比例
            local lose_per = (-win_gold / ma_data.db_info.gold - win_gold)
            if (tpl_mg.protect_value <= -win_gold) or (tpl_mg.protect_percent/10000 <= lose_per) then
                print("====debug qc==== 触发麻神庇佑",win_gold,lose_per)                
                local score_step2 = tpl_mg.protect_limit > -win_gold and -win_gold or  tpl_mg.protect_limit
                tempTbl.mg_status = MJ_GOD_STATUS.OK
                tempTbl.mg_gold_num = score_step2
            else
                tempTbl.mg_status = MJ_GOD_STATUS.NONE
            end                  
        end
        -- table.print(tempTbl)
    end

    --print('================战绩储存33333333')
    if not game_record_info or not game_record_info.game_record then
        game_record_info = {}
        game_record_info.pid = ma_data.my_id
        game_record_info.game_record = {}
        table.insert(game_record_info.game_record,1,tempTbl)
        skynet.call(get_db_mgr(), "lua", "insert", "game_rec", game_record_info)
    else
        --print('=========后续添加==========',#game_record_info.game_record)
        if #game_record_info.game_record >= 5 then
            if #game_record_info.game_record - 5 >= 1 then
                local tempRecord = {}
                for i=#game_record_info.game_record,(#game_record_info.game_record -3),-1 do
                    table.insert(tempRecord,game_record_info.game_record[i])
                end
                game_record_info.game_record = tempRecord
            else
                table.remove(game_record_info.game_record)
            end
        end
        table.insert(game_record_info.game_record,1,tempTbl)
        skynet.call(get_db_mgr(), "lua", "update", "game_rec",{pid = ma_data.my_id},game_record_info)
    end
end


--获取战绩
function request:get_20_game_record()
   local game_record_info = skynet.call(get_db_mgr(), "lua", "find_one",COLL.GAME_REC, {pid=ma_data.my_id}, 
            {_id = false, pid=true, game_record=true}) or {}
   --print('====================获取战绩====================')
   --table.print(game_record)
   return {game_record = game_record_info.game_record}
end

----------------------------------------------------------------------
----------------------------------------------------------------------
--麻神祝福/庇佑

--返回最后一个对局 
function ma_hall.get_last_game_record()
    local game_record_info = skynet.call(get_db_mgr(), "lua", "find_one",COLL.GAME_REC, {pid=ma_data.my_id}, 
    {_id = false, pid=true, game_record=true})
    if game_record_info then        
        return game_record_info
    end
    return nil    
end

--领取最后一局麻神奖励
function ma_hall.get_mj_god_reward(god_type)

    local game_record = ma_hall.get_last_game_record()
    if game_record and game_record.game_record[1] then
        local record = game_record.game_record[1]
        if god_type == record.mg_gold_type and record.mg_status == MJ_GOD_STATUS.OK then        
            local good_num =  record.mg_gold_num
            ma_data.add_gold(good_num,GOODS_WAY_MJ_GOD,"麻神祝福.庇佑",nil,true)
            record.mg_status =MJ_GOD_STATUS.USED
            print("====debug qc==== 领取麻神 奖励成功 ", ma_data.my_id,record.mg_gold_type,record.mg_gold_num)   
            --回写数据
            skynet.call(get_db_mgr(), "lua", "update", "game_rec",{pid = ma_data.my_id},game_record)

            --同步给客户端弹窗消息
            local goods = {id = COIN_ID,num = good_num}
            ma_data.send_push("buy_suc", {
                goods_list = {goods},
                msgbox = 1
            })
            
            return true
        end      
    end
    return false
end

--麻神祝福/庇佑 对于最近1局的状态
function request:get_mjgod()
    local game_record = ma_hall.get_last_game_record()    
    if game_record and game_record.game_record[1] then
        local record = game_record.game_record[1]
        return {
            gold_num = record.mg_gold_num,
            god_type = record.mg_gold_type,
            status = record.mg_status
        }
    end
    return {status =  MJ_GOD_STATUS.NONE}
 end

----------------------------------------------------------------------
----------------------------------------------------------------------
--获取当前状态
function request:set_curr_ui()
    print('===============获取当前状态',self.currUI)
    ma_data.db_info.currUI = self.currUI
    skynet.send('pay_info_mgr','lua','update_operation_info',nil,ma_data.db_info.currUI,1)
    skynet.call(get_db_mgr(),'lua','update_userinfo',ma_data.my_id,{currUI = self.currUI})
end
----------------------------------------------------------------------
----------------------------------------------------------------------

function request:get_channel()
    return {channel = ma_data.db_info.channel}
end
----------------------------------------------------------------------
----------------------------------------------------------------------



--请求vip_data
function request:vip_data()
    local ret ={}
    
      --VIP每日奖励更新
    if not ma_data.db_info.vip_point_daily or not check_same_day(ma_data.db_info.vip_point_daily.time_span)  then
        --重置vip
        ma_data.reset_VP_daily()
    end

    ret.viplv = ma_data.get_vip()
    --VIP每日奖励更新
    if not check_same_day(ma_data.db_info.vip_reward)  then
        ma_data.db_info.vip_reward = 0        
    end
    
    ret.bReward = ma_data.db_info.vip_reward==0 and ma_data.db_info.viplv>0
    ret.recharge_diamondc = ma_data.find_goods(VIP_POINT).num
    ret.vp_daily = ma_data.get_VP_daily()
    local goods_list = ma_data.get_cfg_vip()
    if goods_list then
        ret.goods = ma_data.get_vip_goods_by_day(goods_list)
     
    end    
    return ret
end

--领取vip奖励
-- 0：领取成功  1:不能重复领取 2:还没有领取资格
function request:receive_vip_reward()
    print(" =======我要领取 vip奖励 ========",ma_data.get_vip())
    if ma_data.db_info.viplv ==0 then
        return {result = 2}
    end    

    if check_same_day(ma_data.db_info.vip_reward) then
        return {result = 1}
    end
        
    ma_data.recive_vip_reward()   

    return {result = 0}
end

--self.code --cdk码
function request:get_cdk_award()
    local award = skynet.call("cdk_mgr","lua","get_cdk",self.code)
    if not award then
        return {result = 1}
    end
    ma_data.add_goods_list(award, GOODS_WAY_CDK, self.code)
    ma_data.send_push("buy_suc", {
        goods_list = award,
        msgbox = 1
    })
    return {result = 0}
end 

----------------------------------------------------------------------
----------------------------------------------------------------------


function ma_hall.init(REQUEST,CMD)
    if request then
        table.connect(REQUEST,request)
    end
    if cmd then
        table.connect(CMD,cmd)
    end

  
    --初始化ma_...
    -- ma_task.init(REQUEST, CMD)
    -- ma_hall_order.init(REQUEST, CMD)
    -- ma_hall_store.init(REQUEST, CMD)
    -- ma_hall_mail.init(REQUEST, CMD)
    -- ma_lamp.init(REQUEST, CMD)
    -- ma_hall_ranklist.init(REQUEST, CMD)
    -- ma_admin.init(REQUEST, CMD)
    -- ma_share.init(REQUEST, CMD)
    -- ma_hall_active.init(REQUEST, CMD)

    -- ma_month_card.init(REQUEST, CMD)

    -- ma_emotion.init(REQUEST, CMD)
    -- ma_dress.init(REQUEST, CMD)
    -- ma_month_sign.init(REQUEST, CMD)
    -- ma_growth_plan.init(REQUEST, CMD)
    -- ma_day_comsume.init(REQUEST,CMD)
    -- ma_seven_day_sign.init(REQUEST, CMD)
    -- ma_common.init(REQUEST, CMD)
   
    -- ma_hall_frame.init(REQUEST,CMD)
   
    -- ma_spread.init(REQUEST,CMD)

    --2021 ddz 待定
    -- ma_heilao.init(REQUEST,CMD)
    -- ma_hall_bank.init(REQUEST,CMD)

    --2v2模块
    -- ma_team2v2.init(REQUEST,CMD)

    --QQ红包ma
    --ma_qq_wallet.init(REQUEST,CMD)
    -- ma_hall_entity.init(REQUEST, CMD)

    --设置默认时装穿戴
    -- if ma_data.db_info.sex == SEX_BOY or ma_data.db_info.sex == SEX_GIRL then
    --     ma_dress.set_base_dress()
    -- end

    if not ma_data.db_info.playinfo then
        ma_data.db_info.playinfo = {winc=0,total=0,gameTypec = {}}
    end

end

return ma_hall

