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


-- TODO fix lags during drops (and laggy feeling overall)

ServerMissile = {}
ServerMissile.__index = ServerMissile

ServerMissile.SCALE = 0.45

ServerMissile.EXPLOSION_STRENGTH = 4.0
ServerMissile.NOSE_OFFSET = Vec3.new(0, 0, -2.5)
ServerMissile.NOZZLE_OFFSET = Vec3.new(0, 0, 3.0)
ServerMissile.CAMERA_OFFSET = Vec3.new(0, 1, 6.0)

ServerMissile.DETONATION_TIME = 0.15

function ServerMissile.new()
  local obj = {}
  obj.__type = "ServerMissile"

  -- Model
  obj.scale = ServerMissile.SCALE -- TODO what to do with the scale? I cannot get scale on server without spawning the object. keep in sync with xml file
  obj.model = MissileModel.new(obj.scale)

  -- Sounds
  obj.engineLoop = nil

  -- Destroyed
  obj.isDestroyed = false
  obj.ownerId = 0

  -- Explosion
  obj.isArmed = false
  obj.shouldDetonate = false
  obj.detonationPos = nil -- Vec3
  obj.detonationTimer = 0.0

  -- Effects
  obj.engineLoop = server.CreateLoop("engine", obj.model.transform.pos, 0, false, 1.0)

  return setmetatable(obj, ServerMissile)
end

function ServerMissile:setTransform(transform)
  self.model:setTransform(transform)
  shared.soundLoops[self.engineLoop].pos = self.model.transform.pos
end

function ServerMissile:tick(deltaTime)
  if self.isDestroyed then
    return
  end


  --- === Handle detonation ===
  -- TODO enable
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


  -- === Update transforms and visuals ===
  self:_updateSounds()


  ---- === Draw debug axes ===
  --Debug.VecInTransform(self.model.transform, self.model.finPivotPosTL, self.model.finPivotDirTL)
  --Debug.VecInTransform(self.model.transform, self.model.finPivotPosTR, self.model.finPivotDirTR)
  --Debug.VecInTransform(self.model.transform, self.model.finPivotPosBL, self.model.finPivotDirBL)
  --Debug.VecInTransform(self.model.transform, self.model.finPivotPosBR, self.model.finPivotDirBR)
end

function ServerMissile:update(deltaTime)
  if self.isDestroyed then
    return
  end

  -- TODO this is ok, but have to figure out how to update raycast then

  -- === Update model ===
  self.model:update(deltaTime)
end

function ServerMissile:_checkDetonation(deltaTime)
  local checkPos = self.model.transform.pos
  local checkDir, speed = self.model.velocity:normalize()
  local checkDist = 1.0 + speed * deltaTime
  local radius = 30 * Math.VOXEL_SIZE * self.scale

  -- Client-side object are very server-side when it comes to raycast -_-
  QueryRequire("physical")
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

function ServerMissile:_updateSounds()
  shared.soundLoops[self.engineLoop].pos = self.model.transform.pos
  shared.soundLoops[self.engineLoop].volume = self.model.propulsion
end
