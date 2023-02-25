--
-- channel data collecter
--
local skynet = require "skynet"
local timer = require "timer"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
local timer = require "timer"
local NODE_NAME = skynet.getenv "node_name"
local COLL = require "config/collections"
local GLOBAL = require "cfg/cfg_global"
local cfg_items = require "cfg.cfg_items"
local player_info = {}
local can_apply_list = {} --12个
local can_ids = {}
local give_coin_info_list = {} -- 赠送信息，包括赠送了哪些好友和赠送接收次数n
local online_player_list = {}



function CMD.inject(filePath)
    require(filePath)
end

function CMD.online(id)
    --print("玩家在线",id)
    online_player_list[id] = true
end

function CMD.player_logout(id)
    --print("玩家离线",id)
    online_player_list[id] = false
    -- 记录玩家离线时间
    if player_info[id] then
        player_info[id].last_time = os.time()
    end
    
end

-- 获取一个玩家的最近离线时间
function CMD.get_player_logout_time(id)
    local time = player_info[id] and player_info[id].last_time or nil

    -- 如果服务重启player_info中没有数据，就从数据库中查找数据
    if not time then
        --print("本地服务中没有数据")
        local data = skynet.call(get_db_mgr(), "lua", "find_one",COLL.USER,{id = id},{_id=false,nickname=true,headimgurl=true,sex=true,last_time=true})
        time = data.last_time
        player_info[id] = {id = id, nickname = data.nickname, headimgurl = data.headimgurl, sex = data.sex,last_time = time}
    end
    --print("返回好友上次离线时间",id,time)
    return time
end

function CMD.get_online_player()
    return online_player_list
end

