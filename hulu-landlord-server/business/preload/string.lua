local function urlencodechar(char)
    return "%" .. string.format("%02X", string.byte(char))
end


function string.urlencode(input)
    -- convert line endings
    input = string.gsub(tostring(input), "\n", "\r\n")
    -- escape all characters but alphanumeric, '.' and '-'
    input = string.gsub(input, "([^%w%.%- ])", urlencodechar)
    -- convert spaces to "+" symbols
    return string.gsub(input, " ", "+")
end


function string.random_str(n)
    local str = ''
    for i=1,n do
        str = str.. string.char(math.random(48,57))
    end
    return str
end

--- 计算文本长度
---@param str string
---@return integer
string.getLength = function (str)
    local len  = string.len(str)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string.byte(str, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end