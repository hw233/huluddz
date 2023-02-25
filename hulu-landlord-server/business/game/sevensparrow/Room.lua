local skynet = require "skynet"
local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local common = require "common_mothed"

local roomData = require "roomData"
roomData.setGameType(GameType.SevenSparrow)
local Player = require "game.sevensparrow.Player"
local RoomGameEvent = require "game.sevensparrow.RoomGameEvent"
local qqp_algo = require "util.qique"
local matchserver = false
local helper = require "game.sevensparrow.helper"
local timer = require "timer"

local Room = RoomGameEvent({})

function Room:new(o)
	o = o or {}
	self.__index = self
	setmetatable(o, self)
	return o
end

function Room:init(id, conf, players)
	self.id = id
	self.startDt = os.time()
	self.endDt = nil
	self.conf = conf

	self.newUserCardCfgIdArr = table.first(players, function (key, value)
        return value.newUserCardCfgIdArr
    end)
	self.newUserCardCfgIdArr = self.newUserCardCfgIdArr and self.newUserCardCfgIdArr.newUserCardCfgIdArr or nil
	self.newUserCardCfg = nil

	self.cfgData = datax.roomGroup[conf.gametype][conf.roomtype]
	self.status = RoomState_QQP.Readying 		-- "readying", "swapcard", "takecard", "playcard", "ended"

	self.round = 0 					-- 轮次(玩家摸牌 伦次+1)
	self.pool = {} 					-- 牌堆(玩家只能看见数量)
	self.discard_cards = {} 		-- 弃牌区
	self.selectional_cards = {} 	-- 选牌区
	self.players = {}
	self.all_bills = {}
	self.actions = {}
	self.praise_col = {}
	self.first_one = players[1].id	--默认第一个人首出

	if matchserver then
		for _,p in ipairs(players) do
			self.players[p.fixed_chair] = Player:new(p):init(self, p.fixed_chair)
		end
	else
		for i,p in ipairs(players) do
			self.players[i] = Player:new(p):init(self, i)
			self.praise_col[p.id] = {}
		end
	end

	self:game_deduction_room_ticket()


	skynet.fork(function ()
		for i,p in ipairs(self.players) do
			p:send_push("ssw_match_ok", p:ssw_room_info())
		end
		self:gamestart()
	end)

	return self
end

