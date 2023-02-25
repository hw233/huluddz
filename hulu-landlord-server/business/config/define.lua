
Int32MaxValue = 2147483647

-- [Flags]
ServerType = {
	Game	= 4,
	Login 	= 8,
	Client	= 16,
	Manger	= 128,
	All 	= 220,
}

RET_VAL = {
	Default_0 = 0,
	Succeed_1 = 1,
	Fail_2 = 2,
	ERROR_3 = 3,
	Exists_4 = 4,
	NotExists_5 = 5,
	Lack_6 = 6,
	Empty_7 = 7,
	NoUse_8 = 8,
	NotOpen_9 = 9,
	Other_10 = 10,
	Other_11 = 11,
	Other_12 = 12,
	Other_13 = 13,
	Other_14 = 14,
	Other_15 = 15,
	Other_16 = 16,
	Other_17 = 17,

}

-- 事件枚举
EventxEnum = {
	UserDataGet = 100,		-- getuserinfo时触发

	UserNewDay = 1001, 		-- 新的日触发
	UserNewWeek = 1002,		-- 新的周触发
	UserNewMonth = 1003,	-- 新的月触发

	UserNewMinutes = 1006,	-- 新的分触发
	UserOnline = 1030,		-- 登录触发
	UserOffline = 1031,		-- 离线触发

	UserTimeEnd = 1060,
	
	UserNewPendingData		= 1070,	-- 有未处理的待处理数据

	UserPay 				= 1100,			-- 充值触发
	UserStoreBuy			= 1200,			-- 商城购买礼包
	UserVipUpLv			    = 1201,			-- VIP升级

	UserItemUpdate 			= 3001,			-- 道具增加 or 减少都触发
	UserHeroAdd 			= 3002,
	HeroMoodUp				= 3003,
	HeroSkillUp				= 3004,

	RuneAdd 				= 3101,
	RuneLvUp 				= 3102,

	UserBonusDataChange		= 3500,			-- 加成数据变动

	GourdWatering 			= 4001,
	GourdFertilizer 		= 4002,
	GourdLoosenSoil 		= 4003,
	GourdPickFruit          = 4004, --摘取金豆

	RoomGameStar 			= 10000,
	RoomGameDealCard		= 10001,
	RoomPlayerMessage 		= 10002,		-- 房间对局发送到玩家的消息
	RoomPlayerAction 		= 10003,		-- 房间对局玩家操作
	RoomGameOver			= 10005,
	RoomGameReward			= 10008,		-- 对局获取奖励
	RoomGameLostGold		= 10009,		-- 对局输豆处理

	RoomGameTake_QQP		= 11000,		-- 对局拿牌事件_七雀牌
	RoomGameHu_QQP			= 11001,		-- 对局胡牌事件_七雀牌


	AdvertLook 				= 20001,
	UserGiftSend 			= 20002,
	VisitorPlayer 			= 20003,
	DWAnnounce              = 20004,   --段位升级广播
	SysAnnounce             = 20005,   --系统公告
	SysAnnounceTxt          = 20006,   --系统公告
	SysAnnounceImg          = 20007,   --系统公告

	TaskReward              = 30003,	-- 领取任务奖励
	UserRq                  = 30004,	-- 人气
	UserDz                  = 30005,	-- 点赞
	UserBDz                 = 30006,	-- 被点赞
	UserUseTitle            = 30007,	-- 穿戴称号
	UserLoginContinue       = 30008,    --持续登陆天数
	UserConWinOrLose        = 30009,    --持续连胜连败次数
	AddAchievement          = 30010,    --成就
	ProtectWinStreak        = 30011,
	CheckItemExpire         = 20008,   --背包过期时间事件
	ItemExpire              = 20009,   --背包过期时间事件

	ActOpenExent            = 30001,	-- 活动开启事件
	ActCloseExent           = 30002,	-- 活动关闭事件

	WriteLog                = 40001,	-- 数据埋点事件


}

-- 服务间事件枚举
EventCenterEnum = {
	GameFunc = "GameFunc",

	NewUserAnnounce = "NewUserAnnounce",
	NewSysAnnounce = "NewSysAnnounce",
	NewSysAnnounceTxt = "NewSysAnnounceTxt",
	NewSysAnnounceImg = "NewSysAnnounceImg",

	HeroSkillUse = "HeroSkillUse",

	RoomGameSpring = "RoomGameSpring",

	RoomGameDouble = "RoomGameDouble",
	RoomGameDoubleMax = "RoomGameDoubleMax",
}

