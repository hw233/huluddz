local conf = {}

conf.head_prefix = "https://yunteng-static.oss-cn-hangzhou.aliyuncs.com/heads/"

conf.prob = {
	showcardx5 = 0.01,
	good_cards = {
		call_landlord = 0.8,
		rob_landlord = 0.6,
		overlord_rob_landlord = 0.5,
		double = 0.7,
		double_cap = 0.4
	},
	bad_cards = {
		call_landlord = 0.1,
		rob_landlord = 0.1,
		overlord_rob_landlord = 0.1,
		double = 0.1,
		double_cap = 0.1
	}
}


return conf