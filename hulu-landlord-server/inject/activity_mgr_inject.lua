-- inject :00000021 inject/activity_mgr_inject.lua

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
		
		skynet.logd("qwe", table.tostr(ServerData.ActData))
	end
end

datax.activity[2003] = nil
print("qwe", table.tostr(ServerData.ActData))
print("end")