#include "Math.lua"
#include "Physics.lua"
#include "SoundManager.lua"
#include "Debug.lua"

-- Missile is facing in the -Z direction
-- LOG: Tried +Z, but it's easier to remember that forward is at negative direction, than that right is left. Camera is also looking at -Z, so with +Z I'd have to invert the body transform

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
Missile.NOSE_OFFSET = Vec3.new(0, 0, -2.5)
Missile.NOZZLE_OFFSET = Vec3.new(0, 0, 3.0)
Missile.CAMERA_OFFSET = Vec3.new(0, 1, 6.0)

Missile.MASS = 800
Missile.FIN_PIVOT_SIZE = 0.3
Missile.FIN_MAX_ANGLE = 25.0
Missile.FIN_ROTATION_SPEED = 360.0

Missile.PROPULSION_CHANGE_SPEED = 0.5

Missile.DETONATION_TIME = 0.15
Missile.PENETRATION_TABLE = {
  ["foliage"] = 0.01,
  ["glass"] = 0.1,
  ["dirt"] = 0.1,
  ["plaster"] = 0.1,
  ["wood"] = 0.1,
  ["brick"] = 0.1,
  ["masonry"] = 0.1,
  ["metal"] = 0.1,
  ["rock"] = 1.0,
  ["heavymetal"] = 0.2,
  ["unphysical"] = 1.0,
}

function Missile.new()
  local obj = {
    __type = "Missile",

    -- Entities
    entities = {},

    -- Wings visual data
    scale = 1.0,

    leftWing = nil,
    rightWing = nil,
    wingTransformLeft = nil,
    wingTransformRight = nil,
    wingsOffsetY = 0.0,

    -- Fins visual data
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

    -- Effects
    smokeTimer = 0.0,

    -- Wings state
    wingsRotation = Missile.WINGS_FOLDED_ROTATION,
    wingsTargetRotation = Missile.WINGS_FOLDED_ROTATION,
    wingsStateProgress = 1,
    wingsSpreading = 0,
    wingsState = Missile.WingsState.FOLDED,

    -- Destroyed
    isDestroyed = false,
    ownerId = 0,

    -- Explosion
    penetrationMode = false,
    isArmed = false,
    shouldDetonate = false,
    detonationTimer = 0.0,
    penetration = 1.0,

    -- Physics
    transform = Transform(),
    right = Math.RIGHT,
    up = Math.UP,
    forward = Math.FORWARD,

    velocity = Vec3.new(),
    angularVelocity = Vec3.new(),
    propulsion = 0.0,

    -- Input
    pitchInput = 0.0,
    yawInput = 0.0,
    rollInput = 0.0,
    propulsionInput = 0.0
  }

  return setmetatable(obj, Missile)
end

function Missile:spawn(transform)
  -- Not reusable
  if self.isDestroyed then
    return
  end

  -- Update transform and basis
  if transform == nil then
    transform = Transform()
  end

  self.transform = transform
  self:_updateBasis()

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
  self.finsOffsetZ = 41.5 * self.scale

  -- Calculate fins axes (in body space)
  self.finPivotPosTL = Vec3.new(-self.finsOffsetX, self.finsOffsetY, self.finsOffsetZ)
  self.finPivotPosTR = Vec3.new(self.finsOffsetX, self.finsOffsetY, self.finsOffsetZ)
  self.finPivotPosBL = Vec3.new(-self.finsOffsetX, -self.finsOffsetY, self.finsOffsetZ)
  self.finPivotPosBR = Vec3.new(self.finsOffsetX, -self.finsOffsetY, self.finsOffsetZ)

  self.finPivotDirTL = Math.UP:rotateAround(Math.FORWARD, -math.rad(45))
  self.finPivotDirTR = Math.UP:rotateAround(Math.FORWARD, math.rad(45))
  self.finPivotDirBL = Math.UP:rotateAround(Math.FORWARD, -math.rad(135))
  self.finPivotDirBR = Math.UP:rotateAround(Math.FORWARD, math.rad(135))

  self.finAngleTL = 0.0
  self.finAngleTR = 0.0
  self.finAngleBL = 0.0
  self.finAngleBR = 0.0

  self.finAngleTargetTL = 0.0
  self.finAngleTargetTR = 0.0
  self.finAngleTargetBL = 0.0
  self.finAngleTargetBR = 0.0

  -- Effects
  self.engineLoop = server.CreateLoop("engine", self.transform.pos, 0, false, 1.0)
