local json = require("json")
local socket = require("socket")
local ssl = require("ssl")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local ConfirmBox = require("ui/widget/confirmbox")
local UIManager = require("ui/uimanager")
-- local posix = require("posix")

local function log(data)
    UIManager:show(InfoMessage:new {
        text = data,
    })
end

local function contains(table, val)
    for i = 1, #table do
        if table[i] == val then
            return true
        end
    end
    return false
end

local function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

local CERT_PEM = [[-----BEGIN CERTIFICATE-----
MIIDBzCCAe+gAwIBAgIUH+KS+f0YAM1Zke5vhors+8IwK0MwDQYJKoZIhvcNAQEL
BQAwEzERMA8GA1UEAwwIa29yZWFkZXIwHhcNMjYwNjI0MTEyNDQxWhcNMzYwNjIx
MTEyNDQxWjATMREwDwYDVQQDDAhrb3JlYWRlcjCCASIwDQYJKoZIhvcNAQEBBQAD
ggEPADCCAQoCggEBAKn0qb41FeWVnacOfsgwhLDe8WC7nXwqrwIHcgm/vSpUrTwC
/7a9LO2xFioX36ui7QGVotzdFYIrni9y2BNjiV1AsGoI2yaf/iRVVPMGQMrsT8Bu
1YSrPz8sB57UqBUZdfF1Lz2pyCuivtQFnTdFyZEy1jtG5RuOJc24rqH8Yjnx/f2S
TlADOc0R6qdZ5VfR2j3LJh4LIE1O6lCzR3kZPesYil9i08lnI/AtnKqw5zUVH4++
ls0JM2Tguix5PWvcv9Vmfj6e7yU0u1IXK+hN3U/lBheHspfhpetRzRUGiGySoVSJ
C3/OaBlSWDNvWbYJF1T0zrVf1VdT38IJwpyAepECAwEAAaNTMFEwHQYDVR0OBBYE
FMl/UIarqTsFRAjIlvej4q7UjfslMB8GA1UdIwQYMBaAFMl/UIarqTsFRAjIlvej
4q7UjfslMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAI5VaCZ1
6nMr0dWNaVQ/h2tqBGnD8LLypsJs6jKnFqzrE+ugqZsiCXBElAamGspvPUuVBGS1
0LCeo7GwdpRCtvJ7CEIxmkjNyC1XWnT02xgHE9/GfNfw/FRy99KXJxpY+YGoguAr
csptgWFnhfqdPQm7RNqZkF8Z6zd9gcExTeDReh8dlBljtHdRK16QbaLl86c7kolE
0mHM9xFJrZb2iFpXWl3pjRmhRuGJQEvOqnYXvZ7P74leVTYWK1e5CcXL9/hDCdww
HFNYk1DtZdl5ApwQmoC61RqJ1F6Wl2ZifVF853GLJ7WWdQ6dTlkrIKQPIPdTlP53
bMZHjuhGhrmRu4o=
-----END CERTIFICATE-----]]

