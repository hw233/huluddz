local skynet = require "skynet"
local ma_data = require "ma_data"
local cfg_popularize = require "cfg.cfg_popularize"
local cfg_rank_grade = require "cfg.cfg_rank_grade"
local M = {}
local request = {}
local cmd = {}

--coinType 1金2钻
function M.updateOtherAward(coinType,num)
    if ma_data.mySpread.bindId == '0' then
        return false
    end

    if coinType == 1 then
        if ma_data.mySpread.otherGold > 1000000 then
            return false
        end
        ma_data.mySpread.otherGold = ma_data.mySpread.otherGold + num
    elseif coinType == 2 then
        if ma_data.mySpread.otherDiamond > 1000000 then
            return false
        end
        ma_data.mySpread.otherDiamond = ma_data.mySpread.otherDiamond + num
    end
    skynet.call(get_db_mgr(), "lua", "update", "spread_data", {pid = ma_data.my_id}, {otherGold = ma_data.mySpread.otherGold,
                                                                                    otherDiamond = ma_data.mySpread.otherDiamond})
    return true
end

function M.check_day()
    if not check_same_day(ma_data.mySpread.t) then
        ma_data.mySpread.t = os.time()
        skynet.call(get_db_mgr(), "lua", "update", "spread_data", {pid = ma_data.my_id}, {
            t = ma_data.mySpread.t
        })
        M.addLoginDay()
    end
end

--登陆天数增加
function M.addLoginDay()
    if M.updateOtherAward(cfg_popularize[2].type,cfg_popularize[2].award) then
        ma_data.mySpread.loginNum = ma_data.mySpread.loginNum + 1
        skynet.call(get_db_mgr(), "lua", "update", "spread_data", {pid = ma_data.my_id}, {loginNum = ma_data.mySpread.loginNum})
    end
    
end

--游戏局数增加
function M.addGameNum()
    if M.updateOtherAward(cfg_popularize[3].type,cfg_popularize[3].award) then
        ma_data.mySpread.gameNum = ma_data.mySpread.gameNum + 1
        skynet.call(get_db_mgr(), "lua", "update", "spread_data", {pid = ma_data.my_id}, {gameNum = ma_data.mySpread.gameNum})
    end
end

--支付次数增加
function M.addPayNum()
    if M.updateOtherAward(cfg_popularize[1].type,cfg_popularize[1].award) then
        ma_data.mySpread.payNum = ma_data.mySpread.payNum + 1
        skynet.call(get_db_mgr(), "lua", "update", "spread_data", {pid = ma_data.my_id}, {payNum = ma_data.mySpread.payNum})
    end
end

--段位增加
function M.addGradingLv(level_lv)
    if level_lv <= ma_data.mySpread.gradingLv then
        return
    end
    local gold_num = (level_lv- ma_data.mySpread.gradingLv) * cfg_popularize[4].award
    if M.updateOtherAward(cfg_popularize[4].type,gold_num) then
        ma_data.mySpread.gradingLv = level_lv
        skynet.call(get_db_mgr(), "lua", "update", "spread_data", {pid = ma_data.my_id}, {gradingLv = ma_data.mySpread.gradingLv})
    end
end

--宠物等阶增加
function M.addPetLv(level_lv)
    if level_lv == ma_data.mySpread.petLv then
        return
    end
    local gold_num = (level_lv - ma_data.mySpread.petLv) * cfg_popularize[5].award
    if M.updateOtherAward(cfg_popularize[5].type,gold_num) then
        ma_data.mySpread.petLv = level_lv
        skynet.call(get_db_mgr(), "lua", "update", "spread_data", {pid = ma_data.my_id}, {petLv = ma_data.mySpread.petLv})
    end
end

