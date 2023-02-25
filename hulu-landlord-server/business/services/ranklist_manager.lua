-- huluddz 排行榜管理器
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


local setting = nil      -- 相关设置

local rank_list = {rq={},dz={},dw={},cj={},hlt={}}     -- 总榜 200条
local rank_list_m = {rq={},dz={},dw={},cj={},hlt={}}   -- 月榜 200条
-- key:userid, val:{rank排名, data该玩家排行榜数据}
local rklist_uid = {rq={},dz={},dw={},cj={},hlt={}}        -- 总榜
local rklist_uid_m = {rq={},dz={},dw={},cj={},hlt={}}      -- 月榜

local user_rkinfo = {}       -- 玩家总榜数据
local user_rkinfo_m = {}     -- 玩家月榜数据

local refresh_interval   = 60  --排行榜刷新周期 秒
local refresh_left_time = refresh_interval

local refresh_base_data_interval   = 60*60*1  --刷新排行榜玩家基数信息
local refresh_base_data_left_time   = refresh_base_data_interval  --刷新排行榜玩家基数信息
local duanwei_init_level = 1
local max_rank = 200

-- 人气、点赞、段位、成就、葫芦藤
-- 所有人/好友
-- 总榜/月榜/赛季榜
-- 好友榜用的是总榜数据, 所以好友都上榜

---------------------------------------


local function get_user_rkinfo(uid, nickname, head, headframe)
    local user_info = user_rkinfo[uid]
    if not user_info then
        local rk = dbx.get(COLL.UserRankList, {uid = uid},{_id=false})
        if not rk then
            local now = os.time()
            rk = {
                uid=uid,nickname=nickname,head=head,headframe=tostring(headframe),t=now,
                rq=0, rq_t=now,
                dz=0, dz_t=now,
                dw=0, lv=duanwei_init_level, dw_t=now,
                cj=0, cj_t=now, title=0,
                hlt=0, hlt_t=now,
            }

            local user = dbx.get(COLL.USER, {id=uid}, {giftCount=true, like=true, exp=true, lv=true,gourdExp=true})
            if user then
                rk.rq = user.giftCount or 0
                rk.dz = user.like or 0
                rk.dw = user.exp or 0
                rk.lv = user.lv or duanwei_init_level
                rk.cj = 0     -- 暂无字段s
                rk.hlt = user.gourdExp or 0
                rk.title = user.title or 0
            end

            dbx.add(COLL.UserRankList,rk)
        end
        user_rkinfo[uid] = rk
    else 
        if user_info.nickname ~= nickname then
            user_info.nickname = nickname
        end
        if user_info.head ~= head then
            user_info.head = head
        end
        if user_info.headframe ~= headframe then
            user_info.headframe = headframe
        end
    end

    return user_rkinfo[uid]
end

local function get_user_rkinfo_m(uid, nickname, head, headframe)
    head = tostring(head)
    headframe = tostring(headframe)

    local user_info = user_rkinfo_m[uid]
    if not user_info then
        local rk = dbx.get(COLL.UserRankListM, {uid = uid},{_id=false})
        if not rk then
            local now = os.time()
            rk = {
                uid=uid,nickname=nickname,head=head,headframe=tostring(headframe),t=now,
                rq=0, rq_t=now,
                dz=0, dz_t=now,
                dw=0, lv=duanwei_init_level, dw_t=now,
                cj=0, cj_t=now, title=0,
                hlt=0, hlt_t=now,
            }
            dbx.add(COLL.UserRankListM,rk)
        end
        user_rkinfo_m[uid] = rk
    else 
        if user_info.nickname ~= nickname then
            user_info.nickname = nickname
        end
        if user_info.head ~= head then
            user_info.head = head
        end
        if user_info.headframe ~= headframe then
            user_info.headframe = headframe
        end 
    end

    return user_rkinfo_m[uid]
end


