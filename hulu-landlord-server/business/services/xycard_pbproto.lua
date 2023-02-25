local skynet = require "skynet"
local sharetable = require "skynet.sharetable"

local protos = {
	-- "all.pb",
	"public_1p.proto",				--公共结构等
	"hall_2p.proto",					--大厅相关（匹配，获取场次信息等）
	"store_3p.proto",					--商店相关
	"fight_4p.proto",				--俄罗斯方块游戏相关
	"room_public_5p.proto",			--房间公共相关
	"active_6p.proto",
	"dress_7p.proto", 				--时装穿戴
	"chat_9p.proto",					--好友
	"pet_10p.proto",					--宠物
	"lottery_11p.proto",				--抽奖
	"month_sign_12p.proto",			--签到
	"month_card_13p.proto",			--月卡
	"growth_plan_14p.proto",			--成长计划
	"day_comsume_15p.proto",			--日常连续消费
	"seven_day_sign_16p.proto",		--七天签到
	"common_17p.proto",				--公共模块
	"family_18p.proto",				--家园系统
	"tk_kings_19p.proto",				--千王之王
	"three_one_20p.proto",			--三缺一
	"ma_hall_frame_21p.proto",		--雀神名人堂 
	"roomPetSkills_22p.proto",		--房间宠物技能
	"ranklist_23p.proto",				--排行榜
	"booster_24p.proto",				--助力礼包协议
	"heilao_25p.proto",				--海底捞
	"qq_wallet.proto"				--红包接口
}

local pbidfile = "Cmd.ts"
local pbmaps = "CmdStr.lua"


local function initpbs()
	local pbs = ""

	local root = skynet.getenv("root")

	-- 加载协议
	root = root .. "business/pbprotos/"
	for _,name in ipairs(protos) do
		local f = assert(io.open(root .. name , "rb"))
		local buffer = f:read "*a"
		pbs = pbs .. buffer
		f:close()
	end

	sharetable.loadtable("pbprotos",{pbs})

	-- 加载协议索引文件
	local f = assert(io.open(root .. pbidfile,"rb"))
	local pbids = {}

	-- print("------------------------message_define.proto")
	-- table.print(f:lines())

	for line in f:lines() do
		-- local message_id,message_name = string.match(line,'%[(%d+)%]%s+=%s+"([%w_.]+)"')
		-- print(line)
		local name,id = string.match(line,'([%w_.]+)%s+=%s+(%d+)')
        if name and id then
            id = assert(tonumber(id))
            assert(pbids[name] == nil)
            assert(pbids[id] == nil)
            pbids[name] = id
            pbids[id] = name
			
			-- print("====debug qc==== pbids  name id",name,id)
        end
	end

	sharetable.loadtable("pbids",pbids)


	local f = io.open(root .. pbmaps,"rb")
	local t = load(f:read "*a")()

	local pbmaps = {}

	for i,v in ipairs(t) do
		pbmaps[i - 1] = v
		pbmaps[v] = i - 1
	end

	sharetable.loadtable("pbmaps",pbmaps)

	f:close()


	return pbs
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)

	initpbs()

	skynet.exit()
end)