--
-- channel data collecter
--

local skynet = require "skynet"
local timex = require "timex"
local create_dbx = require "dbx"
local dbx = create_dbx(get_db_manager)
local common = require "common_mothed"
local timer = require "timer"
local schedule = require "schedule"
local xy_cmd = require "xy_cmd"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

local COLL = require "config/collections"
local TableNameArr = COLL

local NODE_NAME = skynet.getenv "node_name"


ServerData.delayUpdate = true

-- 渠道统计数据
ServerData.channelDatas = {} -- old: channel
ServerData.needUpdate = {}


--ltv 和 流失数据计算数据
--channel_today :key total_charge,h5_total_charge,retention 修改这三个属性
ServerData.ltv_retention = {}
ServerData.ltv_retention_update = {}


function CMD.inject(filePath)
    require(filePath)
end

function CMD._Init()
	-- load dayZero channel data
	local dayZero = timex.getDayZero()
	local datas = dbx.find(TableNameArr.UserChannelData, {dayZero = dayZero, nodeName = NODE_NAME})

	ServerData.channelDatas = {}
	for _, channelData in ipairs(datas) do
		ServerData.channelDatas[channelData.channel] = channelData
	end

	CMD._StartSaveTimer()
end

function CMD._StartSaveTimer()
	if ServerData.delayUpdate then
		skynet.timeout(150, CMD._StartSaveTimer)
	end
	CMD.Save()
end

function CMD.server_will_shutdown()
	ServerData.delayUpdate = false
end

function CMD.Save()
	local needUpdate = ServerData.needUpdate
	ServerData.needUpdate = {}

	for channel, value in pairs(needUpdate) do
		local channelData = CMD._GetChannelData(channel)
		dbx.update(TableNameArr.UserChannelData, {dayZero = channelData.dayZero, channel = channelData.channel, nodeName = NODE_NAME}, channelData)
	end

	-- local ltv_retention_update = ServerData.ltv_retention_update
	-- ServerData.ltv_retention_update= {}
	-- --ltv等数据更新
	-- for c,_ in pairs(ltv_retention_update) do
	-- 	skynet.call(get_db_mgr(), "lua", "update", COLL.CHANNEL_DATA, {day = c.day, channel = c.channel, node_name = NODE_NAME}, 
	-- 		{total_charge=c.total_charge,h5_total_charge=c.h5_total_charge,ltv=c.ltv,total_charge_pnum=c.total_charge_pnum,retention=c.retention})
	-- end
end


CMD._GetChannelData = function (channel)
	local currentDayZero = timex.getDayZero()

	local channelData = ServerData.channelDatas[channel]
	if not channelData or channelData.dayZero ~= currentDayZero then
		channelData = {
			dayZero = currentDayZero,	-- 日期
			channel = channel,			-- 渠道名
			node_name = NODE_NAME,

			newUserNum = 0,				-- 今天注册人数
			loginUserNum = 0,			-- 今天登录人数

			paySum = 0, 				-- 今天充值总额(所有游戏)
			payUserNum = 0, 			-- 今天充值人数

			newUserPaySum = 0,			-- 今天新玩家充值总额
			newUserPayNum = 0,			-- 今天新玩家充值人数

			payGroupSum = {},			-- 每日支付档位分组数量统计

			----------------------------------------------
			-- reg_num = 0,				-- 今天注册人数
			-- act_num = 0, 				-- 今天登录人数

			-- charge_amount = 0, 			-- 今天充值总额(所有游戏)
			-- charge_pnum = 0, 			-- 今天充值人数

			-- new_charge_amount = 0,		-- 今天新玩家充值总额
			-- new_charge_pnum = 0,		-- 今天新玩家充值人数


			-- first_charge_pnum = 0, 		-- 今天首次充值人数
			-- game_charge = {},			-- 各个游戏的充值总额
			-- total_charge_pnum = 0,		--总的充值人数
			-- total_charge = 0,			--麻将总的充值金额
			-- h5_total_charge = 0, 		--h5游戏的充值总额
			-- retention = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},				--统计31天留存数据
			-- ltv = {
			-- 		0,0,0,0,0,0,0,0,0,0,
			-- 		0,0,0,0,0,0,0,0,0,0,
			-- 		0,0,0,0,0,0,0,0,0,0,
			-- 		0,0,0,0,0,0,0,0,0,0,
			-- 		0,0,0,0,0,0,0,0,0,0,
			-- 		0,0,0,0,0,0,0,0,0,0,
			-- 		0,0,0,0,0,0,0,0,0,0,
			-- 		0,0,0,0,0,0,0,0,0,0,
			-- 		0,0,0,0,0,0,0,0,0,0,
			-- 		0,0,0,0,0,0,0,0,0,0,
			-- 		0,0,0,0,0,0,0,0,0,0,
			-- 		0,0,0,0,0,0,0,0,0,0,
			-- 		0
			-- 	},				--统计31天ltv数据
		}
		ServerData.channelDatas[channel] = channelData
		dbx.add(TableNameArr.UserChannelData, channelData)
	end

	return channelData
