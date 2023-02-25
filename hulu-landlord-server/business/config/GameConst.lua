ActionType = {
	None 	= 0,
	Cancel 	= 1,
	Play 	= 2,
	Chi  	= 3,
	Peng 	= 4,
	Gang 	= 5,
	BGang   = 6,	-- 补杠
	AGang   = 7,	-- 暗杠
	MGang   = 8,	-- 明杠
	HGang   = 9,	-- 憨包杠
	Ting    = 10,	-- 报听
	XlHu 	= 11,	-- 捉鸡血流 闷胡
	Hu   	= 12, 	-- 胡
}

HU_TYPE = {
	No_hu 		  = 0,
	Zi_mo 		  = 4,  -- 自摸
	RobKong       = 36,  -- 抢杠胡
	Ping_hu		  = 45,	-- 点炮
	Flower   	  = 13, 	 -- 杠上开花
	Re_Pao		  = 46,	 --杠上炮
	Born		  = 41,   -- 天胡
	Lack_Born 	  = 42,   -- 地胡
	F_LackBorn    = 47,   -- 放炮 地胡
}

WIN_FLAG = {
	None = 0,
	Bankrupt = 1,-- 破产了
	Full = 2, -- 赢爆了
	WinLimit = 3, -- 限制了
	LoserLimit = 4
}

-- 选择弃牌类型
DiscardType = {
	None      = 0,
	Bam 	  = 1, --条
	Dot		  = 2, --筒
	Crak	  = 3, --万
}

DirectionType = {
	Clockwise = 2, -- 顺时针
	Anti  	  = 1, -- 逆时针
	UpDown	  = 3, -- 上下
}


BE_FROM_TYPE ={   --计算胡牌时，标记胡的那张牌的来的地方
	Deal     = 1, -- 发牌
	Gang     = 2, -- 其他玩家杠的牌
	Ping     = 3,	-- 胡其他人的牌
}

-- 破产,由杠或 胡破产标记
BROKE_FROM_TYPE = {
	Gang 	= 1,
	BGang   = 2,
	Hu 		= 3,
}

CARD_TYPE = {
	No_hu 		 			= -1,
	Pinghu 					= 3,  -- 平胡     1
	Duiduipeng 			    = 6,  -- 大对子   5
	Qidui 					= 7,  -- 七对     10
	Longqidui  		 	    = 8,  -- 龙七对	  20
	Jingougou   			= 12,  -- 金钩钓     10
	Jiulianbaodeng			= 14,  -- 九莲宝灯
	Shibaluohan				= 15,  -- 十八罗汉
	Sanjiegao    			= 16,  -- 三节高
	Sijiegao				= 17, 	-- 四节高
	Qinglong				= 18,   -- 清龙
	Quandaiwu				= 19,	-- 全带五
	Shuanganke				= 20,	-- 双暗刻
	Sananke 				= 21,	-- 三暗刻
	Sianke 					= 22,	-- 四暗刻
	Dayuwu 					= 23,	-- 大于五
	Xiaoyuwu				= 24,	-- 小于五
	Lianqidui 				= 25,	-- 连七对
	Qingyaojiu				= 26,	-- 清幺九
	Quanshuangke 			= 27,	-- 全双刻
	Laoshaopei 				= 30,	-- 老少配
	Yiseshuanglonghui	    = 31,	-- 一色双龙会
	Shierjinchai			= 32,	-- 十二金钗
	Quandaiyao				= 33,	-- 全带幺
	Shuangminggang			= 34,	-- 双明杠
	Duanyaojiu 				= 38,	-- 断幺九
	-- Yitiaolong				= 44,	-- 一条龙
	Qingyise 				= 5,	-- 清一色	
	Queyimen 				= 9,	-- 缺一门
	Bianzhang   			= 10,	-- 边张
	Kanzhang 				= 11,	-- 坎张
	Daigen 					= 48,	-- 带根

	Juezhang  		= 35,	-- 绝张
	Menqing	  		= 37,	-- 门清
	Buqiuren  		= 39,	-- 不求人
	Quanqiuren 		= 40,	-- 全求人
	Qishoujiao  	= 43,	-- 起手叫
	Haidilaoyue 	= 28,	-- 海底捞月
	Miaoshouhuichun = 29,	-- 妙手回春
	luckStar		= 49,
	-- Uniform     			= 6,  -- 清一色   10
	-- Uniform_HightPair 		= 7,  -- 清大对	  15
	-- Uniform_QiDui      		= 8,  -- 清七对   20
	-- Uniform_LongDui 		= 9,  -- 清龙七对 30
	-- Uniform_LandDui         = 10, -- 清地七对 30
	-- Uniform_SHPair          = 11, -- 清单吊   20
}

-- 检查牌型标记类型
VER_TYPE = {
	None		= 0,--没有验证
	Succ		= 1,--成功
	Fail		= 2,--失败
}

TIME_TYPE = {
	Normal = 1,
	tip  = 2
}
HU_SCORE = 2 -- 胡牌分数

-- 麻将牌类型
CARD_COLOR = {
	Bamboo 		= 1, 
	Dot 		= 2,
	Character  	= 3,
	Honor 		= 4,
	Flower 		= 5,
}

-- 胡牌的状态
HU_STATE = {         
	Normal  = 0,
	Ting    = 1, -- 报听
	Kill    = 2, -- 杀报
	Ting_Kill = 3,--报听杀报
	-- BeKill  = 4, -- 被杀报

}


FLOWER_PIG_MUL = 16 -- 花猪番数

IOType = {
	fPig 		= 1, --花猪
	noTing 		= 2, --查大叫
	retScore 	= 3, --退税
	ZiMo 		= 4, --自摸
	Hu 			= 5, --胡
	BGang   	= 6,	-- 补杠
	AGang   	= 7,	-- 暗杠
	MGang   	= 8,	-- 明杠
	Call		= 9,	--呼叫转移
	FTing 		= 10, 	--首次听牌加500
	ZhaBird		= 11, 	-- 扎鸟
}

-- 交换手牌错误
EX_ERR  = {
	Already   = 1, -- 已经设置完成
	End		  = 2, -- 结束
	CardErr   = 3, -- 牌错误
}


CARD_TYPE_VALUE = {[0]=1,1,1,2,2,1,1,5,2,3,3,2,2}  -- 与 CARD_TYPE相对于的分值
HU_TYPE_VALUE = {[0] = 0,1,1,1,1,2,3,2,2,2,2,2}
-- GANG_VALUE = {[6] = 3,[7] = 2,[8]= 1,[9] = 0}

--前端特效表现类型
DIS_EFFECT = {
	fpig = 1, --花猪
	deuce = 2, --查大叫
	return_gang = 3 --退税
}

--vip每日富豪点重置
VIP_POINT_DAILY = {
	daily_task = 30,
	online_times = 15,
	xixi_gift = 15,
	watch_any_ads = 30
}
VIP_POINT_ADS = 2 --任意视频观看奖励vip富豪点数


--好牌开局概率配置
GOOD_HAND_CFG = {
	[1] = {50,50},
	[2] = {20,80},
	[3] = {0,100}
}