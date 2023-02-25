local skynet = require "skynet"

local xy_cmd = require "xy_cmd"
local CMD,ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data

function CMD.process_buy_suc(data,p_agent)
	local orderNo = data.out_trade_no
	local transaction_id = data.transaction_id
	print('====================process_buy_suc=========',data.out_trade_no)


	local pre_order = skynet.call(get_db_mgr(), "lua", "find_one", COLL.PRE_ORDER, {out_trade_no = orderNo})
	
	if not pre_order then
		return {ok = true}
	end

	local p = skynet.call(get_db_mgr(), "lua", "get_user_info", pre_order.pid)
	local mall_id = pre_order.mall_id

	local coll_name = data.sandbox ~= "sandbox" and COLL.ORDER or COLL.ORDER_SANDBOX

	local p_agent = skynet.call("agent_mgr", "lua", "find_player", p.id)

	if skynet.call(get_db_mgr(), "lua", "find_one", coll_name, {transaction_id = transaction_id}) then
		if p_agent and pre_order.platform == "applepay" then
			skynet.send(p_agent,"lua","apple_buy_suc",data.transaction_id,orderNo,data.sign)
		end
		return {ok = true}
	end

	
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
		os = p.os,
		nickname = p.nick_name,
		channel = p.channel,
		mall_id = mall_id,
		transaction_id = transaction_id,
		out_trade_no = pre_order.out_trade_no,
		time_end = os.time(),
		total_fee = pre_order.price,
		platform = pre_order.platform,
	})

	return {ok = true},p_agent
end