end



CMD.UserNew = function (channel, channelData, curDayZero, baseObj, firstLoginDt)
	channelData.newUserNum = channelData.newUserNum + 1

	-- TODO：先直接写数据库吧，后面再优化，框架内部消息队列也可以缓冲下
	common.write_record(TableNameArr.UserCreate_REC, baseObj.id, nil, nil, channel, firstLoginDt, curDayZero, baseObj.os)
	--(user, "Role", "CreateRole", Loader.ServerId, user.server, prams.Text());
end

CMD.UserDayLogin = function (channel, channelData, curDayZero, baseObj, date)
	channelData.loginUserNum = channelData.loginUserNum + 1
end

CMD.UserLogin = function (channel, channelData, curDayZero, baseObj, date)
	common.write_record(TableNameArr.UserOnline_REC, baseObj.id, "Online", nil, channel, date, curDayZero, baseObj.os)

	common.write_record(TableNameArr.UserOnline_Day_REC, baseObj.id, "Online", nil, channel, date, curDayZero, baseObj.os)

	-- (user, "Online", "Online", Loader.ServerId, Loader.DsId, prams.GetText());
end

CMD.UserOffline = function (channel, channelData, curDayZero, baseObj, date)
	common.write_record(TableNameArr.UserOnline_REC, baseObj.id, "Offline", nil, channel, date, curDayZero, baseObj.os)
	-- (user, "Online", "Online", Loader.ServerId, Loader.DsId, prams.GetText());
end

CMD.UserPay = function (channel, channelData, curDayZero, baseObj, date, cfgId, price, orderId, otherObj)

	-- otherObj.firstLoginDt
	-- otherObj.isFirst
	-- otherObj.isFirstDay

	cfgId = tostring(cfgId)

	channelData.paySum = channelData.paySum + price

	if otherObj.isFirstDay then
		channelData.payUserNum = channelData.payUserNum + 1
	end

	if timex.equalsDay(otherObj.firstLoginDt, curDayZero) then
		channelData.newUserPaySum = channelData.newUserPaySum + price
		if otherObj.isFirst then
			channelData.newUserPayNum = channelData.newUserPayNum + 1
		end
	end

	local num = channelData.payGroupSum[cfgId] or 0
	channelData.payGroupSum[cfgId] = num + 1

	-- common.write_record(TableNameArr.UserPay_REC, id, "Pay", nil, channel, date, curDayZero, baseObj.os, cfgId)
	-- (user, "AddPay", "AddPay", sData.id, sData.gem.ToString(), 
	-- 	sData.cny, platform, order, gem.ToString(), realMoney.ToString(), first ? "1" : "0", firstDay ? "1" : "0");
end




-- function CMD.today_0_time(time)
-- 	local t = os.date("*t",time or os.time())
-- 	return os.time {year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0}	
-- end

-- -- 每日首次登录
-- function CMD.login(channel,c,reg_time)
-- 	c.act_num = c.act_num + 1

