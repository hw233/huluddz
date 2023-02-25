local skynet = require "skynet"
local ma_data = require "ma_data"
local timer = require "timer"
local eventx = require "eventx"
local cmd =  {}
local request = {}

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo
local ma_obj = {
    AnList = {}
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)
    ma_obj.id = userInfo.id

    ma_obj:ScrollOnTimer()
    -- ma_obj:TextOnTimer()
    -- ma_obj:ImgOnTimer()
end

function ma_obj:ScrollOnTimer()
    -- timer.create(5*100, function()
    -- end, -1)
    local list = skynet.call("server_announce", "lua", "Get", AnnounceType.Scroll)
    if not list then
        return
    end
    local currentAt = os.time()
    for _, _annceData in pairs(list) do
        if _annceData.startDt < currentAt and _annceData.endDt > currentAt then
            local lastAt = ma_obj.AnList[tostring(_annceData.id)] or 0
            if lastAt + _annceData.intervalMinute < currentAt then
                ma_obj.AnList[tostring(_annceData.id)] = os.time()
                eventx.call(EventxEnum.SysAnnounce, _annceData)
            end
        end
    end

    skynet.timeout(5*100, ma_obj.ScrollOnTimer)
end


function ma_obj:TextOnTimer()
    timer.create(5*100, function()
        local list = skynet.call("server_announce", "lua", "Get", AnnounceType.Text)
        if not list then
            return
        end
        local currentAt = os.time()
        for _, _annceData in pairs(list) do
            if _annceData.startDt < currentAt and _annceData.endDt > currentAt then
                local lastAt =  ma_obj.AnList[tostring(_annceData.id)] or 0
                if lastAt + _annceData.intervalMinute < currentAt then
                    ma_obj.AnList[tostring(_annceData.id)] = os.time()
                    ---add code 
                    eventx.call(EventxEnum.SysAnnounceTxt, _annceData)
                end
            end
        end
    end, -1)
end

function ma_obj:ImgOnTimer()
    timer.create(5*100, function()
        local list = skynet.call("server_announce", "lua", "Get", AnnounceType.Img)
        if not list then
            return
        end
        local currentAt = os.time()
        for _, _annceData in pairs(list) do
            if _annceData.startDt < currentAt and _annceData.endDt > currentAt then
                local lastAt =  ma_obj.AnList[tostring(_annceData.id)] or 0
                if lastAt + _annceData.intervalMinute < currentAt then
                    ma_obj.AnList[tostring(_annceData.id)] = os.time()
                    eventx.call(EventxEnum.SysAnnounceImg, _annceData)
                end
            end
        end
    end, -1)
end


-- args = { AWorldAnnounce
--     id = "",
--     type = 0,            -- 公告类型
--     content = "",        -- 内容
--     imgUrl = "",         -- 图片地址
--     startDt = 0,         -- 开始时间
--     endDt = 1,           -- 结束时间
--     sortVal = 1,         -- 排序字段
--     intervalMinute = 1,  -- 间隔
-- }

return ma_obj