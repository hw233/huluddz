local skynet = require "skynet"

local datax = require "datax"
local objx = require "objx"
local timex = require "timex"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ec = require "eventcenter"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local xy_cmd 				= require "xy_cmd"

local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data


ServerData.init = function ()

end


CMD.GetServerSetingData = function (source, key)
    local setData = dbx.get(TableNameArr.ServerSeting, {id = key})
    if not setData then
        setData = {id = key, data = {}}
        dbx.add(TableNameArr.ServerSeting, setData)
    end
    return setData.data
end

CMD.SetServerSetingData = function (source, key, data)
    dbx.update(TableNameArr.ServerSeting, key, {data = data})
end


function CMD.inject(filePath)
    require(filePath)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(source, ...)))
    end)
    ServerData.init()
end)