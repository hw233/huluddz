local struct = [[
    .RoomInfo {
        id 					0 : string
        conf 				1 : RoomConf
        state 				2 : integer
        bottomCards 		3 : *integer
        players 			4 : *RoomPlayerInfo
    }
	.RoomPlayerInfo {
		id 					0 : string
		data        		1 : IUserBase			# 基础数据
		gold 				2 : integer
	
		pos 				3  : integer 			# 座位号
		cards 				4  : *integer 			# 手牌
		cardNum 			5  : integer 			# 手牌数量
		playedCards 		6  : *RoomPlayedCards 	# 已出牌的记录
		state 				7  : integer 			# 玩家状态 枚举值
		clock 				8  : integer 			# 倒计时
		lastAction 			9  : integer 			# 最后一次的	PlayerAction
		
		playCardState  		10  : integer  		# 0：默认值，无法出牌 1: 第一次出牌的人(有明牌按钮) & 必须出牌(没有pass按钮)  2: 必须出牌(没有pass按钮)  3: 普通出牌, 有pass按钮 
		
		isShowcard 			11 : boolean 		# 是否明牌
		isTrusteeship 		12 : boolean		# 是否托管中
		isLandlord 			13 : boolean 		# 是不是地主

		multiple 			14 : integer 		# 当前倍率
		doubleMultiple 		15 : integer 		# 加倍倍数
		doubleMaxMultiple 	16 : integer 		# 封顶倍数

		useCardRecord 		17 : boolean 		# 记牌器已使用

		doubleAction 		18 : integer 		# 加倍操作
		doubleMaxAction 	19 : integer 		# 封顶操作

		skillId				22 : integer		# 技能id
		skillState			23 : boolean		# 技能触发状态 true：触发状态，可使用

		#showcardx5  		18 : boolean 		# 是否明牌开始的
		#banChat 			19 : boolean 		# 是否被禁言的
	}
	
]]


local c2s = [[
	# 对局开始匹配
	RoomStartMatch 3000 {
		request {
			gametype 		0 : integer		
			roomtype 		1 : integer		
			showcardx5 		2 : boolean 	# 是否明牌开始
			anonymous  		3 : boolean		# 是否匿名开始
			effectTimeCfg	4 : *KeyValuePair(key)	# 特效时间配置 配置单位(ms), 调试使用，正式无需传递
		}
		response {
			e_info 			0 : integer
		}
	}

	# 对局取消匹配
	RoomMatchCancel 3001 {
		response {
			e_info 			0 : integer
		}
	}

	# 记牌器状态设置
	RoomCardRecordAutoUseStateSet 3002 {
		request {
			state 		0 : boolean		# true or false
		}
		response {
			e_info 					0 : integer
			cardRecordAutoUse 		1 : boolean
		}
	}

	# 房间发送表情
	RoomEmoticonSend 3003 {
		request {
			id 			0 : integer # 表情id
			toId 		1 : string # 目标id
		}
		response {
			e_info 	0 : integer
		}
	}

	# 大厅房间信息获取
	RoomLobbyInfoGet 3004 {
		request {
			gameType 	0 : integer # room_cost 表格中的	game_id
		}
		response {
			.RoomLobbyInfo {
				id 			0 : integer			# 房间id， 目前表格转lua工具生成的数据有问题，先不用此字段
				roomLevel 	1 : integer			# 房间等级
				num 		2 : integer			# 房间数
				playerNum 	3 : integer			# 人数
			}
			.RankDataInfo {
				dwrank      1 : integer			# 当前服务器排名
				dwrankdis   2 : integer			# 当前服务器前一名相距的距离，如果是第一名，就是第一名倒过来与第二名的相差段位经验
			}
			datas    0 : *RoomLobbyInfo
			rankdata 1 : RankDataInfo
		}
	}

	# 获取房间信息
	RoomInfoGet 3005 {
		response {
			roomInfo 0 : RoomInfo
		}
	}
	
	# 房间底牌信息获取
	RoomBottomCardInfoGet 3006 {
		# request {
		# 	index 	0 : integer 	# 位置索引 废弃了，一次查看3张
		# }
		response {
			e_info 		0 : integer
			cards 		1 : *integer	# 3张底牌值
			storeRet 	2 : integer		# 商店购买返回值
		}
	}

	# 房间记牌器信息
	RoomCardRecordInfo 3007 {
		response {
			e_info 		0 : integer
			storeRet 	1 : integer		# 商店购买返回值
		}
	}

	# 设置or取消托管
	RoomSetTrusteeship 3008 {
		request {
			isTrusteeship 0 : boolean # 开启or取消
		}
	}
	
	RoomShowCard 3010 {}
	
	RoomCallLandlord 3015 {
		request {
			type 0 : integer # PlayerAction_DDZ
		}
	}
	
	RoomRobLandlord 3020 {
		request {
			type 0 : integer # PlayerAction_DDZ
		}
	}

	# 强叫地主
	RoomForceRobLandlord 3023 {
		request {
			# 暂时没有
		}
		response {
			e_info 		0 : integer
		}
	}
	
	RoomDouble 3025 {
		request {
			type 0 : integer # PlayerAction_DDZ
		}
		response {
			e_info 		0 : integer
			storeRet 	1 : integer		# 商店购买返回值
		}
	}
	# 封顶翻倍
	RoomDoubleMax 3030 {
		request {
			type 0 : integer # PlayerAction_DDZ
		}
		response {
			e_info 		0 : integer
			storeRet 	1 : integer		# 商店购买返回值
		}
	}
	
	RoomPlayCard 3035 {
		request {
			type 		0 : integer # PlayerAction_DDZ
			playCardObj 1 : RoomPlayedCards
		}
	}
	


	# 段位保护
	RoomProtectLv 3800 {
		response {
			e_info 		0 : integer
			expOld 		1 : integer
			lvOld 		2 : integer
			exp 		3 : integer		# 新经验
			lv 			4 : integer		# 新段位
		}
	}

	# 连胜保护
	RoomProtectWinStreak 3801 {
		response {
			e_info 			0 : integer
			winStreak 		1 : integer	# 新连胜数据
			winStreakLast 	2 : integer
		}
	}

	# 破产救济金领取
	RoomBrokeSubsidyGet 3805 {
		request {
			AdvSign	0 : integer #1广告3倍领取, 其他普通领取
        }
		response {
			e_info 					0 : integer
			brokeSubsidyCountDay 	1 : integer	# 新破产救济金领取次数
		}
	}

]]


