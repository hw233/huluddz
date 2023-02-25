local c2s = [[
buy 1200 {
	request {
		id 0 : integer 			# 商品 ID
		num 1 : integer
	}
	response {
		err 0 : integer
		is_double 1 : boolean 	# 是否翻倍
	}
}

ali_order 1201 {
	request {
		id 			0 : integer 	# 商品 ID
		platform 	1 : string 		# 'ios', 'android'
		extend 		2 : string 		# 'json string'
	}
	response {
		err 0 : integer 
	    orderinfo 1 : string
    }
}

wx_order 1202 {
	request {
		id 			0 : integer  	# 商品ID
		platform 	1 : string
		extend 		2 : string 		# 'json string'
	}
	response {
		err 0 : integer 
	    url 1 : string
    }
}

huawei_order 1203 {
	request {
		id 			0 : integer  	# 商品ID
		platform 	1 : string
		extend 		2 : string 		# 'json string'
	}
	response {
		err 0 : integer
		orderid 1 : string
		product_id 2 : string
	}
}

huawei_pay_suc 1204 {
	request {
		orderid 0 : string 		# huawei_order 返回的 orderid
		trade_no 1 : string 	# InAppPurchaseData.orderId
		token 2 : string 		# InAppPurchaseData.purchaseToken
		productid 3 : string
	}
	response {
		err 0 : integer
	}
}

]]


local s2c = [[

# 支付成功后的通知
buy_suc 1200 {
	request {
		id 0 : integer 			# 商品 ID
		list 1 : *Item 			# 商品列表
	}
}
]]




return {
	c2s = c2s,
	s2c = s2c
}