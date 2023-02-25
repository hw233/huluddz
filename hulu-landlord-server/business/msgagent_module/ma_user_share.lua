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
local dbx = create_dbx(get_db_manager)

require "define"
require "table_util"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local globalId = 170002
local cfg_data = {
    gold_limit= 2000000
}

 

local ma_obj = {

}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)
    ma_obj.uid = userInfo.id

    local _cfgData = datax.globalCfg[globalId]
    if _cfgData then
        cfg_data.gold_limit =   _cfgData.val
    end
end

function ma_obj:CreateRecord()
    local Data = {
        VList = {}
    }
    return Data
end


function ma_obj:refresh()
    if self.Data and self.Data.VList then
        local current_time = os.time()
        local curr_date = os.date("%Y%m%d")
        for _point, _share_data in pairs(self.Data.VList) do
            local last_date = os.date("%Y%m%d", _share_data.LastAt)
            if _share_data and last_date ~= curr_date  then
                self.Data.VList[_point] = nil
                self.SFlag = true
            end
        end
    end
end

function ma_obj:load()
    self.SFlag = false
    if not self.Data  then
        local data = dbx.find_one(TableNameArr.UserShareRecord, self.uid)
        if not data then
            self.Data = self:CreateRecord()
            self.SFlag = true
            self:save()
        else 
            self.Data = data
        end
    end
end

function ma_obj:save() 
    if self.SFlag then
        self.SFlag = false
        dbx.update_add(TableNameArr.UserShareRecord, self.uid, self.Data)
    end
end

function ma_obj:reward(point)

    point= tostring(point)

    local cfgList = datax.share
    local cfg
    for _, _cfg in pairs(cfgList) do
        if tostring(_cfg.point) == point then
            cfg = _cfg
            break
        end
    end
    
    if not cfg then
        return  RET_VAL.NotExists_5
    end

    local itemlist = clone(cfg.reward)
    local gold_num = 0
    for _, _item in pairs(itemlist) do
        if _item.id == ItemID.Gold then
            gold_num = _item.num
            break
        end
    end
    
    local point_data = self.Data.VList[point]
    if not point_data then
        point_data = {gold = 0, LastAt = os.time()}
        self.Data.VList[point] = point_data
        self.SFlag = true
    end

    if point_data.gold + gold_num > cfg_data.gold_limit then
        gold_num = cfg_data.gold_limit - point_data.gold
        if gold_num <= 0 then
            return  RET_VAL.NotExists_5
        end

        for _, _item in pairs(itemlist) do
            if _item.id == ItemID.Gold then
                _item.num =  gold_num
                break
            end
        end
    end

    point_data.LastAt = os.time()
    point_data.gold = gold_num + point_data.gold
    self.SFlag = true
    return RET_VAL.Succeed_1, itemlist
end

REQUEST_New.ShareReward = function (args)
    if not args and not args.point then
        return  RET_VAL.ERROR_3
    end

    local point = args.point
    ma_obj:load()
    ma_obj:refresh()
    local errCode, itemlist = ma_obj:reward(point)
    ma_obj:save()
    if errCode ~= RET_VAL.Succeed_1 then
        return errCode
    end

    eventx.call(EventxEnum.WriteLog, UserLogKey.cxcg_total, tostring(point)) 

    -- 加入背包
    local sendDataArr = {}
    ma_useritem.addList(itemlist, 1, "分享" .. point .. "奖励", sendDataArr)
    ma_common.showReward(sendDataArr)
    local proto = {}
    proto.rewardboxitems = itemlist
    return errCode, proto
end


-- ShareReward 5008 {
--     request {
--         point 0 : integer #分享点id
--     }

--     response {
--         e_info          0 : integer
--         rewardboxitems  1 : *rewardboxitem  #奖励信息
--     }
-- }


return ma_obj