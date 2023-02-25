local skynet = require "skynet"

local ma_data      = require "ma_data"

local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local common = require "common_mothed"
local eventx = require "eventx"
require "define"
require "table_util"

local ma_common = require "ma_common"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name


local CMD, REQUEST_New = {}, {}
local M = {}

----------------------------------------------
function M.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

end

-------------------------------------------------
REQUEST_New.GetOtherUserInfo = function (args)
    local uid = args.uid
    if not uid then
        return RET_VAL.ERROR_3
    end

    -- local fields = {
    --     id        = true,
    --     gold      = true,
    --     lv        = true,
    --     lvMax     = true,
    --     nickname  = true,
    --     signature = true,
    --     gender    = true,
    --     gameCountSum   = true,
    --     winCountSum    = true,
    --     winCountSum_20 = true,
    -- }

    local user = dbx.get(TableNameArr.User, uid) or common.getRobotInfo(uid)
    if not user then
        return RET_VAL.Empty_7
    end

    eventx.call(EventxEnum.VisitorPlayer, {uid = uid, targetInfo=ma_common.toUserBase(ma_data.userInfo)})

    return RET_VAL.Succeed_1, {
        uinfo = user,
        heroDatas = user.heroDatas,
        runeDatas = user.runeDatas,
    }
end


-------------------------------------------------
return M
