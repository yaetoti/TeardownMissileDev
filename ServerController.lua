#include "Missile.lua"
#include "Player.lua"
#include "ReloadManager.lua"

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

function server.init()
  ReloadManager.markLoaded()

  -- Register tools
  RegisterTool(ToolTabletId, "Tablet", "MOD/vox/Tablet.vox", 4)
end

function server.tick(deltaTime)
  if ReloadManager.isReload() then
    ReloadManager.initRegistry()
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
    missile:update(deltaTime)
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

function server.destroy()

end