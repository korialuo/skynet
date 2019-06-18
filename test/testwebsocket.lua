local skynet = require "skynet"
local httpd = require "http.httpd"
local websocket = require "websocket"
local socket = require "skynet.socket"
local sockethelper = require "http.sockethelper"

local handler = {}

function handler.on_open(ws)
    skynet.error(string.format("Client connected: %s", ws.addr))
    ws:writetext("Hello websocket !")
end

function handler.on_message(ws, msg, sz)
    skynet.error("Received a message from client:\n"..msg)
end

function handler.on_error(ws, msg)
    skynet.error("Error. Client may be force closed.")
    ws:close()
end

function handler.on_close(ws, code, reason)
    skynet.error(string.format("Client disconnected: %s", ws.addr))
    -- do not need close.
    -- ws:close
end

local function check_origin(origin, host)
    return true
end

local function respcb(ret)

end

local function handle_socket(fd, addr)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(fd), 8192)
    if code then
        if url == "/ws" then
            if (not websocket.upgrade(header, check_origin, function(resp) socket.write(fd, resp) end)) then
	        socket.close(fd)
		return
            end
            local ws = websocket.new(fd, addr, handler, nil)
        end
    end
end

skynet.start(function()
    local fd = assert(socket.listen("127.0.0.1:8001"))
    socket.start(fd , function(fd, addr)
        socket.start(fd)
        pcall(handle_socket, fd, addr)
    end)
end)
