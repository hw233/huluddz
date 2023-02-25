return [[
.package {
	type  		0 : integer
	session 	1 : integer
}

# sproto 无法用HashSet，lj ，只有用这种格式替代
.Hash {
	key			0 : string
}

# 
.KeyValuePair {
	key			0 : string
	value		1 : string
}

# 值为数值类型
.KeyNumPair {
	key			0 : string
	num			1 : integer
}

.Item {
	id 			0 : integer
	num			1 : integer	
}

.BackpackItem {
	id 			0 : integer
	num			1 : integer
	expiry_time 2 : integer
}

.UserCountStoreItem {
	id 0 : integer 			# 商品ID
	allbuy 1 : integer 		# 累计购买数量
	day 2 : string 			# 最后一次购买日期 '2021-04-01'
	daybuy 3 : integer 		# 最后一次购买日期购买数量
}

.UserTitle {
	lv 				0 : integer		# 等级
	star 			1 : integer 	# 星数
	exp 			2 : integer 	# 经验
	receive_month 	3 : string		# 上次领取月份(赛季)
}


.UserDailyTaskItem {
	id 			0 : integer 	# 每日任务ID
	now 		1 : integer 	# 当前完成数量
	received 	2 : boolean 	# 是否领取
}

.UserActivityRewardItem {
	id 			0 : integer 	# 活跃礼盒ID
	received 	1 : boolean
}


.BankBox {
	lv  		0 : integer 		# 银行等级 1 - 3
	purchased 	1 : boolean 		# 是否已购买
	timeleft 	2 : integer  		# 剩余有效时间 	(未激活的银行)
	expiry_time 3 : integer 		# 到期时间  		(当前激活银行)
}

.Bank {
	lv 			1 : integer 	# 银行等级
	amount 		2 : integer		# 存款金额
	expiry_time 3 : integer		# 有效期
	boxes 		4 : *BankBox 	# 各个银行的详细信息
}

.IUserBase {
	id 				0  : string
	nickname 		1  : string
	head 			2  : string
	headFrame 		3  : integer
	chatFrame		4  : integer	# 聊天框
	gameChatFrame	5  : integer	# 游戏内聊天框
	infoBg			6  : integer	# 个人信息底板
	clockFrame		7  : integer	# 闹钟
	title			8  : integer	# 称号

	lv 				13 : integer
	vip       		14 : integer
	gourdLv       	15 : integer
	skin			16 : integer	# 出场角色表格id
	gender       	17 : integer
}

.UserInfo {
	id 				0  : string
	openid 			1  : string

	online			2  : boolean	# 在线状态
	onlineDt		3  : integer	# 最后上线的时间 old:last_time
	offlineDt		4  : integer	# 离线时间
	onlineTimes		5  : integer	# 在线时长 old:online_time
	onlineTimeDay	6  : integer	# 当天在线时长

	firstLoginDt	10 : integer	# 首次登录时间/注册时间 old:reg_time?
	loginTime 		11 : integer	# 登录次数 old:login_time
	loginDays		12 : integer	# 登录天数，每天首次登陆加一

	gold 			15 : double		# 金币
	diamond 		16 : integer	# 钻石

	pay				20 : integer	# 累计充值 old:recharge_diamondc
	payMonth		21 : integer	# 月累计充值 old:month_fee
	payDayCount		22 : integer	# 充值天数
	payDay			24 : integer	# 日累计充值
	
	gender 			28 : integer 		# 0: 未知,	1: 男 	2: 女
	area			29 : string			# 地区 old:district
	name    		30 : string 		# 姓名
	idcard 			31 : string 		# 身份证
	ipRegister		32 : string			# 注册ip old:reg_ip
	ipLast			33 : string			# 上次登录注册ip old:last_ip
	
	nickname 		38 : string
	nickNameSetNum 	39 : integer	# 昵称设置次数
	head			40 : string 	# 头像  与性别关联
	headFrame		41 : integer	# 头像框 old:headframe
	chatFrame		42 : integer	# 聊天框
	gameChatFrame	43 : integer	# 游戏内聊天框
	infoBg			44 : integer	# 个人信息底板
	clockFrame		45 : integer	# 闹钟
	title			46 : integer	# 称号
	cardBg          47 : integer	# 牌面
	sceneBg         48 : integer	# 场景
	tableClothBg    49 : integer	# 桌布

	seasonId		53 : integer	# 赛季id
	lv 				54 : integer	# 段位
	lvMax 			55 : integer	# 历史最高段位
	lvSeasonMax		56 : integer	# 赛季最高
	expSeasonMax	57 : integer	# 赛季最高
	exp 			58 : integer	# 段位经验
	expMax 			59 : integer	# 历史最高段位经验
	lvRewardRecord	60 : *Hash(key)	# 已领取段位奖励

	vip 			65 : integer	# old:viplv
	vipExp 			66 : integer
	viplv_xl        67 : integer   # 虚拟vip等级

	signature		72 : string 	# 签名
	like			73 : integer	# 点赞
	giftCount 		74 : integer	# 礼物数量

	initSet			80 : boolean	# 是否创角 为 true 代表已创角
	guideObj		85 : *KeyNumPair(key) # 引导对象  目前由客户端自己设置使用
	guideRewardQQP	86 : integer	# 等于 1 表示已领取

	# roomAddr = source # 对局服务地址
	roomState				90	: integer	# 对局状态 UserRoomState  0：闲置  2：游戏中
	roomGameType			91	: integer	# 对局游戏类型
	roomGameLevel			92	: integer	# 对局游戏等级

	gameCountSum 			97 : integer	# 总对局数量
	winCountSum 			98 : integer	# 总胜场数量
	winCountSum_20 			99 : integer	# 近20场胜场数量

	winStreak				102 : integer	# 连胜数量
	winStreakLast			103 : integer	# 上次连胜数量（使用保护令后重置为0）
	cardRecordAutoUse		104 : boolean	# 自动使用记牌器开关
	brokeSubsidyCountDay	105 : integer	# 已领取的破产救济金次数（天）

	heroId					115 : string	# 出场角色id
	skin					116 : integer	# 出场角色表格id

	runeExpWeek				120 : integer	# 符文经验_周

	gourdLv					123 : integer	# 葫芦藤等级
	gourdExp				124 : integer	# 葫芦藤经验

	location_open     		129 : boolean   # 开启手机定位
	location_sex      		130 : integer   # 手机定位 性别 0:男女,1:男 2:女
	locale_city       		131 : string    # 定位城市
	locale_longitude  		132 : integer   # 定位经度
	locale_latitude   		133 : integer   # 定位维度

	auto_gift         		136 : boolean   # 好友自动答谢
	not_accept_apply  		137 : boolean   # 不再接受好友申请
	friend_gift_num         138 : integer   # 今天收取了多少次好友赠送的礼物
	Authtion                139 : integer #实名认证，0，没有实名，1 少年实名，2 成年实名

	
	isCloseShowGameRecord	150 : boolean   # 是否关闭战绩显示


	#promoter 		39 : string 		# 推介人(主播ID)
	#bank 			40 : Bank
	
	#backpack    	42 : *BackpackItem
	#title 			44 : UserTitle

	# 后端使用 start
	# dbLoginDt integer 	# db_manager 里的上次调用 GetUserInfoData 的时间
	# init string 			# 是否初始化

	# bonusObj {rune={}} 	# 各项加成
	# roomGameCountObj		# 各对局次数统计

	# 后端使用 end
}

# old:BackpackItem
.UserItem {
	id 			0 : integer
	num			1 : integer
	endDt 		2 : integer   # 到期时间 old:expiry_time
	
	gId			3 : string    # 相对于道具的唯一id
	arr			4 : *UserItem # 独立计时道具数组
}

# 奖励结构
.RewardStruct {
	fromType 		0 : integer # ShowRewardFrom 道具来源标记， 0：普通来源
	arr				1 : *Item
}

# 商城数据结构
.UserStore {
	id 			0 : integer # 商品id
	num			1 : integer	# 已购买商品数量
	endDt		2 : integer	# 不为 nil 则为到期时间
}

# old:Mail
.UserMail {
	id          0 : string 			# 邮件ID
    uId         1 : string 		    # 收件人ID

	sender      2 : string 		    # 发送人
    sendName    3 : string          # 发送人
    
    mailId     4 : integer         # 邮件id  此id不为空则为配置好的邮件，否则为其他邮件
	title       5 : string 			# 邮件标题	不为配置邮件时，此参数有用
	content     6 : *string 		# 邮件内容	如果为配置邮件，这里是动态参数数组。 如果是非配置邮件，此数组第一项为内容
	itemArr     7 : *Item 			# 附件
    sendDt      8 : integer 	    # 创建(发送)时间
	read        9 : boolean 		# 是否已读
	itemGet     10 : boolean 		# 是否已领取附件 (对于没有附件的邮件, 该字段没有意义)	
}

.UserTask {
	id			0 : string
	val			1 : integer	# 进度
	state		3 : integer # 任务状态	0：未完成  1：完成，完成了才可领取奖励  2：已领取奖励
}

# 角色
.UserHero {
	id          0 : string					#
	sId         1 : integer					# 表格id
	skillLv     2 : integer					# 技能等级
	moodLv      3 : integer					# 心情等级
	moodExp     4 : integer					# 心情经验
	runeArr     5 : *KeyValuePair(key)		# 符文组

	notLimit    6 : boolean					# 是否不是体验卡
	endDt     	7 : integer					# 体验结束时间
	useCount    8 : integer					# 剩余使用次数

	skillCount	11 : integer				# 技能使用次数
}

# 符文
.UserRune {
	id          0 : string		#
	sId         1 : integer		# 表格id
	uHero       2 : string		# 装备英雄id
	lv       	3 : integer		#
	exp       	4 : integer		#
}

# 葫芦果实
.UserGourdFruit {
	id 				0 : string	# 
	growLv 			1 : integer # 生长等级
	type			2 : integer	# 葫芦类型
	endDt			3 : integer	# 成熟时间
	addNum			4 : integer	# 增产数量
	bePickNum		5 : integer	# 被偷取数量
	canPick			6 : boolean	# 能否被摘取
	isTree			7 : boolean	# 是否在树上
}

# 葫芦
.UserGourd {
	id 			0 : integer 		# 葫芦id（位置）
	arr			1 : *UserGourdFruit	# 果实数组
}

# 好友
.UserFriend {
	id          	0 : string		# 自己的userid
	data        	1 : IUserBase	# 好友的基础数据
	onlineState     3 : integer		# 在线状态  0:未在线 1:在线 2:游戏中
	offlineDt		4 : integer		# 离线时间
	friendVal       5 : integer		# 亲密度
	friendLv       	6 : integer		# 亲密度等级
	isSendGift      7 : boolean		# 是否已赠送礼物
	giftIndex      	8 : integer		# 礼物索引  0：空  其他值：可领取
    addtime         9 : integer     # 加好友的时间
	# uId string 后端使用 #好友的userid
}

# 好友申请
.UserFriendApply {
	id          	0 : string		# 被请求者uid
	data        	1 : IUserBase	# 基础数据 发起者基础数据
	type			2 : integer		# 操作类型 0：未处理	1：接受	2：拒绝
	fromType       	3 : integer		# 枚举 FriendFromType
	dt       		4 : integer		# 时间
	uId             5 : string      # 请求发起者uid
}

# 好友聊天记录
.UserFriendChat {
	id          	0 : string		#
	from       		1 : string		# 发出人id
	content       	2 : string		# 内容
	dt       		3 : string		# 时间
}


# 牌结构
.RoomPlayedCards {
	type 		0 : string			# 牌型
	weight 		1 : integer 		# 权重
	cards 		2 : *integer
	subtype 	3 : string			# 子类型
}

.RoomConf {
	gametype 		0 : integer
	roomtype 		1 : integer
	max_player 		2 : integer
}

.RoomLastAction {
	name 0 : string						# 'call_landlord' 'not_call' 'rob_landlord' 'not_rob' 'double_1' 'double_2' 'double_4' 'double_cap' 'not_double_cap' 'pass' 'playcard'
	playedcards 1 : RoomPlayedCards		# name = 'playcard' 才有
}

.RoomPlayer {
	id 					0 : string
	nick 				1 : string
	head				2 : string
	gold 				3 : integer

	showcardx5  		5 : boolean 		# 是否明牌开始的
	chair 				6 : integer 		# 座位号
	status 				7 : string 			# 玩家状态 'ready_ok', 'dealcard', 'call_landlord', 'rob_landlord', 'doubleing', 'double_caping', 'waiting', 'playing'
	playstatus  		8 : string  		# 'first': 第一次出牌的人(有明牌按钮)  'mustplay': 必须出牌(没有pass按钮)  'normal': 普通出牌, 有pass按钮
	clock 				9 : integer 		# 倒计时
	last_action 		10 : RoomLastAction # 最后一次的Action
	is_trusteeship 		11 : boolean		# 是否托管中
	is_showcard 		12 : boolean 		# 是否明牌
	is_landlord 		13 : boolean 		# 是不是地主
	double_cap_multiple 14 : integer 		# 封顶倍数 (1, 2)
	double_multiple 	15 : integer 		# 加倍倍数 (1, 2, 4)
	cardnum				16 : integer		# 手牌数量
	cards 				17 : *integer 		# 手牌
	banChat 			18 : boolean 		# 是否被禁言的
	title 				19 : UserTitle 		# 头衔信息
	vip 				20 : integer
	played_cards 		21 : *RoomPlayedCards 	# 已出牌的记录
	useCardRecord 		22 : boolean 			# 记牌器已使用
	gameCountSum 		23 : integer		# 总对局数量
	winCountSum 		24 : integer		# 总胜场数量
}

.Room {
	id 					0 : string
	conf 				1 : RoomConf
	status 				2 : string 			# 'readying', 'dealcard', 'call_landlord', 'rob_landlord', 'doubleing', 'double_caping', 'playing', 'ended'
	bottom_cards 		3 : *integer
	bottom_cards_mulite 4 : integer
	players 			5 : *RoomPlayer
}

# 房间对局结算通用结构
.RoomGameOverInfoBase {
	isWin				0 : boolean 					# 当前段位
	lv					1 : integer 					# 当前段位
	lvOld				2 : integer 					# 旧的等级
	exp					3 : integer 					# 当前经验
	expOld				4 : integer 					# 旧的经验
	
	rewardInfo 			5 : *RewardStruct(fromType)		# 奖励道具信息
	lvExpAddRateObj		6 : *KeyValuePair(key)			# 段位经验加成比率（万分比）	winStreakRate:连胜加成比率	runeRate:符文加成	vipRate:VIP加成
	rewardLimitFrom		7 : *KeyValuePair(key)			# 各奖励道具限制获取的原因 {[道具id] = {key = "道具id", value = "原因"}}  hero：角色限制 room：房间限制
	lvExpProtect		8 : integer					 	# 因为段位保护少扣除的奖杯
}

#角色数据Ext
.UserHeroDataExt {
    id           0: string     #heroid
    ljexp        1: integer    #总累计经验
    ljexp_week   2: integer    #周累计经验
}

#拉黑好友
.UserFriendBlack {
	uid          	0 : string		#
	blackuid        1 : string      # 被拉黑的玩家的uid
	blackdata       2 : IUserBase	# 被拉黑的玩家的基础数据
    onlineState     3 : integer		# 在线状态  0:未在线 1:在线 2:游戏中
    offlineDt       4 : integer		# 离线时间
}

#附近玩家
.UserFriendNearby {
	uid               0: string
	data              1: IUserBase
	isApply           2: boolean        # 是否已申请
	locale_city       3: string         # 定位位置 城市
	distance          4: integer        # 距离
	game              5: integer        # 常玩游戏     
}

# 游戏功能设置
.GameFuncData {
	id 					0 : integer 		# ID
	startDt 			1 : integer 		# 开始时间
	endDt 				2 : integer 		# 结束时间
	open      			3 : boolean 		# 是否开启
	channelCloseArr     4 : *string 			# 关闭渠道数组
}

]]