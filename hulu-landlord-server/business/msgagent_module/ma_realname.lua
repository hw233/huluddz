local ma_realname = {}
local request = {}
local cmd = {}
local skynet = require "skynet"
local cluster = require "skynet.cluster"
local ma_data = require "ma_data"
local timer = require("lualib/timer")
local rn_regular_auth = require "utils.realname_auth"
local rn_conf = require "config.realname_conf"
--local certification = (require "cfg.cfg_global")[1].certification
local COLL = require "config/collections"

require "define"


function ma_realname.ignore_channel()
    local channel = ma_data.db_info.channel
    if rn_conf.ignore_channel[channel] then
        return true
    end

    -- 没有需要验证的渠道,则除开忽略渠道全部验证
    if not rn_conf.need_auth then
        return false
    end

    -- 有需要验证的渠道,则只验证需要的渠道
    return not rn_conf.need_auth[channel]
end

--判断法定节假日
function ma_realname.is_holiday()
    local date = tonumber(os.date("%Y"))
    local today = tonumber(os.date("%m%d"))

    for _,v in ipairs(cfg_Holidays) do
        if v.year == date then
            for _,day in ipairs(v) do
                if today == day then
                    return true
                end
            end
            return false
        end
    end
end

-- 检查玩家在实名认证系统中,是否允许购买
function ma_realname.can_buy(price)
    if ma_realname.ignore_channel() then
        return true
    end

    -- 认证中玩家可以充值
    if ma_data.db_info.rn_status == 1 then
        return true
    end

    if ma_data.db_info.idcard and not ma_data.db_info.rn_status then
        return true
    end


     -- 未实名认证(包括认证中和认证失败)不能购买
    if not ma_data.db_info.rn_pi then
        return false,RN_ERR.NO_RNAUTH
    end

    ma_realname.refresh_user_age()

    local curr_age = ma_data.db_info.curr_age

    if curr_age >= 18 then return true end

    -- 小于8岁玩家不能充值
    if not curr_age or curr_age < 8 then
        return false,RN_ERR.AGE_LT_8
    end

    local single_price,month_fee = 0,0
    -- 单笔不能超过 50,每月充值金额累计不能超过200
    if curr_age >= 8 and curr_age < 16 then
        single_price = 50
        month_fee = 200
    elseif curr_age >= 16 and curr_age < 18 then
         -- 单笔不能超过 100,每月充值金额累计不能超过 400
        single_price = 100
        month_fee = 400
    end

    -- 单笔充值不能超过限额
    if price > single_price then
        return false,RN_ERR.SINGLE_LIMIT
    end

    -- 月累计充值不能大于限额
    if (ma_data.db_info.month_fee or 0) + price > month_fee then
        return false,RN_ERR.MONTH_LIMIT
    end
    
    return true
end
--獲取可在線時間
function ma_realname.get_can_oltime(isrn)
    -- 未实名认证或实名认证失败的玩家
    if not isrn then
        -- 只能玩一个小时
        return 3600
    end

    ma_realname.refresh_user_age()

    local curr_age = ma_data.db_info.curr_age

    if not curr_age or curr_age == 0 then
        return  3600
    elseif ma_data.db_info.curr_age < 18 then
        --法定节假日不超过3小时
        if ma_realname.is_holiday() then
            return 10800 -- 3 小时
        else -- 平时
            return  5400 -- 1.5 小时
        end
    end
    return 90000
end

