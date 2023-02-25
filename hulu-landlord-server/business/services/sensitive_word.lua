local skynet = require "skynet"
local sensitive_word = require "cfg/cfg_sensitive_word"
local filter_sensitive_words = require "utils.filter_sensitive_words"
require "define"
require "table_util"
local xy_cmd 				= require "xy_cmd"

-- local SpecialChar = {" ", "!", "~", "@", "#", "$", "%", "^", "&", "*", "(", ")", "-", "{", "}", "[", "]", "【", "】", "，", ",", "<", ">"}
local SpecialChar = {" "}

local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

local special = {" ", "!", "~"}
function ReplaceChar(text)
    if not text then
        return text
    end

    for _, _char in pairs(special) do
        text = string.gsub(text, _char,"");    
    end

    return text
end

ServerData.init = function ()

end

CMD.IsSensitiveWords = function (_, text)
    text = ReplaceChar(text)
    for key, _flag in pairs(sensitive_word) do
        if _flag and string.find(text, key) then
            return true
        end
    end
    return false
    -- return sensitive_word[ReplaceChar(text)]
end

CMD.FilterSensitiveWords = function (_, text, type)
    return filter_sensitive_words(text, type)
end

CMD.inject = function (filePath)
    require(filePath)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(source, ...)))
    end)
    ServerData.init()
end)