local internal = require "http.internal"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local httpd = require "http.httpd"
local skynet = require "skynet"
local sockethelper = require "http.sockethelper"
local socket_error = sockethelper.socket_error

local GLOBAL_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
local MAX_FRAME_SIZE = 256 * 1024 -- max frame is 256K

local M = {}


local ws_pool = {}
local function _close_websocket(ws_obj)
    local id = ws_obj.id
    assert(ws_pool[id] == ws_obj)
    ws_pool[id] = nil
    ws_obj.close()
end

local function _isws_closed(id)
    return not ws_pool[id]
end

local function read_handshake(self,upgrade_ops)
    local header, method, url
    if upgrade_ops then
        header, method, url = upgrade_ops.header, upgrade_ops.method, upgrade_ops.url
    else
        local tmpline = {}
        local header_body = internal.recvheader(self.read, tmpline, "")
        if not header_body then
            return 413
        end

        local request = assert(tmpline[1])
        local httpver
        method, url, httpver = request:match "^(%a+)%s+(.-)%s+HTTP/([%d%.]+)$"
        assert(method and url and httpver)
        if method ~= "GET" then
            return 400, "need GET method"
        end

        httpver = assert(tonumber(httpver))
        if httpver < 1.1 then
            return 505  -- HTTP Version not supported
        end
        header = internal.parseheader(tmpline, 2, {})
    end

    -- local header = internal.parseheader(tmpline, 2, {})
    if not header then
        return 400  -- Bad request
    end
    if not header["upgrade"] or header["upgrade"]:lower() ~= "websocket" then
        return 426, "Upgrade Required"
    end

    if not header["host"] then
        return 400, "host Required"
    end

    if not header["connection"] or not header["connection"]:lower():find("upgrade", 1,true) then
        return 400, "Connection must Upgrade"
    end

    local sw_key = header["sec-websocket-key"]
    if not sw_key then
        return 400, "Sec-WebSocket-Key Required"
    else
        skynet.error("crypt-server-65",sw_key)
        local raw_key = crypt.base64decode(sw_key)
        if #raw_key ~= 16 then
            return 400, "Sec-WebSocket-Key invalid"
        end
    end

    if not header["sec-websocket-version"] or header["sec-websocket-version"] ~= "13" then
        return 400, "Sec-WebSocket-Version must 13"
    end

    local sw_protocol = header["sec-websocket-protocol"]
    local sub_pro = ""
    if sw_protocol then
        local has_chat = false
        for sub_protocol in string.gmatch(sw_protocol, "[^%s,]+") do
            if sub_protocol == "chat" then
                sub_pro = "Sec-WebSocket-Protocol: chat\r\n"
                has_chat = true
                break
            end
        end
        if not has_chat then
            print("read_handshake13")
            return 400, "Sec-WebSocket-Protocol need include chat"
        end
    end

    -- response handshake
    skynet.error("crypt-server-95",sw_key .. self.guid,crypt.sha1(sw_key .. self.guid))
    local accept = crypt.base64encode(crypt.sha1(sw_key .. self.guid))
    local resp = "HTTP/1.1 101 Switching Protocols\r\n"..
                 "Upgrade: websocket\r\n"..
                 "Connection: Upgrade\r\n"..
    string.format("Sec-WebSocket-Accept: %s\r\n", accept)..
                  sub_pro ..
                  "\r\n"
    self.write(resp)
    return nil, header, url
end

local function try_handle(self, method, ...)
    local handle = self.handle
    local f = handle and handle[method]
    if f then
        f(self.id, ...)
    end
end

local op_code = {
    ["frame"]  = 0x00,
    ["text"]   = 0x01,
    ["binary"] = 0x02,
    ["close"]  = 0x08,
    ["ping"]   = 0x09,
    ["pong"]   = 0x0A,
    [0x00]     = "frame",
    [0x01]     = "text",
    [0x02]     = "binary",
    [0x08]     = "close",
    [0x09]     = "ping",
    [0x0A]     = "pong",
}

