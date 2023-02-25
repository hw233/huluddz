local skynet = require "skynet"
local queue = require "skynet.queue"
require "pub_util"
require "table_util"
require "define"
local CONFIG = require "server_conf"
local COLLECTIONS = require "config/collections"
local COLL_INDEXES = require "config/coll_indexes"
local Mongolib = require "Mongolib"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

-- 设置一个db_mgr 初始化时检测索引
local check_db_index = ...

ServerData.POOL = {} 		-- 处理游戏逻辑的数据库链接(如 用户表)
ServerData.POOL_REC = {}	-- 处理数据记录的数据链接 (如金币消耗记录,道具记录)
ServerData.INDEX = 0
ServerData.INDEX_REC = 0
ServerData.max_user_id = 1000000 --当前最大游戏ID记录
ServerData.max_invite_code = 1000000000 --当前最大游戏邀请码


ServerData.yetIndx = {} -- 已经检测过的索引
-- upvalue
ServerData.CURRENT_MAX_PID = nil

ServerData.tourist_id = nil

ServerData.proportion = nil

ServerData.temp_meinv_index = nil

-- local func
function CMD.index_inc( )
	ServerData.INDEX = ServerData.INDEX + 1
	if ServerData.INDEX == #ServerData.POOL + 1 then
		ServerData.INDEX = 1
	end
end

function CMD.index_rec_inc()
	ServerData.INDEX_REC = ServerData.INDEX_REC + 1
	if ServerData.INDEX_REC == #ServerData.POOL_REC + 1 then
		ServerData.INDEX_REC = 1
	end
end

-- 获取 游戏id 和 游戏码
function CMD.get_a_id( )
	ServerData.max_user_id = ServerData.max_user_id + 1
	return tostring(ServerData.max_user_id)
end

