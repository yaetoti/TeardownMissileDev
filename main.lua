-- MEINE
local EXPLOSION_STRENGTH = 4

local BASE_SPEED = 30
local BASE_SPEED_MODIFIER = 1
local SHIFT_SPEED_MODIFIER = 3
local MAX_ACCELERATION = 50

local ROTATION_SPEED_MODIFIER = 500
local ROTATION_MAX_ACCELERATION = 500
local ROLL_SPEED_MODIFIER = 30
local ROLL_MAX_ACCELERATION = 30
local BASE_ROTATION_RESPONSE_TIME = 0.75

local targetVelocity = Vec(0, 0, 0)
local currentVelocity = Vec(0, 0, 0)
local currentRotationX = 0
local currentRotationY = 0
local currentRotationZ = 0

local savedCameraRotation


local function sign(n)
  if n >= 0 then
    return 1
  else
    return -1
  end
end

local function clamp(n, min, max)
  if n < min then
    return min
  end

  if n > max then
    return max
  end

  return n
end

local function VecClamp(v, min, max)
  v = VecCopy(v)
  v.x = clamp(v.x, min, max)
  v.y = clamp(v.y, min, max)
  v.z = clamp(v.z, min, max)
  return v
end

local function clamp_abs(n, min, max)
  local nSign = sign(n)
  n = math.abs(n)

  if n < min then
    return nSign * min
  end

  if n > max then
    return nSign * max
  end

  return nSign * n
end

local function lerp(v1, v2, t)
  return v1 * (1 - t) + v2 * t
end

local function expSmoothingAlpha(responseTime, dt)
  return 1 - math.exp(-dt / responseTime)
end

function init()
  RegisterTool("guided", "Storm Shadow", "MOD/vox/radio.vox", 4)
  SetBool("game.tool.guided.enabled", true)
  SetString("game.tool.guided.ammo.display","")
  SetFloat("game.tool.guided.ammo", 101)

  guidedexplosionSound = LoadSound("MOD/snd/explosion.ogg")
  guidedflyingSound = LoadLoop("MOD/snd/rocket_loop.ogg")
  guidedfireSound = LoadSound("tools/launcher0.ogg")
  guidedboosterSound = LoadLoop("MOD/snd/rocket_loop.ogg")
  guidedmissileSprite = LoadSprite("MOD/img/missile.png")
  guidedmissile = {}
  guidedcamdist = 2

  isMissileFlying = false
  isMissileDetached = false
  guidedprimed = false
  piercing = false
end

function GuidedExplode()
  local explode_point = TransformToParentPoint(guidedmissile, Vec(0, 0, -6.5))
  SpawnFire(guidedmissile, Vec(0, 0, -6.5))
  ParticleReset()
  ParticleType("fire")
  ParticleColor(0.7, 0.6, 0.5)
  SpawnParticle(explode_point, Vec(1, 1, 1), 10.0)
  ParticleReset()
  ParticleType("smoke")
  ParticleColor(0.7, 0.6, 0.5)
  SpawnParticle(explode_point, Vec(1, 1, 1), 10.0)
  PlaySound(guidedexplosionSound, guidedmissile.pos, 8, false)
  Explosion(explode_point, EXPLOSION_STRENGTH)
  Explosion(explode_point, EXPLOSION_STRENGTH)

  guidedmissile.pos = nil
  guidedmissile.rot = nil
  guidedprimed = false
  isMissileFlying = false
  isMissileDetached = false
  targetVelocity = Vec(0, 0, 0)
  currentVelocity = Vec(0, 0, 0)
  currentRotationX = 0
  currentRotationY = 0
  currentRotationZ = 0
  Delete(rocketProjectile[1])
end

function RestoreCameraRotation()
  local t = GetPlayerTransform()
  local v = GetPlayerVelocity()
  t.rot = savedCameraRotation
  SetPlayerTransformWithPitch(t)
  SetPlayerVelocity(v)
end

