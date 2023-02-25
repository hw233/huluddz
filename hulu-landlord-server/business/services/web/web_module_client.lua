local skynet = require "skynet"
local sharetable = require "skynet.sharetable"
local queue = require "skynet.queue"
local timer = require "timer"
local timex  = require "timex"
local objx = require "objx"
-- local arrayx     = require "arrayx"
local create_dbx = require "dbx"
-- local dbx_mgr = create_dbx("db_manager")
local dbx_rec = create_dbx("db_manager_rec")
-- local common = require "common_mothed"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name
local COLL_INDEXES = require "config.coll_indexes"

local cjson = require "cjson"
local httpc = require "http.httpc"
httpc.timeout = 500 -- 超时时间 5s

require "table_util"

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

local writeClientLogQueue       = queue()
local writeClientDataLogQueue   = queue()

return function (CMD, agentMap)
    local moduleDatas = ServerData.moduleDatas
    moduleDatas.cacheData               = {}
    moduleDatas.writeLogTimer           = nil
    moduleDatas.cacheDataLog            = {} --client数据埋点
    moduleDatas.writeDataLogTimer       = nil

    moduleDatas.loginWhiteList          = {}
    moduleDatas.loginWhiteListGetTimer  = nil

    -- 临时使用的数据
    moduleDatas.loginWhiteList  = EnumAlias({
        "115.216.2.7",
    })


    CMD.ServerInfoGet = function (args, header)
        local ret = {ip = "47.100.72.197", port = 18001, channel = args.channel, isMaintain = false}

        -- args.channel
        local platform = args.platform
        local channel = args.channel

        -- 临时改动，前端需求，屏蔽测试pc包连入正式服
        if platform == "ios" then
            ret.port = 17001
        elseif platform == "pc" then
            ret.ip = "8.133.185.84"
            ret.port = 18001
        end
        if channel == "huluddz_peipai" then
            ret.ip = "8.133.185.84"
            ret.port = 16001
        end

        -- if not CMD.ServerCanLogin(args, header) then
        --     ret.isMaintain = true
        -- end

        return ret
    end

    CMD.ServerCanLogin = function (args, header)
        local ip = header["x-real-ip"]
        return moduleDatas.loginWhiteList[ip]
    end

    -- if agentMap then
    --     local func = function ()
    --         moduleDatas.loginWhiteList = table.toObject(dbx_mgr.find(TableNameArr.ServerLoginWhiteList, {}), function (key, value)
    --             return value
    --         end)
    --         skynet.send("web_client", "lua", "ServerLoginWhiteListSync", {loginWhiteList = moduleDatas.loginWhiteList})
    --     end
    --     func()
    --     moduleDatas.loginWhiteListGetTimer = timer.create(1000, func, -1)
    -- end

    -- CMD.ServerLoginWhiteListSync = function (args)
    --     moduleDatas.loginWhiteList = args.loginWhiteList or moduleDatas.loginWhiteList
    -- end


        
    ---写入操作记录
    ---@param tableName string 记录表明，传入 config/collections 中定义的值
    ---@param id string
    ---@param type string 记录类型
    ---@param from string 记录来源
    ---@param param1 any 未命名参数1
    ---@param param2 any
    ---@param param3 any
    ---@param param4 any
    CMD.write_record = function (tableName, id, type, from, channel, param1, param2, param3, param4, ...)
        local obj = {
            id = id,
            time = os.time(),
            type = type,
            --way = ??, -- 不要了
            from = from,
            channel = channel,
            dayZero = timex.getDayZero(),
        }

        local collObj = COLL_INDEXES[tableName]
        if not collObj then
            skynet.loge("write_record tableName error")
            return
        end

        local arr = collObj.paramNameArr
        if arr then
            obj[arr[1] or "p1"] = param1
            obj[arr[2] or "p2"] = param2
            obj[arr[3] or "p3"] = param3
            obj[arr[4] or "p4"] = param4
        else
            obj.p1 = param1
            obj.p2 = param2
            obj.p3 = param3
            obj.p4 = param4
            --obj.parms = ...
        end

        local selector
        if collObj.updateSelectorField then
            selector = {}
            for index, value in ipairs(collObj.updateSelectorField) do
                selector[value] = obj[value]
            end
        end

        skynet.call("db_mgr_client", "lua", "write_record", tableName, selector, obj)
    end

    moduleDatas.writeLogTimer = timer.create(100, function ()
        writeClientLogQueue(function ()
            local cacheDataOld = moduleDatas.cacheData
            moduleDatas.cacheData = {}
            
            local root = skynet.getenv("root")
            local dicPath = root .. "clientLog/"
            if not os.execute("cd ".. dicPath) then
                os.execute("mkdir ".. dicPath)
            end

            local path = dicPath .. string.format("%s.html", os.date("%Y-%m-%d"))

            for key, arr in pairs(cacheDataOld) do

                local str = ""
                for index, obj in ipairs(arr) do
                    str = str .. string.format("[%s] [%s] msg:[%s] other:[%s]\n\n", os.date("%Y-%m-%d %H:%M:%S", math.tointeger(obj.time)), obj.type, obj.msg, obj.other)
                end
                io.writefile(path, str, "a+b")
            end
        end)
    end, -1)

    --客户端埋点数据定时器
    moduleDatas.writeDataLogTimer = timer.create(100, function ()
        writeClientDataLogQueue(function ()
            local cacheDataLogOld = moduleDatas.cacheDataLog
            moduleDatas.cacheDataLog = {}
            for key, arr in pairs(cacheDataLogOld) do
                local filed = {key = key, data = arr, at = os.time()}
                CMD.write_record(TableNameArr.UserClientDataRecord, "", key, "client", "", filed)
            end
        end)
    end, -1)


    CMD.WriteClientLog = function (args)
        local ret = 1

        local type, msg = args.type, args.msg
        type = type or "default"

        args.type = nil
        args.msg = nil

        skynet.send("web_client", "lua", "ServerWriteClientLog", {
            type = type,
            time = os.time(),
            msg = msg,
            other = table.tostr(args)
        })

        return ret
    end
 
    CMD.ServerWriteClientLog = function (args)
        writeClientLogQueue(function ()
            local arr = moduleDatas.cacheData[args.type]
            if not arr then
                arr = {}
                moduleDatas.cacheData[args.type] = arr
            end
            
            table.insert(arr, args)
        end)
    end

    ----------------客户端埋点接口 1
    CMD.WriteClientDataLog = function (args)
        local ret = 1

        local type, msg = args.type, args.msg
        type = type or "default"

        args.type = nil
        args.msg = nil

        skynet.send("web_client", "lua", "ServerWriteClientDataLog", {
            type = type,
            time = os.time(),
            msg = msg,
            other = table.tostr(args)
        })
        
        return ret
    end

    ----------------客户端埋点接口 2
    CMD.ServerWriteClientDataLog = function (args)
        writeClientDataLogQueue(function ()
            local arr = moduleDatas.cacheDataLog[args.type]
            if not arr then
                arr = {}
                moduleDatas.cacheDataLog[args.type] = arr
            end

            table.insert(arr, args)
        end)
    end
end