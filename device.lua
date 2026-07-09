--- a discovered device
--- @class Device
--- @field ip string device IP
--- @field deviceId string device identifier
--- @field deviceName string device name
--- @field deviceType string device type
--- @field protocolVersion number version of protocol used by device
--- @field tcpPort number tcp port to connect to on the device
--- @field incomingCapabilities string[]
--- @field outgoingCapabilities string[]
--- @field connection table TLS connection object (for sending responses, persistent)
--- @field plugin_id string Plugin ID that should handle send() calls (for namespace resolution)
local Device = {}
Device.__index = Device

--- @param ip string device IP
--- @param deviceId string device identifier
--- @param deviceName string device name
--- @param deviceType string device type
--- @param protocolVersion number version of protocol used by device
--- @param tcpPort number tcp port to connect to on the device
--- @param incomingCapabilities string[]
--- @param outgoingCapabilities string[]
--- @return Device
function Device:new(ip, deviceId, deviceName, deviceType, protocolVersion, tcpPort, incomingCapabilities,
                    outgoingCapabilities)
  local self = setmetatable({}, Device)
  self.ip = ip
  self.deviceId = deviceId
  self.deviceName = deviceName
  self.deviceType = deviceType
  self.protocolVersion = protocolVersion
  self.tcpPort = tcpPort
  self.incomingCapabilities = incomingCapabilities
  self.outgoingCapabilities = outgoingCapabilities
  self.connection = nil
  self.plugin_id = nil
  return self
end

--- Send a packet response back to the device
--- @param type string Packet type suffix (e.g., "response", "notification.request")
--- @param body table Packet body
--- @param plugin_id string Plugin ID for namespace resolution (optional, uses device.plugin_id if not provided)
--- @return boolean success
--- @return string error message on failure
function Device:send(type, body, plugin_id)
  if not self.connection or not self.connection.tls then
    return false, "No connection available"
  end

  -- Use provided plugin_id or fall back to device.plugin_id
  local ns_plugin_id = plugin_id or self.plugin_id
  if not ns_plugin_id then
    return false, "No plugin ID available for namespace resolution"
  end

  -- Resolve the full packet type
  local full_type = self:_resolve_packet_type(type, ns_plugin_id)

  -- Construct the packet
  local packet = {
    id = 0,
    type = full_type,
    body = body or {}
  }

  -- Encode the packet using stored encode function
  local encoded
  if self.connection.encode_func then
    encoded = self.connection.encode_func(packet)
  else
    -- Fallback to direct JSON encoding if encode function not available
    local json = require("json")
    encoded = json.encode(packet)
  end

  if not encoded then
    return false, "Failed to encode packet"
  end

  -- Send via TLS
  local ok, err = self.connection.tls:send(encoded .. "\n")
  if not ok then
    return false, "Send failed: " .. (err or "unknown error")
  end

  return true, ""
end

--- Resolve packet type to full namespaced type
--- @param type_suffix string Type suffix (e.g., "response", "notification.request", or nil)
--- @param plugin_id string Plugin ID for the namespace
--- @return string Full packet type (e.g., "kdeconnect.notification.response")
function Device:_resolve_packet_type(type_suffix, plugin_id)
  if not type_suffix or type_suffix == "" then
    -- No suffix provided, use plugin ID as type
    return plugin_id
  end

  -- If type_suffix already contains dots (e.g., "notification.request"),
  -- append it to the plugin namespace
  if string.find(type_suffix, "%.")
  then
    return plugin_id .. "." .. type_suffix
  end

  -- Simple suffix without dots (e.g., "response")
  return plugin_id .. "." .. type_suffix
end

return Device
