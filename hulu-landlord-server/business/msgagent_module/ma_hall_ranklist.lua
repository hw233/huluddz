local skynet = require "skynet"
local ma_data = require "ma_data"
local COLL = require "config/collections"
local place_config = require "cfg/place_config"
local cfg_item = require "cfg.cfg_items"
require "define"
require "config/GameConst"
local request = {}
local cmd = {}
local M = {}

--获取排行榜信息
-- self.name    排行榜名 (1.雀神榜 2.千王榜3.身价 4.家园 5.宠物 6.看广告)
-- self.start   起始位置
-- self.num     获取数量
function request:sync_ranklist_info()
    --table.print(self)
    local rank,value = skynet.call("ranklist_mgr","lua","get_rank",self.name,ma_data.my_id)
    return {list = skynet.call("ranklist_mgr","lua","get_rank_list",self.name,self.start,self.num) or {}, own_rank = rank,own_value=value,
                name=self.name}
end

--self.list:好友id列表
--self.name:排行榜名称
function request:get_fri_ranklist_info()
    return {list = skynet.call("ranklist_mgr","lua","get_fri_rank_info",self.list,self.name) or {},name = self.name}
end

local aop = require "aop"
local mult_king_rank_module_state = aop.helper:make_state("mult_king_rank")
local lucky_king_rank_module_state = aop.helper:make_state("lucky_king_rank")
local mult_king_rank_interface = aop.helper:make_interface_tbl(mult_king_rank_module_state)
local lucky_king_rank_interface = aop.helper:make_interface_tbl(lucky_king_rank_module_state)

local function get_rank_two_info(self)
    local rank,value1,value2 = skynet.call("rank_two_mgr","lua","get_rank",self.name,ma_data.my_id)
    local list = skynet.call("rank_two_mgr","lua","get_rank_list",self.name,self.start,self.num) or {}
    return {reulst = 0, list = list, own_rank = rank,
    own_value1=value1,own_value2=value2,name=self.name}
end

--更新番王榜
function mult_king_rank_interface.updateMultipleRank(multiple,pack,gameType)
    M.check_reset()
    local gameId = gameType // 100
    local placeId = gameType % 100
    if multiple > place_config[gameId][placeId].cap and place_config[gameId][placeId].cap~= 0 then
        multiple = place_config[gameId][placeId].cap
    end
    print("updateMultipleRank",multiple)
    if multiple < 10000 or place_config[gameId][placeId].stype == 2 or place_config[gameId][placeId].stype == 3 then
        return
    end

    local automsg = {[1]=ma_data.db_info.nickname,[2]=math.floor(multiple)}
    skynet.send("services_mgr", "lua", "fightNotice",3,1,automsg)
    --print('==================更新番王榜===========',ma_data.db_info.multipleKing.multipleKing,multiple,pack)
    if ma_data.db_info.multipleKing.multipleKing <= multiple then
        ma_data.db_info.multipleKing.multipleKing = multiple
        ma_data.db_info.multipleKing.cards = pack
        M.flush({multipleKing = ma_data.db_info.multipleKing})
        --更新排行榜数据
        skynet.call("rank_two_mgr","lua","updateMultipleRank",ma_data.my_id,ma_data.db_info.multipleKing,
            ma_data.db_info.nickname,ma_data.db_info.headimgurl,gameType,ma_data.get_picture_frame(ma_data.db_info.backpack))
        --番王榜第一名 走马灯
        skynet.send("services_mgr", "lua", "activeNotice", 2, 1, automsg)
    else 
        if multiple >= 500000 then 
            skynet.send("services_mgr", "lua", "activeNotice", 3, 1, automsg)
        end 
    end
end