end

function Missile:_updateBasis()
  self.right = Math.RIGHT:rotate(self.transform.rot)
  self.up = Math.UP:rotate(self.transform.rot)
  self.forward = Math.FORWARD:rotate(self.transform.rot)
end

function Missile:update(deltaTime)
  if self.isDestroyed then
    return
  end

  -- === Update wings ===
  self:_updateWingsSpreading(deltaTime)
  self:_updateWingsTransform()


  -- === Update propulsion ===
  self.propulsion = Math.moveTowards(self.propulsion, self.propulsionInput, Missile.PROPULSION_CHANGE_SPEED * deltaTime)


  -- === Fins control mixing ===
  local pitch = self.pitchInput
  local yaw = -self.yawInput
  local roll = self.rollInput

  local xyLength = math.sqrt(pitch * pitch + yaw * yaw)
  --pitch = pitch / xyLength
  --yaw = yaw / xyLength

  local s = 1.0
  self.finAngleTargetTL = Math.clamp(roll + s * (pitch + yaw), -1, 1) * Missile.FIN_MAX_ANGLE
  self.finAngleTargetTR = Math.clamp(roll + s * (-pitch + yaw), -1, 1) * Missile.FIN_MAX_ANGLE
  self.finAngleTargetBL = Math.clamp(roll + s * (pitch - yaw), -1, 1) * Missile.FIN_MAX_ANGLE
  self.finAngleTargetBR = Math.clamp(roll + s * (-pitch - yaw), -1, 1) * Missile.FIN_MAX_ANGLE

  self.finAngleTL = Math.moveTowards(self.finAngleTL, self.finAngleTargetTL, Missile.FIN_ROTATION_SPEED * deltaTime)
  self.finAngleTR = Math.moveTowards(self.finAngleTR, self.finAngleTargetTR, Missile.FIN_ROTATION_SPEED * deltaTime)
  self.finAngleBL = Math.moveTowards(self.finAngleBL, self.finAngleTargetBL, Missile.FIN_ROTATION_SPEED * deltaTime)
  self.finAngleBR = Math.moveTowards(self.finAngleBR, self.finAngleTargetBR, Missile.FIN_ROTATION_SPEED * deltaTime)

  -- === Set stabilizers visual rotation ===
  local finsData = {
    { self.finTL, self.finTransformTL, self.finPivotDirTL, self.finPivotPosTL, self.finAngleTL },
    { self.finTR, self.finTransformTR, self.finPivotDirTR, self.finPivotPosTR, self.finAngleTR },
    { self.finBL, self.finTransformBL, self.finPivotDirBL, self.finPivotPosBL, self.finAngleBL },
    { self.finBR, self.finTransformBR, self.finPivotDirBR, self.finPivotPosBR, self.finAngleBR },
  }

  for _, finData in ipairs(finsData) do
    SetShapeLocalTransform(
      finData[1],
      Math.RotateTransformAroundAxis(
        finData[2],
        finData[3],
        finData[4],
        -finData[5]
      )
    )
  end



  -- === Update movement ===
  if not debugMissile then
    self:_updateMovement(deltaTime)
  end


  -- === Update particles ===
  if self.propulsion > Math.EPSILON then
    self.smokeTimer = self.smokeTimer + deltaTime
    if self.smokeTimer > 0.02 * (1.1 - self.propulsion) then
      self.smokeTimer = 0.0

      local velocity = -self.forward * math.max(self.forward:dot(self.velocity), 10)

      ParticleType("plain")
      ParticleRadius(self.propulsion * 0.3 + 0.1, 1.0)
      ParticleDrag(0.1)
      SpawnParticle(Missile.NOZZLE_OFFSET:fromTransformPos(self.transform), velocity, 2)
    end
  end



  -- === Update music effects ===
  shared.soundLoops[self.engineLoop].pos = self.transform.pos
  shared.soundLoops[self.engineLoop].volume = self.propulsion

  ---- === Draw debug axes ===
  --Debug.VecInTransform(self.transform, self.finPivotPosTL, self.finPivotDirTL)
  --Debug.VecInTransform(self.transform, self.finPivotPosTR, self.finPivotDirTR)
  --Debug.VecInTransform(self.transform, self.finPivotPosBL, self.finPivotDirBL)
  --Debug.VecInTransform(self.transform, self.finPivotPosBR, self.finPivotDirBR)


  --- === Handle detonation ===
  self:_checkDetonation(deltaTime)

  if self.isArmed then
    self.detonationTimer = self.detonationTimer - deltaTime
    if self.detonationTimer < 0 then
      self.shouldDetonate = true
    end
  end

  if self.shouldDetonate then
    self:explode()
  end
