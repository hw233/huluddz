--[[
	rsa: 	https://github.com/foundwant/lua-rsa
	sha256: https://github.com/jqqqi/Lua-HMAC-SHA256
]]


local crypt = require "skynet.crypt"
local sha256 = require "sha256"
local rsa = require "luarsa"

local M = {}



function M.sha256_rsa(msg, prv_key)
	return rsa.process_signature(msg, prv_key, "SHA256")
end

function M.sha1_rsa_pub(msg, pub_key, base64_flag)
	local s = crypt.sha1(msg)
	local ret, r = rsa.encrypt_pem(s, pub_key, base64_flag)
	assert(ret == 0, r)
	return r
end


M.sha256 = sha256.sha256
M.hmac_sha256 = sha256.hmac_sha256
M.process_check = rsa.process_check
M.process_signature = rsa.process_signature
return M