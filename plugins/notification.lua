local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")

local Plugin = require("./plugins/__init__").Plugin

--- Notification plugin handler
---@param plugin Plugin Plugin instance
---@param packet table Incoming packet
---@param device Device Device that sent the packet
local function notification_handler(plugin, packet, device)
  local body = packet.body or {}
  local title = body.title or ""
  local message = body.text or ""
  local silent = body.silent or false
  local isCancel = body.isCancel or false

  if silent or isCancel then
    return
  end

  -- Display notification on screen
  local display_text = ""
  if title ~= "" then
    display_text = title .. "\n"
  end
  display_text = display_text .. message

  UIManager:show(Notification:new {
    text = display_text,
    timeout = 5,
  })
end

--- Create and return the notification plugin
---@return Plugin
return Plugin:new(
  "kdeconnect.notification",
  "Notification",
  notification_handler,
  {
    "",
    -- "request",
    -- "reply",
    -- "action",
  },
  {
    "",
    -- "request",
    -- "reply",
    -- "action",
  }
)
