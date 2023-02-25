local skynet = require "skynet"

local datax = require "datax"
local objx = require "objx"
local timex = require "timex"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local common = require "common_mothed"
local ec = require "eventcenter"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local xy_cmd 				= require "xy_cmd"

local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

ServerData.datas = {}

ServerData.data = {
    id = 0,
    index = 0,
    startDt = nil,
    endDt = nil,
    rankArr = {},
}
ServerData.data = nil

ServerData.init = function ()

    ServerData.update()
	skynet.fork(function ()
		while true do
            local ok, err = pcall(ServerData.update)
			if not ok then
				skynet.loge("update error!", err)
			end
			skynet.sleep(100)
		end
	end)
end

ServerData.update = function ()
    local serverData = common.GetServerSeting("user_season")
    if not serverData.index then
        serverData.index = 1
        common.SetServerSeting("user_season", serverData)
    end

    local now = os.time()
    if not ServerData.data then
        local data = dbx.get(TableNameArr.ServerSeason, {id = tostring(serverData.index)})
        if not data then
            data = ServerData.addSeasonData(serverData.index, now)
        end
        ServerData.data = data
    end

    if now >= ServerData.data.endDt then
        serverData.index = serverData.index + 1
        common.SetServerSeting("user_season", serverData)

        ServerData.addSeasonData(serverData.index, timex.addMonth(ServerData.data.startDt, 1))
    end
end

ServerData.addSeasonData = function (index, time)
    local data = {
        id = tostring(index),
        index = index,
        rankArr = {},
    }
    data.startDt = timex.getMonthZero(time)
    data.endDt = timex.addMonth(data.startDt, 1) - 1
    dbx.add(TableNameArr.ServerSeason, data)
    ServerData.data = data

    ec.pub({type = "UserSeasonUpdate", data = data})

    return data
end


CMD.TestAddSeasonIndex = function ()
    local serverData = common.GetServerSeting("user_season")
    serverData.index = serverData.index + 1
    common.SetServerSeting("user_season", serverData)

    ServerData.addSeasonData(serverData.index)
end

CMD.GetSeasonData = function (source)
    local ret = table.merge({}, ServerData.data)
    ret.rankArr = nil
    return ret
end

CMD.GetRankUser = function (source, seasonId, id)
    local data
    if seasonId == ServerData.data.id then
        data = ServerData.data
    else
        data = ServerData.datas[seasonId] or dbx.get(TableNameArr.ServerSeason, {id = seasonId})
        ServerData.datas[seasonId] = data
    end

    local ret
    if data and data.rankArr then
        ret = table.first(data.rankArr, function (key, value)
            return value.id == id
        end)
    end
    return ret
end

CMD.UpdateUserExp = function (source, id, exp)
    local lenMax = 100

    local len = #ServerData.data.rankArr
    local data, idx
    for i = len, 1, -1 do
        data = ServerData.data.rankArr[i]
        if data then
            if exp > data.exp then
                idx = i
            else
                break
            end
        end
    end

    if idx or len <= 0 then
        idx = idx or 1
        table.insert(ServerData.data.rankArr, idx, {id = id, exp = exp})

        if len >= lenMax then
            local removeData = table.remove(ServerData.data.rankArr, 101)
            common.send_useragent(removeData.id, "SeasonLvUpdate")
        end
        dbx.update(TableNameArr.ServerSeason, ServerData.data.id, {rankArr = ServerData.data.rankArr})

        return true
    end
    return false
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