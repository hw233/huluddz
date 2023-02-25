local skynet = require "skynet"

local ma_data      = require "ma_data"
local ma_useritem  = require "ma_useritem"
local UserHero     = require "ma_userhero"
local HeroDataExt  = require "ma_userheroget"
local ma_common    = require "ma_common"

local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)

require "define"
require "table_util"

local cfgExpReward = require "cfg.cfg_cost_expbook_rewards"
local cfgExchShop  = require "cfg.cfg_exchange_shop"
local cfgItems      = require "cfg.cfg_items"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local uid = nil; 

local CMD, REQUEST_New = {}, {}

-----------------------------------------------

local ma_obj = {

    -- 碎片领取信息
    -- array, val为:
    -- {
    --   heroid,        -- 角色id
    --   takelist={}    -- 碎片领取信息 数组
    -- }
    mTakeInfo = {},

    isLoaded = false;       --是否已加载
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    uid = ma_data.db_info.id
end

function Include_K(tb, key)
    for k,v in pairs(tb) do
        if k == key then return true end
    end
    return false
end

function Include_V(tb, val)
    for k,v in pairs(tb) do
        if v == val then return true end
    end
    return false
end

local function print_tb( t )
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(tostring(t).." {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end

function ma_obj.LoadData()
    if ma_obj.isLoaded then return end

    ma_obj.mTakeInfo = {}
    ma_obj.LoadFromDB()

    ma_obj.isLoaded = true
end

function ma_obj.LoadFromDB()
    --print("................PieceShop LoadFromDB")
    local selectObj = { uid = uid }
    local data = dbx.find(TableNameArr.UserPieceTakeTable, selectObj)
    if data then
        --print_tb(data)
        for i, v in pairs(data) do
            local d = {heroid=v.heroid, takelist=v.takelist}
            table.insert(ma_obj.mTakeInfo, d)
        end
    end
end


function ma_obj.IsTaked(heroid, takeid)
    for i, info in pairs(ma_obj.mTakeInfo) do
        if heroid == info.heroid then
            if Include_V(info.takelist) then
                return true;
            end
        end
    end

    return false
end


function ma_obj.TakePiece(heroid, awardid)

    local idx = 0
    local isnew = false
    for i, info in pairs(ma_obj.mTakeInfo) do
        if heroid == info.heroid then 
            idx = i
            break
        end
    end
    
    if idx == 0 then
        table.insert(ma_obj.mTakeInfo, { heroid=heroid, takelist={}} )
        idx = #ma_obj.mTakeInfo
        isnew = true
    end

    table.insert(ma_obj.mTakeInfo[idx].takelist, awardid)
    --print(".............TakePiece:", idx, isnew)
    return idx, isnew
end


------------------------------------------------
-- 获取相关信息
REQUEST_New.PieceShop_GetInfo = function()
    ma_obj.LoadData();

    --print_tb(ma_obj.mTakeInfo)
    -- 将takeinfo发送给client
    return RET_VAL.Succeed_1, {takeinfo=ma_obj.mTakeInfo}
end


-- 领取碎片
REQUEST_New.PieceShop_TakePiece = function(args)
    if ma_obj.isLoaded == false then
        return RET_VAL.ERROR_3, {msg="load data first"}
    end

    local heroid  = args.heroid;
    local awardid = args.awardid;

    if awardid<1 or awardid>#cfgExpReward then
        return RET_VAL.ERROR_3, {msg="awarid error"}
    end

    -- 是否有该角色
    local hero = UserHero.get(heroid)
    if not hero or hero.notLimit==false then
        --print("...........", hero, heroid)
        return RET_VAL.ERROR_3, {msg="get hero error"}
    end

    local cfg = cfgExpReward[awardid]

    -- 是否可以领取
    local ljExp = HeroDataExt.GetLJExpBook(heroid)
    -- ljExp = 120000    -- for test
    if ljExp<cfg.cost_exp[1].num then 
        return RET_VAL.ERROR_3, {msg="ljexp error"}
    end

    -- 是否已领取过
    if ma_obj.IsTaked(heroid, awardid) then
        return RET_VAL.ERROR_3, {msg="is taked"}
    end

    -- 领取碎片
    local idx, isnew = ma_obj.TakePiece(heroid, awardid)
    
    -- 碎片放入背包
    local sendDataArr = {}
    ma_useritem.addList(cfg.rewards, 1, "PieceShop_TakePiece_碎片商店领取", sendDataArr)
    ma_common.showReward(sendDataArr)
    --print("...........reward:", cfg.rewards[1].id, cfg.rewards[1].num,  fok)

    -- update db
    if isnew then
        local d = { uid = uid, heroid=heroid, takelist = ma_obj.mTakeInfo[idx].takelist, }
        dbx.add(TableNameArr.UserPieceTakeTable, d)
    else
        local selectObj = { uid = uid, heroid=heroid }
        dbx.update(TableNameArr.UserPieceTakeTable, selectObj, { takelist=ma_obj.mTakeInfo[idx].takelist } )
    end

    --print("...........PieceShop_TakePiece  ok")
    return RET_VAL.Succeed_1, {msg="ok"}
end


-- 购买
REQUEST_New.PieceShop_BuyGoods = function(args)
    local goodsid = args.goodsid    --商品id

    if not goodsid or goodsid<0 or goodsid>#cfgExchShop then
        return RET_VAL.ERROR_3, {msg= "error goodsid"}
    end

    local cfg = cfgExchShop[goodsid]
    local itemid = cfg.exchange_items[1].id
    local itemnum = cfg.exchange_items[1].num
    
    -- 注意部分商品已有就不能再买
    local cfgit = cfgItems[itemid]
    if cfgit.type == 14 then  --hero道具
        local heroid = cfgit.param[1].id;
        local hero = UserHero.get(heroid)
        if hero and hero.notLimit then   --already get notlimit hero
            --print("...........", hero, heroid)
            return RET_VAL.Other_10, {msg="already have notlimit hero"}
        end
    end

    -- 检测碎片是否足够
    local pieceid = cfg.essence_num[1].id
    local costnum = cfg.essence_num[1].num
    local item = ma_useritem.get(pieceid)
    if not item or item.num < costnum then
        return RET_VAL.Other_11, {msg="not enough"}
    end

    -- 扣除碎片道具, 添加商品道具
    if not ma_useritem.remove(pieceid, costnum, "PieceShop_BuyGoods_碎片商店购买") then
        return RET_VAL.ERROR_3, {msg="cost piece fail"}
    end

    local sendDataArr = {}
    ma_useritem.add(itemid, itemnum, "PieceShop_BuyGoods_碎片商店购买", sendDataArr)
    ma_common.showReward(sendDataArr)
    --print("........PieceShop_BuyGoods add:", itemid, itemnum,  fok)

    return RET_VAL.Succeed_1, {msg="ok"}
end


------------------------------------------------

return ma_obj