
-- ty
local timex = {}

timex.toString = function (time, format)
    return os.date(format or "%Y%m%d %H:%M:%S", time)
end

timex.toDays = function (num)
    return num / 86400
end

timex.toHours = function (num)
    return num / 3600
end

timex.toMinutes = function (num)
    return num / 60
end

--- 添加指定天数
---@param val number
---@param num number 几天
---@return number
timex.addDays = function (val, num)
    return val + 86400 * num
end

timex.addHours = function (val, num)
    return val + 3600 * num
end

timex.addMonth = function (time, num)
    local obj = os.date("*t", time)
    obj.month = obj.month + math.floor(num)
    return os.time(obj)
end

--- 获取指定时间0点时刻
---@param time integer 默认当天
---@return integer
timex.getDayZero = function (time)
    local obj = os.date("*t", time)
    return os.time({year = obj.year, month = obj.month, day = obj.day, hour = 0, min = 0, sec = 0})
end

--- 获取指定时间当月第一天0点时刻
---@param time integer 默认本月
---@return integer
timex.getMonthZero = function (time)
    local obj = os.date("*t", time)
    return os.time({year = obj.year, month = obj.month, day = 1, hour = 0, min = 0, sec = 0})
end


--- 是否同一天
---@param time1 number
---@param time2 number
timex.equalsDay = function (time1, time2)
    return os.date("%Y%m%d", time1) == os.date("%Y%m%d", time2)
end

return timex