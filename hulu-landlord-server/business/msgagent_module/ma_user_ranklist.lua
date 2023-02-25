local skynet = require "skynet"
local ma_data = require "ma_data"
local common = require "common_mothed"

local CMD, REQUEST_New = {}, {}

local M = {}

local myuid = nil
local userInfo = ma_data.userInfo

--------------------------------
function M.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)


    myuid    = userInfo.id
    skynet.call("ranklistmanager", "lua", "join_ranklist", myuid, userInfo.nickname, userInfo.head, tostring(userInfo.headframe))
end

function M:getUserRankNextDistance(rank_name, type)
    return common.getUserRankNextDistance(myuid, rank_name, type == RankType.Month, userInfo.nickname, userInfo.head, userInfo.headframe)
end

function M:get_user_rankinfo(rank_name, type)
    return common.get_user_rankinfo(myuid, rank_name, type == RankType.Month, userInfo.nickname, userInfo.head, userInfo.headframe)
end


---------------------------------
REQUEST_New.Test_RankList_UpdateRQ = function()
    -- skynet.call("ranklistmanager", "lua", "update_rq", myuid, "nickname", "head", "headframe", 100, 20)

    return RET_VAL.Succeed_1
end


REQUEST_New.GetRankList = function(args)
    local name = args.name
    local type = args.type
    local startidx = args.startidx
    local num = args.num

    if not name or (name~=RankName.RQ and 
                    name~=RankName.DZ and 
                    name~=RankName.DW and 
                    name~=RankName.CJ and 
                    name~=RankName.HLT) then
        return RET_VAL.ERROR_3
    end

    if not type or type <1 or type>3 then
        return RET_VAL.ERROR_3
    end

    if not startidx or startidx<1 or startidx>200 then 
        return RET_VAL.ERROR_3
    end

    if not num or num<1 or num>100 then
        return RET_VAL.ERROR_3
    end

    local ranklist = nil
    local maxnum = 0
    local myrankinfo = nil
    if type == RankType.Normal or type == RankType.Month then
        if name == "dw" then
            type = RankType.Month
        end
        ranklist, maxnum = skynet.call("ranklistmanager", "lua", "get_ranklist", name, startidx, num, type == RankType.Month)
        myrankinfo = skynet.call("ranklistmanager", "lua", "get_user_rankinfo", myuid, name, type == RankType.Month, userInfo.nickname,userInfo.head, userInfo.headFrame)
    elseif type == RankType.Friend then
        ranklist, maxnum = skynet.call("ranklistmanager", "lua", "get_friend_ranklist", myuid, name, userInfo.nickname, userInfo.head, userInfo.headFrame)
        for i, rk in pairs(ranklist) do
            if rk.uid == myuid then
                myrankinfo = rk
                break;
            end
        end
    end

    local ret = {
        name          = name,
        type          = args.type,
        startidx      = startidx,
        ranklist      = ranklist,
        myrankinfo    = myrankinfo,
        rklist_maxnum = maxnum,
    }

    -- --更新天下第一
    -- if ret.ranklist then
    --     for key, _rank in pairs(ret.ranklist) do
    --         if _rank and _rank.lv and _rank.lv == 38 and _rank.rank <= 100 then
    --             _rank.lv = 39
    --         end
    --     end
    -- end

    -- if ret.myrankinfo and ret.myrankinfo.lv == 38 and ret.myrankinfo.rank <= 100 then
    --     ret.myrankinfo.lv = 39
    -- end
    if name == "dw" then
        ret.myrankinfo.lv = userInfo.lv
        ret.myrankinfo.val = userInfo.exp
    end

    return RET_VAL.Succeed_1, ret
end

----------------------------------
return M