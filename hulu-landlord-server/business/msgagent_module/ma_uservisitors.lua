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
local TableNameArr = COLL_Name

local CMD, REQUEST_New = {}, {}

local userInfo = ma_data.userInfo

local cfg_data = {
    DayLimit = 30, --显示30天内访客
    DayLimitSec = 30*24*60*60, --显示30天内访客
    VisitorNumLimit = 5--显示50条访客记录
}

local cacheFlag = false

local ma_obj = {
    uid = 0,
    Data = nil,
}

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

    ma_obj.uid = userInfo.id
    if cacheFlag then
        ma_obj:load() --加载数据
        ma_obj:refresh() --刷新
        ma_obj:save()
    end

    eventx.listen(EventxEnum.VisitorPlayer, function (args)
        if not args then
            return
        end
        -- common.call_useragent(args.uid, "UpdateVisitor", {uid=args.uid, targetInfo=args.targetInfo}, ma_obj.UpdateVisitor)
        if not common.call_useragent(args.uid, "UpdateVisitor", {uid=args.uid, targetInfo=args.targetInfo}) then
            ma_obj.UpdateVisitor({uid=args.uid, targetInfo=args.targetInfo})
        end

    end)
end

function ma_obj:CreateRecord()
    local Data = {
        VList = {}
    }
    return Data
end


function ma_obj:refresh()
    if self.Data and self.Data.VList then
        local currentTime = os.time()
        for _uid, _visitor in pairs(self.Data.VList) do
            --删除30天前的访客
            if _visitor and _visitor.LastAt + cfg_data.DayLimitSec < currentTime  then
                self.Data.VList[_uid] = nil
                self.SFlag = true
            end
        end
    end
end

function ma_obj:load()
    self.SFlag = false
    if not self.Data  then
        local data = dbx.find_one(TableNameArr.UserVisitorRecord, self.uid)
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
        dbx.update_add(TableNameArr.UserVisitorRecord, self.uid, self.Data)
    end
end


function ma_obj:loadById(uid) 
    local Data = dbx.find_one(TableNameArr.UserVisitorRecord, uid)
    if not Data then
        Data = self:CreateRecord()
    end
    return Data
end

function ma_obj:saveById(uid, Data) 
    dbx.update_add(TableNameArr.UserVisitorRecord, uid, Data)
end

function ma_obj:refreshById(Data)
    if Data and Data.VList then
        local currentTime = os.time()
        for _uid, _visitor in pairs(Data.VList) do
            --删除30天前的访客
            if _visitor and _visitor.LastAt + cfg_data.DayLimitSec < currentTime  then
                Data.VList[_uid] = nil
            end
        end
    end
end

function ma_obj:CreateVisitorData()
    local NewVisitorData = {
        NewSign = 1,
        LastAt = 0, --最近访问时间
        RefreshAt = 0, --更新基础信息时间
        BaseData = {} --访客基础数据
    }
    return NewVisitorData
end


function ma_obj:GetVisitorById(Data, id)
    if not Data or not Data.VList then
        return nil
    end

    for _, visitor in pairs(Data.VList)  do
        if visitor and visitor.BaseData.id == id then
            return visitor
        end
    end
    return nil
end

function ma_obj:GetVisitorData()
    return self.Data
end

function ma_obj:GetVisitorLength(Data)
    if not Data or not Data.VList then
        return 0
    end
    return #Data.VList
end

function ma_obj:GetTodayVisitorLength(Data)
    if not Data or not Data.VList then
        return 0
    end
    local curr_date = os.date("%Y%m%d")
    local today_num = 0
    for _, _visitor in pairs(Data.VList) do
        if _visitor and _visitor.LastAt then
            local last_date =  os.date("%Y%m%d", _visitor.LastAt)
            if curr_date == last_date then
                today_num = today_num + 1
            end
        end
    end
    return today_num
end


