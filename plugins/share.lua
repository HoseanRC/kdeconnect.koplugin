local json = require("json")
local socket = require("socket")
local ssl = require("ssl")
local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")
local _ = require("gettext")

local Plugin = require("./plugins/__init__").Plugin

local plugin_id = "kdeconnect.share"

local payload_transfers = {}

local function read_file_binary(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function write_file_binary(path, data)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(data)
    f:close()
    return true
end

local function get_plugin_dir()
    local info = debug.getinfo(1, "S")
    local dir = info.source:match("^@?(.*/)")
    return dir:match("(.*/)plugins/") or dir
end

local function get_download_path(filename)
    local base = get_plugin_dir() .. "received_files/"
    os.execute("mkdir -p \"" .. base .. "\"")
    local path = base .. filename
    local stem = filename:match("(.+)%.[^.]*$") or filename
    local ext = filename:match("%.[^.]*$") or ""
    local n = 1
    while io.open(path, "r") do
        n = n + 1
        path = base .. stem .. " (" .. n .. ")" .. ext
    end
    return path
end

local function process_payload_receive(transfer_id)
    local t = payload_transfers[transfer_id]
    if not t then return end

    if t.state == "connect" then
        local client, err = socket.connect(t.ip, t.port)
        if not client then
            UIManager:show(Notification:new {
                text = _("File transfer connect failed: ") .. (err or "unknown"),
            })
            payload_transfers[transfer_id] = nil
            return
        end
        client:settimeout(0)
        t.client = client
        t.state = "wrap_tls"
        UIManager:scheduleIn(0.1, function() process_payload_receive(transfer_id) end)
        return
    end

    if t.state == "wrap_tls" then
        local dir = get_plugin_dir()
        local tls_conn, err = ssl.wrap(t.client, {
            mode = "client",
            protocol = "tlsv1_2",
            certificate = dir .. "cert.pem",
            key = dir .. "key.pem",
            verify = "none",
        })
        if not tls_conn then
            t.client:close()
            payload_transfers[transfer_id] = nil
            return
        end
        t.tls = tls_conn
        t.state = "handshake"
        UIManager:scheduleIn(0.1, function() process_payload_receive(transfer_id) end)
        return
    end

    if t.state == "handshake" then
        t.tls:settimeout(0)
        local ok, err = t.tls:dohandshake()
        if ok then
            t.state = "receiving"
            UIManager:scheduleIn(0.1, function() process_payload_receive(transfer_id) end)
            return
        end
        if err == "wantread" or err == "wantwrite" then
            UIManager:scheduleIn(0.1, function() process_payload_receive(transfer_id) end)
            return
        end
        t.client:close()
        payload_transfers[transfer_id] = nil
        return
    end

    if t.state == "receiving" then
        t.tls:settimeout(0)
        local remaining = t.payload_size - t.received
        local chunk_size = math.min(remaining, 8192)
        local data, err = t.tls:receive(chunk_size)
        if data then
            t.data = t.data .. data
            t.received = t.received + #data
            if t.received >= t.payload_size then
                local save_path = get_download_path(t.filename)
                write_file_binary(save_path, t.data)
                UIManager:show(Notification:new {
                    text = _("Received file: ") .. t.filename,
                })
                payload_transfers[transfer_id] = nil
                return
            end
            UIManager:scheduleIn(0.05, function() process_payload_receive(transfer_id) end)
            return
        end
        if err == "timeout" or err == "wantread" then
            UIManager:scheduleIn(0.1, function() process_payload_receive(transfer_id) end)
            return
        end
        t.client:close()
        payload_transfers[transfer_id] = nil
        return
    end
end

local function download_payload(device, port, payload_size, filename)
    local transfer_id = "dl_" .. device.deviceId .. "_" .. tostring(os.time())
    payload_transfers[transfer_id] = {
        state = "connect",
        ip = device.ip,
        port = port,
        payload_size = payload_size,
        filename = filename,
        data = "",
        received = 0,
    }
    UIManager:show(Notification:new {
        text = _("Receiving: ") .. filename,
    })
    process_payload_receive(transfer_id)
end

local function process_payload_send_accept(transfer_id)
    local t = payload_transfers[transfer_id]
    if not t then return end

    if t.state == "accepting" then
        t.server:settimeout(0)
        local client = t.server:accept()
        if client then
            client:settimeout(0)
            t.client = client
            t.state = "wrap_tls"
            UIManager:scheduleIn(0.1, function() process_payload_send_accept(transfer_id) end)
            return
        end
        UIManager:scheduleIn(0.1, function() process_payload_send_accept(transfer_id) end)
        return
    end

    if t.state == "wrap_tls" then
        local dir = get_plugin_dir()
        local tls_conn, err = ssl.wrap(t.client, {
            mode = "server",
            protocol = "tlsv1_2",
            certificate = dir .. "cert.pem",
            key = dir .. "key.pem",
            verify = "none",
        })
        if not tls_conn then
            t.client:close()
            t.server:close()
            payload_transfers[transfer_id] = nil
            return
        end
        t.tls = tls_conn
        t.state = "handshake"
        UIManager:scheduleIn(0.1, function() process_payload_send_accept(transfer_id) end)
        return
    end

    if t.state == "handshake" then
        t.tls:settimeout(0)
        local ok, err = t.tls:dohandshake()
        if ok then
            t.state = "sending"
            UIManager:scheduleIn(0.1, function() process_payload_send_accept(transfer_id) end)
            return
        end
        if err == "wantread" or err == "wantwrite" then
            UIManager:scheduleIn(0.1, function() process_payload_send_accept(transfer_id) end)
            return
        end
        t.client:close()
        t.server:close()
        payload_transfers[transfer_id] = nil
        return
    end

    if t.state == "sending" then
        t.tls:settimeout(0)
        local remaining = t.payload_size - t.offset
        local chunk_size = math.min(remaining, 8192)
        local chunk = t.content:sub(t.offset + 1, t.offset + chunk_size)
        local ok, err = t.tls:send(chunk)
        if ok then
            t.offset = t.offset + #chunk
            if t.offset >= t.payload_size then
                t.tls:close()
                t.client:close()
                t.server:close()
                UIManager:show(Notification:new {
                    text = _("Sent file: ") .. t.filename,
                })
                payload_transfers[transfer_id] = nil
                return
            end
            UIManager:scheduleIn(0.05, function() process_payload_send_accept(transfer_id) end)
            return
        end
        if err == "timeout" or err == "wantwrite" then
            UIManager:scheduleIn(0.1, function() process_payload_send_accept(transfer_id) end)
            return
        end
        t.client:close()
        t.server:close()
        payload_transfers[transfer_id] = nil
        return
    end
end

local function share_file(device, filepath)
    local filename = filepath:match("([^/]+)$")
    if not filename then
        filename = filepath
    end

    local content = read_file_binary(filepath)
    if not content then
        UIManager:show(Notification:new {
            text = _("Could not read file: ") .. filepath,
        })
        return
    end

    local server = socket.tcp4()
    server:setoption("reuseaddr", true)
    server:settimeout(0)
    local ok, err = server:setsockname("*", 0)
    if not ok then
        server:close()
        UIManager:show(Notification:new {
            text = _("Failed to create transfer socket: ") .. tostring(err),
        })
        return
    end
    ok, err = server:listen(1)
    if not ok then
        server:close()
        UIManager:show(Notification:new {
            text = _("Failed to listen: ") .. tostring(err),
        })
        return
    end

    local _ip, port = server:getsockname()
    local transfer_id = "up_" .. device.deviceId .. "_" .. tostring(os.time())

    payload_transfers[transfer_id] = {
        state = "accepting",
        server = server,
        content = content,
        payload_size = #content,
        filename = filename,
        offset = 0,
    }

    local packet = {
        id = 0,
        type = plugin_id .. ".request",
        body = {
            filename = filename,
        },
        payloadSize = #content,
        payloadTransferInfo = {
            port = port,
        },
    }
    local encoded = json.encode(packet)
    local ok, err = device.connection.tls:send(encoded .. "\n")
    if not ok then
        server:close()
        payload_transfers[transfer_id] = nil
        UIManager:show(Notification:new {
            text = _("Failed to send share request: ") .. (err or "unknown"),
        })
        return
    end

    UIManager:show(Notification:new {
        text = _("Sharing: ") .. filename,
    })
    process_payload_send_accept(transfer_id)
end

local function share_handler(plugin, packet, device)
    local body = packet.body or {}
    local payload_info = packet.payloadTransferInfo or packet.payloadInfo

    if body.text then
        UIManager:show(Notification:new {
            text = _("Shared text from ") .. (device.deviceName or "device") .. ":\n" .. body.text,
        })
    elseif body.url then
        UIManager:show(Notification:new {
            text = _("Shared URL from ") .. (device.deviceName or "device") .. ":\n" .. body.url,
        })
    elseif body.filename and payload_info and payload_info.port and packet.payloadSize then
        download_payload(device, payload_info.port, packet.payloadSize, body.filename)
    end
end

--- Create and return the share plugin
---@return Plugin
return Plugin:new(
    plugin_id,
    "Share",
    share_handler,
    { "request", "request.update" },
    { "request" }
)
