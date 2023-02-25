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
	log_process_info()

	skynet.name("load_gameconf",skynet.newservice("load_gameconf"))

	-- skynet.name("xy_protoloader", skynet.newservice("xy_protoloader"))
	--if (not skynet.getenv "daemon") and (not skynet.getenv "vscdbg_open" == "on") then
	if (not skynet.getenv "daemon") then
		-- skynet.newservice("console")
		local debug_console_port = skynet.getenv("debug_console_port") or 13000
		skynet.newservice("xycard_debug_console", debug_console_port)
	end

	local dbconfs = skynet.call("load_gameconf", "lua", "get_dbconfs")

	skynet.name("db_mgr_client", skynet.newservice("db_manager")) -- 记录客户端数据的
	skynet.call("db_mgr_client", "lua", "init", dbconfs.rec, "POOL_Client", true)

	skynet.name("web_client", skynet.newservice("web/httpserver"))
	skynet.call("web_client", "lua", "init", skynet.getenv("httpClientPort"), "web_module_client")

	skynet.send("load_gameconf","lua","exit")

	print("======start ok=======")

	skynet.exit()
end)
