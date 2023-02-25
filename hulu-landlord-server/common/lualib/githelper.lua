local M = {}
local mt = {}
mt.author	= "%an"
mt.date 	= "%ad"
mt.message 	= "%s"
function mt.__index(tbl, key)
	local mt_ = getmetatable(tbl)
	local arg = mt_[key]
	if arg then
		local cmd = string.format([[git log  -1  --pretty=format:'%s' --abbrev-commit |awk -F ':' '{print " "  $0 }']], arg)
		local res = io.popen(cmd)
		local str = res:read("all")
		str = string.sub(str, 1, string.len(str) - 1)
		return str
	end
end
setmetatable(M, mt)

return M