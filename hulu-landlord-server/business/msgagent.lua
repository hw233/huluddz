local skynet = require "skynet"
local sharetable = require "skynet.sharetable"
local datacenter = require "skynet.datacenter"

local mode = ...
local istcp = not mode or mode == "tcp"

local protoloader = istcp and require "sprotoloader" or require "xy_pb"
-- local linuxtime = require "linuxtime"
-- local PushQueue = require "PushQueue"
local queue = require "skynet.queue"
local cs
local mc = require "skynet.multicast"
local timer = require "timer"
local inspect = require "base.inspect"
local eventx = require "eventx"
local create_dbx = require "dbx"
local ma_user = require "ma_user"

local dbx = create_dbx(get_db_manager)

require "define"

local COLL_Name = require "config/collections"
local TableNameArr = COLL_Name

local xy_cmd 				= require "xy_cmd"
local ma_data 				= require "ma_data"
local ma_common 			= require "ma_common"
--local ma_pushmsg 			= require "ma_pushmsg"			  --
local ma_user_ddz 			= require "ma_user_ddz"
local ma_usertime 			= require "ma_usertime"

-- local ma_hall 				= require "ma_hall"               -- 游戏大厅相关请求
-- local ma_hall_store 		= require "ma_hall_store"         -- 商城相关
-- local ma_room_match 		= require "ma_room_match"         -- 房间匹配
local ma_realname  			= require "ma_realname"


local host, send_request, unpack_msg


xy_cmd.REQUEST 		= {}
xy_cmd.CMD 	   		= {}
xy_cmd.REQUEST_New 	= {}

local REQUEST = xy_cmd.REQUEST
local CMD = xy_cmd.CMD
-- 另一种形式的接口
-- 此类接口约定 proto 协议中必须包含 e_info 字段
-- 如果接口方法返回的是 table，则直接将此 table 发送给客户端
-- 如果接口方法返回的是 number, 则会创建一个包含 e_info 字段的 table，并将返回数值赋值给 e_info 字段后再将此 table 发送到客户端
-- 如果接口方法的第一个类型为 number， 第二个值类型为 table，会在在第二个值上将第一个参数值赋值给 e_info 字段，然会将此 table 发送到客户端
local REQUEST_New = xy_cmd.REQUEST_New



local function create_sender()
	local msgqueue = {}	-- 发送队列
	local self = {}
	function self.send(pack, need_reqpeat)
		if need_reqpeat then
			table.insert(msgqueue, pack)
		else
			if ma_data.userInfo.online then
				skynet.send(ma_data.gate, "lua", "send_push", ma_data.fd, pack)
			else
				skynet.logw("msg miss!")
			end
		end
		while #msgqueue > 0 do
			local ok = true
			if ma_data.userInfo.online then
				msgqueue = {}
			else
				ok = skynet.send(ma_data.gate, "lua", "send_push", ma_data.fd, msgqueue[1])
			end
			if ok then
				table.remove(msgqueue, 1)
			else
				return
			end
		end
	end

	return self
end

local function log_transport(action, name, tbl)
	if name ~= "heartbeat" then
		local options = {}
		options.newline = ""
		options.indent = " "
		local str = inspect(tbl, options)
		print(action .. " message nid =", ma_data.my_id, "message =", name, ";tbl =", str)
	end
end

local needCallCmd = {
	buy_suc = true,
	sync_goods = true,
	sign = true,
	seven_sign = true,
	get_intAward_award = true,
	receive_dailytask_reward = true,
	video_ad_report_1 = true,
	updateWealthGod = true,
	time_down = true,
}

--最终发包 pack		返回直接走这个发送
local function send_package(pack, name)
	local package =  istcp and string.pack(">s2", pack) or pack
	ma_data.sender.send(package, needCallCmd[name])
end

