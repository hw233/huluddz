local skynet = require "skynet"
local ec = require "eventcenter"
local util = require "util.ddz_classic"
local PlayerAction = require "game.ddz.PlayerAction"
local PlayerActionEx = require "game.ddz.PlayerActionEx"
local PlayerPlease = require "game.ddz.PlayerPlease"
local PlayerRequest = require "game.ddz.PlayerRequest"
local Player = PlayerRequest(PlayerPlease(PlayerActionEx(PlayerAction{})))
local Robot = require "game.robot.classic.Robot"

--[[
	o: {
		id = "123456", 		-- user id
		addr = 0x123456 	-- agent addr
	}
]]
function Player:new(o)
	o = o or {}
	self.__index = self
	setmetatable(o, self)
	return o
end


function Player:init(room, chair, showcardx5)
	self.room = room
	self.chair = chair
	self.showcardx5 = showcardx5 and true or false 	-- 明牌开始 * 5
	self.status = PlayerState_DDZ.ReadyOk
	self.clock = 0
	self.double_multiple = nil
	self.cards = {}
	self.last_action = {}
	self.is_showcard = false
	self.is_landlord = false
	self.is_trusteeship = false
	self.playcount = 0
	self.muted = false
	self.first_call = false
	self.played_cards = {}
	self.useCardRecord = false

	local coll = self.robot and "robot" or self.tourist and "tourist" or "user"

	local base = skynet.call(self.addr, "lua", "RoomUserInfoGet")
	for k,v in pairs(base) do
		self[k] = v
	end
	
	self.cancel_timer = function ()
	end

	ec.sub({type = "player_add_gold", pid = self.id}, function (e)
		self.gold = e.now
		self.room:radio2other("sync_player_gold", {pid = e.pid, gold = e.now}, self.id)
	end)

	return self
end


function Player:sync_multiple()
	local n = self:game_multiple()
	self:send_push("sync_multiple", {multiple = n})
end


function Player:game_multiple()
	local function calc_public_multiple()
		local n = 1
		for k,v in pairs(self.room.multiple) do
			n = n * v
		end
		return n
	end

	local pub = calc_public_multiple()
	local landlord = self.room:find_landlord()
	if not landlord then
		return pub
	end

	if self.is_landlord then
		local farmers = self.room:find_farmers()
		local farmer1 = (farmers[1].double_multiple or 1) * (farmers[1].double_cap_multiple or 1)
		local farmer2 = (farmers[2].double_multiple or 1) * (farmers[2].double_cap_multiple or 1)

		return pub * (self.double_multiple or 1) * (self.double_cap_multiple or 1) * (farmer1 + farmer2)
	else
		local dz = (landlord.double_multiple or 1) * (landlord.double_cap_multiple or 1)
		
		return pub * (self.double_multiple or 1) * (self.double_cap_multiple or 1) * dz
	end
end

function Player:auto_play()
	-- local can_pass = self.playstatus == "normal"

	-- if can_pass then
	-- 	self:playcard{pass = true}
	-- else
	-- 	local card = self.cards[#self.cards]
	-- 	self:playcard{pass = false, playedcards = {type = "dan", weight = util.V(card), cards = {card}}}
	-- end

	local result = self.agent.playcard(self.playstatus)
	self:playcard(result)
end


function Player:send_push(name, args)

	local on = {}

	function on.match_ok()
		self.agent = Robot(args.room, self.id)
	end

	function on.game_start_dealcard()
		self.agent.init_handcards(table.copy(args.cards))
	end

	function on.determine_landlord()
		self.agent.determine_landlord(args.landlord_id, table.copy(args.bottom_cards))
	end

	function on.p_playcard()
		self.agent.p_playcard(args.pid, args.pass, args.playedcards and table.copy(args.playedcards))
	end

	local f = on[name]
	if f then
		f()
	end

	pcall(skynet.send, self.addr, "lua", "room_push", name, args)
end


function Player:sort_cards()
    table.sort(self.cards, function (a, b)
        return a&0xf > b&0xf
    end)
end


function Player:deduction_room_ticket(ticket)
	self.gold = self.gold - ticket
	self:send_push("deduction_room_ticket", {ticket = ticket})

	-- if self.robot then
	-- 	self.room:radio2other("sync_player_gold", {pid = self.id, gold = self.gold}, self.id)
	-- end
end


function Player:set_last_action(name, playedcards)
	self.last_action.name = name
	self.last_action.playedcards = playedcards
end


function Player:clear_clock()
	self.cancel_timer()
	self.clock = 0
end


function Player:check_backpack(name)
	if self.robot then
		return true
	end
	return skynet.call(self.addr, "lua", "have_backpack_item", name)
end


function Player:sub_item_or_diamond(name, diamond)
	if self.robot then
		return true
	else
		local ok, r, use_diamond = pcall(skynet.call, self.addr, "lua", "room_sub_item_or_diamond", name, diamond)
		if ok then
			return r, use_diamond
		else
			return false
		end
	end
end


function Player:sub_item(name)
	if self.robot then
		return true
	else
		local ok, r = pcall(skynet.call, self.addr, "lua", "room_sub_item", name)
		return ok and r
	end
end


return Player