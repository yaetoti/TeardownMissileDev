#include "ServerMissile.lua"
#include "Player.lua"
#include "ReloadManager.lua"
#include "Settings.lua"

MISSILE_UPDATE_DT = 1 / 144

server.players = {}
server.missiles = {}
server.nextMissileId = 1
server.missileUpdateTimer = 0.0

shared.models = {}
shared.timestamp = 0



---@param missile ServerMissile
---@return number missile ID
function server.addMissile(missile)
  local missileId = server.nextMissileId
  server.nextMissileId = server.nextMissileId + 1

  server.missiles[missileId] = missile
  shared.models[missileId] = Utils.deepCopy(missile.model)
  shared.timestamp = GetTime()

  return missileId
end

---@param missileId number
function server.removeMissile(missileId)
  server.missiles[missileId] = nil
  shared.models[missileId] = nil
  shared.timestamp = GetTime()
end

function server.syncModels()
  local snapshot = {}
  for missileId, missile in pairs(server.missiles) do
    if not missile.isDestroyed then
      snapshot[missileId] = Utils.deepCopy(missile.model)
    end
  end

  shared.models = snapshot
  shared.timestamp = GetTime()
end



function server.randomSpawnTransform()
  local margin = Settings.Get("spawnDistance")
  local y = Settings.Get("spawnHeight")

  local aabbMin, aabbMax = GetBoundaryBounds()
  aabbMin = VecSub(aabbMin, Vec(margin, 0, margin))
  aabbMax = VecAdd(aabbMax, Vec(margin, 0, margin))

  local isClampedX = GetRandomBool()

  local xBool = GetRandomInt(0, 1)
  local x = Math.lerp(aabbMin[1], aabbMax[1], xBool)
  local zBool = GetRandomInt(0, 1)
  local z = Math.lerp(aabbMin[3], aabbMax[3], zBool)

  if isClampedX then
    z = GetRandomFloat(aabbMin[3], aabbMax[3])
  else
    x = GetRandomFloat(aabbMin[1], aabbMax[1])
  end

  local pos = Vec(x, y, z)
  local rot = QuatLookAt(pos, Vec(0, y, 0))
  return Transform(pos, rot)
end


function server.init()
  Settings.init()
  ReloadManager.markLoaded()

  -- Register tools
  RegisterTool(ToolTabletId, "Tablet", "MOD/vox/Tablet.vox", 4)
end

function server.tick(deltaTime)
  if ReloadManager.isReload() then
    ReloadManager.initRegistry()
    Settings.init()
    ReloadManager.reload()
    ReloadManager.markLoaded()
  end

  -- Timers
  server.missileUpdateTimer = server.missileUpdateTimer + deltaTime

  -- Init connected players
  for _, playerId in ipairs(GetAddedPlayers()) do
    server.players[playerId] = Player.new()

    -- Enable tools
    SetToolEnabled(ToolTabletId, true, playerId)
  end

  -- Destroy removed players
  for _, playerId in ipairs(GetRemovedPlayers()) do
    local player = server.players[playerId]
    if player.isControllingMissile then
      local missile = server.missiles[player.controlledMissileId]
      missile:explode()
    end

    server.players[playerId] = nil
  end

  -- Update events
  do
    local eventCount = GetEventCount("playerdied")
    for i = 1, eventCount do
      local playerId = GetEvent("playerdied", i)
      local player = server.players[playerId]
      if player.isControllingMissile then
        -- Destroy missiles of dead players
        local missile = server.missiles[player.controlledMissileId]
        missile:explode()
      end
    end
  end

  -- Update players
  for playerId, player in pairs(server.players) do
    if player.isControllingMissile and not player.isDetached then
      if not debugMissile then
        DisablePlayerInput(playerId)
      end
    end
  end

  -- Update missiles
  local markedForDestruction = {}
  for missileId, missile in pairs(server.missiles) do
    missile:tick(deltaTime)

    if missile.isDestroyed then
      table.insert(markedForDestruction, missileId)
    end
  end

  -- Remove marked missiles
  for _, missileId in ipairs(markedForDestruction) do
    server.removeMissile(missileId)
  end

  -- Update physics and sync
  if server.missileUpdateTimer >= MISSILE_UPDATE_DT then
    local updateDeltaTime = math.max(server.missileUpdateTimer, MISSILE_UPDATE_DT)
    server.missileUpdateTimer = 0.0

    for missileId, missile in pairs(server.missiles) do
      missile:update(updateDeltaTime)
    end

    -- Sync models
    server.syncModels()
  end
end

function server.destroy()

end