local function get_rank(uid, name, ismonth)
    if ismonth then
        if rklist_uid_m[name][uid] then 
            return rklist_uid_m[name][uid].rank
        end
    else
        if rklist_uid[name][uid] then 
            return rklist_uid[name][uid].rank
        end
    end

    return 0
end

local function updateRank(uid, name, nickname, head, headframe)
    if rklist_uid_m[name][uid] then
        local data = rklist_uid_m[name][uid].data
        if data then
            if data.nickname ~= nickname then
                rklist_uid_m[name][uid].data.nickname = nickname
            end
            if data.head ~= tostring(head) then
                rklist_uid_m[name][uid].data.head = tostring(head)
            end
            if data.headframe ~= tostring(headframe) then
                rklist_uid_m[name][uid].data.headframe = tostring(headframe)
            end
        end
    end
    if rklist_uid[name][uid] then 
        local data = rklist_uid[name][uid].data
        if data then
            if data.nickname ~= nickname then
                rklist_uid[name][uid].data.nickname = nickname
            end
            if data.head ~= tostring(head) then
                rklist_uid[name][uid].data.head = tostring(head)
            end
            if data.headframe ~= tostring(headframe) then
                rklist_uid[name][uid].data.headframe = tostring(headframe)
            end
        end
    end
end

-------------------------------
-- CMD

function CMD.inject(filePath)
    require(filePath)
end

function CMD.UpdateProtoValueEx(data, value, name)
    if name == "cj" then
        data.valueEx = tostring(value or 0)
    end
end

-- 获取排行榜总榜，分批取
-- name: 人气:rq, 点赞:dz, 段位:dw, 成就:cj, 葫芦藤:hlt
-- ismonth: 是否为月榜
function CMD.get_ranklist(name, start, num, ismonth)
    if start>200 or start<=0 or num<=0 then
        return nil
    end

    num = num>100 and 100 or num
    local endidx = math.min(200, start + num-1)

    --print("-------------",start, endidx)
    local ret = {}
    for i = start, endidx do
        -- local data = ismonth and rank_list_m[name][i] or rank_list[name][i]
        local data
        if ismonth then
            data = rank_list_m[name][i]
        else
            data = rank_list[name][i]
        end
        if data then
            data.rank = i
            data.val = data[name]
            CMD.UpdateProtoValueEx(data,data.title, name)
            table.insert(ret, data)
        end
    end
    ret = #ret>0 and ret or nil

    local maxnum = 0
    if ismonth then
        maxnum =  #rank_list_m[name]
    else
        maxnum = #rank_list[name]
    end

    return ret, maxnum
end

-- 获取好友排行榜, 好友用的是总榜数据
function CMD.get_friend_ranklist(uid, name, nickname, head, headframe)
    local ret = {}
    local maxnum = 0
    local friendlist = dbx.find(COLL.UserFriend, {id=uid}, {_id=false, id=false})
    for i, f in pairs(friendlist) do
        local rkinfo = get_user_rkinfo(f.uId, f.data.nickname, f.data.head, f.data.headFrame)
        local rk = {
            uid       = rkinfo.uid,
            nickname  = rkinfo.nickname,
            head      = rkinfo.head,
            headframe = tostring(rkinfo.headframe),
            lv = rkinfo.lv or 0,
        }
        rk.val  = rkinfo[name]
        CMD.UpdateProtoValueEx(rk, rkinfo.title, name)
        rk.rank = 0
        table.insert(ret, rk)
    end

    local rkinfo =  CMD.get_user_rankinfo(uid, name, false, nickname, head, headframe)
    table.insert(ret, rkinfo)

    -- 根据val 排序
    if ret then

        table.sort(ret, function(rk1,rk2) return rk1.val > rk2.val end)
        for i, rk in pairs(ret) do
            rk.rank = i
        end

        maxnum = #ret
    end

    return ret, maxnum
end

