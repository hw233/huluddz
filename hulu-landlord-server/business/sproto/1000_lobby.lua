local struct = [[

.ActivePoint {
	sign 				0 : integer
	consume_reward 		1 : integer
	dailyshare 			2 : integer
	online_gift 		3 : integer
	monthcard 			4 : integer

	winning_streak 		5 : integer
	totalcharge 		6 : integer
	singlecharge 		7 : integer
	group_buy			8 : integer
	invite_newplayer    9 : integer
	yearcard 			10 : integer
}



.Redpoint {
	mail 		0 : integer 		# 邮件数量
	dailytask 	1 : integer
	vip 		2 : integer
	active      3 : ActivePoint
}

.HorseLampItem {
	text 0 : string
	start_time 1 : integer	# 开始时间
	end_time 2 : integer 	# 结束时间
	index 3 : integer 		# 按从小到大排序
}

]]


local c2s = [[
base_info 1000 {
	response {
		user    0 : UserInfo
		status 	1 : string
		is_anchor 2 : boolean 	# 是否是主播
	}
}

horselamps 1001 {
	response {
		list 0 : *HorseLampItem
	}
}

receive_title_season_reward 1003 {
	response {
		err 0 : integer
		title 1 : UserTitle
	}
}

realname_auth 1004 {
	request {
		name 		0 : string
		idcard 		1 : string
		tel 		2 : string
		verify_code 3 : string
	}
	response {
		err 0 : integer
	}
}

backpack 1005 {
	response {
		backpack 0 : *BackpackItem
	}
}

give_advice 1006 {
	request {
		advice 0 : string
	}
}

redpoint 1007 {
	response {
		redpoint 0 : Redpoint
	}
}

gain_verify_code 1008 {
	request {
		tel 0 : string
	}
	response {
		err 0 : integer
	}
}

exchange_cdk 1009 {
	request {
		cdk 0 : string
	} response {
		err 0 : integer 	# 错误码
		list 1 : *Item 		# 获得的道具列表
	}
}

]]


local s2c = [[
sync_gold 1000 {
	request {
		gold 0 : integer
	}
}

sync_diamond 1001 {
	request {
		diamond 0 : integer
	}
}

sync_coupon 1002 {
	request {
		coupon 0 : integer
	}
}

sync_backpack 1003 {
	request {
		backpack 0 : *BackpackItem
	}
}

sync_redpoint 1005 {
	request {
		redpoint 0 : Redpoint
	}
}

immediate_horselamp 1008 {
	request {
		text 	0 : string 		# 内容
		times 	1 : integer 	# 展现次数
		lv 		2 : integer 	# 优先级 (大的优先)
	}
}

sync_bank 1009 {
	request {
		bank 0 : Bank
	}
}

]]


return {
	struct = struct,
	c2s = c2s,
	s2c = s2c
}