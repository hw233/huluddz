local struct = [[
.MailSender {
	type 1 : integer			# 邮件类型, 1: 系统  2: 好友
	id 2 : string
	nick 3 : string
}

.Mail {
	id 0 : string 				# 邮件ID
	sender 1 : MailSender 		# 发送人
	receiver 2 : string 		# 收件人ID
	title 3 : string 			# 邮件标题
	content 4 : string 			# 邮件内容
	pack 5 : *Item 				# 附件
	readed 6 : boolean 			# 是否已读
	received 7 : boolean 		# 是否已领取附件 (对于没有附件的邮件, 该字段没有意义)
	create_time 8 : integer 	# 创建(发送)时间
}
]]



local c2s = [[
query_mails 1300 {
	request {
		page 0 : integer	# 请求第几页的邮件(从1开始, 1页6封)
	}
	response {
		mails 0 : *Mail
	}
}

read_mail 1301 {
	request {
		id 0 : string
	}
}

receive_mail 1302 {
	request {
		id 0 : string
	}
	response {
		err 0 : integer
	}
}

delete_mail 1303 {
	request {
		id 0 : string
	}
}

]]


local s2c = [[

]]



return {
	struct = struct,
	c2s = c2s,
	s2c = s2c
}