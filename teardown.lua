---@class Vec
---@field x number
---@field y number
---@field z number

---@class Quat
---@field x number
---@field y number
---@field z number
---@field w number

---@class Transform
---@field pos Vec
---@field rot Quat



---Display message on screen. The last 20 lines are displayed. The function will also recognize tables and convert them to strings automatically.
---@param message string Message to display
---@param lineWrapping boolean True if you need to wrap Table lines. Works only with tables (optional)
function DebugPrint(message, lineWrapping) end



---Create new vector and optionally initializes it to the provided values. A Vec is equivalent to a regular lua table with three numbers.
---@param x number X value (optional)
---@param y number Y value (optional)
---@param z number Z value (optional)
---@return Vec New vector
function Vec(x, y, z) end

---Copy of org vector. Use this instead of direct assignment for vectors.
---@param org Vec A vector
---@return Vec Copy of org vector
function VecCopy(org) end

---Returns the string representation of a vector.
---@param vector Vec The input vector
---@return string String representation of the vector
function VecStr(vector) end

---Calculates the length (magnitude) of the vector.
---@param vec Vec A vector
---@return number Length (magnitude) of the vector
function VecLength(vec) end

---Returns a normalized version of the input vector (unit length). Returns {0,0,1} if input is zero length.
---@param vec Vec A vector
---@return Vec A vector of length 1.0
function VecNormalize(vec) end

---Returns a new vector with the input vector scaled by a factor.
---@param vec Vec The input vector
---@param scale number The scale factor
---@return Vec A scaled version of input vector
function VecScale(vec, scale) end

---Calculates the sum of two vectors (a + b).
---@param a Vec First vector
---@param b Vec Second vector
---@return Vec New vector with sum of a and b
function VecAdd(a, b) end

---Calculates the difference between two vectors (a - b).
---@param a Vec First vector
---@param b Vec Second vector
---@return Vec New vector representing a-b
function VecSub(a, b) end

---Calculates the dot product of two vectors.
---@param a Vec First vector
---@param b Vec Second vector
---@return number Dot product of a and b
function VecDot(a, b) end

---Calculates the cross product (vector product) of two vectors.
---@param a Vec First vector
---@param b Vec Second vector
---@return Vec Cross product of a and b
function VecCross(a, b) end

---Linearly interpolated vector between a and b, using t.
---@param a Vec Start vector
---@param b Vec End vector
---@param t number Fraction (usually between 0.0 and 1.0)
---@return Vec Linearly interpolated vector between a and b, using t
function VecLerp(a, b, t) end




---@param x number
---@param y number
---@param z number
---@param w number
---@return Quat
function Quat(x, y, z, w) end

---@param org Quat Quaternion
---@return Quat
function QuatCopy(org) end

---@param x number Roll, angle around X axis in degrees
---@param y number Yaw, angle around Y axis in degrees
---@param z number Pitch, angle around Z axis in degrees
---@return Quat
function QuatEuler(x, y, z) end

---@param eye Vec Vector representing the camera location
---@param target Vec Vector representing the point to look at
---@return Quat
function QuatLookAt(eye, target) end

---@param a Quat
---@param b Quat
---@return Quat
function QuatRotateQuat(a, b) end

---@param a Quat – Quaternion
---@param vec Vec – Vector
function QuatRotateVec(a, vec) end

---Spherical, linear interpolation between a and b, using t. This is very useful for animating between two rotations.
---@param a Quat
---@param b Quat
---@param t number fraction (usually between 0.0 and 1.0)
---@return Quat
function QuatSlerp(a, b, t) end

---Create a quaternion representing a rotation between the input vectors that doesn't need to be of unit-length
---@param vector0 Vec
---@param vector1 Vec
---@return Quat
function QuatDeltaVectors(vector0, vector1) end

---Return euler angles from quaternion
---@param quat Quat – Quaternion
---@return number, number, number X, Y, Z
function GetQuatEuler(quat) end



---Create a new transform. If only one argument is provided, it assumes no rotation (identity quaternion).
---@param pos Vec Vector representing transform position (optional)
---@param rot Quat Quaternion representing transform rotation (optional)
---@return Transform New transform
function Transform(pos, rot) end

---Creates a copy of an existing transform.
---@param org Transform The source transform
---@return Transform Copy of org transform
function TransformCopy(org) end

---Returns the string representation of a transform.
---@param transform Transform The transform to represent
---@return string String representation of the transform
function TransformStr(transform) end

---Transforms child transform out of the parent transform (World space).
---@param parent Transform Parent's world transform
---@param child Transform Child's local transform relative to its body
---@return Transform New transform representing child in world space
function TransformToParentTransform(parent, child) end

---Transforms one transform into the local space of another transform.
---@param parent Transform The target parent transform
---@param child Transform The source child transform
---@return Transform New transform relative to the parent
function TransformToLocalTransform(parent, child) end

---Transforms vector v out of transform t by considering rotation only (World space).
---@param t Transform The world transform defining orientation
---@param v Vec The vector to transform
---@return Vec Transformed vector in world space
function TransformToParentVec(t, v) end

