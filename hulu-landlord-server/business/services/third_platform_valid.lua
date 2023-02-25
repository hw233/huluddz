local skynet = require 'skynet'
local snax = require 'skynet.snax'
local queue = require "skynet.queue"
local cjson = require "cjson"
local httpc = require "http.httpc"
local timer = require "timer"
local url = require "utils/url"
require "pub_util"
require "table_util"
require "cqll_util"
require "wx_util"

local server_conf = require "server_conf"
local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
ServerData.cs = nil
-- local db_mgr,httpclient
-- 唯一字符串 = last_gen_nonce_time + suffix_nonce
ServerData.last_gen_nonce_time = nil -- 上一次产生字符串的时间
ServerData.suffix_nonce = nil        -- 字符串后缀

ServerData.nonceStrDic = {}

ServerData.waitInformOrders = {} --等待通知的订单
ServerData.informFailOrders = {} --通知失败的订单
ServerData.secrets = {} --客户端与服务器通信密钥

ServerData.game_names = {
    'cqll',
    'zjxj',
    'tyby',
}

-- 请求头必须的参数
ServerData.essential_headers_args = {
    "appid",
    "nonce_str",    -- 请求唯一字符，防重
    "timestamp",    -- 时间戳
    "sign",         -- 签名
}
-- 请求订单必须的参数
ServerData.essential_order_args = {
    "openId",       
    "out_trade_no", -- 订单号
    "total_fee",    -- 价格
    --"trade_type",   --1 微信，2 支付宝 -- 去掉支付类型
    "notify_url",   -- 异步通知url
    "desc",         -- 商品描述
   -- "attach",     -- 非必须参数，附加数据，支付成功后原样返回
}

-- 获取玩家信息必须的参数
ServerData.essential_pinfo_args = {
    "openId",
    "accessToken",
}

-- 请求支付的订单字符串必须的参数
ServerData.essential_order_str_args = {
    "openId",
    "order_id",
    "trade_type",
    "ip",
}

-- 查询订单状态必须的参数
ServerData.essential_order_state_agrs = {
    "openId",
    "order_id",
}
-- 关闭游戏
ServerData.essential_close_game_agrs = {
    "openId"
}

-- 每次通知时间间隔
ServerData.asyn_inform_interval = {
    4  * 60,          -- 4分钟   -- 距离上一次通知的时间间隔
    14 * 60,          -- 10 分钟
    24 * 60,          -- 10 分钟
    84 * 60,          -- 1 小时
    204 * 60,         -- 2 小时
    564 * 60,         -- 6 小时
    1464 * 60 * 60,   -- 15 小时
}

-- local CMD = {}

function CMD.post_string(host, url, context, recvheader)
    local header = {
        ["content-type"] = "application/x-www-form-urlencoded"
    }

    return httpc.request("POST", host, url, recvheader, header, context)
end


function CMD.encode_body(pack,secret,plat_name)
    local sign,string_sign = cqll_signature(pack,secret,plat_name)
    pack.sign = sign

    local param = cjson.encode(pack)

    return param
end

function CMD.parse_query(q)
    local r = {}
    for k,v in q:gmatch "(.-)=([^&]*)&?" do
        r[k] = v
    end
    return r
end


function CMD.decode_body(body)
    local pack = CMD.parse_query(body)
    local decode_pack = {}
    for k,v in pairs(pack) do
        if k ~= 'sign' then -- 签名字段不进行解码
            decode_pack[SpecialDecodeURI(k)] = SpecialDecodeURI(v)
        else
            decode_pack[k] = v
        end
    end
    return decode_pack
end


-- 删除超时的 请求唯一字符串
function CMD.del_timout_nonce_str()
    local current_time = os.time()
    for nonce_str,time in pairs(ServerData.nonceStrDic) do
        if current_time - time >= 30 * 60 then
            ServerData.nonceStrDic[nonce_str] = nil
        end
    end
end

-- 删除场时间没使用的密钥
function CMD.del_timout_secret()
    local current_time = os.time()
    for pid,pack in pairs(ServerData.secrets) do
        if current_time - pack.time >= 30 * 60 then
            ServerData.secrets[pid] = nil
        end 
    end
