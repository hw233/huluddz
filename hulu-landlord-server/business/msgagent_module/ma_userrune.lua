local skynet = require "skynet"

local ma_data = require "ma_data"
local ma_useritem = require "ma_useritem"
local ma_userhero = require "ma_userhero"

local datax = require "datax"
local eventx = require "eventx"
local objx = require "objx"
local arrayx = require "arrayx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
--local cfg_items = require "cfg.cfg_items"
local cfg_rune = require "cfg.cfg_rune"
local cfg_rune_level = require "cfg.cfg_rune_level"

--#endregion

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local ma_obj = {
    userrune = nil,
}

ma_obj.initCfg = function ()
    
end

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.initCfg()

    local versionsKey = "2021.12.31 01:48"      -- 数据版本
    local valVersionKey = "2021.12.31 01:48"    -- 数值版本
    local obj = dbx.get(TableNameArr.UserRune, userInfo.id) or {}
    if obj.versionsKey ~= versionsKey then
        obj.versionsKey = versionsKey

        obj.id = userInfo.id
        obj.dataTable = obj.dataTable or {}

        if obj.valVersionKey ~= valVersionKey then
            obj.valVersionKey = valVersionKey
            ma_obj._valVersionUpdate(obj.dataTable)
        end

        dbx.update_add(TableNameArr.UserRune, userInfo.id, obj)
    end
    ma_obj.userrune = obj.dataTable

    eventx.listen(EventxEnum.UserOnline, function ()
        ma_obj.computeBonus()
    end)

end


--#region 核心部分

ma_obj.getDatas = function ()
    return ma_obj.userrune
end

ma_obj.get = function (id)
    return ma_obj.userrune[id]
end

--- 
---@param id string|number
---@param from string
---@param sendDatas table
---@return table 返回空表示添加失败
ma_obj.add = function (id, from, sendDatas)
    id = tonumber(id)
    local sData = cfg_rune[id]
    if not sData then
        return nil
    end

    local uData = {
        id = objx.getUid_Time(),
        sId = id,
        uHero = "",
        lv = 1,
        exp = 0,
    }
    ma_obj.userrune[uData.id] = uData

    if sendDatas then
        --sendDatas["rune_" .. id]++;
    end

    dbx.update(TableNameArr.UserRune, userInfo.id, { ["dataTable." .. uData.id] = uData })

    --ma_common.write_record(TableNameArr.Rune_REC, "add", from, id)

    eventx.call(EventxEnum.RuneAdd, sData, uData)

    return uData
end

--- 内部使用
ma_obj._remove = function (id, from, updateData)
    local uData = ma_obj.userrune[id]
    if not uData then
        return false
    end

    ma_obj.unequip(id)

    ma_obj.userrune[id] = nil
    updateData["dataTable." .. id] = ""

    return true
end

ma_obj.remove = function (id, from)
    local updateData = {}

    local ret = ma_obj._remove(id, from, updateData)

    dbx.del_field(TableNameArr.UserRune, userInfo.id, updateData)

    return ret
end

ma_obj.removeList = function (idArr, from)
    if not next(idArr) then
        return true
    end

    local updateData = {}

    for index, id in ipairs(idArr) do
        if not ma_obj.userrune[id] then
            return false
        end
    end

    for index, id in ipairs(idArr) do
        ma_obj._remove(id, from, updateData)
    end

    dbx.del_field(TableNameArr.UserRune, userInfo.id, updateData)

    return true
end

