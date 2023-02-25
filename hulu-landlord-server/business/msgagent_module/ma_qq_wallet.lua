--QQ 红包数据
local skynet = require "skynet"
local ma_data = require "ma_data"
local mall_conf = require "cfg.cfg_mall"
local items_conf = require "cfg.cfg_items"
local cfg_global = require "cfg.cfg_global"
local COLL = require "config/collections"

local cfg_Rpcash = require "cfg.cfg_RPcash"
local cfg_Rpgold = require "cfg.cfg_RPgold"
local cfg_Rpgames = require "cfg.cfg_RPgames"
local cfg_Rpeveryday = require "cfg.cfg_RPeveyday"

require "define"
require "pub_util"
local request = {}
local cmd = {}

local M = {}

--
-- message Rpcash{
--     optional int32 times = 1; // 每日剩余可提现次数
--     optional int32 days = 2; // 连续登录天数
--     optional int32 play_gamec = 3; // 当日对局数
--     optional int32 rp_times = 4; // 累计领取对局红包次数
--     repeated int32 withdrawals_times=5;    //对应cfg配置已领取次数
--     repeated int32 exChange_times=6;      //对应cfg配置已领取次数

--按照count从cfg中检索对应的配置条目
function M.FindFromCfg(cfg,count)
    for i,content in ipairs(cfg) do
        if count >= content.count_min and count<= content.count_max then
            return content
        end
    end
    return nil
end

--初始化数据
function M.InitRpcash()
    --todo 从db，ma_*中初始化数据
    M.Rpcash = ma_data.db_info.qq_hb_data
    if M.Rpcash == nil then
        M.Rpcash ={}
        M.Rpcash.times =QQ_WALLET_EVERYDAY_TIEMS
        M.Rpcash.days =1
        M.Rpcash.play_gamec =0
        M.Rpcash.rp_times =0
        M.Rpcash.withdrawals_times = {0,0,0,0,0,0,0,0}
        M.Rpcash.exChange_times = {0,0,0,0,0,0,0,0}
        M.Rpcash.time = os.time()
    end
  
end

--初始化广告领取次数
function M.InitAds()
    M.Ads_data = ma_data.db_info.qq_ads_data
    if M.Ads_data == nil then
        M.Ads_data ={}
        M.Ads_data.games = 0
        M.Ads_data.games_count = 0 --对局礼包
        M.Ads_data.everyday = 1 --每日礼包
                
       
        
        -- M.Ads_data.day30 = 0
        
        -- M.Ads_data.cardsshow = 0
    end
    M.Ads_data.daycash_1 = 1 --每日礼包
    M.Ads_data.daycash_2 = 1 --每日礼包
    if M.Ads_data.online ==nil then M.Ads_data.online = 1  end--在线礼包
    if M.Ads_data.online_time ==nil then M.Ads_data.online_time = os.time() end
    if M.Ads_data.watched ==nil then  M.Ads_data.watched = {day ={},all={}} end  --每日广告点位统计 watched={day={scenename = {start,end}},all={scenename = {start,end}}}
end

--获取广告次数统计
function M.Get_watch_count(sceneName,only_day)
    if sceneName~=nil then
        return {M.Ads_data.watched.day[sceneName],M.Ads_data.watched.all[sceneName]}
    end
    
    if only_day then
        local ret = {0,0}
        for i,item in pairs(M.Ads_data.watched.day) do
            ret[1] = ret[1]+ item[1]
            ret[2] = ret[2]+ item[2]
        end
        return ret
    else
        local ret = {0,0}
        for i,item in pairs(M.Ads_data.watched.all) do
            ret[1] = ret[1]+ item[1]
            ret[2] = ret[2]+ item[2]
        end
        return ret
    end
end

function M.flush_Rpcash()
    ma_data.db_info.qq_hb_data = M.Rpcash
    skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {qq_hb_data = ma_data.db_info.qq_hb_data})
end

function M.flush_ads()
    ma_data.db_info.qq_ads_data = M.Ads_data
    skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {qq_ads_data = ma_data.db_info.qq_ads_data})
end


--修改统计数据
function M.Add_QQ_HB_Data(tbl)
    for key,value in pairs(tbl) do
        M.Rpcash[key] = M.Rpcash[key] + value
    end
    M.flush_Rpcash()
end

