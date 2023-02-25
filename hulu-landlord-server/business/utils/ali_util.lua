---------------------------------------------------------------
--    Author   : Tangxr
--    Date     : 2018-12-24 15:50:00
--    Describe : about ali message functions
---------------------------------------------------------------
local crypt = require "skynet.crypt"
local server_conf = require "server_conf"
require "base.BaseFunc"

function compute_signature(tbl,accessKeySecret)
    accessKeySecret = accessKeySecret or server_conf.accessKeySecret
    local tt = {}

    for k,v in pairs(tbl) do
        table.insert(tt,{k = k,v = v})
    end
    table.sort(tt,function(a,b)
        return a.k < b.k
    end)

    local string_sign = ''
    for i,node in ipairs(tt) do
        string_sign = string_sign .. SpecialEncodeURI(node.k) .. '='
                    ..SpecialEncodeURI(tostring(node.v))..'&'
    end
    string_sign = string.sub(string_sign,1,-2)
    -- %2F --> /
    local sign = 'GET&'..SpecialEncodeURI('/')..'&' .. SpecialEncodeURI(string_sign)
    sign = crypt.hmac_sha1(accessKeySecret .. "&",sign)

    return SpecialEncodeURI(crypt.base64encode(sign)) .."&"..string_sign
end

function SpecialDecodeURI(s)
    s = string.gsub(s,'%%20','+')
    s = string.gsub(s,"%%2A",'*')
    s = string.gsub(s,'~','%%7E')
    -- s = string.gsub(s,'_','%%255F')
    return string.urldecode(s)
end

function SpecialEncodeURI(s)
   s = string.urlencode(s)
   -- s = string.gsub(s,'%%255F','_')
   -- string.urlencode 方法会把 '_' --> '%5F'
   -- 而其他url编码不会
   s = string.gsub(s,'%%5F','_') 
   -- 阿里POP协议的特殊规则
   s = string.gsub(s,'+','%%20')
   s = string.gsub(s,'*',"%%2A")
   s = string.gsub(s,"%%7E",'~')
   return s
end
