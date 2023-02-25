local sign_util = require "utils.sign_util"
local md5 = require "md5"
local M = {}


M.app_id = "C5E0332E5E3C87236A68111292E61C88"


M.app_key = "3571a218337835d072a74a00809d35e4"

M.secret = "xunyouhongzhongios&Duoyou202006666"

function M:openapi_sign(t)
	t.server_id = nil
	local sign = t.sign
	t.sign = nil
	local tt = sign_util.sort_tbl_by_key(t)
	local base_str = sign_util.sign_table2str(tt)
	base_str = base_str .. "&key=" .. M.secret
	print("base_str =",base_str)
	print("sign =",md5.sumhexa(base_str))
	return sign ==  md5.sumhexa(base_str)
end

return M