-- 获取个人的排名数据
-- name: 人气:rq, 点赞:dz, 段位:dw, 成就:cj, 葫芦藤:hlt
function CMD.get_user_rankinfo(uid, name, ismonth, nickname, head, headframe)
    local rkinfo = nil
    if ismonth then
        rkinfo = get_user_rkinfo_m(uid, nickname, head, headframe)
    else
        rkinfo = get_user_rkinfo(uid, nickname, head, headframe)
    end

    local ret = {
        uid       = rkinfo.uid,
        nickname  = rkinfo.nickname,
        head      = rkinfo.head,
        headframe = tostring(rkinfo.headframe)
    }
    CMD.UpdateProtoValueEx(ret, rkinfo.title, name)
    ret.val  = rkinfo[name]
    ret.lv = rkinfo.lv
    CMD.UpdateProtoValueEx(ret, rkinfo.title, name)
    ret.rank = get_rank(uid, name, ismonth)

    return ret
end


function CMD.join_ranklist(uid, nickname, head, headframe)
    get_user_rkinfo(uid, nickname, head, headframe)
    get_user_rkinfo_m(uid, nickname, head, headframe)
end

local function get_next_rank(name, ismonth, rank_index)
    local rankList = nil
    if ismonth then
        rankList = rank_list_m[name]
    else
        rankList = rank_list[name]
    end

    if rankList then
        if rank_index == 1 then
            rank_index = 2
        elseif rank_index == 0 then
            rank_index = #rankList
        else
            rank_index = rank_index - 1
        end
        if rank_index > 0 and rank_index <= #rankList then
            return rank_index, rankList[rank_index]
        end
    end
    return 0, nil
end


-- 获取个人的排名数据
-- name: 人气:rq, 点赞:dz, 段位:dw, 成就:cj, 葫芦藤:hlt
function CMD.getUserRankNextDistance(uid, name, ismonth, nickname, head, headframe)
    local PRankD = nil
    if ismonth then
        PRankD = get_user_rkinfo_m(uid, nickname, head, headframe)
    else
        PRankD = get_user_rkinfo(uid, nickname, head, headframe)
    end

    local dis_data = {}
    local list = {}
    local playerRank = nil
    if PRankD then
        playerRank = {}
        playerRank.uid = PRankD.uid
        playerRank.val = PRankD[name]
        playerRank.rank = get_rank(uid, name, ismonth)
        list[playerRank.uid] = playerRank
    end

    local NPRank, NPRankD = get_next_rank(name, ismonth, playerRank.rank)
    local nextPlayerRank = nil
    if NPRankD then
        nextPlayerRank = {}
        nextPlayerRank.uid = NPRankD.uid
        nextPlayerRank.val = NPRankD[name]
        nextPlayerRank.rank = NPRank
        list[nextPlayerRank.uid] = nextPlayerRank
    end
    dis_data[name] = {}
    dis_data[name].list = list

    local data = nil
    if playerRank and nextPlayerRank then
        data = {}
        data.rankP = playerRank.rank
        data.rankNP = nextPlayerRank.rank
        data.rankDis = playerRank.val - nextPlayerRank.val
        if data.rankDis < 0 then
            data.rankDis = -data.rankDis
        end
        dis_data[name].data = data
    end
    return dis_data
end


---------------------------------------------
-- 更新接口,

-- 更新人气值， 玩家人气变动时请调用该接口
-- uid     用户id
-- rq      人气值
-- rq_add  新增人气值
function CMD.update_rq(uid, nickname, head, headframe, rq, rq_add)
    print("------------ranklist_manager: update_rq")

    -- 总榜
    local rkinfo = get_user_rkinfo(uid, nickname, head, headframe)
    rkinfo.rq   = rq
    rkinfo.rq_t = os.time()
    rkinfo.refresh_t = rkinfo.rq_t
    dbx.update(COLL.UserRankList, {uid=uid}, {rq=rkinfo.rq, rq_t=rkinfo.rq_t, nickname = nickname, head = tostring(head), headframe=tostring(headframe)})

    -- 月榜
    local mrkinfo = get_user_rkinfo_m(uid, nickname, head, headframe)
    mrkinfo.rq   = mrkinfo.rq+rq_add
    mrkinfo.rq_t = os.time()
    mrkinfo.refresh_t = mrkinfo.rq_t
    dbx.update(COLL.UserRankListM, {uid=uid}, {rq=mrkinfo.rq, rq_t=mrkinfo.rq_t, nickname = nickname, head = tostring(head), headframe=tostring(headframe)})
    updateRank(uid, "rq",  nickname, head, headframe)
