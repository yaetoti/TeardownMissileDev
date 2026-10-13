SoundManager = {}

-- TODO make a separate table for [name -> id] map? I mean, how many entries can we potentially have, cmon brow

---@class SoundLoop
---@field name string Name of the loop on client
---@field id number Id of the loop instance on the server
---@field pos Vec position
---@field volume number
---@field registerVolume boolean
---@field pitch number

---@type SoundLoop[]
shared.soundLoops = {}
server.nextLoopId = 1

function SoundManager:init()
  client.sounds = {
    wings = LoadSound("MOD/snd/wings.ogg", 10),
    marker_success = LoadSound("MOD/snd/marker_success.ogg", 10),
    marker_fail = LoadSound("MOD/snd/marker_fail.ogg", 10),
  }

  client.loops = {
    engine = LoadLoop("MOD/snd/engine.ogg", 2000),
  }
end

function SoundManager:destroy()
  -- Unload sounds
  for _, handle in pairs(client.sounds) do
    UnloadSound(handle)
  end

  -- Unload loops
  for _, handle in pairs(client.loops) do
    UnloadLoop(handle)
  end
end

function SoundManager:updateLoops()
  for _, loop in pairs(shared.soundLoops) do
    if loop.volume > Math.EPSILON then
      PlayLoop(client.loops[loop.name], loop.pos, loop.volume, loop.registerVolume, loop.pitch)
    end
  end
end

---@param soundId string Sound ID
---@param pos Vec __optional__ World position as vector. Default is player position.
---@param volume number __optional__ Playback volume. Default is 1.0
---@param registerVolume boolean __optional__ Register position and volume of this sound for GetLastSound. Default is true
---@param pitch number __optional__ Playback pitch. Default 1.0
function server.PlaySoundClientRpc(playerId, soundId, pos, volume, registerVolume, pitch)
  ClientCall(playerId, "client.PlaySoundClientRpc", soundId, pos, volume, registerVolume, pitch)
end

---@param soundId string Sound ID
---@param pos Vec __optional__ World position as vector. Default is player position.
---@param volume number __optional__ Playback volume. Default is 1.0
---@param registerVolume boolean __optional__ Register position and volume of this sound for GetLastSound. Default is true
---@param pitch number __optional__ Playback pitch. Default 1.0
function client.PlaySoundClientRpc(soundId, pos, volume, registerVolume, pitch)
  pos = pos or GetPlayerTransform().pos
  -- TODO pass optional params and investigate why I didnt do that (it wasn't playing, as I recall)
  volume = volume or 1.0
  registerVolume = registerVolume or true
  pitch = pitch or 1.0
  PlaySound(client.sounds[soundId], pos)
end

function client.PlaySound(soundId, pos, volume, registerVolume, pitch)
  pos = pos or GetPlayerTransform().pos
  volume = volume or 1.0
  registerVolume = registerVolume or true
  pitch = pitch or 1.0
  PlaySound(client.sounds[soundId], pos, volume, registerVolume, pitch)
end

---@param name string Name of the loop
function server.CreateLoop(name, pos, volume, registerVolume, pitch)
  local id = server.nextLoopId
  server.nextLoopId = server.nextLoopId + 1

  shared.soundLoops[id] = {
    name = name,
    id = id,
    pos = pos or {},
    volume = volume or 1.0,
    registerVolume = registerVolume or true,
    pitch = pitch or 1.0
  }

  return id
end

function server.DeleteLoop(id)
  shared.soundLoops[id] = nil
end