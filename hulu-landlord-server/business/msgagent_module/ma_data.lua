local skynet = require "skynet"
local timer = require "timer"
local cfg_items = require "cfg.cfg_items"

local cfg_gift = require "cfg.cfg_gift"
local cfg_vip = require "cfg.cfg_vip"

require "define"
require "table_util"

local ma_day_comsume
local ma_data = nil
ma_data = {
	my_agent                = nil,   	-- 玩家当前服务地址
	msgQueueOfflineToClient	= nil,		-- 离线时的消息队列
	msgQueueToClient		= {},		-- 保证发送到客户端的消息队列

    my_id                   = nil,		-- 玩家id
	_userInfo 				= nil,		-- 登录时更新， 一般不使用这个 获取or修改 user 信息
	userInfo                = setmetatable({}, {
		__index = function (self, key)
			return ma_data._userInfo[key]
		end,
		__newindex = function (self, key, value)
			rawset(ma_data._userInfo, key, value)
		end
	}),		-- 玩家信息 = db_info
    db_info                 = setmetatable({}, {
		__index = function (self, key)
			return ma_data._userInfo[key]
		end,
		__newindex = function (self, key, value)
			rawset(ma_data._userInfo, key, value)
		end
	}),		-- 玩家信息


	reconnectTime			= 0,
	heartcount				= 5,
	sameDay					= true,		-- 本次登录是否与上次为同一天？  目前不用这个了

	gate					= nil,		-- gate 服务
	fd						= nil,
	session_key				= nil,		-- 暂时作用不明
	userid					= nil,		--
	subid					= nil,		--
	ip 						= nil,		-- 玩家 IP

	isLogin 				= false,	--
	isLoginEnd 				= false,	--

	roomConnect 			= true, 	-- 客户端与房间处于连接状态
	roomQueueFunc			= nil,		-- room的执行队列

    my_room_id              = nil,   -- 当前房间id
    server_will_shutdown    = false, -- 服务器即将关闭标签

	last_place				= 0,	 -- 上一场次ID
	
	give_coin_info          = {},    -- 赠送信息，包括赠送了哪些好友和赠送接收次数n
	tbl2ma 					= {}, 	 -- msgagent_module 关注哪些表
}

local main_node = (skynet.getenv "node") == "main"
local main_node_host = skynet.getenv "main_node_host"




-- 新增金币记录
function ma_data.insert_gold_rec(begin_gold, add_gold, way, detail,subjoinDesc)
	local pack = {
		pid = ma_data.my_id,
		time = os.time(),
		begin_num = begin_gold,
		num = add_gold,
		way=way,
		detail = detail
	}

	if subjoinDesc then
		table.connect(pack,subjoinDesc)
	end

	skynet.call("db_mgr_rec", "lua", "rec_insert", "gold_rec", pack)
end

--新增QQ红包余额记录
function ma_data.insert_qq_wallet_rec(begin_gold, add_gold, way, detail,subjoinDesc)
	local pack = {
		pid = ma_data.my_id,
		time = os.time(),
		begin_num = begin_gold,
		num = add_gold,
		way=way,
		detail = detail
	}

	if subjoinDesc then
		table.connect(pack,subjoinDesc)
	end

	skynet.call("db_mgr_rec", "lua", "rec_insert", "qq_wallet_rec", pack)
end

-- 新增银行金币记录
function ma_data.insert_bankgold_rec(begin_gold, add_gold, way, detail,subjoinDesc)
	local pack = {
		pid = ma_data.my_id,
		time = os.time(),
		begin_num = begin_gold,
		num = add_gold,
		way=way,
		detail = detail
	}

	if subjoinDesc then
		table.connect(pack,subjoinDesc)
	end

	skynet.call("db_mgr_rec", "lua", "rec_insert", "bankgold_rec", pack)
end

-- 新增钻石记录
function ma_data.insert_diamond_rec(begin_diamond, add_diamond, way, detail,subjoinDesc)
	local pack = {
		pid = ma_data.my_id,
		time = os.time(),
		begin_num = begin_diamond,
		num = add_diamond,
		way=way,
		detail = detail
	}

	if subjoinDesc then
		table.connect(pack,subjoinDesc)
	end

	skynet.call("db_mgr_rec", "lua", "rec_insert", "diamond_rec",pack )
end

