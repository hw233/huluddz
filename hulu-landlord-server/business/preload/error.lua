local errors = {}

function errmsg(ec)
	if not ec then
		return "nil"
	end
	return errors[ec].desc
end

local function add(err)
	assert(errors[err.code] == nil, string.format("have the same error code[%x], msg[%s]", err.code, err.desc))
	errors[err.code] = {code = err.code, desc = err.desc}
	return err.code
end


GAME_ERROR = {
	has_sign 			= add{code = 769, desc = "今天已经签到了"}, -- 0x0301
	matching_or_inroom  = add{code = 770, desc = "已经在匹配或已加入房间"},
	over_room_limit 	= add{code = 771, desc = "金币不足或超过限制"},
	already_ready 		= add{code = 772, desc = "你已经在准备中"},
	not_in_matching 	= add{code = 773, desc = "不在匹配状态中"},
	already_showcards 	= add{code = 774, desc = "你已经明牌了"},
	already_double 		= add{code = 775, desc = "你已经加倍了"},
	must_playcard  		= add{code = 776, desc = "必须出牌"},
	cardtype_invalid	= add{code = 777, desc = "牌型非法"},
	card_too_small 		= add{code = 778, desc = "你的牌太小"},
	room_no_in_playing  = add{code = 785, desc = "房间不在出牌状态中"},-- 0x0311
	vip_need_bigger  	= add{code = 786, desc = "VIP必须大于对方才能操作"},
	not_use_room_type  	= add{code = 787, desc = "房间类型未开放"},
}



return errors