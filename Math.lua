#include "Vec3.lua"

Math = {}
Math.EPSILON = 0.000001
Math.HALF_PI = math.pi * 0.5

Math.RIGHT = Vec3.new(1, 0, 0)
Math.UP = Vec3.new(0, 1, 0)
Math.FORWARD = Vec3.new(0, 0, -1)

---@param n number
function Math.sign(n)
  if n < 0 then return -1
  elseif n > 0 then return 1
  else return 0
  end
end

---@return Vec component of v1, perpendicular to v2
function Math.VecOrthogonalize(v1, v2)
  local v1AlongV2 = VecScale(v2, VecDot(v1, v2))
  return VecSub(v1, v1AlongV2)
end

---Transforms vector into basis. Assumes that basis vectors are orthonormal
---@param v Vec vector to transform
---@param right Vec right basis vector
---@param up Vec vector basis vector
---@param forward Vec vector basis vector
function Math.VecToBasis(v, right, up, forward)
  return Vec(
    VecDot(v, right),
    VecDot(v, up),
    VecDot(v, forward)
  )
end

---Transforms vector out of basis. Assumes that basis vectors are orthonormal
---@param v Vec vector to transform
---@param right Vec right basis vector
---@param up Vec vector basis vector
---@param forward Vec vector basis vector
function Math.VecFromBasis(v, right, up, forward)
  return Vec(
    v[1] * right[1] + v[2] * up[1] + v[3] * forward[1],
    v[1] * right[2] + v[2] * up[2] + v[3] * forward[2],
    v[1] * right[3] + v[2] * up[3] + v[3] * forward[3]
  )
end

---@return Vec, number normalized vector, original length
function Math.VecNormalizeSafe(v)
  local length = VecLength(v)
  if length <= Math.EPSILON then
    return Vec(0, 0, 0), 0
  end

  return Vec(v[1] / length, v[2] / length, v[3] / length), length
end

function Math.VecAdd(...)
  local vecs = { ... }
  local x, y, z = 0, 0, 0

  for _, vec in ipairs(vecs) do
    x = x + vec[1]
    y = y + vec[2]
    z = z + vec[3]
  end

  return Vec(x, y, z)
end

---@param v1 Vec Vector
---@param v2 Vec Vector
---@return number Angle in radians
function Math.VecAngle(v1, v2)
  return math.acos(VecDot(Math.VecNormalizeSafe(v1), Math.VecNormalizeSafe(v2)))
end

---Returns angle between vectors. Does not normalize vectors
---@param v1 Vec Vector
---@param v2 Vec Vector
---@return number Angle in radians
function Math.VecAngleUnsafe(v1, v2)
  return math.acos(VecDot(v1, v2))
end

---@param v Vec Vector
---@param n Vec Normal
---@return number Angle in radians
function Math.VecPlaneAngle(v, n)
  return math.asin(VecDot(Math.VecNormalizeSafe(v), Math.VecNormalizeSafe(n)))
end

---Returns angle between vector and plane. Does not normalize vectors
---@param v Vec Vector
---@param n Vec Normal
---@return number Angle in radians
function Math.VecPlaneAngleUnsafe(v, n)
  return math.asin(VecDot(v, n))
end

function Math.lerp(a, b, t)
  return a + (b - a) * t
end

function Math.clamp(value, min, max)
  if value < min then
    return min
  elseif value > max then
    return max
  else
    return value
  end
end

function Math.clamp01(value)
  return Math.clamp(value, 0, 1)
end

---@param v1 number
---@param v2 number
---@return number Absolute distance between numbers
function Math.distance(v1, v2)
  return math.abs(v1 - v2)
end

---@param value number
---@param target number
---@param maxSpeed number
function Math.moveTowards(value, target, maxSpeed)
  local diff = target - value
  if math.abs(diff) <= maxSpeed then
    return target
  end

  if diff > 0 then
    return value + maxSpeed
  end

  return value - maxSpeed
end

---Rotates transform around a pivot point
---@param transform Transform Transform to rotate
---@param pivot Vec Pivot point
---@param rotation Quat Rotation to apply to the transform
function Math.RotateTransformAroundPivot(transform, pivot, rotation)
  local relative = VecSub(transform.pos, pivot)
  local newPos = VecAdd(pivot, QuatRotateVec(rotation, relative))
  local newRot = QuatRotateQuat(rotation, transform.rot)
  return Transform(newPos, newRot)
end

---Rotates point around a pivot point
---@param point Vec Point to rotate
---@param pivot Vec Pivot point
---@param rotation Quat Rotation
function Math.RotateAroundPivot(point, pivot, rotation)
  local relative = VecSub(point, pivot)
  return VecAdd(pivot, QuatRotateVec(rotation, relative))
end

---Rotates transform around axis stemming from pivot
---@param transform Transform
---@param axis Vec axis vector (normalized)
---@param angle number angle (counterclockwise, degrees)
---@param pivotOffset Vec __optional__ pivot position (in the same space as transform)
---@return Transform
function Math.RotateTransformAroundAxis(transform, axis, pivot, angle)
  local deltaRotation = QuatAxisAngle(axis, angle)
  return Transform(
    VecAdd(QuatRotateVec(deltaRotation, VecSub(transform.pos, pivot)), pivot),
    QuatRotateQuat(deltaRotation, transform.rot)
  )
end


-- https://easings.net

--
-- Ease in
--

function Math.easeIn2(x)
  return x^2
end

function Math.easeIn3(x)
  return x^3
end

function Math.easeInExp(x)
  if x == 0 then
    return 0
  end

  return 2 ^ (10 * x - 10)
end

--
-- Ease out
--

function Math.easeOut2(x)
  return 1 - (1 - x) ^ 2;
end

function Math.easeOut3(x)
  return 1 - (1 - x) ^ 3;
end


function Math.easeOutExp(x)
  if x == 1 then
    return 1
  end

  return 1 - 2 ^ (-10 * x)
end

function Math.easeOutElastic(x)
  local c4 = (2 * math.pi) / 3;
  if x == 0 then
    return 0
  elseif x == 1 then
    return 0
  else
    return math.pow(2, -10 * x) * math.sin((x * 10 - 0.75) * c4) + 1
  end
end
