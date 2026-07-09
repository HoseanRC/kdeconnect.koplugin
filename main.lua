local json = require("json")
local socket = require("socket")
local ssl = require("ssl")
local _ = require("gettext")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ConfirmBox = require("ui/widget/confirmbox")
local UIManager = require("ui/uimanager")
local File = require("./file")
local Table = require("./table")
local PluginManager = require("./plugins/__init__").PluginManager
local Device = require("./device")

--- @class KDEConnectPlugin
--- @field name string
--- @field is_doc_only boolean
--- @field protocol_version number
--- @field tcp_port number
--- @field udp_socket unknown
--- @field discovered_devices Device[]
--- @field device_name string
--- @field device_type string
--- @field capabilities table
--- @field plugin_manager PluginManager
--- @field connections table
--- @field paired_devices Device[]
--- @field tcp_server unknown
--- @field plugin_dir string
--- @field pending_connections table
local KDEConnectPlugin = WidgetContainer:extend {
    name = "kdeconnect",
    is_doc_only = false,
    protocol_version = 8,
    tcp_port = 1716,
    udp_socket = socket.udp4(),
    discovered_devices = {},
    device_name = "KOReader HoseanRC",
    device_type = "tablet",
    capabilities = {},
    plugin_manager = nil,
    connections = {},
    paired_devices = {},
    tcp_server = nil,
    plugin_dir = nil,
    pending_connections = {},
}

function KDEConnectPlugin:_print(a)
    self.udp_socket:sendto(a .. "\n", "10.208.233.146", 11111)
end

-- ────────────────────────── Get IPs ───────────────────────────

local function getips()
    local ips = {}
    local f = io.popen("ip -o -4 addr show")
    if not f then return ips end
    for line in f:lines() do
        local ip = line:match("inet (%d+%.%d+%.%d+%.%d+)")
        if ip then table.insert(ips, ip) end
    end
    f:close()
    return ips
end

local current_dir = nil

---
---returns current dir path
---
---@return string
---@nodiscard
local function plugin_dir()
    if current_dir then
        return current_dir
    end
    local info = debug.getinfo(2, "S")
    current_dir = info.source:match("^@?(.*/)")
    return current_dir
end

function KDEConnectPlugin:_load_config()
    local path = plugin_dir() .. "config.json"
    self:_print(tostring(debug.getinfo(2, "S").source:match("^@?(.*/)")))
    local data = File.read(path)
    if data then
        local ok, parsed = pcall(json.decode.decode, data)
        self:_print("parsing: " .. tostring(ok) .. " " .. tostring(parsed))
        if ok and parsed and parsed.device_id then
            self:_print("ID: " .. parsed.device_id)
            self.device_id = parsed.device_id
            return
        end
    end
    math.randomseed(os.time())
    self.device_id = ""
    for _ = 1, 32 do
        self.device_id = self.device_id .. string.format("%x", math.random(0, 15))
    end
    if not (File.exists(plugin_dir() .. "cert.pem") and File.exists(plugin_dir() .. "key.pem")) then
        local status = os.execute("cd " .. plugin_dir() .. '; ./genkey "' .. self.device_id .. '"')
        if status ~= 0 or status == false then
            self:_print("error in executing genkey")
            -- handle error and show solutions
            return
        end
    end
    File.write(path, json.encode({ device_id = self.device_id }))
end