local function init_module()
	if ma_data.sender then
		return
	end
	ma_data.sender = create_sender()
	-- ma_data.send_push = function (name, args)
	-- 	if not ma_data.isLoginEnd then
	-- 		skynet.logd("====not serverToClient====", name, table.tostr(args))
	-- 		return
	-- 	end

	-- 	skynet.logd("====serverToClient====", name, table.tostr(args))
	-- 	local pack = send_request(name, args)
	-- 	send_package(pack, name)
	-- end

	ma_data.send_push = function (name, param, isSure)
		if ma_data.isLoginEnd then
			if not ma_data.userInfo.online then
				ma_data.msgQueueOfflineToClient = ma_data.msgQueueOfflineToClient or {}
				table.insert(ma_data.msgQueueOfflineToClient, {name = name, param = param})
			else
				skynet.logd("====serverToClient====", ma_data.my_id, name, table.tostr(param))
				local pack = send_request(name, param)
				send_package(pack)
			end
		elseif isSure then
			table.insert(ma_data.msgQueueToClient, {name = name, param = param})
		else
			skynet.logd("====not serverToClient====", ma_data.my_id, name, table.tostr(param))
		end
	end

	ma_data.sendMsgQueue = function (msgQueue)
		if not msgQueue or not next(msgQueue) then
			return
		end

		local len = #msgQueue
		for i = 1, len do
			local obj = msgQueue[i]
			if obj then
				if obj.name then
					ma_data.send_push(obj.name, obj.param)
				end
				obj.name = nil
				table.remove(msgQueue, 1)
			end
		end
	end

	ma_user_ddz.init(REQUEST, CMD, REQUEST_New)
	-- ma_hall.init(REQUEST,CMD)
	-- ma_room_match.init(REQUEST,CMD)
	-- ma_realname.init(REQUEST,CMD)
end

--初始化广播
local channels = {}
local function init_multicast()
    do
		if channels.conf_update then
			return
		end
		local channel = datacenter.get("channels", "conf_update")
		local channel = mc.new {
			channel = channel,
			dispatch = function (channel, source, ...)
				print("channel =>", channel, "; source=>", source, ";... =>", ...)
				CMD.conf_update(...)
			end,
		}
		channel:subscribe()
		channels.conf_update = channel
    end
end