--检验并刷新本天
function M.ResetEveryDay()   
    if check_same_day(M.Rpcash.time) then
        M.Rpcash.times =QQ_WALLET_EVERYDAY_TIEMS
        M.Rpcash.play_gamec =0
        if check_next_day(M.Rpcash.time) then
            M.Rpcash.days = M.Rpcash.days + 1            
        end
        M.Rpcash.exChange_times = {0,0,0,0,0,0,0,0} --每日兑换重置
        M.Rpcash.time = os.time()
        M.flush_Rpcash()

        M.Ads_data.games = 0
        M.Ads_data.everyday = 1
        M.Ads_data.daycash_1 =1
        M.Ads_data.daycash_2 =1
        M.Ads_data.watched.day ={} --每日广告点位统计重置
        M.flush_ads()
    end
end

--插入QQ红包领取记录

function M.get_qq_hb_withdrawal(openid)
    return skynet.call(get_db_mgr(), "lua", "get_qq_hb_withdrawal",openid)
end

function M.insert_qq_hb_withdrawal(record)
    skynet.send(get_db_mgr(), "lua", "insert_qq_hb_withdrawal",record)
end
--更新订单状态
function M.update_qq_hb_withdrawal(out_trade_no,record)
    skynet.send(get_db_mgr(), "lua", "update_qq_hb_withdrawal",out_trade_no,record)
end

--
-- 拉取红包钱包数据
--
function request:wallet_data()

    --从db拉取历史提现记录
    local records = M.get_qq_hb_withdrawal(ma_data.db_info.id)    
    -- print("===records====",records)
    -- table.print(records)

    if records and #records>0 then
        local qq_hb_drawals = {}
        for k,rec in pairs(records) do

            table.insert(qq_hb_drawals,{
                total_fee = rec.total_fee,
                create_time = rec.create_time,
                state = rec.state,
                drawals_type = rec.drawals_type,
                exchange_type = rec.exchange_type
            })
        end
        --不必录入数据库的数据
        M.Rpcash.qq_hb_drawals = {qq_hb_drawals}
    end
    return {rpcash = M.Rpcash}
end



--
-- QQ 余额 提现
--
function request:qq_with_drawals()
    local mall_id = self.mall_id
    local type = self.type        
    local content = cfg_Rpcash[mall_id]
    if content==nil then
        return {result =3} --商品不存在
    end    

    --间隔时间 or 累计请求次数检验?
    
    --可领取条件判断 true false false true false false
    print("===qq_with_drawals condition===: ",
                M.Rpcash.times>0,
                M.Rpcash.days < content.loginday ,
                M.Rpcash.rp_times < content.getRPcount ,
                M.Rpcash.play_gamec < content.everydaygames ,
                (mall_id>1 and M.Rpcash.withdrawals_times[mall_id-1] < content.proPRget) ,
                M.Rpcash.withdrawals_times[mall_id] > content.getcount)

    if M.Rpcash.times>0 or
        M.Rpcash.days < content.loginday or
        M.Rpcash.rp_times < content.getRPcount or 
        M.Rpcash.play_gamec < content.everydaygames or 
        (mall_id>1 and M.Rpcash.withdrawals_times[mall_id-1] < content.proPRget) or 
        M.Rpcash.withdrawals_times[mall_id] > content.getcount then
        return {result = 4} --领取次数条件cfg不足
    end

    if content==nil then
        return {result = 4} --领取次数条件不足
    end

    if ma_data.get_qq_wallet() < content.cost.num then
        return {result = 6} --余额不足
    end

    --货币类型断言
    assert(content.award.id == QQ_CASH, "qq_with_drawals type error getaward.id: "..content.award.id)
    assert(content.cost.id == QQ_WALLET, "qq_with_drawals type error cost.id: "..content.cost.id)

    local total_fee = content.award.num/100.0

    local openid = ma_data.db_info.openid
    -- local openid = "E9C9A2A3F52868CF4A2511A776608B2C"
    local ok, body = skynet.call("httpclient", "lua", "QQ_minigame_hb_send",openid,type,self.act_name,total_fee,self.wishing)
    -- print("call QQ_minigame_hb_send :",ok,body)
    
    if ok == 200 then
        table.print(body)
        if body.code==1 then
            --发送成功
            if ok then
                --扣费
                local qq_wallet = ma_data.add_qq_wallet(-content.cost.num ,GOODS_WAY_QQ_WALLET_WITH_DRAWALS,"qq提现",true,nil,nil)
                
                --根据返回data.code 判断是否需要审核
                if body.data ~=nil then
                    local record = {
                        openid = openid,
                        act_name = self.act_name,
                        total_fee = total_fee,
                        out_trade_no = body.data.out_trade_no,
                        create_time = body.time, --下单时间
                        state = 1,               --订单状态 1已领取，2 审核中,3审核通过未领取
                        drawals_type = type,     --提现类型
                        exchange_type = false,   --提现/兑换
                        comp_time = nil,         --审核完成时间
                        recive_time = nil,       --用户领取时间
                    }                    
                    if body.data.code ==1 then
                        --正常到账
                        skynet.logi(string.format("%s ===成功提现=== %s ,out_trade_no %s",openid,total_fee,body.data.out_trade_no))
                        --加入提现成功列表
                        M.insert_qq_hb_withdrawal(record)
                        --统计领取次数
                        M.Rpcash.times = M.Rpcash.times + 1
                        M.Rpcash.withdrawals_times[mall_id] = M.Rpcash.withdrawals_times[mall_id] + 1
                        M.flush_Rpcash()
                        return {result =0,wallet = qq_wallet,total_fee=total_fee}
                    elseif body.data.code ==2 then
                        --延迟到账 审核中
                        skynet.logi(string.format("%s ===成功提现，但是要审核=== %s ,out_trade_no %s",openid,total_fee,body.data.out_trade_no))
                        -- 加入审核订单列表
                        record.state = 2
                        M.insert_qq_hb_withdrawal(record)
                        --统计领取次数
                        M.Rpcash.times = M.Rpcash.times + 1
                        M.Rpcash.withdrawals_times[mall_id] = M.Rpcash.withdrawals_times[mall_id] + 1
                        M.flush_Rpcash()
                        return {result =0,wallet = qq_wallet,total_fee=total_fee}
                    end
                end 
                skynet.logi(string.format("%s ===半成功提现=== %s ,out_trade_no %s",openid,total_fee,body.data.out_trade_no))
                return {result =0,wallet = qq_wallet,total_fee=0} --成功但是body.data.code异常
            end
        else
            return {result =5} --SDK返回失败
        end
    end

    return {result =1}
