local skynet = require "skynet"
local ma_data = require "ma_data"
-- local active_conf = require "conftbl.active"
local cfg_gift = require "cfg.cfg_gift"
local cfg_global = require "cfg.cfg_global"
local place_config = require "cfg.place_config"
local COLL = require "config/collections"
require "define"
require "pub_util"
local request = {}
local cmd = {}


-- 新玩家登录有礼状态
local STATE = {
    NO_FINISHED = 0,
    FINDISHED = 1,
    RECEIVED = 2,
    Expired = 3
}


local M = {}
--
-- 救助金
--
function request:receive_bailout()
    local cfg = cfg_global[1]
    if ma_data.db_info.gold >= cfg.benefit then
        return {result = 1}
    else
        M.bailout_check_day()

        --vip加成系数   
        local vip_bailout_num = ma_data.get_vip_ability("succourCount")
        local vip_ability = ma_data.get_vip_ability("succourAward")      
        
        if ma_data.db_info.bailout.count >= vip_bailout_num then
            return {result = 2}
        else
            ma_data.db_info.bailout.count = ma_data.db_info.bailout.count + 1 
            skynet.call(get_db_mgr(), "lua", "update", COLL.USER, {id = ma_data.my_id}, {bailout = ma_data.db_info.bailout})

            local rewards = cfg.benefit_get
            local month_type = ma_data.ma_month_card.get_type()
            local fanNum = cfg_month_card["multiple"..month_type]
            if month_type > 0 then
                rewards = goods_list_mul(rewards,(fanNum/10000))
            end
            --vip加成系数   
            rewards = goods_list_mul(rewards,vip_ability / 10000)

            ma_data.add_goods_list(rewards,GOLDRECEIVE,"receive_aid")
            ma_data.send_push("buy_suc", {
                goods_list = rewards,
                msgbox = 1
            })
            return {result = 0, t=ma_data.db_info.bailout.t, count = ma_data.db_info.bailout.count}
        end
    end
end

--获取救助金剩余次数
function request:get_bailout_info()
    M.bailout_check_day(true)
    return {t = ma_data.db_info.bailout.t,count = ma_data.db_info.bailout.count}
end

function M.bailout_check_day(syncdb)
    if not check_same_day(ma_data.db_info.bailout.t) then
        ma_data.db_info.bailout.t = os.time()
        ma_data.db_info.bailout.count = 0
        if syncdb then
            skynet.call(get_db_mgr(), "lua", "update", COLL.USER, {id = ma_data.my_id}, {bailout = ma_data.db_info.bailout})
        end
    end
end

-- 获取自身的邀请数据
function request:get_share_tbl()
    if not ma_data.share_tbl then
        ma_data.share_tbl = skynet.call(get_db_mgr(), "lua", "get_share_tbl", ma_data.my_id)
    end

    local pack = {}
    pack.result = true
    pack.bind_num = ma_data.share_tbl.bind_num
    pack.finish_num = ma_data.share_tbl.finish_num
    pack.get_award = ma_data.share_tbl.get_award
    return pack
end

--获取活动信息
function request:get_act_info()
    return {list = skynet.call("active_mgr","lua","get_active_info")}
end

--甄选有礼
--self.actId 活动id
function request:get_select_act_info()
    local actId = tostring(self.actId)
    local actData = ma_data.act_data[actId]
    if not actData then
        return {list=nil}
    end
    local ret = {}
    for giftId,giftInfo in pairs(actData) do
        table.insert(ret,{id=tonumber(giftId),goods=giftInfo.goods})
    end
    return {list = ret}
end

--设置甄选有礼礼包
--self.id 活动id
--self.giftId 礼包id
--self.list 选择物品索引列表
function request:set_select_act_info()
    local actId = tostring(self.id)
    local giftId = tostring(self.giftId)
    local cfgGift = cfg_gift[self.giftId]
    if GIFT_TYPE_GIFTS_SELECT ~= cfgGift.type then
        return {result = 1}
    end
    if #self.list ~= cfgGift.num then
        return {result = 2}
    end
    local awardGoods = {}
    for i,index in ipairs(self.list) do
        local awardKey = "award" .. i
        if not cfgGift[awardKey] or  not cfgGift[awardKey][index] then
            
            return {result = 3}
        end
        table.insert(awardGoods,cfgGift[awardKey][index])
    end
    if not ma_data.act_data[actId] then
        ma_data.act_data[actId] = {}
    end
    local actData = ma_data.act_data[actId]
    if not actData[giftId] then
        actData[giftId] = {goods = awardGoods}
    else
        actData[giftId].goods = awardGoods
    end
    print("set_select_act_info 111",self.id,self.giftId)
    --table.print(self.list)
    skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{[actId]=ma_data.act_data[actId]})
    return {result = 0}
end 

