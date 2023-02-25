
local datax = require "datax"

local myObj = {
    _gameType = nil,
	testEffectTimeCfg = nil, -- 策划调整特效时间用的

    -- 房间等待延时默认值
    RoomDelayTimeDefault = {
        ["deal_card"] = 5500,
        ["take_card"] = 130,
        ["take_card_flower"] = 1000,
        ["play_card"] = 600,
        ["hu"] = 10,
    },
    --胡牌特效等待时间
    RoomEffectDelayTimeDefault = {
        ["baxingzha"] = 1270,
        ["tonghuashun"] = 1270,
        ["6+2"] = 1500,
        ["5+3"] = 1500,
        ["shuanglonghui"] = 1140,
        ["lianzhahu"] = 1140,
        ["4+4"] = 1500,
        ["feijihu"] = 850,
        ["sanliandui"] = 1270,
        ["4+2+2"] = 1500,
        ["3+3+2"] = 1500,
        ["2+2+2+2"] = 1500,

        -- 以下为事件默认特效
        ["tianhu"] = 2000,
        ["dihu"] = 2000,
        ["fishmoon"] = 1500,
        ["qingyise"] = 1270,
        ["zimo"] = 1600,
        ["huamanyuan"] = 1200,
    },
}

myObj.multipleInfo = setmetatable({}, {__index = function (self, key)
    return datax.cardTypeGroup[myObj._gameType][key].magnification or 1
end})

myObj.setGameType = function (gameType)
    myObj._gameType = gameType
end

myObj.setDelayTimeDataTest = function (data)
	for key, value in pairs(data) do
		value = tonumber(value)
		value = math.max(0, math.min(value, 10000))

		if myObj.RoomDelayTimeDefault[key] then
			myObj.RoomDelayTimeDefault[key] = value
		elseif myObj.RoomEffectDelayTimeDefault[key] then
			myObj.RoomEffectDelayTimeDefault[key] = value
		end
	end
end

--- 获取房间状态延时
---@param key string
---@return integer
myObj.getRoomDelayTime = function (key)
    local obj = datax.effectCodeGroup[myObj._gameType][key]
    return math.ceil((obj and obj.delay_time or (myObj.RoomDelayTimeDefault[key] or 0)) / 10)
end

--- 获取特效延时
---@param fashionId integer 时装id
---@param effectArr table Array {type,type,...} or {{type="",subtype=""},{type="",subtype=""},...}
---@return integer
myObj.getRoomEffectDelayTime = function (fashionId, effectArr)
    local dealyTime = 0
    if effectArr and next(effectArr) then
		local datas = datax.effectGroup[myObj._gameType] or {}
        datas = datas[tonumber(fashionId)] or {}

        local obj
        for i, effect in ipairs(effectArr) do
            local _type, subtype
            if type(effect) == "string" then
                _type = effect
            else
                _type = effect.type
                subtype = effect.subtype
            end
            obj = datas[_type]
            obj = obj and obj[subtype] or obj
            -- obj = obj and next(obj) or obj
            dealyTime = dealyTime + (obj and obj.delay_time or (myObj.RoomEffectDelayTimeDefault[_type] or 0))
        end
        dealyTime = math.ceil(dealyTime / 10)
	end
    return dealyTime
end

-- local PlayerActionWaiteTime = {
--     [PlayerState_DDZ.CallLandlord] = 10,
--     [PlayerState_DDZ.RobLandlord] = 10,
--     [PlayerState_DDZ.Doubleing] = 5,
--     [PlayerState_DDZ.DoubleMax] = 8,
--     [PlayerState_DDZ.Playing] = 20,
-- }

-- --- 房间状态延时
-- myObj.getPlayerActionWaiteTime = function (playerState)
-- 	return PlayerActionWaiteTime[playerState]
-- end

return myObj