local skynet = require "skynet"
local timer = require "timer"

local objx = require "objx"
local arrayx = require "arrayx"
local timex = require "timex"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local dbx_del = create_dbx("db_mgr_del")
local common = require "common_mothed"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data



--检测邮件是否领取过
CMD.ComputeMailGlobal = function (uId, channel)
	if not uId then
		skynet.loge("ComputeMailGlobal error!", uId, channel)
		return
	end

	if not next(ServerData.mailGlobalDatas) then
		return
	end

	local uDatas = dbx.find(TableNameArr.UserMailGlobal, {id = uId}) or {}
	uDatas = table.toObject(uDatas, function (key, value)
		return value.mailGid
	end)

	local now = os.time()
	for index, data in ipairs(ServerData.mailGlobalDatas) do
		if data.id and not uDatas[data.id] then
			if now >= data.startDt and now < data.endDt then
				local isSend = true
				if data.channelArr and #data.channelArr > 0 then
					if not channel then
						local user = dbx.get(TableNameArr.User, uId, {id = true, channel = true})
						channel = user and user.channel
					end
					
					if not arrayx.findVal(data.channelArr, channel) then
						isSend = false
					end
				end

				if isSend then
					common.addSystemMail(uId, data.title, "MailGlobal_全局邮件", data.contentStr, data.itemArr)

					dbx.add(TableNameArr.UserMailGlobal, {id = uId, mailGid = data.id, endDt = data.endDt})
				end
			end
		end
	end

end

print("end")
-- inject :00000022 inject/mail_manager_inject.lua