--未实名认证 或 未满18 岁 获取实际可在线时间
function ma_realname.get_residue_oltime(yet_oltime)
    local isrn = ma_data.db_info.rn_pi
    local cur_time = os.time()
    local cur_date = os.date("*t")
    local last_time = os.time({year=cur_date.year, month=cur_date.month, day=cur_date.day, hour=22,min=0,sec=0})
    local early_time = os.time({year=cur_date.year, month=cur_date.month, day=cur_date.day, hour=8,min=0,sec=0})

    -- 实名认证成功 未满 18 岁的玩家
    -- 在 22 - 次日 8 点 不能登录
    if isrn and (cur_time < early_time or cur_time > last_time) then
        return -1,RN_ERR.NO_LOGIN
    end

    local oltime = ma_realname.get_can_oltime(isrn)
    local can_oltime = oltime - yet_oltime
    if not isrn then
        return can_oltime,RN_ERR.NO_RN
    end

    local cur_to_last_time = last_time - cur_time
    
    if cur_to_last_time <= oltime then
        if cur_to_last_time > 0 then
            can_oltime = cur_to_last_time - yet_oltime
        else
            can_oltime = 0
        end
    end
    return can_oltime,RN_ERR.NO_TIME
end

--在線時間獲取
function ma_realname.update_online_time(is_leave)
    if ma_data.up_ot_invoke then
        ma_data.up_ot_invoke()
        ma_data.up_ot_invoke = nil
    end

    if not is_leave then
        ma_realname.check_realname() -- 存量用户检查
    end

     if ma_realname.ignore_channel() then
        return true
    end

    -- 大于18岁的实名玩家不受此限制
    if ma_data.db_info.rn_pi 
            and ma_data.db_info.curr_age 
            and ma_data.db_info.curr_age >= 18 then
        return
    end

    -- 认证中的玩家暂时也按照实名认证成处理
    local rn_status = ma_data.db_info.rn_status
    if rn_status == 1 or (ma_data.db_info.idcard and not rn_status ) then
        return
    end

    -- 实名认证成功或认证中的玩家更新 在线时间
    if ma_data.db_info.rn_pi or ma_data.db_info.rn_status == 1 then
        local today = os.date("%Y%m%d")
        if ma_data.db_info.today ~= today then
            ma_data.db_info.online_time = 0
            ma_data.db_info.today = today
        end
    end

    local online_time = ma_data.db_info.online_time or 0
    local diff = os.time() - ma_data.db_info.last_time
    diff = diff < 0 and 0 or diff -- 避免服务器时间修改导致错误
    online_time = online_time + diff
    ma_data.db_info.online_time = online_time

    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, 
        {   
            online_time = ma_data.db_info.online_time,
            today = ma_data.db_info.today
        })
    
   
    if is_leave then
        return
    end
    
    -- 获取玩家剩余可在线时间
    local last_time,desc = ma_realname.get_residue_oltime(online_time)

    if last_time <= 0 then
        ma_data.send_push('time_down', {online_time = -1,desc = desc,channel = ma_data.db_info.channel})
        return
    else
        ma_data.send_push('time_down', {online_time = last_time,channel = ma_data.db_info.channel})
    end
    
    ma_data.up_ot_invoke = timer.create(last_time*100,function ()
            ma_realname.update_online_time()
    end)
end

--獲取年齡
function ma_realname.get_user_age(idcard)
    local dt = os.date("*t", os.time())
    local year = tonumber(idcard:sub(7,10))
    local month = tonumber(idcard:sub(11,12))
    local day = tonumber(idcard:sub(13,14))
    local user_age = dt.year - year

    if month == dt.month and day > dt.day then
        user_age = user_age - 1
    elseif month > dt.month then
        user_age = user_age - 1
    end

    return user_age
end

--刷新年齡
function ma_realname.refresh_user_age()
    if ma_data.db_info.idcard then
        local curr_age = ma_realname.get_user_age(ma_data.db_info.idcard)
        if curr_age ~= ma_data.db_info.curr_age then
            ma_data.db_info.curr_age = curr_age
            skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, {curr_age = ma_data.db_info.curr_age})
        end
    end
end

-- 实名认证成功
function ma_realname.rn_auth_succ(result)
    -- 认证成功,更新状态
    ma_data.db_info.rn_status = result.status
    ma_data.db_info.rn_pi = result.pi
    local curr_age = ma_realname.get_user_age(ma_data.db_info.idcard)
    ma_data.db_info.curr_age = curr_age
    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, 
        {   
            curr_age = curr_age,
            rn_pi = rn_pi,
            rn_status = result.status,
        })

    ma_data.send_push("rnauth_result",{
        auth_succ = true,
        curr_age  = curr_age,
    })

    ma_realname.update_online_time()