end

-- 插入密钥
function CMD.insert_secret(pid,secret)
    if not pid or not secret then
        return
    end
    ServerData.secrets[pid] = {secret = secret,time = os.time()}

    CMD.del_timout_secret()
end
-- 更新密钥使用时间
function CMD.update_secret(pid)
    if not pid or not ServerData.secrets[pid] then return end
    ServerData.secrets[pid].time = os.time()
end
-- 获取密钥
function CMD.get_secret_by_openid(openid,plat_name)
    if not openid then return end
    local gameid = cqll_get_gameid_by_opneid(openid)
    local secret = ServerData.secrets[gameid] and ServerData.secrets[gameid].secret
    if not secret then
        local cqll_dbinfo = skynet.call(get_db_mgr(), "lua", "cqll_get_dbinfo", gameid,plat_name)
        -- local cqll_dbinfo = db_mgr.req.cqll_get_dbinfo(gameid,plat_name)
        if cqll_dbinfo then
            secret = cqll_dbinfo.secret
            CMD.insert_secret(gameid,secret)
        end
    else
        CMD.update_secret(gameid)
    end
    return secret
end

function CMD.del_secret(openid)
    if not openid then return end
    local gameid = cqll_get_gameid_by_opneid(openid)
    ServerData.secrets[gameid] = nil
end

-- 插入等待通知的订单
function CMD.push_wait_order(order_id)
    ServerData.waitInformOrders[order_id] = true
end
-- 通知成功，删除等待通知的订单
function CMD.del_wait_order(order_id)
    ServerData.waitInformOrders[order_id] = nil
end
-- 查询等待通知的订单
function CMD.query_wait_order(order_id)
    return ServerData.waitInformOrders[order_id]
end

-- 插入通知失败的订单
function CMD.push_inform_fail_order(order,plat_name)
    order.inform_count = (order.inform_count or 0) + 1

    -- 在数据库中 插入通知失败订单
    if not ServerData.informFailOrders[order.order_id] then
        skynet.call(get_db_mgr(), "lua", "cqll_insert_err_order", order,plat_name)
        -- db_mgr.req.cqll_insert_err_order(order,plat_name)
    else -- 在数据库中，更新通知失败订单更新次数
        skynet.call(get_db_mgr(), "lua", "cqll_update_err_order", order.order_id,{inform_count = order.inform_count},plat_name)
        -- db_mgr.req.cqll_update_err_order(order.order_id,{inform_count = order.inform_count},plat_name)
    end
    order.plat_name = plat_name
    ServerData.informFailOrders[order.order_id] = order
end

-- 查询通知失败的订单
function CMD.query_inform_fail_order(order_id)
    return ServerData.informFailOrders[order_id]
end

-- 删除已经通知成功的订单
function CMD.del_inform_succ_order(order_id, plat_name, timeout)
    CMD.del_wait_order(order_id)

    ServerData.informFailOrders[order_id] = nil
    if not timeout then -- 正常通知成功,删除数据
        skynet.send(get_db_mgr(), "lua", "cqll_del_inform_succ_order", order_id,plat_name)
    end
end

-- 获取一个唯一字符串
function CMD.get_nonceStr()
    local curr_time = os.time()
    if curr_time ~= ServerData.last_gen_nonce_time then
        ServerData.last_gen_nonce_time = curr_time
        -- 首先随机一个数尽量保证数字唯一（服务重启时）
        ServerData.suffix_nonce = math.random(10000000,59999999)
    else
        ServerData.suffix_nonce = ServerData.suffix_nonce + 1
    end
    return ServerData.last_gen_nonce_time..ServerData.suffix_nonce
end
-- 记录已经生产的 唯一字符串 及 时间
function CMD.insert_nonceStr(nonceStr,gen_time)
    ServerData.nonceStrDic[nonceStr] = gen_time or os.time()
    
    CMD.del_timout_nonce_str()
end

function CMD.check_nonceStr(nonceStr)
    return ServerData.nonceStrDic[nonceStr]
end

