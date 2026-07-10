local Table = {}

---
---checks if table contains specific value
---
---@generic T: table, K, V
---@param table T
---@param value V
---@return boolean
---@nodiscard
function Table.contains(table, value)
  for i = 1, #table do
    if table[i] == value then
      return true
    end
  end
  return false
end

---
---returns length of table
---
---@generic T: table, K, V
---@param table T
---@return integer
---@nodiscard
function Table.length(table)
  local count = 0
  for _ in pairs(table) do count = count + 1 end
  return count
end

return Table
