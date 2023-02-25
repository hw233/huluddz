local skynet = require "skynet"
local ec = require "eventcenter"
local conf = require "config_ddz.robot"
local cft_robot = require "conftbl_ddz.robot"
local Robot = require "game.robot.leperking.Robot"


return function (myindex, gametype, roomtype, gameSubType)
	-- skynet.error("====debug qc==== create robot leperking ")
	local room_addr, robot

	local myid = '#'..myindex
	local me = {
		id = myid,
		nick = cft_robot[myindex].name,
		head = conf.head_prefix .. cft_robot[myindex].icon,
		gender = myindex%2 + 1,
		gold = math.random(conf.start_gold[roomtype].min, conf.start_gold[roomtype].max),
		gameCountSum = math.random(100,200),
		winCountSum = math.random(1,100),
	}


	local function send_room(name, args)
		return skynet.send(room_addr, "lua", "PlayerRequest", myid, name, args)
	end


	local on = {}

	function on:match_ok()
		robot = Robot(self.room, myid)
	end

	function on:game_start_dealcard()
		robot.init_handcards(self.cards)
	end

	function on:please_call_landlord()
		if self.pid == myid then
			if robot.should("call_landlord") then
				skynet.sleep(math.random(80, 160))
				send_room("call_landlord", {call = true})
			else
				skynet.sleep(math.random(60, 120))
				send_room("call_landlord", {call = false})
			end
		end
	end

	function on:please_rob_landlord()
		if self.pid == myid then
			if robot.should("rob_landlord") then
				skynet.sleep(math.random(80, 160))
				send_room("rob_landlord", {rob = true})
			else
				skynet.sleep(math.random(60, 120))
				send_room("rob_landlord", {rob = false})
			end
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

	function on:determine_landlord()
		robot.determine_landlord(self.landlord_id, self.bottom_cards)
	end

	function on:please_double()
		skynet.sleep(math.random(50, 250))
		if robot.should("double") then
			local multiple = 2
			if math.random() < 0.4 then
				multiple = 4
			end
			send_room("double", {multiple = 2})
		else
			send_room("double", {multiple = 1})
		end
	end

	function on:please_double_cap()
		skynet.sleep(math.random(50, 250))
		if robot.should("double_cap") then
			send_room("double_cap", {multiple = 4})
		else
			send_room("double_cap", {multiple = 1})
		end
	end


	function on:please_playcard()
		if self.pid == myid then
			skynet.sleep(math.random(150, 350))
			send_room("playcard", robot.playcard(self.playstatus))
		end
	end

	function on:p_playcard()
		robot.p_playcard(self.pid, self.pass, self.playedcards)
	end

	function on:gameover()
		local bills = assert(self.bills)
		for i,p in ipairs(bills) do
			if p.id == myid then
				ec.pub{type = "robot_gameover", id = myid, index = myindex, win_gold = p.win_gold}
			end
		end
		skynet.exit()
	end


	local command = {}


	function command.room_push(source, name, args)
		room_addr = source

		local f = on[name]
		if f then
			f(args)
		end
	end


	function command.RoomUserInfoGet(source, name, args)
		return {
			gold = me.gold,
			nickname = me.nick,
			head = me.head,
			lv = math.random(1, 3),
			vip = myindex%5,
			gender = me.gender,
			skin = math.random(0, 1) == 1 and 104001 or 104002,
		}
	end


	-- init
	skynet.fork(function ()
		local showcardx5 = math.random() < conf.prob.showcardx5 and true or false

		skynet.call("ddz_match_mgr", "lua", "StartMatch", gametype, roomtype, {
			id = myid,
			addr = skynet.self(),
			robot = true,
			gold = me.gold,
			showcardx5 = showcardx5,
			gamec = 10,
			gameCountSum = me.gameCountSum,
            winCountSum = me.winCountSum,
		}, gameSubType)
	end)


	return function (source, cmd, ...)
		local f = command[cmd]
		if f then
			return f(source, ...)
		end
	end
end