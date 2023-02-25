local Player = require "game.ddz.Player"
local RoomPlayerEvent = require "game.ddz.RoomPlayerEvent"
local RoomGameEvent = require "game.ddz.RoomGameEvent"
local matchserver = false
local datax       = require("datax")

local Room = RoomGameEvent(RoomPlayerEvent{})

function Room:new(o)
	o = o or {}
	self.__index = self
	setmetatable(o, self)
	return o
end

function Room:init(id, conf, players)
	self.id = id
	self.conf = conf
	self.status = RoomState_DDZ.Readying
	self.multiple = {
		init = 15,
		showcard = 1, 					-- 明牌
		rob_landlord = 1, 				-- 抢地主
		bottom_card = 1,				-- 底牌
		bomb = 1, 						-- 炸弹
		spring = 1 						-- 春天
	}
	self.startcount = 0			-- 每局最多重新发牌3次
	self.bottom_card = {}
	self.players = {}


	if matchserver then
		skynet.error("matchserver not allowed!!")
		for _,p in ipairs(players) do
			self.players[p.fixed_chair] = Player:new(p):init(self, p.fixed_chair, p.showcardx5)
		end
	else
		for i,p in ipairs(players) do
			self.players[i] = Player:new(p):init(self, i, p.showcardx5)
		end
	end

	for i,p in ipairs(self.players) do
		p:send_push("match_ok", p:room_info())
	end

	self:game_deduction_room_ticket()
	self:game_start_dealcard()
	return self
end

function Room:game_top()
	local top = self:realconf().capped_num
	for _,p in ipairs(self.players) do
		if p.double_cap_multiple and p.double_cap_multiple > 1 then
			top = top * 2
		end
	end
	return top
end

function Room:game_bills(winner)
	local top = self:game_top()
	local conf = self:realconf()
	-- body
	local bill = {}
	for _,p in ipairs(self.players) do
		bill[p] = {id = p.id, multiple = p:game_multiple(), is_landlord = false, cards = p.cards}
	end

	local function calc_landlord_max_get_gold(landlord)
		local b = bill[landlord]
		local get_gold = conf.difen * b.multiple
		if get_gold > landlord.gold then
			get_gold = landlord.gold
		end

		-- 房间封顶
		if get_gold > top then
			get_gold = top
		end

		if landlord ~= winner then
			get_gold = -get_gold
		end

		return get_gold, b.multiple		
	end

	local landlord = self:find_landlord()
	local farmers = self:find_farmers()

	local landlord_max_gold, landlord_multiple = calc_landlord_max_get_gold(landlord)
	local landlord_get_gold = 0

	local luck_index = math.random(1, 2)

	for i,p in ipairs(farmers) do
		local b = bill[p]
		local get_gold = math.abs((b.multiple/landlord_multiple) * landlord_max_gold)

		if landlord_max_gold > 0 then
			get_gold = -get_gold
		end

		if math.abs(get_gold) > p.gold then
			get_gold = landlord_max_gold > 0 and (-p.gold) or p.gold
		end
		-- 去掉小数点
		if i == luck_index then
			get_gold = math.ceil(get_gold) 	-- 农民赢:多赚1金币, 地主赢:少出1金币
		else
			get_gold = math.floor(get_gold)
		end
		b.win_gold = get_gold
		b.tag = (get_gold >= top or get_gold == p.gold) and "capping" or ((p.gold + get_gold) == 0 and "bankrupt") or nil
		landlord_get_gold = landlord_get_gold - get_gold
	end
	bill[landlord].win_gold = landlord_get_gold
	bill[landlord].is_landlord = true
	bill[landlord].tag = (landlord_get_gold >= top or landlord_get_gold == landlord.gold) and "capping" or ((landlord.gold + landlord_get_gold) == 0 and "bankrupt") or nil

	local bills = {}
	for k,v in pairs(bill) do
		table.insert(bills, v)
	end
	return bills
end


function Room:is_spring(winner)
	if winner.is_landlord then
		local farmers = self:find_farmers()
		for _,p in ipairs(farmers) do
			if p.playcount > 0 then
				return
			end
		end
		return "spring"
	else
		local landlord = self:find_landlord()
		if landlord.playcount == 1 then
			return "reverse_spring"
		end
	end
end

function Room:find_an_showcardx5_player()
	local list = {}
	for i,p in ipairs(self.players) do
		if p.showcardx5 then
			table.insert(list, p)
		end
	end
	if #list > 0 then
		return list[math.random(1, #list)]
	end
end

function Room:find_call_landlord_player()
	for _,p in ipairs(self.players) do
		if p.first_call then
			return p
		end
	end
end


function Room:have_rob_player()
	for _,p in ipairs(self.players) do
		if p.last_action.name == "rob_landlord" then
			return true
		end
	end
	return false
end


function Room:all_double_cap()
	for _,p in ipairs(self.players) do
		if not p.double_cap_multiple then
			return false
		end
	end
	return true
end

function Room:all_double()
	for _,p in ipairs(self.players) do
		if not p.double_multiple then
			return false
		end
	end
	return true
end

function Room:sync_multiple()
	for _,p in ipairs(self.players) do
		p:sync_multiple()
	end
end

function Room:find_farmers()
	local farmers = {}
	for _,v in ipairs(self.players) do
		if not v.is_landlord then
			table.insert(farmers, v)
		end
	end
	return farmers
end

function Room:find_landlord()
	for _,p in ipairs(self.players) do
		if p.is_landlord then
			return p
		end
	end
end

function Room:front_player(p)
	local chair = p.chair - 1
	if chair == 0 then
		chair = 3
	end
	return self.players[chair]
end

function Room:next_player(p)
	local chair = p.chair + 1
	if chair == 4 then
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


function Room:radio(name, args)
    for _,p in ipairs(self.players) do
    	p:send_push(name, args)
    end
end


function Room:realconf()
	return datax.roomGroup[self.conf.gametype][self.conf.roomtype]
end

return Room