-- ty
local skynet = require "skynet"
local objx = require "objx"

local FuncInfo = {}
function FuncInfo.new(priority, func)
    return {
        priority = priority,
        func = func
    }
end


local FuncList = class("FuncList")
function FuncList:ctor()
    self.priorityMap = {}
    self.isDirty = false

    self.funcs = {};
    self.containCanceled = false
end

---comment
---@param priority number
---@param value any
function FuncList:add(priority, value)
    local arr = self.priorityMap[priority];
    if not arr then
        arr = {}
        self.priorityMap[priority] = arr;
    end
    table.insert(arr, FuncInfo.new(priority, value))
    self.isDirty = true -- 添加新的，必须重置事件队列
end

---comment
---@param priority? number
---@param value any
function FuncList:remove(priority, value)
    local idx, target
    for index, info in ipairs(self.funcs) do
        if info.func == value and info.priority == priority then
            idx = index
            target = info
            break;
        end
    end

    -- 不管其是否在事件队列中，直接在 priorityMap 中移除即可，不影响 funcs 事件队列
    local arr = self.priorityMap[priority];
    for index, info in ipairs(arr) do
        if info.func == value then
            table.remove(arr, index)
            break;
        end
    end

    if target then
        if self.isInvoking then
            target.func = nil -- 调用中需要主动设置为nil    
            self.containCanceled = true -- 调用中发生移除，只需要主调用层重置事件队列即可
        else
            table.remove(self.funcs, idx)
        end
    else
        -- 如果不在队列中，说明添加后还未重置事件队列，无需做其他处理
    end
end

function FuncList:sort()
    local prioritySort = {}
    prioritySort = table.keys(self.priorityMap)
    table.sort(prioritySort)

    local funcs = {}
    for index, priority in ipairs(prioritySort) do
        local arr = self.priorityMap[priority]
        if arr then
            for i, value in ipairs(arr) do
                table.insert(funcs, value)
            end
        end
    end

    self.funcs = funcs -- 排序后为新的数组
    self.isDirty = false
    self.containCanceled = false
end

-- local FuncsHandle = class("FuncsHandle")

local eventx = {
    _callbackTable = {}
}

-- 预先定义的几个事件优先级
local EventPriority = {
    Default = 100,
    Before = 90,
    After = 110,
}
eventx.EventPriority = EventPriority


--- 注册/监听事件
---@param key any 事件名
---@param callback function 回调
---@param priority? number 优先级(默认为 EventPriority.Default )(数值越小优先级越高)
---@return function 返回添加的函数体，便于移除或更新
eventx.add = function (key, callback, priority)
    local list = eventx._callbackTable[key];
    if not list then
        list = FuncList.new();
        eventx._callbackTable[key] = list;
    end
    if not priority then
        priority = EventPriority.Default
    end
    list:add(priority, callback)

    return callback
end

eventx.get = function (key)
    local list = eventx._callbackTable[key];
    if not list then
        list = FuncList.new();
        eventx._callbackTable[key] = list;
    end
    return list;
end

--- Check if the specified key has any registered callback. If a callback is also specified,
--- it will only return true if the callback is registered.
---@param key any
---@param callback? function
---@param priority? number 优先级(默认为 EventPriority.Default )(数值越小优先级越高)
---@return boolean
eventx.has = function (key, callback, priority)
    local list = eventx._callbackTable[key];
    if not list then
        return false
    end

    if not priority then
        priority = EventPriority.Default
    end

    local funcs = list.priorityMap[priority]
    if not funcs then
        return false
    end

    if not callback then
        for i = 1, #funcs do
            if funcs[i].func then
                return true
            end
        end
        return false
    end

    for i = 1, #funcs do
        if funcs[i].func == callback then
            return true
        end
    end

    return false
end

---comment
---@param key any
---@param callback any
---@param priority? integer 优先级(默认为 EventPriority.Default )(数值越小优先级越高)
eventx.remove = function (key, callback, priority)
    local list = eventx._callbackTable[key];
    if not list then
        return
    end

    if not priority then
        priority = EventPriority.Default
    end

    list:remove(priority, callback)
end

--- 触发事件
---@param key any 事件名
---@param p1 any 参数1
---@param p2 any 参数2
---@param p3 any 参数3
eventx.invoke = function (key, p1, p2, p3, ...)
    local list = eventx._callbackTable[key];
    if not list then
        return
    end

    local rootInvoker = not list.isInvoking; -- TODO:是否增加多重递归警告
    list.isInvoking = true;

    if list.isDirty then
        list:sort();
    end

    -- 必须记录下当前事件数组，不然重新排序后就改变了
    local funcs = list.funcs;
    local len = #funcs;

    for i = 1, len do
        local info = funcs[i];
        if info.func then
            local ok, err = pcall(info.func, p1, p2, p3, ...)
            if not ok then
                skynet.loge("funcs invoke error", key, i, p1, p2, p3, err, debug.traceback())
            end
        end
    end

    if rootInvoker then
        list.isInvoking = false;
        if list.containCanceled then
            list:sort();
        end
    end

end


eventx.call = eventx.invoke
eventx.listen = eventx.add
eventx.on = eventx.add

return eventx