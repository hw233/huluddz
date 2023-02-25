local c2s = [[

receive_dailytask_reward 1360 {
	request {
		id 0 : integer
	}
}

receive_dailytask_activity_reward 1361 {
	request {
		id 0 : integer
	}
}

]]


local s2c = [[

]]



return {
	c2s = c2s,
	s2c = s2c
}