local KEY_PEM = [[-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCp9Km+NRXllZ2n
Dn7IMISw3vFgu518Kq8CB3IJv70qVK08Av+2vSztsRYqF9+rou0BlaLc3RWCK54v
ctgTY4ldQLBqCNsmn/4kVVTzBkDK7E/AbtWEqz8/LAee1KgVGXXxdS89qcgror7U
BZ03RcmRMtY7RuUbjiXNuK6h/GI58f39kk5QAznNEeqnWeVX0do9yyYeCyBNTupQ
s0d5GT3rGIpfYtPJZyPwLZyqsOc1FR+PvpbNCTNk4LoseT1r3L/VZn4+nu8lNLtS
FyvoTd1P5QYXh7KX4aXrUc0VBohskqFUiQt/zmgZUlgzb1m2CRdU9M61X9VXU9/C
CcKcgHqRAgMBAAECggEADcOKMaTD8rVksKBMZTMEs/xCKRbYoLMmPDBVLHPyQmjc
JLWLdwWoC1HhnSQU0aYespenOmLPOJ0GsQoIdL2FZN91ygiQkva3EsM0X4AcpDJy
HP/828MwmpGaxmKrgBXxRs46NrC2zM3fzXTs8Ap/Ufp/fgp2SH6BEkGIJwc0/0M3
ghqNn8l3myXK1sNrOrSVV+tfhlyle01P72A5r1bjMY9Ef1rnQbSKm1asyOUlUqfu
A5lnW7eQZ7Z+NhOYn1JU99Cuiddtf3gvaZBYkVfC7A9AmCWmUC6YBq8KFvYz9hCv
E24cYwiT/HI6aOzbHwqgbL7VPu9tgXFmtWSNxn3gyQKBgQDZItkqjO1vISfqQXZb
iIv1Sj6Nk2eSxNKnI1TdgHSbWWoCXHMQUDwanpMW/yGb6Zf3ghRSF9dZ3MGTSLU5
wMmudqICwQTX5ZP6VcTRPUeHSwzmTb44waQgQH+EblbssojYpuYGvfqpQPDuGcmY
WSxgvuFhjofk5R8dCzBRo71XFQKBgQDIYAONnlOh4mxH/4ZNlX+H+xyHGADeTYec
KME3tW0RfB+KOWvW1XkQONJxbsnpXbWCXpS7730i9D4GbNSxjfGOPW5LwygM1cU5
Y42mrNd9BkI7Ebc4rm2NhBYu/aMYa/08gX53YJ0rDmRQvvrDzbFaUkuSHCCU+i5i
7qSeCzp0jQKBgQCtiN1Y1WKZEz2MSZ8nDl0Uv654hZscQHM+os0bbaND2NURaAOJ
wSYX/C4ADg01Rx5t8Cb/aRByQCzw4gX8TyigZy2Z19tgFJoMUunGdBwrc36uvOlP
AOuD3yhKlcigyRr3U4O5VbHz/PPQxwlH2dTOyR7lUf0noToZgyytwpf69QKBgQCS
+IniqEzjoraVoMEbyxn93ZwxItQQOoHLcsE2YWacupRPyIpmy7G+yk7hUMfc2hU2
iLVDnAgHSWrtP4pKqbiSAlESVRTdRTciPvk5VfHBDIQr23SuqJJGiKnU0cl9MkhO
xxTB7yWY3TeLWmmIkSkS/OXdR7BGVbMMccpg+g9oSQKBgAG6lneUFOaiBrhBAHwm
5086XIHQs57apAVdXkKS0swo/icXQE8mqKmGd+PWzGCIaTW1FQ23WgM7kWp2L7Su
s1f5oPxWClD9Ryc6SCTV4VKI3Frx22opcN0Fdhkw2ajtW4+wZmilW60zFUGeJseA
ZUI/ikswbH3CMAugUZpSkhSl
-----END PRIVATE KEY-----]]

local KDEConnectPlugin = WidgetContainer:extend {
    name = "kdeconnect",
    is_doc_only = false,
    device_id = nil,
    protocol_version = 8,
    tcp_port = 1716,
    udp_socket = socket.udp4(),
    discovered_devices = {},
    device_name = "KOReader",
    device_type = "tablet",
    capabilities = {
        "kdeconnect.mock.echo",
    },
    connections = {},
    paired_devices = {},
    tcp_server = nil,
    plugin_dir = nil,
    tls_cert = nil,
    tls_key = nil,
}

local function values(t)
    local i = 0
    return function()
        i = i + 1; return t[i]
    end
end

-- ────────────────────────── Get IPs ───────────────────────────

local function getips()
    local ips = {}

    local f = io.popen("ip -o -4 addr show")
    if not f then
        return ips
    end
    for line in f:lines() do
        local ip = line:match("inet (%d+%.%d+%.%d+%.%d+)")
        if ip then
            table.insert(ips, ip)
        end
    end
    f:close()

    for _, ip in ipairs(ips) do
        print(ip)
    end

    return ips
end

