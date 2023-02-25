local skynet = require "skynet"

local httpc = require "http.httpc"
local cjson = require "cjson"

local server_conf = require "server_conf"
local xy_cmd = require "xy_cmd"
local oppo_sdk = require "sdk.oppo_sdk"
local vivo_sdk = require "sdk.vivo_sdk"
local huawei_sdk = require "sdk.huawei_sdk"
local yyb_sdk 	= require "sdk.yyb_sdk"
local xiaomi_sdk 	= require "sdk.xiaomi_sdk"
-- local yyb_sdk 	= require "config.yyb_sdk"
-- local qihoo_sdk	= require "config.qihoo_sdk"
local apple_sdk = require "sdk.apple_sdk"
local wx_sdk = require "sdk.wx_sdk"
local baidu_sdk = require "sdk.baidu_sdk"



require "pub_util"
require "wx_util"
require "ali_util"

require "base.BaseFunc"
local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
ServerData.last_gen_order_time = nil
ServerData.suffix_order = nil



function CMD.init_dns()
	local dns_conf = {host = "114.114.114.114", port = 53}
	httpc.dns(dns_conf.host, dns_conf.port)
end 

function CMD.inject(filePath)
    require(filePath)
end

function CMD.init(  )
	local r, errmsg = pcall(CMD.init_dns)
	if not r then
		skynet.logw("httpc init_dns wrong errmsg=", errmsg)
	end
	skynet.timeout(100, CMD.tick_out)
end

------------------test1 专用文件
local tick_tasks = {
	--测试服 取消微信getAccessToken和支付流程
	--['WX_mini_Game_AccessToken'] = {delay = 60, last = 0}  --1分钟 秒检查一次
}

function CMD.tick_out()
	local now = os.time()
	for cmd, conf in pairs(tick_tasks) do
		local diff = now - conf.last
		if diff > conf.delay then
			local f = CMD[cmd]
			if f then
				local r, err = pcall(f)
				if r and err then
					conf.last = now
				end
			end
		end
	end
	skynet.timeout(100, CMD.tick_out)
end

-- #  curl 'http://127.0.0.1:80/auth_token_or_userinfo?what=auth_token&token=123&openid=888'

-- https://api.mch.weixin.qq.com/mmpaymkttransfers/promotion/transfers

function CMD.post_string(host, url, context, recvheader)
	local header = {
		["content-type"] = "application/x-www-form-urlencoded"
	}
	return httpc.request("POST", host, url, recvheader, header, context)
end



-- 获取一个订单号
function CMD.get_order_num()
	local curr_time = os.time()
	if curr_time ~= ServerData.last_gen_order_time then
		ServerData.last_gen_order_time = curr_time
		-- 首先随机一个数尽量保证数字唯一（服务重启时）
		ServerData.suffix_order = math.random(10000000,59999999)
	else
		ServerData.suffix_order = ServerData.suffix_order + 1
	end
	return ServerData.last_gen_order_time..ServerData.suffix_order
end

-- 代理提现
-- function CMD.apply_cash( openid, name, money )
-- 	print("httpclient apply_cash ==================" , money, type(money))

-- 	local merchant = server_conf.merchant_info[1]

-- 	local t = {
-- 		mch_appid 			= merchant.appid,
-- 		mchid 	  			= merchant.mch_id,
-- 		nonce_str 			= random_string_32(),
-- 		partner_trade_no 	= get_new_order_number(),
-- 		openid 				= openid,
-- 		check_name 			= 'NO_CHECK',
-- 		re_user_name 		= name,
-- 		amount 				= math.floor(money),
-- 		desc 				= '提现',
-- 		spbill_create_ip    = server_conf.server_ip, 
-- 	}

-- 	local xml = tbl2xml_sign(t,merchant.pay_key)
-- 	print(xml)

-- 	local status, body = CMD.post_string("127.0.0.1:80", '/apply_cash', xml)
-- 	return body
-- end

-- -- 第三方请求微信支付
-- function CMD.third_wx_order(pack,ip,plat_name)
-- 	local merchant = server_conf.merchant_info[1]
-- 	local tbl = {
-- 		attach 		 = pack.attach .. ","..plat_name, 				  -- 附加数据, 微信支付成功通知时原样返回
-- 		appid   	 = merchant.appid, 							      -- 应用ID
-- 		mch_id 		 = merchant.mch_id,						          -- 商户ID
-- 		nonce_str    = random_string_32(), 					      	  -- 随机字符串
-- 		body 		 = pack.desc,							          -- 描述
-- 		out_trade_no = pack.out_trade_no, 				          -- 商户系统内部订单号 (基本没用)
-- 		total_fee 	 = math.ceil(tonumber(pack.total_fee) * 100),	                  -- 微信是分, 我们是元
-- 		spbill_create_ip = ip, 								      -- 终端IP (用户端实际ip)
-- 		notify_url = server_conf.notify_url, 				      -- 支付成功通知
-- 		trade_type = 'APP' 									      -- 支付类型
-- 	}

