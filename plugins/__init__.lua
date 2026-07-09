-- Plugin handler for KDE Connect plugins
-- This file provides the base plugin class and plugin management system

--- Base plugin class for all KDE Connect plugins
---@class Plugin
---@field id string Plugin identifier (e.g., "kdeconnect.mock.echo")
---@field name string Human-readable plugin name
---@field direction "incoming"|"outgoing"|"both" Plugin direction
---@field handler function Plugin handler function
local Plugin = {}
Plugin.__index = Plugin

--- Create a new plugin instance
---@param id string Plugin identifier
---@param name string Human-readable name
---@param direction "incoming"|"outgoing"|"both" Plugin direction
---@param handler function Plugin handler function
---@return Plugin
function Plugin:new(id, name, direction, handler)
    local self = setmetatable({}, Plugin)
    self.id = id
    self.name = name
    self.direction = direction
    self.handler = handler
    return self
end

--- Check if plugin can handle a packet
---@param packet table Packet to check
---@return boolean
function Plugin:can_handle(packet)
    return packet.type == self.id
end

--- Handle incoming packet
---@param packet table Packet to handle
---@param device Device
function Plugin:handle(packet, device)
    if self.handler then
        self.handler(self, packet, device)
    end
end

--- Base plugin manager
---@class PluginManager
---@field plugins table List of loaded plugins
local PluginManager = {}
PluginManager.__index = PluginManager

--- Create a new plugin manager
---@return PluginManager
function PluginManager:new()
    local self = setmetatable({}, PluginManager)
    self.plugins = {}
    return self
end

--- Register a plugin
---@param plugin Plugin Plugin to register
function PluginManager:register(plugin)
    table.insert(self.plugins, plugin)
end

--- Load plugins from directory
---@param plugin_dir string Directory containing plugin files
function PluginManager:load_from_directory(plugin_dir)
    local files = require("lfs").attributes(plugin_dir, "mode")

    if files == "directory" then
        for filename in require("lfs").dir(plugin_dir) do
            if filename:sub(-4) == ".lua" and filename ~= "__init__.lua" then
                local plugin_path = plugin_dir .. filename
                local ok, plugin = pcall(dofile, plugin_path)
                if ok and plugin and type(plugin) == "table" then
                    self:register(plugin)
                end
            end
        end
    end
end

--- Handle packet
---@param packet table Packet to handle
---@param device Device
function PluginManager:handle_packet(packet, device)
    ---@param plugin Plugin
    for _, plugin in ipairs(self.plugins) do
        if plugin:can_handle(packet) then
            plugin:handle(packet, device)
            return true
        end
    end
    return false
end

return {
    Plugin = Plugin,
    PluginManager = PluginManager,
}
