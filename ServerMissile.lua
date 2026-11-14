#include "Math.lua"
#include "Physics.lua"
#include "SoundManager.lua"
#include "Debug.lua"
#include "MissileModel.lua"


-- TODO missile should not explode from leaves (penetration logic)
-- UPD: it will explode, because API is inconsistent with giving materials. Player's house is clearly made of bricks and game knows that because of sounds. But API returns an empty string ""
-- TODO camera modes: fixed 3st, fixed 1st (nose camera, maybe noise), super epic anime camera (affected by linear/angular velocity delta)


-- ~ TODO move interpolation to client
-- ~ TODO make tick/modelUpdate capped by desired fps (20-60)
-- TODO move offset to the MissileModel. Same stuff as fin offsets that have direct relation to the... to the flight model, gotcha! we can change offsets arbitrary, but this has to remain visual
-- TODO rescale nozzle_offset and others by scale ( / scale) and multiply by scale everywhere


ServerMissile = {}
ServerMissile.__index = ServerMissile

ServerMissile.EXPLOSION_STRENGTH = 4.0
ServerMissile.NOSE_OFFSET = Vec3.new(0, 0, -2.5)
ServerMissile.NOZZLE_OFFSET = Vec3.new(0, 0, 3.0)
ServerMissile.CAMERA_OFFSET = Vec3.new(0, 1, 6.0)

ServerMissile.DETONATION_TIME = 0.15

function ServerMissile.new()
  local obj = {}
  obj.__type = "ServerMissile"

  -- Model
  obj.scale = 0.45 -- TODO what to do with the scale? I cannot get scale on server without spawning the object. keep in sync with xml file
  obj.model = MissileModel.new(obj.scale)

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

  -- Destroyed
  obj.isDestroyed = false
  obj.ownerId = 0

  -- Explosion
  obj.isArmed = false
  obj.shouldDetonate = false
  obj.detonationPos = nil -- Vec3
  obj.detonationTimer = 0.0

  return setmetatable(obj, ServerMissile)
end

function ServerMissile:spawn(transform)
  -- Not reusable
  if self.isDestroyed then
    return
  end

  -- Update transform and basis
  transform = transform or Transform()
  self.model:setTransform(transform)

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

  -- Effects
  self.engineLoop = server.CreateLoop("engine", self.model.transform.pos, 0, false, 1.0)
end

function ServerMissile:tick(deltaTime)
  if self.isDestroyed then
    return
  end


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
    return
  end


  -- === Update model ===
  self.model:update(deltaTime)


  -- === Update transforms and visuals ===
  SetBodyTransform(self.entities[1], self.model.transform)
  self:_updateWingsTransform()
  self:_updateFinsTransform()
  self:_updateParticles(deltaTime)
  self:_updateSounds()


  ---- === Draw debug axes ===
  --Debug.VecInTransform(self.model.transform, self.model.finPivotPosTL, self.model.finPivotDirTL)
  --Debug.VecInTransform(self.model.transform, self.model.finPivotPosTR, self.model.finPivotDirTR)
  --Debug.VecInTransform(self.model.transform, self.model.finPivotPosBL, self.model.finPivotDirBL)
  --Debug.VecInTransform(self.model.transform, self.model.finPivotPosBR, self.model.finPivotDirBR)
end

function ServerMissile:_checkDetonation(deltaTime)
  local checkPos = self.model.transform.pos
  local checkDir, speed = self.model.velocity:normalize()
  local checkDist = 1.0 + speed * deltaTime
  local radius = 30 * Math.VOXEL_SIZE * self.scale

  QueryRejectBody(self.entities[1])
  local hit, dist, normal, shape = QueryRaycast(checkPos, checkDir, checkDist)

  if hit then
    local hitPos = VecAdd(checkPos, VecScale(checkDir, dist))
    local hasUnbreakableTag = HasTag(shape, "unbreakable")
    if hasUnbreakableTag then
      self.shouldDetonate = true
      self.detonationPos = hitPos
      return
    end

    MakeHole(hitPos, radius, radius, radius)

    -- If timer mode enabled and required penetration accumulated - start timer
    if not self.isArmed then
      self.isArmed = true
    end
  end
end

function ServerMissile:spreadWings()
  if (self.model.wingsState == MissileModel.WingsState.SPREAD) then
    return
  end

  self.model:spreadWings()

  server.PlaySoundClientRpc(0, "wings", self.model.transform.pos)
end

function ServerMissile:foldWings()
  if (self.model.wingsState == MissileModel.WingsState.FOLDED) then
    return
  end

  self.model:foldWings()
end

function ServerMissile:destroy()
  if self.isDestroyed then
    return
  end

  -- Delete resources
  Delete(self.entities[1])
  server.DeleteLoop(self.engineLoop)

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

  self.isDestroyed = true
end

function ServerMissile:explode()
  if self.isDestroyed then
    return
  end

  --local explodePoint = TransformToParentPoint(self.model.transform, Missile.NOSE_OFFSET)
  local explodePoint = self.detonationPos
  if explodePoint == nil then
    explodePoint = self.model.transform.pos
  end

  SpawnFire(explodePoint)
  Explosion(explodePoint, ServerMissile.EXPLOSION_STRENGTH)
  Explosion(explodePoint, ServerMissile.EXPLOSION_STRENGTH)
  server.PlaySoundClientRpc(0, "explosion", explodePoint, 1.0)

  self:destroy()
end

function ServerMissile:_updateWingsTransform()
  local newLeftWingTransform = Math.RotateTransformAroundPivot(self.wingTransformLeft, self.leftWingPivot, QuatEuler(0, -self.model.wingsRotation, 0))
  local newRightWingTransform = Math.RotateTransformAroundPivot(self.wingTransformRight, self.rightWingPivot, QuatEuler(0, self.model.wingsRotation, 0))
  SetShapeLocalTransform(self.leftWing, newLeftWingTransform)
  SetShapeLocalTransform(self.rightWing, newRightWingTransform)
end

function ServerMissile:_updateFinsTransform()
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

function ServerMissile:_updateParticles(deltaTime)
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

function ServerMissile:_updateSounds()
  shared.soundLoops[self.engineLoop].pos = self.model.transform.pos
  shared.soundLoops[self.engineLoop].volume = self.model.propulsion
end