--获取甄选有礼设置的值
--actId 活动id
--giftId 礼包id
function M.get_select_act_awards(id,giftid)
    local actId = tostring(id)
    local giftId = tostring(giftid)
    local cfgGift = cfg_gift[giftid]
   
    local actData = ma_data.act_data[actId]
    if actData[giftId] and actData[giftId].goods and (#(actData[giftId].goods) == cfgGift.num) then
        return actData[giftId].goods
    end
    return nil
end
-------------------------------------------------------------------------------
--嘻嘻大礼包
-------------------------------------------------------------------------------
function M.init_big_gift()
    if not ma_data.act_data.bigGift then
        ma_data.act_data.bigGift = {
            redBloodNum = 0,
            threeOneLv = 0,
            tkingNum = 0,
            godLv = 0,
            get_award = 0,
            redBlood2v2Num =0
        }
    end
    if not ma_data.act_data.bigGift.redBlood2v2Num then
        ma_data.act_data.bigGift.redBlood2v2Num = 0 --补充初始化  
    end  
end
--嘻嘻大礼包
function request:get_xixi_big_gift()
    M.init_big_gift()
    -- print('================嘻嘻大礼包================')
    -- table.print(ma_data.act_data.bigGift)
    return ma_data.act_data.bigGift
end

--更新数据
function M.update_xixi_big_gift(place_id,lv)
    M.init_big_gift()
    if ma_data.act_data.bigGift.get_award == 2 or ma_data.act_data.bigGift.get_award == 1 then
        return
    end
    --print('==========================大礼包条件1==================',place_id,lv)
    local gameId = place_id // 100
    local placeId = place_id % 100
    --print('==========================大礼包条件2==================',gameId,placeId)
    if place_config[gameId][placeId].type == 1 and place_config[gameId][placeId].stype ~= 4 then
        ma_data.act_data.bigGift.redBloodNum = ma_data.act_data.bigGift.redBloodNum + 1
    end

    --红中血流2v2对局统计
    if place_config[gameId][placeId].type == GAME_TYPE_HZXL2v2 then
        ma_data.act_data.bigGift.redBlood2v2Num = (ma_data.act_data.bigGift.redBlood2v2Num or 0 ) + 1 --补充初始化        
    end

    if place_config[gameId][placeId].stype == 2 then
        ma_data.act_data.bigGift.tkingNum = ma_data.act_data.bigGift.tkingNum + 1
    end
    if place_config[gameId][placeId].stype == 4 and lv then
        if lv > ma_data.act_data.bigGift.threeOneLv then
            ma_data.act_data.bigGift.threeOneLv = lv
        end
    end
    if place_config[gameId][placeId].stype == 3 and lv then
        if lv > ma_data.act_data.bigGift.godLv then
            ma_data.act_data.bigGift.godLv = lv
        end
    end

    local curr_info = cfg_global[1].xixi_gift
    --modify by qc 2021.8.4 修改嘻嘻大礼包完成条件
    if ma_data.act_data.bigGift.redBloodNum >= curr_info.redBloodNum and 
       ma_data.act_data.bigGift.redBlood2v2Num >= curr_info.redBlood2v2Num and 
       ma_data.act_data.bigGift.godLv >= curr_info.godLv then
       --完成标记
       ma_data.act_data.bigGift.get_award = 1
    end
    skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{bigGift=ma_data.act_data.bigGift})
end

--领取嘻嘻大礼包
function request:get_xix_gift_award()
    M.init_big_gift()
    local xixi_award = cfg_global[1].xixi_award
    if ma_data.act_data.bigGift.get_award == 1 then
       --发送礼物
        ma_data.add_goods_list(xixi_award,GOODS_WAY_NEW_PLAYER, "嘻嘻大礼包")
        ma_data.send_push("buy_suc", {goods_list = xixi_award,msgbox = 1})

       ma_data.act_data.bigGift.get_award = 2
       skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{bigGift=ma_data.act_data.bigGift})
       return {result = true}
    end
    return {result = false}
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--新手任务初始化
function M.init_new_player_task()
    if not ma_data.db_info.newPTask then
        ma_data.db_info.newPTask = {}
        ma_data.db_info.newPTask.task = {}
        for i=1,#cfg_newhand_task do
             ma_data.db_info.newPTask.task[i] = 0
        end
        ma_data.db_info.newPTask.award = 1
    end
end
--新手任务
function request:get_new_player_data()
    M.init_new_player_task()
    return {newPTask = ma_data.db_info.newPTask}
end
--新手任务
function request:new_player_task_award()
    --self.index 第几个奖励，self.awardType 哪一种奖励
    M.init_new_player_task()
    local newPTask = ma_data.db_info.newPTask
    if self.awardType == 1 then
        if newPTask.award ~= 1 then
            return {result = 1,newPTask = newPTask,index = self.index}
        end
        ma_data.add_goods_list(cfg_global[1].newhand_award,NEWPAWARD,"新手礼包")
        ma_data.send_push("buy_suc", {
            goods_list = cfg_global[1].newhand_award,
            msgbox = 1
        })
        newPTask.award = 2
    else
        if newPTask.task[self.index] ~= 1 then
            return {result = 1,newPTask = newPTask,index = self.index}
        end
        ma_data.add_goods_list(cfg_newhand_task[self.index].award,NEWPAWARD,"新手礼包")
        ma_data.send_push("buy_suc", {
            goods_list = cfg_newhand_task[self.index].award,
            msgbox = 1
        })
        newPTask.task[self.index] = 2
    end
    skynet.send(get_db_mgr(),"lua","update",COLL.USER,{id=ma_data.my_id},{newPTask=ma_data.db_info.newPTask})
    return {result = 0,newPTask = newPTask,index = self.index}
end

--新手任务完成
function M.finish_new_player_task(index)
    M.init_new_player_task()
    local newPTask = ma_data.db_info.newPTask
    if newPTask.task[index] ~= 0 then
        return
    end
    newPTask.task[index] = 1
    skynet.send(get_db_mgr(),"lua","update",COLL.USER,{id=ma_data.my_id},{newPTask=ma_data.db_info.newPTask})
