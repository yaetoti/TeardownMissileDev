### Goals

- Improve network performance under load

### TODO

- Decouple missile model's code from the Missile itself. Model should only predict the coords / speed / etc
- Store missiles' model data in shared. Currently, it's not stored anywhere, but passed from the RPC to the specific client. Bodies are currently synchronized by the engine.
- Make clients spawn/delete/update missile bodies
- Add client side prediction

### v1.2 - Network Performance Update

- Upgraded api.lua and some functions to match the new JetBrains Lua plugin's comment style. '?' and multiple return values are now supported
- 

### v1.1 - Settings UI Update

### v1.0 - Release