---------------------------------------------------------------
--    Author   : Windy
--    Date     : 2017-07-30 03:26:30
--    Describe : public uitl functions
---------------------------------------------------------------
local skynet = require "skynet"

--math.randomseed(os.time())


-- 可取消计时器
function cancelable_timeout(ti, func)
    local function cb()
        if func then
            func()
        end
    end
    
    local function cancel()
        func = nil
    end
    skynet.timeout(ti, cb)
    return cancel
end

-- 表转换为一行字符串
function tbl2str_l( t )
    if type(t) ~= 'table' then
        return tostring(t)
    else
        if next(t) == nil then
            return '{}'
        end

        local l, r = '{ ', ' }'
        if #t > 0 then
            l, r = '[ ', ' ]'
        end
        for k,v in pairs(t) do
            if r == ' ]' then
                k = ''
            else
                k = k..': ' 
            end
            if type(v) == 'table' then
                l = l ..k..tbl2str_l(v)..', '
            elseif type(v) == 'string' then
                l = l..k.."'"..v.."', "
            else
                l = l..k..tostring(v)..', '
            end
        end
        l = string.sub(l, 1, #l-2)
        l = l..r
        return l
    end
end

-- 获取格式化的时间
function get_ftime( )
    return os.date("%Y/%m/%d %H:%M:%S")
end

--检测是否在时间段内
function inTheTime(bTime,endTime)
    local currtime = os.time()
    if bTime <= currtime and endTime >= currtime then
        return true
    end
    return false
end
-- 今天24点的时间戳
function get_today_24_time(time)
    local date = os.date("%Y%m%d",time)

    local year = tonumber(string.sub(date,1,4))  
    local month = tonumber(string.sub(date,5,6)) 
    local day = tonumber(string.sub(date,7,8)) 

    return os.time({day=day, month=month, year=year, hour=24, min=0, sec=0})
end

function get_yesterday_0_time( )
    local date = os.date("%Y%m%d")

    local year = tonumber(string.sub(date,1,4))  
    local month = tonumber(string.sub(date,5,6)) 
    local day = tonumber(string.sub(date,7,8)) 

    return os.time({day=day, month=month, year=year, hour=0, min=0, sec=0}) - 24*3600
end


function get_today_0_time( )
    local date = os.date("%Y%m%d")

    local year = tonumber(string.sub(date,1,4))  
    local month = tonumber(string.sub(date,5,6)) 
    local day = tonumber(string.sub(date,7,8)) 

    return os.time({day=day, month=month, year=year, hour=0, min=0, sec=0})
end

function check_same_day_2(time1,time2)
    if (not time1) or (not time2) then
        return false
    end
    local last_date =  os.date("%Y%m%d",time1)
    local curr_date =  os.date("%Y%m%d",time2)

    return last_date == curr_date
end

--检查 time1 是不是昨日
function check_next_day(time1)
    local yesterday0 = get_yesterday_0_time()
    local today0 = get_today_0_time()
    return time1>=yesterday0 and time1<today0
end

-- 检查last_time 是不是 当天
function check_same_day(last_time)
    if not last_time then
        return false
    end

    local last_date =  os.date("%Y%m%d",last_time)
    local curr_date = os.date("%Y%m%d")

    return last_date == curr_date
end

-- 检查last是不是当月
function check_same_month(last_time)
    if not last_time then
        return false
    end

    local last_date =  os.date("%Y%m",last_time)
    local curr_date = os.date("%Y%m")

    return last_date == curr_date
end

-- 检查last是不是当月
function check_same_month_p2(t1, t2)
    if (not t1) or (not t2) then
        return false
    end

    local last_date =  os.date("%Y%m",t1)
    local curr_date = os.date("%Y%m",t2)

    return last_date == curr_date
end


--判断周几 0-6 Sun-Sat
function get_weekday(tmp_time)
   return tonumber(os.date("%w", os.time()))
end

--判断是否同一周
function check_same_week(last_time)
    if not last_time then
        return false
    end
    local last_week = os.date("%W",last_time)
    local curr_week = os.date("%W")
    if last_week ~= curr_week then
        return false
    end
    local last_year = os.date("%Y", last_time)
    local curr_year = os.date("%Y")
    return last_year == curr_year
end

function is_award_getted(value,index)
    return 0 ~= (value & (0x01 << (index - 1)))
end

function set_award_getted(tl,key,index)
    tl[key] = tl[key] | (0x01 << (index - 1))
end

-- 获取指定时间的0点
function get_0_time_by_time(time)
    local date = os.date("%Y%m%d",time)

    local year = tonumber(string.sub(date,1,4))  
    local month = tonumber(string.sub(date,5,6)) 
    local day = tonumber(string.sub(date,7,8))
    return os.time({day=day, month=month, year=year, hour=0, min=0, sec=0})
end

function table_2_string(obj)
    local lua = ""
        local t = type(obj)
        if t == "number" then
            lua = lua .. obj
        elseif t == "boolean" then
            lua = lua .. tostring(obj)
        elseif t == "string" then
            lua = lua .. string.format("%q", obj)
        elseif t == "table" then
            lua = lua .. "{"
            for k, v in pairs(obj) do
                lua = lua .. "[" .. table_2_string(k) .. "]=" .. table_2_string(v) .. ","
            end
            local metatable = getmetatable(obj)
            if metatable ~= nil and type(metatable.__index) == "table" then
                for k, v in pairs(metatable.__index) do  
                    lua = lua .. "[" .. table_2_string(k) .. "]=" .. table_2_string(v) .. ","
                end
            end
            lua = lua .. "}"
        elseif t == "nil" then
            return "nil"
        elseif t == "userdata" then
            return "userdata"
        elseif t == "function" then
            return "function"
        elseif t == "thread" then
            return "thread"
        else
            error("can not serialize a " .. t .. " type.")
        end
        return lua
end

-- 把表写入文件
function dump_tbl_2_file(tbl, fname)
    
    local str = table_2_string(tbl)

    str = "return "..str
    local file = io.open(fname, "w")
    file:write(str)
    file:close()
end

-- 改对象在表中?
function intbl(o, tbl)
    assert(tbl and type(tbl) == 'table') 
    for i,v in ipairs(tbl) do
        if v == o then
            return true
        end
    end
    return false
end

--取无序table长度
function table_len(tb)
    local len=0
    for k, v in pairs(tb) do
      len=len+1
    end
    return len;
end

-- 字符串分割函数
function string.split(str, delimiter)
    if str==nil or str=='' or delimiter==nil then
        return nil
    end
    
    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
            table.insert(result, match)
    end
    return result
end

function log( format, ... )
    skynet.error(string.format(format, ...))
end

function printf( format, ... )
    print(string.format(format, ...))
end

local function search( k, plist )
    for i=1,#plist do
        local v = plist[i][k]
        if v then return v end
    end
end

function table.filter_kv( tbl, func)
	local temp_tbl = {}
	for k,v in pairs(tbl) do
		if func(k, v) then
			tbl[k] = v
		end
	end
	return temp_tbl
end

function table.filter( tbl, func)
	local temp_tbl = {}
	for i,v in ipairs(tbl) do
		if func(i, v) then
			table.insert(temp_tbl, v)
		end
	end
	return temp_tbl
end

function table.indexof(array, value, begin)
    for i = begin or 1, #array do
        if array[i] == value then return i end
    end
	return false
end

function table.findObj(tbl, func)
	for i,v in ipairs(tbl) do
		if func(i, v) then
			return i
		end
	end
end

