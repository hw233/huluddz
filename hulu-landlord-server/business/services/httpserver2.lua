local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local cjson = require "cjson"
local table = table
local string = string
local sharetable = require "skynet.sharetable"
local MjHandle = require "game/tools/MjHandle"

local objx = require "objx"
require "table_util"

local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
ServerData.agent = {}
ServerData.order = {}

local mode = ...

function CMD.inject(filePath)
	print("httpserver2 inject ", filePath)
    require(filePath)
    if mode ~= "agent" then
		for _,agent in pairs(ServerData.agent) do
			skynet.send(agent, "lua", "inject", filePath)
		end
    end
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
--斗地主用 做牌设置 2021.9.10 
-- {"cmd":"change_card",
-- "args":{"id_table":["1000001"],
-- "type":"qqp", --七雀牌
-- "card_table":[[1,2,3,5,6,7,9,10,11,13,14,15,4],[66,67,68,69,18,19,20,21,22,23,24,25,26],[27,28,29,30,31,32,33,34,35,36,37,38,39],[40,41,42,43,44,45,46,47,48,49,50,51,52]],

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

	local data = {
		idArr = args.idArr,
		cardDataArr = args.cardDataArr
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
	print("SetRoomCardData =>", table.tostr(datas))
	return ret
end

if mode == "agent" then
	------------------------------------------------------------------------
	-- WEB API START
	------------------------------------------------------------------------
	-- function CMD.wechat_subscribe_in(data)
	-- 	local unionid = assert(data.unionid)
	-- 	local u = skynet.call(get_db_mgr(), "lua", "find_one", "user", {unionid = unionid}, {id = true})
	-- 	if u then
	-- 		if skynet.call(get_db_mgr(), "lua", "find_one", "subscribe_gift", {pid = u.id}) then
	-- 			return {result  = false, e_info = 2}
	-- 		else
	-- 			skynet.call(get_db_mgr(), "lua", "insert", "subscribe_gift", {pid = u.id, time = os.time()})
	-- 			local mail =  {
	--                     title = "关注奖励",
	--                     content = "小礼物奉上, 感谢您对游戏的支持!",
	--                     attachment = {{id = GOODS_GOLD_ID, num = 200000}, {id = GOODS_DIAMOND_ID, num = 50}}
	--                 }
	--             skynet.call("mail_mgr", "lua", "send_mail", u.id, mail)
	--             return {result = true}
	-- 		end
	-- 	else
	-- 		return {result  = false, e_info = 1}
	-- 	end
	-- end


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

	--发送邮件
	--p_id:发送目标
	--title:邮件标题
	--content:邮件内容
	--award:邮件奖励{{id=xx,num=xxx},{id=xx,num=xxx}}
	--mail_type:2:装扮 3:文字邮件(award为空) 4:奖励邮件
	function CMD.send_mail(data)
		local mail =  {
		title = data.title,
		content = data.content,
		attachment = data.award,
		mail_type = MAIL_TYPE_KF,
		mail_stype = data.mail_type,
		-- friend_name = ma_data.db_info.nickname,
		-- friend_head = ma_data.db_info.headimgurl
		}
		skynet.call("mail_mgr", "lua", "send_mail", data.p_id, mail)
	end

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
	--跑马灯，公告
	function CMD.get_horse_lamp()
		return skynet.call("db_mgr_http", "lua", "get_horse_lamp")
	end

	function CMD.add_horse_lamp(data)
		local r = skynet.call("db_mgr_http", "lua", "add_horse_lamp", data.msg)
		return { result = r }
	end

	function CMD.delete_horse_lamp(data)
		skynet.send("db_mgr_http", "lua", "delete_horse_lamp", data.msg_id)
		return { result = true }
	end
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
		local env = skynet.getenv("env")
		env = env or "publish"
		if not (env == "debug" or env == "local")then
			return
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
		local env = skynet.getenv("env")
		env = env or "publish"
		if not (env == "debug" or env == "local" or env == "local_rz") then
			return {false, "only debug local env can use this interface"}
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
	---------------------------------------------------------------------------
	---------------------------------------------------------------------------
	function CMD.response(id, ...)
		local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
		if not ok then
			-- if err == sockethelper.socket_error , that means socket closed.
			skynet.error(string.format("fd = %d, %s", id, err))
		end
	end

	function CMD.handle_socket(id)
		socket.start(id)

		-- limit request body size to 8192 (you can pass nil to unlimit)
		local code, url, _, _, body = httpd.read_request(sockethelper.readfunc(id), 8192)
		if code then
			if code ~= 200 then
				CMD.response(id, code)
			else

				-- local path, query = urllib.parse(url)

				if url ~= '/php.action' and url ~= '/realphp.action'
					and url ~= '/h5php.action' or #body ==0 then
					print('invalid client from:', url)
					socket.close(id)
					return
				end

				if #body ==0 then
					print('invalid client from:', url)
					socket.close(id)
					return
				end

				print("body =>", body)
				local json = cjson.decode(body)
				print('===========handle_socket==============')
				assert(CMD[json.cmd])
				local f = CMD[json.cmd]
				assert(type(json.args) == 'table')

				local rs = f(json.args)

				rs = cjson.encode(rs)

				CMD.response(id, code, rs)
			end
		else
			if url == sockethelper.socket_error then
				skynet.error("socket closed")
			else
				skynet.error(url)
			end
		end
		socket.close(id)
	end

	skynet.start(function()

		skynet.dispatch("lua", function(_, _, command, ...)
			local f = assert(CMD[command])
			skynet.ret(skynet.pack(f(...)))
		end)
	end)

else

	skynet.start(function()

		local httpserver = skynet.self()
		for i= 1, 5 do
			ServerData.agent[i] = skynet.newservice(SERVICE_NAME, "agent", httpserver, i)
		end
		local balance = 1
		local port = skynet.getenv("http_server2_port")
		local fd = socket.listen("0.0.0.0", port)
		skynet.error("Listen web port:" .. port)

		skynet.dispatch("lua", function(_, _, command, ...)
			local f = assert(CMD[command])
			skynet.ret(skynet.pack(f(...)))
		end)

		socket.start(fd , function(id, addr)
			skynet.error(string.format("[%s] %s connected, pass it to agent :%08x",os.date(),addr, ServerData.agent[balance]))
			skynet.send(ServerData.agent[balance], "lua", "handle_socket", id)
			balance = balance + 1
			if balance > #ServerData.agent then
				balance = 1
			end
		end)


		local user_hands = require "config_ddz/user_hands_qqp"
		for _, conf in ipairs(user_hands) do
			CMD.SetRoomCardDataCfg(conf)
		end

	end)

end