end

function Missile:_checkDetonation(deltaTime)
  local checkPos = Missile.NOZZLE_OFFSET:fromTransformPos(self.transform)
  local checkDir = self.forward
  local checkDist = (Missile.NOSE_OFFSET - Missile.NOZZLE_OFFSET):length()
  local radius = 30 * self.scale

  QueryRejectBody(self.entities[1])
  --local hit, dist, normal, shape = QueryRaycast(checkPos, checkDir, checkDist, radius)
  local hit, dist, normal, shape = QueryRaycast(checkPos, checkDir, checkDist)

  if hit then
    local hitPos = checkPos + checkDir * dist
    local hasUnbreakableTag = HasTag(shape, "unbreakable")

    MakeHole(hitPos, radius, radius, radius)

    if hasUnbreakableTag then
      self.shouldDetonate = true
    end

    if self.penetrationMode then
      -- Check materials
      local material = GetShapeMaterialAtPosition(shape, hitPos)
      if material ~= nil then
        local penetrationLoss = Missile.PENETRATION_TABLE[material] or 0
        self.penetration = self.penetration - penetrationLoss * self.velocity:length() * deltaTime
        if self.penetration <= 0 then
          self.shouldDetonate = true
        end
      end
    else
      -- Start timer
      if not self.isArmed then
        self.isArmed = true
        self.detonationTimer = Missile.DETONATION_TIME
      end
    end
  end
end

