local skynet = require "skynet"
--local queue = require "skynet.queue"
local timer = require "timer"


--local objx = require "objx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"
local common = require "common_mothed"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require

--#endregion

local ma_obj = {
    likeObj = {},
    giftObj = {},
}

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

ServerData.userInfoCache = {}

ServerData.init = function ()
    dbx.update(TableNameArr.User, {}, {online = false}, true)
end


CMD.UpdateUserInfo = function (source, id, obj)
    local userInfo = ServerData.GetUserInfo(id)
    if userInfo then
        table.merge(userInfo, obj)
    end
end

local otherFieldsDefine = {}
otherFieldsDefine.id = true
otherFieldsDefine.nickname = true
otherFieldsDefine.head = true
otherFieldsDefine.headFrame = true
otherFieldsDefine.chatFrame = true
otherFieldsDefine.gameChatFrame = true
otherFieldsDefine.infoBg = true
otherFieldsDefine.clockFrame = true
otherFieldsDefine.title = true
otherFieldsDefine.lv = true
otherFieldsDefine.vip = true
otherFieldsDefine.gourdLv = true
otherFieldsDefine.skin = true
otherFieldsDefine.gender = true

otherFieldsDefine.online = true
otherFieldsDefine.offlineDt = true

otherFieldsDefine.cardBg = true
otherFieldsDefine.sceneBg = true
otherFieldsDefine.tableClothBg = true


-- 其他通过游戏内更新赋值的字段
-- roomState 游戏状态

ServerData.GetUserInfo = function (id, isDirty)
    -- TODO：暂时先不加清理机制
    local userInfo = ServerData.userInfoCache[id]
    if isDirty or not userInfo then
        local dbData = dbx.get(TableNameArr.User, id, otherFieldsDefine) or true
        userInfo = ServerData.userInfoCache[id]
        if not userInfo then
            userInfo = dbData
        elseif userInfo ~= true then
            table.merge(userInfo, dbData)
        end
        ServerData.userInfoCache[id] = userInfo
    end
    return userInfo ~= true and userInfo or nil
end

CMD.GetUserInfo = function (source, idArr, otherFields)
    local ret = {}

    local isDirty = false
    if otherFields then
        for key, value in pairs(otherFields) do
            if not otherFieldsDefine[key] then
                otherFieldsDefine[key] = true
                isDirty = true
            end
        end
    end

    if idArr then
        local userInfo
        for index, id in ipairs(idArr) do
            userInfo = ServerData.GetUserInfo(id, isDirty)
            if userInfo then
                ret[id] = userInfo
            end
        end
    end

    return ret
end

ma_obj.getUserLike = function (id)
    local obj = ma_obj.likeObj[id]
    if not obj then
        local data = dbx.get(TableNameArr.User, id, {_id = false, like = true}) or common.getRobotInfo(id)
        if not data then
            return nil
        end
        obj = {like = data.like or 0, isRobot = data.isRobot}
    end
    return obj
end

CMD.UserLike = function (source, id)
    local obj = ma_obj.getUserLike(id)
    if obj then
        obj.like = obj.like + 1
        dbx.update(obj.isRobot and TableNameArr.User or TableNameArr.ServerRobot, id, {like = obj.like})
        return true, obj.like
    end
    return false
end

CMD.GetUserGiftDatas = function (source, id)
    local data = ma_obj.giftObj[id]
    if not data then
        local obj = dbx.get(TableNameArr.UserGiftRecord, id)
        if not obj then
            obj = {
                id = id,
                data = {},
                record = {},-- {{}}
            }
            dbx.add(TableNameArr.UserGiftRecord, obj)
        end
        ma_obj.giftObj[id] = obj.data
    end
    return data
end

CMD.UserGiftSend = function (source, uId, sId, num, asd)
    local data = CMD.GetUserGiftDatas(uId)
    local currentNum = data[sId] or 0
    currentNum = currentNum + num
    data[sId] = currentNum

    dbx.update(TableNameArr.UserGiftRecord, uId, {["data." .. sId] = currentNum})

    return currentNum
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