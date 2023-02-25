local struct = [[

.Bill {
	id 			0 : string 		# 玩家ID
	multiple 	1 : integer		# 游戏倍数
	win_gold	2 : integer 	# 赢取金币 (负值代表输的金币)
	gold 		3 : integer  	# 该玩家当前金币
	tag 		4 : string 		# 'bankrupt' | 'capping'
	cards   	5 : *integer 	# 剩余的牌
}
]]


local c2s = [[
room_info 2000 {
	response {
		room 0 : Room 
	}
}

# 请求记牌器信息
card_recorder 2001 {
	response {
		err 0 : integer
		cards 1 : *integer
	}
}

################## Actions 没有返回 ##################

trusteeship 2002 {}

cancel_trusteeship 2003 {}

showcard 2004 {}

call_landlord 2005 {
	request {
		call 0 : boolean
	}
}

rob_landlord 2006 {
	request {
		rob 0 : boolean
	}
}

# 霸王抢
overlord_rob_landlord 2007 {}


double 2008 {
	request {
		multiple 0 : integer 	# 1:不加倍	2: 加倍	 4: 超级加倍
	}
}

double_cap 2009 {
	request {
		multiple 0 : integer 	# 1:不翻倍 	4:翻倍
	}
}

playcard 2010 {
	request {
		pass 0 : boolean
		playedcards 1 : RoomPlayedCards
	}
}

check_bottom_card 2011 {
	request {
		index 0 : integer
	}
	response {
		card 0 : integer
	}
}

]]


local s2c = [[
####################################################### GameEvent

# 开始发牌
game_start_dealcard 2000 {
	request {
		cards 0 : *integer 		# 你的手牌
	}
}

# 确定地主
determine_landlord 2001 {
	request {
		landlord_id 0 : string
		bottom_cards 1 : *integer 	# 3张底牌
		multiple 2 : integer 		# 1 / 2 / 4
	}
}

gameover 2002 {
	request {
		bills 0 : *Bill 		# 玩家结局信息清单列表
		spring 1 : string 		# 'spring': 春天  'reverse_spring': 反春
		title 2 : UserTitle 	# 我的头衔信息
		bust_id 3 : integer 	# 破产礼包ID  (破产了才有)
	}
}


####################################################### Game Player Actions

p_trusteeship 2003 {
	request {
		pid 0 : string
	}
}

p_cancel_trusteeship 2004 {
	request {
		pid 0 : string
	}
}

p_showcard 2005 {
	request {
		pid 0 : string
		cards 1 : *integer
	}
}

p_call_landlord 2006 {
	request {
		pid 0 : string
		call 1 : boolean
	}
}

p_rob_landlord 2007 {
	request {
		pid 0 : string
		rob 1 : boolean
	}
}

p_overlord_rob_landlord 2008 {
	request {
		pid 0 : string
		use_diamond 1 : boolean
	}
}


p_double 2009 {
	request {
		pid 0 : string
		multiple 1 : integer 	# 1:不加倍	2: 加倍	 4: 超级加倍
		use_diamond 2 : boolean
	}
}

# 封顶翻倍
p_double_cap 2010 {
	request {
		pid 0 : string
		multiple 1 : integer
		top 2 : integer 		# 如果玩家封顶翻倍, 才有该值
		use_diamond 3 : boolean
	}
}

p_playcard 2011 {
	request {
		pid 0 : string
		pass 1 : boolean
		playedcards 2 : RoomPlayedCards
	}
}


####################################################### Please
please_call_landlord 2012 {
	request {
		pid 0 : string
		clock 1 : integer
	}
}

please_rob_landlord 2013 {
	request {
		pid 0 : string
		clock 1 : integer
	}
}

please_overlord_rob_landlord 2014 {
	request {
		qualified 0 : boolean 	# 是否有资格参与霸王抢
		clock 1 : integer
	}
}

please_double 2015 {
	request {
		clock 0 : integer
	}
}

please_double_cap 2016 {
	request {
		clock 0 : integer
	}
}

please_playcard 2017 {
	request {
		pid 0 : string
		clock 1 : integer
		playstatus 2 : string  # 'first': 第一次出牌的人(有明牌按钮)  'mustplay': 必须出牌(没有pass按钮)  'normal': 普通出牌, 有pass按钮
	}
}

####################################################### Other

# 同步游戏倍数
sync_multiple 2018 {
	request {
		multiple 0 : integer
	}
}

# 扣除房费
deduction_room_ticket 2019 {
	request {
		ticket 0 : integer
	}
}

# 同步其他玩家的金币
sync_player_gold 2020 {
	request {
		pid 0 : string
		gold 1 : integer
	}
}

]]


return {
	struct = struct,
	c2s = c2s,
	s2c = s2c
}