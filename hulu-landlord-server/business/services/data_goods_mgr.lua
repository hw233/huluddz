--
-- channel data collecter
--

local skynet = require "skynet"
local timer = require "timer"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
local schedule = require "schedule"
local timer = require "timer"


local NODE_NAME = skynet.getenv "node_name"
local COLL = require "config/collections"

ServerData.delay_update = true

ServerData.channel = {}
ServerData.need_update = {}


function CMD.inject(filePath)
    require(filePath)
end

function CMD.today_0_time()
	local t = os.date("*t")
	return os.time {year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0}	
end

--
function CMD.goods_add_sub(c,goods_id, way, num)
	local add_or_sub = "add"
	if num == 0 then
		return
	end
	if num < 0 then
		add_or_sub = "sub"
	end
	local key = tostring(goods_id) .. "_" .. tostring(way) .. "_" .. add_or_sub
	c[key] = (c[key] or 0) + num
end

function CMD.flush()
	local need_update = ServerData.need_update
	ServerData.need_update = {}

	for c,_ in pairs(need_update) do
		skynet.call(get_db_mgr(), "lua", "update", COLL.GOODS_OVERVIEW, {day = c.day, channel = c.channel, node_name = NODE_NAME}, table.filter(c, {_id = false}))
	end
end

function CMD.listener_in(cmd, channel, ...)
	if not channel or channel == "" then
		return
	end

	local today = CMD.today_0_time()

	local c = ServerData.channel[channel]
	if not c or c.day ~= today then
		c = {
			day = today,				-- 日期
			channel = channel,			-- 渠道名
			node_name = NODE_NAME,
		}
		c._id = skynet.send(get_db_mgr(), "lua", "insert", COLL.GOODS_OVERVIEW, c)
		ServerData.channel[channel] = c
	end
	ServerData.need_update[c] = true
	local f = assert(CMD[cmd], cmd)
	local r = f(c, ...)
	
	return r
end

--goods_id way
function CMD.listener(cmd, channel, ...)
	CMD.listener_in(cmd,channel,...)
	local r =  CMD.listener_in(cmd,"total",...)
	
	if not ServerData.delay_update then
		CMD.flush()
	end
	return r
end

function CMD.start_flush_timer()
	if ServerData.delay_update then
		skynet.timeout(200,CMD.start_flush_timer)
	end
	CMD.flush()
end

function CMD.server_will_shutdown()
	ServerData.delay_update = false
end

function CMD.init()
	-- load today channel data
	local today = CMD.today_0_time()
	local datas = skynet.call(get_db_mgr(), "lua", "find_all", COLL.GOODS_OVERVIEW, {day = today, node_name = NODE_NAME}) or {}
	ServerData.channel = {}

	for _,c in ipairs(datas) do
		ServerData.channel[c.channel] = c
	end
end

skynet.start(function ()
	skynet.dispatch("lua", function(session, source, cmd, channel, ...)
		skynet.ret(skynet.pack(CMD.listener(cmd, channel, ...)))
	end)
	CMD.init()
	CMD.start_flush_timer()
end)