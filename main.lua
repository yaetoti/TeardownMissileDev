#version 2
#include "ClientController.lua"
#include "ServerController.lua"
#include "RPC.lua"
#include "Missile.lua"
#include "Player.lua"

-- TODO remove
debugMissile = false
debugDetach = false
debugFreeCamera = false

ToolTabletId = "tablet"

-- How much missiles can we create at once? One.

--Inside game
-- +[create missile and control it]
-- [control the launched missile again]
-- [blow up the launched missile]

--Inside missile
-- [leave missile]
-- +[blow up missile]
-- +[input]
