#version 2

if not Missile then
  Missile = {}
  Missile.__index = Missile

  Missile.WingsState = {
    FOLDED = 1,
    SPREAD = 2,
    FOLDING = 3,
    SPREADING = 4,
  }
  Missile.WING_SPREAD_TIME = 0.15
  Missile.WING_FOLD_TIME = 0.6

  function Missile:new()
    local obj = {
      -- Physical
      entities = {},

      -- Wing data
      leftWing = nil,
      rightWing = nil,
      leftWingTransform = nil,
      rightWingTransform = nil,
      leftWingScale = 1,
      rightWingScale = 1,

      -- State
      wingsRotation = 0,
      wingsTargetRotation = 0,
      wingsSpreadingProgress = 0,
      wingsState = Missile.WingsState.FOLDED
    }

    return setmetatable(obj, self)
  end

  function Missile:Spawn(transform)
    if transform == nil then
      transform = Transform()
    end

    self.entities = Spawn("MOD/vox/Missile.xml", transform)
    self.leftWing = self.entities[8]
    self.rightWing = self.entities[7]
    self.leftWingTransform = GetShapeLocalTransform(self.leftWing)
    self.rightWingTransform = GetShapeLocalTransform(self.rightWing)
    _, _, _, self.leftWingScale = GetShapeSize(self.leftWing)
    _, _, _, self.rightWingScale = GetShapeSize(self.rightWing)

    local verticalOffset = -2.5
    self.leftWingTransform.pos = VecAdd(self.leftWingTransform.pos, Vec(0, verticalOffset * self.leftWingScale, 0))
    self.rightWingTransform.pos = VecAdd(self.rightWingTransform.pos, Vec(0, verticalOffset * self.rightWingScale, 0))
    SetShapeLocalTransform(self.leftWing, self.leftWingTransform)
    SetShapeLocalTransform(self.rightWing, self.rightWingTransform)
  end

  setmetatable(Missile, {
    __newindex = function(t, k, v)
      error("Attempt to change the Missile class table! Property: " .. tostring(k), 2)
    end
  })
end