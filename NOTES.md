### Register new class

1. Create a metatable

```lua
ServerMissile = {}
ServerMissile.__index = ServerMissile
```

2. Create a constructor `new()`. Set `__type` variable, needed by ReloadManager

```lua
function ServerMissile.new()
  local obj = {
    __type = "Missile",

    ...
  }

  return setmetatable(obj, ServerMissile)
end
```

3. Register type in the ReloadManager. Type names must match (except for the table name, but keep it like that for consistency).

```lua
  #include "ServerMissile.lua"

...

CLASS_REGISTRY = {
  ["Vec3"] = Vec3,
  ["Player"] = Player,
  ["ServerMissile"] = ServerMissile,
  ["ControlsWidget"] = ControlsWidget,
  ["TabletUI"] = TabletUI,
}
```
