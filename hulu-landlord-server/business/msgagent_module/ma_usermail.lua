local skynet = require "skynet"

local ma_data = require "ma_data"
local ma_useritem = require "ma_useritem"

local objx = require "objx"
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

local ma_obj = {
    maxMailCount = 100
}

local userInfo = ma_data.userInfo

function ma_obj.init(cmd, request_new)
    table.tryMerge(cmd, CMD)
    table.tryMerge(request_new, REQUEST_New)

end


--#region 核心部分

---comment
---@return table 数组
ma_obj.getDataArr = function ()
    -- 删除超过数量的邮件
	--del_rahter_mail(max_mail_count)

    local datas = dbx.find(TableNameArr.UserMail, {uId = userInfo.id}, nil, ma_obj.maxMailCount)--, {sendDt = -1})

    return datas
end

---comment
---@param id any
---@return boolean 不存在返回false，否则true
ma_obj.read = function (id)
    local selectObj = {uId = userInfo.id, id = id}

    local uData = dbx.get(TableNameArr.UserMail, selectObj)
    if not uData then
        return false
    end

    if not uData.read then
        uData.read = true

        dbx.update(TableNameArr.UserMail, selectObj, {read = true})
    end

    return true
end

---comment  TODO：考虑传入id数组，一次性写入多个
---@param id any
---@param uData? any
---@return boolean 不存在此邮件，已领取或道具为空返回 false，否则 true
ma_obj.getItem = function (id, uData, sendDataArr)
    local selectObj = {uId = userInfo.id, id = id}

    if not uData then
        uData = dbx.get(TableNameArr.UserMail, selectObj)
    end
    if not uData or uData.itemGet then
        return false
    end

    if not uData.itemArr or #uData.itemArr <= 0 then
        return false
    end

    uData.read = true
    uData.itemGet = true
    dbx.update(TableNameArr.UserMail, selectObj, {read = true, itemGet = true})

    ma_useritem.addList(uData.itemArr, 1, "GetMailItem_领取邮件道具", sendDataArr)

    return true
end


ma_obj.remove = function (idOrArr)
    if objx.isString(idOrArr) then
        idOrArr = {idOrArr}
    end

    for idx, id in ipairs(idOrArr) do
        dbx.del(TableNameArr.UserMail, id)
    end

    return true
end

--#endregion


REQUEST_New.GetUserMailDatas = function ()
    local arr = ma_obj.getDataArr()

    local ret = {}
    for i, value in ipairs(arr) do
        ret[value.id] = value
    end
    return {datas = ret}
end

REQUEST_New.ReadMail = function (args)
    local id = args.id

    if not ma_obj.read(id) then
        return RET_VAL.Fail_2
    end

    return RET_VAL.Succeed_1, { id = id }--客户端需要这个id
end

REQUEST_New.GetMailItem = function (args)
    local id, type = args.id, args.type
    
    local sendDataArr = {}
    if type == 1 then
        if not ma_obj.getItem(id, nil, sendDataArr) then
            return RET_VAL.Fail_2
        end
    elseif type == 2 then
        local arr = ma_obj.getDataArr()
        for index, value in ipairs(arr) do
            ma_obj.getItem(value.id, value, sendDataArr)
        end
    else
        return RET_VAL.ERROR_3
    end

    ma_common.showReward(sendDataArr)

    return RET_VAL.Succeed_1, {id = id}
end

REQUEST_New.RemoveMail = function (args)
    local id, type = args.id, args.type
    
    if type == 1 then
        if not ma_obj.remove(id) then
            return RET_VAL.Fail_2
        end
    elseif type == 2 then
        local idArr = {}
        local arr = ma_obj.getDataArr()
        for index, value in ipairs(arr) do
            if value.read and (value.itemGet or not value.itemArr or #value.itemArr <= 0) then
                table.insert(idArr, value.id)
            end
        end
        ma_obj.remove(idArr)
    else
        return RET_VAL.ERROR_3
    end

    return RET_VAL.Succeed_1, { id = id }--客户端需要这个id
end


return ma_obj