---comment
---@param id string
---@param heroId string
---@param pos number 装备符文的位置
---@return boolean
ma_obj.equip = function (id, heroId, pos)
    local uData = ma_obj.userrune[id]
    if not uData then
        return false, RET_VAL.NotExists_5
    end

    local uHero = ma_userhero.get(uData.uHero)
    if uHero then
        return RET_VAL.Exists_4
    end

    uHero = ma_userhero.get(heroId)
    if not uHero then
        return false, RET_VAL.NotExists_5
    end

    local sData = ma_userhero.cfg_hero[uHero.sId]
    local maxRuneNum = sData.carry_rune_num
    if pos < 1 or pos > maxRuneNum then
        return false, RET_VAL.Lack_6
    end

    pos = tostring(pos)
    if uHero.runeArr and uHero.runeArr[pos] then
        ma_obj.unequip(uHero.runeArr[pos].value)
    end

    uData.uHero = heroId
    uHero.runeArr[pos] = {key = pos, value = id}
    
    dbx.update(TableNameArr.UserRune, userInfo.id, { ["dataTable." .. id .. ".uHero"] = uData.uHero })
    dbx.update(TableNameArr.UserHero, userInfo.id, { ["dataTable." .. heroId .. ".runeArr"] = uHero.runeArr })
    ma_userhero.syncData(uHero.id)

    ma_obj.computeBonus(heroId)

    return true, RET_VAL.Succeed_1, { uHero = uData.uHero, runeArr = uHero.runeArr }
end

---comment
---@param id string
---@return boolean
ma_obj.unequip = function (id)
    local uData = ma_obj.userrune[id]
    if not uData then
        return false, RET_VAL.NotExists_5
    end

    local heroId = uData.uHero
    if uData.uHero and #uData.uHero > 0 then
        local uHero = ma_userhero.get(uData.uHero)
        if uHero then
            local isUpdate = false
            for key, obj in pairs(uHero.runeArr) do
                if obj.value == id then
                    isUpdate = true
                    uHero.runeArr[key] = nil
                    break;
                end
            end
            if isUpdate then
                dbx.update(TableNameArr.UserHero, userInfo.id, { ["dataTable." .. uHero.id .. ".runeArr"] = uHero.runeArr })
                ma_userhero.syncData(uHero.id)
            end
        end
    end

    uData.uHero = ""

    dbx.update(TableNameArr.UserRune, userInfo.id, { ["dataTable." .. id .. ".uHero"] = uData.uHero })

    ma_obj.computeBonus(heroId)

    return true, RET_VAL.Succeed_1
end

ma_obj.computeBonus = function (heroId)
    if heroId and heroId ~= userInfo.heroId then
        return
    end

    local uHero = ma_userhero.get(userInfo.heroId)
    if uHero then
        local runeBonusObj = {}
        local uDataArr = table.where(table.select(uHero.runeArr, function (key, kvObj)
            return ma_obj.get(kvObj.value)
        end), function (key, value)
            return value
        end)
        local groupDatas = table.groupBy(uDataArr, function (key, uData)
            return uData.sId
        end)
        for key, arr in pairs(groupDatas) do
            local uData = table.max(arr, function (key, value)
                return value.lv
            end)
            local rune = cfg_rune[uData.sId]
            if rune then
                local key, base = rune.rune_basal_value.key, rune.rune_basal_value.value
                runeBonusObj[key] = (runeBonusObj[key] or 0) + (base + rune.rune_level_value * math.max(uData.lv - 1, 0))
            end
        end
        local bonusObj = userInfo.bonusObj or {}
        bonusObj.rune = runeBonusObj
        userInfo.bonusObj = bonusObj
        dbx.update(TableNameArr.User, userInfo.id, {["bonusObj.rune"] = runeBonusObj})

        eventx.call(EventxEnum.UserBonusDataChange)
    end
end

ma_obj._valVersionUpdate = function (datas)
    for key, uData in pairs(datas) do
        if uData.exp > 0 then
            uData.exp = uData.exp * 4

            local rune = cfg_rune[uData.sId]
            local cfgObj = datax.runeLevel[rune.rune_quality]
            local maxData = table.max(cfgObj, function (key, value)
                return value.rune_growup_cost[1].num
            end)

            for i = uData.lv, maxData.level - 1 do
                local sData = cfgObj[i]
                if uData.exp >= sData.rune_growup_cost[1].num then
                    uData.lv = uData.lv + 1
                else
                    break;
                end
            end
        end
    end
end

--#endregion