end

-- 更新点赞数
function CMD.update_dz(uid, nickname, head, headframe, dz, dz_add)
    -- 总榜
    local rkinfo = get_user_rkinfo(uid, nickname, head, headframe)
    rkinfo.dz   = dz
    rkinfo.dz_t = os.time()
    rkinfo.refresh_t = rkinfo.dz_t
    dbx.update(COLL.UserRankList, {uid=uid}, {dz=rkinfo.dz, dz_t=rkinfo.dz_t, nickname = nickname, head = tostring(head), headframe=tostring(headframe)})

    -- 月榜
    local mrkinfo = get_user_rkinfo_m(uid, nickname, head, headframe)
    mrkinfo.dz   = mrkinfo.dz+dz_add
    mrkinfo.dz_t = os.time()
    mrkinfo.refresh_t = mrkinfo.dz_t
    dbx.update(COLL.UserRankListM, {uid=uid}, {dz=mrkinfo.dz, dz_t=mrkinfo.dz_t, nickname = nickname, head = tostring(head), headframe=tostring(headframe)})
    updateRank(uid, "dz",  nickname, head, headframe)
end

-- 更新段位累计奖杯
function CMD.update_dw(uid, nickname, head, headframe, dw, dw_add, lv, lv_add)
    -- 总榜
    local rkinfo = get_user_rkinfo(uid, nickname, head, headframe)
    rkinfo.lv = lv
    rkinfo.dw = dw
    rkinfo.dw_t = os.time()
    rkinfo.refresh_t = rkinfo.dw_t
    dbx.update(COLL.UserRankList, {uid=uid}, {dw=rkinfo.dw, dw_t=rkinfo.dw_t, lv=rkinfo.lv , nickname = nickname, head = tostring(head), headframe=tostring(headframe)})

    -- 月榜
    local mrkinfo = get_user_rkinfo_m(uid, nickname, head, headframe)
    -- mrkinfo.dw   = mrkinfo.dw+dw_add
    -- mrkinfo.lv = mrkinfo.lv+lv_add
    mrkinfo.dw = dw
    mrkinfo.lv = lv
    mrkinfo.dw_t = os.time()
    mrkinfo.refresh_t = mrkinfo.dw_t
    dbx.update(COLL.UserRankListM, {uid=uid}, {dw=mrkinfo.dw, dw_t=mrkinfo.dw_t, lv=mrkinfo.lv, nickname = nickname, head = tostring(head), headframe=tostring(headframe)})
    updateRank(uid, "dw",  nickname, head, headframe)
end

-- 更新成就点
function CMD.update_cj(uid, nickname, head, headframe, cj, cj_add, title)
    -- 总榜
    local rkinfo = get_user_rkinfo(uid, nickname, head, headframe)
    if cj and  cj ~= 0 then
        rkinfo.cj   = cj
        rkinfo.cj_t = os.time()
    end
    rkinfo.title = title
    rkinfo.refresh_t = rkinfo.cj_t
    dbx.update(COLL.UserRankList, {uid=uid}, {cj=rkinfo.cj, cj_t=rkinfo.cj_t, title = title, nickname = nickname, head = tostring(head), headframe=tostring(headframe)})

    -- 月榜
    local mrkinfo = get_user_rkinfo_m(uid, nickname, head, headframe)
    if cj and cj ~= 0 then
        mrkinfo.cj   = mrkinfo.cj
        mrkinfo.cj_t = os.time()
    end
    mrkinfo.title = title
    mrkinfo.refresh_t = mrkinfo.cj_t
    dbx.update(COLL.UserRankListM, {uid=uid}, {cj=mrkinfo.cj, cj_t=mrkinfo.cj_t, title = title, nickname = nickname, head = tostring(head), headframe=tostring(headframe)})
    updateRank(uid, "cj",  nickname, head, headframe)
