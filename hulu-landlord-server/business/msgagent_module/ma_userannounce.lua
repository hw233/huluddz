local skynet = require "skynet"
local eventx = require "eventx"
local ec = require "eventcenter"

local ma_data = require "ma_data"
local ma_userstore = require "ma_userstore"

local datax = require "datax"
local objx = require "objx"
local arrayx = require "arrayx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local ma_common = require "ma_common"

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

--#region 配置表 require
--#endregion

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local ma_obj = {
    
}


function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ec.sub({type = EventCenterEnum.NewUserAnnounce}, function (eventObj)
        -- TODO：优化方案，先缓存，定时器一起发送
        ma_common.send_myclient("AUserAnnounce", eventObj)
	end)

    ec.sub({type = EventCenterEnum.NewSysAnnounce, uId = userInfo.id }, function (eventObj)
        -- TODO：优化方案，先缓存，定时器一起发送
        ma_common.send_myclient("AWorldAnnounce", eventObj)
	end)

    ec.sub({type = EventCenterEnum.NewSysAnnounceTxt, uId = userInfo.id }, function (eventObj)
        -- TODO：优化方案，先缓存，定时器一起发送
        -- ma_common.send_myclient("AWorldAnnounce", eventObj)
	end)

    ec.sub({type = EventCenterEnum.NewSysAnnounceImg, uId = userInfo.id }, function (eventObj)
        -- TODO：优化方案，先缓存，定时器一起发送
        -- ma_common.send_myclient("AWorldAnnounce", eventObj)
	end)
    
    ma_obj.initListen()
end

ma_obj.initListen = function ()
    eventx.listen(EventxEnum.UserStoreBuy, function (sData)
        if sData.id == StorIdEm.Zhouka7 then
            ma_common.addAnnounce(AnnounceIdEm.Zhouka7, {name = userInfo.nickname})
        elseif sData.id == StorIdEm.Yueka30 then
            ma_common.addAnnounce(AnnounceIdEm.Yueka30, {name = userInfo.nickname})
        elseif sData.id == StorIdEm.Nianka then
            ma_common.addAnnounce(AnnounceIdEm.Nianka, {name = userInfo.nickname})
        elseif sData.id == StorIdEm.XianshiMiaosha then
            ma_common.addAnnounce(AnnounceIdEm.XianshiMiaosha, {name = userInfo.nickname})            
        elseif sData.id == StorIdEm.StoreBuyHeroJdaohai or sData.id == StorIdEm.BuyHeroSWanqing or
         sData.id == StorIdEm.BuyHeroYsimo or sData.id == StorIdEm.BuyHeroLyun then
            ma_common.addAnnounce(AnnounceIdEm.StoreBuyHero, {name = userInfo.nickname, itemname = sData.name})     
        elseif sData.id == StorIdEm.StoreFirst1 or sData.id == StorIdEm.StoreFirst6 then
            ma_common.addAnnounce(AnnounceIdEm.StoreFirst, {name = userInfo.nickname})     
        end
    end)

    eventx.listen(EventxEnum.DWAnnounce, function (args)
        if not args then
            return
        end
        local annId = args.annId
        if annId == AnnounceIdEm.DwShengjiDouhuang or
            annId == AnnounceIdEm.DwShengjiDousheng or
            annId == AnnounceIdEm.DwShengjiDoudi or
            annId == AnnounceIdEm.DwShengjiTianxiadiyi then
            ma_common.addAnnounce(annId, {name = userInfo.nickname})
        elseif annId == AnnounceIdEm.luckSItem then
            ma_common.addAnnounce(annId, {name = userInfo.nickname, itemname=args.itemname})
        elseif annId == AnnounceIdEm.TxzGold then
            ma_common.addAnnounce(annId, {name = userInfo.nickname})
        elseif annId == AnnounceIdEm.TxzBoJinGold then
            ma_common.addAnnounce(annId, {name = userInfo.nickname, itemname=args.itemname})
        end
    end)

    eventx.listen(EventxEnum.SysAnnounce, function (args)
        if not args then
            return
        end
        ma_common.addSysAnnounce(args.content)
    end)

    eventx.listen(EventxEnum.SysAnnounceTxt, function (args)
        if not args then
            return
        end
        ma_common.addSysAnnounce(args.content)
    end)
    eventx.listen(EventxEnum.SysAnnounceImg, function (args)
        if not args then
            return
        end
        ma_common.addSysAnnounce(args.content)
    end)
end

--#region 核心部分

--#endregion


return ma_obj