-- 	print("total_fee = ",tbl.total_fee)
-- 	local xml = tbl2xml_sign(tbl,merchant.pay_key)

-- 	local status, body = httpc.post("127.0.0.1:80", '/order', {xml = xml})
-- 	return body
-- end
-- -- 第三方请求支付宝支付
-- function CMD.third_ali_order(pack,ip,plat_name)
-- 	local subject = pack.desc  -- 商品描述信息
-- 	local passback_params = pack.attach .. ","..plat_name -- 附加数据,支付成功通知时原样返回
-- 	local request_url = '/xixiqipai/createOrder?orderNo='..pack.out_trade_no 
-- 						.."&tradeMoney="..pack.total_fee
-- 						.."&subject="..string.urlencode(subject)
-- 						.."&passback_params="..string.urlencode(passback_params)
-- 	print("=================request_url================")
-- 	local status, body = httpc.get("127.0.0.1:8085", request_url)
-- 	return body
-- end

function CMD.ip2city( ip )
	local city = ""
	local status, body = httpc.post("127.0.0.1:80", '/ip', {ip = ip})
	local result,t = pcall(cjson.decode,body)
	--local t = cjson.decode(body)
	if result and  t.code == 0 then
		city = t.data.region..t.data.city
		city = string.gsub(city, "省", "")
		city = string.gsub(city, "市", "")
	end
	return city
end

function CMD.get(...)
	return httpc.get(...)
end

function CMD.auth_token(sdk, args)
	args.what = "auth_token"
	args.sdk = sdk

	local status, body = httpc.post("127.0.0.1:80", "/auth_token_or_userinfo", args)
	print(status, body)

	if status == 200 then
		local ok, t = pcall(cjson.decode, body)
		if ok then
			if sdk == 'wechat' then
				if t.errmsg == 'ok' then
					return true
				else
					return false, t.errmsg
				end
			elseif sdk == 'oppo' then
				return oppo_sdk.check_resp(t)
			elseif sdk == 'vivo' or sdk == "vivoad" then
				if tonumber(t.retcode) == 0 then
					return true, t.data
				else
					return false, t.retcode
				end
			elseif sdk == "huawei" then
				return huawei_sdk.check_resp(t)
			elseif sdk == "yyb" then
				return yyb_sdk.check_resp(t)
			elseif sdk == "qihoo" then
				return qihoo_sdk.check_resp(t)
			elseif sdk == "apple" then
				return apple_sdk.check_resp(t,args)
			end
		else
			return false, t
		end
	end
	return false, 'status ~= 200'
end

function CMD.auth_token_self(sdk, args)
	args.what = "auth_token"
	args.sdk = sdk
	if sdk == 'oppo' then
		return oppo_sdk.auth_token(args)
	elseif sdk == 'vivo' then
		return vivo_sdk.auth_token(args)
	elseif sdk == 'huawei' then
		return huawei_sdk.auth_token(args)
	elseif sdk == 'yyb' then
		return yyb_sdk.auth_token(args)
	elseif sdk == 'xiaomi' then
		return xiaomi_sdk.auth_token(args)
	elseif sdk == "apple" then
		return apple_sdk.auth_token(args)
	elseif sdk == "wechat" then
		return wx_sdk.auth_token(args)
	elseif sdk == "baidu" then
		return baidu_sdk.auth_token(args)
	end
end


function CMD.userinfo( openid, token )

	if type(token) ~= 'string' and type(openid) ~= 'string' then
		return
	end

	local status, body = httpc.post("127.0.0.1:80", "/auth_token_or_userinfo", {
		what = "userinfo",
		openid = openid,
		token = token
	})

	if status == 200 then
		local result,info = pcall(cjson.decode,body)
		if result and info.errcode then
			return false, info.errcode
		else
			return true, info
		end
	end
end

function CMD.version( )
	local status, body = httpc.get("127.0.0.1:80", "/file_ver.json")
	return body
end

function CMD.reg_ip(reg_ip)
    local status, channel = httpc.get('hzmj.xixiqipai.com','/hzmj/insertRegisterSuccess?ip='..reg_ip)
    print('=============reg_ip=====',status, channel)
    if status == 200 and channel ~= "error" and channel ~= "" then
    	return channel
    end
end