--随机替换一个
local function rnd_replace(item)
    if can_ids[item.id] then
        --玩家已在列表中
        return 
    end
    if #can_apply_list >= 60 then
        local tmpIndex = math.random(#can_apply_list)
        local tmpItem = can_apply_list[tmpIndex]
        can_ids[tmpItem.id] = false
        table.remove(can_apply_list, tmpIndex)
        table.insert(can_apply_list, item)
    else
        table.insert(can_apply_list, item) 
    end
    can_ids[item.id] = true
end

--随机获取可以添加的好友列表
function CMD.get_can_apply_fri_list()
    return can_apply_list
end

-- 测试用方法
function CMD.test()
    return player_info
end

function CMD.player_exit(id)
    if player_info[id] then
        player_info[id] = nil
        -- table.remove(player_info_table, index)
    end
end

-- 判断玩家是否开启拒绝添加好友，开启则不把玩家加入玩家池，如果已经加入则把玩家从池中删除
function CMD.player_refuse_friend(id, nickname, headimgurl, sex,headframe, refuse_friend)
    if refuse_friend then
        CMD.player_exit(id)
    else
        CMD.player_login(id, nickname, headimgurl, sex,headframe, refuse_friend)
    end
end


-- 判断玩家是否已经到达接收嘻嘻币上限
local function is_friend_give_full(coin_get_num)
    if coin_get_num >= GLOBAL[1].coin_get_num then
        return true
    end
    return false
end

-- 判断邮件是否是好友赠送嘻嘻币类型的邮件
local function is_friend_give_gold_mail(mail)
	if (mail.mail_type and mail.mail_type == MAIL_TYPE_FRIEND) and (mail.mail_stype == MAIL_STYPE_F_GOLD) then
        return true
    else
        return false
	end
end

-- 给邮件功能调用，用来处理好友类型和赠送嘻嘻币类型的邮件
function CMD.friend_give_gold_add(mail,give_coin_info)
    if give_coin_info.coin_get_num < GLOBAL[1].coin_get_num then
        local info ={give_coin_info = {coin_get_num = give_coin_info.coin_get_num+1,
                                        coin_give_num = give_coin_info.coin_give_num,
                                        give_friends = give_coin_info.give_friends,
                                        last_reset_time = give_coin_info.last_reset_time},
                    id = mail.receiver}
		CMD.set_give_coin_info(info)
	end
end

-- 给邮件功能调用，用来检测好友赠送嘻嘻币类型的邮件是否接收
-- 0 不是嘻嘻币邮件  1 是嘻嘻不邮件玩家接收已满 2 是嘻嘻币邮件玩家接收不满
function CMD.can_receive_mail(mail,give_coin_info)
    -- 在检测前先检测是否需要重置
    CMD.time_reset(give_coin_info.last_reset_time,mail.receiver)
    
    if is_friend_give_gold_mail(mail) then
		if give_coin_info.coin_get_num >= GLOBAL[1].coin_get_num then
        --当天已领取满
			return 1
        end
        return 2
	end
	return 0
end

-- 获取对应id玩家的赠送嘻嘻币的相关信息
function CMD.get_give_coin_info(id)
    return give_coin_info_list[id]
end

-- 设置赠送嘻嘻币的相关信息
function CMD.set_give_coin_info(info)
    local new_give_coin_info = {coin_get_num = info.give_coin_info.coin_get_num,
                                coin_give_num = info.give_coin_info.coin_give_num,
                                give_friends = info.give_coin_info.give_friends,
                                last_reset_time = info.give_coin_info.last_reset_time}
    local id = info.id
    give_coin_info_list[id] = new_give_coin_info
    skynet.call(get_db_mgr(),"lua","update",COLL.USER,{id=id},{["give_coin_info"] = new_give_coin_info})
end

-- 根据时间判断是否进行重置
function CMD.time_reset(last_reset_time,id)
    -- 设置重置的时间
    local reset_hour=00
    local reset_min=00
    local reset_sec=00
    -- 获得当天重置时间的时间戳
    local date = os.date("*t",  os.time())
	local reset_time = os.time({year =date.year, month = date.month, day =date.day, hour =reset_hour, min =reset_min, sec = reset_sec})
    -- 上次重置时间小于当天0点则重置
    if last_reset_time  and (last_reset_time < reset_time) and (os.time() > reset_time) then
        CMD.reset_give_coin_info(id)
    end
end

-- 重置好友嘻嘻币赠送和接受限制
function CMD.reset_give_coin_info(id)
    CMD.set_give_coin_info({give_coin_info = {coin_get_num = 0,coin_give_num = 0,give_friends = {},last_reset_time = os.time()} ,id = id})
end

-- 如果当前玩家允许添加好友且不在玩家池中，则添加进玩家池，并把当前玩家加入可以被添加好友的列表中
function CMD.player_login(id, nickname, headimgurl, sex,headframe, refuse_friend)
    local curr_time = os.time()
    --print('=======================玩家登陆=====================',headframe)
    if not refuse_friend and (not player_info[id]) then
        player_info[id] = {id = id, nickname = nickname, headimgurl = headimgurl,headframe =headframe, sex = sex,last_time = curr_time}
        rnd_replace(player_info[id])
    end

    -- 第一次登录时更新好友嘻嘻币赠送和接受限制
    local my_data = skynet.call(get_db_mgr(), "lua", "find_one",COLL.USER,{id = id},{_id=false,login_time=true,give_coin_info=true}) or {}
    if my_data and (my_data.login_time == 1 or my_data.give_coin_info == {}) then
        CMD.reset_give_coin_info(id)
    else
        local tmp_data = skynet.call(get_db_mgr(), "lua", "find_one",COLL.USER,{id = id},{_id=false,give_coin_info=true})
        local init_give_coin_data = {coin_get_num = 0,coin_give_num = 0,give_friends = {},last_reset_time = os.time()}
        give_coin_info_list[id] = tmp_data and tmp_data.give_coin_info or init_give_coin_data
    end
end

function is_goods_time_out(goods)
    if not goods or goods.num <= 0 then
        return true
    end
    local gItem = cfg_items[goods.id]
    if gItem.time <= 0 or not goods.gettime then
        return false
    end
    if os.time() - (goods.gettime or 0) > (ONE_DAY * gItem.time*goods.num) then
        return true
    end
    return false
end
--获取角色当前装备的头像框,头像框只能装一个，返回ID就行
local function get_picture_frame(backpack)
    local typeused = {}
    local picture_frame = 0
    if not backpack then
        return 30001
    end
    --先遍历非默认头像
    for _,goods in ipairs(backpack) do
        local gItem = cfg_items[goods.id]
        if (1 ~= gItem.default) and goods.usetime  and (not is_goods_time_out(goods)) 
            and (gItem.top_type == BAG_PICTURE_FRAME) then
            picture_frame = goods.id
            typeused[gItem.type] = true
        end
    end
    --遍历默认装扮
    for _,goods in ipairs(backpack) do
        local gItem = cfg_items[goods.id]
        if (1 == gItem.default) and goods.usetime and (gItem.top_type == BAG_PICTURE_FRAME) then
            if not typeused[gItem.type] then
                picture_frame = goods.id
            end
        end
    end

    return picture_frame
end

--玩家绑定更新
function CMD.updateOtherbind(pid,my_id)
    local spreadInfo = skynet.call(get_db_mgr(), "lua", "find_one",COLL.SPREAD_DATA,{pid = pid}) or {}
    print('===========玩家绑定==============',pid,my_id)
    table.print(spreadInfo)
    if not spreadInfo or not spreadInfo.pidTbl then
        local user = skynet.call(get_db_mgr(), "lua", "find_one", "user", {id = pid})
        spreadInfo = {
            pid             = user.id,
            pictureframe    = get_picture_frame(user.backpack),
            headimgurl      = user.headimgurl,
            nickname        = user.nickname,
            last_time       = 0,
            getGold         = 0,
            getDiamond      = 0,
            bindId          = '0',
            pidTbl          = {},
            payNum          = 0,
            loginNum        = 0,
            gameNum         = 0,
            gradingLv       = 1,
            petLv           = 0,
            t               = os.time(),
            otherGold       = 0,
            otherDiamond    = 0
        }
        table.insert(spreadInfo.pidTbl,my_id)
        skynet.call(get_db_mgr(), "lua", "insert",COLL.SPREAD_DATA, spreadInfo)
        return 0
    elseif #spreadInfo.pidTbl >= 5 then
        return 4
    else
        table.insert(spreadInfo.pidTbl,my_id)
        skynet.call(get_db_mgr(),"lua","update",COLL.SPREAD_DATA,{pid = pid},{pidTbl = spreadInfo.pidTbl})
        return 0
    end
    
    
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
end)