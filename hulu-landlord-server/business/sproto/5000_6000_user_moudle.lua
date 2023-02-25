local struct = [[
    .LuckyData {
        systemfreenum   0 : integer #今天系统免费赠送剩余次数
        advfreenumlimit 1 : integer #今天看广告免费赠送剩余次数
        advfreenum      2 : integer #今天以看广告方式抽取次数
        todaytakenum    3 : integer #今天总抽取次数
    }
    
    .LuckyInfomation {
        lucky1          0 : LuckyData #1连抽数据
        lucky10         1 : LuckyData #10连抽数据
        luckvalue       2 : integer #当前幸运值
        nextrefreshtime 3 : integer #下次更新时间
        advnum          4 : integer #当前看广告的次数
        advcontdaynum   5 : integer #连续看广告的累计天数，每天看5次或以上才记录
    }

    .itemsnum {
        id 0 : integer
        num 1 : integer    
    }

    .rewardboxitem {
        type_id 0 : integer #宝箱type_id
        items    1 : *itemsnum #物品列表
    }

    .VisitorData {
        newsign   0:integer #是否是新客访问
        lastat    1:integer #最后访问时间
        basedata  2:IUserBase # 基础数据 
    }

    .Sign14Data {
        status 0:integer #0不可领奖 1可领奖  2可钻石领奖 3已领奖
    }

    .AchData {
        id  0 : string #成就id
        val 1 : integer #成就值
    }

    .AchTitleData {
        id  1 : string #成就id
        status 2 : integer # Unknown = 0 未拥有, Own = 5, --已拥有, Using = 10, --使用中
        expAt  3 : integer #过期时间
    }    
    
    .AchPData {
        hisDoubleMax    0 : integer #历史最大加倍数
        hisConWinMax    1 : integer #最大连胜次数
        hisClearPlayer  2 : integer #清空对手次数
        hisSpringNum    3 : integer #春天次数
    } 

    .TxzRewardData {
        lv     0 : integer #当前等级
        status 1 : integer #1 普通奖励已领取，2付费奖励已领取，3 普通奖励和付费奖励都已领取
    }

    .TxzData {
       lv       0 : integer #当前等级
       exp      1 : integer #当前经验
       lvRewardList 2 : *TxzRewardData
    }
]]