function Missile:_updateMovement(deltaTime)
  local cInertia = 500 * 2
  local cDamping = 50 * 8
  local cThrust = 1
  local cLift = 1
  local cDragWings = 1

  -- Parameters
  local THRUST = 8000 * cThrust
  local AIR_DENSITY = 1.22 -- TODO min max

  --local WINGS_POS = Vec3.new(0, self.wingsOffsetY, 0)
  --local WINGS_POS = Vec3.new(0, self.scale * 8, self.scale * 10)
  --local WINGS_POS = Vec3.new(0, self.scale * 8, -self.scale * 3)
  --local WINGS_POS = Vec3.new(0, self.scale * 8, 0)
  local WINGS_POS = Vec3.new(0, 0, 0)
  local WINGS_SIZE = self.scale * 30

  local AREA_WING_TOP = 4.0
  local CL_ALPHA_WING = 3.5 * cLift
  local CD_WING = 1.0 * cDragWings

  local AREA_FIN = 0.5
  local CL_ALPHA_FIN = 1.5 * cLift
  local CD_FIN = 1.0 * cDragWings

  local AREA_BODY_SIDE = 8.0
  local AREA_BODY_FRONT = 1.5
  local CL_ALPHA_BODY = 1.0
  local CD_BODY = 1.0

  local INERTIA = Vec3.new(4, 4, 1) * cInertia
  local TORQUE_DAMPING = Vec3.new(4, 4, 1) * cDamping

  -- Pre-calculated
  local velocityDir, velocity = self.velocity:normalize()
  local localVelocityVec = self.velocity:toBasis(self.right, self.up, self.forward)
  local localVelocityDir = localVelocityVec:normalize()

  -- TODO relative velocity: wind
  -- TODO debug
  --DebugWatch("Position", self.transform.pos)
  --DebugWatch("Velocity", self.velocity)
  --DebugWatch("Local velocity", localVelocityVec)
  --DebugWatch("Speed", velocity)


  -- === Forces ===
  local localForce = Vec3.new()
  local force = Vec3.new()
  local torque = Vec3.new()

  -- Gravity
  local fGravity = Vec3.from(GetGravity()) * Missile.MASS
  force = force + fGravity

  -- Thrust
  local fThrust = THRUST * self.propulsion * self.forward
  force = force + fThrust

  -- == Lift / Drag ==

  -- Body
  local fLiftBody = Physics.CalculateLiftAxis(localVelocityVec, AIR_DENSITY, AREA_BODY_SIDE, CL_ALPHA_BODY, Math.FORWARD)

  local fFrontDrag = Physics.CalculateDrag(localVelocityVec, AIR_DENSITY, AREA_BODY_FRONT, CD_BODY, Math.FORWARD)
  local fTopDrag = Physics.CalculateDrag(localVelocityVec, AIR_DENSITY, AREA_BODY_SIDE, CD_BODY, Math.UP)
  local fSideDrag = Physics.CalculateDrag(localVelocityVec, AIR_DENSITY, AREA_BODY_SIDE, CD_BODY, Math.RIGHT)

  localForce = localForce + fLiftBody + fFrontDrag + fTopDrag + fSideDrag

  -- Main wings
  if self.wingsSpreading > 0.1 then
    local rightVec = WINGS_POS + Math.RIGHT * WINGS_SIZE * self.wingsSpreading
    local leftVec = WINGS_POS - Math.RIGHT * WINGS_SIZE * self.wingsSpreading
    local rightWingVelocity = Physics.PointVelocity(rightVec, localVelocityVec, self.angularVelocity)
    local leftWingVelocity = Physics.PointVelocity(leftVec, localVelocityVec, self.angularVelocity)

    local fLiftRightWing = Physics.CalculateLift(rightWingVelocity, AIR_DENSITY, AREA_WING_TOP, CL_ALPHA_WING, Math.RIGHT, Math.UP) * self.wingsSpreading
    local fLiftLeftWing = Physics.CalculateLift(leftWingVelocity, AIR_DENSITY, AREA_WING_TOP, CL_ALPHA_WING, -Math.RIGHT, Math.UP) * self.wingsSpreading
    local tLiftRightWing = rightVec:cross(fLiftRightWing)
    local tLiftLeftWing = leftVec:cross(fLiftLeftWing)

    local fDragRightWing = Physics.CalculateDrag(rightWingVelocity, AIR_DENSITY, AREA_WING_TOP, CD_WING, Math.UP)
    local fDragLeftWing = Physics.CalculateDrag(leftWingVelocity, AIR_DENSITY, AREA_WING_TOP, CD_WING, Math.UP)
    local tDragRightWing = rightVec:cross(fDragRightWing)
    local tDragLeftWing = leftVec:cross(fDragLeftWing)

    localForce = localForce + fLiftRightWing + fLiftLeftWing + fDragRightWing + fDragLeftWing
    torque = torque + tLiftRightWing + tLiftLeftWing + tDragRightWing + tDragLeftWing

    --Debug.VecInTransform(self.transform, WINGS_POS + rightVec, fLiftRightWing)
    --Debug.VecInTransform(self.transform, WINGS_POS + leftVec, fLiftLeftWing)
    --DebugPrint(tLiftRightWing:length())
    --DebugPrint(tLiftLeftWing:length())

    -- TODO debug
    --Debug.PosInTransform(self.transform, WINGS_POS)
    --Debug.LineInTransform(self.transform, WINGS_POS, rightVec)
    --Debug.LineInTransform(self.transform, WINGS_POS, leftVec)
    --
    --Debug.VecInTransform(self.transform, rightVec, fLiftRightWing)
    --Debug.VecInTransform(self.transform, leftVec, fLiftLeftWing)
  end

  -- Fins
  local finsData = {
    { self.finPivotDirTL, self.finAngleTL, self.finPivotPosTL },
    { self.finPivotDirTR, self.finAngleTR, self.finPivotPosTR },
    { self.finPivotDirBL, self.finAngleBL, self.finPivotPosBL },
    { self.finPivotDirBR, self.finAngleBR, self.finPivotPosBR },
  }

  for _, finData in ipairs(finsData) do
    local finPos = finData[3] + finData[1] * Missile.FIN_PIVOT_SIZE
    local finPointVelocity = Physics.PointVelocity(finPos, localVelocityVec, self.angularVelocity)

    local normal = Math.FORWARD:rotateAround(finData[1], math.rad(-finData[2] - 90))
    local fLiftFin = Physics.CalculateLift(finPointVelocity, AIR_DENSITY, AREA_FIN, CL_ALPHA_FIN, finData[1], normal)
    local tLiftFin = finPos:cross(fLiftFin)

    local fDragFin = Physics.CalculateDrag(finPointVelocity, AIR_DENSITY, AREA_FIN, CD_FIN, normal)
    local tDragFin = finPos:cross(fDragFin)

    localForce = localForce + fLiftFin + fDragFin
    torque = torque + tLiftFin + tDragFin

    --Debug.PosInTransform(self.transform, finPos)
    --Debug.VecInTransform(self.transform, finData[3], normal)
    --Debug.VecInTransform(self.transform, finData[3], fLiftFin)
    --DebugPrint(tLiftFin:length())
  end

  -- Damping
  local tDampingBody = -self.angularVelocity * TORQUE_DAMPING


  -- === Combine forces ===
  force = force + localForce:fromBasis(self.right, self.up, self.forward)

  -- === Integrate (Linear) ===
  local acceleration = force / Missile.MASS
  self.velocity = self.velocity + acceleration * deltaTime
  self.transform.pos = VecAdd(self.transform.pos, self.velocity * deltaTime)

  -- === Integrate (Rotational) ===
  local angularAcceleration = torque / INERTIA
  self.angularVelocity = self.angularVelocity + angularAcceleration * deltaTime

  local angularAxis, angularSpeed = self.angularVelocity:normalize()
  if angularSpeed > Math.EPSILON then
    local angularDeltaDegrees = math.deg(angularSpeed * deltaTime)
    local deltaRotation = QuatAxisAngle(angularAxis, angularDeltaDegrees)

    -- Local space rotation
    self.transform.rot = QuatRotateQuat(self.transform.rot, deltaRotation)
  end

  -- TODO debug
  -- Debug.Vec(self.transform.pos, self.velocity)

  -- === Update body basis ===
  self:_updateBasis()

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

