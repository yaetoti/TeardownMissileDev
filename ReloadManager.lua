#include "Vec3.lua"
#include "Player.lua"
#include "Missile.lua"
#include "ControlsWidget.lua"

-- Restores metatables after save/load

-- Usage:
-- - markLoaded() from server.init() and client.init(). This sets initialized to true
-- - if isReload(): initRegistry(), reload(), markLoaded() from server.tick() and client.tick(). This restores metatables

-- hasInitialized: false before first load, always true after first load (because engine restores it)
-- vmReloaded: local, not serialized, always true after init

-- Values:
-- false, true - First init
-- true, true - Reload

ReloadManager = {}
ReloadManager.hasInitialized = false
local vmReloaded = true

-- should be local, because tables get other handle after reload
local CLASS_REGISTRY = {}

local function restoreMetatables(t, visited)
  if type(t) ~= "table" then return end

  visited = visited or {}
  if visited[t] then return end
  visited[t] = true

  local mt = CLASS_REGISTRY[t.__type]
  if mt then
    setmetatable(t, mt)
  end

  for k, v in pairs(t) do
    restoreMetatables(k, visited)
    restoreMetatables(v, visited)
  end
end

function ReloadManager.initRegistry()
  -- This should not be filled in the global scope, but here, because of the order of save/load
  -- - Global context execution, variables are set
  -- - Old values are deserialized and they replace global variables (that's why we cannot set registry in global space, links will be to a different object)
  -- - server.tick(), client.tick()
  CLASS_REGISTRY = {
    ["Vec3"] = Vec3,
    ["Player"] = Player,
    ["Missile"] = Missile,
    ["ControlsWidget"] = ControlsWidget,
  }
end

function ReloadManager.markLoaded()
  ReloadManager.hasInitialized = true
  vmReloaded = false
end

function ReloadManager.isFirstRun()
  return vmReloaded and not ReloadManager.hasInitialized
end

function ReloadManager.isReload()
  return vmReloaded and ReloadManager.hasInitialized
end

function ReloadManager.reload()
  restoreMetatables(_G)
end
