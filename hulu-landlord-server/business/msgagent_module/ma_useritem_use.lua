local skynet = require "skynet"

local ma_data = require "ma_data"
local ma_useritem = nil
local ma_userhero = nil
local ma_userrune = nil
local ma_user_achievement = nil
local ma_user_txz = nil

local objx = require "objx"
-- local create_dbx = require "dbx"
-- local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name


local ma_obj = {}

ma_obj.init =function ()
    ma_useritem = require "ma_useritem"
    ma_userhero = require "ma_userhero"
    ma_userrune = require "ma_userrune"
    ma_user_achievement = require "ma_user_achievement"
    ma_user_txz = require "ma_user_txz"
end

--- 规范
-- ma_obj.道具分组(items表格中的group) = function(策划表数据，要使用的数量, 其他参数, sendDataArr, 使用源) return 返回实际使用数量 end

--- 奖励宝箱
---@param cfgData table 道具配置数据
---@param num number 增加数量
---@param param any
---@param from string 来源
---@param sendDataArr table
---@return number 消耗数量
ma_obj.RewardBox = function (cfgData, num, param, from, sendDataArr)
    ma_useritem.addList(cfgData.param, num, from, sendDataArr)

    return num
end

-- 权重宝箱
ma_obj.RewardWeightBox = function (cfgData, num, param, from, sendDataArr)
    for i = 1, num do
        local data = objx.getChance(cfgData.param, function (value)
            return value.weight
        end)
        if data then
            ma_useritem.add(data.id, data.num, from, sendDataArr)
        end
    end
    return num
end

-- 英雄宝箱
ma_obj.HeroBox = function (cfgData, num, param, from, sendDataArr)

    local now = os.time()
    for index, value in ipairs(cfgData.param) do
        ma_userhero.add(value.id, from)
    end

    return num
end

-- 英雄宝箱(期限)
ma_obj.HeroBoxLimit = function (cfgData, num, param, from, sendDataArr)

    -- local now = os.time()
    for index, value in ipairs(cfgData.param) do
        ma_userhero.add_limit(value.id, from, nil, function (uData)
            uData.skillLv = value.skilllv
            uData.useCount = value.count
            uData.skillCount = 0
        end)
    end

    return num
end

-- 符文宝箱
ma_obj.RuneBox = function (cfgData, num, param, from, sendDataArr)
    for i = 1, num do
        for index, value in ipairs(cfgData.param) do
            ma_userrune.add(value.id, from)
        end
    end
    return num
end

--成就
ma_obj.Achievement = function (cfgData, num, param, from, sendDataArr)
    -- for i = 1, num do
    ma_user_achievement:loadAndAddAchievement(cfgData.id, num)
    -- end
    return num
end


--成就称号
ma_obj.AchTitle = function (cfgData, num, param, from, sendDataArr)
    num = 1
    for i = 1, num do
        for _, value in ipairs(cfgData.param) do
            ma_user_achievement:loadAndAddTitle(value.id, cfgData.time)
        end
    end
    return num
end

--通行证经验
ma_obj.TxzExp = function (cfgData, num, param, from, sendDataArr)
    ma_user_txz:loadAndAddTxzExp(cfgData.id, num)
    return num
end

return ma_obj