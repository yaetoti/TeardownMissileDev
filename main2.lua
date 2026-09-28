#version 2
#include "Missile.lua"
#include "SoundManager.lua"

local time = 0
local ToolTabletId = "tablet"

-- Client

function client.init()
  SoundManager:Init()
end

function client.tick(deltaTime)
  if InputPressed("lmb") and GetPlayerTool() == ToolTabletId then
    DebugPrint("Hello, world!")
  end
end

-- Server

function server.init()
  -- Register tools
  RegisterTool(ToolTabletId, "Tablet", "MOD/vox/Tablet.vox", 4)

  -- Spawn missiles
  missiles = {}
  for j = 1, 10 do -- 10
    for i = 1, 20 do -- 20
      local missile = Missile:new()
      missile:spawn(Transform(Vec(-45 + i * 4, 2, -25 + j * 10), QuatEuler(0, 180, 0)))
      table.insert(missiles, missile)
    end
  end

  -- Spawn prototype missile
  missile = Missile:new()
  --missile:spawn(Transform(Vec(3, 2, 6)))
  DebugPrint(missile)

  -- Spawn old missile
  --rocketProjectile = Spawn("MOD/vox/rocket.xml", Transform(Vec(-5, 3, 10)))
end

function server.tick(deltaTime)
  -- Update time
  time = time + deltaTime

  -- Init connected players
  for _, playerId in ipairs(GetAddedPlayers()) do
    -- Enable tools
    SetToolEnabled(ToolTabletId, true, playerId)
  end

  -- Controls
  if InputPressed("q") then
    for _, m in ipairs(missiles) do
      m:foldWings()
    end
  end

  if InputPressed("e") then
    for _, m in ipairs(missiles) do
      m:spreadWings()
    end
  end

  -- Update missiles
  for _, m in ipairs(missiles) do
    m:update(deltaTime)
  end
end

function server.destroy()

end