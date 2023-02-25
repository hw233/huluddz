local skynet = require "skynet"
local snax = require "skynet.snax"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local httpc = require "http.httpc"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local cjson = require "cjson"
local table = table
local string = string
local cluster = require "skynet.cluster"
local md5 = require "md5"
local timer = require "timer"

require "table_util"

local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
ServerData.agent = {}
ServerData.order = {}

local mode, httpserver, SERVER_ID = ...

function CMD.inject(filePath)
	print("httpserver inject ", filePath)
    require(filePath)
    if mode ~= "agent" then
    	for _,agent in pairs(ServerData.agent) do
    		skynet.send(agent, "lua", "inject", filePath)
    	end
    end
end


if mode == "agent" then


--QQ红包提现异步回调
function CMD.bh_send_suc(data)
	--验签sign 根据sdk规则验签
	local retCode = 1 --验签失败
	-- print("type data" ,type(data))
	print('====================bh_send_suc=========', table.tostr(data))
	table.print(data)

	--更新数据记录
	if data~=nil and data.out_trade_no then
		local record = {				
			state = 1,               
			comp_time = nil,         --审核完成时间
			recive_time = nil,       --用户领取时间
		}
	
		if data.type == "hb" then
			record.state = 3 --订单状态 1已领取，2 审核中,3审核通过未领取
			record.comp_time = data.create_time
		elseif data.type == "hb_notify" then
			record.state = 1 
			record.recive_time = data.create_time
		end
	
		skynet.send(get_db_mgr(), "lua", "update_qq_hb_withdrawal",data.out_trade_no,record)
	else
		skynet.loge("===bh_send_suc=== error! rsp data is nil !")
	end	

	--默认成功返回
	retCode=0
	return {code=retCode,message="success"}
end

--第三方支付回调 qq minigame SdkV3 modify by qc 2021.7.7
--购买成功 第三方回调 QQ用  VX不用
function CMD.process_buy_suc(data,p_agent)
	--todo 等待wx支付回调
	--验签sign 根据sdk规则验签
	local retCode = 1 --验签失败	
	if not wx_sdk.payapi_sign(data) then
		return {code=retCode,message="sign error"}
	end

	local pay_status = data.pay_status
	if pay_status ~= 1 and pay_status ~= "1" then
		retCode = 3 --支付状态未完成
		return {code=retCode,message="pay_status  error"}
	end
	

	local orderNo = data.order_sn
	--local transaction_id = data.transaction_id	
	
	print('====================process_buy_suc=========', table.tostr(data))

	local pre_order = skynet.call(get_db_mgr(), "lua", "find_one", COLL.PRE_ORDER, {out_trade_no = orderNo})
	print("pre_order =>", table.tostr(pre_order))
	if not pre_order then
		retCode = 2 --订单不存在
		return {code=retCode,message="not exits order"}
	end

	if pre_order.status == 2 then
		retCode = 0 --已完成订单 但是按照sdk要求 返回成功
		return {code=retCode,message="success"}
	end

	
	local extra_info = data.extra_info
	if extra_info ~= nil and extra_info ~= pre_order.out_trade_no.."_"..math.ceil(data.pay_amount) then
		retCode = 4 --参数不匹配
		return {code=retCode,message="extra_info  error"}
	end	

	-- 更新 pre_order status = 2
	skynet.send(get_db_mgr(), "lua", "update", COLL.PRE_ORDER, 
		{_id = pre_order._id}, 
		{ status = 2 })

	local p = skynet.call(get_db_mgr(), "lua", "get_user_info", pre_order.pid)
	local mall_id = pre_order.mall_id

	local coll_name = data.sandbox ~= "sandbox" and COLL.ORDER or COLL.ORDER_SANDBOX

	local p_agent = skynet.call("agent_mgr", "lua", "GetPlayerAgent", p.id)
	if p_agent then
		skynet.call(p_agent, 'lua', 'buy_suc', mall_id,data.sandbox,orderNo)
		if pre_order.platform == "applepay" then
			skynet.send(p_agent,"lua","apple_buy_suc",data.transaction_id,orderNo,data.sign)
		end
	else
		skynet.call(get_db_mgr(), "lua", "push", COLL.USER, {id = p.id}, "buy_suc_packs", {
			mall_id = mall_id,
			sandbox = data.sandbox,
			platform = pre_order.platform,
			transaction_id = transaction_id,
			sign 		= data.sign,
			out_trade_no =   orderNo,
		})
	end

	-- 完成订单
	skynet.send(get_db_mgr(), "lua", "insert", coll_name, {
		pid = p.id,
		os = pre_order.os,
		nickname = p.nick_name,
		channel = p.channel,
		mall_id = mall_id,
		transaction_id = transaction_id,
		out_trade_no = pre_order.out_trade_no,
		time_end = os.time(),
		total_fee = pre_order.price,
		platform = pre_order.platform,
		pf = pre_order.pf
	})
	--成功返回
	retCode=0
	return {code=retCode,message="success"},p_agent
