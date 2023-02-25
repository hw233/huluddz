--matching_mgr
--匹配服务
local skynet = require "skynet"
local sharetable = require "skynet.sharetable"
local skynet_queue = require "skynet.queue"
local robot_info = require 'cfg.cfg_robot'
local COLL = require "config/collections"
local timer = require "timer"
require "pub_util"
require "table_util"
require 'define'
-- local patterns  = require "patterns"

local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

ServerData.place_config = require "cfg/place_config"
ServerData.fm_players = {}

ServerData.join_players = {} -- 正在加入房間中的玩家
ServerData.interval = 1 -- 模糊匹配检查间隔
ServerData.clear_interval = 10  -- 清除 【正在加入房間中的玩家】 记录
ServerData.match_invoke = nil -- 模糊匹配调度器

ServerData.clear_invoke  = nil -- 清楚 【正在加入房間中的玩家】 记录 定时器
-- ServerData.timeout = 10 -- 匹配超时,直接加入机器人
ServerData.blacklist = {}
ServerData.HaveMatch_players = {} --已经被内部玩家匹配过的人
ServerData.markMatchNum = 5
ServerData.make_card_users = {}

--2v2---
--[[
	fm_teams ={
		[place_id]=
		{
			{
				teamid = teamid,
				members={ 
					player1,
					p2 },
				count = #teammembers,
				gold = gold,
				match_time = skynet.now(), -- team开始匹配时间
				place_ids =  place_ids
			}
			...
		}
		...
	}
]]
ServerData.fm_teams ={}  --2v2等待匹配的team 
ServerData.match_invoke2v2 = nil -- 2v2匹配调度器
ServerData.join_teams = {} -- 正在加入房間中的玩家

local robot_pInfos = {}

