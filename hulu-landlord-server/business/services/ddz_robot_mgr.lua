local skynet = require "skynet"
local ec = require "eventcenter"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local common = require "common_mothed"

local xy_cmd 				= require "xy_cmd"
local CMD, ServerData 		= xy_cmd.xy_cmd, xy_cmd.xy_server_data

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

ServerData.DbData = nil

ServerData.len = 10
ServerData.robotCfgIdArr = arrayx.orderBy(table.select(datax.robot, function (key, value)
	return value.id
end), function (id)
	return id
end)
ServerData.robotCfgLen = #ServerData.robotCfgIdArr

ServerData.robotIndex = 1
ServerData.robotDatas = {}

ServerData.robotDataGroup = {}
ServerData.robotMapDatas = {}

ServerData.robotUseInfo = {}

ServerData.versionsKey = "1000"
ServerData.goldRange = nil
ServerData.headArr = {}
ServerData.infoBgArr = nil
ServerData.headFramArr = {}
ServerData.clockFrameArr = {}
ServerData.gameChatFramArr = {}
ServerData.vipRange = nil
ServerData.heroIdArr = {}


ServerData.getRobotId = function (cfgId, idx, robotTagType)
	return "robot" .. cfgId .. "_" .. idx .. "_" .. robotTagType
end

ServerData.getRobotTagType = function (id)
	local arr = string.split(id, "_")
	return tonumber(arr[3])
end

ServerData.init = function ()
	local dbKey = "ddz_robot_mgr"
	ServerData.DbData = common.GetServerSeting(dbKey) or {}
	ServerData.robotIndex = ServerData.DbData.robotIndex or 1

	skynet.fork(function ()
		while true do
			skynet.sleep(100)
			ServerData.DbData.robotIndex = ServerData.robotIndex
			common.SetServerSeting(dbKey, ServerData.DbData)
		end
	end)


	ServerData.versionsKey = datax.globalCfg[190001].version

	ServerData.goldRange = {table.minNum(datax.roomCost, function (key, value)
		return value.robot_corn_least
	end), table.maxNum(datax.roomCost, function (key, value)
		return value.robot_corn_max
	end)}

	local defHeroIdArr = {datax.globalCfg[101002][1].id, datax.globalCfg[101003][1].id}
	ServerData.defHeroIdArr = defHeroIdArr
	
	local heroIdArr = datax.globalCfg[190002]
	local heroIdArrPay = arrayx.where(heroIdArr, function (i, value)
		return not arrayx.findVal(defHeroIdArr, value.id)
	end)
	local heroIdArrNotPay = arrayx.where(heroIdArr, function (i, value)
		return arrayx.findVal(defHeroIdArr, value.id)
	end)

	ServerData.heroIdArr[RobotTagType.Default] = heroIdArr

	ServerData.heroIdArr[RobotTagType.Pay] = heroIdArrPay
	ServerData.clockFrameArr[RobotTagType.Pay] = datax.globalCfg[190003]
	ServerData.gameChatFramArr[RobotTagType.Pay] = datax.globalCfg[190004]
	ServerData.headFramArr[RobotTagType.Pay] = datax.globalCfg[190005]
	ServerData.headArr[RobotTagType.Pay] = datax.globalCfg[190006]

	ServerData.heroIdArr[RobotTagType.NotPay] = heroIdArrNotPay
	ServerData.clockFrameArr[RobotTagType.NotPay] = datax.globalCfg[190007]
	ServerData.gameChatFramArr[RobotTagType.NotPay] = datax.globalCfg[190008]
	ServerData.headFramArr[RobotTagType.NotPay] = datax.globalCfg[190009]
	ServerData.headArr[RobotTagType.NotPay] = datax.globalCfg[190010]



	ServerData.infoBgArr = table.toArray(datax.fashionTypeGroup[FashionType.InfoBg])
	ServerData.vipRange = {0, 5}

	ServerData.initRobot()

	ec.sub({type = "robot_gameover"}, function (eventObj)
		local robotData = ServerData.robotDatas[eventObj.robotId]
		if robotData then
			local robotTagType = ServerData.getRobotTagType(eventObj.robotId)
			local groupDataArr = ServerData.robotDataGroup[robotTagType][robotData.cfgId]
			table.insert(groupDataArr, eventObj.robotId)

			ServerData.robotUseInfo[robotTagType] = (ServerData.robotUseInfo[robotTagType] or 0) - 1
		end
	end)

