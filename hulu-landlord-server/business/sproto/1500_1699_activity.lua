local struct = [[

.ActiveReliefFund {
	day 	0 : string				# 最后一次领取日期 '2021-04-01'
	count 	1 : integer 			# 领取次数
}

.ActiveSign {
	day 		0 : string 			# 最后一次签到日期 '2021-04-01', index = 0 时, 该字段没有意义
	index 		1 : integer 		# 最后一次签到的索引, 0 代表没有签到
	list 		2 : *boolean 		# 30个solt, true 表示已领取
}

.ActiveConsumeReward {
	received 0 : *integer 			# 已领取的 indexes
}

.ActiveDailyShare {
	day 				0 : string		# 上一次分享日期
	shared 				1 : integer
}

.ActiveFirstCharge {
	purchased 0 : boolean 			# 已购买的
}

.ActiveOnlineGift {
	received 0 : *integer 			# 已领取的 indexes
}

.ActiveMonthCard {
	.ReceivedItem {
		index 0 : integer
		day 1 : string 		# 领取日期 '2021-04-15'
	}
	received 0 : *ReceivedItem
}

# 拉新
.ActiveInviteNewPlayer {
	received     0 : integer 	# 已领取的 indexes (64 bit)
	invited_num  1 : integer 	# 已邀请的数量
	belong_user  2 : string		# 属于哪个玩家
}

.Invite {
	bid 0 : string
	id  1 : string
	nick 2 : string
}


.ActiveAnchorRebate {
	day 				0 : string 		# 当前日期 '2021-04-15'
	received_times 		1 : integer 	# 已领取次数
	max_receive_times 	2 : integer 	# 最大领取次数
}


.ActiveYearCard {
	receive_day 0 : string 	# 上次领取日期
}
# 限时活动 ###################################################################


.ActiveWinningStreak {
	achieved 		0 : boolean 	# 已通关
	reviving 		1 : boolean 	# 复活中
	count 			2 : integer 	# 当前胜利局数
	history_best 	3 : integer 	# 历史最高成绩
	received 		4 : *integer 	# 已领取的 indexes

}

.ActiveTotalCharge {
	received 0 : *integer 			# 已领取的 indexes
	recharge_amount 1 : double 		# 累计充值
}

.ActiveSingleCharge {
	received 0 : *integer 			# 已领取的 indexes
	max_singlecharge 1 : double 	# 最大单笔充值
}

.ActiveGroupBuy {
	.StoreItem {
		id 0 : integer 				# 商品ID
		allbuy 1 : integer 			# 累计购买数量
	}
	received 0 : *integer 			# 已领取的 indexes
	purchased 1 : integer 			# 已购买的 indexes (64 bit)
	store 2 : *StoreItem
}

.ActiveCollocation {
	purchased 0 : integer 			# 已购买的 indexes (64 bit)
}

.Active {
	relieffund 			0 : ActiveReliefFund 		# 救济金
	sign 				1 : ActiveSign
	consume_reward 		2 : ActiveConsumeReward
	dailyshare 			3 : ActiveDailyShare
	firstcharge 		4 : ActiveFirstCharge
	online_gift 		5 : ActiveOnlineGift
	monthcard 			6 : ActiveMonthCard
	anchor_rebate 		7 : ActiveAnchorRebate
	yearcard 			8 : ActiveYearCard

	winning_streak 		9 : ActiveWinningStreak
	totalcharge 		10 : ActiveTotalCharge
	singlecharge 		11 : ActiveSingleCharge
	group_buy			12 : ActiveGroupBuy
	collocation 		13 : ActiveCollocation
	invite_newplayer 	14 : ActiveInviteNewPlayer
}


	.ActivityData {
		id 			0 : integer 		# 活动ID
		startDt 	1 : integer 		# 开始时间
		endDt 		2 : integer 		# 结束时间
		open      	3 : boolean 		# 是否开启
	}

	.UserActivityData {
		id 			0 : integer 		# 活动ID
		startDt 	1 : integer 		# 个人活动 or 触发活动的开始时间
		endDt 		2 : integer 		# 个人活动 or 触发活动的结束时间

		paramNum	3 : integer			# 活动通用参数，太简单的活动直接复用

		data4001	6 : Active4001		# 破产礼包
		data4004	7 : Active4004		# 摇一摇
	}

	.Active4001 {
		id		0 : integer		# 破产礼包id
		isBuy	1 : boolean		# 是否购买
		gold	2 : integer		# 反还额度
	}
	.Active4004 {
		count	0 : integer # 每日已使用次数
	}
]]