function KDEConnectPlugin:_init_plugins()
    self.plugin_manager = PluginManager:new()
    self.plugin_manager:load_from_directory(plugin_dir() .. "plugins/")
    self:_print("Loaded " .. #self.plugin_manager.plugins .. " plugins")
end

function KDEConnectPlugin:_encode(packet)
    return json.encode(packet)
end

function KDEConnectPlugin:_decode(data)
    local ok, packet = pcall(json.decode.decode, data)
    if ok then return packet end
end

-- ──────────────────────────── Discovery ────────────────────────────

function KDEConnectPlugin:_create_discovery_packet(targetDeviceId, targetProtocolVersion)
    local body = {
        deviceId = self.device_id,
        deviceName = self.device_name,
        deviceType = self.device_type,
        protocolVersion = self.protocol_version,
        tcpPort = self.tcp_port,
        incomingCapabilities = self.capabilities,
        outgoingCapabilities = {},
    }

    if targetDeviceId then
        self:_print(targetDeviceId)
        body.targetDeviceId = targetDeviceId
    end
    if targetProtocolVersion then
        self:_print(targetProtocolVersion)
        body.targetProtocolVersion = tostring(targetProtocolVersion)
    end

    return self:_encode({
        id = 0,
        type = "kdeconnect.identity",
        body = body,
    })
end

function KDEConnectPlugin:start_discovery()
    self:_print("starting UDP")
    if not self.udp_socket_start then
        self.udp_socket = socket.udp4()
        local _, err = self.udp_socket:setsockname("*", 1716)
        if err then self:_print("UDP setsockname error: " .. err) end
        self.udp_socket_start = true
    end
    self.udp_socket:setoption("broadcast", true)
    self.udp_socket:settimeout(0)
    local packet_str = self:_create_discovery_packet()
    local ok = self.udp_socket:sendto(packet_str, "255.255.255.255", 1716)
    self:_receive_discovery_responses()
end

function KDEConnectPlugin:_process_pending_connection(conn_id)
    local pending = self.pending_connections[conn_id]
    if not pending then return end

    if pending.state == "connect" then
        local client, err = socket.connect(pending.ip, pending.port)
        if not client then
            self:_print("TCP connect failed: " .. (err or "unknown"))
            self.pending_connections[conn_id] = nil
            return
        end
        client:settimeout(0)
        pending.client = client
        pending.state = "send_identity"
        self:_print("TCP connected, sending identity")
        UIManager:scheduleIn(0.1, function()
            self:_process_pending_connection(conn_id)
        end)
        return
    end

    if pending.state == "send_identity" then
        local ok, err = pending.client:send(
            self:_create_discovery_packet(pending.target_id, pending.target_version) .. "\n"
        )
        if not ok then
            self:_print("TCP send failed: " .. (err or "unknown"))
            pending.client:close()
            self.pending_connections[conn_id] = nil
            return
        end
        pending.state = "wrap_tls"
        self:_print("Identity sent, wrapping TLS")
        UIManager:scheduleIn(0.1, function()
            self:_process_pending_connection(conn_id)
        end)
        return
    end

    if pending.state == "wrap_tls" then
        local tls, err = self:_wrap_server_tls(pending.client)
        if not tls then
            self:_print("TLS wrap failed: " .. (err or "unknown"))
            pending.client:close()
            self.pending_connections[conn_id] = nil
            return
        end
        pending.tls = tls
        pending.state = "handshake"
        self:_print("TLS wrapped, starting handshake")
        UIManager:scheduleIn(0.1, function()
            self:_process_pending_connection(conn_id)
        end)
        return
    end

    if pending.state == "handshake" then
        pending.tls:settimeout(0)
        local ok, err = pending.tls:dohandshake()
        if ok then
            pending.state = "receive_identity"
            self:_print("TLS handshake complete, receiving identity")
            UIManager:scheduleIn(0.1, function()
                self:_process_pending_connection(conn_id)
            end)
            return
        end
        if err == "wantread" or err == "wantwrite" then
            UIManager:scheduleIn(0.1, function()
                self:_process_pending_connection(conn_id)
            end)
            return
        end
        self:_print("TLS handshake failed: " .. (err or "unknown"))
        pending.client:close()
        self.pending_connections[conn_id] = nil
        return
    end

    if pending.state == "receive_identity" then
        pending.tls:settimeout(0)
        local line, err = pending.tls:receive("*l")
        if line then
            self:_print("Received identity: " .. line)
            pending.state = "send_full_identity"
            UIManager:scheduleIn(0.1, function()
                self:_process_pending_connection(conn_id)
            end)
            return
        end
        if err == "timeout" or err == "wantread" then
            UIManager:scheduleIn(0.1, function()
                self:_process_pending_connection(conn_id)
            end)
            return
        end
        self:_print("Receive identity failed: " .. (err or "unknown"))
        pending.client:close()
        self.pending_connections[conn_id] = nil
        return
    end

    if pending.state == "send_full_identity" then
        local pkt = self:_create_discovery_packet()
        self:_print("sending: " .. pkt)
        local ok, err = pending.tls:send(pkt .. "\n")
        if ok then
            self:_print("Sent full identity, connection complete")
            local dev = Device:new(
                pending.ip,
                pending.target_id,
                pending.device_name,
                "unknown",
                pending.target_version,
                pending.port,
                {},
                {}
            )
            self.discovered_devices[pending.target_id] = dev
            self.connections[pending.target_id] = {
                tcp = pending.client,
                tls = pending.tls,
                device = dev,
            }
            self.pending_connections[conn_id] = nil
            self:_start_polling(pending.target_id)
            return
        end
        self:_print("Send full identity failed: " .. (err or "unknown"))
        pending.client:close()
        self.pending_connections[conn_id] = nil
        return
    end
end

function KDEConnectPlugin:_receive_discovery_responses()
    local data, ip = self.udp_socket:receivefrom()
    while data do
        self:_print("got UDP packet: " .. data)
        local packet = self:_decode(data)
        if packet and packet.body then
            if type(packet.body.outgoingCapabilities) == "table"
                and Table.length(packet.body.outgoingCapabilities) > 0
                and (not Table.contains(getips(), ip)) then
                -- device has capabilities, initiate non-blocking TCP connection
                local conn_id = packet.body.deviceId
                self:_print("initiating tcp: [" .. ip .. "]:" .. (packet.body.tcpPort or 1716))
                self.pending_connections[conn_id] = {
                    state = "connect",
                    ip = ip,
                    port = packet.body.tcpPort or 1716,
                    target_id = packet.body.deviceId,
                    target_version = packet.body.protocolVersion,
                    device_name = packet.body.deviceName or conn_id,
                }
                self:_process_pending_connection(conn_id)
            elseif packet.type == "kdeconnect.identity"
                and packet.body and packet.body.deviceId ~= self.device_id then
                local dev = packet.body
                if not self.discovered_devices[dev.deviceId] then
                    dev.ip = ip
                    self.discovered_devices[dev.deviceId] = dev
                    self:_print("Discovered: " .. (dev.deviceName or dev.deviceId))
                end
            end
        end
        data, ip = self.udp_socket:receivefrom()
    end
    UIManager:scheduleIn(0.5, function()
        self:_receive_discovery_responses()
    end)
end

-- ──────────────────────────── TCP Server ────────────────────────────

function KDEConnectPlugin:start_tcp_server()
    self.tcp_server = socket.tcp4()
    self.tcp_server:setoption("reuseaddr", true)
    self.tcp_server:settimeout(0)
    local ok, err = self.tcp_server:setsockname("*", 1716)
    if not ok then
        self:_print("TCP server bind failed: " .. err)
        return
    end
    ok, err = self.tcp_server:listen(5)
    if not ok then
        self:_print("TCP server listen failed: " .. err)
        return
    end
    self:_poll_tcp_server()
end

function KDEConnectPlugin:_poll_tcp_server()
    local client = self.tcp_server:accept()
    while client do
        self:_print("Incoming TCP connection")
        self:_handle_incoming_connection(client)
        client = self.tcp_server:accept()
    end
    UIManager:scheduleIn(0.1, function()
        self:_poll_tcp_server()
    end)
end

function KDEConnectPlugin:_handle_incoming_connection(client)
    client:settimeout(0)
    local line = client:receive("*l")
    if not line then
        client:close()
        return
    end
    local packet = self:_decode(line)
    if not packet or packet.type ~= "kdeconnect.identity"
        or not packet.body or not packet.body.deviceId then
        client:close()
        return
    end
    local body = packet.body
    if body.targetDeviceId and body.targetDeviceId ~= self.device_id then
        client:close()
        return
    end
    local client_id = body.deviceId
    local client_proto = body.protocolVersion or 7
    local tls = self:_wrap_client_tls(client)
    if not tls then
        client:close()
        return
    end
    local ok, err = tls:dohandshake()
    self:_print("TLS handshake: " .. (ok and "OK" or "FAIL") .. " " .. (err or ""))
    if not ok then
        client:close()
        return
    end
    local full = self:_create_full_identity()
    tls:send(full .. "\n")
    tls:settimeout(0)
    local remote_line = tls:receive("*l")
    if not remote_line then
        tls:close()
        client:close()
        return
    end
    local remote_pkt = self:_decode(remote_line)
    if not remote_pkt or remote_pkt.type ~= "kdeconnect.identity" then
        tls:close()
        client:close()
        return
    end
    local packet_str = self:_create_discovery_packet()
    tls:send(packet_str)
    local remote = remote_pkt.body
    local dev = {
        ip = client:getpeername(),
        deviceId = client_id,
        deviceName = remote.deviceName or body.deviceName or client_id,
        deviceType = remote.deviceType,
        protocolVersion = client_proto,
        tcpPort = body.tcpPort or 1716,
        incomingCapabilities = remote.incomingCapabilities or {},
        outgoingCapabilities = remote.outgoingCapabilities or {},
    }
    self.discovered_devices[client_id] = dev
    self.connections[client_id] = {
        tcp = client,
        tls = tls,
        device = dev,
    }
    self:_print("Connected: " .. (dev.deviceName or client_id))
    self:_start_polling(client_id)
end

function KDEConnectPlugin:_wrap_client_tls(client)
    local cert_path = plugin_dir() .. "cert.pem"
    local key_path = plugin_dir() .. "key.pem"
    local tls, err = ssl.wrap(client, {
        mode = "client",
        protocol = "tlsv1_2",
        certificate = cert_path,
        key = key_path,
        verify = "none",
    })
    if err then
        self:_print("TLS wrap error: " .. err)
    end
    return tls
end

function KDEConnectPlugin:_wrap_server_tls(client)
    local cert_path = plugin_dir() .. "cert.pem"
    local key_path = plugin_dir() .. "key.pem"
    self:_print("wrapping tls")
    local tls, err = ssl.wrap(client, {
        mode = "server",
        protocol = "tlsv1_2",
        certificate = cert_path,
        key = key_path,
        verify = "none",
    })
    self:_print("TLS wrap complete")
    if err then
        self:_print("TLS wrap error: " .. err)
    end
    return tls
end

function KDEConnectPlugin:_create_full_identity()
    return self:_encode({
        id = 0,
        type = "kdeconnect.identity",
        body = {
            deviceId = self.device_id,
            protocolVersion = self.protocol_version,
            deviceName = self.device_name,
            deviceType = self.device_type,
            incomingCapabilities = self.capabilities,
            outgoingCapabilities = self.capabilities,
        },
    })
end

-- ──────────────────────────── Outbound Connection ──────────────────

function KDEConnectPlugin:_create_initial_identity(target_id, target_version)
    return self:_encode({
        id = 0,
        type = "kdeconnect.identity",
        body = {
            deviceId = self.device_id,
            protocolVersion = self.protocol_version,
            targetDeviceId = target_id,
            targetProtocolVersion = target_version,
        },
    })
end

-- ──────────────────────────── Packet Send/Recv ─────────────────────

function KDEConnectPlugin:_send_json(conn, packet)
    local ok, err = conn.tls:send(self:_encode(packet) .. "\n")
    if not ok then
        self:_disconnect(conn.device.deviceId, "Send failed: " .. err)
    end
    return ok
end

function KDEConnectPlugin:_disconnect(device_id, reason)
    local conn = self.connections[device_id]
    if not conn then return end
    pcall(conn.tls.close, conn.tls)
    pcall(conn.tcp.close, conn.tcp)
    self.connections[device_id] = nil
    self:_print("Disconnected: " .. reason)
end

-- ──────────────────────────── Packet Loop ────────────────────────────

function KDEConnectPlugin:_start_polling(device_id)
    UIManager:scheduleIn(0.5, function()
        self:_poll_connection(device_id)
    end)
end

function KDEConnectPlugin:_poll_connection(device_id)
    local conn = self.connections[device_id]
    if not conn then return end
    conn.tls:settimeout(0)
    local line, err = conn.tls:receive("*l")
    while line do
        self:_print("RX: " .. line)
        local packet = self:_decode(line)
        if packet then
            self:_dispatch_packet(device_id, packet)
        end
        line, err = conn.tls:receive("*l")
    end
    if err and (err ~= "timeout" and err ~= "wantread") then
        self:_disconnect(device_id, err)
        return
    end
    self:_start_polling(device_id)
end

function KDEConnectPlugin:_dispatch_packet(device_id, packet)
    local t = packet.type
    if t == "kdeconnect.pair" then
        self:_handle_pair(device_id, packet.body)
    elseif t == "kdeconnect.identity" then
        local body = packet.body
        if body.deviceId then
            local dev = self.discovered_devices[device_id]
            if dev then
                dev.deviceName = body.deviceName or dev.deviceName
                dev.deviceType = body.deviceType or dev.deviceType
                dev.incomingCapabilities = body.incomingCapabilities or dev.incomingCapabilities
                dev.outgoingCapabilities = body.outgoingCapabilities or dev.outgoingCapabilities
            end
        end
        -- Let plugin manager handle plugin-specific packets
    else
        if self.plugin_manager then
            socket.udp4():sendto("#1\n", "10.208.233.146", 11111)
            local handled = self.plugin_manager:handle_packet(packet, self.discovered_devices[device_id])
            if handled then
                return
            end
        end
        -- self:_print("Unknown packet type: " .. t)
    end
end

-- ──────────────────────────── Pairing ────────────────────────────

function KDEConnectPlugin:_handle_pair(device_id, body)
    local conn = self.connections[device_id]
    if not conn then return end
    local name = conn.device.deviceName or device_id
    if body.pair then
        -- Note: E-readers are not meant to be used for real time chat, so in most cases, the time is inaccurate
        -- we will need to ignore expiration in this case
        --if body.timestamp and math.abs(os.time() - body.timestamp) > 1800 then
        --    self:_print("Pairing request from " ..
        --    name .. " expired! (current time: " .. os.time() .. ", pair time: " .. body.timestamp .. ")")
        --    self:_send_pair_response(device_id, false)
        --    return
        --end

        UIManager:show(ConfirmBox:new {
            text = _("Device \"" .. name .. "\" sent a pair request.\nDo you want to pair?"),
            ok_text = _("Pair"),
            ok_callback = function()
                self:_send_pair_response(device_id, true)
            end,
            cancel_callback = function()
                self:_send_pair_response(device_id, false)
            end
        })
    else
        self:_print("Pairing rejected/unpaired by " .. name)
    end
end

function KDEConnectPlugin:_send_pair_response(device_id, accepted)
    self.paired_devices[device_id] = accepted
    local conn = self.connections[device_id]
    if not conn then return end
    self:_send_json(conn, {
        id = 0,
        type = "kdeconnect.pair",
        body = { pair = accepted },
    })
end

-- ──────────────────────────── Init ────────────────────────────

local initialised = false

function KDEConnectPlugin:init()
    if initialised then return end
    initialised = true

    self:_load_config()
    self:_init_plugins()
    self:start_discovery()
    self:start_tcp_server()
end

return KDEConnectPlugin
