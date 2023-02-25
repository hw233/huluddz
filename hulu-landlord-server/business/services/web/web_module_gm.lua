local skynet = require "skynet"
local sharetable = require "skynet.sharetable"

local datax = require "datax"
local objx = require "objx"
local arrayx     = require "arrayx"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local common = require "common_mothed"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name


local cjson = require "cjson"
local httpc = require "http.httpc"
httpc.timeout = 500 -- 超时时间 5s

require "table_util"

return function (CMD, agentMap)
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------

    CMD.TestPay = function (args)
        local yyb_sdk 	= require "sdk.yyb_sdk"
        return yyb_sdk.payGoods(args)
    end

    CMD.UserAgentExit = function (args)
        local ret = {code = 1, msg = "成功"}
        if not args.id or not common.call_useragent(args.id, "exit") then
            ret.code = 3
            ret.msg = "玩家未在线"
        end
        return ret
    end

    -- 做牌设置
    -- "args":{
    -- "idArr":["1000001"],
    -- "type":"3", --七雀牌
    -- "cards":[],
    -- "cardDataArr":[[1,2,3,5,6,7,9,10,11,13,14,15,4],[66,67,68,69,18,19,20,21,22,23,24,25,26],[27,28,29,30,31,32,33,34,35,36,37,38,39],[40,41,42,43,44,45,46,47,48,49,50,51,52]],
    -- "firstId":""

    -- todo 未使用
    -- "wantCard":[[14,4,6],[70,71,72,73,74],[65,66,67,68,69,75],[76,77,78,79,80,81,82]]}}
    -- "banker_chair : 1/2/3/4"
    function CMD.SetRoomCardDataCfg(args)
        local ret = {e_info = 1, tip = "成功"}

        if skynet.getenv("isTest") ~= "1" then
            sharetable.loadtable("RoomCardDataCfg", {})

            ret.e_info = 3
            ret.tip = "测试服才能设置"
            return ret
        end

        if not args.idArr or not args.type or not args.cardDataArr then
            ret.e_info = 3
            ret.tip = "参数错误"
            return ret
        end

        args.idArr = table.where(args.idArr, function (key, value)
            return value ~= ""
        end)

        if args.firstId and #args.firstId > 0 and not arrayx.findVal(args.idArr, args.firstId) then
            ret.e_info = 3
            ret.tip = "设置玩家id中不包含首出id"
            return ret
        end

        local data = {
            idArr = args.idArr,
            cards = arrayx.select(args.cards or {}, function (index, value)
                return math.tointeger(value)
            end),
            cardDataArr = arrayx.select(args.cardDataArr, function (index, arr)
                return arrayx.select(arr, function (index, value)
                    return math.tointeger(value)
                end)
            end),
            firstId = args.firstId
        }
        local datasOld = sharetable.query("RoomCardDataCfg") or {}
        local datas = clone(datasOld)
        for index, id in ipairs(args.idArr) do
            local obj = datas[id]
            if not obj then
                obj = {}
                datas[id] = obj
            end

            obj[args.type] = data
        end

        sharetable.loadtable("RoomCardDataCfg", datas)
        skynet.logd("SetRoomCardData =>", table.tostr(datas))
        return ret
    end

    if skynet.getenv("isTest") == "1" then
        if not sharetable.query("RoomCardDataCfg") then
            skynet.loge("开启测试配牌")
            local user_hands = require "config_ddz/user_hands_qqp"
            for _, conf in ipairs(user_hands) do
                CMD.SetRoomCardDataCfg(conf)
            end
        end
    end

    CMD.SetRoomMatchCfg = function (args)
        local ret = {e_info = 1, tip = "成功"}

        -- args = {
        --     type = 3,
        --     cards = {},
        --     arr = {
        --         {id = "", card = {}, pos = 0}
        --     },
        --     firstId = "",   -- 首出玩家id
        --     isMatch = true, -- 强制匹配到一起
        -- }

        if not args.type or not args.arr or not args.arr[1] or not args.arr[1].card then
            ret.e_info = 3
            ret.tip = "参数错误"
            return ret
        end

        args.type = tonumber(args.type)
        local arr = arrayx.orderBy(args.arr, function (obj)
            return obj.pos or 0
        end)
        args.idArr = arrayx.distinct(arrayx.select(arr, function (index, value)
            return value.id
        end))
        args.cardDataArr = arrayx.select(arr, function (index, value)
            return value.card
        end)

        if #args.idArr ~= GameType.GetGamePlayerNumMax(args.type) then
            ret.e_info = 3
            ret.tip = "参数玩家数量不匹配"
            return ret
        end

        local cardNum = args.type == GameType.SevenSparrow and 7 or 17
        if arrayx.find(arr, function (index, value)
            return #value.card > cardNum
        end) then
            ret.e_info = 3
            ret.tip = "参数玩家配牌数量错误"
            return ret
        end

        local numMax = GameType.GetGamePlayerNumMax(args.type)
        if numMax ~= #args.arr then
            ret.e_info = 3
            ret.tip = "配置对局人数不符"
            return ret
        end

        local ret = CMD.SetRoomCardDataCfg(args)
        if ret.e_info == 1 and args.isMatch then
            local datasOld = sharetable.query("RoomMatchCfg") or {}
            local datas = clone(datasOld)
            for index, id in ipairs(args.idArr) do
                local obj = datas[id]
                if not obj then
                    obj = {}
                    datas[id] = obj
                end
                obj[args.type] = args.idArr
            end
            sharetable.loadtable("RoomMatchCfg", datas)
            skynet.logd("RoomMatchCfg =>", table.tostr(datas))
        end

        return ret
    end

    -- 实际不通过接口这个添加，后台直接写入数据库，但可通过这个接口校验数据格式
    CMD.AddMailGlobal = function (args)
        -- args = {
        --     id = "",
        --     title = "",
        --     contentStr = "",
        --     itemArr = {},
        --     startDt = 0,
        --     endDt = 100,
        --     channelArr:[]
        -- }
        return CMD.AddMail(args, nil, 2)
    end

    CMD.AddMail = function (args, _, _type)
        local ret = {code = 1, msg = "成功"}

        local toId = tostring(args.toId) -- 发送目标
        local title = args.title -- 标题
        local contentStr = args.contentStr -- 内容
        local itemArr = args.itemArr -- 奖励道具

        if not title or not contentStr or not itemArr then
            ret.code = 3
            ret.msg = "缺少参数"
            return ret
        end

        if not _type and not toId then
            if not toId then
                ret.code = 3
                ret.msg = "缺少参数"
                return ret
            end

            if not dbx.get(TableNameArr.User, toId, {_id = false}) then
                ret.code = 3
                ret.msg = "无此用户"
                return ret
            end
        elseif _type == 2 and (
            not args.id or not args.startDt or not args.endDt
        ) then
            -- args.startRegDt  -- 注册开始时间
            -- args.endRegDt    -- 注册结束时间

            ret.code = 3
            ret.msg = "缺少参数"
            return ret
        end

        for index, value in ipairs(itemArr) do
            value.id = tonumber(value.id)
            value.num = tonumber(value.num)

            if not datax.items[value.id] then
                ret.code = 3
                ret.msg = "道具id错误"
                return ret
            end
        end

        local result
        if not _type then
            result = common.addSystemMail(toId, title, "GMAddMail_后台发送", contentStr, itemArr)
        elseif _type == 2 then
            result = true
            if skynet.getenv("env") == "debug" then
                dbx.add(TableNameArr.MailGlobal, args)
            end
        end

        if not result then
            ret.code = 3
            ret.msg = "发送出错"
            return ret
        end

        return ret
    end

    CMD.ItemRemove = function (args)
        local ret = {code = 1, msg = "成功"}

        if not args.uId or not args.id or not args.num then
            ret.code = 3
            ret.msg = "缺少参数"
            return ret
        end

        args.id = tonumber(args.id)
        args.num = tonumber(args.num)
        
        local addr = common.getUserAgent(args.uId)
        if not addr then
            ret.code = 3
            ret.msg = "玩家不在线"
            return ret
        end

        common.removeItem(addr, args.id, args.num, "GmItemRemove_后台删除道具", false, true)

        return ret
    end

    CMD.SetUserField = function (args)
        local ret = {code = 1, msg = "成功"}

        if not args.uId or not args.key or not args.value then
            ret.code = 3
            ret.msg = "缺少参数"
            return ret
        end

        if not common.call_useragent(args.uId, "SetUserField", args.key, args.value) then
            ret.code = 3
            ret.msg = "玩家不在线"
            return ret
        end

        return ret
    end

    CMD.SetUserVipLv = function (args)
        local ret = {code = 1, msg = "成功"}

        if not args.uId or not args.vip then
            ret.code = 3
            ret.msg = "缺少参数"
            return ret
        end
        args.vip = tonumber(args.vip)

        if not common.call_useragent(args.uId, "SetVip", args.vip) then
            ret.code = 3
            ret.msg = "玩家不在线"
            return ret
        end

        return ret
    end

    CMD.SetUserHead = function (args)
        local keyStr = "head"
        args.key = keyStr
        args.value = args[keyStr]

        return CMD.SetUserField(args)
    end

    CMD.SetUserGourdLv = function (args)
        local ret = {code = 1, msg = "成功"}

        local id, lv = args.id, tonumber(args.lv)

        if not id or not lv then
            ret.code = 3
            ret.msg = "参数错误"
            return ret
        end

        if not common.call_useragent(id, "SetUserGourdLv", lv) then
            ret.code = 3
            ret.msg = "玩家未在线"
            return ret
        end

        return ret
    end


    --- 玩法房间人数统计
    ---@param args any
    ---@return table {[1] = {{id = 1, num = 100, playerNum = 3},{id = 2, num = 200, playerNum = 4},}}
    CMD.RoomLobbyInfoGet = function (args)
        return skynet.call("ddz_room_info", "lua", "GetDatas")
    end

    --- 获取活动数据
    ---@return table ret {}
    CMD.GetActCfgData = function ()
        return skynet.call("activity_mgr", "lua", "GetActData")
    end

    --- 配置活动数据
    ---@param args table {datas = {[1] = {id = 1, startDt = 0, endDt = 100, open = true}}}
    ---@return table ret {ret = 是否配置成功, msg = 错误信息}
    CMD.SetActCfgData = function (args)
        local ret, msg = skynet.call("activity_mgr", "lua", "SetCfgData", args.datas)
        return {ret = ret, msg = msg}
    end

    --- 获取游戏功能设置数据
    ---@return table ret {}
    CMD.GetGameFuncCfgData = function ()
        return skynet.call("game_func_mgr", "lua", "GetCfgData")
    end

    --- 配置游戏功能设置数据
    ---@param args table {datas = {[1] = {id = 1, startDt = 0, endDt = 100, open = true, channelCloseArr = {}}}}
    ---@return table ret {code = 错误码, msg = 错误信息}
    CMD.SetGameFuncCfgData = function (args)
        local result, msg = skynet.call("game_func_mgr", "lua", "SetCfgData", args.datas)

        local ret = {code = 1, msg = "成功"}

        if not result then
            ret.code = 3
            ret.msg = msg
        end

        return ret
    end

    CMD.UserPay = function (args)
        local ret = {code = 1, msg = "成功"}

        if skynet.getenv("isTest") ~= "1" then
            ret.code = 3
            ret.msg = "非测试服"
            return ret
        end

        local id, storeId = args.id, math.tointeger(args.storeId)
        local agent = skynet.call("agent_mgr", "lua", "GetPlayerAgent", id)
        if agent then
            local result, obj = skynet.call(agent, "lua", "PayOrderGet", storeId, "Gm")
            if result ~= RET_VAL.Succeed_1 then
                ret.code = 3
                ret.msg = "参数错误"
                return ret
            end

            skynet.sleep(20)

            local status, body = httpc.request("POST", "127.0.0.1:" .. skynet.getenv("http_server_port"), "/game.html", nil, nil, cjson.encode({
                cmd = "PayFinish",
                args = {
                    out_trade_no    = obj.id,
                    -- transaction_id  = obj.transaction_id,
                    -- sandbox         = ""
                }
            }))

            if status ~= 200 then
                ret.code = 3
                ret.msg = "验证错误"
                return ret
            end
            body = cjson.decode(body)
            if body.code ~= 1 then
                ret.code = 2
                ret.msg = body.message
                return ret
            end
            return ret
        else
            ret.code = 3
            ret.msg = "玩家未在线"
            return ret
        end
    end

    -- 跑马灯公告
    CMD.AnnounceSet = function (args)
        local ret = {code = 1, msg = "成功"}

        -- args = {
        --     id = "",
        --     type = 0,            -- 公告类型
        --     content = "",        -- 内容
        --     imgUrl = "",         -- 图片地址
        --     startDt = 0,         -- 开始时间
        --     endDt = 1,           -- 结束时间
        --     sortVal = 1,         -- 排序字段
        --     intervalMinute = 1,  -- 间隔
        -- }

        if not args.type or not args.content or not args.startDt or not args.endDt or not args.intervalMinute or not args.sortVal then
            ret.code = 3
            ret.msg = "缺少参数"
            return ret
        end

        if #args.content > 300 then
            ret.code = 3
            ret.msg = "不可超过300字符"
            return ret
        end

        args.type = tonumber(args.type)
        args.startDt = tonumber(args.startDt)
        args.endDt = tonumber(args.endDt)
        args.sortVal = tonumber(args.sortVal)
        args.intervalMinute = tonumber(args.intervalMinute)

        if not table.first(AnnounceType, function (key, value)
            return value == args.type
        end) then
            ret.code = 3
            ret.msg = "类型错误"
            return ret
        end

        local obj = skynet.call("server_announce", "lua", "Set", args)

        if not obj then
            ret.code = 3
            ret.msg = "不可修改类型"
            return ret
        end

        ret.id = obj.id
        return ret
    end

    CMD.AnnounceGet = function (args)
        return skynet.call("server_announce", "lua", "Get", args.type)
    end

    CMD.AnnounceDelete = function (args)
        local ret = {code = 1, msg = "成功"}

        if not args.id then
            ret.code = 3
            ret.msg = "缺少参数"
            return ret
        end

        skynet.call("server_announce", "lua", "Delete", args.id)

        ret.id = args.id
        return ret
    end

    CMD.CreateCDK = function (args)
        local ret = {code = 1, msg = "成功"}

        if not args then
            ret.code = 3
            ret.msg = "缺少参数"
            return ret
        end

        ret.code = skynet.call("cdk", "lua", "CreateCDK", args)
        if ret.code ~= 1 then 
            ret.msg = "失败"
        end
        
        return ret
    end


    --------------------------------------------------------------

    function CMD.remind_new_mail(data)
        local agent = skynet.call("agent_mgr", "lua", "GetPlayerAgent", data.p_id)
        pcall(skynet.call, agent, "lua", "admin_have_new_mail")
        return {ok = true}
    end

    function CMD.change_entity(data)
        print('===============兑换话费=====================')
        local currEntity = skynet.call(get_db_mgr(), "lua", "find_one", COLL.ENTITY, {id = data.e_id})
        table.print(currEntity)
        currEntity.received = data.e_received
        local overTime = os.time()
        skynet.call(get_db_mgr(), "lua", "update", COLL.ENTITY, {id = data.e_id},{received = data.e_received,
            overTime = overTime,submit_userId = data.submit_userId,phoneNum = data.phoneNum})
        local agent = skynet.call("agent_mgr", "lua", "GetPlayerAgent", data.p_id)
        table.print(currEntity)
        pcall(skynet.call, agent, "lua", "admin_change_entity",currEntity)
        return {ok = true}
    end

    --封禁玩家
    --p_id:玩家id
    --forbidTime:封禁到的时间(utc)
    --forbid_reason:封号理由
    function CMD.set_player_forbid(data)
        local agent = skynet.call("agent_mgr", "lua", "GetPlayerAgent", data.p_id)
        if agent and pcall(skynet.call, agent, "lua", "admin_set_player_forbid", data.forbidTime, data.forbid_reason,
                                                                                data.forbidBeginTime,data.forbidUserid,
                                                                                data.forbidUserName) then
            -- pass
        else
            skynet.call(get_db_mgr(), "lua", "update", "user", {id = data.p_id}, {forbid_time = data.forbidTime,
                                                                                forbid_reason = data.forbid_reason,
                                                                                forbidBeginTime = data.forbidBeginTime,
                                                                                forbidUserid = data.forbidUserid,
                                                                                forbidUserName = data.forbidUserName
                                                                                    })
        end
        skynet.call('ranklist_mgr', "lua", "delete_forbid_player",data.p_id)
        skynet.call('rank_two_mgr', "lua", "delete_forbid_player",data.p_id)
        return {ok = true}
    end

    --标记玩家------0或空为未标记，1为内部玩家，2为目标玩家,3为封禁排行榜玩家
    function CMD.set_player_markNum(data)
        local agent = skynet.call("agent_mgr", "lua", "GetPlayerAgent", data.p_id)
        if agent and pcall(skynet.call, agent, "lua", "admin_set_player_markNum", data.markNum) then
            if data.markNum == 2 then
                skynet.call("agent_mgr", "lua", "add_markNum", data.p_id)
            end
        else
            skynet.call(get_db_mgr(), "lua", "update", "user", {id = data.p_id}, {markNum = data.markNum})
        end
        if data.markNum == 3 then
            skynet.call('ranklist_mgr', "lua", "delete_forbid_player",data.p_id)
            skynet.call('rank_two_mgr', "lua", "delete_forbid_player",data.p_id)
        end
        return {ok = true}
    end
    --获取标记的在线玩家
    function CMD.getOnlineMarkP()
        return skynet.call("agent_mgr", "lua", "getOnlineMarkPlayers")
    end
    --设置玩家头像无效
    --p_id:玩家id
    --invalid_headimg:头像是否无效
    function CMD.set_player_invalid_headimg(data)
        local agent = skynet.call("agent_mgr", "lua", "GetPlayerAgent", data.p_id)
        if agent and pcall(skynet.call, agent, "lua", "admin_set_player_invalid_headimg", data.invalid_headimg) then
            -- pass
        else
            skynet.call(get_db_mgr(), "lua", "update", "user", {id = data.p_id}, {invalid_headimg = data.invalid_headimg})
        end
        return {ok = true}
    end

    -- function CMD.update_user_gold(data)
    -- 	local ok, err = skynet.call("agent_mgr", "lua", "admin_update_user_gold", data.p_id, data.num)
    -- 	return {ok = ok, err = err}
    -- end

    -- function CMD.update_user_diamond(data)
    -- 	local ok, err = skynet.call("agent_mgr", "lua", "admin_update_user_diamond", data.p_id, data.num)
    -- 	return {ok = ok, err = err}
    -- end

    function CMD.online_count()
        return {num = skynet.call("agent_mgr", "lua", "GetPlayerOnlineNum")}
    end

    ------------------------------------------------------------
    --运营埋点
    function CMD.get_operation()
        return skynet.call("pay_info_mgr", "lua", "get_operation_info")
    end
    ------------------------------------------------------------
    --head:开头字母
    --award:奖励内容
    --num:生成数量
    --get_num:每条cdk最多领取多少次
    --ret:false 失败 true 成功
    function CMD.generate_cdk(data)
        local ret = skynet.call("cdk_mgr","lua","generate_cdk",data.head,data.award,data.num,data.get_num)
        return {ret = ret}
    end


    --公众号绑定
    function CMD.binding_xixi(data)
        print('================公众号绑定============',data)
        table.print(data)
        if data.result then
            local userInfo = skynet.call(get_db_mgr(), "lua", "find_one", "user", {id = data.pid}, {binding_xixi = true})
            if userInfo and not userInfo.binding_xixi then
                local mail =  {
                            title = "公众号关注奖励",
                            content = "您已成功关注游戏公众号，特为您献上关注礼包，请查收。",
                            attachment = {{id = 100001, num = 10},{id = 100000,num = 2000},{id = 100005,num = 5}},
                            mail_type = MAIL_TYPE_OTHER,
                            mail_stype = MAIL_STYPE_AWARD,
                        }
                skynet.call("mail_mgr", "lua", "send_mail", data.pid, mail)
                skynet.call(get_db_mgr(), "lua", "update", "user", {id = data.pid}, {binding_xixi = true})
                local agent = skynet.call("agent_mgr", "lua", "GetPlayerAgent", data.pid)
                if agent then
                    pcall(skynet.call, agent, "lua", "admin_binding_xixi", data.result)
                end
                return {ret = true}
            end
            return {ret = false}
        end
        return {ret = false}
    end

    -- -- 获取版本
    -- function CMD.version(data)
    -- 	local body = cjson.encode {
    -- 	    cmd = "game_version",
    -- 	    args = {
    -- 	        gameid = skynet.getenv "gameid",
    -- 	        platform = data.platform
    -- 	    }
    -- 	}
    -- 	local status, res = httpc.request("POST", "47.105.78.85:9000", '/public.action', nil, nil, body)
    -- 	if status == 200 then
    -- 		local version = cjson.decode(res)
    -- 		version._id = nil
    -- 		version.platform = nil
    -- 		version.ok = true

    -- 		table.print(version)
    -- 		return version
    -- 	else
    -- 		return {ok = false}
    -- 	end
    -- end

    -- 外公告
    -- function CMD.notice(data)

    -- 	local body = cjson.encode {
    -- 		cmd = "notice",
    -- 		args = {
    -- 			gameid = skynet.getenv "gameid"
    -- 		}
    -- 	}

    -- 	local status, res = httpc.request("POST", "47.105.78.85:9000", '/public.action', nil, nil, body)

    -- 	if status == 200 then
    -- 		return cjson.decode(res)
    -- 	else
    -- 		return {}
    -- 	end
    -- end

    --------------------------------------------------------------------------------------------------
    -- 定时关闭服务器
    -- function CMD.timing_shutdown(data)
    -- 	-- get_services_mgr()
    -- 	local result = skynet.call("services_mgr", "lua", "timing_shutdown", data.start_time,data.time,data.forbid_time,data.msg)
    -- 	-- local result = services_mgr.req.timing_shutdown(self.start_time,self.time,self.forbid_time,self.msg)
    -- 	return {result = result}
    -- end

    -- -- 获取所有定时关服任务
    -- function CMD.all_timing_task()
    -- 	return skynet.call("services_mgr", "lua", "get_all_timing_task")
    -- end

    -- -- 停止所有任务
    -- function CMD.stop_all_timing_task()
    -- 	skynet.send("services_mgr", "lua", "stop_all_timing_task")
    -- 	return {result = true}
    -- end

    -- -- 停止某个定时任务
    -- function CMD.stop_timing_task(data)
    -- 	skynet.send("services_mgr", "lua", "stop_timing_task", data.t_id)
    -- 	return {result = true}
    -- end

    -- 提示更新数据
    function CMD.update_active_info()
        skynet.send("active_mgr", "lua", "update_active_info")
        return {result = true}
    end

    --获取房间在线信息
    function CMD.get_room_info()
        return skynet.call("game_info_mgr","lua","get_room_info")
    end

    --获取房间玩家在线信息
    --data.gameid 房间类型id
    --data.placeid 房间关卡id(免费,平民,巨富等)
    function  CMD.get_room_players_info(data)
        table.print(data)
        return skynet.call("game_info_mgr","lua","get_room_players_info",data.gameid,data.placeid)
    end

    --获取视频信息
    function  CMD.get_ad_info()
        local temptbl = skynet.call("game_info_mgr","lua","get_ad_info")
        return temptbl
    end
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    --设置玩家限制
    function CMD.setMarkMatchNum(data)
        skynet.call("matching_mgr", "lua", "setMarkMatchNum", data.num)
        return {ok = true}
    end

    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    --重置玩家vip数据
    function CMD.reset_vip_data(args)
        local env = skynet.getenv("env")
        env = env or "publish"
        if not (env == "debug" or env == "local")then
            return
        end
        local nid = args.pid
        local agent = skynet.call("agent_mgr", "lua", "find_agent", nid)
        if agent then
            ma = "ma_data"
            interface = "reset_vip"
            return skynet.call(agent, "lua", "ma_interface_test", 
                ma, interface)
        end
        return "reset_vip_data  failed  agent error!"
    end

    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    --修改玩家金币接口
    function CMD.update_user_gold(args)
        local env = skynet.getenv("env")
        env = env or "publish"
        if not (env == "debug" or env == "local")then
            return
        end
        local nid = args.p_id
        local now_gold = args.num
        local agent = skynet.call("agent_mgr", "lua", "find_agent", nid)
        if agent then
            ma = "ma_data"
            interface = "update_gold"
            return skynet.call(agent, "lua", "ma_interface_test", 
                ma, interface, now_gold, GOLD_HTTP_ADMIN, 
                "http.update_user_gold")
        end
        return "update_gold  failed  agent error!"
    end

    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    --结束游戏接口
    function CMD.end_game(args)
        local env = skynet.getenv("env")
        env = env or "publish"
        if not (env == "debug" or env == "local")then
            return
        end
        table.print("end_game in args =>", args)
        local numid = args.numid
        local agent = skynet.call("agent_mgr", "lua", "find_agent", numid)
        if agent then
            local room = skynet.call(agent, "lua", "get_room")
            if room then
                print("room=", room)
                local pack = args.pack
                skynet.send(room, "lua", "end_game", pack)
                return {result = true, msg = "Success"}
            end
            return {result = false, msg = "Get room error"}
        end
        return  {result = false, msg = "Get agent error"}
    end
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    --接口测试用接口
    function CMD.interface_test(args)
        if skynet.getenv("isTest") ~= "1" then
            return {false, "测试服才可使用"}
        end

        table.print("interface_test in args =>", args)
        local service 	= args.service
        local interface = args.interface
        local arglist   = args.arglist
        local ret = table.pack(skynet.call(service, "lua", interface, table.unpack(arglist)))
        print("ret=", table.unpack(ret))
    end

    -- usercmd 610 ma 通用测试接口
    function CMD.ma_usercmd(args)
        if skynet.getenv("isTest") ~= "1" then
            return {false, "测试服才可使用"}
        end

        table.print("ma_usercmd in args =>", args)
        local interface = args.interface
        local pid 		= args.pid
        local arglist   = args.arglist
        local agent = skynet.call("agent_mgr", "lua", "GetPlayerAgent", pid)
        if agent then
            print("agent=", agent, ";interface=", interface)
            return skynet.call(agent, "lua", "UserCmd", interface, arglist)
        else
            return {false, "not find agent"}
        end
    end


    function CMD.ma_interface_test(args)
        local env = skynet.getenv("env")
        env = env or "publish"
        if not (env == "debug" or env == "local")then
            return false, "only debug local env can use this interface"
        end
        table.print("ma_interface_test in args =>", args)
        local ma 		= args.ma
        local interface = args.interface
        local nid 		= args.nid
        local arglist   = args.arglist
        local agent = skynet.call("agent_mgr", "lua", "find_agent", nid)
        if agent then
            print("agent=", agent, ";ma=", ma, ";interface=", interface)
            return skynet.call(agent, "lua", "ma_interface_test", ma, interface, table.unpack(arglist))
        else
            return false, "not find agent"
        end
    end

    function CMD.test_protocol(args)
        local env = skynet.getenv("env")
        env = env or "publish"
        if not (env == "debug" or env == "local")then
            return false, "only debug local env can use this interface"
        end
        local nid 			= args.nid
        local message_name 	= args.message_name
        local tbl 			= args.tbl
        local agent = skynet.call("agent_mgr", "lua", "find_agent", nid)
        if agent then
            print("agent=", agent, ";message_name=", message_name, ";tbl=", table.tostr(tbl))
            return skynet.call(agent, "lua", "send_push", message_name, tbl)
        else
            return false, "not find agent"
        end
    end

    --单元测试 UnitTest
    --特殊发牌 好牌开局 2021 by qc
    function CMD.GoodHands2021(args)	
        local luck_ct = args.luck_ct
        local hand1,hand2,hand3,hand4
        local wall2list = MjHandle:GetWall2ListNew()
        local ret ={
            {name ="==好牌结果1=="},
            {name ="==好牌结果2=="},
            {name ="==好牌结果3=="},
            {name ="==好牌结果4=="},
            {name ="==剩余临时牌堆=="}}

        print('===============好牌开局2021===============',luck_ct)

        local type = MjHandle:GetGoodHandByCt(luck_ct)
        ret[1].type = type
        ret[1].hands,wall2list = MjHandle:GetGoodHandByType(type,wall2list)
        
        type = MjHandle:GetGoodHandByCt(luck_ct)
        ret[2].type = type
        ret[2].hands,wall2list = MjHandle:GetGoodHandByType(type,wall2list)

        type = MjHandle:GetGoodHandByCt(luck_ct)
        ret[3].type = type
        ret[3].hands,wall2list = MjHandle:GetGoodHandByType(type,wall2list)
        
        type = MjHandle:GetGoodHandByCt(luck_ct)
        ret[4].type = type
        ret[4].hands,wall2list = MjHandle:GetGoodHandByType(type,wall2list)

        ret[5].walls = wall2list

        ret.allcount = #ret[1].hands + #ret[2].hands + #ret[3].hands + #ret[4].hands
        ret.allcount = ret.allcount + #ret[5].walls[1] + #ret[5].walls[2] + #ret[5].walls[3] + #ret[5].walls[4]
        return {data = ret}
    end



    --单元测试 UnitTest
    --特殊发牌 --todo
    function CMD.pick_cards_test(args)	
        local pid =args.id
        local agent = skynet.call("agent_mgr", "lua", "find_agent", numid)
        if agent then
        end
    end

    local XlmjHandle = require "game/tools/XlmjHandle"
    --单元测试 测试换三张算法
    --特殊发牌 --todo
    function CMD.exchange3(args)	
        local hand =args.cards
        local my_real_card = XlmjHandle:GetExchangeCards2021(hand,3)
        return {my_real_card = my_real_card}
    end

    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    --紧急走马灯
    function CMD.toNotice_marquee (args)
        local id = args.id
        print("id=", id)
        local r, msg = skynet.call("services_mgr", "lua", "emergencyNotice", id)
        if r then
            return { result = true, msg = "Success" }
        end
        return { result = false, msg = msg }
    end
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    --设置玩家为无效玩家
    function CMD.disable_user(args)
        local id = args.pid
        local r, msg = skynet.call(get_db_mgr(), "lua", "disable_user", id)
        if r then
            return { result = true, msg = "Success" }
        end
        return { result = false, msg = msg }
    end
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------

    function CMD.pause_game(args)
        local env = skynet.getenv("env")
        env = env or "publish"
        if not (env == "debug" or env == "local")then
            return
        end
        table.print("pause_game in args =>", args)
        local numid = args.numid
        local agent = skynet.call("agent_mgr", "lua", "find_agent", numid)
        if agent then
            local room = skynet.call(agent, "lua", "get_room")
            if room then
                print("room=", room)
                local pack = args.pack
                skynet.send(room, "lua", "pause_game", pack)
                return {result = true, msg = "Success"}
            end
            return {result = false, msg = "Get room error"}
        end
        return  {result = false, msg = "Get agent error"}
    end


    --牌桌上所有玩家推牌
    function CMD.push_cards(args)
        local env = skynet.getenv("env")
        env = env or "publish"
        if not (env == "debug" or env == "local")then
            return
        end
        table.print("push_cards in args =>", args)
        local numid = args.numid
        local agent = skynet.call("agent_mgr", "lua", "find_agent", numid)
        if agent then
            local room = skynet.call(agent, "lua", "get_room")
            if room then
                print("room=", room)
                local pack = args.pack
                skynet.send(room, "lua", "push_cards", pack)
                return {result = true, msg = "Success"}
            end
            return {result = false, msg = "Get room error"}
        end
        return  {result = false, msg = "Get agent error"}
    end

    
end