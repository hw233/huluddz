
local struct = [[
	.GourdLoosenSoilBox {
		id			0 : string
		endDt		1 : integer		# 结束时间
		isOpen		2 : boolean		# 是否已开启宝箱
		rewardArr	3 : *Item		# 宝箱奖励
	}
	.GourdFriendHelp {
		id			0 : string		# 好友id
		endDt		1 : integer		# 结束时间
		data 		2 : IUserBase
	}
	.GourdFriendApply {
		id			0 : string		# 好友id
		lastDt		1 : integer		# 上次邀请时间
	}
	.GourdPickFruitRecord {
		id			0 : string		# 玩家id
		count		1 : integer		# 摘取次数
		pickNum		2 : integer		# 摘取总数
		arr			3 : *string		# 已被摘取的果实id
	}
	.GourdCollectUser {
		id			0 : string		# 好友id
		data		1 : IUserBase	# 基础信息
		startDt		2 : integer		# 加入时间
	}	
	.GourdActionRecord {
		num					0 : integer				# 摘豆时是数量，松土是氧气
		dt					1 : integer				# 时刻

		isOpenBox			2 : boolean				# 是否为开启宝箱操作，不是开启宝箱就是松土
		boxObj				3 : GourdLoosenSoilBox	# 宝箱信息，开启宝箱时有内部道具信息，未松土时表示获取宝箱

		fruitType			4 : integer				# 果实类型
		isUseItem			5 : boolean				# 是否使用道具
	}
	.GourdActionRecordInfo {
		id			0 : string				# 操作者
		toId		1 : string				# 被操作者
		data		2 : IUserBase			# 基础信息
		type		3 : integer				# 记录类型
		dayDt		4 : integer				# 每日0点
		lastDt		5 : integer				# 最后一次操作事件
		recordArr	6 : *GourdActionRecord	# 最后一次操作事件
		isLook		7 : boolean				# 最新操作数据是否查看
	}

	.UserFashion {
		id		0 : integer
		type	1 : integer
		endDt	2 : integer
	}
	.UserFashionTypeData {
		type	0 : integer
		datas	1 : *UserFashion(id)
	}
	.VipInfo {
		exp 0 :integer
		level 1 :integer
	}

]]