end

-- 实名认证失败
function ma_realname.rn_auth_fail(status)
    local count = ma_data.db_info.rn_auth_count or 0 -- 实名认证,认证次数
    count = count + 1
    ma_data.db_info.rn_auth_count = count
    ma_data.db_info.rn_status = status
    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, 
        {   
            rn_auth_count = count,
            rn_status = status,
        })
    ma_realname.update_online_time()
end

-- 发送实名认证奖励
function ma_realname.send_rn_awards()
    ma_data.add_goods_list(certification,GOODS_WAY_REALNAME,"实名认证")
    ma_data.send_push("buy_suc", {
        goods_list = certification,
        msgbox = 1
    })
    ma_data.db_info.rn_yet_award = true
    skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, 
    {   
        rn_yet_award = true,
    })
end

-- 实名认证
function ma_realname.realname_auth(args)
    local ok,succ,result = pcall(skynet.call,"rn_auth_mgr","lua","check_realname",{
        name = args.name,
        idcard = args.idcard,
        pid = ma_data.my_id,
        rn_auth_count = ma_data.db_info.rn_auth_count,
    })

    -- TODO 测试
    -- local ok,succ,result = pcall(skynet.call,"rn_auth_mgr","lua","check_realname",{
    --     name = args.name,
    --     idcard = args.idcard,
    --     pid = ma_data.my_id,
    -- })



    -- 认证失败
    if ok and succ == RN_ERR.SUCC and result.status == 2  then
        ma_realname.rn_auth_fail(result.status)
        return {result = false, e_info = 3}
    end

    -- 请求错误
    if ok and succ ~= RN_ERR.SUCC then
        --local currtime = skynet.time()
        -- 请求过载 延迟 2 - 30 秒请求
        -- 其他错误 延迟 10 - 30 分钟请求
        local diff = succ == RN_ERR.OVERDRIVE and math.random(2,30) or math.random(600,1800)
        timer.create(diff * 100,function()
            ma_realname.realname_auth(args)
        end)
        
        if ma_data.db_info.idcard ~= args.idcard then
            ma_data.db_info.idcard = args.idcard
            ma_data.db_info.realname = args.name
            skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, 
                {   
                    idcard = args.idcard, 
                    realname = args.name,
                })
        end
        -- 返回验证中
        return {result = false, e_info = 4}
    end

   
    if ok and succ == RN_ERR.SUCC then
         -- 防沉迷系统返回 认证中
        ma_data.db_info.idcard = args.idcard
        ma_data.db_info.realname = args.name
        ma_data.db_info.rn_status = result.status
        local curr_age,rn_pi
        if result.status == 0 then -- 认证成功
            curr_age = ma_realname.get_user_age(args.idcard)
            rn_pi = result.pi
        end
        ma_data.db_info.curr_age = curr_age
        ma_data.db_info.rn_pi = rn_pi
        ma_data.db_info.rn_time = os.time()
        skynet.call(get_db_mgr(), "lua", "update", "user", {id = ma_data.my_id}, 
                {   
                    idcard = args.idcard, 
                    realname = args.name,
                    curr_age = curr_age,
                    rn_pi = rn_pi,
                    rn_status = result.status,
                    rn_time    = ma_data.db_info.rn_time,
                })

        -- 认证成功 或 认证中 状态 都返回true,发放实名认知奖励
        if curr_age then
            return {result = true,curr_age = ma_data.db_info.curr_age}
        else
            return {result = true, e_info = 4}
        end
    end

end

