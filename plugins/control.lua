-- Control plugin for KDE Connect
-- A plugin to receive keyboard and mouse events

local Plugin = require("./plugins/__init__").Plugin
local UIManager = require("ui/uimanager")
local Event = require("ui/event")
local _ = require("gettext")

--- Control plugin handler
---@param plugin Plugin Plugin instance
---@param packet table Incoming packet
---@param device Device
local function control_handler(plugin, packet, device)
  ---@class mousepad_packet_body
  ---@field key string|nil
  ---@field specialKey number|nil
  ---@field alt boolean|nil
  ---@field ctrl boolean|nil
  ---@field shift boolean|nil
  ---@field super boolean|nil
  ---@field singleclick boolean|nil
  ---@field doubleclick boolean|nil
  ---@field middleclick boolean|nil
  ---@field rightclick boolean|nil
  ---@field singlehold boolean|nil
  ---@field singlerelease boolean|nil
  ---@field dx number|nil
  ---@field dy number|nil
  ---@field scroll boolean|nil
  ---@field isAck boolean|nil
  local body = packet.body
    if body.specialKey == 8 then
    -- previous page
    UIManager:sendEvent(Event:new("GotoViewRel", -1))
  end
    if body.specialKey == 9 then
    -- next page
    UIManager:sendEvent(Event:new("GotoViewRel", 1))
  end
end

--- Create and return the control plugin
---@return Plugin
return Plugin:new(
  "kdeconnect.mousepad",
  "control",
  control_handler,
  { "request" },
  {}
)
