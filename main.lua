#version 2
#include "Missile.lua"

local time = 0
local ToolTabletId = "tablet"
local WING_SPREAD_TIME = 0.15
local WING_FOLD_TIME = 0.6

-- Client

function client.init()

end

function client.tick(deltaTime)
  --DebugPrint("Hello, world!")
end



-- Server

function server.init()
  -- Register tools
  RegisterTool(ToolTabletId, "Tablet", "MOD/vox/Tablet.vox", 4)

  missiles = {}
  for i = 1, 20 do
    local missile = Missile:new()
    missile:spawn(Transform(Vec(0 + i * 4, 2, 20)))
    table.insert(missiles, missile)
  end

  missile = Missile:new()
  missile:spawn(Transform(Vec(3, 5, 6)))
  DebugPrint(missile)

  rocketProjectile = Spawn("MOD/vox/rocket.xml", Transform(Vec(0, 3, 4)))
  rocketProjectile2 = Spawn("MOD/vox/Missile.xml", Transform(Vec(0, 2, 0)))

  leftWing = rocketProjectile2[8]
  rightWing = rocketProjectile2[7]

  leftTransform = GetShapeLocalTransform(leftWing)
  rightTransform = GetShapeLocalTransform(rightWing)
  leftSizeX, leftSizeY, leftSizeZ, leftScale = GetShapeSize(leftWing)
  rightSizeX, rightSizeY, rightSizeZ, rightScale = GetShapeSize(rightWing)

  rotation = 0
  wingsState = "FOLDED"
  progress = 0
  targetRotation = 0
end

function RotateAround(tr, pivot, rot)
  local relative = VecSub(tr.pos, pivot)
  local newPos = VecAdd(pivot, QuatRotateVec(rot, relative))
  local newRot = QuatRotateQuat(rot, tr.rot)
  return Transform(newPos, newRot)
end

function server.tick(deltaTime)
  time = time + deltaTime
  SetBodyTransform(rocketProjectile[1], Transform(Vec(-5 + math.sin(time) * 0, 3, 10)))
  --SetBodyTransform(rocketProjectile2[1], Transform(Vec(3 + math.sin(time), 2, 0)))
  SetBodyTransform(rocketProjectile2[1], Transform(Vec(3, 2, 6)))

  -- Controls
  if InputPressed("q") then
    if wingsState == "SPREAD" or wingsState == "SPREADING" then
      wingsState = "FOLDING"
      targetRotation = 0
    end

    for _, m in ipairs(missiles) do
      m:foldWings()
    end
  end

  if InputPressed("e") then
    if wingsState == "FOLDED" or wingsState == "FOLDING" then
      wingsState = "SPREADING"
      targetRotation = 40
    end

    for _, m in ipairs(missiles) do
      m:spreadWings()
    end
  end

  -- TODO Update missiles
  for _, m in ipairs(missiles) do
    m:update(deltaTime)
  end

  -- Update progress
  if wingsState == "SPREADING" then
    progress = progress + deltaTime / WING_SPREAD_TIME
    if progress >= 1 then
      progress = 1
      wingsState = "SPREAD"
    end
    -- Ease-in
    local t = progress * progress * progress
    rotation = t * targetRotation
  elseif wingsState == "FOLDING" then
    progress = progress - deltaTime / WING_FOLD_TIME
    if progress <= 0 then
      progress = 0
      wingsState = "FOLDED"
    end
    -- Ease-out
    local t = progress * (2 - progress)
    rotation = t * 40
  end

  --DebugPrint("State: " .. wingsState .. " Progress: " .. progress .. " Rotation: " .. rotation)

  -- Set pivot 3 units from wing base
  local leftPivot = Vec(0.5 * leftSizeX * leftScale, 0, -3 * leftScale)
  local rightPivot = Vec(-0.5 * rightSizeX * rightScale, 0, -3 * rightScale)

  local newLeft = TransformCopy(leftTransform)
  local newRight = TransformCopy(rightTransform)

  -- Wing vertical offset (TODO bake into saved transform)
  local verticalOffset = -2.5 * leftScale
  newLeft.pos = VecAdd(newLeft.pos, Vec(0, verticalOffset, 0))
  newRight.pos = VecAdd(newRight.pos, Vec(0, verticalOffset, 0))

  -- Wing rotation
  newLeft = RotateAround(newLeft, leftPivot, QuatEuler(0, -rotation, 0))
  newRight = RotateAround(newRight, rightPivot, QuatEuler(0, rotation, 0))

  -- Apply wing transform
  SetShapeLocalTransform(leftWing, newLeft)
  SetShapeLocalTransform(rightWing, newRight)

  -- Init connected players
  for _, playerId in ipairs(GetAddedPlayers()) do
    -- Enable tools
    SetToolEnabled(ToolTabletId, true, playerId)
  end
end

function server.destroy()

end