-- 短信验证码
function CMD.get_verify_code(num,code)
	local pack = {
		AccessKeyId = server_conf.accessKeyId,
		Timestamp = os.date('%Y-%m-%dT%H:%M:%SZ',os.time() - 8*3600), -- -8小時，时区问题
		--Format = 'XML',
		SignatureMethod = 'HMAC-SHA1',
		SignatureVersion = '1.0',
		SignatureNonce	= CMD.get_order_num(),
		Action = 'SendSms',
		Version = '2017-05-25',
		RegionId = 'cn_hangzhou',
		PhoneNumbers = num,
		SignName = server_conf.signName,
		TemplateCode = server_conf.templateCode,
		TemplateParam = cjson.encode({code = code}),
	}
	pack.Signature = compute_signature(pack,server_conf.accessKeySecret)

	local sign = pack.Signature
	skynet.fork(function()
		httpc.get('dysmsapi.aliyuncs.com',"/?Signature="..sign)
	end)
end

-- aliyun oss sdk---------------------
-- command    -- 命令  -- put_object  delete_object  put_bucket  put_bucket_acl  delete_bucket
-- bucket     -- 存储空间名
-- content    -- 上传对象的内容
-- filetype   -- 上传对象 文件类型
-- filename   -- 上传对象 文件名称
-- acl        -- 上传对象 文件权限
function CMD.aliyun_oss(pack)
	pack.accessKey  = server_conf.ossAccessKey
	pack.secretKey  = server_conf.ossSecretKey
	pack.endpoint   = server_conf.ossEndpoint
	skynet.fork(function()
		local status, body = httpc.post("127.0.0.1:80",'/oss',pack)
	end)
end





--心跳检查QQ小游戏的 qq_minigame
function CMD.WX_mini_Game_AccessToken()
	-- print("wx_sdk.WX_mini_Game_AccessToken")
	if not wx_sdk.access_token_vaild() then
		local get_url = string.format(wx_sdk.url_getAccessToken, wx_sdk.get_app_id(),wx_sdk.app_secret)
		--print("====wx accesstoken : ",wx_sdk.host..get_url)
		local status, body = httpc.get(wx_sdk.host,get_url)
		print("WX_mini_Game_AccessToken post back :  = =====",status,body)
		if status == 200 then
			body = cjson.decode(body)
			--table.print(body)
			if body.errcode ==nil then
				wx_sdk.update_access_token(body.access_token, body.expires_in)	
				
				--test 拉取一次用户session_key
				-- CMD.WX_code2Session("071i3S000SSj3M13KU0002X0ir0i3S0f")
				
				--(openid,type,act_name,total_fee,wishing)	
				--CMD.QQ_minigame_hb_send("E9C9A2A3F52868CF4A2511A776608B2C",1,"qqwallet_test",0.01,"大吉大利")
				return true
			else
				skynet.loge("errcode =>", body.errcode, ";msg =>", body.errmsg)
			end
		else
			skynet.loge("get access token err")
		end
		print("WX_mini_Game_AccessToken complete")
		return false
	else
		return true
	end
end

--QQ小游戏 获取用户session_key
--参数 openid  (id,id,id...)
function CMD.WX_code2Session(code)
	local get_url = string.format(wx_sdk.url_code2Session, wx_sdk.get_app_id(),wx_sdk.app_secret,code)
	print("====wx code2Session : ",wx_sdk.host..get_url)	
	local status, body = httpc.get(wx_sdk.host,get_url)
	print("WX_code2Session post back :  = =====",status, body)
	if status == 200 then
		body = cjson.decode(body)
		--table.print(body)
		if body.errcode ==nil then
			print("WX_code2Session succ ")
			table.print(body)
			return body
		else
			skynet.loge("errcode =>", body.errcode, ";msg =>", body.errmsg)
		end
	else
		skynet.loge("get session_key err")
	end	
	return nil
end


--QQ小游戏 SDK 提现接口
function CMD.QQ_minigame_hb_send(openid,type,act_name,total_fee,wishing)	
	local args = {}
	args.appid = wx_sdk.get_app_id()
	args.openid = openid
	args.act_name = act_name
	args.wishing = wishing
	args.total_fee = total_fee
	args.redirect_uri = "https://xyminigame.cn/qq_mini_hb_send_back" --回调地址
	local sign = wx_sdk.sign_qq_sdk(args) --qqSDK sign签名
	args.sign = sign

	print("QQ_minigame_hb_send args")
	table.print(args)
	
	if type ==1 then
		local status, body = httpc.post(wx_sdk.get_host(), "/api/qpay_hb_mch_send", args)
		print(type, " =type QQ_minigame_hb_send post back :  = =====",status, body)
		return status, cjson.decode(body)
	elseif type ==2 then
		local status, body = httpc.post(wx_sdk.get_host(), "/api/login_hb_send", args)
		print(type," =type QQ_minigame_hb_send post back :  = =====",status, body)
		return status, cjson.decode(body)
	else 
		skynet.loge("QQ_minigame_hb_send type error",type)
	end	
end



skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
    CMD.init()
end)

