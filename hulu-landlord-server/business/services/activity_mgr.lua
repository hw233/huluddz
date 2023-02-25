local skynet = require "skynet"

local datax = require "datax"
local objx = require "objx"
local timex = require "timex"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ec = require "eventcenter"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local xy_cmd 				= require "xy_cmd"

local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

ServerData.DbData = nil
ServerData.ActData = nil
ServerData.ActConfigData = nil

ServerData.init = function ()

	skynet.fork(function ()
		while true do
			local ok, err = pcall(ServerData.update)
			if not ok then
				skynet.loge("update error!", err)
			end
			skynet.sleep(100)
		end
	end)
end

ServerData.getData = function ()
	return dbx.get(TableNameArr.ActivityData, {server = "main"}) or {}
end

ServerData.setCfgData = function (datas)
	local ok, ret1, ret2 = pcall(function ()
		local updateData = {}

		for key, data in pairs(datas) do
			if data.open == nil then
				return false, "未设置活动开关"
			end
			if data.startDt == nil or data.endDt == nil or (data.startDt > data.endDt) then
				return false, "活动时间设置错误"
			end

			data.id = tonumber(key)
			local sData = datax.activity[tonumber(key) or -1]
			if sData then
				updateData["actConfigData." .. key] = data
			else
				return false, "未找到配置为 " .. key .. " 的活动"
			end
		end

		if next(updateData) then
			dbx.update(TableNameArr.ActivityData, {server = "main"}, updateData)
		end
		return true
	end)
	if ok then
		return ret1, ret2
	else
		return false, "设置活动出错"
	end
end

ServerData.update = function ()
	ServerData.DbData = ServerData.getData()

	if not ServerData.ActData then
		ServerData.DbData.actData = ServerData.DbData.actData or {}
		dbx.update_add(TableNameArr.ActivityData, {server = "main"}, {actData = ServerData.DbData.actData})
		ServerData.ActData = ServerData.DbData.actData
	end

	ServerData.DbData.actConfigData = ServerData.DbData.actConfigData or {}
	ServerData.ActConfigData = ServerData.DbData.actConfigData
	
	-- TODO：临时配置
	-- local datas = table.clone(datax.activity)
	-- for key, value in pairs(datas) do
	-- 	key = tostring(key)
	-- 	if ServerData.ActConfigData[key] then
	-- 		datas[value.id] = nil --先走配置
	-- 	else
	-- 		value.open = false
	-- 		value.startDt = os.time()
	-- 		value.endDt = timex.addMonth(value.startDt, 1)
	-- 	end
	-- end
	-- ServerData.setCfgData(datas)
	-- end

	local now = os.time()

	local isUpdate = false
	for key, sData in pairs(datax.activity) do
		local id = tostring(sData.id)
		local actData = ServerData.ActData[id]
		if not actData then
			actData = {}
			table.merge(actData, sData)
			ServerData.ActData[id] = actData
			isUpdate = isUpdate or true
		end
		actData.openTimes = actData.openTimes or 0

		local openValOld = (not not actData.open) and (not not (actData.startDt and actData.endDt))
		if openValOld then
			openValOld = now >= actData.startDt and now < actData.endDt
		end

		local cfgData = ServerData.ActConfigData[id]
		if cfgData then
			for key, value in pairs(cfgData) do
				local val = actData[key]
				isUpdate = isUpdate or (val ~= value)

				actData[key] = value
			end
		end

		if actData.open == nil then
			actData.open = false
			isUpdate = true
		end
		if actData.startDt == nil or actData.endDt == nil then
			actData.startDt = 0
			actData.endDt = 0
			isUpdate = true
		end

		local openValNew = actData.open and (now >= actData.startDt and now < actData.endDt)
		if openValNew and openValNew ~= openValOld then
			actData.openTimes = actData.openTimes + 1	-- 活动新一轮开启
			isUpdate = true
		end
	end

	for key, actData in pairs(ServerData.ActData) do
		local sData = datax.activity[actData.id]
		if not sData then
			ServerData.ActData[key] = nil
			isUpdate = true
		end
	end

	if isUpdate then
		dbx.update(TableNameArr.ActivityData, {server = "main"}, {actData = ServerData.ActData})
		ec.pub({type = "reloadActiveConfig"})
	end
end

CMD.GetActData = function ()
	return ServerData.ActData
end

CMD.SetCfgData = function (datas)
	return ServerData.setCfgData(datas)
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, cmd, ...)
    	local f = CMD[cmd]
		skynet.ret(skynet.pack(f(...)))
    end)
    ServerData.init()
end)