-- 道具记录
function ma_data.insert_goods_rec(name,begin_num,add_num,way,detail,subjoinDesc)
	pack = {
		pid 		= ma_data.my_id,
		time 		= os.time(),
		begin_num 	= begin_num,
		name 		= name,
		num 		= add_num,
		way 		= way,
		detail 		= detail
	}
	if subjoinDesc then
		table.connect(pack,subjoinDesc)
	end
	skynet.call("db_mgr_rec", "lua", "rec_insert", "props_rec", pack)
end

--金币变换返回
function ma_data.cheak_gold_change(gold,num)
	if num > 0 then
		if gold < 2000 then
			return 'less_2K'
		elseif gold < 100000 then
			return 'less_10w'
		elseif gold < 500000 then
			return 'less_50w'
		elseif gold < 5000000 then
			return 'less_500w'
		end
	end
end


function ma_data.get_qq_wallet()
	if ma_data.db_info.QQ_Wallet == nil then
		ma_data.db_info.QQ_Wallet = 0
	end
	return ma_data.db_info.QQ_Wallet
end


-- 修改金币唯一接口
function ma_data.add_gold(num, way,detail,from_room,sync_db,out,subjoinDesc)
	-- print("====================add_gold===================")
	-- print(num,from_room)
	local gold = ma_data.db_info.gold + num
	assert(way and ("string" == type(detail)))
	assert(gold >= 0, string.format("begin_gold:%s num:%s way:%s", ma_data.db_info.gold, num, way))
	if num > 0 and (way == GOODS_WAY_MALL or way == GOODS_WAY_DIAMOND_BUY) then
		ma_data.ma_task.add_task_count(TASK_DAY_T_BUY_COIN)
	end
	ma_data.insert_gold_rec(ma_data.db_info.gold, num, way,detail,subjoinDesc)
	ma_data.db_info.gold = gold

	if not out then
		ma_data.send_push("sync_goods", {goods_list = {{id = GOODS_GOLD_ID, num = gold}}})
	else
		table.insert(out,{id = GOODS_GOLD_ID, num = gold})
	end
	local currUI = ma_data.cheak_gold_change(gold,num)
	local db_change = {}
	db_change.gold = ma_data.db_info.gold
	if currUI then
		ma_data.db_info.currUI = currUI
		db_change.currUI = currUI
	end
	skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, db_change)
	
	if ma_data.my_room and not from_room then
		pcall(skynet.send, ma_data.my_room, "lua", "receive_gold", ma_data.my_id, num)
	end
	skynet.send("data_goods_mgr","lua","goods_add_sub",ma_data.db_info.channel,GOODS_GOLD_ID,way,num)
	-- skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, {gold = ma_data.db_info.gold})
	return gold
end

function ma_data.update_gold(num, way,detail,from_room,sync_db,out,subjoinDesc)
	local env = skynet.getenv("env")
	env = env or "publish"
	if not (env == "debug" or env == "local")then
		return false, "only local/debug env can use"
	end
	if num == nil then 
		return false, "num can not be nil"
	end
	if num < 0 or num > 1000000 then 
		return false, string.format("invaild num num < 0 or num > 1000000.num =>", num) 
	end
	local diff = num -  ma_data.db_info.gold
	return ma_data.add_gold(diff, way,detail,from_room,sync_db,out,subjoinDesc) == num
end

-- 修改银行金币唯一接口
function ma_data.add_bankgoldtwo(num,way,detail)
	local bankgold = ma_data.db_info.bank.bankgold + num
	assert(way and ("string" == type(detail)))
	assert(bankgold >= 0, string.format("begin_bankgold:%s num:%s way:%s", ma_data.db_info.bank.bankgold, num, way))
	ma_data.insert_bankgold_rec(ma_data.db_info.bank.bankgold, num, way,detail,subjoinDesc)
	ma_data.db_info.bank.bankgold = bankgold
	skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {bank = ma_data.db_info.bank})
	return bankgold
end

-- 修改银行金币唯一接口
function ma_data.add_bankgold(num, way,detail,from_room,sync_db,out,subjoinDesc)
	--print("====================add_bankgold===================",num)
	local bankgold = (ma_data.db_info.bankgold or 0) + num
	ma_data.insert_bankgold_rec((ma_data.db_info.bankgold or 0), num, way,detail,subjoinDesc)
	ma_data.db_info.bankgold = bankgold
	skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {bankgold = ma_data.db_info.bankgold})
	return bankgold
end

