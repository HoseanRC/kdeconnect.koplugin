-- Ping plugin for KDE Connect
-- This plugin handles ping requests from connected devices

local Plugin = require("./plugins/__init__").Plugin
local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")
local _ = require("gettext")

--- Ping plugin handler
---@param plugin Plugin Plugin instance
---@param packet table Incoming packet
---@param device Device
local function ping_handler(plugin, packet, device)
  -- Display ping message on screen
  local display_text = "Ping from " .. (device and (device.deviceName or "UNKNOWN") or "UNKNOWN")
  UIManager:show(Notification:new {
    text = _(display_text),
  })
end

--- Create and return the ping plugin
---@return Plugin
return Plugin:new(
  "kdeconnect.ping",
  "Ping",
  ping_handler,
  { "" },
  { "" }
)