--更新十八罗汉
function lucky_king_rank_interface.updateEighteenMonk(usetime,pack)
    M.check_reset()
    if ma_data.db_info.eighteenMonk.useTime1 > usetime or ma_data.db_info.eighteenMonk.useTime1 == 0 then
        ma_data.db_info.eighteenMonk.useTime1 = usetime
        ma_data.db_info.eighteenMonk.cards1 = pack
        M.flush({eighteenMonk = ma_data.db_info.eighteenMonk})
        --更新排行榜数据
        skynet.call("rank_two_mgr","lua","updateEighteenMonk",ma_data.my_id,ma_data.db_info.eighteenMonk,
            ma_data.db_info.nickname,ma_data.db_info.headimgurl,ma_data.get_picture_frame(ma_data.db_info.backpack))
    end
    local automsg = {['nickname']=ma_data.db_info.nickname,['cardsType']='十八罗汉'}
    skynet.send("services_mgr", "lua", "fightNotice",4,1,automsg)
end

--更新四暗刻
function lucky_king_rank_interface.updateFourThree(usetime,pack)
    M.check_reset()
    table.print("usetime =>", usetime)
    table.print("pack =>", pack)
    table.print("db_info.fourThree =>", ma_data.db_info.fourThree)
    if ma_data.db_info.fourThree.useTime2 > usetime or ma_data.db_info.fourThree.useTime2 == 0 then
        ma_data.db_info.fourThree.useTime2 = usetime
        ma_data.db_info.fourThree.cards2 = pack
        M.flush({fourThree = ma_data.db_info.fourThree})
        --更新排行榜数据
        skynet.call("rank_two_mgr","lua","updateFourThree",ma_data.my_id,ma_data.db_info.fourThree,
            ma_data.db_info.nickname,ma_data.db_info.headimgurl,ma_data.get_picture_frame(ma_data.db_info.backpack))
    end
    local automsg = {['nickname']=ma_data.db_info.nickname,['cardsType']='四暗刻'}
    skynet.send("services_mgr", "lua", "fightNotice",4,1,automsg)
end

--更新九莲宝灯
function lucky_king_rank_interface.updateNineLamp(usetime,pack)
    M.check_reset()
    if ma_data.db_info.nineLamp.useTime3 > usetime or ma_data.db_info.nineLamp.useTime3 == 0 then
        ma_data.db_info.nineLamp.useTime3 = usetime
        ma_data.db_info.nineLamp.cards3 = pack
        M.flush({nineLamp = ma_data.db_info.nineLamp})
        --更新排行榜数据
        skynet.call("rank_two_mgr","lua","updateNineLamp",ma_data.my_id,ma_data.db_info.nineLamp,
            ma_data.db_info.nickname,ma_data.db_info.headimgurl,ma_data.get_picture_frame(ma_data.db_info.backpack))
    end
    local automsg = {['nickname']=ma_data.db_info.nickname,['cardsType']='九莲宝灯'}
    skynet.send("services_mgr", "lua", "fightNotice",4,1,automsg)
end

function lucky_king_rank_interface.updateLuckRank(usetime,pack,cardTypes)
    for _,cardType in ipairs(cardTypes) do
        if cardType == CARD_TYPE.Jiulianbaodeng then
            M.updateNineLamp(usetime,pack)
        elseif cardType == CARD_TYPE.Shibaluohan then
            M.updateEighteenMonk(usetime,pack)
        elseif cardType == CARD_TYPE.Sianke then
            M.updateFourThree(usetime,pack)
        end
    end
end

table.connect(M, mult_king_rank_interface)
table.connect(M, lucky_king_rank_interface)
function mult_king_rank_interface:get_rankTwo_info(req)
    return get_rank_two_info(req)
end

function lucky_king_rank_interface:get_rankTwo_info(req)
    return get_rank_two_info(req)
end

--获取番王榜/鸿运榜
function request:get_rankTwo_info()
    if self.name == "multipleKing" then
        return mult_king_rank_interface:get_rankTwo_info(self)
    elseif self.name == "eighteenMonk" or self.name == "fourThree"
        or self.name == "nineLamp" then
        return lucky_king_rank_interface:get_rankTwo_info(self)
    else
        return get_rank_two_info(self)
    end
end

