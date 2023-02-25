-- module proto as examples/proto.lua
package.path = "./xycard/?.lua;" .. package.path

local skynet = require "skynet"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
local codecache = require "skynet.codecache"
-- local proto = (require "xycard_proto")(skynet.getenv("root"))
--local protobuf = require "protobuf"
local sharetable = require "skynet.sharetable"

local CMD = {}

function CMD.reload()
	-- skynet.error("reload proto ...............")
	-- local root = skynet.getenv("root")
	-- proto = loadfile(root .. "protos/xycard_proto.lua")()(root)

	-- sprotoloader.save(proto.c2s, 1)
	-- sprotoloader.save(proto.s2c, 2)
	-- skynet.send("agent_mgr", "lua", "notice2agent", "reload_proto")
end


-- function CMD.testpb()
--     -- local protobuf = require "protobuf"

--     local msg = protobuf.encode("MsgLoginRsp",{ 
--     	platform = 1,
--         user_id = "fdasfad",
--         char_id = 1111, 
--         char_name = "dsfa",
--         aaa = "xxxx",
--     })

--     print("+++++++++++++ msg =",msg)

--     table.print(protobuf.decode("MsgLoginRsp",msg))
-- end


skynet.start(function()
	codecache.mode("OFF")

	-- sprotoloader.save(proto.c2s, 1)
	-- sprotoloader.save(proto.s2c, 2)


	skynet.newservice("xycard_pbproto")

	local protoloader = require "xy_pb"
	-- print("~~~~~~~~~~~~~~~~~~~~~~~~")
	-- table.print(sharetable.query("pbprotos"))
	-- print("++++++++++++++++++++++++")
	-- table.print(sharetable.query("pbids"))

	host = protoloader.new({
			pbfiles = sharetable.query("pbprotos"),
			pbids 	= sharetable.query("pbids"),
			pbmaps  = sharetable.query("pbmaps")
		})

	send_request = function(...)
		return host:pack_message(...)
	end

	unpack_msg = function(msg,sz)
		msg,sz = skynet.unpack(msg,sz)
		return host:dispatch(msg, sz)
	end



	-- local v = send_request("byebye",{what = "see you."})

	-- crypt = require "skynet.crypt"
	-- print("send_request",v,type(v),crypt.base64encode(v))
	-- print("-----------==========",host.tohex(v))
	-- print("==================",host.tohex(crypt.base64decode("AghzZWUgeW91Lg==")))
	-- table.print(host.decode(host.packagename.."S2cByebye",crypt.base64decode("CghzZWUgeW91Lg==")))

	-- local pbproto = sharetable.query("pbprotos")

	-- for _,v in ipairs(pbproto) do
	-- 	table.print(protobuf.register(v))
	-- end

	-- CMD.testpb()

	-- don't call skynet.exit() , because sproto.core may unload and the global slot become invalid

    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.ret(skynet.pack(f(...)))
    end)
end)