end

--
-- QQ 余额 兑换金币
--
function request:qq_exchange_gold()
    local mall_id = self.mall_id
    local content = cfg_Rpgold[mall_id]

    --可领取条件判断

    print("===qq_exchange_gold condition===: ",M.Rpcash.exChange_times[mall_id] >content.exchargetime )

    if M.Rpcash.exChange_times[mall_id] >content.exchargetime then
        return {result = 4} --领取次数条件cfg不足
    end

    -- content.exchargetime
    if content==nil then
        return {result =4} --领取次数条件不足
    end

    --货币类型断言
    assert(content.getaward.id == COIN_ID, "qq_exchange_gold type error getaward.id: "..content.getaward.id)
    assert(content.cost.id == QQ_WALLET, "qq_exchange_gold type error cost.id: "..content.cost.id)

    if ma_data.get_qq_wallet() < content.cost.num then
        return {result = 6} --余额不足
    end

    local total_fee = content.getaward.num
    local qq_wallet = ma_data.add_qq_wallet(-content.cost.num ,GOODS_WAY_QQ_WALLET_EXCHANGE_GOLD,"qq余额兑换",true,nil,nil)    
    local gold = ma_data.add_gold(total_fee,GOODS_WAY_QQ_WALLET_EXCHANGE_GOLD,"qq余额兑换",true,nil,nil)

    --加入兑换订单列表
    local record = {
        openid = ma_data.db_info.openid,
        act_name = self.act_name,
        total_fee = total_fee,
        create_time = os.time(), --下单时间
        state = 1,               --订单状态 1已领取，2 审核中,3审核通过未领取
        exchange_type = true,   --提现/兑换
    }
    M.insert_qq_hb_withdrawal(record)
    --统计领取次数
    M.Rpcash.exChange_times[mall_id] = M.Rpcash.exChange_times[mall_id] + 1
    M.flush_Rpcash()

    --通知客户端
    ma_data.send_push("buy_suc", {
        mall_id = self.mall_id,
        goods_list = content.getaward,
        msgbox = 1
    })

    return {result =0,wallet= qq_wallet,gold=gold}
end

