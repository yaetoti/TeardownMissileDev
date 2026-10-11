#include "SoundManager.lua"
#include "ControlsWidget.lua"
#include "RPC.lua"

if not ClientController then
  ClientController = {}

  -- Network
  client.activeRequests = {
    createMissile = false,
    explodeMissile = false,
  }

  -- State
  client.isControllingMissile = false
  client.isDetached = false
  client.missileId = 0
  client.missileBody = 0

  -- Target marker
  --client.targetPos = nil
  client.targetPos = Vec()

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
    SoundManager:init()
  end

  function client.destroy()
    SoundManager:destroy()
  end

  function client.tick(deltaTime)
    SoundManager:updateLoops()

    -- Place tools
    for _, playerId in ipairs(GetAllPlayers()) do
      if GetPlayerTool(playerId) == ToolTabletId then
        if playerId == GetLocalPlayer() and not GetBool("game.thirdperson") then
          local time = GetTime()
          local velocity = GetPlayerVelocity(playerId)
          local speed = math.min(VecLength(velocity), 4)

          local bobY = math.sin(time * 15.0) * 0.006 * speed
          local bobX = math.cos(time * 5.0) * 0.003 * speed
          local roll = math.sin(time * 5.0) * 0.1 * speed

          local baseTransform = Transform(Vec(0.4, 0.1, -1.5), QuatEuler(-5, -10, 0))
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
    if GetPlayerTool() == ToolTabletId then
      if InputPressed("lmb") then
        -- Create missile
        if not client.isControllingMissile and not client.activeRequests.createMissile then
          client.createMissileServerRpc()
        end

        -- Explode missile
        if client.isControllingMissile and not client.activeRequests.explodeMissile then
          client.explodeMissileServerRpc(client.missileId)
        end
      end

      if InputPressed("space") then
        client.ToggleWingsDeploymentServerRpc()
      end

      -- TODO make a separate state on server
      if InputPressed("rmb") then
        if client.isControllingMissile then
          debugDetach = not debugDetach
        else
          -- Set target marker
          local cameraTransform = GetCameraTransform()
          local cameraForward = Math.FORWARD:fromTransformVec(cameraTransform)
          local hit, dist, normal, shape = QueryRaycast(cameraTransform.pos, cameraForward, 10000)

          if hit then
            client.targetPos = VecAdd(cameraTransform.pos, VecScale(cameraForward, dist))
            client.PlaySound("marker_success")
          else
            client.targetPos = nil
            client.PlaySound("marker_fail")
          end
        end
      end

      -- TODO make a separate state on server
      if InputPressed("mmb") then
        debugFreeCamera = not debugFreeCamera
      end

      -- Handle input
      -- TODO remove debugFreeCamera or make it a feature
      if client.isControllingMissile and not debugFreeCamera then
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
    end

    -- TODO rewrite camera rotation
    if not debugDetach and not debugMissile and client.isControllingMissile and IsHandleValid(client.missileBody) then
      -- Handle camera
      local missileTransform = GetBodyTransform(client.missileBody)

      local offsetVec = Missile.CAMERA_OFFSET:fromTransformVec(missileTransform)
      local rot = missileTransform.rot

      if debugFreeCamera then
        local inputX = InputValue("camerax")
        local inputY = InputValue("cameray")

        local deltaRot = QuatEuler(-inputY * 30, -inputX * 30, 0)
        debugFreeCameraRot = QuatRotateQuat(debugFreeCameraRot, deltaRot)

        rot = QuatRotateQuat(missileTransform.rot, debugFreeCameraRot)
        offsetVec = QuatRotateVec(rot, Missile.CAMERA_OFFSET)
      else
        debugFreeCameraRot = Quat()
      end

      local newTransform = Transform(VecAdd(missileTransform.pos, offsetVec), rot)

      SetCameraTransform(newTransform)
    end
  end

  function client.draw()
    if not client.isControllingMissile then
      return
    end

    local width, height = UiWidth(), UiHeight()

    -- === Draw target marker ===
    if client.targetPos ~= nil then
      UiPush()

      local x, y, dist = UiWorldToPixel(client.targetPos)
      local boxSize = 28
      local boxSizeHalf = boxSize * 0.5
      local boxSizePart = boxSize * 0.4
      local thickness = 2
      local color = dist > 0 and Vec(1, 1, 1) or Vec(0.8, 0.6, 0.6)

      UiColor(color[1], color[2], color[3], 0.1)

      -- Invert coords when behind
      if dist <= 0 then
        x = width - x
        y = height - y
      end

      -- Rect
      if dist > 0 then
        -- w/o lines overlapping
        local function corner(x, y, dx, dy)
          local t1 = dy >= 0 and (thickness) or (-thickness)
          local t2 = dx >= 0 and (thickness) or (-thickness)

          UiPush()
          UiTranslate(x, y)
          UiRect(dx, t1)

          UiTranslate(0, t1)
          UiRect(t2, dy - t1)
          UiPop()
        end

        corner(x - boxSizeHalf, y - boxSizeHalf, boxSizePart, boxSizePart)
        corner(x + boxSizeHalf + 1, y - boxSizeHalf, -boxSizePart, boxSizePart)
        corner(x - boxSizeHalf, y + boxSizeHalf + 1, boxSizePart, -boxSizePart)
        corner(x + boxSizeHalf + 1, y + boxSizeHalf + 1, -boxSizePart, -boxSizePart)
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

    -- === Draw horizon line ===

    -- === TODO Noise ===
    --noiseTimer = noiseTimer or 0
    --noiseTimer = noiseTimer - GetTimeStep()
    --if noiseTimer <= 0 then
    --  noiseTimer = GetRandomFloat(0.01, 0.05)
    --  noiseId = GetRandomInt(1, 4)
    --end
    --
    --UiImage("MOD/img/noise_"..noiseId..".png", 0, 0, 1920, 1080)


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
end