### Register new class

1. Create a metatable

```lua
Missile = {}
Missile.__index = Missile
```

2. Create a constructor `new()`. Set `__type` variable, needed by ReloadManager

```lua
function Missile.new()
  local obj = {
    __type = "Missile",

    ...
  }

  return setmetatable(obj, Missile)
end
```

3. Register type in the ReloadManager. Type names must match (except for the table name, but keep it like that for consistency).

```lua
  #include "Missile.lua"

  ...
  
  CLASS_REGISTRY = {
    ["Vec3"] = Vec3,
    ["Player"] = Player,
    ["Missile"] = Missile,
    ["ControlsWidget"] = ControlsWidget,
    ["TabletUI"] = TabletUI,
  }
```