-- 代办数据类型
PendingDataType = {
	PayFinish = "PayFinish", -- 支付完成
}

-- 日期类型
DateType = {
	--Default = 0,
	Day = 1,
	Week = 2,
	Month = 3,
	Forever = 4 --永远
}

-- 加成类型
BonusType = {
	Medal 					= "Medal",						-- 勋章加成
	UserGiftVal 			= "UserGiftVal",				-- 收礼人气加成
	GameWinGold 			= "GameWinGold",				-- 对局胜利豆子加成
	PayGold 				= "PayGold",					-- 充值买豆子

	GameWinExp				= "GameWinExp",					-- 对局胜利段位奖杯加成
	GameRuneExpFixedWin		= "GameRuneExpFixedWin",		-- 对局胜利符文固定增加
	GameRuneExpFixedLose	= "GameRuneExpFixedLose",		-- 对局失败符文固定增加

	GourdWaterDay 		= "GourdWaterDay",		-- 葫芦藤每天免费水分
	GourdGoldBase 		= "GourdGoldBase",		-- 葫芦藤基础豆子
	BrokeGold			= "BrokeGold",			-- 破产补助
	SignInGold 			= "SignInGold",			-- 签到豆子
	RuneExpBook          = "runeexpbook",         --广告经验书
	SkillExpBook          = "skillexpbook",       --广告技能书
}

-- 常用道具ID，需要与items表格同步
ItemID = {
	Diamond = 10001,
	Gold = 10002,

	LvExp = 10007,

	HeroJingHua = 10011, -- 精华

	RuneExp			= 605001,	-- 符文经验书

	GourdWater      = 115001,
	GourdFertilizer = 115002,--肥料
	

	GameCardRecord 			= 205001,	-- 记牌器 场
	GameCardRecordDay 		= 205002,	-- 记牌器 天
	GameBottomCardCheck 	= 205003,	-- 透视卡
	GameDoubleSuper 		= 205004,	-- 超级加倍卡
	GameDoubleMax 			= 205005,	-- 封顶翻倍卡

	GameProtectWinStreak	= 125001,	-- 连胜保护令
}
ItemID_Enum = ItemID

-- 道具使用类型
ItemUseType = {
	Default 	= 0,
	Use 		= 1,
	AutoUse 	= 2, 	-- 获取时自动使用
	Time 		= 3,	-- 只加累计时间不加次数的
	UseAndTime 	= 4,	-- 可使用且独自计时
}

ItemType = {
	Hero 			= 14, 
	InfoBg 			= 15, -- 信息底板
	HeadFrame 		= 16,
	ClockFram 		= 17,
	GameChatFram 	= 18, -- 游戏内聊天框

	sceneBg 		= 29,
	tableClothBg 	= 30,
	cardBg 		    = 31,
}


ItemFromRecord = {
	RoomProtectLv = {num = 1000, str = "段位保护"},
}

-- 显示奖励来源
ShowRewardFrom = {
	Default 	= 0,	-- 基础值
	Rune		= 1,	-- 符文增加
	Mood		= 2,	-- 心情增加
	Vip			= 10,	-- vip增加
}

--
FashionType = {
	Hero 			= 14, 
	InfoBg 			= 15, -- 信息底板
	HeadFrame 		= 16,
	ClockFram 		= 17,
	GameChatFram 	= 18, -- 游戏内聊天框
}

-- 任务状态
TaskState = {
	Default = 0,
	Finish = 1,
	Get = 2, -- 已领取奖励
}

GenderEnum = {
	Default = 0,
	BOY = 1,
	GIRL = 2,
}

GourdType = {
	Default 	= 0, -- 基础豆子
	BigGourd 	= 1,
	FakeGourd 	= 2, -- 伪装豆子
	GiftGourd 	= 3, -- 礼品豆子
	HoeGourd 	= 4, -- 锄头豆子
	SuperGourd 	= 5, -- 超级豆子
}

GourdActionType = {
    Default = 0,		-- 
    PickFruit = 1,		-- 摘豆
    LoosenSoil = 2,		-- 松土
    FriendHelp = 3,		-- 好友助产
}

GourdActionType = {
    Default = 0,
    PickFruit = 1,
    LoosenSoil = 2,
    FriendHelp = 3,
}

FriendFromType = {
	Default = 0,
	Find = 1,		-- 搜索
	RecentRoom = 2,	-- 最近牌友
	Other = 3,		-- 其他
}

-- 公告类型
AnnounceType = {
	Scroll	= 10, -- 跑马灯
	Img		= 20, -- 图片公告
	Text	= 30, -- 文本公告
}

