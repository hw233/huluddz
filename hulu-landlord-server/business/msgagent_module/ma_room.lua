local ma_room = {}
local cluster = require "skynet.cluster"
local skynet = require "skynet"
local ma_data = require "ma_data"
local request = {}

----------------------- 公共的消息---------------------------------------------
-- 玩家准备
function request:ready()
    if ma_data.my_room then
        -- ma_data.my_room.post.ready(ma_data.my_id,self.is_ming_pai)
        skynet.send(ma_data.my_room, "lua", "ready", ma_data.my_id)
        -- cluster.send("room", ma_data.my_room, "lua", "ready", ma_data.my_id,self.is_ming_pai)
    end
end

-- 玩家取消准备
function request:cancel_ready()
    if ma_data.my_room then
        skynet.send(ma_data.my_room, "lua", "cancel_ready", ma_data.my_id)
    end
end

-- 房间中玩家发送动画
function request:play_ani( )
    print('========================表情======================',self.ani_id, self.target_id)
    if ma_data.my_room then
        -- ma_data.my_room.post.play_ani(ma_data.my_id, self.ani_id, self.target_id)
        skynet.send(ma_data.my_room, "lua", "play_ani", ma_data.my_id, self.ani_id, self.target_id)
        -- cluster.send("room", ma_data.my_room, "lua", "play_ani", ma_data.my_id, self.ani_id, self.target_id)
    end
end


function request:request_hand( )
    if ma_data.my_room then
        skynet.send(ma_data.my_room, "lua", "request_hand", ma_data.my_id)
    end
end


-- 房间中玩家发送消息
function request:say( )
    if ma_data.my_room then
        -- ma_data.my_room.post.say(ma_data.my_id, self.msg, self.music_id )
        skynet.send(ma_data.my_room, "lua", "say", ma_data.my_id, self.msg, self.music_id )
        -- cluster.send("room", ma_data.my_room, "lua", "say", ma_data.my_id, self.msg, self.music_id )
    end
end
-- 请求战绩信息（每个房间的总战绩信息）
function request:request_big_record_info()
    local t = skynet.call(get_db_mgr(), "lua", "get_big_records", self.pid or ma_data.my_id, self.index)
    -- local t =  cluster.call("db_mgr", "db_mgr", "lua", "get_big_records", self.pid or ma_data.my_id, self.index)
    -- local t =  db_mgr.req.get_big_records(self.pid or ma_data.my_id, self.index)
    return { info = t }
end

function request:changeDirection()
    local t = skynet.send(ma_data.my_room, "lua", "changeDirection", ma_data.my_id, self.objId,self.skill_id)
    -- local t =  cluster.call("db_mgr", "db_mgr", "lua", "get_big_records", self.pid or ma_data.my_id, self.index)
    -- local t =  db_mgr.req.get_big_records(self.pid or ma_data.my_id, self.index)
end

function request:changeCardC()
    local t = skynet.send(ma_data.my_room, "lua", "changeCardC", ma_data.my_id, self.cardId,self.skill_id)
    -- local t =  cluster.call("db_mgr", "db_mgr", "lua", "get_big_records", self.pid or ma_data.my_id, self.index)
    -- local t =  db_mgr.req.get_big_records(self.pid or ma_data.my_id, self.index)
end

function request:getWantCardC()
    local t = skynet.send(ma_data.my_room, "lua", "getWantCardC", ma_data.my_id, self.card,self.skill_id)
    -- local t =  cluster.call("db_mgr", "db_mgr", "lua", "get_big_records", self.pid or ma_data.my_id, self.index)
    -- local t =  db_mgr.req.get_big_records(self.pid or ma_data.my_id, self.index)
end

function request:disWantCardC()
    local t = skynet.send(ma_data.my_room, "lua", "disWantCardC", ma_data.my_id, self.cards,self.skill_id)
    -- local t =  cluster.call("db_mgr", "db_mgr", "lua", "get_big_records", self.pid or ma_data.my_id, self.index)
    -- local t =  db_mgr.req.get_big_records(self.pid or ma_data.my_id, self.index)
