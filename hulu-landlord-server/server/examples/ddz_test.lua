--经典斗地主 算法单元测试
package.cpath = "luaclib/?.so"
package.path = "lualib/?.lua;../business/utils/?.lua;../business/util/ddz_classic/?.lua;../business/?.lua;../business/game/robot/classic/?.lua"
-- local qique = require "init"
require "preload.table"
local helper = require "init"
--local split_cards = require "split_cards"
require "lua_utils"
require "table_util"


local function create_two_pair_cards1()
	return {
		0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d,
		0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d,
		0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d,
		0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d,
		0x5e, 0x5f,
	}
end

local function create_two_pair_cards()
	return {
		0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d,
		0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d,
		0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d,
		0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d,
		0x5e, 0x5f,

		0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d,
		0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d,
		0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d,
		0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d,
		0xae, 0xaf
	}
end


local function test_flush()
    local test_cards = {0x11, 0x14, 0x15, 0x16, 0x17}
    print("顺子测试结果 : ",helper.check_flush(test_cards,2))

	local test_cards = {0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17}
    print("顺子测试结果 : ",helper.check_flush(test_cards,2))
end

local function is_5x2lianzha()
	local test_cards = {17,33,49,65,97,18,34,50,66,98}
	local fuc = require "is_5x2lianzha"
	print("测试5星2连炸")
	table.print(fuc(test_cards))
end

local function is_feiji_budai()
	local test_cards = {17,33,49,18,34,50,19,35,51}
	local fuc = require "is_feiji_budai"
	print("测试飞机不带")
	table.print(fuc(test_cards))
end

local function is_feiji_daidan()
	--local cards = {0x12,0x22,0x32, 0x13,0x23,0x33, 0x14,0x24,0x34, 0x17,0x27,0x37}
	--local cards = {0x33,0x23,0x13,0x43, 0x37,0x27,0x17, 0x36,0x26,0x16, 0x35,0x25,0x15, 0x34,0x24,0x14}
	local cards = {0x37,0x27,0x17, 0x35,0x25,0x15, 0x34,0x24,0x14, 0x31,0x21,0x11}
	--local cards = {0x47,0x45,0x44, 0x36,0x26,0x16, 0x35,0x25,0x15, 0x34,0x24,0x14}
	print("测试飞机带单张")
	table.print(helper.parseCardTypeOnly(cards))
end


local function is_feiji_daidui()
	local cards = {0x11,0x21,0x31, 0x12,0x22,0x32, 0x13,0x23,0x33, 0x14,0x24, 0x15,0x25, 0x16,0x26}
	print("测试飞机带对子")
	table.print(helper.parseCardType(cards))
end

local function is_liandui()
	local test_cards = {17,33,18,34,19,35}
	local fuc = require "is_liandui"
	print("测试连对")
	table.print(fuc(test_cards))
end

local function is_lianzha()
	local cards = {0x11,0x21,0x31,0x41,0x12,0x22,0x32,0x42}
	print("测试连炸")
	table.print(helper.parseCardType(cards))
end

local function is_sandaiyi()
	local cards = {0x44, 0x28, 0x32, 0x22}
	--local test_cards = {68, 40, 50, 34}
	print("测试3带1")
	table.print(helper.parseCardType(cards))
end

local function is_sandaiyidui()
	local cards = {0x4c,0x2c,0x1c, 0x31,0x21}
	--local cards = {0x25,0x45,0x35, 0x11,0x41}
	print("测试3带一对")
	table.print(helper.parseCardTypeOnly(cards))

	print("3带一对大小比较", not not helper.compareCardType(helper.parseCardTypeOnly({0x4c,0x2c,0x1c, 0x31,0x21}), helper.parseCardTypeOnly({0x25,0x45,0x35, 0x11,0x41})))
end

local function is_shunzi()
	-- local test_cards = {17,18,19,20,21,22}
	local test_cards = {17,34,51,68,53,38,23,}
	local fuc = require "is_shunzi"
	print("测试顺子")
	table.print(fuc(test_cards))
end

local function is_sidaier()
	local test_cards = {17,33,49,65,50,51}
	-- local test_cards = {17,33,49,65,67,51}
	local fuc = require "is_sidaier"
	print("测试4带2")
	table.print(fuc(test_cards))
end

local function is_sidailiangdui()
	--local cards = {0x11,0x21,0x31,0x41, 0x13,0x23,0x33,0x43}
	local cards = {0x11,0x21,0x31,0x41, 0x12,0x22,0x32,0x42}
	print("测试4带2对")
	table.print(helper.parseCardType(cards))
end

local function is_zhadan()
	-- local test_cards = {17,33,49,65}
	-- local test_cards = {17,33,49,65,97}
	local test_cards = {17,33,49,65,97,113}
	local fuc = require "is_zhadan"
	print("测试各种炸弹")
	table.print(fuc(test_cards))
end

local function is_dan()
	local cards = {0x11}
	print("测试单张")
	
	table.print(helper.parseCardType(cards))
end


local function is_tuple()
	local test_cards = {22,38,54}
	local fuc = require "is_tuple"
	print("测试三张")
	table.print(fuc(test_cards))
end

local function is_dui()
	local test_cards = {22,38}
	local fuc = require "is_dui"
	print("测试对")
	table.print(fuc(test_cards))
end

local function main()
    -- test_flush()
	-- is_5x2lianzha()
	-- is_feiji_budai()
	is_feiji_daidan()
	is_feiji_daidui()
	-- is_liandui()
	is_lianzha()
	is_sandaiyi()
	is_sandaiyidui()
	-- is_shunzi()
	-- is_sidaier()
	is_sidailiangdui()
	-- is_zhadan()
	is_dan()
	-- is_tuple()
	-- is_dui()

    -- local test_cards = {0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17}
    -- local test_cards = {27,107,123,28,44,25,41}
    -- local test_num=1
    -- local time1 = os.time()
    -- for i=1,test_num do
    --     -- t_hu_which() -- 算法平均耗时0.44s
    --     t_hu_infer(test_cards) --算法平均耗时0.02s
    -- end
    -- print("算法耗时预算 :",(os.time()-time1)/test_num)

	local cards = create_two_pair_cards1()

	function RandSort(t)
		math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)))

		local arr = {}
		for index, value in ipairs(t) do
			arr[index] = {val = value, qq = math.random(1,#t)}
		end
		table.sort(arr, function (a, b)
			return a.qq > b.qq
		end)

		for index, value in ipairs(arr) do
			t[index] = value.val
		end
	end

	RandSort(cards)
	print(table.tostr(cards))
	
	-- local type_list, three_list, dui_list, dan_list = split_cards(table.slice(cards, 1, 17))

	-- print(table.tostr(type_list))
	-- print(table.tostr(three_list))
	-- print(table.tostr(dui_list))
	-- print(table.tostr(dan_list))


end


main()