local c2s = [[

	# （创角）用户信息初始设置
	UserInitSet 590 {
		request {
			type 	0 : integer # 1：初始男角色  2：初始女角色
			name 	1 : string  # 初始名称
		}
		response {
			e_info 		0 : integer
			initSet   	1 : boolean # 更新 userinfo
			nickname   	2 : string 	# 新昵称
			data		3 : IUserBase
		}
	}

	# 设置引导值
	SetGuideObj 595 {
		request {
			key		0 : string  # 键
			num		1 : integer 
		}
		response {
			e_info 		0 : integer
			guideObj	1 : *KeyNumPair(key) # userinfo上 guideObj 更新
		}
	}

	# 领取引导奖励
	GuideRewardGet 596 {
		response {
			e_info 			0 : integer
			guideRewardQQP	1 : integer
			reward 			2 : *RewardStruct(fromType)
		}
	}

	# 设置昵称
	SetNickName 600 {
		request {
			name 0 : string
		}
		response {
			e_info 			0 : integer # 1:成功 2:昵称长度错误 8:昵称格式错误 6:材料不足
			nickname 		1 : string  # 新昵称
			nickNameSetNum 	2 : integer # 设置昵称次数
		}
	}

	SetGender 601 {
		request {
			gender 0 : integer
		}
		response {
			e_info 0 : integer # 1:成功 3:参数错误
			gender 1 : integer
		}
	}

	SetHead 602 {
		request {
			head 0 : string
		}
		response {
			e_info 	0 : integer # 1:成功 3:参数错误
			head 	1 : string
			gender 	2 : integer
		}
	}

	SetSignature 603 {
		request {
			signature 0 : string
		}
		response {
			e_info 		0 : integer # 1:成功 3:签名长度错误
			signature 	1 : string
		}
	}

	SetHeadFrame 604 {
		request {
			headFrameItemId 	0 : integer # 头像框道具id
		}
		response {
			e_info 		0 : integer # 1:成功 3:参数错误
			headFrame 	1 : integer
		}
	}

	SetChatFrame 605 {
		request {
			chatFrameItemId 0 : integer
		}
		response {
			e_info 		0 : integer # 1:成功 3:参数错误
			chatFrame 	1 : integer
		}
	}

	# 点赞
	UserLike 606 {
		request {
			id 0 : string
		}
		response {
			e_info 0 : integer
			like   1 : integer # 点赞数量
		}
	}

	SetGameChatFrame 607 {
		request {
			gameChatFrameItemId 	0 : integer # 道具id
		}
		response {
			e_info 		0 : integer # 1:成功 3:参数错误
			gameChatFrame 	1 : integer
		}
	}

	SetInfoBg 608 {
		request {
			InfoBgItemId 	0 : integer # 道具id
		}
		response {
			e_info 		0 : integer # 1:成功 3:参数错误
			infoBg 	1 : integer
		}
	}

	SetClockFrame 609 {
		request {
			clockFrameItemId 	0 : integer # 道具id
		}
		response {
			e_info 		0 : integer # 1:成功 3:参数错误
			clockFrame 	1 : integer
		}
	}

# Cmd 指令接口
UserCmd 610 {
    request {
        cmd 0 : string # 指令
        paramArr 1 : *string # 参数数组
    }
    response {
        e_info  0 : integer # 0:失败 1:成功
        obj     1 : string  # 返回对象字符串
        tip     2 : string  # 返回信息说明
    }
}

# 领取段位奖励
GetLvReward 615 {
    request {
		idArr 0 : *integer
	}
	response {
		e_info 0 : integer
		lvRewardRecord 1 : *Hash(key)
	}
}

# 获取对局记录（战绩）
GetGameRecordArr 616 {
    request {
		id 0 : string # 指定玩家id， 不传默认为本玩家id
	}
	response {
        .GameRecord {
            id 			0 : string
            uId			1 : string
            gameType	2 : integer # 对局类型
            isWin	    3 : boolean # 胜负
            startDt	    4 : integer # 开始时间
            endDt	    5 : integer

            playerType	6 : integer # 玩家在对局中的类型 农民 or 地主
            multiple	7 : integer # 倍数
            cardType	8 : string  # 牌型（七雀牌中是牌型字符串）
        }
		arr 0 : *GameRecord
	}
}

# 战绩显示开关
GameRecordShowSet 617 {
	request {
		isCloseShowGameRecord 0 : boolean # 
	}
	response {
		isCloseShowGameRecord 0 : boolean # 更新userinfo上的改字段
	}
}

# 获取玩家道具集合
GetUserItemDatas 625 {
	response {
		datas 0 : *UserItem(id)
	}
}

# 使用道具
UseItem 626 {
	request {
        id 		0 : integer
        gId 	1 : string  # 有的道具又唯一id
        num 	2 : integer
        param 	3 : string # 预留参数，如果此道具是个选择获取的宝箱，可以传入选择奖励索引
    }
    response {
        e_info 0 : integer
    }
}

# 获取邮件数据
GetUserMailDatas 630 {
	response {
		datas 0 : *UserMail(id)
	}
}

# 读取邮件
ReadMail 631 {
	request {
		id 0 : string
	}
	response {
		e_info 0 : integer # 1:成功 2:失败
		id 	   1 : string
	}
}

# 领取邮件道具
GetMailItem 632 {
	request {
		id 		0 : string
		type    1 : integer # 1：单个领取 2：一键领取,会将其设置为已读
	}
	response {
		e_info 0 : integer # 1:成功 2:失败
		id 	   1 : string
	}
}

# 删除邮件
RemoveMail 633 {
	request {
		id 		0 : string
		type    1 : integer # 1：单个删除 2：一键删除已读，已领取道具的邮件
	}
	response {
		e_info 0 : integer # 1:成功 2:失败
		id 	   1 : string
	}
}


# 获取任务数据
GetUserTaskDatas 650 {
    request {
		taskType 0 : integer # 为nil时 返回所有任务数据， 其他值时只返回指定类型数据
	}
	response {
		datas 				0 : *UserTask(id)
		treasureArr 		1 : *integer		# 该类型已获取的活跃宝箱id
		taskType			2 : integer			# 因前端需求返回
	}
}

# 领取任务奖励
GetTaskItem 651 {
	request {
		id 		0 : integer		# 任务id
	}
	response {
		e_info 	0 : integer
		id 		1 : integer		# 因前端需求返回
	}
}

# 领取任务活跃奖励
GetTaskTreasureItem 652 {
	request {
		id 		0 : integer		# 活跃奖励id
	}
	response {
		e_info 	0 : integer
		id 		1 : integer		# 因前端需求返回
	}
}

# 获取英雄数据
GetUserHeroDatas 670 {
	request {
		id 0 : string # 指定玩家id， 不传默认为本玩家id
	}
	response {
		datas 	0 : *UserHero(id)
		id		1 : string
	}
}

# 英雄技能提升
HeroSkillLvUp 671 {
	request {
		id      0 : string
		type    1 : integer # 1 为普通材料 2 为钻石升级
	}
	response {
		e_info  	0 : integer
		skillLv 	1 : integer
		skillLvOld 	2 : integer
	}
}

# 英雄心情提升
HeroMoodUp 672 {
	request {
		id      0 : string
		costArr 1 : *Item
	}
	response {
		e_info  		0 : integer
		moodExp 		1 : integer
		moodLv  		2 : integer
		moodExpOld  	3 : integer
		moodLvOld  		4 : integer
	}
}

# 英雄出场
HeroUse 673 {
	request {
		id      0 : string
	}
	response {
		e_info  	0 : integer
		skin  		1 : integer
		heroId  	2 : string
	}
}

# 获取符文数据
GetUserRuneDatas 690 {
	request {
		id 0 : string # 指定玩家id， 不传默认为本玩家id
	}
	response {
		datas 	0 : *UserRune(id)
		id		1 : string
	}
}

# 装备符文
RuneEquip 691 {
	request {
		id      	0 : string
		heroId      1 : string
		pos      	2 : integer
	}
	response {
		e_info  0 : integer
	}
}

# 卸下符文
RuneUnEquip 692 {
	request {
		id      0 : string
	}
	response {
		e_info  0 : integer
	}
}

# 符文等级提升
RuneLvUp 693 {
	request {
		id      	0 : string
		type 		1 : integer # 1 为普通材料 2 为钻石升级
		itemNum 	2 : integer # 经验书数量
		runeArr 	3 : *string # 材料符文id数组
	}
	response {
		e_info  	0 : integer
		exp 		1 : integer
		lv  		2 : integer
		expOld  	3 : integer
		lvOld  		4 : integer
	}
}

# 获取好友数据
GetUserFriendDatas 710 {
	response {
		datas 0 : *UserFriend
	}
}

# 通过id查找好友
FriendFind 711 {
	request {
		id      	0 : string
	}
	response {
		e_info  	0 : integer
		data 		1 : IUserBase
		onlineDt 	2 : integer		# 上线时间 
		offlineDt 	3 : integer		# 离线时间
		isApply 	4 : integer		# 0未申请,1已申请,2已添加
	}
}

# 获取好友申请数据
GetUserFriendApplyDatas 712 {
	response {
		datas 0 : *UserFriendApply(id)
	}
}

# 好友申请
FriendApply 713 {
	request {
		id      	0 : string
		fromType    1 : integer	#枚举 FriendFromType
	}
	response {
		e_info  0 : integer
		id      1 : string
	}
}

# 好友申请处理
FriendApplyHandler 714 {
	request {
		idArr      	0 : *string	#	id数组
		type 		1 : integer # 1：同意 2：拒绝
		isAll       2 : boolean # 是否一键
	}
	response {
		e_info  0 : integer
		idArr   1 : *string
		type    2 : integer
		isAll   3 : boolean
	}
}

# 好友赠送礼物
FriendSendGift 715 {
	request {
		id      	0 : string	# 好友id
		index 		1 : integer	# 礼物在策划表中的位置索引
	}
	response {
		e_info  0 : integer
		id      1 : string
	}
}

# 好友礼物领取   成功后需要重新拉取好友数据
FriendGetGift 716 {
	request {
		idArr      	0 : *string	#	id数组
	}
	response {
		e_info  0 : integer
		idArr   1 : *string
	}
}

# 获取好友聊天数据
GetUserFriendChatDatas 717 {
	request {
		id      	0 : string
	}
	response {
		datas 0 : *UserFriendChat(id)
	}
}

# 好友聊天
FriendChat 718 {
	request {
		id      	0 : string
		content     1 : string
	}
	response {
		e_info  0 : integer
	}
}

# 近期牌友
GetUserRecentGameFriendDatas 719 {
	response {
		.UserRecentGameFriend {
			id          	0 : string		# id
			data        	1 : IUserBase	# 基础数据
			gameType		2 : integer		# 对局类型
			roomLevel       3 : integer		# 房间级别
			playerType      4 : integer		# 0：队友 1：对手
			dt       		5 : integer		# 时间
			isApply       	6 : boolean		# 是否申请
			#type			6 : integer 	# 操作类型 0：未处理	1：已申请
		}
		datas 0 : *UserRecentGameFriend(id)
	}
}

# 解除好友
FriendRemove 720 {
	request {
		id      	0 : string
	}
	response {
		e_info  	0 : integer
		id      	1 : string
	}
}

ResetFriendGiftAndNewApply 721 {
	request {
		type   	0 : integer #1 重置好友，2重置好友赠礼
	}
	response {
		e_info  	0 : integer
	}
}

	# 获取商城数据
	GetUserStoreDatas 740 {
		response {
			.StoreShowData {
				showType 	0 : integer
				arr			1 : *integer	# 该页签商品需要在这里包含才可购买
				endDt		2 : integer		# 到期时间
			}
			datas 		0 : *UserStore(id)				# 已购买商品数据
			showDatas 	1 : *StoreShowData(showType)	# 有些页签商品需要在这里包含才可购买
		}
	}

	# 商城购买
	StoreBuy 741 {
		request {
			id 		0 : integer # 商品id
			num 	1 : integer # 数量
		}
		response {
			e_info  0 : integer
		}
	}

	# 获取自己或者其他玩家葫芦藤相关数据
	GetGourdData 770 {
		request {
			id 		1 : string # 数量
		}
		response {
			.GourdLvReward {
				level	0 : string		# 等级（注意是字符串）
				vip		1 : boolean		# vip奖励是否领取
			}
			id						1  : string						# 
			data					2  : IUserBase					# 基础信息
			lvReward  				3  : *GourdLvReward(level) 		# 等级奖励记录
			fixedTimeReward  		4  : *integer  					# 已领取的定点补给记录
			lastGetWaterRewardDt  	5  : integer					# 上次领取水分补给的时刻
			getWaterTimes  			6  : integer					# 已连续几日领取水分补给

			loosenSoilO2ValDayMy  	7  : integer					# 贡献氧气值（日）

			friendHelpApplyRecord  	8  : *GourdFriendApply(id)		# 邀请好友助产记录

			pickFruitNumDay  		9  : integer					# 偷取果实的数量（日）
			pickFruitCountDay  		10 : integer					# 偷取果实次数（日）
			pickFruitFreeCountDay  	11 : integer					# 免费偷取陌生人果实次数（日）
			pickFruitRecord  		12 : *GourdPickFruitRecord(id)	# 摘豆记录/天

			collectUserRecord  		13 : *GourdCollectUser(id)		# 收藏用户数据

			#上面部分为自己的才有
		
			gourdLv					14 : integer				# 葫芦藤等级
			gourdArr				15 : *UserGourd(id)			# 所有的葫芦
			bePickFruitNumDay		16 : integer				# 被别人偷取豆子数量(日)
			fertilizerNum  			17 : integer				# 剩余可用施肥数量
			loosenSoilLv  			18 : integer				# 氧气等级
			loosenSoilO2Val  		19 : integer				# 氧气值
			loosenSoilO2ValDay  	20 : integer				# 获取氧气值（日）
			loosenSoilEndDt  		21 : integer				# 氧气加成结束时间
			friendHelpArr  			22 : *GourdFriendHelp		# 好友助产数组

			loosenSoilCount			23 : integer				# 对此好友的松土次数
			loosenSoilBoxArr		24 : *GourdLoosenSoilBox	# 松土宝箱数组

			addRateSum				25 : integer				# 豆子产出总加成（万分比，向下取整）
		}
	}

	# 葫芦藤浇水
	GourdWatering 771 {
		request {
			num 	1 : integer # 数量
		}
		response {
			e_info  	0 : integer
			gourdLv  	1 : integer # 新的等级
			gourdExp  	2 : integer
			oldLv  		3 : integer # 旧的等级
		}
	}

	# 葫芦藤领取水分奖励
	GourdGetWaterReward 772 {
		response {
			e_info  				0 : integer
			lastGetWaterRewardDt  	1 : integer # 更新葫芦藤数据的该数据
			getWaterTimes  			2 : integer
		}
	}

	# 葫芦藤定点奖励
	GourdFixedTimeReward 773 {
		request {
			index 	0 : integer # 奖励索引
		}
		response {
			e_info  			0 : integer
			fixedTimeReward  	1 : *integer # 更新葫芦藤数据的该数据
		}
	}

	# 葫芦藤施肥
	GourdFertilizer 774 {
		request {
			num 	0 : integer # 数量
		}
		response {
			e_info  			0 : integer
			fertilizerNum  		1 : integer # 剩余施肥加成数量
			fertilizerNumAdd  	2 : integer # 实际增加施肥加成数量
		}
	}

	# 葫芦藤松土
	GourdLoosenSoil 775 {
		request {
			id			0 : string 	# 目标id
			isHoe		1 : boolean # 是否使用锄头
		}
		response {
			e_info  			0 : integer
			isHoe  				1 : boolean
			loosenSoilBoxArr  	2 : *GourdLoosenSoilBox	# 松土宝箱数组
			loosenSoilLvOld  	3 : integer				# 旧的等级
			loosenSoilLv  		4 : integer				# 等级
			loosenSoilO2Val  	5 : integer				# 氧气
			loosenSoilEndDt  	6 : integer				# 加成结束时间
			loosenSoilCount  	7 : integer				# 松土次数
		}
	}

	# 葫芦藤开启宝箱
	GourdLoosenSoilBoxOpen 776 {
		request {
			id		0 : string 	# 目标id
			index	1 : integer # 宝箱索引
		}
		response {
			e_info  			0 : integer
			loosenSoilBoxArr  	1 : *GourdLoosenSoilBox	# 松土宝箱数组
			loosenSoilLv  		2 : integer				# 等级
			loosenSoilO2Val  	3 : integer				# 氧气
			loosenSoilEndDt  	4 : integer				# 加成结束时间
		}
	}

	# 葫芦藤邀请好友助产
	GourdFriendHelpApply 777 {
		request {
			id		0 : string 	# 目标id
		}
		response {
			e_info  		0 : integer
			data  			1 : GourdFriendApply # 新增加的好友助产邀请数据
		}
	}

	# 葫芦藤好友助产
	GourdFriendHelp 778 {
		request {
			id		0 : string 	# 目标id
		}
		response {
			e_info  		0 : integer
		}
	}

	# 葫芦藤动态获取
	GourdActionRecordGet 779 {
		request {
			type		0 : integer # 记录类型 GourdActionType 枚举
			isMe		1 : boolean # 是我的动态
			isLook		2 : boolean # 是查看操作，会将 isLook 字段设置为true
		}
		response {
			e_info  		0 : integer
			arr				1 : *GourdActionRecordInfo # 
			type			2 : integer
			isMe			3 : boolean
		}
	}

	# 葫芦藤收藏
	GourdCollectUser 780 {
		request {
			id		0 : string 	# 目标id
			type	1 : integer # 1：添加收藏 2：取消收藏
		}
		response {
			e_info  		0 : integer
			type  			1 : integer 
			data  			2 : GourdCollectUser # 收藏or取消玩家数据
		}
	}

	# 葫芦藤摘豆
	GourdPickFruit 781 {
		request {
			uId		0 : string 	# 目标id
			id		1 : string 	# 果实位置
			fruitId	2 : string 	# 果实id
		}
		response {
			e_info  				0 : integer
			uId  					1 : string
			data  					2 : UserGourd # 指定位置果实变化
			record  				3 : GourdPickFruitRecord # 对指定玩家的摘取记录，只有摘取别人才返回
			pickFruitFreeCountDay  	4 : integer
			fruitId  				5 : integer # 果实id
			goldNum  				6 : integer # 豆子数量
		}
	}

	# 葫芦藤一键摘豆
	GourdPickFruitQuick 782 {
		request {
			type			0 : integer 	# 0：所有  1：篮子
		}
		response {
			e_info  		0 : integer
		}
	}

	# 葫芦藤附近用户获取
	GourdNearbyUserGet 783 {
		response {
			.GourdNearbyUser {
				id				0 : string		# 
				data			1 : IUserBase	# 基础信息
				onlineState		2 : integer		# 
			}
			e_info  		0 : integer
			arr				1 : *GourdNearbyUser
		}
	}

	# 获取广告数据
	GetUserAdvertDatas 800 {
		request {
			typeArr 	0 : *integer 	# 可选的, 不传则返回所有类型的广告数据
		}
		response {
			datas 		0 : *KeyNumPair(key)
		}
	}

	# 广告开始
	AdvertStart 801 {}

	# 广告完成
	AdvertFinish 802 {
		request {
			type 	0 : integer 			# 指定广告类型
			param 	1 : *KeyValuePair(key)	# 具体有哪些键值根据调用的功能决定
		}
		response {
			e_info  		0 : integer
		}
	}


	# 获取时装数据  直接使用道具，这个废弃了
	#GetUserFashionDatas 810 {
		#	request {
			#		type 		0 : integer 	# 可选的, 不传则返回所有类型的时装数据
			#	}
			#	response {
				#		datas 		0 : *UserFashionTypeData(type)
				#	}
				#}

	# 获取用户现有的各项加成(万分比)
	GetUserBonusObj 820 {
		response {
			rune  		0 : *KeyNumPair(key) # 符文加成，有很多加成，使用 BonusType 枚举取值
			mood  		1 : *KeyNumPair(key) # 心情加成，有很多加成，使用 BonusType 枚举取值
		}
	}

	# 获取订单
	PayOrderGet 900 {
		request {
			storeId 		0 : integer # 商城配置id
			platform 		1 : string	# 平台

			# 以下参数直接复用旧代码
			version      	5  : string
			payToken     	6  : string #应用宝下单参数
			accessToken  	7  : string #应用宝下单参数
			pf           	8  : string #应用宝下单参数
			pfKey        	9  : string #应用宝下单参数

			payType      	12 : string #xyx  下单参数
			cpSid        	13 : string #xyx  下单参数       
		}
		response {
			e_info  		0 : integer
			id  			1 : string  # 订单id
			storeId  		2 : integer # 商城配置id
			price  			3 : integer # 价格（分）
			platform  		4 : string  # 平台
			orderStr  		5 : string  # alipay为下单字符串，其他是json格式参数
			extra_info  	6 : string  # 透传字段
			pay_amount  	7 : integer # 


			result  		10 : integer # 结果 貌似没用了
		}
	}

	# 对应旧版协议 apple_pay_suc2
	# 有些平台需要客户端通知订单完成 如：ios
	PaySucceed 903 {
		request {
			orderId 		0 : string 	# 订单id
			platform 		1 : string	# 平台
			receipt_data 	2 : string	# ios 支付凭证
		}
		response {
			e_info  		0 : integer
		}
	}

	
	# 游戏功能设置数据
	GetGameFuncDatas 920 {
		request {
			idArr 	0 : *integer 	# 可选的, 不传则返回所有数据
		}
		response {
			datas 	0 : *GameFuncData(id)
		}
	}

]]


