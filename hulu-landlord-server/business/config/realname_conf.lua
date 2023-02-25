local M = {}


-- SK0000001890
M.appid = "1ff61d9d9e3747e8835d2312e1b419c8"
M.secret = "605175d3e130931303af4ca3cdb8a883"
M.bizId = "1104002551"--"1101999999"

-- 忽略实名认证的渠道 优先最高
M.ignore_channel = {	
	hzmjlx_vivo		= true,
	hzmjlx_vivoad	= true,
	hzmjlx_oppo		= true,
	hzmjlx_oppoad	= true,
	hzmjlx_huawei	= true,
	hzmjlx_mi		= true,
	hzmjlx_YSDK		= true,
	hzmjlx_vivoad	= true,
	hzmjlx_qihoo	= true,
	hzmjlx_duoyou	= true,
	hzmjlx_taoshouyou	= true,
	hzmjlx_baidu		= true,
	hzmjlx_lenovo		= true,
	hzmjlx_233		= true,
	hzmjlx_youjiu 	= true,
	h5hzmjxl_qq = true, --qq小游戏渠道
	h5hzmjxl_wx = true, --wx小游戏渠道
	h5hzmjxl = true, --默认web渠道
	
}

-- 强制实名认证的渠道,当有need_auth 字段时,只认证其中含有的渠道
M.need_auth = {
	hzmjlx_formal15 = true, -- 仲勋渠道
	ks_kuaishou2 = true,	-- 
	h5hzmjxl_test 	= true,
	h5hzmjxl_qq = false, --qq小游戏渠道
	h5hzmjxl_wx = false, --wx小游戏渠道
	h5hzmjxl = false,--默认web渠道
}

return M