-- api 权限验证
function CMD.permissions_validation(openId,accessToken,plat_name)
   if not openId or not accessToken then return false end

    local gameid = cqll_get_gameid_by_opneid(openId)
    local cqll_dbinfo = skynet.call(get_db_mgr(), "lua", "cqll_get_dbinfo", gameid,plat_name)
    -- local cqll_dbinfo = db_mgr.req.cqll_get_dbinfo(gameid,plat_name)
    if not cqll_dbinfo then
        return false -- 没查找到用户
    end
    if cqll_dbinfo.token ~= accessToken then
        return false -- token 错误
    end

    return true,gameid
end

-- 验证签名
-- pack             -- 参数
-- secret     -- 使用对应客户端的密钥
function CMD.sign_verify(pack,secret,plat_name)
    local original_sign = pack.sign
    if not original_sign then
        return false
    end
    plat_name = plat_name or "cqll"
    local appKeyName = plat_name .. "_appKey"
    if pack.appid ~= server_conf[appKeyName] then
        return false
    end
    pack.sign = nil

    local sign = cqll_signature(pack,secret,plat_name)
    return sign == original_sign
end

-- 验证请求是否包含所有的必须参数
function CMD.request_args_verify(pack,essential_args)
    -- 验证每个请求必须包括的参数
    for _,key in ipairs(ServerData.essential_headers_args) do
        if not pack[key] then
            return false
        end
    end
    -- 验证请求的业务参数
    for _,key in ipairs(essential_args) do
        if not pack[key] then
            return false
        end
    end

    return true
end

-- 检查请求超时，请求有效期 15分钟
function CMD.check_timeout(time)
    return os.time() - time >= 150 * 60
end

-- 验证请求的正确性
-- pack             -- 请求参数
-- essential_args   -- 需验证的必须存在的业务参数
-- secret           -- 使用客户端自己密钥
function CMD.check_request(pack,essential_args,secret,plat_name)
    -- 参数验证
    if not CMD.request_args_verify(pack,essential_args) then 
        return {result = 'Fail',code = 4}
    end
    -- 请求超时验证
    if CMD.check_timeout(pack.timestamp) then
        return {result = 'Fail',code = 5}
    end
    -- 验证请求唯一字符串
    if CMD.check_nonceStr(pack.nonceStr) then
        return {result = 'Fail',code = 6}
    end

    -- 验证签名
    if not CMD.sign_verify(pack,secret,plat_name) then
        return {result = 'Fail',code = 2} -- 签名验证失败
    end

    return {result = 'Success'}
end

--服务器即将关闭
function CMD.server_will_shutdown()
    isServerWillShutdown = true
end

-- platform_name    平台名
-- p_id             玩家游戏id
function CMD.get_login_proof(platform_name,p_id)
    platform_name = platform_name  or 'cqll'
    if platform_name == 'cqll' or platform_name == "zjxj" or platform_name == "tyby" then
        local secret = gen_app_secret()
        local cqll_dbinfo = skynet.call(get_db_mgr(), "lua", "cqll_get_dbinfo", p_id,platform_name)
        -- local cqll_dbinfo = db_mgr.req.cqll_get_dbinfo(p_id,platform_name)

        local login_time = os.time()

        if not cqll_dbinfo then -- 注册传奇用户
            local cqll_openid = cqll_get_openid_by_gameid(p_id)
            local token = cqll_get_access_token(cqll_openid,platform_name)
            cqll_dbinfo= skynet.call(get_db_mgr(), "lua", "cqll_register", p_id,cqll_openid,token,secret,platform_name)
            -- cqll_dbinfo = db_mgr.req.cqll_register(p_id,cqll_openid,token,secret,platform_name)
        else
            local pack = {}
            pack.last_time = login_time
            pack.login_count = cqll_dbinfo.login_count + 1
            pack.secret = secret
            -- 刷新token
            if os.time() - cqll_dbinfo.token_gen_time >= server_conf.cqll_usefulLife then
                pack.token = cqll_get_access_token(cqll_dbinfo.openId,platform_name)
                pack.token_gen_time = login_time
                cqll_dbinfo.token = pack.token
            end
            skynet.call(get_db_mgr(), "lua", "cqll_update_dbinfo", p_id,pack,platform_name)
            -- db_mgr.req.cqll_update_dbinfo(p_id,pack,platform_name)
        end

        local nonce_str = CMD.get_nonceStr()
        --insert_nonceStr(nonceStr,login_time)
        -- 获取登录参数
        local pack = {
            appid  = server_conf[platform_name .. "_appKey"],
            openId = cqll_dbinfo.openId,
            accessToken = cqll_dbinfo.token,
            timestamp = login_time,
            nonce_str  = nonce_str
        }
        
        CMD.insert_secret(p_id,secret) 
        local sign,string_sign = cqll_signature(pack,nil,platform_name)
        return "sign="..sign .. "&" .. string_sign,pack.openId,secret
    end
