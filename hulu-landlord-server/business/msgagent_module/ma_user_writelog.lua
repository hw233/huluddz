local skynet = require "skynet"
local eventx = require "eventx"

local ma_data = require "ma_data"
local objx = require "objx"
local datax = require "datax"
local create_dbx = require "dbx"
local ma_userhero = require "ma_userhero"
local cfg_items = require "cfg.cfg_items"
local ma_useritem   = require "ma_useritem"
local ma_common = require "ma_common"
local common = require "common_mothed"
local dbx = create_dbx(get_db_manager)

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local dbx_rec = create_dbx("db_manager_rec")

local TableNameArr = COLL_Name
--UserServerDataRecord
local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo


local ma_obj = {
    uid = 0,
    Data = nil,
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)
    ma_obj.uid = userInfo.id

    eventx.listen(EventxEnum.WriteLog, function (...)
        ma_obj.WriteLog(...)
    end)

    eventx.listen(EventxEnum.UserStoreBuy, function (sData, num, rewardInfo)
        if not sData then
            return 
        end

        eventx.call(EventxEnum.WriteLog, UserLogKey.chongzhicishu, UserLogKey.dancijine, tostring(sData.price), 
            UserLogKey.goumaiwuping, tostring(sData.id))

        if sData.id == StorIdEm.StoreFirst1 or sData.id == StorIdEm.StoreFirst6 then
            local playCount = userInfo.gameCountSum or 0
            local winCountSum = userInfo.gameCountSum or 0
            eventx.call(EventxEnum.WriteLog, UserLogKey.shouchongplayer, tostring(sData.id), 
                UserLogKey.dijiju, tostring(playCount), UserLogKey.shengli, tostring(winCountSum), 
                UserLogKey.shibai, tostring(playCount-winCountSum), UserLogKey.douzishuliang, tostring(userInfo.gold or 0))
        elseif sData.id == StorIdEm.Pochan1 or sData.id == StorIdEm.Pochan3 or sData.id == StorIdEm.Pochan6 or 
            sData.id == StorIdEm.Pochan8 or sData.id == StorIdEm.Pochan12 or sData.id == StorIdEm.Pochan18 or 
            sData.id == StorIdEm.Pochan30 or sData.id == StorIdEm.Pochan50 or sData.id == StorIdEm.Pochan60 or 
            sData.id == StorIdEm.Pochan68 or sData.id == StorIdEm.Pochan88 or sData.id == StorIdEm.Pochan98 or 
            sData.id == StorIdEm.Pochan108 or sData.id == StorIdEm.Pochan128 or sData.id == StorIdEm.Pochan328 or sData.id == StorIdEm.Pochan648 then
            eventx.call(EventxEnum.WriteLog, UserLogKey.goumairenshu, tostring(sData.id), UserLogKey.goumailibaodoushu,tostring(userInfo.gold or 0))
        end
    end)

    eventx.listen(EventxEnum.RoomGameStar, function (gameType)
        local playCount = userInfo.gameCountSum or 0
         if playCount == 0 then
            local duration = os.time() - (userInfo.firstLoginDt or 0)
            eventx.call(EventxEnum.WriteLog, UserLogKey.first_dapai, tostring(duration))
         end
    end)

end

function ma_obj.WriteLog(...)
    common.write_record(TableNameArr.UserServerDataRecord, userInfo.id, "", userInfo.os, userInfo.channel, os.date("%Y-%m-%d %H:%M:%S"), ...)
end

return ma_obj