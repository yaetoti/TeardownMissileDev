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

      -- State
      scale = 1.0,

      -- Wing data
      leftWing = nil,
      rightWing = nil,
      leftWingTransform = nil,
      rightWingTransform = nil,
      wingsOffsetY = 0.0,

      -- Stabilizers data
      stabilizersOffsetX = 0.0,
      stabilizersOffsetY = 0.0,
      stabilizersOffsetZ = 0.0,
      wingTL = nil,
      wingTR = nil,
      wingBL = nil,
      wingBR = nil,
      wingTransformTL = nil,
      wingTransformTR = nil,
      wingTransformBL = nil,
      wingTransformBR = nil,

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

    -- Update transform and basis
    if transform == nil then
      transform = Transform()
    end

    self.transform = transform
    self.right = Math.RIGHT:rotate(self.transform.rot)
    self.up = Math.UP:rotate(self.transform.rot)
    self.forward = Math.FORWARD:rotate(self.transform.rot)

    -- Spawn entities
    self.entities = Spawn("MOD/vox/Missile.xml", self.transform)

    self.leftWing = self.entities[8]
    self.rightWing = self.entities[7]

    self.wingTL = self.entities[3]
    self.wingTR = self.entities[4]
    self.wingBL = self.entities[5]
    self.wingBR = self.entities[6]

    -- Get default shape transforms
    self.leftWingTransform = GetShapeLocalTransform(self.leftWing)
    self.rightWingTransform = GetShapeLocalTransform(self.rightWing)

    self.wingTransformTL = GetShapeLocalTransform(self.wingTL)
    self.wingTransformTR = GetShapeLocalTransform(self.wingTR)
    self.wingTransformBL = GetShapeLocalTransform(self.wingBL)
    self.wingTransformBR = GetShapeLocalTransform(self.wingBR)

    -- But pivot points in local wing space... AAAAAAA

    -- Calculate wings offset
    local leftWingSizeX, leftWingSizeY, leftWingSizeZ, leftWingScale = GetShapeSize(self.leftWing)
    local rightWingSizeX, rightWingSizeY, rightWingSizeZ, rightWingScale = GetShapeSize(self.rightWing)
    self.scale = leftWingScale
    self.wingsOffsetY = -2.5 * self.scale

    -- Move wings to their place
    self.leftWingTransform.pos = VecAdd(self.leftWingTransform.pos, Vec(0, self.wingsOffsetY, 0))
    self.rightWingTransform.pos = VecAdd(self.rightWingTransform.pos, Vec(0, self.wingsOffsetY, 0))
    SetShapeLocalTransform(self.leftWing, self.leftWingTransform)
    SetShapeLocalTransform(self.rightWing, self.rightWingTransform)

    -- Calculate wings pivot (+3 voxels from wing base)
    self.leftWingPivot = Vec(-0.5 * leftWingSizeX * self.scale, 0, -10 * self.scale)
    self.rightWingPivot = Vec(0.5 * rightWingSizeX * self.scale, 0, -10 * self.scale)


    -- Calculate stabilizers offset
    self.stabilizersOffsetX = 9 * self.scale
    self.stabilizersOffsetY = 6 * self.scale
    self.stabilizersOffsetZ = -41.5 * self.scale

    -- Calculate stabilizers axes (in missile space)
    self.wingPivotPosTL = Vec3.new(-self.stabilizersOffsetX, self.stabilizersOffsetY, self.stabilizersOffsetZ)
    self.wingPivotPosTR = Vec3.new(self.stabilizersOffsetX, self.stabilizersOffsetY, self.stabilizersOffsetZ)
    self.wingPivotPosBL = Vec3.new(-self.stabilizersOffsetX, -self.stabilizersOffsetY, self.stabilizersOffsetZ)
    self.wingPivotPosBR = Vec3.new(self.stabilizersOffsetX, -self.stabilizersOffsetY, self.stabilizersOffsetZ)

    self.wingPivotDirTL = Math.OBJ_UP:rotateAround(Math.OBJ_FORWARD, math.rad(45))
    self.wingPivotDirTR = Math.OBJ_UP:rotateAround(Math.OBJ_FORWARD, -math.rad(45))
    self.wingPivotDirBL = Math.OBJ_UP:rotateAround(Math.OBJ_FORWARD, math.rad(135))
    self.wingPivotDirBR = Math.OBJ_UP:rotateAround(Math.OBJ_FORWARD, -math.rad(135))

    self.wingAngleTL = 0.0
    self.wingAngleTR = 0.0
    self.wingAngleBL = 0.0
    self.wingAngleBR = 0.0
  end

  function Missile:update(deltaTime)
    if self.exploded then
      return
    end

    -- Update wings
    self:_updateWingsSpreading(deltaTime)
    local newLeftWingTransform = Math.RotateTransformAroundPivot(self.leftWingTransform, self.leftWingPivot, QuatEuler(0, -self.wingsRotation, 0))
    local newRightWingTransform = Math.RotateTransformAroundPivot(self.rightWingTransform, self.rightWingPivot, QuatEuler(0, self.wingsRotation, 0))
    SetShapeLocalTransform(self.leftWing, newLeftWingTransform)
    SetShapeLocalTransform(self.rightWing, newRightWingTransform)



    -- Control stabilizers
    --angle = angle + 30 * deltaTime
    local pitch = 0.0
    local yaw = 0.0
    local roll = 0.0

    if InputDown("up") then
      pitch = pitch + 1
    end
    if InputDown("down") then
      pitch = pitch - 1
    end
    if InputDown("right") then
      yaw = yaw + 1
    end
    if InputDown("left") then
      yaw = yaw - 1
    end
    if InputDown("e") then
      roll = roll + 1
    end
    if InputDown("q") then
      roll = roll - 1
    end

    DebugWatch("pitch", pitch)
    DebugWatch("yaw", yaw)
    DebugWatch("roll", roll)

    local maxAngle = 25

    pitch = -pitch
    --yaw = -yaw
    --roll = -roll

    local s = 0.7
    self.wingAngleTL = (roll + s * (pitch + yaw)) * maxAngle
    self.wingAngleTR = (roll + s * (-pitch + yaw)) * maxAngle
    self.wingAngleBL = (roll + s * (pitch - yaw)) * maxAngle
    self.wingAngleBR = (roll + s * (-pitch - yaw)) * maxAngle

    -- Set stabilizers visual rotation
    -- -Z forward in transforms - invert Z
    local wingsData = {
      { self.wingTL, self.wingTransformTL, self.wingPivotDirTL, self.wingPivotPosTL:invertZ(), self.wingAngleTL },
      { self.wingTR, self.wingTransformTR, self.wingPivotDirTR, self.wingPivotPosTR:invertZ(), self.wingAngleTR },
      { self.wingBL, self.wingTransformBL, self.wingPivotDirBL, self.wingPivotPosBL:invertZ(), self.wingAngleBL },
      { self.wingBR, self.wingTransformBR, self.wingPivotDirBR, self.wingPivotPosBR:invertZ(), self.wingAngleBR },
    }

    for _, wingData in ipairs(wingsData) do
      SetShapeLocalTransform(
        wingData[1],
        Math.RotateTransformAroundAxis(
          wingData[2],
          wingData[3],
          wingData[4],
          wingData[5]
        )
      )
    end

    -- Update movement
    if not debugMissile then
      self:_updateMovement(deltaTime)
    end



    ---- Draw debug axes
    ---- TL
    --Debug.Vec(
    --  self.wingPivotDirTL:fromBasis(self.right, self.up, self.forward),
    --  Vec3.from(self.transform.pos) + self.wingPivotPosTL:fromBasis(self.right, self.up, self.forward)
    --)
    --
    ---- TR
    --Debug.Vec(
    --  self.wingPivotDirTR:fromBasis(self.right, self.up, self.forward),
    --  Vec3.from(self.transform.pos) + self.wingPivotPosTR:fromBasis(self.right, self.up, self.forward)
    --)
    --
    ---- BL
    --Debug.Vec(
    --  self.wingPivotDirBL:fromBasis(self.right, self.up, self.forward),
    --  Vec3.from(self.transform.pos) + self.wingPivotPosBL:fromBasis(self.right, self.up, self.forward)
    --)
    --
    ---- BR
    --Debug.Vec(
    --  self.wingPivotDirBR:fromBasis(self.right, self.up, self.forward),
    --  Vec3.from(self.transform.pos) + self.wingPivotPosBR:fromBasis(self.right, self.up, self.forward)
    --)
  end

  angle = 0
  angleOffset = 0

  function Missile:_updateMovement(deltaTime)
    -- TODO update movement

    -- Parameters
    local THRUST = 8000
    local AIR_DENSITY = 1.22 -- TODO min max

    local AREA_WINGS_TOP = 8.0
    local AREA_WINGS_FRONT = 0.9
    local CL_ALPHA_WINGS = 5.5

    local AREA_STABILIZER = 0.5
    local CL_ALPHA_STABILIZER = 0.5

    local AREA_BODY_SIDE = 10.0
    local AREA_BODY_FRONT = 1.5
    local CL_ALPHA_BODY = 0.3
    local CD_BODY = 0.3

    local INERTIA = Vec3.new(4000, 4000, 1000)

    local INERTIA_X = 4000.0
    local INERTIA_Y = 4000.0
    local INERTIA_Z = 1000.0

    local PITCH_TORQUE = 80000.0
    local YAW_TORQUE = 80000.0
    local ROLL_TORQUE = 15000.0

    local PITCH_DAMPING = 4000.0
    local YAW_DAMPING = 4000.0
    local ROLL_DAMPING = 1000.0

    --local WINGS_CENTER_OF_PRESSURE = Vec(0, 0, self.wingsOffsetY)
    --local WINGS_CENTER_OF_PRESSURE = Vec(0, 0, 0)

    -- Input
    -- TODO mapping?
    -- TODO enforce clamp
    -- TODO replace with self.var

    local propulsion = self.propulsion -- [0, 1]
    local wingsSpreading = self.wingsSpreading -- [0, 1]
    local pitchInput = self.pitchInput -- [-1, 1]
    local yawInput = self.yawInput -- [-1, 1]
    local rollInput = self.rollInput -- [-1, 1]

    -- Pre-calculated
    local velocityDir, velocity = self.velocity:normalize()
    local localVelocityVec = self.velocity:toBasis(self.right, self.up, self.forward)
    local localVelocityDir = localVelocityVec:normalize()

    -- TODO relative velocity: wind

    -- TODO debug
    DebugWatch("Propulsion", self.propulsion)
    DebugWatch("Position", self.transform.pos)
    DebugWatch("Velocity", self.velocity)
    DebugWatch("Local velocity", localVelocityVec)
    DebugWatch("Speed", velocity)

    -- Helpers

    function _localPointVelocity(point)
      return localVelocityVec + VecCross(self.angularVelocity, point)
    end

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

      local aoa = -localVelocityDir:anglePlane(normalAxis)
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

      --DebugPrint("Angle of attack for axis: "..math.deg(aoa))

      local liftDir = -velocityVec:orthogonalize(axis):normalize()
      local q = 0.5 * airDensity * localVelocity * localVelocity

      return (q * area * cl) * liftDir
    end

    ---@param velocityVec Vec3 Velocity (should be in the same space as axis)
    ---@param airDensity number
    ---@param area number Surface area
    ---@param cd number Drag coefficient
    ---@param axis Vec3 Surface axis (normalized)
    local function _calculateDrag(velocityVec, airDensity, area, cd, axis)
      local localVelocityVec = velocityVec:project(axis)
      local localVelocityDir, localVelocity = localVelocityVec:normalize()

      if localVelocity < Math.EPSILON then
        return Vec3.new()
      end

      -- TODO check sign
      -- Mul by -sign to handle both sides and move in the opposite direction
      local q = -0.5 * airDensity * localVelocity * localVelocity * Math.sign(localVelocityDir:dot(axis))
      return (q * area * cd) * axis
    end


    -- Forces (Linear)


    -- Gravity
    local fGravity = Vec3.from(GetGravity()) * Missile.MASS

    -- Thrust
    local fThrust = THRUST * propulsion * self.forward

    -- Lift

    --Lift for:
    -- +rocket Z axis
    -- wings XZ plane ((+)front + side?)
    -- 4 stabilizers: (front only? + TODO add torque calculation)

    local fLiftWings = _calculateLift(localVelocityVec, AIR_DENSITY, AREA_WINGS_TOP, CL_ALPHA_WINGS, Math.OBJ_RIGHT, Math.OBJ_UP) * wingsSpreading
    local fLiftBody = _calculateLiftAxis(localVelocityVec, AIR_DENSITY, AREA_BODY_SIDE, CL_ALPHA_BODY, Math.OBJ_FORWARD)

    local fLiftWingTotal = Vec3.new()
    local tLiftWingTotal = Vec3.new()

    local wingsData = {
      { self.wingPivotDirTL, self.wingAngleTL, self.wingPivotPosTL },
      { self.wingPivotDirTR, self.wingAngleTR, self.wingPivotPosTR },
      { self.wingPivotDirBL, self.wingAngleBL, self.wingPivotPosBL },
      { self.wingPivotDirBR, self.wingAngleBR, self.wingPivotPosBR },
    }

    -- TODO add velocity obtained from angularVelocity (calculate using radius vector)
    -- TODO add drag calculation

    for _, wingData in ipairs(wingsData) do
      local wingPointVelocity = _localPointVelocity(wingData[3])

      -- No idea why tf rotation is inversed. maybe because model was rotated in other direction, idk TODO investigate
      local normal = Math.OBJ_FORWARD:rotateAround(wingData[1], -math.rad(wingData[2] - 90))
      local fLiftWing = _calculateLift(wingPointVelocity, AIR_DENSITY, AREA_STABILIZER, CL_ALPHA_STABILIZER, wingData[1], normal)
      -- TODO minus helped, but that should be wrong. maybe normals are messed up?
      local tLiftWing = -wingData[3]:cross(fLiftWing)

      fLiftWingTotal = fLiftWingTotal + fLiftWing
      tLiftWingTotal = tLiftWingTotal + tLiftWing

      Debug.Vec(wingData[1]:fromBasis(self.right, self.up, self.forward), wingData[3]:invertZ():fromTransformPos(self.transform))
      Debug.Vec(normal:fromBasis(self.right, self.up, self.forward), wingData[3]:invertZ():fromTransformPos(self.transform))
    end

    -- Drag
    local fFrontDrag = _calculateDrag(localVelocityVec, AIR_DENSITY, AREA_BODY_FRONT + AREA_WINGS_FRONT * wingsSpreading, CD_BODY, Math.OBJ_FORWARD)
    local fTopDrag = _calculateDrag(localVelocityVec, AIR_DENSITY, AREA_BODY_SIDE + AREA_WINGS_TOP * wingsSpreading, CD_BODY, Math.OBJ_UP)
    local fSideDrag = _calculateDrag(localVelocityVec, AIR_DENSITY, AREA_BODY_SIDE, CD_BODY, Math.OBJ_RIGHT)

    --Debug.Vec(fForwardDrag:fromBasis(self.right, self.up, self.forward), self.transform.pos)
    --DebugWatch("fForwardDrag", fForwardDrag)
    --DebugWatch("fForwardDragLength", fForwardDrag:length())

    -- Damping
    local tDampingBody = Vec3.new(
      -self.angularVelocity[1] * PITCH_DAMPING,
      -self.angularVelocity[2] * YAW_DAMPING,
      -self.angularVelocity[3] * ROLL_DAMPING
    ) * 0

    -- Combine
    local localForces = fLiftWings + fLiftBody + fFrontDrag + fTopDrag + fSideDrag + fLiftWingTotal
    local worldForces = fGravity + fThrust
    local forces = worldForces + localForces:fromBasis(self.right, self.up, self.forward)

    local torque = tLiftWingTotal + tDampingBody
    local angularAcceleration = torque / INERTIA

    -- Forces (Rotational)


    --local angularMomentum = Vec(
    --  INERTIA_X * self.angularVelocity[1],
    --  INERTIA_Y * self.angularVelocity[2],
    --  INERTIA_Z * self.angularVelocity[3]
    --)
    --local gyroTorque = VecCross(self.angularVelocity, angularMomentum)
    --local tauControl = Math.VecAdd(
    --  VecScale(self.right, PITCH_TORQUE * pitchInput),
    --  VecScale(self.up, YAW_TORQUE * yawInput),
    --  VecScale(self.forward, ROLL_TORQUE * rollInput)
    --)
    --
    --local tauDampingBody = Vec(
    --  -self.angularVelocity[1] * PITCH_DAMPING,
    --  -self.angularVelocity[2] * YAW_DAMPING,
    --  -self.angularVelocity[3] * ROLL_DAMPING
    --)
    --
    --local tauControlBody = TransformToLocalVec(self.transform, tauControl)
    --local torque = Math.VecAdd(tauControlBody, tauDampingBody, tLiftWingTotal)
    --local angularAcceleration = Vec(
    --  (torque[1] - gyroTorque[1]) / INERTIA_X,
    --  (torque[2] - gyroTorque[2]) / INERTIA_Y,
    --  (torque[3] - gyroTorque[3]) / INERTIA_Z
    --)


    -- Integrate (Linear)
    local acceleration = forces / Missile.MASS
    self.velocity = self.velocity + acceleration * deltaTime
    self.transform.pos = VecAdd(self.transform.pos, self.velocity * deltaTime)

    -- Integrate (Rotational)
    self.angularVelocity = VecAdd(self.angularVelocity, VecScale(angularAcceleration, deltaTime))

    local angularAxis, angularSpeed = Math.VecNormalizeSafe(self.angularVelocity)
    if angularSpeed > Math.EPSILON then
      local angularDeltaDegrees = math.deg(angularSpeed * deltaTime)
      local deltaRotation = QuatAxisAngle(angularAxis, angularDeltaDegrees)
      self.transform.rot = QuatRotateQuat(self.transform.rot, deltaRotation)
    end

    -- Update body basis
    self.right = Math.RIGHT:rotate(self.transform.rot)
    self.up = Math.UP:rotate(self.transform.rot)
    self.forward = Math.FORWARD:rotate(self.transform.rot)

    -- Apply transform
    SetBodyTransform(self.entities[1], self.transform)

    -- TODO DEBUG
    --Debug.Vec(self.velocity, self.transform.pos)
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