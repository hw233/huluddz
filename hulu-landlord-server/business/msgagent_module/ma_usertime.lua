local skynet = require "skynet"

local ma_data = require "ma_data"
local ma_userother = require "ma_userother"

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

local REQUEST, REQUEST_New = {}, {}
-- 后续写服务间调用接口时命名方式以 CMD_ 开头， 如 CMD_Open
local CMD = {}

local userInfo = ma_data.userInfo

local ma_obj = {
    lastTime = nil,

    startDt = os.time({year = 1970, month = 1, day = 1, hour = 0, min = 0, sec = 0}),
    weekStartDt = os.time({year = 1970, month = 1, day = 5, hour = 0, min = 0, sec = 0}), -- 第一个周一
}

function ma_obj.init(request, cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

end


--#region 核心部分

--ma_userother

--- 检查相对于用户的时间以触发对应事件
ma_obj.check = function ()
    local ok, err = pcall(function ()
        local now = os.time()
        if ma_obj.lastTime == now then
            return
        end
        ma_obj.lastTime = now

        local dateObj = os.date("*t", now)

        if dateObj.year ~= ma_userother.get(ma_userother.keyEnum.newYear) or dateObj.month ~= ma_userother.get(ma_userother.keyEnum.newMonth) then
            ma_userother.set(ma_userother.keyEnum.newYear, dateObj.year)
            ma_userother.set(ma_userother.keyEnum.newMonth, dateObj.month)

            -- 新的月
            eventx.call(EventxEnum.UserNewMonth, userInfo)
        end

        local daySum = math.floor((now - ma_obj.weekStartDt) / (24 * 60 * 60)) + 1
        local weekTimes = math.ceil(daySum / 7)
        if weekTimes ~= ma_userother.get(ma_userother.keyEnum.newWeek) then
            ma_userother.set(ma_userother.keyEnum.newWeek, weekTimes)
            
            -- 新的周
            eventx.call(EventxEnum.UserNewWeek, userInfo)
        end

        if dateObj.yday ~= ma_userother.get(ma_userother.keyEnum.newDay) then
            ma_userother.set(ma_userother.keyEnum.newDay, dateObj.yday)
            
            -- 新的天
            eventx.call(EventxEnum.UserNewDay, userInfo)
        end

        if dateObj.min ~= ma_userother.get(ma_userother.keyEnum.newMinutes) then
            ma_userother.set(ma_userother.keyEnum.newMinutes, dateObj.min)
            
            -- 新的分
            eventx.call(EventxEnum.UserNewMinutes, userInfo)
        end
    end)

    if not ok then
        skynet.logd("check error!", err)
    end
end

--#endregion



return ma_obj