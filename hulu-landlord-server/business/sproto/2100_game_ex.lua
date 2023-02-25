local c2s = [[
game_report 2100 {
	request {
		pid 0 : string 		# 被举报人ID
		content 1 : string
	}
}

GameChat 2101 {
	request {
		id 0 : integer 		# 文字语音ID
		type 1 : integer  # 1：文字 2：表情
	}
}

mute 2103 {
	request {
		to 0 : string 		# 禁言对象ID
	}
	response {
		err 0 : integer
	}
}
]]


local s2c = [[
PlayerGameChat 2100 {
	request {
		pid 0 : string
		id 1 : integer
		type 2 : integer
	}
}

p_mute 2102 {
	request {
		from 1 : string
		to 2 : string
	}
}
]]



return {
	c2s = c2s,
	s2c = s2c
}