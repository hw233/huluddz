local skynet = require "skynet"
local ec = require "eventcenter"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local timex  = require "timex"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name
local COLL_INDEXES = require "config.coll_indexes"

local ma_obj = {}

---comment
---@param key string
---@return table
ma_obj.GetServerSeting = function (key)
    return skynet.call("server_service", "lua", "GetServerSetingData", key)
end

---comment
---@param key string
---@param data table
ma_obj.SetServerSeting = function (key, data)
    skynet.call("server_service", "lua", "SetServerSetingData", key, data)
end

---comment
---@param id string
---@param name string
---@param ... any
ma_obj.send_useragent = function (id, name, ...)
    skynet.send("agent_mgr", "lua", "send2player", id, name, ...)
end

---comment
---@param id any
---@param name any
---@param ... any
---@return boolean ret 玩家代理存在则成功
ma_obj.call_useragent = function (id, name, ...)
    return skynet.call("agent_mgr", "lua", "send2player", id, name, ...)
end

---comment
---@param id string
---@param name string
---@param paramTable? table
ma_obj.send_client = function (id, name, paramTable)
    skynet.send("agent_mgr", "lua", "send2player", id, "send_push", name, paramTable)
end

ma_obj.toUserBase = function (obj)
    return {
        id = obj.id,
        nickname = obj.nickname,
        head = obj.head,
        headFrame = obj.headFrame,
        chatFrame = obj.chatFrame,
        gameChatFrame = obj.gameChatFrame,
        infoBg = obj.infoBg,
        clockFrame = obj.clockFrame,
        title = obj.title,
        cardBg = obj.cardBg,
        sceneBg = obj.sceneBg,
        tableClothBg = obj.tableClothBg,

        lv = obj.lv,
        vip = obj.vip,
        gourdLv = obj.gourdLv,
        skin = obj.skin,
        gender = obj.gender,
    }
end

ma_obj.getUserAgent = function (id)
    return skynet.call("agent_mgr", "lua", "GetPlayerAgent", id)
end

---comment
---@param id string
---@param otherFields table
---@return table
ma_obj.getUserBase = function (id, otherFields)
    local obj = ma_obj.getUserBaseArr({id}, otherFields)
    return obj[id]
end

---comment
---@param idArr table string[]
---@param otherFields table
---@return table {[id] = {}}
ma_obj.getUserBaseArr = function (idArr, otherFields)
    return skynet.call("user_service", "lua", "GetUserInfo", idArr, otherFields)
end

ma_obj.handleUserBaseArr = function (arr)
    if arr then
        local idArr = arrayx.select(arr, function (key, value)
            return value.id
        end)
        local userArr = ma_obj.getUserBaseArr(idArr)
        for i, uData in pairs(arr) do
            local dataBase = userArr[uData.id]
            uData.data = dataBase or uData.data
        end
    end
end

ma_obj.getRobotInfo = function (id)
    return skynet.call("ddz_robot_mgr", "lua", "GetRobotInfo", id)
end


--- 添加用户代办数据
---@param type string 代办数据类型
---@param id string 用户id
---@param data any 数据包
ma_obj.pushUserPendingData = function (type, id, data)
    dbx.add(TableNameArr.UserPendingData, {id = id, type = type, data = data, dt = os.time()})
    
    ma_obj.send_useragent(id, "PendingDataEvent", type)
end

--- 判断玩家道具数量是否满足参数要求道具数量
---@param addr any 指定玩家服务地址
---@param itemArr table
---@param num number 参数 itemArr 中数量的倍数，默认 1 倍
---@param notSend any
---@return boolean
ma_obj.hasItem = function (addr, itemArr, num, notSend)
    return skynet.call(addr, "lua", "UserItemHas", itemArr, num, notSend)
end

---comment
---@param addr any
---@param itemId number
---@param num number
---@param from string
---@return boolean ret, number nowNum
ma_obj.addItem = function (addr, itemId, num, from)
    return skynet.call(addr, "lua", "UserItemAdd", itemId, num, from)
end

---comment
---@param addr any
---@param itemArr table
---@param num integer
---@param from string
ma_obj.addItemList = function (addr, itemArr, num, from)
    return skynet.call(addr, "lua", "UserItemAddList", itemArr, num, from)
end

