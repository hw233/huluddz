local function getuv(f)
    local i = 1
    local ups = {}
    while true do
        local name, value = debug.getupvalue(f, i)
        if not name then
            break
        end
        ups[name] = { i, value }
        i = i + 1
    end
    return ups
end

local skynet = require "skynet"
local datax = require "datax"
local create_dbx = require "dbx"
local dbx  = create_dbx(get_db_manager)
local COLL = require "config/collections"

require "pub_util"
require "define"
local common = require "common_mothed"
local xy_cmd = require "xy_cmd"
local CMD = xy_cmd.xy_cmd


print("start")

print("qwe", table.tostr(_P.lua.handler))
-- { command = <function 1>, connect = <function 2>, disconnect = <function 3>, error = <function 3>, message = <function 4>, open = <function 5>} 

local qweObj = getuv(CMD.update_dz)
print("qwe", table.tostr(qweObj.get_user_rkinfo_m))

local qweObj1 = getuv(qweObj.get_user_rkinfo_m[2])

local user_rkinfo_m = qweObj1.user_rkinfo_m[2]
--print("qwe", table.tostr(user_rkinfo_m))

for key, value in pairs(user_rkinfo_m) do
    user_rkinfo_m[key] = nil
end

--skynet.loge("qwe", table.tostr(do_requestUvObjOld))

print("end")

-- inject :00000023 inject/ranklist_manager_inject.lua