local skynet = require 'skynet'

local objx = require "objx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)

require 'base.BaseFunc'
require "utils/pub_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

-- ServerData.room_conf = require("cfg/place_config")
ServerData.players = {} -- 所有玩家的
ServerData.onlineNum = 0
ServerData.active_user_num = 0
ServerData.last_active_record_time = nil

-- 生成游戏玩家人数初始数据 -------------
--记录上次时间
ServerData.last_time = 0
--间隔时间
ServerData.interval_time = 60
-- 生成游戏玩家人数初始数据 end -------------

ServerData.afk_user = {}
ServerData.markNum_user = {} --在线的被标记的玩家

ServerData.rooms = {}

ServerData.gen_room_table = {}
ServerData.gen_room_index = 1


ServerData.roomIndex_ddz = 1



--不是3的倍数补足
function CMD.meet_count(num,base)
    local temp_num = num % base
    if temp_num > 0 then
        return num + (base-temp_num)
    else
        return num
    end
end

--随机浮动人数
function CMD.random_init_pnum()
    local time = os.time()
    if time - ServerData.last_time < ServerData.interval_time then
        return
    end

    ServerData.last_time = time

    for k,game in pairs(ServerData.game) do
        local conf = ServerData.room_conf[k]
        local count = math.random(conf.minPCount,conf.maxPCount)
        count = CMD.meet_count(count,conf.playerCount)
        game.init_pnum = count
    end
    
end

--获取金币场的人数信息
function CMD.get_game_pcount()
    CMD.random_init_pnum()
    return ServerData.game
end

--玩家在黑名单
function CMD.player_in_blacklist(pid,blacklist)
    for i=1,#blacklist do
        if blacklist[i] == pId then
            return true
        end
    end
    return false
end





---------------------------------------------------------
--player api start
---------------------------------------------------------

function CMD.PlayerLogin(id, p_agent, markNum)
    ServerData.players[id] = p_agent
    ServerData.onlineNum = ServerData.onlineNum + 1
    -- if markNum and markNum > 1 then
    --     table.insert(ServerData.markNum_user,id)
    -- end
end

function CMD.PlayerLogout(id)
    if id and ServerData.players[id] then
        ServerData.players[id] = nil
        ServerData.onlineNum = ServerData.onlineNum - 1
    end
    -- for i=#ServerData.markNum_user,-1,1 do
    --     if ServerData.markNum_user[i] == p_id then
    --         table.remove(ServerData.markNum_user,i)
    --         break
    --     end
    -- end
end

function CMD.GetPlayers()
    return ServerData.players
end

-- old : find_player
function CMD.GetPlayerAgent(id)
    return ServerData.players[id]
end

function CMD.find_agent(id)
    return ServerData.players[id]
end

--获取在线人数
function CMD.GetPlayerOnlineNum()
    return ServerData.onlineNum
end

function CMD.send2player(pid, ...)
    local a = ServerData.players[pid]
    if a then
        skynet.send(a, "lua", ...)
        return true
    end
    return false
end



--添加屏蔽人数在线
function CMD.add_markNum(p_id)
    table.insert(ServerData.markNum_user,p_id)
end

--获取在线人数
function CMD.getOnlineMarkPlayers()
    return ServerData.markNum_user
end
------------------------------------------------------------------
--player api end
------------------------------------------------------------------



---------------------------------------------------------
--afk
---------------------------------------------------------



function CMD.userafk(uid, room, islogout)
    print("====debug qc==== agent_mgr.userafk  ",uid, room, islogout)
    ServerData.afk_user[uid] = room
    skynet.send(room, "lua", "userafk", uid, islogout)
end

function CMD.userback(uid,uagent,gold)
    local room = ServerData.afk_user[uid]
    print("====debug qc==== agent_mgr.userback  ",uid, room, gold)
    if room then
        ServerData.afk_user[uid] = nil
        skynet.send(room, "lua", "userback", uid,uagent,gold)
    end
    return room
end
-------------------------------------------------------


--------------------------------------------------------------------
--room api start
--------------------------------------------------------------------

function CMD.GetRoomId()
    local index = ServerData.roomIndex_ddz
    ServerData.roomIndex_ddz = ServerData.roomIndex_ddz + 1
    -- return tostring(index)
    return objx.getUid_Time()
end

function CMD.get_a_room_id()
    local room_id

    while true do
        room_id = tostring(math.random(100000,999999))
        if ServerData.rooms[room_id] == nil then
            return room_id
        end
    end