---comment
---@param uid any
---@param other_visitor any
function ma_obj.UpdateVisitor(args) --visitor
    if not args or not args.uid or not args.targetInfo or args.uid == args.targetInfo.id then
        return
    end

    --获取在线数据
    if args.uid == ma_obj.uid then
        ma_obj:load()
        ma_obj:refresh()
        local visitorData = ma_obj:GetVisitorById(ma_obj.Data, args.targetInfo.id)
        if not visitorData then
            visitorData = ma_obj:CreateVisitorData()
            local index = ma_obj:GetVisitorLength(ma_obj.Data) + 1
            ma_obj.Data.VList[index] = visitorData
        end
        visitorData.BaseData = args.targetInfo
        visitorData.NewSign = 1
        visitorData.LastAt = os.time()
        visitorData.RefreshAt = os.time()

        table.sort(ma_obj.Data.VList, function(tv1,tv2) return tv1.LastAt > tv2.LastAt end)
        if ma_obj:GetVisitorLength(ma_obj.Data) > cfg_data.VisitorNumLimit then
            for iLoop = cfg_data.VisitorNumLimit, ma_obj:GetVisitorLength(ma_obj.Data), 1 do
                ma_obj.Data.VList[iLoop] = nil
            end
        end
        ma_obj.SFlag = true
        ma_obj:save()
    else 
        --获取他人离线数据
        local otherData = ma_obj:loadById(args.uid)
        ma_obj:refreshById(otherData)
        if not otherData or not otherData.VList then
            return
        end

        local visitorData = ma_obj:GetVisitorById(otherData, args.targetInfo.id)
        if not visitorData then
            visitorData = ma_obj:CreateVisitorData()
            local index = ma_obj:GetVisitorLength(otherData) + 1
            otherData.VList[index] = visitorData
        end
        visitorData.BaseData = args.targetInfo
        visitorData.NewSign = 1
        visitorData.LastAt = os.time()
        visitorData.RefreshAt = os.time()

        table.sort(otherData.VList, function(tv1,tv2) return tv1.LastAt > tv2.LastAt end)
        if ma_obj:GetVisitorLength(otherData) > cfg_data.VisitorNumLimit then
            for iLoop = cfg_data.VisitorNumLimit, ma_obj:GetVisitorLength(otherData), 1 do
                otherData.VList[iLoop] = nil
            end
        end
        ma_obj:saveById(args.uid, otherData)
    end
end

function ma_obj:SetNewSignToOld()
    if not self.Data or not self.Data.VList then
        return nil
    end

    for _, visitor in pairs(self.Data.VList)  do
        if visitor and visitor.NewSign then
            visitor.NewSign = 0
            self.SFlag = true
        end
    end
end

function ma_obj:visitorToProto(visitor)
    if not visitor then
        return
    end
    local pro_visitor = {}
    pro_visitor.newsign = visitor.NewSign
    pro_visitor.lastat = visitor.LastAt
    pro_visitor.basedata = visitor.BaseData
    return pro_visitor
end

CMD.UpdateVisitor = function (_, args)
    if  not args then
        return  RET_VAL.Empty_7
    end

    -- common.call_useragent(args.id, "UpdateVisitor", {uid=args.id, targetInfo=userInfo}, ma_obj.UpdateVisitor)
    ma_obj.UpdateVisitor(args)
    return RET_VAL.Succeed_1
end


REQUEST_New.GetVisitor = function (args)
    if not args then
        return RET_VAL.Default_0
    end

    ma_obj:load()
    ma_obj:refresh()
    local visitorData = ma_obj:GetVisitorData()
    ma_obj:save()
    if not visitorData or not visitorData.VList then
        return RET_VAL.NotExists_5
    end

    local proto = {}
    proto.visitorlist = {}
    proto.allvisitornum = ma_obj:GetVisitorLength(ma_obj.Data)
    proto.todayvisitornum = ma_obj:GetTodayVisitorLength(ma_obj.Data)

    local curnum = 0
    if args.startindex <=  proto.allvisitornum then
        for _index = args.startindex,  proto.allvisitornum, 1 do
            if curnum >=  args.num then
                break
            end

            local _visitor = visitorData.VList[_index]
            if _visitor then
                local pro_visitor = ma_obj:visitorToProto(_visitor)
                if pro_visitor then
                    curnum =  curnum + 1
                    proto.visitorlist[curnum] = pro_visitor
                end
            end
        end
    end
    return RET_VAL.Succeed_1, proto
end


REQUEST_New.SetVisitorNewSign = function (args)
    ma_obj:load()
    ma_obj:refresh()
    ma_obj:SetNewSignToOld()
    ma_obj:save()
    return RET_VAL.Succeed_1
end


-- .VisitorData {
--     newsign   0:integer #是否是新客访问
--     lastat    1:integer #最后访问时间
--     basedata  2:IUserBase # 基础数据 
-- }

-- GetVisitor 5002 {
--     request {
--         startindex :0 integer
--         num        :1 integer
--     }
--     response {
--         e_info  		0 : integer
--         visitorlist     1 : *VisitorData #访客列表
--         allvisitornum   2 : integer #总访客数
--         todayvisitornum 3 : integer #今日访客数
--     }
-- }

-- UpdateVisitor 5003 {
--     request {
--         id  0 : integer
--     }
--     response {
--         e_info  0 : integer
--     }
-- }

-- SetVisitorNewSign 5004 {
--     request {
--         visitedIdList  0 : *integer
--     }
--     response {
--         e_info  0 : integer
--     }
-- }

return ma_obj