-- 修改钻石唯一接口
function ma_data.add_diamond(num, way, detail,from_room,sync_db,out,subjoinDesc)
	print("==============add_diamond=================")
	print("numid=", ma_data.my_id, ";num=", num)
	local diamond = ma_data.db_info.diamond + num
	print("diamond=", diamond)
	assert(way and ("string" == type(detail)))
	assert(diamond >= 0, string.format("begin_diamond:%s num:%s desc:%s", ma_data.db_info.diamond, num, desc))
	if num < 0 then
		ma_data.ma_task.add_task_count(TASK_DAY_T_USE_DIAMOND)
	end
	ma_data.insert_diamond_rec(ma_data.db_info.diamond, num, way,detail,subjoinDesc)
	ma_data.db_info.diamond = diamond

	if not out then
		ma_data.send_push("sync_goods", {goods_list = {{id = GOODS_DIAMOND_ID, num = diamond}}})
	else
		table.insert(out,{id = GOODS_DIAMOND_ID, num = diamond})
	end

	if not ma_day_comsume then
		ma_day_comsume = require "ma_day_comsume"
	end
	if num < 0 then
		-- ma_data.ma_hall_active.update_DailyBack(-num)
		ma_data.ma_day_comsume.comsume_diamond(-num)
	end
	skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {diamond = ma_data.db_info.diamond})

	skynet.send("data_goods_mgr","lua","goods_add_sub",ma_data.db_info.channel,GOODS_DIAMOND_ID,way,num)
	return diamond
end


--重置vip数据
function ma_data.reset_vip()
    print("====debug qc==== reset_vip ",ma_data.my_id)
    ma_data.reset_VP_daily()
    ma_data.db_info.viplv = 0
    ma_data.db_info.vip_reward = 0

    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id},{
        viplv = ma_data.db_info.viplv,
        vip_reward = ma_data.db_info.vip_reward,
    })	
	local vip_point = ma_data.find_goods(VIP_POINT).num
	local goods = {id = VIP_POINT, num = -vip_point}
	ma_data.add_goods(goods,GOODS_WAY_GM,"vip reset ",false,true)
    return "succ"
end

function ma_data.get_VP_daily()
	return ma_data.db_info.vip_point_daily
end

 --重置vip每日富豪点统计
 function ma_data.reset_VP_daily()
	print("====debug qc====  reset_VP_daily ")
    ma_data.db_info.vip_point_daily = {
        daily_task = {0,VIP_POINT_DAILY.daily_task},
        online_times = {0,VIP_POINT_DAILY.online_times},
        xixi_gift = {0,VIP_POINT_DAILY.xixi_gift},
        watch_any_ads = {0,VIP_POINT_DAILY.watch_any_ads},
		time_span = os.time()
    }
    skynet.call(get_db_mgr(),'lua','update_userinfo',ma_data.my_id,{vip_point_daily = ma_data.db_info.vip_point_daily })
end

--增加vp每日统计
--返回 更新值 ,增量值[控制每日可获得上限]
function ma_data.add_vp_daily(keyname,value)
	if not ma_data.db_info.vip_point_daily  then
		ma_data.reset_VP_daily()
	end
	local delta = 0
	if ma_data.db_info.vip_point_daily[keyname] then
		local oldValue = ma_data.db_info.vip_point_daily[keyname][1]
		ma_data.db_info.vip_point_daily[keyname][1] = ma_data.db_info.vip_point_daily[keyname][1] + value
		--上限处理
		ma_data.db_info.vip_point_daily[keyname][1] = math.min(ma_data.db_info.vip_point_daily[keyname][1], ma_data.db_info.vip_point_daily[keyname][2])
		delta = ma_data.db_info.vip_point_daily[keyname][1] - oldValue
	else
		skynet.loge(string.format("add_vp_daily error! keyname: %s , value: %d",keyname,value))
	end
	print("====debug qc====  add_vp_daily ",keyname,value ,delta)
	table.print(ma_data.db_info.vip_point_daily)
	skynet.call(get_db_mgr(),'lua','update_userinfo',ma_data.my_id,{vip_point_daily = ma_data.db_info.vip_point_daily})
	return ma_data.db_info.vip_point_daily[keyname][1] ,delta
end



