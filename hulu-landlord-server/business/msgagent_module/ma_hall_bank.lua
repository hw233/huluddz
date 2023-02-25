--银行
local skynet = require "skynet"
local ma_data = require "ma_data"
local cfg_bank = require"cfg/cfg_bank"
local request = {}
local cmd = {}

local M = {}
function M.updatebankdbinfo()
    skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {bank = ma_data.db_info.bank})
end

--购买银行升级
-- modify by qc 2021.8.13 购买多个保险库的情况 优先生效最高级的 。低级保险库leveltime 转换到"-剩余时间"
function M.get_bank_update(mall_id)
    local timeIndex = 1
    local item_time = 0
    for i,info in ipairs(cfg_bank) do
        if info.shopid == mall_id then
            timeIndex = i
            item_time = info.time
            break
        end
    end
    if timeIndex == 1 then
        return
    end


    --判断当前level 是否跃迁其他level 低买高
    if ma_data.db_info.bank.level < timeIndex and ma_data.db_info.bank.level >1 then
        local old_level = ma_data.db_info.bank.level
        --旧的level中断计时 用 -剩余时间保存进度
        ma_data.db_info.bank.leveltime[old_level] = os.time() - ma_data.db_info.bank.leveltime[old_level]
        ma_data.db_info.bank.level = timeIndex  
    end
  
  
      -- 高买低
    if ma_data.db_info.bank.level > timeIndex and timeIndex>1 then       
        --积累 - 时间进度
        ma_data.db_info.bank.leveltime[timeIndex] =  ma_data.db_info.bank.leveltime[timeIndex] - item_time
    else
        --正常累加时间
        if ma_data.db_info.bank.leveltime[timeIndex] < os.time() then
            ma_data.db_info.bank.leveltime[timeIndex] = os.time()
        end    
        ma_data.db_info.bank.leveltime[timeIndex] = ma_data.db_info.bank.leveltime[timeIndex] + item_time
    end
   
  
    M.updatebankdbinfo()
    ma_data.insert_goods_rec(mall_id,ma_data.db_info.bank.leveltime[ma_data.db_info.bank.level],item_time,GOLD_BANK,'银行升级')
    ma_data.send_push('bank_update',{level=ma_data.db_info.bank.level,
                                    leveltime=ma_data.db_info.bank.leveltime})
end

--检测银行到期
function M.cheak_bank_time_down()
    local bankinfo = ma_data.db_info.bank
    if bankinfo.level <= 1 then
        --1级银行不到期
        return
    end
    local currtime = os.time()
    if bankinfo.leveltime[bankinfo.level] < currtime then
        --到期处理
        local lastLevel = bankinfo.level
        bankinfo.leveltime[bankinfo.level] = 0
        for i=(bankinfo.level-1),1,-1 do
            if bankinfo.leveltime[i] == -1 then
                bankinfo.level = i
                break
            elseif bankinfo.leveltime[i] < -1 then
                bankinfo.level = i
                --暂停计时的 保险亏恢复计时
                bankinfo.leveltime[i] = currtime - bankinfo.leveltime[i]
                break
            else
                bankinfo.leveltime[i] = 0
            end
        end
        --返还上限金币到玩家金币
        local bankconf = cfg_bank[bankinfo.level]
        local maxgold = math.floor(bankconf.goldmax*(1+bankinfo.addMax/100))
        if bankinfo.bankgold > maxgold then
            local addGold = bankinfo.bankgold - maxgold
            ma_data.add_bankgoldtwo(-addGold,GOLD_BANK,('银行过期退还'..lastLevel..'--'..bankinfo.level..'金额'..addGold))
            ma_data.add_gold(addGold,GOLD_BANK,('银行过期退还'..lastLevel..'--'..bankinfo.level..'金额'..addGold))
        end
        M.updatebankdbinfo()
        --推送消息
        ma_data.send_push('bank_time_down',{level=ma_data.db_info.bank.level,
                                    leveltime=ma_data.db_info.bank.leveltime,
                                    is_down=1,
                                    bankgold=bankinfo.bankgold})
    elseif bankinfo.leveltime[bankinfo.level] <= os.time()+300 then
        --推送即将到期
        ma_data.send_push('bank_time_down',{level=ma_data.db_info.bank.level,
                                    leveltime=ma_data.db_info.bank.leveltime,
                                    is_down=0})
    end
end

--获取银行数据
function request:get_bank_info()
    M.cheak_bank_time_down()
    print('================获取银行数据===============')
    local bankinfo = ma_data.db_info.bank
    --modify by qc 2021.7.2 vip减免费用 未完成 待定
    local vip_ability = ma_data.get_vip_ability("保险库减免")  or 0 
    return {bankgold=bankinfo.bankgold,level=bankinfo.level,
            addMax=bankinfo.addMax,bankcoin=bankinfo.bankcoin,
            leveltime=bankinfo.leveltime,vip_derate = vip_ability}