local cfg_conf = require "cfg_conf"
local function init_rank_module()
    local subtype = 2004
    local tbl_match = {subtype = subtype}
    local conf = skynet.call(cfg_conf.DB_MGR, "lua", "find_one", cfg_conf.COLL.ACTIVITY_CONF, tbl_match)
    print("mult king module conf =>", table.tostr(conf))
    mult_king_rank_module_state.init(conf)

    subtype = 2005
    tbl_match = {subtype = subtype}
    conf = skynet.call(cfg_conf.DB_MGR, "lua", "find_one", cfg_conf.COLL.ACTIVITY_CONF, tbl_match)
    print("lucky king module conf =>", table.tostr(conf))
    lucky_king_rank_module_state.init(conf)
end

function M.on_conf_update()
    init_rank_module()
end

function request:sync_rankThreeTwo_info()
end

--self.list:好友id列表
--self.name:排行榜名称
function request:get_fri_rankThreeTwo_info()
end

function M.flush(tbl)
    skynet.call(get_db_mgr(), "lua", "update", COLL.USER, {id = ma_data.my_id},tbl)
end

--更新连胜榜
function M.updateLianWinRank(count)
    M.check_reset()
    if count < 3 then
        return
    end
    if ma_data.db_info.lianWinRank.count < count or ma_data.db_info.lianWinRank.count == 0 then
        ma_data.db_info.lianWinRank.count = count
        ma_data.db_info.lianWinRank.t = os.time()
        M.flush({lianWinRank = ma_data.db_info.lianWinRank})
        --更新排行榜数据
        skynet.call("rank_two_mgr","lua","updateLianWinRank",ma_data.my_id,count,
            ma_data.db_info.nickname,ma_data.db_info.headimgurl,ma_data.get_picture_frame(ma_data.db_info.backpack))
    end
end

--初始化番王榜信息
function M.initMultipleRank()
    if not ma_data.db_info.multipleKing then
        ma_data.db_info.multipleKing = {}
        ma_data.db_info.multipleKing.multipleKing = 0
        ma_data.db_info.multipleKing.cards = {}
        ma_data.db_info.multipleKing.t = os.time()
    end
end

--初始化鸿运榜
function M.initLuckRank()
    if not ma_data.db_info.eighteenMonk then
        ma_data.db_info.eighteenMonk = {}
        ma_data.db_info.eighteenMonk.useTime1 = 0
        ma_data.db_info.eighteenMonk.cards1 = {}
        ma_data.db_info.eighteenMonk.t = os.time()
    end

    if not ma_data.db_info.fourThree then
        ma_data.db_info.fourThree = {}
        ma_data.db_info.fourThree.useTime2 = 0
        ma_data.db_info.fourThree.cards2 = {}
        ma_data.db_info.fourThree.t = os.time()
    end

    if not ma_data.db_info.nineLamp then
        ma_data.db_info.nineLamp = {}
        ma_data.db_info.nineLamp.useTime3 = 0
        ma_data.db_info.nineLamp.cards3 = {}
        ma_data.db_info.nineLamp.t = os.time()
    end
end

function M.initLianWinRank()
    if not ma_data.db_info.lianWinRank then
        ma_data.db_info.lianWinRank = {}
        ma_data.db_info.lianWinRank.count = 0
        ma_data.db_info.lianWinRank.t = os.time()
    end
end

--重置数据
function M.refreshMultipleKingRankValue()
    ma_data.db_info.multipleKing = {}
    ma_data.db_info.multipleKing.multipleKing = 0
    ma_data.db_info.multipleKing.cards = {}
    ma_data.db_info.multipleKing.t = os.time()
    M.flush({multipleKing = ma_data.db_info.multipleKing})
end

function M.refreshEighteenMonkRankValue()
    ma_data.db_info.eighteenMonk = {}
    ma_data.db_info.eighteenMonk.useTime1 = 0
    ma_data.db_info.eighteenMonk.cards1 = {}
    ma_data.db_info.eighteenMonk.t = os.time()
    M.flush({eighteenMonk = ma_data.db_info.eighteenMonk})
end

function M.refreshFourThreeRankValue()
    ma_data.db_info.fourThree = {}
    ma_data.db_info.fourThree.useTime2 = 0
    ma_data.db_info.fourThree.cards2 = {}
    ma_data.db_info.fourThree.t = os.time()
    M.flush({fourThree = ma_data.db_info.fourThree})
end