function GuidedCheckHit()
  local fwdpos = TransformToParentPoint(guidedmissile, Vec(0, 0, -6.5))
  local bckpos = TransformToParentPoint(guidedmissile, Vec(0, 0, 0))
  local dir = VecNormalize(VecSub(fwdpos, guidedmissiletip))
  QueryRejectBody(rocketProjectile[1])

  local hit, dist = QueryRaycast(guidedmissiletip, dir, VecLength(VecSub(fwdpos, guidedmissiletip)), 0.1)

  if hit then
    if piercing then
      MakeHole(fwdpos, 1, 1, 1)
    else
      if not isMissileDetached then
        RestoreCameraRotation()
      end

      GuidedExplode()
    end
  end
end

function tick(deltaTime)
  if GetString("game.player.tool") == "guided" and GetPlayerVehicle() == 0 then
    if InputPressed("lmb") then
      -- Launch missile
      if not isMissileFlying and not isMissileDetached then
        isMissileFlying = true
        PlaySound(guidedfireSound)
        rocketProjectile = Spawn("MOD/vox/rocket.xml", rocketTrans)

        -- Save camera rotation
        local t = GetPlayerTransformWithPitch()
        savedCameraRotation = t.rot
      end

      if guidedprimed and isMissileFlying or isMissileDetached then
        if not isMissileDetached then
          RestoreCameraRotation()
        end

        GuidedExplode()
      end
    end

    if InputPressed("rmb") then
      -- Detach
      if isMissileFlying and not isMissileDetached then
        -- TODO bad design my modder
        isMissileFlying = false
        isMissileDetached = true

        RestoreCameraRotation()
      end
    end

    if InputPressed("R") then
      piercing = not piercing
      SetString("hud.notification", "Piercing rocket "..(piercing and "on" or "off"))
    end

    local b = GetToolBody()
    if b ~= 0 then
      if body ~= b then
        body = b
        local shapes = GetBodyShapes(b)
        rocket = shapes[2]
        rocketTrans = GetShapeLocalTransform(rocket)
      end
    end
  end

  if isMissileFlying and InputValue("mousewheel") ~= 0 then
    isMissileFlying = false
    isMissileDetached = true
  end

  -- Movement update
  if isMissileFlying then
    -- Input
    local xMouse, yMouse, shiftDown = InputValue("camerax"), InputValue("cameray"), InputDown("shift")
    local missileSpeedModifier = BASE_SPEED_MODIFIER
    local rotationSpeedModifier = ROTATION_SPEED_MODIFIER

    local deltaZ = 0
    if InputDown("q") then
      deltaZ = deltaZ - 1
    end

    if InputDown("e") then
      deltaZ = deltaZ + 1
    end

    local guidedct = GetCameraTransform()
    if not guidedmissile.pos then guidedmissile.pos = guidedct.pos end
    if not guidedmissile.rot then guidedmissile.rot = guidedct.rot end

    if shiftDown then
      missileSpeedModifier = SHIFT_SPEED_MODIFIER
    end

    -- Velocity
    local targetSpeed = BASE_SPEED * missileSpeedModifier
    local forward = TransformToParentVec(guidedmissile, Vec(0, 0, -1))
    targetVelocity = VecScale(forward, targetSpeed)
    local deltaVelocity = VecSub(targetVelocity, currentVelocity)
    local accelerationStep = MAX_ACCELERATION * deltaTime
    if VecLength(deltaVelocity) > accelerationStep then
      deltaVelocity = VecScale(VecNormalize(deltaVelocity), accelerationStep)
    end

    currentVelocity = VecAdd(currentVelocity, deltaVelocity)

    -- Apply position
    guidedmissile.pos = VecAdd(guidedmissile.pos, VecScale(currentVelocity, deltaTime))

    -- Rotation Pitch-Yaw
    local currentSpeed = VecLength(currentVelocity)

    local speedTurnModifier = 1 / (math.max(currentSpeed, 0.01) / BASE_SPEED)
    local alpha = expSmoothingAlpha(BASE_ROTATION_RESPONSE_TIME * speedTurnModifier, deltaTime)
    local targetRotationX = lerp(currentRotationX, xMouse * rotationSpeedModifier * speedTurnModifier, alpha)
    local targetRotationY = lerp(currentRotationY, yMouse * rotationSpeedModifier * speedTurnModifier, alpha)

    local rotationAccelerationStep = ROTATION_MAX_ACCELERATION * deltaTime
    local deltaX = clamp(targetRotationX - currentRotationX, -rotationAccelerationStep, rotationAccelerationStep)
    local deltaY = clamp(targetRotationY - currentRotationY, -rotationAccelerationStep, rotationAccelerationStep)

    currentRotationX = currentRotationX + deltaX
    currentRotationY = currentRotationY + deltaY

    -- Rotation Roll
    local targetRotationZ = deltaZ * ROLL_SPEED_MODIFIER
    local rollAccelerationStep = ROLL_MAX_ACCELERATION * deltaTime
    local deltaRoll = clamp(targetRotationZ - currentRotationZ, -rollAccelerationStep, rollAccelerationStep)

    currentRotationZ = currentRotationZ + deltaRoll

    -- Apply rotation
    --guidedmissile.rot = QuatLookAt(guidedmissile.pos, forwardPos)
    guidedmissile.rot = QuatRotateQuat(guidedmissile.rot, QuatEuler(-targetRotationY * deltaTime, -targetRotationX * deltaTime, -currentRotationZ * deltaTime))



    -- Camera and effects
    guidedmissiletip = TransformToParentPoint(guidedmissile, Vec(0, 0, -1.1))
    guidedsmokepos = TransformToParentPoint(guidedmissile, Vec(0, 0, 0.9))

    guidedflycam = {}
    --guidedflycam.pos = TransformToParentPoint(guidedmissile, Vec(0, 0, 0))
    --guidedflycam.pos = TransformToParentPoint(guidedmissile, Vec(0, guidedcamdist/3, guidedcamdist))
    guidedflycam.pos = TransformToParentPoint(guidedmissile, Vec(0, guidedcamdist/3, 0))
    guidedflycam.rot = QuatCopy(guidedmissile.rot)

    SetCameraTransform(guidedflycam)

    local width = 0.5
    local length = 1.5
    local spritepos = TransformToParentPoint(guidedmissile, Vec(0, 0, -0.75))
    --local rot = QuatLookAt(guidedmissile.pos, guidedmissiletip)
    local rot = guidedmissile.rot
    rocketWorldtransform = Transform(spritepos, rot)

    SetBodyTransform(rocketProjectile[1], rocketWorldtransform)

    PlayLoop(guidedflyingSound, guidedmissile.pos, 1, false)
    SpawnParticle("fire", guidedsmokepos, Vec(0, 0, 0), 0.75, 0.25)
    SpawnParticle("smoke", guidedsmokepos, Vec(0, 0, 0), 1, 2)
    guidedprimed = true
    GuidedCheckHit()
  end

  if isMissileDetached then
    local guidedct = GetCameraTransform()
    if not guidedmissile.pos then guidedmissile.pos = guidedct.pos end
    if not guidedmissile.rot then guidedmissile.rot = guidedct.rot end

    -- Velocity
    local deltaVelocity = VecSub(targetVelocity, currentVelocity)
    local accelerationStep = MAX_ACCELERATION * deltaTime
    if VecLength(deltaVelocity) > accelerationStep then
      deltaVelocity = VecScale(VecNormalize(deltaVelocity), accelerationStep)
    end

    currentVelocity = VecAdd(currentVelocity, deltaVelocity)

    -- Apply position
    guidedmissile.pos = VecAdd(guidedmissile.pos, VecScale(currentVelocity, deltaTime))

    -- Effects
    guidedmissiletip = TransformToParentPoint(guidedmissile, Vec(0, 0, -1.1))
    guidedsmokepos = TransformToParentPoint(guidedmissile, Vec(0, -0.1, -1))

    local rot = QuatLookAt(guidedmissile.pos, guidedmissiletip)
    rocketWorldtransform = Transform(guidedmissile.pos, rot)

    SetBodyTransform(rocketProjectile[1], rocketWorldtransform)
    PlayLoop(guidedflyingSound, guidedmissile.pos, 4, false)
    SpawnParticle("fire", guidedsmokepos, Vec(0, 0, 0), 0.75, 0.25)
    SpawnParticle("smoke", guidedsmokepos, Vec(0, 0, 0), 1, 2)
    guidedprimed = true
    GuidedCheckHit()
  end
end