end

function CMD.query_order_state_comp(order_id,plat_name)
    if not order_id then
        return 1   --订单号错误
    end

    if CMD.query_wait_order(order_id) then
        return 2   -- 订单完成，未通知
    end
    if skynet.call(get_db_mgr(), "lua", "cqll_check_order_by_orderid", order_id,plat_name) then
    -- if db_mgr.req.cqll_check_order_by_orderid(order_id,plat_name) then
        return 0   -- 订单完成，并完成通知
    end

    return 1 -- 订单未完成
end 

-- 查询订单状态
function CMD.query_order_state(order_id,plat_name)
   return CMD.query_order_state_comp(order_id,plat_name)
end

function CMD.query_order_state_http(pack,plat_name)
    local secret = CMD.get_secret_by_openid(pack.openId,plat_name)
     -- 请求参数验证
    local result = CMD.check_request(pack,ServerData.essential_order_state_agrs,secret,plat_name)
    if not result.result or result.result == "Fail" then
        return CMD.encode_body(result,secret)
    end
    local state = CMD.query_order_state_comp(pack.order_id,plat_name)
    return CMD.encode_body({result = "Success",code = 0,state = state},secret)
end

-- 获取玩家信息
-------参数-------------
-- appid
-- nonce_str
-- timestamp
-- sign
-- openId
-- accessToken
-------返回参数----------
-- openId
-- nick_name
-- sex
-- headimgurl
function CMD.get_player_info(body,plat_name)
    local pack = CMD.decode_body(body)
    -- 请求参数验证
    local result = CMD.check_request(pack,ServerData.essential_pinfo_args,nil,plat_name)
    if not result.result or result.result == "Fail" then
        return CMD.encode_body(result,nil,plat_name)
    end

    local openId = pack.openId
    local accessToken = pack.accessToken
    local result,gameid = CMD.permissions_validation(openId,accessToken,plat_name)
    if not result then
        return CMD.encode_body({result = 'Fail',code = 1},nil,plat_name) -- 权限验证错误
    end

    CMD.insert_nonceStr(pack.nonce_str)
    local dbinfo = skynet.call(get_db_mgr(), "lua", "get_user_info", gameid)
    -- local dbinfo = db_mgr.req.get_user_info(gameid)
    assert(dbinfo)

    local pack = {
        result      = "Success",
        code        = 0,
        openId      = openId,
        nick_name   = dbinfo.nick_name,
        sex         = dbinfo.sex,
        headimgurl  = dbinfo.headimgurl,
    }

    return CMD.encode_body(pack,nil,plat_name)
end


