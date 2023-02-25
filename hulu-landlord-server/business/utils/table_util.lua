---------------------------------------------------------------
--    Author   : Windy
--    Date     : 2017-07-30 03:26:30
--    Describe : about table uitl func
---------------------------------------------------------------
require "base.BaseFunc"
local inspect = require "base.inspect"

-- 相等?
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

-- 打乱顺序
function table.randsort(t)
    local len = #t
    for i = 1, len do
        local index = math.random(1, len)
        local temp = t[i]
        t[i] = t[index]
        t[index] = temp
    end
    return t
end

function table.notshuffle(handCardsCount)
    local cardsCount = {}
    local length = 15
    for i=1,length do
        if i>13 then
            cardsCount[i] = 1
        else
            cardsCount[i] = 4
        end
    end
    local restoreId = function(id)
        if id <= 13 then
            return id*4
        elseif id == 14 then
            return 53
        elseif id == 15 then
            return 54
        end
    end

    local randomCardsCount = function(id,count)
        local cardCount = 1
        if id <= 13 then
            local rand = math.random(1,10)
            if rand > 1 and rand <= 3 then
                cardCount = 4
            elseif rand > 3 and rand <= 6 then
                cardCount = 2
            elseif rand > 6 then
                cardCount = 3
            end
            if cardCount > handCardsCount - count then
                cardCount = handCardsCount - count
            end
        end
        return cardCount
    end

    t = {}
    for i=1,3 do
        local count = 0
        while count < handCardsCount do
            local randId = math.random(1,length)
            local cardCount = randomCardsCount(randId,count)

            local index = 1
            while index <= length do
                if cardsCount[randId] >= cardCount then
                    local amount = cardsCount[randId]
                    cardsCount[randId] = amount - cardCount
                    randId =restoreId(randId)
                    for i=1,cardCount do
                        table.insert(t,randId - amount + i)
                    end
                    break
                end
                randId = randId + 1
                if randId > length then
                    randId = 1
                end
                index = index + 1
            end
            count = count + cardCount
        end
    end
    local residueWalls = {}
    for i=1,length do
        local amount = cardsCount[i]
        if amount > 0 then
            local cardId = i
            cardId = restoreId(cardId)
            for j=1,amount do
                table.insert(residueWalls,math.random(1,#residueWalls +1),cardId - j + 1)
            end
        end
    end
    table.extend(t,residueWalls)

    return t
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

-- for hash table
-- 连接2个表 (建议换个名字, 和标准库冲突了)
function table.connect( t0, t1 )
    assert(type(t0) == 'table' and type(t1) == 'table')
    -- local t0 = table.clone(t0)

    for k,v in pairs(t1) do
        if t0[k] then
            print(string.format(
                "Warning: In func 'table.connect', t0['%s'] = %s will been over by t1['%s'] = %s",
                tostring(k), tostring(t0[k]), tostring(k), tostring(v) )
            )
        end
        t0[k] = v
    end

    return t0
end


--递归展开table到底层
--需要ipairs索引
--t1是输出集合
function table.expand(t0,t1)
    assert(type(t0) == 'table')
    for _,obj in ipairs(t0) do
        if (type(obj) == 'table') then
            table.expand(obj,t1)
        else
            table.insert(t1,obj)
        end
        
    end
    return t1
end

-- for pure array
-- 向表尾追加元素, 接受 table, 或其他类型
function table.extend( t0, ... )
    assert(type(t0) == 'table')

    for _,obj in ipairs({...}) do
        if type(obj) == 'table' then
            for _,v in ipairs(obj) do
                table.insert(t0, v)
            end
        else
            table.insert(t0, obj)
        end
    end

    return t0
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

-- 在一行打印table -- 不支持数组与字典混合的table
function table.print_l( t )
    local function tbl2str_l( t )
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
    print(tbl2str_l(t))
end

function table.print(...)
    local options = {}
    options.newline = ""
    options.indent = " "
    local fullstr = ""
    for _,v in ipairs({...}) do
        if type(v) == "table" then
            local str = inspect(v, options)
            fullstr = fullstr .. str
        else
            fullstr = fullstr .. tostring(v)
        end
    end
    print(fullstr)
end

function table.tostr(tbl)
    local str = ""
    local options = {}
    options.newline = ""
    options.indent = " "
    if type(tbl) == "table" then
        str = inspect(tbl, options)
    else
        str = tostring(tbl)
    end
    return str
end

-- 设置表为只读
function table.readonly( t )
    local proxy = {}
    local mt = {
        __index = t,
        __newindex = function ( t, k, v )
            error("attempt to update a read_only table")
        end
    }
    setmetatable(proxy, mt)
    return proxy
end

function table.cmp(t1, t2)
    local diff = {}
    local before = {}
    local after = {}
    for k1, v1 in pairs(t1) do
        local v2 = t2[k1]
        if v2 then
            if type(v2) == "table" then
                if type(v1) == "table" then
					local sub_diff = table.cmp(v1, v2)
					if table.nums(sub_diff) > 0  then
                        diff[k1] = sub_diff
                        before[k1] = v1
                        after[k1] = v2
					end
                else
                    diff[k1] = {op = 'update', value = v2}
                    before[k1] = v1
                    after[k1] = v2
                end
            else
                if not (v2 == v1) then
                    diff[k1] = {op = 'update', value = v2}
                    before[k1] = v1
                    after[k1] = v2
                end
            end
        else
            diff[k1] = {op = 'del'}
            before[k1] = v1
        end
    end

    for k2, v2 in pairs(t2) do
        local v1 = t1[k2]
        if v1 == nil then
            diff[k2] = {op = 'add', v2}
            after[k2] = v2
        end
    end
    return diff, before, after
end

