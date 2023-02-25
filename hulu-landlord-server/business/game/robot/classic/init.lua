local skynet = require "skynet"
local datax = require "datax"
local objx    = require "objx"
local common = require "common_mothed"

local ec = require "eventcenter"
local RobotBase = require "game.robot.RobotBase"
local Command, ServerData = RobotBase.CMD, RobotBase.ServerData
local Robot = require "game.robot.classic.Robot"


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
	local roomObj = {
		landlordId = nil,
		lastPlayCardObj = {}
	}


	local function send_room(name, args)
		return skynet.send(room_addr, "lua", "PlayerRequest", myid, name, args)
	end


	local on = {}

	function on:RoomMatchOk_C()
		robot = Robot(self.room, myid)
	end

	function on:RoomDealCard_C()
		robot.init_handcards(self.cards)
	end

	function on:RoomPleasePlayerAction_C()
		local id, state, clock, playCardState, roomData = self.id, self.state, self.clock, self.playCardState, self.roomData

		if id == myid then
			if state == PlayerState_DDZ.CallLandlord then
				on.please_call_landlord()
			elseif state == PlayerState_DDZ.RobLandlord then
				on.please_rob_landlord()
			elseif state == PlayerState_DDZ.Doubleing then
				on.please_double()
			elseif state == PlayerState_DDZ.DoubleMax then
				on.please_doubleMax()
			elseif state == PlayerState_DDZ.Playing then
				skynet.sleep(math.random(150, 350))

				skynet.logd("RoomPleasePlayerAction_C----id=", id, "playCardState=", playCardState, 
					", isLandlord=", roomObj.lastPlayCardObj.isLandlord == me.isLandlord, table.tostr(roomObj.lastPlayCardObj.playCardObj),
					"handcards = ", table.tostr(robot.GetHandcards()))
				roomData.lastPlayerId = roomObj.lastPlayCardObj.id
				roomData.lastPlayerCard = roomObj.lastPlayCardObj.playCardObj
				
				local result = robot.getPlayCardObj(playCardState, roomObj.lastPlayCardObj.isLandlord == me.isLandlord, roomObj.lastPlayCardObj.playCardObj, roomData)
				send_room("PlayCard", {
					type = result.pass and PlayerAction_DDZ.Pass or PlayerAction_DDZ.PlayCard,
					playCardObj = result.playedcards
				})
			end
		end
	end

	function on.please_call_landlord()
		if robot.should("call_landlord") then
			skynet.sleep(math.random(80, 160))
			send_room("CallLandlord", {type = PlayerAction_DDZ.CallLandlord})
		else
			skynet.sleep(math.random(60, 120))
			send_room("CallLandlord", {type = PlayerAction_DDZ.NotCall})
		end
	end

	function on.please_rob_landlord()
		if robot.should("rob_landlord") then
			skynet.sleep(math.random(80, 160))
			send_room("RobLandlord", {type = PlayerAction_DDZ.RobLandlord})
		else
			skynet.sleep(math.random(60, 120))
			send_room("RobLandlord", {type = PlayerAction_DDZ.NotRob})
		end
	end

	function on:please_overlord_rob_landlord()
		if self.qualified then
			if robot.should("overlord_rob_landlord") then
				skynet.sleep(math.random(60, 250))
				send_room("overlord_rob_landlord")
			end
		end
	end

	function on.please_double()
		skynet.sleep(math.random(50, 250))
		local type = PlayerAction_DDZ.NotDouble
		if robot.should("double") then
			type = math.random() < 0.4 and PlayerAction_DDZ.Double_4 or PlayerAction_DDZ.Double_2
		end
		send_room("Double", {type = type})
	end

	function on.please_doubleMax()
		skynet.sleep(math.random(50, 250))
		local type = PlayerAction_DDZ.NotDoubleMax
		if robot.should("double_cap") then
			type = PlayerAction_DDZ.DoubleMax
		end
		send_room("DoubleMax", {type = type})
	end


	function on:RoomLandlordSet_C()
		local id = self.id
		if id == myid then
			me.isLandlord = true
			robot.setLandlord(self.bottomCards)
		end
		roomObj.landlordId = id
	end

	function on:RoomSyncPlayerAction_C()
		local id, _type, playCardObj = self.id, self.type, self.playCardObj
		if _type == PlayerAction_DDZ.Pass or _type == PlayerAction_DDZ.PlayCard then
			if id == myid then
				robot.playCard(_type == PlayerAction_DDZ.Pass, playCardObj)
			end

			if _type == PlayerAction_DDZ.PlayCard then
				roomObj.lastPlayCardObj.id = id
				roomObj.lastPlayCardObj.playCardObj = playCardObj
				roomObj.lastPlayCardObj.isLandlord = roomObj.landlordId == id
			end
					
		end
	end

	function on:RoomGameOver_C()
		local datas = assert(self.datas)
		for id, p in pairs(datas) do
			if p.id == myid then
				ServerData.exitRobot(p.win_gold)
			end
		end
	end



	function Command.RoomPlayerMessage(source, name, args)
		room_addr = source

		local f = on[name]
		if f then
			f(args)
		end
	end

	function Command.RoomUserInfoGet(source, name, args)
		local ret = common.toUserBase(me)
		ret.gold = me.gold
		return ret
	end


	-- init
	skynet.fork(function ()
		--local showcardx5 = math.random() < conf.prob.showcardx5 and true or false

		skynet.call("ddz_match_mgr", "lua", "StartMatch", gametype, roomtype, {
			id = myid,
			addr = skynet.self(),
			robot = true,
			gold = me.gold,
			--showcardx5 = showcardx5,
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