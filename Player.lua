Player = {}
Player.__index = Player

function Player.new()
  obj = {
    __type = "Player",

    isControllingMissile = false,
    isDetached = false,
    controlledMissileId = 0,
  }
  return setmetatable(obj, Player)
end