local skynet = require "skynet"

local ma_data = require "ma_data"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local eventx = require "eventx"
local timex  = require "timex"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 其他功能 require
local ma_globalCfg			= require "ma_global_cfg"

local moudles = {
    "ma_user",
    "ma_userother",

    "ma_useritem",
    "ma_userstore",
    "ma_userpay",
    "ma_userhero",
    "ma_userheroget",
    "ma_userrune",
    "ma_usermail",
    "ma_usertask",
    "ma_usergourd",
    "ma_useradvert",
    "ma_userannounce",


    "ma_userroom",
    "ma_userroom_ddz",
    "ma_userroom_qqp",

    "ma_usersettinginfo",
    "ma_userpieceshop",
    "ma_usersignin",
    "ma_userfriend",
    "ma_uservip",
    "ma_userotherplayerinfo",
    "ma_user_ranklist",

    "activity.ma_useractivity",
    "activity.ma_activity_4001",
    "activity.ma_activity_4004",
    "activity.ma_activity_4007",
    "activity.ma_activity_task",

    "ma_usergamefunc",
    --start
    "ma_userxybaoxiang",
    "ma_uservisitors",
    "ma_usersgin14",
    "ma_user_realname",
    "ma_user_share",
    "ma_user_writelog",
    "ma_user_lamp",
    "ma_user_achievement",
    "ma_user_txz",
    "ma_usersgin7",
}

local ma_useritem 			= require "ma_useritem"
local ma_userhero 			= require "ma_userhero"
local ma_userrune 			= require "ma_userrune"

local ma_usercmd          = require "ma_usercmd" -- 这个放最后
--#endregion

--#region 配置表 require
--#endregion

local REQUEST, REQUEST_New = {}, {}
local CMD = {}

local ma_obj = {
    _init = false
}

local userInfo = ma_data.userInfo

function ma_obj.init(request, cmd, request_new)
    if ma_obj._init then
        return
    end
    ma_obj._init = true

    table.tryMerge(request, REQUEST)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj._load_moudle(cmd, request_new)

    ma_obj.initData()
    ma_usercmd.init()   -- 这个放最后
end

ma_obj._load_moudle = function (cmd, request_new)
    for index, moudleName in ipairs(moudles) do
        local moudleObj = require(moudleName)
        if moudleObj.init then
            moudleObj.init(cmd, request_new)
        end
    end
end

ma_obj.initData = function ()
    eventx.listen(EventxEnum.UserOnline, function ()

        ma_obj.initDefault()
        ma_obj:updateDefault()
    end, eventx.EventPriority.Before)

    eventx.listen(EventxEnum.ItemExpire, function (item)
        ma_obj.UpdateUserExpireData(item)
    end)

end

ma_obj.initDefault = function ()
    if userInfo.initDataFlag then
        return
    end

    userInfo.initDataFlag = true
    dbx.update(TableNameArr.User, userInfo.id, {initDataFlag = userInfo.initDataFlag})

    local init_items = ma_globalCfg.getValue(101008)
    ma_useritem.addList(init_items, 1, "InitData_玩家初始数据")
    --直接使用 头像，闹钟，聊天框等可使用道具
    if init_items then
        for _, _item in pairs(init_items) do
            local _itemCfg = datax.items[_item.id]
            if _itemCfg then
                if _itemCfg.type == ItemType.HeadFrame  then
                    ma_useritem.add(_item.id, _item.num,"InitData_玩家初始数据")
                    REQUEST_New.SetHeadFrame({headFrameItemId = _item.id})
                elseif _itemCfg.type == ItemType.ClockFram  then
                    ma_useritem.add(_item.id, _item.num,"InitData_玩家初始数据")
                    REQUEST_New.SetClockFrame({clockFrameItemId = _item.id})
                elseif _itemCfg.type == ItemType.GameChatFram  then
                    ma_useritem.add(_item.id, _item.num,"InitData_玩家初始数据")
                    REQUEST_New.SetGameChatFrame({gameChatFrameItemId = _item.id}) 
                elseif _itemCfg.type == ItemType.InfoBg  then
                    ma_useritem.add(_item.id, _item.num,"InitData_玩家初始数据")
                    REQUEST_New.SetInfoBg({InfoBgItemId = _item.id})
                end
            end
        end
    end
    -- 设置默认头像
    REQUEST_New.SetHead({head = "1001"})
