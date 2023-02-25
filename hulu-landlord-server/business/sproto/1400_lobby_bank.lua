local c2s = [[
bank_info 1400 {
	response {
		bank 0 : Bank
	}
}

bank_deposit 1401 {
	request {
		amount 0 : integer 	# 存入的数量
	}
	response {
		amount 0 : integer 	# 存入的数量
		balance 1 : integer # 银行最新的余额
	}
}

bank_takeout 1402 {
	request {
		amount 0 : integer 	# 取出的数量
	}
	response {
		amount 0 : integer 	# 取出的数量
		balance 1 : integer # 银行最新的余额
	}
}

bank_upgrade 1403 {
	response {
		addition 0 : integer # 升级后的加成
	}
}

bank_upgrade_oneclick 1404 {
	response {
		addition 0 : integer # 升级后的加成
	}
}


]]


local s2c = [[

]]



return {
	c2s = c2s,
	s2c = s2c
}