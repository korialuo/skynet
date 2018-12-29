local skynet = require "skynet"
local crypt = require "skynet.crypt"
local socket = require "skynet.socket"

local socket_write = socket.write
local socket_read  = socket.read
local socket_close = socket.close

local s_format = string.format
local s_pack   = string.pack
local s_unpack = string.unpack

local t_pack   = table.pack
local t_unpack = table.unpack
local t_concat = table.concat

local GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

local function upgrade_response(key, protocol)
    protocol = protocol or ""
    if protocol ~= "" then protocol = "Sec-WebSocket-Protocol: "..protocol end
    local accept = crypt.base64encode(crypt.sha1(key..GUID))
    return s_format("HTTP/1.1 101 Switching Protocols\r\n"..
        "Upgrade: websocket\r\n"..
        "Connection: Upgrade\r\n"..
        "Sec-WebSocket-Accept: %s\r\n"..
        "%s\r\n\r\n", accept, protocol)
end

local function readframe(fd)
    local data, err = socket_read(fd, 2)
    if not data then return 'e', "Read fin, payload len error." end
    local fin, len = s_unpack("BB", data)
    local opcode, mask = fin & 0xf, len & 0x80 ~= 0
    fin = fin & 0x80 ~= 0
    len = len & 0x7f

    if len == 126 then
        data, err = socket_read(fd, 2)
        if not data then return 'e', "Read extended payload len error." end
        len = s_unpack(">H", data)
    elseif len == 127 then
        data, err = socket_read(fd, 8)
        if not data then return 'e', "Read extended payload len error." end
        len = s_unpack(">I8", data)
    end
    data, err = socket_read(fd, (mask and 4 or me0) + len)
    if not data then return 'e', "Read payload error." end
    
    if mask then
        -- xor decrypt
        mask, data = s_unpack("I4c"..len, data)
        data = crypt.xor_str(data, s_pack(">I4", mask))
    else
        data = s_unpack("c"..len, data)
    end

    if opcode & 0x8 ~= 0 then
        -- control frame (0x8, 0x9, 0xA)
        if not fin or len >= 126 then return 'e', "Invalid control frame." end
        if opcode == 0x8 then -- close frame
            if len < 2 then return 'e', "Invalid close frame, miss code."
            elseif len == 2 then return 'c', s_unpack(">H", data)
            else return 'c', s_unpack(">Hc"..(len-2), data) end
        elseif opcode == 0x9 then -- ping
            return 'i', data, len
        elseif opcode == 0xa then -- pong
            return 'o', data, len
        end
    else
        -- data frame (0x0, 0x1, 0x2)
        return 'd', fin, opcode, data, len
    end
end

local function writeframe(fd, op, fin, data, sz, mask)
    local finbit = fin and 0x80 or 0x0
    local maskbit = mask and 0x80 or 0x0

    local payload = data
    local frame, len
    if type(data) == "string" then len = #data
    elseif type(data) == "userdata" then len = sz end

    if len < 126 then
        frame = s_pack("BB", finbit | op, len | maskbit)
    elseif len >= 126 and len <= 0xffff then
        frame = s_pack(">BBH", finbit | op, 126 | maskbit, len)
    else
        frame = s_pack(">BBI8", finbit | op, 127 | maskbit, len)
    end

    if mask then
        frame = frame..s_pack(">I4", mask) 
        payload = crypt.xor_str(data, s_pack(">I4", mask)) 
    end
    socket_write(self.fd, frame)
    socket_write(self.fd, payload, sz)
end

local websocket = {}

function websocket.upgrade(header, checkorigin, respcb)
    local key = header['sec-websocket-key']
    if not key then return false, respcb("HTTP/1.1 400 Bad Request.\r\n\r\n") end

    if not header['upgrade'] or header['upgrade'] ~= "websocket" or
        not header['connection'] or not header['connection']:lower() ~= 'upgrade' or
        not header['sec-websocket-version'] or header['sec-websocket-version'] ~= '13'
    then
        return false, respcb("HTTP/1.1 400 Bad Request.\r\n\r\n")
    end
    local origin = header["origin"] or header['sec-websocket-origin']
    if origin and checkorigin and not checkorigin(origin, header['host']) then
        return false, respcb("HTTP/1.1 403 Websocket agency not allowed.\r\n\r\n")
    end
    local protocol = header['sec-websocket-protocol']
    if protocol then
        for p in protocol:gmatch('(%a+),*') do
            protocol = p
            break
        end
    end
    return true, respcb(upgrade_response(key, protocol))
end

function websocket.new(fd, addr, handler, mask)
    local ws = setmetatable({
        fd = fd,
        addr = addr,
        handler = handler,
        mask = mask,
    }, {__index = websocket})
    return ws
end

function websocket:read()
    local message, size = '', 0
    while true do
        local S, R1, R2, R3, R4 = readframe(self.fd)
        if S == 'e' then self:on_error(R1)         return false
        elseif S == 'c' then self:on_close(R1, R2) return false
        elseif S == 'i' then self:on_ping(R1, R2)  return true
        elseif S == 'o' then self:on_pong(R1, R2)  return true
        elseif S == 'd' then
            local fin, op, data, sz = R1, R2, R3, R4
            message = message..data
            size = size + sz
            if fin then break end
        end
    end
    self:on_message(message, size)
end

function websocket:writetext(data, fin)
    writeframe(self.fd, 0x1, fin or true, data, nil, self.mask)
end

function websocket:writebin(data, sz, fin)
    writeframe(self.fd, 0x2, fin or true, data, sz, self.mask)
end

function websocket:ping(data, sz)
    writeframe(self.fd, 0x9, true, data, sz, self.mask)
end

function websocket:pong(data, sz)
    writeframe(self.fd, 0xa, true, data, sz, self.mask)
end

function websocket:close(code, reason)
    local data = s_pack(">H", code)
    if reason then data = data..reason end
    writeframe(self.fd, 0x8, true, data)
    socket_close(self.fd)
    if self.handler and self.handler.on_close then
        self.handler.on_close(self, code, reason)
    end
end

function websocket:on_ping(data, sz)
    if self.handler and self.handler.on_ping then
        self.handler.on_ping(self, data, sz)
    end
end

function websocket:on_pong(ws, data, sz)
    if self.handler and self.handler.on_pong then
        self.handler.on_pong(self, data, sz)
    end
end

function websocket:on_close(code, reason)
    socket_close(self.fd)
    if self.handler and self.handler.on_close then
        self.handler.on_close(self, code, reason)
    end
end

function websocket:on_message(data, sz)
    if self.handler and self.handler.on_message then
        self.handler.on_message(ws, data, sz)
    end
end

function websocket:on_error(err)
    if self.handler and self.handler.on_error then
        self.handler.on_error(ws, err)
    end
end

return websocket