local skynet = require "skynet"
local datax = require "datax"
local objx    = require "objx"
local common = require "common_mothed"

local ec = require "eventcenter"
local RobotBase = require "game.robot.RobotBase"
local Command, ServerData = RobotBase.CMD, RobotBase.ServerData
local Robot = require "game.robot.sevensparrow.Robot"
local profile = require "skynet.profile"



return function (robotId, gametype, roomtype, gameSubType)
	ServerData.setData(robotId, gametype, roomtype, gameSubType)

	local sData = datax.roomGroup[gametype][roomtype]

	local myid = robotId
	local me = common.getRobotInfo(robotId)

	me.gold = math.random(sData.robot_corn_least, sData.robot_corn_max)

	me.gameCountSum 	= math.random(100,200)
	me.winCountSum 		= math.random(100,200)
	me.isLandlord 		= false

	local room_addr, robot

	local function send_request(name, args)
		return skynet.send(room_addr, "lua", "PlayerRequest", myid, name, args)
	end


	local on = {}

	function on:ssw_match_ok()
		robot = Robot(self.room, myid, send_request)
	end

	function on:ssw_gamestart()
		robot.gamestart(self.selectional_cards, self.players)
	end

	-- Please
	function on.ssw_please_recharge(args)
		if args.pid == myid then
			-- 机器人随机等待退出时间
			skynet.sleep(math.random(400, 700))
			send_request("ssw_exit")
		end
	end

	function on:ssw_please_takecard()
		robot.please_takecard(self.pid)
	end

	function on:ssw_please_playcard()
		robot.auto_play(self.pid)
	end


	-- Action
	function on:ssw_p_hu()
		robot.p_hu(self.pid, self.card, self.bills, self.over)
	end


	function on:ssw_p_playcard()
		robot.p_playcard(self.pid, self.card)
	end


	function on:ssw_p_swapcard()
		robot.p_swapcard(self.pid, self.flowers, self.cards)
	end


	function on:ssw_p_takecard()
		robot.p_takecard(self.pid, self.from_pool, self.card,self.flowers)
	end


	function on:ssw_gameover()
		ServerData.exitRobot(robotId, 0)
	end



	local ti = {}

	function Command.RoomPlayerMessage(source, name, args)
		room_addr = source

		local f = on[name]
		if f then
			profile.start()
			f(args)
			local time = profile.stop()
			local p = ti[name]
			if p == nil then
				p = { n = 0, ti = 0 }
				ti[name] = p
			end
			p.n = p.n + 1
			p.ti = p.ti + time
		end
	end
	
	skynet.info_func(function()
	  return ti
	end)

	function Command.RoomUserInfoGet(source, name, args)
		local ret = common.toUserBase(me)
		ret.gold = me.gold
		return ret
	end


	-- init
	skynet.fork(function ()
		skynet.call("ddz_match_mgr", "lua", "StartMatch", gametype, roomtype, {
			id = myid,
			addr = skynet.self(),
			robot = true,
			gold = me.gold,
			gamec = 10,
			gameCountSum = me.gameCountSum,
            winCountSum = me.winCountSum,
		}, gameSubType)
	end)


	return function (source, cmd, ...)
		local f = Command[cmd]
		if f then
			return f(source, ...)
		end
	end
end