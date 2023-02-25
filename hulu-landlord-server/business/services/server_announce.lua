local skynet = require "skynet"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
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

ServerData.dataArr = nil
ServerData.dataGroup = nil

ServerData.init = function ()
    ServerData.dataArr = dbx.find(TableNameArr.ServerAnnounce, {})
    for key, value in pairs(ServerData.dataArr) do
        value.type = AnnounceType.Scroll
        value.sortVal = tonumber(value.sortVal or 0)
        value.intervalMinute = tonumber(value.intervalMinute)
    end

    ServerData.update()
end

ServerData.update = function ()
    ServerData.dataGroup = table.groupBy(ServerData.dataArr, function (key, value)
        return value.type
    end)
    for key, arr in pairs(ServerData.dataGroup) do
        arrayx.orderBy(arr, function (obj)
            return obj.sortVal
        end)
    end
end

CMD.Set = function (source, args)
    args.id = (not args.id or #args.id <= 0) and objx.getUid_Time() or args.id

    local index = arrayx.findIndex(ServerData.dataArr, function (index, value)
        return value.id == args.id
    end)
    if index > 0 then
        local oldData = ServerData.dataArr[index]
        if oldData.type ~= args.type then
            return nil
        end
        ServerData.dataArr[index] = args
    else
        table.insert(ServerData.dataArr, args)
    end
    ServerData.update()

    dbx.update_add(TableNameArr.ServerAnnounce, args.id, args)

    return args
end

CMD.Get = function (source, _type)
    if _type then
        return ServerData.dataGroup[_type] or {}
    end
    return ServerData.dataArr
end

CMD.Delete = function (source, id)
    local index = arrayx.findIndex(ServerData.dataArr, function (index, value)
        return value.id == id
    end)

    if index > 0 then
        table.remove(ServerData.dataArr, index)
        ServerData.update()

        dbx.del(TableNameArr.ServerAnnounce, id)
    end
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