end
----------------------------------------------------------------------
----------------------------------------------------------------------
local aop = require "aop"
local int_award_module_state = aop.helper:make_state("int_award_module")
local int_award_request = aop.helper:make_interface_tbl(int_award_module_state)

--整点活动 0:未开启,1:可领取,2:可补领,3:已领取
function M.check_integer_time()
    local currTime = tonumber(os.date('%H%M'))
    if not ma_data.act_data.intAward then
        ma_data.act_data.intAward = {}
        ma_data.act_data.intAward.t = os.time()
        ma_data.act_data.intAward.award = {}
        for i=1,#int_award_config do
           ma_data.act_data.intAward.award[i] = 0
        end
    elseif not check_same_day(ma_data.act_data.intAward.t) then
        for i=1,#int_award_config do
            ma_data.act_data.intAward.award[i] = 0
        end
        ma_data.act_data.intAward.t = os.time()
    end
    for i,info in ipairs(int_award_config) do
        if ma_data.act_data.intAward.award[i] ~= 3 then
            if currTime < info.begintime then
                ma_data.act_data.intAward.award[i] = 0
            elseif currTime > info.endtime then
                ma_data.act_data.intAward.award[i] = 2
            else
                ma_data.act_data.intAward.award[i] = 1
            end
        end
    end
end

--获取整点信息
function int_award_request:get_intAward_info()
    M.check_integer_time()
    return {result = 0, intAward = ma_data.act_data.intAward.award}
end

function M.get_intAward_award(index,Double)
    M.check_integer_time()
    print('============获取整点奖励==========',index)
    table.print(ma_data.act_data.intAward)
    if not ma_data.act_data.intAward.award[index] then
        return {result=1,intAward = ma_data.act_data.intAward.award}
    end


    if ma_data.act_data.intAward.award[index] == 2 then
        --可补领
        if ma_data.db_info.diamond < int_award_config[index].price then
            return {result = 2,intAward = ma_data.act_data.intAward.award}
        end
        ma_data.add_diamond(-int_award_config[index].price, GOODS_WAY_FIXHOUR, "整点奖励钻石购买")
        local month_type = ma_data.ma_month_card.get_type()
        local fanNum = cfg_month_card["multiple"..month_type]
        local rewards = table.clone(int_award_config[index].awards)
        if month_type > 0 then
            rewards = goods_list_mul(rewards,(fanNum/10000))
        end

        --vip加成系数   
        local vip_ability = ma_data.get_vip_ability("timeonAward")
        --  print("VIP加成前",vip_ability)
        --  table.print(rewards)
        rewards = goods_list_mul(rewards,vip_ability / 10000)
        --  print("VIP加成后")
        --  table.print(rewards)

        --特殊处理 整点在线奖励 修正原数据到5点 modify by qc 2021.7.30
        for _,goods in pairs(rewards) do
            if goods.id == VIP_POINT then
                goods.num = 5
            end
        end

        ma_data.add_goods_list(rewards, GOODS_WAY_FIXHOUR, "整点奖励钻石购买")
        ma_data.send_push("buy_suc", {
            goods_list = rewards,
            msgbox = 1
        })
        ma_data.act_data.intAward.award[index] = 3
        skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{intAward=ma_data.act_data.intAward})
        return {result=0,intAward = ma_data.act_data.intAward.award}
    elseif ma_data.act_data.intAward.award[index] == 1 then
        --可领取
        local month_type = ma_data.ma_month_card.get_type()
        local fanNum = cfg_month_card["multiple"..month_type]
        local rewards = table.clone(int_award_config[index].awards)
        if month_type > 0 then
            rewards = goods_list_mul(rewards,(fanNum/10000))
        end

        --vip加成系数   
        local vip_ability = ma_data.get_vip_ability("timeonAward")
        --  print("VIP加成前",vip_ability)
        --  table.print(rewards)
        rewards = goods_list_mul(rewards,vip_ability / 10000)
        --  print("VIP加成后")
        --  table.print(rewards)
        
        --看视频双倍领取金币
        if Double then
            currency_numX2(rewards)
        end

        --特殊处理 整点在线奖励 修正原数据到5点 modify by qc 2021.7.31
        for _,goods in pairs(rewards) do
            if goods.id == VIP_POINT then
                goods.num = 5
            end
        end
        
        ma_data.add_goods_list(rewards, GOODS_WAY_FIXHOUR, "整点奖励免费")
        ma_data.send_push("buy_suc", {
            goods_list = rewards,
            msgbox = 1
        })
        ma_data.act_data.intAward.award[index] = 3
        skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{intAward=ma_data.act_data.intAward})
        return {result=0,intAward = ma_data.act_data.intAward.award}
    elseif ma_data.act_data.intAward.award[index] == 0 then
        return {result=4,intAward = ma_data.act_data.intAward.award}
    else
        return {result=3,intAward = ma_data.act_data.intAward.award}
    end
end

function cmd.get_intAward_award(index)
    local Double = true
    local tmpTbl = M.get_intAward_award(index,Double)
    ma_data.send_push('get_intAward_award',tmpTbl)
end

--获取整点奖励
function int_award_request:get_intAward_award()
    return M.get_intAward_award(self.index,self.Double)
end

table.connect(request, int_award_request)

