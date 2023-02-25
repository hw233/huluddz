local struct = [[

]]


-----------------------------------------
local c2s = [[

###########################################
# 设置功能
GetSettingInfo 4000 {
    response {
        e_info    0: integer   # 1:成功
        item      1: *boolean  # 音乐, 音效, 震动, 音效2, 智能选牌, 消息推送, 位置显示
        logintype 2: integer   # 登录方式： 1微信
        realname  3: boolean   # 实名认证
    }
}
    

SetSettingInfo 4001 {
    request {
        item 0: *boolean  # 音乐, 音效, 震动, 音效2, 智能选牌, 消息推送, 位置显示
    }
    response {
        e_info 0 : integer # 1:成功 
    }
}   
    
############################################
# 碎片商店 
PieceShop_GetInfo 4005 {

    response {
        .TakeInfo_t {
            heroid   0: string   
            takelist 1: *integer   # 已领取的id
        }
        e_info     0 : integer          # 1:成功 
        takeinfo   1 : *TakeInfo_t      # 碎片领取信息
    }
}


# 领取碎片
PieceShop_TakePiece 4006 {
    request {
        heroid  0: string    
        awardid 1: integer   # 奖励id
    }
    response {
        e_info 0: integer # 1:成功 
        msg    1: string  # 错误msg
    }
}


# 购买物品
PieceShop_BuyGoods 4007 {
    request {
        goodsid 0: integer   # 商品id
    }
    response {
        e_info 0: integer # 1:成功,10:不能重复获得 11:碎片不够
        msg    1: string  # 错误msg
    }
}

#############################################
# 签到系统
SignIn_GetInfo 4015 {

    response {
        e_info      0: integer          # 1:成功 
        patchcount  1: integer          # 补签次数
        video3count 2: integer          # 视频3倍签到次数
        signlog     3: *integer         # 签到记录
        progressawardtakelog  4: *integer   #进度奖领取记录
    }
}


# 签到
SignIn_Sign 4016 {
    request {
        ispatch   0: boolean    # 是否为补签
        isvideo3  1: boolean    # 是否为视频3倍签到
        patchday  2: integer    # 补签几号
    }

    response {
        e_info   0: integer # 1:成功 
        msg      1: string  # 错误msg
        signday  2: integer # 
        isvideo3 3: boolean
    }
}


# 领取进度奖励
SignIn_TakeProgressAward 4017 {
    request {
        awardid 0: integer   # 奖励id
    }
    response {
        e_info  0: integer # 1:成功 
        msg     1: string  # 错误msg
        awardid 2: integer   # 奖励id
    }
}


#############################################
#ma_userheroget

GetUserHeroDatasExt  4030 {
    response {
        e_info  0: integer # 1:成功 
        datas   1: *UserHeroDataExt(id)
    }   
}

#for test
Test_AddExpBook 4031 {
    request {
        heroid 0: string
        num    1: integer
    }
    response {
        e_info  0: integer # 1:成功 
        datas   1: *UserHeroDataExt(id)
    }
}

##############################################
#Friend
Friend_SetNotAcceptFriendApply 4035 {
    request {
        notaccept  0: boolean    #不接受好友申请
    }

    response {
        e_info       0: integer # 1:成功 
        notaccept    1: boolean
    }    
}

# 获取黑名单
Friend_GetBlackList 4036 {
    response {
		datas 0 : *UserFriendBlack(blackuid)
	}
}


# 加入黑名单
Friend_AddBlackList 4037 {
    request {
        blackuid     0: string    #目标uid
    }

    response {
        e_info       0: integer # 1:成功 
        msg          1: string 
        newblack     2: UserFriendBlack
    }   
}


# 从黑名单移除
Friend_RemoveBlackList 4038 {
    request {
        blackuid      0: string    # 目标uid
        friendapply   1: boolean   # 好友申请
    }

    response {
        e_info       0: integer     # 1:成功 
        msg          1: string
        blackuid     2: string 
        friendapply  3: boolean   # 好友申请
    }   
}


# 开启手机定位
Friend_OpenPhoneLocation 4039 {
    request {
        open   0: boolean   #是否开启
        sex    1: integer   #0:男女， 1：男，2：女
    }

    response {
        e_info       0: integer     # 1:成功 
        msg          1: string
        open         2: boolean
        sex          3: integer
    }   
}


#获取同城附近玩家
Friend_GetNearbyPlayers 4040 {

    response {
        e_info       0: integer     # 1:成功 
        msg          1: string
        datas        2: *UserFriendNearby
    }   
}

# 获取向我申请好友的数据
Friend_GetApplyToMeDatas 4041 {
	response {
		datas 0 : *UserFriendApply(uId)
	}
}

# 好友系统相关设置    
Friend_GetSettingInfo  4042 {
    
    response {
        e_info            0: integer      # 1:成功 
        auto_gift         1: boolean      # 自动答谢
        location_open     2: boolean      # 定位是否开启
        location_sex      3: integer      # 0:男女， 1：男，2：女
        not_accept_apply  4: boolean      # 不接受好友申请
    }   
}

# 自动答谢
Friend_SetAutoGift   4043 {
    request {
        auto  0: boolean    #自动答谢
    }

    response {
        e_info       0: integer # 1:成功 
        auto         1: boolean
    }   
}



########################################
#Vip
Vip_GetInfo 4060 {
    response {
        e_info       0: integer     # 1:成功 
        vipexp       1: integer     # vip经验
        viplv_xl     2: integer     # 虚拟vip等级
        istaked      3: boolean     # true:已领取，false:未领取
        buycount     4: *integer    # vip商店购买次数记录
    }   
}

# for test
TestVip_AddExp  4061 {
    request {
        val          0: integer    
    }

    response {
        e_info       0: integer     # 1:成功 
        msg          1: string
        vipexp       2: integer   
        viplv        3: integer
    }      
}

# vip每日奖励
Vip_GetDayAward 4062 {
    response {
        e_info       0: integer     # 1:成功,2已领过 
    }   
}

#vip商店购买, 测试接口
TestVip_BuyItem  4063 {
    request {
        id          0: integer  # 商品id  
    }
}

#########################################
#其他玩家信息获取
GetOtherUserInfo  4070 {
    request {
        uid          0: string    
    }
    response {
        e_info      0: integer          # 1:成功 
        uinfo       1: UserInfo         # 玩家信息
        heroDatas   2 : *UserHero(id)   # 机器人的角色数据会一起发送
        runeDatas 	3 : *UserRune(id)   # 机器人的符文数据会一起发送
    }   
}


#########################################
# 发通知  测试接口  4075 -- 4080
Test_Notice  4075 {
    request {
        msg          0: string    
        players      1: *string  # 玩家id
    }

    response {
        e_info       0: integer     # 1:成功 
    }    
}

#########################################
# 排行榜

# 测试接口 更新人气
Test_RankList_UpdateRQ  4081 {
    response {
        e_info       0: integer     # 1:成功 
    }   
}

GetRankList 4082 {
    request {
        name       0: string   # 排行榜名: 人气:rq, 点赞:dz, 段位:dw, 成就:cj, 葫芦藤:hlt
        type       1: integer  # 1总榜，2月榜，3好友
        startidx   2: integer  
        num        3: integer
    }

    response {

        .RankInfo {
            rank       0: integer    # 排名
            uid        1: string     # user id
            nickname   2: string     
            head       3: string
            headframe  4: string
            val        5: integer    # 人气值，点赞数，段位值，成就点数，葫芦藤成长值
            lv         6: integer    # 段位等级lv
            valueEx    7: string     # 对应值根据名称决定（成就:cj， 对应title）
        }
        e_info       0: integer   # 1:成功
        name         1: string    # 排行榜名
        type         2: integer   # 1总榜，2月榜，3好友
        startidx     3: integer

        ranklist     5: *RankInfo
        myrankinfo   6: RankInfo
        rklist_maxnum 7: integer    # ranklist 当前榜单最大数量
    }   
}





#########################################



]]


-------------------------------------------
local s2c = [[
    # 签到
    SyncSignIn_Sign 4077 {
        request {
            msg      1: string  # 错误msg
            signday  2: integer # 
            isvideo3 3: boolean
        }
    }
]]



-----------------------------------------------
return {
    c2s = c2s,
    s2c = s2c
}