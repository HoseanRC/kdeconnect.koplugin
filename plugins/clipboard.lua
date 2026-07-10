local Plugin = require("./plugins/__init__").Plugin
local PluginManager = require("./plugins/__init__").PluginManager
local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")
local Device = require("device")
local _ = require("gettext")

local plugin_id = "kdeconnect.clipboard"

local originalSetClipboardText = Device.input.setClipboardText

local lastClipboardContent = nil

local checkCopy

---@param text string
function Device.input.setClipboardText(text)
  if text ~= lastClipboardContent and text ~= "" then
    local devices = PluginManager:get_connected_devices()
    for _, device in pairs(devices) do
      device:send("", {
        content = text
      }, plugin_id)
    end
    lastClipboardContent = text
  end
end

---@param plugin Plugin Plugin instance
---@param packet table Incoming packet
---@param device Device
local function clipboard_handler(plugin, packet, device)
  if packet and packet.body and packet.body.content then
    originalSetClipboardText(packet.body.content)
    UIManager:show(Notification:new {
      text = _("copied"),
    })
  end
end

--- Create and return the ping plugin
---@return Plugin
return Plugin:new(
  plugin_id,
  "Clipboard",
  "both",
  clipboard_handler
)