end


ma_obj.updateDefault = function ()
    if not userInfo.cardBg then
        local _cfgData = datax.globalCfg[101014]
        if _cfgData then
            local _id = _cfgData.val
            ma_useritem.add(_id, 1, "设置默认数据cardBg")
            REQUEST_New.SetCardBg({cardBgItemId = _id})
        end
    end

    if not userInfo.sceneBg then
        local _cfgData = datax.globalCfg[101012]
        if _cfgData then
            local _id = _cfgData.val
            ma_useritem.add(_id, 1, "设置默认数据sceneBg")
            REQUEST_New.SetSceneBg({sceneBgItemId = _id})
        end
    end

    if not userInfo.tableClothBg then
        local _cfgData = datax.globalCfg[101013]
        if _cfgData then
            local _id = _cfgData.val
            ma_useritem.add(_id, 1, "设置默认数据tableClothBg")
            REQUEST_New.SetTableClothBg({tableClothBgItemId = _id})
        end
    end
end

ma_obj.UpdateUserExpireData = function (item)
    if not item then
        return
    end
    local sData = datax.items[tostring(item.id)]
    if not sData then
        return
    end

    local param = sData.param
    if not param then
        return
    end

    local id = param.id
    if sData.type == ItemType.InfoBg then
        if tostring(userInfo.infoBg) ==  tostring(id) then
            local init_items = ma_globalCfg.getValue(101008)
            if not init_items then
                return
            end

            for _, _item in pairs(init_items) do
                local _itemCfg = datax.items[_item.id]
                if _itemCfg and _itemCfg.type == ItemType.InfoBg then
                    REQUEST_New.SetInfoBg({InfoBgItemId = _item.id})
                end
            end
        end
    elseif sData.type == ItemType.HeadFrame then
        if tostring(userInfo.headFrame) ==  tostring(id) then
            local init_items = ma_globalCfg.getValue(101008)
            if not init_items then
                return
            end
            for _, _item in pairs(init_items) do
                local _itemCfg = datax.items[_item.id]
                if _itemCfg and _itemCfg.type == ItemType.HeadFrame then
                    REQUEST_New.SetHeadFrame({headFrameItemId = _item.id})
                end
            end
        end
    elseif sData.type == ItemType.clockFrame then
        if tostring(userInfo.clockFrame) ==  tostring(id) then
            local init_items = ma_globalCfg.getValue(101008)
            if not init_items then
                return
            end

            for _, _item in pairs(init_items) do
                local _itemCfg = datax.items[_item.id]
                if _itemCfg and _itemCfg.type == ItemType.ClockFram then
                    REQUEST_New.SetClockFrame({clockFrameItemId = _item.id})
                end
            end
        end
    elseif sData.type == ItemType.GameChatFram then
        if tostring(userInfo.gameChatFrame) ==  tostring(id) then
            local init_items = ma_globalCfg.getValue(101008)
            if not init_items then
                return
            end
            for _, _item in pairs(init_items) do
                local _itemCfg = datax.items[_item.id]
                if _itemCfg and _itemCfg.type == ItemType.GameChatFram then
                    REQUEST_New.SetGameChatFrame({gameChatFrameItemId = _item.id})
                end
            end
        end
    elseif sData.type == ItemType.sceneBg then
        if tostring(userInfo.sceneBg)  == tostring(id) then
            local _cfgData = datax.globalCfg[101012]
            if not _cfgData then
                return
            end
            local _id = _cfgData.val
            REQUEST_New.SetSceneBg({sceneBgItemId = _id})
        end
    elseif sData.type == ItemType.tableClothBg then
        if tostring(userInfo.tableClothBg)  == tostring(id) then
            local _cfgData = datax.globalCfg[101013]
            if not _cfgData then
                return
            end
            local _id = _cfgData.val
            REQUEST_New.SetTableClothBg({tableClothBgItemId = _id})
        end
    elseif sData.type == ItemType.cardBg then
        if tostring(userInfo.cardBg)  == tostring(id) then
            local _cfgData = datax.globalCfg[101014]
            if not _cfgData then
                return
            end
            local _id = _cfgData.val
            REQUEST_New.SetCardBg({cardBgItemId = _id})
        end
    end
