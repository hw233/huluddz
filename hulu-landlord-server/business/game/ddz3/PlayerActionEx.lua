local skynet = require "skynet"
local ec = require "eventcenter"
local cft_vip = require "conftbl_ddz.vip"


return function (Player)

	local discount = {}

	function discount.mute(vip)
		local vip = cft_vip[vip]
		return vip and vip.mute_discount/10 or 1
	end

	function discount.magic(vip)
		local vip = cft_vip[vip]
		return vip and vip.expression_discount/10 or 1
	end

	function Player:game_report(params)
		local pid = assert(params.pid)
		local text = assert(params.content)
		ec.pub{type = "game_report", from = self.id, to = pid, text = text}
	end

	function Player:GameChat(params)
		assert(params.id)
		assert(self.muted == false)
		self.room:radio("PlayerGameChat", {pid = self.id, id = params.id, type = params.type})
	end

	function Player:unleash_magic(params)
		--local cost = math.ceil(cft_magic[params.id].expression_cost * discount.magic(self.realvip))
		-- assert(self.gold > cost)
		-- assert(params.to ~= params.id)
		-- assert(self.muted == false)
		-- assert(self.room:find_player(params.to))
		-- self.room:radio("p_unleash_magic", {from = self.id, to = params.to, id = params.id, cost = cost})
	end

	function Player:mute(params)
		local cf = self.room:realconf()
		local cost = math.ceil(cf.mute_cost * discount.mute(self.realvip))
		assert(self.gold > cost)
		assert(params.to ~= self.id)

		local p = assert(self.room:find_player(params.to))
		if self.realvip <= p.realvip then
			return {err = GAME_ERROR.vip_need_bigger}
		end

		assert(p.muted == false)
		p.muted = true

		self.room:radio("p_mute", {from = self.id, to = params.to, cost = cost})
		return {}
	end

	return Player
end