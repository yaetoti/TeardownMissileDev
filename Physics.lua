#include "Math.lua"

Physics = {}

---Calculates total point velocity. All vectors should be in the same space
---@param velocity Vec3
---@param angularVelocity Vec3
---@param point Vec3 Radius-vector
function Physics.PointVelocity(point, velocity, angularVelocity)
  return velocity + angularVelocity:cross(point)
end

---@param angle number Angle of attack (radians, [-90, 90]). Positive above wind, negative below wind.
function Physics.CalculateCL(angle)
  local sign = Math.sign(angle)
  local angleAbs = math.abs(angle)
  --if angleAbs < 0.35 then -- peak at 15
  if angleAbs < 0.5 then -- peak at 20
    -- so peak
    --return sign * math.sin(6 * angleAbs) -- peak at 15
    return sign * math.sin(6 * angleAbs) -- peak at 20
  else
    -- stall
    local c = math.cos(angleAbs)
    return 0.9 * sign * c * c
  end
end

---Calculate lift for surface. All vectors should be in the same space
---@param velocityVec Vec3 Velocity
---@param airDensity number
---@param area number Wing area
---@param clAlpha number Lift coefficient for wing shape and profile
---@param spanAxis Vec3 Axis, along which velocity is ignored (hinge axis, skeleton axis, side axis, not forward, STFU, whatever) (normalized)
---@param normalAxis Vec3 Axis, perpendicular to the wing surface (normalized)
function Physics.CalculateLift(velocityVec, airDensity, area, clAlpha, spanAxis, normalAxis)
  local localVelocityVec = velocityVec:orthogonalize(spanAxis) -- remove span component
  local localVelocityDir, localVelocity = localVelocityVec:normalize()

  if localVelocity < Math.EPSILON then
    return Vec3.new()
  end

  local aoa = -localVelocityDir:anglePlane(normalAxis)
  local cl = 0.5 * clAlpha * Physics.CalculateCL(aoa)

  local liftDir = normalAxis:orthogonalize(-localVelocityDir):normalize()
  local q = 0.5 * airDensity * localVelocity * localVelocity

  return (q * area * cl) * liftDir
end

---Calculate lift for axis. All vectors should be in the same space
---@param velocityVec Vec3 Velocity
---@param airDensity number
---@param area number Surface area
---@param clAlpha number Lift coefficient for wing shape and profile
---@param axis Vec3 Axis (normalized)
function Physics.CalculateLiftAxis(velocityVec, airDensity, area, clAlpha, axis)
  local localVelocityVec = velocityVec:project(axis)
  local localVelocityDir, localVelocity = localVelocityVec:normalize()

  if localVelocity < Math.EPSILON then
    return Vec3.new()
  end

  local aoa = velocityVec:angle(axis)
  -- wind from behind - aoa negative
  if aoa > Math.HALF_PI then
    aoa = aoa - math.pi
  end

  local cl = 0.5 * clAlpha * Physics.CalculateCL(aoa)
  --DebugPrint("Angle of attack for axis: "..math.deg(aoa))

  local liftDir = -velocityVec:orthogonalize(axis):normalize()
  local q = 0.5 * airDensity * localVelocity * localVelocity

  return (q * area * cl) * liftDir
end

---Calculate drag for surface. All vectors should be in the same space
---@param velocityVec Vec3 Velocity
---@param airDensity number
---@param area number Surface area
---@param cd number Drag coefficient
---@param axis Vec3 Surface axis (normalized)
function Physics.CalculateDrag(velocityVec, airDensity, area, cd, axis)
  local localVelocityVec = velocityVec:project(axis)
  local localVelocityDir, localVelocity = localVelocityVec:normalize()

  if localVelocity < Math.EPSILON then
    return Vec3.new()
  end

  -- TODO check sign
  -- Mul by -sign to handle both sides and move in the opposite direction
  local q = -0.5 * airDensity * localVelocity * localVelocity * Math.sign(localVelocityDir:dot(axis))
  return (q * area * cd) * axis
end
