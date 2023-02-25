local skynet = require "skynet"

local ma_data = require "ma_data"

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

--#region 其他功能 require
local ma_user               = require "ma_user"
local ma_userother          = require "ma_userother"
local ma_usertime 			= require "ma_usertime"

local ma_globalCfg			= require "ma_global_cfg"
local ma_useritem 			= require "ma_useritem"
local ma_userhero 			= require "ma_userhero"
local ma_userrune			= require "ma_userrune"
local ma_usermail           = require "ma_usermail"
local ma_usertask           = require "ma_usertask"
local ma_userstore          = require "ma_userstore"
--#endregion

--#region 配置表 require
--#endregion



local ma_obj = {
    cmdObj = {} -- 存放 cmd 指令
}
local cmdObj = ma_obj.cmdObj

local userInfo = ma_data.userInfo

function ma_obj.init()
    
end

ma_obj.runCmd = function (cmd, paramArr)
    local result = {e_info = RET_VAL.Succeed_1, obj = "", tip = ""}

    if skynet.getenv("isTest") ~= "1" then
        result.e_info = RET_VAL.ERROR_3
        result.tip = "测试服才可使用"
    else
        local func = cmdObj[cmd]
        if func then
            local e_info, obj, tip = func(paramArr)
            if not e_info then
                e_info = RET_VAL.Default_0
                result.tip = "指令未返回执行结果 e_info"
            end

            result.e_info = e_info
            if obj then
                result.obj = obj
            end
            if tip then
                result.tip = tip
            end
        else
            result.e_info = RET_VAL.Default_0
            result.tip = "不存在该指令"
        end
    end

    if objx.isTable(result.obj) then
        result.obj = table.tostr(result.obj)
    else
        result.obj = tostring(result.obj)
    end

    return result
end

cmdObj.resetTimeAll = function (paramArr)
    local keyEnum = ma_userother.keyEnum
    ma_userother.set(keyEnum.newYear, ma_userother.get(keyEnum.newYear) - 1)
    ma_userother.set(keyEnum.newMonth, ma_userother.get(keyEnum.newMonth) - 1)
    ma_userother.set(keyEnum.newWeek, ma_userother.get(keyEnum.newWeek) - 1)
    ma_userother.set(keyEnum.newDay, ma_userother.get(keyEnum.newDay) - 1)

    skynet.call("user_season", "lua", "TestAddSeasonIndex")

    ma_usertime.check()

    return RET_VAL.Succeed_1
end

cmdObj.setLv = function (paramArr)
    local lv = math.max(objx.toNumber(paramArr[1]), 1)
    lv = math.min(lv, table.maxNum(datax.titleRewards, function (key, sData)
        return sData.level
    end))
    userInfo.lv = lv

    local sData = datax.titleRewards[lv]
    local num = ma_useritem.num(ItemID.LvExp) - sData.exp
    if num > 0 then
        ma_useritem.remove(ItemID.LvExp, num, "UserCmd_setLv")
    else
        ma_useritem.add(ItemID.LvExp, -num, "UserCmd_setLv")
    end

    ma_user.updateVal("lv")
    ma_user.updateVal("exp")

    return RET_VAL.Succeed_1, { lv = userInfo.lv }
end

cmdObj.add = function (paramArr)
    local itemId, num, time = tonumber(paramArr[1]), tonumber(paramArr[2]), objx.toNumber(paramArr[3])
    if num > 0 then
        local sendDataArr = {}

        local ret = ma_useritem.add(itemId, num, "UserCmd_add", sendDataArr)
        if not ret then
            return RET_VAL.NotExists_5
        end

        ma_common.showReward(sendDataArr)

    elseif num < 0 then
        local ret = ma_useritem.remove(itemId, -num, "UserCmd_add")
        if not ret then
            return RET_VAL.Fail_2
        end
    elseif num == 0 then
        local uData = ma_useritem.get(itemId)
        if uData.endDt and uData.endDt > 0 then
            uData.endDt = math.max(uData.endDt + time, 0)
            ma_useritem.saveData(itemId)
            ma_useritem.syncData({uData})
        end
    end

    return RET_VAL.Succeed_1, ma_useritem.get(itemId)
