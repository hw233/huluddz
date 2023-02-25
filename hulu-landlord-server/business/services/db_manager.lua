local skynet = require "skynet"
--local queue = require "skynet.queue"
require "table_util"
require "define"
local COLLECTIONS = require "config/collections"
local COLL_INDEXES = require "config.coll_indexes"
local Mongolib = require "Mongolib"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

ServerData.POOL = {}
ServerData.INDEX = 1
ServerData.dbType = nil -- db 功能类型， 是写业务数据还是记录数据
ServerData.indexCache = {} -- 已经检测过的索引

ServerData.max_user_id = 1000000 --当前最大游戏ID记录


-- local func
function CMD.index_inc( )
	ServerData.INDEX = ServerData.INDEX + 1
	if ServerData.INDEX == #ServerData.POOL + 1 then
		ServerData.INDEX = 1
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


function CMD.write_record(tableName, selector, obj)
    CMD.index_inc()

    local collObj = COLL_INDEXES[tableName]
	if collObj then
		if collObj.dbpoolname ~= ServerData.dbType then
			skynet.loge("写入日志类型错误")
		end

		local db = ServerData.POOL[ServerData.INDEX]

		local realTableName = tableName
        if collObj.split then
            local time = os.date("%Y%m")
            realTableName = tableName.."_"..time
		    CMD.create_index(db, tableName, realTableName)
        end

		if selector then
			return db:update_insert(realTableName, selector, obj)
		else
			return db:insert(realTableName, obj)
		end
	else
		skynet.loge("write_record error!", tableName, table.tostr(obj))
	end
end



function CMD.NewUserInfoData(openid, baseObj, setObj)
	setObj = setObj or {}

	CMD.index_inc()

	local id = CMD.get_a_id()
	local user = {}
	if baseObj then
		for k,v in pairs(baseObj) do
			user[k] = v
		end
	end

	user.id = id
	user.openid = openid

	local time = os.time()
	do
		user.online = true
		user.onlineDt = time
		user.offlineDt = time
		user.onlineTimes = 0
		user.onlineTimeDay = 0

		user.firstLoginDt = time
		user.loginTime = 0
		user.loginDays = 0

		user.gold = 0
		user.diamond = 0

		user.lv = 1
		user.exp = 0
		user.vip = 0
		user.vipExp = 0
		user.nickname = "玩家_" .. id
		--user.headimgurl = info.headimgurl or defaultheads[math.random(1, #defaultheads)],

		user.pay = 0
		user.payMonth = 0
		user.payDayCount = 0

		user.gender = GenderEnum.BOY
		user.area = nil
		user.name = user.openid
		user.idcard = user.openid
		user.ipRegister = baseObj.ip
		user.ipLast = baseObj.ip
	end

	table.merge(user, setObj)

	ServerData.POOL[ServerData.INDEX]:insert(COLLECTIONS.USER, user)
	if baseObj.os ~= "ios" then
		skynet.send("cd_collecter", "lua", "register", baseObj.channel)
	end
	return user
end

---comment 登录流程才用这个
CMD.GetUserInfoData = function (openid, base, isSdkLogin)
	-- 游客登录第三方账号 如微信,vivo账号
	if openid:sub(1,1) == "@" then
		openid = openid:sub(2, #openid)
	end
	CMD.index_inc()
	local dbConnectObj = ServerData.POOL[ServerData.INDEX]

	local tbl_match = {openid = openid, disabled = {['$ne'] = true}}
	if base.sdk == "QQ" then
		tbl_match = {openid = openid, os = base.os, disabled = {['$ne'] = true}}
	end
	local user = dbConnectObj:find_one(COLLECTIONS.USER, tbl_match)
	if user then
		if isSdkLogin then
			-- msgagent 里登录才算真登录
			-- 这里的登录只算验证用户
			user.dbLoginDt = os.time()
			dbConnectObj:set_update(COLLECTIONS.USER, {id = user.id}, {dbLoginDt = user.dbLoginDt})
		end
	end
	return user
end




function CMD.create_index(db, tableName, realTableName)
	if ServerData.indexCache[realTableName] then
		return
	end
	local coll = COLL_INDEXES[tableName]
	db:createIndexes(realTableName, table.unpack(coll.indexes))
	ServerData.indexCache[realTableName] = true
end

-- 根据索引表获取 索引名
function CMD.get_index_name(idxs)
    local inxtbl = {}
    for _, inx in ipairs(idxs) do
        local n = ""
        for _, tmp in pairs(inx) do
            for k, v in pairs(tmp) do
                if n == "" then
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
	for name, coll in pairs(COLL_INDEXES) do
		if coll.dbpoolname == ServerData.dbType then
			if coll.split then
				name = name.."_"..time
			elseif coll.split_day then
				name = name .. "_" .. daytime
			end
			local db = ServerData.POOL[1]
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
						skynet.loge("error :",name .. "表创建索引失败")
					end
				end
			end
			ServerData.indexCache[name] = true
		end
	end
end

-- 同步创建过的索引
function CMD.sync_yet_indexes()
	return ServerData.indexCache
end

function CMD.inject(filePath)
    require(filePath)
end


local isInit = false

---comment
---@param dbConfigArr table 数据库连接配置数组
---@param dbType string 本db服务功能类型， 兼容代码 coll_indexes.lua 中的 dbpoolname, 传入此参数会检查该类型集合索引
function CMD.init(dbConfigArr, dbType, isMain)
	if isInit then
		return
	end
	isInit = true

	local dbConnectNum = math.max(tonumber(skynet.getenv("dbConnectNum")) or 32, 1)

	for i = 1, dbConnectNum do
		local m = Mongolib.new()
		local dbInfo = (dbConfigArr)[i % (#(dbConfigArr)) + 1]
	    m:connect(dbInfo)
	    m:use(dbInfo.name)
	    table.insert(ServerData.POOL, m)
	end

	-- TODO:新的 db_manager 职责单一，只负责 dbType 参数指定的数据表。
	ServerData.dbType = dbType

	if isMain then
		if dbType == "POOL" then
			-- 获取当前最大的ip
			-- 查找最后一条记录
			local last_info = ServerData.POOL[ServerData.INDEX]:load_all(COLLECTIONS.USER, {}, {id = true}, {firstLoginDt = -1,}, 1, 1)
			if last_info and #last_info > 0 and #last_info[1].id > 6 then
				ServerData.max_user_id = tonumber(last_info[1].id)
			end
	
			-- 保证现在的id是最大的
			repeat
				local id = CMD.get_a_id()
				CMD.index_inc()
			until (not ServerData.POOL[ServerData.INDEX]:find_one(COLLECTIONS.USER, {id = id}))
	
			ServerData.max_user_id = ServerData.max_user_id - 1
		end

		CMD.check_indexes()
	else
		-- 需要同步无需分表的记录，防止调用错误导致重复创建索引
		ServerData.indexCache = skynet.call("db_manager", "lua", "sync_yet_indexes")
	end
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
end)