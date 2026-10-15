#include "SoundManager.lua"
#include "ControlsWidget.lua"
#include "RPC.lua"
#include "ReloadManager.lua"

-- Network
client.activeRequests = {
  createMissile = false,
  explodeMissile = false,
  detach = false,
  reattach = false,
}

-- State
client.isControllingMissile = false
client.isDetached = false
client.freeCameraEnabled = false
client.freeCameraRot = Quat()
client.missileId = 0
client.missileBody = 0

-- Target marker
client.targetPos = nil

-- Controls
client.pitchSensitivity = 0.5
client.yawSensitivity = 0.5
client.rollSensitivity = 2.0
client.propulsionSensitivity = 0.1
client.roll = 0.0
client.pitch = 0.0
client.yaw = 0.0
client.propulsion = 0.0

-- UI
client.controlsWidget = ControlsWidget.new()

function client.init()
  ReloadManager.markLoaded()

  SoundManager:init()
end

function client.destroy()
  SoundManager:destroy()
end

function client.tick(deltaTime)
  if ReloadManager.isReload() then
    ReloadManager.initRegistry()
    ReloadManager.reload()
    ReloadManager.markLoaded()
  end

  SoundManager:updateLoops()

  -- Place tools
  for _, playerId in ipairs(GetAllPlayers()) do
    if GetPlayerTool(playerId) == ToolTabletId then
      if playerId == GetLocalPlayer() and not GetBool("game.thirdperson") then
        local time = GetTime()
        local velocity = GetPlayerVelocity(playerId)
        local cameraTransform = GetPlayerCameraTransform()
        local speed = math.min(VecLength(velocity), 4)

        local bobY = math.sin(time * 15.0) * 0.006 * speed
        local bobX = math.cos(time * 5.0) * 0.003 * speed
        local roll = math.sin(time * 5.0) * 0.1 * speed

        local range = 1.5
        local tabletLocation = Vec3.new(0.4, 0.1, -range)
        hit, dist = QueryRaycast(cameraTransform.pos, tabletLocation:fromTransformVec(cameraTransform), range, 0.1)
        if hit then
          tabletLocation[3] = -math.min(dist, range)
        end

        local baseTransform = Transform(tabletLocation, QuatEuler(-5, -10, 0))
        local offset = Transform(Vec(bobX, bobY, 0), QuatEuler(0, 0, roll))
        local transform = TransformToParentTransform(baseTransform, offset)

        SetToolTransform(transform, 1.0, playerId)
      else
        --TODO Dis baka holds his hands straight. No point in this unless I find how to bend his elbow. Offset Z: -dot * 0.3
        --local transform = GetPlayerTransformWithPitch(playerId)
        --local forward = TransformToParentVec(transform, Vec(0, 0, -1))
        --local up = Vec(0, 1, 0)
        --local dot = VecDot(forward, up)
        --DebugPrint(dot)

        SetToolTransform(Transform(Vec(0.0, 0.5, -0.6), QuatEuler(-10, 0, 0)), 1.0, playerId)
        SetToolHandPoseLocalTransform(
          Transform(Vec(0.8, -0.7, -0.5)),
          Transform(Vec(-0.8, -0.7, -0.5)),
          playerId
        )
      end
    end
  end

  -- Tool input
  if GetPlayerCanUseTool() and GetPlayerGrabBody() == 0 and GetPlayerTool() == ToolTabletId then
    if InputPressed("lmb") then
      -- Create missile
      if client.isControllingMissile then
        if client.isDetached then
          client.reattachRequestServerRpc()
        else
          client.explodeMissileServerRpc(client.missileId)
        end
      else
        client.createMissileServerRpc()
      end
    end

    if InputPressed("space") then
      client.ToggleWingsDeploymentServerRpc()
    end

    if InputPressed("rmb") then
      if client.isControllingMissile and not client.isDetached then
        client.detachRequestServerRpc()
      else
        -- Set target marker
        local cameraTransform = GetCameraTransform()
        local cameraForward = Math.FORWARD:fromTransformVec(cameraTransform)
        local hit, dist, normal, shape = QueryRaycast(cameraTransform.pos, cameraForward, 10000)

        if hit then
          client.targetPos = VecAdd(cameraTransform.pos, VecScale(cameraForward, dist))
          client.PlaySound("marker_success")
        else
          client.PlaySound("marker_fail")
        end
      end
    end

    if InputPressed("mmb") then
      if client.isControllingMissile and not client.isDetached then
        client.freeCameraEnabled = not client.freeCameraEnabled
        client.freeCameraRot = Quat()
      else
        client.targetPos = nil
        client.PlaySound("marker_fail")
      end
    end



    if client.isControllingMissile and not client.isDetached then
      -- Update input
      if not client.freeCameraEnabled then
        -- TODO remove client.freeCameraEnabled or make it a feature
        -- Get input
        local pitchInput = InputValue("cameray") * client.pitchSensitivity
        local yawInput = InputValue("camerax") * client.yawSensitivity
        local propulsionInput = InputValue("mousewheel") * client.propulsionSensitivity
        local rollInput = 0.0

        if (InputDown("shift")) then
          propulsionInput = propulsionInput * 0.1

          -- Update roll (precise)
          if InputDown("left") then rollInput = rollInput - client.rollSensitivity * deltaTime end
          if InputDown("right") then rollInput = rollInput + client.rollSensitivity * deltaTime end
          client.roll = Math.clamp(client.roll + rollInput, -1, 1)
        else
          -- Update roll (abrupt)
          if InputDown("left") then rollInput = rollInput - 1 end
          if InputDown("right") then rollInput = rollInput + 1 end
          --if Math.distance(rollInput, 0) < Math.EPSILON and (InputReleased("left") or InputReleased("right")) then
          if Math.distance(rollInput, 0) < Math.EPSILON then
            client.roll = 0
          else
            --client.roll = Math.clamp(client.roll + rollInput, -1, 1)
            client.roll = Math.clamp(rollInput, -1, 1)
          end
        end

        -- Update controls
        client.pitch = Math.clamp(client.pitch + pitchInput, -1, 1)
        client.yaw = Math.clamp(client.yaw + yawInput, -1, 1)
        client.propulsion = Math.clamp01(client.propulsion + propulsionInput)

        -- Send data to the server
        client.SetInputServerRpc(client.propulsion, client.pitch, client.yaw, client.roll)
      end

      -- Update camera
      if not debugMissile and IsHandleValid(client.missileBody) then
        local missileTransform = GetBodyTransform(client.missileBody)

        local offsetVec = Missile.CAMERA_OFFSET:fromTransformVec(missileTransform)
        local rot = missileTransform.rot

        if client.freeCameraEnabled then
          local inputX = InputValue("camerax")
          local inputY = InputValue("cameray")

          local deltaRot = QuatEuler(-inputY * 30, -inputX * 30, 0)
          client.freeCameraRot = QuatRotateQuat(client.freeCameraRot, deltaRot)

          rot = QuatRotateQuat(missileTransform.rot, client.freeCameraRot)
          offsetVec = QuatRotateVec(rot, Missile.CAMERA_OFFSET)
        end

        local newTransform = Transform(VecAdd(missileTransform.pos, offsetVec), rot)

        SetCameraTransform(newTransform)
      end
    end
  end