-- 	CMD.ltv_retention_data_handle(channel,reg_time,1,"",0,0)
-- end

-- -- 注册
-- function CMD.register(channel,c)
-- 	c.reg_num = c.reg_num + 1
-- 	c.act_num = c.act_num + 1
-- end

--ltv等数据整合
function CMD.ltv_retention_merge(datadb,datatmp)
	datadb.total_charge = (datatmp.tmp_total_charge or 0) + (datadb.total_charge or 0)
	datadb.h5_total_charge = (datadb.h5_total_charge or 0) + (datatmp.tmp_h5_total_charge or 0)
	datadb.total_charge_pnum = (datadb.total_charge_pnum or 0) + (datatmp.tmp_total_charge_pnum or 0)
	if datatmp.tmpretention then
		if not datadb.retention then
			datadb.retention = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		end
		for day,num in pairs(datatmp.tmpretention) do
			datadb.retention[day] = datadb.retention[day] + num
		end
	end
	if datatmp.tmpltv then
		if not datadb.ltv then
			datadb.ltv = { 
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0}				--统计31天ltv数据
		end
		for day,num in pairs(datatmp.tmpltv) do
			datadb.ltv[day] = (datadb.ltv[day] or 0) + num
		end
	end

end

--reg_time:注册时间
--login_num:登录人数
--game_name:充值游戏名称
--amount:充值金额
--first_num:
function CMD.ltv_retention_data_handle(channel,reg_time,login_num,game_name,amount,first_num)
	local key = channel .. CMD.today_0_time(reg_time)
	local deltaDay = math.floor(((CMD.today_0_time() - CMD.today_0_time(reg_time) + 10) / 86400))

	if not ServerData.ltv_retention[key] then
		ServerData.ltv_retention[key] = {load_data = true}
		if deltaDay > 0 and deltaDay < 32 then
			ServerData.ltv_retention[key].tmpretention = {}
			ServerData.ltv_retention[key].tmpretention[deltaDay] = (ServerData.ltv_retention[key].tmpretention[deltaDay] or 0) + login_num
		end
		
		if game_name == "basegame" then
			ServerData.ltv_retention[key].tmp_total_charge = (ServerData.ltv_retention[key].tmp_total_charge or 0) + amount
			ServerData.ltv_retention[key].tmpltv = {}
			if deltaDay >= 120 then
				ServerData.ltv_retention[key].tmpltv[121] = (ServerData.ltv_retention[key].tmpltv[121] or 0) + amount
			else
				
				ServerData.ltv_retention[key].tmpltv[deltaDay+1] = (ServerData.ltv_retention[key].tmpltv[deltaDay+1] or 0) + amount
			end
		else
			ServerData.ltv_retention[key].tmp_h5_total_charge = (ServerData.ltv_retention[key].tmp_h5_total_charge or 0) + amount
		end
		ServerData.ltv_retention[key].tmp_total_charge_pnum = (ServerData.ltv_retention[key].tmp_total_charge_pnum or 0) + first_num
		local channel_data = skynet.call(get_db_mgr(),"lua", "find_one",COLL.CHANNEL_DATA, {day = CMD.today_0_time(reg_time), node_name = NODE_NAME, channel=channel},{_id=false,total_charge=true,h5_total_charge=true,retention=true,ltv=true,total_charge_pnum=true,day=true,node_name=true,channel=true})

		if not channel_data then
			--数据不存在不管(理论上应该存在)
			skynet.error("not find channel data")
		else
			CMD.ltv_retention_merge(channel_data,ServerData.ltv_retention[key])
			ServerData.ltv_retention[key] = channel_data
			ServerData.ltv_retention_update[channel_data] = true
		end
		--ltv统计打印
		--table.print(channel_data)
		
	else
		if ServerData.ltv_retention[key].load_data then
			if deltaDay > 0 and deltaDay < 32 then
				ServerData.ltv_retention[key].tmpretention[deltaDay] = (ServerData.ltv_retention[key].tmpretention[deltaDay] or 0) + 1
			end
			if game_name == "basegame" then
				if deltaDay >= 120 then
				ServerData.ltv_retention[key].tmpltv[121] = (ServerData.ltv_retention[key].tmpltv[121] or 0) + amount
				else
					ServerData.ltv_retention[key].tmpltv = {}
					ServerData.ltv_retention[key].tmpltv[deltaDay+1] = (ServerData.ltv_retention[key].tmpltv[deltaDay+1] or 0) + amount
				end
				ServerData.ltv_retention[key].tmp_total_charge = (ServerData.ltv_retention[key].tmp_total_charge or 0) + amount
			else
				ServerData.ltv_retention[key].tmp_h5_total_charge = (ServerData.ltv_retention[key].tmp_h5_total_charge or 0) + amount
			end
			ServerData.ltv_retention[key].tmp_total_charge_pnum = (ServerData.ltv_retention[key].tmp_total_charge_pnum or 0) + first_num
		else
			if deltaDay > 0 and deltaDay < 32 then
				ServerData.ltv_retention[key].retention[deltaDay] = ServerData.ltv_retention[key].retention[deltaDay] + login_num
			end

			if game_name == "basegame" then
				ServerData.ltv_retention[key].total_charge = (ServerData.ltv_retention[key].total_charge or 0) + amount
				if not ServerData.ltv_retention[key].ltv then
					ServerData.ltv_retention[key].ltv = { 
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0,0,0,0,0,0,0,0,0,0,
					0}
				end
				if deltaDay >= 120 then
					ServerData.ltv_retention[key].ltv[121] = (ServerData.ltv_retention[key].ltv[121] or 0) + amount
				else
					ServerData.ltv_retention[key].ltv[deltaDay+1] = (ServerData.ltv_retention[key].ltv[deltaDay+1] or 0) + amount
				end
			else
				ServerData.ltv_retention[key].h5_total_charge = (ServerData.ltv_retention[key].h5_total_charge or 0) + amount
			end
			ServerData.ltv_retention[key].total_charge_pnum = (ServerData.ltv_retention[key].total_charge_pnum or 0) + first_num
			local channel_data = ServerData.ltv_retention[key]
			ServerData.ltv_retention_update[channel_data] = true
		end
	end