end

--存钱
function request:save_bankgold()
    -- 银行活动购买限制
    -- if ma_data.db_info.channel ~= 'hzmjlx_mi'   
    --     or ma_data.db_info.firstLoginDt < 0 then
    --     return 8
    -- end
    local bankinfo = ma_data.db_info.bank
    local bankconf = cfg_bank[bankinfo.level]
    if ma_data.db_info.gold < bankconf.onece then
        return {result=1}
    end
    if (bankinfo.bankgold + bankconf.onece) > math.floor(bankconf.goldmax*(1+bankinfo.addMax/100)) then
        return {result=2}
    end
    --扣除手续费
    tmp_weight = bankconf.weight
    --modify by qc 2021.7.2 vip减免费用 未完成 待定
    local vip_ability = ma_data.get_vip_ability("保险库减免 ")  or 0 
    tmp_weight = tmp_weight - vip_ability
    local usegold = math.floor(bankconf.onece*(tmp_weight/10000))
    
    ma_data.add_bankgoldtwo((bankconf.onece-usegold),GOLD_BANK,('银行存钱'..bankinfo.level..'金额'..bankconf.onece))
    ma_data.add_gold(-bankconf.onece,GOLD_BANK,('银行存钱'..bankinfo.level..'金额'..bankconf.onece))
    --增加银行币
    local begin_num = bankinfo.bankcoin
    bankinfo.bankcoin = bankinfo.bankcoin + math.ceil(usegold*0.1)
    M.updatebankdbinfo()
    --写入背包记录 BNAK_COIN_ID
    ma_data.insert_goods_rec(BNAK_COIN_ID,begin_num,(bankinfo.bankcoin-begin_num),GOLD_BANK,'银行存钱')
    return {result=0,bankgold=bankinfo.bankgold,curgold=(bankconf.onece-usegold),bankcoin=bankinfo.bankcoin}
end

--取钱
function request:draw_bankgold()
    local bankinfo = ma_data.db_info.bank
--print('==================取钱=============',bankinfo.bankgold,self.getgold)
    if self.getgold <= 0 then
        return {result=1}
    end
    if bankinfo.bankgold < self.getgold then
        return {result=2}
    end
    ma_data.add_bankgoldtwo(-self.getgold,GOLD_BANK,('银行取钱'..bankinfo.level..'金额'..self.getgold))
    ma_data.add_gold(self.getgold,GOLD_BANK,('银行取钱'..bankinfo.level..'金额'..self.getgold))
    local goods_list = {{id=COIN_ID,num=self.getgold}}
    ma_data.send_push('buy_suc', {goods_list = goods_list,msgbox = 1})
    return {result=0,bankgold=bankinfo.bankgold}
end

--银行等级提升
function request:bank_limit_upgrade()
    local bankinfo = ma_data.db_info.bank
    local needcoin = 0
    if bankinfo.addMax <= 100 then
        needcoin = math.ceil(10*1.1^bankinfo.addMax)
    else
        needcoin = 150000
    end
    if bankinfo.bankcoin < needcoin then
        return {result=1,addMax=bankinfo.addMax}
    end

    bankinfo.addMax = bankinfo.addMax + 1
    begin_num = ma_data.db_info.bank.bankcoin
    ma_data.db_info.bank.bankcoin = ma_data.db_info.bank.bankcoin - needcoin
    M.updatebankdbinfo()
    --写入背包记录 BNAK_COIN_ID
    ma_data.insert_goods_rec(BNAK_COIN_ID,begin_num,-needcoin,GOLD_BANK,'银行上限升级')
    return {result=0,addMax=bankinfo.addMax,bankcoin=bankinfo.bankcoin}
end

--初始化银行
function M.initBankData()
    if not ma_data.db_info.bank then
        ma_data.db_info.bank            = {}
        ma_data.db_info.bank.bankgold   = 0 --银行存款
        ma_data.db_info.bank.level      = 1 --银行等级，默认1
        ma_data.db_info.bank.addMax     = 0 --封顶加成等级
        ma_data.db_info.bank.bankcoin   = 0 --银行币
        ma_data.db_info.bank.leveltime  = {} --银行等级时限
        for i,info in ipairs(cfg_bank) do
            if info.time == -1 then 
                ma_data.db_info.bank.leveltime[i] = -1
            else
                ma_data.db_info.bank.leveltime[i] = 0
            end
        end
    end
    M.cheak_bank_time_down()
end

function M.init(REQUEST, CMD)
    if request then
        table.connect(REQUEST, request)
    end
    if cmd then
        table.connect(CMD, cmd)
    end
    M.initBankData()
end
ma_data.ma_hall_bank = M
return M