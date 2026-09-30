#version 2
#include "Math.lua"
#include "SoundManager.lua"

-- Missile is facing in the -Z direction

if not Missile then
  Missile = {}
  Missile.__index = Missile

  Missile.WingsState = {
    FOLDED = 1,
    SPREAD = 2,
    FOLDING = 3,
    SPREADING = 4,
  }
  Missile.WINGS_SPREADING_TIME = 0.25
  Missile.WINGS_FOLDING_TIME = 0.6
  Missile.WINGS_FOLDED_ROTATION = 0
  Missile.WINGS_SPREAD_ROTATION = 40

  Missile.EXPLOSION_STRENGTH = 4.0
  Missile.NOSE_OFFSET = Vec(0, 0, -2.5)
  Missile.CAMERA_OFFSET = Vec(0, 1, 6.0)
  Missile.MASS = 1

  function Missile.new()
    local obj = {
      -- Physical
      entities = {},

      -- Wing data
      leftWing = nil,
      rightWing = nil,
      leftWingTransform = nil,
      rightWingTransform = nil,

      -- State
      wingsRotation = Missile.WINGS_FOLDED_ROTATION,
      wingsTargetRotation = Missile.WINGS_FOLDED_ROTATION,
      wingsStateProgress = 1,
      wingsSpreading = 0,
      wingsState = Missile.WingsState.FOLDED,

      exploded = false,
      transform = Transform(),
      forward = Vec(0, 0, -1),
      up = Vec(0, 1, 0),

      -- TODO new
      velocity = Vec(),
    }

    return setmetatable(obj, Missile)
  end

  function Missile:spawn(transform)
    -- Not reusable
    if self.exploded then
      return
    end

    if transform == nil then
      transform = Transform()
    end

    self.transform = transform
    self.forward = QuatRotateVec(self.transform.rot, Vec(0, 0, -1))
    self.up = QuatRotateVec(self.transform.rot, Vec(0, 1, 0))

    self.entities = Spawn("MOD/vox/Missile.xml", self.transform)
    self.leftWing = self.entities[8]
    self.rightWing = self.entities[7]
    self.leftWingTransform = GetShapeLocalTransform(self.leftWing)
    self.rightWingTransform = GetShapeLocalTransform(self.rightWing)

    -- Default transform (offset wings down into the mounting slot)
    local leftWingSizeX, leftWingSizeY, leftWingSizeZ, leftWingScale = GetShapeSize(self.leftWing)
    local rightWingSizeX, rightWingSizeY, rightWingSizeZ, rightWingScale = GetShapeSize(self.rightWing)
    local verticalOffset = -2.5

    self.leftWingTransform.pos = VecAdd(self.leftWingTransform.pos, Vec(0, verticalOffset * leftWingScale, 0))
    self.rightWingTransform.pos = VecAdd(self.rightWingTransform.pos, Vec(0, verticalOffset * rightWingScale, 0))
    SetShapeLocalTransform(self.leftWing, self.leftWingTransform)
    SetShapeLocalTransform(self.rightWing, self.rightWingTransform)

    -- Pivot (center + 3 from wing base)
    self.leftWingPivot = Vec(0.5 * leftWingSizeX * leftWingScale, 0, -3 * leftWingScale)
    self.rightWingPivot = Vec(-0.5 * rightWingSizeX * rightWingScale, 0, -3 * rightWingScale)
  end

  function Missile:update(deltaTime)
    if self.exploded then
      return
    end

    -- Update wings
    self:_updateWingsSpreading(deltaTime)
    local newLeftWingTransform = Math:RotateAround(self.leftWingTransform, self.leftWingPivot, QuatEuler(0, -self.wingsRotation, 0))
    local newRightWingTransform = Math:RotateAround(self.rightWingTransform, self.rightWingPivot, QuatEuler(0, self.wingsRotation, 0))
    SetShapeLocalTransform(self.leftWing, newLeftWingTransform)
    SetShapeLocalTransform(self.rightWing, newRightWingTransform)

    -- TODO update movement
    -- Parameters
    local THRUST = 800
    local AIR_DENSITY = 1.22 -- TODO min max

    -- State
    local propulsion = 1.0 -- [0, 1]
    local wingsSpreading = 1.0 -- [0, 1]

    -- Calculated
    local velocityVec = VecNormalize(self.velocity)
    local minusVelocityVec = VecScale(velocityVec, -1)
    local velocity = VecLength(self.velocity)
    local dynamicPressure = 0.5 * AIR_DENSITY * velocity * velocity

    -- Forces
    local newPosition = self.transform.pos

    local fGravity = VecScale(GetGravity(), Missile.MASS)
    local fThrust = VecScale(self.forward, THRUST * propulsion)
    local fDragBody = VecScale(minusVelocityVec, dynamicPressure) -- TODO multiply by: cross-sectional area * drag coefficient for body shape
    local fDragWings = VecScale(minusVelocityVec, dynamicPressure * wingsSpreading) -- TODO multiply by: cross-sectional area * drag coefficient for wings shape
    local fLift = VecScale(self.up, dynamicPressure * wingsSpreading) -- TODO multiply by: cross-sectional area * lift coefficient, ANGLE OF ATTACK

    local forces = Math.VecAdd(fGravity, fThrust, fDragBody, fDragWings)
    DebugPrint(forces)

    -- Integrate
    local acceleration = VecScale(forces, 1 / Missile.MASS)
    self.velocity = VecAdd(self.velocity, VecScale(acceleration, deltaTime))
    newPosition = VecAdd(newPosition, VecScale(self.velocity, deltaTime))

    -- Update transform
    self.transform.pos = newPosition
    self.forward = QuatRotateVec(self.transform.rot, Vec(0, 0, -1))
    self.up = QuatRotateVec(self.transform.rot, Vec(0, 1, 0))

    -- Apply transform
    SetBodyTransform(self.entities[1], self.transform)
  end

  function Missile:spreadWings()
    if (self.wingsState == Missile.WingsState.SPREAD) then
      return
    end

    self.wingsStateProgress = 1 - self.wingsStateProgress
    self.wingsState = Missile.WingsState.SPREADING

    server.PlaySoundClientRpc(0, "wings", self.transform.pos)
  end

  function Missile:foldWings()
    if (self.wingsState == Missile.WingsState.FOLDED) then
      return
    end

    self.wingsStateProgress = 1 - self.wingsStateProgress
    self.wingsState = Missile.WingsState.FOLDING
  end

  function Missile:explode()
    if self.exploded then
      return
    end

    local explodePoint = TransformToParentPoint(self.transform, Missile.NOSE_OFFSET)



    -- TODO can be smoke or plain
    --ParticleReset()
    --ParticleType("smoke")
    --ParticleColor(0.7, 0.6, 0.5)
    --SpawnParticle(explodePoint, Vec(1, 1, 1), 10.0)
    --
    --ParticleReset()
    --ParticleType("smoke")
    --ParticleColor(0.7, 0.6, 0.5)
    --SpawnParticle(explodePoint, Vec(1, 1, 1), 10.0)

    SpawnFire(explodePoint)
    Explosion(explodePoint, Missile.EXPLOSION_STRENGTH)
    --Explosion(explodePoint, Missile.EXPLOSION_STRENGTH)

    server.PlaySoundClientRpc(0, "explosion", explodePoint, 1.0)

    -- Delete body
    Delete(self.entities[1])

    self.exploded = true
  end

  function Missile:_updateWingsSpreading(deltaTime)
    -- Update wings spreading
    if self.wingsState == Missile.WingsState.SPREADING then
      -- Spreading
      self.wingsStateProgress = self.wingsStateProgress + deltaTime / Missile.WINGS_SPREADING_TIME

      -- Finish spreading
      if self.wingsStateProgress >= 1 then
        self.wingsStateProgress = 1
        self.wingsSpreading = 1
        self.wingsState = Missile.WingsState.SPREAD
      else
        -- Apply easing here
        self.wingsSpreading = Math:easeOutElastic(self.wingsStateProgress)
      end

      -- Update rotation
      self.wingsRotation = Math:lerp(Missile.WINGS_FOLDED_ROTATION, Missile.WINGS_SPREAD_ROTATION, self.wingsSpreading)
    elseif self.wingsState == Missile.WingsState.FOLDING then
      -- Folding
      self.wingsStateProgress = self.wingsStateProgress + deltaTime / Missile.WINGS_FOLDING_TIME

      -- Finish folding
      if self.wingsStateProgress >= 1 then
        self.wingsStateProgress = 1
        self.wingsSpreading = 0
        self.wingsState = Missile.WingsState.FOLDED
      else
        -- Apply easing here
        self.wingsSpreading = 1 - self.wingsStateProgress
      end

      -- Update rotation
      self.wingsRotation = Math:lerp(Missile.WINGS_FOLDED_ROTATION, Missile.WINGS_SPREAD_ROTATION, self.wingsSpreading)
    end
  end

  setmetatable(Missile, {
    __newindex = function(t, k, v)
      error("Attempt to change the Missile class table! Property: " .. tostring(k), 2)
    end
  })
end