function KDEConnectPlugin:_get_plugin_dir()
    if not self.plugin_dir then
        local info = debug.getinfo(2, "S")
        self.plugin_dir = info.source:match("^(.*/)")
    end
    return self.plugin_dir
end

function KDEConnectPlugin:_read_file(path)
    local f = io.open(path, "r")
    if not f then return end
    local content = f:read("*a")
    f:close()
    return content
end

function KDEConnectPlugin:_write_file(path, content)
    local f, err = io.open(path, "w")
    if not f then return false, err end
    f:write(content)
    f:close()
    return true
end

function KDEConnectPlugin:_load_or_create_identity()
    local dir = self:_get_plugin_dir()
    local path = dir .. "identity.json"
    local data = self:_read_file(path)
    if data then
        local ok, parsed = pcall(json.decode.decode, data)
        if ok and parsed and parsed.device_id then
            self.device_id = parsed.device_id
            return
        end
    end
    self.device_id = self:_generate_device_id()
    self:_write_file(path, json.encode({ device_id = self.device_id }))
end

function KDEConnectPlugin:_generate_device_id()
    math.randomseed(os.time())
    local id = ""
    for _ = 1, 32 do
        id = id .. string.format("%x", math.random(0, 15))
    end
    return id
end

function KDEConnectPlugin:_ensure_certificate()
    local ok, cert = pcall(ssl.loadcertificate, CERT_PEM)
    if ok then
        self.tls_cert = cert
        self.tls_key = KEY_PEM
    end
end

function KDEConnectPlugin:_encode(packet)
    return json.encode(packet)
end

function KDEConnectPlugin:_decode(data)
    local ok, packet = pcall(json.decode.decode, data)
    if ok then return packet end
end

-- ──────────────────────────── Discovery ────────────────────────────

function KDEConnectPlugin:_create_discovery_packet()
    return self:_encode({
        id = 0,
        type = "kdeconnect.identity",
        body = {
            deviceId = self.device_id,
            deviceName = "hoseanrc-kindle",
            deviceType = "desktop",
            protocolVersion = self.protocol_version,
            tcpPort = self.tcp_port,
            incomingCapabilities = {
                "kdeconnect.notification",
                "kdeconnect.ping"
            },
            outgoingCapabilities = {},
        },
    })
end

function KDEConnectPlugin:start_discovery()
    self.udp_socket:setoption("broadcast", true)
    self.udp_socket:settimeout(0)
    self.udp_socket:setsockname("*", self.tcp_port)
    self:_broadcast_presence()
end

function KDEConnectPlugin:_broadcast_presence()
    local packet_str = self:_create_discovery_packet()
    local ok = self.udp_socket:sendto(packet_str, "255.255.255.255", 1716)
    if ok then
        UIManager:scheduleIn(0.5, function()
            self:_receive_discovery_responses()
        end)
    end
end

function KDEConnectPlugin:_receive_discovery_responses()
    local data, ip, port = self.udp_socket:receivefrom()
    local localIp, localPort = self.udp_socket:getsockname()
    while data do
        local packet = self:_decode(data)
        if packet and packet.body then
            log("got UDP JSON from " .. ip)
            if type(packet.body.outgoingCapabilities) == "table"
                and tablelength(packet.body.outgoingCapabilities) > 0
                and (not contains(getips(), ip)) then
                local packet_str = self:_create_discovery_packet()
                local ok = self.udp_socket:sendto(packet_str, ip, packet.tcpPort or 1716)
            elseif packet.type == "kdeconnect.identity"
                and packet.body and packet.body.deviceId ~= self.device_id then
                -- UIManager:show(InfoMessage:new {
                --     text = "packet: " .. packet.id .. " ok " .. (packet.id == 0 and "yes" or "no"),
                -- })
                local dev = packet.body
                if not self.discovered_devices[dev.deviceId] then
                    dev.ip = ip
                    self.discovered_devices[dev.deviceId] = dev
                    UIManager:show(InfoMessage:new {
                        text = "Discovered: " .. (dev.deviceName or dev.deviceId),
                    })
                end
            end
        else
            log("got UDP Packet from " .. ip)
        end
        data, ip = self.udp_socket:receivefrom()
    end
    UIManager:scheduleIn(0.5, function()
        self:_receive_discovery_responses()
    end)
