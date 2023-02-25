local skynet = require "skynet"
require "define"
require "table_util"
local httpc = require "http.httpc"
local cjson = require "cjson"
local xy_cmd  = require "xy_cmd"

local create_dbx = require "dbx"
local dbx  = create_dbx(get_db_manager)
local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local mycrypt = require "utils.mycrypt"
local crypt = require "skynet.crypt"
local cjson = require "cjson"
local sign_util = require "utils.sign_util" 
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

local CDRType = {
    Type1 = "1", --只能单个人领一次
    Type2 = "2"  --可以一人领一次
}

ServerData.init = function ()

end

local M = {
    Map = {"A", "B", "C", "D", "E", "F", "G", "0", "1", "2", "3", "7", "8", "9", "H","I","J","K","L","O","P","Q","R","S","T","U","V","W","X","Y","Z", "4", "5", "6","M","N"}
}


function M.Get36Num(num)
    local num36 = ""
    local line = num
    local index = 0
    local mod = 0
    for i = 1, 30, 1 do
        mod = math.fmod( line, 36 )    -- 取余数
        line = math.modf( line / 36 )  -- 取整数
        num36 = M.Map[mod+1]..num36
        if line == 0 then
            break
        end
        index = index + 1
    end
    return num36
end

function M.GetCdkData(cdkId)
    return dbx.find_one(TableNameArr.ServerCdkRecord, {cdkId=cdkId})
end

function M.GetBatchIdData(batchId)
    return dbx.find_one(TableNameArr.ServerBatchRecord, {batchId=batchId})
end

function M.CheckBatchIdAndUpdate(args)
    if not args or not args.batchId then
        return false
    end

    local data = dbx.find_one(TableNameArr.ServerBatchRecord, {batchId = args.batchId})
    if data then
        return false
    end
    local addBatchData = {
        batchId = args.batchId,
        cdkName = args.cdkName,
        createAt = os.date("%Y-%m-%d %H:%M:%S"),
        startAt = args.startAt,
        endAt = args.endAt,
        enable = args.enable or false,
        num = args.num or 0
    }
    dbx.add(TableNameArr.ServerBatchRecord, addBatchData)
    return true
end

function M.CreateCDK(args)
    -- args.type = "1" --类型
    -- args.batchId = "" --生成批次 
    -- args.num = 100 --生成次数 
    -- args.cdkId = "" --指定生成1个cdkid
    -- args.startAt = os.time() --有效开始时间
    -- args.endAt = os.time() + 86400 --有效结束时间
    -- args.channel = "all" --渠道
    --args.enable = true, --是否起效
    -- args.rewardList = {}

    --检查批次是否重复
    if not M.CheckBatchIdAndUpdate(args) then
        return RET_VAL.Exists_4
    end

    if args.cdkId and args.cdkId ~= "" then
        if M.GetCdkData(args.cdkId) then --兑换码已经存在
            return RET_VAL.Exists_4
        end

        local cdkId = string.upper(args.cdkId)
        local addData = {
            type = args.type,
            batchId = args.batchId,
            startAt = args.startAt,
            endAt = args.endAt,
            cdkId = cdkId,
            cdkName = args.cdkName,
            channel = args.channel,
            rewardList = args.rewardList,
            userNumN = 0, --新用户领取次数
            userNumO = 0, --老用户领取次数
            userNum = 0, --领取次数
            createAt = os.date("%Y-%m-%d %H:%M:%S"),
            enable = args.enable or false,
            -- information = args,
        }
        -- skynet.logd("CreateCDK::cdkId=[", cdkId, "]")
        dbx.add(TableNameArr.ServerCdkRecord, addData)
    else
        local limit = args.num or 0
        if limit <= 0 then
            skynet.loge("CreateCDK::error, limit=", limit)
            return RET_VAL.ERROR_3
        end

        local cdkId = ""
        skynet.loge("CreateCDK::startAt=", os.date("%Y-%m-%d %H:%M:%S"))
        for i = 1, limit, 1 do
            cdkId = M.Get36Num(tonumber(tostring(100000+i)..os.date("%H%M%m%d%S"))) .. M.Get36Num(math.random(1,1000))
            -- local addData = {cdkId = cdkId, information = args, createAt = os.date("%Y-%m-%d %H:%M:%S")}
            local addData = {
                type = args.type,
                batchId = args.batchId,
                startAt = args.startAt,
                endAt = args.endAt,
                cdkId = cdkId,
                cdkName = args.cdkName,
                channel = args.channel,
                rewardList = args.rewardList,
                userNumN = 0, --新用户领取次数
                userNumO = 0, --老用户领取次数
                userNum = 0, --领取次数
                createAt = os.date("%Y-%m-%d %H:%M:%S"),
                enable = args.enable or false,
                -- information = args,
            }
            -- skynet.logd("CreateCDK::cdkId=[", cdkId, "]")
            dbx.add(TableNameArr.ServerCdkRecord, addData)
        end
        skynet.loge("CreateCDK::endAt=", os.date("%Y-%m-%d %H:%M:%S"))
    end

    return RET_VAL.Succeed_1