end

function CMD.get_room_num()
    local num = 0
    
    for _,game in pairs(ServerData.game) do
        num = num + game.room_num
    end

    return num
end




function CMD.create_room(conf)
    print("agent mgr create room ---------------",conf.gameName)
    
    -- ServerData.rooms[room_id] = {}

    local gen_index = ServerData.gen_room_index
    ServerData.gen_room_index = ServerData.gen_room_index + 1
    if ServerData.gen_room_index > #ServerData.gen_room_table then
        ServerData.gen_room_index = 1
    end
    
    local gen_room = ServerData.gen_room_table[gen_index]
  
    local room_name = conf.gameName
    room = skynet.call(gen_room, "lua", "get_room","room",room_name)
    local room_id = CMD.get_a_room_id()
    conf.id = room_id
    
    ServerData.rooms[room_id] = room

    --房间初始化
    skynet.send(room, "lua", "init", conf)
   
    if conf.gameType then
        ServerData.game[conf.gameType].room_num = ServerData.game[conf.gameType].room_num + 1
    end

    return room_id, room
end

--玩家离开房间
function CMD.player_leave(pid,gameType)
    if ServerData.afk_user[pid] then
        ServerData.afk_user[pid] = nil
    end

    -- 减少同种房间中玩家基数
    if gameType then
        ServerData.game[gameType].room_num = 
                ServerData.game[gameType].room_num - 1
    end
end

function CMD.dissolve_room(room_id,gameType,pids)
    
    local room = ServerData.rooms[room_id]

    if not room then
        return
    end
    --断线用户的房间清理
    for pid,r in pairs(ServerData.afk_user) do
        if r == room then
            ServerData.afk_user[pid] = nil 
        end
    end
    -- 减少房间计数
    if gameType then
        ServerData.game[gameType].room_num = ServerData.game[gameType].room_num - 1
    end

    if pids then
        for _,pid in ipairs(pids) do
            CMD.player_leave(pid,gameType)
        end
    end

    ServerData.rooms[room_id] = nil
end

function CMD.find_room(room_id)
    local room = ServerData.rooms[room_id]
    return room
end

--------------------------------------------------------
--room api end
--------------------------------------------------------

function CMD.get_user_num()
    local num = 0
    for _,game in pairs(ServerData.game) do
        num = num + game.player_num
    end
    
    local pack = {}
    for k,v in pairs(ServerData.game) do
        local key = math.ceil(k / 100)
        pack[key] = (pack[key] or 0) + v.player_num
    end

    pack.all = num

    return pack
end

function CMD.get_user_num_in_type(gameType)
    
    return ServerData.game[gameType].player_num
    
end


local isServerWillShutdown = false
local isForbidCreateRoom = false

function CMD.get_server_shutdown()
    return isServerWillShutdown,isForbidCreateRoom
end

function CMD.server_will_shutdown()
    isServerWillShutdown = true
    for p_id,agent in pairs(ServerData.players) do
        skynet.send(agent,'lua','server_will_shutdown')
        -- cluster.send(get_user_cluster(p_id), agent, 'lua','server_will_shutdown')
    end
end
-- 服务器将关闭的时候，禁止创建朋友局
function CMD.forbid_create_room()
    isForbidCreateRoom = true
    for p_id,agent in pairs(ServerData.players) do
        skynet.send(agent,'lua','forbid_create_room')
        -- cluster.send(get_user_cluster(p_id), agent, 'lua','forbid_create_room')
    end
end

-- 全服广播
function CMD.notice(name,args)
    for p_id,agent in pairs(ServerData.players) do
        pcall(skynet.call,agent,'lua','push_msg',name,args)
        -- pcall(cluster.send, get_user_cluster(p_id), agent, 'lua','push_msg',name,args)
    end
end

-- 全服广播2
-- group: 玩家id 数组 
function CMD.notice2(name, args, group)
    if group then
        for i, id in pairs(group) do
            local agt = ServerData.players[id]
            if agt then
                pcall(skynet.call,agt,'lua','push_msg',name,args)
            end
        end
    else
        CMD.notice(name,args)
    end
end



function CMD.notice2agent(name, args)
    for p_id,agent in pairs(ServerData.players) do
        pcall(skynet.call, agent, 'lua', name, args)
    end
end

