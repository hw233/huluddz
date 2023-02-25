local skynet = require "skynet"
local arrayx = require "arrayx"
local cardx = require "cardx"
local qqp_algo = require "util.qique"
local skills = require "config_ddz.skills"
local sharetable = require "skynet.sharetable"

local dealcard = {}

local SKILL_LEPER = 10

local function create_a_pair_cards()
	return {
		0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d,
		0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d,
		0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d,
		0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d,
		0x5e, 0x5f
	}
end

local function create_two_pair_cards()
	return {
		0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d,--方块
		0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d,--梅花
		0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d,--红心
		0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d,--黑桃
		0x5e, 0x5f,

		0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d,
		0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d,
		0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d,
		0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d,
		0xae, 0xaf
	}
end


local function pool_one_not_2(cards, index)

	local function find_not_2_index()
		for i=#cards-1,2,-1 do
			local card = cards[i]
			if card&0xf ~= 0xd then
				return i
			end
		end
	end

	local one = cards[index]
	if one&0xf == 0xd then
		local index2 = find_not_2_index()
		cards[index], cards[index2] = cards[index2], cards[index]
	end

	return cards
end

local function pool_one_is_2(cards, index)
	local function find_2_index()
		for i=1,#cards do
			local card = cards[i]
			if card&0xf == 0xd then
				return i
			end
		end
	end

	local one = cards[index]
	if one&0xf ~= 0xd then
		local index2 = find_2_index()
		cards[index], cards[index2] = cards[index2], cards[index]
	end

	return cards
end



