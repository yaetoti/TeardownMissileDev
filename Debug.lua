Debug = {}

function Debug.Vec(pos, vec)
  DebugLine(pos, VecAdd(pos, vec))
end

function Debug.VecInTransform(transform, pos, vec)
  local worldPos = TransformToParentPoint(transform, pos)
  local worldVec = TransformToParentVec(transform, vec)
  DebugLine(worldPos, VecAdd(worldPos, worldVec))
end

function Debug.LineInTransform(transform, p1, p2)
  local worldP1 = TransformToParentPoint(transform, p1)
  local worldP2 = TransformToParentPoint(transform, p2)
  DebugLine(worldP1, worldP2)
end

function Debug.PosInTransform(transform, pos)
  local worldPos = TransformToParentPoint(transform, pos)
  DebugCross(worldPos)
end