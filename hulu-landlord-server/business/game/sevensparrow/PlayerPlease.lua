local skynet = require "skynet"
local timer = require "timer"
local objx  = require "objx"

local TIME = {
	takecard = 20,	 	-- 包含出牌时间
	recharge = 20
}

return function (Player)


	function Player:please_recharge(timeleft)
		self.room:add_action(self.id, "please_recharge")
		self.status = PlayerState_QQP.Recharging

		local goldChange = table.sum(self.room.all_bills, function (key, value)
			return value.id == self.id and value.win_gold or 0
		end)
		goldChange = math.abs(goldChange)
		self.goldBrokeLast = goldChange - self.goldBrokeLast

		self.room:radio("ssw_please_recharge", {pid = self.id, clock = TIME.recharge, goldBrokeLast = self.goldBrokeLast})

		if self.is_trusteeship then
			skynet.sleep(100)
			self:ssw_giveup()
		else
			self.clock = timeleft or TIME.recharge
			self.cancel_timer = timer.create(100, function ()
				self.clock = self.clock - 1
			end, self.clock, function ()
				self:ssw_giveup()
			end)
		end
	end


	function Player:please_playcard(timeleft)
		self.room:add_action(self.id, "please_playcard")
		self.status = PlayerState_QQP.Playing
		if timeleft < 1 then
			timeleft = 1
		end

		-- self.clock = timeleft
		-- self.room:radio("ssw_please_playcard", {pid = self.id, clock = self.clock})

		-- local trusteeship = self.is_trusteeship
		-- if trusteeship then
		-- 	self:auto_play()
		-- else
		-- 	self.cancel_timer = timer.create(100, function ()
		-- 		self.clock = self.clock - 1
		-- 	end, timeleft, function ()
		-- 		self:auto_play()

		-- 		if not trusteeship then
		-- 			self:trusteeship()
		-- 		end
		-- 	end)
		-- end


		self.clock = timeleft
		self.room:radio("ssw_please_playcard", {pid = self.id, clock = math.floor(self.clock)})

		local trusteeshipTime = objx.toInt(math.random(10, 20) + (timeleft - math.floor(self.clock)) * 10)
        self.cancel_timer = timer.create(10, function ()
			self.clock = self.clock - 0.1
            trusteeshipTime = trusteeshipTime - 1
        end, trusteeshipTime, function ()
			if self.is_trusteeship then
                self:trusteeshipAction(self.status)
			else
				self.clock = math.ceil(self.clock)
				if self.clock <= 0 then
					self:trusteeship()
				else
					self.cancel_timer = timer.create(100, function ()
						self.clock = self.clock - 1
					end, self.clock, function ()
						self:trusteeship()
					end)
				end
            end
        end)
	end

	--[[

	]]
	function Player:please_takecard(is_first, NO_1)
		self.room:add_action(self.id, "please_takecard")
		self.status = PlayerState_QQP.Takeing
		if is_first then
			self.is_first = true
		end

		-- 天眼 (七雀牌模式下可以看到当前牌堆最上方的一张牌是什么牌)
		local pool_last_one
		if #self.room.pool > 0 and self.is_anchor and math.random(1, 100) <= 50 then
			pool_last_one = self.room.pool[#self.room.pool]
		end
		
		self.clock = TIME.takecard
		self.room:radio("ssw_please_takecard", {pid = self.id, clock = self.clock, first = is_first, pool_last_one = pool_last_one, NO_1 = NO_1})
		
		local trusteeshipCheckTime = 2
		local trusteeshipTime = math.random(10, 15)
        self.cancel_timer = timer.create(10, function ()
			self.clock = self.clock - 0.1
            trusteeshipTime = trusteeshipTime - 1
			if trusteeshipTime <= 0 and self.is_trusteeship then
				self:trusteeshipAction(self.status)
			end
        end, 10 * trusteeshipCheckTime, function ()
			self.clock = math.ceil(self.clock)
			self.cancel_timer = timer.create(100, function ()
				self.clock = self.clock - 1
			end, self.clock, function ()
				if self.is_trusteeship then
					self:trusteeshipAction(self.status)
				else
					self:trusteeship()
				end
			end)
        end)

		-- if self.is_trusteeship then
		-- 	self.room:radio("ssw_please_takecard", {pid = self.id, clock = self.clock, first = is_first, pool_last_one = pool_last_one, NO_1 = NO_1})
		-- 	--自动摸牌也有clock 在ssw_take中cancle
		-- 	self:auto_take()
		-- else
		-- 	self.cancel_timer = timer.create(100, function ()
		-- 		self.clock = self.clock - 1
		-- 	end, self.clock, function ()
		-- 		self:trusteeship()
		-- 	end)
		-- 	self.room:radio("ssw_please_takecard", {pid = self.id, clock = self.clock, first = is_first, pool_last_one = pool_last_one, NO_1 = NO_1})
		-- end
	end

	return Player
end