--- 消耗玩家指定道具
---@param addr any 指定玩家服务地址
---@param itemId number 道具id
---@param num number 数量
---@param from string 消耗源
---@param notSend boolean
---@param isSure boolean 保证删除
---@return boolean ret, number nowNum 消耗成功or失败
ma_obj.removeItem = function (addr, itemId, num, from, notSend, isSure)
    return skynet.call(addr, "lua", "UserItemRemove", itemId, num, from, notSend, isSure)
end

--- 消耗玩家道具
---@param addr any 指定玩家服务地址
---@param itemArr table Array { {id="", num=0}, {id="", num=0} }
---@param num number 数量
---@param from string 消耗源
---@param notSend boolean
---@param isSure boolean 保证删除
---@return boolean ret 消耗成功or失败
ma_obj.removeListItem = function (addr, itemArr, num, from, notSend, isSure)
    return skynet.call(addr, "lua", "UserItemRemoveList", itemArr, num, from, notSend, isSure)
end

--- 购买商品
---@param addr any 指定玩家服务地址
---@param id number 商品id
---@param num number 数量
---@param notShow boolean 不显示奖励
---@return boolean 成功 or 失败
---@return number 错误码
ma_obj.buyStore = function (addr, id, num, notShow)
    local retVal = skynet.call(addr, "lua", "UserStoreBuy", id, num, notShow)
    return retVal == RET_VAL.Succeed_1, retVal
end

---添加邮件，策划表中已配置的邮件
---@param toId string 目标玩家id
---@param mailId number 配置表id
---@param from any
---@param contentArr table 额外参数数组
---@param itemArr table 邮件道具
---@return boolean
ma_obj.addMail = function (toId, mailId, from, contentArr, itemArr)
    if itemArr and not objx.isTable(itemArr) then
        skynet.loge("addMail error!", toId,  mailId, from, table.tostr(contentArr))
        return nil
    end
    return skynet.call("mail_manager", "lua", "AddGameMail", toId, mailId, from, contentArr, itemArr)
end

---添加系统邮件，一般为后台编辑发送的邮件
---@param toId string
---@param title string
---@param from any
---@param contentStr string
---@param itemArr table
---@return boolean
ma_obj.addSystemMail = function (toId, title, from, contentStr, itemArr)
    if itemArr and not objx.isTable(itemArr) then
        skynet.loge("addMail error!", toId,  title, from, contentStr)
        return nil
    end
    return skynet.call("mail_manager", "lua", "AddSystemMail", toId, title, from, contentStr, itemArr)
end

ma_obj.sendClientMsg = function (id, msg)
    ma_obj.send_client(id, "ServerMsg", {msg = msg})
end

---写入操作记录
---@param tableName string 记录表明，传入 config/collections 中定义的值
---@param id string
---@param type string 记录类型
---@param from string 记录来源
---@param param1 any 未命名参数1
---@param param2 any
---@param param3 any
---@param param4 any
ma_obj.write_record = function (tableName, id, type, from, channel, param1, param2, param3, param4, ...)
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

    skynet.call("db_manager_rec", "lua", "write_record", tableName, selector, obj)
end

ma_obj.getUserRankNextDistance = function (uid, rank_name, isMonth, nickname, head, headframe)
    return skynet.call("ranklistmanager", "lua", "getUserRankNextDistance", uid, rank_name, isMonth, nickname, head, headframe)
end

ma_obj.get_user_rankinfo = function (uid, name, ismonth, nickname, head, headframe)
    return skynet.call("ranklistmanager", "lua", "get_user_rankinfo", uid, name, ismonth, nickname, head, headframe)
end

--- 添加跑马灯公告
---@param id number 配置id
---@param obj table 参数
ma_obj.addAnnounce = function (id, obj, uId)
    id = tonumber(id)
    local sData = datax.announce[id]
    if not sData or not obj then
        return false
    end

    if sData.isopen ~= 1 then
        return false
    end
    ec.pub({type = EventCenterEnum.NewUserAnnounce, sId = id, dt = os.time(), data = objx.toKeyValuePair(obj), uId = uId})

    return true
end

--- 添加跑马灯公告
ma_obj.addSysAnnounce = function (content, uId)
    ec.pub({type = EventCenterEnum.NewSysAnnounce, content = content, uId =  uId})
    return true
end

