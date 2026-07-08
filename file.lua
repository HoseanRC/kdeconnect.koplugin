local File = {}

---
---opens and reads file content
---
---@param path string
---@return string | nil
---@nodiscard
function File.read(path)
  local f = io.open(path, "r")
  if not f then return end
  local content = f:read("*a")
  f:close()
  return content
end

---
---opens and writes file content
---returns success state
---
---@param path string
---@param content string
---@return boolean
function File.write(path, content)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(content)
  f:close()
  return true
end

---
---checks if file exists
---
---@param path string
---@return boolean
---@nodiscard
function File.exists(path)
  local f = io.open(path, "r")
  if not f then return false end
  f:close()
  return true
end

return File
