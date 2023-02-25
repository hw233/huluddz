local skynet = require "skynet"
local ma_data = require "ma_data"
local GLOBAL = require "cfg/cfg_global"
local cfg_items = require "cfg/cfg_items"

local tmp_clothes ={}  -- 一键领取临时存放装扮
local request = {}
local cmd = {}

local M = {}

local function friend_give_gold_add(mail)
	skynet.call("friend_mgr", "lua", "friend_give_gold_add",mail,ma_data.give_coin_info)
	local give_coin_data = skynet.call("friend_mgr", "lua", "get_give_coin_info", ma_data.db_info.id)
	ma_data.give_coin_info = give_coin_data
end

-- 判断玩家是否已经到达接收嘻嘻币上限
local function is_friend_give_full(coin_get_num)
    if coin_get_num >= GLOBAL[1].coin_get_num then
        return true
    end
    return false
end

-- 判断邮件是否是好友赠送嘻嘻币类型的邮件
local function mail_type(mail,mail_type,mail_stype)
    -- print("邮件类型")
    -- print(mail.mail_type)
    -- print(mail.mail_stype)

	if (mail.mail_type and mail.mail_type == mail_type) and (mail.mail_stype == mail_stype) then
        return true
    else
        return false
	end
end

local function disassemble_clothes(id)
	--print("你已经有了这个时装，分解为服装币")
	local coinlist = {cfg_items[id].clothes_coin}
	if coinlist then
		return coinlist
	end
	return {}
end

-- 0 不是嘻嘻币邮件  1 是嘻嘻不邮件玩家接收已满 2 是嘻嘻币邮件玩家接收不满
local function can_receive_mail(mail)
	-- local ret = skynet.call("friend_mgr", "lua", "can_receive_mail",mail,ma_data.give_coin_info)

	local give_coin_info = ma_data.give_coin_info
    -- 在检测前先检测是否需要重置
	-- print("检测邮件是否接收")
 --    table.print(give_coin_info)
    
    if mail_type(mail,MAIL_TYPE_FRIEND,MAIL_STYPE_F_GOLD) then
		--print("是嘻嘻币赠送邮件")
		-- 加载最新的give_coin_info
		skynet.call("friend_mgr", "lua", "time_reset",give_coin_info.last_reset_time,mail.receiver)
		if give_coin_info.coin_get_num >= GLOBAL[1].coin_get_num then
        --当天已领取满
            --print("玩家接收已满")
			return 1
        end
		return 2
	end
	if mail_type(mail,MAIL_TYPE_FRIEND,MAIL_STYPE_F_DRESS) then
		--print("是好友装扮赠送邮件")
		--print(mail.attachment[1].id)
		local id = mail.attachment[1].id
		local ret = ma_data.get_goods_num(id)
		if ret ~= 0 or tmp_clothes[id] then
			--print("你已经有了这个时装，分解为服装币")
			return 3
		else
			tmp_clothes[id] = true
			return 0
		end
	elseif mail.mail_stype == MAIL_TYPE_BANK then
		return 5
	end
	return 0
end


local function del_rahter_mail(count)
	local match_tbl = {receiver = ma_data.my_id}
	local sort_tbl = {create_time = -1}
	local skip = count
	local mails = skynet.call(get_db_mgr(), "lua", "find_all_skip", COLL.MAIL, match_tbl, nil, sort_tbl, skip)
	if #mails > 0 then
		local ts = mails[1].create_time
		skynet.call(get_db_mgr(), "lua", "delete", COLL.MAIL, {create_time = {["$lte"] = ts}, receiver = ma_data.my_id})
	end
	table.print("del_rahter_mail mails =>", mails)
end

