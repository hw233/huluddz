local skynet = require "skynet"

local ma_data               = require "ma_data"
local ma_useritem_use       = require "ma_useritem_use"
local ma_useritemrecord 	= require "ma_useritemrecord"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local eventx = require "eventx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require

--#endregion

local CMD, REQUEST_New = {}, {}

local ma_obj = {
    timeEndMin = nil,
}

local userInfo = ma_data.userInfo
local userItem = nil

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    local versionsKey = "2021.12.10 11:08"
    local obj = dbx.get(TableNameArr.UserItem, userInfo.id) or {}
    if obj.versionsKey ~= versionsKey then
        obj.versionsKey = versionsKey

        obj.id = userInfo.id
        obj.dataTable = obj.dataTable or {}

        dbx.update_add(TableNameArr.UserItem, userInfo.id, obj)
    end

    userItem = obj.dataTable

    -- ma_obj.timeEndMin = table.minNum(userItem, function (key, value)
    --     return value.endDt and value.endDt or math.maxinteger
    -- end)

    ma_useritem_use.init()
    ma_useritemrecord.init(cmd, request_new)

    ma_obj.initListen()
end

function ma_obj.initListen()
    eventx.listen(EventxEnum.UserOnline, function ()
        ma_obj.CheckAndUpdateItemExpireList()
    end, eventx.EventPriority.Before)

    eventx.listen(EventxEnum.UserNewMinutes, function ()
        ma_obj.CheckAndUpdateItemExpireList()
    end)
    
end


--#region 核心部分

---useritem 模块内部使用，其他地方统一使用 add 方法添加，例：ma_useritem.add(ItemID.Gold, 100, "")
ma_obj._addGold = function (num, from)

    local nowNum = userInfo.gold + num

    assert(nowNum >= 0, string.format("gold:%s addNum:%s from:%s", userInfo.gold, num, from))

    userInfo.gold = nowNum

    dbx.update(TableNameArr.User, userInfo.id, { gold = userInfo.gold })

    ma_common.write_record(TableNameArr.GOLD_REC, num < 0 and "remove" or "add", from, num, nowNum - num, nowNum)

	return nowNum
end

---useritem 模块内部使用，其他地方统一使用 add 方法添加，例：ma_useritem.add(ItemID.Diamond, 100, "")
ma_obj._addDiamond = function (num, from)

    local nowNum = userInfo.diamond + num

    assert(nowNum >= 0, string.format("diamond:%s addNum:%s from:%s", userInfo.gold, num, from))

    userInfo.diamond = nowNum

    dbx.update(TableNameArr.User, userInfo.id, { diamond = userInfo.diamond })

    ma_common.write_record(TableNameArr.DIAMOND_REC, num < 0 and "remove" or "add", from, num, nowNum - num, nowNum)

    return nowNum
end

ma_obj.computeItemExpired = function (uData)
    local oldNum = table.sum(uData.arr, function (key, value)
        return value.num
    end)
    local now = os.time()
    uData.arr = arrayx.where(uData.arr, function (i, value)
        return value.endDt > now
    end)
    local nowNum = table.sum(uData.arr, function (key, value)
        return value.num
    end)

    if nowNum ~= oldNum then
        ma_common.write_record(TableNameArr.Item_REC, "removeitem", "ItemExpired_过期", uData.id, oldNum - nowNum, oldNum, nowNum)
    end

    return nowNum > 0
end


ma_obj.get = function (itemId)
    local ret
    if itemId == ItemID.Gold then
        ret = { id = tonumber(itemId), num = userInfo.gold }
    elseif itemId == ItemID.Diamond then
        ret = { id = tonumber(itemId), num = userInfo.diamond }
    elseif itemId == ItemID.LvExp then
        ret = { id = tonumber(itemId), num = userInfo.exp }
    else
        ret = userItem[tostring(itemId)]
    end
    return ret
end

---comment
---@param datas table Array
ma_obj.syncData = function (datas)
    if next(datas) then
        ma_common.send_myclient("SyncUserItem", {datas = datas})
    end
