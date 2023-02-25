local skynet = require "skynet"
local sharetable = require "skynet.sharetable"
require "define"

COLL = require "config/collections"


-- 传入概率列表, 返回随机到的索引
-- 如果传入对象列表 及概率字段名, 返回随机到的对象
function random_by_probability(list, prob_name)
    local n = math.random()
    local current = 0

    local is_prob_array = true
    if type(list[1]) == "table" then
        is_prob_array = false
    end

    if is_prob_array then
        for i,prob in ipairs(list) do
            current = current + prob
            if n <= current then
                return i
            end
        end
    else
        for i,o in ipairs(list) do
            current = current + o[prob_name]
            if n <= current then
                return o
            end
        end
    end
    error("probs error")
end

function today_0_time()
    local t = os.date("*t")
    return os.time {year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0}    
end

function goods_listx2(goods_list)
    local t = {}
    for i,goods in ipairs(goods_list) do
        table.insert(t, {id = goods.id, num = goods.num * 2})
    end
    return t
end

--商品乘系数
function goods_list_mul(goods_list, n)
    local t = {}
    for i,goods in ipairs(goods_list) do
        table.insert(t, {id = goods.id, num = math.ceil(goods.num * n)})
    end
    return t
end



--红中麻将金币翻倍专用
function gold_numX2(goods_list)
    for i,goods in ipairs(goods_list) do
        if goods.id == COIN_ID then
            goods.num = math.ceil(goods.num * 2)
            break
        end
    end
    return goods_list
end

--红中麻将金币 钻石 翻倍专用
function currency_numX2(goods_list)
    for i,goods in ipairs(goods_list) do
        if goods.id == COIN_ID  or goods.id == DIAMOND_ID then
            goods.num = math.ceil(goods.num * 2)            
        end
    end
    return goods_list
end

--获取用户所在的服务器集群
function get_user_cluster(uid)
    local num = tonumber(uid)
    local totalAgent = skynet.getenv("agent_num")
    local tmp = math.floor(num % totalAgent + 1)
    tmp = math.random(1,1)
    return "agent" .. tmp
end

function get_user_gate_index(uid)
    uid = assert(tonumber(uid), uid)
    local gate_num = skynet.getenv("gate_port_num")
    return math.floor(math.floor(uid / 10) % gate_num + 1)
end

function get_user_gate(uid)
    return "gate" .. get_user_gate_index(uid)
end

function get_user_wsgate(uid)
    return "wsgate" .. get_user_gate_index(uid)
end

function get_db_manager()
    --从sharetable读取实际的dbmgr_num
    local db_num_conf = sharetable.query("db_mgr_max_count") or {db_mgr_max_count = 1}
    local rnd = math.random(1, db_num_conf.db_mgr_max_count)

    return "db_manager" .. rnd
end

get_db_mgr = get_db_manager

-- TODO：旧的代码，不出问题的话就废弃了
-- function get_db_mgr()
--     --从sharetable读取实际的dbmgr_num
--     local db_num_conf = sharetable.query("db_mgr_max_count") or {db_mgr_max_count =1}    
--     local rnd = math.random(1,db_num_conf.db_mgr_max_count)
--     --local rnd = math.random(1,4)
--     if 1 == rnd then
--         return "db_mgr1"
--     elseif 2 == rnd then
--         return "db_mgr2"
--     elseif 3 == rnd then
--         return "db_mgr3"
--     end
--     return "db_mgr4"
-- end

function string.split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if delimiter == '' then
        return false
    end
    local pos, arr = 0, {}
    for st, sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end


-- 深克隆 deep copy table
function table.clone( obj )
    local function _copy( obj )
        if type(obj) ~= 'table' then
            return obj
        else
            local tmp = {}
            for k,v in pairs(obj) do
                tmp[_copy(k)] = _copy(v)
            end
            return setmetatable(tmp, getmetatable(obj))
        end
    end
    return _copy(obj)
end

-- 切片 only pure array
function table.slice( t, index1, index2 )
    assert(type(t) == 'table' and #t > 0)
    index1 = index1 or 1
    index2 = index2 or #t

    assert(index2 - index1 < #t)

    local tt = {}
    for i = index1, index2 do
        table.insert(tt, table.clone(t[i]))
    end
    return tt
end


local function table_print( t )  
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => ".."{")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print("{")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end

function table.print( ... )
    for i,t in ipairs({...}) do
        if type(t) ~= 'table' then
            print(tostring(t))
        else
            table_print(t)
        end
    end
end


function table.eq(o1, o2)
    if type(o2) == "table" and type(o1) == "table" then
        for k,v in pairs(o2) do
            if not table.eq(o1[k], v) then
                return false
            end
        end
        for k,v in pairs(o1) do
            if not table.eq(o2[k], v) then
                return false
            end
        end
        return true
    else
        return o1 == o2
    end
end

function table.clone( obj )
    local function _copy( obj )
        if type(obj) ~= 'table' then
            return obj
        else
            local tmp = {}
            for k,v in pairs(obj) do
                tmp[_copy(k)] = _copy(v)
            end
            return setmetatable(tmp, getmetatable(obj))
        end
    end
    return _copy(obj)
end

function table.filter(t, filter)
    local new = {}
    for k,v in pairs(t) do
        if filter[k] == false then
        else
            new[k] = v
        end
    end
    return new
end