end

function request:nextMoudle()
    local t = skynet.send(ma_data.my_room, "lua", "nextMoudle", ma_data.my_id)
    -- local t =  cluster.call("db_mgr", "db_mgr", "lua", "get_big_records", self.pid or ma_data.my_id, self.index)
    -- local t =  db_mgr.req.get_big_records(self.pid or ma_data.my_id, self.index)
end
-- 请求踢人
function request:Kick_player()
    if ma_data.my_room then
        skynet.call(ma_data.my_room, "lua", "Kick_player", ma_data.my_id, self.obj_id)
    end
end

function request:player_begin_game()
    if ma_data.my_room then
        skynet.call(ma_data.my_room, "lua", "player_begin_game", ma_data.my_id)
    end
end
--取消托管
function request:request_entrust()
    if ma_data.my_room then
        -- ma_data.my_room.post.request_entrust(ma_data.my_id,self.isentrust)
        skynet.send(ma_data.my_room, "lua", "request_entrust", ma_data.my_id,self.isentrust)
        -- cluster.send("room", ma_data.my_room, "lua", "request_entrust", ma_data.my_id,self.isentrust)
    end
end

function request:leave( )
    if ma_data.my_room then
        -- ma_data.my_room.post.leave(ma_data.my_id)
        skynet.send(ma_data.my_room, "lua", "leave", ma_data.my_id)
        -- cluster.send("room", ma_data.my_room, "lua", "leave", ma_data.my_id)
    end
end

-- 玩家虚拟按键功能开关
function request:OF_button()
    if not ma_data.db_info.button or ma_data.db_info.button ~= self.button then
        ma_data.db_info.button = self.button
        skynet.send(get_db_mgr(),"lua","update_userinfo",ma_data.my_id,{button = ma_data.db_info.button})
    end
end
---------------紅中麻將---------------------------------------
--玩家打牌
function request:action()
    if ma_data.my_room then
        -- skynet.send(ma_data.my_room, "lua", "action_cancel_entrust", ma_data.my_id)
        skynet.send(ma_data.my_room, "lua", "action", ma_data.my_id,self)
    end
end

--玩家定缺
function request:select_lack()
    if ma_data.my_room then
        -- skynet.send(ma_data.my_room, "lua", "action_cancel_entrust", ma_data.my_id)
        skynet.send(ma_data.my_room, "lua", "select_lack", ma_data.my_id,self)
    end
end

--玩家认输
function request:give_up()
    if ma_data.my_room then
        skynet.send(ma_data.my_room, "lua", "give_up", ma_data.my_id)
    end
end

--玩家换三张
function request:exchange_card()
    if ma_data.my_room then
        -- skynet.send(ma_data.my_room, "lua", "action_cancel_entrust", ma_data.my_id)
        skynet.send(ma_data.my_room, "lua", "exchange_card", ma_data.my_id,self)
    end
end

--玩家请求流水信息
function request:get_self_io()
    if ma_data.my_room then
        -- skynet.send(ma_data.my_room, "lua", "action_cancel_entrust", ma_data.my_id)
        skynet.send(ma_data.my_room, "lua", "get_self_io", ma_data.my_id)
    end
end
--玩家发送加倍请求
-- function request:double()
--     if ma_data.my_room then
--         skynet.send(ma_data.my_room, "lua", "double", ma_data.my_id,self.result,self.is_super)
--     end
-- end
-----
-----------------紅中麻將end---------------------------------------


-----------------2v2----------------------------------
function request:exchange_card_pre()
    if ma_data.my_room then
        -- skynet.send(ma_data.my_room, "lua", "action_cancel_entrust", ma_data.my_id)
        skynet.send(ma_data.my_room, "lua", "exchange_card_pre", ma_data.my_id,self)
    end
end

function ma_room.init(REQUEST,CMD)
    if request then
        table.connect(REQUEST,request)
    end
    if cmd then
        table.connect(CMD,cmd)
    end
end

return ma_room