--
-- QQ 领取红包余额
--
function request:qq_ads_reward()
    local subjoinDesc = self.subjoinDesc
    if subjoinDesc == "games" then
        --对局红包
        if M.Ads_data.games <1 then
            return  {result = 4 } -- 次数不足
        end

        M.Ads_data.games_count = (M.Ads_data.games_count or 0 ) + 1-- 累计次数+1
        local content = M.FindFromCfg(cfg_Rpgames,M.Ads_data.games_count)
        if content == nil then
            return  {result = 3 } -- 商品不存在
        end

        --断言货币类型
        assert(content.RPaward[1].id == QQ_WALLET, "qq_ads_reward subScene cfg.id error subjoinDesc: "..subjoinDesc)

        M.Ads_data.games = M.Ads_data.games - 1  -- 可用次数-1
        M.flush_ads()

        --发放奖励 默认 QQ_WALLET
        local reward_num = math.random(content.RPaward[1].num,content.RPaward[2].num)        
        local qq_wallet = ma_data.add_qq_wallet(reward_num ,GOODS_WAY_QQ_WALLET_ADS,"qq视频红包",true,nil,{subjoinDesc = subjoinDesc})
        return {result =0,wallet = reward_num,times = M.Ads_data.games}
    elseif subjoinDesc == "everyday" then
        --每日礼包
        if M.Ads_data.everyday <1 then
            return  {result = 4 } -- 次数不足
        end

        local content = cfg_Rpeveryday[3]
        if content == nil then
            return  {result = 3 } -- 商品不存在
        end

        --断言货币类型
        assert(content.award[3][1].id == QQ_CASH, "qq_ads_reward subScene cfg.id error subjoinDesc: "..subjoinDesc)

        M.Ads_data.everyday = M.Ads_data.everyday - 1  -- 可用次数-1
        M.flush_ads()

        --发放奖励 默认 QQ_CASH 提现到QQ钱包
        local rand = math.random(1,#content.award[3])
        local ok, body = skynet.call("httpclient", "lua", "QQ_minigame_hb_send",openid,1,subjoinDesc,rand/100.0,"每日礼包")
        -- print("call QQ_minigame_hb_send :",ok,body)        
        if ok == 200 then
            table.print(body)
            if body.code==1 then
                --发送成功
                if ok then                   
                    return {result =0,times = M.Ads_data.everyday}                    
                end
            else
                return {result =5} --SDK返回失败
            end
        end
        return {result =5} --SDK返回失败 
    elseif subjoinDesc == "online" then
        --在线红包
        local get_type = self.times or 0   
   

        --更新领取倒计时
        local nowtime = os.time()
        if nowtime - M.Ads_data.online_time >= 120 then
            print(" ==== qq ads  online ==== time ok!!")
            M.Ads_data.online = 1
            M.Ads_data.online_time  = nowtime
        end

        if M.Ads_data.online <1 then
            return  {result = 4 } -- 次数不足，CD中
        end
        
        local content = cfg_Rpeveryday[4]
        if get_type>1 then
            content =  cfg_Rpeveryday[5]
        end        
        if content == nil then
            return  {result = 3 } -- 商品不存在
        end

        --断言货币类型
        assert(content.award[1].id == QQ_WALLET, "qq_ads_reward subScene cfg.id error subjoinDesc: "..subjoinDesc)

        M.Ads_data.online = M.Ads_data.online - 1  -- 可用次数-1
        M.flush_ads()

        --发放奖励 默认 QQ_WALLET
        local reward_num = content.award[1].num
        local qq_wallet = ma_data.add_qq_wallet(reward_num ,GOODS_WAY_QQ_WALLET_ADS,"qq视频红包",true,nil,{subjoinDesc = subjoinDesc})
        return {result =0,wallet = reward_num,times = M.Ads_data.online}       
    elseif  subjoinDesc == "day_cash" then
        --提现红包
        local mall_id = self.times or 1         
        if mall_id >2 then
            return {result = 3 } --商品不存在
        end                 

        local content = cfg_Rpeveryday[mall_id]      
        if content == nil then
            return  {result = 3 } -- 商品不存在
        end

        local start,comp = M.Get_watch_count(nil,true)
        if mall_id==1 and comp < content.adcount and M.Ads_data.daycash_1 <1 then
            return  {result = 4 } -- 次数不足
        end        
        if mall_id==2 and comp < content.adcount and M.Ads_data.daycash_2 <1 then
            return  {result = 4 } -- 次数不足
        end

        --断言货币类型
        assert(content.award[1].id == QQ_CASH, "qq_ads_reward subScene cfg.id error subjoinDesc: "..subjoinDesc)

        if mall_id==1 then
            M.Ads_data.daycash_1 = M.Ads_data.daycash_1 - 1  -- 可用次数-1
            M.flush_ads()
        elseif mall_id==2 then
            M.Ads_data.daycash_2 = M.Ads_data.daycash_2 - 1  -- 可用次数-1
            M.flush_ads()
        end
        --发放奖励 默认 QQ_CASH
        local reward_num = content.award[1].num
        local ok, body = skynet.call("httpclient", "lua", "QQ_minigame_hb_send",openid,1,subjoinDesc,reward_num/100.0,"每日礼包")
        -- print("call QQ_minigame_hb_send :",ok,body)        
        if ok == 200 then
            table.print(body)
            if body.code==1 then
                --发送成功
                if ok then 
                    --todo 每日提现返回times含义不完整                  
                    return {result =0,wallet = reward_num,times = 0 }                    
                end
            else
                return {result =5} --SDK返回失败
            end
        end
        --todo 每日提现返回times含义不完整
        return {result =0,wallet = reward_num,times = 0 }               
    end
    
    return {result = 3 } --商品不存在
end

--
-- GM 方法 修改广告次数
--
function request:gm_qq_ads_times()
    local subjoinDesc = self.subjoinDesc
    if subjoinDesc == "games" then
        M.Ads_data.games = M.Ads_data.games + (self.times or 0)
        M.flush_ads()
        return {subjoinDesc = self.subjoinDesc,times = M.Ads_data.games }
    elseif subjoinDesc == "everyday" then
        M.Ads_data.everyday = M.Ads_data.everyday + (self.times or 0)
        M.flush_ads()
        return {subjoinDesc = self.subjoinDesc,times = M.Ads_data.everyday }
    elseif subjoinDesc == "online" then
        M.Ads_data.online = M.Ads_data.online + (self.times or 0)
        M.flush_ads()
        return {subjoinDesc = self.subjoinDesc,times = M.Ads_data.online }
    elseif subjoinDesc == "day_cash" then
        local start,comp = M.Get_watch_count(nil,true)
        --todo 每日提现返回times含义不完整
        return {subjoinDesc = self.subjoinDesc,times = comp }
    end

    return {subjoinDesc = self.subjoinDesc}
end


--提交广告播放次数
function request:qq_ads_watch_submit()
    local subjoinDesc = self.subjoinDesc
    if self.type == nil then
        return {result = 0 }
    end
    local bPlaySucc = self.type == 2

    if M.Ads_data.watched.day[subjoinDesc] ==nil then
        M.Ads_data.watched.day[subjoinDesc] ={0,0}
    end
    if M.Ads_data.watched.all[subjoinDesc] ==nil then
        M.Ads_data.watched.all[subjoinDesc] ={0,0}
    end
    if bPlaySucc then
        M.Ads_data.watched.day[subjoinDesc][2] =  M.Ads_data.watched.day[subjoinDesc][2] + 1
        M.Ads_data.watched.all[subjoinDesc][2] =  M.Ads_data.watched.all[subjoinDesc][2] + 1
        local rank,value,value2= skynet.call("ranklist_mgr","lua","get_rank","watch_ads",ma_data.my_id)
        print(" 我的广告播放次数 ",rank,value,value2)
        --排行榜统计自己的次数 并提交排行榜
        skynet.call("ranklist_mgr","lua","update_watch_ads",ma_data.my_id,value+1,
            ma_data.db_info.nickname,ma_data.db_info.headimgurl,ma_data.get_picture_frame(ma_data.db_info.backpack))
    else
        M.Ads_data.watched.day[subjoinDesc][1] =  M.Ads_data.watched.day[subjoinDesc][1] + 1
        M.Ads_data.watched.all[subjoinDesc][1] =  M.Ads_data.watched.all[subjoinDesc][1] + 1
    end   
    M.flush_ads()
    print("===table M.Ads_data.watched ===")
    table.print(M.Ads_data.watched)
    print("===table Get_watch_count(nil,true)===")
    table.print(M.Get_watch_count(nil,true))
    return {result =1}
end

-- function cmd.get_intAward_award(index)
--     local Double = true
--     local tmpTbl = M.get_intAward_award(index,Double)
--     ma_data.send_push('get_intAward_award',tmpTbl)
-- end

-------------------------------------------------------------------------------
local function init()
    -- ma_data.follow_conf(M, cfg_conf.COLL.ACTIVITY_CONF)
    -- init_int_award_module()
    -- ma_data.act_data = skynet.call(get_db_mgr(),"lua","find_one",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{_id=false})

    -- if not ma_data.act_data then
    --     ma_data.act_data = {}
    --     ma_data.act_data.id = ma_data.my_id
    --     skynet.call(get_db_mgr(),"lua","insert",COLL.ACTIVITY_DATA,ma_data.act_data)
    -- end
    -- --table.print(ma_data.act_data)
    -- if not ma_data.db_info.bailout then
    --     ma_data.db_info.bailout = {t = os.time(),count=0}
    -- end
    M.InitRpcash()
    M.InitAds()
    M.ResetEveryDay()
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

ma_data.ma_qq_wallet = M
return M