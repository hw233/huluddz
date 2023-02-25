local ma_pushmsg = {}
require "config.GameConst"
require 'base.BaseFunc'
local skynet = require "skynet"
local cluster = require "skynet.cluster"
local ma_data = require "ma_data"
local ma_hall = require "ma_hall"
local cfg_rank_grade = require "cfg/cfg_rank_grade"
local place_config = require "cfg/place_config"
local ma_room_match = require "ma_room_match"         -- 房间匹配

ma_pushmsg.PROCESS = {}
local PROCESS = ma_pushmsg.PROCESS


function ma_pushmsg.sync_min_charm(min_charm)
    ma_hall_rankinglist.sync_min_charm(min_charm)
end

-- TOOD
-- 设置房间等参数
function ma_pushmsg.you_back_complete(args)
    ma_data.my_room = skynet.call("agent_mgr", "lua", "find_room", args.room_info.id)
    ma_data.my_room_id = args.room_info.id
end

-- 玩家加入房间
function PROCESS.joinresult(args)
    if args.result then
        --if ma_data.my_room then
            --skynet.error("error:玩家 ".. ma_data.my_id .. " 房间重入")
        --end

        ma_data.my_room = skynet.call("agent_mgr", "lua", "find_room", args.room_info.id)
        -- ma_data.my_room = cluster.call("agent_mgr", "agent_mgr", "lua", "find_room", args.room_info.id )
        ma_data.my_room_id = args.room_info.id

       
    end
end

function PROCESS.all_join(args)
    ma_data.my_room = skynet.call("agent_mgr", "lua", "find_room", args.room_info.id)
    -- ma_data.my_room = cluster.call("agent_mgr", "agent_mgr", "lua", "find_room", args.room_info.id )
    ma_data.my_room_id = args.room_info.id

     ma_room_match.set_matching(false)
end

-- 玩家加入房间
function PROCESS.joinroom(args)
    if args.result then
        if not ma_data.my_room then
            ma_data.my_room = skynet.call("agent_mgr", "lua", "find_room", args.room_info.id)
            -- ma_data.my_room = cluster.call("agent_mgr", "agent_mgr", "lua", "find_room", args.room_info.id )
            ma_data.my_room_id = args.room_info.id
        end
    end
end

-- 玩家离开
function PROCESS.player_leave(args)
    if args.id == ma_data.my_id then
        ma_data.my_room = nil
        ma_data.my_room_id = nil
    end
    --声望结算/嘻嘻捞，游戏局数增加
    for i,p_info in ipairs(args.bills) do
        if p_info.pid == ma_data.my_id then
            ma_pushmsg.my_game_over(args,p_info)
            break
        end
    end
end
-- 解散房间
function PROCESS.dissolve_room(args)
    if ma_data.my_room_id ~= args.room_id then
        return false
    end
    ma_data.my_room = nil
    ma_data.my_room_id = nil
end

-- 玩家从离线回来
function PROCESS.you_back(args)
    print('process_msg you_back ==========================')
    ma_pushmsg.you_back_complete(args)
end

local function update_player_gold(args)
    local wlGold = 0
    for i,p_info in ipairs(args.currencys) do
        if p_info.p_id == ma_data.my_id then
            wlGold = p_info.gold_num
            break
        end
    end
    --print('==============,====gold',wlGold)
    if not wlGold or wlGold == 0 then
        return
    end

    local pack = {}
    pack.id = GOODS_GOLD_ID
    pack.num = wlGold
    local goods = {}
    table.insert(goods,pack)
    local new_args = {}
    new_args.goods = goods
    new_args.desc = args.desc
    new_args.ex = tostring(args.roomId)
    new_args.subjoinDesc = {
        roomType = args.roomType
    }
    if args.roomId then
        new_args.from_room = true
    end
    return new_args
end

local function update_player_petCoin(args)
    local wlpetCoin = 0
    for i,p_info in ipairs(args.currencys) do
        if p_info.p_id == ma_data.my_id then
            wlpetCoin = p_info.petCoin
            break
        end
    end
    --print('====,========petCoin',wlpetCoin)
    if not wlpetCoin or wlpetCoin == 0 then
        return
    end

    local pack = {}
    pack.id = 100012
    pack.num = wlpetCoin
    local goods = {}
    table.insert(goods,pack)
    local new_args = {}
    new_args.goods = goods
    new_args.desc = args.desc
    new_args.ex = tostring(args.roomId)
    new_args.subjoinDesc = {
        roomType = args.roomType
    }
    if args.roomId then
        new_args.from_room = true
    end
    return new_args