local cfg_conf = require "cfg_conf"
local function init_int_award_module()
    local subtype = 2003
    local tbl_match = {subtype = subtype}
    local conf = skynet.call(cfg_conf.DB_MGR, "lua", "find_one", cfg_conf.COLL.ACTIVITY_CONF, tbl_match)
    print("int_award_module conf =>", table.tostr(conf))
    int_award_module_state.init(conf)
end

function M.on_conf_update()
    init_int_award_module()
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--财神降临活动
function M.refreshWealthGod()
    print('=============财神降临活动=====================')
    table.print(ma_data.act_data.WealthGod)
    skynet.call(get_db_mgr(), "lua", "update", COLL.ACTIVITY_DATA, {id = ma_data.my_id}, {WealthGod = ma_data.act_data.WealthGod})
end
function M.initWealthGod()
    if not ma_data.act_data.WealthGod then
        ma_data.act_data.WealthGod = {}
        ma_data.act_data.WealthGod.t = os.time()
        ma_data.act_data.WealthGod.endTime = 0
        ma_data.act_data.WealthGod.randAward = 0
        ma_data.act_data.WealthGod.godFire = {0,0,0,0,0}
        ma_data.act_data.WealthGod.godIndex = 0
        ma_data.act_data.WealthGod.discountNum = 0
        ma_data.act_data.WealthGod.awardId = 0
        ma_data.act_data.WealthGod.awardIndex = 0
    end

    if not check_same_day(ma_data.act_data.WealthGod.t) then
        ma_data.act_data.WealthGod.discountNum = 0
        ma_data.act_data.WealthGod.t = os.time()
        M.refreshWealthGod()
    end
end

--获取当前的财神信息
function request:getWealthGodInfo()
    M.initWealthGod()
    return {WealthGod = ma_data.act_data.WealthGod}
end

--随机财神
function M.randWealthGod()
    --五个财神汇集
    local haveFive = true
    for i,v in ipairs(ma_data.act_data.WealthGod.godFire) do
        if v ~= 1 then
            haveFive = false
            break
        end
    end

    if haveFive then
        return 6
    end

    local tempRand = math.random(1,100)
    local godIndex = 0
    local allRand = 0
    for i,godInfo in ipairs(cfg_mammon) do
        allRand = allRand + godInfo.appear
        if tempRand <= allRand then
            return i
        end
    end
    return 0
end