-- 更新vip等级
function ma_data.update_viplv()
	print("==============update_viplv=================")
	local vip_point = ma_data.find_goods(VIP_POINT).num
	print("====debug qc====  vip_point =",vip_point)

	local tmp_viplv = ma_data.db_info.viplv or 0
	local tmp_reward = ma_data.db_info.vip_reward or 0

	assert(tmp_viplv>=0,string.format("viplv error %d",tmp_viplv))
	local tmp_cfg = ma_data.get_cfg_vip()
	-- assert(cfg_vip[tmp_viplv+1] ~= nil ,string.format("cfg_vip error %d",tmp_viplv))
	while cfg_vip[tmp_viplv+1]~=nil and cfg_vip[tmp_viplv+1].vipExp <=vip_point do		
		tmp_viplv = tmp_viplv + 1	
		tmp_reward = 0	
	end
	print("====debug qc==== update viplv =", tmp_viplv)
	table.print(tmp_reward)

	--是否升级了？
	if ma_data.db_info.viplv ~= tmp_viplv then
		ma_data.db_info.viplv = tmp_viplv
		ma_data.db_info.vip_reward = tmp_reward
	
		skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id},{
			viplv = ma_data.db_info.viplv,
			vip_reward = ma_data.db_info.vip_reward,
		})	
	
		--通知客户端
		ma_data.send_push("vip_up", { viplv = ma_data.db_info.viplv,bReward = ma_data.db_info.vip_reward==0 and ma_data.db_info.viplv>0 , recharge_diamondc = vip_point})
	end

end

--拉取or初始化vip.lv
function ma_data.get_vip()
	local bInit =false
	if ma_data.db_info.viplv == nil then
		ma_data.db_info.viplv = ma_data.db_info.viplv or 0
		bInit = true
	end
	if ma_data.db_info.vip_reward == nil then
		ma_data.db_info.vip_reward =  ma_data.db_info.vip_reward or 0
		bInit = true
	end

	local vip_point = ma_data.find_goods(VIP_POINT).num
	
	--更新初始化结果
	if bInit then
		skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id},{
			viplv = ma_data.db_info.viplv,
			vip_reward = ma_data.db_info.vip_reward,
		})	
	end

	return ma_data.db_info.viplv
end

--读取cfg_vip vipGift列表
function ma_data.get_cfg_vip()
	local vip_lv = ma_data.get_vip()
	local goods_pack = cfg_vip[vip_lv]
	local goods_list = table.clone(goods_pack.vipGift)
	-- print("=====recive_vip_reward table : =======")
	-- table.print(goods_list)
	return goods_list
end

--领取vip奖励
function ma_data.recive_vip_reward()
	local goods_list = ma_data.get_cfg_vip()	
	goods_list = ma_data.get_vip_goods_by_day(goods_list)
	--发放奖励
	ma_data.add_goods_list(goods_list,GOODS_WAY_VIP,'vip礼包领取')
	--同步给客户端弹窗消息
	ma_data.send_push("buy_suc", {
		goods_list = goods_list,
		msgbox = 1
	})
	--更新vip_reward
	ma_data.db_info.vip_reward = os.time() --更新当前时间戳
	skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id},{
		vip_reward = ma_data.db_info.vip_reward,
    })
end


--根据今天周几 确定vip奖励内容
function ma_data.get_vip_goods_by_day(goods_list)
	local weekday = get_weekday(os.time())
	print("当前星期几 ",weekday)
	-- table.print(goods_list)
	local rewards =  {}
	--必选项目
	local good = goods_list[1]
	-- table.print(good)
	local tmp_goods = {id = good.id, num = good.num}
	table.insert(rewards, tmp_goods)

	--周轮序
	-- print("------------- \n ")
	-- table.print(goods_list[2])
	good = goods_list[2][weekday]
	
	local tmp_week_goods = {id = good.id, num = good.num}
	table.insert(rewards, tmp_week_goods)
	return rewards	
end

--获取vip加成
function ma_data.get_vip_ability(name)
	local vip_lv = ma_data.get_vip()
	local goods_pack = cfg_vip[vip_lv]
	return goods_pack[name]
end

-- 查找背包里的物品, 没有就新建一个
function ma_data.find_goods(goods_id)
	for _,goods in ipairs(ma_data.db_info.backpack) do
		if goods.id == goods_id then
			return goods
		end
	end
	local goods = {id = goods_id, num = 0}
	table.insert(ma_data.db_info.backpack, goods)
	return goods
end

--查找物品是否存在
function ma_data.get_goods_num(goods_id)
	if goods_id == GOODS_GOLD_ID then
		return ma_data.db_info.gold
	elseif goods_id == GOODS_DIAMOND_ID then
		return ma_data.db_info.diamond
	end
	for _,goods in ipairs(ma_data.db_info.backpack) do
		if goods.id == goods_id then
			return goods.num
		end
	end
	return 0
end

