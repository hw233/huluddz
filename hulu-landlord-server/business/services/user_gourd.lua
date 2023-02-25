local skynet = require "skynet"
--local queue = require "skynet.queue"
local timer = require "timer"

local ma_globalCfg			= require "ma_global_cfg"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local timex = require "timex"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local common = require "common_mothed"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
local cfg_gourd = require "cfg.cfg_gourd_vine"
local cfg_gourd_oxygen = require "cfg.cfg_gourd_vine_oxygen"
cfg_gourd_oxygen = table.toObject(cfg_gourd_oxygen, function (key, value)
    return value.level
end)
--#endregion

local xy_cmd = require "xy_cmd"
local CMD, ma_obj = xy_cmd.xy_cmd, xy_cmd.xy_server_data

ma_obj.dataCache = {}


ma_obj.tryGetData = function (id)
    local obj = ma_obj.dataCache[id]
    if not obj then
        obj = dbx.get(TableNameArr.UserGourd, id, {
            _id = false,
            id = true,
            versionsKey1 = true,
            resetDt = true,
            vip = true,
            gourdLv = true,
            gourdArr = true,
            bePickFruitNumDay = true,

            fertilizerNum = true,

            loosenSoilLv = true,
            loosenSoilO2Val = true,
            loosenSoilO2ValDay = true,
            loosenSoilEndDt = true,
            loosenSoilRecord = true,

            friendHelpArr = true,

            bonusObj = true, -- 与 userInfo 上的同步
        })
        if not obj then
            return false
        end

        obj.vip                 = obj.vip
        obj.gourdLv             = obj.gourdLv
        obj.gourdArr            = obj.gourdArr or {}
        obj.bePickFruitNumDay   = obj.bePickFruitNumDay or 0    -- 被别人摘取豆子数量(日)

        obj.fertilizerNum       = obj.fertilizerNum or 0

        obj.loosenSoilLv        = obj.loosenSoilLv or 0
        obj.loosenSoilO2Val     = obj.loosenSoilO2Val or 0
        obj.loosenSoilO2ValDay  = obj.loosenSoilO2ValDay or 0
        obj.loosenSoilEndDt     = obj.loosenSoilEndDt or 0
        obj.loosenSoilRecord    = obj.loosenSoilRecord or {}

        obj.friendHelpArr       = obj.friendHelpArr or {}

        ma_obj.dataCache[id] = obj


        local versionsKey1 = "2021.11.16 10:58"
        if obj.versionsKey1 ~= versionsKey1 then
            obj.versionsKey1 = versionsKey1

            obj.gourdArr = {}
            dbx.update(TableNameArr.UserGourd, obj.id, obj)
        end
    end

    local dt = timex.getDayZero()
    local resetDt = obj.resetDt
    if resetDt ~= dt then
        obj.resetDt = dt
        obj.bePickFruitNumDay = 0

        obj.loosenSoilO2ValDay = 0
        obj.loosenSoilRecord = {}
        obj.friendHelpArr = {}

        dbx.update(TableNameArr.UserGourd, id, obj)
    end

    if os.time() > obj.loosenSoilEndDt then
        obj.loosenSoilLv = 0
        obj.loosenSoilO2Val = 0
    end

    obj.addRateSum = ma_obj.getGourdAddRate(obj)

    ma_obj.updateGourd(obj)

    return true, obj
end

ma_obj.getGourdAddRate = function (uData, isUse)
    local now = os.time()
    local addRate = 0
    local isUseFertilizer = false

    if uData.fertilizerNum > 0 then
        uData.fertilizerNum = isUse and uData.fertilizerNum - 1 or uData.fertilizerNum
        addRate = addRate + ma_globalCfg.getNumber(103003); -- 施肥加成
        isUseFertilizer = isUse
    end

    if now <= uData.loosenSoilEndDt then
        local sData = cfg_gourd_oxygen[uData.loosenSoilLv]
        addRate = addRate + (sData and sData.output_percentage or 0) -- 氧气加成
    end

    for index, value in ipairs(uData.friendHelpArr) do
        if now <= value.endDt then
            addRate = addRate + ma_globalCfg.getValue(103016).rate; -- 好友加成
        end
    end

    local bonusObj = uData.bonusObj
    if bonusObj and bonusObj.rune then
        addRate = addRate + (bonusObj.rune[BonusType.GourdGoldBase] or 0) -- 符文加成
    end

    local vipCfg = datax.vipGroup[uData.vip]
    if vipCfg then
        addRate = addRate + vipCfg.gourd_vine_add
    end

    return addRate, isUseFertilizer
end