--上香
function request:prayWealthGod()
    M.initWealthGod()
    if ma_data.get_goods_num(100011) < 1 then
        return {result = 1}
    end
    local goods = {id = 100011,num = -1}
    ma_data.add_goods(goods,GOODS_WAY_entity,'财神上香',nil,true)

    --随机财神
    ma_data.act_data.WealthGod.godIndex = M.randWealthGod()
    if ma_data.act_data.WealthGod.godIndex == 6 then
        ma_data.act_data.WealthGod.godFire = {0,0,0,0,0}
    end
    if ma_data.act_data.WealthGod.godIndex > 0 then
        local currGod = cfg_mammon[ma_data.act_data.WealthGod.godIndex]
        --随机礼包
        ma_data.act_data.WealthGod.awardIndex = math.random(1,#currGod.giftInfo)
        local currAwards = currGod.giftInfo[ma_data.act_data.WealthGod.awardIndex]
        local tempRand = math.random(1,10000)
        local allRate = 0
        for i,awardId in ipairs(currAwards) do
            allRate = allRate + awardId.rate
            if tempRand <= allRate then
                ma_data.act_data.WealthGod.randAward = i
                break
            end
        end
        
        local awardInfo = currAwards[ma_data.act_data.WealthGod.randAward]

        --随机价格
        ma_data.act_data.WealthGod.awardId = awardInfo.id
        ma_data.act_data.WealthGod.endTime = os.time() + 1800
        M.refreshWealthGod()
        return {result = 0,WealthGod = ma_data.act_data.WealthGod}
    end
    return {result = 2,WealthGod = ma_data.act_data.WealthGod}
end

--刷新折扣
--modify by qc 2021.7.2 修改为根据vip等级和配置 决定每日可免费刷新次数
function request:updateDiscount()
    M.initWealthGod()

   

    -- local month_type = ma_data.ma_month_card.get_type()
    -- local max_buy_count = cfg_month_card["mammon"..month_type] or 0
      --vip加成系数   
    local max_buy_count = ma_data.get_vip_ability("mammonRefresh")  or 0 
    if ma_data.act_data.WealthGod.discountNum >= max_buy_count then
        return {result = 1,discounxNum = ma_data.act_data.WealthGod.discountNum}
    end
    if ma_data.act_data.WealthGod.godIndex > 0 then
        local currGod = cfg_mammon[ma_data.act_data.WealthGod.godIndex]
        --随机礼包
        local currAwards = currGod.giftInfo[ma_data.act_data.WealthGod.awardIndex]
        local tempRand = math.random(1,10000)
        local allRate = 0
        for i,awardId in ipairs(currAwards) do
            allRate = allRate + awardId.rate
            if tempRand <= allRate then
                ma_data.act_data.WealthGod.randAward = i
                break
            end
        end
        
        local awardInfo = currAwards[ma_data.act_data.WealthGod.randAward]

        --随机价格
        ma_data.act_data.WealthGod.awardId = awardInfo.id
        ma_data.act_data.WealthGod.discountNum = ma_data.act_data.WealthGod.discountNum + 1
        M.refreshWealthGod()
    end
   
    return {result = 0,discountNum = ma_data.act_data.WealthGod.discountNum,
            awardId = ma_data.act_data.WealthGod.awardId}
end

function M.getPriceAndAward()
    M.initWealthGod()
    return ma_data.act_data.WealthGod.awardId
end

--更新购买数据
function M.updatePriceAndAward()
    ma_data.act_data.WealthGod.endTime = 0
    ma_data.act_data.WealthGod.randAward = 0
    if ma_data.act_data.WealthGod.godIndex == 6 then
        ma_data.act_data.WealthGod.godFire = {0,0,0,0,0}
    elseif ma_data.act_data.WealthGod.godIndex ~= 0 then
        ma_data.act_data.WealthGod.godFire[ma_data.act_data.WealthGod.godIndex] = 1
    end
    ma_data.act_data.WealthGod.godIndex = 0
    ma_data.act_data.WealthGod.awardId = 0
    ma_data.act_data.WealthGod.awardIndex = 0
    M.refreshWealthGod()
    ma_data.send_push('updateWealthGod',{WealthGod = ma_data.act_data.WealthGod})
end

--免费领取
function request:freeGetAward()
    local Godmall_id = ma_data.ma_hall_active.getPriceAndAward()
    if mall_conf[Godmall_id].coin_type ~= 0 then
        return {result = 1}
    end
    local goods_pack = mall_conf[Godmall_id]
    local goods_list = goods_pack and goods_pack.content
    ma_data.add_goods_list(goods_list, FREE_AWARD, "财神免费礼包")
    ma_data.send_push("buy_suc", {
        goods_list = goods_list,
        msgbox = 1
    })
    M.updatePriceAndAward()
    return {result = 0}
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--10月新版本领取
function request:getNewSepInfo()
    local overTime = 1603371600
    if ma_data.db_info.channel and ma_data.db_info.channel == 'hzmjlx_oppo' then
        overTime = 1603710000
    end
    if ma_data.db_info.firstLoginDt > overTime then
        return {result = 1}
    end
    if ma_data.act_data.SepAward and ma_data.act_data.SepAward == 2 then
        return {result = 2}
    end
    return {result = 0}
end
function request:getNewSwpAward()
    local overTime = 1603371600
    if ma_data.db_info.channel and ma_data.db_info.channel == 'hzmjlx_oppo' then
        overTime = 1603710000
    end
    if ma_data.db_info.firstLoginDt > overTime then
        return {result = 1}
    end
    if ma_data.act_data.SepAward and ma_data.act_data.SepAward == 2 then
        return {result = 2}
    end
    ma_data.act_data.SepAward = 2
    skynet.call(get_db_mgr(), "lua", "update", COLL.ACTIVITY_DATA, {id = ma_data.my_id}, {SepAward = ma_data.act_data.SepAward})
    ma_data.add_diamond(100, FREE_AWARD, "10月新版本礼包")
    local goods_list = {{id = 100001,num = 100}}
    ma_data.send_push("buy_suc", {
        goods_list = goods_list,
        msgbox = 1
    })
    return {result = 0}
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--国庆八天乐
function M.refreshGuoQing()
    -- print('=============国庆活动=====================')
    -- table.print(ma_data.act_data.GuoQingAward)
    skynet.call(get_db_mgr(), "lua", "update", COLL.ACTIVITY_DATA, {id = ma_data.my_id}, {GuoQingAward = ma_data.act_data.GuoQingAward})
end

--是否在活动期间内
function M.inTheGuoQingTime()
    return inTheTime(GuoQing_time_config.begintime,GuoQing_time_config.endtime)
end
--玩家登出/掉线
function M.playerLogout()
    if not M.inTheGuoQingTime() then
        return
    end
     if not ma_data.act_data then
        skynet.error('not-ma_data.act_data')
        return
    end
    M.check_online_time_award()
    if not check_same_day(ma_data.db_info.last_time) then
        ma_data.act_data.GuoQingAward.online_time = ma_data.act_data.GuoQingAward.online_time + os.time() - get_today_0_time( )
    else
        ma_data.act_data.GuoQingAward.online_time = ma_data.act_data.GuoQingAward.online_time + os.time() - ma_data.db_info.last_time
    end
    print('=================玩家登出==========================',ma_data.act_data.GuoQingAward.online_time,ma_data.db_info.last_time)
    M.refreshGuoQing()
end
---1:不可领取,1:可领取,0,2,4,6,8:领取等级
--检测在线时长奖励
function M.check_online_time_award()
    if not ma_data.act_data.GuoQingAward then
        ma_data.act_data.GuoQingAward = {}
        ma_data.act_data.GuoQingAward.online_time = 0
        ma_data.act_data.GuoQingAward.award = {}
        ma_data.act_data.GuoQingAward.t = os.time()
        for i=1,#GuoQing_award_config do
           ma_data.act_data.GuoQingAward.award[i] = -1
        end
    elseif not check_same_day(ma_data.act_data.GuoQingAward.t) then
        for i=1,#GuoQing_award_config do
            ma_data.act_data.GuoQingAward.award[i] = -1
        end
        ma_data.act_data.GuoQingAward.online_time = 0
        ma_data.act_data.GuoQingAward.t = os.time()
    end

    if not check_same_day(ma_data.db_info.last_time) then
        currTime = ma_data.act_data.GuoQingAward.online_time + os.time() - get_today_0_time( )
    else
        currTime = ma_data.act_data.GuoQingAward.online_time + os.time() - ma_data.db_info.last_time
    end
    for i,info in ipairs(GuoQing_award_config) do
        if ma_data.act_data.GuoQingAward.award[i] == -1 then
            if currTime > info.time then
                ma_data.act_data.GuoQingAward.award[i] = 1
            end
        end
    end
    print('==================刷新=====================')
    table.print(ma_data.act_data.GuoQingAward)
end

--获取国庆信息
function request:get_GuoQingAward_info()
    if not M.inTheGuoQingTime() then
        return {result=1}
    end
    M.check_online_time_award()
    print('=================玩家获取国庆信息========',ma_data.act_data.GuoQingAward.online_time,ma_data.db_info.last_time)
    return {GuoQingAward = ma_data.act_data.GuoQingAward.award,
            onlineTime = ma_data.act_data.GuoQingAward.online_time,
            result = 0}
end

--获取国庆奖励
function request:get_GuoQingAward_award()
    if not M.inTheGuoQingTime() then
        return {result=3}
    end
    M.check_online_time_award()
    print('============获取国庆奖励==========',self.index)
    table.print(ma_data.act_data.GuoQingAward)
    if not ma_data.act_data.GuoQingAward.award[self.index] then
        return {result=3,GuoQingAward = ma_data.act_data.GuoQingAward.award,
                onlineTime = ma_data.act_data.GuoQingAward.online_time}
    end
    
    if ma_data.act_data.GuoQingAward.award[self.index] < 8 then
        if ma_data.act_data.GuoQingAward.award[self.index] == -1 then
            return {result=1,GuoQingAward = ma_data.act_data.GuoQingAward.award}
        end
        local month_type = ma_data.ma_month_card.get_type()
        local fanNum = cfg_month_card["multiple"..month_type]
        local currfanNum =  0
        print('=============获取国庆奖励=================',ma_data.my_id,ma_data.act_data.GuoQingAward.award[self.index])
        if ma_data.act_data.GuoQingAward.award[self.index] ~= 1 then
            currfanNum = cfg_month_card["multiple"..ma_data.act_data.GuoQingAward.award[self.index]] or 10000
        end
        --领奖
        local rewards = GuoQing_award_config[self.index].awards
        if fanNum and fanNum > 0 then
            fanNum = (fanNum-currfanNum)/10000
            rewards = goods_list_mul(rewards,fanNum)
        end

        ma_data.add_goods_list(rewards,GUOQING,"国庆在线奖励")
        ma_data.send_push("buy_suc", {
            goods_list = rewards,
            msgbox = 1
        })
        ma_data.act_data.GuoQingAward.award[self.index] = month_type
        M.refreshGuoQing()
        return {result = 0,GuoQingAward = ma_data.act_data.GuoQingAward.award,
        onlineTime = ma_data.act_data.GuoQingAward.online_time}
    else
        return {result=2,GuoQingAward = ma_data.act_data.GuoQingAward.award,
            onlineTime = ma_data.act_data.GuoQingAward.online_time}
    end
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------



------------------------------------
--初始化天赐豪礼
local function init_Act_GiftCom()  
    -- print("====debug qc==== 初始 天降豪礼 ")    
    return
    {
        buyc = 0,
        refreshc =-1, -- 初始后肯定随机 +1 
        discount =0,
        originalPrice =0,
        value =0,
        mallid=0,
        time = os.time(),
        e_info=0,
    }
end

--刷新数据 改写pack
local function refresh_Act_GiftCom(pack) 
    local spreerefresh = cfg_global[1].spreerefresh  
    local spreebuy = cfg_global[1].spreebuy
    assert(spreerefresh,"spree config error . spreerefresh")   
    assert(spreebuy,"spree config error . spreebuy")

    if pack.refreshc < spreerefresh then       
        local idx = math.random(#spreebuy)        
        pack.mallid = SPREE_MALL[idx]
        pack.refreshc = pack.refreshc + 1
        local mall = mall_conf[pack.mallid]
        assert(mall,"spree config cfg_mall "..pack.mallid)   
        pack.discount = math.random(500,5000) /100000  
        pack.value = math.ceil(mall.price * 10000 / pack.discount)
        pack.originalPrice = math.floor(pack.value /10000)  
    else
        pack.e_info = 1 --刷新次数用尽
    end
    -- print("====debug qc==== 刷新天降豪礼 ")
    -- table.print(pack)    
    return pack
end

--天赐豪礼
function request:get_giftcom_data()
    local type = self.type
    if ma_data.act_data.spree == nil or not check_same_day(ma_data.act_data.spree.time) then
        --刷新 初始化数据
        ma_data.act_data.spree = init_Act_GiftCom()
        ma_data.act_data.spree = refresh_Act_GiftCom(ma_data.act_data.spree)
        skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{ spree = ma_data.act_data.spree})
    end

    if type == 1 then
        --刷新1次
        ma_data.act_data.spree = refresh_Act_GiftCom(ma_data.act_data.spree)
        skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{ spree = ma_data.act_data.spree})
    end
    return {GiftCom = ma_data.act_data.spree}
