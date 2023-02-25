local function ALIAS(t)
	local t1 = {}
	for k,v in pairs(t) do
		t1[v] = k
	end

	return setmetatable(t, {__call = function (_, k)
		return t1[k] or t[k]
	end})
end

GAMETYPE = ALIAS{"noshuffle", "classic", "sevensparrow"}

ROOMTYPE = ALIAS{"xinshou", "zhongji", "gaoji", "zhizun"}


COMMID = ALIAS{
	[25] = "bawangka_diamond",
	[27] = "cj_jiabei_diamond",
	[28] = "fd_fanbei_diamond",
	[124] = "yearcard",
}