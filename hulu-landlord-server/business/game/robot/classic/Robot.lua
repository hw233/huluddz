local skynet = require "skynet"
local arrayx = require "arrayx"
local util = require "util.ddz_classic"
local split_cards = require "game.robot.classic.split_cards"
local conf = require "config_ddz.robot"
local robot_ai = require "game.robot.algorithm.robot"
local robot_fellow_ai = require "game.robot.algorithm.robotFellowOut"


local V = util.V


--[[
一. 主动出牌:
	跟据已拆好的牌, 从小到大. (飞机/三带 (带对/单/不带), 单牌, 对牌, 顺子, 连对, 炸弹)

二. 遇见敌方出牌
	跟据拆好的牌, 从小到大找一个牌出，没有就过 (先找对应牌型, 然后炸弹)

三. 遇见友方出牌
	如果是炸弹 就过
	非炸弹 50%随机出(如果有对应牌型)
]]
local function Robot() --(room, myid)

	local handcards
	local type_list = {} 	-- {{type, weight, cards = {...}}, ...} (包含炸弹, 连对, 顺子)
	local three_list 		-- {{333444}, {777}}
	local dui_list 			-- {{22}, {33}, {55}}
	local dan_list 			-- {3478JAZ}
	local nzhadan, nhand

	local isLandlord = false

	local function zhadan_count()
		local c = 0
		for _,t in ipairs(type_list) do
			if t.type == "zhadan" then
				c = c + 1
			end
		end
		return c
	end

	-- 最少手数
	local function least_hand_count()

		local function other_count()
			local nthree = #three_list
			local ndui = #dui_list
			local ndan = #dan_list

			for i,tuples in ipairs(three_list) do
				local n = #tuples//3
				if ndui >= n then
					ndui = ndui - n
				elseif ndan >= n then
					ndan = ndan - n
				end
			end

			return nthree + ndui + ndan
		end

		return #type_list + other_count()
	end


	-- 获取 飞机(带对/单/不带) / 三带(一对, 一张, 不带)
	local function get_threeX()
		if #three_list == 0 then return end
		local three = three_list[1]
		local n = #three // 3
		local danLen = #dan_list
		if danLen >= n then
			local cards = table.copy(three)
			for i=1,n do
				table.insert(cards, dan_list[i][1])
			end
			return {type = n > 1 and "feiji_daidan" or "sandaiyi", weight = V(three[1]), cards = cards}
		elseif #dui_list >= n then
			local cards = table.copy(three)
			for i=1,n do
				table.append(cards, dui_list[i])
			end
			return {type = n > 1 and "feiji_daidui" or "sandaiyidui", weight = V(three[1]), cards = cards}
		elseif #dui_list * 2 + danLen >= n then
			assert(n > 1)
			-- TODO: m+2n = x
			local cards = table.copy(three)
			local ndan = 0
			local ndui = 0
			if (n - danLen) % 2 == 0 then
				ndan = danLen
			else
				ndan = danLen - 1
			end
			ndui = (n - ndan) / 2

			for i = 1, ndan do
				table.insert(cards, dan_list[i][1])
			end
			for i = 1, ndui do
				local duiArr = dui_list[i]
				local len = #duiArr
				if n >= len then
					table.append(cards, duiArr)
					n = n - len
				else
					table.append(cards, arrayx.slice(duiArr, 1, n))
					n = 0
					break;
				end
			end
			return {type = "feiji_daidan", weight = V(three[1]), cards = cards}
		end
	end

	local function get_playedcards()
		local threex = get_threeX()
		if threex then
			return threex
		end
		if #dan_list > 0 then
			return {type = "dan", weight = util.V(dan_list[1][1]), cards = dan_list[1]}
		end
		if #dui_list > 0 then
			return {type = "dui", weight = util.V(dui_list[1][1]), cards = dui_list[1]}
		end
		if #three_list > 0 then
			local three = three_list[1]
			return {type = #three == 3 and "tuple" or "feiji_budai", weight = util.V(three[1]), cards = three}
		end
		return assert(type_list[1])
	end


	local function remove_handcards(playedcards)
		local function remove_from_list(cardslist, card)
			for i,list in ipairs(cardslist) do
				for j,c in ipairs(list) do
					if c == card then
						return table.remove(list, j)
					end
				end
			end
		end

		local function clear_empty(cardslist)
			for i=#cardslist,1,-1 do
				local list = cardslist[i]
				if not next(list) then
					table.remove(cardslist, i)
				end
			end
		end

		local function remove_one(card)
			return remove_from_list(three_list, card) or remove_from_list(dui_list, card) or remove_from_list(dan_list, card)
		end

		local function remove(cards)
			for _,v in ipairs(cards) do
				assert(remove_one(v))
			end

			-- clear empty list
			clear_empty(three_list)
			clear_empty(dui_list)
			clear_empty(dan_list)
		end


		if table.find_one({"zhadan", "shunzi", "liandui"}, playedcards.type) then
			for i,v in ipairs(type_list) do
				if table.eq(v, playedcards) then
					table.remove(type_list, i)
					break
				end
			end
		else
			remove(playedcards.cards)
		end

		-- remove from handcards
		local function remove_one_from_handcards(one)
			for i,v in ipairs(handcards) do
				if v&0xff == one&0xff then
					return table.remove(handcards, i)
				end
			end
		end

		for i,v in ipairs(playedcards.cards) do
			remove_one_from_handcards(v)
		end
	end

	local function remove_from_handcards(playedcards)
		
		local function remove_one_from_handcards(one)
			for i,v in ipairs(handcards) do
				if v&0xff == one&0xff then
					return table.remove(handcards, i)
				end
			end
			error("remove_one_from_handcards failed", one)
		end
		
		for i,v in ipairs(playedcards.cards) do
			remove_one_from_handcards(v)
		end
	end

	local function find_shunzi_or_liandui(type, weight, length)
		for i,item in ipairs(type_list) do
			if item.type == type and item.weight > weight and #item.cards == length then
				return item
			end
		end
	end

	local searcher = {}

	function searcher.dan(playedcards)
		for _,cards in ipairs(dan_list) do
			if V(cards[1]) > playedcards.weight then
				return {type = "dan", weight = V(cards[1]), cards = cards}
			end
		end
	end

	function searcher.dui(playedcards)
		for _,cards in ipairs(dui_list) do
			if V(cards[1]) > playedcards.weight then
				return {type = "dui", weight = V(cards[1]), cards = cards}
			end
		end
	end

	function searcher.tuple(playedcards)
		for _,cards in ipairs(three_list) do
			if #cards == 3 and V(cards[1]) > playedcards.weight then
				return {type = "tuple", weight = V(cards[1]), cards = cards}
			end
		end
	end

	function searcher.sandaiyi(playedcards)
		if #dan_list > 0 then
			for _,cards in ipairs(three_list) do
				if #cards == 3 and V(cards[1]) > playedcards.weight then
					local cards = table.copy(cards)
					table.insert(cards, dan_list[1][1])
					return {type = "sandaiyi", weight = V(cards[1]), cards = cards}
				end
			end
		end
	end

	function searcher.sandaiyidui(playedcards)
		if #dui_list > 0 then
			for _,cards in ipairs(three_list) do
				if #cards == 3 and V(cards[1]) > playedcards.weight then
					local cards = table.copy(cards)
					table.append(cards, dui_list[1])
					return {type = "sandaiyidui", weight = V(cards[1]), cards = cards}
				end
			end
		end
	end

	function searcher.feiji_budai(playedcards)
		for _,cards in ipairs(three_list) do
			if #cards == #playedcards.cards and V(cards[1]) > playedcards.weight then
				return {type = "feiji_budai", weight = V(cards[1]), cards = cards}
			end
		end
	end

	function searcher.feiji_daidan(playedcards)
		local nthree = #playedcards.cards//4
		if #dan_list >= nthree or ((nthree - #dan_list)%2 == 0 and (#dui_list*2 >= (nthree - #dan_list))) then
			for _,cards in ipairs(three_list) do
				if #cards == #playedcards.cards and V(cards[1]) > playedcards.weight then
					local cards = table.copy(cards)

					local count = 0
					for i,dan in ipairs(dan_list) do
						table.insert(cards, dan[1])
						count = count + 1
						if count == nthree then
							break
						end
					end

					if count < nthree then
						for i,dui in ipairs(dui_list) do
							table.append(cards, dui)
							count = count + 2
							if count == nthree then
								break
							end
						end
					end
					assert(count == nthree)

					return {type = "feiji_daidan", weight = V(cards[1]), cards = cards}
				end
			end
		end
	end

	function searcher.feiji_daidui(playedcards)
		local nthree = #playedcards.cards//5
		if #dui_list >= nthree then
			for _,cards in ipairs(three_list) do
				if #cards == #playedcards.cards and V(cards[1]) > playedcards.weight then
					local cards = table.copy(cards)
					for i=1,nthree do
						table.append(cards, dui_list[i])
					end
					return {type = "feiji_daidui", weight = V(cards[1]), cards = cards}
				end
			end
		end
	end

	local function find_zhadan(playedcards)
		for i,t in ipairs(type_list) do
			if t.type == "zhadan" then
				if playedcards.type ~= "zhadan" or t.weight > playedcards.weight then
					return t
				end
			end
		end
	end

	local function find_bigger(playedcards)
		local s = searcher[playedcards.type]
		local r
		if s then
			r = s(playedcards)
		end
		if not r then
			r = find_zhadan(playedcards)
		end
		return r
	end


	local function find_bigger_except_zhadan(playedcards)
		local s = searcher[playedcards.type]
		return s and s(playedcards)
	end


	local self = {}


	local function after_enemy_playcard(playedcards)
		local result = find_bigger(playedcards)
		if result then
			return {pass = false, playedcards = result}
		else
			return {pass = true}
		end
	end

	local function after_friend_playcard(playedcards)

		-- 如果是最后一手牌就打出去
		local result = find_bigger(playedcards)
		if result and #result.cards == #handcards then
			return {pass = false, playedcards = result}
		end

		if playedcards.type == "zhadan" then
			return {pass = true}
		else
			-- 一定概率跟牌 (友方权重越高(1 ~ 0xf), 跟牌概率越低)
			if math.random() <= (0xf-playedcards.weight)/0xf - 0.1 then
				result = find_bigger_except_zhadan(playedcards)
				if result then
					return {pass = false, playedcards = result}
				else
					return {pass = true}
				end
			else
				return {pass = true}
			end
		end
	end

	self.getPlayCardObj = function (playstate, isLastPlayerFriend, lastPlayerPlayCardObj, roomData)
		-- 跟据已拆好的牌, 从小到大. (飞机/三带 (带单/对/不带), 单牌, 对牌, 顺子, 连对, 炸弹)
		if playstate == PlayCardState_DDZ.Normal then
			if roomData then
				--out_data= {playedcards={cards={1=19, 2=67, 3=35, 4=51, }, weight=515, type=zhadan, }, pass=false, }
				robot_ai:print(roomData.pList[roomData.index].id, roomData.lastPlayerId, "【fellow】start----------------------------")
				local out_data = robot_fellow_ai:FollowOutCardEx(roomData)
				if out_data and next(out_data) then
					robot_ai:print(roomData.pList[roomData.index].id, roomData.lastPlayerId, "【fellow】end:getPlayCardObj:out_data1=", robot_ai:pTable(out_data))
					return out_data
				else 
					out_data = {pass = true}
					robot_ai:print(roomData.pList[roomData.index].id, roomData.lastPlayerId, "【fellow】end:getPlayCardObj:out_data2=", robot_ai:pTable(out_data))
					return out_data
				end
				robot_ai:print(roomData.pList[roomData.index].id, roomData.lastPlayerId, "【fellow】end----------------------------")
			end
			local out_data
			if isLastPlayerFriend then
				out_data = after_friend_playcard(lastPlayerPlayCardObj)
			else
				out_data = after_enemy_playcard(lastPlayerPlayCardObj)
			end
			robot_ai:print("【fellow】end,  getPlayCardObj:out_data3=", robot_ai:pTable(out_data))
			return out_data
		else
			if true and roomData then
				robot_ai:print(roomData.pList[roomData.index].id, roomData.lastPlayerId, "【first】start----------------------------")
				local firstOutCard = robot_ai:GetFirstOutCardEx(roomData)
				if firstOutCard then
					-- return firstOut
					local firstOut = {
						pass = false,
						playedcards = firstOutCard
					}
					robot_ai:print(roomData.pList[roomData.index].id, roomData.lastPlayerId, "【first_end】=",  robot_ai:pTable(firstOut))
					robot_ai:print(roomData.pList[roomData.index].id, roomData.lastPlayerId, "【first】end----------------------------")
					return firstOut
				end

				robot_ai:print(roomData.pList[roomData.index].id, roomData.lastPlayerId, "【first_end】error !!!!!!!")
			end

			local firstOut = {
				pass = false,
				playedcards = get_playedcards()
			}
			robot_ai:print("firstOut2=",  robot_ai:pTable(firstOut))
			return firstOut
		end
	end

	self.playCard = function (pass, playCardObj)
		if not pass then
			remove_from_handcards(playCardObj)
			self.init_handcards(handcards)
		end
	end

	self.setLandlord = function (bottomCards)
		isLandlord = true
		table.append(handcards, bottomCards)
		type_list, three_list, dui_list, dan_list = split_cards(handcards)
		nzhadan = zhadan_count()
		nhand = least_hand_count()
	end

	function self.init_handcards(cards)
		handcards = cards
		type_list, three_list, dui_list, dan_list = split_cards(handcards)
		nzhadan = zhadan_count()
		nhand = least_hand_count()
	end

	function self.good_cards()
		return nzhadan >= 3 or nhand <= 5
	end

	local function roll(action)
		if self.good_cards() then
			return math.random() < conf.prob.good_cards[action]
		else
			return math.random() < conf.prob.bad_cards[action]
		end
	end

	function self.should(action)
		return roll(action)
	end

	function self.GetHandcards()
		return handcards
	end

	return self
end


return Robot