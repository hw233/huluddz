local skynet = require "skynet"
local eventx = require "eventx"

local ma_data = require "ma_data"
local ma_user = require "ma_user"
local ma_useritem = require "ma_useritem"

local datax = require "datax"
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
local cfg_items = require "cfg.cfg_items"
local cfg_fashion = require "cfg.cfg_fashion"
local cfg_skilllv_cost = require "cfg.cfg_skilllv_cost"

--#endregion

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local ma_obj = {
    cfg_hero = {},
    userhero = nil,
}

ma_obj.initCfg = function ()
    for key, sData in pairs(cfg_fashion) do
        sData.id = key
        if sData.type == FashionType.Hero then
            ma_obj.cfg_hero[sData.id] = sData
        end
    end
end

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.initCfg()

    local obj = dbx.get(TableNameArr.UserHero, userInfo.id)
    if not obj then
        obj = {
            id = userInfo.id,
            dataTable = {},
        }
        dbx.add(TableNameArr.UserHero, obj)
    else

    end
    ma_obj.userhero = obj.dataTable


    eventx.listen(EventxEnum.UserOnline, function ()
        if not userInfo.heroId or not userInfo.skin then
            ma_obj.resetUseHero()
        end

        ma_obj.computeBonus()
    end)

    eventx.listen(EventxEnum.RoomGameOver, function (gameType, obj)
        local uData = ma_obj.get(obj.heroId)
        if uData and not uData.notLimit then
            uData.useCount = uData.useCount - 1
            ma_obj.syncData(uData.id)

            if uData.useCount <= 0 then
                ma_obj.resetUseHero()
            end
        end
    end)

    eventx.listen(EventxEnum.UserNewWeek, function (args)
        --每周1重置角色培养，心情
        ma_obj.weekResetMood()

        for key, value in pairs(ma_obj.userhero) do
            if value.sId == HeroId.TangBaoEr then
                if value.skillCount and value.skillCount > 0 then
                    value.skillCount = 0
                    ma_obj.syncData(value.id)
                end
            end
        end
    end)
end

--#region 核心部分

ma_obj.getDatas = function ()
    return ma_obj.userhero
end

ma_obj.get = function (id)
    local uData = ma_obj.userhero[id]
    if uData then
        uData.skillCount = uData.skillCount or 0
    end
    return uData
end

ma_obj.syncData = function (id, syncType)
    syncType = syncType or 1
    ma_common.send_myclient("SyncUserHero", {data = ma_obj.get(id), syncType = syncType})
end

--- 添加无期限的英雄
---@param id string|number
---@param from string
---@param sendDatas table
---@return table 返回空表示添加失败
ma_obj.add = function (id, from, sendDatas)
    id = tonumber(id)
    local sData = ma_obj.cfg_hero[id]
    if not sData then
        return nil
    end

    id = tostring(id)
    local uData = ma_obj.userhero[id]
    if uData then
        return nil
    end

    uData = {
        id = id,
        sId = sData.id,
        skillLv = 1,
        moodLv = 1,
        moodExp = 0,
        runeArr = {},

        notLimit = true,
        useCount = 0,

        skillCount = 0,
    }
    ma_obj.userhero[uData.id] = uData
    --HeroClass.Compute(user, uData);

    if sendDatas then
        --sendDatas["hero_" .. id]++;
    end

    dbx.update(TableNameArr.UserHero, userInfo.id, { ["dataTable." .. uData.id] = uData })

    ma_common.write_record(TableNameArr.Hero_REC, "add", from, id)

    eventx.call(EventxEnum.UserHeroAdd, sData, uData)

    ma_obj.syncData(uData.id, 0)

    return uData
end

--- 添加有期限的英雄
---@param id string|number
---@param from string
---@param sendDatas table
---@param dataHandle fun(uData: any)
---@return table 返回空表示添加失败
ma_obj.add_limit = function (id, from, sendDatas, dataHandle)
    id = tonumber(id)
    local sData = ma_obj.cfg_hero[id]
    if not sData then
        return nil
    end

    local uData = table.first(ma_obj.userhero, function (key, value)
        return value.sId == id and not value.notLimit
    end)
    if not uData then
        uData = {
            id = objx.getUid_Time(),
            sId = sData.id,
            skillLv = 1,
            moodLv = 1,
            moodExp = 0,
            runeArr = {},
    
            notLimit = false,
            useCount = 0,

            skillCount = 0,
        }
    end

    if dataHandle then
        dataHandle(uData)
    end
    uData.notLimit = false

    ma_obj.userhero[uData.id] = uData
    --HeroClass.Compute(user, uData);

    if sendDatas then
        --sendDatas["hero_" .. id]++;
    end

    dbx.update(TableNameArr.UserHero, userInfo.id, { ["dataTable." .. uData.id] = uData })

    ma_common.write_record(TableNameArr.Hero_REC, "addtemp", from, id, uData.useCount)

    eventx.call(EventxEnum.UserHeroAdd, sData, uData)

    ma_obj.syncData(uData.id, 0)

    return uData
