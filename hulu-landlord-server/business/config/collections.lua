--collections 数据库表
-- 数据库表
local COLLECTIONS = {
	ETC 							= "etc", 					-- 放一些杂项(单独的小记录 比如广告统计)
	User							= "user_test",				-- 用户管理，兼容大小写
	USER 							= "user_test",				-- 用户管理
	UserOther 						= "userother",				-- 用户的一些杂项数据，主要是服务端用
	UserPendingData					= "userpendingdata",		-- 用户待处理数据

	UserLikeRecord					= "userlikerecord",			-- 用户点赞记录
	UserGiftRecord					= "usergiftrecord",			-- 用户礼物记录

	UserItem						= "useritem",				-- 用户道具
	UserItemRecord					= "useritemrecord",			-- 用户道具记录
	UserStore						= "userstore",				-- 用户商店
	UserPayOrderPre					= "userpayorderpre",		-- 用户充值预订单
	UserPayOrder					= "userpayorder",			-- 用户充值订单
	UserPayOrderSandBox				= "userpayordersandbox",	-- 用户充值订单沙盒
	UserPayOrderFail				= "userpayorderfail",		-- 用户充值失败订单

	PRE_ORDER 		= "pre_order", 				-- 预订单
	ORDER 			= "order",					-- 订单记录
	ORDER_SANDBOX   = "order_sandbox",			-- 测试订单记录

	UserHero						= "userhero",				-- 用户英雄
	UserHeroGet						= "userheroget",			-- 用户英雄通用记录
	UserRune						= "userrune",				-- 用户符文
	UserGourd						= "usergourd",				-- 用户葫芦藤
	UserGourdAction					= "usergourdaction",		-- 用户葫芦藤动态
	UserAdvert						= "useradvert",				-- 用户广告数据
	UserRoomData					= "userroomdata",			-- 用户房间数据
	UserGameRecord					= 'usergamerecord',			-- 战绩
	UserRoomGameRecord				= "userroomgamerecord",		-- 用户对局记录
	UserFashion						= "userfashion",			-- 用户时装相关数据

	ActivityData					= "activitydata",			-- 活动数据
	UserActivityData				= "useractivitydata",		-- 用户活动数据

	GameFuncData					= "gamefuncdata",			-- 游戏功能设置数据

	UserFriend			        	= "userfriend",				-- 用户好友
	UserFriendChat		        	= "userfriendchat",			-- 用户好友聊天记录
	UserFriendOther		        	= "userfriendother",		-- 用户好友其他数据
	UserFriendApply		        	= "userfriendapply",		-- 好友申请

	UserMail        	        	= "usermail",				-- 邮件
	MailGlobal        	        	= "mailglobal",				-- 全局邮件
	UserMailGlobal        	        = "usermailglobal",			-- 用户已领取的全局邮件
	        
	TASK				        	= 'task',					--日常任务表
	UserTask			        	= 'usertask',				--任务

	SETTING 						= "setting", --全局设置
	ServerSeting					= "serverseting",			-- 服务器全局设置数据
	ServerSeason					= "serverseason",			-- 服务器赛季数据
	ServerRobot						= "serverrobot",			-- 服务器机器人数据
	ServerAnnounce					= "serverannounce",			-- 服务器公告
	ServerRoomPrison				= "serverroomprison",		-- 小黑屋


	UserCreate_REC		        	= "usercreate_rec",				-- 用户创建
	UserOnline_REC		        	= "useronline_rec",				-- 用户登录 or 离线
	UserOnline_Day_REC	        	= "useronline_day_rec",			-- 用户登录(日-每日唯一)
	UserPay_REC			        	= "userpay_rec",				-- 用户支付记录
	DIAMOND_REC			        	= "diamond_rec",				-- 钻石记录
	GOLD_REC			        	= "gold_rec",					-- 金币记录
	Item_REC			        	= "item_rec",					-- 道具记录
	Hero_REC			        	= "hero_rec",					-- 英雄记录
        
	UserChannelData		        	= "userchanneldata",			-- 渠道数据



	QQ_WALLET_REC	= "qq_wallet_rec",			-- 红包余额记录
	BANKGOLD_REC	= "bankgold_rec",			-- 银行金币记录
	PROPS_REC 		= "props_rec", 				-- 道具记录
	
	MALL 			= "mall",					-- 商城相关信息
	SHARE_TBL		= "share_tbl",				-- 分享邀请相关
	GAME_VERSION    = "game_version",			-- 游戏版本信息
	MESSAGE 		= "message", 				-- 用户留言
	LAMP			= "lamp",					-- 跑马灯
	-- TITLE_TBL		= "title_tbl",				-- 头衔系统
	INVITE_LOG		= "invite_log", 			-- 邀请完成记录

	

	CHANNEL_DATA 	= "channel_data",			-- 渠道数据
	GOODS_OVERVIEW	= "goods_overview",			-- 道具使用概览 
	CHARGE_OVERVIEW = "charge_overview",		-- 充值概览
	VIDEO_AD_LOG    = "video_ad_log",			-- 视频广告播放统计
	ACTIVE_DATA		= 'active_data',			--活躍人數表
	PROPS_DATA		= 'props_data',				--道具使用总表


	APPLY_CHAT		= 'apply_chat',				--好友申请表(id:app_id .. fri_id,fri_id,time)
	FRIEND_DATA		= 'friend_data',			--好友数据
	FRI_CONFIRM_DATA = 'fri_confirm_data',		--好友申请同意确认表
	LOTTERY_DATA = 'lottery_data', --千王争霸抽奖记录	
	LOTTETY_BEST_DATA = "lottery_best_data", --千万争霸极品奖励记录	
	-- MONTH_SIGN = 'month_sign',	--月签到数据
	ERROR_LOG = 'error_log', --错误日志表
	FAMILY_DATA = "family_data", --家园数据
	CDK_DATA = "cdk_data",	--cdk数据
	FRIEND_VISIT = "friend_visit", --好友访问记录表
	T_SHOW_DATA = "t_show_data", --t台数据
	T_SHOW_RANK_DATA = "t_show_rank_data", --t台排行榜数据
	HALL_FRAMEL_DATA = "hall_frame_data", --名人堂

	ACTIVITY_DATA = "activity_data", --活动数据
	RANKLIST_DATA = "ranklist_data", --排行榜数据
	RANKTWO_DATA = "ranktwo_data", 	 --一天刷新的排行榜
	LASTRANK_DATA = "lastrank_data", --以前
	LONGRANK_DATA = "longrank_data", --永久排行榜
	ACTIVE = "active", -- 用户活动数据
	ENTITY = "entity", -- 兑换实物信息
	REPORT = "report", -- 举报信息
	
	SPREAD_DATA = "spread_data",--个人推广信息信息
	GAME_REC = "game_rec", 		--游戏记录
	PANGLE_REC = "pangle_rec", 	--穿山甲广告回调记录
	OPERATION_REC =	"operation_rec", --运营埋点记录
	COLLECT_DATA = "collect_data",	--客户端数据采集
	ACTIVITY_CONF = "activity_conf", --活动列表
	QQ_HB_WITHDRAWAL = "qq_hb_withdrawal" , -- QQ红包提现记录





	RECORD_7 = "record_7",--对局记录 七雀牌
	RECORD_DDZ = "record_ddz",--对局记录 ddz

	UserSettingInfoTable = "UserSettingInfoTable",  -- 设置数据
	UserPieceTakeTable = "UserPieceTakeTable",      -- 碎片领取记录表
	UserSignInTable = "UserSignInTable",            -- 签到
	UserFriendBlackListTable = "UserFriendBlackLIstTable",       -- 好友 黑名单
	UserFriendGift = "UserFriendGift",              -- 好友送礼表
	UserVipDayAward = "UserVipDayAward",            -- vip每日奖励
	UserVipStoreBuy = "UserVipStoreBuy",            -- vip商店购买
	UserRankList  = "UserRankList",                 -- 排行榜总榜
	UserRankListM = "UserRankListM",                 -- 排行榜月榜

	-- start
	UserLuckBaoxiangRecord = "userluckbaoxiangrecord", --用户幸运宝箱数据
	UserVisitorRecord = "uservisitorrecord", --用户访客数据
	UserSign14Record = "userSign14record",  --用户14日签到
	UserSignRecord = "userSign7record",  --用户7日签到
	UserSign14Record_REC = "user_sign14_record_rec",  --用户14日签到记录
	UserSessionDataRecord = "user_session_record",  --赛季信息记录

	UserClientDataRecord = "client_data_record", --用户客户端数据埋点
	UserServerDataRecord = "server_data_record", --用户服务器数据埋点

	UserShareRecord = "user_share_record", --用户分享点
	UserAchievement = "user_achievement_record", --用户成就数据
	ServerCdkRecord = "server_cdk_record", -- 服务器cdk数据
	ServerBatchRecord = "server_batch_record", -- 批次数据id记录
	UserCdkRecord = "user_cdk_record", --用户领取cdk数据
	UserTXZRecord = "user_txz_record", --通行证
}
-- 注:凡是新添加表有查询,更新操作
-- 请在coll_indexes.lua文件中添加对应索引配置

return COLLECTIONS

