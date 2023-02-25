--番王榜，鸿运榜
local skynet = require "skynet"
local xy_cmd = require "xy_cmd"
require 'pub_util'
local CMD = xy_cmd.xy_cmd
local COLL = require "config/collections"
local ranktwo_setting = nil
local rank_list = {multipleKing = {},eighteenMonk = {},fourThree = {},nineLamp = {}, lianWin = {}}
local rank_id_mac = {multipleKing = {},eighteenMonk = {},fourThree = {},nineLamp = {}, lianWin = {}}
local rank_cal_interval = 10 * 60
local rank_cal_left_time = rank_cal_interval
local first_id_mac = {multipleKing = {},eighteenMonk = {},fourThree = {},nineLamp = {}, lianWin = {}}
--赛季配置id 100000

function CMD.inject(filePath)
    require(filePath)
end

function CMD.get_setting()
    return ranktwo_setting
end

function CMD.updateLianWinRank(id, count, nickname, headimgurl, headframe)
    if rank_id_mac['lianWin'] and rank_id_mac['lianWin'][id] then
        if rank_id_mac['lianWin'][id].data.count < count then
            skynet.call(get_db_mgr(),"lua","update",COLL.RANKTWO_DATA,{id=id},{lianWinCount=count, useTime4 = os.time()})
        end
    else
         local rank_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.RANKTWO_DATA, {id = id},
                {_id=false,id=true,lianWinCount=true,nickname=true,headimgurl=true,headframe=true})
        if not rank_data then
            rank_data = {id=id, lianWinCount=count,nickname=nickname,headimgurl=headimgurl,headframe=headframe,t=os.time(), useTime4 = os.time()}
            skynet.call(get_db_mgr(),"lua","insert",COLL.RANKTWO_DATA,rank_data)
        else
            if rank_data.lianWinCount == nil or rank_data.lianWinCount < count then
                skynet.call(get_db_mgr(),"lua","update",COLL.RANKTWO_DATA,{id=id},{lianWinCount=count, useTime4 = os.time()})
            end
        end
    end
    first_id_mac['lianWin'][(#first_id_mac['lianWin']+1)] = id
end

--更新番王榜
function CMD.updateMultipleRank(id,multipleKing,nickname,headimgurl,gameType,headframe)
    if rank_id_mac['multipleKing'] and rank_id_mac['multipleKing'][id] then
        if rank_id_mac['multipleKing'][id].data.multipleKing < multipleKing.multipleKing then
            skynet.call(get_db_mgr(),"lua","update",COLL.RANKTWO_DATA,{id=id},{multipleKing=multipleKing.multipleKing,cards = multipleKing.cards})
        end
    else
         local rank_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.RANKTWO_DATA, {id = id},
                {_id=false,id=true,multipleKing=true,cards=true,useTime1=true,cards1=true,useTime2=true,cards2=true,
                useTime3=true,cards3=true,nickname=true,headimgurl=true,headframe=true})
        if not rank_data then
            rank_data = {id=id, multipleKing=multipleKing.multipleKing,cards=multipleKing.cards,useTime1=0,cards1={},useTime2=0,cards2={},
            useTime3=0,cards3={},nickname=nickname,headimgurl=headimgurl,headframe=headframe,t=os.time()}
            skynet.call(get_db_mgr(),"lua","insert",COLL.RANKTWO_DATA,rank_data)
        else
            if rank_data.multipleKing == nil or rank_data.multipleKing < multipleKing.multipleKing then
                skynet.call(get_db_mgr(),"lua","update",COLL.RANKTWO_DATA,{id=id},{multipleKing=multipleKing.multipleKing,cards = multipleKing.cards})
            end
        end
    end
    first_id_mac['multipleKing'][(#first_id_mac['multipleKing']+1)] = id
end

--更新十八罗汉
function CMD.updateEighteenMonk(id,eighteenMonk,nickname,headimgurl,headframe)
    if rank_id_mac['eighteenMonk'] and rank_id_mac['eighteenMonk'][id] then
        if rank_id_mac['eighteenMonk'][id].data.useTime1 > eighteenMonk.useTime1 then
            skynet.call(get_db_mgr(),"lua","update",COLL.RANKTWO_DATA,{id=id},{useTime1=eighteenMonk.useTime1,cards1 = eighteenMonk.cards1})
        end
    else
         local rank_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.RANKTWO_DATA, {id = id},
                {_id=false,id=true,multipleKing=true,cards=true,useTime1=true,cards1=true,useTime2=true,cards2=true,
                useTime3=true,cards3=true,nickname=true,headimgurl=true,headframe=true})
        if not rank_data then
            rank_data = {id=id, multipleKing=0,cards={},useTime1=eighteenMonk.useTime1,cards1=eighteenMonk.cards1,useTime2=0,cards2={},
            useTime3=0,cards3={},nickname=nickname,headimgurl=headimgurl,headframe=headframe,t=os.time()}
            skynet.call(get_db_mgr(),"lua","insert",COLL.RANKTWO_DATA,rank_data)
        else
            rank_data.useTime1 = rank_data.useTime1 or 0
            if rank_data.useTime1 == 0 or rank_data.useTime1 > eighteenMonk.useTime1 then
                skynet.call(get_db_mgr(),"lua","update",COLL.RANKTWO_DATA,{id=id},{useTime1=eighteenMonk.useTime1,cards1 = eighteenMonk.cards1})
            end
        end
    end
     if #first_id_mac['eighteenMonk'] <= 0 then
        first_id_mac['eighteenMonk'][(#first_id_mac['eighteenMonk']+1)] = id
    end
end

--更新四暗刻
function CMD.updateFourThree(id,fourThree,nickname,headimgurl,headframe)
    print("nid=", id, ";nickname=", nickname)
    table.print("fourThree =>", fourThree)
    if rank_id_mac['fourThree'] and rank_id_mac['fourThree'][id] then
        if rank_id_mac['fourThree'][id].data.useTime2 > fourThree.useTime2 then
            skynet.call(get_db_mgr(),"lua","update",COLL.RANKTWO_DATA,{id=id},{useTime2=fourThree.useTime2,cards2 = fourThree.cards2})
        end
    else
         local rank_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.RANKTWO_DATA, {id = id},
                {_id=false,id=true,multipleKing=true,cards=true,useTime1=true,cards1=true,useTime2=true,cards2=true,
                useTime3=true,cards3=true,nickname=true,headimgurl=true,headframe=true})
        if not rank_data then
            rank_data = {id=id, multipleKing=0,cards={},useTime1=0,cards1={},useTime2=fourThree.useTime2,cards2=fourThree.cards2,
            useTime3=0,cards3={},nickname=nickname,headimgurl=headimgurl,headframe=headframe,t=os.time()}
            skynet.call(get_db_mgr(),"lua","insert",COLL.RANKTWO_DATA,rank_data)
        else
            rank_data.useTime2 = rank_data.useTime2 or 0
            if rank_data.useTime2 == 0 or rank_data.useTime2 > fourThree.useTime2 then
                skynet.call(get_db_mgr(),"lua","update",COLL.RANKTWO_DATA,{id=id},{useTime2=fourThree.useTime2,cards2 = fourThree.cards2})
            end
        end
    end
    if #first_id_mac['fourThree'] <= 0 then
        first_id_mac['fourThree'][(#first_id_mac['fourThree']+1)] = id
    end
end

--更新九莲宝灯
function CMD.updateNineLamp(id,nineLamp,nickname,headimgurl,headframe)
    print("nid=", id, ";nickname=", nickname)
    table.print("nineLamp =>", nineLamp)
    if rank_id_mac['nineLamp'] and rank_id_mac['nineLamp'][id] then
        if rank_id_mac['nineLamp'][id].data.useTime3 > nineLamp.useTime3 then
            skynet.call(get_db_mgr(),"lua","update",COLL.RANKTWO_DATA,{id=id},{useTime3=nineLamp.useTime3,cards3 = nineLamp.cards3})
        end
    else
         local rank_data = skynet.call(get_db_mgr(), "lua", "find_one", COLL.RANKTWO_DATA, {id = id},
                {_id=false,id=true,multipleKing=true,cards=true,useTime1=true,cards1=true,useTime2=true,cards2=true,
                useTime3=true,cards3=true,nickname=true,headimgurl=true,headframe=true})
        if not rank_data then
            rank_data = {id=id, multipleKing=0,cards={},useTime1=0,cards1={},useTime2=0,cards2={},
            useTime3=nineLamp.useTime3,cards3=nineLamp.cards3,nickname=nickname,headimgurl=headimgurl,headframe=headframe,t=os.time()}
            skynet.call(get_db_mgr(),"lua","insert",COLL.RANKTWO_DATA,rank_data)
        else
            rank_data.useTime3 = rank_data.useTime3 or 0
            if rank_data.useTime3 == 0 or rank_data.useTime3 > nineLamp.useTime3 then
                skynet.call(get_db_mgr(),"lua","update",COLL.RANKTWO_DATA,{id=id},{useTime3=nineLamp.useTime3,cards3 = nineLamp.cards3})
            end
        end
    end
    if #first_id_mac['nineLamp'] <= 0 then
        first_id_mac['nineLamp'][(#first_id_mac['nineLamp']+1)] = id
    end
end

--获取返回的字段
function CMD.get_value(name)
    if name == 'multipleKing' then
        return 'multipleKing','cards'
    elseif name == 'nineLamp' then
        return 'useTime3','cards3'
    elseif name == 'fourThree' then
        return 'useTime2','cards2'
    elseif name == 'eighteenMonk' then
        return 'useTime1','cards1'
    elseif name == "lianWin" then
        return 'lianWinCount'
    end
end
--获取自身排名
function CMD.get_rank(name,id)
    local rank = -1
    local value1 = 0
    local value2 = {}
    if rank_id_mac[name] and rank_id_mac[name][id] then
        rank = rank_id_mac[name][id].rank
        local temp1,temp2 = CMD.get_value(name)
        value1 = rank_id_mac[name][id].data[temp1]
        value2 = rank_id_mac[name][id].data[temp2]
    end
    --print('四榜获取排名=====name,rank,value1,value2',name,rank,value1,value2)
    return rank,value1,value2
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

    skynet.call("db_mgr_del", "lua", "delete",COLL.RANKTWO_DATA,{id=id})
end

function CMD.refreshRank()
    --番数
    rank_list.multipleKing = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKTWO_DATA,
        {t={["$gte"] = ranktwo_setting.t},multipleKing = {["$gt"] = 0}},
        {_id = false,id=true,multipleKing = true,cards=true,nickname=true,headimgurl=true,headframe=true},
        {{multipleKing = -1,}}, 10) or {}
    rank_id_mac.multipleKing = {}
    for rank,data in ipairs(rank_list.multipleKing) do
        rank_id_mac.multipleKing[data.id] = {rank=rank,data=data}
        first_id_mac.multipleKing[rank] = data.id
    end

    --十八罗汉
    rank_list.eighteenMonk = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKTWO_DATA,
        {t={["$gte"] = ranktwo_setting.t},useTime1={["$gt"] = 0}},
        {_id = false,id=true,useTime1 = true,cards1=true,nickname=true,headimgurl=true,headframe=true},
        {{useTime1 = 1}}, 3) or {}
    rank_id_mac.eighteenMonk = {}
    for rank,data in ipairs(rank_list.eighteenMonk) do
        rank_id_mac.eighteenMonk[data.id] = {rank=rank,data=data}
        first_id_mac.eighteenMonk[rank] = data.id
    end

    --四暗刻
    rank_list.fourThree = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKTWO_DATA,
        {t={["$gte"] = ranktwo_setting.t},useTime2={["$gt"] = 0}},
        {_id = false, id=true,useTime2 = true,cards2=true, nickname=true, headimgurl=true,headframe=true},
        {{useTime2 = 1}}, 3) or {}
    rank_id_mac.fourThree = {}
    for rank,data in ipairs(rank_list.fourThree) do
        rank_id_mac.fourThree[data.id] = {rank=rank,data=data}
        first_id_mac.fourThree[rank] = data.id
    end

    --九莲宝灯
    rank_list.nineLamp = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKTWO_DATA,
        {t={["$gte"] = ranktwo_setting.t},useTime3={["$gt"] = 0}},
        {_id = false, id=true,useTime3 = true,cards3=true, nickname=true, headimgurl=true,headframe=true},
        {{useTime3 = 1}}, 3) or {}
    rank_id_mac.nineLamp = {}
    for rank,data in ipairs(rank_list.nineLamp) do
        rank_id_mac.nineLamp[data.id] = {rank=rank,data=data}
        first_id_mac.nineLamp[rank] = data.id
    end

    --连胜排行榜
    rank_list.lianWin = skynet.call(get_db_mgr(), "lua", "find_all", COLL.RANKTWO_DATA,
        {t={["$gte"] = ranktwo_setting.t},lianWinCount={["$gt"] = 0}},
        {_id = false, id=true,lianWinCount = true, nickname=true, headimgurl=true,headframe=true},
        {{lianWinCount = -1}, {useTime4 = 1}}, 100) or {}
    rank_id_mac.lianWin = {}

    for rank,data in ipairs(rank_list.lianWin) do
        data.count = data.lianWinCount
        rank_id_mac.lianWin[data.id] = {rank=rank,data=data}
        first_id_mac.lianWin[rank] = data.id
    end
end

--倒计时判断
function CMD.time_count_down()
    if #rank_list.multipleKing > 100 or
        #rank_list.eighteenMonk > 100 or
        #rank_list.fourThree > 100 or
        #rank_list.nineLamp > 100 then
        return false
    end
    return true
end

function CMD.time_tick_op()
    if not check_same_day(ranktwo_setting.t) then
        print("rank_two_2")
        CMD.refreshRank()
        ranktwo_setting.settle = 1
        --设置奖励状态
        for id,item in pairs(rank_id_mac.multipleKing) do
            if item.rank <= 3 then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=id},{["multipleKing.erank"] = item.rank})
            end
        end
        for id,item in pairs(rank_id_mac.eighteenMonk) do
            if item.rank <= 3 then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=id},{["eighteenMonk.erank"] = item.rank})
            end
        end
        for id,item in pairs(rank_id_mac.fourThree) do
            if item.rank <= 3 then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=id},{["fourThree.erank"] = item.rank})
            end
        end
        for id,item in pairs(rank_id_mac.nineLamp) do
            if item.rank <= 3 then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=id},{["nineLamp.erank"] = item.rank})
            end
        end
        for id,item in pairs(rank_id_mac.lianWin) do
            if item.rank <= 100 then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=id},{["lianWinRank.erank"] = item.rank})
            end
        end
        ranktwo_setting.t = os.time()
        ranktwo_setting.settle = 0
        skynet.call("db_mgr_del", "lua", "delete", COLL.RANKTWO_DATA, {t={["$lt"] = ranktwo_setting.t}})
        skynet.call(get_db_mgr(),"lua","update",COLL.SETTING,{id="ranktwo_setting"},ranktwo_setting)
        rank_list = {multipleKing = {},eighteenMonk = {},fourThree = {},nineLamp = {}, lianwin = {}}
        rank_id_mac = {multipleKing = {},eighteenMonk = {},fourThree = {},nineLamp = {}, lianWin = {}}
        first_id_mac = {multipleKing = {},eighteenMonk = {},fourThree = {},nineLamp = {}, lianWin = {}}
    end
    rank_cal_left_time = rank_cal_left_time - 1
    if rank_cal_left_time <= 0 then
        rank_cal_left_time = rank_cal_interval
        CMD.refreshRank()
        if CMD.time_count_down() then
            --小于100人10秒钟刷新一次
            rank_cal_left_time = 10
        end
    end
