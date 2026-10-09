#version 2
#include "Utils.lua"

if not Mat3 then
  ---@class Mat3
  Mat3 = {}
  Mat3.__index = Mat3

  ---Create matrix from 9 numbers (row-major order)
  function Mat3.new(m11, m12, m13, m21, m22, m23, m31, m32, m33)
    local self = setmetatable({}, Mat3)
    self.m11, self.m12, self.m13 = m11, m12, m13
    self.m21, self.m22, self.m23 = m21, m22, m23
    self.m31, self.m32, self.m33 = m31, m32, m33
    return self
  end

  ---Create zero matrix
  function Mat3.zero()
    return Mat3.new(
      0, 0, 0,
      0, 0, 0,
      0, 0, 0
    )
  end

  ---Create identity matrix
  function Mat3.identity()
    return Mat3.new(
      1, 0, 0,
      0, 1, 0,
      0, 0, 1
    )
  end

  ---Create matrix from row vectors
  function Mat3.fromRowVecs(v1, v2, v3)
    return Mat3.new(
      v1[1], v1[2], v1[3],
      v2[1], v2[2], v2[3],
      v3[1], v3[2], v3[3]
    )
  end

  ---Create matrix from column vectors
  function Mat3.fromColVecs(v1, v2, v3)
    return Mat3.new(
      v1[1], v2[1], v3[1],
      v1[2], v2[2], v3[2],
      v1[3], v2[3], v3[3]
    )
  end

  function Mat3:clone()
    return Mat3.new(
      self.m11, self.m12, self.m13,
      self.m21, self.m22, self.m23,
      self.m31, self.m32, self.m33
    )
  end

  ---@param s number Multiplier
  function Mat3:scale(s)
    return Mat3.new(
      self.m11 * s, self.m12 * s, self.m13 * s,
      self.m21 * s, self.m22 * s, self.m23 * s,
      self.m31 * s, self.m32 * s, self.m33 * s
    )
  end

  ---Matrix multiplication
  ---@param other Mat3
  function Mat3:mul(other)
    return Mat3.new(
      self.m11 * other.m11 + self.m12 * other.m21 + self.m13 * other.m31,
      self.m11 * other.m12 + self.m12 * other.m22 + self.m13 * other.m32,
      self.m11 * other.m13 + self.m12 * other.m23 + self.m13 * other.m33,

      self.m21 * other.m11 + self.m22 * other.m21 + self.m23 * other.m31,
      self.m21 * other.m12 + self.m22 * other.m22 + self.m23 * other.m32,
      self.m21 * other.m13 + self.m22 * other.m23 + self.m23 * other.m33,

      self.m31 * other.m11 + self.m32 * other.m21 + self.m33 * other.m31,
      self.m31 * other.m12 + self.m32 * other.m22 + self.m33 * other.m32,
      self.m31 * other.m13 + self.m32 * other.m23 + self.m33 * other.m33
    )
  end

  ---Multiply row vector (1x3) by matrix (returns 1x3 vector)
  function Mat3:mulRowVec(v)
    return {
      v[1] * self.m11 + v[2] * self.m21 + v[3] * self.m31,
      v[1] * self.m12 + v[2] * self.m22 + v[3] * self.m32,
      v[1] * self.m13 + v[2] * self.m23 + v[3] * self.m33
    }
  end

  ---Multiply matrix by column vector (3x1) (returns 3x1 vector)
  function Mat3:mulColVec(v)
    return Vec(
      self.m11 * v[1] + self.m12 * v[2] + self.m13 * v[3],
      self.m21 * v[1] + self.m22 * v[2] + self.m23 * v[3],
      self.m31 * v[1] + self.m32 * v[2] + self.m33 * v[3]
    )
  end

  function Mat3:transpose()
    return Mat3.new(
      self.m11, self.m21, self.m31,
      self.m12, self.m22, self.m32,
      self.m13, self.m23, self.m33
    )
  end

  function Mat3:det()
    return self.m11 * (self.m22 * self.m33 - self.m23 * self.m32)
      - self.m12 * (self.m21 * self.m33 - self.m23 * self.m31)
      + self.m13 * (self.m21 * self.m32 - self.m22 * self.m31)
  end

  function Mat3:inverse()
    local d = self:det()
    if d == 0 then
      return nil
    end

    local invDet = 1 / d
    return Mat3.new(
      (self.m22 * self.m33 - self.m23 * self.m32) * invDet,
      (self.m13 * self.m32 - self.m12 * self.m33) * invDet,
      (self.m12 * self.m23 - self.m13 * self.m22) * invDet,

      (self.m23 * self.m31 - self.m21 * self.m33) * invDet,
      (self.m11 * self.m33 - self.m13 * self.m31) * invDet,
      (self.m13 * self.m21 - self.m11 * self.m23) * invDet,

      (self.m21 * self.m32 - self.m22 * self.m31) * invDet,
      (self.m12 * self.m31 - self.m11 * self.m32) * invDet,
      (self.m11 * self.m22 - self.m12 * self.m21) * invDet
    )
  end