end

--购买到账回调
function M.buy_succ_spree(mall_id)
    -- print("====debug qc==== buy_succ_spree  ",mall_id)
    local pack ={}
    local spreebuycount = cfg_global[1].spreebuycount    
    assert(spreebuycount,"spree config error . spreebuycount")
    
    local bIsSpreeMall = false
    if not ma_data.act_data.spree then
        pack.result  =1 --数据异常
    elseif ma_data.act_data.spree.buyc >= spreebuycount then
        pack.result  =2 -- 购买次数超限
    else
        for _,mall in pairs(SPREE_MALL) do
            if mall == mall_id then                
                pack.result = 0
                ma_data.act_data.spree.buyc = ma_data.act_data.spree.buyc + 1
                pack.GiftCom = ma_data.act_data.spree    
                skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{ spree = ma_data.act_data.spree})                
                bIsSpreeMall = true

                local goods = {id = COIN_ID,num = pack.GiftCom.value }
                ma_data.add_gold(pack.GiftCom.value,GOODS_WAY_SPREE,"天赐豪礼金币",nil,true)
                ma_data.send_push("buy_suc", {
                    goods_list = {goods},
                    msgbox = 1
                })

                break
            end
        end
        pack.result  = 3 --商品不存在      
    end
    if bIsSpreeMall then
        --S2c
        ma_data.send_push("updata_giftcom",  pack )
    end