end

function CMD.time_tick()
    skynet.timeout(100, CMD.time_tick)
    CMD.time_tick_op()
end

function CMD.init()
    ranktwo_setting = skynet.call(get_db_mgr(), "lua", "find_one", COLL.SETTING, {id = "ranktwo_setting"},
                                            {_id=false,t=true,settle=true})
    if not ranktwo_setting then
        print("rank_two_init")
        ranktwo_setting = {}
        ranktwo_setting.id = "ranktwo_setting"
        ranktwo_setting.t = os.time()
        ranktwo_setting.settle = 0
        skynet.call(get_db_mgr(),"lua","insert",COLL.SETTING,ranktwo_setting)
    end
    CMD.refreshRank()
    print("rank_two_t",ranktwo_setting.t,os.time())
    if not check_same_day(ranktwo_setting.t) then
        print("rank_two_1")
        CMD.refreshRank()
        ranktwo_setting.settle = 1
        --设置奖励状态
        for id,item in pairs(rank_id_mac.multipleKing) do
            if item.rank <= 3 then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=id},{["multipleKing.erank"] = item.rank})
            end
        end
        for id,item in pairs(rank_id_mac.eighteenMonk) do
            if item.rank <= 3 then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=id},{["eighteenMonk.erank"] = item.rank})
            end
        end
        for id,item in pairs(rank_id_mac.fourThree) do
            if item.rank <= 3 then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=id},{["fourThree.erank"] = item.rank})
            end
        end
        for id,item in pairs(rank_id_mac.nineLamp) do
            if item.rank <= 3 then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=id},{["nineLamp.erank"] = item.rank})
            end
        end
        for id,item in pairs(rank_id_mac.lianWin) do
            if item.rank <= 100 then
                skynet.call(get_db_mgr(),"lua", "update", COLL.USER, {id=id},{["lianWinRank.erank"] = item.rank})
            end
        end

        ranktwo_setting.t = os.time()
        ranktwo_setting.settle = 0
        skynet.call("db_mgr_del", "lua", "delete", COLL.RANKTWO_DATA, {t={["$lt"] = ranktwo_setting.t}})
        skynet.call(get_db_mgr(),"lua","update",COLL.SETTING,{id="ranktwo_setting"},ranktwo_setting)
        rank_list = {multipleKing = {},eighteenMonk = {},fourThree = {},nineLamp = {}, lianWin={}}
        rank_id_mac = {multipleKing = {},eighteenMonk = {},fourThree = {},nineLamp = {}, lianWin={}}
        first_id_mac = {multipleKing = {},eighteenMonk = {},fourThree = {},nineLamp = {}, lianWin={}}
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