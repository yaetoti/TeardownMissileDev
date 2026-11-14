ClientMissile = {}
ClientMissile.__index = ClientMissile

function ClientMissile.new()
  local obj = {}
  return setmetatable(obj, ClientMissile)
end
