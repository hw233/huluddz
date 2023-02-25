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
ServerData.CacheData = nil
ServerData.ConfigData = nil

ServerData.init = function ()

	skynet.fork(function ()
		while true do
			local ok, err = pcall(ServerData.update)
			if not ok then
				skynet.loge("update error!", err)
			end
			skynet.sleep(1000)
		end
	end)
end

ServerData.getData = function ()
	return dbx.get(TableNameArr.GameFuncData, {server = "main"}) or {}
end

ServerData.setCfgData = function (datas)
	local ok, ret1, ret2 = pcall(function ()
		local updateData = {}

		for key, data in pairs(datas) do
			if data.open == nil then
				return false, "未设置开关"
			end
			-- if data.startDt == nil or data.endDt == nil or (data.startDt > data.endDt) then
			-- 	return false, "活动时间设置错误"
			-- end
            if not data.channelCloseArr or not objx.isTable(data.channelCloseArr) then
                return false, "未设置关闭渠道数组"
            end

			data.id = tonumber(key)

			-- local sData = datax.activity[tonumber(key) or -1]
			-- if sData then
			 	updateData["configData." .. key] = data
			-- else
			-- 	return false, "未找到配置为 " .. key .. " 的活动"
			-- end
		end

		if next(updateData) then
			dbx.update(TableNameArr.GameFuncData, {server = "main"}, updateData)
		end
		return true
	end)
	if ok then
		return ret1, ret2
	else
		return false, "设置出错"
	end
end

ServerData.update = function ()
	ServerData.DbData = ServerData.getData()

	if not ServerData.CacheData then
		ServerData.DbData.cacheData = ServerData.DbData.cacheData or {}
		dbx.update_add(TableNameArr.GameFuncData, {server = "main"}, {cacheData = ServerData.DbData.cacheData})
		ServerData.CacheData = ServerData.DbData.cacheData
	end

	ServerData.DbData.configData = ServerData.DbData.configData or {}
	ServerData.ConfigData = ServerData.DbData.configData

	local now = os.time()

	local isUpdate = false
	for key, cfgData in pairs(ServerData.ConfigData) do
		local id = tostring(cfgData.id)
		local cacheData = ServerData.CacheData[id]
		if not cacheData then
			cacheData = {}
			table.merge(cacheData, cfgData)
			ServerData.CacheData[id] = cacheData
			isUpdate = isUpdate or true
		end

		for key, value in pairs(cfgData) do
            local val = cacheData[key]
			if not isUpdate then
				if objx.isTable(val) then
					local str1 = value and table.tostr(value) or ""
					local str2 = val and table.tostr(val) or ""
					isUpdate = isUpdate or (str1 ~= str2)
				else
					isUpdate = isUpdate or (val ~= value)
				end
			end

            cacheData[key] = value
        end

		if cacheData.open == nil then
			cacheData.open = false
			isUpdate = true
		end
		-- if cacheData.startDt == nil or cacheData.endDt == nil then
		-- 	cacheData.startDt = 0
		-- 	cacheData.endDt = 0
		-- 	isUpdate = true
		-- end
	end

	for key, cacheData in pairs(ServerData.CacheData) do
		local sData = ServerData.ConfigData[tostring(cacheData.id)]
		if not sData then
			ServerData.CacheData[key] = nil
			isUpdate = true
		end
	end

	if isUpdate then
		dbx.update(TableNameArr.GameFuncData, {server = "main"}, {cacheData = ServerData.CacheData})
		ec.pub({type = EventCenterEnum.GameFunc})
	end
end

CMD.GetData = function ()
	return ServerData.CacheData
end

CMD.GetCfgData = function ()
	local DbData = ServerData.getData()
	return DbData.configData or {}
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