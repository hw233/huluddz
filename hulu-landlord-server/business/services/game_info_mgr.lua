--
-- channel data collecter
--
local skynet = require "skynet"
local timer = require "timer"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
local NODE_NAME = skynet.getenv "node_name"
local COLL = require "config/collections"
local place_config = require("cfg/place_config")
require "pub_util"
local room_info = {}
local room_players_info = {}
local click_num = 0
local look_over_num = 0
local refresh_time = 0
function CMD.refresh_ad_data()
    if not check_same_day(refresh_time) then
        click_num = 0
        look_over_num = 0
        refresh_time = os.time()
    end
end
function CMD.add_click_num()
    CMD.refresh_ad_data()
    click_num = click_num + 1
end

function CMD.add_look_over_num()
    CMD.refresh_ad_data()
    look_over_num = look_over_num + 1
end

--获取视屏信息
function CMD.get_ad_info()
    return {click_num = click_num,look_over_num = look_over_num}
end

function CMD.inject(filePath)
    require(filePath)
end

function CMD.get_gameid(gametype)
    local gameId = gametype // 100
    local placeId = gametype % 100
    return gameId,placeId
end

--玩家加入房间
function CMD.join_all(gametype,player_num,players)
    local gameId,placeId = CMD.get_gameid(gametype)
    local tmpInfo = room_info[gameId]
    local tmpPlayersInfo = room_players_info[gameId]
    tmpInfo.detail[placeId].room_num = tmpInfo.detail[placeId].room_num + 1
    tmpInfo.detail[placeId].player_num = tmpInfo.detail[placeId].player_num + player_num
    if players then
        local detailPlayers = tmpPlayersInfo.detail[placeId].players
        for _,playerInfo in pairs(players) do
            detailPlayers[playerInfo.id] = playerInfo
        end
    end
end

--房间解散
function CMD.dissolve_room(gametype,player_num,playerIds)
    local gameId,placeId = CMD.get_gameid(gametype)
    local tmpInfo = room_info[gameId]
    local tmpPlayersInfo = room_players_info[gameId]
    tmpInfo.detail[placeId].room_num = tmpInfo.detail[placeId].room_num - 1
    tmpInfo.detail[placeId].player_num = tmpInfo.detail[placeId].player_num - player_num
    if playerIds then
        local detailPlayers = tmpPlayersInfo.detail[placeId].players
        for _,id in pairs(playerIds) do
            detailPlayers[id] = nil
        end
    end
end

-- 玩家离开
function CMD.player_leave(gametype,playerId)
    local gameId,placeId = CMD.get_gameid(gametype)
    local tmpInfo = room_info[gameId]
    local tmpPlayersInfo = room_players_info[gameId]
    tmpInfo.detail[placeId].player_num = tmpInfo.detail[placeId].player_num - 1
    local detailPlayers = tmpPlayersInfo.detail[placeId].players
    detailPlayers[playerId] = nil
end

function CMD.get_room_info()
    local onlineNum = skynet.call("agent_mgr", "lua", "GetPlayerOnlineNum")
    room_info.online_num = onlineNum or 0
    return room_info
end

function CMD.get_room_players_info(gameId, placeId)
    if not place_config[gameId][placeId] then
        return
    end
    return room_players_info[gameId].detail[placeId].players
end

function CMD.init()
    for id,item in ipairs(place_config) do
        if item[1] then
            room_info[id] = {game_des=item[1].game_des,detail={}}
            room_players_info[id] = {game_des=item[1].game_des,detail={}}
            for sid,_ in ipairs(item) do
                room_info[id].detail[sid] = {room_num = 0, player_num=0}
                room_players_info[id].detail[sid] = {players = {}}
            end
        end
    end
    CMD.refresh_ad_data()
    --table.print(room_players_info)
end

skynet.start(function ()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
    CMD.init()
end)