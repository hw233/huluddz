local c2s = [[

	heartbeat 1 {
		# response {
		#	ok 		0 : boolean
		#	time 	1 : integer # 服务器时间
		# }
	}
	
	# 获取服务器时间
	TimeGet 2 {
		response {
			time 	2 : integer # 服务器时间
		}
	}

	logout 3 {}

	GetUserInfo 4 {
		response {
			userInfo 0 : UserInfo
			
			gameFuncDatas 92 : *GameFuncData(id)
		}
	}


]]


local s2c = [[
	s2c_heartbeat 1 {}

	# 显示奖励
	ShowReward 10 {
		request {
			data 0 : *RewardStruct(fromType)
		}
	}

]]




return {
	c2s = c2s,
	s2c = s2c
}