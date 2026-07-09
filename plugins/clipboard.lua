local Plugin = require("./plugins/__init__").Plugin
local PluginManager = require("./plugins/__init__").PluginManager
local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")
local Device = require("device")
local _ = require("gettext")

local plugin_id = "kdeconnect.clipboard"

local lastClipboardContent = nil

---@type string|nil
local lastview = nil

local checkCopy
checkCopy = function()
  local view = UIManager:getNthTopWidget(1)
  if (view and view.name or nil) ~= lastview then
    -- delay on view change
    lastview = (view and view.name or nil)
    UIManager:scheduleIn(5, checkCopy)
    return
  end
  local content = Device.input.getClipboardText()
  if content ~= lastClipboardContent and content ~= "" then
    if lastClipboardContent ~= nil then
      local devices = PluginManager:get_connected_devices()
      for _, device in pairs(devices) do
        device:send("", {
          content = content
        }, plugin_id)
      end
    end
    lastClipboardContent = content
  end
  UIManager:scheduleIn(1, checkCopy)
end
checkCopy()

---@param plugin Plugin Plugin instance
---@param packet table Incoming packet
---@param device Device
local function clipboard_handler(plugin, packet, device)
  if packet and packet.body and packet.body.content then
    Device.input.setClipboardText(packet.body.content)
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