UserRoomState = {
	Idle 			= 0, 	-- 闲着的
	Matching 		= 1, 	-- 匹配中
	Gameing 		= 2, 	-- 游戏中
}

-- 房间类型
GameType = {
	Default = 0,
	NoShuffle = 1,		-- 不洗牌
	SwapThree = 2,		-- 换三张
	SevenSparrow = 3,	-- 七雀牌
	DdzFour = 4,	-- 4人斗地主
}

-- 房间等级
GameRoomLevel = {
	V1 = 1,
	V2 = 2,
	V3 = 3,
	V4 = 4,
}

-- 房间子类型
GameSubType = {
	Default = 0,
	Recycle = 10,
	NewUser = 20,	-- 新用户
	Prison	= 30,	-- 黑屋

	MatchServer	= 100, -- 配置匹配
}


GameType.GetGameRoomDicPath = function (gameType)
	return ({
		[GameType.NoShuffle] = "ddz",
		[GameType.SwapThree] = "ddz",
		[GameType.SevenSparrow] = "sevensparrow",
	})[gameType]
end

GameType.GetGameRobotDicPath = function (gameType)
	return ({
		[GameType.NoShuffle] = "classic",
		[GameType.SwapThree] = "classic",
		[GameType.SevenSparrow] = "sevensparrow",
	})[gameType]
end

GameType.GetGamePlayerNumMax = function (gameType)
	return ({
		[GameType.NoShuffle] = 3,
		[GameType.SevenSparrow] = 4,
	})[gameType] or 3
end


RobotTagType = {
	Default = 0,
	NotPay = 10,
	Pay = 11,
}


CardVal = {
	V_2 = 0xd,
	V_A = 0xc,
	V_9 = 0x7,
	V_SJocker = 0xae,
	V_BJocker = 0xaf,
}

CardColor = {
	Diamond 	= 1, -- 方块
	Club 		= 2, -- 梅花
	Hearts 		= 3, -- 红心
	Spade 		= 4, -- 黑桃
}


RoomState_QQP = {
	Readying = "readying",
	SwapCard = "swapcard",
	TakeCard = "takecard", --拿牌
	PlayCard = "playcard",
	Ended = "ended",
}

PlayerState_QQP = {
	ReadyOk = "ready_ok",
	Waiting = "waiting",
	Takeing = "takeing",--拿牌
	Playing = "playing",--出牌
	Recharging = "recharging",
	Watching = "watching",
	Exited = "exited",
}


RoomState_DDZ = {
	Readying = 10,
	ReadyOk = 15,		--准备完成
	DealCard = 20,
	CallLandlord = 30,
	RobLandlord = 40,
	Doubleing = 50,
	DoubleMax = 60,
	Playing = 70,
	Ended = 80,
}

PlayerState_DDZ = {
	Waiting = 0,		--等待
	ReadyOk = 10,		--准备完成
	DealCard = 20,		--发牌
	CallLandlord = 30,	--叫地主
	RobLandlord = 40,	--抢地主
	Doubleing = 50, 	--加倍 地主选定后进入加倍状态，
	DoubleMax = 60, 	--封顶加倍
	Playing = 70, 		--出牌
	
	Skill = 200,		--技能操作
}

PlayerAction_DDZ = {
	--call_landlord' 'not_call' 'rob_landlord' 'not_rob' 'double_1' 'double_2' 'double_4' 'double_cap' 'not_double_cap' 'pass' 'playcard'

	CallLandlord = 10,
	NotCall = 20,

	RobLandlord = 30,
	NotRob = 40,

	NotDouble = 50,
	Double_2 = 51,
	Double_4 = 52,

	DoubleMax = 60,
	NotDoubleMax = 70,

	Pass = 80,
	PlayCard = 90,


	SkillUse = 200,		-- 技能使用
	SkillUnUse = 210,	-- 技能不使用
}

PlayCardState_DDZ = {
	Default = 0, -- 默认值，无法出牌
	First = 1, -- 第一次出牌的人(有明牌按钮)
	Play = 2, -- 必须出牌(没有pass按钮)
	Normal = 3, -- 普通出牌, 有pass按钮
}

-- 玩家结算标签
RoomPlayerOverTag = {
	Default = 0,
	Broke 	= 1, 		-- 破产
	Max 	= 2, 		-- 封顶
}