local s2c = [[

	# 服务器提示 
	ServerMsg 360 {
		request {
			msg 			0 : string
		}
	}

	# 后台跑马灯公告
	AWorldAnnounce 365 {
		request {
			content		0 : string  # 内容
		}
	}

	# 用户跑马灯公告
	AUserAnnounce 366 {
		request {
			sId 		1 : integer 			# announce表格配置id
			dt 			2 : integer 			# 发送时间
			data		3 : *KeyValuePair(key) 	# 对应announce表格content字段的内容
			uId			4 : string				# 用户id，给客户端点击跳转使用的
		}
	}


	# 配牌服设置玩家数据需要(一般不使用这个，GM后台修改数据时同步给前端)
	SyncUserData_GM 600 {
		request {
			data 			0 : UserInfo
		}
	}

	# 同步段位
	SyncUserLv 601 {
		request {
			lv 				0 : integer
			exp 			1 : integer
			lvMax 			2 : integer
			expMax 			3 : integer
			lvSeasonMax 	4 : integer
			expSeasonMax 	5 : integer
		}
	}

	# 段位重置通知
	LvReset_C 602 {
		request {
			oldLv 			0 : integer
			newLv 			1 : integer
			lvRewardRecord	2 : *Hash(key)
			startDt 		3 : integer
			endDt 			4 : integer
			seasonId 		5 : string
		}
	}

	# 同步连胜数据
	SyncUserWinStreak 610 {
		request {
			winStreak 				0 : integer
			winStreakLast 			1 : integer
		}
	}

	# 同步玩家对局相关数据
	SyncUserRoomGame 611 {
		request {
			gameCountSum 			0 : integer
			winCountSum 			1 : integer
			winCountSum_20 			2 : integer
		}
	}

	# 同步道具数据
	SyncUserItem 625 {
		request {
			datas 0 : *UserItem(id)
		}
	}

	# 新邮件提示
	MailTip 630 {}

	# 同步任务数据
	SyncUserTask 650 {
		request {
			datas 0 : *UserTask(id)	# 任务完成时会主动推
		}
	}

	# 重置任务
	ResetUserTask 651 {
		request {
			dateType	0 : integer # 重置指定任务时间类型的数据
		}
	}

	# 同步英雄数据
	SyncUserHero 670 {
		request {
			data 		0 : UserHero
			syncType 	1 : integer  # 0:增加新角色， 1：更新已有角色数据
		}
	}

	# 同步userinfo上与英雄相关的数据
	SyncUser_Hero 671 {
		request {
			skin  		1 : integer
			heroId  	2 : string
		}
	}


	# 同步好友数据
	SyncUserFriend 710 {
		request {
			data 0 : UserFriend
		}
	}

	# 同步商城数据
	SyncUserStore 740 {
		request {
			data 		0 : UserStore
			dateType 	1 : integer		# 该值不为nil且 > 0	时，该限购类型的数据全部删除 或者 重新拉取商城数据
			showType 	2 : integer		# 该值不为nil且 > 0	时，该显示类型数据发生更新，需要重新拉取商城数据
		}
	}

	# 葫芦藤邀请好友助产
	GourdFriendHelpApply_C 777 {
		request {
			data 	0 : IUserBase	# 邀请者基础信息
		}
	}

	# 葫芦藤接受好友助产
	GourdFriendHelp_C 778 {
		request {
			data 	0 : GourdFriendHelp	# 接受邀请信息
		}
	}

	# 葫芦藤动态更新
	GourdActionRecord_C 779 {
		request {
			data 	0 : GourdActionRecordInfo
		}
	}

	# 同步广告数据
	SyncUserAdvertData 800 {
		request {
			data 	0 : KeyNumPair(key)	# 邀请者基础信息
		}
	}
    
	#同步vip信息
	SyncUserVipData 801 {
		request {
			vipinfo 0 : VipInfo #vip信息
		}
	}

	# 葫芦藤定点奖励
	SyncGourdFixedTimeReward 802 {
		request {
			fixedTimeReward  	0 : *integer # 更新葫芦藤数据
		}
	}

	SyncFriendGiftAndNewApply 803 {
		request {
			HasNewFriend  	0 : boolean # 是否有新朋友申请,true有
			HasFriendGift  	1 : boolean # 是否有朋友送礼,true有
		}
	}

	# 对应旧版协议 apple_pay_suc
	# 通知客户端支付完成
	PayFinish 900 {
		request {
			e_info			0 : integer  # 新支付结果 1：成功 对应旧版的 apple_pay_suc 推送  3：错误 对应旧版的 apple_pay_err
			result			1 : integer  # 支付结果  # 旧版的 result 返回值
			orderId  		2 : string 	 # 订单id
			platform 		3 : string	 # 平台
			transaction_id  6 : string 	 # ios 用的一个啥东西
			sign  			7 : string 	 # ios 用的一个啥东西
		}
	}

	# 同步时装数据
	#SyncUserFashion 810 {
	#	request {
			#		data 	0 : UserFashion
			#	}
			#}

	# 同步游戏功能设置配置数据
	SyncGameFuncData 920 {
		request {
			datas 0 : *GameFuncData(id)
		}
	}

]]




return {
	struct = struct,
	c2s = c2s,
	s2c = s2c
}
