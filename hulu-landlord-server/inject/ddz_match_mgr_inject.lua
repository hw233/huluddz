

local function getuv(f)
    local i = 1
    local ups = {}
    while true do
        local name, value = debug.getupvalue(f, i)
        if not name then
            break
        end
        ups[name] = { i, value }
        i = i + 1
    end
    return ups
end

local function uvjoin(f, old_f, old_uv)
    local i = 1
    while true do
        local name, value = debug.getupvalue(f, i)
        if not name then
            break
        end
        if old_uv[name] then
            debug.upvaluejoin(f, i, old_f, old_uv[name][1])
        end
        i = i + 1
    end
end


--斗地主匹配服务
local skynet = require "skynet"
local sharetable = require "skynet.sharetable"

local datax      = require "datax"
local arrayx     = require "arrayx"

local xy_cmd 				= require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data


print("start")

---comment
---@param gameType number
---@param gameSubType number 给黑房间用的
---@return table
ServerData.GetMatchQueueObj = function (gameType, gameSubType, userId)
	local gameSubTypeKey = gameSubType
	local isOpenRobot = true
	local idArrSort = nil
	local isRemoveMatchQueue = false -- 匹配完成后删除队列

	if gameSubType == GameSubType.Recycle or gameSubType == GameSubType.NewUser then
		isRemoveMatchQueue = true
		gameSubTypeKey = gameSubType .. "_" .. userId
	elseif gameSubType == GameSubType.MatchServer then
		local datas = sharetable.query("RoomMatchCfg") or {}
		local idArr = (datas[userId] or {})[gameType]
		if idArr and next(idArr) then
			isOpenRobot = false
			idArrSort = idArr
			isRemoveMatchQueue = true
			gameSubTypeKey = gameSubType .. "_" .. table.concat(idArr)
		end
	end

	local queueKey = gameType .. "_" .. (gameSubTypeKey or "")
	local obj = ServerData.MatchQueue[queueKey]
	if not obj then
		local queues = {}
		obj = {
			gameType = gameType,
			gameSubType = gameSubType,
			queues = queues,
		}
		ServerData.MatchQueue[queueKey] = obj

		for key, sData in pairs(datax.roomGroup[gameType]) do
			queues[sData.room_type] = {
				queue = {},
				lastAddRobotDt = 0,
			}
		end
		local PlayerNum = ServerData.PlayerNumObj[gameType] or 3

		local function match_ok(players, roomtype)
			if idArrSort and #idArrSort == #players then
				local arr = arrayx.select(idArrSort, function (index, id)
					return table.first(players, function (key, value)
						return value.id == id
					end)
				end)

				if not arrayx.findVal(arr, nil) then
					players = arr
				end
			end

			for _, p in ipairs(players) do
				p.startDt = nil
				ServerData.MatchUserArr[p.id] = nil
			end

			local conf = {
				gametype = gameType,
				roomtype = roomtype,
				max_player = PlayerNum
			}
			skynet.send("ddz_room_mgr", "lua", "create_room", conf, players)

			if isRemoveMatchQueue then
				ServerData.MatchQueue[queueKey] = nil
			end
		end

		function obj.AddPlayer(roomtype, player)
			local queueObj = queues[roomtype]
			table.insert(queueObj.queue, player)

			local function remove()
				for i,v in ipairs(queueObj.queue) do
					if v == player then
						if isRemoveMatchQueue then
							ServerData.MatchQueue[queueKey] = nil
						end
						return table.remove(queueObj.queue, i)
					end
				end
			end
			return remove
		end


		obj.Tick = function ()
			if gameSubType == GameSubType.Recycle or gameSubType == GameSubType.NewUser then
				obj.TickRecycle()
			else
				obj.TickDefault()
			end
		end
		
		--[[
			1. queueLen >= 6, 金币排序
			2. 如果 第一名 等待时间大于3秒
				a. 满3人的话 则匹配前3人
				b. 不满3人 且 等待时间大于5秒 召唤机器人
		]]
		obj.TickDefault = function ()
			for roomtype, queueObj in pairs(queues) do
				local queue = queueObj.queue
				local queueLen = #queue
				if queueLen >= PlayerNum * 2 then
					local createRoomNum = queueLen // PlayerNum
					local sortQueue = sort_by_gold(table.splice(queue, 1, PlayerNum * createRoomNum))
					for i = 1, createRoomNum do
						match_ok(table.splice(sortQueue, 1, PlayerNum), roomtype)
					end
				else
					local first = queue[1]
					local second = queue[2]
					if first then
						local roomLevelObj = datax.roomGroup[gameType]
						local sData = roomLevelObj[roomtype]
						local now = os.time()
						local waitTime = now - first.startDt
						if waitTime >= (sData.wait_time / 1000) then
							if queueLen >= PlayerNum then
								match_ok(table.splice(queue, 1, PlayerNum), roomtype)
							elseif isOpenRobot and (now - queueObj.lastAddRobotDt >= (sData.gap_time / 1000)) then
								--[[and ROOMTYPE(roomtype) == "xinshou"]]
								
								--主播？
								if first.is_anchor then
									if second and not second.is_anchor then
										queue[2] = first
										queue[1] = second
									end
								else
									skynet.send("ddz_robot_mgr", "lua", "CreateRobot", gameType, roomtype, 1, gameSubTypeKey)
									queueObj.lastAddRobotDt = now
								end
							end
						end
					end
				end
			end
		end

		obj.TickRecycle = function ()
			for roomtype, queueObj in pairs(queues) do
				local queue = queueObj.queue
				local queueLen = #queue
				local first = queue[1]
				if first then
					local roomLevelObj = datax.roomGroup[gameType]
					local sData = roomLevelObj[roomtype]
					local now = os.time()
					local waitTime = now - first.startDt
					if waitTime >= (sData.wait_time / 1000) then
						if queueLen >= PlayerNum then
							match_ok(table.splice(queue, 1, PlayerNum), roomtype)
						elseif (now - queueObj.lastAddRobotDt >= (sData.gap_time / 1000)) then
							local robotTagType = gameSubType == GameSubType.NewUser and RobotTagType.Pay or RobotTagType.Default
							skynet.send("ddz_robot_mgr", "lua", "CreateRobot", gameType, roomtype, 1, gameSubTypeKey, robotTagType)
							queueObj.lastAddRobotDt = now
						end
					end
				end
			end
		end
	
	end

	return obj