-- 请求订单id
-------参数-------------
-- appid
-- nonce_str
-- timestamp
-- sign
-- openId
-- out_trade_no
-- total_fee
-- trade_type  1 微信，支付宝
-- notify_url
-- desc
-- attach      -- 附加数据，支付成功后原样返回
-------返回参数------------
-- order_id
function CMD.pre_order(body,plat_name)
    -- return ServerData.cs(function()
        local pack = CMD.decode_body(body)

        plat_name = plat_name or "cqll"

        local secret = server_conf[plat_name .. "_appSecret"]
        -- 请求参数验证

        local result = CMD.check_request(pack,ServerData.essential_order_args,secret,plat_name)
        if not result.result or result.result == "Fail" then
            return CMD.encode_body(result,secret)
        end

        -- 检查订单存在
        -- if skynet.call(get_db_mgr(), "lua", "cqll_check_pre_order", pack.out_trade_no,plat_name) then
        -- -- if db_mgr.req.cqll_check_pre_order(pack.out_trade_no,plat_name) then
        --     return CMD.encode_body({result = 'Fail',code = 3},secret) -- 请求订单信息重复
        -- end

        CMD.insert_nonceStr(pack.nonce_str)

        local order_id = CMD.get_nonceStr() -- 获取订单id
        -- 插入预请求订单信息
        pack.order_id = order_id
        pack.p_id = cqll_get_gameid_by_opneid(pack.openId)
        skynet.call(get_db_mgr(), "lua", "cqll_insert_pre_order", pack,plat_name)
        -- db_mgr.req.cqll_insert_pre_order(pack,plat_name)

        return CMD.encode_body({result = "Success",code = 0,order_id = order_id},secret)
    -- end)
end

-- 获取微信支付请求订单字符串
function CMD.gen_wx_order_str(body)
    if not body then return false end
    body = xml2tbl(body)
    if body.return_code == 'SUCCESS' then
        local pack = {
            appid       = body.appid,
            partnerid   = body.mch_id,
            prepayid    = body.prepay_id,
            package     = 'Sign=WXPay',
            noncestr    = body.nonce_str,
            timestamp   = tostring(os.time())
        }

        local sign = get_sign_by_tbl(pack)

        local url = pack.appid .. " " ..
                    pack.partnerid .. " " ..
                    pack.prepayid .. " " ..
                    pack.package .. " " ..
                    pack.noncestr .. " " ..
                    pack.timestamp .. " " ..
                    sign

        return url
    else
        return false
    end
end

-- 获取支付宝支付请求订单
function CMD.gen_ali_order_str(body)
    if not body then return false end
    body = cjson.decode(body)
    if tonumber(body.status) == 0 then
        return body.result
    end
end

function CMD.get_order_str_comp(order_id,pay_type,ip,plat_name)
    local order_info = skynet.call(get_db_mgr(), "lua", "cqll_get_pre_order", order_id,plat_name)
    -- local order_info = db_mgr.req.cqll_get_pre_order(order_id,plat_name)
    if not order_info then
        return false
    end

    -- 根据支付类型请求 支付订单
    local body
    local trade_type = tonumber(pay_type) or 1
    order_info.attach = order_info.attach or ""
    if trade_type == 1 then -- 微信支付
        body = skynet.call("httpclient", "lua", "third_wx_order", order_info,ip,plat_name)
        -- body = httpclient.req.third_wx_order(order_info,ip,plat_name)
        
        return CMD.gen_wx_order_str(body),trade_type
    elseif trade_type == 2 then --支付宝支付
        body = skynet.call("httpclient", "lua", "third_ali_order", order_info,ip,plat_name)
        -- body = httpclient.req.third_ali_order(order_info,ip,plat_name)

        return CMD.gen_ali_order_str(body),trade_type
    else
        return false
    end
end

-- 获取请求支付的订单字符串
function CMD.get_order_str(order_id,pay_type,ip,plat_name)
    return CMD.get_order_str_comp(order_id,pay_type,ip,plat_name)
end
-- 通过http协议 获取请求支付的订单字符串
function CMD.get_order_str_http(body,plat_name)

    --
    if isServerWillShutdown then
        return {result = "Fail",code = 7} --服务器即将个关闭 
    end
    local pack = CMD.decode_body(body)
    local secret = CMD.get_secret_by_openid(pack.openId,plat_name)
    -- 请求参数验证
    local result = CMD.check_request(pack,ServerData.essential_order_str_args,secret,plat_name)
    if not result.result or result.result == "Fail" then
        return CMD.encode_body(result,secret)
    end
    local order_str,trade_type = CMD.get_order_str_comp(pack.order_id,pack.trade_type,pack.ip,plat_name)
    if not order_str then
        return CMD.encode_body({result = "Fail",code = 8},secret) -- 未查找到订单
    end
    return CMD.encode_body({result = "Success",code = 0,order_str = order_str,trade_type = trade_type},secret)
