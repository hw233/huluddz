local skynet = require "skynet"
local ma_data = require "ma_data"
local cfg_cards = require "cfg.cfg_cards"
local cfg_global = require "cfg.cfg_global"
local place_config = require "cfg.place_config"
local COLLECTIONS = require "config/collections"
local MjHandle = require "game/tools/MjHandle"
require "table_util"
local request = {}
local cmd = {}

local M = {}

--执行海底捞
function request:heilao_req()
    local useGoodsId = cfg_global[1].xixicard[1].id
    local useGoodsIdNum = cfg_global[1].xixicard[1].num
    local curGoodsIdNum = ma_data.get_goods_num(useGoodsId)
    if curGoodsIdNum < useGoodsIdNum then
        return {result = 1}
    end
    local diff = os.time() - ma_data.heilao.t
    print("now =>", os.time())
    print("ma_data.heilao.t =>", ma_data.heilao.t)
    print("diff =>", diff)
    if os.time() - ma_data.heilao.t > 35 then
        return {result = 2}
    end
    if ma_data.heilao.selectnum >= ma_data.heilao.selectmaxnum then
        return {result = 3}
    end
    ma_data.add_goods_list({{id = useGoodsId, num = -useGoodsIdNum}},GOODS_WAY_HEILAO,"嘻嘻捞")
    local tmpIndex = math.random(#ma_data.heilao.selectlist)
    print('海底捞胡牌INDEX======================',ma_data.heilao.lastHuNum)
    table.print(ma_data.heilao.selectlist)
    print('海底捞胡牌table======================')
    table.print(ma_data.heilao.hulist)
    if ma_data.heilao.placesubid == 4 then
        tempRand = math.random(1,100)
        if tempRand <= 10 then
            tmpIndex = math.random(ma_data.heilao.lastHuNum)
        else
            tmpIndex = math.random(ma_data.heilao.lastHuNum+1,#ma_data.heilao.selectlist)
        end 
    end
    if tmpIndex <= ma_data.heilao.lastHuNum then
        ma_data.heilao.lastHuNum = ma_data.heilao.lastHuNum - 1
    end
    local selectInfo = ma_data.heilao.selectlist[tmpIndex]
    local mjid = ma_data.heilao.hulist[selectInfo.index]
    table.remove(ma_data.heilao.selectlist,tmpIndex)
    table.insert(ma_data.heilao.oplist,selectInfo.index)

    local coinAdd = 0
    local prestigeAdd = 0
    local rate = 0
    local cfg = place_config[ma_data.heilao.placeid][ma_data.heilao.placesubid]
    if ma_data.heilao.huinfo[mjid] then
        --海底捞中了的表现
        rate = ma_data.heilao.huinfo[mjid].rate
        
        skynet.error('================嘻嘻捞，rate，cfg.cap==================',rate,cfg.cap)
        if cfg.cap > 0 and rate > cfg.cap then
            ma_data.heilao.huinfo[mjid].rate = cfg.cap
            rate = cfg.cap
        end
        coinAdd = cfg.base_score * rate
        if cfg.prestige then
            prestigeAdd = math.floor(cfg.prestige * rate * ma_data.heilao.prestigebuffnum)
            print('===============番数=============',prestigeAdd,ma_data.heilao.prestigebuffnum)
        end
    end
    if prestigeAdd > 0 then
         local curSeg = ma_data.ma_hall_frame.hall_frame_settle(prestigeAdd)
         local place_id = ma_data.heilao.placeid*100+ma_data.heilao.placesubid
          ma_data.ma_hall_active.update_xixi_big_gift(place_id,curSeg)
    end
    if coinAdd > 0 then
        if cfg.stype == 2 then
            local tempAward = {{id = 100012,num = coinAdd}}
            ma_data.add_goods_list(tempAward,GOODS_WAY_TK_AWARD,"千王之王每日赠送")
        else
            ma_data.add_gold(coinAdd,GOODS_WAY_HEILAO_GET,"嘻嘻捞获得")
        end
    end
    ma_data.heilao.selectnum = ma_data.heilao.selectnum + 1
    local hulist
    if ma_data.heilao.selectnum >= ma_data.heilao.selectmaxnum then
        hulist = ma_data.heilao.hulist
    end
    --

    return {result = 0, coin = coinAdd, prestige = prestigeAdd, huinfo=ma_data.heilao.huinfo[mjid], 
            index=selectInfo.index,selectnum=ma_data.heilao.selectnum,
            selectmaxnum=ma_data.heilao.selectmaxnum,hulist=hulist,mjid = mjid}
end

--设置嘻嘻捞信息
-- mjid:能胡的麻将id,rate:胡后生效的倍率,types: 翻新列表 
--hulist:{{mjid=xx,types={},rate=1}}
--placeid 玩法id
--placesubid 场次id
function M.set_info(phulist,prestigebuffnum,placeid,placesubid)
    print("ma_heilao =>", table.tostr(phulist), "; prestigebuffnum =>", prestigebuffnum, "; placeid =>", placeid, "; placesubid=>", placesubid)
    local month_type = ma_data.ma_month_card.get_type()
    local cfg = place_config[placeid][placesubid]
    if month_type <= 0 or cfg.type ~= 1 then
        return 0,0
    end
    local cardNum = cfg_month_card["xixicard"..month_type]
    local maxNumList = {3,5,8}
    local maxNum = maxNumList[cardNum]
    local hulist = {}
    local huinfo = {}
    local cardIdUsed = {}
    local currNum = 0
    
    print('==========胡牌table==============================')
    table.print(phulist)
    local phulen = #phulist
    for _,item in ipairs(phulist) do
        if not huinfo[item.mjid] and currNum < cardNum then
            if MjHandle:TrsfomId(item.mjid) ~= 31 or phulen == 1 then
                huinfo[item.mjid] = item
                table.insert(hulist,item.mjid)
                currNum = currNum + 1
            end
        end
        cardIdUsed[cfg_cards[item.mjid].caleType] = true
    end
    if #hulist < cardNum then
        local tmpcount = #hulist
        for i = #hulist+1, cardNum do
            table.insert(hulist,hulist[math.random(tmpcount)])
        end
    end
    local tmpMjIdList = {}
    for mjid = 1, 108 do
        if not cardIdUsed[cfg_cards[mjid].caleType] then
            table.insert(tmpMjIdList,mjid)
        end
    end
    for i = #hulist + 1,maxNum do
        local tmpIndex = math.random(#tmpMjIdList)
        table.insert(hulist,tmpMjIdList[tmpIndex])
        table.remove(tmpMjIdList,tmpIndex)
    end
    local selectlist = {}
    for i=1,#hulist do
        -- selectlist[i] = hulist[i]
        table.insert(selectlist,{index=i})
    end
    print('===============海底捞ssss===========',cardNum)
    table.print(hulist)
    ma_data.heilao.t = os.time()
    ma_data.heilao.huinfo = huinfo
    ma_data.heilao.hulist = hulist
    ma_data.heilao.selectlist = selectlist
    ma_data.heilao.selectnum = 0
    ma_data.heilao.prestigebuffnum = prestigebuffnum or 0
    ma_data.heilao.selectmaxnum = cardNum
    ma_data.heilao.oplist = {} --操作索引,第几张被选中过
    ma_data.heilao.placeid = placeid
    ma_data.heilao.placesubid = placesubid
    ma_data.heilao.lastHuNum = cardNum -- 记录剩下几张胡牌
    return cardNum,maxNum
end

function M.init(REQUEST, CMD)
    ma_data.heilao = {t=0,huinfo={},cards={},hulist={}}
    if request then
        table.connect(REQUEST, request)
    end
    if cmd then
        table.connect(CMD, cmd)
    end
end

ma_data.ma_heilao = M
return M