--------------------------------------------------
--top_type = 10,type=14,15,16
function ma_data.open_the_gift(gift_id,num,gift_award)
	local goodsNum = ma_data.get_goods_num(gift_id)
	if goodsNum == 0 or goodsNum < num or num < 1 then
		return false
	end

	if cfg_gift[cfg_items[gift_id].content.value].type == 1 then
		return ma_data.open_rand_gift(gift_id,num)
	elseif cfg_gift[cfg_items[gift_id].content.value].type == 2 then
		return ma_data.open_self_gift(gift_id,gift_award)
	elseif cfg_gift[cfg_items[gift_id].content.value].type == 3 then
		return ma_data.open_fixed_gift(gift_id,num)
	end
end
--随机礼包开启1
function ma_data.open_rand_gift(gift_id,num)
	local g = ma_data.find_goods(gift_id)
	local gRand = cfg_gift[cfg_items[gift_id].content.value].award1

	local realAward = {}
	local tempAward = {}
	for i=1,num do
		local gIndex = math.random(#gRand)
		if tempAward[gIndex] then
			tempAward[gIndex].num = tempAward[gIndex].num + 1
		else
			tempAward[gIndex] = table.clone(gRand[gIndex])
		end
	end
	for _,gInfo in pairs(tempAward) do
		table.insert(realAward,gInfo)
	end

	 ma_data.send_push("buy_suc", {
        gift_id = gift_id,
        goods_list = realAward,
        msgbox = 1
    })
	table.insert(realAward,{id=gift_id,num=-num})
	ma_data.add_goods_list(realAward,GOODS_WAY_GFIT,'随机礼包开启')
	return true
end
--自选礼包2
function ma_data.open_self_gift(gift_id,gift_award)
	local g = ma_data.find_goods(gift_id)
	local gAward = cfg_gift[cfg_items[gift_id].content.value].award1
	local AwardNum = cfg_gift[cfg_items[gift_id].content.value].num

	if AwardNum ~= #gift_award then
		return false
	end

	local allHave = false
	for _,oneInfo in ipairs(gift_award) do
		allHave = false
		for _,oneAward in ipairs(gAward) do
			if oneAward.id == oneInfo.id then
				allHave = true
				break
			end
		end
	end

	if not allHave then
		return false
	end

	ma_data.send_push("buy_suc", {
        gift_id = gift_id,
        goods_list = gift_award,
        msgbox = 1
    })
    table.insert(gift_award,{id=gift_id,num=-num})
	ma_data.add_goods_list(gift_award,GOODS_WAY_GFIT,'自选礼包开启')
	return true
end
--固定礼包
--随机礼包开启1
function ma_data.open_fixed_gift(gift_id,num)
	local g = ma_data.find_goods(gift_id)
	local gAward = cfg_gift[cfg_items[gift_id].content.value].award1

	local realAward = {}
	for i,oneInfo in ipairs(gAward) do
		local tempInfo = table.clone(oneInfo)
		tempInfo.num = num
		table.insert(realAward,tempInfo)
	end

	ma_data.send_push("buy_suc", {
        gift_id = gift_id,
        goods_list = realAward,
        msgbox = 1
    })
	table.insert(realAward,{id=gift_id,num=-num})
	ma_data.add_goods_list(realAward,GOODS_WAY_GFIT,'固定礼包开启')
	return true
end

function ma_data.is_goods_time_out(goods)
	if not goods or goods.num <= 0 then
		return true
	end
	local gItem = cfg_items[goods.id]
	if gItem.time <= 0 or not goods.gettime then
		return false
	end
	if goods.usetime and not goods.endtime then
		if goods.gettime + goods.num*ONE_DAY > os.time() then
			return false
		end
		return true
	end
	if goods.endtime and goods.endtime < os.time() then
		return true
	end
	return false
end

--------------------------------------------------
--脱掉类型相同的时装
--基础的东西脱不掉
function ma_data.drop_similar_goods(goods_id, syncGoods)
	local gItem = cfg_items[goods_id]
	local top_type = gItem.top_type
	local s_type = gItem.type

	for _,goods in ipairs(ma_data.db_info.backpack) do
		local tmpItem = cfg_items[goods.id]
		if 1 ~= tmpItem.default and goods.usetime and goods.usetime > 0 and tmpItem.top_type == top_type and tmpItem.type == s_type then
			goods.usetime = nil
			table.insert(syncGoods, goods)
		end
	end

end

--穿单品需要脱下套装
function ma_data.drop_set(goods_id, set_type,syncGoods)
	local gItem = cfg_items[goods_id]
	local top_type = gItem.top_type
	local s_type = set_type

	for _,goods in ipairs(ma_data.db_info.backpack) do
		local tmpItem = cfg_items[goods.id]
		if 1 ~= tmpItem.default and goods.usetime and tmpItem.top_type == top_type and tmpItem.type == s_type then
			goods.usetime = nil
			table.insert(syncGoods, goods)
		end
	end
end

--脱掉所有非基础的,穿套装时需要这个操作
--goods_id:套装id
function ma_data.drop_all(goods_id,syncGoods)
	--3,4,5,6部件需要全部脱掉
	local gItem = cfg_items[goods_id]
	local dropType = BAG_DRESS_TYPE_RELATIONS[gItem.top_type]
	for _,goods in ipairs(ma_data.db_info.backpack) do
		local tmpItem = cfg_items[goods.id]
		if 1 ~= tmpItem.default and goods.usetime and tmpItem.top_type == gItem.top_type and dropType[tmpItem.type] then
			goods.usetime = nil
			table.insert(syncGoods, goods)
		end
	end
end

--脱掉时装
function ma_data.drop_goods(goods_id)
	local gItem = cfg_items[goods_id]
	if BAG_DRESS_TYPE_RELATIONS[gItem.top_type] and (1 ~= gItem.default) then
		local g = ma_data.find_goods(goods_id)
		if g.usetime and g.usetime > 0 then
			g.usetime = nil
			ma_data.send_push("sync_goods", {goods_list = {g}})
			skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {backpack = ma_data.db_info.backpack})
		end
	end
