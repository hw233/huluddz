local skynet = require "skynet"
local sharetable = require "skynet.sharetable"
local objx = require "objx"

require "define"
require "table_util"

local ma_obj = {}

ma_obj.getC = function (card)
	card = card & 0xff
	local c = (card>>4)%5
	if c == 0 then
		return 5
	else
		return c
	end
end

ma_obj.getV = function (card)
	return card & 0x0f
end

ma_obj.isKing = function (card)
	return ma_obj.getV(card) >= 0xe
end

ma_obj.cardsSort = function (cards)
	local va, vb
	table.sort(cards, function (a, b)
		va = ma_obj.getV(a)
		vb = ma_obj.getV(b)
		if va == vb then
			return ma_obj.getC(a) < ma_obj.getC(b)
		else
			return va < vb
		end
	end)
	return cards
end


--- 获取做牌数据
---@param id string
---@param gameType number
---@return any
ma_obj.getRoomCardDataCfg = function (id, gameType)
    local datas = sharetable.query("RoomCardDataCfg") or {}
	local data = datas[id]
	if data then
		return clone(data[gameType])
	end
	return nil
end



return ma_obj