end

-- cmd 使用
ma_obj.saveData = function (itemId)
    local uData = ma_obj.get(itemId)
    if uData then
        dbx.update(TableNameArr.UserItem, userInfo.id, {["dataTable." .. itemId] = uData})
    end
end

--- 内部使用
---@return boolean 先返回 true or false
ma_obj._add = function (itemId, num, from, sendDataArr, updateData, syncObj)
    local sData = datax.items[itemId]
    num = objx.toNumber(num)
    if not sData then
        skynet.loge("addItem id error!", userInfo.id, tostring(itemId), num, from)
    end
    if num <= 0 or not sData then
        return false, 0
    end
    itemId = sData.id

    -- if itemId ~= math.tointeger(itemId) then
    --     skynet.loge("addItem id error!", userInfo.id, tostring(itemId), num, from)

    --     itemId = math.tointeger(itemId)
    -- end

    local addNum = num;--实际增加的数量
    local oldNum, nowNum = 0, 0;--写记录需要

    local ok, err = pcall(function ()
        if itemId == ItemID.Gold then
            oldNum = userInfo.gold
            nowNum = ma_obj._addGold(addNum, from)
        elseif itemId == ItemID.Diamond then
            oldNum = userInfo.diamond
            nowNum = ma_obj._addDiamond(addNum, from)
        elseif itemId == ItemID.LvExp then
            oldNum = userInfo.exp
            nowNum = userInfo.exp + addNum
            userInfo.exp = nowNum
            dbx.update(TableNameArr.User, userInfo.id, {exp = nowNum})
        else
            local useCount = 0
            if sData.use_type == ItemUseType.AutoUse then
                useCount = ma_obj.use(itemId, nil, num, from, sendDataArr)
            end

            addNum = num - useCount
            if addNum > 0 then
                local uData = userItem[tostring(itemId)]

                if not uData then
                    uData = {id = tostring(itemId), num = 0, endDt = nil}
                    userItem[uData.id] = uData
                elseif not uData.id then -- TODO：监控之前的错误数据，后续删除
                    uData = {id = tostring(itemId), num = 0, endDt = nil}
                    userItem[uData.id] = uData

                    skynet.loge("addItem data error!", userInfo.id, tostring(itemId), num, from)
                end

                if sData.use_type == ItemUseType.Time then
                    local now = os.time()
                    local endDt = math.max((uData.endDt or 0), now)

                    oldNum = (endDt - now) / sData.time
                    uData.endDt = endDt + (sData.time * addNum)
                    nowNum = oldNum + addNum
                elseif sData.use_type == ItemUseType.UseAndTime then
                    uData.arr = uData.arr or {}
                    ma_obj.computeItemExpired(uData)

                    oldNum = table.sum(uData.arr, function (key, value)
                        return value.num
                    end)

                    local now = os.time()
                    table.insert(uData.arr, {id = uData.id, num = addNum, endDt = now + sData.time, gId = objx.getUid_Time()})

                    nowNum = oldNum + addNum

                    -- ma_obj.timeEndMin = table.minNum(userItem, function (key, value)
                    --     return value.endDt and value.endDt or math.maxinteger
                    -- end)
                else
                    oldNum = uData.num
                    uData.num = uData.num + addNum
                    nowNum = uData.num
                end
                updateData["dataTable." .. itemId] = uData
            end
        end

        if addNum > 0 then
            syncObj[itemId] = ma_obj.get(itemId)

            if sendDataArr then
                table.insert(sendDataArr, {id = itemId, num = addNum})
                --sendDatas[itemId] = (sendDatas[itemId] or 0) + addNum
            end

            eventx.call(EventxEnum.UserItemUpdate, itemId, sData, nowNum, oldNum, addNum)
        else
            if sData.isshow == 1 and sendDataArr then
                table.insert(sendDataArr, {id = itemId, num = num})
                --sendDatas[itemId] = (sendDatas[itemId] or 0) + addNum
            end
        end

    end)

    if ok then
        ma_common.write_record(TableNameArr.Item_REC, "additem", from, itemId, num, oldNum, nowNum, addNum)
    else
        skynet.loge("additem error. id: %s  num: %s from: %s error: %s", itemId, num, from, err)

        ma_common.write_record(TableNameArr.Item_REC, "additemError", from, itemId, num, oldNum, nowNum, addNum)
    end
    
    return true, nowNum
