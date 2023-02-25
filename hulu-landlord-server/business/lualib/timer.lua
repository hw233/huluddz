local skynet = require "skynet"

local timer = {}
local lock

local M = {}

function M.set_lock(_lock)
 lock = _lock
end


function M.create(delay, func, iteration, on_end)

 iteration = iteration or 1
 local count = 1
 local cb, cancel_handle
 local canceled = false

    function cb()
        if func then
            func(count)
            count = count + 1
            if iteration > 0 then
                iteration = iteration - 1
            end
            if iteration ~= 0 then
                skynet.timeout(delay, function ()
                    if lock then
                        lock(cb)
                    else
                        cb()
                    end
                end)
            else
                timer[cancel_handle] = nil
                if on_end then on_end() end
            end
        end
    end

    function cancel_handle(execute)
        if execute then
            for i=count,iteration do
                func()
            end
        end 
        canceled = true
        func = nil
        timer[cancel_handle] = nil
    end

    timer[cancel_handle] = true

    skynet.timeout(delay, function ()
        if lock then
            lock(cb)
        else
            cb()
        end
    end)

    return cancel_handle
end


function M.cancel_all()
 for cancel,_ in pairs(timer) do
  cancel()
 end

 timer = {}
end


return M