function CMD.gen_si()
	ma_data.gen_si_count = ma_data.gen_si_count or 0
	ma_data.gen_si_count = ma_data.gen_si_count + 1

	if ma_data.gen_si_count % 2 ~= 0 then
		-- 12 位 + 10 位随机 +10 位id(不足前位补0)
		ma_data.rn_si = string.format("%d",(skynet.time()*100))
		.. math.random(1000000000,9999999999)
		.. string.rep("0",10 - #ma_data.my_id)..ma_data.my_id
	end

	return ma_data.rn_si
end
-- 上报玩家下线,上线
-- status  0 下线; 1上线
function CMD.push_loginout(status)
	if ma_realname.ignore_channel() then
        return
    end

    -- 认证中玩家不需要上报数据
    if ma_data.db_info.rn_status == 1 then
        return
    end

	local args = {
		bt = status
	}

	local leave = status == 0

	if leave then -- 下线
		args.ot = ma_data.userInfo.offlineDt
	end

	ma_realname.update_online_time(leave)

	args.ot = args.ot or os.time()
	args.si = CMD.gen_si()
	-- 0：已认证通过用户. 2：游客用户
	args.ct = ma_data.db_info.rn_pi and 0 or 2
	if args.ct == 0 then
		args.pi = ma_data.db_info.rn_pi
	else
		args.di = ma_data.my_id
	end

	skynet.call("rn_auth_mgr","lua","push_loginout",args)
end

----- CMD api start (处理skynet其他服务消息)----------------------------------

-- 设置日活跃数据
function CMD.set_active_user_num(last_time)
	if not check_same_day(last_time) then
		-- agent_mgr.post.set_active_user_num()
		skynet.send("agent_mgr", "lua", "set_active_user_num")
		-- cluster.send("agent_mgr", "agent_mgr", "lua", "set_active_user_num")
	end
end

function CMD.reg_ip(ip)
	if ma_data.db_info.loginTime == 1 and ma_data.db_info.os == "ios" then
		skynet.fork(function()
			skynet.sleep(50)
			local channel = skynet.call("httpclient", "lua", "reg_ip", ip)
			if channel and ((ma_data.db_info.channel or "") ~= "duoyou_ios") then
				ma_data.db_info.channel = channel
				dbx.update(TableNameArr.User, ma_data.my_id, {channel = channel})
			end
			skynet.send("cd_collecter", "lua", "register", ma_data.db_info.channel)
		end)
	end
end

function CMD.initHeartbeat()
	ma_data.heartcount = 5
	if ma_data.hearbeat_invoke then
		ma_data.hearbeat_invoke()
	end
	ma_data.hearbeat_invoke = timer.create(100, function ()
		ma_data.heartcount = ma_data.heartcount - 1
		if ma_data.heartcount == -10 and ma_data.userInfo.online then
			print("====debug qc==== user break line  ",ma_data.my_id, ma_data.my_room)
			if ma_data.my_room then
				skynet.send("agent_mgr", "lua", "userafk", ma_data.my_id, ma_data.my_room)
			end
		end

		-- 实名认证,运行上报数据延迟 180s 因此玩家离线1分钟后上报
		if ma_data.heartcount < -60 and not ma_data.yet_push_out then
			ma_data.yet_push_out = true -- 上报下标识
			CMD.push_loginout(0) -- 0 表示下线
		end

		local userInfo = ma_data.userInfo
		if ma_data.heartcount < -5 * 60 and (userInfo and not userInfo.roomAddr) then
			print("nid = ", ma_data.my_id, " heartbeat out time.")
			ma_data.hearbeat_invoke()
			CMD.exit()
		end
	end, -1)
end

local op2num = {
	update = 0,
	del = 1,
	add = 2,
}

local function judge_op(before, after)
	if before then
		if after then
			return "update"
		else
			return "del"
		end
	else
		return "add"
	end
end

function CMD.conf_update(...)
	local tbl2ma = ma_data.tbl2ma or {}
	local tbl_name, diff, before, after = ...
	local ma_list = tbl2ma[tbl_name]
	for _, ma in ipairs(ma_list) do
		if ma and ma.on_conf_update(tbl_name) then
			ma:on_conf_update(tbl_name)
		end
	end
	for key, df in pairs(diff) do
		print("before value =>", table.tostr(before[key]))
		print("after value =>", table.tostr(after[key]))
		local op = judge_op(before[key], after[key])
		local msg_tbl = {
			activity = after[key] or before[key],
			op = op2num[op]
		}
		print("conf_update msg_tbl =>", table.tostr(msg_tbl))
		ma_data.send_push("activity_state_update", msg_tbl)
	end
end

--2v2 相关player数据对外接口----
--取得gold
function CMD.get_db_gold(source)
	if ma_data.db_info then
		return ma_data.db_info.gold
	end
	return 0
end

function CMD.get_player_info(source,placeid,gameid,place_type)
	if ma_room_match then
		local player = ma_room_match.get_player_info(placeid,gameid,place_type)
		ma_room_match.set_matching(true)
		return player
	end
	return nil
end

function CMD.remove_matching2v2(source,teamid)
	print("====debug qc==== team2v2_set_match 取消匹配了",ma_data.my_id,teamid)
	local result = skynet.call('matching_mgr',"lua","remove_matching",ma_data.my_id)
	ma_room_match.clear_match_time()
    if result then
        ma_room_match.set_matching(false)
    end
end


-- 玩家登陆
--function CMD.login(source, uid, sid, secret, ip, token, sdk, osv, session_key, fd)
function CMD.login(source, uid, param, fd)
	local subid, ip, sdk, osv, session_key = param.subid, param.ip, param.sdk, param.os, param.session_key
	skynet.logd("msgagemt.login start source =>", source, "uid => ", uid, ";subid => ", subid, ";session_key => ", session_key, ";fd =>", fd)

	ma_data.gate = source
	ma_data.fd = fd
	ma_data.session_key = session_key
	ma_data.userid = uid
	ma_data.subid = subid
	ma_data.ip = ip

	ma_data.msgQueueOfflineToClient = nil
	--ma_data.msgQueueToClient = {}

	ma_data.isLoginEnd = false
	ma_data.roomConnect = false

	ma_data.reconnectTime = 0
	ma_data.server_will_shutdown, ma_data.forbid_create_room = skynet.call("agent_mgr", "lua", "get_server_shutdown")

	CMD.initHeartbeat()

	if ma_data.isLogin then
		skynet.loge("CMD.login")
	end
	ma_data.isLogin = true

	local user
	local base = {sdk = sdk, os = osv}
	if string.sub(uid,1,1) == '?' or string.sub(uid,1,1) == '@' then
		ma_data.my_id = uid
		user = skynet.call(get_db_mgr(), "lua", "GetUserInfoData", uid, base)
	else
		-- TODO：这里是旧的微信登录区分，没什么差别啊？
		user = skynet.call(get_db_mgr(), "lua", "GetUserInfoData", uid, base)
		-- CMD.set_active_user_num(user.onLineDt)
	end
	if not user then
		skynet.loge("login error ", uid)
	end
	if not ma_data._userInfo then
		ma_data._userInfo = user
	else
		table.merge(ma_data._userInfo, user)	-- 存在userInfo上无需保存的数据需要保留
	end
	ma_data.my_id = user.id
	-- ma_data.sameDay = check_same_day(user.onLineDt)

	local currTime = os.time()
	-- 这里是限制登录？
	if user.forbid_time and user.forbid_time > currTime then
		skynet.fork(function()
			skynet.sleep(1)
			CMD.logout()
		end)
		return user.forbid_time
	end

	init_module()

	CMD._loginHander(source, fd, ip, currTime)

	-- CMD.reg_ip(ip)

	skynet.send("agent_mgr", "lua", "PlayerLogin", ma_data.my_id, ma_data.my_agent, user.markNum or 0)
	init_multicast()

	skynet.fork(function()
		skynet.sleep(100)
		CMD.push_loginout(1) -- 防沉迷系统 1 表示 上线
	end)

	ma_common.pushCollecter("UserLogin", currTime)
	
	--测试服务端s2c心跳
	-- skynet.fork(function()
	-- 	while true do
	-- 		ma_data.send_push('s2c_heartbeat')
	-- 		skynet.sleep(500)
	-- 	end
	-- end)
	skynet.logd("msgagemt.login end uid => ", uid, ";subid => ", subid, ";id => ", user.id)
end

CMD.reconnect = function (source, fd)
	ma_data.gate = source
	ma_data.fd = fd

	CMD._loginHander(source, fd)

	ma_data.sendMsgQueue(ma_data.msgQueueOfflineToClient)

	ma_data.heartcount = 5
end

CMD._loginHander = function (source, fd, ip, currTime)
	local user = ma_data.userInfo

	user.ip = user.ip or ip
	user.ipRegister = user.ipRegister or ip
	user.ipLast = ip or user.ipLast
	user.online = true
	user.onLineDt = currTime or os.time()
	user.loginTime = (user.loginTime or 0) + 1

	if user.loginTime == 1 then
		ma_common.pushCollecter("UserNew", user.firstLoginDt)
	end

	dbx.update(TableNameArr.User, user.id, {
		ip = user.ip,
		ipRegister = user.ipRegister,
		ipLast = user.ipLast,
		online = user.online,
		onlineDt = user.onlineDt,
		loginTime = user.loginTime
	})

	eventx.call(EventxEnum.UserOnline)
	ma_usertime.check()

	ma_common.updateUserBase(user.id, {online = user.online})
end

function CMD.send_push(source, ...)
	ma_data.send_push(...)
end


function CMD.get_room()
	return ma_data.my_room
end

function CMD.close( )
	if ma_data.gate then
		skynet.call(ma_data.gate, "lua", "close_msgserver", ma_data.userid, ma_data.subid)
	end
end

-- 玩家离线
function CMD.afk(source)
	-- the connection is broken, but the user may back
	skynet.logd("msgagemt.afk start source => ", source, ";uid => ", ma_data.my_id)

	local currTime = os.time()
	local user = ma_data.userInfo
	if user then
		user.online = false
		user.offlineDt = currTime

		dbx.update(TableNameArr.User, user.id, {
			online = user.online,
			offlineDt = user.offlineDt
		})
	end

	-- local res = skynet.call("matching_mgr", "lua", "userafk", ma_data.my_id)
	-- if res then
	-- 	ma_room_match.set_matching(false)
	-- end

	if ma_data.my_room then
		skynet.send("agent_mgr", "lua", "userafk", ma_data.my_id, ma_data.my_room)
	end

	--退出当前2v2队伍
	--skynet.call("team2v2_mgr", "lua", "Leave_team2v2", ma_data.my_id)

	eventx.call(EventxEnum.UserOffline)

	ma_common.updateUserBase(user.id, {online = user.online, offlineDt = user.offlineDt})

	ma_common.pushCollecter("UserOffline", currTime)

	skynet.logd("msgagemt.afk end source => ", source, ";uid => ", ma_data.my_id)
end

function CMD.logout(source, type)
	-- NOTICE: The logout MAY be reentry
	--ma_data.send_push("logout")
	CMD._logoutComplete()
end

function CMD._logoutComplete()
	if ma_data.isLogin then
		ma_data.isLogin = false

		-- 注销时未离线也要做离线处理
		local user = ma_data.userInfo
		if user and user.online then
			CMD.afk()
		end

		-- ma_data.hearbeat_invoke()
		-- ma_data.ma_hall_active.playerLogout()
		if not ma_data.yet_push_out then
			ma_data.yet_push_out = true
			CMD.push_loginout(0) -- 0 表示下线标识
		end
	end

	if ma_data.my_room then
		skynet.send("agent_mgr", "lua", "userafk", ma_data.my_id, ma_data.my_room, true)
	end

	skynet.send("agent_mgr", "lua", "PlayerLogout", ma_data.my_id)
	if ma_data.gate then
		skynet.call(ma_data.gate, "lua", "logout", ma_data.userid, ma_data.subid)
	end
end

-- call by gated / agent_mgr server
function CMD.exit()
	CMD._logoutComplete()

	-- safe release last player 's closure
	if ma_data.my_id then
		skynet.logd("msgagent player:" .. ma_data.my_id .. " exit.")
	end

	if ma_data.gate then
		skynet.send(ma_data.gate, "lua", "agentexit", ma_data.userid, ma_data.subid, ma_data.my_agent)
	end
	skynet.exit()
end

-- 服务器即将关闭
function CMD.server_will_shutdown( )
	ma_data.server_will_shutdown = true
end
-- 服务器即将关闭,禁止创建朋友局
function CMD.forbid_create_room()
	ma_data.forbid_create_room = true
end

function CMD.shutdown(source)
	ma_data.send_push('server_shutdown')
	CMD.exit()
end

-- 处理后台请求
function CMD.push_msg_by_web(source,usertbl)

end

-- 处理skynet 其他服务请求（不推送给client）
function CMD.process_no_client_msg(source,name,args)
end
-- 处理skynet 其他服务请求（推送给client）
function CMD.push_msg(source, name, args)
	ma_pushmsg.process_msg(name,args)
end

--隔天更新登录时间
function CMD.update_login_time()
	if ma_data.db_info then
		dbx.update(TableNameArr.User, ma_data.db_info.id, {last_time = os.time()})
	end
end

-- 更新推广员金币钻石
function CMD.update_blind()
    ma_data.ma_spread.player_blind()
end

function CMD.inject(filePath)
    require(filePath)
end

function CMD.reload_proto()
	--tcp 使用 sproto 初始化	
	if istcp then
		--sproto
		host = protoloader.load(1):host "package"
	    send_request = function(...)
			-- local name, args = ...
			-- log_transport("=server say=: ", name, args)
			return host:attach(protoloader.load(2))(...)
		end

	    unpack_msg = function(msg,sz)
			local mode, message_name, tbl, response, ud = host:dispatch(msg,sz)
			-- log_transport("=client say=: ", message_name, tbl)
			return mode, message_name, tbl, response, ud
		end
	else
		--proto
		-- host = protoloader.new({
		-- 	pbfiles = sharetable.query("pbprotos"),
		-- 	pbids 	= sharetable.query("pbids"),
		-- 	pbmaps  = sharetable.query("pbmaps")
		-- })
		
		-- unpack_msg = function(msg,sz)
		-- 	msg,sz = skynet.unpack(msg,sz)
		-- 	local mode, message_name, tbl, response, ud = host:dispatch(msg, sz)
		-- 	log_transport("client say", message_name, tbl)
		-- 	return mode, message_name, tbl, response, ud
		-- end

		-- send_request = function(...)
		-- 	local name, args = ...
		-- 	log_transport("server say", name, args)
		-- 	return host:pack_message(...)
		-- end
		unpack_msg = function(msg,sz)
			-- msg,sz = skynet.unpack(msg,sz)
			-- -- local mode, message_name, tbl, response, ud = host:dispatch(msg, sz)
			-- -- return mode, message_name, tbl, response, ud
			-- return host:dispatch(msg,sz)
			return msg,sz
		end

		send_request = function(...)
			-- local name, args = ...
			-- log_transport("server say", name, args)
			-- return host:pack_message(...)
			return skynet.call("pb_mgr" .. pb_mgr_index,"lua","pack_message",...)
		end
	end
	
end


function CMD.ma_interface_test(source, ma, interface, ...)
	print("ma_interface_test ma =>", ma, ";interface =>", interface, ...)
	if skynet.getenv("isTest") ~= "1" then
		return false, "非测试服不可使用此接口"
	end
	local module = ma_data[ma]
	if ma == "ma_data" then 
		module = ma_data
	end
	if not module then
		return false, "not find module ma=" ..  ma
	end
	local func = module[interface]
	return func(...)
end

-- CMD api  end--------------------------------------------


--#region REQUEST api start （client 消息处理）

function REQUEST:GetUserInfo()

	ma_data.isLoginEnd = true	-- 客户端获取此信息才开始同步消息

	skynet.fork(function ()
		ma_data.sendMsgQueue(ma_data.msgQueueToClient)

		skynet.sleep(10)
		-- 补发购买成功的包		
		-- if ma_data.db_info.buy_suc_packs then
		-- 	for _,t in ipairs(ma_data.db_info.buy_suc_packs) do
		-- 		skynet.sleep(100)
		-- 		ma_hall_store.buy_suc(t.mall_id,t.sandbox,t.out_trade_no)

		-- 		if t.platform == "applepay" then
		-- 			-- nil 位表示 游戏的商品id,apple现前端没用
		-- 			ma_hall_store.apple_buy_suc(t.transaction_id,nil,t.sign)
		-- 		end
		-- 	end
		-- 	ma_data.db_info.buy_suc_packs = nil
		-- 	skynet.send(get_db_mgr(), "lua", "replace", COLL.USER, {id = ma_data.my_id}, {["$unset"] = {buy_suc_packs = ''}})
		-- end

		-- 补发广告奖励
		-- if ma_data.db_info.pangle_suc_packs then
		-- 	for _,t in ipairs(ma_data.db_info.pangle_suc_packs) do
		-- 		skynet.sleep(100)
		-- 		-- TODO
		-- 		-- 补发广告奖励
		-- 		CMD.video_ad_report(nil,t.trans_id,t.reward_name)
		-- 	end
		-- 	ma_data.db_info.pangle_suc_packs = nil
		-- 	skynet.send(get_db_mgr(), "lua", "replace", COLL.USER, {id = ma_data.my_id}, {["$unset"] = {pangle_suc_packs = ''}})
		-- end

	end)

	--local can_bind = false
	--local switch_status = skynet.call(get_db_mgr(), "lua", "find_one", "channel", {name = ma_data.db_info.channel})

	--local team_info = skynet.call("team2v2_mgr", "lua", "get_teaminfo", nil,ma_data.my_id)

	local data = {
		userInfo = ma_data._userInfo,

		gameFuncDatas = nil,

		-- can_bind = can_bind,
		-- ad_switch  = switch_status and switch_status.ad_switch,
		-- ios_pay_switch = switch_status and switch_status.ios_pay_switch,
		-- android_pay_switch = switch_status and switch_status.android_pay_switch,
		-- share_switch = switch_status and switch_status.share_switch,
		-- today_share_count = ma_data.share.today_share_count,
		-- game_sharec = ma_data.share.game_sharec,
		-- today_receive_aidc = ma_data.db_info.bailout.countc,
		-- show_what_sign = (os.time() - ma_data.db_info.firstLoginDt <= 7*24*60*60) and 1 or 2,
		-- teaminfo = team_info
	}

	eventx.call(EventxEnum.UserDataGet, data)

	return data
end

function REQUEST:enter_game_check( )
	local room = skynet.call("agent_mgr", "lua", "userback", ma_data.my_id, ma_data.my_agent,ma_data.db_info.gold,ma_data.my_room)
	return {result = room ~= nil}
end

-- 玩家重连
function REQUEST:reconnect( )
	-- local diff = ma_data.push_index - self.index
	-- if diff > 0 and ma_data.my_room then
	if ma_data.my_room then
		skynet.fork(function()
			skynet.sleep(1)
			skynet.send("agent_mgr", "lua", "userback", ma_data.my_id, ma_data.my_agent,ma_data.db_info.gold)

		end)
	end
	return {diff = 0,in_game = (ma_data.my_room or ma_data.matching) and true or false}
end

function REQUEST:logout()
	CMD._logoutComplete()
end

-- public request:
function REQUEST:heartbeat()
	ma_data.heartcount = 5

	if ma_data.yet_push_out then
		CMD.push_loginout(1) -- 1 表示上线
		ma_data.yet_push_out = nil
	end

	-- return {ok = true, time = os.time()}
end

REQUEST_New.TimeGet = function ()
	return {time = os.time()}
end

--#endregion REQUEST api end

local function request(name, args, response)
	if name == "send_session" then
		-- pass
		if response then
			response()
		end
	else
		local newType = false
		local func = REQUEST[name]
		if not func then
			func = REQUEST_New[name]
			if func then
				newType = true
			end
		end

		assert(func, name)

		log_transport("=client say=", name, args)
		local r
		if not newType then
			r = func(args)
		else
			local ret, obj = func(args)
			if type(ret) ~= "number" then -- 不是错误码就直接返回
				obj = ret
			else
				if not obj then -- 如果返回两个值，则第一个为错误码， 第二各为table， 包含其他值
					obj = {}
				end
				obj.e_info = ret
			end
			r = obj
		end

		if response then
			log_transport("=server say=", name, r)
			return response(r)
		end
	end
end


skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return unpack_msg(msg, sz)
	end,
	dispatch = function (_, _, type, name, args, response)
		-- assert(fd == ma_data.fd)	-- You can use fd to reply message
		skynet.ignoreret()	-- session is fd, don't call skynet.ret
		-- skynet.trace()

		if skynet.getenv("enx") ~= "publish" and name ~= "heartbeat" then
			skynet.logd("client:{" 
				.. ma_data.my_id .. "_" 
				.. (ma_data.db_info or {nickname = "nil"}).nickname .. "_"
				.. name
				.. "} message has been queued")
		end

		if type == "REQUEST" then
			cs(function ()
				ma_usertime.check()

				local ok, result  = pcall(request, name, args, response)
				if ok then
					if result then
						result = send_package(result)
					end
				else
					skynet.loge(ma_data.my_id .. "_" .. name .. " no return. error:" .. tostring(result))
				end
			end)
		else
			assert(type == "RESPONSE")
			error "This example doesn't support request client"
		end
	end
}

local function memoryCheck()
	local kb, bytes = collectgarbage("count")
	if kb > 2500 then
		collectgarbage("collect")
	end
	skynet.timeout(math.random(1000,1500), memoryCheck)
end

skynet.start(function()
	math.randomseed(os.time())
	cs = queue()

	ma_data.my_agent = skynet.self()
	CMD.reload_proto()

	-- If you want to fork a work thread , you MUST do it in CMD.login
	skynet.dispatch("lua", function(_, source, command, ...)
		-- local f = assert(CMD[command])
		-- skynet.ret(skynet.pack(f(source, ...)))
		local args = {...}
		if command == "lua" then
			command = table.remove(args, 1)
		end

        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(source, table.unpack(args))))
	end)
	memoryCheck()
end)