end

-- function CMD.charge(channel, c, game_name, amount, is_new_player, is_first, is_today_first,reg_time)
-- 	c.charge_amount = c.charge_amount + amount
-- 	c.game_charge[game_name] = (c.game_charge[game_name] or 0) + amount
-- 	if is_new_player then
-- 		c.new_charge_amount = c.new_charge_amount + amount
-- 	end

-- 	if is_today_first then
-- 		c.charge_pnum = c.charge_pnum + 1
-- 		if is_new_player then
-- 			c.new_charge_pnum = c.new_charge_pnum + 1
-- 		end
-- 	end

-- 	if is_first then
-- 		c.first_charge_pnum = c.first_charge_pnum + 1
-- 	end
-- 	local first_num = 0
-- 	if is_first then
-- 		first_num = 1
-- 	end
-- 	CMD.ltv_retention_data_handle(channel,reg_time,0,game_name,amount,first_num)

-- end



function CMD._onMessage(channel, cmd, ...)
	if not channel or channel == "" then
		return
	end

	local func = CMD[cmd]
	if not func then
		skynet.loge("collecter cmd miss!", cmd)
		return
	end

	local currentDayZero = timex.getDayZero()
	local channelData = CMD._GetChannelData(channel)

	local ok, ret = pcall(func, channel, channelData, currentDayZero, ...)
	if not ok then
		skynet.loge("collecter cmd error!", cmd, channel)
		return
	end

	ServerData.needUpdate[channel] = true

	if not ServerData.delayUpdate then
		CMD.Save()
	end

	return ret
end

skynet.start(function ()
	skynet.dispatch("lua", function(session, source, channel, cmd, ...)
		skynet.ret(skynet.pack(CMD._onMessage(channel, cmd, ...)))
	end)
	CMD._Init()
end)