-- 牌型类型
RoomCardType = {
	C_2222 = "2+2+2+2",
	C_332 = "3+3+2",
	feijihu = "feijihu",
	sanliandui = "sanliandui",
	C_422 = "4+2+2",
	C_44 = "4+4",
	shuanglonghui = "shuanglonghui",
	lianzhahu = "lianzhahu",
	tonghuashun = "tonghuashun",
	baxingzha = "baxingzha",
	flower = "flower",
	huamanyuan = "huamanyuan",
	fishmoon = "fishmoon",
	zimo = "zimo",
	tianhu = "tianhu",
	dihu = "dihu",
	qingyise = "qingyise",
}



--队伍状态
TEAM_STATUS=
{    
    READY = 0,
    MATCHING = 1,
    GAMEING = 2    
}

ONE_DAY = 86400 




--时间段
TIME_8_13 = 1
TIME_13_18 = 2
TIME_18_24 = 3
TIME_OTHER = 0

PET_TOUCH = 1 --抚摸
PET_KISS = 2 --亲吻
PET_PLAY = 3 --玩耍



-- 实名错误
RN_ERR = {
	SUCC 		= 0,
	TIMEOUT 	= 1, -- 请求超时
	ENC_ERR 	= 2, -- 加密错误
	OVERDRIVE 	= 3, -- 请求过载
	REQ_ERR 	= 4, -- 请求错误

	NO_RNAUTH   = 11, -- 未实名认证,不能购买
	AGE_LT_8    = 12, -- 年纪小于8,不能购买
	SINGLE_LIMIT = 13, -- 单笔限额
	MONTH_LIMIT  = 14, -- 月度限额

	NO_TIME 	 = 21, -- 剩余时间不足
	NO_LOGIN     = 22, -- 不能登录,不在登录时间
	NO_RN 		 = 23, -- 剩余时间不足,没有实名
}




--广告场景值
AD_SCENE_NAME = {
	xixiReward = "xixiReward",  --嘻嘻大奖 看视频
    MajongGod_Win = "MajongGod_Win",            --雀神祝福
    MajongGod_Lose = "MajongGod_Lose",          --雀神恩赐
    spree = "spree",  --天赐豪礼
    daily_task = "daily_task",--每日任务    
    draw_luck = "draw_luck",--幸运转盘
    luck_card = "luck_card", --好牌开局
    default_ad = "default_ad",--默认广告场景 ,后续细分,
	pick_card_gift = "pick_card_gift", --翻拍豪礼
}




RankName ={
	RQ = "rq",
	DZ = "dz",
	DW = "dw",
	CJ = "cj",
	HLT = "hlt",
}

RankType = {
	Normal = 1,    -- 总榜
	Month =  2,    -- 月榜
	Friend = 3,    -- 好友榜
}

HeroId = {
	JiangDaohai = 104001,--江道海
	TangBaoEr = 104009, --汤宝儿
	HuManYu = 1040401, --胡曼玉
	JiangXiaoYu = 1040501, --江小鱼
}

StorIdEm = {
    Zhouka7 =800001, --周卡
    Yueka30 =800002, --月卡
    Nianka  =800003, --年卡
	XianshiMiaosha  =800016, --限时秒杀

	StoreFirst1  =800006, -- 
	StoreFirst6  =800007, -- 
	
	StoreBuyHeroJdaohai  =100001, -- 
	BuyHeroSWanqing  =100002, -- 
	BuyHeroYsimo  =100003, -- 
	BuyHeroLyun  =100004, --   

	Pochan1 = 800027,
	Pochan3 = 800028,
	Pochan6 = 800029,
	Pochan8 = 800030,
	Pochan12 = 800031,
	Pochan18 = 800032,
	Pochan30 = 800033,
	Pochan50 = 800034,

	Pochan60 = 800035,
	Pochan68 = 800036,
	Pochan88 = 800037,
	Pochan98 = 800038,
	Pochan108 = 800039,

	Pochan128 = 800040,
	Pochan328 = 800041,
	Pochan648 = 800042,

	StoreTxzGold = 900101,
	StoreTxzChaoGold_1 = 900102,
	StoreTxzChaoGold_2 = 900103,
}








DWLv_DouHuang_min = 22 --斗皇
DWLv_DouHuang_max = 22 --斗皇

DWLv_DouSheng_min = 28 --斗圣
DWLv_DouSheng_max = 28 --斗圣

DWLv_DouDi_min = 38 --斗帝
DWLv_DouDi_max = 38 --斗帝
DWLv_TianXDyi_min = 39 --天下第一
DWLv_TianXDyi_max = 39 --天下第一