local c2s = [[

	# 活动配置数据
	GetActivityDatas 1600 {
		request {
			idArr 	0 : *integer 	# 可选的, 不传则返回所有活动配置数据
		}
		response {
			datas 	0 : *ActivityData(id)
		}
	}

	# 活动用户相关数据
	GetUserActivityDatas 1605 {
		request {
			idArr 	0 : *integer 	# 可选的, 不传则返回所有用户活动数据
		}
		response {
			datas 	0 : *UserActivityData(id)
		}
	}


	# 摇一摇
	Act4004	1640 {
		response {
			e_info  	0 : integer
			id 			1 : integer	# 商城id
		}
	}
	

# 订阅成功后, 该活动信息变动后, 服务器会发送 sync_active_info
sub_active 1501 {
	request {
		name 0 : string 	# 活动名称
	}
}

unsub_active 1502 {
	request {
		name 0 : string 	# 活动名称
	}
}



sign 1503 {
	request {
		index 0 : integer
	}
}

receive_consume_reward 1504 {
	request {
		index 0 : integer
	}
}

dailyshare 1505 {
	request {
		type 0 : integer
	} response {
		err 0 : integer
	}
}

receive_online_gift 1506 {
	request {
		index 0 : integer
	}
}

receive_winning_streak 1507 {
	request {
		index 0 : integer
	}
}

receive_totalcharge 1508 {
	request {
		index 0 : integer
	}
}

receive_singlecharge 1509 {
	request {
		index 0 : integer
	}
}

receive_group_buy 1510 {
	request {
		index 0 : integer
	}
}

receive_monthcard 1511 {
	request {
		index 0 : integer
	}
}

receive_relieffund 1512 {
}
#领取邀请奖励接口
receive_invite_newplayer 1513 {
	request {
		index 0 : integer
	} response {
		err 0 : integer 	# 错误码
	}
}

join_invite_newplayer 1514 {
	request {
		bid 0 : string
	} response {
		err 0 : integer 	# 错误码
	}
}

me_invite_newplayer 1515 {
	request {
		id 0 : string
	} response {
		err 0 : integer 	# 错误码
	}
}

invite_info 1516 {
	response {
		invite 0 : ActiveInviteNewPlayer
	}
}

#同意加入玩家消息通知接口
ok_invite 1517 {
	request {
		id 0 : string
		bid 1 : string
	}
}

receive_yearcard 1518 {
}


]]


local s2c = [[

# 注意, 一般情况下只同步 active 下面的某一个字段(活动)
sync_active_info 1500 {
	request {
		active 0 : Active
	}
}

	# 同步活动配置数据
	SyncActivityData 1600 {
		request {
			datas 0 : *ActivityData(id)
		}
	}

	# 同步活动用户数据
	SyncUserActivityData 1605 {
		request {
			datas 0 : *UserActivityData(id)
		}
	}

invite 1502 {
	request {
		invite 0 : Invite
	}
}

ok_invite 1503 {
	request {
		invite 0 : Invite
	}
}

SyncAct4004	1504 {
	request {
		id 			1 : integer	# 商城id
	}
}

]]



return {
	struct = struct,
	c2s = c2s,
	s2c = s2c
}