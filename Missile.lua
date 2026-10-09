#version 2
#include "Math.lua"
#include "Physics.lua"
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
      wingTransformLeft = nil,
      wingTransformRight = nil,
      wingsOffsetY = 0.0,

      -- Fins data
      finsOffsetX = 0.0,
      finsOffsetY = 0.0,
      finsOffsetZ = 0.0,
      finTL = nil,
      finTR = nil,
      finBL = nil,
      finBR = nil,
      finTransformTL = nil,
      finTransformTR = nil,
      finTransformBL = nil,
      finTransformBR = nil,

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

    self.finTL = self.entities[3]
    self.finTR = self.entities[4]
    self.finBL = self.entities[5]
    self.finBR = self.entities[6]

    -- Get default shape transforms
    self.wingTransformLeft = GetShapeLocalTransform(self.leftWing)
    self.wingTransformRight = GetShapeLocalTransform(self.rightWing)

    self.finTransformTL = GetShapeLocalTransform(self.finTL)
    self.finTransformTR = GetShapeLocalTransform(self.finTR)
    self.finTransformBL = GetShapeLocalTransform(self.finBL)
    self.finTransformBR = GetShapeLocalTransform(self.finBR)

    -- Calculate wings offset
    local leftWingSizeX, leftWingSizeY, leftWingSizeZ, leftWingScale = GetShapeSize(self.leftWing)
    local rightWingSizeX, rightWingSizeY, rightWingSizeZ, rightWingScale = GetShapeSize(self.rightWing)
    self.scale = leftWingScale
    self.wingsOffsetY = -2.5 * self.scale

    -- Move wings to their place
    self.wingTransformLeft.pos = VecAdd(self.wingTransformLeft.pos, Vec(0, self.wingsOffsetY, 0))
    self.wingTransformRight.pos = VecAdd(self.wingTransformRight.pos, Vec(0, self.wingsOffsetY, 0))
    SetShapeLocalTransform(self.leftWing, self.wingTransformLeft)
    SetShapeLocalTransform(self.rightWing, self.wingTransformRight)

    -- Calculate wings pivot (+3 voxels from wing base)
    self.leftWingPivot = Vec(-0.5 * leftWingSizeX * self.scale, 0, -10 * self.scale)
    self.rightWingPivot = Vec(0.5 * rightWingSizeX * self.scale, 0, -10 * self.scale)


    -- Calculate fins offset
    self.finsOffsetX = 9 * self.scale
    self.finsOffsetY = 6 * self.scale
    self.finsOffsetZ = -41.5 * self.scale

    -- Calculate fins axes (in body space)
    self.finPivotPosTL = Vec3.new(-self.finsOffsetX, self.finsOffsetY, self.finsOffsetZ)
    self.finPivotPosTR = Vec3.new(self.finsOffsetX, self.finsOffsetY, self.finsOffsetZ)
    self.finPivotPosBL = Vec3.new(-self.finsOffsetX, -self.finsOffsetY, self.finsOffsetZ)
    self.finPivotPosBR = Vec3.new(self.finsOffsetX, -self.finsOffsetY, self.finsOffsetZ)

    self.finPivotDirTL = Math.OBJ_UP:rotateAround(Math.OBJ_FORWARD, math.rad(45))
    self.finPivotDirTR = Math.OBJ_UP:rotateAround(Math.OBJ_FORWARD, -math.rad(45))
    self.finPivotDirBL = Math.OBJ_UP:rotateAround(Math.OBJ_FORWARD, math.rad(135))
    self.finPivotDirBR = Math.OBJ_UP:rotateAround(Math.OBJ_FORWARD, -math.rad(135))

    self.finAngleTL = 0.0
    self.finAngleTR = 0.0
    self.finAngleBL = 0.0
    self.finAngleBR = 0.0
  end

  function Missile:update(deltaTime)
    if self.exploded then
      return
    end

    -- === Update wings ===
    self:_updateWingsSpreading(deltaTime)
    local newLeftWingTransform = Math.RotateTransformAroundPivot(self.wingTransformLeft, self.leftWingPivot, QuatEuler(0, -self.wingsRotation, 0))
    local newRightWingTransform = Math.RotateTransformAroundPivot(self.wingTransformRight, self.rightWingPivot, QuatEuler(0, self.wingsRotation, 0))
    SetShapeLocalTransform(self.leftWing, newLeftWingTransform)
    SetShapeLocalTransform(self.rightWing, newRightWingTransform)



    -- === Fins control mixing ===
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

    pitch = -pitch
    --yaw = -yaw
    --roll = -roll

    DebugWatch("pitch", pitch)
    DebugWatch("yaw", yaw)
    DebugWatch("roll", roll)

    local maxAngle = 25
    local s = 0.7
    self.finAngleTL = (roll + s * (pitch + yaw)) * maxAngle
    self.finAngleTR = (roll + s * (-pitch + yaw)) * maxAngle
    self.finAngleBL = (roll + s * (pitch - yaw)) * maxAngle
    self.finAngleBR = (roll + s * (-pitch - yaw)) * maxAngle



    -- === Set stabilizers visual rotation ===
    -- -Z forward in transforms - invert Z
    local finsData = {
      { self.finTL, self.finTransformTL, self.finPivotDirTL, self.finPivotPosTL:invertZ(), self.finAngleTL },
      { self.finTR, self.finTransformTR, self.finPivotDirTR, self.finPivotPosTR:invertZ(), self.finAngleTR },
      { self.finBL, self.finTransformBL, self.finPivotDirBL, self.finPivotPosBL:invertZ(), self.finAngleBL },
      { self.finBR, self.finTransformBR, self.finPivotDirBR, self.finPivotPosBR:invertZ(), self.finAngleBR },
    }

    for _, finData in ipairs(finsData) do
      SetShapeLocalTransform(
        finData[1],
        Math.RotateTransformAroundAxis(
          finData[2],
          finData[3],
          finData[4],
          finData[5]
        )
      )
    end



    -- === Update movement ===
    if not debugMissile then
      self:_updateMovement(deltaTime)
    end


    ---- === Draw debug axes ===
    ---- TL
    --Debug.Vec(
    --  self.finPivotDirTL:fromBasis(self.right, self.up, self.forward),
    --  Vec3.from(self.transform.pos) + self.finPivotPosTL:fromBasis(self.right, self.up, self.forward)
    --)
    --
    ---- TR
    --Debug.Vec(
    --  self.finPivotDirTR:fromBasis(self.right, self.up, self.forward),
    --  Vec3.from(self.transform.pos) + self.finPivotPosTR:fromBasis(self.right, self.up, self.forward)
    --)
    --
    ---- BL
    --Debug.Vec(
    --  self.finPivotDirBL:fromBasis(self.right, self.up, self.forward),
    --  Vec3.from(self.transform.pos) + self.finPivotPosBL:fromBasis(self.right, self.up, self.forward)
    --)
    --
    ---- BR
    --Debug.Vec(
    --  self.finPivotDirBR:fromBasis(self.right, self.up, self.forward),
    --  Vec3.from(self.transform.pos) + self.finPivotPosBR:fromBasis(self.right, self.up, self.forward)
    --)
  end

  function Missile:_updateMovement(deltaTime)
    -- Parameters
    local THRUST = 8000
    local AIR_DENSITY = 1.22 -- TODO min max

    local AREA_WINGS_TOP = 8.0
    local CL_ALPHA_WINGS = 5.5
    local CD_WINGS = 0.3

    --local WINGS_POS = Vec3.new(0, self.wingsOffsetY, 0)
    local WINGS_POS = Vec3.new(0, 0, 0)
    local WINGS_SIZE = self.scale * 40

    local AREA_FIN = 0.5
    local CL_ALPHA_FIN = 0.5
    local CD_FIN = 0.1

    local AREA_BODY_SIDE = 10.0
    local AREA_BODY_FRONT = 1.5
    local CL_ALPHA_BODY = 0.3
    local CD_BODY = 0.3

    local INERTIA = Vec3.new(4000, 4000, 1000)
    local TORQUE_DAMPING = Vec3.new(4000, 4000, 1000)

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



    -- === Forces ===

    -- Gravity
    local fGravity = Vec3.from(GetGravity()) * Missile.MASS

    -- Thrust
    local fThrust = THRUST * propulsion * self.forward


    -- == Lift / Drag ==

    -- Body
    local fLiftBody = Physics.CalculateLiftAxis(localVelocityVec, AIR_DENSITY, AREA_BODY_SIDE, CL_ALPHA_BODY, Math.OBJ_FORWARD)

    local fFrontDrag = Physics.CalculateDrag(localVelocityVec, AIR_DENSITY, AREA_BODY_FRONT, CD_BODY, Math.OBJ_FORWARD)
    local fTopDrag = Physics.CalculateDrag(localVelocityVec, AIR_DENSITY, AREA_BODY_SIDE, CD_BODY, Math.OBJ_UP)
    local fSideDrag = Physics.CalculateDrag(localVelocityVec, AIR_DENSITY, AREA_BODY_SIDE, CD_BODY, Math.OBJ_RIGHT)

    -- Main wings
    local fLiftWings = Physics.CalculateLift(localVelocityVec, AIR_DENSITY, AREA_WINGS_TOP, CL_ALPHA_WINGS, Math.OBJ_RIGHT, Math.OBJ_UP) * wingsSpreading

    local rightVec = WINGS_POS + Math.OBJ_RIGHT * WINGS_SIZE
    local leftVec = WINGS_POS - Math.OBJ_RIGHT * WINGS_SIZE
    local tLiftWingsRight = -rightVec:cross(fLiftWings)
    local tLiftWingsLeft = -leftVec:cross(fLiftWings)
    local tWings = tLiftWingsRight + tLiftWingsLeft

    -- Fins
    local fLiftFinTotal = Vec3.new()
    local tLiftFinTotal = Vec3.new()

    local finsData = {
      { self.finPivotDirTL, self.finAngleTL, self.finPivotPosTL },
      { self.finPivotDirTR, self.finAngleTR, self.finPivotPosTR },
      { self.finPivotDirBL, self.finAngleBL, self.finPivotPosBL },
      { self.finPivotDirBR, self.finAngleBR, self.finPivotPosBR },
    }

    for _, finData in ipairs(finsData) do
      local finPointVelocity = Physics.PointVelocity(finData[3], localVelocityVec, self.angularVelocity)

      -- No idea why tf rotation is inversed. maybe because model was rotated in other direction, idk TODO investigate
      local normal = Math.OBJ_FORWARD:rotateAround(finData[1], -math.rad(finData[2] - 90))
      --local normal = Math.OBJ_FORWARD:rotateAround(finData[1], math.rad(-finData[2] - 90))
      local fLiftFin = Physics.CalculateLift(finPointVelocity, AIR_DENSITY, AREA_FIN, CL_ALPHA_FIN, finData[1], normal)
      -- TODO minus helped, but that should be wrong. maybe normals are messed up?
      -- TODO but the force is correct...
      local tLiftFin = -finData[3]:cross(fLiftFin)


      local fDragFin = Physics.CalculateDrag(finPointVelocity, AIR_DENSITY, AREA_FIN, CD_FIN, normal)
      local tDragFin = -finData[3]:cross(fDragFin)

      fLiftFinTotal = fLiftFinTotal + fLiftFin + fDragFin
      tLiftFinTotal = tLiftFinTotal + tLiftFin + tDragFin

      -- TODO debug axes
      --Debug.Vec(finData[1]:fromBasis(self.right, self.up, self.forward), finData[3]:invertZ():fromTransformPos(self.transform))
      --Debug.Vec(normal:fromBasis(self.right, self.up, self.forward), finData[3]:invertZ():fromTransformPos(self.transform))

      -- TODO debug torque direction
      --Debug.Vec(finData[3]:fromBasis(self.right, self.up, self.forward), finData[3]:invertZ():fromTransformPos(self.transform))
      --Debug.Vec(fLiftFin:fromBasis(self.right, self.up, self.forward), finData[3]:invertZ():fromTransformPos(self.transform))
      --Debug.Vec(tLiftFin:fromBasis(self.right, self.up, self.forward), finData[3]:invertZ():fromTransformPos(self.transform))
      --DebugPrint("Torque: "..tostring(tLiftFin))
    end

    -- TODO debug world stuff
    --Debug.Vec(velocityDir, self.transform.pos)
    --Debug.Vec(fForwardDrag:fromBasis(self.right, self.up, self.forward), self.transform.pos)
    --DebugWatch("fForwardDrag", fForwardDrag)
    --DebugWatch("fForwardDragLength", fForwardDrag:length())

    -- Damping
    local tDampingBody = -self.angularVelocity * TORQUE_DAMPING * 0



    -- === Combine forces ===
    local localForces = fLiftWings + fLiftBody + fFrontDrag + fTopDrag + fSideDrag + fLiftFinTotal
    local worldForces = fGravity + fThrust
    local forces = worldForces + localForces:fromBasis(self.right, self.up, self.forward)

    local torque = tLiftFinTotal + tWings + tDampingBody
    local angularAcceleration = torque / INERTIA

    -- === Integrate (Linear) ===
    local acceleration = forces / Missile.MASS
    self.velocity = self.velocity + acceleration * deltaTime
    self.transform.pos = VecAdd(self.transform.pos, self.velocity * deltaTime)

    -- === Integrate (Rotational) ===
    self.angularVelocity = self.angularVelocity + angularAcceleration * deltaTime

    local angularAxis, angularSpeed = self.angularVelocity:normalize()
    if angularSpeed > Math.EPSILON then
      local angularDeltaDegrees = math.deg(angularSpeed * deltaTime)
      local deltaRotation = QuatAxisAngle(angularAxis, angularDeltaDegrees)
      self.transform.rot = QuatRotateQuat(self.transform.rot, deltaRotation)
    end

    -- === Update body basis ===
    self.right = Math.RIGHT:rotate(self.transform.rot)
    self.up = Math.UP:rotate(self.transform.rot)
    self.forward = Math.FORWARD:rotate(self.transform.rot)

    -- === Apply transform ===
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