end


local fix_queue = function (queueObj)
    local TickDefaultOld = queueObj.TickDefault
	local uvOld = getuv(TickDefaultOld)

	-- local queues, PLAYERNUM, sort_by_gold, match_ok, enable_robot, gametype, name
    local queues, PlayerNum, sort_by_gold, match_ok, gameType, isOpenRobot, gameSubTypeKey

    queueObj.TickDefault = function ()
        for roomtype, queueObj in pairs(queues) do
            local queue = queueObj.queue
            local queueLen = #queue
            if queueLen >= PlayerNum * 2 then
                local createRoomNum = queueLen // PlayerNum
                local sortQueue = sort_by_gold(table.splice(queue, 1, PlayerNum * createRoomNum))
                for i = 1, createRoomNum do
                    match_ok(table.splice(sortQueue, 1, PlayerNum), roomtype)
                end
            else
                local first = queue[1]
                local second = queue[2]
                if first then
                    local roomLevelObj = datax.roomGroup[gameType]
                    local sData = roomLevelObj[roomtype]
                    local now = os.time()
                    local waitTime = now - first.startDt
                    if waitTime >= (sData.wait_time / 1000) then
                        if queueLen >= PlayerNum then
                            match_ok(table.splice(queue, 1, PlayerNum), roomtype)
                        elseif isOpenRobot and (now - queueObj.lastAddRobotDt >= (sData.gap_time / 1000)) then
                            --[[and ROOMTYPE(roomtype) == "xinshou"]]
                            
                            --主播？
                            if first.is_anchor then
                                if second and not second.is_anchor then
                                    queue[2] = first
                                    queue[1] = second
                                end
                            else
                                skynet.send("ddz_robot_mgr", "lua", "CreateRobot", gameType, roomtype, 1, gameSubTypeKey)
                                queueObj.lastAddRobotDt = now
                            end
                        end
                    end
                end
            end
        end
    end

    uvjoin(queueObj.TickDefault, TickDefaultOld, uvOld)
end

local queueObjOld = ServerData.GetMatchQueueObj(GameType.NoShuffle, GameSubType.Default)

fix_queue(queueObjOld)


print("end")
-- inject :00000020 inject/activity_mgr_inject.lua