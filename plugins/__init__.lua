-- Plugin handler for KDE Connect plugins
-- This file provides the base plugin class and plugin management system

local lfs = require("libs/libkoreader-lfs")

--- Base plugin class for all KDE Connect plugins
---@class Plugin
---@field id string Plugin identifier (e.g., "kdeconnect.mock.echo")
---@field name string Human-readable plugin name
---@field handler function Plugin handler function
---@field incoming_capabilities string[]
---@field outgoing_capabilities string[]
---@field menus table Menu items for main menu
local Plugin = {}
Plugin.__index = Plugin

--- Create a new plugin instance
---@param id string Plugin identifier
---@param name string Human-readable name
---@param handler function Plugin handler function
---@param incoming_capabilities string[]
---@param outgoing_capabilities string[]
---@param menus table|nil Menu items for main menu
---@return Plugin
function Plugin:new(id, name, handler, incoming_capabilities, outgoing_capabilities, menus)
    local self = setmetatable({}, Plugin)
    self.id = id
    self.name = name
    self.handler = handler
    self.incoming_capabilities = incoming_capabilities
    self.outgoing_capabilities = outgoing_capabilities
    self.menus = menus or {}
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
---@field devices Device[] Map of device_id -> Device
local PluginManager = {}
PluginManager.__index = PluginManager

--- Create a new plugin manager
---@return PluginManager
function PluginManager:new()
    -- local self = setmetatable({}, PluginManager)
    self.plugins = {}
    self.devices = {}
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
    local files = lfs.attributes(plugin_dir, "mode")

    if files == "directory" then
        for filename in lfs.dir(plugin_dir) do
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

--- Register a device with the plugin manager
---@param device Device Device to register
function PluginManager:register_device(device)
    self.devices[device.deviceId] = device
end

--- Unregister a device from the plugin manager
---@param device_id string Device ID to unregister
function PluginManager:unregister_device(device_id)
    self.devices[device_id] = nil
end

--- Get a device by ID
---@param device_id string Device ID
---@return Device or nil
function PluginManager:get_device(device_id)
    return self.devices[device_id]
end

--- Get connected devices
---@return Device[]
function PluginManager:get_connected_devices()
    ---@type Device[]
    local connectedDevices = {}
    for _, device in pairs(self.devices) do
        if device.connection then
            table.insert(connectedDevices, device)
        end
    end
    return connectedDevices
end

--- Handle packet
---@param packet table Packet to handle
---@param device Device
---@param connection table Connection object (for plugin responses)
function PluginManager:handle_packet(packet, device, connection)
    ---@param plugin Plugin
    for _, plugin in ipairs(self.plugins) do
        if plugin:can_handle(packet) then
            -- Set plugin_id on device for namespace resolution in device:send()
            device.plugin_id = plugin.id
            plugin:handle(packet, device)
            -- Clear plugin_id after handling
            device.plugin_id = nil
            return true
        end
    end
    return false
end

return {
    Plugin = Plugin,
    PluginManager = PluginManager,
}
