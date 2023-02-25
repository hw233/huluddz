local skynet = require "skynet"
local ma_data = require "ma_data"
local cfg_items = require "cfg.cfg_items"
local request = {}
local cmd = {}
local M = {}

function M.set_base_dress()
    --判断基础服装是否拥有
    local needSet = false
    if ma_data.db_info.sex == SEX_BOY or ma_data.db_info.sex == SEX_GIRL then
        --查找一个性别的默认时装
        for id,item in pairs(cfg_items) do
            if item.gender == 0 and 1 == item.default then
                local goods_num = ma_data.get_goods_num(id)
                if goods_num <= 0 then
                    --未初始化过
                    needSet = true
                    break
                end
            end
        end
    end
    if not needSet then
        return
    end

    local addGoodsList = {}
    for id,item in pairs(cfg_items) do
        if (item.gender == ma_data.db_info.sex or item.gender == 0 or item.gender == 3 or item.gender == 4) and 1 == item.default then
            table.insert(addGoodsList, {id = id, num = 1})
        end
    end
    --  print('===================组件基础服装2')
    -- table.print(addGoodsList)
    ma_data.add_goods_list(addGoodsList,GOODS_WAY_BASE_DRESS,"基础服装")
    -- M.ranktest()
end

--穿戴
function request:dress_goods()
    print('================穿戴时装=====================')
    local ret = ma_data.dress_goods(self.goods_id, true)
     print('================穿戴时装2=====================',ret)
    return {result = ret,goods_id = self.goods_id}
end

--脱掉
function request:drop_goods()
    ma_data.drop_goods(self.goods_id)
    return {result = 0,goods_id = self.goods_id}
end

--隐藏时装
function request:hide_dress()
    local result,hide = ma_data.hide_dress(self.goods_id,self.hide)
    return {result = result,goods_id = self.goods_id,hide = hide}
end

function M.init(REQUEST, CMD)
    if request then
        table.connect(REQUEST, request)
    end
    if cmd then
        table.connect(CMD, cmd)
    end
end
ma_data.ma_dress = M
return M