end

---增加道具
---@param itemId number 道具id
---@param num number 数量
---@param from string 道具来源
---@param sendDataArr table
---@return boolean ret, number nowNum 返回true:成功 false:失败 当前数量
ma_obj.add = function (itemId, num, from, sendDataArr) --, notUpdateDB) 还是每次都更新DB吧，不然如果中间出现异常就GG了
    local updateData, syncObj = {}, {}

    local ret, nowNum = ma_obj._add(itemId, num, from, sendDataArr, updateData, syncObj)

    if next(updateData) then
        dbx.update(TableNameArr.UserItem, userInfo.id, updateData)
    end

    if ret then
        ma_obj.syncData(syncObj)
    end

    return ret, nowNum
end

---comment
---@param itemArr table Array { {id="", num=0}, {id="", num=0} }
---@param num integer
---@param from string
---@param sendDataArr table
ma_obj.addList = function (itemArr, num, from, sendDataArr)
    if not itemArr or not next(itemArr) then
        return
    end

    local updateData, syncObj = {}, {}

    for index, obj in ipairs(itemArr) do
        ma_obj._add(obj.id, obj.num * num, from, sendDataArr, updateData, syncObj)
    end

    if next(updateData) then
        dbx.update(TableNameArr.UserItem, userInfo.id, updateData)
    end

    ma_obj.syncData(syncObj)
end

--- 内部使用
ma_obj._remove = function (itemId, num, from, updateData)
    local result = false
    local sData = datax.items[itemId]
    local nowNum, oldNum = 0, 0

    itemId = tonumber(itemId)
    num = objx.toNumber(num)
    if num < 0 and sData and sData.use_type == ItemUseType.Time then
        result = false
    elseif num == 0 then
        result = true
    else
        if itemId == ItemID.Gold then
            result = userInfo.gold >= num
            if result then
                oldNum = userInfo.gold
                nowNum = ma_obj._addGold(-num, from)
            end
        elseif itemId == ItemID.Diamond then
            result = userInfo.diamond >= num
            if result then
                oldNum = userInfo.diamond
                nowNum = ma_obj._addDiamond(-num, from)
            end
        elseif itemId == ItemID.LvExp then
            result = userInfo.exp >= num
            if result then
                oldNum = userInfo.exp
                userInfo.exp = userInfo.exp - num
                nowNum = userInfo.exp
            end
        else
            local uData = userItem[tostring(itemId)]
            if uData and uData.num >= num then
                oldNum = uData.num

                uData.num = uData.num - num
                result = true
                nowNum = uData.num

                updateData["dataTable." .. itemId] = uData
            end
        end

        if result then
            eventx.call(EventxEnum.UserItemUpdate, itemId, sData, nowNum, oldNum, -num)
        end
    end

    if result then
        ma_common.write_record(TableNameArr.Item_REC, "removeitem", from, itemId, num, nowNum + num, nowNum)
    end

    return result, nowNum
end

---消耗玩家指定道具
---@param itemId number 道具id
---@param num number 数量
---@param from string 消耗源
---@param notSend boolean
---@return boolean 消耗成功or失败
ma_obj.remove = function (itemId, num, from, notSend)
    local updateData = {}

    local ret, nowNum = ma_obj._remove(itemId, num, from, updateData)

    if next(updateData) then
        dbx.update(TableNameArr.UserItem, userInfo.id, updateData)
    end

    if ret then
        ma_obj.syncData({ma_obj.get(itemId)})
    end

    if not notSend then
        -- 告知客户端哪个材料不足
    end

    return ret, nowNum
end

