local skynet = require "skynet"
require "define"
require "table_util"
local httpc = require "http.httpc"
local cjson = require "cjson"
local xy_cmd  = require "xy_cmd"

local mycrypt = require "utils.mycrypt"
local crypt = require "skynet.crypt"
local cjson = require "cjson"
local sign_util = require "utils.sign_util" 

local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data
ServerData.init = function ()
end

local M = {}
M.AppId = "6186ba735dfa476faff9bbeec4ae21b8"
M.BizId = "1104011481"
M.secret = "5c9b3ab6299a931593d374885787eb12"

-- --红中
-- M.AppId = "1ff61d9d9e3747e8835d2312e1b419c8"
-- M.BizId = "1104002551"
-- M.secret = "eebd9b948cdec5f43d77903b849a21e6"

-- M.AppId_test = "a88abf5ab2204dd79b3d16531a621b3d"
-- M.BizId_test = "1101999999"
-- M.secret_test = "95e60bae456d5c8293928bed6111934b"

M.trim = function(input)
    input = string.gsub(input, "^[ \t\n\r]+", "")
    return string.gsub(input, "[ \t\n\r]+$", "")
end

-- 生成签名
 M.sign =function(header,data,subdata)
	local args
	if subdata then
		args = table.clone(header)
		for k,v in pairs(subdata) do
			args[k] = v
		end
	else
		args = header
	end

	local tt = sign_util.sort_tbl_by_key(args)

	local str = ""
	for _,v in ipairs(tt) do
		str = str .. v.k .. v.v
	end

	if data then
		str = str .. data
	end
	str = M.secret .. str
	return mycrypt.sha256(str)
end

-- 获取请求header
M.get_header =function(data,subdata)
	local header = {
		-- ["Content-Type"] = "application/json;charset=utf-8",
		["appId"] = M.AppId,
		["bizId"] = M.BizId,
		["timestamps"] = string.format("%d",skynet.time() * 100 * 10), -- 毫秒
	}

	local sign = M.sign(header,data,subdata)

	header["Content-Type"] = "application/json;charset=utf-8"

	header.sign = sign

	return header
end

-- 生成实名认证请求接口 游戏账户唯一内部标识 32 位
M.gen_ai=function(gid,rn_count)
	local len = 0
	if rn_count then
		len = #tostring(rn_count)
	end

	local diff = 32 - len - #gid

	local ai 
	if not ishzpalm then
		ai = string.rep("0",diff) .. gid
	else
		ai = string.rep("x",diff) .. gid
	end

	if rn_count then
		ai = rn_count .. ai
	end

	return ai 
end

function M.query()
	local args = {}
	args.ai = "300000000000000001" --{"ai":"100000000000000001"}
	args.pid = ""
	args.uid = ""

	-- local ai = args.ai or gen_ai(args.pid,args.rn_auth_count)
	local ai = args.ai or M.gen_ai(M.AppId, args.uid)

	local header = M.get_header(nil,{
		ai =  ai--args.ai or CMD.gen_ai(args.pid),
	})

	local req = {
		data = cjson.encode({
			ai = ai,
		}),
		secret = M.secret
	}

	-- 请求加密数据
	local ok, status, data1 = pcall(httpc.post,"127.0.0.1:8080","/cipher",req)
	if not ok or status ~= 200 or not data1 then
		skynet.error("request nginx cipher error!")
		return RN_ERR.ENC_ERR 	-- 数据加密错误
	end

	data1 = M.trim(data1)

	local data2 = cjson.encode({data = data1})
	local recHeader = {}
	-- header.url = "https://wlc.nppa.gov.cn/test/authentication/query/NNyzJ7?ai="..ai
    header.url = "http://api2.wlc.nppa.gov.cn/idcard/authentication/query?ai="..ai
	header.method = "GET"
	local ok = true
	
	local status,body =  httpc.request("POST","127.0.0.1:8080","/https_trans",nil,header)
	
	-- TODO 结果处理
	if status ~= 200 or not ok then
		return RN_ERR.REQ_ERR
	end

	body = cjson.decode(body)

	if body.errcode == 0 then
		return RN_ERR.SUCC,body.data.result
	else
		return RN_ERR.SUCC,{status = 2} ,body.errcode-- errcode ~= 0,则直接返回认证失败
	end

end

function M.loginout(args)
    if not args then
        return false
    end
	-- local args = {}
    -- args.no = 103   --int
    -- args.si = args.no .. tostring(os.time())  --string
    -- args.bt = 1--int
	-- args.ot = os.time()--Long
	-- args.ct = 2--int
	-- args.di = "1fffbl6st3fbp199i8zh5ggcp84fgo3r"--string
	-- args.pi = "1fffbl6st3fbp199i8zh5ggcp84fgo3rj7pn1y"--string

	local req = {
		no = args.no,
		si = args.si,
		bt = args.bt,
		ot = args.ot,

		ct = args.ct,
		di = args.di,
		pi = args.pi,
	}

	local reqList = {}
	reqList[1] = req

    local req_data = {
		data = cjson.encode({
			collections = reqList,
		}),
		secret = M.secret
	}


	-- 请求加密数据
	local ok, status, data = pcall(httpc.post,"127.0.0.1:8080","/cipher",req_data)
	if not ok or status ~= 200 or not data then
		skynet.error("request nginx cipher error!")
		return RN_ERR.ENC_ERR 	-- 数据加密错误
	end

	data = M.trim(data)

	local data = cjson.encode({data = data})

	local header = M.get_header(data)
		
	local ok1, status1, data1 = httpc.request("POST", "127.0.0.1:8080","/loginout", nil, header, data)
	-- TODO 结果处理
	if status1 ~= 200 or not ok1 then
		return RET_VAL.Fail_2
	end

end

M.CheckRealName = function (args)
    if not args then
        return false
    end
    -- local args = {}
    -- args.uid = "hl100000000002"
    -- args.name = "xxx"
    -- args.cardId = "410xxxxxxxxxxxxxxX"

    local req = {
		data = cjson.encode({
			ai = args.uid,
			name = args.name,
			idNum = args.cardId,
		}),
		secret = M.secret
	}

	-- 请求加密数据
	local ok, status, data = pcall(httpc.post,"127.0.0.1:8080","/cipher",req)
	if not ok or status ~= 200 or not data then
		skynet.error("request nginx cipher error!")
		return RN_ERR.ENC_ERR 	-- 数据加密错误
	end

	data = M.trim(data)
	local data = cjson.encode({data = data})
	local header = M.get_header(data)
	local status, results = httpc.request("POST", "127.0.0.1:8080","/check_realname", nil, header, data)
	-- TODO 结果处理
	if status ~= 200 or not results then
		return RET_VAL.Fail_2
	end

	local result = cjson.decode(results)
	if not result or result["errcode"] ~= 0 then
		skynet.error("CheckRealName, uid=", args.uid, ", results=", results)
		return RET_VAL.Fail_2
	end

	local r_data = result["data"]
	if r_data then
		local data_result = r_data["result"]
		if not data_result then
			skynet.error("CheckRealName, uid=", args.uid, ", data_result=", results)
			return RET_VAL.Fail_2
		end

		local r_status = data_result["status"]
		local r_pi = data_result["pi"]
		return RET_VAL.Succeed_1, r_status, r_pi
	end

    return RET_VAL.Fail_2
end

CMD.CheckRealName = function (_, args)
    return  M.CheckRealName(args)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(source, ...)))
    end)
    ServerData.init()
end)