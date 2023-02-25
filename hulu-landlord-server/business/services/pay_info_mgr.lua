--
-- channel data collecter
--

local skynet = require "skynet"
local timer = require "timer"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
local schedule = require "schedule"
local timer = require "timer"


local NODE_NAME = skynet.getenv "node_name"
local COLL = require "config/collections"

ServerData.delay_update = true

ServerData.channel = {}
ServerData.need_update = {}


function CMD.inject(filePath)
    require(filePath)
end

function CMD.today_0_time()
    local t = os.date("*t")
    return os.time {year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0}    
end

--
function CMD.charge(c, mall_id, amount)
    local key = tostring(mall_id)
    c[key] = (c[key] or 0) + amount
    --table.print(c)
end

function CMD.flush()
    local need_update = ServerData.need_update
    ServerData.need_update = {}

    for c,_ in pairs(need_update) do
        skynet.call(get_db_mgr(), "lua", "update", COLL.CHARGE_OVERVIEW, {day = c.day, channel = c.channel, node_name = NODE_NAME}, table.filter(c, {_id = false}))
    end
end

function CMD.listener_in(cmd, channel, ...)
    if not channel or channel == "" then
        return
    end

    local today = CMD.today_0_time()

    local c = ServerData.channel[channel]
    if not c or c.day ~= today then
        c = {
            day = today,                -- 日期
            channel = channel,          -- 渠道名
            node_name = NODE_NAME,
        }
        c._id = skynet.send(get_db_mgr(), "lua", "insert", COLL.CHARGE_OVERVIEW, c)
        ServerData.channel[channel] = c
    end

    local f = assert(CMD[cmd], cmd)
    local r = f(c, ...)
    ServerData.need_update[c] = true
    return r
end

--goods_id way
function CMD.listener(cmd, channel, ...)
    CMD.listener_in(cmd,channel,...)
    local r =  CMD.listener_in(cmd,"total",...)
    --TODO
    -- ServerData.need_update[c] = true
    -- local c = ServerData.channel[channel]
    -- ServerData.need_update[c] = true
    --TODO
    if not ServerData.delay_update then
        CMD.flush()
    end
    return r
end

function CMD.start_flush_timer()
    if ServerData.delay_update then
        skynet.timeout(200,CMD.start_flush_timer)
    end
    CMD.flush()
    CMD.refresh_operation_info()
end

function CMD.server_will_shutdown()
    ServerData.delay_update = false
end

------------------------------------------------------
--运营埋点事件
ServerData.operationData = nil
local need_count = {
    logining = true,
    CheckSexsus = true,
    Dating = true,
    OpenActivity = true,
    gohfqt = true,
    TaskHfqt = true,
    SelectGift = true,
    Growth = true,
    ContinuRecharge = true,
    AddUpCharge = true,
    DayCharge = true,
    PlayDice = true,
    PayCancel = true,
    GetXiXiGift = true,
    DaySignGet = true,
    SevenDaySignGet = true,
    TimeOnline = true,
    Share = true,
    matchBox = true,
    DoubleLuckyStar = true,
    NewPlayerGuid1 = true,
    NewPlayerGuid2 = true,
    NewPlayerGuid3 = true,
    NewPlayerGuid4 = true,
}

--其它临时活动需求
local other_need = {
    DoubleCharge = true,
    LuckyStarCount = true
}

--添加活动的下属分支evenName事件名称SecnName二级名称
function CMD.add_active_branch(x,evenName,SecnName,num)
    print('==================双旦活动奖励次数领取11==================',evenName,SecnName,type(SecnName))
    if not other_need[evenName] and not need_count[evenName] then
        return
    end
    --print('==================双旦活动奖励次数领取22==================',evenName,SecnName,num)
    tempName = evenName..'value'
    if not ServerData.operationData[tempName] then
        ServerData.operationData[tempName] = {}
    end
    SecnName = tostring(SecnName)
    ServerData.operationData[tempName][SecnName] = (ServerData.operationData[tempName][SecnName] or 0) + 1
    --table.print(ServerData.operationData)
end

function CMD.update_operation_info(x,evenName,num)
    -- bodyOPERATION_REC
    table.print(evenName)
    print('===============统计埋点数据=============',evenName,num)
    if not need_count[evenName] then
        return
    end
    ServerData.operationData.info[evenName] = (ServerData.operationData.info[evenName] or 0) + 1
    table.print(ServerData.operationData)
end

--初始化埋点事件
function CMD.init_operation_info()
    local today = CMD.today_0_time()
    ServerData.operationData = skynet.call(get_db_mgr(),'lua','find_one',COLL.OPERATION_REC,{day = today, mode_name = 'operation'})
    --print('=======初始化埋点事件=======',ServerData.operationData)
    if not ServerData.operationData then
        ServerData.operationData = {}
        ServerData.operationData.day = today
        ServerData.operationData.mode_name = 'operation'
        ServerData.operationData.info = {}
        skynet.call(get_db_mgr(),'lua','insert',COLL.OPERATION_REC,ServerData.operationData)
    end
end

--刷新
function CMD.refresh_operation_info()
    local today = CMD.today_0_time()
    if ServerData.operationData.day ~= today then
        table.print(ServerData.operationData)
        skynet.call(get_db_mgr(),'lua','update',COLL.OPERATION_REC,{day = ServerData.operationData.day, mode_name = 'operation'},ServerData.operationData)
        CMD.init_operation_info()
    end
end

function CMD.get_operation_info()
    print('===============请求埋点数据===============')
    table.print(ServerData.operationData)
    return ServerData.operationData
end
------------------------------------------------------
function CMD.init()
    -- load today channel data
    local today = CMD.today_0_time()
    local datas = skynet.call(get_db_mgr(), "lua", "find_all", COLL.CHARGE_OVERVIEW, {day = today, node_name = NODE_NAME})
    ServerData.channel = {}

    for _,c in ipairs(datas) do
        ServerData.channel[c.channel] = c
    end
end

skynet.start(function ()
    skynet.dispatch("lua", function(session, source, cmd, channel, ...)
        if cmd == 'inject' then
            local f = assert(CMD[command], command)
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.ret(skynet.pack(CMD.listener(cmd, channel, ...)))
        end
    end)
    CMD.init()
    CMD.init_operation_info()
    CMD.start_flush_timer()
end)