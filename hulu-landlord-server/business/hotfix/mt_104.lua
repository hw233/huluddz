local skynet = require "skynet"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data


-- 模糊匹配/精准匹配
function CMD.fuzzy_matching(player)
	-- 玩家已经在匹配中
	if CMD.check_in_match(player.id) then
		return false
	end
	
	if player.dbinfo.isNew < 3 then
		CMD.create_room({player},player.place_id,true)
		return
	end
	local gold = player.dbinfo.gold
	local place_ids,place_id

	-- 精准匹配
	if player.place_id then
		place_ids = {player.place_id}
		place_id = player.place_id
	else -- 模糊匹配
		local gameId = player.gameId
		place_ids = CMD.get_match_type(gameId,gold)
		-- 没找到合适的匹配类型直接返回
		if not place_ids then
			return false
		end
		place_id = place_ids[1]
	end
	player.match_time = os.time() -- 玩家开始匹配时间
	player.place_ids = place_ids
	for _,place_id in ipairs(place_ids) do	
		if pack then
			pack.have_count = pack.have_count - 1
		end

		if not ServerData.fm_players[place_id] then
			ServerData.fm_players[place_id] = {}
			ServerData.fm_players[place_id].players = {}
		end
		-- 根据金币数量决定插入顺序
		local is_insert = false

		for i,p in ipairs(ServerData.fm_players[place_id]) do
			if p.dbinfo.gold > gold then
				table.insert(ServerData.fm_players[place_id],i,player)
				is_insert = true
				break
			end
		end
		-- 
		if not is_insert then
			table.insert(ServerData.fm_players[place_id],player)
		end
		
	end
end