
local objx = require "objx"
local cfg_global = require "cfg.cfg_global"

local ma_obj = {}

ma_obj.getValue = function (key)
    local data = cfg_global[key]
    return data.global
end

ma_obj.getNumber = function (key)
    local data = cfg_global[key]
    return objx.toNumber(data.global.val)
end




return ma_obj