local max_mail_count = 60
local function get_mails()
	-- 删除超过数量的邮件
	del_rahter_mail(max_mail_count)
	-- 如果没有奖励就默认领取
	local mails = skynet.call(get_db_mgr(), "lua", "find_all", COLL.MAIL,
		{receiver = ma_data.my_id}, nil, {create_time = -1}, max_mail_count
	) or {}
	print("mails count=", #mails)
	for _,v in pairs(mails) do
		if not v.attachment then
			v.received = true
			skynet.call(get_db_mgr(), "lua", "update", COLL.MAIL, {id = v.id}, {received = true})
		end
	end
	return mails
end

function request:mails()
	
	-- local mails = skynet.call(get_db_mgr(), "lua", "find_all", COLL.MAIL, {receiver = ma_data.my_id}, nil, {{create_time = -1}}, 12) or {}
	-- return {mails = mails}
	return {mails = get_mails()}
end


function request:read_mail()
	assert(self.mail_id)
	--print("read_mail")
	local mail = skynet.call(get_db_mgr(), "lua", "find_one", COLL.MAIL, {id = self.mail_id, receiver = ma_data.my_id})
	if not mail then
		return {result = 1}
	end
	--print(self.mail_id)
	skynet.call(get_db_mgr(), "lua", "update", COLL.MAIL, {id = self.mail_id}, {have_read = true})

	return {result = 0, mail_id = self.mail_id}
end


function request:receive_mail()
	assert(self.mail_id)
	tmp_clothes = {}
	local mail = skynet.call(get_db_mgr(), "lua", "find_one", COLL.MAIL, {id = self.mail_id, receiver = ma_data.my_id})
	if not mail or not mail.attachment or mail.received then
		return {result = 1}
	end
	local type_num = can_receive_mail(mail)

    if 1 == type_num then
    	return {result = 2 ,coin_get_max = GLOBAL[1].coin_get_num}
	elseif 0 == type_num then
		local attachment = mail.attachment

		ma_data.add_goods_list(attachment,GOODS_WAY_MAIL, "邮件领取")
		ma_data.send_push("buy_suc", {
			goods_list = attachment,
			msgbox = 1
		})
	
		skynet.call(get_db_mgr(), "lua", "update", COLL.MAIL, {id = self.mail_id}, {received = true, receive_time = os.time()})
	elseif 2 == type_num then
		local attachment = mail.attachment

		ma_data.add_goods_list(attachment,GOODS_WAY_MAIL, "邮件领取")
		ma_data.send_push("buy_suc", {
			goods_list = attachment,
			msgbox = 1
		})
	
		--skynet.call(get_db_mgr(), "lua", "update", COLL.MAIL, {id = self.mail_id}, {received = true, receive_time = os.time()})
		friend_give_gold_add(mail)
		skynet.send(get_db_mgr(), "lua", "delete", "mail", {id = self.mail_id})
	elseif 3 == type_num then
		local attachment = disassemble_clothes(mail.attachment[1].id)
		table.print(attachment)
		ma_data.add_goods_list(attachment,GOODS_WAY_MAIL, "邮件时装分解领取")
		ma_data.send_push("buy_suc", {
			goods_list = attachment,
			msgbox = 1
		})
		ma_data.send_push("disassemble_clothes",{disassembles = {{itemid = mail.attachment[1].id,coin =attachment[1].num}}})
		-- skynet.send("agent_mgr", "lua", "send2player", ma_data.my_id, "send_push", "disassemble_clothes",{disassembles = {{itemid = mail.attachment[1].id,coin =attachment[1].num}}})
		skynet.call(get_db_mgr(), "lua", "update", COLL.MAIL, {id = self.mail_id}, {received = true, receive_time = os.time()})
	elseif 5 == type_num then
		local mall_id = cfg_items[mail.attachment[1].id].mall_id
		ma_data.ma_hall_bank.get_bank_update(mall_id)
		skynet.call(get_db_mgr(), "lua", "update", COLL.MAIL, {id = self.mail_id}, {received = true, receive_time = os.time()})
	else
	end
	ma_data.send_push("mail_sync")
	return {result = 0, mail_id = self.mail_id}
end

function request:receive_all_mail()
	tmp_clothes = {}

	local function find_in_a1(a1, id)
		for i,v in ipairs(a1) do
			if v.id == id then
				return v
			end
		end
	end

	local function connect_attachment(a1, a2)
		for i,v in ipairs(a2) do
			local goods = find_in_a1(a1, v.id)
			if goods then
				goods.num = goods.num + v.num
			else
				table.insert(a1, v)
			end
		end
	end
	local ret_mails = {}
	local mails = get_mails()
	--skynet.call(get_db_mgr(), "lua", "find_all", COLL.MAIL, {receiver = ma_data.my_id, received = false})

	if #mails == 0 then
		return {result = 1}
	else
		local attachment = {}
		local disassemble_clothes_list = {}
		for _,mail in ipairs(mails) do
			local flag = ((self.type <= MAIL_TYPE_FRIEND) and (mail.mail_type and mail.mail_type <= MAIL_TYPE_FRIEND)) or (self.type > MAIL_TYPE_FRIEND and (mail.mail_type and mail.mail_type > MAIL_TYPE_FRIEND))
			if flag then
				table.insert(ret_mails, mail)
				if mail.attachment and (not mail.received) then
					local type_num = can_receive_mail(mail)
					if (0 == type_num) and mail.attachment and (not mail.received) then
						connect_attachment(attachment, mail.attachment)
						mail.received = true
						mail.have_read = true
						skynet.call(get_db_mgr(), "lua", "update", COLL.MAIL, {id = mail.id}, {received = true, have_read = true})
					end
					if 2 == type_num then
						friend_give_gold_add(mail)
						connect_attachment(attachment, mail.attachment)
						mail.received = true
						mail.have_read = true
						skynet.call(get_db_mgr(), "lua", "update", COLL.MAIL, {id = mail.id}, {received = true, have_read = true})
						skynet.send(get_db_mgr(), "lua", "delete", "mail", {id = mail.id})
					end  
					if 3 == type_num then
						local tmp_attachment = disassemble_clothes(mail.attachment[1].id)
						connect_attachment(attachment, tmp_attachment)
						mail.received = true
						mail.have_read = true
						skynet.call(get_db_mgr(), "lua", "update", COLL.MAIL, {id = mail.id}, {received = true, have_read = true})
						table.insert(disassemble_clothes_list,{itemid = mail.attachment[1].id,coin =mail.attachment[1].num})
					end
				end		
			end
		end
		if #attachment >= 1 then
			ma_data.add_goods_list(attachment, GOODS_WAY_MAIL, "邮件奖励")
			ma_data.send_push("buy_suc", {
				goods_list = attachment,
				msgbox = 1
			})
		end
		if #disassemble_clothes_list >=1 then
			ma_data.send_push("disassemble_clothes",{disassembles = disassemble_clothes_list})
			-- skynet.send("agent_mgr", "lua", "send2player", ma_data.my_id, "send_push", "disassemble_clothes",{disassembles = disassemble_clothes_list})
		end
		ma_data.send_push("mail_sync")
		return {result = 0, type = self.type, mails = ret_mails}
	end
end

function request:deletemail()
	-- request.receive_mail(self)
	skynet.send(get_db_mgr(), "lua", "delete", "mail", {id = self.mailid})
	return {result = 0, mailid = self.mailid}
end

function request:delete_all_mail()
	-- request.receive_all_mail()
	-- skynet.send(get_db_mgr(), "lua", "delete", "mail", {receiver = ma_data.my_id})
	local mails = get_mails()
	--skynet.call(get_db_mgr(), "lua", "find_all", COLL.MAIL, {receiver = ma_data.my_id, received = false})
	for _,mail in ipairs(mails) do
		local isDelete = false
		if ((self.type <= MAIL_TYPE_FRIEND) and (mail.mail_type and mail.mail_type <= MAIL_TYPE_FRIEND)) or 
			(self.type > MAIL_TYPE_FRIEND and 
			(mail.mail_type and mail.mail_type > MAIL_TYPE_FRIEND)) then
			if not mail.attachment or mail.received then
				skynet.send(get_db_mgr(), "lua", "delete", "mail", {id = mail.id})
			end
			
		end
		
	end
	return {result = 0, type = self.type, mails = get_mails()}
end

function request:send_gold()
	skynet.call(get_db_mgr(), "lua", "insert", "subscribe_gift", {pid = u.id, time = os.time()})
	local mail =  {
            title = "好友赠送",
            content = "!!!!!!!!!!!!!",
            attachment = {{id = 100001, num = 20000}},
            mail_type = 1,
            mail_stype = 1,
            friend_name = ma_data.db_info.nickname,
            friend_head = ma_data.db_info.headimgurl
        }
    skynet.call("mail_mgr", "lua", "send_mail", self.id, mail)
end



function M.init(REQUEST, CMD)
    if request then
        table.connect(REQUEST, request)
    end
    if cmd then
        table.connect(CMD, cmd)
    end
end
ma_data.ma_hall_mail = M
return M