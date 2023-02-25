--2v2 组队请求

local cluster = require "skynet.cluster"
local skynet = require "skynet"
local ma_data = require "ma_data"
local request = {}
local M = {}

----------------------- 公共的消息---------------------------------------------

function request:create_team2v2()    
    -- print("====debug qc==== create_team2v2 ",self.gameid,self.placeid,self.needGlv,self.password)
    local ret = skynet.call("team2v2_mgr", "lua", "Create_team2v2",ma_data.my_id,self.gameid,self.placeid,self.needGlv,self.password)
    --table.print(ret)
    return ret
end

function request:join_team2v2()
    -- print("====debug qc==== join_team2v2 ")
    return skynet.call("team2v2_mgr", "lua", "Join_team2v2",ma_data.my_id,self.teamid,self.password)
end

function request:leave_team2v2()
    -- print("====debug qc==== leave_team2v2 ")
    local ret = skynet.call("team2v2_mgr", "lua", "Leave_team2v2",ma_data.my_id)
    table.print(ret)
    return ret
end

--更改team当前配置
function request:set_team_conf()
    return skynet.call("team2v2_mgr", "lua", "Set_team_conf",ma_data.my_id,self.placeid)
end

--匹配
function request:match_next()
    return skynet.call("team2v2_mgr", "lua", "match_next",ma_data.my_id,self.ready)    
end

--取消匹配
-- function request:cancel_matching2v2()
--     skynet.call("team2v2_mgr", "lua", "Cancel_match2v2",ma_data.my_id,self.teamid)    
-- end

function M.init(REQUEST,CMD)
    if request then
        table.connect(REQUEST,request)
    end
    if cmd then
        table.connect(CMD,cmd)
    end
end

return M


