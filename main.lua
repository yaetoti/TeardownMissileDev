-- MEINE
local EXPLOSION_STRENGTH = 4

local THRUST = 80
local BASE_SPEED = 30
local BASE_SPEED_MODIFIER = 1
local SHIFT_SPEED_MODIFIER = 3

local PITCH_TORQUE = 600
local YAW_TORQUE = 600
local ROLL_TORQUE = 320
local MAX_ANGULAR_SPEED = 180

local FORWARD_DRAG = 0.8
local LATERAL_DRAG = 14
local ANGULAR_DRAG = 0.8

local FUSE_TIMER = 0.25

local targetSpeed = 0
local velocity = Vec(0, 0, 0)
local angularVelocity = Vec(0, 0, 0)

local fuseTimer = FUSE_TIMER
local armed = false


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
  targetSpeed = 0
  velocity = Vec(0, 0, 0)
  angularVelocity = Vec(0, 0, 0)
  armed = false
  fuseTimer = FUSE_TIMER

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

  local hit, dist, normal, shape = QueryRaycast(guidedmissiletip, dir, VecLength(VecSub(fwdpos, guidedmissiletip)), 0.1)
  local material = GetShapeMaterialAtPosition(shape, fwdpos)

  if hit then
    MakeHole(fwdpos, 1, 1, 1)
    armed = true
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

  if isMissileFlying or isMissileDetached then
    if armed then
      fuseTimer = fuseTimer - deltaTime
      if fuseTimer <= 0 then
        if not isMissileDetached then
          RestoreCameraRotation()
        end

        GuidedExplode()
      end
    end
  end

  -- Movement update
  if isMissileFlying then
    -- Input
    local mouseX, mouseY = InputValue("camerax"), InputValue("cameray")
    local missileSpeedModifier = BASE_SPEED_MODIFIER

    local rollInput = 0
    if InputDown("q") then
      rollInput = rollInput - 1
    end

    if InputDown("e") then
      rollInput = rollInput + 1
    end

    if InputDown("shift") then
      missileSpeedModifier = SHIFT_SPEED_MODIFIER
    end

    local guidedct = GetCameraTransform()
    if not guidedmissile.pos then guidedmissile.pos = guidedct.pos end
    if not guidedmissile.rot then guidedmissile.rot = guidedct.rot end

    -- Velocity

    -- Forward direction
    local forward = TransformToParentVec(guidedmissile, Vec(0, 0, -1))

    -- Apply thrust
    targetSpeed = BASE_SPEED * missileSpeedModifier
    local speed = VecDot(velocity, forward)
    local velDir = VecNormalize(velocity)
    local alignment = VecDot(velDir, forward)
    alignment = clamp(alignment, 0, 1)
    speedFactor = (1 - speed/targetSpeed) * alignment

    local acceleration = VecScale(forward, THRUST * speedFactor)
    velocity = VecAdd(velocity, VecScale(acceleration, deltaTime))

    -- Decompose updated velocity
    local forwardSpeed = VecDot(velocity, forward)
    local forwardVelocity = VecScale(forward, forwardSpeed)
    local lateralVelocity = VecSub(velocity, forwardVelocity)

    -- Apply drag
    forwardVelocity = VecScale(forwardVelocity, math.exp(-FORWARD_DRAG * deltaTime))
    lateralVelocity = VecScale(lateralVelocity, math.exp(-LATERAL_DRAG * deltaTime))

    -- Recombine
    velocity = VecAdd(forwardVelocity, lateralVelocity)

    -- Integrate
    guidedmissile.pos = VecAdd(guidedmissile.pos, VecScale(velocity, deltaTime))



    -- Rotation
    local avLen = VecLength(angularVelocity)
    if avLen > MAX_ANGULAR_SPEED then
      angularVelocity = VecScale(
          VecNormalize(angularVelocity),
          MAX_ANGULAR_SPEED
      )
    end

    angularVelocity = VecAdd(
        angularVelocity,
        Vec(
            -mouseY * PITCH_TORQUE * deltaTime,
            -mouseX * YAW_TORQUE * deltaTime,
            -rollInput * ROLL_TORQUE * deltaTime
        )
    )

    -- Roll affects yaw stability
    local rollEffect = angularVelocity[3] * 0.2
    angularVelocity[1] = angularVelocity[1] + rollEffect * deltaTime

    -- Damping
    angularVelocity = VecScale(angularVelocity, math.exp(-ANGULAR_DRAG * deltaTime))

    -- Integrate
    local deltaRot = QuatEuler(
        angularVelocity[1] * deltaTime,
        angularVelocity[2] * deltaTime,
        angularVelocity[3] * deltaTime
    )

    guidedmissile.rot = QuatRotateQuat(guidedmissile.rot, deltaRot)


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
    -- Forward direction
    local forward = TransformToParentVec(guidedmissile, Vec(0, 0, -1))

    -- Apply thrust
    local speed = VecDot(velocity, forward)
    local velDir = VecNormalize(velocity)
    local alignment = VecDot(velDir, forward)
    alignment = clamp(alignment, 0, 1)
    speedFactor = (1 - speed/targetSpeed) * alignment

    local acceleration = VecScale(forward, THRUST * speedFactor)
    velocity = VecAdd(velocity, VecScale(acceleration, deltaTime))

    -- Decompose updated velocity
    local forwardSpeed = VecDot(velocity, forward)
    local forwardVelocity = VecScale(forward, forwardSpeed)
    local lateralVelocity = VecSub(velocity, forwardVelocity)

    -- Apply drag
    forwardVelocity = VecScale(forwardVelocity, math.exp(-FORWARD_DRAG * deltaTime))
    lateralVelocity = VecScale(lateralVelocity, math.exp(-LATERAL_DRAG * deltaTime))

    -- Recombine
    velocity = VecAdd(forwardVelocity, lateralVelocity)

    -- Integrate
    guidedmissile.pos = VecAdd(guidedmissile.pos, VecScale(velocity, deltaTime))




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