-- 存量实名认证检查
function ma_realname.check_realname()
    if rn_conf.ignore_channel[ma_data.db_info.channel] then
        return
    end

    -- 实名认证处理
    if ma_data.db_info.rnauth_result then
        local rnauth_result = ma_data.db_info.rnauth_result
        ma_data.db_info.rnauth_result = nil
        cmd.rn_auth_end(nil,rnauth_result)
        skynet.send(get_db_mgr(), "lua", "replace", COLL.USER, {id = ma_data.my_id}, 
        {["$unset"] = {rnauth_result = ''}})
    end

    -- 已通过实名认证用户的唯一 标识
    if ma_data.db_info.rn_pi then
        return
    end

    -- 存在rn_status 表示已经进行过新的防沉迷系统认证
    -- 无需重复检查

    local rn_status = ma_data.db_info.rn_status
    local rn_time = ma_data.db_info.rn_time
    if rn_status and rn_status ~= 1 then
        return
    elseif rn_status then
        -- -- 去掉2天超时限制
        -- if not rn_time or os.time() - rn_time < ONE_DAY * 2 then
            -- 重新查询认证结果
            skynet.send("rn_auth_mgr","lua","set_inauth_data",{
                pid = ma_data.my_id,
                time = rn_time,
                rn_auth_count = ma_data.db_info.rn_yet_award and ma_data.db_info.rn_auth_count,
                -- rn_auth_count 判断 ma_data.db_info.rn_yet_award 主要为了兼容之前逻辑
            })
        -- else
        --     -- 直接修改为认证失败
        --     ma_data.db_info.rn_status = 2
        --     skynet.call(get_db_mgr(), "lua", "update_userinfo", ma_data.my_id, {rn_status = 2})
            
        -- end
        return
    end


    -- 存量用户验证
    if ma_data.db_info.idcard then
        ma_realname.realname_auth({
            name = ma_data.db_info.realname,
            idcard = ma_data.db_info.idcard,
        })
    end
end

function request:realname_auth()
    -- 已通过实名认证用户的唯一 标识
    if ma_data.db_info.rn_pi then
        return {result = false, e_info = 1}
    end

    if ma_data.db_info.rn_auth_count and ma_data.db_info.rn_auth_count >= 3 then -- 认证超过次数
        return {result = false, e_info = 5}
    end

    -- 认证中
    if ma_data.db_info.rn_status == 1 then
        return {result = false, e_info = 4}
    end

    -- 正在实名认证,请勿重复发送
    if ma_data.in_rn_auth then
        return {result = false, e_info = 6}
    end

    local auth_ok = rn_regular_auth(self.idcard)
    if not auth_ok then
        return {result = false, e_info = 2}
    else
         
        ma_data.in_rn_auth = true

        local ret = ma_realname.realname_auth(self)
        ma_data.in_rn_auth = nil
        if ret.result and not ma_data.db_info.rn_yet_award then
            ma_realname.send_rn_awards()
        end

        -- 防沉迷系统返回认证中状态,发放奖励后,重置result返回false
        if ret.result and ret.e_info then
            ret.result = false
        end

        ma_realname.update_online_time()
        -- ma_realname.rn_auth_succ(args)

        return ret
    end
end
-- 实名认证结束,认证中的 认证完成
function cmd.rn_auth_end(_,args)
    if ma_data.db_info.rn_pi or not args then
        return
    end


    -- 认证失败
    if args.status == 2 then
        ma_realname.rn_auth_fail(args.status)
        ma_data.send_push("rnauth_result",{
            auth_succ = false
        })
        return
    end

    -- 没有发送过实名认证奖励的玩家,发送实名认证奖励
    -- 正常情况,在实名认证立即返回结果时已经发送奖励,这里不需要再次发送
    -- 再次检查发送的原因是 兼容之前 逻辑
    if not ma_data.db_info.rn_yet_award then
        ma_realname.send_rn_awards()
    end

    ma_realname.rn_auth_succ(args)
end


function ma_realname.init(REQUEST,CMD)
    if request then
        table.connect(REQUEST,request)
    end
    if cmd then
        table.connect(CMD,cmd)
    end
end

ma_data.ma_realname = ma_realname
return ma_realname