---Transforms vector v into the local space of transform t by considering rotation only.
---@param t Transform The target transform's orientation
---@param v Vec The original vector (assumed to be in world space or some consistent base frame)
---@return Vec Transformed vector relative to t
function TransformToLocalVec(t, v) end

---Transforms position p out of transform t (World space).
---@param t Transform The world transform defining the coordinate system origin
---@param p Vec Vector representing position in local space
---@return Vec Transformed position in world space
function TransformToParentPoint(t, p) end

---Transforms position p into the local space of transform t.
---@param t Transform The target transform's coordinate system
---@param p Vec Vector representing position (assumed to be in world space)
---@return Vec Transformed position relative to t
function TransformToLocalPoint(t, p) end



---@param playerId number Player ID. On client, zero means client player. On server, zero means server (host) player.
---@return Transform Current player transform
function GetPlayerTransform(playerId) end

---The player eye transform is the same as what you get from GetCameraTransform when playing in first-person, but if you have set a camera transform manually with SetCameraTransform or playing in third-person, you can retrieve the player eye transform with this function
---@param playerId number Player ID
---@return Transform
function GetPlayerEyeTransform(playerId) end

---Instantly teleport the player to desired transform, excluding pitch. If you want to include pitch, use SetPlayerTransformWithPitch instead. Player velocity will be reset to zero.
---@param transform Transform
---@param playerId number
function SetPlayerTransform(transform, playerId) end

---@param playerId number Player ID. On client, zero means client player. On server, zero means server (host) player.
---@return Transform Current player transform, including pitch (look up/down)
function GetPlayerTransformWithPitch(playerId) end

---Instantly teleport the player to desired transform, including pitch. Player velocity will be reset to zero.
---@param transform Transform Desired player transform
---@param playerId number Player ID. On server, zero means server (host) player.
function SetPlayerTransformWithPitch(transform, playerId) end

---@param playerId number Player ID. On client, zero means client player. On server, zero means server (host) player.
---@return Vec Player velocity in world space as vector
function GetPlayerVelocity(playerId) end

---@param velocity Vec Player velocity in world space as vector
---@param playerId number Player ID. On server, zero means server (host) player.
function SetPlayerVelocity(velocity, playerId) end

---Disable input for a player. Should be called from tick.
---@param playerId number Player to disable
function DisablePlayerInput(player) end

---Will be false if player is in vehicle, interacting with a screen, has pause menu open, is dead or uses interactive UI.
---@param player number Player ID. On client, zero means client player. On server, zero means server (host) player.
---@return boolean
function GetPlayerCanUseTool(player) end




---Sets the body transform
---@param handle number Body handle
---@param transform Transform – Desired transform
function SetBodyTransform(handle, transform) end

---Return the size of a shape in voxels
---@param handle number Shape handle
---@return number xsize: Size in voxels along x axis
---@return number ysize: Size in voxels along y axis
---@return number zsize: Size in voxels along z axis
---@return number scale: The size of one voxel in meters (with default scale it is 0.1)
function GetShapeSize(handle) end

---The first argument can be either a prefab XML file in your mod folder or a string with XML content. It is also possible to spawn prefabs from other mods, by using the mod id followed by colon, followed by the prefab path. Spawning prefabs from other mods should be used with caution since the referenced mod might not be installed.
---@param xml string File name or xml string
---@param transform Transform Spawn transform
---@param allowStatic boolean __optional__ Allow spawning static shapes and bodies (default false)
---@param jointExisting boolean __optional__ Allow joints to connect to existing scene geometry (default false)
---@return table Indexed table with handles to all spawned entities
function Spawn(xml, transform, allowStatic, jointExisting) end

---(Server only) Register a custom tool that will show up in the player inventory and can be selected with scroll wheel. Do this only once per tool. Tools are disabled by default after RegisterTool and must be enabled per player using SetToolEnabled before they can be selected or used.
---@param id string Tool unique identifier
---@param name string Tool name to show in hud
---@param file string Path to vox file or prefab xml
---@param group number __optional__ – Tool group for this tool (1-6) Default is 6.
function RegisterTool(id, name, file, group) end

---(Server only)
---@param toolId string Tool ID
---@param enabled boolean Tool enabled
---@param playerId number __optional__ Player ID
function SetToolEnabled(toolId, enabled, playerId) end



---@return table List of added player Ids
function GetAddedPlayers() end

---@return table List of removed player Ids
function GetRemovedPlayers() end

---@return table List of all player Ids
function GetAllPlayers() end

---@return number Number of players
function GetPlayerCount() end


---@param input string The input identifier
---@param playerId number __optional__ Player ID. On client, zero means client player. On server, zero means server (host) player.
---@return boolean True if input was pressed during last frame
function InputPressed(input, playerId) end

---@param input string The input identifier
---@param playerId number __optional__ Player ID. On client, zero means client player. On server, zero means server (host) player.
---@return boolean True if input was released during last frame
function InputReleased(input, playerId) end

---@param input string The input identifier
---@param playerId number __optional__ Player ID. On client, zero means client player. On server, zero means server (host) player.
---@return boolean True if input is currently held down
function InputDown(input, playerId) end