end

function ma_pushmsg.update_self_gold(args)
    local new_args = update_player_gold(args)

    if new_args then
        ma_data.add_goods_list(
                new_args.goods, 
                new_args.desc, 
                new_args.ex,
                new_args.from_room,
                new_args.subjoinDesc
            )
    end
end

function ma_pushmsg.update_self_petCoin(args)
    local new_args = update_player_petCoin(args)

    if new_args then
        ma_data.add_goods_list(
                new_args.goods, 
                new_args.desc, 
                new_args.ex,
                new_args.from_room,
                new_args.subjoinDesc
            )
    end
end

function ma_pushmsg.update_player_frame(args)
    print('update_player_frame args =>', table.tostr(args))
    local wlScore = 0
    local gameId = args.roomType // 100
    local placeId = args.roomType % 100
    for _,p_info in ipairs(args.currencys) do
        if p_info.p_id == ma_data.my_id then
            wlScore = p_info.addRankScore
            break
        end
    end
    if not wlScore or wlScore == 0 then
        return
    end
    print('update_player_frame wlScore =>',wlScore)
    local buffNum = ma_data.ma_hall_frame.frame_buff_num()
    buffNum = buffNum + place_config[gameId][placeId].addition/100
    print('update_player_frame buffNum =>',buffNum)
    if wlScore > 0 then
        wlScore = math.floor(wlScore*buffNum)
        local enable = ma_data.IsItemEnabled(ITEM_TYPE_DOUBLE_PRESTIGE_CARD)
        if enable then
            wlScore = wlScore * 2
        end
    end
    print('update_player_frame final wlScore =>',wlScore)
    ma_data.ma_hall_frame.hall_frame_settle(wlScore)
end

-- 更新金币信息
function PROCESS.wlResult(args)
    -- print('=======================更新金币信息=======================args ')
    -- table.print(args)
    ma_pushmsg.update_self_gold(args)
    ma_pushmsg.update_self_petCoin(args)
    ma_pushmsg.update_player_frame(args)
end

-- 获取胡牌信息
function PROCESS.players_hu(args)
    --print('=======================获取胡牌信息=======================',ma_data.my_id,args.huData.gameType)
    --table.print(args)
    local my_hu = {}
    local isUpdate = false
    for i,one_info in ipairs(args.huData) do
        if one_info.pid == ma_data.my_id then
            my_hu = one_info
            isUpdate = true
            break
        end
    end
    print("players_hu my_id=", ma_data.my_id, ";isUpdate=", isUpdate, ";markNum=", ma_data.db_info.markNum)
    if isUpdate then
        table.print("cTypes =>", my_hu.cTypes)
        table.print("FanNum =>", my_hu.FanNum)
        local pack = {}
        pack.hand = my_hu.pHand
        pack.pengs = my_hu.pengs
        pack.gangs = my_hu.gangs
        pack.huCard = my_hu.huCard
        pack.cTypes = my_hu.cTypes
        pack.FanNum = my_hu.FanNum
        if not ma_data.db_info.markNum or ma_data.db_info.markNum ~= 3 then
            ma_data.ma_hall_ranklist.updateLuckRank(os.time(),pack,my_hu.cTypes,args.huData.gameType)
            ma_data.ma_hall_ranklist.updateMultipleRank(my_hu.FanNum,pack,args.huData.gameType)
        end
        ma_hall.updateMaxCard(args.huData.gameType,pack,my_hu.cap)
        ma_data.ma_task.hu_fan(my_hu.FanNum,my_hu.cap)
    end
end

