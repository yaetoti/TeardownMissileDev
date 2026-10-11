#version 2
#include "ClientController.lua"
#include "ServerController.lua"
#include "RPC.lua"
#include "Missile.lua"
#include "Player.lua"

-- TODO remove
debugMissile = false
debugDetach = false
debugFreeCamera = false

time = 0
ToolTabletId = "tablet"

server.missiles = {}
server.players = {}
server.nextMissileId = 1

function server.createMissile()
  local missile =  Missile.new()
  local missileId = server.nextMissileId
  server.nextMissileId = server.nextMissileId + 1
  server.missiles[missileId] = missile
  return missile, missileId
end


-- Client

-- How much missiles can we create at once? One.

--Inside game
-- [create missile and control it]
-- [control the launched missile again]
-- [blow up the launched missile]

--Inside missile
-- [leave missile]
-- [blow up missile]
-- [input]

-- Client wants to [create missile and control it]
-- Server checks if client can. If so, state changes on server and we notify player



-- Playing
-- ControllingMissile

-- Server

function server.init()
  -- Register tools
  RegisterTool(ToolTabletId, "Tablet", "MOD/vox/Tablet.vox", 4)
end

function server.tick(deltaTime)
  -- Update time
  time = time + deltaTime

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
    if player.isControllingMissile then
      if not debugMissile then
        DisablePlayerInput(playerId)
      end
    end
  end

  -- Update missiles
  local markedForDestruction = {}
  for missileId, missile in pairs(server.missiles) do
    missile:update(deltaTime)
    if missile.exploded then
      table.insert(markedForDestruction, missileId)
    end
  end

  -- Remove marked missiles
  for _, missileId in ipairs(markedForDestruction) do
    server.missiles[missileId] = nil
  end


  -- TODO Investigate
  --- Missile Falling
  --- Nose down
  --- Fov change when changing speed
end

function server.destroy()

end



