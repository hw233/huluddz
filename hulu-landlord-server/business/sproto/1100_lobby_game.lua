local struct = [[
.GameRecord {
	id 			0 : string
	start_time 	1 : integer
	end_time 	2 : integer
	roomtype 	3 : integer
	is_win 		4 : boolean
}
]]


local c2s = [[
start_match 1100 {
	request {
		gametype 		0 : integer		
		roomtype 		1 : integer		
		showcardx5 		2 : boolean 	# 是否明牌开始
		anonymous  		3 : boolean		# 是否匿名开始
		effectTimeCfg	4 : *KeyValuePair(key)	# 特效时间配置 配置单位(ms), 调试使用，正式无需传递
	}
	response {
		err 0 : integer
	}
}

cancel_match 1101 {
	response {
		err 0 : integer
	}
}

game_records 1102 {
	request {
		page 0 : integer
		page_num 1 : integer
		gametype 2 : integer
	} response {
		records 0 : *GameRecord
	}
}

game_record_content 1103 {
	request {
		id 0 : string
		gametype 1 : integer
	} response {
		content 0 : string 			# json string
	}
}
]]


local s2c = [[
match_ok 1100 {
	request {
		room 0 : Room
	}
}

]]



return {
	struct = struct,
	c2s = c2s,
	s2c = s2c
}