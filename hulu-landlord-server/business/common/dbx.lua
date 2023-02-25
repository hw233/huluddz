local skynet = require "skynet"
local objx = require "objx"

local create_dbx = function (serviceName_or_getNameFunc)
    local serivceName, getSerivceNameFunc
    if objx.isString(serviceName_or_getNameFunc) then
        serivceName = serviceName_or_getNameFunc
    else
        getSerivceNameFunc = serviceName_or_getNameFunc
    end

    local dbx = {}

    dbx.get_db_service_name = function()
        if serivceName then
            return serivceName
        else
            return getSerivceNameFunc()
        end
    end

    --#region 增

    ---comment
    ---@param tableName string
    ---@param obj table
    ---@return any
    dbx.add = function(tableName, obj)
        return skynet.call(dbx.get_db_service_name(), "lua", "insert", tableName, obj)
    end

    dbx.insert = dbx.add

    --#endregion


    --#region 删

    ---不能用这个删除所有数据
    ---@param tableName string
    ---@param idOrSelector any
    ---@param single? boolean 是否只删除第一个匹配数据，默认删除所有匹配数据
    ---@return boolean
    dbx.del = function (tableName, idOrSelector, single)
        if objx.isString(idOrSelector) then
            idOrSelector = {id = idOrSelector}
        elseif not next(idOrSelector) then
            skynet.loge("dbx.del error!")
            return false
        end
        skynet.call(dbx.get_db_service_name(), "lua", "delete", tableName, idOrSelector, single and 1 or 0)
        return true
    end

    --- 根据指定键删除多份数据
    ---@param tableName string
    ---@param key string
    ---@param keyArr table Arrary<string>
    dbx.delMany = function (tableName, key, keyArr)
        -- {
        --     '_id': {"$in": delete_ids},
        --     "createTime": {'$lt': delete_date}
        -- }
        dbx.del(tableName, {[key] = {["$in"] = keyArr}})
    end

    --- 删除集合所有数据单独为一个方法
    ---@param tableName any
    ---@return boolean
    dbx.delAll = function (tableName)
        skynet.call(dbx.get_db_service_name(), "lua", "delete", tableName, {})
        return true
    end

    --#endregion


    --#region 查

    ---comment
    ---@param tableName string 集合名
    ---@param idOrSelector any 如果索引中包含 id 则可直接传入 id，否则传入 selector 对象
    ---@param fields table
    ---@return any
    dbx.get = function (tableName, idOrSelector, fields)
        if objx.isString(idOrSelector) then
            idOrSelector = {id = idOrSelector}
        elseif not idOrSelector or not next(idOrSelector) then
            return nil
        end
        return skynet.call(dbx.get_db_service_name(), "lua", "find_one", tableName, idOrSelector, fields)
    end

    dbx.find_one = dbx.get;

    ---comment
    ---@param tableName string
    ---@param selector table
    ---@param fields table
    ---@param limit number
    ---@param sorter table
    ---@param skip number
    ---@return table 数组
    dbx.find = function (tableName, selector, fields, limit, sorter, skip)
        return skynet.call(dbx.get_db_service_name(), "lua", "find_all", tableName, selector, fields, sorter, limit, skip)
    end


    -- dbx.find_all = function (tableName, selector, fields, sorter, limit, skip)
    --     return skynet.call(dbx.get_db_service_name(), "lua", "find_all", tableName, selector, fields, sorter, limit, skip)
    -- end

    --#endregion


    --#region 改

    ---comment
    ---@param tableName string
    ---@param idOrSelector any
    ---@param updateObj table
    ---@param isMulti? boolean 是否修改查询出的所有匹配数据，默认 false
    ---@return any
    dbx.update = function (tableName, idOrSelector, updateObj, isMulti)
        if objx.isString(idOrSelector) then
            idOrSelector = {id = idOrSelector}
        end

        if isMulti then
            skynet.call(dbx.get_db_service_name(), "lua", "update_multi", tableName, idOrSelector, updateObj)
        else
            return skynet.call(dbx.get_db_service_name(), "lua", "update", tableName, idOrSelector, updateObj)
        end
    end

    ---comment
    ---@param tableName string
    ---@param idOrSelector any
    ---@param updateObj table
    ---@return any
    dbx.update_add = function (tableName, idOrSelector, updateObj)
        if objx.isString(idOrSelector) then
            idOrSelector = {id = idOrSelector}
        end
        return skynet.call(dbx.get_db_service_name(), "lua", "update_insert", tableName, idOrSelector, updateObj)
    end

    --- 删除字段
    ---@param tableName string
    ---@param idOrSelector any
    ---@param fieldArr table key-要删除的字段，val-不为nil就行
    ---@return any
    dbx.del_field = function (tableName, idOrSelector, fieldArr)
        if objx.isString(idOrSelector) then
            idOrSelector = {id = idOrSelector}
        end
        if not next(idOrSelector) then
            skynet.loge("dbx.del_field error!", tableName, table.tostr(fieldArr))
            return
        end
        return skynet.call(dbx.get_db_service_name(), "lua", "replace", tableName, idOrSelector, { ["$unset"] = fieldArr })
    end

    -- dbx.update_insert = function ( ... )
    -- 	CMD.index_inc()
    -- 	return ServerData.POOL[ServerData.INDEX]:update_insert(...)
    -- end

    -- dbx.replace = function ( ... )
    -- 	CMD.index_inc()
    -- 	return ServerData.POOL[ServerData.INDEX]:update_insert(...)
    -- end

    --#endregion

    return dbx
end

return create_dbx