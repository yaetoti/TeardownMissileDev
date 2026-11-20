#include "Utils.lua"
#include "Math.lua"
#include "Debug.lua"
#include "MissileModel.lua"

ClientMissile = {}
ClientMissile.__index = ClientMissile

-- Old model
-- Server spawns bodies
-- Server passes only body id only to the corresponding client
-- Updates are propagated by game api SetBodyTransform from the server. Clients don't store missile model
-- Updates are happening in server:update(), which updates physics. server interpolated position in server.tick() and user SetBodyTransform again

-- New model
-- Server creates missile models for players and stores them in shared
-- Client creates ClientMissile wrapper for every new model
-- - Creates the actual body and sets its transform
-- - Updates local model simulation using own deltaTime
-- - Replaces model with the new one from server when updated (track local time?)

-- Non-host lag sources:
-- - Low update() tickrate (but server interpolation didn't change shit)
-- - Low bandwidth (but smoke runs properly. input lags though)

-- Moving to shared may fix network issues depending on how it's prioritized
-- Moving server updates to tick may fix tickrate issues
-- Adding client interpolation fixes reliance on network SetBodyTransform: if issue was prioritization


-- TODO smart
-- Why not update issue? Because tick() interpolation would have helped
-- But interpolation also uses SetBodyTransform. What if it's updated in update()?
-- But friend's client wasn't lagging visually. Maybe only updates. Maybe network latency
-- Not latency because smoke is delivered on time

-- Then it means that clients should spawn bodies themselves


-- TODO test with network lag utility



-- Plan
-- + Add facade addition/removal
-- - Add facades updates
-- - Add facade code

function ClientMissile.new(model)
  local obj = {}
  obj.__type = "ClientMissile"

  -- Model
  obj.model = model
  obj.scale = ServerMissile.SCALE

  -- Entities
  obj.entities = {}

  -- Wings visual data
  obj.leftWing = nil
  obj.rightWing = nil
  obj.wingTransformLeft = nil
  obj.wingTransformRight = nil
  obj.wingsOffsetY = 0.0

  -- Fins visual data
  obj.finTL = nil
  obj.finTR = nil
  obj.finBL = nil
  obj.finBR = nil
  obj.finTransformTL = nil
  obj.finTransformTR = nil
  obj.finTransformBL = nil
  obj.finTransformBR = nil

  -- Effects
  obj.smokeTimer = 0.0

  -- Interpolation
  obj.positionOffsetInterp = Vec3.new()

  return setmetatable(obj, ClientMissile)
end

function ClientMissile:spawn()
  -- Spawn entities
  self.entities = Spawn("MOD/vox/Missile.xml", self.model.transform)

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
  self.wingsOffsetY = -2.5 * Math.VOXEL_SIZE * self.scale

  -- Move wings to their place
  self.wingTransformLeft.pos = VecAdd(self.wingTransformLeft.pos, Vec(0, self.wingsOffsetY, 0))
  self.wingTransformRight.pos = VecAdd(self.wingTransformRight.pos, Vec(0, self.wingsOffsetY, 0))
  SetShapeLocalTransform(self.leftWing, self.wingTransformLeft)
  SetShapeLocalTransform(self.rightWing, self.wingTransformRight)

  -- Calculate wings pivot (+3 voxels from wing base)
  self.leftWingPivot = Vec(-0.5 * leftWingSizeX * Math.VOXEL_SIZE * self.scale, 0, -10 * Math.VOXEL_SIZE * self.scale)
  self.rightWingPivot = Vec(0.5 * rightWingSizeX * Math.VOXEL_SIZE * self.scale, 0, -10 * Math.VOXEL_SIZE * self.scale)
end

function ClientMissile:destroy()
  Delete(self.entities[1])
end

--- Call this after receiving a new model from shared
function ClientMissile:updateModel(model)
  -- Interpolation settings should be initialized here

  self.prevPositionInterp = Vec3.from(self.model.transform.pos)
  self.nextPositionInterp = Vec3.from(model.transform.pos)
  self.positionOffsetInterp = self.prevPositionInterp - self.nextPositionInterp

  -- Update model
  self.model = model
end

function ClientMissile:tick(deltaTime)
  -- TODO fix fucked up spawn (rotation + location)

--  local startTime = client.localTimestemp
--  local currentTime = GetTime()
--  local dtInterp = currentTime - startTime

  --self.model:update(deltaTime)

  -- === Update transforms ===
  local transform = TransformCopy(self.model.transform)

  local usedOffset = self.positionOffsetInterp * 0.3
  self.positionOffsetInterp = self.positionOffsetInterp - usedOffset
  --transform.position = VecAdd(transform.position, usedOffset)

  SetBodyTransform(self.entities[1], transform)
  --SetBodyTransform(self.entities[1], self.model.transform)

  -- === Update visuals ===
  self:_updateWingsTransform()
  self:_updateFinsTransform()
  self:_updateParticles(deltaTime)
end

function ClientMissile:_updateWingsTransform()
  local newLeftWingTransform = Math.RotateTransformAroundPivot(self.wingTransformLeft, self.leftWingPivot, QuatEuler(0, -self.model.wingsRotation, 0))
  local newRightWingTransform = Math.RotateTransformAroundPivot(self.wingTransformRight, self.rightWingPivot, QuatEuler(0, self.model.wingsRotation, 0))
  SetShapeLocalTransform(self.leftWing, newLeftWingTransform)
  SetShapeLocalTransform(self.rightWing, newRightWingTransform)
end

function ClientMissile:_updateFinsTransform()
-- TODO unwrap
  local finsData = {
    { self.finTL, self.finTransformTL, self.model.finPivotDirTL, self.model.finPivotPosTL, self.model.finAngleTL },
    { self.finTR, self.finTransformTR, self.model.finPivotDirTR, self.model.finPivotPosTR, self.model.finAngleTR },
    { self.finBL, self.finTransformBL, self.model.finPivotDirBL, self.model.finPivotPosBL, self.model.finAngleBL },
    { self.finBR, self.finTransformBR, self.model.finPivotDirBR, self.model.finPivotPosBR, self.model.finAngleBR },
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
end

function ClientMissile:_updateParticles(deltaTime)
  if self.model.propulsion > Math.EPSILON then
    self.smokeTimer = self.smokeTimer + deltaTime
    if self.smokeTimer > 0.02 * (1.1 - self.model.propulsion) then
      self.smokeTimer = 0.0

      local velocity = -self.model.forward * math.max(self.model.forward:dot(self.model.velocity), 10)

      ParticleType("plain")
      ParticleRadius(self.model.propulsion * 0.15 + 0.1, 1.0)
      ParticleDrag(0.1)
      SpawnParticle(ServerMissile.NOZZLE_OFFSET:fromTransformPos(self.model.transform), velocity, 2)
    end
  end
end