end

------------------------------------
--首充礼包
local function init_FirstCharge()  
    print("====debug qc==== 初始 首充礼包 ")
    return
    {
        type = 0,
        dayc = 0, -- 初始后肯定随机 +1
        hadGotState = {0,0,0},
        time = os.time()
    }
end


function M.get_firstcharge_data()
    -- print("====debug qc==== get M.首充礼包 ")
    if ma_data.act_data.first_charge == nil then
        --刷新 初始化数据
        ma_data.act_data.first_charge = init_FirstCharge()        
        skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{ first_charge = ma_data.act_data.first_charge})
    end

    --刷新连续登录统计
    if ma_data.act_data.first_charge.type == 1 and 
        ma_data.act_data.first_charge.dayc < 3 and 
        not check_same_day(ma_data.act_data.first_charge.time) then

        ma_data.act_data.first_charge.time = os.time()       
        ma_data.act_data.first_charge.dayc = ma_data.act_data.first_charge.dayc + 1
        skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{ first_charge = ma_data.act_data.first_charge})        
    end
    -- print("====debug qc==== get 首充礼包 ")
    -- table.print(ma_data.act_data.first_charge)
    return {info = ma_data.act_data.first_charge}
end

--购买了首充礼包到账有效 /一次性
--mallid = 500207
function M.First_charge_Check(mallId)
    local tmp_data = M.get_firstcharge_data().info
    local cfg = cfg_gift[11]
    assert(cfg,"firstcharge_day_award cfg error! ")
    if cfg.mallid == mallId and tmp_data.type==0 then
        tmp_data.type =1 
        tmp_data.time = os.time()
        tmp_data.dayc = 1

        ma_data.send_push("get_firstcharge_state", {
            result = 0,
            info = tmp_data
        })
        skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{ first_charge = tmp_data})        
    end
end

--首充礼包get
function request:get_firstcharge_data()
    -- print("====debug qc==== get 首充礼包 ")
   return M.get_firstcharge_data()
end

function request:get_firstcharge_day_award()
    --拉取 or 刷新
    local tmp_data = M.get_firstcharge_data().info

    local day = self.day
    local result = 1
    assert(day,"firstcharge_day_award day error!")
    local cfg = cfg_gift[11]
    assert(cfg,"firstcharge_day_award cfg error! ")

    --领取条件判断
    if tmp_data.type ==1 and tmp_data.dayc >= day and tmp_data.hadGotState[day] and tmp_data.hadGotState[day] == 0 then
        --确定奖励
        local award
        if day == 1 then
            award = cfg.award1
        elseif day == 2 then
            award = cfg.award2
        elseif day == 3 then
            award = cfg.award3
        else
            skynet.loge("firstcharge_day_award cfg.award[day] error! "..day)   
            return {result = result, info = tmp_data}  
        end
        assert(cfg,"firstcharge_day_award cfg error! "..day)

        ma_data.add_goods_list(award,GOODS_WAY_FIRST_CHARGE_GIFT,"首充礼包奖励")
        result = 0 
        tmp_data.hadGotState[day] = 1
        skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{ first_charge = tmp_data})                

        ma_data.send_push("buy_suc", {
            goods_list = award,
            msgbox = 1
        })
    end

    return {result = result, info = tmp_data}
end

--------------------------------
---翻拍豪礼
local function init_PickCardGift()  
    print("====debug qc==== 初始 翻拍豪礼 ")
    return
    {
        num = 10,
        reward_id = 1,
        cards = {},
        goods = {},
        time = os.time()
    }
end


function request:get_cardsgift_data()
     -- print("====debug qc==== get M.首充礼包 ")
     if ma_data.act_data.pick_card_gift == nil or not check_same_day(ma_data.act_data.pick_card_gift.time) then
        --刷新 初始化数据
        ma_data.act_data.pick_card_gift = init_PickCardGift()        
        skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{ pick_card_gift = ma_data.act_data.pick_card_gift})
    end

    return {pick_card = ma_data.act_data.pick_card_gift}
end