end

cmdObj.addHero = function (paramArr)
    local id, count = tonumber(paramArr[1]), tonumber(paramArr[2])

    local ret = false
    if count then
        ret = ma_userhero.add_limit(id, "UserCmd_addHero", nil, function (uData)
            if count then
                uData.useCount = count
            end
        end)
    else
        ret = ma_userhero.add(id, "UserCmd_addHero")
    end

    if not ret then
        return RET_VAL.Default_0
    end
    return RET_VAL.Succeed_1, ret
end

cmdObj.addRune = function (paramArr)
    local id = tonumber(paramArr[1])
    local ret = ma_userrune.add(id, "UserCmd_addRune")

    if not ret then
        return RET_VAL.Default_0, nil, "添加失败，错误的id"
    end

    return RET_VAL.Succeed_1, ret
end

cmdObj.addMail = function (paramArr)
    local itemArr = paramArr[2]
    if not objx.isTable(itemArr) then
        local ok, obj = pcall(load("return " .. paramArr[2]))
        if not ok then
            return RET_VAL.ERROR_3
        end
        itemArr = obj
    end

    local ret = ma_common.addMail(userInfo.id, paramArr[1], "UserCmd_addMail", nil, itemArr)
    if not ret then
        return RET_VAL.Fail_2, nil, "添加配置邮件出错，错误的邮件id"
    end

    return RET_VAL.Succeed_1, ret
end

cmdObj.addSystemMail = function (paramArr)
    local itemArr = paramArr[3]
    if not objx.isTable(itemArr) then
        local ok, obj = pcall(load("return " .. paramArr[3]))
        if not ok then
            return RET_VAL.ERROR_3
        end
        itemArr = obj
    end

    local ret = ma_common.addSystemMail(userInfo.id, paramArr[1], "UserCmd_addSystemMail", paramArr[2], itemArr)
    if not ret then
        return RET_VAL.Fail_2
    end

    return RET_VAL.Succeed_1, ret
end

cmdObj.addTaskNum = function (paramArr)
    local group, num = paramArr[1], tonumber(paramArr[2])
    local act_id = 0
    if paramArr[3] then
        act_id = tonumber(paramArr[3])
    end
    
    if act_id ~= 0 then
        ma_usertask.initActData(act_id)
    end

    ma_usertask.addVal(group, num)
    return RET_VAL.Succeed_1
end

cmdObj.buyStore = function (paramArr)
    local id, num, isTest = tonumber(paramArr[1]), tonumber(paramArr[2]), tonumber(paramArr[3]) == 1

    if isTest then
        if not ma_userstore.buy(id, num) then
            return RET_VAL.Default_0, nil, "购买失败"
        end
    else
        local ret = ma_userstore.buyStore(id, num)
        if ret ~= RET_VAL.Succeed_1 then
            return ret, nil, "返回错误码对应商城购买错误码"
        end
    end
    return RET_VAL.Succeed_1, ma_userstore.get(id)
end

cmdObj.getAdvertReward = function (paramArr)
    local _type = tonumber(paramArr[1])

    local ma_useradvert          = require "ma_useradvert"
    return ma_useradvert.finish(_type)
end

cmdObj.addAnnounce = function (paramArr)
    local args = paramArr[2]
    if not objx.isTable(args) then
        local ok, obj = pcall(load("return " .. paramArr[2]))
        if not ok then
            return RET_VAL.ERROR_3
        end
        args = obj
    end

    if not ma_common.addAnnounce(paramArr[1], args) then
        return RET_VAL.Fail_2, nil, "参数错误"
    end

    return RET_VAL.Succeed_1
end


return ma_obj