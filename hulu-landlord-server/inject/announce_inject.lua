-- inject :0000001e inject/qwe_inject.lua

local skynet = require "skynet"
local common = require "common_mothed"

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

print("start")

ServerData.gonggaoFunc = function ()
    local players = skynet.call("agent_mgr", "lua", "GetPlayers")

    if players then
        print("start111")

        for id, value in pairs(players) do
            common.send_client(id, "AWorldAnnounce", {content = "亲爱的各位玩家，我们将于今日23：50停服更新，本次更新预计需要5分钟；届时请大家不要进行对局，谢谢。"})
        end
    end

    skynet.timeout(30 * 100, ServerData.gonggaoFunc)
end

ServerData.gonggaoFunc()


print("end")