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

--#region 配置表 require
local cfg_mail = require "cfg.cfg_mail"
--#endregion

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data


ServerData.mailGlobalDatas = nil
ServerData.cancelClearTimer1 = nil
ServerData.cancelClearTimer2 = nil

ServerData.phoneInfo = {}

local mail_index = 0
local getMailId = function ()
    mail_index = mail_index + 1
	return tostring(os.time() .. mail_index)
end


CMD.inject = function (filePath)
    require(filePath)
end

ServerData.init = function ()
	ServerData.updateDatas()

	-- 1小时清除一次过期邮件
	ServerData.cancelClearTimer1 = timer.create(60 * 60 * 100, function ()
		CMD.ClearMail()
	end, -1)

	ServerData.cancelClearTimer2 = timer.create(60 * 100, function ()
		local now = os.time()
		dbx_del.del(TableNameArr.MailGlobal, {endDt = {["$lt"] = now}})

		dbx_del.del(TableNameArr.UserMailGlobal, {endDt = {["$lt"] = now}})

		ServerData.updateDatas()
	end, -1)

	-- ServerData.phoneInfo = skynet.call(get_db_mgr(), "lua", "find_one", COLL.ETC, {name = 'phoneInfo'},{phone_info=true,["_id"]=false})
	-- if not ServerData.phoneInfo then
	-- 	ServerData.phoneInfo = {}
	-- 	ServerData.phoneInfo.phone_info = {}
	-- 	skynet.call(get_db_mgr(), "lua", "insert", COLL.ETC,{name = 'phoneInfo',phone_info = {}})
	-- end
end

ServerData.updateDatas = function ()
	local now = os.time()
	ServerData.mailGlobalDatas = dbx.find(TableNameArr.MailGlobal, {startDt = {["$lte"] = now}, endDt = {["$gt"] = now}}) or {}
end

CMD.ClearMail = function ()
	-- 创建时间超过30天的邮件可以删掉
	local time = timex.addDays(os.time(), -30)
	dbx_del.del(TableNameArr.UserMail, {sendDt = {["$lt"] = time}})
end

ServerData.AddMail = function (uData)
	dbx.add(TableNameArr.UserMail, uData)

	-- 不能超过60封
	local arr = dbx.find(TableNameArr.UserMail, {uId = uData.uId}, {id = true}, 1, {sendDt = -1}, 60)
	if #arr > 0 then
		for _, _m_data in pairs(arr) do
			dbx.del(TableNameArr.UserMail, {id = _m_data.id})
		end
	end

	common.send_client(uData.uId, "MailTip")
end

-- 发送策划表中的邮件使用
CMD.AddGameMail = function (toId, mailId, from, contentArr, itemArr)
	mailId = tonumber(mailId)
    if not cfg_mail[mailId] then
        skynet.loge("error mail: " .. mailId)
        --NetWork.WriteLog(user, "Mail", "AddError", mailId, itemList, contentList?.Text(), from);
        return nil
    end

    local uData = {
        id = getMailId(),
        uId = toId,

        mailId = mailId,
        content = contentArr,
        itemArr = itemArr,
        sendDt = os.time(),
        read = false,
        itemGet = false,
    }

	ServerData.AddMail(uData)

    -- 此项目是否需要写记录日志？

    return uData
end

-- 后台发送邮件调用
CMD.AddSystemMail = function (toId, title, from, contentStr, itemArr)
    if not title then
        return nil
    end

    local uData = {
        id = getMailId(),
        uId = toId,

        title = title,
        content = {contentStr},
        itemArr = itemArr,
        sendDt = os.time(),
        read = false,
        itemGet = false,
    }

    ServerData.AddMail(uData)

    -- 此项目是否需要写记录日志？

    return uData
end

--检测邮件是否领取过
CMD.ComputeMailGlobal = function (uId, channel, regDt)
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

				if isSend and data.startRegDt and data.endRegDt and (regDt < data.startRegDt or regDt >= data.endRegDt) then
					isSend = false
				end

				if isSend then
					common.addSystemMail(uId, data.title, "MailGlobal_全局邮件", data.contentStr, data.itemArr)

					dbx.add(TableNameArr.UserMailGlobal, {id = uId, mailGid = data.id, endDt = data.endDt})
				end
			end
		end
	end
end


--机型统计
function CMD.set_phone_info(phone_name)
	if phone_name and not ServerData.phoneInfo.phone_info[phone_name] then
		ServerData.phoneInfo.phone_info[phone_name] = 1
		skynet.call(get_db_mgr(), "lua", "update", COLL.ETC, {name = 'phoneInfo'},{phone_info = ServerData.phoneInfo.phone_info})
	else
		return ServerData.phoneInfo.phone_info[phone_name]
	end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
    ServerData.init()
end)