end

-- ──────────────────────────── TCP Server ────────────────────────────

function KDEConnectPlugin:start_tcp_server()
    -- log("starting tcp")
    self.tcp_server = socket.tcp4()
    self.tcp_server:setoption("reuseaddr", true)
    self.tcp_server:settimeout(0)
    local ok, err = self.tcp_server:setsockname("*", self.tcp_port)
    if not ok then
        UIManager:show(InfoMessage:new { text = "TCP server bind failed: " .. err })
        return
    end
    ok, err = self.tcp_server:listen(5)
    if not ok then
        UIManager:show(InfoMessage:new { text = "TCP server listen failed: " .. err })
        return
    end
    self:_poll_tcp_server()
end

function KDEConnectPlugin:_poll_tcp_server()
    -- log("tcp")
    local client = self.tcp_server:accept()
    while client do
        log("connected")
        self.udp_socket:sendto("connected tcp\n", "10.169.63.146", 11111)
        self:_handle_incoming_connection(client)
        client = self.tcp_server:accept()
    end
    UIManager:scheduleIn(0.1, function()
        self:_poll_tcp_server()
    end)
end

function KDEConnectPlugin:_handle_incoming_connection(client)
    self.udp_socket:sendto("#1 tcp\n", "10.169.63.146", 11111)
    client:settimeout(0)
    local line = client:receive("*l")
    if not line then
        client:close()
        return
    end
    self.udp_socket:sendto("#2 tcp\n", "10.169.63.146", 11111)
    log(line)
    local packet = self:_decode(line)
    if not packet or packet.type ~= "kdeconnect.identity"
        or not packet.body or not packet.body.deviceId then
        client:close()
        return
    end
    self.udp_socket:sendto("#3 tcp\n", "10.169.63.146", 11111)
    local body = packet.body
    if body.targetDeviceId and body.targetDeviceId ~= self.device_id then
        client:close()
        return
    end
    self.udp_socket:sendto("#4 tcp\n", "10.169.63.146", 11111)
    local client_id = body.deviceId
    local client_proto = body.protocolVersion or 7
    local tls, err = self:_wrap_server_tls(client)
    self.udp_socket:sendto("tls err: " .. err .. "\n", "10.169.63.146", 11111)
    if not tls then
        self.udp_socket:sendto("tls failed\n", "10.169.63.146", 11111)
        client:close()
        return
    end
    local full = self:_create_full_identity()
    self.udp_socket:sendto("#5 tcp\n", "10.169.63.146", 11111)
    tls:send(full .. "\n")
    tls:settimeout(5)
    local remote_line = tls:receive("*l")
    if not remote_line then
        tls:close()
        client:close()
        return
    end
    self.udp_socket:sendto("#6 tcp\n", "10.169.63.146", 11111)
    local remote_pkt = self:_decode(remote_line)
    if not remote_pkt or remote_pkt.type ~= "kdeconnect.identity" then
        tls:close()
        client:close()
        return
    end
    self.udp_socket:sendto("#7 tcp\n", "10.169.63.146", 11111)
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
    UIManager:show(InfoMessage:new {
        text = "Connected: " .. (dev.deviceName or client_id),
    })
    self:_start_polling(client_id)
end

function KDEConnectPlugin:_wrap_server_tls(client)
    return ssl.wrap(client, {
        mode = "server",
        protocol = "tlsv1_2",
        certificate = self.tls_cert,
        key = self.tls_key,
        verify = "none",
    })
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