end

-- 更新葫芦藤成长值
function CMD.update_hlt(uid, nickname, head, headframe, hlt, hlt_add)
    -- 总榜
    local rkinfo = get_user_rkinfo(uid, nickname, head, headframe)
    rkinfo.hlt   = hlt
    rkinfo.hlt_t = os.time()
    rkinfo.refresh_t = rkinfo.hlt_t
    dbx.update(COLL.UserRankList, {uid=uid}, {hlt=rkinfo.hlt, hlt_t=rkinfo.hlt_t, nickname = nickname, head = tostring(head), headframe=tostring(headframe)})
    
    -- 月榜
    local mrkinfo = get_user_rkinfo_m(uid, nickname, head, headframe)
    mrkinfo.hlt   = mrkinfo.hlt+hlt_add
    mrkinfo.hlt_t = os.time()
    mrkinfo.refresh_t = mrkinfo.hlt_t
    dbx.update(COLL.UserRankListM, {uid=uid}, {hlt=mrkinfo.hlt, hlt_t=mrkinfo.hlt_t, nickname = nickname, head = tostring(head), headframe=tostring(headframe)})
    updateRank(uid, "hlt",  nickname, head, headframe)
end


-----------------------------------------
-- load from db

-- 加载人气榜
local function load_rank_rq()
    local fields   = {uid=true, rq=true, nickname=true, head=true, headframe=true, refresh_t= true}
    local sorts    = {{rq = -1}}
    
    -- 总榜
    local selector = {rq={["$gt"]=0}}
    rank_list.rq   = dbx.find(COLL.UserRankList, selector, fields, 200, sorts)
    rklist_uid.rq = {}
    for rank, data in ipairs(rank_list.rq) do
        rklist_uid.rq[data.uid] = {rank=rank, data=data}
    end
    
    -- 月榜
    local selectorM = {t={["$gte"]=setting.t}, rq={["$gt"]=0}}
    rank_list_m.rq = dbx.find(COLL.UserRankListM, selectorM, fields, 200, sorts)
    rklist_uid_m.rq = {}
    for rank, data in ipairs(rank_list_m.rq) do
        rklist_uid_m.rq[data.uid] = {rank=rank, data=data}
    end
end

-- 加载点赞榜
local function load_rank_dz()
    local fields   = {uid=true, dz=true, nickname=true, head=true, headframe=true, refresh_t= true}
    local sorts    = {{dz = -1}}
    
    -- 总榜
    local selector = {dz={["$gt"]=0}}
    rank_list.dz   = dbx.find(COLL.UserRankList, selector, fields, 200, sorts)
    rklist_uid.dz = {}
    for rank, data in ipairs(rank_list.dz) do
        rklist_uid.dz[data.uid] = {rank=rank, data=data}
    end

    -- 月榜
    local selectorM = {t={["$gte"]=setting.t}, dz={["$gt"]=0}}
    rank_list_m.dz = dbx.find(COLL.UserRankListM, selectorM, fields, 200, sorts)
    rklist_uid_m.dz = {}
    for rank, data in ipairs(rank_list_m.dz) do
        rklist_uid_m.dz[data.uid] = {rank=rank, data=data}
    end
end

