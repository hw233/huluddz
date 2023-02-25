local skynet = require "skynet"
local datax = require "datax"
local objx = require "objx"
local common = require "common_mothed"
--local ec = require "eventcenter"
local util = require "util.ddz_classic"
local roomData = require "roomData"

return function (Player)

	function Player:GameChat(params)
        if not params.id then
            return RET_VAL.ERROR_3
        end
        if self.banChat then
            return RET_VAL.Fail_2
        end
		self.roomObj.sendToPlayerAll("PlayerGameChat", {pid = self.id, id = params.id, type = params.type})
	end

	function Player:EmoticonSend(params)
		local sData = datax.emoticon[params.id]
        if not sData or params.toId == self.id or not self.roomObj.getPlayer(params.toId) then
            return RET_VAL.ERROR_3
        end

        if self.banChat then
            return RET_VAL.Fail_2
        end

        -- 目前只有专属需要限制，其他的不限制了
        if sData.expression_type == 3 then
            if sData.role_id ~= self.userObj.skin then
                return RET_VAL.NoUse_8
            end
        end

        if next(sData.expression_cost) then
            local costGold = table.sum(sData.expression_cost, function (key, value)
                return value.id == ItemID.Gold and value.num or 0
            end)
            if costGold > 0 and self.userObj.gold - costGold < self.roomObj.cfgData.min then
                return RET_VAL.NotOpen_9
            end

            if not common.removeListItem(self.userObj.addr, sData.expression_cost, 1, "RoomEmoticonSend_房间表情发送") then
                return RET_VAL.Lack_6
            end
        end

        self.roomObj.sendToPlayerAll("RoomEmoticonSend_C", {id = params.id, fromId = self.id, toId = params.toId})

        return RET_VAL.Succeed_1
	end

    function Player:CardRecordInfo()
		if not self.useCardRecord then
			if self.isUser and not common.hasItem(self.userObj.addr, {{id = ItemID.GameCardRecordDay, num = 1}}, 1, true) then
				if not common.hasItem(self.userObj.addr, {{id = ItemID.GameCardRecord, num = 1}}, 1, true) then
					local shopId = 500001
					local ok, retVal = common.buyStore(self.userObj.addr, shopId, 1, true)
					if not ok then
						return {e_info = RET_VAL.Empty_7, storeRet = retVal}
					end
				end

				if not common.removeItem(self.userObj.addr, ItemID.GameCardRecord, 1, "RoomCardRecordInfo_记牌器") then
					return RET_VAL.Lack_6
				end
			end
			self.useCardRecord = true
		end
		return RET_VAL.Succeed_1
	end

    return Player
end