end

--获取角色时装穿戴的物品列表
function ma_data.get_human_drees_goods(backpack)
	local ret = {}
	local typeused = {}
	if not backpack then
		backpack = ma_data.db_info.backpack
	end
	--先遍历非默认装扮
	for _,goods in ipairs(backpack) do
		local gItem = cfg_items[goods.id]
		if (1 ~= gItem.default) and goods.usetime and (not ma_data.is_goods_time_out(goods)) 
			and ((gItem.top_type == BAG_TOP_TYPE_ROLE_DRESS) 
			or (gItem.top_type == BAG_TOP_TYPE_FINGER_DRESS)) then
			--if gItem.type == BAG_TYPE_ROLE_SET then
				--套装直接返回
				--table.insert{ret,{goods.id,goods.hide}}
			--else
				table.insert(ret,{id = goods.id,hide = goods.hide})
				if not goods.hide then
					typeused[gItem.type] = true
				end
			--end
		end
	end
	--遍历默认装扮
	for _,goods in ipairs(backpack) do
		local gItem = cfg_items[goods.id]
		if (1 == gItem.default) and goods.usetime 
			and ((gItem.top_type == BAG_TOP_TYPE_ROLE_DRESS) 
			or (gItem.top_type == BAG_TOP_TYPE_FINGER_DRESS)) then
			if not typeused[gItem.type] then
				table.insert(ret,{id = goods.id})
			end
		end
	end
	-- print('==================时装=====================')
	-- table.print(ret)
	return ret
end

--获取角色当前装备的头像框,头像框只能装一个，返回ID就行
function ma_data.get_picture_frame(backpack)
	local typeused = {}
	local picture_frame = 300001
	if not backpack then
		backpack = ma_data.db_info.backpack
	end
	--先遍历非默认头像
	for _,goods in ipairs(backpack) do
		local gItem = cfg_items[goods.id]
		if (1 ~= gItem.default) and goods.usetime  and (not ma_data.is_goods_time_out(goods)) 
		 	and (gItem.top_type == BAG_PICTURE_FRAME) then
			picture_frame = goods.id
			typeused[gItem.type] = true
		end
	end
	--遍历默认装扮
	for _,goods in ipairs(backpack) do
		local gItem = cfg_items[goods.id]
		if (1 == gItem.default) and goods.usetime and (gItem.top_type == BAG_PICTURE_FRAME) then
			if not typeused[gItem.type] then
				picture_frame = goods.id
			end
		end
	end

	return picture_frame
end

--获取宠物时装穿戴的物品列表
function ma_data.get_pet_drees_goods(backpack)
	local ret = {}
	local typeused = {}
	if not backpack then
		backpack = ma_data.db_info.backpack
	end
	--先遍历非默认装扮
	for _,goods in ipairs(backpack) do
		local gItem = cfg_items[goods.id]
		if (1 ~= gItem.default) and goods.usetime and (not ma_data.is_goods_time_out(goods)) and (gItem.top_type == BAG_TOP_TYPE_PET_DRESS) then
			if gItem.type == BAG_TYPE_PET_SET then
				table.insert(ret, goods.id)
				typeused[gItem.type] = true
			end
		end
	end
	--遍历默认装扮
	for _,goods in ipairs(backpack) do
		local gItem = cfg_items[goods.id]
		if (1 == gItem.default) and goods.usetime and (gItem.top_type == BAG_TOP_TYPE_PET_DRESS) then
			if not typeused[gItem.type] then
				table.insert(ret, goods.id)
			end
		end
	end
	return ret
