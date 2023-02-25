local COLL = require "config/collections"


-- dbpoolname  db_mgr中存储 数据库链接 池名
	-- POOL 游戏数据
	-- POOL_REC 记录数据
-- indexes 	   索引 -- hashed 现只支持单索引,不支持复合索引
				   -- 复合索引 等于类型在前,排序类型在后,范围类型最后
	-- 例
		-- 单索引
		-- indexes = {{{id = "hashed"},{{time = -1}}}
		-- 复合索引
		-- indexes = {{{id = 1},{time = -1}}}
-- split   -- 分表模式,已年月份拆开

-- paramNameArr：write_record 方法提供的4个未命名的参数在数据库中的字段名

-- updateSelectorField：已指定字段作为查找更新操作

local INDEXES = {
	[COLL.UserCreate_REC] = {dbpoolname = "POOL_REC", indexes = {
			{{id = "hashed"}},
			{{channel = "hashed"}}, 	-- 渠道
			{{os = "hashed"}}, 			--
			{{dayZero = "hashed"}},		-- 记录日0点
			{{date = -1}},				-- 创号时间
		},
		--split = true,
		paramNameArr = {"date", "dayZero", "os"}
	},
	[COLL.UserOnline_REC] = {dbpoolname = "POOL_REC", indexes = {
			{{id = "hashed"}},
			{{type = "hashed"}},		-- 登录 or 离线
			{{channel = "hashed"}},		-- 渠道
			{{os = "hashed"}}, 			--
			{{dayZero = "hashed"}},
			{{date = -1}},				-- 时间
		},
		split = true,
		paramNameArr = {"date", "dayZero", "os"}
	},
	[COLL.UserOnline_Day_REC] = {dbpoolname = "POOL_REC", indexes = {
			{{id = "hashed"}},
			{{type = "hashed"}},
			{{channel = "hashed"}},		-- 渠道
			{{os = "hashed"}}, 			--
			{{dayZero = "hashed"}},
			{{date = -1}},				-- 时间
		},
		split = true,
		paramNameArr = {"date", "dayZero", "os"},
		updateSelectorField = {"id", "dayZero"},
	},
	[COLL.UserPay_REC] = {dbpoolname = "POOL_REC", indexes = {
			{{id = "hashed"}},
			{{type = "hashed"}},		-- 充值类型，备用
			{{from = "hashed"}},		-- 准备用于区分后台充值还是真实充值
			{{channel = "hashed"}},		-- 渠道
			{{os = "hashed"}}, 			--
			{{dayZero = "hashed"}},
			{{cfgId = "hashed"}},		-- 配置商品id
			{{date = -1}},				-- 时间
		},
		split = true,
		paramNameArr = {"date", "dayZero", "os", "cfgId"}
	},
	[COLL.DIAMOND_REC] = {dbpoolname = "POOL_REC", indexes = {
			{{id = "hashed"}},
			{{channel = "hashed"}},
			{{dayZero = "hashed"}},
			{{time = -1}}
		},
		split = true,
		paramNameArr = { "addNum", "oldNum", "num" }
	},
	[COLL.GOLD_REC] = {dbpoolname = "POOL_REC", indexes = {
			{{id = "hashed"}},
			{{channel = "hashed"}},
			{{dayZero = "hashed"}},
			{{time = -1}},
			{{id = 1},{time = -1}}
		},
		split = true,
		paramNameArr = { "addNum", "oldNum", "num" }
	},
	[COLL.Item_REC] = {dbpoolname = "POOL_REC", indexes = {
			{{id = "hashed"}},
			{{itemId = "hashed"}},
			{{type = "hashed"}},
			{{channel = "hashed"}},
			{{dayZero = "hashed"}},
			{{time = -1}},
		},
		split = true,
		paramNameArr = { "itemId", "addNum", "oldNum", "num" }
	},
	[COLL.Hero_REC] = {dbpoolname = "POOL_REC", indexes = {
			{{id = "hashed"}},
			{{heroId = "hashed"}},
			{{type = "hashed"}},
			{{channel = "hashed"}},
			{{dayZero = "hashed"}},
			{{time = -1}},
		},
		split = true,
		paramNameArr = { "heroId", "useCount" }
	},

	[COLL.UserChannelData] = {dbpoolname = "POOL", indexes = {
		{{channel = "hashed"}},
		{{dayZero = "hashed"}},
		{{channel = 1},{dayZero = 1}},
		{{channel = 1},{dayZero = 1},{nodeName = 1}},
	}},
	[COLL.COLLECT_DATA] = {dbpoolname = "POOL_Client",indexes = {{{id = "hashed"}}}, split = true},

	[COLL.QQ_WALLET_REC] = {dbpoolname = "POOL_REC",indexes = {{{pid = "hashed"}},{{time = -1}},{{pid = 1},{time = -1}}},split = true},
	[COLL.BANKGOLD_REC] = {dbpoolname = "POOL_REC",indexes = {{{pid = "hashed"}},{{time = -1}},{{pid = 1},{time = -1}}},split = true},
	[COLL.PROPS_REC] = {dbpoolname = "POOL_REC",indexes = {{{pid = "hashed"}},{{time = -1}}},split = true},
	[COLL.PANGLE_REC] = {dbpoolname = "POOL_REC",indexes = {{{trans_id = "hashed"}},{{time = -1}}},split = true},

	
	[COLL.USER] = {
		dbpoolname = "POOL",
		indexes = {
			{{id = "hashed"}},
			{{openid = "hashed"}},
			{{unionid = "hashed"}},
			{{vip = "hashed"}},
			{{lv = "hashed"}},
			{{firstLoginDt = -1}},
			{{onLineDt = 1}},
		}
	},
	[COLL.UserOther] = {dbpoolname = "POOL",	indexes = {{{id = "hashed"}},}},
	[COLL.UserPendingData] = {dbpoolname = "POOL",	indexes = {
		{{id = "hashed"}},
		{{type = "hashed"}},
		{{dt = 1}},
	}},
	
	[COLL.UserLikeRecord] = {dbpoolname = "POOL",	indexes = {{{id = "hashed"}},}},
	[COLL.UserGiftRecord] = {dbpoolname = "POOL",	indexes = {{{id = "hashed"}},}},
	
	[COLL.UserItem] 			= {dbpoolname = "POOL", indexes = {{{id = "hashed"}},}},
	[COLL.UserItemRecord] 		= {dbpoolname = "POOL", indexes = {{{id = "hashed"}},}},
	[COLL.UserStore] = {dbpoolname = "POOL", indexes = {{{id = "hashed"}},}},

	[COLL.UserPayOrderPre] = {dbpoolname = "POOL", indexes = {
		{{id = "hashed"}},
		{{storeId = "hashed"}},
		{{time = -1}},
		{{uId = "hashed"}},{{time = -1}},
		{{channel = "hashed"}},
		{{platform = "hashed"}},
	}},
	[COLL.UserPayOrder] = {dbpoolname = "POOL", indexes = {
		{{id = "hashed"}},
		{{transaction_id = "hashed"}},
		{{storeId = "hashed"}},
		{{time = "hashed"}},
		{{time = -1}},
		{{uId = "hashed"},{time = -1}},
		{{channel = "hashed"}},
		{{platform = "hashed"}},
		{{registerDt = "hashed"}},
	}},
	[COLL.UserPayOrderSandBox] = {dbpoolname = "POOL", indexes = {
		{{id = "hashed"}},
		{{transaction_id = "hashed"}},
		{{storeId = "hashed"}},
		{{time = "hashed"}},
		{{time = -1}},
		{{uId = "hashed"},{time = -1}},
		{{channel = "hashed"}},
		{{platform = "hashed"}},
		{{registerDt = "hashed"}},
	}},
	[COLL.UserPayOrderFail] = {dbpoolname = "POOL", indexes = {
		{{id = "hashed"}},
		{{storeId = "hashed"}},
		{{time = -1}},
		{{uId = "hashed"}},{{time = -1}},
		{{channel = "hashed"}},
		{{platform = "hashed"}},
	}},

	[COLL.ORDER] = {dbpoolname = "POOL",indexes = {{{transaction_id = "hashed"}},{{time_end = -1}},{{pid = 1},{time_end = -1}},}},
	[COLL.PRE_ORDER] = {dbpoolname = "POOL",indexes = {{{out_trade_no = "hashed"}},{{pid = "hashed"}},{{time = -1}},}},

	[COLL.UserHero] = {dbpoolname = "POOL",	indexes = {{{id = "hashed"}},}},
	[COLL.UserHeroGet] = {dbpoolname = "POOL",	indexes = {{{id = "hashed"}},}},
	[COLL.UserRune] = {dbpoolname = "POOL",	indexes = {{{id = "hashed"}},}},
	[COLL.UserGourd] = {dbpoolname = "POOL", indexes = {{{id = "hashed"}},}},
	[COLL.UserGourdAction] = {
		dbpoolname = "POOL",
		indexes = {
			{{id = "hashed"}},
			{{toId = "hashed"}},
			{{type = "hashed"}},
			{{dayDt = "hashed"}},
			{{lastDt = -1}}
		}
	},
	[COLL.UserAdvert] = {dbpoolname = "POOL", indexes = {{{id = "hashed"}},}},
	[COLL.UserRoomData] = {dbpoolname = "POOL", indexes = {{{id = "hashed"}},}},
	[COLL.UserFashion] = {dbpoolname = "POOL", indexes = {{{id = "hashed"}},}},

	[COLL.ActivityData] = {dbpoolname = "POOL", indexes = {{{server = "hashed"}},}},
	[COLL.UserActivityData] = {dbpoolname = "POOL", indexes = {{{id = "hashed"}},}},

	[COLL.APPLY_CHAT] = {dbpoolname = "POOL",indexes = {{{ap_id = "hashed"}},{{fri_id = "hashed"}},}},
	[COLL.FRIEND_DATA] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},}},
	[COLL.FRIEND_VISIT] = {dbpoolname = "POOL",indexes = {{{fri_id = "hashed"}},}},
	[COLL.UserFriend] = {dbpoolname = "POOL",
		indexes = {
			{{id = "hashed"}},
			{{uId = "hashed"}},
		}
	},
	[COLL.UserFriendChat] = {dbpoolname = "POOL",	indexes = {{{id = "hashed"}},}},
	[COLL.UserFriendOther] = {dbpoolname = "POOL",	indexes = {{{id = "hashed"}},}},
	[COLL.UserFriendApply] = {dbpoolname = "POOL",
		indexes = {
			{{id = "hashed"}},
			{{uId = "hashed"}},
			{{dt = -1}},
		}
	},

	[COLL.UserMail] = {dbpoolname = "POOL",
		indexes = {
			{{uId = "hashed"}},
			{{id = "hashed"}},
			{{sendDt = -1}},
		}
	},
	-- 后台配置的数据，数据量不大，无需索引
	-- [COLL.MailGlobal] = {dbpoolname = "POOL", indexes = {{{id = "hashed"}}, {{sendDt = -1}}, {{endDt = -1}},}},

	[COLL.TASK] = {dbpoolname = "POOL",indexes = {{{pid = "hashed"}},}},
	[COLL.UserTask] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},}},
	[COLL.UserGameRecord] = {dbpoolname = "POOL",
		indexes = {
			{{uId = "hashed"}},
			{{id = "hashed"}},
			{{startDt = -1}},
		}
	},
	[COLL.UserRoomGameRecord] = {dbpoolname = "POOL",
		indexes = {
			{{uId = "hashed"}},
			{{id = "hashed"}},
			{{startDt = -1 }},
		}
	},

	[COLL.SETTING] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},}},
	[COLL.ServerSeting] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},}},
	[COLL.ServerSeason] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},{{index = "hashed"}},{{index = -1}}}},
	[COLL.ServerRobot] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},{{sId = "hashed"}},}},
	[COLL.ServerAnnounce] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},}},
	[COLL.ServerRoomPrison] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},}},


	
	[COLL.ACTIVE] = {dbpoolname = "POOL",indexes = {{{pid = "hashed"}},{{pid = 1},{name = 1}},}},
	[COLL.ACTIVE_DATA] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}}}},
	[COLL.CHANNEL_DATA] = {dbpoolname = "POOL",indexes = {{{channel = "hashed"}},{{channel = 1},{day = 1}},{{channel = 1},{day = 1},{node_name = 1}},}},
	[COLL.CHARGE_OVERVIEW] = {dbpoolname = "POOL",indexes = {{{day = "hashed"}},{{day = 1},{node_name = 1},},{{channel = 1},{day = 1},{node_name = 1}},}},
	[COLL.GOODS_OVERVIEW] = {dbpoolname = "POOL",indexes = {{{day = "hashed"}},{{day = 1},{node_name = 1},},{{channel = 1},{day = 1},{node_name = 1}},}},
	[COLL.LOTTERY_DATA] = {dbpoolname = "POOL",indexes = {{{pid = "hashed"}},}},
	[COLL.RANKLIST_DATA] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},{{t = -1}},{{pet_level = -1}},{{luxury = -1}},{{worth = -1}},{{prestige = -1}},}},
	[COLL.RANKTWO_DATA] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},{{t = -1}},{{multipleKing = -1}},{{useTime1 = -1}},{{useTime2 = -1}},{{useTime3 = -1}},}},
	[COLL.LONGRANK_DATA] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},{{t = -1}},}},
	[COLL.LASTRANK_DATA] = {dbpoolname = "POOL",indexes = {{{pid = "hashed"}},}},
	[COLL.T_SHOW_RANK_DATA] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},}},
	[COLL.CDK_DATA] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},}},
	[COLL.FAMILY_DATA] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},}},
	[COLL.MESSAGE] = {dbpoolname = "POOL",indexes = {{{pid = "hashed"}},}},
	[COLL.PROPS_DATA] = {dbpoolname = "POOL",indexes = {{{day = "hashed"}},{{day = 1},{node_name = 1},},}},
	[COLL.ENTITY] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},{{receiver = "hashed"}},{{received = -1}},{{receive_time = 1}}}},
	[COLL.SPREAD_DATA] = {dbpoolname = "POOL",indexes = {{{pid = "hashed"}},{{bindId = "hashed"}},}},
	[COLL.GAME_REC] = {dbpoolname = "POOL",indexes = {{{pid = "hashed"}}}},
	[COLL.OPERATION_REC] = {dbpoolname = "POOL",indexes = {{{day = "hashed"}},{{mode_name = "hashed"}}}},

	
	
	[COLL.LOTTETY_BEST_DATA] = {dbpoolname = "POOL",indexes = {{{create_time = -1}},}},
	[COLL.MALL] = {dbpoolname = "POOL",indexes = {{{pid = "hashed"}},}},
	[COLL.ACTIVITY_DATA] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},}},
	[COLL.QQ_HB_WITHDRAWAL] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},{{openid = "hashed"}},}},
	[COLL.RECORD_7] = {dbpoolname = "POOL_REC",indexes = {{{pid = "hashed"}},{{end_time = -1 }}}},
	[COLL.RECORD_DDZ] = {dbpoolname = "POOL_REC",indexes = {{{pid = "hashed"}},{{end_time = -1 }}}},

	[COLL.UserSettingInfoTable] = {dbpoolname = "POOL", indexes = {{{uid = "hashed"}}}},
	[COLL.UserPieceTakeTable] = {dbpoolname = "POOL", indexes = {{{uid = "hashed"}}}},
	[COLL.UserSignInTable] = {dbpoolname = "POOL", indexes = {{{uid = "hashed"}}}},
	[COLL.UserFriendBlackListTable] = {dbpoolname = "POOL", indexes = {{{uid = "hashed"}}}},
	[COLL.UserFriendGift] = {dbpoolname = "POOL", indexes = {{{uid = "hashed"}}}},
	[COLL.UserVipDayAward] = {dbpoolname = "POOL", indexes = {{{uid = "hashed"}}}},
	[COLL.UserVipStoreBuy] = {dbpoolname = "POOL", indexes = {{{uid = "hashed"}}}},
	[COLL.UserRankList]  = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},{{t = -1}},{{rq = -1}},{{dz = -1}},{{dw = -1}},{{cj = -1}},{{hlt = -1}},}},
	[COLL.UserRankListM] = {dbpoolname = "POOL",indexes = {{{id = "hashed"}},{{t = -1}},{{rq = -1}},{{dz = -1}},{{dw = -1}},{{cj = -1}},{{hlt = -1}},}},

	-- start
	[COLL.UserLuckBaoxiangRecord] = {dbpoolname = "POOL", indexes = {{{uid = "hashed"}}}},
	[COLL.UserVisitorRecord] = {dbpoolname = "POOL", indexes = {{{uid = "hashed"}}}},
	[COLL.UserSign14Record] = {dbpoolname = "POOL", indexes = {{{uid = "hashed"}}}},
	[COLL.UserSignRecord] = {dbpoolname = "POOL", indexes = {{{uid = "hashed"}}}},

	[COLL.UserSign14Record_REC] = {dbpoolname = "POOL_REC", indexes = {
		{{id = "hashed"}},
		{{channel = "hashed"}},
		{{dayZero = "hashed"}},
		{{time = -1}},
		{{id = 1},{time = -1}}
		},
		split = true,
		paramNameArr = { "index", "signtype" }
	},

	[COLL.UserSessionDataRecord] = {dbpoolname = "POOL", indexes = {{{uid = "hashed"}}}},

	[COLL.UserClientDataRecord] = {dbpoolname = "POOL_Client", indexes = {
		{{id = "hashed"}},
		{{channel = "hashed"}},
		{{dayZero = "hashed"}},
		{{time = -1}},
		{{id = 1},{time = -1}}
		},
		split = true,
		-- paramNameArr = { "data" }
	},

	[COLL.UserServerDataRecord] = {dbpoolname = "POOL_REC", indexes = {
		{{id = "hashed"}},
		{{channel = "hashed"}},
		{{dayZero = "hashed"}},
		{{time = -1}},
		{{id = 1},{time = -1}}
		},
		split = true,
		-- paramNameArr = { "data" }
	},

	[COLL.UserShareRecord] = {dbpoolname = "POOL", indexes = {{{id = "hashed"}}}},
	[COLL.UserAchievement] = {dbpoolname = "POOL", indexes = {{{id = "hashed"}}}},

	[COLL.ServerCdkRecord] = {dbpoolname = "POOL", indexes = {{{cdkId = "hashed"}}, {{type = "hashed"}}, {{channel = "hashed"}}, {{batchId = "hashed"}}}},
	[COLL.ServerBatchRecord] = {dbpoolname = "POOL", indexes = {{{cdkId = "hashed"}}, {{batchId = "hashed"}}}},
	[COLL.UserCdkRecord] = {dbpoolname = "POOL", indexes = {{{cdkId = "hashed"}}, {{uId = "hashed"}}, {{channel = "hashed"}}, {{batchId = "hashed"}}}},
	[COLL.UserTXZRecord] = {dbpoolname = "POOL", indexes = {{{id = "hashed"}}}},
	------------
}

return INDEXES