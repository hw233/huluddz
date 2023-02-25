-- ty
local skynet = require "skynet"
require 'base.BaseFunc'

local objx = {}

objx.isString = function (param)
    return type(param) == "string"
end

objx.isTable = function (param)
    return type(param) == "table"
end

objx._uid_idx = 0
objx.getUid_Time = function ()
    objx._uid_idx = objx._uid_idx + 1
	return tostring(os.time() .. objx._uid_idx)
end

--- 参数不规范时返回0
---@param val any
---@return number
objx.toNumber = function (val)
    return tonumber(val) or 0
end

--- 参数不规范时返回0
---@param val any
---@return integer
objx.toInt = function (val)
    return math.tointeger(tostring(val)) or 0
end

---comment
---@param obj table
---@return table
objx.toKeyValuePair = function (obj)
    return table.toObject(obj, function (key, value)
        return tostring(key)
    end, function (key, value)
        return {key = tostring(key), value = tostring(value)}
    end)
end

---comment
---@param obj table
---@return table
objx.toKeyNumPair = function (obj)
    return table.toObject(obj, function (key, value)
        return tostring(key)
    end, function (key, value)
        return {key = tostring(key), num = tonumber(value)}
    end)
end

--- 四舍五入
---@param val any
---@return number
objx.round = function (val)
    return math.floor(val + 0.5)
end

--- 尝试合并到 target 上，重复则输出错误
---@param target table 合并目标
---@param from table
table.tryMerge = function (target, from)
    if objx.isTable(target) and objx.isTable(from) then
        for k, v in pairs(from) do
            if target[k] then
                skynet.loge(string.format(
                    "Warning: In func 'table.tryMerge', t0['%s'] = %s will been over by t1['%s'] = %s",
                    tostring(k), tostring(target[k]), tostring(k), tostring(v))
                )
            end
            target[k] = v
        end
    end
    return target
end

---comment
---@param arr table Array
---@param selector fun(value: any):number
---@param weightSum number
---@return integer
objx.getChanceIndex = function (arr, selector, weightSum)
    if next(arr) then
        if not weightSum then
            weightSum = table.sum(arr, function (key, value)
                return selector(value)
            end)
            if weightSum <= 0 then
                weightSum = 1
            end
        end
        local num, num1 = math.random(1, weightSum)
        for index, value in ipairs(arr) do
            num1 = selector(value)
            if num <= num1 then
                return index
            end
            num = num - num1
        end
    end
    return -1
end

---comment
---@param obj table
---@param selector fun(value: any):number
---@param weightSum number
---@return any
objx.getChance = function (obj, selector, weightSum)
    if next(obj) then
        if not weightSum then
            weightSum = table.sum(obj, function (key, value)
                return selector(value)
            end)
            if weightSum <= 0 then
                weightSum = 1
            end
        end
        local num, num1 = math.random(1, weightSum)
        for key, value in pairs(obj) do
            num1 = selector(value)
            if num <= num1 then
                return value
            end
            num = num - num1
        end
    end
    return nil
end

objx.getChanceArr = function ()
    
end

---comment
---@param obj table
---@return table Array
table.keys = function (obj)
    local keys = {}
    for k, v in pairs(obj) do
        table.insert(keys, k)
    end
    return keys
end

---comment
---@param obj any
---@param selectFunc fun(key: any, value: any):number
---@return number
table.maxNum = function (obj, selectFunc)
    local ret = math.mininteger
    for key, value in pairs(obj) do
        local val = selectFunc(key, value)
        if val > ret then
            ret = val
        end
    end
    return ret
end

---comment
---@param obj table
---@param selectFunc fun(key: any, value: any):number
---@return any
table.max = function (obj, selectFunc)
    local ret, num = nil,  math.mininteger
    for key, value in pairs(obj) do
        local val = selectFunc(key, value)
        if not ret or val > num then
            ret = value
            num = val
        end
    end
    return ret
end

---comment
---@param obj table
---@param selectFunc fun(key: any, value: any):number
---@return number
table.minNum = function (obj, selectFunc)
    local ret = math.maxinteger
    for key, value in pairs(obj) do
        local val = selectFunc(key, value)
        if val < ret then
            ret = val
        end
    end
    return ret
end

---comment
---@param obj table
---@param selectFunc fun(key: any, value: any):number
---@return any
table.min = function (obj, selectFunc)
    local ret, num = nil,  math.maxinteger
    for key, value in pairs(obj) do
        local val = selectFunc(key, value)
        if not ret or val < num then
            ret = value
            num = val
        end
    end
    return ret
end

---comment
---@param obj table
---@param selectFunc fun(key: any, value: any):number
---@return number
table.sum = function (obj, selectFunc)
    local ret = 0
    for key, value in pairs(obj) do
        ret = ret + selectFunc(key, value)
    end
    return ret
end

--- 返回第一个匹配项，搜索非数组table使用
---@param obj table 
---@param selectFunc fun(key: any, value: any):boolean
---@return any
table.first = function (obj, selectFunc)
    local ret = nil
    if selectFunc then
        for key, value in pairs(obj) do
            if selectFunc(key, value) then
                ret = value
                break;
            end
        end
    end
    return ret
end

---comment
---@param obj table
---@param filter fun(key: any, value: any):boolean
---@return table Array
table.where = function (obj, filter)
    local ret = {}
    for key, value in pairs(obj) do
        if filter(key, value) then
            table.insert(ret, value)
        end
    end
    return ret
end

---comment
---@param obj table
---@param selectKeyFunc fun(key: any, value: any):any
---@return table
table.groupBy = function (obj, selectKeyFunc)
    local ret = {}
    local k, arr
    for key, value in pairs(obj) do
        k = selectKeyFunc(key, value)
        arr = ret[k]
        if not arr then
            arr = {}
            ret[k] = arr
        end
        table.insert(arr, value)
    end
    return ret
end

---comment
---@param obj table
---@param selectFunc fun(key: any, value: any):any
---@return table Array
table.select = function (obj, selectFunc)
    local arr = {}
    if selectFunc then
        for key, value in pairs(obj) do
            table.insert(arr, selectFunc(key, value))
        end
    end
    return arr
end

---comment
---@param obj table
---@return table Array
table.toArray = function (obj)
    return table.select(obj, function (key, value)
        return value
    end)
end

--- 遍历 table , 选择键和值返回另一个 table
---@param obj table
---@param keySelect fun(key: any, value: any):any
---@param valueSelect fun(key: any, value: any):any
---@return table
table.toObject = function (obj, keySelect, valueSelect)
    local ret = {}
    for key, value in pairs(obj) do
        if keySelect then
            key = keySelect(key, value)
        end
        if valueSelect then
            value = valueSelect(key, value)
        end

        if ret[key] then
            skynet.loge("table.toObject error! An item with the same key has already been added. Key: ", key)
        end
        ret[key] = value
    end
    return ret
end


return objx