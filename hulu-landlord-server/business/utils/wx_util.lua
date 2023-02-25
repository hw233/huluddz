---------------------------------------------------------------
--    Author   : Windy
--    Date     : 2017-07-30 03:32:52
--    Describe : about wechat functions
---------------------------------------------------------------
local md5 = require "md5"
local server_conf = require "server_conf"

---------------------------------------------------------------
--  random
---------------------------------------------------------------
local last = ''

-- 获取一个订单号
function get_new_order_number( )
    local order_num
    while true do 
        order_num = os.time()..math.random(10000000,99999999)
        if order_num ~= last then
            last = order_num
            return last
        end
    end
end

-- 获取随机32位字符串
function random_string_32( )
    local str = ''
    for i=1,32 do
        str = str.. string.char(math.random(48,57))
    end
    return str
end

---------------------------------------------------------------
--  sign
---------------------------------------------------------------

function get_sign_by_tbl( tbl, pay_key )
    assert(pay_key)
    local tt = {}
    for k,v in pairs(tbl) do
        table.insert(tt, {k = k,v = v})
    end
    table.sort( tt, function ( a,b )
        return a.k < b.k
    end )
    local stringA = ''
    for i,node in ipairs(tt) do
        stringA = stringA..node.k..'='..tostring(node.v)..'&'
    end
    stringA = stringA..'key='..pay_key
    return string.upper(md5.sumhexa(stringA))
end

function tbl2xml_sign( tbl, pay_key )
    tbl.sign = get_sign_by_tbl(tbl, pay_key)
    return tbl2xml(tbl)
end

---------------------------------------------------------------
--  xml
---------------------------------------------------------------
function xml2tbl( _xml )
    if not _xml then
        return nil
    end
    local xml, is_xml
    xml, is_xml = string.gsub(_xml, "<xml>", "")
    if is_xml == 0 then
        print(string.format("\nerror: function xml2tbl(xml): arg:'%s' is not xml\n", tostring(xml)))
        return false
    end
    xml = string.gsub(xml, "</xml>", "")
    xml = string.gsub(xml, "<!%[CDATA%[", "")
    xml = string.gsub(xml, "%]%]>", "")

    local t = {}
    for k,v in string.gmatch(xml, "<([%w_]+)>([^<]+)</") do
        t[k] = v
    end
    return t
end

function tbl2xml( t )
    assert(type(t) == 'table', t)
    local xml = "<xml>\n"
    for k,v in pairs(t) do
        xml = xml.."\t<"..k..">"
        xml = xml..tostring(v).."</"..k..">\n"
    end
    xml = xml.."</xml>"
    return xml
end

function tbl2xml_cdata( t )
    assert(type(t) == 'table', t)
    local xml = "<xml>\n"
    for k,v in pairs(t) do
        xml = xml.."\t<"..k.."><![CDATA["
        xml = xml..tostring(v).."]]></"..k..">\n"
    end
    xml = xml.."</xml>"
    return xml
end

---------------------------------------------------------------
--  end                     
---------------------------------------------------------------