end

ma_obj.use = function (id)
    local uData = ma_obj.userhero[id]
    if uData then
        userInfo.skin = uData.sId
        userInfo.heroId = id

        if uData.notLimit then
            userInfo.heroIdLast = userInfo.heroId
        end

        local updateData = {skin = userInfo.skin, heroId = userInfo.heroId, heroIdLast = userInfo.heroIdLast}
        dbx.update(TableNameArr.User, userInfo.id, updateData)

        ma_common.send_myclient("SyncUser_Hero", updateData)

        ma_user.computeBonus()
    end
    return uData
end

--- 重置为上一次使用的永久角色
ma_obj.resetUseHero = function ()
    if userInfo.heroIdLast then
        ma_obj.use(userInfo.heroIdLast)
    else
        local arr = table.where(ma_obj.getDatas(), function (key, value)
            return value.notLimit or value.useCount > 0
        end)
        local data = objx.getChance(arr, function (value)
            return 1
        end)
        if data then
            ma_obj.use(data.id)
        end
    end
end


ma_obj.computeBonus = function (heroId)
    if heroId and heroId ~= userInfo.heroId then
        return
    end

    local uHero = ma_obj.get(userInfo.heroId)
    if uHero then
        local moodBonusObj = {}
        local sData = datax.mood[uHero.moodLv]
        if sData then
            moodBonusObj[BonusType.GameRuneExpFixedWin] = (moodBonusObj[BonusType.GameRuneExpFixedWin] or 0) + sData.win_exp_book
            moodBonusObj[BonusType.GameRuneExpFixedLose] = (moodBonusObj[BonusType.GameRuneExpFixedLose] or 0) + sData.lose_exp_book

            moodBonusObj[BonusType.RuneExpBook] = sData.rune_exp_book
            moodBonusObj[BonusType.SkillExpBook] = sData.skill_exp_book
        end
        local bonusObj = userInfo.bonusObj or {}
        bonusObj.mood = moodBonusObj
        userInfo.bonusObj = bonusObj
        dbx.update(TableNameArr.User, userInfo.id, {["bonusObj.mood"] = moodBonusObj})

        eventx.call(EventxEnum.UserBonusDataChange)
    end
end

ma_obj.getUseHeroList = function () 
    local NotlimitHeros = {}
    local limitHeros = {}
    if ma_obj.userhero then
        for key, hero in pairs(ma_obj.userhero) do
            skynet.logd("getUseHeroList::", key, "=", table.tostr(hero))    
            if hero then
                if hero.notLimit then
                    NotlimitHeros[key] = hero
                else
                    limitHeros[key] = hero
                end
            end
        end
    end

    return NotlimitHeros, limitHeros
end

ma_obj.weekResetMood = function ()
    local globalId = 180001
    local _cfgDataList = datax.globalCfg[globalId]
    if not _cfgDataList then
        return
    end

    local heroList = ma_obj.userhero
    if not heroList then
        return
    end


    for hero_id, hero_data in pairs(heroList) do
        local _mood_data = objx.getChance(_cfgDataList, function (value) return value.weight end)
        if _mood_data then
            hero_data.moodLv = math.max(hero_data.moodLv + _mood_data.value, 1) 
            if hero_data.moodLv == 1 then
                hero_data.moodExp = 0
            else
                local sData = datax.mood[hero_data.moodLv-1]
                if sData then
                    hero_data.moodExp = sData.need_mood
                end
            end

            local updateData = {}
            
            dbx.update(TableNameArr.UserHero, userInfo.id, {["dataTable." .. hero_id] = hero_data})
            ma_obj.syncData(hero_id)
        end
    end


end

--ResetMood
--#endregion


REQUEST_New.GetUserHeroDatas = function (args)
    local id = args.id
    local datas

    if id then
        local obj = dbx.get(TableNameArr.UserHero, id)
        datas = obj and obj.dataTable or {}
    end
    datas = datas or ma_obj.userhero

    return {id = id, datas = datas}
