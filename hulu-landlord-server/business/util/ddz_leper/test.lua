---------------------------------------------------------------
-- 癞子算法测试文件
---------------------------------------------------------------

local ddz = require "util.ddz_leper"

local cards = {
	0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d,
	0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d,
	0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d,
	0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d,
	0x5e, 0x5f
}

local function print_cards(cards)
	table.sort(cards, function (a, b)
		return ddz.V(a) < ddz.V(b)
	end)

	local s = ""
	for j,c in ipairs(cards) do
		s = s .. string.format("%#03x", c) .. ", "
	end
	s = s:sub(1, #s-2)
	print(s)
end


local function dump_types(types)
	if types then
		for i,t in ipairs(types) do
			local s = ""
			local cards = ""
			for j,c in ipairs(t.cards) do
				cards = cards .. string.format("%#03x", c) .. ", "
			end
			cards = cards:sub(1, #cards-2)

			if t.type == "zhadan" then
				t.weight = (t.weight & 0xf) .. '('..ddz.zhadan_type(t.weight)..')'
			end

			s = s .. "type: " .. t.type .. ", weight: " ..t.weight.." cards: {" .. cards .."}"
			print(s)
		end
	else
		print("invalid type")
	end
end


local function test(n)
	for i=1,n do
		local handcards = table.random_n(cards, math.random(1, 20))
		local ok, err = pcall(ddz.card_types, handcards)
		if ok then
			-- dump_types(err)
		else
			print(i, err)
			print_cards(handcards)
			break
		end
	end
end


local t1 = os.time()
print("TEST leperking start ...")
test(100000)
print("TEST leperking done, use " .. (os.time() - t1) .. "s")