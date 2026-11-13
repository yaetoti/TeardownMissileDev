#include "Math.lua"
#include "Physics.lua"

MissileModel = {}
MissileModel.__index = MissileModel

function MissileModel.new()
  obj = {
    __type = "MissileModel",
  }

  return setmetatable(obj, MissileModel)
end