ma_obj.updateGourd = function (data)
    local isDirty = false

    local sData = cfg_gourd[data.gourdLv]
    if not data or not sData then
        return
    end

    local otherTypeNum = 0
    local now = os.time()
    for i = 1, sData.unlock_num, 1 do
        local id = tostring(i)
        local gourdPosObj = data.gourdArr[id]
        if not gourdPosObj then
            gourdPosObj = {id = id, arr = {}}
            data.gourdArr[id] = gourdPosObj
        end

        local isOutputOther = otherTypeNum < datax.globalCfg[103020].countMax

        if ma_obj.updateGourdOutput(data, data.gourdArr[id].arr, sData, now, isOutputOther) and not isDirty then
            isDirty = true
        end

        if gourdPosObj.arr[1] and gourdPosObj.arr[1].type ~= GourdType.Default then
            otherTypeNum = otherTypeNum + 1
        end
    end

    if isDirty then
        dbx.update(TableNameArr.UserGourd, data.id, data)
    end
end

ma_obj.updateGourdOutput = function (uData, arr, sData, now, isOutputOther)
    local isDirty = false

    local len = #arr
    local startDt = now
    local endData = len > 0 and arr[len] or nil -- 最后一个是成长最后成长的豆

    local timeMax = ma_globalCfg.getNumber(103017)
    for i = 1, 20, 1 do
        if endData then
            if endData.endDt > now then
                if uData.fertilizerNum > 0 and not endData.isUseFertilizer then
                    isDirty = true

                    local addRateSum, isUseFertilizer = ma_obj.getGourdAddRate(uData, true)
                    endData.isUseFertilizer = isUseFertilizer
            
                    local rewardArr = ma_obj.getRewardArr(sData, endData.type)
                    local baseObj = arrayx.find(rewardArr, function (index, value)
                        return value.id == ItemID.Gold
                    end)
                    local base = baseObj and baseObj.num or 0
                    endData.addNum = math.floor(base * addRateSum / 10000)
                end
                break;
            end
            if endData.type ~= GourdType.Default then
                break;
            end
            startDt = (endData.isTree and not endData.isStopOutput) and endData.endDt or now   -- 如果树上果实已收取，则生长下一颗
        end

        local timeVal = timeMax - table.sum(arr, function (key, value)
            return value.tiemVal
        end)
        if timeVal < sData.single_output_times then
            if endData then
                endData.isStopOutput = true
            end
            break;
        end
        isDirty = true
        if endData then
            endData.isTree = false  -- 收进篮子
        end

        local data = {}
        data.id = objx.getUid_Time()
        data.growLv = sData.level -- 记录生长时的等级，然后读取表格
        data.tiemVal = sData.single_output_times

        local gourdType = isOutputOther and objx.getChance(sData.specialbeans_Probability, function (value)
            return value.weight
        end).type or GourdType.Default

        data.type = gourdType -- 豆子类型
        data.endDt = startDt + sData.single_output_times
        data.addNum = 0
        data.bePickNum  = 0     -- 被摘取豆子数量
        data.canPick    = true  -- 能否被摘取
        data.isTree     = true  -- 在树上

        local addRateSum, isUseFertilizer = ma_obj.getGourdAddRate(uData, true)
        data.isUseFertilizer = isUseFertilizer

        local rewardArr = ma_obj.getRewardArr(sData, data.type)
        local baseObj = arrayx.find(rewardArr, function (index, value)
            return value.id == ItemID.Gold
        end)
        local base = baseObj and baseObj.num or 0

        data.addNum = math.floor(base * addRateSum / 10000)

        table.insert(arr, data)

        endData = data
    end

    return isDirty
end

ma_obj.getRewardArr = function (sData, type)
    local rewardArr = sData.single_output_num
    if type == GourdType.BigGourd then
        rewardArr = sData.bigbeans
    elseif type == GourdType.FakeGourd then
        rewardArr = sData.fakebeans
    elseif type == GourdType.GiftGourd then
        rewardArr = sData.giftbeans
    elseif type == GourdType.HoeGourd then
        rewardArr = sData.hoebeans
    elseif type == GourdType.SuperGourd then
        rewardArr = sData.superbeans
    end
    return rewardArr
end