end

ServerData.initRobot = function ()
	local id
	local groupDataArr
	for key, robotTagType in pairs(RobotTagType) do
		ServerData.robotDataGroup[robotTagType] = {}
		for index, sData in ipairs(datax.robot) do
			groupDataArr = {}
			ServerData.robotDataGroup[robotTagType][sData.id] = groupDataArr

			for i = 1, ServerData.len do
				id = ServerData.getRobotId(sData.id, i, robotTagType)
				table.insert(groupDataArr, id)

				ServerData.robotMapDatas[id] = {cfgId = sData.id, index = i}
			end
		end
	end
end

ServerData.getRobotData = function (id)
	local robotTagType = ServerData.getRobotTagType(id)

	local data = ServerData.robotDatas[id]
	if not data then
		local mapData = ServerData.robotMapDatas[id]
		-- 兼容旧数据
		if not mapData and not robotTagType then
			mapData = ServerData.robotMapDatas[id .. "_" .. RobotTagType.Default]
		end
		if not mapData then
			return nil
		end

		local sData = datax.robot[mapData.cfgId]
		data = dbx.get(TableNameArr.ServerRobot, {id = id, cfgId = sData.id})
		data = data or {}

		data.id = data.id or id
		data.robotTagType = robotTagType
		data.cfgId = sData.id
		data.isRobot = true

		data.gold = math.random(ServerData.goldRange[1], ServerData.goldRange[2])
		data.nickname = sData.name

		data.lv = data.lv or math.random(table.unpack(sData.title_lv))
		if not data.vip or data.vip > ServerData.vipRange[1] then
			data.vip = math.random(table.unpack(ServerData.vipRange))
		end
		if not data.gourdLv or data.gourdLv > sData.gourd_vine_lv[1] then
			data.gourdLv = math.random(table.unpack(sData.gourd_vine_lv))
		end

		data.like = data.like or 0
		data.isCloseShowGameRecord = true

		data.location_open = data.location_open or false
		-- data.lvMax = math.min(math.random(0, 1)+data.lv, 37)
		data.lvSeasonMax = data.lvSeasonMax or math.min(math.random(0, 1)+data.lv, 37)
		if not data.gameCountSum  then
			data.gameCountSum = math.random(table.unpack(sData.total_game_num))
			local win_rate = math.random(table.unpack(sData.win_rate)) / 10000
			data.winCountSum = math.ceil(data.gameCountSum*win_rate)
			win_rate = math.random(table.unpack(sData.win_rate_last20)) / 10000
			data.winCountSum_20 = math.ceil(20*win_rate)
		end

		-- 新增字段后版本必须变化
		if data.versionsKey ~= ServerData.versionsKey then
			-- 兼容旧版数据
			if robotTagType then
				local heroId
				local idArr = table.clone(ServerData.defHeroIdArr)
				local heroIdArr = ServerData.heroIdArr[robotTagType]
				heroId = objx.getChance(heroIdArr, function (value)
					return value.weight
				end).id
				table.insert(idArr, heroId)

				local heroDatas = {}
				for index, id in ipairs(idArr) do
					id = tostring(id)
					if not heroDatas[id] then
						heroDatas[id] = {
							id = id,
							sId = id,
							skillLv = 1,
							moodLv = 1,
							moodExp = 0,
							runeArr = {},

							notLimit = true,
							useCount = 0,

							skillCount = 0,
						}
					end
				end
				data.heroDatas = heroDatas
				data.heroId = tostring(heroId or data.heroId)
				data.skin = tonumber(data.heroId)
			end

			local isPay = not arrayx.findVal(ServerData.defHeroIdArr, data.heroId)

			local clockFrameArr = ServerData.clockFrameArr[isPay and RobotTagType.Pay or RobotTagType.NotPay]
			local gameChatFramArr = ServerData.gameChatFramArr[isPay and RobotTagType.Pay or RobotTagType.NotPay]
			local headFramArr = ServerData.headFramArr[isPay and RobotTagType.Pay or RobotTagType.NotPay]
			local headArr = ServerData.headArr[isPay and RobotTagType.Pay or RobotTagType.NotPay]

			data.clockFrame = data.clockFrame or objx.getChance(clockFrameArr, function (value) return value.weight end).id
			data.gameChatFram = data.gameChatFram or objx.getChance(gameChatFramArr, function (value) return value.weight end).id
			data.headFrame = data.headFrame or objx.getChance(headFramArr, function (value) return value.weight end).id
			if not data.head then
				local headData = datax.player_avatar[objx.getChance(headArr, function (value) return value.weight end).id]
				data.head = tostring(headData.id)
				data.gender = headData.sex
			end

			data.infoBg = data.infoBg or ServerData.infoBgArr[math.random(1, #ServerData.infoBgArr)].id
		end

		if not data.runeDatas then
			data.runeDatas = {}
		end

		if data.versionsKey ~= ServerData.versionsKey then
			data.versionsKey = ServerData.versionsKey
			dbx.update_add(TableNameArr.ServerRobot, {id = id, cfgId = sData.id}, data)
		end

		ServerData.robotDatas[data.id] = data
	end
	return data
end



CMD.GetRobotInfo = function (id)
	return ServerData.getRobotData(id)
end

function CMD.CreateRobot(gametype, roomtype, num, gameSubType, robotTagType)
	num = num or 1
	robotTagType = robotTagType or RobotTagType.Default

	for i = 1, num * 5 do
		num = num - 1

		ServerData.robotIndex = ServerData.robotIndex + 1
		if ServerData.robotIndex >= Int32MaxValue then
			ServerData.robotIndex = 1
		elseif ServerData.robotIndex % ServerData.robotCfgLen == 0 then
			ServerData.robotIndex = ServerData.robotIndex + 1
		end
		local idx = ServerData.robotIndex % ServerData.robotCfgLen
		local cfgId = ServerData.robotCfgIdArr[idx]

		-- TODO:遇见重复的先不处理，机器人数量足够多
		local groupDataArr = ServerData.robotDataGroup[robotTagType][cfgId]
		if #groupDataArr < 1 then
			num = num + 1
		else
			ServerData.robotUseInfo[robotTagType] = (ServerData.robotUseInfo[robotTagType] or 0) + 1

			local robotId = table.remove(groupDataArr, 1)
			skynet.newservice("ddz_robot", robotId, gametype, roomtype, gameSubType)
		end

		if num <= 0 then
			return
		end
	end

	skynet.loge("CreateRobot Error.", gametype, roomtype, gameSubType, robotTagType)
end

--机器人占用情况
function CMD.robot_snapshot_log()
	local ret = {}
	for robotTagType, robotDataGroup in pairs(ServerData.robotDataGroup) do
		local len = 0
		for key, groupDataArr in pairs(robotDataGroup) do
			len = len + #groupDataArr
		end
		ret[robotTagType] = {len = len, useLen = (ServerData.robotUseInfo[robotTagType] or 0)}
	end
	skynet.logd(string.format("robot report:", table.tostr(ret)))
end


CMD.inject = function (filePath)
    require(filePath)
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, cmd, ...)
    	local f = CMD[cmd]
		skynet.ret(skynet.pack(f(...)))
    end)
	ServerData.init()

end)