function CMD.shutdown(type)
    if type == 'room' then
        for _,agent in pairs(ServerData.rooms) do
            -- pcall(agent.post.shutdown)
            pcall(skynet.send, agent.room, "lua", "shutdown")
        end
    elseif type == 'user' then
        for p_id,agent in pairs(ServerData.players) do
            pcall(skynet.send,agent,'lua','shutdown')
            -- pcall(cluster.send, get_user_cluster(p_id), agent, 'lua','shutdown')
        end
        skynet.exit()
    end
end

-- 设置日活跃 start ----------
function CMD.get_active_num_in_db()
    --local info = skynet.call(get_db_mgr(), "lua", "get_intraday_active_num")
    local info = dbx.get(TableNameArr.ACTIVE_DATA, {time = get_today_0_time()})
    ServerData.active_user_num = info and info.active_num or 0
    ServerData.last_active_record_time = get_today_0_time()
    if not info then
        --skynet.send(get_db_mgr(), "lua", "insert_intraday_active_num", {active_num = 0,time = ServerData.last_active_record_time})
        dbx.add(TableNameArr.ACTIVE_DATA, {active_num = 0,time = ServerData.last_active_record_time})
    end
end

--绑定好友通知 bind_user_id(绑定玩家) bound_user_id(被绑定玩家)
function CMD.bound_friend_tips(bind_user_id,bound_user_id,invitation_award)
    print("bound_friend_tips agent_mgr",bind_user_id,bound_user_id)
    table.print(invitation_award)

    skynet.call(get_db_mgr(), "lua","set_update_data","user",{id = bound_user_id},{invitation_award = invitation_award})

    for p_id,agent in pairs(ServerData.players) do
        if p_id == tostring(bound_user_id) then
            skynet.send(agent,'lua','bound_friend_tips',bind_user_id,bound_user_id,invitation_award)
        end
    end

end

function CMD.set_active_num_to_db(time,isUpdate)
    local pack = {
        active_num = ServerData.active_user_num,
        time = time,
    }
    if not isUpdate then
        --skynet.send(get_db_mgr(), "lua", "insert_intraday_active_num", pack)
        dbx.add(TableNameArr.ACTIVE_DATA, pack)
    else
        --skynet.send(get_db_mgr(), "lua", "update_intraday_active_num", pack)
        dbx.update(TableNameArr.ACTIVE_DATA, {time = pack.time}, {active_num = pack.active_num})
    end
end

function CMD.set_active_user_num()
    local time = get_today_0_time()
    if time ~= ServerData.last_active_record_time then
        ServerData.active_user_num = 1
        ServerData.last_active_record_time = time
        CMD.set_active_num_to_db(time)
    else
        ServerData.active_user_num = ServerData.active_user_num + 1
        CMD.set_active_num_to_db(time,true)
    end
    
end

function CMD.get_active_user_num()
    return ServerData.active_user_num
end

-- 设置日活跃 end ----------

function CMD.init_game_args()

    ServerData.game = {}
    for gameId,place in ipairs(ServerData.room_conf) do
        for pid,_ in ipairs(place) do
            local key = gameId * 100 + pid
            ServerData.game[key]   = {}
            ServerData.game[key].player_num = 0
            ServerData.game[key].room_num   = 0
            ServerData.game[key].init_pnum  = 0
        end
    end
end

function CMD.init()

    -- 获取当日 日活跃
    CMD.get_active_num_in_db()
    -- CMD.init_game_args()
    ----------------------------------------------4
    -- for i = 1, skynet.getenv("thread") do
    --     table.insert(ServerData.gen_room_table, skynet.newservice("gen_room"))
    -- end

end

function CMD.inject(filePath)
    require(filePath)
end

function CMD.inject_msgagent(filePath)
    for p_id,agent in pairs(ServerData.players) do
        skynet.send(agent, "lua", "server_will_shutdown")
        -- cluster.send(get_user_cluster(p_id), agent, 'lua','inject',filePath)
    end
end

skynet.register_protocol{
    name = "cmd",
    id = 16,
    pack = skynet.pack,
    unpack = skynet.unpack,
    dispatch = function (session, source, command, ...)
    end
}

skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    skynet.dispatch("lua", function(session, source, command, ...)
        local args = { ... }
        if command == "lua" then
            command = args[1]
            table.remove(args, 1)
        end
        local f = assert(CMD[command],command)
        skynet.ret(skynet.pack(f(table.unpack(args))))
    end)
    CMD.init()
end)


