local skynet = require "skynet"
local snax = require "skynet.snax"
local config = require "server_conf"
local Mongolib = require "Mongolib"

require "pub_util"
require "table_util"

local CONFIG = require "server_conf"
local xy_cmd = require "xy_cmd"

local CMD, ServerData = xy_cmd.xy_cmd, xy_cmd.xy_server_data


local function init()
	local m = Mongolib.new()
    m:connect(CONFIG.DB_CONF)
    m:use(CONFIG.DB_CONF.name)

   	ServerData.db = m

   	CMD.get_gameconf()
end

CMD.init = function ()
    
end

function CMD.get_gameconf()
	local gameid = skynet.getenv("gameid")
	local serverId = skynet.getenv("serverId")
	assert(gameid, "gameid not found")

	-- local gameconf = ServerData.db:find_one("game_conf", {gameid = gameid, serverId = serverId}, {_id  = false, gameid = false, serverId = false})
	-- assert(gameconf, gameid .. " config not found")

	local gameconf = {}
    local isOut = false
    if config.gameConfig then
        if not isOut then
            isOut = true
            skynet.logw("Text config overrides the database config")
        end
        for key, value in pairs(config.gameConfig) do
            gameconf[key] = value
        end
    end

	CMD.set_env(gameconf)
end

function CMD.exit()
	ServerData.db:disconnect()
	skynet.exit()
end



function CMD.set_env(gameconf)
	skynet.logd("====dbs====", table.tostr(gameconf))
	for k,v in pairs(gameconf) do
		if k == "agents" then
			for name,agent in pairs(v) do
				skynet.setenv(name,tostring(agent))
			end
		elseif k == "gates" then
			for name,gate in pairs(v) do
				skynet.setenv(name,tostring(gate))
			end
		elseif k == "wsgate" then
			for name,wsgate in pairs(v) do
				skynet.setenv(name,tostring(wsgate))
			end
		elseif k == "dbs" then
			ServerData.dbconfs = v
		else
			skynet.setenv(k,tostring(v))
		end
	end
end

function CMD.get_dbconfs()
	return ServerData.dbconfs
end


function CMD.inject(filePath)
    require(filePath)
end

skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command], command)
        skynet.ret(skynet.pack(f(...)))
    end)
    init()
end)