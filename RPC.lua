function client.createMissileServerRpc(detonationTimer)
  if client.activeRequests.createMissile or client.isControllingMissile then
    return
  end

  client.activeRequests.createMissile = true
  ServerCall("server.createMissileServerRpc", GetLocalPlayer(), detonationTimer)
end

function server.createMissileServerRpc(clientId, detonationTimer)
  local player = server.players[clientId]
  if not player or player.isControllingMissile then
    -- Reject
    server.createMissileResponseClientRpc(clientId, false)
    return
  end

  -- Create missile
  -- TODO this causes race conditions. Maybe it's better to copy models into shared?
  local missile, missileId = server.createMissile()
  missile.ownerId = clientId
  missile.detonationTimer = detonationTimer

  if debugMissile then
    missile:setTransform(Transform(Vec(0, 2, 6)))
  elseif debugFixedSpawn then
    missile:setTransform(Transform(Vec(0, 80, 500)))
    missile.model.velocity = missile.model.forward * 25
  else
    missile:setTransform(server.randomSpawnTransform())
    missile.model.velocity = missile.model.forward * 25
  end

  -- Update status
  player.isControllingMissile = true
  player.controlledMissileId = missileId

  -- Send confirmation and body
  server.createMissileResponseClientRpc(clientId, true, missileId)
end

function server.createMissileResponseClientRpc(clientId, approval, missileId)
  ClientCall(clientId, "client.createMissileResponseClientRpc", approval, missileId)
end

function client.createMissileResponseClientRpc(approval, missileId)
  client.activeRequests.createMissile = false

  if not approval then
    return
  end

  client.isControllingMissile = true
  client.isDetached = false
  client.missileId = missileId

  client.freeCameraEnabled = false
  client.freeCameraRot = Quat()
end



function server.missileExplodedClientRpc(clientId)
  ClientCall(clientId, "client.missileExplodedClientRpc")
end

function client.missileExplodedClientRpc()
  client.activeRequests.explodeMissile = false

  client.isControllingMissile = false
  client.isDetached = false
  client.pitch = 0.0
  client.yaw = 0.0
  client.roll = 0.0
  client.propulsion = 0.0
end



function client.explodeMissileServerRpc(missileId)
  if not client.isControllingMissile or client.activeRequests.explodeMissile then
    return
  end

  ServerCall("server.explodeMissileServerRpc", GetLocalPlayer(), missileId)
end

function server.explodeMissileServerRpc(clientId, missileId)
  local player = server.players[clientId]
  if not player.isControllingMissile or player.controlledMissileId ~= missileId then
    -- Reject
    server.explodeMissileResponseClientRpc(clientId, false)
    return
  end

  local missile = server.missiles[missileId]
  missile:explode()

  player.isControllingMissile = false
  player.isDetached = false
end



function client.detachRequestServerRpc()
  if client.activeRequests.detach or not client.isControllingMissile or client.isDetached then
    return
  end

  client.activeRequests.detach = true
  ServerCall("server.detachRequestServerRpc", GetLocalPlayer())
end

function server.detachRequestServerRpc(clientId)
  local player = server.players[clientId]
  if not player.isControllingMissile or player.isDetached then
    server.detachResponseServerRpc(clientId, false)
    return
  end

  server.players[clientId].isDetached = true
  server.detachResponseServerRpc(clientId, true)
end

function server.detachResponseServerRpc(clientId, approval)
  ClientCall(clientId, "client.detachResponseServerRpc", approval)
end

function client.detachResponseServerRpc(approval)
  client.activeRequests.detach = false
  if not approval then
    return
  end

  client.isDetached = true
end



function client.reattachRequestServerRpc()
  if client.activeRequests.detach or not client.isControllingMissile or not client.isDetached then
    return
  end

  client.activeRequests.reattach = true
  ServerCall("server.reattachRequestServerRpc", GetLocalPlayer())
end

function server.reattachRequestServerRpc(clientId)
  local player = server.players[clientId]
  if not player.isControllingMissile or not player.isDetached then
    server.reattachResponseServerRpc(clientId, false)
    return
  end

  server.players[clientId].isDetached = false
  server.reattachResponseServerRpc(clientId, true)
end

function server.reattachResponseServerRpc(clientId, approval)
  ClientCall(clientId, "client.reattachResponseServerRpc", approval)
end

function client.reattachResponseServerRpc(approval)
  client.activeRequests.reattach = false
  if not approval then
    return
  end

  client.isDetached = false
end



function client.ToggleWingsDeploymentServerRpc()
  if not client.isControllingMissile then
    return
  end

  ServerCall("server.ToggleWingsDeploymentServerRpc", GetLocalPlayer(), client.missileId)
end

function server.ToggleWingsDeploymentServerRpc(clientId, missileId)
  local player = server.players[clientId]
  if not player.isControllingMissile or player.controlledMissileId ~= missileId then
    return
  end

  local missile = server.missiles[missileId]
  if missile.model.wingsState == MissileModel.WingsState.FOLDED or missile.model.wingsState == MissileModel.WingsState.FOLDING then
    missile:spreadWings()
  elseif missile.model.wingsState == MissileModel.WingsState.SPREAD or missile.model.wingsState == MissileModel.WingsState.SPREADING then
    missile:foldWings()
  end
end



function client.SetInputServerRpc(propulsionInput, pitchInput, yawInput, rollInput)
  if not client.isControllingMissile then
    return
  end

  ServerCall("server.SetInputServerRpc", GetLocalPlayer(), client.missileId, propulsionInput, pitchInput, yawInput, rollInput)
end

function server.SetInputServerRpc(clientId, missileId, propulsionInput, pitchInput, yawInput, rollInput)
  local player = server.players[clientId]
  if not player.isControllingMissile or player.controlledMissileId ~= missileId then
    return
  end

  local missile = server.missiles[missileId]
  missile.model:setInput(
    Math.clamp(pitchInput, -1, 1),
    Math.clamp(yawInput, -1, 1),
    Math.clamp(rollInput, -1, 1),
    Math.clamp01(propulsionInput)
  )
end
