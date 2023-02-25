local skynet = require "skynet"
local bson = require "bson"
local COLL = require "config/collections"
require "pub_util"

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

-- all service's mgr
-- local agent_mgr, login_master,third_platform_valid
ServerData.cancel_shutdown_tasks = {}  -- 可取消的定时任务
ServerData.timing_task_id = 0 -- 定时任务id
-- local CMD = {}
function CMD.get_task_id()
	ServerData.timing_task_id = ServerData.timing_task_id + 1
	return ServerData.timing_task_id
end

-- 可取消的定时任务
function CMD.cancelable_timeout(ti, func)
    local function cb()
        if func then
            func()
        end
    end
    
    local function cancel()
        func = nil
    end
    skynet.timeout(ti, cb)
    return cancel
end

function CMD.notice( msg,num,atOnce,effects,currLive)
	skynet.send("agent_mgr", "lua", "notice", 'server_notice',
		{ what = msg,num = (num or 1),atOnce = (atOnce or false),effects = (effects or 0),currLive=(currLive or 1) }
	)
end

--各种活动广播
-- function CMD.activeNotice(bType,sType,automsg)
-- 	local tempInfo = cfg_horse_lamp[bType][sType]
-- 	--print("activeNotice bType=",bType, ";bType=", sType, ";tempInf=", tempInfo)
-- 	table.print(automsg)
-- 	if not tempInfo then
-- 		return
-- 	end
-- 	local tempMsg = ''
-- 	local nextIndex = 1
-- 	for i,info in ipairs(tempInfo.msg) do
-- 		print(info)
-- 		if info then
-- 			tempMsg = tempMsg..info
-- 		else
-- 			tempMsg = tempMsg..automsg[nextIndex]
-- 			nextIndex = nextIndex + 1
-- 		end
-- 	end
-- 	print('=================g公告===============',tempMsg)
-- 	CMD.notice(tempMsg,tempInfo.msg.num,tempInfo.msg.atOnce,tempInfo.msg.effects)
-- end

--紧急走马灯
local last_emergency_notice_stp = 0
function CMD.emergencyNotice(id)
	local now = os.time()
	local diff = now - last_emergency_notice_stp
	if diff > 5 * 60 then
		local notice = skynet.call(get_db_mgr(), "lua", "find_one", COLL.LAMP, {_id = bson.objectid(id)})
		if notice then
			last_emergency_notice_stp = os.time()
			CMD.notice(notice.msg, notice.num, notice.atOnce, notice.effects, notice.currLive)
			return true
		end
		return false, "Find lamp failed"
	end
	return false, "Too often. Try again later"
end

--战斗内通知
function CMD.fightNotice(bType,sType,automsg)
	print('==============战斗内通知===================')
	local tempTbl = {}
	tempTbl.nickname = automsg.nickname
	tempTbl.game_des = automsg.game_des
	tempTbl.multiple = automsg.multiple
	tempTbl.bType 	= bType
	tempTbl.sType 	= sType
	tempTbl.cardsType = automsg.cardsType
	table.print(tempTbl)
	skynet.send("agent_mgr", "lua", "notice", 'fightNotice',tempTbl)
end
-- function CMD.notice( msg )
-- 	notice(msg)
-- end

local function shutdown_comp(time,forbid_time,msg)
	print("shutdown_comp ================", time,forbid_time,msg)
	if cancel_shutdown_task then
		cancel_shutdown_task()
		cancel_shutdown_task = nil
	end

	time = tonumber(time)
	assert(time >= 1)
	forbid_time = forbid_time or 1

	forbid_time = tonumber(forbid_time)

	-- 禁止创建房间与即将关闭
	skynet.send("agent_mgr", "lua", "forbid_create_room")

	-- cluster.send("agent_mgr", "agent_mgr", "lua", "forbid_create_room")
	-- agent_mgr.post.forbid_create_room()
	--forbid_time 关闭服务器前forbid_time禁止创建房间
	skynet.timeout(time*60*100 -forbid_time *60*100,function()
		skynet.send("t_plat_valid", "lua", "server_will_shutdown")
		-- third_platform_valid.post.server_will_shutdown()
		skynet.send("agent_mgr", "lua", "server_will_shutdown")
		-- cluster.send("agent_mgr", "agent_mgr", "lua", "server_will_shutdown")
		-- agent_mgr.post.server_will_shutdown()
	end)

	for i=time,1,-2 do
		skynet.timeout((time-i)*60*100, function()
			CMD.notice("服务器将在"..i.."分钟后关闭! "..msg)
		end)
	end

	--服务器关闭前一分钟
	skynet.timeout(time*60*100 - 60*100, function ()
		skynet.send("global_status", "lua", "server_will_shutdown")
	end)

	skynet.timeout(time*60*100 - 30*100, function ()
		CMD.notice("服务器将在30秒后关闭! 解散所有房间. "..msg)
		skynet.send("agent_mgr", "lua", "shutdown", 'room')
		-- cluster.send("agent_mgr", "agent_mgr", "lua", "shutdown", 'room')
		-- agent_mgr.post.shutdown('room')
	end)

	skynet.timeout(time*60*100 - 3*100, function ()
		CMD.notice("服务器将在3秒后关闭! "..msg)
	end)

	skynet.timeout(time*60*100, function ()
		skynet.error(get_ftime().." server will shutdown.\n")
		skynet.call(login_master, 'lua', 'shutdown')
		skynet.send("agent_mgr", "lua", "shutdown", 'user')
		skynet.exit()
	end)