function dealcard.classic()
	local cards = table.randsort(create_two_pair_cards())

	-- for i=1,28 do
	-- 	pool_one_not_2(cards, i)
	-- end

	local p1 = table.splice(cards, 1, 7)
	local p2 = table.splice(cards, 1, 7)
	local p3 = table.splice(cards, 1, 7)
	local p4 = table.splice(cards, 1, 7)
	pool_one_not_2(cards, 1)
	pool_one_not_2(cards, #cards)


	local function find_not_2_and_remove()
		for i=2,#cards do
			if not qqp_algo.is_flower(cards[i]) then
				return table.remove(cards, i)
			end
		end
	end


	local function fix_hand(hand)
		for i=1,#hand do
			if qqp_algo.is_flower(hand[i]) then
				table.insert(hand, find_not_2_and_remove())
			end
		end
		return hand
	end



	-- pool_one_is_2(cards, #cards-1)
	-- pool_one_is_2(cards, #cards-2)
	-- pool_one_is_2(cards, #cards-3) 

	-- dump("dealcard.cards =======================", cards)
	return fix_hand(p1), fix_hand(p2), fix_hand(p3), fix_hand(p4), cards
end


local function count_item(t)
	local n = 0
	for k,v in pairs(t) do
		n = n + v
	end
	return n
end

local function find_and_remove_by_value(cards, v)
	for i,card in ipairs(cards) do
		if qqp_algo.V(card) == v then
			return table.remove(cards, i)
		end
	end
end

local function find_four_shunzi_color(cc, v)
	for i=1,4 do
		if not cc[v+i-1] then
			return false
		end
	end

	for i=1,4 do
		local c = i
		for j=1,4 do
			if not cc[v+j-1][i] then
				c = nil
				break
			end
		end
		if c then
			return c
		end
	end
end

local function find_and_remove_by_color_value(cards, c, v)
	for i,card in ipairs(cards) do
		if qqp_algo.V(card) == v and qqp_algo.C(card) == c then
			return table.remove(cards, i)
		end
	end
end


local function random_4lian(cards)
	local cc = qqp_algo.cards_count(cards)

	local function random_4_leopard()
		local hand = {}
		local v
		while true do
			v = math.random(1, 0xc)
			if cc[v] and count_item(cc[v]) >= 4 then
				break
			end
		end

		for i=1,4 do
			hand[i] = find_and_remove_by_value(cards, v)
		end

		return hand
	end

	local function random_4_shunzi()
		local hand = {}
		local c, v
		while true do
			v = math.random(1, 0xc-3)
			c = find_four_shunzi_color(cc, v)
			if c then
				break
			end
		end

		for i=1,4 do
			hand[i] = find_and_remove_by_color_value(cards, c, v+i-1)
		end

		return hand
	end

	local is_leopard = math.random(1, 5) == 5
	if is_leopard then
		return random_4_leopard()
	else
		return random_4_shunzi()
	end
end


local function find_one_king(cards)
	return find_and_remove_by_value(cards, math.random(0xe, 0xf))
end


local function random_one_2_or_king(cards)
	local is_2 = math.random(1, 2) == 1

	if is_2 then
		return find_and_remove_by_value(cards, 0xd)
	else
		return find_and_remove_by_value(cards, 0xe) or find_and_remove_by_value(cards, 0xf) 
	end
end

local function random_1_dui(cards)
	local cc = qqp_algo.cards_count(cards)
	local list = {}
	for v=1,0xc do
		if cc[v] and count_item(cc[v]) >= 2 then
			table.insert(list, v)
		end
	end
	local value = list[math.random(1, #list)]

	local r = {}
	for i=1,2 do
		r[i] = find_and_remove_by_value(cards, value)
	end
	return r
end

local function random_x_liandui(cards, n)
	assert(n >= 2)
	local max_v = 0xc - n + 1
	local cc = qqp_algo.cards_count(cards)
	local list = {}

	local function check(v)
		for i=v,v+n-1 do
			if not cc[i] or count_item(cc[i]) < 2 then
				return false
			end
		end
		return true
	end

	for v=1,max_v do
		if check(v) then
			table.insert(list, v)
		end
	end

	local value = list[math.random(1, #list)]
	local r = {}
	for v=value,value+n-1 do
		table.insert(r, find_and_remove_by_value(cards, v))
		table.insert(r, find_and_remove_by_value(cards, v))
	end
	return r
end

local function random_x_leopard(cards, n)
	local cc = qqp_algo.cards_count(cards)
	local list = {}
	for v=1,0xc do
		if cc[v] and count_item(cc[v]) >= n then
			table.insert(list, v)
		end
	end

	assert(#list >= 1)

	local value = list[math.random(1, #list)]

	local r = {}

	for i=1,n do
		r[i] = find_and_remove_by_value(cards, value)
	end

	return r
end

local function random_x_tonghuashun(cards, n)
	assert(n >= 2)
	local max_v = 0xc - n + 1
	local cc = qqp_algo.cards_count(cards)
	local list = {}

	local function check(c, v)
		for i=v,v+n-1 do
			if not cc[i] or not cc[i][c] then
				return false
			end
		end
		return true
	end

	for v=1,max_v do
		for c=1,4 do
			if check(c, v) then
				table.insert(list, {c, v})
			end
		end
	end

	assert(#list >= 1)
	local item = list[math.random(1, #list)]
	local r = {}

	for i=1,n do
		r[i] = find_and_remove_by_color_value(cards, item[1], item[2]+i-1)
	end

	return r
end


-- 开局技能
local start_skill = {}

-- 幸运成对 (七雀牌模式下增加摸到多个对子的概率)
start_skill[4] = function (cards)
	local ndui = math.random(2, 3)
	local hand = {}

	for i=1,ndui do
		table.append(hand, random_1_dui(cards))
	end

	return hand
end


-- 兄弟同心 (增加摸到连对的概率)
start_skill[5] = function (cards)
	local n = math.random(2, 3)
	local hand = random_x_liandui(cards, n)
	return hand
end


-- 四星连珠 (七雀牌模式下增加摸到同样四张牌的概率)
start_skill[6] = function (cards)
	local hand = random_x_leopard(cards, 4)
	return hand
end

start_skill[7] = function (cards)
	local hand = random_x_tonghuashun(cards, 4)
	return hand
end


-- 起手一张花
start_skill[9] = function (cards)
	local hand = {find_and_remove_by_value(cards, 0xd)}
	return hand
end


-- 起手一张王
start_skill[10] = function (cards)
	local one 
	if math.random(1, 2) == 1 then
		one = find_and_remove_by_value(cards, 0xe) or find_and_remove_by_value(cards, 0xf)
	else
		one = find_and_remove_by_value(cards, 0xf) or find_and_remove_by_value(cards, 0xe)
	end

	local hand = {one}
	return hand
end


-- 起手4张同花
start_skill[11] = function (cards)
	local c = math.random(1, 4)

	local hand = {}
	for i=#cards,1,-1 do
		local one = cards[i]
		if qqp_algo.C(one) == c and qqp_algo.V(one) ~= 0xd then
			table.insert(hand, table.remove(cards, i))
			if #hand == 4 then
				return hand
			end
		end
	end
end

local function random_an_start_skill(disable_king_skill)
	local list = {}
	for _,v in pairs(skills) do
		if v.type == 1 then
			if disable_king_skill and v.id == SKILL_LEPER then
				-- pass
			else
				table.insert(list, v)
			end
		end
	end
	return list[math.random(1, #list)].id
end


local function trigger(pet)
	for i,skill_id in ipairs(pet) do
		if math.random(1, 100) <= 20 then
			return skill_id
		end
	end
end


local function tmp_anchor_virtual_pet(disable_king_skill)
	local pet = {10, 9, 11}
	
	if disable_king_skill then
		table.remove(pet, 1)
	end

	return trigger(pet)
end


local function init_hand(cards, p, roomtype)
	if p.robot then
		if roomtype > GameRoomLevel.V1 then
			return random_4lian(cards)
		else
			if math.random(1, 100) <= 10 then
				return {random_one_2_or_king(cards)}
			else
				return {}
			end
		end
	else
		local hand = {}
		local disable_king_skill = false

		if p.ssw_2game_king then
			local _, prob = DIVISION(p.ssw_2game_king)
			skynet.error("init_hand ===================", prob)
			if math.random(1, 100) <= prob then
				disable_king_skill = true 					-- 已经有一个王了, 禁止癞子王技能
				table.insert(hand, find_one_king(cards))
				skynet.error("init_hand ===================== suc")
			end
		end

		if p.is_anchor then
			local skill_id = tmp_anchor_virtual_pet(disable_king_skill)
			if skill_id then
				local f = start_skill[skill_id]
				table.append(hand, f(cards))
				return hand, skill_id
			else
				return hand
			end
		else
			return hand
		end
	end
end


function dealcard.qptimized_for_robot(roomtype, players)
	local cards = table.randsort(create_two_pair_cards())
	
	local function find_not_2_and_remove()
		for i=2,#cards do
			if not qqp_algo.is_flower(cards[i]) then
				return table.remove(cards, i)
			end
		end
	end

	local function fix_hand(hand)
		for i=1,#hand do
			if qqp_algo.is_flower(hand[i]) then
				table.insert(hand, find_not_2_and_remove())
			end
		end
		return hand
	end

	local hands = {}
	local skills = {}
	for i=1,4 do
		hands[i], skills[i] = init_hand(cards, players[i], roomtype)
	end
	for i=1,4 do
		hands[i] = table.append(hands[i], table.splice(cards, 1, 7-#hands[i]))
	end
	pool_one_not_2(cards, 1)
	pool_one_not_2(cards, #cards)

	for _,hand in ipairs(hands) do
		fix_hand(hand)
	end

	return hands[1], hands[2], hands[3], hands[4], cards, skills
end




local helper = {}

local HuEventType = {
	TianHu 			= "tianhu",
	DiHu 			= "dihu",
	Fishmoon 		= "fishmoon", 		-- 海底捞月？
	QingYiSe 		= "qingyise",
	ZiMo 			= "zimo",
	HuaManYuan 		= "huamanyuan",
}
helper.HuEventType = HuEventType

-- 兼容旧代码
local eventIdArr = {
	[HuEventType.TianHu] 		= 1,
	[HuEventType.DiHu] 			= 2,
	[HuEventType.Fishmoon] 		= 3,
	[HuEventType.QingYiSe] 		= 4,
	[HuEventType.ZiMo] 			= 5,
	[HuEventType.HuaManYuan] 	= 6,
}

helper.getEventId = function (eventType)
	return eventIdArr[eventType]
end

local function find_and_remove_by_card(cards, c)
	for i,v in ipairs(cards) do
		if c == v then
			return table.remove(cards, i)
		end
	end
end


local function find_and_remove_by_value_array(cards,hands)
	local ret = {}
	for i,v in ipairs(hands) do
		local card_value = find_and_remove_by_card(cards, v)
		table.insert(ret, card_value)
	end
	return ret
end


--做牌发牌
function dealcard.qptimized_for_robot_change_hands(roomtype, players, roomCardDataCfg)
	print("====debug qc==== qqp 做牌发牌 ")
	local cards = table.randsort(create_two_pair_cards())

	local function find_not_2_and_remove()
		for i=2,#cards do
			if not qqp_algo.is_flower(cards[i]) then
				return table.remove(cards, i)
			end
		end
	end

	local function fix_hand(hand)
		for i=1,#hand do
			if qqp_algo.is_flower(hand[i]) then
				table.insert(hand, find_not_2_and_remove())
			end
		end
		return hand
	end

	local hands = {}
	local skills = {}

	local idArr = roomCardDataCfg.idArr or {}
	local cardsCfg = roomCardDataCfg.cards or {}
	local cardDataArr = roomCardDataCfg.cardDataArr or {}
	local firstId = roomCardDataCfg.firstId

	local p_hands = {}
	--匹配 hands_conf
	for index, value in ipairs(players) do
		local arr = cardDataArr[index]
		local id = idArr[index]
		if arr and #arr > 0 and (#idArr == 1 or value.id == id) then
			p_hands[index] = arr
		else
			print("id = ", value.id, " no make cards config")
		end
	end

	--实际发放 hands_conf
	for i=1,4 do
		if p_hands[i] then
			hands[i] = find_and_remove_by_value_array(cards,p_hands[i])	
			print("====debug qc==== qqp 做牌成功 ",i,tostring(hands[i]))
		else
			hands[i], skills[i] = init_hand(cards, players[i], roomtype)
		end
		skills[i] = nil --不考虑技能	
	end

	--补手牌
	for i=1,4 do
		hands[i] = table.append(hands[i], table.splice(cards, 1, 7-#hands[i]))
	end
	
	pool_one_not_2(cards, 1)
	pool_one_not_2(cards, #cards)

	for _,hand in ipairs(hands) do
		fix_hand(hand)
	end

	if cardsCfg and next(cardsCfg) then
		cards = cardsCfg
	end

	print("====debug qc==== qqp 做牌发牌 over p1-p4,cards ",#hands[1],#hands[2],#hands[3],#hands[4],#cards)
	return hands[1], hands[2], hands[3], hands[4], cards, skills, firstId
end

-- 根据配置发牌
function dealcard.dealcardCfg(roomtype, players, cardDataCfg, bottomCards, firstId)
	local cards = table.randsort(create_two_pair_cards())

	local function find_not_2_and_remove()
		for i=2,#cards do
			if not qqp_algo.is_flower(cards[i]) then
				return table.remove(cards, i)
			end
		end
	end

	local function fix_hand(hand)
		for i=1,#hand do
			if qqp_algo.is_flower(hand[i]) then
				table.insert(hand, find_not_2_and_remove())
			end
		end
		return hand
	end

	local hands = {}
	--匹配 hands_conf
	local p_hands = {}
	for index, value in ipairs(players) do
		local arr = cardDataCfg[value.id]
		if arr and #arr > 0 then
			p_hands[index] = arr
		end
	end

	--实际发放 hands_conf
	for index, value in ipairs(players) do
		if p_hands[index] then
			hands[index] = find_and_remove_by_value_array(cards, p_hands[index])
		else
			hands[index] = init_hand(cards, players[index], roomtype)
		end
	end

	for index, value in ipairs(hands) do
		hands[index] = table.append(hands[index], table.splice(cards, 1, 7 - #hands[index]))
	end

	pool_one_not_2(cards, 1)
	pool_one_not_2(cards, #cards)

	for _,hand in ipairs(hands) do
		fix_hand(hand)
	end

	if bottomCards and next(bottomCards) then
		cards = bottomCards
	end

	return hands[1], hands[2], hands[3], hands[4], cards, firstId
end

function helper.dealcard(roomtype, players, newUserCardCfg)
	local hand_cards = {}
	for _, player in ipairs(players) do
		local cfg = cardx.getRoomCardDataCfg(player.id, GameType.SevenSparrow)
		if cfg then
			return dealcard.qptimized_for_robot_change_hands(roomtype, players, cfg)
		end
	end

	if newUserCardCfg then
		local cardDataCfg = {}
		local cardDataArr = table.clone(newUserCardCfg.init_cards)
		local idx = arrayx.findIndex(players, function (index, value)
			return value.isUser
		end)
		for i = 1, 10, 1 do
			if #cardDataArr > 0 then
				local player = players[idx]
				local cardsCfg = table.remove(cardDataArr, 1)
				cardDataCfg[player.id] = cardsCfg
				idx = idx + 1
				idx = idx > #players and 1 or idx
			else
				break
			end
		end
		return dealcard.dealcardCfg(roomtype, players, cardDataCfg)
	end

	return dealcard.qptimized_for_robot(roomtype, players)
end

helper.pool_one_not_2 = pool_one_not_2

return helper