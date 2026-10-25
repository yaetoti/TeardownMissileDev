Settings = {}
Settings.Types = {
  FLOAT = 1,
  BOOL = 2,
}
Settings.OPTIONS = {
  sensitivityX = { default = 0.5, type = Settings.Types.FLOAT },
  sensitivityY = { default = 0.5, type = Settings.Types.FLOAT },
  fastBoot = { default = false, type = Settings.Types.BOOL },

  spawnHeight = { default = 70.0, type = Settings.Types.FLOAT },
  spawnDistance = { default = 500.0, type = Settings.Types.FLOAT },
  detonationTimer = { default = 0.0, type = Settings.Types.FLOAT },
  penetrationThreshold = { default = 0.0, type = Settings.Types.FLOAT },
}

local GetActions = {
  [Settings.Types.FLOAT] = GetFloat,
  [Settings.Types.BOOL] = GetBool,
}
local SetActions = {
  [Settings.Types.FLOAT] = SetFloat,
  [Settings.Types.BOOL] = SetBool,
}


function Settings.GetId(id)
  return "savegame.mod."..id
end

function Settings.Has(id)
  return Settings.OPTIONS[id] ~= nil and HasKey(Settings.GetId(id))
end

function Settings.Get(id)
  return GetActions[Settings.OPTIONS[id].type](Settings.GetId(id))
end

function Settings.Set(id, value)
  local option = Settings.OPTIONS[id]
  return SetActions[option.type](Settings.GetId(id), value)
end


function Settings.init()
  for id, option in pairs(Settings.OPTIONS) do
    if not Settings.Has(id) then
      Settings.Set(id, option.default)
    end
  end
end

function Settings.load()
  local obj = {}
  for id, _ in pairs(Settings.OPTIONS) do
    obj[id] = Settings.Get(id)
  end

  return obj
end

function Settings.save(settings)
  for id, value in pairs(settings) do
    Settings.Set(id, value)
  end
end