REQUEST_New.GetUserRuneDatas = function (args)
    local id = args.id
    local datas

    if id then
        local obj = dbx.get(TableNameArr.UserRune, id)
        datas = obj and obj.dataTable or {}
    end
    datas = datas or ma_obj.userrune

    return {id = id, datas = datas}
end

REQUEST_New.RuneEquip = function (args)
    local _, ret = ma_obj.equip(args.id, args.heroId, args.pos)
    return ret
end

REQUEST_New.RuneUnEquip = function (args)
    local _, ret = ma_obj.unequip(args.id)
    return ret
end

REQUEST_New.RuneLvUp = function (args)
    local id, _type, itemNum, runeArr = args.id, args.type, args.itemNum, args.runeArr

    local uData = ma_obj.userrune[id]
    if not uData then
        return RET_VAL.NotExists_5
    end

    local rune = cfg_rune[uData.sId]
    local arr = table.where(cfg_rune_level, function (key, value)
        return value.rune_quality == rune.rune_quality
    end)
    local cfgObj = table.toObject(arr, function (key, value)
        return value.level
    end)

    local maxData = table.max(cfgObj, function (key, value)
        return value.rune_growup_cost[1].num
    end)

    if uData.lv >= maxData.level then
        return RET_VAL.NoUse_8
    end

    local lvOld, expOld = uData.lv, uData.exp

    if _type == 1 then
        local itemId = maxData.rune_growup_cost[1].id
        local maxExp = math.max(cfgObj[maxData.level - 1].rune_growup_cost[1].num - uData.exp, 0)
        itemNum = math.min(itemNum, maxExp)
        
        maxExp = maxExp - itemNum
        local upExp = itemNum;
        
        local runeIdArr = {}
        if runeArr then
            local runeArr1 = arrayx.distinct(runeArr)
            if #runeArr1 ~= #runeArr then
                return RET_VAL.ERROR_3
            end
            
            for index, runeId in ipairs(runeArr) do
                if not ma_obj.userrune[runeId] or runeId == id then
                    return RET_VAL.ERROR_3
                end
            end

            for index, runeId in ipairs(runeArr) do
                if maxExp <= 0 then
                    break;
                end
                local runeData = ma_obj.userrune[runeId]
                local sData = cfg_rune[runeData.sId]
                local exp = sData.convert_exp + runeData.exp
                
                maxExp = maxExp - exp
                upExp = upExp + exp
                table.insert(runeIdArr, runeId)
            end
        end

        if not ma_useritem.remove(itemId, itemNum, "RuneLvUp_符文升级") then
            return RET_VAL.Lack_6
        end

        ma_obj.removeList(runeIdArr, "RuneLvUp_符文升级")

        uData.exp = uData.exp + upExp

        for i = uData.lv, maxData.level - 1 do
            local sData = cfgObj[i]
            if uData.exp >= sData.rune_growup_cost[1].num then
                uData.lv = uData.lv + 1
            else
                break;
            end
        end
    elseif _type == 2 then
        local sData = cfgObj[uData.lv]
        if not ma_useritem.removeList(sData.rune_growup_diamond_cost, 1, "RuneLvUp_符文升级") then
            return RET_VAL.Lack_6
        end

        local lastCfgData = cfgObj[uData.lv - 1]
        local tempExp = math.max(0, uData.exp - (lastCfgData and lastCfgData.rune_growup_cost[1].num or 0))

        uData.lv = uData.lv + 1
        uData.exp = sData.rune_growup_cost[1].num + tempExp  -- 钻石直接上级，保留上一级经验
    else
        return RET_VAL.ERROR_3
    end

    dbx.update(TableNameArr.UserRune, userInfo.id, { ["dataTable." .. id] = uData })

    ma_obj.computeBonus(uData.uHero)

    eventx.call(EventxEnum.RuneLvUp, uData, uData.lv - lvOld)

    return RET_VAL.Succeed_1, {lv = uData.lv, exp = uData.exp, lvOld = lvOld, expOld = expOld}
end


return ma_obj