----------------------------------------------------------------------------
-- mongo 增删查改
----------------------------------------------------------------------------
function CMD.insert(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:insert(...)
end

function CMD.delete(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:delete(...)
end

function CMD.find_one(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:find_one(...)
end

function CMD.find_all(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:find_all(...)
end

function CMD.find_all_skip(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:find_all_skip(...)
end

function CMD.update(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:set_update(...)
end

function CMD.update_insert( ... )
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:update_insert(...)
end

function CMD.update_multi( ... )
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:update_multi(...)
end

-- 替换(全量更新)
function CMD.replace(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:update(...)
end

function CMD.max(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:get_max(...)
end

function CMD.count(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:get_count(...)
end

function CMD.push(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:push(...)
end

function CMD.push_insert(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:push_insert(...)
end

function CMD.sum( ... )
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:sum(...)
end

function CMD.pull(...)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:pull(...)
end

---------------------------------------------------------------------------
-- call by httpserver2 (web)
----------------------------------------------------------------------------


---------------------------------------------------------------------------
-- call by rec 
----------------------------------------------------------------------------

function CMD.rec_insert(name, ...)
	CMD.index_rec_inc()
	local oname = name
	local coll = COLL_INDEXES[name]
	local db = ServerData.POOL_REC[ServerData.INDEX_REC]
	if coll.split then
		local time = os.date("%Y%m")
		name = name.."_"..time
		CMD.create_index(db,name,oname)
	end

	return db:insert(name,...)

end

function CMD.rec_find_one(name,...)
	CMD.index_rec_inc()
	local oname = name
	local coll = COLL_INDEXES[name]
	local db = ServerData.POOL_REC[ServerData.INDEX_REC]
	if coll.split then
		local time = os.date("%Y%m")
		name = name.."_"..time
		CMD.create_index(db,name,oname)
	end
	return db:find_one(name,...)
end

function CMD.day_rec_insert(name, ...)
	CMD.index_rec_inc()
	local oname = name
	local coll = COLL_INDEXES[name]
	local db = ServerData.POOL_REC[ServerData.INDEX_REC]
	if coll.split then
		local time = os.date("%Y%m%d")
		name = name.."_"..time
		CMD.create_index(db,name,oname)
	end

	return db:insert(name,...)

end

function CMD.day_rec_find_all(name,...)
	CMD.index_rec_inc()
	local oname = name
	local coll = COLL_INDEXES[name]
	local db = ServerData.POOL_REC[ServerData.INDEX_REC]
	if coll.split then
		local time = os.date("%Y%m%d")
		name = name.."_"..time
		CMD.create_index(db,name,oname)
	end
	return db:find_all(name,...)
end

function CMD.userinfo( p_id )
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:find_one(COLLECTIONS.USER, {id = p_id})
end

function CMD.disable_user(id)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:set_update(COLLECTIONS.USER, {id = id}, {disabled = true})
end

----------------------------------------------------------------------------

-----------------------------------------

function get_tourist_id( )
	ServerData.tourist_id = ServerData.tourist_id - 1
	if ServerData.tourist_id == 0 then
		ServerData.tourist_id = CONFIG.TOURIST_MAX_ID
	end
	return ServerData.tourist_id
end

-- only test
-- local test_id = 1000000
function get_test_id( )
	local test_id = math.random(200000,999999)

	-- print('==================== test_id',test_id)
	return test_id
end

function CMD.buy_suc(pid, goods_id, list_id)
	-- body
end
------------ accept -----------------------------------------------------------
function CMD.get_user_info( p_id )
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:find_one(COLLECTIONS.USER,{id = p_id})
end

function CMD.update_userinfo( p_id, tbl )
	CMD.index_inc()
	ServerData.POOL[ServerData.INDEX]:set_update(COLLECTIONS.USER,{id = p_id},tbl)
end


local function newUserInfoData(baseObj, ip, isVisitor, base)
	local time = os.time()
	local t = {}
	if base then
		for k,v in pairs(base) do
			t[k] = v
		end
	end

	t['id'] 		      	= baseObj.id
	t['openid'] 		    = baseObj.openid

	t['online'] 		    = true
	t['onlineDt'] 		    = time
	t['offlineDt'] 		    = time
	t['onlineTimes'] 		= 0
	t['onlineTimeDay'] 		= 0

	t['firstLoginDt'] 		= time
	t['loginTime'] 		    = 0
	t['loginDays'] 		    = 0

	t['gold'] 		    	= 0
	t['diamond'] 		    = 0

	t['lv'] 		    	= 0
	t['exp'] 		    	= 0
	t['vip'] 		    	= 0
	t['vipExp'] 		    = 0
	t['nickname'] 		    = baseObj.nickname
	t['head'] 		    = baseObj.headimgurl
	--t['headFrame'] 		    = ""
	--t['title'] 		    = ""
	--t['chatFrame'] 		    = ""

	t['pay'] 		    	= 0
	t['payMonth'] 		    = 0
	t['payDayCount'] 		= 0

	t['gender'] 		    = baseObj.gender
	t['area'] 		    = baseObj.openid
	t['name'] 		    = baseObj.openid
	t['idcard'] 		    = baseObj.openid

	--t["reg_ip"]        		= ip    -- 注册ip
	--t["last_ip"]        	= ip 	-- 最后登陆ip

	--t["invalid_headimg"]    = false -- 非法头像
	--t["forbid_time"] 		= 0 	-- 大于0则是被封禁
	--t["forbid_reason"] 		= "" 	-- 封禁理由

	--t["last_recharge_time"] = 0 	   -- 最后一次充值时间

	--t["en_emotion"] = -1 --入场表情id

	--t["lian_win"] = 0 	--连胜场次
	--t["today_lian_win"] = {count = 0, t = os.time()} 	--连胜场次
	--t["playinfo"] = {winc=0,total=0,gameTypec = {}} --胜利场次
	--t["curr_age"] = 0--年齡

	--t["today"] = os.date("%Y%m%d")

	--t["disabled"] = false



	--t["vip_reward"] = 0 -- vip奖励标记时间戳
	--t["QQ_Wallet"] = 0 -- QQ 网赚版本 红包余额
	--t["guide_info"] = {0,0,0,0,0}

	--t["month_card"] = {total_day=0,type=0,begin_time=0,get_time = 0} --月卡信息 total_day:总的天数 type:月卡类型 
	--t["growth_plan"] = {active = false, win_count = 0, award_status = 0} --award_status int 位运算 第几天第几位 0表示未领取 1表示已领取
	-- t["month_sign"] = {status=0,c_award=0,mtime=os.time()}--status 奖励领取状态 c_award 连续签到领取状态
	-- t["d_diamond_c"] = {num=0,status=0,t=os.time()} --每日钻石消费
	-- t["d_fee_c"] = {num=0,status=0,t=0} --每日连冲
	-- t["tdiamond_award"] = {status=0} --累积充值奖励
	-- t["seven_sign"] = {status={0,0,0,0,0,0,0},mtime=0,rf=0}
	-- t["t_award"] = {t=0,rank=0} --t:结算时间,rank结算排名
	-- --名人堂 t:参考时间 prestige:声望值 erank 结算排行 eprestige 结算声望 seg_prestige 段位声望 max_prestige 最大声望
	-- t["hall_frame"] = {t=os.time(),prestige=1000,erank=0,award_status=0,max_prestige=1000,seg_prestige=1000,winc=0,total=0,eprestige=0}
	-- --番王榜 t:参考时间 multipleKing:番数 erank 结算排行 cards 牌
	-- t["multipleKing"] = {t=os.time(),multipleKing=0,erank=0,cards=0}
	-- --十八罗汉 t:参考时间 useTime1:时间 erank 结算排行 cards1 牌
	-- t["eighteenMonk"] = {t=os.time(),useTime1=0,erank=0,cards1=0}
	-- --四暗刻 t:参考时间 useTime2:时间 erank 结算排行 cards2 牌
	-- t["fourThree"] = {t=os.time(),useTime2=0,erank=0,cards2=0}
	-- --九莲宝灯 t:参考时间 useTime3:时间 erank 结算排行 cards3 牌
	-- t["nineLamp"] = {t=os.time(),useTime3=0,erank=0,cards3=0}
	-- t["lianWinRank"] = {t=os.time(), erank=0, count=0}
	-- t["bailout"] = {t=os.time(),count=0}
	-- t["booster_bag_rank"] = {t=os.time(),rank=0,buy_count=0}--t:周参考时间,rank:排行榜名次,buy_count:购买次数
	-- t["match_box"] = {num=0,status=0,t=os.time()}--对局宝箱
	
	return t
end

--扩展方法 增补初始化db数据
local function initDbinfo(u)
	local bAppend_col
	if u and u.guide_info ==nil then
		u.guide_info = {0,0,0,0,0}
		bAppend_col = "guide_info"
	end
	return bAppend_col
end

function CMD.get_player_dbinfo(openid, base, ip, on_login)
	-- 游客登录第三方账号 如微信,vivo账号
	if openid:sub(1,1) == "@" then
		openid = openid:sub(2,#openid)
	end
	CMD.index_inc()
	local tbl_match = {openid = openid, disabled = {['$ne'] = true}}
	if base.sdk == "QQ" then
		tbl_match = {openid = openid, os = base.os, disabled = {['$ne'] = true}}
	end
	local u = ServerData.POOL[ServerData.INDEX]:find_one(COLLECTIONS.USER, tbl_match)
	local last_time = u and u.last_time

	if u then
		if on_login then
			u.last_ip = ip
			u.loginTime = u.loginTime + 1
			ServerData.POOL[ServerData.INDEX]:set_update(COLLECTIONS.USER, {id = u.id}, {last_ip = ip, loginTime = u.loginTime})
		else
			u.last_time = os.time()
			ServerData.POOL[ServerData.INDEX]:set_update(COLLECTIONS.USER, {id = u.id}, {last_time = u.last_time})
		end
	end

	--增补dbinfo
	-- local bAppend_col = initDbinfo(u)
	-- if bAppend_col then
	-- 	ServerData.POOL[ServerData.INDEX]:set_update(COLLECTIONS.USER, {id = u.id}, {[bAppend_col] = u[bAppend_col]})
	-- 	print("====debug qc==== 增补初始数据 : ",u.id,bAppend_col)
	-- end
	
	return u, last_time
end



local defaultheads = {
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/youke1.png",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/youke2.png",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/youke3.png",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux11.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux12.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux13.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux14.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux15.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux16.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux17.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux18.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux19.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux20.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux21.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux22.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux23.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux24.jpg",
	"https://xyddzdownload.xixidoudizhu.com/defaulthead/img_toux25.jpg",
}

function CMD.register(openid, base, ip, info)
	info = info or {}

	CMD.index_inc()

	local id = CMD.get_a_id()

	local base_info = {
		id = id,
		openid = openid,
		nickname = info.nick_name or ("玩家_" .. id),
		--headimgurl = info.headimgurl or defaultheads[math.random(1, #defaultheads)],
		gender = info.sex or GenderEnum.Default,
	}

	local user = newUserInfoData(base_info, ip, false, base)
	ServerData.POOL[ServerData.INDEX]:insert(COLLECTIONS.USER, user)
	if base.os ~= "ios" then
		skynet.send("cd_collecter", "lua", "register", base.channel)
	end
	return user
end

-------------------------------------------------------------------
--分享绑定
function CMD.update_share_tbl(p_id,tbl)
	CMD.index_inc()
	ServerData.POOL[ServerData.INDEX]:set_update(COLLECTIONS.SHARE_TBL,{id = p_id},tbl)
end
--获取分享绑定信息
function CMD.get_share_tbl(p_id)
	CMD.index_inc()
	local action_info = ServerData.POOL[ServerData.INDEX]:find_one(COLLECTIONS.SHARE_TBL,{id = p_id})
	if not action_info then
		action_info = {}
		action_info.id = p_id
		action_info.bind_player_id = nil
		action_info.bind_time = nil
		action_info.bind_num = 0		--绑定人数
		action_info.finish_num = 0		--完成人数
		ServerData.POOL[ServerData.INDEX]:insert(COLLECTIONS.SHARE_TBL,action_info)
	end
	return action_info
end

--获取分享绑定人信息
function CMD.get_blind_share_tbl(p_id)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:find_one(COLLECTIONS.SHARE_TBL,{id = p_id})
end

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
--随机获取一个玩家信息
function CMD.randGetAPlayer()
	print('==================随机获取一个')
	local maxid = ServerData.max_user_id > 1000001 and ServerData.max_user_id or 1000001
	local tempID = tostring(math.random(1000001,maxid))
	return ServerData.POOL[ServerData.INDEX]:find_one(COLLECTIONS.USER,{id = tempID},{backpack=true,id=true,sex=true})
end
----------------------------------------------------------------------------
----------------------------------------------------------------------------
--公告，跑马灯
-- 跑马灯
function CMD.get_horse_lamp( )
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:load_all(COLLECTIONS.LAMP)
end

function CMD.delete_horse_lamp( msg_id )
	CMD.index_inc()
	ServerData.POOL[ServerData.INDEX]:delete(COLLECTIONS.LAMP, {msg_id = msg_id})
end

local function local_add_horse_lamp(msg)
	if msg and msg ~= '' then
		CMD.index_inc()

		local msg_id = ServerData.POOL[ServerData.INDEX]:get_max(COLLECTIONS.LAMP, 'msg_id') + 1
		-- print("max id:", msg_id)
		CMD.index_inc()
		ServerData.POOL[ServerData.INDEX]:insert(COLLECTIONS.LAMP,{
				msg_id = msg_id,
				create_time = os.time(),
				msg = msg
			})
		return true
	end
	return false
end

function CMD.add_horse_lamp( msg )
	return local_add_horse_lamp(msg)
end
-----------------------------------------------------------------------------
-------------------------------------------------------------------
-- 获取当日活跃数据
function CMD.get_intraday_active_num()
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:find_one(COLLECTIONS.ACTIVE_DATA,{time = get_today_0_time()}) 
end

-- 设置当日活跃数据
function CMD.insert_intraday_active_num(tbl)
	CMD.index_inc()
	ServerData.POOL[ServerData.INDEX]:insert(COLLECTIONS.ACTIVE_DATA,tbl)
end

function CMD.update_intraday_active_num(tbl)
	CMD.index_inc()
	ServerData.POOL[ServerData.INDEX]:set_update(COLLECTIONS.ACTIVE_DATA,{time = tbl.time},{active_num = tbl.active_num})
end
-------------------------------------------------------------------

-----------------------------------------------------------------------------
-------------------------------------------------------------------
--QQ红包记录
function CMD.get_qq_hb_withdrawal(openid)
	CMD.index_inc()
	return ServerData.POOL[ServerData.INDEX]:find_all(COLLECTIONS.QQ_HB_WITHDRAWAL,{openid = openid},nil,{{create_time = 1}},10)
end

function CMD.insert_qq_hb_withdrawal(tbl)
	CMD.index_inc()
	ServerData.POOL[ServerData.INDEX]:insert(COLLECTIONS.QQ_HB_WITHDRAWAL,tbl)
end

function CMD.update_qq_hb_withdrawal(out_trade_no,tbl)
	CMD.index_inc()
	ServerData.POOL[ServerData.INDEX]:set_update(COLLECTIONS.QQ_HB_WITHDRAWAL,{out_trade_no = tbl.out_trade_no},tbl)
end
-------------------------------------------------------------------
-- 插入一条未完成的支付订单信息
function CMD.insert_pre_order(tbl)
	CMD.index_inc()
	ServerData.POOL[ServerData.INDEX]:insert(COLLECTIONS.PRE_ORDER,tbl)

 --    -- 删除7天前的
	-- CMD.index_inc()
	-- local selector = {}
	-- selector.time = {['$lt'] = os.time() - 3600*24*7}
	-- ServerData.POOL[ServerData.INDEX]:delete(COLLECTIONS.PRE_ORDER,selector)

end

function CMD.get_pre_order(out_trade_no)
	CMD.index_inc()
	local pre_order = ServerData.POOL[ServerData.INDEX]:find_one(COLLECTIONS.PRE_ORDER,{out_trade_no= out_trade_no})
	return pre_order
end
-- 根据微信 unionid 获取游戏信息
function CMD.get_dbinfo_by_unionid(unionid)
	CMD.index_inc()
	local db_info = ServerData.POOL[ServerData.INDEX]:find_one(COLLECTIONS.USER,{unionid = unionid})
	return db_info
end

function CMD.create_index(db,name,oname)
	if ServerData.yetIndx[name] then
		return
	end
	local coll = COLL_INDEXES[oname]
	db:createIndexes(name,table.unpack(coll.indexes))
	ServerData.yetIndx[name] = true
end

-- 根据索引表获取 索引名
function CMD.get_index_name(idxs)
	local inxtbl = {}
	for _,inx in ipairs(idxs) do
		local n = ''
		for _,tmp in pairs(inx) do
			for k,v in pairs(tmp) do
				if n == '' then
					n = n .. k .. "_" .. v 
				else
					n = n .. "_" .. k .. "_" .. v
				end
			end
		end
		inxtbl[n] = inx
	end
	return inxtbl
end

-- 检查索引
function CMD.check_indexes()
	local time = os.date("%Y%m")
	local daytime = os.date("%Y%m%d")
	for name,coll in pairs(COLL_INDEXES) do
		if coll.split then
			name = name.."_"..time
		elseif coll.split_day then
			name = name .. "_" .. daytime
		end
		if ServerData[coll.dbpoolname] then
			local db = ServerData[coll.dbpoolname][1]
			local indexes = db:getIndexes(name)

			if not indexes then
				-- 直接创建 全部索引
				db:createIndexes(name,table.unpack(coll.indexes))
			else
				-- 查找差值 创建索引
				local needIdxs = CMD.get_index_name(coll.indexes)
				local ownIdxs = {}
				for _,inx in ipairs(indexes) do
					if inx.name ~= '_id_' then  -- 该索引为mongo 创建表时默认 索引
						ownIdxs[inx.name] = true
					end
				end
				local addInxs = {}
				for k,v in pairs(needIdxs) do
					if not ownIdxs[k] then
						table.insert(addInxs,v)
					end
				end
				if #addInxs > 0 then
					-- 查看数据长度,大于 一定值后不创建
					local count = CMD.count(name)
					if count < 1000 then
						-- 创建索引
						db:createIndexes(name,table.unpack(addInxs))
					else
						skynet.error("error :",name .. "表创建索引失败")
					end
				end
			end

			ServerData.yetIndx[name] = true
		end
	end
end

-- 同步创建过的索引
function CMD.sync_yet_indexes()
	return ServerData.yetIndx
end

function CMD.inject(filePath)
    require(filePath)
end


local function init( )
	local dbconfs = skynet.call("load_gameconf","lua","get_dbconfs")
	ServerData.INDEX = 1
	ServerData.INDEX_REC = 1

	local dbConnectNum = math.max(tonumber(skynet.getenv("dbConnectNum")) or 32, 1)

	for i=1,dbConnectNum do
		local m = Mongolib.new()
		local dbInfo = (dbconfs.main)[i % (#(dbconfs.main)) + 1]
	    m:connect(dbInfo)
	    m:use(dbInfo.name)
	    table.insert(ServerData.POOL,m)
	end
	for i = 1,dbConnectNum do
		local m = Mongolib.new()
		local dbInfo = (dbconfs.rec)[i % (#(dbconfs.rec)) + 1]
		m:connect(dbInfo)
	    m:use(dbInfo.name)
	    table.insert(ServerData.POOL_REC,m)
	end

	--获取当前最大的ip
	-- 查找最后一条记录
	--print('ssssssssssssssssssssssssssssssssss', CONFIG.COLLECTIONS.USER)
	local last_info = ServerData.POOL[ServerData.INDEX]:load_all(COLLECTIONS.USER,{},{id = true},{firstLoginDt = -1,},1,1)
	-- table.print(last_info)
	if last_info and #last_info > 0 and #last_info[1].id > 6 then
		ServerData.max_user_id = tonumber(last_info[1].id)
	end
	-- 保证现在的id是最大的
	repeat
		local id = CMD.get_a_id()
		CMD.index_inc()
		-- print(id)
	until (not ServerData.POOL[ServerData.INDEX]:find_one(COLLECTIONS.USER, {id = id}))
	ServerData.max_user_id = ServerData.max_user_id - 1
	ServerData.max_invite_code = ServerData.max_invite_code - 1
	if check_db_index then
		CMD.check_indexes() -- 同步索引
	else
		-- 同步创建过的索引记录
		ServerData.yetIndx = skynet.call("db_mgr","lua","sync_yet_indexes")
	end
end

skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    skynet.dispatch("lua", function(_, _, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
    init()
end)