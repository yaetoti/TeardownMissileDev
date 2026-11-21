#include "Math.lua"
#include "Physics.lua"
#include "Debug.lua"



-- This is a missile model class that is responsible for storing the simulation data and performing physics updates
-- It accepts player input and produces new transform and velocities
-- It does not handle detonation, destruction, sounds or the visual part
-- It's only purpose it to be a reusable flight model that can be used on both the server and the client (for prediction)
-- Missile is facing in the -Z direction (LOG: Tried +Z, but it's easier to remember that forward is at negative direction, than that right is left. Camera is also looking at -Z, so with +Z I'd have to invert the body transform)

MissileModel = {}
MissileModel.__index = MissileModel

MissileModel.WingsState = {
  FOLDED = 1,
  SPREAD = 2,
  FOLDING = 3,
  SPREADING = 4,
}

MissileModel.WINGS_SPREADING_TIME = 0.25
MissileModel.WINGS_FOLDING_TIME = 0.6
MissileModel.WINGS_FOLDED_ROTATION = 0
MissileModel.WINGS_SPREAD_ROTATION = 40

MissileModel.MASS = 800
MissileModel.FIN_PIVOT_SIZE = 0.3
MissileModel.FIN_MAX_ANGLE = 25.0
MissileModel.FIN_ROTATION_SPEED = 360.0

MissileModel.PROPULSION_CHANGE_SPEED = 0.5

---@param scale number? Model scale (same as in xml). Default 1.0
---@return MissileModel
function MissileModel.new(scale)
  scale = scale or 1.0

  local obj = {}
  obj.__type = "MissileModel"

  -- Model scale TODO ensure scale works properly everywhere
  obj.scale = scale

  -- Input
  obj.pitchInput = 0.0
  obj.yawInput = 0.0
  obj.rollInput = 0.0
  obj.propulsionInput = 0.0

  -- Transform
  obj.transform = Transform()
  obj.right = Math.RIGHT
  obj.up = Math.UP
  obj.forward = Math.FORWARD

  -- Physics
  obj.velocity = Vec3.new()
  obj.angularVelocity = Vec3.new()
  obj.propulsion = 0.0

  -- Wings state
  obj.wingsRotation = MissileModel.WINGS_FOLDED_ROTATION
  obj.wingsTargetRotation = MissileModel.WINGS_FOLDED_ROTATION
  obj.wingsStateProgress = 1
  obj.wingsSpreading = 0
  obj.wingsState = MissileModel.WingsState.FOLDED

  -- Fins state
  obj.finAngleTL = 0.0
  obj.finAngleTR = 0.0
  obj.finAngleBL = 0.0
  obj.finAngleBR = 0.0

  obj.finAngleTargetTL = 0.0
  obj.finAngleTargetTR = 0.0
  obj.finAngleTargetBL = 0.0
  obj.finAngleTargetBR = 0.0

  -- Calculate fins offset
  local finsOffsetX = 9 * Math.VOXEL_SIZE * scale
  local finsOffsetY = 6 * Math.VOXEL_SIZE * scale
  local finsOffsetZ = 41.5 * Math.VOXEL_SIZE * scale

  -- Calculate fins axes (in body space)
  obj.finPivotPosTL = Vec3.new(-finsOffsetX, finsOffsetY, finsOffsetZ)
  obj.finPivotPosTR = Vec3.new(finsOffsetX, finsOffsetY, finsOffsetZ)
  obj.finPivotPosBL = Vec3.new(-finsOffsetX, -finsOffsetY, finsOffsetZ)
  obj.finPivotPosBR = Vec3.new(finsOffsetX, -finsOffsetY, finsOffsetZ)

  obj.finPivotDirTL = Math.UP:rotateAround(Math.FORWARD, -math.rad(45))
  obj.finPivotDirTR = Math.UP:rotateAround(Math.FORWARD, math.rad(45))
  obj.finPivotDirBL = Math.UP:rotateAround(Math.FORWARD, -math.rad(135))
  obj.finPivotDirBR = Math.UP:rotateAround(Math.FORWARD, math.rad(135))

  return setmetatable(obj, MissileModel)
end


-- === Public methods ===

---@param pitch number Pitch [0; 1]
---@param yaw number Yaw [0; 1]
---@param roll number Roll [0; 1]
---@param propulsion number Propulsion [0; 1]
function MissileModel:setInput(pitch, yaw, roll, propulsion)
  self.pitchInput = pitch
  self.yawInput = yaw
  self.rollInput = roll
  self.propulsionInput = propulsion
end

---@param transform Transform
function MissileModel:setTransform(transform)
  self.transform = transform
  self:_updateBasis()
end

function MissileModel:spreadWings()
  if (self.wingsState == MissileModel.WingsState.SPREAD) then
    return
  end

  self.wingsStateProgress = 1 - self.wingsStateProgress
  self.wingsState = MissileModel.WingsState.SPREADING
end

function MissileModel:foldWings()
  if (self.wingsState == MissileModel.WingsState.FOLDED) then
    return
  end

  self.wingsStateProgress = 1 - self.wingsStateProgress
  self.wingsState = MissileModel.WingsState.FOLDING