end

--隐藏时装
function ma_data.hide_dress(goods_id,hide)
	local g = ma_data.find_goods(goods_id)
	if ma_data.is_goods_time_out(g) then
		return 1
	end
	g.hide = hide
	skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {backpack = ma_data.db_info.backpack})
	return 0,hide
end
--穿戴时装
function ma_data.dress_goods(goods_id, sync_db, add_dress)
	--类型相同的需要先脱掉
	local gItem = cfg_items[goods_id]
	--穿戴需要统一同步变化的时装
	local syncGoods = {}
	local g = ma_data.find_goods(goods_id)
	if ma_data.is_goods_time_out(g) then
		return 1
	end
	--穿之前需要先脱掉
	if BAG_DRESS_TYPE_RELATIONS[gItem.top_type] and g.num > 0 then
		if BAG_DRESS_SET_LIST[gItem.type] then
			--套装需要全部脱掉
			ma_data.drop_all(goods_id,syncGoods)
		else
			--部件需要脱掉对应的其他部件
			if TYPE_MAP_SET[gItem.type] then
				ma_data.drop_set(goods_id, TYPE_MAP_SET[gItem.type],syncGoods)
				-- table.print(syncGoods)
			end
			ma_data.drop_similar_goods(goods_id, syncGoods)
		end
		g.usetime = os.time()
		if not g.endtime and gItem.time ~= 0 then
			g.endtime = os.time() + ONE_DAY * gItem.time*g.num
		end
		table.insert(syncGoods, g)
		if not add_dress then
			ma_data.send_push("sync_goods", {goods_list = syncGoods})
		end
		--print('================更换头像================',gItem.top_type,BAG_PICTURE_FRAME,goods_id)
		if gItem.top_type == BAG_PICTURE_FRAME then
			ma_data.db_info.headframe = goods_id
			skynet.call('ranklist_mgr', "lua", "update_headframe", ma_data.my_id,goods_id)
		end

		if sync_db then
			skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {backpack = ma_data.db_info.backpack,
																				headframe = ma_data.db_info.headframe})
		end
		return 0
	else
		return 1
	end
end

--默认装扮物品
function ma_data.add_dress_goods_handle(goods,sync_db)
	local gItem = cfg_items[goods.id]
	-- if goods.id == 300001 then
	-- 	print('===============头像框=======',BAG_PICTURE_FRAME,gItem.top_type)
	-- end
	--默认装扮
	if BAG_TOP_TYPE_ROLE_DRESS == gItem.top_type or BAG_TOP_TYPE_PET_DRESS == gItem.top_type or 
			BAG_TOP_TYPE_TTTOP_DRESS == gItem.top_type or BAG_TOP_TYPE_HOME_DRESS == gItem.top_type
			or BAG_PICTURE_FRAME == gItem.top_type then
		--是否临时道具
		-- goods.tmp = gItem.time > 0
		goods.gettime = os.time()
		--goods.etime = gItem.time * 24 * 60 * 60 + goods.gettime
		if 1 == gItem.default or 1 == gItem.use then
			--获取立即传递上
			print("add_goods dress",goods.id)
			ma_data.dress_goods(goods.id, sync_db, true)
		end
		-- if goods.num > 1 then
		-- 	goods.num = 1
		-- end
	end
	--默认桌面和牌背
	if BAG_TOP_TYPE_TTTOP_DRESS == gItem.top_type then
	end
end

local function is_prestige_benefit_goods(goods_id)
	return goods_id == ITEM_TYPE_ZIMO_CARD or
		goods_id == ITEM_TYPE_PENGGANG_CARD or
		goods_id == ITEM_TYPE_DOUBLE_PRESTIGE_CARD
end

function ma_data.use_goods(goods_id, use)
	local conf = cfg_items[goods_id]
	if not conf then
		return 1
	end
	local goods = ma_data.find_goods(goods_id)
	if is_prestige_benefit_goods(goods_id) then
		if ma_data.my_room then
			return 3
		end
		if goods.num == 0 then
			return 4
		end
		if use then
			goods.usetime = os.time()
		else
			goods.usetime = nil
		end
	else
		return 2
	end
	skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {backpack = ma_data.db_info.backpack})
	ma_data.send_push("sync_goods", { goods_list = { goods } })
	return 0