function ma_pushmsg.consume_prestige_item(info)
    print("consume_prestige_item info =>", table.tostr(info))
    local used = false
    if info.itemTakeEffect then
        do--暴击卡使用
            local take_effect = info.itemTakeEffect[ITEM_TYPE_ZIMO_CARD] or info.itemTakeEffect[ITEM_TYPE_PENGGANG_CARD]
            take_effect = take_effect or info.isWin
            if take_effect then
                print("nid=", info.pid, "use double prestige card")
                local goods = {id = ITEM_TYPE_DOUBLE_PRESTIGE_CARD, num = -1}
                ma_data.add_goods(goods, GOODS_WAY_CONSUME, "游戏结束,扣除暴击卡", nil, true)
                used = true
            end
        end
        do--自摸卡使用
            if info.itemTakeEffect[ITEM_TYPE_ZIMO_CARD] then
                print("nid=", info.pid, "use zimo card")
                local goods = {id = ITEM_TYPE_ZIMO_CARD, num = -1}
                ma_data.add_goods(goods, GOODS_WAY_CONSUME, "游戏结束,扣除自摸卡", nil, true)
                used = true
            end
        end
        do--碰杠卡使用
            if info.itemTakeEffect[ITEM_TYPE_PENGGANG_CARD] then
                print("nid=", info.pid, "use peng gang card")
                local goods = {id = ITEM_TYPE_PENGGANG_CARD, num = -1}
                ma_data.add_goods(goods, GOODS_WAY_CONSUME, "游戏结束,扣除碰杠卡", nil, true)
                used = true
            end
        end
    end
    if used then
        ma_data.ma_task.add_task_count(TASK_DAY_T_USE_ITEM)
    end
end

function ma_pushmsg.my_game_over(args,p_info)
    print("my_game_over =", table.tostr(p_info))
    local isAdd = false
    local gameId = args.place_id // 100
    local placeId = args.place_id % 100
    if p_info.rankScore then
        local buffNum = 1
        buffNum = ma_data.ma_hall_frame.frame_buff_num()
        buffNum = buffNum + place_config[gameId][placeId].addition/100
        if p_info.rankScore > 0 then
            p_info.rankScore = math.floor(p_info.rankScore*buffNum)
            local enable = ma_data.IsItemEnabled(ITEM_TYPE_DOUBLE_PRESTIGE_CARD)
            if enable then
                p_info.rankScore = p_info.rankScore * 2
            end
        end
        local curSeg = ma_data.ma_hall_frame.get_seg_by_prestige(ma_data.db_info.hall_frame.seg_prestige)
        ma_data.ma_hall_active.update_xixi_big_gift(args.place_id,curSeg)
        isAdd = true
    end
    --print('==============================声望=====================',ma_data.db_info.hall_frame.seg_prestige)
    p_info.prestige = ma_data.db_info.hall_frame.seg_prestige
    --print('==============场次============',args.place_id,gameId,placeId)
    local isWin = (p_info.win_gold > 0)

    --雀神模式
    if place_config[gameId][placeId].stype == PLACE_STYPE_MRT then
        isWin = p_info.isWin
        ma_data.ma_hall_active.finish_new_player_task(3)
    end

    --红中血流模式 普通场
    if place_config[gameId][placeId].stype == PLACE_STYPE_NORMAL
        and place_config[gameId][placeId].type == GAME_TYPE_HZXL then
        ma_data.ma_hall_active.finish_new_player_task(1)
    end 


    --红中血流2v2玩法
    if place_config[gameId][placeId].type == GAME_TYPE_HZXL2v2 then
        ma_data.ma_hall_active.finish_new_player_task(2)
        ma_data.ma_task.add_task_count(TASK_DAY_T_2v2)
    end 

    ma_hall.updateGameNum(args.place_id,isWin,p_info.noRedNum,p_info.matchMarkId)
    local today_lian_win = ma_data.db_info.today_lian_win or {}
    if not check_same_day(today_lian_win.t) then
        today_lian_win.t = os.time()
        today_lian_win.count = 0
        skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id},
        {today_lian_win = today_lian_win})
    end
    if isWin then
        ma_data.ma_task.add_task_count(TASK_DSY_T_WIN)
        ma_data.ma_growth_plan.game_wind()
        ma_data.db_info.lian_win = ma_data.db_info.lian_win + 1
        today_lian_win.count =  today_lian_win.count + 1
        if ma_data.db_info.lian_win == 30 then
            local automsg = {[1]=ma_data.db_info.nickname}
            skynet.send("services_mgr", "lua", "activeNotice",4, 1, automsg)
        end
        ma_data.ma_hall_ranklist.updateLianWinRank(today_lian_win.count)
        print("my_game_over win lian win count=", ma_data.db_info.lian_win, ";my_id=", ma_data.db_info.id)
        print("my_game_over win today lian win count=", today_lian_win.count, ";my_id=", ma_data.db_info.id)
        print("my_game_over win today lian win t=", today_lian_win.t, ";my_id=", ma_data.db_info.id)
    else
        ma_data.db_info.lian_win = 0
        today_lian_win.count =  0

        print("my_game_over lose lian win count=", ma_data.db_info.lian_win, ";my_id=", ma_data.db_info.id)
        print("my_game_over lose today lian win count=", today_lian_win.count, ";my_id=", ma_data.db_info.id)
        print("my_game_over lose today lian win t=", today_lian_win.t, ";my_id=", ma_data.db_info.id)
    end
    today_lian_win.t = os.time()

    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id},
        {lian_win = ma_data.db_info.lian_win})
    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id},
        {today_lian_win = today_lian_win})
    today_lian_win.t = os.time()
    ma_data.db_info.today_lian_win = today_lian_win

    if not isAdd then
        ma_data.ma_hall_active.update_xixi_big_gift(args.place_id)
    end
    local placeCfg = place_config[gameId]
    local cfg = placeCfg[placeId]
    if cfg.stype == PLACE_STYPE_MRT then
        ma_data.ma_task.add_task_count(TASK_DAY_T_MRT)
    end
    if cfg.type == GAME_TYPE_HZXL and cfg.stype == PLACE_STYPE_NORMAL then --血流红中
        ma_data.ma_task.add_task_count(TASK_DAY_T_PLAY_HZXL)
    end
    ma_data.ma_day_comsume.small_game_over()
    --牌局结束,扣除使用中的声望增益道具
    ma_pushmsg.consume_prestige_item(p_info)

    local pack = {}
    pack.hand = p_info.hand
    pack.pengs = p_info.pong
    pack.gangs = p_info.gang
    pack.huCard = p_info.lastHuCard
    ma_hall.saveRecord(args.place_id,isWin,p_info.IOChange,pack,p_info.win_gold,p_info.rankScore)

    --增加红包每日对局次数统计
    -- print(" 增加每日对局次数统计 ")
    -- ma_data.ma_qq_wallet.Add_QQ_HB_Data({play_gamec=1})