-- 加载段位榜
local function load_rank_dw()
    local selector = {dw={["$gt"]=0}}
    local fields   = {uid=true, dw=true, lv=true, nickname=true, head=true, headframe=true, refresh_t= true}
    local sorts    = {{dw = -1}}

    -- 总榜
    rank_list.dw   = dbx.find(COLL.UserRankList, selector, fields, 200, sorts)
    rklist_uid.dw = {}
    for rank, data in ipairs(rank_list.dw) do
        rklist_uid.dw[data.uid] = {rank=rank, data=data}
    end

    -- 月榜
    local selectorM = {t={["$gte"]=setting.t}, dw={["$gt"]=0}}
    rank_list_m.dw = dbx.find(COLL.UserRankListM, selectorM, fields, 200, sorts)
    rklist_uid_m.dw = {}
    for rank, data in ipairs(rank_list_m.dw) do
        rklist_uid_m.dw[data.uid] = {rank=rank, data=data}
    end
end

-- 加载成就榜
local function load_rank_cj()
    local selector = {cj={["$gt"]=0}}
    local fields   = {uid=true, cj=true, title = true, nickname=true, head=true, headframe=true, refresh_t= true}
    local sorts    = {{cj = -1}}

    -- 总榜
    rank_list.cj   = dbx.find(COLL.UserRankList, selector, fields, 200, sorts)
    rklist_uid.cj = {}
    for rank, data in ipairs(rank_list.cj) do
        rklist_uid.cj[data.uid] = {rank=rank, data=data}
    end

    -- 月榜
    local selectorM = {t={["$gte"]=setting.t}, cj={["$gt"]=0}}
    rank_list_m.cj = dbx.find(COLL.UserRankListM, selectorM, fields, 200, sorts)
    rklist_uid_m.cj = {}
    for rank, data in ipairs(rank_list_m.cj) do
        rklist_uid_m.cj[data.uid] = {rank=rank, data=data}
    end
end

-- 加载葫芦藤榜
local function load_rank_hlt()
    local fields   = {uid=true, hlt=true, nickname=true, head=true, headframe=true, refresh_t= true}
    local sorts    = {{hlt = -1}}
    
    -- 总榜
    local selector = {hlt={["$gt"]=0}}
    rank_list.hlt   = dbx.find(COLL.UserRankList, selector, fields, 200, sorts)
    rklist_uid.hlt = {}
    for rank, data in ipairs(rank_list.hlt) do
        rklist_uid.hlt[data.uid] = {rank=rank, data=data}
    end

    -- 月榜
    local selectorM = {t={["$gte"]=setting.t}, hlt={["$gt"]=0}}
    rank_list_m.hlt = dbx.find(COLL.UserRankListM, selectorM, fields, 200, sorts)
    rklist_uid_m.hlt = {}
    for rank, data in ipairs(rank_list_m.hlt) do
        rklist_uid_m.hlt[data.uid] = {rank=rank, data=data}
    end
end


-- 跨月处理
local function next_month_check()
    if check_same_month(setting.t) then return end

    -- 月榜数据重置
    setting.t = os.time()
    setting.settle = setting.settle + 1
    dbx.update(COLL.SETTING, {id="ranklist_setting"}, setting)

    rank_list_m = {rq={},dz={},dw={},cj={},hlt={}}
    rklist_uid_m = {rq={},dz={},dw={},cj={},hlt={}}
    user_rkinfo_m = {}
    dbx.delAll(COLL.UserRankListM)
end


-- 刷新排行榜
function CMD.refresh()
    load_rank_rq()
    load_rank_dz()
    load_rank_dw()
    load_rank_cj()
    load_rank_hlt()
    
    --检查是否是本赛季

    if not pcall(CMD.refreshAnnounce) then
        skynet.loge("CMD.refreshAnnounce()-----------------------")
    end
end