ma_obj.UpdateSessionDuanwei = function (dbx, user_base_data, upType, rank)
    if not user_base_data or not dbx  then
        return
    end

    local MinLv = DWLv_DouHuang_min
    local lv =  tostring(user_base_data.lv or 0)
    if string.find(upType, "dw_up") then
        if tonumber(user_base_data.lv) < MinLv then
            return
        end
    end

    local sessionDWDataDB = dbx.find_one(TableNameArr.UserSessionDataRecord, tostring(user_base_data.id), {data=true})
    local sessionDWData
    if  sessionDWDataDB and sessionDWDataDB.data then
        sessionDWData = sessionDWDataDB.data
    else 
        sessionDWData = {}
    end

    local upFlag = false
    local upDWAnncFlag = false
    local UpDWRankFlag = false
    local UpHUTRankFlag = false
    if "dw_up" == upType then
        local ok, seasonData = ma_obj.GetSeasonData()
        local seasonID = 0
        if ok then
            seasonID = seasonData.id
        end

        if sessionDWData.seasonId ~= seasonID then
            sessionDWData.seasonId = seasonID
            sessionDWData.s = {}
            upFlag = true
        end

        if not sessionDWData.s[lv] then
            sessionDWData.s[lv] = {}
            sessionDWData.s[lv].num = 1
            sessionDWData.s[lv].lastAt = os.time()
            upFlag = true
            upDWAnncFlag = true
        end
    elseif "dw_refresh" == upType then
        if not sessionDWData.s then
            sessionDWData.s = {}
            local ok, seasonData = ma_obj.GetSeasonData()
            local seasonID = 0
            if ok then
                seasonID = seasonData.id
            end
            sessionDWData.seasonId = seasonID
        end
        if not sessionDWData.s[lv] then
            sessionDWData.s[lv] = {}
            sessionDWData.s[lv].num = 1
            sessionDWData.s[lv].lastAt = os.time()
            upFlag = true
            upDWAnncFlag = true
        end

        if sessionDWData.s[lv].num == 1 then
            if tonumber(lv) >= DWLv_DouDi_min then
                local anncId =  AnnounceIdEm.GetDWAnnounceId(tonumber(lv), rank or 0)
                if anncId == AnnounceIdEm.DwShengjiTianxiadiyi then
                    sessionDWData.s[lv].num = sessionDWData.s[lv].num + 1
                    sessionDWData.s[lv].lastAt = os.time()
                    upFlag = true
                    upDWAnncFlag = true
                end
            end
        end
    elseif "rank_dw_refresh" == upType then
        local ok, seasonData = ma_obj.GetSeasonData()
        local seasonID = 0
        if ok then
            seasonID = seasonData.id
        end
        if not sessionDWData["rank_dw"] or sessionDWData["rank_dw"].seasonId ~= seasonID then
            sessionDWData["rank_dw"] = {}
            sessionDWData["rank_dw"].seasonId = seasonID
            sessionDWData["rank_dw"][tostring(rank)] = rank
            UpDWRankFlag = true
            upFlag = true
        end
    elseif "rank_hlt_refresh" == upType then
        if not sessionDWData["rank_hlt"] then
            sessionDWData["rank_hlt"] = {}
            sessionDWData["rank_hlt"][tostring(rank)] = rank
            UpHUTRankFlag = true
            upFlag = true
        end
    end

    if upDWAnncFlag then
        ma_obj.addAnnounce(AnnounceIdEm.GetDWAnnounceId(tonumber(lv), rank or 0), {name = user_base_data.nickname}, user_base_data.id)
    elseif UpDWRankFlag then
        ma_obj.addAnnounce(AnnounceIdEm.DWRank1, {name = user_base_data.nickname}, user_base_data.id)
    elseif UpHUTRankFlag then
        ma_obj.addAnnounce(AnnounceIdEm.HLRank1, {name = user_base_data.nickname}, user_base_data.id)
    end

    if upFlag then
        local updateData = {data=sessionDWData}
        dbx.update_add(TableNameArr.UserSessionDataRecord, tostring(user_base_data.id), updateData)
    end
end


ma_obj.GetSeasonData = function ()
    return pcall(skynet.call, "user_season", "lua", "GetSeasonData")
end

ma_obj.UserCDKReward = function (args)
    return skynet.call("cdk", "lua", "CDKReward", args)
end


return ma_obj