--- 添加动态记录
---@param id string 操作者
---@param toId string 被操作者
---@param type number
---@param param table
ma_obj.addRecord = function (id, toId, type, param) --, fruitType, num, isUseItem)
    local now = os.time()
    local dayDt = timex.getDayZero()

    local selector = {id = id, toId = toId, type = type, dayDt = dayDt}
    local recordData = dbx.get(TableNameArr.UserGourdAction, selector)
    if not recordData then
        recordData = {
            id = id,
            toId = toId,
            type = type,
            dayDt = dayDt,
            lastDt = now,
            recordArr = {}
        }
    end
    recordData.isLook = false

    if type == GourdActionType.PickFruit then
        table.insert(recordData.recordArr, {
            fruitType = param.fruitType,
            num = param.num,
            dt = now,
            isUseItem = param.isUseItem,
        })
    elseif type == GourdActionType.LoosenSoil then
        table.insert(recordData.recordArr, {
            isOpenBox = not not param.isOpenBox,
            num = param.num,
            dt = now,
            boxObj = param.boxObj,
        })
    elseif type == GourdActionType.FriendHelp then
        -- table.insert(recordData.recordArr, {
        --     dt = now,
        -- })
    end

    dbx.update_add(TableNameArr.UserGourdAction, selector, recordData)

    common.send_client(toId, "GourdActionRecord_C", {data = recordData})
end

CMD.GetData = function (id)
    local ok, obj = ma_obj.tryGetData(id)
    return obj
end

CMD.UpdateData = function (id, data)
    local ok, obj = ma_obj.tryGetData(id)
    if ok and data then
        table.merge(obj, data)
        ma_obj.updateGourd(obj)
    end
end

-- CMD.GetOutputReward = function (uId, lv, idArr)
--     local sData = cfg_gourd[lv]
--     local ok, obj = ma_obj.tryGetData(uId)
--     local now = os.time()

--     for index, id in ipairs(idArr) do
--         local gourdData = obj.gourdArr[id]
--         if gourdData then
--             ma_obj.updateGourdOutput(gourdData.arr, sData, now)
--         end
--     end

-- end

ma_obj._getGourdRewardArr = function (gourdData)
    local sData = cfg_gourd[gourdData.growLv]
    if not sData then
        return nil
    end

    local rewardArr = ma_obj.getRewardArr(sData, gourdData.type)
    rewardArr = table.clone(rewardArr)
    local baseObj = arrayx.find(rewardArr, function (index, value)
        return value.id == ItemID.Gold
    end)
    baseObj.num = baseObj.num + gourdData.addNum
    return rewardArr, baseObj
end

CMD.PickFruit = function (targetId, fromId, id, fruitId, isUseItem)
    local ok, obj = ma_obj.tryGetData(targetId)
    if not ok or not obj.gourdArr[id] then
        return RET_VAL.ERROR_3
    end

    local gourdDataArr = obj.gourdArr[id].arr or {}
    local index = arrayx.findIndex(gourdDataArr, function (index, value)
        return value.id == fruitId
    end)
    local gourdData = gourdDataArr[index]
    if not gourdData then
        return RET_VAL.ERROR_3
    end

    local now = os.time()
    if gourdData.endDt > now then
        return RET_VAL.NoUse_8
    end

    local rewardArr, goldItemObj = ma_obj._getGourdRewardArr(gourdData)
    if not rewardArr then
        return RET_VAL.ERROR_3
    end

    if targetId == fromId then
        table.remove(gourdDataArr, index)
        ma_obj.updateGourd(obj)
    else
        local cfgData = ma_globalCfg.getValue(103004)
        if gourdData.bePickNum / goldItemObj.num >= (cfgData.rateMax / 10000) then
            return RET_VAL.Other_10
        end

        rewardArr = {}
        local num = goldItemObj.num * datax.globalCfg[103004].ratePick // 10000
        table.insert(rewardArr, {id = ItemID.Gold, num = num})
    
        gourdData.bePickNum = gourdData.bePickNum + num
        gourdData.canPick = gourdData.bePickNum / goldItemObj.num >= (cfgData.rateMax / 10000)
        obj.bePickFruitNumDay = obj.bePickFruitNumDay + num
    
        -- updateData.bePickFruitNumDay = obj.bePickFruitNumDay
        -- updateData["gourdArr." .. id] = gourdDataArr
        dbx.update(TableNameArr.UserGourd, id, {
            bePickFruitNumDay = obj.bePickFruitNumDay,
            ["gourdArr." .. id] = obj.gourdArr[id]
        })

        ma_obj.addRecord(fromId, targetId, GourdActionType.PickFruit, {fruitType = gourdData.fruitType, num = num, isUseItem = isUseItem})
    end

    return RET_VAL.Succeed_1, rewardArr, obj.gourdArr[id]
end

