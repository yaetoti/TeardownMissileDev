-- MEINE
local EXPLOSION_STRENGTH = 4

local THRUST = 80
local BASE_SPEED = 50
local BASE_SPEED_MODIFIER = 1
local SHIFT_SPEED_MODIFIER = 3

local PITCH_TORQUE = 500
local YAW_TORQUE = 300
local ROLL_TORQUE = 320
local MAX_ANGULAR_SPEED = 180

local FORWARD_DRAG = 0.8
local LATERAL_DRAG = 14
local ANGULAR_DRAG = 0.8

local PENETRATION = 1.00
local FUSE_TIMER = 0.25

local targetSpeed = 0
local velocity = Vec(0, 0, 0)
local angularVelocity = Vec(0, 0, 0)

local penetration = PENETRATION
local fuseTimer = FUSE_TIMER
local armed = false


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
  penetration = PENETRATION

  Delete(rocketProjectile[1])
end

function GuidedCheckHit()
  -- todo replace with direction and scale
  local origin = guidedmissiletip
  local forwardPos = TransformToParentPoint(guidedmissile, Vec(0, 0, -6.5))
  local forwardDir = VecSub(forwardPos, origin)

  local dir = VecNormalize(forwardDir)
  local dirLength = VecLength(forwardDir)

  QueryRejectBody(rocketProjectile[1])
  local hit, dist, normal, shape = QueryRaycast(origin, dir, dirLength, 0.1)
  local hasUnbreakableTag = HasTag(shape, "unbreakable")

  if hit then
    local hitPos = VecAdd(origin, VecScale(dir, dist + 0.001))
    local material = GetShapeMaterialAtPosition(shape, hitPos)

    local penetrationTable = {
      ["foliage"] = 0.01,
      ["glass"] = 0.1,
      ["plaster"] = 0.1,
      ["dirt"] = 0.1,
      ["wood"] = 0.2,
      ["brick"] = 0.7,
      ["masonry"] = 0.7,
      ["metal"] = 0.8,
      ["heavymetal"] = 1.0,
      ["rock"] = 1.0,
      ["unphysical"] = 1.0,
    }
    local penetrationLoss = penetrationTable[material] or 0

    MakeHole(hitPos, 1.2, 1, 0.7)
    armed = true
    penetration = penetration - penetrationLoss

    if hasUnbreakableTag then
      fuseTimer = 0.0
    end
  end
end

function HitDebug(deltaTime)
  local playerTransform = GetPlayerEyeTransform()
  local playerLookDir = TransformToParentVec(playerTransform, Vec(0, 0, -1))
  local hit, dist, normal, shape = QueryRaycast(playerTransform.pos, playerLookDir, 100)

  if hit then
    local hitPos = VecAdd(playerTransform.pos, VecScale(playerLookDir, dist + 0.001))
    local mat = GetShapeMaterialAtPosition(shape, hitPos)
    local hasUnbreakableTag = HasTag(shape, "unbreakable")

    local penetrationTable = {
      ["foliage"] = 0.01,
      ["glass"] = 0.1,
      ["plaster"] = 0.1,
      ["dirt"] = 0.1,
      ["wood"] = 0.1,
      ["masonry"] = 0.5,
      ["metal"] = 0.8,
      ["heavymetal"] = 1.0,
      ["rock"] = 1.0,
      ["unphysical"] = 1.0,
    }
    local penetrationLoss = penetrationTable[mat] or 0

    DebugPrint("playerTransform = "..TransformStr(playerTransform))
    DebugPrint("lookDir = "..VecStr(playerLookDir))

    DebugPrint("pos = "..VecStr(hitPos))
    DebugPrint("material = "..tostring(mat))
    DebugPrint("hasUnbreakableTag = "..tostring(hasUnbreakableTag))
    DebugPrint("penetrationLoss = "..tostring(penetrationLoss))
  end
end

function tick(deltaTime)
  -- TODO debug
  --HitDebug(deltaTime)

  if GetPlayerCanUseTool() and GetString("game.player.tool") == "guided" then
    -- Launch missile
    if InputPressed("lmb") then
      if not isMissileFlying and not isMissileDetached then
        isMissileFlying = true
        PlaySound(guidedfireSound)
        rocketProjectile = Spawn("MOD/vox/rocket.xml", rocketTrans)
      end

      if guidedprimed and isMissileFlying or isMissileDetached then
        GuidedExplode()
      end
    end

    -- Detach
    if InputPressed("rmb") then
      if isMissileFlying and not isMissileDetached then
        -- TODO bad design my modder
        isMissileFlying = false
        isMissileDetached = true
      end
    end

    -- TODO integrate
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
      local shouldExplode = false

      if not piercing then
        fuseTimer = fuseTimer - deltaTime
        if fuseTimer <= 0 then
          shouldExplode = true
        end
      end

      if penetration <= 0 then
        shouldExplode = true
      end

      if shouldExplode then
        GuidedExplode()
      end
    end
  end

  -- Movement update
  if isMissileFlying then
    DisablePlayerInput()

    -- Input
    local mouseX, mouseY = InputValue("camerax"), InputValue("cameray")
    local missileSpeedModifier = BASE_SPEED_MODIFIER

    local rollInput = 0
    if InputDown("a") then
      rollInput = rollInput - 1
    end

    if InputDown("d") then
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
    --local alignment = 1
    alignment = clamp(alignment, 0.001, 1)
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
    alignment = clamp(alignment, 0.001, 1)
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