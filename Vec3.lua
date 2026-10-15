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
    __type = "Vec3",
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

function Vec3.lerp(v1, v2, t)
  return Vec3.new(
    Math.lerp(v1[1], v2[1], t),
    Math.lerp(v1[2], v2[2], t),
    Math.lerp(v1[3], v2[3], t)
  )
end

function Vec3:sign()
  return Vec3.new(
    Math.sign(self[1]),
    Math.sign(self[2]),
    Math.sign(self[3])
  )
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

function Vec3:values()
  return self[1], self[2], self[3]
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
