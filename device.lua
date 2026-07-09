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
local Device = {}

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
  self.ip = ip
  self.deviceId = deviceId
  self.deviceName = deviceName
  self.deviceType = deviceType
  self.protocolVersion = protocolVersion
  self.tcpPort = tcpPort
  self.incomingCapabilities = incomingCapabilities
    self.outgoingCapabilities = outgoingCapabilities
  return self
end

return Device
