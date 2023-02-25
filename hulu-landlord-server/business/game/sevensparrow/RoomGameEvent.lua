local skynet = require "skynet"
local ec = require "eventcenter"

local objx     = require "objx"
local arrayx   = require "arrayx"

local helper = require "game.sevensparrow.helper"
local qqp_algo = require "util.qique"





local rebate_conf = {
	{7000000000, {gold = 500000000, nplayer = 1000}},
	{4000000000, {gold = 200000000, nplayer = 400}},
	{2000000000, {gold = 100000000, nplayer = 200}},
}


local function player_bill(bills, pid)
	for i,bill in ipairs(bills) do
		if bill.id == pid then
			return bill
		end
	end
end


local function get_rebate_conf(win_gold)
	for i,v in ipairs(rebate_conf) do
		if win_gold >= v[1] then
			return v[2]
		end
	end
end


return function (Room)

	function Room:add_action(...)
		table.insert(self.actions, {...})
	end

	function Room:exit()
		skynet.call("ddz_room_mgr", "lua", "room_exit", self.id)
		skynet.exit()
	end

	-- 不能听牌玩家的惩罚
	function Room:punishment_bills()
		local difen = self.cfgData.difen

		local bills = {}
		local ting, others = self:get_ting_and_not_ting_players()
		
		local need_gold = 0
		local all_multiple = 0
		for _,t in ipairs(ting) do
			need_gold = need_gold + t.multiple * difen
			all_multiple = all_multiple + t.multiple
		end

		if #ting > 0 and #others > 0 then
			local luck_index = math.random(1, #ting)
			
			for _,other in ipairs(others) do

				local other_gold = other.gold
				local lose_gold = other_gold >= need_gold and need_gold or other_gold

				for i,t in ipairs(ting) do
					if i == luck_index then
						t.win_gold = t.win_gold + math.ceil((t.multiple / all_multiple) * lose_gold)
					else
						t.win_gold = t.win_gold + math.floor((t.multiple / all_multiple) * lose_gold)
					end
				end
				table.insert(bills, {
					id = other.id,
					win_gold = -lose_gold,
					gold = other_gold - lose_gold,
					tag = ""
				})
			end

			for _,t in ipairs(ting) do
				table.insert(bills, {
					id = t.pid,
					win_gold = t.win_gold,
					gold = t.gold + t.win_gold,
					type = t.type,
					tag = ""
				})
			end

			for _,bill in ipairs(bills) do
				local p = self:find_player(bill.id)
				p:add_gold(bill.win_gold)
			end
		end

		return bills
	end


	function Room:get_ting_and_not_ting_players()
		local ting = {}
		local others = {}
		for _,p in ipairs(self.players) do
			if p.status ~= PlayerState_QQP.Watching and p.status ~= PlayerState_QQP.Exited then
				local type, multiple = qqp_algo.max_ting(p.cards)
				if type then
					table.insert(ting, {pid = p.id, type = type, multiple = multiple, win_gold = 0, gold = p.gold})
				else
					table.insert(others, p)
				end
			end
		end
		return ting, others
	end

	--定首出
	function Room:getFirstPlayer()
		local players = arrayx.where(self.players, function (index, player)
			return player.skillState and player.skillBuffCfg.skill_id == 1040201
		end)

		local weightArr
		if #players > 0 then
			weightArr = arrayx.select(players, function (index, player)
				return {id = player.id, weight = player.heroSkillRate, skillId = player.skillBuffCfg.skill_id}
			end)
		else
			weightArr = arrayx.select(self.players, function (index, player)
				return {id = player.id, weight = player.is_anchor and 120 or 100}
			end)
		end

		local obj = objx.getChance(weightArr, function (value)
			return value.weight
		end)

		if obj.skillId then
			ec.pub({type = EventCenterEnum.HeroSkillUse, id = obj.id, skillId = obj.skillId})
		end

		return obj.id, obj.skillId
	end

	function Room:start_swapcard()
		
		if not self:need_swapcard() then
			-- skynet.error("dont need swapcard ====================")
			return
		end
		self.status = RoomState_QQP.SwapCard

		-- skynet.error("start_swapcard ===================== #pool=", #self.pool)
		for _,p in ipairs(self.players) do
			p:swapcard()
		end
		skynet.sleep(200)
		return self:start_swapcard()
	end

	function Room:game_deduction_room_ticket()
		for i,p in ipairs(self.players) do
			p:deduction_room_ticket(self.cfgData.cost)
		end
	end


	return Room
end