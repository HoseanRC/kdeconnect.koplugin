local json = require("json")
local socket = require("socket")
local ssl = require("ssl")
local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")
local FileChooser = require("ui/widget/filechooser")
local InfoMessage = require("ui/widget/infomessage")
local ButtonDialog = require("ui/widget/buttondialog")
local PathChooser = require("ui/widget/pathchooser")
local _ = require("gettext")

local Plugin = require("./plugins/__init__").Plugin
local PluginManager = require("./plugins/__init__").PluginManager

local plugin_id = "kdeconnect.share"

---@type Plugin
local plugin = nil

local payload_transfers = {}

local function select_download_directory()
    local chooser = nil
    local stored_path = plugin and (plugin.config and plugin.config.download_path or nil) or nil
    chooser = PathChooser:new {
        path = stored_path or (PluginManager.plugin_dir .. "received_files"),
        title = _("Select download directory"),
        onConfirm = function(path)
            if plugin then
                if not plugin.config then
                    plugin.config = {}
                end
                plugin.config.download_path = path .. "/"
                plugin:save()
            end
            UIManager:close(chooser)
        end,
    }
    UIManager:show(chooser)
end

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

local function get_download_path(filename)
    local base = PluginManager.plugin_dir .. "received_files/"
    if plugin and plugin.config and plugin.config.download_path then
        base = plugin.config.download_path
    end
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
        local dir = PluginManager.plugin_dir
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
        local dir = PluginManager.plugin_dir
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

local function file_chooser_share()
    local isConnected = false
    for _i, device in pairs(PluginManager.devices) do
        if device.connection then
            isConnected = true
            break
        end
    end
    if not isConnected then
        UIManager:show(InfoMessage:new {
            text = _("No devices are connected"),
            timeout = 3,
        })
        return
    end
    local filechooser = FileChooser:new {
        path = plugin.config.download_path,
        select_directory = false, -- Don't select directories
        show_files = true,
    }
    function filechooser:onFileSelect(file)
        UIManager:close(filechooser)
        local paired_devices = {}
        for _i, device in pairs(PluginManager.devices) do
            if device.deviceId then
                table.insert(paired_devices, device)
            end
        end

        table.sort(paired_devices, function(a, b)
            local a_name = a.deviceName or a.deviceId or ""
            local b_name = b.deviceName or b.deviceId or ""
            return a_name < b_name
        end)

        local buttonDialog = nil

        local buttons = {}
        ---@param device Device
        for __i, device in ipairs(paired_devices) do
            local label = device.deviceName or device.deviceId or _("Unknown device")
            table.insert(buttons, {
                {
                    text = label,
                    callback = function()
                        UIManager:close(buttonDialog)
                        share_file(device, file.path)
                    end,
                },
            })
        end

        buttonDialog = ButtonDialog:new {
            title = _("Choose a device to send the file to"),
            buttons = buttons,
            width_factor = 0.95,
        }

        UIManager:show(buttonDialog)
    end

    UIManager:show(filechooser)
end

plugin = Plugin:new(
    plugin_id,
    "Share",
    share_handler,
    { "request", "request.update" },
    { "request" },
    {
        kdeconnect_share = {
            text = _("Share file to device..."),
            sorting_hint = "network",
            callback = file_chooser_share
        },
        kdeconnect_share_settings = {
            text = _("Select download directory..."),
            sorting_hint = "network",
            callback = select_download_directory
        }
    }
)

return plugin