local function write_frame(self, op, payload_data, masking_key)
    payload_data = payload_data or ""
    local payload_len = #payload_data
    local op_v = assert(op_code[op])
    local v1 = 0x80 | op_v -- fin is 1 with opcode
    local s
    local mask = masking_key and 0x80 or 0x00
    -- mask set to 0
    if payload_len < 126 then
        s = string.pack("I1I1", v1, mask | payload_len)
    elseif payload_len < 0xffff then
        s = string.pack("I1I1>I2", v1, mask | 126, payload_len)
    else
        s = string.pack("I1I1>I8", v1, mask | 127, payload_len)
    end
    self.write(s)

    -- write masking_key
    if masking_key then
        s = string.pack(">I4", masking_key)
        self.write(s)
        skynet.error("crypt-server-151",payload_data, s)
        payload_data = crypt.xor_str(payload_data, s)
    end

    if payload_len > 0 then
        self.write(payload_data)
    end
end


local function read_close(payload_data)
    local code, reason
    local payload_len = #payload_data
    if payload_len > 2 then
        local fmt = string.format(">I2c%d", payload_len - 2)
        code, reason = string.unpack(fmt, payload_data)
    end
    return code, reason
end


local function read_frame(self)
    local s = self.read(2)
    local v1, v2 = string.unpack("I1I1", s)
    local fin  = (v1 & 0x80) ~= 0
    -- unused flag
    -- local rsv1 = (v1 & 0x40) ~= 0
    -- local rsv2 = (v1 & 0x20) ~= 0
    -- local rsv3 = (v1 & 0x10) ~= 0
    local op   =  v1 & 0x0f
    local mask = (v2 & 0x80) ~= 0
    local payload_len = (v2 & 0x7f)
    if payload_len == 126 then
        s = self.read(2)
        payload_len = string.unpack(">I2", s)
    elseif payload_len == 127 then
        s = self.read(8)
        payload_len = string.unpack(">I8", s)
    end

    if self.mode == "server" and payload_len > MAX_FRAME_SIZE then
        error("payload_len is too large")
    end

    -- print(string.format("fin:%s, op:%s, mask:%s, payload_len:%s", fin, op_code[op], mask, payload_len))
    local masking_key = mask and self.read(4) or false
    local payload_data = payload_len>0 and self.read(payload_len) or ""
    skynet.error("crypt-server-198",payload_data, masking_key)
    payload_data = masking_key and crypt.xor_str(payload_data, masking_key) or payload_data
    return fin, assert(op_code[op]), payload_data
end