end

function client.draw()
  if not client.isControllingMissile or client.isDetached then
    return
  end

  local width, height = UiWidth(), UiHeight()

  -- === Draw target marker ===
  
  -- w/o lines overlapping so that transparency works properly
  local function corner(x, y, dx, dy, thickness)
    local t1 = dy >= 0 and (thickness) or (-thickness)
    local t2 = dx >= 0 and (thickness) or (-thickness)

    UiPush()
    UiTranslate(x, y)
    UiRect(dx, t1)

    UiTranslate(0, t1)
    UiRect(t2, dy - t1)
    UiPop()
  end

  if client.targetPos ~= nil then
    UiPush()

    local x, y, dist = UiWorldToPixel(client.targetPos)
    local boxSize = 28
    local boxSizeHalf = boxSize * 0.5
    local boxSizePart = boxSize * 0.4
    local thickness = 2
    local color = dist > 0 and Vec(1, 1, 1) or Vec(1.0, 0.6, 0.6)

    UiColor(color[1], color[2], color[3], 0.4)

    -- Invert coords when behind
    if dist <= 0 then
      x = width - x
      y = height - y
    end

    -- Rect
    if dist > 0 then
      corner(x - boxSizeHalf, y - boxSizeHalf, boxSizePart, boxSizePart, thickness)
      corner(x + boxSizeHalf + 1, y - boxSizeHalf, -boxSizePart, boxSizePart, thickness)
      corner(x - boxSizeHalf, y + boxSizeHalf + 1, boxSizePart, -boxSizePart, thickness)
      corner(x + boxSizeHalf + 1, y + boxSizeHalf + 1, -boxSizePart, -boxSizePart, thickness)
    end

    -- Lines
    UiPush()
    UiTranslate(0, y)
    UiRect(width, thickness)
    UiPop()

    UiPush()
    UiTranslate(x, 0)
    UiRect(thickness, height)
    UiPop()

    UiPop()
  end

  -- === Draw reticle ===
  do
    local function line(x, y, w, h)
      UiPush()
      UiTranslate(x, y)
      UiRect(w, h)
      UiPop()
    end

    UiPush()
    local size = 20
    local distance = 10
    local halfThickness = 1

    UiTranslate(width * 0.5, height * 0.5)
    UiColor(1, 1, 1, 0.4)

    -- horizontal left/right
    line(-(distance + size), -halfThickness, size, halfThickness * 2)
    line(distance, -halfThickness, size, halfThickness * 2)

    -- vertical
    line(-halfThickness, distance * 0.5, halfThickness * 2, size * 0.5)

    UiPop()
  end

  -- === Draw horizon line ===
  local function drawHorizon()
    -- TODO broken when not 16:9 for some reason
    -- TODO but the thing is, you cannot set not 16:9 not in 2 players mode. Seems like a legitimate reason to not give a fuck
    -- TODO Also, teardown does some blood wizardry to stretch rendering, because width/height is still displayed 1920x1080, nevertheless, scale changes

    -- The Great Horizon Rendering Explanation

    -- We draw a straight horizontal line for the horizon
    -- When we change pitch - line moves away from the center
    -- When we change roll - line rotates around the center

    -- Offset = normal to the horizon line in screen space
    -- For canonical line equation Ax + By = C, the normal is (A, B)

    -- We can define the horizon line through pixel vector and vector UP, perpendicular to the horizon
    -- Let (x, y, -focalLength) be a vector to the pixel on the near plane (in camera space)
    -- localUp = (lX, lY, lZ) - vector, perpendicular to the horizon (also camera space)
    -- Then line goes where (x, y, -focalLength) dot (lX, lY, lZ) = 0 - when vectors are perpendicular

    -- x*lX + y*lY - focalLength*lZ = 0
    -- x*lX + y*lY = focalLength*lZ
    -- where A = lX, B = lY, C = focalLength * lZ
    -- But direction (A, B) is in camera space on the near plane, to get offset in pixels we need to find it's length in pixels

    -- Let (x0, y0) be the point on the screen that lies on both line and normal
    -- Then x0 = kA, y0 = kB, let's find k
    -- A(kA) + B(kB) = C
    -- k(A^2 + B^2) = C
    -- k = C / (A^2 + B^2)

    local transform = GetCameraTransform()
    local localUp = Math.UP:toTransformVec(transform)

    if localUp[3] > 0.99 then
      -- Looking along world Y - infinite line distance
      return
    end

    local fov = GetInt("options.gfx.fov")
    local focalLength = (width * 0.5) / math.tan(math.rad(fov / 2))

    local A = localUp[1]
    local B = localUp[2]
    local C = localUp[3] * focalLength
    local k = C / (A * A + B * B)

    local offsetX = k * A
    local offsetY = -k * B
    local roll = math.deg(math.atan2(-localUp[1], localUp[2]))

    UiPush()

    UiTranslate(width * 0.5 + offsetX, height * 0.5 + offsetY)
    UiRotate(roll)
    UiAlign("center middle")
    UiColor(0.3, 1, 0.3, 0.3)
    UiRect(width * 1.5, 2)

    UiTranslate(0, 2)
    UiColor(0.2, 0.7, 0.2, 0.3)
    UiRect(width * 1.5, 1)

    UiPop()
  end

  drawHorizon()

  -- === Noise ===
  -- TODO annoying. Make more different images or remove
  --noiseTimer = noiseTimer or 0
  --noiseTimer = noiseTimer - GetTimeStep()
  --if noiseTimer <= 0 then
  --  noiseTimer = GetRandomFloat(0.01, 0.05)
  --  noiseId = GetRandomInt(1, 4)
  --end
  --
  --UiImage("MOD/img/noise_"..noiseId..".png", 0, 0, 1920, 1080)


  -- === Draw decorative camera lines ===
  do
    local size = height * 0.1
    local margin = height * 0.1
    local thickness = 3

    UiColor(1, 1, 1, 1)
    corner(margin, margin, size, size, thickness)
    corner(width - margin, margin, -size, size, thickness)
    corner(margin, height - margin, size, -size, thickness)
    corner(width - margin, height - margin, -size, -size, thickness)
  end

  -- === Draw controls widget ===
  client.controlsWidget.pitch = client.pitch
  client.controlsWidget.yaw = client.yaw
  client.controlsWidget.roll = client.roll
  client.controlsWidget.propulsion = client.propulsion

  local marginSize = 25

  UiPush()
  UiTranslate(marginSize, height - ControlsWidget.HEIGHT - marginSize)
  client.controlsWidget:draw()
  UiPop()
end
