#version 2

local time = 0
local ToolTabletId = "tablet"

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

  rocketProjectile = Spawn("MOD/vox/rocket.xml", Transform(Vec(0, 3, 4)))
  rocketProjectile2 = Spawn("MOD/vox/Missile.xml", Transform(Vec(0, 2, 0)))

  leftWing = rocketProjectile2[8]
  rightWing = rocketProjectile2[7]
  leftTransform = GetShapeLocalTransform(leftWing)
  rightTransform = GetShapeLocalTransform(rightWing)
  leftSizeX, leftSizeY, leftSizeZ, leftScale = GetShapeSize(leftWing)
  rightSizeX, rightSizeY, rightSizeZ, rightScale = GetShapeSize(rightWing)

  leftOffset = Vec()
  rightOffset = Vec()

  --local shapes = GetBodyShapes(rocketProjectile2)
  --DebugPrint("shapes: "..#rocketProjectile2)
  --DebugPrint(rocketProjectile2)
  --DebugPrint(rocketProjectile2[3])

  --for i = 1, #rocketProjectile2 do
  --  local s = rocketProjectile2[i]
  --  DebugPrint(GetDescription(s))
  --  if HasTag(s, "left_wing") then
  --    leftWing = s
  --  elseif HasTag(s, "right_wing") then
  --    rightWing = s
  --  end
  --end

  rotation = 0

  DebugPrint(leftWing)
  DebugPrint(leftTransform)
  --DebugPrint(rightWing)
end

function RotateAround(tr, pivot, rot)
  local relative = VecSub(tr.pos, pivot)
  local newPos   = VecAdd(pivot, QuatRotateVec(rot, relative))
  local newRot   = QuatRotateQuat(rot, tr.rot)   -- order matters; try the other way if it looks mirrored
  --local newRot   = QuatRotateQuat(tr.rot, rot)   -- order matters; try the other way if it looks mirrored
  return Transform(newPos, newRot)
end

function server.tick(deltaTime)
  time = time + deltaTime
  SetBodyTransform(rocketProjectile[1], Transform(Vec(-5 + math.sin(time), 3, 4)))
  SetBodyTransform(rocketProjectile2[3], Transform(Vec(3 + math.sin(time), 2, 0)))

  -- Controls
  rotation = rotation + InputValue("mousewheel")
  DebugPrint(rotation)
  DebugPrint(leftOffset)

  -- Position
  if InputPressed("q") then
    rotation = 0
  end

  if InputPressed("e") then
    rotation = 40
  end

  if InputPressed("uparrow") then
    leftOffset = Vec(leftOffset[1], leftOffset[2], leftOffset[3] + leftScale)
  end

  if InputPressed("downarrow") then
    leftOffset = Vec(leftOffset[1], leftOffset[2], leftOffset[3] - leftScale)
  end

  if InputPressed("leftarrow") then
    leftOffset = Vec(leftOffset[1] - leftScale, leftOffset[2], leftOffset[3])
  end

  if InputPressed("rightarrow") then
    leftOffset = Vec(leftOffset[1] + leftScale, leftOffset[2], leftOffset[3])
  end

  -- Move wings
  -- 3 units from front

  local leftPivot = Vec(0.5 * leftSizeX * leftScale, 0, -3 * leftScale)
  local rightPivot = Vec(-0.5 * rightSizeX * rightScale, 0, -3 * rightScale)

  local newLeft = TransformCopy(leftTransform)
  local newRight = TransformCopy(rightTransform)

  local verticalOffset = -2.5 * leftScale
  newLeft.pos = VecAdd(newLeft.pos, Vec(0, verticalOffset, 0))
  newRight.pos = VecAdd(newRight.pos, Vec(0, verticalOffset, 0))

  newLeft = RotateAround(newLeft, leftPivot, QuatEuler(0, -rotation, 0))
  newRight = RotateAround(newRight, rightPivot, QuatEuler(0, rotation, 0))

  --newLeft.pos = Vec(newLeft.pos[1], newLeft.pos[2] - 2.5 / 20, newLeft.pos[3])


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