local skynet = require "skynet"
local datax = require "datax"
local common = require "common_mothed"
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
		assert(self.banChat == false)
		self.room:radio("PlayerGameChat", {pid = self.id, id = params.id, type = params.type})
	end

	function Player:EmoticonSend(params)
		local sData = datax.emoticon[params.id]
        if not sData or params.toId == self.id or not self.room:find_player(params.toId) then
            return RET_VAL.ERROR_3
        end

        if self.banChat then
            return RET_VAL.Fail_2
        end

        -- 目前只有专属需要限制，其他的不限制了
        if sData.expression_type == 3 then
            if sData.role_id ~= self.skin then
                return RET_VAL.NoUse_8
            end
        end

		if next(sData.expression_cost) then
			local costGold = table.sum(sData.expression_cost, function (key, value)
				return value.id == ItemID.Gold and value.num or 0
			end)
			if costGold > 0 and self.gold - costGold < self.room.cfgData.min then
				return RET_VAL.NotOpen_9
			end

			if not common.removeListItem(self.addr, sData.expression_cost, 1, "RoomEmoticonSend_房间表情发送") then
				return RET_VAL.Lack_6
			end
		end

        self.room:radio("RoomEmoticonSend_C", {id = params.id, fromId = self.id, toId = params.toId})

        return RET_VAL.Succeed_1
	end

	function Player:mute(params)
		local cfgData = self.room.cfgData
		local cost = math.ceil(cfgData.mute_cost * discount.mute(self.realvip))
		assert(self.gold > cost)
		assert(params.to ~= self.id)

		local p = assert(self.room:find_player(params.to))
		if self.realvip <= p.realvip then
			return {err = GAME_ERROR.vip_need_bigger}
		end

		assert(p.banChat == false)
		p.banChat = true

		self.room:radio("p_mute", {from = self.id, to = params.to, cost = cost})
		return {}
	end
	return Player
end