end

if not Vec3 then
  ---non-index operations should return a new vector
  ---@class Vec3
  Vec3 = {}
  Vec3.__index = function(t, k)
    if k == "x" then return rawget(t, 1)
    elseif k == "y" then return rawget(t, 2)
    elseif k == "z" then return rawget(t, 3)
    else return rawget(Vec3, k)
    end
  end

  Vec3.__newindex = function(t, k, v)
    if k == "x" then rawset(t, 1, v)
    elseif k == "y" then rawset(t, 2, v)
    elseif k == "z" then rawset(t, 3, v)
    else rawset(t, k, v)
    end
  end

  ---@return Vec3 New vector
  function Vec3.new(x, y, z)
    local obj = {
      x or 0,
      y or 0,
      z or 0,
    }
    return setmetatable(obj, Vec3)
  end

  ---@return Vec3 New vector
  function Vec3.from(v)
    return Vec3.new(v[1], v[2], v[3])
  end

  ---@return Vec3
  function Vec3.__unm(v)
    return Vec3.new(-v[1], -v[2], -v[3])
  end

  ---@return Vec3
  function Vec3.__add(a, b)
    if type(a) == "number" then
      return Vec3.new(a + b[1], a + b[2], a + b[3])
    end

    if type(b) == "number" then
      return Vec3.new(a[1] + b, a[2] + b, a[3] + b)
    end

    if type(a) == "table" and type(b) == "table" then
      return Vec3.new(a[1] + b[1], a[2] + b[2], a[3] + b[3])
    end

    error("unsupported vec3 addition operand:"..type(b), 2)
  end

  ---@return Vec3
  function Vec3.__sub(a, b)
    if type(a) == "number" then
      return Vec3.new(a - b[1], a - b[2], a - b[3])
    end

    if type(b) == "number" then
      return Vec3.new(a[1] - b, a[2] - b, a[3] - b)
    end

    if type(a) == "table" and type(b) == "table" then
      return Vec3.new(a[1] - b[1], a[2] - b[2], a[3] - b[3])
    end

    error("unsupported vec3 subtraction operand:"..type(b), 2)
  end

  ---@return Vec3
  function Vec3.__mul(a, b)
    if type(a) == "number" then
      return Vec3.new(a * b[1], a * b[2], a * b[3])
    end

    if type(b) == "number" then
      return Vec3.new(a[1] * b, a[2] * b, a[3] * b)
    end

    if type(a) == "table" and type(b) == "table" then
      return Vec3.new(a[1] * b[1], a[2] * b[2], a[3] * b[3])
    end

    error("unsupported vec3 multiplication operand:"..type(b), 2)
  end

  ---@return Vec3
  function Vec3.__div(a, b)
    if type(a) == "number" then
      return Vec3.new(a / b[1], a / b[2], a / b[3])
    end

    if type(b) == "number" then
      return Vec3.new(a[1] / b, a[2] / b, a[3] / b)
    end

    if type(a) == "table" and type(b) == "table" then
      return Vec3.new(a[1] / b[1], a[2] / b[2], a[3] / b[3])
    end

    error("unsupported vec3 division operand:"..type(b), 2)
  end

  function Vec3.__tostring(v)
    return string.format("Vec3(%.3f, %.3f, %.3f)", v[1], v[2], v[3])
  end

  ---@return Vec3
  function Vec3:clone()
    return Vec3.new(self[1], self[2], self[3])
  end

  ---@return Vec3
  function Vec3:with(x, y, z)
    return Vec3.new(
      x or self.x,
      y or self.y,
      z or self.z
    )
  end

  function Vec3:invertX()
    return Vec3.new(-self.x, self.y, self.z)
  end

  function Vec3:invertY()
    return Vec3.new(self.x, -self.y, self.z)
  end

  function Vec3:invertZ()
    return Vec3.new(self.x, self.y, -self.z)
  end

  function Vec3:invertXY()
    return Vec3.new(-self.x, -self.y, self.z)
  end

  function Vec3:invertXZ()
    return Vec3.new(-self.x, self.y, -self.z)
  end

  function Vec3:invertYZ()
    return Vec3.new(self.x, -self.y, -self.z)
  end

  function Vec3:length()
    return math.sqrt(self[1] * self[1] + self[2] * self[2] + self[3] * self[3])
  end

  function Vec3:length2()
    return self[1] * self[1] + self[2] * self[2] + self[3] * self[3]
  end

  ---@return Vec3, number Normalized vector, original length
  function Vec3:normalize()
    local len = self:length()
    -- TODO relative length might be better, but more expensive
    if len < Math.EPSILON then
      return Vec3.new(0, 0, 0), 0
    end
    return Vec3.new(self[1] / len, self[2] / len, self[3] / len), len
  end

  ---@param v Vec
  ---@return number
  function Vec3:dot(v)
    if v == nil then
      error("NIL", 3)
    end

    return self[1] * v[1] + self[2] * v[2] + self[3] * v[3]
  end

  ---@param v Vec
  ---@return Vec3
  function Vec3:cross(v)
    return Vec3.new(
      self[2] * v[3] - self[3] * v[2],
      self[3] * v[1] - self[1] * v[3],
      self[1] * v[2] - self[2] * v[1]
    )
  end

  ---Project vector onto another vector
  ---@param v Vec3
  ---@return Vec3
  function Vec3:project(v)
    return v * self:dot(v)
  end

  ---Project vector onto a plane with normal v
  ---@param v Vec3
  ---@return Vec3 Component of vector, perpendicular to vector v
  function Vec3:orthogonalize(v)
    return self - self:project(v)
  end

  ---@return number Angle between vectors [0; 180] (radians)
  function Vec3:angle(v)
    return math.acos(Math.clamp(self:normalize():dot(v:normalize()), -1, 1))
  end

  ---@return number Angle between vectors [0; 180] (radians)
  function Vec3:angleUnsafe(v)
    return math.acos(self:dot(v))
  end

  ---@return number Angle between vector and plane [-90; 90] (radians)
  function Vec3:anglePlane(n)
    -- dot can be 1.00000000000002 and asin returns nan
    return math.asin(Math.clamp(self:normalize():dot(n:normalize()), -1, 1))
  end

  ---@param n Vec3 plane normal
  ---@return number Angle between vector and plane [-90; 90] (radians)
  function Vec3:anglePlaneUnsafe(n)
    return math.asin(self:dot(n))
  end

  ---Transforms vector into basis. Assumes that basis vectors are orthogonal. Uses Teardown's RH coordinate system, where -Z forward is preserved.
  ---@param right Vec3 right basis vector
  ---@param up Vec3 vector basis vector
  ---@param forward Vec3 vector basis vector
  ---@return Vec3
  function Vec3:toBasis(right, up, forward)
    return Vec3.new(
      self:dot(right),
      self:dot(up),
      self:dot(-forward)
    )
  end

  function Vec3:toTransformPos(transform)
    return Vec3.from(TransformToLocalPoint(transform, self))
  end

  function Vec3:toTransformVec(transform)
    return Vec3.from(TransformToLocalVec(transform, self))
  end

  ---Transforms vector out of basis. Assumes that basis vectors are orthogonal. Uses Teardown's RH coordinate system, where -Z forward is preserved.
  ---@param right Vec right basis vector
  ---@param up Vec vector basis vector
  ---@param forward Vec vector basis vector
  ---@return Vec3
  function Vec3:fromBasis(right, up, forward)
    return Vec3.new(
      self[1] * right[1] + self[2] * up[1] + self[3] * -forward[1],
      self[1] * right[2] + self[2] * up[2] + self[3] * -forward[2],
      self[1] * right[3] + self[2] * up[3] + self[3] * -forward[3]
    )
  end

  function Vec3:fromTransformPos(transform)
    return Vec3.from(TransformToParentPoint(transform, self))
  end

  function Vec3:fromTransformVec(transform)
    return Vec3.from(TransformToParentVec(transform, self))
  end

  ---@param q Quat
  function Vec3:rotate(q)
    return Vec3.from(QuatRotateVec(q, self))
  end

  ---Rotate around axis
  ---@param axis Vec3 Rotation axis (normalized)
  ---@param angle number Angle in radians (counterclockwise, right hand rule)
  function Vec3:rotateAround(axis, angle)
    -- https://en.wikipedia.org/wiki/Rodrigues%27_rotation_formula
    local c, s = math.cos(angle), math.sin(angle)
    return self * c + axis:cross(self) * s + axis * (axis:dot(self) * (1 - c))
  end
end

if not Math then
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
end
