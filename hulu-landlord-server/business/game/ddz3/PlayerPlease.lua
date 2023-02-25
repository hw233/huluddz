local skynet = require "skynet"
local timer = require "timer"

local TIME = {
	call_landlord = 10,
	rob_landlord = 10,
	overlord_rob_landlord = 5,
	double = 8,
	double_cap = 8,
	playcard = 20
}

return function (Player)

	function Player:please_playcard(playstatus)
		self.status = PlayerState_DDZ.Playing
		self.playstatus = playstatus
		if self.is_trusteeship then
			self:auto_play()
		else
			self.clock = TIME.playcard
			self.cancel_timer = timer.create(100, function ()
				self.clock = self.clock - 1
			end, TIME.playcard, function ()
				self:auto_play()
				self:trusteeship()
			end)
			self.room:radio("please_playcard", {pid = self.id, clock = TIME.playcard, playstatus = playstatus})
		end
	end

	function Player:please_double_cap()
		self.status = PlayerState_DDZ.DoubleMax
		if self.is_trusteeship then
			self:double_cap{multiple = 1}
		else
			self.clock = TIME.double_cap
			self.cancel_timer = timer.create(100, function ()
				self.clock = self.clock - 1
			end, TIME.double_cap, function ()
				self:double_cap{multiple = 1}
			end)
			self:send_push("please_double_cap", {clock = TIME.double_cap})
		end
	end

	function Player:please_double()
		self.status = PlayerState_DDZ.Doubleing
		if self.is_trusteeship then
			self:double{multiple = 1}
		else
			self.clock = TIME.double
			self.cancel_timer = timer.create(100, function ()
				self.clock = self.clock -1
			end, TIME.double, function ()
				self:double{multiple = 1}
			end)
			self:send_push("please_double", {clock = TIME.double})
		end
	end

	function Player:please_overlord_rob_landlord(qualified)
		if qualified then
			self.status = PlayerState_DDZ.OverlordRobLandlord
		else
			self.status = PlayerState_DDZ.Waiting
		end
		self.clock = TIME.overlord_rob_landlord
		self.cancel_timer = timer.create(100, function ()
			self.clock = self.clock -1
		end, TIME.overlord_rob_landlord, function ()
			self:overlord_rob_landlord_timeout()
		end)
		self:send_push("please_overlord_rob_landlord", {clock = TIME.overlord_rob_landlord, qualified = qualified})
	end

	function Player:please_rob_landlord()
		self.status = PlayerState_DDZ.RobLandlord
		if self.is_trusteeship then
			self:rob_landlord{rob = false}
		else
			self.clock = TIME.rob_landlord
			self.cancel_timer = timer.create(100, function ()
				self.clock = self.clock - 1
			end, TIME.rob_landlord, function ()
				self:rob_landlord{rob = false}
				self:trusteeship()
			end)
			self.room:radio("please_rob_landlord", {clock = TIME.rob_landlord, pid = self.id})
		end
	end

	function Player:please_call_landlord()
		self.status = PlayerState_DDZ.CallLandlord

		if self.is_trusteeship then
			self:call_landlord{call = false}
		else
			self.clock = TIME.call_landlord
			self.cancel_timer = timer.create(100, function ()
				self.clock = self.clock - 1
			end, TIME.call_landlord, function ()
				self:call_landlord{call = false}
				self:trusteeship()
			end)
			self.room:radio("please_call_landlord", {clock = TIME.call_landlord, pid = self.id})
		end
	end

	return Player
end