function Room:gamestart()
	self.newUserCardCfg = self.newUserCardCfgIdArr and datax.init_cards[self.conf.gametype][self.newUserCardCfgIdArr[math.random(1, table.nums(self.newUserCardCfgIdArr))]]
	if self.newUserCardCfg then
        self:sendToAgentAll("NewUserCardCfgUse", self.newUserCardCfg.id)
    end

	local p1, p2, p3, p4, cards, skills, firstId = helper.dealcard(self.conf.roomtype, self.players, self.newUserCardCfg)
	local one = table.remove(cards, #cards)

	-- 测试结算用
	-- local cardsTemp = {cards[1], cards[2], cards[3]}
	-- cards = cardsTemp

	self.pool = cards
	self.selectional_cards = {one}
	self.discard_cards = {}

	self.players[1].cards = p1
	self.players[2].cards = p2
	self.players[3].cards = p3
	self.players[4].cards = p4

	for _, player in ipairs(self.players) do
		player:move_flowers_from_hand()
	end

	skynet.logd(string.format("ssw_gamestart [%s, %s, %s, %s]", self.players[1].id, self.players[2].id, self.players[3].id, self.players[4].id))

	-- 首出
	local firstSkillId
	if not (firstId and table.first(self.players, function (key, value)
		return value.id == firstId
	end)) then
		firstId, firstSkillId = self:getFirstPlayer()
	end
	self.first_one = firstId

	local function get_players_info(pid)
		local players = {}
		for i,p in ipairs(self.players) do
			players[i] = {id = p.id, flowers = p.flowers, cards = pid == p.id and p.cards or nil}
		end
		return players
	end

	for i,p in ipairs(self.players) do
		p:send_push("ssw_gamestart", {
			selectional_cards = self.selectional_cards, 
			pool_num = #self.pool, 
			players = get_players_info(p.id), 
			skill_id = skills and skills[i], 
			first_pid = self.first_one,
			firstSkillId = firstSkillId,
		})
	end

	--发牌，整理牌 客户端播放等待时间
	skynet.sleep(roomData.getRoomDelayTime("deal_card"))

	self:realstart()
end

function Room:realstart()
	self.status = RoomState_QQP.TakeCard

	local first_one
	for _,p in ipairs(self.players) do
		if p.id == self.first_one then
			first_one = p
		end
	end
	assert(first_one, "realstart first_one error! ")

	local NO_1 = false
	if first_one.is_anchor then
		NO_1 = math.random(1, 2) == 1  	-- 50% 概率显示技能
	end

	first_one:please_takecard(true, NO_1)
end

function Room:gameOverInfo(endDt)
	local datas = {}
	for _, player in ipairs(self.players) do
		local goldChange = 0
		local cardTypeMax, multipleMax
		for index, value in ipairs(self.all_bills) do
			if value.id == player.id then
				goldChange = goldChange + value.win_gold
				if not cardTypeMax or value.multiple > multipleMax then
					cardTypeMax, multipleMax = value.cardType, value.multiple
				end
			end
		end
		player.goldBrokeLast = math.abs(goldChange) - player.goldBrokeLast
		-- local goldChange = table.sum(self.all_bills, function (key, value)
		-- 	return value.id == player.id and value.win_gold or 0
		-- end)

		local data = {
			id = player.id,
			data = common.toUserBase(player),
			cards = player.cards,

			gold = player.gold,
			goldChange = goldChange,
			goldBrokeLast = player.goldBrokeLast,
			tag = player.gold == 0 and RoomPlayerOverTag.Broke or RoomPlayerOverTag.Default,

			heroId = player.heroId,

			cardTypeMax = cardTypeMax,
			multipleMax = multipleMax,
		}
		datas[data.id] = data
	end

	local result = {
		roomInfo = {
			id			= self.id,
			gameType 	= self.cfgData.game_id,
			roomLevel 	= self.cfgData.room_type,
			startDt 	= self.startDt,
			endDt 		= endDt or os.time(),
		},
		datas = datas
	}
	return result
end

function Room:gameover()
	self.status = RoomState_QQP.Ended
	self.endDt = os.time()

	local bills = self:punishment_bills()

	local result = self:gameOverInfo(self.endDt)
	result.punishmentBills = bills

	for key, data in pairs(result.datas) do
		local bill = table.first(bills, function (key, value)
			return value.id == data.id
		end)

		if bill then
			data.goldChange = data.goldChange + bill.win_gold
		end
	end

	for _, p in ipairs(self.players) do
		p:send_push("ssw_gameover", result)
	end

	self:exit()
end


function Room:insert_bills(bills)
	for i,bill in ipairs(bills) do
		table.insert(self.all_bills, bill)
	end
end

--点赞
function Room:praise(p,pid)
	print(p.id , "点赞 :",pid)
	if p.id == pid then
		return
	end	
	if not self.praise_col[p.id] then
		self.praise_col[p.id] = {}
	end
	local count_praise = 0
	local already_praise = false
	for _,_pid in ipairs(self.praise_col[p.id]) do
		already_praise = already_praise or _pid == pid
		count_praise = count_praise + 1
	end
	if not already_praise then
		table.insert(self.praise_col[p.id],pid)	
		count_praise = count_praise + 1
	end
	self:radio("ssw_p_praise", {pid = pid, num = count_praise})
end 


function Room:next_one_take(p)
	if self:check_over() then
		self:gameover()
	else
		local p = self:next_game_player(p)
		p:please_takecard()
	end
end


function Room:check_over()
	return #self.pool == 0
end


function Room:take_cards_from_pool(n)
	assert(#self.pool >= n)
	local cards = {}
	for i=1,n do
		table.insert(cards, table.remove(self.pool))
	end

	return cards
end



function Room:takeCard(card)
	local ret, flowers = false, {}

	self.round = self.round + 1
	if card then
		ret = not not table.removebyvalue(self.selectional_cards, card)
	else
		ret = #self.pool > 0

		while true do
			if #self.pool <= 0 then
				break
			end
			card = table.remove(self.pool)

			if qqp_algo.is_flower(card) then
				table.insert(flowers, card)

				if #self.pool <= 0 then
					break
				end
				--防止客户端 抓到 >=2 个 2 "0x0d" 花
				self.pool = helper.pool_one_not_2(self.pool , 1)

				card = nil
			else
				break
			end
		end
	end
	return ret, card, flowers
end


function Room:need_swapcard()
	for _,p in ipairs(self.players) do
		for _,card in ipairs(p.cards) do
			if qqp_algo.V(card) == 0xd then
				return true
			end
		end
	end
end


function Room:count_watching_or_exited()
	local n = 0
	for _,p in ipairs(self.players) do
		if p.status == PlayerState_QQP.Watching or p.status == PlayerState_QQP.Exited then
			n = n + 1
		end
	end
	return n
end

function Room:getRechargeingNum()
	local n = 0
	for _,p in ipairs(self.players) do
		if p.status == PlayerState_QQP.Recharging then
			n = n + 1
		end
	end
	return n
end


function Room:front_player(p)
	local chair = p.chair - 1
	if chair == 0 then
		chair = 3
	end
	return self.players[chair]
end

function Room:next_game_player(p)
	for i=1,3 do
		p = self:next_player(p)
		if p.status ~= PlayerState_QQP.Watching and p.status ~= PlayerState_QQP.Exited then
			return p
		end
	end
end

function Room:next_player(p)
	local chair = p.chair + 1
	if chair == self.conf.max_player + 1 then
		chair = 1
	end
	return self.players[chair]
end

function Room:find_player(pid)
	for _,p in ipairs(self.players) do
		if p.id == pid then
			return p
		end
	end
end

function Room:radio2other(name, args, my_id)
    for _,p in ipairs(self.players) do
    	if p.id ~= my_id then
    		p:send_push(name, args)
    	end
    end
end

function Room:playerRequest(id, name, args)
    local player = self:find_player(id)
    local func = player[name]
    local result = func(player, args)
    if result then
        skynet.logd("RoomPlayerRequest : ", result, id, name, player.status)
    end
    return result
end

function Room:radio(name, args)
    for _,p in ipairs(self.players) do
    	p:send_push(name, args)
    end
end

function Room:sendToAgentAll(name, args)
    for index, player in ipairs(self.players) do
        player:sendToAgent(name, args)
    end
end

--[[
	0. 初始豆子
	1. 赢
		大于初始豆子 每个人赢当前豆子
		小于初始豆子 最多 赢初始豆子
]]
function Room:getWinGoldMax(player, multiple)
	local goldBase = self.cfgData.difen * multiple
	local goldMax = self.cfgData.capped_num
	-- 赢豆数量不能超出（初始豆子 or 身上的豆子）
	-- 不能超出房间封顶
	local winGoldMax = math.min(goldBase, goldMax < 0 and goldBase or goldMax, math.max(player.gold, player.goldInit))

	return math.tointeger(winGoldMax)
end


function Room:on_player_playcard(p, card)
	table.insert(self.selectional_cards, 1, card)
	if #self.selectional_cards == 4 then
		local one = table.remove(self.selectional_cards, 4)
		table.insert(self.discard_cards, one)
	end
end


return Room