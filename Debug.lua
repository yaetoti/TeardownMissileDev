if not Debug then
  Debug = {}

  function Debug.Vec(pos, vec)
    DebugLine(pos, VecAdd(pos, vec))
  end

  function Debug.VecInTransform(transform, pos, vec)
    local worldPos = TransformToParentPoint(transform, pos)
    local worldVec = TransformToParentVec(transform, vec)
    DebugLine(worldPos, VecAdd(worldPos, worldVec))
  end

  function Debug.PosInTransform(transform, pos)
    local worldPos = TransformToParentPoint(transform, pos)
    DebugCross(worldPos)
  end
end