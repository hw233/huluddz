local skynet = require "skynet"
local server_conf = require "server_conf"
local Mongolib = require "Mongolib"
local mc = require "skynet.multicast"
local datacenter = require "skynet.datacenter"

require "table_util"
local cfg_conf = require "cfg_conf"
local check_interval = 60
local DB_CONF = server_conf.DB_CONF
local CMD = {}
local mongo
local conf_update_ch

local confs = {
    {
        name = cfg_conf.COLL.ACTIVITY_CONF,
        fields = {_id = false, id = true, type = true, subtype = true, begintime = true, endtime = true, name = true, level = true, enable = true, location=true},
        conf = {}
    }
}

local function conf_tbl_convert(tbl)
    local res = {}
    for _, t in pairs(tbl) do
        local id = t.id
        if id then
            res[id] = t
        end
    end
    return res
end

local function init_confs()
    for _, conf in ipairs(confs) do
        local tbl = CMD.find_all(conf.name, {}, conf.fields)
        conf.conf = conf_tbl_convert(tbl)
    end
end

--初始化广播
local function init_multicast()
    do
        --生成配置变化广播
        conf_update_ch = mc.new()
        datacenter.set("channels", "conf_update", conf_update_ch.channel)
    end
end

local function init()
    mongo = Mongolib.new()
    mongo:connect(DB_CONF)
    mongo:use(DB_CONF.name)
    init_confs()
    init_multicast()
end

function CMD.find_one(...)
    return mongo:find_one(...)
end

function CMD.find_all(...)
    return mongo:find_all(...)
end

function CMD.get_conf(name)
    for _, conf in ipairs(confs) do 
        if conf.name == name then 
            return conf.conf
        end 
    end
end

--配置变化广播
function CMD.conf_update(...)
    local name, diff, before, after = ...
    print("conf_update=", name, "; diff=>", table.tostr(diff))
    print("before =>", table.tostr(before), "; after=>", table.tostr(after))
    conf_update_ch:publish(...)
end


local function check_conf_update()
    --print("on time check_conf_update")
    for _, conf in ipairs(confs) do
        local tbl = CMD.find_all(conf.name, {}, conf.fields)
        tbl = conf_tbl_convert(tbl)
        local diff, before, after = table.cmp(conf.conf, tbl)
        if table.nums(diff) > 0 then
            CMD.conf_update(conf.name, diff, before, after)
        end
        conf.conf = tbl
    end
end

local function time_tick()
    check_conf_update()
    skynet.timeout(check_interval * 100, time_tick)
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
    init()

    skynet.timeout(check_interval * 100, time_tick)
end)