function KDEConnectPlugin:connect_to_device(device_id)
    local device = self.discovered_devices[device_id]
    if not device then
        UIManager:show(InfoMessage:new { text = "Device not found" })
        return
    end
    local tcp = socket.tcp()
    tcp:settimeout(5)
    local ok, err = tcp:connect(device.ip, device.tcpPort or 1716)
    if not ok then
        UIManager:show(InfoMessage:new { text = "TCP connect failed: " .. err })
        return
    end
    local init = self:_create_initial_identity(device.deviceId, device.protocolVersion)
    tcp:send(init .. "\n")
    local tls, tls_err = ssl.wrap(tcp, {
        mode = "client",
        protocol = "tlsv1_2",
        verify = "none",
    })
    if not tls then
        tcp:close()
        UIManager:show(InfoMessage:new { text = "TLS wrap failed" })
        return
    end
    tls:settimeout(5)
    ok, tls_err = tls:dohandshake()
    if not ok then
        tcp:close()
        UIManager:show(InfoMessage:new { text = "TLS handshake failed" })
        return
    end
    local full = self:_create_full_identity()
    tls:send(full .. "\n")
    self.connections[device_id] = {
        tcp = tcp,
        tls = tls,
        device = device,
    }
    UIManager:show(InfoMessage:new { text = "Connected to " .. (device.deviceName or device.deviceId) })
    self:_start_polling(device_id)
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
    if reason then
        UIManager:show(InfoMessage:new { text = "Disconnected: " .. reason })
    end
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
        local packet = self:_decode(line)
        if packet then
            self:_dispatch_packet(device_id, packet)
        end
        line, err = conn.tls:receive("*l")
    end
    if err and err ~= "timeout" then
        self:_disconnect(device_id, err)
        return
    end
    self:_start_polling(device_id)
end

function KDEConnectPlugin:_dispatch_packet(device_id, packet)
    local t = packet.type
    if t == "kdeconnect.pair" then
        self:_handle_pair(device_id, packet.body)
    elseif t == "kdeconnect.mock.echo" then
        self:_handle_echo(packet.body)
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
    end
end

-- ──────────────────────────── Pairing ────────────────────────────

function KDEConnectPlugin:send_pair_request(device_id)
    local conn = self.connections[device_id]
    if not conn then
        UIManager:show(InfoMessage:new { text = "Not connected" })
        return
    end
    self:_send_json(conn, {
        id = 0,
        type = "kdeconnect.pair",
        body = {
            pair = true,
            timestamp = os.time(),
        },
    })
end

function KDEConnectPlugin:_handle_pair(device_id, body)
    local conn = self.connections[device_id]
    if not conn then return end
    if body.pair then
        if body.timestamp and math.abs(os.time() - body.timestamp) > 1800 then
            UIManager:show(InfoMessage:new { text = "Pairing request expired" })
            self:_send_pair_response(device_id, false)
            return
        end
        UIManager:show(ConfirmBox:new {
            text = "Pair with " .. (conn.device.deviceName or conn.device.deviceId) .. "?",
            ok_text = "Accept",
            cancel_text = "Reject",
            ok_callback = function()
                self:_send_pair_response(device_id, true)
                self.paired_devices[device_id] = true
                UIManager:show(InfoMessage:new { text = "Paired with " .. (conn.device.deviceName or device_id) })
            end,
            cancel_callback = function()
                self:_send_pair_response(device_id, false)
            end,
        })
    else
        UIManager:show(InfoMessage:new { text = "Pairing rejected by " .. (conn.device.deviceName or device_id) })
    end
end

function KDEConnectPlugin:_send_pair_response(device_id, accepted)
    local conn = self.connections[device_id]
    if not conn then return end
    self:_send_json(conn, {
        id = 0,
        type = "kdeconnect.pair",
        body = { pair = accepted },
    })
end

-- ──────────────────────────── Echo ────────────────────────────

function KDEConnectPlugin:_handle_echo(body)
    UIManager:show(InfoMessage:new { text = "Echo: " .. json.encode(body) })
end

-- ──────────────────────────── Init ────────────────────────────

function KDEConnectPlugin:init()
    self:_load_or_create_identity()
    self:_ensure_certificate()
    self:start_discovery()
    self:start_tcp_server()
end

return KDEConnectPlugin
