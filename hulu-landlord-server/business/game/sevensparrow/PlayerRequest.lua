local common = require "common_mothed"

return function (Player)

	function Player:ssw_card_recorder()
		if not self.useCardRecord then
			if self.isUser and not common.hasItem(self.addr, {{id = ItemID.GameCardRecordDay, num = 1}}, 1, true) then
				if not common.hasItem(self.addr, {{id = ItemID.GameCardRecord, num = 1}}, 1, true) then
					local shopId = 500001
					local ok, retVal = common.buyStore(self.addr, shopId, 1, true)
					if not ok then
						return {e_info = RET_VAL.Empty_7, storeRet = retVal}
					end
				end

				if not common.removeItem(self.addr, ItemID.GameCardRecord, 1, "RoomCardRecordInfo_记牌器") then
					return RET_VAL.Lack_6
				end
			end
			self.useCardRecord = true
		end
		return RET_VAL.Succeed_1
	end

	--点赞pid
	function Player:ssw_praise(params)
		local pid = assert(params.pid)
		self.room:praise(self,pid)
		--todo skynet.call A给B点赞
	end


	function Player:ssw_room_info()
		local room = self.room
		local info = {
			id = room.id,
			conf = room.conf,
			status = room.status,
			selectional_cards = room.selectional_cards,
			discard_cards = room.discard_cards,
			cardnum = #room.pool,
			all_bills = room.all_bills,
			players = {}
		}

		for _,p in ipairs(room.players) do
			local t = {
				id = p.id,
				data = common.toUserBase(p),
				gold = p.gold,
				isUser = p.isUser,							-- 只在服务器使用
				isOpenRecycle = p.isOpenRecycle,			-- 只在服务器使用

				chair = p.chair,
				status = p.status,
				clock = math.floor(p.clock),
				is_trusteeship = p.is_trusteeship,
				is_first = p.is_first,
				cardnum = #p.cards,
				cards = p.id == self.id and p.cards or {},
				flowers = p.flowers,
				hu_cards = p.hu_cards,
				banChat = p.banChat,
				fixed_events = p.fixed_eventIdArr,--兼容旧代码
				useCardRecord = p.useCardRecord,
				gameCountSum = p.gameCountSum,
				winCountSum = p.winCountSum,

				skillId = p.skillId,
				skillState = p.skillState,
			}

			table.insert(info.players, t)
		end

		return {room = info}
	end


	return Player
end