local s2c = [[
	# 匹配成功，发送房间信息
    RoomMatchOk_C 3000 {
        request {
            roomInfo 0 : RoomInfo
        }
    }

	# 房间表情
	RoomEmoticonSend_C 3003 {
		request {
			id 			0 : integer 	# 表情id
			fromId 		1 : string 		# 发送者
			toId 		2 : string 		# 接收者
		}
	}

	# 开始发牌
	RoomDealCard_C 3005 {
		request {
			cards 0 : *integer 		# 你的手牌
		}
	}
	
	# 等待玩家动作
	RoomPleasePlayerAction_C 3010 {
		request {
			id				0 : string		# player id
			state 			1 : integer		# 此动作状态枚举值
			clock 			2 : integer 	# 时钟
			playCardState 	3 : integer 	# 出牌状态
		}
	}

	# 明牌
	RoomShowCard_C 3012 {
		request {
			id 		0 : string
			cards 	1 : *integer
		}
	}

	# 托管
	RoomSetTrusteeship_C 3015 {
		request {
			id 				0 : string
			isTrusteeship 	1 : boolean
		}
	}

	# 同步玩家操作
	RoomSyncPlayerAction_C 3020 {
		request {
			id 			0 : string
			type 		1 : integer # PlayerAction_DDZ
			playCardObj 2 : RoomPlayedCards # 
			skillId 	3 : integer			# 操作对应的技能id
		}
	}
	
	# 确定地主
	RoomLandlordSet_C 3025 {
		request {
			id 				0 : string
			bottomCards 	1 : *integer 	# 3张底牌
			multiple 		2 : integer 	# 1 / 2 / 4
		}
	}

	# 同步倍数
	RoomSyncMultiple_C 3030 {
		request {
			multiple 	0 : integer 	# 当前倍率
			key 		1 : string 		# 倍率变化的key
			val 		2 : integer 	# 加倍值
			id 			3 : string 		# 触发此加倍的玩家id
		}
	}

	# 对局结束
	RoomGameOver_C 3035 {
		request {
			.RoomGameOverInfo {
				id 					0 : string 		# 玩家ID
				multiple 			1 : integer		# 游戏倍数
				cards   			2 : *integer 	# 剩余的牌
	
				gold 				3 : integer  	# 该玩家当前金币
				goldChange 			4 : integer 	# 金币变化 (负值代表输的金币)
				tag 				5 : integer 	# RoomPlayerOverTag

				doubleMultiple		6  : integer		# 私有加倍 = 加倍 * 封顶加倍
				goldBase			7  : integer		# 计算值
				goldOld				8  : integer		# 携带值
				goldMax				9  : integer		# 封顶值
				goldReal			10 : integer		# 分摊值

				isLast				11 : boolean		# 是否为最后一手玩家
				doubleAction 		12 : integer 		# 加倍操作
				doubleMaxAction 	13 : integer 		# 封顶操作
			}
			info  				0 : RoomGameOverInfoBase		# 基础信息
			datas 				1 : *RoomGameOverInfo(id) 		# 各玩家结局信息清单列表
			# 房间倍率信息 init, showCard, callLandlord, robLandlord, bottomCard, bomb, spring 春天, springReverse 反春, skill 技能倍率
			roomMultiple		3 : *KeyValuePair(key)			
		}
	}

	# 同步玩家数据
	RoomSyncPlayerData_C 3040 {
		request {
			id 			0 : string
			gold 		1 : integer
			skillState 	2 : boolean
		}
	}

	SyncRoomBrokeSubsidyGet 3041 {
		request {
			e_info 					0 : integer
			brokeSubsidyCountDay 	1 : integer	# 新破产救济金领取次数
		}
	}

]]



return {
	struct = struct,
	c2s = c2s,
	s2c = s2c
}