---comment
---@param itemArr table Array { {id="", num=0}, {id="", num=0} }
---@param num number
---@param from string
---@param notSend boolean
---@return boolean
ma_obj.removeList = function (itemArr, num, from, notSend)
    if not itemArr then
        return false
    end

    if not ma_obj.has(itemArr, num, notSend) then
        return false
    end

    local updateData = {}

    for index, obj in ipairs(itemArr) do
        ma_obj._remove(obj.id, obj.num * num, from, updateData)
    end

    if next(updateData) then
        dbx.update(TableNameArr.UserItem, userInfo.id, updateData)
    end

    local syncDatas = {}
    for index, obj in ipairs(itemArr) do
        syncDatas[obj.id] = ma_obj.get(obj.id)
    end
    ma_obj.syncData(syncDatas)

    return true
end

---获取玩家指定道具数量
---@param itemId number
---@return number
ma_obj.num = function (itemId)
    if itemId == ItemID.Gold then
        return userInfo.gold
    elseif itemId == ItemID.Diamond then
        return userInfo.diamond
    elseif itemId == ItemID.LvExp then
        return userInfo.exp
    else
        local uData = userItem[tostring(itemId)]
        if uData then
            return uData.num
        end
    end
    return 0
end

--- 判断玩家道具数量是否满足参数要求道具数量
---@param itemArr table 
---@param num number 参数 itemArr 中数量的倍数，默认 1 倍
---@param notSend any
---@return boolean
ma_obj.has = function (itemArr, num, notSend)
    if not objx.isTable(itemArr) then
        return false
    end

    num = objx.toNumber(num)
    if not num or num <= 0 then
        num = 1
    end

    local count, sData, itemNum
    for index, obj in ipairs(itemArr) do
        count = obj.num * num
        if count < 0 then
            return false
        else
            sData = datax.items[obj.id]
            if not sData then
                return false
            end

            if sData.use_type == ItemUseType.Time then -- 限时道具只计算时间
                local uData = ma_obj.get(obj.id)
                if not uData or (uData.endDt or 0) < os.time() then
                    return false
                end
            elseif ma_obj.num(obj.id) < count then
                if not notSend then
                    -- 告知客户端哪个材料不足
                end
                return false
            end
        end
    end
    return true
end

---使用道具
---@param itemId number
---@param num number
---@param from any
---@param sendDataArr any
---@param param any
---@return integer 真正使用了的数量
ma_obj.use = function (itemId, uData, num, from, sendDataArr, param)
    local useNum = 0

    local sData = datax.items[itemId]
    if not sData then
        return useNum
    end

    num = objx.toNumber(num)

    local useFunc = ma_useritem_use[sData.group]
    if not useFunc then
        return useNum
    end

    if sData.use_type == ItemUseType.Use then
        if uData and uData.num >= num then
            local ok, ret = pcall(useFunc, sData, num, param, from, sendDataArr)
            if not ok or ret <= 0 or ret > uData.num then
                skynet.loge("useitem.use error.  uid:%s id:%s itemNum:%s num:%s useNumOrError:%s", uData.id, uData.num, num, userInfo.id, ret)
            end
            ma_obj.remove(itemId, num, from, true)
            useNum = num
        end
    elseif sData.use_type == ItemUseType.UseAndTime then
        local mainData = userItem[tostring(itemId)]
        if mainData and mainData.arr and arrayx.findVal(mainData.arr, uData) then
            if uData and uData.num >= num then
                local ok, ret = pcall(useFunc, sData, num, param, from, sendDataArr)
                if not ok or ret <= 0 or ret > uData.num then
                    skynet.loge("useitem.use error.  uid:%s id:%s itemNum:%s num:%s useNumOrError:%s", uData.id, uData.num, num, userInfo.id, ret)
                end
                useNum = num

                uData.num = uData.num - useNum
                if uData.num <= 0 then
                    table.removebyvalue(mainData.arr, uData)
                end
                ma_obj.saveData(itemId)

                ma_obj.syncData({ma_obj.get(itemId)})
            end
        end
    elseif sData.use_type == ItemUseType.AutoUse then -- 自动使用异常不能处理掉，让其中断单个道具的添加流程
        useNum = useFunc(sData, num, param, from, sendDataArr)
    end

    return useNum
