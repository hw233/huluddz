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


function CMD.register(c)
	c.reg_num = c.reg_num + 1
	c.act_num = c.act_num + 1
end


function CMD.login(c)
	c.act_num = c.act_num + 1
end

function CMD.charge(c, game_name, amount, is_new_player, is_first, is_today_first)
	c.charge_amount = c.charge_amount + amount
	c.game_charge[game_name] = (c.game_charge[game_name] or 0) + amount
	if is_new_player then
		c.new_charge_amount = c.new_charge_amount + amount
	end

	if is_today_first then
		c.charge_pnum = c.charge_pnum + 1
		if is_new_player then
			c.new_charge_pnum = c.new_charge_pnum + 1
		end
	end

	if is_first then
		c.first_charge_pnum = c.first_charge_pnum + 1
	end
end

function CMD.flush()
	local need_update = ServerData.need_update
	ServerData.need_update = {}

	for c,_ in pairs(need_update) do
		skynet.call(get_db_mgr(), "lua", "update", COLL.CHANNEL_DATA, {day = c.day, channel = c.channel, node_name = NODE_NAME}, table.filter(c, {_id = false}))
	end
end


function CMD.listener(cmd, channel, ...)
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

			reg_num = 0,				-- 今天注册人数
			act_num = 0, 				-- 今天登录人数

			charge_amount = 0, 			-- 今天充值总额(所有游戏)
			charge_pnum = 0, 			-- 今天充值人数

			new_charge_amount = 0,		-- 今天新玩家充值总额
			new_charge_pnum = 0,		-- 今天新玩家充值人数

			first_charge_pnum = 0, 		-- 今天首次充值人数
			game_charge = {},			-- 各个游戏的充值总额
		}
		c._id = skynet.send(get_db_mgr(), "lua", "insert", COLL.CHANNEL_DATA, c)
		ServerData.channel[channel] = c
	end

	local f = assert(CMD[cmd], cmd)
	local r = f(c, ...)

	ServerData.need_update[c] = true
	if not ServerData.delay_update then
		CMD.flush()
	end

	return r
end



function CMD.start_flush_timer()
	ServerData.cancle_flush_timer = timer.create(1500, function ()
		CMD.flush()
	end, -1)
end


function CMD.server_will_shutdown()
	if ServerData.cancle_flush_timer then
		ServerData.cancle_flush_timer()
		ServerData.cancle_flush_timer = nil
		ServerData.delay_update = false
	end
end


function CMD.init()
	-- load today channel data
	local today = CMD.today_0_time()
	local datas = skynet.call(get_db_mgr(), "lua", "find_all", COLL.CHANNEL_DATA, {day = today, node_name = NODE_NAME})
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