end


-- 配牌服设置使用
CMD.SetUserField = function (source, key, value)

    local updateData = {[key] = value}
    dbx.update(TableNameArr.User, userInfo.id, updateData)

    ma_common.updateUserBase(userInfo.id, updateData)

    ma_common.send_myclient("SyncUserData_GM", {data = updateData})
end


CMD.UserCmd = function (source, cmd, arglist)
	skynet.logd("UserCmd cmd =>", cmd, table.unpack(arglist))
	local obj = ma_usercmd.runCmd(cmd, arglist)
	return obj
end

REQUEST_New.UserCmd = function (args)
    local obj = ma_usercmd.runCmd(args.cmd, args.paramArr)
    return obj.e_info, obj
end


REQUEST_New.UserInitSet = function (args)
    local _type, name = args.type, args.name

    if userInfo.initSet then
        return RET_VAL.ERROR_3
    end

    if _type ~= 1 and _type ~= 2 then
        return RET_VAL.ERROR_3
    end

    local ret = REQUEST_New.SetNickName({name = name}, true)
    if ret ~= RET_VAL.Succeed_1 then
        return ret
    end

    userInfo.initSet = true
    dbx.update(TableNameArr.User, userInfo.id, {initSet = userInfo.initSet})
    eventx.call(EventxEnum.WriteLog, UserLogKey.xuanrenchenggong)

    local cfgId = _type == 1 and 101002 or 101003
    local heroId = datax.globalCfg[cfgId][1].id

    local uHero = ma_userhero.add(heroId, "UserInitSet_创角选择")
    if not uHero then
        uHero = table.first(ma_userhero.getDatas(), function (index, value)
            return value.sId == heroId
        end)
    end
    if uHero then
        ma_userhero.use(uHero.id)

        local userRunes = ma_userrune.getDatas()
        local key, rune = next(userRunes)
        if rune then
            ma_userrune.equip(rune.id, uHero.id, 1)
        end
    end

    ma_obj.initDefault()
    return RET_VAL.Succeed_1, {initSet = userInfo.initSet, nickname = userInfo.nickname, data = ma_common.toUserBase(userInfo) }
end

