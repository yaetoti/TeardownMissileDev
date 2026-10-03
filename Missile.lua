#version 2
#include "Math.lua"
#include "SoundManager.lua"

-- Missile is facing in the -Z direction
-- LOG: Tried +Z, but it's easier to remember that forward is at negative direction, than that right is left. Camera is also looking at -Z, so with +Z I'd have to invert the body transform

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
  Missile.MASS = 800

  function Missile.new()
    local obj = {
      -- Physical
      entities = {},

      -- Wing data
      leftWing = nil,
      rightWing = nil,
      leftWingTransform = nil,
      rightWingTransform = nil,
      wingsOffsetZ = 0.0,

      -- State
      wingsRotation = Missile.WINGS_FOLDED_ROTATION,
      wingsTargetRotation = Missile.WINGS_FOLDED_ROTATION,
      wingsStateProgress = 1,
      wingsSpreading = 0,
      wingsState = Missile.WingsState.FOLDED,

      exploded = false,
      transform = Transform(),
      right = Math.RIGHT,
      up = Math.UP,
      forward = Math.FORWARD,

      -- TODO new
      velocity = Vec(),
      angularVelocity = Vec(),

      pitchInput = 0.0,
      yawInput = 0.0,
      rollInput = 0.0,
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
    self.right = QuatRotateVec(self.transform.rot, Math.RIGHT)
    self.up = QuatRotateVec(self.transform.rot, Math.UP)
    self.forward = QuatRotateVec(self.transform.rot, Math.FORWARD)

    self.entities = Spawn("MOD/vox/Missile.xml", self.transform)
    self.leftWing = self.entities[8]
    self.rightWing = self.entities[7]
    self.leftWingTransform = GetShapeLocalTransform(self.leftWing)
    self.rightWingTransform = GetShapeLocalTransform(self.rightWing)

    -- Default transform (offset wings down into the mounting slot)
    local leftWingSizeX, leftWingSizeY, leftWingSizeZ, leftWingScale = GetShapeSize(self.leftWing)
    local rightWingSizeX, rightWingSizeY, rightWingSizeZ, rightWingScale = GetShapeSize(self.rightWing)
    local verticalOffset = -2.5
    self.wingsOffsetZ = verticalOffset * leftWingScale

    self.leftWingTransform.pos = VecAdd(self.leftWingTransform.pos, Vec(0, verticalOffset * leftWingScale, 0))
    self.rightWingTransform.pos = VecAdd(self.rightWingTransform.pos, Vec(0, verticalOffset * rightWingScale, 0))
    SetShapeLocalTransform(self.leftWing, self.leftWingTransform)
    SetShapeLocalTransform(self.rightWing, self.rightWingTransform)

    -- Pivot (center + 3 from wing base)
    self.leftWingPivot = Vec(-0.5 * leftWingSizeX * leftWingScale, 0, -10 * leftWingScale)
    self.rightWingPivot = Vec(0.5 * rightWingSizeX * rightWingScale, 0, -10 * rightWingScale)
  end

  function Missile:update(deltaTime)
    if self.exploded then
      return
    end

    -- Update wings
    self:_updateWingsSpreading(deltaTime)
    local newLeftWingTransform = Math.RotateTransformAround(self.leftWingTransform, self.leftWingPivot, QuatEuler(0, -self.wingsRotation, 0))
    local newRightWingTransform = Math.RotateTransformAround(self.rightWingTransform, self.rightWingPivot, QuatEuler(0, self.wingsRotation, 0))
    SetShapeLocalTransform(self.leftWing, newLeftWingTransform)
    SetShapeLocalTransform(self.rightWing, newRightWingTransform)

    -- TODO update movement
    local newPosition = self.transform.pos

    -- Parameters
    local THRUST = 20000
    local AIR_DENSITY = 1.22 -- TODO min max

    local BODY_AREA = 8.08
    local BODY_DRAG_COEFFICIENT = 0.3

    local WINGS_AREA = 10.0
    local WINGS_DRAG_COEFFICIENT = 0.03
    local WINGS_INDUCED_DRAG = 0.08

    local LIFT_COEFFICIENT_ALPHA = 5.5
    local LIFT_COEFFICIENT_MAX = 1.5

    -- Rotational Parameters
    local INERTIA_X = 4000.0
    local INERTIA_Y = 4000.0
    local INERTIA_Z = 1000.0

    local PITCH_TORQUE = 80000.0
    local YAW_TORQUE = 80000.0
    local ROLL_TORQUE = 15000.0

    local PITCH_DAMPING = 10000.0
    local YAW_DAMPING = 10000.0
    local ROLL_DAMPING = 3000.0

    --local WINGS_CENTER_OF_PRESSURE = Vec(0, 0, self.wingsOffsetZ)
    local WINGS_CENTER_OF_PRESSURE = Vec(0, 0, 0)

    -- Input (TODO mapping?)
    local propulsion = 1.0 -- [0, 1]
    local wingsSpreading = self.wingsSpreading -- [0, 1]
    local pitchInput = self.pitchInput -- [-1, 1]
    local yawInput = self.yawInput -- [-1, 1]
    local rollInput = self.rollInput -- [-1, 1]

    -- Calculated (Linear)
    local velocityDir, velocity = Math.VecNormalizeSafe(self.velocity)
    local dynamicPressure = 0.5 * AIR_DENSITY * velocity * velocity

    local forwardVelocity = VecDot(self.velocity, self.forward)
    local upVelocity = VecDot(self.velocity, self.up)
    local angleOfAttack = math.atan2(-upVelocity, forwardVelocity) -- radians

    local liftCoefficient = Math.clamp(LIFT_COEFFICIENT_ALPHA * angleOfAttack, -LIFT_COEFFICIENT_MAX, LIFT_COEFFICIENT_MAX) -- TODO -pi; pi - min max
    local liftDir, liftLength = Math.VecNormalizeSafe(Math.VecOrthogonalize(self.up, velocityDir))

    -- Calculated (Rotational)


    -- Forces (Linear)
    local fGravity = VecScale(GetGravity(), Missile.MASS)
    local fThrust = VecScale(self.forward, THRUST * propulsion)
    local fDragBody = VecScale(velocityDir, -dynamicPressure * BODY_AREA * BODY_DRAG_COEFFICIENT)
    local fDragWings = VecScale(velocityDir, -dynamicPressure * wingsSpreading * WINGS_AREA * (WINGS_DRAG_COEFFICIENT + WINGS_INDUCED_DRAG * liftCoefficient * liftCoefficient))
    local fLift = VecScale(liftDir, dynamicPressure * WINGS_AREA * liftCoefficient * wingsSpreading)

    local forces = Math.VecAdd(fGravity, fThrust, fDragBody, fDragWings, fLift)

    -- Forces (Rotational)
    local angularMomentum = Vec(
        INERTIA_X * self.angularVelocity[1],
        INERTIA_Y * self.angularVelocity[2],
        INERTIA_Z * self.angularVelocity[3]
    )
    local gyroTorque = VecCross(self.angularVelocity, angularMomentum)
    local tauControl = Math.VecAdd(
        VecScale(self.right, PITCH_TORQUE * pitchInput),
        VecScale(self.up, YAW_TORQUE * yawInput),
        VecScale(self.forward, ROLL_TORQUE * rollInput)
    )

    local fLiftBody = Vec(
      VecDot(fLift, self.right),
      VecDot(fLift, self.up),
      VecDot(fLift, VecScale(self.forward, -1))
    )
    local tauLiftBody = VecCross(WINGS_CENTER_OF_PRESSURE, fLiftBody)
    local tauDampingBody = Vec(
        -self.angularVelocity[1] * PITCH_DAMPING,
        -self.angularVelocity[2] * YAW_DAMPING,
        -self.angularVelocity[3] * ROLL_DAMPING
    )

    --tauLiftBody = Vec()
    --gyroTorque = Vec()

    --local torque = Math.VecAdd(tauControl, tauLiftBody, tauDampingBody)
    --local angularAcceleration = Vec(
    --    ((torque[1] - gyroTorque[1]) / INERTIA_X),
    --    ((torque[2] - gyroTorque[2]) / INERTIA_Y),
    --    ((torque[3] - gyroTorque[3]) / INERTIA_Z)
    --)

    -- after you have built the world-space tauControl
    local tauControlBody = TransformToLocalVec(self.transform, tauControl)
    -- now everything is body-frame
    local torque = Math.VecAdd(tauControlBody, tauLiftBody, tauDampingBody)
    local angularAcceleration = Vec(
        (torque[1] - gyroTorque[1]) / INERTIA_X,
        (torque[2] - gyroTorque[2]) / INERTIA_Y,
        (torque[3] - gyroTorque[3]) / INERTIA_Z
    )

    -- Integrate (Rotational)
    self.angularVelocity = VecAdd(self.angularVelocity, VecScale(angularAcceleration, deltaTime))

    local angularAxis, angularSpeed = Math.VecNormalizeSafe(self.angularVelocity)
    if angularSpeed > Math.EPSILON then
      local angularDeltaDegrees = angularSpeed * deltaTime * 180.0 / math.pi
      local deltaRotation = QuatAxisAngle(angularAxis, angularDeltaDegrees)
      self.transform.rot = QuatRotateQuat(self.transform.rot, deltaRotation)
    end

    -- Integrate (Linear)
    local acceleration = VecScale(forces, 1 / Missile.MASS)
    self.velocity = VecAdd(self.velocity, VecScale(acceleration, deltaTime))
    newPosition = VecAdd(newPosition, VecScale(self.velocity, deltaTime))

    -- Update transform
    self.transform.pos = newPosition
    self.right = QuatRotateVec(self.transform.rot, Math.RIGHT)
    self.up = QuatRotateVec(self.transform.rot, Math.UP)
    self.forward = QuatRotateVec(self.transform.rot, Math.FORWARD)

    -- Apply transform
    SetBodyTransform(self.entities[1], self.transform)

    DebugTransform(self.transform, 3.0)
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
        self.wingsSpreading = Math.easeOutElastic(self.wingsStateProgress)
      end

      -- Update rotation
      self.wingsRotation = Math.lerp(Missile.WINGS_FOLDED_ROTATION, Missile.WINGS_SPREAD_ROTATION, self.wingsSpreading)
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
      self.wingsRotation = Math.lerp(Missile.WINGS_FOLDED_ROTATION, Missile.WINGS_SPREAD_ROTATION, self.wingsSpreading)
    end
  end

  setmetatable(Missile, {
    __newindex = function(t, k, v)
      error("Attempt to change the Missile class table! Property: " .. tostring(k), 2)
    end
  })
end