end

REQUEST_New.HeroUse = function (args)
    local uData = ma_obj.use(args.id)
    if not uData then
        return RET_VAL.NotExists_5
    end
    return RET_VAL.Succeed_1, {skin = userInfo.skin, heroId = userInfo.heroId}
end

REQUEST_New.HeroSkillLvUp = function (args)
    local id, type = args.id, args.type

    local uData = ma_obj.userhero[id]
    if not uData then
        return RET_VAL.NotExists_5
    end
    if not uData.notLimit then
        return RET_VAL.Fail_2
    end

    local hero = ma_obj.cfg_hero[uData.sId]
    local arr = table.where(cfg_skilllv_cost, function (key, value)
        return value.skill_quality == hero.fashion_quality
    end)
    local cfgObj = table.toObject(arr, function (key, value)
        return value.skill_level
    end)

    local sData = cfgObj[uData.skillLv + 1]
    if not sData then
        return RET_VAL.NoUse_8
    end
    sData = cfgObj[uData.skillLv]

    if type == 1 then
        if not ma_useritem.removeList(sData.upgrade_cost_exp, 1, "HeroSkillLvUp_技能升级") then
            return RET_VAL.Lack_6
        end
    elseif type == 2 then
        if not ma_useritem.removeList(sData.upgrade_cost_diamond, 1, "HeroSkillLvUp_技能升级") then
            return RET_VAL.Lack_6
        end
    else
        return RET_VAL.ERROR_3
    end

    local skillLvOld = uData.skillLv

    uData.skillLv = uData.skillLv + 1

    dbx.update(TableNameArr.UserHero, userInfo.id, { ["dataTable." .. id .. ".skillLv"] = uData.skillLv })

    eventx.call(EventxEnum.HeroSkillUp, uData)

    return RET_VAL.Succeed_1, {skillLv = uData.skillLv, skillLvOld = skillLvOld}
end

REQUEST_New.HeroMoodUp = function (args)
    local id, costArr = args.id, args.costArr

    local uData = ma_obj.userhero[id]
    if not uData then
        return RET_VAL.NotExists_5
    end
    if not uData.notLimit then
        return RET_VAL.Fail_2
    end

    local maxData = table.max(datax.mood, function (key, value)
        return value.level
    end)
    
    if uData.moodLv >= maxData.level then
        return RET_VAL.NoUse_8
    end

    local maxExp = math.max(datax.mood[maxData.level - 1].need_mood - uData.moodExp, 0)
    local upExp = 0
    local itemArr = {}

    for index, value in ipairs(costArr) do
        local item = cfg_items[value.id]
        if not item or item.type ~= 5 then
            return RET_VAL.ERROR_3
        end

        local itemExp = item.param[1].num
        local num = math.ceil(maxExp / itemExp)
        if num < value.num then
            table.insert(itemArr, {id = value.id, num = num})
            upExp = upExp + itemExp * num
            break;
        else
            table.insert(itemArr, value)
            maxExp = maxExp - itemExp * value.num
            upExp = upExp + itemExp * value.num
        end
    end

    if not ma_useritem.removeList(itemArr, 1, "HeroMoodUp_提升心情") then
        return RET_VAL.Lack_6
    end

    local moodExpOld, moodLvOld = uData.moodExp, uData.moodLv

    uData.moodExp = uData.moodExp + upExp

    for i = uData.moodLv, maxData.level - 1 do
        local sData = datax.mood[i]
        if uData.moodExp >= sData.need_mood then
            uData.moodLv = sData.level + 1
        else
            break;
        end
    end

    dbx.update(TableNameArr.UserHero, userInfo.id, { ["dataTable." .. id] = uData })

    ma_obj.computeBonus(id)

    eventx.call(EventxEnum.HeroMoodUp, uData)

    return RET_VAL.Succeed_1, {moodExp = uData.moodExp, moodLv = uData.moodLv, moodExpOld = moodExpOld, moodLvOld = moodLvOld}
end


CMD.UserHeroSkillUse = function (source, heroId)
    local uData = ma_obj.get(heroId)
    if not uData then
        return false
    end

    local skillId = datax.fashion[uData.sId].skill_id
    local skillBuffCfg = datax.skillBuff[skillId][uData.skillLv]

    if not skillBuffCfg then
        return false
    end

    if skillBuffCfg.week_chance <= uData.skillCount then
        return false
    end

    uData.skillCount = uData.skillCount + 1
    ma_obj.syncData(uData.id)

    return true
end

return ma_obj