local c2s = [[
    GetTakeLuckBaoxiang 5000 {
        request {            
        }
        response {
            e_info  		0 : integer
            luckinfo        1 : LuckyInfomation #抽奖信息
        }
    }

    TakeLuckBaoxiang 5001 {
        request {
            lucktype  0 : integer
        }
        response {
            e_info  		0 : integer
            luckinfo        1 : LuckyInfomation  #抽奖信息
            rewardboxitems  2 : *rewardboxitem  #抽奖奖励信息
        }
    }

    TakeLuckBaoxiangTest 5010 {
        request {
            type  0 : integer
        }
        response {
            e_info  		0 : integer
        }
        
    }

    GetVisitor 5002 {
        request {
            startindex  0 : integer
            num 1 : integer
        }
        response {
            e_info  		0 : integer
            visitorlist     1 : *VisitorData #访客列表
            allvisitornum   2 : integer #总访客数
            todayvisitornum 3 : integer #今日访客数
        }
    }

    UpdateVisitor 5003 {
        request {
            id  0 : integer
        }
        response {
            e_info  0 : integer
        }
    }

    SetVisitorNewSign 5004 {
        request {
        }
        response {
            e_info  0 : integer
        }
    }

    GetSign14 5005 {
        request {
        }
        response {
            e_info       0 : integer
            signdatalist 1 : *Sign14Data
            currentindex 2 : integer #当天签到第几天
        }
    }

    RewardSign14 5006 {
        request {
            signtype 0 : integer #0正常领奖，1 钻石领奖
            index    1 : integer
        }
        response {
            e_info       0 : integer
            signdata     1 : Sign14Data
            index        2 : integer
            currentindex 3 : integer #当天签到第几天
        }
    }

    Authentication 5007 {
        request {
            AuthenticationType 0 : integer #证件类型，1 身份证
            Id                 1 : string #证件id
            Name               2 : string #证件名字
        }

        response {
            e_info       0 : integer
        }
    }

    ShareReward 5008 {
        request {
            point 0 : integer #分享点id
        }

        response {
            e_info          0 : integer
            rewardboxitems  1 : *rewardboxitem  #奖励信息
        }
    }

    
    GetAchievent 5009 {
        request {
        }

        response {
            e_info            0 :  integer
            AchDataList       1 : *AchData
            AchiTitleDataList 2 : *AchTitleData
            AchPlayerData     3 : AchPData
        }
    }

    UseAchieventTitle 5011 {
        request {
            UpOrDown 0 :integer #佩戴，1卸下
            titleId  1 :string
            taskId   2 :string
        }

        response {
            e_info            0 :  integer
            AchDataList       1 : *AchData
            AchiTitleDataList 2 : *AchTitleData
            titleId           3 :  string
            #AchPlayerData    4 : AchPData
        }
    }
    
    UserCDKReward 5020 {
        request {
            cdkId 0 : string
        }
        response {
            e_info          0 : integer
            rewardboxitems  1 : *rewardboxitem  #奖励信息
        }
    }

    GetTxzData 5030 {
        request {
        }
        response {
            e_info          0 : integer
            txzData         1 : TxzData #通行证数据
        }
    }

    TxzBuyLvByDiamond 5031 {
        request {
            lv   0 : integer
        }
        response {
            e_info          0 : integer
            txzData         1 : TxzData #通行证数据
        }
    }

    TxzReward 5032 {
        request {
            lv   0 : integer #领取奖励对应的等级，0是一键领取
            type 1 : integer #领取类型，1 普通领取，2钻石领取
        }
        response {
            e_info          0 : integer
            txzData         1 : TxzData #通行证数据
        }
    }

	SetCardBg 5050 {
		request {
			cardBgItemId 	0 : integer # 道具id
		}
		response {
			e_info 		0 : integer # 1:成功 3:参数错误
			cardBg 	1 : integer
		}
	}

    SetSceneBg 5051 {
		request {
			sceneBgItemId 	0 : integer # 道具id
		}
		response {
			e_info 		0 : integer # 1:成功 3:参数错误
			sceneBg 	1 : integer
		}
	}

    SetTableClothBg 5052 {
		request {
			tableClothBgItemId 	0 : integer # 道具id
		}
		response {
			e_info 		 0 : integer # 1:成功 3:参数错误
			tableClothBg 1 : integer
		}
	}

    GetSign7 5040 {
        request {
        }
        response {
            e_info       0 : integer
            signdatalist 1 : *Sign14Data
            currentindex 2 : integer #当天签到第几天
        }
    }
    
    RewardSign7 5041 {
        request {
            signtype 0 : integer #0正常领奖，1 钻石领奖
            index    1 : integer
        }
        response {
            e_info       0 : integer
            signdata     1 : Sign14Data
            index        2 : integer
            currentindex 3 : integer #当天签到第几天
        }
    }

]]


local s2c = [[
    PushTakeLuckBaoxiang 6500 {
        request {
            luckinfo  0 : LuckyInfomation #抽奖信息
        }
    }

    SyncAchievent 6501 { 
        request {
            AchDataList       1 : *AchData
            AchiTitleDataList 2 : *AchTitleData
        }
    }

    SyncTxzUpLv 6502 { 
        request {
            txzData   0 : TxzData #通行证数据
            oldLv     1 : integer #升级之前等级
        }
    } 

    SyncTxzGoldId 6503 { 
        request {
            goldId   0 : integer #金卡id
        }
    }

]]

return {
	struct = struct,
	c2s = c2s,
	s2c = s2c
}