--绑定功能
function request:binding_player()
    if os.time() - ma_data.db_info.firstLoginDt > 86400 then
        return {result = 1}
    end
    if ma_data.mySpread.bindId ~= '0' then
        return {result = 2}
    end
    if ma_data.my_id == self.p_id then
        return {result = 6}
    end
    local user = skynet.call(get_db_mgr(), "lua", "find_one", "user", {id = self.p_id})
    if not user then
        return {result = 3}
    end

    if ma_data.db_info.firstLoginDt < user.firstLoginDt then
        return {result = 5}
    end
    local result = skynet.call('friend_mgr',"lua","updateOtherbind",self.p_id,ma_data.my_id)
    if result == 0 then
        ma_data.mySpread.bindId = self.p_id
        ma_data.mySpread.bindTime = os.time()
        skynet.call(get_db_mgr(), "lua", "update", "spread_data", {pid = ma_data.my_id}, {bindId = self.p_id,
                                                                bindTime=ma_data.mySpread.bindTime})
        M.addPetLv(ma_data.pet_data.level)
        local curSeg = ma_data.ma_hall_frame.get_seg_by_prestige(ma_data.db_info.hall_frame.seg_prestige)
        M.addGradingLv(cfg_rank_grade[curSeg].level)
        
        local otherAgent = skynet.call('agent_mgr',"lua","find_player",ma_data.mySpread.bindId)
        if otherAgent then
            pcall(skynet.call,otherAgent,'lua','update_blind')
        end
        M.addLoginDay()
        return {result = result,p_id = self.p_id}
    else
        return {result = result}
    end
end

--获取自己推广员信息
function request:getMySpreadInfo()
    local myPlayers = skynet.call(get_db_mgr(), "lua", "find_all", "spread_data", {bindId = ma_data.my_id})
    local lastGetGold = 0
    local lastGetDiamond = 0
    for i,info in ipairs(myPlayers) do
        lastGetGold = lastGetGold + info.otherGold
        lastGetDiamond = lastGetDiamond + info.otherDiamond
    end
    ma_data.mySpread.lastGetGold = lastGetGold
    ma_data.mySpread.lastGetDiamond = lastGetDiamond
    --table.print(ma_data.mySpread)
    return {myInfo = ma_data.mySpread,otherInfos = myPlayers}
end

--取钱
function request:getMySpreadAward()
    local myPlayers = skynet.call(get_db_mgr(), "lua", "find_all", "spread_data", {bindId = ma_data.my_id})
    local lastGetGold = 0
    local lastGetDiamond = 0
    for i,info in ipairs(myPlayers) do
        lastGetGold = lastGetGold + info.otherGold
        lastGetDiamond = lastGetDiamond + info.otherDiamond
    end
    --print('====================取钱======================',lastGetGold,lastGetDiamond,self.coinType)
    if self.coinType == 1 then
        if lastGetGold <= 0 then
            return {result = 1}
        end
        for i,info in ipairs(myPlayers) do
            skynet.call(get_db_mgr(), "lua", "update", "spread_data", {pid = info.pid}, {otherGold = 0})
            local otherAgent = skynet.call('agent_mgr',"lua","find_player",info.pid)
            if otherAgent then
                pcall(skynet.call,otherAgent,'lua','update_blind')
            end
        end
        ma_data.add_gold(lastGetGold, SPREAD,'推广员取金币',nil,true)
        return {result = 0,coinType = self.coinType}
    elseif self.coinType == 2 then
        if lastGetDiamond <= 0 then
            return {result = 1}
        end
        for i,info in ipairs(myPlayers) do
            skynet.call(get_db_mgr(), "lua", "update", "spread_data", {pid = info.pid}, {otherDiamond = 0})
            local otherAgent = skynet.call('agent_mgr',"lua","find_player",info.pid)
            if otherAgent then
                pcall(skynet.call,otherAgent,'lua','update_blind')
            end
        end
        ma_data.add_diamond(lastGetDiamond,SPREAD,'推广员取钻石',nil,true)
        return {result = 0,coinType = self.coinType}
    end
    return {result = 3}
end

local function init()
    --print('================获取推广员ID初始化====================')
    local mySpread = skynet.call(get_db_mgr(), "lua", "find_one", "spread_data", {pid = ma_data.my_id})
    if not mySpread then
        mySpread = {
            pid             = ma_data.my_id,
            pictureframe    = ma_data.get_picture_frame(),
            headimgurl      = ma_data.db_info.headimgurl,
            nickname        = ma_data.db_info.nickname,
            last_time       = 0,
            getGold         = 0,
            getDiamond      = 0,
            bindId          = '0',
            pidTbl          = {},
            payNum          = 0,
            loginNum        = 0,
            gameNum         = 0,
            gradingLv       = 1,
            petLv           = 0,
            t               = os.time(),
            otherGold       = 0,
            otherDiamond    = 0
        }
        skynet.call(get_db_mgr(), "lua", "insert", "spread_data", mySpread)
        ma_data.mySpread = mySpread
    else
        ma_data.mySpread = mySpread
        M.check_day()
    end
end

function M.player_blind()
    init()
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
ma_data.ma_spread = M
return M