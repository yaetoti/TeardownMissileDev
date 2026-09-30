#version 2

-- https://easings.net

if not Math then
  Math = {}
  Math.EPSILON = 0.000001

  ---@return Vec component of v1, perpendicular to v2
  function Math.VecOrthogonalize(v1, v2)
    local v1AlongV2 = VecScale(v1, VecDot(v1, v2))
    return VecSub(v1, v1AlongV2)
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

  ---Rotates transform around a pivot point
  ---@param transform Transform Transform to rotate
  ---@param pivot Vec Pivot point
  ---@param rotation Quat Rotation to apply to the transform
  function Math.RotateAround(transform, pivot, rotation)
    local relative = VecSub(transform.pos, pivot)
    local newPos = VecAdd(pivot, QuatRotateVec(rotation, relative))
    local newRot = QuatRotateQuat(rotation, transform.rot)
    return Transform(newPos, newRot)
  end
end