--初始化离线10天以上玩家的数据表
function CMD.init_robot_pInfo()
	local temp_players = skynet.call(get_db_mgr(),'lua','find_all',COLL.USER,{last_time={['$lte']=(os.time()-ONE_DAY*10)},
		['playinfo.total']={['$gte']=300}},
		{_id = false,id=true,nickname=true,headimgurl=true,ip=true,hall_frame=true,sex=true,
		headframe=true,half_photo=true},{{last_time = -1}},2000)
	--print('==============初始化离线10天以上玩家的数据表',#temp_players)
	--table.print(temp_players)
	for _,p_info in ipairs(temp_players) do
		local randInfo = robot_info[math.random(#robot_info)]
		local onePInfo = {
							id 				= p_info.id,
							nickname		= p_info.nickname,
							headimgurl		= p_info.headimgurl,
							ip 				= p_info.ip,
							hall_frame  	= p_info.headframe or 300001,
							sex 			= randInfo.sex or 1,
							half_photo 		= p_info.half_photo,
							human_drees 	= randInfo.human_drees,
							pet_info 		= randInfo.pet_info,
							prestige 		= p_info.prestige or 1000,
							seg_prestige 	= p_info.seg_prestige or 1000,
						}
		table.insert(robot_pInfos,onePInfo)
	end
end
--初始化各配置table
function CMD.init_place_tbl()

	ServerData.search_order = {}
	for gameId,place in ipairs(ServerData.place_config) do
		for placeId,_ in ipairs(place) do
			table.insert(ServerData.search_order,gameId * 100 + placeId)
		end
	end
end

function CMD.get_roomconf(gameType)
	local gameId = gameType // 100
	local placeId = gameType % 100
	return ServerData.place_config[gameId][placeId]
end

-- 
function CMD.add_blacklist(pId)
	-- TODO
	-- 后台添加玩家至黑名单中
	table.insert(ServerData.blacklist,pId)
end

function CMD.remove_blacklist(pId)
	for i=#ServerData.blacklist,1,-1 do
		if ServerData.blacklist[i] == pId then
			table.remove(ServerData.blacklist,i)
		end
	end
end

function CMD.get_blacklist_in_db()
	-- TODO
	-- 服务启动时从数据库中获取黑名单玩家
	local rt = skynet.call(get_db_mgr(), "lua", "get_blacklist")
	-- local rt = db_mgr.req.get_blacklist()
	if rt then
		for _,pack in ipairs(rt) do
			table.insert(ServerData.blacklist,pack.gameid)
		end
	end
end

--玩家在黑名单
function CMD.player_in_blacklist(pId)
	for i=1,#ServerData.blacklist do
		if ServerData.blacklist[i] == pId then
			return true
		end
	end
end

--获取黑名单
function CMD.get_blacklist_to_msgagent()
	return ServerData.blacklist
end

function CMD.GetRandomIndex(lastIndexs,isMark)
	local maxIndex = 100
	if isMark and #robot_pInfos > 1 then
		maxIndex = #robot_pInfos
	end
	local index = math.random(1,maxIndex)

	local checkExist = function(idx,lastidxs)
		for _,v in ipairs(lastidxs) do
			if v == idx then
				return true
			end
		end
	end
	while checkExist(index,lastIndexs) do
		index = math.random(1,maxIndex)
	end
	return index
end

function CMD.GetRandomRoBotInfo(count,isMark)
	local lastIndexs = {}
	local randIndex
	local infos = {}
	local tempInfo = robot_info
	if isMark and #robot_pInfos > 100 then
		tempInfo = robot_pInfos
	end
	for i=1,count do
		randIndex = CMD.GetRandomIndex(lastIndexs,isMark)
		--print('==============加入等值===',randIndex)
		table.insert(lastIndexs,randIndex)
		table.insert(infos,tempInfo[randIndex])
	end
	--table.print(infos)
	return infos
end

function CMD.create_room(players,gameType,needAI,need_type,isMark,make_cards_conf)
	skynet.fork(function ()
		local pack = CMD.get_roomconf(gameType)

		local conf = {
			playerCount = pack.playerCount,
			gameType = gameType,
			cap = pack.cap,
			gang_pay = pack.gang_pay,
			ticket = pack.ticket,
			base_score = pack.base_score,
			gameName = pack.game_name,
			prestige = pack.prestige,
			need_type = need_type,
			make_cards_conf = make_cards_conf,
			-- maxfan = pack.maxfan -- 2v2用 最大番数
		}

		if needAI then
			local diff = pack.playerCount - #players
			local robots = CMD.GetRandomRoBotInfo(diff,isMark)
			for i=1,diff do

				--确认AI是哪个脚本				
				local name = "ai_"..pack.game_name
				print("get ai name =",name)			
				if io.exists(string.format("./business/ai/%s.lua",name)) then
					-- print("====debug qc==== 查找AI脚本 成功！" )
				else
					-- print("====debug qc==== 查找AI脚本 失败！" )
					name = "ai_hzmj_blood"
				end
				print("final : get ai name =",name)				
				local ai = skynet.newservice(name)
				print('==============创建AI====',robots[i],gameType,isMark)
				local result,p = pcall(skynet.call,ai,'lua','init',robots[i],gameType,isMark)
				if not result then
					print("get ai error")
				end
				table.insert(players,p)
			end
		end
		local _, room_server = skynet.call("agent_mgr", "lua", "create_room", conf)
		local player_pack = {}
		for _, p in ipairs(players) do
			-- print('================game.player 玩家信息组装============')
			-- table.print(p)
			table.insert(player_pack,{
				id = p.id,
				agent = p.agent,
				dbinfo = p.dbinfo,
				address = p.address,
				pet_skills = p.pet_skills,
				prestige = p.prestige,
				pet_info = p.pet_info,
				robot = p.robot,
				luck_start_ct = p.luck_start_ct				
			})

		end
		-- table.print(player_pack)

		--2v2模式下 交换2/3座位
		if pack.game_name == "qc2v2_hzmj_blood3" then
			print("====debug qc==== 2v2 交换2/3座位" )
			local tmp = player_pack[2]
			player_pack[2] = player_pack[3]
			player_pack[3] = tmp
		end
		
		skynet.send(room_server,'lua','all_join',player_pack)
	end)
end


function CMD.remove_player_in_match(id)
	local isRemove = false
	for _,packs in pairs(ServerData.fm_players) do
		for j= #packs,1,-1 do
			if packs[j].id == id then
				table.remove(packs,j)
				isRemove = true
				break
			end
		end
	end

	--移除下做牌玩家
	for conf, players in pairs(ServerData.make_card_users) do
		for pos, p in ipairs(players) do
			if p.id == id then
				table.remove(players, pos)
				isRemove = true
				break
			end
		end
		if #players == 0 then
			ServerData.make_card_users[conf] = nil
			break
		end
	end
	return isRemove
end


-- 移除玩家在2v2匹配结束
function CMD.remove_in_match_end2v2(key,teamids)
	local current_time = os.time()
	for _,p in ipairs(teamids) do
		for j= #ServerData.fm_teams[key],1,-1 do
			if ServerData.fm_teams[key][j].teamid == p then
				table.remove(ServerData.fm_teams[key],j)

				--通知team2v2_mgr更新房间状态
				local ret =skynet.call("team2v2_mgr","lua","SetTeamStatus",p,TEAM_STATUS.GAMEING)
				if not ret then
					print("====debug qc==== 通知更新 SetTeamStatus 失败 " )
				end
				ServerData.join_teams[p] = current_time
			end				
		end			
	end



	print("====debug qc==== remove_in_match_end2v2！join time 倒计时 " )
	table.print(ServerData.join_teams)
end

-- 移除玩家在匹配结束
function CMD.remove_in_match_end(players)
	local current_time = os.time()
	for _,p in ipairs(players) do
		local place_ids = p.place_ids
		for _,key in ipairs(place_ids) do
			for j= #ServerData.fm_players[key],1,-1 do
				if ServerData.fm_players[key][j].id == p.id then
					table.remove(ServerData.fm_players[key],j)
					break
				end
			end
		end
		ServerData.join_players[p.id] = current_time
	end
end

--检测是否能加入这个匹配
function CMD.checkMatchMark(packMatchMark,playerMatchMark)
	for _,plMarkId in ipairs(playerMatchMark) do
		for _,packMarkId in ipairs(packMatchMark) do
			if plMarkId == packMarkId then
				return false
			end
		end
	end
	return true
end

function CMD.gen_match_group(p,packs,need_count,noCreate)
	local in_blacklist = CMD.player_in_blacklist(p.id)
	local pack
	local joined = false
	if #packs == 0 and not noCreate then
		pack = {players = {p},have_black = in_blacklist,MatchMarkTbl = {}}
		for _,markId in ipairs(p.dbinfo.matchMark) do
			table.insert(pack.MatchMarkTbl,markId)
		end
		table.insert(packs,pack)
		joined = true
	else
		for j=1,#packs do
			pack = packs[j]
			-- 匹配中没有黑名单玩家,或要加入的玩家不是黑名单玩家;
			if #pack.players < need_count and (not pack.have_black or not in_blacklist)
				and CMD.checkMatchMark(pack.MatchMarkTbl,p.dbinfo.matchMark) then
				table.insert(pack.players,p)
				for _,markId in ipairs(p.dbinfo.matchMark) do
					table.insert(pack.MatchMarkTbl,markId)
				end
				pack.have_black = pack.have_black or in_blacklist
				joined = true
				break
			end
		end

		if not joined and not noCreate then
			pack = {players = {p},have_black = in_blacklist,MatchMarkTbl = {}}
			table.insert(packs,pack)
			joined = true
		end
	end
end

--匹配处理器
function CMD.process_match()
	for _,key in ipairs(ServerData.search_order) do
		local count = ServerData.fm_players[key] and #ServerData.fm_players[key] or 0
		local roomConf = CMD.get_roomconf(key)
		local need_count = roomConf.playerCount
		if count > 0 then
			-- 满足游戏需要人数
			if count >= need_count then
				-- 存储游戏中需要数量玩家一组
				local packs = {}
				for i = count,1,-1 do
					local p = ServerData.fm_players[key][i]
					if p then
						p.place_id = key
						CMD.gen_match_group(p,packs,need_count)
					end
				end
				local end_count = 0
				for _,pack in ipairs(packs) do
					if #pack.players >= need_count then
						CMD.create_room(pack.players,key)
						-- 移除创建房间的玩家
						CMD.remove_in_match_end(pack.players)
						end_count = end_count + need_count
					end
				end
				count = count - end_count
			end
			local timeout = math.random(200, 500)
			if count > 0 then  -- 如果有玩家超时，则直接匹配机器人
				local packs = {}
				local curr_time = skynet.now()
				for i=count,1,-1 do
					local p = ServerData.fm_players[key][i]
					if p then
						p.place_id = key
						-- 玩家匹配超时
						if curr_time - p.match_time >= timeout then
							CMD.gen_match_group(p,packs,need_count)
						end
					end
				end
				if #packs > 0 then -- 有超时的玩家
					for i=count,1,-1 do -- 先添加正常用户
						local p = ServerData.fm_players[key][i]
						p.place_id = key
						if p and curr_time - p.match_time < timeout then
							CMD.gen_match_group(p,packs,need_count,true)
						end
					end
					local pCount = 0
					for _,pack in ipairs(packs) do
						if #pack.players >= need_count then
							CMD.create_room(pack.players,key)
							-- 移除创建房间的玩家
							CMD.remove_in_match_end(pack.players)
						elseif pCount and pCount < 20 then
							CMD.create_room(pack.players,key,true)
							CMD.remove_in_match_end(pack.players)
						end
					end
				end
			end
		end
	end
end



function CMD.gen_match_teams_2v2(teams,packs,need_count)
	local teamsLen = #teams
	local t1 = teams[1]
	-- local in_blacklist = CMD.player_in_blacklist(p.id)
	local pack
	local joined = false
	if #packs == 0 then
		pack = {players = t1.members,teams = {t1.teamid}}
		if teamsLen==2 then
			table.insert(pack.players,teams[2].members[1])
			table.insert(pack.teams,teams[2].teamid)
		end
		table.insert(packs,pack)
		joined = true
	else
		for j=1,#packs do
			pack = packs[j]			
			local need_num = need_count - #pack.players
			if need_num==2 and t1.count==2 then
				--2 = 2 匹配成功
				table.insert(pack.players,t1.members[1])
				table.insert(pack.players,t1.members[2])
				table.insert(pack.teams,t1.teamid)
				joined = true
				print("====debug qc==== 真 2v2 配对成功！" )
				table.print(pack)
			elseif need_num == 2 and teamsLen==2 then
				-- 2 = 1+1 匹配成功
				table.insert(pack.players,teams[1].members[1])
				table.insert(pack.players,teams[2].members[1])
				table.insert(pack.teams,teams[1].teamid)
				table.insert(pack.teams,teams[2].teamid)
				joined = true
				print("====debug qc==== 真 2 = 1+1 配对成功！" )
				table.print(pack)			
			end			
		end		
	end
	-- 配对构成packs 
	-- 等待后续填入人机
end


--匹配填坑
--优先 2=2 
--其次 2=1+1
function CMD.gen_match_group_2v2(key,packs,need_count)
	--2人坑
	local m_team2 ={} -- {t1,t2,t3...}
	--1+1坑
	local m_team1_1 ={}  --{{t1,t2},{t2,t3}...}
	local index1_1 =1

	for _,t in ipairs(ServerData.fm_teams[key]) do
		for _,p in ipairs(t.members) do
			p.place_id = key
		end		
		
		if t.count ==2 then
			table.insert(m_team2,t)
		elseif m_team1_1[index1_1] ==nil then
			m_team1_1[index1_1]={t}		
		elseif #m_team1_1[index1_1] <2 then
			table.insert(m_team1_1[index1_1],t)	
			index1_1 = index1_1 +1
		end
	end

	print("====debug qc==== gen_match_group_2v2！" ,2)
	-- table.print(m_team2)
	for _,t in ipairs(m_team2) do 
		CMD.gen_match_teams_2v2({t},packs,need_count)
	end

	print("packs len : " ,#packs)
	-- table.print(packs)

	print("====debug qc==== gen_match_group_2v2！" ,3)
	-- table.print(m_team1_1)
	for _,t in ipairs(m_team1_1) do 
		CMD.gen_match_teams_2v2(t,packs,need_count)
	end

	print("packs len : " ,#packs)
	-- table.print(packs)

end

--2v2匹配
function CMD.process_match2v2()
	for _,key in ipairs(ServerData.search_order) do
		local count = ServerData.fm_teams[key] and #ServerData.fm_teams[key] or 0
		local roomConf = CMD.get_roomconf(key)
		local need_count = roomConf.playerCount
		
		if count > 0 then
				--test匹配方法
				-- local packs = {}
				-- CMD.gen_match_group_2v2(key,packs,need_count)
				-- if #packs>=1 then
				-- 	CMD.remove_in_match_end2v2(key,packs[1].teams)
				-- end
				

			-- 满足游戏需要人数
			if count >= need_count then
				-- 对匹配池的队伍(按照房主gold排序)预分组
				local packs = {}
				CMD.gen_match_group_2v2(key,packs,need_count)
				
				local end_count = 0
				for _,pack in ipairs(packs) do
					if #pack.players >= need_count then
						CMD.create_room(pack.players,key)
						-- 移除创建房间的玩家
						CMD.remove_in_match_end2v2(key,pack.teams)
						end_count = end_count + need_count
					end
				end
				count = count - end_count
			end
			local timeout = math.random(300, 500)
			print("====debug qc==== 有落单的 " , count)
			if count > 0 then  -- 如果有玩家超时，则直接匹配机器人
				local packs = {}
				local curr_time = skynet.now()
				for i=count,1,-1 do
					local p = ServerData.fm_teams[key][i]
					if p then
						-- p.place_id = key
						-- 玩家匹配超时= 原装team 装入pack 直接填入机器人
						if curr_time - p.match_time >= timeout then
							CMD.gen_match_teams_2v2({p},packs,need_count)
						else
							print("====debug qc==== 落单玩家 等待下一轮匹配")
						end
					end
				end
				if #packs > 0 then -- 有超时的玩家
					-- for i=count,1,-1 do -- 先添加正常用户
					-- 	local t = ServerData.fm_teams[key][i]
					-- 	t.place_id = key
					-- 	if t and curr_time - t.match_time < timeout then
					-- 		CMD.gen_match_group(t,packs,need_count,true)
					-- 	end
					-- end

					local pCount = 0
					for _,pack in ipairs(packs) do
						if #pack.players >= need_count then
							-- 原装team 1,2人 不会进入这里
							CMD.create_room(pack.players,key)
							-- 移除创建房间的玩家
							CMD.remove_in_match_end2v2(key,pack.teams)
						elseif pCount and pCount < 20 then
							CMD.create_room(pack.players,key,true)
							CMD.remove_in_match_end2v2(key,pack.teams)
						end
					end
				end
			end
		end
	end
	-- print("====debug qc==== 匹配一轮 over" )
end

function CMD.create_check_match()
	ServerData.match_invoke = timer.create(100 * ServerData.interval,function()
		CMD.process_match()
	end,-1)
	ServerData.match_invoke2v2 = timer.create(500 * ServerData.interval,function()
		CMD.process_match2v2()
	end,-1)
end

function CMD.clear_timeout_joined()
	local current_time = os.time()
	for id,joined_time in pairs(ServerData.join_players) do
		if current_time - joined_time >= ServerData.clear_interval then
			ServerData.join_players[id] = nil
		end
	end
end

function CMD.create_check_timeout_joined()
	ServerData.clear_invoke = timer.create(100 * ServerData.clear_interval,function()
		CMD.clear_timeout_joined()
	end,-1)
end

-- 检查玩家是否已经参与匹配
function CMD.check_in_match(pid)
	for _,players in pairs(ServerData.fm_players) do
		for _,p in ipairs(players) do
			if p.id == pid then
				return true
			end
		end
	end

	for _, players in pairs(ServerData.make_card_users) do
		for _, p in ipairs(players) do
			if p.id == pid then
				return true
			end
		end
	end

	-- 防止玩家匹配完成，加入房间时重入匹配
	local joined_time = ServerData.join_players[pid]
	if joined_time and os.time() - joined_time <= 5 then
		return true
	end

	return false
end

-- 获取玩家可以参与的匹配类型
function CMD.get_match_type(gameId,gold)
	local place_ids = {}
	for i = 4, 1, -1 do
		local gType = gameId * 100 + i
		local limit = CMD.get_roomconf(gType)
		if limit then
			-- 玩家金币大于下限，小于上限
			if gold >= limit.need_min and
				(limit.need_max == 0 or gold <= limit.need_max) then
				table.insert(place_ids,gType)
			end
		end
	end
	if #place_ids == 0 then
		return false
	end

	return place_ids
end

--更改不匹配玩家参数
function CMD.setMarkMatchNum(num)
	print('==========更改不匹配玩家参数',num,type(string))
	if num then
		ServerData.markMatchNum = tonumber(num)
	end
end

local function get_one_robot(place_id)
	local isMark = true
	local robotInfos = CMD.GetRandomRoBotInfo(1,true)
	local name = "ai_hzmj_blood"
	print("get ai name =",name)
	local ai = skynet.newservice(name)
	local result,p = pcall(skynet.call,ai,'lua','init', robotInfos[1], place_id, isMark)
	if not result then
		print("get ai error")
	end
	return p
end

local function try_start_make_card_test(users, conf)
	local conf_count = #(conf.id_table)
	if #users < conf_count then
		return
	end
	local user = users[1]
	if not user then
		return
	end
	local place_id = user.place_id
	local pack = CMD.get_roomconf(place_id)
	local need_count = pack.playerCount
	local robot_count = need_count - conf_count
	for i = 1, robot_count do
		local robot = get_one_robot(place_id)
		table.insert(users, robot)
	end
	if #users == need_count then
		CMD.create_room(users, place_id, false, nil, nil, conf)
		ServerData.make_card_users[conf] = nil
	end
end


--队伍已在匹配中
function CMD.check_in_match2v2(teamid)
	for _,key_team in pairs(ServerData.fm_teams) do
		for _,t in ipairs(key_team) do
			if t.teamid == teamid then
				return true
			end
		end
	end

	-- 防止玩家匹配完成，加入房间时重入匹配
	local joined_time = ServerData.join_teams[teamid]
	if joined_time and os.time() - joined_time <= 5 then
		return true
	end

	return false
end

--qc2v2匹配
function CMD.matching_qc2v2(playerlist,teamid,teammembers)

	-- 玩家已经在匹配中
	if CMD.check_in_match2v2(teamid) then
		print("====debug qc==== 在匹配中 不能重复操作",teamid )
		return false
	end
	local player = playerlist[1]
	local p2 = playerlist[2]

	local gold = player.dbinfo.gold
	local place_ids

	-- 精准匹配
	if player.place_id then
		place_ids = {player.place_id}
	else -- 模糊匹配
		local gameId = player.gameId
		place_ids = CMD.get_match_type(gameId,gold)
		-- 没找到合适的匹配类型直接返回
		if not place_ids then
			return false
		end
	end

	--匹配的team基本单元 
	local team_cell = {
		teamid = teamid,
		members = playerlist,
		count = #teammembers,
		gold = gold,
		match_time = skynet.now(), -- team开始匹配时间
		place_ids =  place_ids
	}

	player.place_ids = place_ids
	for _,place_id in ipairs(place_ids) do
		if not ServerData.fm_teams[place_id] then
			ServerData.fm_teams[place_id] = {}
		end

		-- 根据金币数量决定插入顺序
		local is_insert = false
		for i,p in ipairs(ServerData.fm_teams[place_id]) do	
			if p.gold > gold then
				table.insert(ServerData.fm_teams[place_id],i,team_cell)
				is_insert = true
				break
			end
		end
		if not is_insert then
			table.insert(ServerData.fm_teams[place_id],team_cell)
		end
	end
	-- print("====debug qc==== 2v2 匹配数据录入成功" )
	-- table.print(ServerData.fm_teams)
end

-- 模糊匹配/精准匹配
function CMD.fuzzy_matching(player)
	-- 玩家已经在匹配中
	if CMD.check_in_match(player.id) then
		return false
	end

	--做牌特殊用户需要匹配到一起
	local env = skynet.getenv("env")
	env = env or "publish"
	if (env == "debug" or env == "local") then
		local conf = get_make_cards_conf(player) -- TODO:新的方法为 cardx.getRoomCardDataCfg 返回数据不一样
		if conf then
			local players = ServerData.make_card_users[conf] or {}
			table.insert(players, player)
			ServerData.make_card_users[conf] = players
			try_start_make_card_test(players, conf)
			return
		end
	end


	--新手匹配前3次
	if player.dbinfo.isNew < 3 then
		if not player.dbinfo.markNum or player.dbinfo.markNum ~= 1 then
			CMD.create_room({player},player.place_id,true)
			return
		end
	end

	local gold = player.dbinfo.gold
	local place_ids

	-- 精准匹配
	if player.place_id then
		place_ids = {player.place_id}
	else -- 模糊匹配
		local gameId = player.gameId
		place_ids = CMD.get_match_type(gameId,gold)
		-- 没找到合适的匹配类型直接返回
		if not place_ids then
			return false
		end
	end
	player.match_time = skynet.now() -- 玩家开始匹配时间
	player.place_ids = place_ids
	for _,place_id in ipairs(place_ids) do
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
		if not is_insert then
			table.insert(ServerData.fm_players[place_id],player)
		end
	end
end

function CMD.userafk(id)
	return CMD.remove_player_in_match(id)
end

--移除匹配队列
function CMD.remove_matching(id)
	return CMD.remove_player_in_match(id)
end

--移除2v2匹配队列
function CMD.remove_matching2v2(teamid)
	local isRemove = false
	for _,teams in pairs(ServerData.fm_teams) do
		for j= #teams,1,-1 do
			if teams[j].teamid == teamid then
				table.remove(teams,j)
				isRemove = true
				break
			end
		end
	end
	
	return isRemove
end



function CMD.init()
	CMD.init_place_tbl()
	CMD.init_robot_pInfo()
	CMD.create_check_match()
	CMD.create_check_timeout_joined()
end

function CMD.inject(filePath)
    require(filePath)
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, command, ...)

        local args = { ... }
        if command == "lua" then
            command = args[1]
            table.remove(args, 1)
        end
        local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(table.unpack(args))))
    end)
    CMD.init()
end)