end
-- 退出h5游戏
function CMD.close_game(body,plat_name)
    local pack = CMD.decode_body(body)
    local secret = CMD.get_secret_by_openid(pack.openId,plat_name)
     -- 请求参数验证
    local result = CMD.check_request(pack,ServerData.essential_close_game_agrs,secret,plat_name)
    if not result.result or result.result == "Fail" then
        return
    end
    CMD.del_secret(pack.openId)
end

function CMD.asyn_buy_succ_comp(pack)
    local plat_name = pack.plat_name
    local inform_count = pack.inform_count
    local notify_url = pack.notify_url
    pack.plat_name = nil
    pack.inform_count = nil
    pack.notify_url = nil
    pack.nonce_str = CMD.get_nonceStr()
    pack.timestamp = os.time()

    local sign,string_sign = cqll_signature(pack,nil,plat_name)

    local url_agrs = "sign=".. sign .. "&" .. string_sign
    CMD.push_wait_order(pack.order_id)

    skynet.fork(function()
        local u = url.parse(notify_url)
        local result,status,body = pcall(CMD.post_string,u.authority,u.path,url_agrs)
        if not result or status ~= 200 or body ~= 'Success' then -- 通知失败
            pack.inform_count = inform_count
            pack.notify_url = notify_url
            CMD.push_inform_fail_order(pack,plat_name)
        else
            CMD.del_inform_succ_order(pack.order_id,plat_name)
        end
    end)
end
-- 异步通知支付成功
----------- 通知参数
-- appid 
-- order_id
-- out_trade_no
-- attach
-- succed   -- "Success/Fail"
-- end_time
-- nonce_str
-- timestamp
-- sign
----------- 需要等待返回
function CMD.asyn_buy_succ(order,plat_name)
    assert(order)

    local pack = {
        appid           = order.appid,
        order_id        = order.order_id,
        out_trade_no    = order.out_trade_no,
        total_fee       = order.total_fee,
        attach          = order.attach,
        end_time        = os.time(),
        succed          = "Success",
        notify_url      = order.notify_url,
        plat_name       = plat_name,
        -- nonce_str       = get_nonceStr(),
        -- timestamp       = os.time(),
    }

    CMD.asyn_buy_succ_comp(pack)
end

-- 处理失败的订单
function CMD.process_inform_fail_order()
    local current_time = os.time()
    for _,order in pairs(ServerData.informFailOrders) do
        local inform_count = order.inform_count
        local interval = ServerData.asyn_inform_interval[inform_count]
        if not interval then -- 超出通知时间
            CMD.del_inform_succ_order(order.order_id, order.plat_name, true)
        else
            -- 通知间隔一定得大于通知超时间隔
            if current_time - order.timestamp >= interval then
                CMD.asyn_buy_succ_comp(order)
            end
        end
       
    end
end


-- 创建一个检测 通知失败的订单 的定时器
function CMD.create_check_fail_order()
    timer.create(10 * 100,function()
        CMD.process_inform_fail_order()

        -- del_timout_nonce_str()
    end,-1)
end

-- 初始化失败的订单
function CMD.init_fail_orders()
    for _,plat_name in ipairs(ServerData.game_names) do
        local fail_orders = skynet.call(get_db_mgr(), "lua", "cqll_all_inform_fail_order", plat_name)
        -- local fail_orders = db_mgr.req.cqll_all_inform_fail_order(plat_name)
        if fail_orders and #fail_orders > 0 then
            for _,order in ipairs(fail_orders) do
                CMD.push_wait_order(order.order_id)
                order.plat_name = plat_name
                ServerData.informFailOrders[order.order_id] = order
            end
        end
    end
    
end

function CMD.init()
    ServerData.cs = queue()
    -- httpclient = snax.queryservice("httpclient")

    CMD.init_fail_orders()

    CMD.create_check_fail_order()

end

-- function exit()
--     skynet.error(string.format("%s agent_mgr exit", get_ftime()))
-- end
function CMD.inject(filePath)
    require(filePath)
end

skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
    CMD.init()
end)


