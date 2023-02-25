
local skynet = require "skynet"
local objx = require "objx"
local arrayx = require "arrayx"
local roomData = require "roomData"
local cardx = require "cardx"
require "table_util"

local util = require "util.ddz_classic"
local ddz_conf = require "config_ddz.ddz"


local dealcard = {}

-- local cardArr = table.readonly({
-- 	0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d,
-- 	0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d,
-- 	0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d,
-- 	0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d,
-- 	0x5e, 0x5f
-- })

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
		0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d,
		0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d,
		0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d,
		0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d,
		0x5e, 0x5f,

		0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d,
		0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d,
		0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d,
		0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d,
		0xae, 0xaf
	}
end



function dealcard.classic()
	local cards = table.randsort(create_a_pair_cards())
	local p1 = table.splice(cards, 1, 17)
	local p2 = table.splice(cards, 1, 17)
	local p3 = table.splice(cards, 1, 17)
	return p1, p2, p3, cards
end


function dealcard.noshuffle1()
	local cards = create_a_pair_cards()
	table.sort(cards, function (a, b)
		local va = util.V(a)
		local vb = util.V(b)
		if va == vb then
			return util.C(a) > util.C(b)
		else
			return va > vb
		end
	end)

	local cardHeapNum = 9
	local sunNum = #cards // cardHeapNum

	local arr = {}
	for i = 1, cardHeapNum do
		arr[i] = i
	end

	local cardArrArr = {}
	for i = 1, 3 do
		local cardArr = cardArrArr[i]
		if not cardArr then
			cardArr = {}
			cardArrArr[i] = cardArr
		end
		for j = 1, 3 do
			local idx = math.random(1, #arr)
			table.append(cardArr, arrayx.slice(cards, sunNum * (arr[idx] - 1) + 1, sunNum))
			table.remove(arr, idx)
		end
	end

	local bottomCards = {}
	for index, cardArr in ipairs(cardArrArr) do
		local idx = math.random(1, #cardArr)
		table.insert(bottomCards, cardArr[idx])
		table.remove(cardArr, idx)
	end

	-- local weightArr = {{weight = 45, num = 2}, {weight = 90, num = 3}, {weight = 100, num = 4}}
	-- local getBombNum = function ()
	-- 	return objx.getChance(weightArr, function (value)
	-- 		return value.weight
	-- 	end).num
	-- end

	-- local spades = {0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d}
	-- local booms1 = table.random_remove_n(spades, getBombNum())
	-- local booms2 = table.random_remove_n(spades, getBombNum())
	-- local booms3 = table.random_remove_n(spades, getBombNum())

	return cardArrArr[1], cardArrArr[2], cardArrArr[3], bottomCards
end

function dealcard.noshuffle()
	local cards = create_a_pair_cards()
	table.sort(cards, function (a, b)
		return a&0x0f > b&0x0f
	end)

	local function cut()
		local i = math.random(2, #cards)
		local n = math.random(1, #cards-i+1)

		for j=1,n do
			table.insert(cards, j, table.remove(cards, i+j-1))
		end
	end

	-- 切牌次数
	local m = math.random(5, 10)

	for i=1,m do
		cut()
	end

	local p1 = table.splice(cards, 1, 17)
	local p2 = table.splice(cards, 1, 17)
	local p3 = table.splice(cards, 1, 17)
	return p1, p2, p3, cards
end



-- 每个人最少2个炸弹(大小王不算)
local function random_bomb_num()
	local n = math.random(1, 100)
	if n <= 45 then
		return 2
	elseif n <= 90 then
		return 3
	else
		return 4
	end
end


function dealcard.leperking_newplayer(gamec)

	local function remove(cards, t)
		for i=#cards,1,-1 do
			if table.find_one(t, cards[i]) then
				table.remove(cards, i)
			end
		end
	end

	local index = gamec + 1
	local conf = ddz_conf.first5card[index][math.random(1, 3)]
	local p1 = table.copy(conf.hand)
	local dipai = table.copy(conf.dipai)

	local cards = table.randsort(create_a_pair_cards())
	remove(cards, p1)
	remove(cards, dipai)

	local p2 = table.splice(cards, 1, 17)
	local p3 = cards

	return p1, p2, p3, dipai
end


function dealcard.leperking(gamec)


	if config.matchcard then
		skynet.error("  config.matchcard not allowed!!")
		-- local t = db.matchcard.find_one()
		-- if t and t.active then
		-- 	return t.p1, t.p2, t.p3, t.bottom_cards
		-- end
	else
		-- 新玩家前5局专用牌
		if gamec < 5 then
			return dealcard.leperking_newplayer(gamec)
		end
	end

	local cards = table.randsort(create_a_pair_cards())

	local function find_same_value_and_remove(id)
		local r = {}
		for i=#cards,1,-1 do
			if util.V(cards[i]) == util.V(id) then
				table.insert(r, table.remove(cards, i))
			end
		end
		return r
	end

	local function get_player_bomb_cards(bombs)
		local cards = {}
		for _,id in ipairs(bombs) do
			local list = find_same_value_and_remove(id)
			for i,v in ipairs(list) do
				table.insert(cards, v)
			end
		end
		return cards
	end

	local spades = {0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d}
	local booms1 = table.random_remove_n(spades, random_bomb_num())
	local booms2 = table.random_remove_n(spades, random_bomb_num())
	local booms3 = table.random_remove_n(spades, random_bomb_num())
	local p1 = get_player_bomb_cards(booms1)
	local p2 = get_player_bomb_cards(booms2)
	local p3 = get_player_bomb_cards(booms3)

	p1 = table.append(p1, table.splice(cards, 1, 17 - #p1))
	p2 = table.append(p2, table.splice(cards, 1, 17 - #p2))
	p3 = table.append(p3, table.splice(cards, 1, 17 - #p3))
	return p1, p2, p3, cards
end


local helper = {}


function helper.dealcard(gametype, gamec, playerArr, newUserCardCfg)

	local cfg
	for index, player in ipairs(playerArr) do
		cfg = cardx.getRoomCardDataCfg(player.id, gametype)
		if cfg then
			break;
		end
	end
	if cfg then
		local cards = create_a_pair_cards()
		local arr = {}
		if gametype == GameType.NoShuffle then
			for index, player in ipairs(playerArr) do
				local idx = arrayx.findIndex(cfg.idArr, function (index, value)
					return value == player.id
				end)
				local cardsCfg = cfg.cardDataArr[idx] or {}
				if next(cardsCfg) then
					cardsCfg = table.where(cardsCfg, function (key, value1)
						return arrayx.findVal(cards, value1)
					end)
					for _, card in ipairs(cardsCfg) do
						table.removebyvalue(cards, card)
					end
					arr[index] = cardsCfg
					skynet.logd("id=", player.id, " cards config")
				else
					arr[index] = {}
					skynet.logd("id=", player.id, " no make cards config")
				end
			end

			for index, value in ipairs(arr) do
				arr[index] = table.append(value, table.splice(cards, 1, 17 - #value))
			end

			skynet.logd("----做牌成功----dealcard roomType: ", gametype, table.tostr(arr), table.tostr(cards))

			return arr[1], arr[2], arr[3], cards, cfg.firstId
		end
	elseif newUserCardCfg then
		local cards = create_a_pair_cards()
		local arr = {}
		local cardDataArr = table.clone(newUserCardCfg.init_cards)
		local idx = arrayx.findIndex(playerArr, function (index, value)
			return value.isUser
		end)
		for i = 1, 10, 1 do
			if #cardDataArr > 0 then
				local cardsCfg = table.remove(cardDataArr, 1)
				if next(cardsCfg) then
					cardsCfg = table.where(cardsCfg, function (key, value1)
						return arrayx.findVal(cards, value1)
					end)
					for _, card in ipairs(cardsCfg) do
						table.removebyvalue(cards, card)
					end
				end
				arr[idx] = cardsCfg
				idx = idx + 1
				idx = idx > #playerArr and 1 or idx
			else
				break
			end
		end

		return arr[1], arr[2], arr[3], cards
	end

	local f = dealcard[GAMETYPE[gametype]]
	return f(gamec)
end


--
-- bottom_cards multiple
-- 
local function is_three(cards)
	if util.V(cards[1]) == util.V(cards[2]) and util.V(cards[2]) == util.V(cards[3]) then
		return true
	end
end

local function have_dui(cards)
	local v1 = util.V(cards[1])
	local v2 = util.V(cards[2])
	local v3 = util.V(cards[3])
	if v1 == v2 or v2 == v3 or v1 == v3 then
		return true
	end
end

local function count_over_J(cards)
	local c = 0
	for i,card in ipairs(cards) do
		if util.V(card) >= 0xd-4 then
			c = c + 1
		end
	end
	return c
end

function helper.getBottomCardMultiple(bottom_cards)
	local kingNum = util.getKingCount(bottom_cards)
	if kingNum == 2 then
		return roomData.multipleInfo.kingAll
	elseif kingNum == 1 then
		return roomData.multipleInfo.kingOne
	end

	if is_three(bottom_cards) then --3个点数相同
		return roomData.multipleInfo.sameValueAll
	end

	-- TODO:顺子
	local arr = arrayx.select(bottom_cards, function (key, value)
		return util.V(value)
	end)
	table.sort(arr)
	if arr[1] + 1 == arr[2] and arr[2] + 1 == arr[3] then
		return roomData.multipleInfo.shunzi
	end

	if have_dui(bottom_cards) then
		return roomData.multipleInfo.dui
	end

	local count = count_over_J(bottom_cards)
	if count >= 2 then	-- j - 2 出现2张
		return roomData.multipleInfo.cardVal_J_2_2
	end

	if count <= 0 then	-- 3 - 10
		return roomData.multipleInfo.cardVal_3_10_2
	end

	return roomData.multipleInfo.bottomCardsDefault
end




return helper