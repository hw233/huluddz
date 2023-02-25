local sprotoparser = require "sprotoparser"
local struct = require "sproto.struct"


local protos = {
	"0000_public",
    "0000_test_proto",
    "0300_1000_user",
	"1000_lobby",
	"1100_lobby_game",
	"1200_lobby_store",
	"1300_lobby_mail",
	-- "1320_lobby_rankinglist",
	-- "1340_lobby_vip",
	"1360_lobby_dailytask",
	-- "1380_lobby_anchor",
	"1400_lobby_bank",
	"1500_1699_activity",
	"2000_game",
	"2100_game_ex",
	"2200_game_7",
	"3000_4000_room",
	"4000_4500_user",
	--start
	"5000_6000_user_moudle",
}


local c2s = struct
local s2c = struct


for _,name in ipairs(protos) do
	local p = require ("sproto."..name)
	if p.struct then
		c2s = c2s .. p.struct
		s2c = s2c .. p.struct
	end
	c2s = c2s .. (p.c2s or "")
	s2c = s2c .. (p.s2c or "")
end


local function writeFile(path, str)
    local f = assert(io.open(path, 'w'))
    f:write(str)
    f:close()
end

-- writeFile("s2c_all.proto",s2c)
-- writeFile("c2s_all.proto",c2s)

return {
	c2s = sprotoparser.parse(c2s),
	s2c = sprotoparser.parse(s2c)
}