end

function CMD.buy_suc(data)
	local result,p_agent = CMD.process_buy_suc(data)
	return result
end



function CMD.apple_order_res(data)
	local p_agent = skynet.call("agent_mgr", "lua", "GetPlayerAgent", data.pid)

	if p_agent then
		skynet.send(p_agent,"lua","apple_pay_err",data.result,data.sign,data.transaction_id)
	end
end

-- 穿山甲广告回调成功
function CMD.pangle_succ(data)
	local isExits = skynet.call(get_db_mgr(), "lua", "rec_find_one", COLL.PANGLE_REC, {trans_id = data.trans_id})
	
	if isExits and not data.pid then
		return {ok = true}
	end

	local p_agent = skynet.call("agent_mgr", "lua", "GetPlayerAgent", data.pid)

	if p_agent then
		skynet.call(p_agent, 'lua', 'video_ad_report', data.trans_id,data.reward_name)
	else
		skynet.call(get_db_mgr(), "lua", "push", COLL.USER, {id = data.pid}, "pangle_suc_packs", {
			trans_id = data.trans_id,
			reward_name = data.reward_name,
		})
	end

	local p = skynet.call(get_db_mgr(), "lua", "get_user_info", data.pid)

	if not p then
		return {ok = true}
	end
	-- 插入记录
	skynet.send(get_db_mgr(), "lua", "rec_insert", COLL.PANGLE_REC, {
		pid = p.id,
		nickname = p.nick_name,
		channel = p.channel,
		trans_id = data.trans_id,
		reward_name = data.reward_name,
		time_end = os.time(),
	})

	return {ok = true}
end

function CMD.response(id, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
	if not ok then
		-- if err == sockethelper.socket_error , that means socket closed.
		skynet.error(string.format("fd = %d, %s", id, err))
	end
end

function CMD.handle_socket(id)
	socket.start(id)

	-- limit request body size to 8192 (you can pass nil to unlimit)
	local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
	if code then
		if code ~= 200 then
			CMD.response(id, code)
		else

			-- local path, query = urllib.parse(url)
			print(url)
			print(type(body))
			table.print(body)
			
			if url ~= '/php.action' and url ~= '/realphp.action' 
					and url ~= '/h5php.action' or #body ==0 then
				print('invalid client from:', url)
				socket.close(id)
				return
			end
			local body = cjson.decode(body)

			assert(CMD[body.cmd])
			local f = CMD[body.cmd]
			assert(type(body.args) == 'table')

			local rs = f(body.args)

			rs = cjson.encode(rs)

			CMD.response(id, code, rs)
		end
	else
		if url == sockethelper.socket_error then
			skynet.error("socket closed")
		else
			skynet.error(url)
		end
	end
	socket.close(id)
end

skynet.start(function()

	skynet.dispatch("lua", function(session, source, command, ...)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(...)))
	end)
end)

else

skynet.start(function()

	local httpserver = skynet.self()
	for i= 1, 5 do
		ServerData.agent[i] = skynet.newservice(SERVICE_NAME, "agent", httpserver, i)
	end
	local balance = 1
	local port = skynet.getenv("http_server_port")
	local id = socket.listen("0.0.0.0", port)
	skynet.error("Listen web port:" .. port)

	skynet.dispatch("lua", function(session, source, command, ...)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(...)))
	end)

	socket.start(id , function(id, addr)
		skynet.error(string.format("httpserver:[%s] %s connected, pass it to agent :%08x",os.date(),addr, ServerData.agent[balance]))
		skynet.send(ServerData.agent[balance], "lua", "handle_socket", id)
		balance = balance + 1
		if balance > #ServerData.agent then
			balance = 1
		end
	end)
end)

end