local skynet = require "skynet"
local ma_data = require "ma_data"
require "define"
local request = {}
local cmd = {}

local M = {}

local function get_entitys()
	-- 如果没有奖励就默认领取
	return skynet.call(get_db_mgr(), "lua", "find_all", COLL.ENTITY, {receiver = ma_data.my_id}, nil, {{create_time = -1}}) or {}
end

function request:entitys_info()
	local tenEntity = skynet.call("entity_mgr", "lua", "get_ten_entitys")
	local entitys = get_entitys()
	-- print('=================查询兑换记录==============')
	-- table.print(entitys)
	-- table.print(tenEntity)
	return {entitys = entitys,tenEntity = tenEntity}
end

--兑换话费券
function request:exchange_entity()
	local currCost = cfg_cost[self.exchangeLv]
	if ma_data.get_goods_num(100009) < currCost.num then
		return {result = false,errorId = 1}
	end
	local goods = {id = 100009,num = -currCost.num}
	ma_data.add_goods(goods,GOODS_WAY_entity,'兑换话费券',nil,true)
	local entity = {
		name = currCost.name,
		phoneNum = self.phoneNum,
		nickname = ma_data.db_info.nickname,
		exchangeLv = self.exchangeLv
	}
	entity = skynet.call("entity_mgr", "lua", "send_entity", ma_data.db_info.id, entity)
	-- print('====================兑换话费券返回==================')
	-- table.print(entity)
	return {result = true,entity = entity,errorId = 0}
end

--兑换完成
function M.exchange_entity_over(currEntity)
	-- print('========================兑换完成====================')
	-- table.print(currEntity)
	ma_data.send_push("entity_result",{entity = currEntity})
end

function M.init(REQUEST, CMD)
    if request then
        table.connect(REQUEST, request)
    end
    if cmd then
        table.connect(CMD, cmd)
    end
end
ma_data.ma_hall_entity = M
return M