end

function PROCESS.small_game_over(args)
    --声望结算/嘻嘻捞，游戏局数增加
    for i,p_info in ipairs(args.bills) do
        --print('================small_game_over1x=================',p_info.pid,ma_data.my_id)
        if p_info.pid == ma_data.my_id then
            --print('================small_game_over=================',p_info.rankScore,ma_data.my_id)
            if p_info.DeuceHuCards and #p_info.DeuceHuCards > 0 then
                local gameId = args.place_id // 100
                local placeId = args.place_id % 100
                local buffNum = 1
                buffNum = ma_data.ma_hall_frame.frame_buff_num()
                buffNum = buffNum + place_config[gameId][placeId].addition/100
                local selectnum,maxnum = ma_data.ma_heilao.set_info(p_info.DeuceHuCards,buffNum,gameId,placeId)
                args.selectnum = selectnum
                args.maxnum = maxnum
            end
            ma_pushmsg.my_game_over(args,p_info)
            break
        end
    end
end

-- 更新邀请任务进度
function PROCESS.update_invite_progress(args)
    if args.finish_num then
        ma_data.share_tbl.get_award = args.get_award
        ma_data.share_tbl.finish_num  = args.finish_num
    elseif args.bind_num then
        ma_data.share_tbl.bind_num  = args.bind_num
    end
    -- ma_weeklytask.on.invite_ok()
end

-- 更新推广员金币钻石
function PROCESS.update_my_Award(args)
    ma_data.ma_spread.updateMyAward(args.coinType,args.num)
end

-- 更新推广员金币钻石
function PROCESS.update_other_award(args)
    ma_data.ma_spread.updateMyAward(args.coinType,args.num)
end

function ma_pushmsg.delete_friend(args)
    if args and args.id then
        for index,item in ipairs(ma_data.friend_data.list) do
            if item.id == args.id then
                table.remove(ma_data.friend_data.list, index)
                break
            end
        end
    end
end

function ma_pushmsg.process_msg(name,args)
    local func = PROCESS[name]
    local ok, result
    if func then
        --func(args)
        ok, result = pcall(func,args)
        if not ok then
            return skynet.error(string.format("ma_pushmsg.process_msg [%s] error: %s", name, result))
        end
    end
    if result ~= false then
        -- print('process_msg send_push', name, args)
        ma_data.send_push(name, args)
    end
end

return ma_pushmsg