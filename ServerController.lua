#include "Missile.lua"
#include "Player.lua"
#include "ReloadManager.lua"
#include "Settings.lua"

server.missiles = {}
server.players = {}
server.nextMissileId = 1


function server.createMissile()
  local missile = Missile.new()
  local missileId = server.nextMissileId
  server.nextMissileId = server.nextMissileId + 1
  server.missiles[missileId] = missile
  return missile, missileId
end

function server.randomSpawnTransform()
  local margin = Settings.Get("spawnDistance")
  local y = Settings.Get("spawnHeight")
  DebugPrint(y)
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
    server.missiles[missileId] = nil
  end


  -- TODO Investigate
  --- Fov change when changing speed
end

function server.update(deltaTime)
  for missileId, missile in pairs(server.missiles) do
    missile:update(deltaTime)
  end
end

function server.destroy()

end