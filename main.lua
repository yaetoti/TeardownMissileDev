#version 2
#include "Missile.lua"
#include "SoundManager.lua"
#include "Player.lua"

local time = 0
local ToolTabletId = "tablet"

client.activeRequests = {
  createMissile = false,
  explodeMissile = false,
}

client.isControllingMissile = false
client.missileId = 0
client.missileBody = 0

server.missiles = {}
server.players = {}
server.nextMissileId = 1

function server.createMissile()
  local missile =  Missile:new()
  local missileId = server.nextMissileId
  server.nextMissileId = server.nextMissileId + 1
  server.missiles[missileId] = missile
  return missile, missileId
end



function client.createMissileServerRpc()
  if client.activeRequests.createMissile or client.isControllingMissile then
    return
  end

  client.activeRequests.createMissile = true
  ServerCall("server.createMissileServerRpc", GetLocalPlayer())
  -- TODO remove debug message
  DebugPrint("Request sent")
end

function server.createMissileServerRpc(clientId)
  DebugPrint("Request got")
  local player = server.players[clientId]
  if not player or player.isControllingMissile then
    -- Reject
    DebugPrint("Rejected")
    server.createMissileResponseClientRpc(clientId, false)
    return
  end

  -- Create missile
  local missile, missileId = server.createMissile()
  missile:spawn(Transform(Vec(0, 2, missileId * 6)))

  -- Update status
  player.isControllingMissile = true
  player.controlledMissileId = missileId

  -- Send confirmation and body
  DebugPrint("Created")
  server.createMissileResponseClientRpc(clientId, true, missileId, missile.entities[1])
end

function server.createMissileResponseClientRpc(clientId, approval, missileId, missileBody)
  ClientCall(clientId, "client.createMissileResponseClientRpc", approval, missileId, missileBody)
end

function client.createMissileResponseClientRpc(approval, missileId, missileBody)
  client.activeRequests.createMissile = false

  if not approval then
    return
  end

  client.isControllingMissile = true
  client.missileId = missileId
  client.missileBody = missileBody

  -- TODO how to detect that body is already destroyed?
end

-- TODO remove exploded rockets


function client.explodeMissileServerRpc(missileId)
  if not client.isControllingMissile or client.activeRequests.explodeMissile then
    return
  end

  ServerCall("server.explodeMissileServerRpc", GetLocalPlayer(), missileId)
end

function server.explodeMissileServerRpc(clientId, missileId)
  local player = server.players[clientId]
  if not player.isControllingMissile or player.controlledMissileId ~= missileId then
    -- Reject
    server.explodeMissileResponseClientRpc(clientId, false)
    return
  end

  local missile = server.missiles[missileId]
  missile:explode()

  player.isControllingMissile = false

  -- Approve
  server.explodeMissileResponseClientRpc(clientId, true)
end

function server.explodeMissileResponseClientRpc(clientId, approval)
  ClientCall(clientId, "client.explodeMissileResponseClientRpc", approval)
end

function client.explodeMissileResponseClientRpc(approval)
  client.activeRequests.explodeMissile = false
  if not approval then
    return
  end

  client.isControllingMissile = false
end



-- Client

function client.init()
  SoundManager:Init()
end

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

function client.tick(deltaTime)
  if InputPressed("lmb") and GetPlayerTool() == ToolTabletId then
    -- Create missile
    if not client.isControllingMissile and not client.activeRequests.createMissile then
      client.createMissileServerRpc()
    end

    -- Explode missile
    if client.isControllingMissile and not client.activeRequests.explodeMissile then
      client.explodeMissileServerRpc(client.missileId)
    end
  end
end

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
    server.players[playerId] = Player:new()

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
end

function server.destroy()

end



