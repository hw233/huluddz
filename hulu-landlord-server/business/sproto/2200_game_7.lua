local struct = [[
.SSWRoomConf {
	gametype 0 : integer
	roomtype 1 : integer
	max_player 2 : integer
}

.SSWPlayer {
	id 					0  : string
	data        		1  : IUserBase		# 基础数据
	gold 				2  : integer

	chair 				3  : integer 		# 座位号
	status 				4  : string 		# 玩家状态 "ready_ok", "waiting", "takeing", "playing", "recharging"(破产后充值中), "watching"(放弃后观战中), "exited"
	clock 				5  : integer 		# 倒计时
	banChat 			6	: boolean 		# 是否被禁言的

	is_trusteeship 		7 : boolean			# 是否托管中
	is_first 			8 : boolean 		# 是否首发
	cardnum				9 : integer			# 手牌数量
	cards 				10 : *integer 		# 手牌, 重连时若是拿牌后状态，最后一张就是拿的牌
	flowers 			11 : *integer 		# 花牌
	hu_cards 			12 : *integer 		# 胡的牌
	fixed_events  		13 : *integer 		# 已经固定的事件

	useCardRecord 		14 : boolean 		# 是否已经使用了记牌器
	gameCountSum 		15 : integer		# 总对局数量
	winCountSum 		16 : integer		# 总胜场数量

	skillId				19 : integer		# 技能id
	skillState			20 : boolean		# 技能触发状态 true：触发状态，可使用
}

.SSWPlayerStartInfo {
	id 			0 : string
	cards 		1 : *integer
	flowers 	2 : *integer
}

.SSWRoom {
	id 					0 : string
	conf 				1 : SSWRoomConf
	status 				2 : string 		
	selectional_cards 	3 : *integer 	# 可选的牌
	discard_cards 		4 : *integer 	# 弃牌
	cardnum 			5 : integer 	# 剩余的牌数量
	players 			6 : *SSWPlayer
	all_bills 			7 : *SSWBill 	# 所有的账单记录(每4条为一组)
}

.SSWBill {
	id 			0 : string 		# 玩家ID
	multiple 	1 : integer		# 游戏倍数
	win_gold	2 : integer 	# 赢取金币 (负值代表输的金币)
	gold 		3 : integer  	# 该玩家当前金币
	tag 		4 : string 		# 'bankrupt' | 'capping' 破产 or 封顶
	cards   	5 : *integer 	# 剩余的牌
	all_win_gold 6 : integer 	# 总的输赢 只会出现在惩罚账单中
}
]]


local c2s = [[
	# 获取七雀牌房间信息
	ssw_room_info 2200 {
		response {
			room 0 : SSWRoom 
		}
	}


################## Actions 没有返回 ##################
ssw_takecard 2201 {
	request {
		from_pool 	0 : boolean 	# 从牌堆中获取
		card 		1 : integer 	# 从选牌区中选择一个
	}
}

ssw_playcard 2202 {
	request {
		card 0 : integer
	}
}

ssw_hu 2203 {
}


# 身上金币亏完后, 放弃充值 (进入观战状态)
ssw_giveup 2204 {
}


# 离开房间
ssw_exit 2205 {
	response {
		e_info 		0 : integer
	}
}


################## EX ##################
# 七雀牌使用记牌器
ssw_card_recorder 2206 {
	response {
		e_info 		0 : integer
		storeRet 	1 : integer		# 商店购买返回值
	}
}

ssw_complete_guide 2207 {
	response {
		ok 0 : boolean 		# false 代表已经领取了
		list 1 : *Item 		# 奖励列表
	}
}



]]


local s2c = [[
####################################################### GameEvent

ssw_match_ok 2200 {
	request {
		room 0 : SSWRoom
	}
}

# 开始发牌
ssw_gamestart 2201 {
	request {
		selectional_cards 	0 : *integer	# 可选区的牌(1张)
		pool_num 			1 : integer 	# 牌堆张数
		players 			2 : *SSWPlayerStartInfo
		skill_id 			3 : integer 	# 技能ID
		first_pid			4 : string 	    # 首发玩家id
		firstSkillId		5 : integer 	# 首发技能id（有此值表示是由技能触发的首出）
	}
}

ssw_gameover 2202 {
	request {
		.RoomGameOverInfo_SSW {
			id 			0 : string 		# 玩家ID
			multiple 	1 : integer		# 游戏倍数(总)
			cards   	2 : *integer 	# 剩余的牌
			gold 		3 : integer  	# 该玩家当前金币
			goldChange	4 : integer 	# 金币变化 (负值代表输的金币)
			tag 		5 : integer 	# RoomPlayerOverTag
		}
		info				0 : RoomGameOverInfoBase		# 基础信息
		datas 				1 : *RoomGameOverInfo_SSW(id) 	# 各玩家信息
		punishmentBills		2 : *SSWBill 					# 惩罚账单
	}
}


####################################################### Game Player Actions
ssw_p_swapcard 2203 {
	request {
		pid 		0 : string 		
		flowers 	1 : *integer	# 花牌
		cards 		2 : *integer 	# 换回来的牌
	}
}


ssw_p_takecard 2204 {
	request {
		pid 		0 : string
		from_pool 	1 : boolean
		card 		2 : integer 			# from_pool == false 时 其他人才能看见此参数
		flowers  	3 : *integer
		events  	4 : *integer		# 触发的事件
	}
}

ssw_p_playcard 2205 {
	request {
		pid 0 : string
		card 1 : integer
	}
}

ssw_p_hu 2206 {
	request {
		pid 0 : string
		card 1 : integer
		cardtype 2 : string
		events 3 : *integer  	# 事件列表
		multiple 4 : integer 	# 总的倍数
		bills 5 : *SSWBill
		over 6 : boolean 		# 是否胡之后游戏就结束
	}
}

ssw_p_giveup 2207 {
	request {
		pid 0 : string
		giveup 1 : boolean 		# false 表示玩家充值了, 不放弃
	}
}


ssw_p_exit 2208 {
	request {
		pid 0 : string
	}
}

ssw_p_praise 2210 {
	request {
		pid 0 : string 		# 目标玩家ID
		num 1 : integer     # 被赞次数
	}
}

####################################################### Please
ssw_please_takecard 2209 {
	request {
		pid 			0 : string
		clock 			1 : integer
		first 			2 : boolean 	# 首发
		pool_last_one 	3 : integer		# 天眼技能触发, 显示牌堆最上面一张牌
		NO_1 			4 : boolean 	# 天下第一技能触发
	}
}

# 等待出牌
ssw_please_playcard 2211 {
	request {
		pid 				0 : string
		clock 				1 : integer
	}
}

# 等待玩家购买豆子后再次加入对局
ssw_please_recharge 2213 {
	request {
		pid 				0 : string
		clock 				1 : integer
	}
}

####################################################### Other



]]


return {
	struct = struct,
	c2s = c2s,
	s2c = s2c
}