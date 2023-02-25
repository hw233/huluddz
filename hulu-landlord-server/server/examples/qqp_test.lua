--七雀牌算法单元测试
package.cpath = "luaclib/?.so"
package.path = "lualib/?.lua;../business/?.lua;../business/game/tools/?.lua;../business/util/qique/?.lua;../business/utils/?.lua"
-- local qique = require "init"
require "config/define"
local sc = require "small_type_c"
local mtc = require "multiple_type_c"
local util = require "util.qique.init"
require "lua_utils"
require "table_util"



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

--组合算法
local function t_zuhe()
    local cards,num
    cards = {0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18}
    local ret_zuhe = sc.tableCom.zuhe(cards,7)
    print("组合算法结果 : ===")
    table.print(ret_zuhe)
    print("\n")
end

--移除指定牌面
local function t_remove_value()
    local cards,num
    cards = {0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x66, 0x64}
    print("移除指定牌面 begin: ===")
    table.print(cards)

    local c = sc.removebyvalue(cards,0x64)
    print("移除指定牌面 step1: === ",0x64)
    table.print(cards)
    print("\n")

    c = sc.removebyvalue(cards,0x16)
    print("移除指定牌面 step2: === ",0x16)
    table.print(cards)
    print("\n")
end

--手牌分析
local function t_hu_type_c()
    local cards,num    
    cards = {0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 95}
    local ret = sc.Hu_type_c(cards)
    print("传入牌面 :")
    table.print(cards)
    print("胡牌类型穷举 :")
    table.print(ret)
end


--测试一手牌的可胡类型
local function t_hu_cards()
    local cards,one
    cards = {0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17}
    one = 0x5f
    print("传入牌面 :")
    table.print(cards)
    print("要胡的牌 :",one)
    local ret,relist = sc.eight_c(cards,one)  
    print("所有胡牌结果 :")
    table.print(ret)
    table.print(relist)
end

--测试手牌减少
local function t_cards_reduction()
    local cards,r_cards
    cards = {0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,0x18}
    r_cards = {0x11, 0x12, 0x13}
    print("传入牌面 :")
    table.print(cards)
    print("要移除的牌面 :")
    table.print(r_cards)
    local ret = sc.cardsreduction(cards,r_cards)  
    print("结果 :")
    table.print(ret)
end

--测试 log手牌
local function t_print_cards()
    local cards
    cards = {0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,0x18}
    print("传入牌面 :")
    table.print(cards)
    local ret = sc.PrintCards(cards)  
    print("显示结果 :")
    table.print(ret)
end


--测试一手牌的可胡类型
local function t_check_hu(cards,one)
    print("传入牌面 :")
    table.print(cards)
    print("要胡的牌 :",one)
    local type,mul = mtc.check_hu(cards,one)  
    print(string.format("胡牌结果 : type %s,mul %d",type,mul))
end

--测试反推癞子的胡牌类型
--7张牌用癞子测试所有胡牌可能
local function t_hu_infer(cards)    
	local ret , tmp_all_hu_cards = sc.eight_c(cards,0xae)  
    -- local ret , tmp_all_hu_cards = sc.eight_c(cards,0x1f)  
	local hu_c_list ={}
	--测试反推癞子的胡牌类型
    local max_mul = {mul =0,card =0,type}
	for k,v in pairs(tmp_all_hu_cards) do
		-- print(v.type,PrintCards(v.cards))
		table.print(v)
        
		for p,q in pairs(v) do	
			-- table.print(q)
			local fun_infer = Small_type_infer[q.type].fnc
            local hu_cards_tmp = fun_infer(q.cards)
            if #hu_cards_tmp >0 then
                local type,mul = mtc.get_multiple(v)
                print(string.format(" type %s, mul %d ",type,mul))
                table.print(hu_cards_tmp)
                table.print("\n")
                for _,card in ipairs(hu_cards_tmp) do                    
                    if not hu_c_list[card] or hu_c_list[card].mul<mul then
                        hu_c_list[card] = {type = type ,mul = mul}                        
                        --最大胡牌，倍率
                        if max_mul.mul <mul then
                            max_mul.mul = mul  
                            max_mul.card = card    
                            max_mul.type = type                  
                        end
                    end
                end		
            end
            
		end
	end	
	print("反推癞子替代牌")
    
    --插入最大
    hu_c_list[0x5f] = {type = max_mul.type ,mul = max_mul.mul}
    hu_c_list[0x5e] = {type = max_mul.type ,mul = max_mul.mul}
    -- table.print(hu_c_list)

    for card,v in pairs(hu_c_list) do
        print(string.format("胡牌 %s ,番型 %s, 倍率 %d",sc.PrintCardOne(card),v.type,v.mul))
    end

	-- table.print(hu_c_list)
    -- local cards_list = {}
    -- for i,v in pairs(hu_c_list) do
    --     table.insert(cards_list,i)
    -- end
    -- table.print(sc.PrintCards(cards_list))
end

--穷举可胡的牌
local function t_hu_which()
    local cards,one
    cards = {0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17}
    local all_cards = create_two_pair_cards()

    local hu_result = {}
    for i=1,54 do
        local type,mul = mtc.check_hu(cards,all_cards[i])
        if (type and mul) then
            local one = sc.PrintCardOne(all_cards[i])
            table.insert(hu_result,string.format("胡牌 %s ,番型 %s, 倍率 %d",one,type,mul))
            -- print("预览胡牌结果 type,mul : ",type,mul)
            -- table.print(sc.PrintCards({all_cards[i]}))
            -- print("over \n ")
        else
            -- print("不能胡 \n")
        end
    end
    print("传入牌面 :")
    print(sc.PrintCards(cards))

    print("胡牌推测结果 :")
    for _,v in ipairs(hu_result) do
        print(v)
    end
    -- print("传入牌面 :")
    -- table.print(cards)
    -- print("要胡的牌 :",one)
    -- local ret = sc.eight_c(cards,one)  
    -- print("胡牌结果 :")
    -- table.print(ret)
end


local function main()    
    -- t_zuhe()
    -- t_remove_value()
    -- t_cards_reduction()
    -- t_print_cards()
    -- t_hu_type_c()
    
    -- t_hu_cards()
    --t_check_hu({17,18,20,19,21,24,95},23)
    print(table.tostr(util.check_hu({0x24,0x25,0x26,0x5e,0x5f,0xae,0xaf},0x27)))
    -- local test_cards = {0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17}
    -- local test_cards = {27,107,123,28,44,25,41}

    -- local test_cards = {17,18,20,19,21,24,95}
    -- local test_num=1
    -- local time1 = os.time()
    -- for i=1,test_num do
    --     -- t_hu_which() -- 算法平均耗时0.44s
    --     t_hu_infer(test_cards) --算法平均耗时0.02s
    -- end
    -- print("算法耗时预算 :",(os.time()-time1)/test_num)
    

end


main()