function Missile:destroy()
  if self.isDestroyed then
    return
  end

  -- Delete resources
  Delete(self.entities[1])
  server.DeleteLoop(self.engineLoop)

  self.isDestroyed = true

  -- TODO coupling
  -- TODO callbacks cannot be serialized so I moved the logic here. I could make a global handler function and a table with type, but that's a small mod, so..
  -- Notify owner
  if self.ownerId ~= 0 then
    local player = server.players[self.ownerId]
    if player ~= nil then
      player.isControllingMissile = false
      player.isDetached = false

      server.missileExplodedClientRpc(self.ownerId)
    end
  end
end

function Missile:explode()
  if self.isDestroyed then
    return
  end

  --local explodePoint = TransformToParentPoint(self.transform, Missile.NOSE_OFFSET)
  local explodePoint = self.transform.pos

  SpawnFire(explodePoint)
  Explosion(explodePoint, Missile.EXPLOSION_STRENGTH)
  Explosion(explodePoint, Missile.EXPLOSION_STRENGTH)
  server.PlaySoundClientRpc(0, "explosion", explodePoint, 1.0)

  self:destroy()
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

function Missile:_updateWingsTransform()
  local newLeftWingTransform = Math.RotateTransformAroundPivot(self.wingTransformLeft, self.leftWingPivot, QuatEuler(0, -self.wingsRotation, 0))
  local newRightWingTransform = Math.RotateTransformAroundPivot(self.wingTransformRight, self.rightWingPivot, QuatEuler(0, self.wingsRotation, 0))
  SetShapeLocalTransform(self.leftWing, newLeftWingTransform)
  SetShapeLocalTransform(self.rightWing, newRightWingTransform)
end