--天赐豪礼结果装饰工具
--返回 function[1-6]
local function deal_cards_gift(reward_id)
    local cards_pos = 72 -- 73-108 万牌  72+N
    local card_type1,card_type2,card_type3,card_type4,card_type5,card_type6
    --杠牌
    function card_type1()
        local rand = math.random(1,9)   
        local card = (rand-1)*4 + 1
        return {cards_pos + card ,cards_pos + card + 1 ,cards_pos + card + 2,cards_pos + card + 3}     
    end
    --顺子
    function card_type2()
        local rand = math.random(1,6)   
        local card = (rand-1)*4 + 1
        return {cards_pos + card ,cards_pos + card + 4 ,cards_pos + card + 8,cards_pos + card + 12}     
    end
    --两队
    function card_type3()
        local cards_pool = {1,2,3,4,5,6,7,8,9}
        local rand1 = math.random(1,9)   
        local card1 = (cards_pool[rand1]-1)*4 + 1
        table.remove(cards_pool,rand1)

        local rand2 = math.random(1,8)   
        local card2 = (cards_pool[rand2]-1)*4 + 1
        return {cards_pos + card1 ,cards_pos + card1 + 1 ,cards_pos + card2 ,cards_pos + card2 + 1}     
    end
    --单张
    function card_type4()
        local cards_pool = {1,2,3,4,5,6,7,8,9}
        local rand1 = math.random(1,9)   
        local card1 = (cards_pool[rand1]-1)*4 + 1
        table.remove(cards_pool,rand1)

        local rand2 = math.random(1,8)   
        local card2 = (cards_pool[rand2]-1)*4 + 1
        table.remove(cards_pool,rand2)

        local rand3 = math.random(1,7)   
        local card3 = (cards_pool[rand3]-1)*4 + 1
        table.remove(cards_pool,rand3)

        local rand4 = math.random(1,6)   
        local card4 = (cards_pool[rand4]-1)*4 + 1

        return {cards_pos + card1 ,cards_pos + card2 ,cards_pos + card3,cards_pos + card4}     
    end    

    --刻子
    function card_type5()
        local cards_pool = {1,2,3,4,5,6,7,8,9}
        local rand1 = math.random(1,9)   
        local card1 = (cards_pool[rand1]-1)*4 + 1
        table.remove(cards_pool,rand1)

        local rand2 = math.random(1,8)   
        local card2 = (cards_pool[rand2]-1)*4 + 1
        return {cards_pos + card1 ,cards_pos + card1 + 1 ,cards_pos + card1 + 2,cards_pos + card2}     
    end

    --一对
    function card_type6()
        local cards_pool = {1,2,3,4,5,6,7,8,9}
        local rand1 = math.random(1,9)   
        local card1 = (cards_pool[rand1]-1)*4 + 1
        table.remove(cards_pool,rand1)

        local rand2 = math.random(1,8)   
        local card2 = (cards_pool[rand2]-1)*4 + 1
        table.remove(cards_pool,rand2)

        local rand3 = math.random(1,7)   
        local card3 = (cards_pool[rand3]-1)*4 + 1

        return {cards_pos + card1 ,cards_pos + card1 + 1 ,cards_pos + card2,cards_pos + card3}     
    end

    
    local fun_array = {card_type1,card_type2,card_type3,card_type4,card_type5,card_type6}
    print("====debug qc==== 翻牌好礼 fun ",fun_array[reward_id])
    return fun_array[reward_id]()
end


--看视频 领取翻牌豪礼
--返回更新状态
function M.reward_cardsgift()
    if ma_data.act_data.pick_card_gift == nil or not check_same_day(ma_data.act_data.pick_card_gift.time) then
        --刷新 初始化数据
        ma_data.act_data.pick_card_gift = init_PickCardGift()        
    end

    if ma_data.act_data.pick_card_gift.num<1 then
        return nil
    end

    --随机结果
    local rand = math.random(1,10000)
    local reward_index = 0
    print("====debug qc==== 翻牌好礼 rand ",rand)
    for i,v in ipairs(PICK_CARD_CFG) do
        if rand > v.rate then
            --nothing
        else
            reward_index = i
            ma_data.act_data.pick_card_gift.reward_id = v.reward_id
            ma_data.act_data.pick_card_gift.goods = {v.content}           
            break
        end
        rand = rand - v.rate
    end

    --装饰结果    
    print("====debug qc==== 翻牌好礼 cards ",rand,reward_index)
    local cards =  deal_cards_gift(reward_index)
   
    table.print(cards)
    ma_data.act_data.pick_card_gift.cards = cards
    ma_data.act_data.pick_card_gift.num = ma_data.act_data.pick_card_gift.num-1

    --发放奖励内容
    ma_data.add_goods_list(ma_data.act_data.pick_card_gift.goods,GOODS_WAY_PICK_CARDS_GIFT,"翻牌好礼")
    -- ma_data.send_push("buy_suc", {
    --     goods_list = ma_data.act_data.pick_card_gift.goods,
    --     msgbox = 1
    -- })
    --更新数据库
    skynet.call(get_db_mgr(),"lua","update",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{ pick_card_gift = ma_data.act_data.pick_card_gift})

    return ma_data.act_data.pick_card_gift
end
-------------------------------------------------------------------------------
local function init()
    --print("active init ")
    ma_data.follow_conf(M, cfg_conf.COLL.ACTIVITY_CONF)
    init_int_award_module()
    ma_data.act_data = skynet.call(get_db_mgr(),"lua","find_one",COLL.ACTIVITY_DATA,{id=ma_data.my_id},{_id=false})

    if not ma_data.act_data then
        ma_data.act_data = {}
        ma_data.act_data.id = ma_data.my_id
        skynet.call(get_db_mgr(),"lua","insert",COLL.ACTIVITY_DATA,ma_data.act_data)
    end
    --table.print(ma_data.act_data)
    if not ma_data.db_info.bailout then
        ma_data.db_info.bailout = {t = os.time(),count=0}
    end
    M.initWealthGod()
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

ma_data.ma_hall_active = M
return M