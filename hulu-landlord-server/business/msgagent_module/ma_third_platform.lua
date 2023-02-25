local ma_third_platform = {}
local skynet = require "skynet"

local ma_data = require "ma_data"
require "define"

local request = {}

-- 获取第三方平台(传奇来了)登录凭证(PS:需要测试重入)
function request:get_third_platform_proof()
	return cs(function()
		if ma_data.server_will_shutdown then
			return {result = false, e_info = ERROR_INFO.Server_will_shutdown}
		end

		self.platform_name = self.platform_name or 'cqll'
		-- 传奇来了
		local login_url,openId,appsecret = skynet.call("t_plat_valid", "lua", "get_login_proof", self.platform_name,ma_data.my_id,secret)
		-- local login_url,openId,appsecret = third_platform_valid.req.get_login_proof(self.platform_name,my_id,secret)
		-- assert(login_url,'第三方登录平台类型错误')
		if not login_url then
			return {result = false}
		end
		
		return {
					result = true,
					login_url = login_url,
					appsecret= appsecret,
					openId= openId,
					platform_name= self.platform_name,
				}
	end)

end

-- 第三方平台 请求支付字符串
function request:get_tp_order_str()
	if ma_data.server_will_shutdown then
		return {result = false, e_info = ERROR_INFO.Server_will_shutdown}
	end
	local order_str,pay_type = skynet.call("t_plat_valid", "lua", "get_order_str", self.order_id,self.pay_type,ma_data.db_info.last_ip)
	-- local order_str,pay_type = third_platform_valid.req.get_order_str(self.order_id,self.pay_type,db_info.last_ip)
	if not order_str then
		return {result = false}
	end
	return {result = true,order_str = order_str,pay_type = pay_type}
end

-- 第三方平台 查詢支付状态
function request:query_order_state()
	local state = skynet.call("t_plat_valid", "lua", "query_order_state", self.order_id)
	-- local state = third_platform_valid.req.query_order_state(self.order_id)
	return {state = state}
end

function ma_third_platform.init(REQUEST,CMD)
	if request then
        table.connect(REQUEST,request)
    end
    if cmd then
        table.connect(CMD,cmd)
    end
end

return ma_third_platform