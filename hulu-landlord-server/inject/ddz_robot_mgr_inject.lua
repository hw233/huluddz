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

print("start")

ServerData.vipRange = {0, 5}

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
		data.gourdLv = data.gourdLv or math.random(table.unpack(sData.gourd_vine_lv))

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


print("end")
-- inject :00000020 inject/ddz_robot_mgr_inject.lua