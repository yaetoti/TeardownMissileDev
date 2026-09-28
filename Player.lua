if not Player then
  Player = {}
  Player.__index = Player

  function Player.new()
    obj = {
      isControllingMissile = false,
      controlledMissileId = 0,
    }
    return setmetatable(obj, Player)
  end
end