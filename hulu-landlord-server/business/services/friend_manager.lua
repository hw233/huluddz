local skynet = require "skynet"
local timer = require "timer"

--local objx = require "objx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
--local ma_common = require "ma_common"

require "define"
require "pub_util"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
local cfg_friend_vaule = require "cfg.cfg_friend_vaule"
cfg_friend_vaule = table.toObject(cfg_friend_vaule, function (key, value)
    return value.level
end)
local friendLvMax = table.maxNum(cfg_friend_vaule, function (key, value)
    return value.level
end)
--#endregion

local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data


local addExp = function (target, num)
    target.friendVal = target.friendVal + num

    for i = target.friendLv, friendLvMax - 1 do
        local sData = cfg_friend_vaule[i]
        if target.friendVal >= sData.exp then
            target.friendLv = sData.level + 1
        else
            break;
        end
    end

    dbx.update(TableNameArr.UserFriend, {uId = target.uId, id = target.id}, {friendVal = target.friendVal, friendLv = target.friendLv})
end

CMD.FriendExpAdd = function (uId, friendId, num)
    local uData = dbx.get(TableNameArr.UserFriend, {id = uId, uId = friendId})
    if not uData then
        return
    end

    addExp(uData, num)

    local friendData = dbx.get(TableNameArr.UserFriend, {id = friendId, uId = uId})
    if not friendData then
        return
    end

    addExp(friendData, num)

    return uData
end




function CMD.inject(filePath)
    require(filePath)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)