ClientMissile = {}
ClientMissile.__index = ClientMissile

-- Old model
-- Server spawns bodies
-- Server passes only body id only to the corresponding client
-- Updates are propagated by game api SetBodyTransform from the server. Clients don't store missile model
-- Updates are happening in server:update(), which updates physics. server interpolated position in server.tick() and user SetBodyTransform again

-- New model
-- Server creates missile models for players and stores them in shared
-- Client creates ClientMissile wrapper for every new model
-- - Creates the actual body and sets its transform
-- - Updates local model simulation using own deltaTime
-- - Replaces model with the new one from server when updated (track local time?)

-- Non-host lag sources:
-- - Low update() tickrate (but server interpolation didn't change shit)
-- - Low bandwidth (but smoke runs properly. input lags though)

-- Moving to shared may fix network issues depending on how it's prioritized
-- Moving server updates to tick may fix tickrate issues
-- Adding client interpolation fixes reliance on network SetBodyTransform: if issue was prioritization


-- TODO smart
-- Why not update issue? Because tick() interpolation would have helped
-- But interpolation also uses SetBodyTransform. What if it's updated in update()?
-- But friend's client wasn't lagging visually. Maybe only updates. Maybe network latency
-- Not latency because smoke is delivered on time

-- Then it means that clients should spawn bodies themselves


-- TODO test with network lag utility



-- Plan
-- + Add facade addition/removal
-- - Add facades updates
-- - Add facade code

function ClientMissile.new(model)
  local obj = {}
  obj.__type = "ClientMissile"

  obj.model = model

  return setmetatable(obj, ClientMissile)
end

function ClientMissile:destroy()

end

function ClientMissile:tick(deltaTime)

end