function CMD.refreshAnnounce()
    --赛季前100名如果是斗帝，看有没有播放过天下第一的公告
    local index = 0 
    for rank, data in ipairs(rank_list_m.dw) do
        local user_base_data = {}

        if rank == 1 then
            user_base_data.nickname = data.nickname
            user_base_data.id = data.uid
            user_base_data.nickname = data.nickname
            user_base_data.lv = data.lv
            common.UpdateSessionDuanwei(dbx, user_base_data, "rank_dw_refresh", rank)
        end

        if data.lv >= DWLv_DouDi_min and rank <= 100 then
            user_base_data.nickname = data.nickname
            user_base_data.id = data.uid
            user_base_data.nickname = data.nickname
            user_base_data.lv = data.lv
            common.UpdateSessionDuanwei(dbx, user_base_data, "dw_refresh", rank)
        end
        index = index + 1
        if index > 100 then
            break
        end
    end

    for rank, data in ipairs(rank_list.hlt) do
        if rank == 1 then
            local user_base_data = {}
            user_base_data.nickname = data.nickname
            user_base_data.id = data.uid
            user_base_data.nickname = data.nickname
            user_base_data.lv = data.lv
            common.UpdateSessionDuanwei(dbx, user_base_data, "rank_hlt_refresh", rank)
            break
        end
    end

end


function CMD.UpdatePlayerBaseDataList(list, is_month)
    if not list then
        return
    end
    
    --dw
    local current_time = os.time()

    local _update_id_array = {}
    if list then
        function GetRankPlayer(id, list)
            if list then
                for key, _rank_d in pairs(list) do
                    if _rank_d.uid == id then
                        return _rank_d
                    end
                    
                end
            end
            return nil
        end
        for _, _data in pairs(list) do
            if not _data.refresh_t then
                _data.refresh_t = 0
            end
            if _data.refresh_t + refresh_base_data_interval  <  current_time then
                _data.refresh_t = current_time
                _update_id_array[_data.uid] = true
            end
        end
        if next(_update_id_array) then
            local ids = {}
            local index = 1
            for _id, _ in pairs(_update_id_array) do
                ids[index] = _id
                index = index +1
            end
            local fields = {uid=true, nickname=true, head=true, headFrame=true}
            local _user_datas = common.getUserBaseArr(ids, fields)
            if next(_user_datas) then
                local _temp_user = nil
                for _, _user_data in pairs(_user_datas) do
                    _temp_user = GetRankPlayer(_user_data.id, list)
                    if _temp_user then
                        local is_new = false
                        local up_data = {}
                        if _temp_user.nickname ~= _user_data.nickname then
                            _temp_user.nickname = _user_data.nickname
                            up_data.nickname = _user_data.nickname
                            if user_rkinfo and user_rkinfo[_user_data.id] then
                                user_rkinfo[_user_data.id].nickname = up_data.nickname
                            end
                            is_new = true
                        end
    
                        if _temp_user.head ~= tostring(_user_data.head) then
                            _temp_user.head = tostring(_user_data.head)
                            up_data.head = tostring(_user_data.head)
                            if user_rkinfo and user_rkinfo[_user_data.id] then
                                user_rkinfo[_user_data.id].head = up_data.head
                            end
                            is_new = true
                        end
    
                        if _temp_user.headframe ~= tostring(_user_data.headFrame) then
                            _temp_user.headframe = tostring(_user_data.headFrame)
                            up_data.headframe = tostring(_user_data.headFrame)
                            if user_rkinfo and user_rkinfo[_user_data.id] then
                                user_rkinfo[_user_data.id].headframe = tostring(up_data.headframe)
                            end
                            is_new = true
                        end
    
                        if is_new == true then 
                            up_data.uid = _user_data.id
                            up_data.refresh_t = _temp_user.refresh_t
                            if is_month then
                                dbx.update(COLL.UserRankListM, {uid=up_data.uid}, up_data)
                            else 
                                dbx.update(COLL.UserRankList, {uid=up_data.uid}, up_data)
                            end
                        end
                    end
                end
            end
        end
    end