end


ma_obj.isExpireItem = function(item)
    if not item then
        return false
    end
    return item.use_type == ItemUseType.Time or item.use_type == ItemUseType.UseAndTime and item.arr
end

ma_obj.CheckAndUpdateItemExpireList = function(itemIdList)
    if itemIdList then
        local _item
        for _, itemId in pairs(itemIdList) do
            _item = userItem[tostring(itemId)]
            if ma_obj.isExpireItem(_item) then
                ma_obj.CheckAndUpdateItemExpire(_item)
            end
        end
    else
        for _, _item in pairs(userItem) do
            if ma_obj.isExpireItem(_item) then
                ma_obj.CheckAndUpdateItemExpire(_item)
            end
        end
    end
end

ma_obj.CheckAndUpdateItemExpire = function(item)
    if not item then
        return
    end

    if item.use_type == ItemUseType.Time or item.use_type == ItemUseType.UseAndTime and item.arr then
        if not ma_obj.computeItemExpired(item) then
            return
        end
        eventx.call(EventxEnum.ItemExpire, {item=item})
    end
end
--#endregion




REQUEST_New.GetUserItemDatas = function ()
    local datas = {}
    local now = os.time()
    for key, value in pairs(userItem) do
        if not value.endDt or value.endDt > now then
            datas[value.id] = value
        end
    end
    return {datas = datas}
end

--- 使用道具接口
REQUEST_New.UseItem = function (args)
    local id, gId, num, param = args.id, args.gId, args.num, args.param

    num = objx.toNumber(num)
    -- 还要限制一下范围

    local sData = datax.items[id]
    if num <= 0 or not sData then
        return RET_VAL.ERROR_3
    end

    local uData = userItem[tostring(id)]
    if not uData then
        return RET_VAL.Lack_6
    end

    if sData.use_type == ItemUseType.UseAndTime then
        local arr = uData.arr or {}
        uData = arrayx.find(arr, function (index, value)
            return value.gId == gId
        end)
        if not uData then
            return RET_VAL.Lack_6
        end

        if os.time() >= uData.endDt then
            return RET_VAL.NoUse_8
        end
    elseif sData.use_type == ItemUseType.Use and uData.num <= 0 then
        return RET_VAL.Lack_6
    else
        return RET_VAL.ERROR_3
    end

    --num = num.Clamp(1, uData.count);

    local useCount = ma_obj.use(id, uData, num, "UseItem_使用道具", nil, param)
    if useCount <= 0 then
        return RET_VAL.Fail_2
    end

    return RET_VAL.Succeed_1
end

CMD.UserItemHas = function (source, itemArr, num, notSend)
    return ma_obj.has(itemArr, num, notSend)
end

CMD.UserItemAdd = function (source, itemId, num, from)
    return ma_obj.add(itemId, num, from)
end

CMD.UserItemAddList = function (source, itemArr, num, from)
    return ma_obj.addList(itemArr, num, from)
end

CMD.UserItemRemove = function (source, itemId, num, from, notSend, isSure)
    if isSure then
        local curNum = ma_obj.num(itemId)
        if curNum < num then
            skynet.loge("CMD.UserItemRemove error!", itemId, curNum, num, from)
            num = curNum
        end
    end
    return ma_obj.remove(itemId, num, from, notSend)
end

CMD.UserItemRemoveList = function (source, itemArr, num, from, notSend, isSure)
    if isSure then
        for index, obj in ipairs(itemArr) do
            local itemNum = obj.num * num
            local curNum = ma_obj.num(obj.itemId)
            if curNum < itemNum then
                skynet.loge("CMD.UserItemRemoveList error!", obj.itemId, curNum, itemNum, from, table.tostr(itemArr), num)
                itemNum = curNum
            end
            obj.num = itemNum
        end
    end
    return ma_obj.removeList(itemArr, 1, from, notSend)
end


return ma_obj