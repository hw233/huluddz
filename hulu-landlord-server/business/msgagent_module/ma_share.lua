local skynet = require "skynet"
local ma_data = require "ma_data"
-- local active_conf = require "conftbl.active"
local cfg_global = require "cfg.cfg_global"
local COLLECTIONS = require "config/collections"
local M = {}
local request = {}
local cmd = {}

function request:share_game_ok()
    M.check_day()
    local share = ma_data.share

    if share.share_gamec >= 5 then
        return {result = false}
    else
        local awards = active_conf.share_game.awards

        share.share_gamec = share.share_gamec + 1

        ma_data.add_goods_list(awards,GOODS_WAY_SHARE, "分享游戏")
        ma_data.send_push("buy_suc", {
            msgbox = 1,
            goods_list = awards
        })
        skynet.call(get_db_mgr(), "lua", "update", "active", {pid = ma_data.my_id, name = "share"}, {
            share_gamec = share.share_gamec
        })
        return {result = true, share_gamec = share.share_gamec}
    end
end

-- 1: 朋友 / 朋友圈
function request:share_today_ok()
    M.check_day()
    assert(self.share_type == 1)

    local awards = cfg_global[1].share_award

    ma_data.share.today_share_count = ma_data.share.today_share_count + 1
    skynet.call(get_db_mgr(), "lua", "update", "active", {pid = ma_data.my_id, name = "share"}, {today_share_count = ma_data.share.today_share_count})

    if ma_data.share.today_share_count <= 3 then

        -- if self.watch_ad then
        --     awards = goods_listx2(awards)
        -- end
       
        ma_data.add_goods_list(awards,GOODS_WAY_SHARE, "每日分享")
        ma_data.send_push("buy_suc", {
            msgbox = 2,
            goods_list = awards
        })

        return {result = true, today_share_count = ma_data.share.today_share_count}
    else
        return {result = false, today_share_count = ma_data.share.today_share_count}
    end
end

function M.check_day()
    local today = os.date("%Y%m%d")
    if today ~= ma_data.share.day then
        ma_data.share.day = today
        ma_data.share.today_share_count = 0
        ma_data.share.share_gamec = 0
        skynet.call(get_db_mgr(), "lua", "update", "active", {pid = ma_data.my_id, name = "share"}, {
            day = today,
            today_share_count = 0,
            share_gamec = 0
        })
    end
end


----------------------------------------------------------------------
--SDK 天降福利

local function load_dailytask_data()
    local t = skynet.call(get_db_mgr(), "lua", "find_one", COLLECTIONS.TASK, {pid = ma_data.my_id}, 
        {god_award = true,_id=false})
    return t and t.god_award
end

local function Init_Sdk_gift()
    ma_data.god_award = load_dailytask_data()
    if not ma_data.god_award then
        ma_data.god_award = {}
        for i,v in ipairs(cfg_god_award) do            
            table.insert(ma_data.god_award,{
                id = v.id,
                award = 0,
                goods = #v.award > 0 and v.award or nil,
            })
        end
        skynet.call(get_db_mgr(), "lua", "update", COLLECTIONS.TASK,{pid = ma_data.my_id}, {god_award = ma_data.god_award } )    
    end
    return ma_data.god_award
end

--id2 邀请好友 跟每日分享功能共用
function request:get_sdk_gift()
    local pack = Init_Sdk_gift()
    --拼装[2]数据 分享进入pack
    local awards = cfg_global[1].share_award
    pack[2] = {id = 2,goods =awards, today_share_count = ma_data.share.today_share_count}
    return {god_award = pack}
end

function request:award_sdk_gift()
    local ret ={e_info =1}
    local id = self.id
    local pack = Init_Sdk_gift()
    --分享走  C2s_Share_today_ok 244 接口
    if pack[id] and id ~= 2 then
        if pack[id].award == 0 then
            pack[id].award = 1
            ma_data.add_goods_list(pack[id].goods,GOODS_WAY_SDK_GIFT, "天降福利")
            ma_data.send_push("buy_suc", {
                msgbox = 2,
                goods_list = pack[id].goods
            })
            ret.good_award = pack[id]
            ret.e_info =0
            --数据库更新
            skynet.call(get_db_mgr(), "lua", "update", COLLECTIONS.TASK,{pid = ma_data.my_id}, {god_award = ma_data.god_award } )    
        end
    end
    return ret
end

---------------------------------------------------------------------

local function init()
    local share = skynet.call(get_db_mgr(), "lua", "find_one", "active", {pid = ma_data.my_id, name = "share"})
    if not share then
        share = {
            pid = ma_data.my_id, 
            name = "share", 
            day = os.date("%Y%m%d"),
            today_share_count = 0,
            share_gamec = 0
        }
        skynet.call(get_db_mgr(), "lua", "insert", "active", share)
        ma_data.share = share
    else
        ma_data.share = share
        M.check_day()
    end
end

function M.init(REQUEST, CMD)
    if request then
        table.connect(REQUEST, request)
    end
    if cmd then
        table.connect(CMD, cmd)
    end
    init()
end
ma_data.ma_share = M
return M