AnnounceIdEm = {
	luckSItem = 1,
	Zhouka7 = 2,--周卡
	Yueka30  = 3,--月卡
	Nianka = 4,--年卡
	XianshiMiaosha = 5,--限时秒杀

	DwShengjiDouhuang = 6,--段位升级斗皇
	DwShengjiDousheng = 7,--段位升级斗圣
	DwShengjiDoudi = 8,--段位升级斗帝
	DwShengjiTianxiadiyi = 9,--段位升级天下第一

	HLRank1 = 10,--好葫芦榜第一名
	DWRank1 = 11,--段位榜第一名

	StoreBuyHero = 12,--在商城购买英雄
	StoreFirst = 13,--首冲大礼包
	TxzGold = 14,
	TxzBoJinGold = 15,

	Sys = 100,--系统公告

}

--段位公告参数
AnnounceIdEm.GetDWAnnounceId = function (lv, rank)
	lv = tonumber(lv)
	rank = tonumber(rank)
	if lv >= DWLv_DouHuang_min and lv <= DWLv_DouHuang_max then
		return AnnounceIdEm.DwShengjiDouhuang
	elseif lv >= DWLv_DouSheng_min and lv <= DWLv_DouSheng_max then
		return AnnounceIdEm.DwShengjiDousheng
	elseif lv >= DWLv_DouDi_min and lv <= DWLv_DouDi_max and (rank <= 0 or rank > 100)  then
		return AnnounceIdEm.DwShengjiDoudi
	elseif lv== 38 and rank > 0 and rank <= 100  then
		return AnnounceIdEm.DwShengjiTianxiadiyi
	elseif lv >= DWLv_TianXDyi_min and lv <= DWLv_TianXDyi_max then
		return  AnnounceIdEm.DwShengjiTianxiadiyi
	end

	return 0
end 


AuthenticationTypeEm = {
	identityCard = 1,--身份证
}

AuthenticationPower = {
	Unknown = 0,
	Power1 = 1, --正在认证中
	Power2 = 2, --未成年
	Power3 = 3, --成年
	Power4 = 4, --其他平台默认实名认证
}

UserLogKey= {
	establish           = "establish", --创号数量；后台查询
	xuanrenchenggong    = "xuanrenchenggong", --创建角色成功的人数（上面相加）；后台查询
	shouchongplayer   	= "shouchongplayer",--首充的玩家数量；后台查询
	dijiju	            = "dijiju",--从进入大厅后第几局游戏后首充的；后台查询

	shengli	            = "shengli",--从进入大厅后到首充，赢了几局；后台查询
	shibai	            = "shibai",--从进入大厅后到首充，输了几局；后台查询
	douzishuliang       = "douzishuliang",--首充时身上豆子的数量；后台查询

	chongzhicishu	    = "chongzhicishu",--	充值的次数；后台查询
	dancijine	        = "dancijine",--	单次的金额；后台查询

	goumaiwuping     	= "goumaiwuping",--	购买的物品；后台查询
	goumairenshu     	= "goumairenshu",--	购买礼包的人数；后台查询
	goumailibaodoushu	= "goumailibaodoushu",--	购买礼包时身上金豆的数量；后台查询

	riqi	            = "riqi",--领取日期；后台查询
	xiaofeirenshu     	= "xiaofeirenshu",--在活动里消费的人数；后台查询
	goumaicishujilu	    = "goumaicishujilu",--记录礼包未领取，然后用葫芦购买每个 坑 购买的次数；后台查询

	cktc_total          = "cktc_total",--	分享弹出的总次数；后台查询
	cxcg_total          = "cxcg_total",--	分享成功的总次数；后台查询

	xtcffx              = "xtcffx",--	玩家在单个系统中触发了几次分享，如：七雀牌触发了几次（上面相加）；后台查询

	first_dapai = "first_dapai", --第一次打牌时间；从而计算从创角到开始打牌的时间;后端查询；
}

CDR = {
	all = "all",
	vivo = "vivo",
	oppo = "oppo",
	huawei = "huawei",
	apple = "apple",
	yyb = "yyb",
}

-- CDR.GetCDKID = function(channel)
-- 	if not channel then
-- 		return ""
-- 	end
-- 	if channel == CDR.all then
-- 		return "A"
-- 	elseif channel == CDR.vivo then
-- 		return "B"
-- 	elseif channel == CDR.oppo then
-- 		return "C"
-- 	elseif channel == CDR.huawei then
-- 		return "D"
-- 	elseif channel == CDR.yyb then
-- 		return "E"
-- 	end
-- 	return ""
-- end