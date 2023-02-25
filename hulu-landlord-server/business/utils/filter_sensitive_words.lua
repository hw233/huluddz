local cfg_sensitive_word = require "cfg.cfg_sensitive_word"
local KNOW_TYPE = 1
-- local ma_sensitive_word = {}

--[[过滤敏感词（如果onlyKnowHas为true，表示只想知道是否存在敏感词，不会返回过滤后的敏感词，比如用户注册的时候，
我们程序是只想知道用户取的姓名是否包含敏感词的(这样也能提高效率，检测到有一个敏感词就直接返回)，而聊天模块是要返回过滤之后的内容的，
那么onlyKnowHas可以不设，但这需要遍历所有可能）]]

--获取字符串中从起始位置到结束位置的字符
local function findWord( wordTable, startpos,endpos )
    local result = ''
    for i=startpos,endpos do
        result = result..wordTable[i]
    end
    return result
end


--处理屏蔽字
local function filterSensitiveWords( content , onlyKnowHas)
    print("filterSensitiveWords***--",content,onlyKnowHas)
    if content == nil or content == '' then
        return ''
    end
  
    --获取每一个字符
    local wordlist = {} 
    local q = 1
    for w in string.gmatch(content, ".[\128-\191]*") do   
        wordlist[q]= w
        q=q+1
    end

    local length = #(string.gsub(content, "[\128-\191]", ""))  --计算字符串的字符数（而不是字节数）
    local i,j = 1,1
    local replaceList={}
    -- local mgc = {}

    local function check()
        local v = findWord(wordlist,i,j)
        local item = cfg_sensitive_word[v]
        if item == true then
            if onlyKnowHas == KNOW_TYPE then
                return true
            end
            table.insert(replaceList,v)
            j = j+1
            i = j
        else
            j = j+1
        end
        local limit = (j-i) >= 15 and true or (j > length and true or false) 
        if limit == true then --因为一个敏感词最多15个字，不会太长，目的提高效率
            i = i +1
            j = i 
        end
        if i <= length then
            return check()
        end
    end

    if check() then
        return true
    end

    if onlyKnowHas == KNOW_TYPE then
       return false
    end

   --模式串中的特殊字符   ( ) . % + - * ? [ ^ $
    --  % 用作特殊字符的转义字符，比如%%匹配字符%     %[匹配字符[
    local specialChar = {['(']=true,[')']=true,['.']=true,['%']=true,['+']=true,['-']=true,['*']=true,['?']=true,['[']=true,['^']=true,['$']=true}
    --检测是否有特殊字符
    local function checkSpecialChar( msg )
        local tArray = string.gmatch(msg, ".[\128-\191]*")
        local contentArray = {}
        for w in tArray do  
           table.insert(contentArray,w)
        end
        local ck = {}
        for i=1,#contentArray do
            local v = contentArray[i]
            if specialChar[v] == true then
                table.insert(ck,'%')
            end
            table.insert(ck,v)
        end
        local result=''
        for i,v in ipairs(ck) do
            result = result..v
        end
        return result
    end
    
    for i,v in ipairs(replaceList) do
        --这里我没用，主要还是为了效率
        -- local count = #(string.gsub(content, "[\128-\191]", "")) --判断多少个字符（用于计算要显示的*个数）
        -- local star = ''
        -- for i=1,count do 
        --     star = star..'*'
        -- end
        v = checkSpecialChar(v)
        content = string.gsub( content , v , '***' )
    end
    return content
end

--[[
--最优算法
local function filterSensitiveWords( content , onlyKnowHas)
    if content == nil or content == '' then
        return ''
    end

    --模式串中的特殊字符   ( ) . % + - * ? [ ^ $
    --  % 用作特殊字符的转义字符，比如%%匹配字符%     %[匹配字符[
    local specialChar = {['(']=true,[')']=true,['.']=true,['%']=true,['+']=true,['-']=true,['*']=true,['?']=true,['[']=true,['^']=true,['$']=true}
    --检测是否有特殊字符
    local function checkSpecialChar( msg )
        local tArray = string.gmatch(msg, ".[\128-\191]*")
        local contentArray = {}
        for w in tArray do  
           table.insert(contentArray,w)
        end
        local ck = {}
        for i=1,#contentArray do
            local v = contentArray[i]
            if specialChar[v] == true then
                table.insert(ck,'%')
            end
            table.insert(ck,v)
        end
        local result=''
        for i,v in ipairs(ck) do
            result = result..v
        end
        return result
    end

    --因为找不到方案禁用虚拟键盘的回车键，所以只能代码移除回车键（游戏中虚拟键盘不应有换行键的）
    --如果可以使用回车键的话，那么就可以发布竖着的敏感词文字了，显示的很明显，没有阅读障碍，但明文规定不能出现很明显的敏感词
    --用字符隔开的敏感词是可以接受的，因为这种用字符隔开的敏感词情况太多，根本无法避免，所以是可以接受的
    --InputField有一个枚举类型keyboardType来设置键盘的，具体没试，也许也是一种解决方案
    local tempContent = ''
    for w in contentArray do   
        if string.byte(w) ~= 10 then --表示回车（换行）
            tempContent = tempContent..w
        end
    end
    content = tempContent
    contentArray = string.gmatch(tempContent, ".[\128-\191]*")
    
    local mgc = {'敏'={'敏1','敏2','敏3'},,'党'={'党1'}}
    
    local contentArray = string.gmatch(content, ".[\128-\191]*")
    local value,startpos,endpos,length,star
    local starChar ='*'
    --循环每一个字符
    for w in contentArray do   
        value = mgc[w] 
        if w ~= starChar and value ~= nil then
            for i,v in ipairs(value) do 
                local z = checkSpecialChar(v)
                startpos,endpos = content:find(z)
                if startpos ~= nil and endpos ~= nil then
                    if onlyKnowHas == true then
                       return true
                    end
                    length = #(string.gsub(v, "[\128-\191]", ""))
                    star = ''
                    for i=1,length  do 
                        star = star..starChar
                    end
                    content = string.gsub( content , z , star )
                    break
                end
            end
        end
    end
    if onlyKnowHas == true then
        return false
    end
    return content
end
]]

return function ( ... )
    return filterSensitiveWords(...)
end
-- return ma_sensitive_word