end

-- 添加物品到背包
function ma_data.add_goods(goods,way,detail,from_room,sync_db,out,subjoinDesc)
	local goods_pack = cfg_items[goods.id]
	if goods_pack.gender ~= SEX_UNKNOWN and goods_pack.gender ~= ma_data.db_info.sex then
		print("add_goods sex error", ma_data.my_id,goods_pack.gender)
		return
	end

	assert(way and ("string" == type(detail)))
	local g = ma_data.find_goods(goods.id)
	if goods_pack.time and goods_pack.time > 0 then
		--获得一个有时效性的道具
		if (not g.gettime) or ma_data.is_goods_time_out(g) then
			g.gettime = os.time()
			g.endtime = nil
			g.usetime = nil
			g.num = goods.num
		else
			g.num = g.num + goods.num
			if g.endtime then
				g.endtime = g.endtime + goods.num*ONE_DAY
			end
			if g.num < 0 then
				g.num = 0
				--写入数据库
			end
		end
		--print('======添加物品到背包3333=======',goods.id,goods.num,g.num)
	else
		g.num = g.num + goods.num
		if g.num < 0 then
			g.num = 0
			--写入数据库
		end
		ma_data.add_dress_goods_handle(g, sync_db)
	end
	
	ma_data.insert_goods_rec(goods.id,g.num - goods.num,goods.num,way,detail,subjoinDesc)
	
	--print("add_goods", g.id, g.num,goods.num)
	if not out then
		ma_data.send_push("sync_goods", {goods_list = {g}})
	else
		table.insert(out,g)
	end

	if sync_db then
		skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {backpack = ma_data.db_info.backpack})
	end

	if ma_data.my_room and not from_room then
		-- pcall(skynet.send, ma_data.my_room, "lua", "sync_goods", ma_data.my_id,100008, ma_data.db_info.backpack)
	end
	skynet.send("data_goods_mgr","lua","goods_add_sub",ma_data.db_info.channel,goods.id,way,goods.num)
	return g
end

-- 添加物品列表
function ma_data.add_goods_list(goods_list, way, detail, from_room,subjoinDesc)
	-- table.print(goods_list)
	--print('===============添加物品列表===',way,detail)
	assert(way and ("string" == type(detail)))
	local out = {}
	for _,goods in ipairs(goods_list) do
		local cfg = mall_conf[goods.id]
		if goods.id == GOODS_GOLD_ID then
			ma_data.add_gold(goods.num, way, detail, from_room,true,out,subjoinDesc)
		elseif goods.id == GOODS_DIAMOND_ID then
			ma_data.add_diamond(goods.num, way, detail, from_room,true,out,subjoinDesc)
		-- elseif cfg.type == BAG_TYPE_MONTN_CARD then
		-- 	ma_data.ma_month_card.on_buy_card(cfg.quality)
		else
			--增加vipPoint统计
			if goods.id == VIP_POINT then
				local delta,vp_cell
				if way == GOODS_WAY_TASK_AWARD then
					vp_cell,delta = ma_data.add_vp_daily("daily_task",goods.num)
				end
				if way == GOODS_WAY_FIXHOUR then
					vp_cell,delta = ma_data.add_vp_daily("online_times",goods.num)
				end
				if way == GOODS_WAY_XIXI_GIFT then
					vp_cell,delta = ma_data.add_vp_daily("xixi_gift",goods.num)
				end
				if way == GOODS_WAY_AD then
					vp_cell,delta = ma_data.add_vp_daily("watch_any_ads",goods.num)
				end
				
				if delta>0 then
					goods.num = delta --修正点数上限
					ma_data.add_goods(goods, way, detail, from_room,true,out,subjoinDesc)
					ma_data.update_viplv()
				end
			else
				ma_data.add_goods(goods, way, detail, from_room,true,out,subjoinDesc)
			end 
			
		end
	end

	if #out > 0 then
		-- table.print('===============out========')
		-- table.print(out)
		ma_data.send_push("sync_goods", {goods_list = out})
	end

	skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {backpack = ma_data.db_info.backpack})
end

function ma_data.IsItemEnabled(itemid)
	local item = ma_data.find_goods(itemid)
	return  item and item.num > 0 and item.usetime
end


function ma_data.follow_conf(ma, tbl_name)
	local ma_list = ma_data.tbl2ma[tbl_name] or {}
	table.insert(ma_list, ma)
	ma_data.tbl2ma[tbl_name] = ma_list
end

return ma_data

