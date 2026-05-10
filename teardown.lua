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