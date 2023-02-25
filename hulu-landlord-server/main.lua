local skynet = require "skynet"
require "skynet.manager"
local config = require "server_conf"
local xy_cmd = require "xy_cmd"
local sharetable = require "skynet.sharetable"

local function log_git_info()
	local helper = require "githelper"
	local author = helper.author--("%an")
	local date = helper.date
	local message = helper.message
	skynet.error("last author =", author, ";date=", date, ";message=", message)
end

local function log_process_info()
	local process_id = tonumber(skynet.getenv "process_id")
	skynet.error("env process id=>", process_id)
	local tbl_match = {id = process_id}
	local fields = {_id = false }
	-- local conf = skynet.call("conf_db_mgr", "lua", "find_one", "process_conf", tbl_match, fields)
	-- skynet.error("process id 	=>", conf.id)
	-- skynet.error("process svrid =>", conf.svrid)
	-- skynet.error("process desc 	=>", conf.desc)
	-- skynet.error("process group =>", conf.group)
	-- skynet.error("process name 	=>", conf.name)
end

skynet.start(function()
	skynet.name("conf_db_mgr",skynet.newservice("conf_db_mgr"))
	--log_git_info()
	log_process_info()

	skynet.name("load_gameconf",skynet.newservice("load_gameconf"))
	skynet.uniqueservice("protoloader")

	-- skynet.name("xy_protoloader", skynet.newservice("xy_protoloader"))
	--if (not skynet.getenv "daemon") and (not skynet.getenv "vscdbg_open" == "on") then
	if (not skynet.getenv "daemon") then
		-- skynet.newservice("console")
		local debug_console_port = skynet.getenv("debug_console_port") or 13000
		skynet.newservice("xycard_debug_console", debug_console_port)
	end

	--db---
	local log_db_waite = true --私货 : db启动耗时print
	local db_mgr_max_count = skynet.getenv("db_mgr_num") or 4 --dbmgr数量
	sharetable.loadtable("db_mgr_max_count", {db_mgr_max_count = db_mgr_max_count})
	do
	-- TODO：七雀牌和经典斗地主记录还在使用，后续重写记录部分这儿就废弃了
	skynet.name("db_mgr_rec",skynet.newservice("db_mgr", "true"))--rec
	if log_db_waite then print("==== start service db_mgr_rec waite ... ====" , os.time()) end
	end

	--#region 现在 db_manager 只作为操作数据使用，不再在其中写入与业务相关代码了

	local dbconfs = skynet.call("load_gameconf", "lua", "get_dbconfs")

	skynet.name("db_manager", skynet.newservice("db_manager")) -- 主业务数据数据库
	skynet.call("db_manager", "lua", "init", dbconfs.main, "POOL", true)
	if log_db_waite then print(string.format("==== start service %s waite ... ==== %d" ,"db_manager", os.time())) end

	for i = 1, db_mgr_max_count do
		local serviceName = "db_manager" .. i
		skynet.name(serviceName, skynet.newservice("db_manager")) -- 业务数据数据库
		skynet.call(serviceName, "lua", "init", dbconfs.main, "POOL")
		if log_db_waite then print(string.format("==== start service %s waite ... ==== %d" , serviceName, os.time())) end
	end

	-- 删除数据数据量较大时用这个么？
	skynet.name("db_mgr_del", skynet.newservice("db_manager"))
	skynet.call("db_mgr_del", "lua", "init", dbconfs.main)
	if log_db_waite then print("==== start service db_mgr_del waite ... ====" , os.time()) end

	skynet.name("db_manager_rec", skynet.newservice("db_manager")) -- 记录数据数据库
	skynet.call("db_manager_rec", "lua", "init", dbconfs.rec, "POOL_REC", true)
	if log_db_waite then print("==== start service %s waite ... ====" , "db_manager_rec", os.time()) end

	skynet.name("db_mgr_client", skynet.newservice("db_manager")) -- 记录客户端数据的
	skynet.call("db_mgr_client", "lua", "init", dbconfs.rec, "POOL_Client", true)
	if log_db_waite then print("==== start service %s waite ... ====" , "db_mgr_client", os.time()) end

	--#endregion

	skynet.name("agent_mgr", skynet.newservice("agent_mgr"))--玩家 agent

	skynet.name("server_service", skynet.newservice("server_service"))
	skynet.name("server_announce", skynet.newservice("server_announce"))
	skynet.name("user_service", skynet.newservice("user_service"))
	skynet.name("activity_mgr", skynet.newservice("activity_mgr"))
	skynet.name("user_season", skynet.newservice("user_season"))
	skynet.name("mail_manager", skynet.newservice("mail_manager"))
	skynet.name("user_gourd", skynet.newservice("user_gourd")) 				-- 豆藤
	skynet.name("game_func_mgr", skynet.newservice("game_func_mgr"))

	skynet.name("ranklistmanager", skynet.newservice("ranklist_manager"))	--排行榜
	skynet.name("friend_manager", skynet.newservice("friend_manager")) 		--好友
	skynet.name("sensitive_word", skynet.newservice("sensitive_word")) 		--敏感字sensitive_word_mgr
	skynet.name("real_name", skynet.newservice("real_name"))
	skynet.name("cdk", skynet.newservice("cdk"))

	--2021 斗地主
	skynet.name("ddz_match_mgr", skynet.uniqueservice("ddz_match_mgr"))--ddz游戏匹配
	skynet.name("ddz_robot_mgr", skynet.uniqueservice("ddz_robot_mgr"))
	skynet.name("ddz_room_mgr", skynet.uniqueservice("ddz_room_mgr"))
	skynet.name("ddz_room_info", skynet.newservice("ddz_room_info"))

	
	skynet.name("cd_collecter", skynet.newservice("cd_collecter")) --渠道数据采集


	-- skynet.name("matching_mgr", skynet.newservice("matching_mgr"))--游戏匹配
	-- skynet.name("mail_mgr", skynet.newservice("mail_mgr"))
	-- skynet.name("friend_mgr", skynet.newservice("friend_mgr")) --好友
	-- skynet.name("team2v2_mgr",skynet.newservice("team2v2_mgr"))--2v2组队
	-- skynet.name("lottery_mgr", skynet.newservice("lottery_mgr")) --抽奖服务
	-- skynet.name("entity_mgr", skynet.newservice("entity_mgr"))--实物奖励
	-- skynet.name("booster_mgr", skynet.newservice("booster_mgr")) --助力礼包
	-- skynet.name("ranklist_mgr", skynet.newservice("ranklist_mgr"))--常规排行榜
	-- skynet.name("rank_two_mgr", skynet.newservice("rank_two_mgr"))--番王 鸿运 连胜榜
	-- skynet.name("http_channel", skynet.newservice("http_channel"))--渠道,后台 API config="http_channel_port"

	-- skynet.name("global_status", skynet.newservice("global_status")) --全局状态服务
	-- skynet.name("cdk_mgr", skynet.newservice("cdk_mgr")) --cdk码服务
	-- skynet.name("rn_auth_mgr",skynet.newservice("realname_auth_mgr"))--实名认证

	skynet.newservice("hs_data_collector")--数据收集

	-- skynet.name("data_goods_mgr", skynet.newservice("data_goods_mgr")) --道具概览
	skynet.name("pay_info_mgr", skynet.newservice("pay_info_mgr")) --支付概览
	skynet.name("active_mgr", skynet.newservice("active_mgr")) --活动管理
	skynet.name("game_info_mgr", skynet.newservice("game_info_mgr")) --频道房间信息采集



	-- skynet.name("httpserver2", skynet.newservice("httpserver2"))--API
	skynet.name("web_gm", skynet.newservice("web/httpserver"))
	skynet.call("web_gm", "lua", "init", skynet.getenv("http_server2_port"), "web_module_gm")

	skynet.name("httpclient", skynet.newservice("web/httpclient"))--SDK充值提现 http call
	-- skynet.name("httpserver", skynet.newservice("httpserver"))--SDK http callback
	skynet.name("web_sdk", skynet.newservice("web/httpserver"))
	skynet.call("web_sdk", "lua", "init", skynet.getenv("http_server_port"), "web_module_sdk")

	local httpClientPort = tonumber(skynet.getenv("httpClientPort"))
	if httpClientPort and httpClientPort > 0 then
		skynet.name("web_client", skynet.newservice("web/httpserver"))
		skynet.call("web_client", "lua", "init", httpClientPort, "web_module_client")
	end

	-- ------------------test1 专用文件
	if skynet.getenv("is_logind_server") then
		skynet.name("logind", skynet.newservice("logind","tcp"))
	end

	for i = 1, skynet.getenv("gate_port_num") do
		local gate = skynet.newservice("gated")
		skynet.name("gate" .. i, gate)
		if log_db_waite then print("==== start gated tcp ... ====" , os.time()) end
		skynet.call(gate, "lua", "open" , {
			port = skynet.getenv("gate_port" .. i), --13011,
			maxclient = config.max_client,
			servername = config.server_name,
		})
	end
		
	------------------test1 专用文件
	-- if skynet.getenv("is_logind_server") then
	-- 	skynet.name("logind", skynet.newservice("logind","ws"))
	-- end

	-- for i = 1, skynet.getenv("gate_port_num") do
	-- 	local gate = skynet.newservice("gated", "ws")
	-- 	skynet.name("gate" .. i, gate)
	-- 	if log_db_waite then print("==== start gated ws ... ====" , os.time()) end
	-- 	skynet.call(gate, "lua", "open" , {
	-- 		port = skynet.getenv("gate_port" .. i), --13011,
	-- 		maxclient = config.max_client,
	-- 		servername = config.server_name,
	-- 		protocol = "ws",
	-- 	})
	-- end

	skynet.name("services_mgr", skynet.newservice("services_mgr"))
	skynet.name("day_over_check",skynet.newservice("day_over_check"))
	skynet.send("load_gameconf","lua","exit")

	print("======start ok=======")

	skynet.exit()
end)
