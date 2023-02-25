-- ty
--local skynet = require "skynet"
require 'base.BaseFunc'

local arrayx = {}

--- 连接两个或更多的数组，并返回新数组
---@return table
arrayx.concat = function (...)
    local ret = {}
    for index, arr in ipairs(...) do
        for key, value in pairs(arr) do
            table.insert(ret, value)
        end
    end
    return ret
end



--- 返回第一个匹配项，搜索数组使用
---@param arr table Array
---@param selectFunc fun(index: number, value: any):boolean
---@return any
arrayx.find = function (arr, selectFunc)
    local ret = nil
    if selectFunc then
        for index, value in ipairs(arr) do
            if selectFunc(index, value) then
                ret = value
                break;
            end
        end
    end
    return ret
end

--- 查找第一个匹配项，搜索数组使用
---@param arr table Array
---@param value any
---@return any
arrayx.findVal = function (arr, value)
    return arrayx.find(arr, function (index, val)
        return value == val
    end)
end

--- 返回第一个匹配项的索引，搜索数组使用
---@param arr table Array
---@param selectFunc fun(index: number, value: any):boolean
---@return integer
arrayx.findIndex = function (arr, selectFunc)
    local index = -1
    if selectFunc then
        for i, value in ipairs(arr) do
            if selectFunc(i, value) then
                index = i
                break;
            end
        end
    end
    return index
end

---comment
---@param arr table Array
---@param selectFunc fun(index: any, value: any):any
---@return table Array
arrayx.select = function (arr, selectFunc)
    local ret = {}
    if selectFunc then
        for i, value in ipairs(arr) do
            table.insert(ret, selectFunc(i, value))
        end
    end
    return ret
end

---comment
---@param arr table Array
---@param filter fun(i: number, value: any):boolean
---@return table Array
arrayx.where = function (arr, filter)
    local ret = {}
    for i, value in ipairs(arr) do
        if filter(i, value) then
            table.insert(ret, value)
        end
    end
    return ret
end

--- 选取数组的的一部分，并返回一个新数组
---@param arr table
---@param start number 起始位置
---@param count number 个数
---@return table
arrayx.slice = function (arr, start, count)
    local ret = {}
    start = math.max(1, start or 1)
    local len = #arr
    local endIdx = (count and math.min(len, start + count - 1)) or len

    for i = start, endIdx do
        table.insert(ret, arr[i])
    end
    return ret
end

-- 内部使用 table.sort 实现，不稳定
---@param arr table
---@param func fun(obj: any):number
arrayx.orderBy = function (arr, func)
    table.sort(arr, function (a, b)
        return func(a) < func(b)
    end)
    return arr
end

--- 去重
---@param arr table Array
---@param comparer? fun(obj1: any, obj2: any):boolean
---@return table 返回去重后的另一个 table
arrayx.distinct = function (arr, comparer)
    local ret = {}
    if comparer then
        for index, value in ipairs(arr) do
            local obj = arrayx.findVal(ret, function (index, val)
                return comparer(value, val)
            end)
            if not obj then
                table.insert(ret, value)
            end
        end
    else
        local hash = {}
        for key, value in ipairs(arr) do
            if not hash[value] then
                hash[value] = true
                table.insert(ret, value)
            end
        end
    end
    return ret
end


return arrayx