REQUEST_New.SetNickName = function (args, isInit)
    local name = args.name

    if not name or string.getLength(name) > datax.globalCfg[101001].val then
        return RET_VAL.Fail_2
    end

    if not isInit then
        local is_senstivewords = skynet.call("sensitive_word", "lua", "IsSensitiveWords", name)
        if is_senstivewords then
            return RET_VAL.NoUse_8 --非法名称
        end

        if objx.toNumber(userInfo.nickNameSetNum) > 0 then
            local consumeItemArray = datax.globalCfg[101004]
            local consume_code = RET_VAL.Lack_6
            local consume_len = #consumeItemArray
            if consume_len <= 0 then
                return RET_VAL.Lack_6
            end

            for i = 1, consume_len, 1 do
                if consume_code == RET_VAL.Succeed_1 then
                    break
                end

                local consumeItem = consumeItemArray[i]
                if consumeItem then
                    if ma_useritem.removeList({consumeItem}, 1, "SetNickName_修改昵称") then
                        consume_code = RET_VAL.Succeed_1
                        break
                    end
                end
            end
            
            if consume_code ~= RET_VAL.Succeed_1 then
                return consume_code
            end
        end

        userInfo.nickNameSetNum = (userInfo.nickNameSetNum or 0) + 1
    end

    userInfo.nickname = name

    local updateData = {nickname = name, nickNameSetNum = userInfo.nickNameSetNum}
    dbx.update(TableNameArr.USER, userInfo.id, updateData)

    ma_common.updateUserBase(userInfo.id, {nickname = userInfo.nickname})

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.SetGender = function (args)
    local gender = args.gender

    if gender ~= GenderEnum.BOY and gender ~= GenderEnum.GIRL then
        return RET_VAL.ERROR_3
    end

    userInfo.gender = gender

    local updateData = {gender = gender}
    dbx.update(TableNameArr.USER, userInfo.id, updateData)

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.SetHead = function (args)
    local head = args.head
    if not head then
        return RET_VAL.ERROR_3
    end

    local sData = datax.player_avatar[tonumber(head)]
    if not sData then
        return RET_VAL.ERROR_3
    end

    userInfo.head = head
    userInfo.gender = sData.sex

    local updateData = {head = head, gender = userInfo.gender}
    dbx.update(TableNameArr.USER, userInfo.id, updateData)

    ma_common.updateUserBase(userInfo.id, updateData)

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.SetHeadFrame = function (args)
    local headFrameItemId = args.headFrameItemId
    local sData = datax.items[headFrameItemId]
    if not sData or sData.type ~= ItemType.HeadFrame then
        return RET_VAL.ERROR_3
    end

    if not ma_useritem.has({{id = headFrameItemId, num = 1}}, 1) then
        return RET_VAL.Lack_6
    end

    userInfo.headFrame = sData.param[1].id

    local updateData = {headFrame = userInfo.headFrame}
    dbx.update(TableNameArr.USER, userInfo.id, updateData)

    ma_common.updateUserBase(userInfo.id, updateData)

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.SetSignature = function (args)
    local signature = args.signature
    local num = 24

    if not signature or #signature > num then
        return RET_VAL.ERROR_3
    end

    userInfo.signature = signature

    local updateData = {signature = signature}
    dbx.update(TableNameArr.USER, userInfo.id, updateData)

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.SetChatFrame = function (args)
    local chatFrameItemId = args.chatFrameItemId
    local sData = datax.items[chatFrameItemId]
    if not sData or sData.type ~= ItemType.GameChatFram then
        return RET_VAL.ERROR_3
    end

    if not ma_useritem.has({{id = chatFrameItemId, num = 1}}, 1) then
        return RET_VAL.Lack_6
    end

    userInfo.chatFrame = sData.param[1].id

    local updateData = {chatFrame = userInfo.chatFrame}
    dbx.update(TableNameArr.USER, userInfo.id, updateData)

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.UserLike = function (args)
    local id = args.id

    local key = os.date("%Y%m%d")
    local datas = dbx.get(TableNameArr.UserLikeRecord, userInfo.id, { ["data." .. key] = true }) or {data = {}}
    datas = datas.data[key] or {}

    if datas[id] then
        return RET_VAL.Exists_4
    end

    local ok, like = skynet.call("user_service", "lua", "UserLike", id)
    if not ok then
        return RET_VAL.ERROR_3
    end

    datas[id] = true
    dbx.update_add(TableNameArr.UserLikeRecord, userInfo.id, {
        id = userInfo.id,
        ["data." .. key .. "." .. id] = true
    })

    -- 更新点赞排行榜
    skynet.call("ranklistmanager", "lua", "update_dz", 
        userInfo.id, userInfo.nickname, userInfo.head, userInfo.headFrame, like, 1)

    return RET_VAL.Succeed_1, {like = like}
end

REQUEST_New.GetUserGiftDatas = function (args)
    local id = args.id
    if id ~= userInfo.id then
        local obj = dbx.get(TableNameArr.User, { id = true })
        if not obj then
            return RET_VAL.NotExists_5
        end
    end
    local data = skynet.call("user_service", "lua", "GetUserGiftDatas", id)

    return {datas = data}
end

REQUEST_New.UserGiftSend = function (args)
    local uId, sId, num = args.uId, args.sId, args.num

    local currentNum = skynet.call("user_service", "lua", "UserGiftSend", uId, sId, num, nil)

    -- 更新人气排行榜
    skynet.call("ranklistmanager", "lua", "update_rq", 
        userInfo.id, userInfo.nickname, userInfo.head, userInfo.headFrame, currentNum, num)

    return RET_VAL.Succeed_1, {sId = sId, currentNum = currentNum}
end

