#version 2
#include "Math.lua"
#include "SoundManager.lua"
#include "Debug.lua"

-- Missile is facing in the -Z direction
-- LOG: Tried +Z, but it's easier to remember that forward is at negative direction, than that right is left. Camera is also looking at -Z, so with +Z I'd have to invert the body transform

if not Missile then
  ---@class Missile
  ---@field velocity Vec3

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
      -- Entities
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

      -- Physics
      transform = Transform(),
      right = Math.RIGHT,
      up = Math.UP,
      forward = Math.FORWARD,

      velocity = Vec3.new(),
      angularVelocity = Vec3.new(),

      -- Input
      pitchInput = 0.0,
      yawInput = 0.0,
      rollInput = 0.0,
      propulsion = 0.0
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
    self.right = Math.RIGHT:rotate(self.transform.rot)
    self.up = Math.UP:rotate(self.transform.rot)
    self.forward = Math.FORWARD:rotate(self.transform.rot)

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

    -- Parameters
    local THRUST = 20000
    local AIR_DENSITY = 1.22 -- TODO min max

    local AREA_WINGS_TOP = 8.0
    local CL_ALPHA_WINGS = 5.5
    local AREA_BODY = 10.0
    local CL_ALPHA_BODY = 0.3



    local AREA_WINGS_FRONT = 0.8


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
    --local WINGS_CENTER_OF_PRESSURE = Vec(0, 0, 0)

    -- Input (TODO mapping? TODO enforce clamp TODO replace with self.var)
    local propulsion = self.propulsion -- [0, 1]
    local wingsSpreading = self.wingsSpreading -- [0, 1]
    local pitchInput = self.pitchInput -- [-1, 1]
    local yawInput = self.yawInput -- [-1, 1]
    local rollInput = self.rollInput -- [-1, 1]

    -- Calculated (Linear)
    local velocityDir, velocity = self.velocity:normalize()
    local localVelocityVec = self.velocity:toBasis(self.right, self.up, self.forward)
    local localVelocityDir = localVelocityVec:normalize()

    -- TODO move
    function _lPointVelocity(point)
      return localVelocityVec + VecCross(self.angularVelocity, point)
    end

    -- TODO relative velocity: wind

    -- Forces (Linear)


    ---@param angle number Angle of attack (radians, [-90, 90]). Positive above wind, negative below wind.
    local function _calculateCL(angle)
      local sign = Math.sign(angle)
      local angleAbs = math.abs(angle)
      if angleAbs < 0.35 then
        -- so peak
        return sign * math.sin(6 * angleAbs) -- peak at 15
      else
        -- stall
        local c = math.cos(angleAbs)
        return 0.9 * sign * c * c
      end
    end


    ---Calculate lift for surface
    ---@param velocityVec Vec3 Velocity (should be in the same space as the axes)
    ---@param airDensity number
    ---@param area number Wing area
    ---@param clAlpha number Lift coefficient for wing shape and profile
    ---@param spanAxis Vec3 Axis, along which velocity is ignored (hinge axis, skeleton axis, side axis, not forward, STFU, whatever) (normalized)
    ---@param normalAxis Vec3 Axis, perpendicular to the wing surface (normalized)
    local function _calculateLift(velocityVec, airDensity, area, clAlpha, spanAxis, normalAxis)
      local localVelocityVec = velocityVec:orthogonalize(spanAxis) -- remove span component
      local localVelocityDir, localVelocity = localVelocityVec:normalize()

      if localVelocity < Math.EPSILON then
        return Vec3.new()
      end

      local aoa = -localVelocityDir:anglePlane(normalAxis) -- TODO check angle
      local cl = 0.5 * clAlpha * _calculateCL(aoa)

      local liftDir = normalAxis:orthogonalize(-localVelocityDir):normalize()
      local q = 0.5 * airDensity * localVelocity * localVelocity

      return (q * area * cl) * liftDir
    end

    ---Calculate lift for axis
    ---@param velocityVec Vec3 Velocity (should be in the same space as the axes)
    ---@param airDensity number
    ---@param area number Surface area
    ---@param clAlpha number Lift coefficient for wing shape and profile
    ---@param axis Vec3 Axis (normalized)
    local function _calculateLiftAxis(velocityVec, airDensity, area, clAlpha, axis)
      local localVelocityVec = velocityVec:project(axis)
      local localVelocityDir, localVelocity = localVelocityVec:normalize()

      if localVelocity < Math.EPSILON then
        return Vec3.new()
      end

      local aoa = velocityVec:angle(axis)
      -- wind from behind - aoa negative
      if aoa > Math.HALF_PI then
        aoa = aoa - math.pi
      end

      local cl = 0.5 * clAlpha * _calculateCL(aoa)

      DebugPrint("Angle of attack for axis: "..math.deg(aoa))

      local liftDir = -velocityVec:orthogonalize(axis):normalize()
      local q = 0.5 * airDensity * localVelocity * localVelocity

      return (q * area * cl) * liftDir
    end


    -- Gravity
    local fGravity = Vec3.from(GetGravity()) * Missile.MASS

    -- Thrust
    local fThrust = THRUST * propulsion * self.forward

    -- Lift

    --Lift for:
    -- +rocket Z axis (TODO write axis lift function. or extract projection)
    -- wings XZ plane ((+)front + side?)
    -- 4 stabilizers: (front only? + TODO add torque calculation)

    local fLiftWings = _calculateLift(localVelocityVec, AIR_DENSITY, AREA_WINGS_TOP, CL_ALPHA_WINGS, Math.OBJ_RIGHT, Math.OBJ_UP) * wingsSpreading
    local fLiftBody = _calculateLiftAxis(localVelocityVec, AIR_DENSITY, AREA_BODY, CL_ALPHA_BODY, Math.OBJ_FORWARD)

    --Debug.Vec(fLiftWings, self.transform.pos)
    Debug.Vec(fLiftBody, self.transform.pos)
    DebugWatch("Local velocity", localVelocityDir)
    DebugWatch("fLiftWings", fLiftWings)

    -- TODO Other forces
    --local fDragBody = VecScale(velocityDir, -dynamicPressure * BODY_AREA * BODY_DRAG_COEFFICIENT)
    --local fDragWings = VecScale(velocityDir, -dynamicPressure * wingsSpreading * WINGS_AREA * (WINGS_DRAG_COEFFICIENT + WINGS_INDUCED_DRAG * liftCoefficient * liftCoefficient))

    local localForces = fLiftWings + fLiftBody
    local worldForces = fGravity + fThrust
    local forces = worldForces + localForces:fromBasis(self.right, self.up, self.forward)

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

    local tauDampingBody = Vec(
        -self.angularVelocity[1] * PITCH_DAMPING,
        -self.angularVelocity[2] * YAW_DAMPING,
        -self.angularVelocity[3] * ROLL_DAMPING
    )

    local tauControlBody = TransformToLocalVec(self.transform, tauControl)
    local torque = Math.VecAdd(tauControlBody, tauDampingBody)
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
    local acceleration = forces / Missile.MASS
    self.velocity = self.velocity + acceleration * deltaTime
    self.transform.pos = VecAdd(self.transform.pos, self.velocity * deltaTime)

    -- Update body basis
    self.right = Math.RIGHT:rotate(self.transform.rot)
    self.up = Math.UP:rotate(self.transform.rot)
    self.forward = Math.FORWARD:rotate(self.transform.rot)

    -- Apply transform
    SetBodyTransform(self.entities[1], self.transform)



    -- TODO DEBUG
    DebugTransform(self.velocity, 1.0)
    Debug.Vec(self.velocity, self.transform.pos)
    DebugWatch("Propulsion", self.propulsion)
    DebugWatch("Position", self.transform.pos)
    DebugWatch("Linear velocity", self.velocity)
    DebugWatch("Local Linear velocity", localVelocityVec)
    DebugWatch("Velocity", velocity)
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