end

function MissileModel:update(deltaTime)
  -- === Update propulsion ===
  self.propulsion = Math.moveTowards(self.propulsion, self.propulsionInput, MissileModel.PROPULSION_CHANGE_SPEED * deltaTime)

  self:_updateWingsSpreading(deltaTime)
  self:_updateFins(deltaTime)
  self:_updateMovement(deltaTime)
end


-- === Private methods ===

function MissileModel:_updateBasis()
  self.right = Math.RIGHT:rotate(self.transform.rot)
  self.up = Math.UP:rotate(self.transform.rot)
  self.forward = Math.FORWARD:rotate(self.transform.rot)
end

function MissileModel:_updateWingsSpreading(deltaTime)
  -- Update wings spreading
  if self.wingsState == MissileModel.WingsState.SPREADING then
  -- Spreading
    self.wingsStateProgress = self.wingsStateProgress + deltaTime / MissileModel.WINGS_SPREADING_TIME

    -- Finish spreading
    if self.wingsStateProgress >= 1 then
      self.wingsStateProgress = 1
      self.wingsSpreading = 1
      self.wingsState = MissileModel.WingsState.SPREAD
    else
    -- Apply easing here
      self.wingsSpreading = Math.easeOutElastic(self.wingsStateProgress)
    end

    -- Update rotation
    self.wingsRotation = Math.lerp(MissileModel.WINGS_FOLDED_ROTATION, MissileModel.WINGS_SPREAD_ROTATION, self.wingsSpreading)
  elseif self.wingsState == MissileModel.WingsState.FOLDING then
  -- Folding
    self.wingsStateProgress = self.wingsStateProgress + deltaTime / MissileModel.WINGS_FOLDING_TIME

    -- Finish folding
    if self.wingsStateProgress >= 1 then
      self.wingsStateProgress = 1
      self.wingsSpreading = 0
      self.wingsState = MissileModel.WingsState.FOLDED
    else
    -- Apply easing here
      self.wingsSpreading = 1 - self.wingsStateProgress
    end

    -- Update rotation
    self.wingsRotation = Math.lerp(MissileModel.WINGS_FOLDED_ROTATION, MissileModel.WINGS_SPREAD_ROTATION, self.wingsSpreading)
  end
end

function MissileModel:_updateFins(deltaTime)
  local pitch = self.pitchInput
  local yaw = -self.yawInput
  local roll = self.rollInput

  --local xyLength = math.sqrt(pitch * pitch + yaw * yaw)
  --pitch = pitch / xyLength
  --yaw = yaw / xyLength

  local s = 1.0
  self.finAngleTargetTL = Math.clamp(roll + s * (pitch + yaw), -1, 1) * MissileModel.FIN_MAX_ANGLE
  self.finAngleTargetTR = Math.clamp(roll + s * (-pitch + yaw), -1, 1) * MissileModel.FIN_MAX_ANGLE
  self.finAngleTargetBL = Math.clamp(roll + s * (pitch - yaw), -1, 1) * MissileModel.FIN_MAX_ANGLE
  self.finAngleTargetBR = Math.clamp(roll + s * (-pitch - yaw), -1, 1) * MissileModel.FIN_MAX_ANGLE

  self.finAngleTL = Math.moveTowards(self.finAngleTL, self.finAngleTargetTL, MissileModel.FIN_ROTATION_SPEED * deltaTime)
  self.finAngleTR = Math.moveTowards(self.finAngleTR, self.finAngleTargetTR, MissileModel.FIN_ROTATION_SPEED * deltaTime)
  self.finAngleBL = Math.moveTowards(self.finAngleBL, self.finAngleTargetBL, MissileModel.FIN_ROTATION_SPEED * deltaTime)
  self.finAngleBR = Math.moveTowards(self.finAngleBR, self.finAngleTargetBR, MissileModel.FIN_ROTATION_SPEED * deltaTime)
end

function MissileModel:_updateMovement(deltaTime)
  local cInertia = 500 * 2
  local cDamping = 50 * 4
  local cThrust = 2
  local cLift = 1
  local cDragWings = 1

  -- Parameters
  local THRUST = 8000 * cThrust
  local AIR_DENSITY = 1.22 -- TODO min max

  local WINGS_POS = Vec3.new(0, 0, 0)
  local WINGS_SIZE = 30 * Math.VOXEL_SIZE * self.scale

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
  local localVelocityVec = self.velocity:toTransformVec(self.transform)
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
  local fGravity = Vec3.from(GetGravity()) * MissileModel.MASS
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

  -- TODO induced drag?

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
    local finPos = finData[3] + finData[1] * MissileModel.FIN_PIVOT_SIZE
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
  torque = torque + tDampingBody


  -- === Combine forces ===
  force = force + localForce:fromTransformVec(self.transform)

  -- === Integrate (Linear) ===
  local acceleration = force / MissileModel.MASS
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


  -- === Update basis ===
  self:_updateBasis()
end