CMD.PickFruitQuick = function (targetId, _type)
    local ok, obj = ma_obj.tryGetData(targetId)
    if not ok then
        return RET_VAL.ERROR_3
    end

    local now = os.time()
    local rewardArr = {}
    for key, data in pairs(obj.gourdArr) do
        local gourdDataArr = arrayx.select(data.arr, function (key, value)
            return value
        end)
        local len = #gourdDataArr
        for index = len, 1, -1 do
            local gourdData = gourdDataArr[index]
            if gourdData.endDt <= now and (_type == 0 or (_type == 1 and not gourdData.isTree)) then
                local arr = ma_obj._getGourdRewardArr(gourdData)
                if arr then
                    for index, obj in ipairs(arr) do
                        if rewardArr[obj.id] then
                            rewardArr[obj.id].num = rewardArr[obj.id].num + obj.num
                        else
                            rewardArr[obj.id] = obj
                        end
                    end
                end
                table.remove(data.arr, index)
            end
        end
    end

    ma_obj.updateGourd(obj)

    return table.toArray(rewardArr)
end

-- 施肥
CMD.Fertilizer = function (id, num)
    local ok, obj = ma_obj.tryGetData(id)

    obj.fertilizerNum = obj.fertilizerNum + num
    dbx.update(TableNameArr.UserGourd, id, {fertilizerNum = obj.fertilizerNum})

    ma_obj.updateGourd(obj)

    return obj.fertilizerNum-- 剩余施肥加成数量
end

-- 松土
CMD.LoosenSoil = function (id, fromId, o2Val, boxObj)
    local ok, obj = ma_obj.tryGetData(id)
    local loosenSoilRecord = obj.loosenSoilRecord

    local count = loosenSoilRecord[fromId] or 0
    count = count + 1
    loosenSoilRecord[fromId] = count
    dbx.update(TableNameArr.UserGourd, id, {["loosenSoilRecord." .. fromId] = count})

    local retObj = CMD.AddO2(id, fromId, o2Val, false, boxObj)
    retObj.loosenSoilCount = count

    return retObj
end

-- 增加氧气
CMD.AddO2 = function (id, fromId, o2Val, isOpenBox, boxObj)
    local ok, obj = ma_obj.tryGetData(id)
    local now = os.time()

    local cfgObj = ma_globalCfg.getValue(103012)
    if now > obj.loosenSoilEndDt then
        obj.loosenSoilLv = 0
        obj.loosenSoilO2Val = 0
        obj.loosenSoilEndDt = now + cfgObj.time
    end

    obj.loosenSoilO2Val = obj.loosenSoilO2Val + o2Val
    obj.loosenSoilO2ValDay = obj.loosenSoilO2ValDay + o2Val

    local loosenSoilLvOld = obj.loosenSoilLv
    local sData = cfg_gourd_oxygen[obj.loosenSoilLv + 1]
    if sData then
        local max = table.maxNum(cfg_gourd_oxygen, function (key, value)
            return value.level
        end)
        for i = obj.loosenSoilLv, (max - 1), 1 do
            sData = cfg_gourd_oxygen[obj.loosenSoilLv]
            if sData then
                if obj.loosenSoilO2Val >= sData.oxygen_num then
                    obj.loosenSoilLv = obj.loosenSoilLv + 1
                else
                    break;
                end
            end
        end
    end

    dbx.update(TableNameArr.UserGourd, id, {loosenSoilO2Val = obj.loosenSoilO2Val, loosenSoilO2ValDay = obj.loosenSoilO2ValDay, loosenSoilEndDt = obj.loosenSoilEndDt})

    ma_obj.addRecord(fromId, id, GourdActionType.LoosenSoil, {isOpenBox = isOpenBox, num = o2Val, boxObj = boxObj})

    return {
        loosenSoilLv        = obj.loosenSoilLv,
        loosenSoilLvOld     = loosenSoilLvOld,
        loosenSoilO2Val     = obj.loosenSoilO2Val,
        loosenSoilEndDt     = obj.loosenSoilEndDt,
    }
end

CMD.FriendHelp = function (id, friendId, friendData)
    local ok, obj = ma_obj.tryGetData(id)

    local cfgData = ma_globalCfg.getValue(103016)
    if #obj.friendHelpArr >= cfgData.numMax then
        return false
    end

    local now = os.time()
    local data = {
        id = friendId,
        data = friendData,
        endDt = now + cfgData.time
    }
    table.insert(obj.friendHelpArr, data)
    dbx.update(TableNameArr.UserGourd, id, {friendHelpArr = obj.friendHelpArr})

    ma_obj.addRecord(friendId, id, GourdActionType.FriendHelp)

    return true, data
end


function CMD.inject(filePath)
    require(filePath)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)