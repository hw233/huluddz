local util = require "util.ddz_classic"

return function (Room)

	function Room:on_player_playcard(p, playedcards)
		if playedcards.type == "zhadan" then
			local m = util.zhadan_multiple(playedcards.weight)
			self.multiple.bomb = self.multiple.bomb * m
			self:sync_multiple()
		end
	end

	function Room:on_player_double_cap(p, multiple)
		if multiple == 1 then
			return
		end
		
		if p.is_landlord then
			self:sync_multiple()
		else
			p:sync_multiple()
			self:find_landlord():sync_multiple()
		end
	end

	function Room:on_player_double(p, multiple)
		if multiple == 1 then
			return
		end

		if p.is_landlord then
			self:sync_multiple()
		else
			p:sync_multiple()
			self:find_landlord():sync_multiple()
		end
	end

	-- 霸王抢 2倍
	function Room:on_player_overlord_rob_landlord()
		self.multiple.rob_landlord = self.multiple.rob_landlord * 2
		self:sync_multiple()
	end

	function Room:on_player_rob_landlord()
		self.multiple.rob_landlord = self.multiple.rob_landlord * 2
		self:sync_multiple()
	end

	function Room:on_player_showcard(multiple)
		self.multiple.showcard = self.multiple.showcard * multiple
		self:sync_multiple()
	end

	return Room
end