local skynet = require "skynet"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data


function CMD.get_room_info()
 	local ret = skynet.call("game_info_mgr","lua","get_room_info")

 	local onlineNum = skynet.call("agent_mgr","lua","GetPlayerOnlineNum")

 	ret.online_num = onlineNum or 0
 	return ret
end