end

-- 定时开始通知服务器关闭
-- start_time (时间戳) 关服时间
-- time (分钟) 提前多少时间发送跑马灯
-- forbid_time (分钟) 提前多少时间静止进入房间
function CMD.timing_shutdown(start_time,time,forbid_time,msg)
	print("timing_shutdown =================", start_time,time,forbid_time,msg)
	if not start_time then return false end
	local curr_time = os.time()
	local diff = start_time - curr_time - time * 60
	if diff < 0 then return false end

	local t_id = CMD.get_task_id()

	local cancel = CMD.cancelable_timeout(diff*100,function()
		shutdown_comp(time,forbid_time,msg)
		CMD.stop_timing_task(t_id)
	end)

	skynet.send("cd_collecter", "lua", "server_will_shutdown")
	skynet.send("chanllenge_game", "lua", "server_will_shutdown", start_time - 30 * 60)
	ServerData.cancel_shutdown_tasks[t_id] = {
		cancel = cancel,
		start_time = start_time,
		msg 	= msg,
	}

	return true
end

-- local function CMD.stop_timing_task(t_id)
-- 	if t_id and ServerData.cancel_shutdown_tasks[t_id] then
-- 		ServerData.cancel_shutdown_tasks[t_id].cancel()
-- 		ServerData.cancel_shutdown_tasks[t_id] = nil
-- 	end
-- end
-- 停止一个定时任务
function CMD.stop_timing_task(t_id)
	if not t_id then return false end
	if t_id and ServerData.cancel_shutdown_tasks[t_id] then
		ServerData.cancel_shutdown_tasks[t_id].cancel()
		ServerData.cancel_shutdown_tasks[t_id] = nil
	end
	return true
end
-- 停止所有定时任务
function CMD.stop_all_timing_task()
	for t_id,_ in ipairs(ServerData.cancel_shutdown_tasks) do
		CMD.stop_timing_task(t_id)
	end
end

-- 获取所用定时任务
function CMD.get_all_timing_task()
	local t = {}
	for t_id,task in pairs(ServerData.cancel_shutdown_tasks) do
		table.insert(t,{
			id = t_id,
			start_time = task.start_time,
			msg = task.msg,
		})
	end
	return t
end

-- msg  关闭服务器的消息
-- time(单位 分钟) 后关闭服务器
-- forbid_time(单位 分钟) 关闭服务器 forbid_time 前不能创建娱乐场、充值
function CMD.shutdown(time,forbid_time,msg)
	shutdown_comp(time,forbid_time,msg)
end

-- -- call by console, time (分钟)
-- function accept.shutdown( time,forbid_time, msg )
-- 	time = tonumber(time)
-- 	assert(time >= 1)
-- 	--forbid_time 关闭服务器前forbid_time禁止创建房间
-- 	skynet.timeout(time*60*100 -forbid_time *60*100,function()
-- 		agent_mgr.post.server_will_shutdown()
-- 	end)

-- 	for i=time,1,-2 do
-- 		skynet.timeout((time-i)*60*100, function()
-- 			notice("服务器将在"..i.."分钟后关闭! "..msg)
-- 		end)
-- 	end

-- 	skynet.timeout(time*60*100 - 30*100, function ()
-- 		notice("服务器将在30秒后关闭! 解散所有房间. "..msg)
-- 		agent_mgr.post.shutdown('room')
-- 	end)

-- 	skynet.timeout(time*60*100 - 3*100, function ()
-- 		notice("服务器将在3秒后关闭! "..msg)
-- 	end)

-- 	skynet.timeout(time*60*100, function ()
-- 		shutdown()
-- 	end)
-- end

function CMD.init( )
	-- agent_mgr 	  = snax.queryservice("agent_mgr")
	-- third_platform_valid = snax.queryservice("third_platform_valid")
	login_master  = skynet.localname(".login_master")
end

function CMD.inject(filePath)
	print("services_mgr inject ", filePath)
    require(filePath)
end

-- function exit( )
-- 	skynet.error(string.format("%s service_mgr exit", get_ftime()))
-- end

skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
    CMD.init()
end)