REQUEST_New.SetGameChatFrame = function (args)
    local gameChatFrameId = args.gameChatFrameItemId
    local sData = datax.items[gameChatFrameId]
    if not sData or sData.type ~= ItemType.GameChatFram then
        return RET_VAL.ERROR_3
    end

    if not ma_useritem.has({{id = gameChatFrameId, num = 1}}, 1) then
        return RET_VAL.Lack_6
    end

    userInfo.gameChatFrame = sData.param[1].id

    local updateData = {gameChatFrame = userInfo.gameChatFrame}
    dbx.update(TableNameArr.USER, userInfo.id, updateData)

    ma_common.updateUserBase(userInfo.id, updateData)

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.SetInfoBg = function (args)
    local infoBgItemId = args.InfoBgItemId
    local sData = datax.items[infoBgItemId]
    if not sData or sData.type ~= ItemType.InfoBg then
        return RET_VAL.ERROR_3
    end

    if not ma_useritem.has({{id = infoBgItemId, num = 1}}, 1) then
        return RET_VAL.Lack_6
    end

    userInfo.infoBg = sData.param[1].id

    local updateData = {infoBg = userInfo.infoBg}
    dbx.update(TableNameArr.USER, userInfo.id, updateData)

    ma_common.updateUserBase(userInfo.id, updateData)

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.SetClockFrame = function (args)
    local clockFrameItemId = args.clockFrameItemId
    local sData = datax.items[clockFrameItemId]
    if not sData or sData.type ~= ItemType.ClockFram then
        return RET_VAL.ERROR_3
    end

    if not ma_useritem.has({{id = clockFrameItemId, num = 1}}, 1) then
        return RET_VAL.Lack_6
    end

    userInfo.clockFrame = sData.param[1].id

    local updateData = {clockFrame = userInfo.clockFrame}
    dbx.update(TableNameArr.USER, userInfo.id, updateData)

    ma_common.updateUserBase(userInfo.id, updateData)

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.SetCardBg = function (args)
    local cardBgId = args.cardBgItemId
    local sData = datax.items[cardBgId]
    if not sData or sData.type ~= ItemType.cardBg then
        return RET_VAL.ERROR_3
    end

    if not ma_useritem.has({{id = cardBgId, num = 1}}, 1) then
        return RET_VAL.Lack_6
    end

    userInfo.cardBg = sData.param[1].id

    local updateData = {cardBg = userInfo.cardBg}
    dbx.update(TableNameArr.USER, userInfo.id, updateData)

    ma_common.updateUserBase(userInfo.id, updateData)

    return RET_VAL.Succeed_1, updateData
end

REQUEST_New.SetSceneBg = function (args)
    local cardBgId = args.sceneBgItemId
    local sData = datax.items[cardBgId]
    if not sData or sData.type ~= ItemType.sceneBg then
        return RET_VAL.ERROR_3
    end

    if not ma_useritem.has({{id = cardBgId, num = 1}}, 1) then
        return RET_VAL.Lack_6
    end

    userInfo.sceneBg = sData.param[1].id

    local updateData = {sceneBg = userInfo.sceneBg}
    dbx.update(TableNameArr.USER, userInfo.id, updateData)

    ma_common.updateUserBase(userInfo.id, updateData)

    return RET_VAL.Succeed_1, updateData
end


REQUEST_New.SetTableClothBg = function (args)
    local cardBgId = args.tableClothBgItemId
    local sData = datax.items[cardBgId]
    if not sData or sData.type ~= ItemType.tableClothBg then
        return RET_VAL.ERROR_3
    end

    if not ma_useritem.has({{id = cardBgId, num = 1}}, 1) then
        return RET_VAL.Lack_6
    end

    userInfo.tableClothBg = sData.param[1].id

    local updateData = {tableClothBg = userInfo.tableClothBg}
    dbx.update(TableNameArr.USER, userInfo.id, updateData)

    ma_common.updateUserBase(userInfo.id, updateData)

    return RET_VAL.Succeed_1, updateData
end

-- REQUEST_New.SetHeadFrame = function (args)
--     local headFrameItemId = args.headFrameItemId
--     local sData = datax.item[headFrameItemId]
--     if not sData or sData.type ~= ItemType.HeadFrame then
--         return RET_VAL.ERROR_3
--     end

--     if not ma_useritem.has({{id = headFrameItemId, num = 1}}, 1) then
--         return RET_VAL.Lack_6
--     end

--     userInfo.headFrame = sData.param[1].id

--     local updateData = {headFrame = userInfo.headFrame}
--     dbx.update(TableNameArr.USER, userInfo.id, updateData)

--     ma_common.updateUserBase(userInfo.id, updateData)

--     return RET_VAL.Succeed_1, updateData
-- end

return ma_obj