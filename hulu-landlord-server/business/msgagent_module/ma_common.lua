local skynet = require "skynet"
local ec = require "eventcenter"
local common = require "common_mothed"

local ma_data = require "ma_data"

local datax  = require "datax"
local objx = require "objx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name
local COLL_INDEXES = require "config.coll_indexes"


local ma_obj = {}

ma_obj.send_client = common.send_client

---comment
---@param name string
---@param paramTable? table
ma_obj.send_myclient = function (name, paramTable)
    -- 为兼容旧代码，所以真正的定义在 magagent.lua 中
    ma_data.send_push(name, paramTable)
end

--- 发送到客户端，保证不因为未完成登录或其他原因而未发送到客户端
---@param name string
---@param param? table
ma_obj.send_myclient_sure = function (name, param)
    if ma_data.isLoginEnd then
        ma_data.send_push(name, param)
    else
        table.insert(ma_data.msgQueueToClient, {name = name, param = param})
    end
end

ma_obj.sendRoomPlayer = function (mothedName, args)
    local userInfo = ma_data.userInfo
    if userInfo.roomAddr then
        local ok, result = pcall(skynet.send, userInfo.roomAddr, "lua", "PlayerRequest", userInfo.id, mothedName, args)
        if not ok then
            skynet.loge("sendRoomPlayer error!", mothedName, result)
        end
    end
end

---comment
---@param data table
ma_obj.showReward = function (data)
    -- local obj = {
    --     [0] = {
    --         fromType = 0,
    --         arr = {{id=1001,num=100}},
    --     },
    -- }
    local key, val = next(data)
    if val then
        if val.fromType then
            ma_obj.send_myclient("ShowReward", {data = data})
        else
            ma_obj.send_myclient("ShowReward", {data = {{fromType = ShowRewardFrom.Default, arr = data}}})
        end
    end
end

--- 获取指定来源数据存放的数组，如果没有就创建一个
---@param sourceArr table
---@param fromType number ShowRewardFrom 枚举
---@return table Array
ma_obj.getShowRewardArr = function (sourceArr, fromType)
    local data = sourceArr[fromType]
    if not data then
        data = {fromType = fromType, arr = {}}
        sourceArr[fromType] = data
    end
    return data.arr
end

ma_obj.toUserBase = common.toUserBase

ma_obj.updateUserBase = function (id, obj)
    if id and obj and next(obj) then
        skynet.send("user_service", "lua", "UpdateUserInfo", id, obj)
    end
end

ma_obj.getUserBase = common.getUserBase

ma_obj.getUserBaseArr = common.getUserBaseArr


ma_obj.getActData = function ()
    return skynet.call("activity_mgr", "lua", "GetActData")
end

ma_obj.getVipCfg = function ()
    return datax.vipGroup[ma_data.userInfo.vip]
end

ma_obj.addMail = common.addMail

ma_obj.addSystemMail = common.addSystemMail

--- 添加跑马灯公告
---@param id number 配置id
---@param obj table 参数
ma_obj.addAnnounce = function (id, obj)
    id = tonumber(id)
    local sData = datax.announce[id]
    if not sData or not obj then
        return false
    end

    local userInfo = ma_data.userInfo
    if sData.isopen ~= 1 or sData.level > userInfo.lv then
        return false
    end

    ec.pub({type = EventCenterEnum.NewUserAnnounce, sId = id, dt = os.time(), data = objx.toKeyValuePair(obj), uId = ma_data.userInfo.id})

    return true
end


--- 添加跑马灯公告
ma_obj.addSysAnnounce = function (content)
    ec.pub({type = EventCenterEnum.NewSysAnnounce, content = content, uId = ma_data.userInfo.id})
    return true
end

--- 添加跑马灯公告
ma_obj.addSysAnnounceTxt = function (content)
    ec.pub({type = EventCenterEnum.NewSysAnnounceTxt, content = content, uId = ma_data.userInfo.id})
    return true
end
--- 添加跑马灯公告
ma_obj.addSysAnnounceImg = function (content)
    ec.pub({type = EventCenterEnum.NewSysAnnounceImg, content = content, uId = ma_data.userInfo.id})
    return true
end


--- 向收集器中推送记录
---@param mothedName string 方法名
ma_obj.pushCollecter = function (mothedName, ...)
    local userInfo = ma_data.userInfo
    skynet.send("cd_collecter", "lua", ma_data.userInfo.channel, mothedName, {
        id = userInfo.id,
        os = userInfo.os,
    }, ...)
end

---写入用户相关的操作记录，自动传入用户ID
---@param tableName string 记录表明，传入 config/collections 中定义的值
---@param type string 记录类型
---@param from string 记录来源
---@param param1 any 未命名参数1
---@param param2 any
---@param param3 any
---@param param4 any
ma_obj.write_record = function (tableName, type, from, param1, param2, param3, param4, ...)
    common.write_record(tableName, ma_data.my_id, type, from, ma_data.userInfo.channel, param1, param2, param3, param4, ...)
end

return ma_obj