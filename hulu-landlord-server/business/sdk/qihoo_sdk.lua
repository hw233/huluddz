local M = {}


function M.check_resp(t)
	if not t.error_code and t.id then
		return true, t
	else
		return false, t.error or ""
	end
end

return M