#version 2

if not Debug then
  Debug = {}

  function Debug.Vec(vec, pos)
    DebugLine(pos, VecAdd(pos, vec))
  end

  function Debug.VecInTransform(vec, transform)
    DebugLine(
      transform.pos,
      TransformToParentPoint(transform, vec)
    )
  end

  function Debug.VecInBasis(vec, right, up, forward)
    DebugLine(
      transform.pos,
      TransformToParentPoint(transform, vec)
    )
  end
end