end

function M.CDKReward(args)
    if not args then
        return RET_VAL.ERROR_3
    end

    local cdkId = string.upper(args.cdkId or "")
    local uId =  tostring(args.uId)
    local isNew =  args.isNew
    local userChannel =  args.channel

    local cdkData = M.GetCdkData(cdkId)
    if not cdkData then
        return RET_VAL.NotExists_5
    end

    local currentAt = os.time()

    --批次检查
    local batchIdData = M.GetBatchIdData(cdkData.batchId)
    if not batchIdData then
        return RET_VAL.NotExists_5
    end

    if not batchIdData.enable then
        return RET_VAL.Other_10
    end

    --已过期
    if not (currentAt >= batchIdData.startAt and currentAt <= batchIdData.endAt) then
        return RET_VAL.Other_11
    end

    -----------------------add code 检测是否可以领取
    --无效
    if not cdkData.enable then
        return RET_VAL.Other_10
    end

    --已过期
    if not (currentAt >= cdkData.startAt and currentAt <= cdkData.endAt) then
        return RET_VAL.Other_11
    end

    --不是可以领取的渠道
    local validChannel = false
    -- local sChannelList = string.split(cdkData.channel, ";")
    -- local sChannelList = cjson.decode(cdkData.channel)
    -- local sChannelList = cdkData.channel --cjson.decode(cdkData.channel)
    local sChannelList = {}
    if type(cdkData.channel) == "table" then
        sChannelList = cdkData.channel
    else
        sChannelList = cjson.decode(cdkData.channel)
    end
    for _, _channel in pairs(sChannelList) do
        if _channel == userChannel or _channel == "all" then
            validChannel = true
            break
        end
    end

    if not validChannel then
        return RET_VAL.Empty_7
    end

    if cdkData.type == CDRType.Type1 then
        --检查是否已经领取过
        local userData = dbx.find_one(TableNameArr.UserCdkRecord, {cdkId = cdkId})
        if userData then
            return RET_VAL.Other_10
        end

        local userBatchData = dbx.find_one(TableNameArr.UserCdkRecord, {batchId = cdkData.batchId, uId = uId})
        if userBatchData then
            return RET_VAL.Other_12
        end
    elseif cdkData.type == CDRType.Type2 then
        --检查自己是否已经领取过
        local userData = dbx.find_one(TableNameArr.UserCdkRecord, {cdkId = cdkId, uId = uId})
        if userData then
            return RET_VAL.Other_12
        end

        local userBatchData = dbx.find_one(TableNameArr.UserCdkRecord, {batchId = cdkData.batchId, uId = uId})
        if userBatchData then
            return RET_VAL.Other_12
        end
    end

    -----------------------add code 检测是否可以领取

    if isNew then
        local updateData = {userNumN = cdkData.userNumN+1, userNum = cdkData.userNum+1 }
        dbx.update(TableNameArr.ServerCdkRecord, {cdkId = cdkId},  updateData)
    else 
        local updateData = {userNumO = cdkData.userNumO+1, userNum = cdkData.userNum+1 }
        dbx.update(TableNameArr.ServerCdkRecord, {cdkId = cdkId},  updateData)
    end

    local updateData = {rewardNum = (batchIdData.rewardNum or 0) + 1}
    dbx.update(TableNameArr.ServerBatchRecord, {batchId = cdkData.batchId},  updateData)

    local addUserData = {uId = uId, batchId = cdkData.batchId, cdkId = cdkId, channel = userChannel, createAt = os.date("%Y-%m-%d %H:%M:%S")}
    dbx.add(TableNameArr.UserCdkRecord, addUserData)
    return RET_VAL.Succeed_1, cdkData.rewardList
end

--创建cdk
CMD.CreateCDK = function (_, args)
    return M.CreateCDK(args)
end

--领取cdk
CMD.CDKReward = function(_, args) 
    if not args then
        return RET_VAL.ERROR_3
    end
    return M.CDKReward(args)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(source, ...)))
    end)
    ServerData.init()
end)