local function resolve_accept(self,options)
    try_handle(self, "connect")
    local code, err, url = read_handshake(self, options and options.upgrade)
    if code then
        local ok, s = httpd.write_response(self.write, code, err)
        if not ok then
            error(s)
        end
        try_handle(self, "close")
        return
    end

    local header = err
    try_handle(self, "handshake", header, url)
    local recv_count = 0
    local recv_buf = {}
    local first_op
    while true do
        if _isws_closed(self.id) then
            try_handle(self, "close")
            return
        end
        local fin, op, payload_data = read_frame(self)
        if op == "close" then
            local code, reason = read_close(payload_data)
            write_frame(self, "close")
            try_handle(self, "close", code, reason)
            break
        elseif op == "ping" then
            write_frame(self, "pong", payload_data)
            try_handle(self, "ping")
        elseif op == "pong" then
            try_handle(self, "pong")
        else
            if fin and #recv_buf == 0 then
                try_handle(self, "message", payload_data, op)
            else
                recv_buf[#recv_buf+1] = payload_data
                recv_count = recv_count + #payload_data
                if recv_count > MAX_FRAME_SIZE then
                    error("payload_len is too large")
                end
                first_op = first_op or op
                if fin then
                    local s = table.concat(recv_buf)
                    try_handle(self, "message", s, first_op)
                    recv_buf = {}  -- clear recv_buf
                    recv_count = 0
                    first_op = nil
                end
            end
        end
    end
end

local SSLCTX_SERVER = nil
local function _new_server_ws(socket_id, handle, protocol,hostname)
    -- print("_new_server_ws server",protocol)
    local obj
    if protocol == "ws" then
        obj = {
            close = function ()
                socket.close(socket_id)
            end,
            read = sockethelper.readfunc(socket_id),
            write = sockethelper.writefunc(socket_id),
        }

    elseif protocol == "wss" then
        local tls = require "http.tlshelper"
        if not SSLCTX_SERVER then
            -- print("_new_server_ws server1",protocol)
            SSLCTX_SERVER = tls.newctx()
            -- gen cert and key
            -- openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout server-key.pem -out server-cert.pem
            local certfile = skynet.getenv("certfile") or "./server-cert.pem"
            local keyfile = skynet.getenv("keyfile") or "./server-key.pem"
            SSLCTX_SERVER:set_cert(certfile, keyfile)
        end
        -- print("_new_server_ws server2",protocol)
        local tls_ctx = tls.newtls("server", SSLCTX_SERVER,hostname)
        -- print("_new_server_ws server3",protocol)
        local init = tls.init_responsefunc(socket_id, tls_ctx)
        -- print("_new_server_ws server4",protocol)
        init()
        -- print("_new_server_ws server5",protocol)
        obj = {
            close = function ()
                socket.close(socket_id)
                tls.closefunc(tls_ctx)() 
            end,
            abandon = function()
                print("_new_server_ws abandon")
                tls.closefunc(tls_ctx)() 
            end,
            read = tls.readfunc(socket_id, tls_ctx),
            write = tls.writefunc(socket_id, tls_ctx),
        }

    else
        error(string.format("invalid websocket protocol:%s", tostring(protocol)))
    end

    obj.mode = "server"
    obj.id = assert(socket_id)
    obj.handle = handle
    obj.guid = GLOBAL_GUID
    ws_pool[socket_id] = obj
    -- print("_new_server_ws server end")
    return obj
end

function M.start(socket_id,protocol,addr)
    socket.start(socket_id)
    protocol = protocol or "ws"
    local ws_obj = _new_server_ws(socket_id, handle, protocol)
    ws_obj.addr = addr
    local code, err, url = read_handshake(ws_obj)
    if code then
        local ok, s = httpd.write_response(ws_obj.write, code, err)
        if not ok then
            error(s)
        end
        return
    end

    return true
end

function M.abandon(socket_id)
    assert(socket_id)
    socket.abandon(socket_id)
    if ws_pool[socket_id].abandon then
        ws_pool[socket_id].abandon()
    end
    ws_pool[socket_id] = nil
end

function M.restart(socket_id,protocol,addr)
    socket.start(socket_id)
    protocol = protocol or "ws"
    local ws_obj = _new_server_ws(socket_id, handle, protocol)
    ws_obj.addr = addr
    return true
end

function M.read(id)
    local ws_obj = assert(ws_pool[id])
    local recv_buf
    local recv_count = 0
    while true do
        local fin, op, payload_data = read_frame(ws_obj)
        if op == "close" then
            write_frame(ws_obj, "close")
            _close_websocket(ws_obj)
            return false, payload_data
        elseif op == "ping" then
            write_frame(ws_obj, "pong", payload_data)
        elseif op ~= "pong" then  -- op is frame, text binary
            if fin and not recv_buf then
                return payload_data
            else
                recv_buf = recv_buf or {}
                recv_buf[#recv_buf+1] = payload_data
                recv_count = recv_count + #payload_data
                if recv_count > MAX_FRAME_SIZE then
                    error("payload_len is too large")
                end
                if fin then
                    local s = table.concat(recv_buf)
                    return s
                end
            end
        end
    end
    assert(false)
end


function M.write(id, data, fmt, masking_key)
    local ws_obj = assert(ws_pool[id])
    fmt = fmt or "text"
    assert(fmt == "text" or fmt == "binary")
    write_frame(ws_obj, fmt, data, masking_key)
end


function M.ping(id)
    local ws_obj = assert(ws_pool[id])
    write_frame(ws_obj, "ping")
end

function M.addrinfo(id)
    local ws_obj = assert(ws_pool[id])
    return ws_obj.addr
end

function M.close(id, code ,reason)
    local ws_obj = ws_pool[id]
    if not ws_obj then
        return
    end

    local ok, err = xpcall(function ()
        reason = reason or ""
        local payload_data
        if code then
            local fmt =string.format(">I2c%d", #reason)
            payload_data = string.pack(fmt, code, reason)
        end
        write_frame(ws_obj, "close", payload_data)
    end, debug.traceback)
    _close_websocket(ws_obj)
    if not ok then
        skynet.error(err)
    end
end


return M
