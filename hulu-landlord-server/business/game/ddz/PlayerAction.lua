local skynet = require "skynet"
local ec = require "eventcenter"

local datax = require "datax"
local objx = require "objx"
local common = require "common_mothed"

local util = require "util.ddz_classic"
local roomData = require "roomData"

return function (Player)

	function Player:SyncRoomData(params)
		local id = params.id

		if id == ItemID.Gold then
			self.userObj.gold = params.num
			self.roomObj.sendToPlayerAll("RoomSyncPlayerData_C", {id = self.id, gold = self.userObj.gold})
		end

	end

	function Player:ShowCard()
		if self.isShowcard then
			return RET_VAL.ERROR_3
		end

		if self.roomObj.state < RoomState_DDZ.Doubleing then
			self.roomObj.addMultiple(RoomMultipleKey.ShowCard, nil, self.id)

			-- 其他阶段不让明牌了
			-- elseif self.state == PlayerState_DDZ.Playing and self.playCardState == PlayCardState_DDZ.First then
			-- self.roomObj.addMultiple(RoomMultipleKey.ShowCard)
		else
			skynet.loge("invalid action showcard, state =" .. self.state)
		end

		self.isShowcard = true
		self.roomObj.sendToPlayerAll("RoomShowCard_C", {id = self.id, cards = self.cards})
	end

	function Player:SetTrusteeship(params)
		local isTrusteeship = not not params.isTrusteeship
		if isTrusteeship == self.isTrusteeship then
			return
		end
		
		self.isTrusteeship = isTrusteeship
		self.roomObj.sendToPlayerAll("RoomSetTrusteeship_C", {id = self.id, isTrusteeship = isTrusteeship})

		if isTrusteeship and self.state ~= PlayerState_DDZ.Waiting then
			self:trusteeshipAction(self.state)
		end

		-- if isTrusteeship and self.state ~= PlayerState_DDZ.Waiting then
		--	self:clearClock() -- 既然托管状态保证能调用成功就无需在这里取消定时器
		-- 	self:trusteeshipAction(self.state)
		-- end
	end

    function Player:CallLandlord(params)
		local type = params.type
		
		if self.state ~= PlayerState_DDZ.CallLandlord then
			return RET_VAL.ERROR_3
		end
		--assert(self.state == PlayerState_DDZ.CallLandlord, self.state)
		assert(type == PlayerAction_DDZ.CallLandlord or type == PlayerAction_DDZ.NotCall)

        self.state = PlayerState_DDZ.Waiting

		self:clearClock()
        self:addAction(type)
		self.roomObj.sendToPlayerAll("RoomSyncPlayerAction_C", {id = self.id, type = type})

		if type == PlayerAction_DDZ.CallLandlord then
			self.roomObj.addMultiple(RoomMultipleKey.CallLandlord, nil, self.id)
		end

		self.roomObj.actionEnd(self, type)
	end

	function Player:RobLandlord(params)
		local type = params.type

		if self.state ~= PlayerState_DDZ.RobLandlord then
			return RET_VAL.ERROR_3
		end
		--assert(self.state == PlayerState_DDZ.RobLandlord)
		assert(type == PlayerAction_DDZ.RobLandlord or type == PlayerAction_DDZ.NotRob)

		self.state = PlayerState_DDZ.Waiting

		self:clearClock()
		self:addAction(type)
		local robLandlordCount = table.sum(self.roomObj.players, function (key, value)
			return value.lastAction == PlayerAction_DDZ.RobLandlord and 1 or 0
		end)
		self.roomObj.sendToPlayerAll("RoomSyncPlayerAction_C", {id = self.id, type = type, nrob = robLandlordCount})

		if type == PlayerAction_DDZ.RobLandlord then
            self.roomObj.addMultiple(RoomMultipleKey.RobLandlord, nil, self.id)
        end

		self.roomObj.actionEnd(self, type)
	end

	function Player:ForceRobLandlord(params)
		if self.roomObj.landlordPlayer then
			return RET_VAL.Fail_2
		end

		if not (self.roomObj.state >= RoomState_DDZ.CallLandlord and self.roomObj.state <= RoomState_DDZ.RobLandlord) then
			return RET_VAL.ERROR_3
		end

		if not self.skillState or self.skillBuffCfg.skill_id ~= 1040101 then
			return RET_VAL.NoUse_8
		end

		self.roomObj.sendToPlayerAll("RoomSyncPlayerAction_C", {id = self.id, skillId = self.skillBuffCfg.skill_id})

		self.roomObj.actionStopAll()

		self.roomObj.addMultiple(RoomMultipleKey.Skill, self.skillBuffCfg.magnification, self.id)

		self.roomObj.setLandlord(self, roomData.getRoomEffectDelayTime(self.userObj.skin, {"skill_" .. self.skillBuffCfg.skill_id}))

		ec.pub({type = EventCenterEnum.HeroSkillUse, id = self.id, skillId = self.skillBuffCfg.skill_id})

		return RET_VAL.Succeed_1
	end

	function Player:Double(params)
		local type = params.type
		local multipleObj = {
			[PlayerAction_DDZ.NotDouble] = 1,
			[PlayerAction_DDZ.Double_2] = roomData.multipleInfo.double,
			[PlayerAction_DDZ.Double_4] = roomData.multipleInfo.doubleSuper,
		}
		local multiple = multipleObj[type]
		if not multiple then
			return RET_VAL.ERROR_3
		end

		if type == PlayerAction_DDZ.Double_4 and self.isUser then
			if not common.hasItem(self.userObj.addr, {{id = ItemID.GameDoubleSuper, num = 1}}, 1, true) then
				local shopId = 500006
				local ok, retVal = common.buyStore(self.userObj.addr, shopId, 1, true)
				if not ok then
					return {e_info = RET_VAL.Empty_7, storeRet = retVal}
				end
				if self.state ~= PlayerState_DDZ.Doubleing then
					return RET_VAL.Exists_4
				end
			end
		end

		if self.state ~= PlayerState_DDZ.Doubleing then
			return RET_VAL.Fail_2
		end

		if type == PlayerAction_DDZ.Double_4 and self.isUser then
			if not common.removeItem(self.userObj.addr, ItemID.GameDoubleSuper, 1, "RoomDouble_超级加倍") then
				return RET_VAL.Lack_6
			end

			-- 无需判断 计时器已进队列
			-- if self.state ~= PlayerState_DDZ.Doubleing then
			-- 	return RET_VAL.ERROR_3
			-- end
		end

		self.state = PlayerState_DDZ.Waiting
		self:clearClock()
		self:addAction(type)
		self.doubleAction = type
		self.doubleMultiple = multiple
		self.roomObj.sendToPlayerAll("RoomSyncPlayerAction_C", {id = self.id, type = type, use_diamond = use_diamond})

		if type ~= PlayerAction_DDZ.NotDouble then
            self.roomObj.addMultiple(type == PlayerAction_DDZ.Double_2 and RoomMultipleKey.Double or RoomMultipleKey.DoubleSuper, multiple, self.id)
            -- if player.isLandlord then
            --     roomObj.syncMultiple()
            -- else
            --     player:syncMultiple()
            --     roomObj.landlordPlayer:syncMultiple()
            -- end
        end

		self.roomObj.actionEnd(self, type)

		ec.pub({type = EventCenterEnum.RoomGameDouble, id = self.id, doubleAction = self.doubleAction, doubleMultiple = self.doubleMultiple})
		return RET_VAL.Succeed_1
	end

	function Player:DoubleMax(params)
		local type = params.type
		local multipleObj = {
			[PlayerAction_DDZ.NotDoubleMax] = 1,
			[PlayerAction_DDZ.DoubleMax] = roomData.multipleInfo.doubleMax,
		}
		local multiple = multipleObj[type]
		if not multiple then
			return RET_VAL.ERROR_3
		end

		local isCost = true
		if type == PlayerAction_DDZ.DoubleMax and self.isUser then
			if self.skillState and self.userObj.skin == HeroId.TangBaoEr then
				isCost = not skynet.call(self.userObj.addr, "lua", "UserHeroSkillUse", self.userObj.heroId)
			end

			if isCost and not common.hasItem(self.userObj.addr, {{id = ItemID.GameDoubleMax, num = 1}}, 1, true) then
				local shopId = 500007
				local ok, retVal = common.buyStore(self.userObj.addr, shopId, 1, true)
				if not ok then
					return {e_info = RET_VAL.Empty_7, storeRet = retVal}
				end
				if self.state ~= PlayerState_DDZ.DoubleMax then
					return RET_VAL.Exists_4
				end
			end
		end

		if self.state ~= PlayerState_DDZ.DoubleMax then
			return RET_VAL.Fail_2
		end

		if isCost and type == PlayerAction_DDZ.DoubleMax and self.isUser then
			if not common.removeItem(self.userObj.addr, ItemID.GameDoubleMax, 1, "RoomDoubleMax_封顶翻倍") then
				return RET_VAL.Lack_6
			end
		end

		self.state = PlayerState_DDZ.Waiting
		self:clearClock()
		self:addAction(type)
		self.doubleMaxAction = type
		self.doubleMaxMultiple = multiple

		-- TODO: sad
		local max = multiple > 1 and self.roomObj.getMultipleMax() or nil
		--self.roomObj.sendToPlayerAll("RoomSyncPlayerAction_C", {id = self.id, type = type, top = top, use_diamond = use_diamond})
		self.roomObj.sendToPlayerAll("RoomSyncPlayerAction_C", {id = self.id, type = type, use_diamond = use_diamond})

		if type ~= PlayerAction_DDZ.NotDoubleMax then
            self.roomObj.addMultiple(RoomMultipleKey.DoubleMax, multiple, self.id)
            -- if player.isLandlord then
            --     roomObj.syncMultiple()
            -- else
            --     player:syncMultiple()
            --     roomObj.landlordPlayer:syncMultiple()
            -- end
        end

		self.roomObj.actionEnd(self, type)
		ec.pub({type = EventCenterEnum.RoomGameDoubleMax, id = self.id, doubleMaxAction = self.doubleMaxAction, doubleMaxMultiple = self.doubleMaxMultiple})
		return RET_VAL.Succeed_1
	end

	function Player:PlayCard(params)
		skynet.logd("Room PlayCard ", self.id, table.tostr(params))

		local type = params.type
		if self.state ~= PlayerState_DDZ.Playing then
			return RET_VAL.Fail_2
		end

		if type ~= PlayerAction_DDZ.Pass and type ~= PlayerAction_DDZ.PlayCard then
			return RET_VAL.ERROR_3
		end

		local pass = type == PlayerAction_DDZ.Pass
		local playCardObj = params.playCardObj
		local cards = playCardObj and playCardObj.cards

		if pass then
			if self.playCardState ~= PlayCardState_DDZ.Normal then
				return RET_VAL.ERROR_3
			end

			playCardObj = nil
		else
			if not cards then
				return RET_VAL.ERROR_3
			end
			
			local cardTypeObjArr = util.parseCardType(cards)
			assert(cardTypeObjArr, playCardObj.type)

			local cardTypeObj = table.first(cardTypeObjArr, function (key, value)
				return value.type == playCardObj.type
			end)
			if cardTypeObj then
				if playCardObj.weight ~= cardTypeObj.weight then
					playCardObj.weight = cardTypeObj.weight
					skynet.logi("PlayCard weight!", playCardObj.type, playCardObj.weight, cardTypeObj.weight)
				end
			else
				skynet.loge("test PlayCard error!", playCardObj.type)
			end
			playCardObj.subtype = cardTypeObj.subtype

			if self.playCardState == PlayCardState_DDZ.Normal and not util.compareCardType(playCardObj, self.roomObj.lastPlayCardObj.playCardObj) then
				error("card is too small")
			end
			for _, card in ipairs(cards) do
				assert(table.find_one(self.cards, card & 0xff))
			end
		end

		self.state = PlayerState_DDZ.Waiting

		self:clearClock()
		self:addAction(type)
		self.robotAgent.playCard(pass, playCardObj)
		self.roomObj.sendToPlayerAll("RoomSyncPlayerAction_C", {id = self.id, type = type, playCardObj = playCardObj})

		if not pass then
			table.insert(self.playedCards, playCardObj)
			self.playCount = self.playCount + 1

			for _, v in ipairs(cards) do
				for i, c in ipairs(self.cards) do
					if c == (v & 0xff) then
						table.remove(self.cards, i)
					end
				end
			end

			self.roomObj.lastPlayCardObj = {id = self.id, playCardObj = playCardObj, isLandlord = self.isLandlord}
		end

        if playCardObj then
			self.playCardCount = self.playCardCount + 1

            if playCardObj.type == util.CardType.zhadan then
                local ok, bombType = pcall(util.getBombType, playCardObj.weight)
                if ok then
                    self.roomObj.addMultiple(RoomMultipleKey.Bomb, roomData.multipleInfo[bombType], self.id)
                else
                    skynet.loge("Room Playing error! type: ", playCardObj.type, playCardObj.weight)
                end
            end

            if playCardObj.type == util.CardType.zhadan and self.roomObj.conf.roomtype >= 2 then
                --local zhadan = util.getBombType(playCardObj.weight)
                --if zhadan == "star_4_4" then
                    --local text = cft_marquee[4 + roomObj.conf.roomtype - 2].contents
                    --ec.pub{type = "immediate_horselamp", text = string.format(text, player.nick), times = 1, lv = HORSELAMP_LV.game_lianzha_4}
                --elseif zhadan == "star_4_5" then
                    --local text = cft_marquee[9 - (roomObj.conf.roomtype-2)].contents
                    --ec.pub{type = "immediate_horselamp", text = string.format(text, player.nick), times = 1, lv = HORSELAMP_LV.game_lianzha_5}
                --end
            end

			if playCardObj.subtype then
				local waitTime = roomData.getRoomEffectDelayTime(self.userObj.skin, {{type = playCardObj.type, subtype = playCardObj.subtype}})
				skynet.sleep(waitTime)
			end
        end

		self.roomObj.actionEnd(self, type)
	end

	function Player:BottomCardInfo(params)
		-- local index = params.index
		-- if not index or not self.roomObj.bottomCards[index] then
		-- 	return RET_VAL.ERROR_3
		-- end

		--local card = self.bottomCards[index]
		if not next(self.bottomCards) then
			if self.isUser then
				if not common.hasItem(self.userObj.addr, {{id = ItemID.GameBottomCardCheck, num = 1}}, 1, true) then
					local shopId = 500005
					local ok, retVal = common.buyStore(self.userObj.addr, shopId, 1, true)
					if not ok then
						return {e_info = RET_VAL.Empty_7, storeRet = retVal}
					end
				end

				if not common.removeItem(self.userObj.addr, ItemID.GameBottomCardCheck, 1, "RoomBottomCardInfoGet_底牌查看") then
					return RET_VAL.Lack_6
				end
			end
			self.bottomCards = self.roomObj.bottomCards
			--self.bottomCards[index] = card
		end
		return {e_info = RET_VAL.Succeed_1, cards = self.bottomCards}
	end

	local ShowBottomCardsStateArr = {
		[RoomState_DDZ.Doubleing] = true,
		[RoomState_DDZ.DoubleMax] = true,
		[RoomState_DDZ.Playing] = true,
		[RoomState_DDZ.Ended] = true,
	}

	function Player:GetRoomInfo()
		local roomObj = self.roomObj
		local info = {
			id = roomObj.id,
			conf = roomObj.conf,
			state = roomObj.state,
			bottomCards = ShowBottomCardsStateArr[roomObj.state] and roomObj.bottomCards or self.bottomCards,
			bottomCardMultiple = roomObj.multiple.bottomCard,
			players = {}
		}
	
		for _, p in ipairs(roomObj.players) do
			local isMe = p.id == self.id

			local data = {
				id = p.id,
				data = common.toUserBase(p.userObj),
				gold = p.userObj.gold,
				isUser = p.isUser,							-- 只在服务器使用
				isOpenRecycle = p.userObj.isOpenRecycle,	-- 只在服务器使用
	 
				pos = p.pos,
				cards = (isMe or p.isShowcard) and p.cards or {},
				cardNum = #p.cards,
				playedCards = p.playedCards,
				state = p.state,
				clock = p.clock,
				lastAction = p.lastAction,
	
				playCardState = p.playCardState,
	
				isShowcard = p.isShowcard,
				isTrusteeship = p.isTrusteeship,
				isLandlord = p.isLandlord,

				skillId = p.skillId,
				skillState = p.skillState,
	
				multiple = isMe and p:getMultiple() or nil,
				doubleAction = p.doubleAction,
				doubleMultiple = p.doubleMultiple,
				doubleMaxAction = p.doubleMaxAction,
				doubleMaxMultiple = p.doubleMaxMultiple,

				useCardRecord = p.useCardRecord,
				--banChat = p.banChat,
				--showcardx5 = p.showcardx5,
			}
	
			table.insert(info.players, data)
		end
	
		return {roomInfo = info}
	end

    return Player
end