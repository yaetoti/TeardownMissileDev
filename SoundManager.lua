#version 2

if not SoundManager then
  SoundManager = {}

  function SoundManager:Init()
    client.sounds = {
      wings = LoadSound("MOD/snd/wings.ogg", 5),
      explosion = LoadSound("MOD/snd/explosion.ogg", 200),
    }

    -- TODO unload sounds
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
    volume = volume or 1.0
    registerVolume = registerVolume or true
    pitch = pitch or 1.0
    PlaySound(client.sounds[soundId], pos)
  end
end