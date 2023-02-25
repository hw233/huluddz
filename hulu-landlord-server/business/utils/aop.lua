local skynet = require "skynet"
require "pub_util"
local M = {}
local function make(interceptor, interceptor_ret, before_action, after_action)
    local t = {}
    local mt = {}
    mt.__newindex = function(tbl, k, v)
        local v_ = v
        if type(v) == "function" then
            v_ = function(...)
                local exec_body = v
                local t1 = skynet.now()
                if interceptor and interceptor(...) then
                    exec_body = interceptor_ret
                end
                if before_action then
                    before_action(...)
                end
                local ret = table.pack(exec_body(...))
                if after_action then
                    after_action(ret, ...)
                end
                local t2 = skynet.now()
                print("interface =>[", k, "] use time =>", t2 - t1)
                return table.unpack(ret)
            end
        end
        rawset(tbl, k, v_)
    end
    setmetatable(t, mt)
    return t
end

local helper = {}
helper.eStatus = {
    OK          = 0,
    NOT_ENABLE  = 1,
    NOT_BEGIN   = 2,
    ALREADY_END = 3,
}

function helper:aop_interceptor(state)
    return function()
        return not (state.status == state.eStatus.OK)
    end
end

function helper:aop_interceptor_ret(state)
    return function()
        local ret = {result = 0}
        ret.module = state.name
        if state.status == self.eStatus.NOT_ENABLE then
            ret.result = -1001
        elseif state.status == self.eStatus.NOT_BEGIN then
            ret.result = -1002
        elseif state.status == self.eStatus.ALREADY_END then
            ret.result = -1003
        end
        table.print("aop_interceptor_ret ret =>", ret)
        return ret
    end
end

function helper:aop_state_init(state)
    return function(conf)
        if conf then
            if conf.enable == 0 then
                state.status = self.eStatus.NOT_ENABLE
            else
                local now = os.time()
                if conf.begintime > 0 and now < conf.begintime then
                    state.status = self.eStatus.NOT_BEGIN
                elseif conf.endtime > 0 and now > conf.endtime then
                    state.status = self.eStatus.ALREADY_END
                else
                    state.status = self.eStatus.OK
                end
            end
        else
            state.status = self.eStatus.NOT_ENABLE
        end
        print("aop module =>", state.name, (state.status == state.eStatus.OK) and "enabled" or "disabled")
    end
end

function helper:make_state(name)
    local state   = {}
    state.name    = name
    state.eStatus = self.eStatus
    state.status  = self.eStatus.NOT_ENABLE
    state.init = self:aop_state_init(state)
    return state
end

function helper:make_interface_tbl(state)
    local interceptor = self:aop_interceptor(state)
    local interceptor_ret = self:aop_interceptor_ret(state)
    local interfaces = make(interceptor, interceptor_ret)
    return interfaces
end

M.helper = helper
return M