function M.refreshNineLampRankValue()
    ma_data.db_info.nineLamp = {}
    ma_data.db_info.nineLamp.useTime3 = 0
    ma_data.db_info.nineLamp.cards3 = {}
    ma_data.db_info.nineLamp.t = os.time()
    M.flush({nineLamp = ma_data.db_info.nineLamp})
end

function M.refreshLianWinRankValue()
    ma_data.db_info.lianWinRank = {}
    ma_data.db_info.lianWinRank.count = 0
    ma_data.db_info.lianWinRank.t = os.time()
    M.flush({lianWinRank = ma_data.db_info.lianWinRank})
end

function M.get_serial_win_cfg(cfgs, rank)
    for _, cfg in ipairs(cfgs) do
        if rank <= cfg.ranking[2] then
            return cfg
        end
    end
end

--重置检测并发放奖励
function M.check_reset()
    --番王榜奖励
    if not check_same_day(ma_data.db_info.multipleKing.t) then
        if ma_data.db_info.multipleKing.erank and ma_data.db_info.multipleKing.erank > 0 then
            --发送十八罗汉奖励
            local cfg_award = cfg_multipleKing_award[ma_data.db_info.multipleKing.erank]
            local award= cfg_award.award
            local mail =  {
                title = "番王榜奖励",
                content = [[恭喜您！在番王榜获得<font color="#ff0000">]]
                        .. ma_data.db_info.multipleKing.erank ..
                        [[</font>名，获得如下奖励请及时领取。]],
                attachment = award,
                mail_type = MAIL_TYPE_OTHER,
                mail_stype = MAIL_STYPE_AWARD,
                -- friend_name = ma_data.db_info.nickname,
                -- friend_head = ma_data.db_info.headimgurl
            }
            skynet.call("mail_mgr", "lua", "send_mail", ma_data.my_id, mail)
            ma_data.db_info.multipleKing.erank = 0
            skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=ma_data.my_id},{["multipleKing.erank"] = ma_data.db_info.multipleKing.erank})
        end
        M.refreshMultipleKingRankValue()
    end
    if not check_same_day(ma_data.db_info.eighteenMonk.t) then
        if ma_data.db_info.eighteenMonk.erank and ma_data.db_info.eighteenMonk.erank > 0 then
            --发送十八罗汉奖励
            local cfg_idx = 20 + ma_data.db_info.eighteenMonk.erank
            local cfg_award = cfg_goodLuck_award[cfg_idx]
            if cfg_award then
                local end_award = cfg_award.award
                 --随机技能书
                local mail =  {
                    title = "鸿运榜十八罗汉奖励",
                    content = [[恭喜您！在鸿运榜十八罗汉获得<font color="#ff0000">]]
                                .. ma_data.db_info.eighteenMonk.erank ..
                                [[</font>名，获得如下奖励请及时领取。]],
                    attachment = end_award,
                    mail_type = MAIL_TYPE_OTHER,
                    mail_stype = MAIL_STYPE_AWARD,
                }
                skynet.call("mail_mgr", "lua", "send_mail", ma_data.my_id, mail)
                ma_data.db_info.eighteenMonk.erank = 0
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=ma_data.my_id},{["eighteenMonk.erank"] = ma_data.db_info.eighteenMonk.erank})
            else
                skynet.loge("good_luck rank idx error! ma_data.db_info.eighteenMonk.erank ",ma_data.db_info.eighteenMonk.erank)       
            end
        end
        M.refreshEighteenMonkRankValue()
    end

    if not check_same_day(ma_data.db_info.fourThree.t) then
        if ma_data.db_info.fourThree.erank and ma_data.db_info.fourThree.erank > 0 then
            --发送四暗刻奖励
            local cfg_idx = 30 + ma_data.db_info.fourThree.erank
            local cfg_award = cfg_goodLuck_award[cfg_idx]
            if cfg_award then
                local end_award = cfg_award.award
                --随机技能书
                local mail =  {
                    title = "鸿运榜四暗刻奖励",
                    content = [[恭喜您！在鸿运榜四暗刻获得<font color="#ff0000">]]
                        .. ma_data.db_info.fourThree.erank .. [[</font>名，获得如下奖励请及时领取。]],
                    attachment = end_award,
                    mail_type = MAIL_TYPE_OTHER,
                    mail_stype = MAIL_STYPE_AWARD,
                    -- friend_name = ma_data.db_info.nickname,
                    -- friend_head = ma_data.db_info.headimgurl
                }
                skynet.call("mail_mgr", "lua", "send_mail", ma_data.my_id, mail)
                ma_data.db_info.fourThree.erank = 0
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=ma_data.my_id},{["fourThree.erank"] = ma_data.db_info.fourThree.erank})
            else
                skynet.loge("good_luck rank idx error! ma_data.db_info.fourThree.erank ",ma_data.db_info.fourThree.erank)       
            end    
        end
        M.refreshFourThreeRankValue()
    end

    if not check_same_day(ma_data.db_info.nineLamp.t) then
        if ma_data.db_info.nineLamp.erank and ma_data.db_info.nineLamp.erank > 0 then
            --发送九莲宝灯奖励
            local cfg_idx = 10 + ma_data.db_info.nineLamp.erank
            local cfg_award = cfg_goodLuck_award[cfg_idx]
            if cfg_award then                
                local end_award = cfg_award.award
                --随机技能书
                local mail =  {
                    title = "鸿运榜九莲宝灯奖励",
                    content = [[恭喜您！在鸿运榜九莲宝灯获得<font color="#ff0000">]]
                                .. ma_data.db_info.nineLamp.erank ..
                                [[</font>名，获得如下奖励请及时领取。]],
                    attachment = end_award,
                    mail_type = MAIL_TYPE_OTHER,
                    mail_stype = MAIL_STYPE_AWARD,
                    -- friend_name = ma_data.db_info.nickname,
                    -- friend_head = ma_data.db_info.headimgurl
                }
                skynet.call("mail_mgr", "lua", "send_mail", ma_data.my_id, mail)
                ma_data.db_info.nineLamp.erank = 0
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=ma_data.my_id},{["nineLamp.erank"] = ma_data.db_info.nineLamp.erank})
            else
                skynet.loge("good_luck rank idx error! ma_data.db_info.nineLamp.erank ",ma_data.db_info.nineLamp.erank)       
            
            end
        end
        M.refreshNineLampRankValue()
    end
    if not check_same_day(ma_data.db_info.lianWinRank.t) then
        if ma_data.db_info.lianWinRank.erank and ma_data.db_info.lianWinRank.erank > 0 then
            local rank = ma_data.db_info.lianWinRank.erank
            ma_data.db_info.lianWinRank.erank = 0
            skynet.call(get_db_mgr(),"lua", "update", COLL.USER,
            {id=ma_data.my_id},{["lianWinRank.erank"] = 0, ["lianWinRank.count"] = 0})

            --发送连胜奖励 todo
            local cfg_award = cfg_serial_win
            local cfg = M.get_serial_win_cfg(cfg_award, rank)
            if cfg then
                local award = cfg.award
                local mail =  {
                    title = "连胜排行奖励领取",
                    content = [[尊敬的玩家,您在昨日的连胜排行榜赢得了第<font color="#ff0000">]]
                        .. rank ..
                        [[</font>名的排名,现发放排行奖励,祝您再接再厉,游戏愉快!]],
                    attachment = award,
                    mail_type = MAIL_TYPE_OTHER,
                    mail_stype = MAIL_STYPE_AWARD,
                }
                skynet.call("mail_mgr", "lua", "send_mail", ma_data.my_id, mail)
            end
        end
        M.refreshLianWinRankValue()
    end
end

function M.loadTwoRank()
    M.initMultipleRank()
    M.initLuckRank()
	M.initLianWinRank()
    M.check_reset()
end

function M.init(REQUEST, CMD)
    if request then
        table.connect(REQUEST, request)
    end
    if cmd then
        table.connect(CMD, cmd)
    end
    ma_data.follow_conf(M, cfg_conf.COLL.ACTIVITY_CONF)
    init_rank_module()
    M.loadTwoRank()
end

ma_data.ma_hall_ranklist = M
return M