end
--总榜
function CMD.refreshRankBaseData()
    if not rank_list  then
        return
    end
    --人气
    CMD.UpdatePlayerBaseDataList(rank_list.rq)
    --点赞
    CMD.UpdatePlayerBaseDataList(rank_list.dz)
    --dw
    CMD.UpdatePlayerBaseDataList(rank_list.dw)
    --cj
    CMD.UpdatePlayerBaseDataList(rank_list.cj)
     --hlt
    CMD.UpdatePlayerBaseDataList(rank_list.hlt)

    --人气
    CMD.UpdatePlayerBaseDataList(rank_list_m.rq,true)
    --点赞
    CMD.UpdatePlayerBaseDataList(rank_list_m.dz,true)
    --dw
    CMD.UpdatePlayerBaseDataList(rank_list_m.dw,true)
    --cj
    CMD.UpdatePlayerBaseDataList(rank_list_m.cj,true)
        --hlt
    CMD.UpdatePlayerBaseDataList(rank_list_m.hlt,true)
end

function CMD.time_tick_handler()
    next_month_check()

    refresh_left_time = refresh_left_time - 1
    if refresh_left_time <= 0 then
        refresh_left_time = refresh_interval
        -- skynet.logd("CMD.refresh()-----------------------")
        CMD.refresh()
    end

    refresh_base_data_left_time = refresh_base_data_left_time - 1
    if refresh_base_data_left_time <= 0 then
        refresh_base_data_left_time = refresh_base_data_interval
        -- skynet.logd("CMD.refreshRankBaseData()-----------------------")
        CMD.refreshRankBaseData()
        -- CMD.refreshRankMBaseData()
    end

end

function CMD.time_tick()
    if not pcall(CMD.time_tick_handler) then
        skynet.loge("CMD.time_tick_handler()-----------------------")
    end
    skynet.timeout(100, CMD.time_tick)
end

local function GetLevel(exp)
    local lv = 0
    for key, sData in pairs(datax.titleRewards) do
        if sData.exp > exp then
            break
        end
        lv = sData.level
    end
    return lv
end

-- 设置测试数据   for test
local function setup_test_data()

    local data = dbx.find(COLL.UserRankList, {},{_id=false, uid=true})
    if data and #data>0 then
        return
    end

    local headArr = table.toArray(datax.player_avatar)

    for i=1001, 2000, 1 do
        local now = os.time()
        local uid = "_robot" ..tostring(i)
        local headData = headArr[math.random(1, #headArr)]

        local rk = {
            uid=uid, nickname="玩家_"..uid, head = tostring(headData.id), headframe="165002", t=now,
            rq=math.random(1, 100), rq_t=now,
            dz=math.random(1, 100), dz_t=now,
            dw=math.random(1, 100), lv=duanwei_init_level, dw_t=now,
            cj=math.random(1, 100), cj_t=now,
            hlt=math.random(1, 100), hlt_t=now,
            refresh_t= now,
        }
        rk.lv = GetLevel(rk.dw)
        dbx.add(COLL.UserRankList,rk)

        rk = {
            uid=uid, nickname="玩家_"..uid, head = tostring(headData.id), headframe="165002", t=now,
            rq=math.random(1, 100), rq_t=now,
            dz=math.random(1, 100), dz_t=now,
            dw=math.random(1, 100), lv=duanwei_init_level, dw_t=now,
            cj=math.random(1, 100), cj_t=now,
            hlt=math.random(1, 100), hlt_t=now,
            refresh_t= now,
        }
        rk.lv = GetLevel(rk.dw)
        dbx.add(COLL.UserRankListM,rk)
    end
end


function CMD.init()
    
    -- 填充测试数据
    -- setup_test_data() -- for test

    -- init setting 
    setting = dbx.get(COLL.SETTING, {id = "ranklist_setting"}, {_id=false,t=true,settle=true})
    if not setting then
        setting = {}
        setting.id     = "ranklist_setting"
        setting.t      = os.time()
        setting.settle = 1
        dbx.add(COLL.SETTING,setting)
    end

    -- load from db
    load_rank_rq()
    load_rank_dz()
    load_rank_dw()
    load_rank_cj()
    load_rank_hlt()

    -- 跨月
    next_month_check()
end


skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
    CMD.init()
    skynet.timeout(100, CMD.time_tick)
end)