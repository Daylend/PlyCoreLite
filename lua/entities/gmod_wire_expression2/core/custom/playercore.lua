E2Lib.RegisterExtension("playercorelite", true)

-- Cache for players currently in the event
local playersInEvent = {}

-- Expose to global scope for testing module
_G.playersInEvent = playersInEvent

-- Commands that don't require boundary checks
local alwaysAllowedCommands = {"resetsettings", "inbounds", "isadminmode", "getplayersinevent"}

local function inEventMode(ply)
	-- Check if player is in the Event Team whitelist and has event mode enabled
	local steamID64 = ply:SteamID64()
	
	-- If no exhibition system is available, return false
	if not Exhibition then
		return false
	end
	
	local isEventTeam = Exhibition.EventMode.Config.Whitelist[steamID64]
	local hasEventMode = ply:GetNWBool("eventmode", false)
	
	return isEventTeam and hasEventMode
end

-- Expose to global scope for testing module
_G.inEventMode = inEventMode

local function ValidPly(ply)
	if not IsValid(ply) or not ply:IsPlayer() then
		return false
	end
	return true
end

-- Map configuration with boundaries
local mapConfigs = {
	["rp_exhib_border_v3b"] = {
		minBounds = Vector(6000, 6000, 3000),
		maxBounds = Vector(-10000, -10000, 11000)
	},
	["gm_construct"] = {
		minBounds = Vector(-1080, -1080, -200),
		maxBounds = Vector(-3220, -1910, 240)
	}
}

local function getSupportedMapConfig()
	local mapName = MAP and MAP or game.GetMap()
	return mapConfigs[mapName]
end

-- Expose to global scope for testing module
_G.getSupportedMapConfig = getSupportedMapConfig

local function isPositionInBounds(pos)
	local mapConfig = getSupportedMapConfig()
	if not mapConfig then
		return true -- No restrictions on unsupported maps
	end
	
	local minBounds = mapConfig.minBounds
	local maxBounds = mapConfig.maxBounds
	
	return pos.x >= math.min(minBounds.x, maxBounds.x) and pos.x <= math.max(minBounds.x, maxBounds.x) and
	       pos.y >= math.min(minBounds.y, maxBounds.y) and pos.y <= math.max(minBounds.y, maxBounds.y) and
	       pos.z >= math.min(minBounds.z, maxBounds.z) and pos.z <= math.max(minBounds.z, maxBounds.z)
end

-- Expose to global scope for testing module
_G.isPositionInBounds = isPositionInBounds

local function inAdminMode(ply)
	return ply.GetAdminmode and ply:GetAdminmode()
end

-- Generic manipulation tracking and cleanup functions
local function markPlayerAsManipulated(ply, e2_chip)
	if not ply.plycore_manipulatedby then
		ply.plycore_manipulatedby = {}
	end
	ply.plycore_manipulatedby[e2_chip] = true
end

local function resetPlayerToDefaults(ply)
	-- Only adjust HP and armor down, otherwise leave as is to prevent abuse
	if ply:Health() > 100 then
		ply:SetHealth(100)
	end
	if ply:Armor() > 100 then
		ply:SetArmor(100)
	end
	ply:SetJumpPower(200)
	ply:SetGravity(1)
	ply:SetWalkSpeed(200)
	ply:SetRunSpeed(400)
	ply:Freeze(false)
end

local function hasAccess(ply, target, command)
	local valid = hook.Call("PlyCoreCommand", GAMEMODE, ply, target, command)

	if valid ~= nil then
		return valid
	end

	-- SITUATION 1: is Exhib MBRP server
	if Exhibition then
		-- Event Team members in event mode have access
		if inEventMode(ply) then
			-- If we're on a supported map, restrict e2 commands to only be useable within the boundary box
			if getSupportedMapConfig() then
				if ValidPly(target) then
					-- Add exceptions for harmless commands
					if table.HasValue(alwaysAllowedCommands, command) then
						return true
					end

					-- Prevent commands from running on admins. Admins can run commands on themselves.
					if ply ~= target and inAdminMode(target) then
						return false
					end

					local targetPos = target:GetPos()
					
					-- Check if target is in event area
					return isPositionInBounds(targetPos)
				end
			end
			
			return true -- Event team in event mode (MBRP server but unsupported map)
		end
		
		-- Fallback: Allow superadmins to use commands even if they're not event team/event mode
		return ply:IsSuperAdmin() and inAdminMode(ply)
	else
		-- SITUATION 2: Not an MBRP server, allow superadmins to use commands
		return ply:IsSuperAdmin()
	end
end

-- Expose to global scope for testing module
_G.hasAccess = hasAccess

local function check(v)
	return	-math.huge < v[1] and v[1] < math.huge and
			-math.huge < v[2] and v[2] < math.huge and
			-math.huge < v[3] and v[3] < math.huge
end

-------------------------------------------------------------------------------------------------------------------------------

__e2setcost(1)

--- Sets the velocity of the player.
e2function void entity:plyApplyForce(vector force)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "applyforce") then self:throw("You do not have access", nil) end

	if check(force) then
		local clampedForce = Vector(
			math.Clamp(force[1], -50000, 50000),
			math.Clamp(force[2], -50000, 50000),
			math.Clamp(force[3], -50000, 50000)
		)
		this:SetVelocity(clampedForce)
	end
end

--- Sets the position of the player.
e2function void entity:plySetPos(vector pos)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "setpos") then self:throw("You do not have access", nil) end

	local targetPos = Vector(math.Clamp(pos[1],-16000,16000), math.Clamp(pos[2],-16000,16000), math.Clamp(pos[3],-16000,16000))
	
	-- Additional check: ensure target position is within bounds on MBRP exhib maps
	if not isPositionInBounds(targetPos) then
		self:throw("Target position is outside allowed boundary", nil)
		return
	end
	
	this:SetPos(targetPos)
end

--- Sets the angle of the player's camera.
e2function void entity:plySetAng(angle ang)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "setang") then self:throw("You do not have access", nil) end

	local normalizedAng = Angle(ang[1], ang[2], ang[3])
	normalizedAng:Normalize()
	this:SetEyeAngles(normalizedAng)
end

--- Sets the health of the player.
e2function void entity:plySetHealth(number health)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "sethealth") then self:throw("You do not have access", nil) end

	markPlayerAsManipulated(this, self)
	
	if health <= 0 then
		if this:Alive() then
			this:Kill()
		end
	else
		this:SetHealth(math.Clamp(health, 1, 2^32/2-1))
	end
end

--- Sets the armor of the player.
e2function void entity:plySetArmor(number armor)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "setarmor") then self:throw("You do not have access", nil) end

	markPlayerAsManipulated(this, self)
	this:SetArmor(math.Clamp(armor, 0, 2^32/2-1))
end

--- Sets the jump power, eg. the velocity the player will applied to when he jumps. default 200 
e2function void entity:plySetJumpPower(number jumpPower)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "setjumppower") then self:throw("You do not have access", nil) end

	markPlayerAsManipulated(this, self)
	this:SetJumpPower(math.Clamp(jumpPower, 0, 2^32/2-1))
end

--- Returns the mass of the player.
e2function number entity:plyGetMass()
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "getmass") then self:throw("You do not have access", nil) end

	return this:GetPhysicsObject():GetMass()
end

--- Returns the jump power of the player.
e2function number entity:plyGetJumpPower()
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "getjumppower") then self:throw("You do not have access", nil) end

	return this:GetJumpPower()
end

--- Sets the gravity of the player. default 600
e2function void entity:plySetGravity(number gravity)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "setgravity") then self:throw("You do not have access", nil) end

	if gravity == 0 then gravity = 1/10^10 end
	markPlayerAsManipulated(this, self)
	this:SetGravity(gravity/600)
end

--- Returns the gravity of the player.
e2function number entity:plyGetGravity()
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "getgravity") then self:throw("You do not have access", nil) end

	return this:GetGravity()*600
end

--- Sets the walk and run speed of the player. (run speed is double of the walk speed) default 200
e2function void entity:plySetSpeed(number speed)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "setspeed") then self:throw("You do not have access", nil) end

	markPlayerAsManipulated(this, self)
	this:SetWalkSpeed(math.Clamp(speed, 1, 10000))
	this:SetRunSpeed(math.Clamp(speed*2, 1, 10000))
end

--- Sets the walk speed of the player. default 200
e2function void entity:plySetWalkSpeed(number speed)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "setwalkspeed") then self:throw("You do not have access", nil) end

	markPlayerAsManipulated(this, self)
	this:SetWalkSpeed(math.Clamp(speed, 1, 10000))
end

--- Sets the run speed of the player. default 400
e2function void entity:plySetRunSpeed(number speed)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "setrunspeed") then self:throw("You do not have access", nil) end

	markPlayerAsManipulated(this, self)
	this:SetRunSpeed(math.Clamp(speed, 1, 10000))
end

--- Resets the settings of the player.
e2function void entity:plyResetSettings()
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "resetsettings") then self:throw("You do not have access", nil) end

	resetPlayerToDefaults(this)
end

--- Returns the walk speed of the player.
e2function number entity:plyGetSpeed()
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "getspeed") then self:throw("You do not have access", nil) end

	return this:GetWalkSpeed()
end

--- Freezes the player.
e2function void entity:plyFreeze(number freeze)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "freeze") then self:throw("You do not have access", nil) end

	markPlayerAsManipulated(this, self)
	this:Freeze(freeze == 1)
end

--- Returns 1 if the player is frozen, 0 otherwise.
e2function number entity:plyIsFrozen()
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "isfrozen") then self:throw("You do not have access", nil) end

	return this:IsFlagSet(FL_FROZEN) and 1 or 0
end

-- Check if a position is within the map boundaries
e2function number posInBounds(vector pos)
	if not hasAccess(self.player, self.player, "inbounds") then self:throw("You do not have access", nil) end

	-- Always in bounds on unsupported maps
	if getSupportedMapConfig() then
		local targetPos = Vector(pos[1], pos[2], pos[3])
		return isPositionInBounds(targetPos) and 1 or 0
	else
		return 1
	end
end

e2function number entity:plyIsAdminMode()
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "isadminmode") then self:throw("You do not have access", nil) end
	return this:GetAdminmode() and 1 or 0
end

-- Use cached players for cheap calls
e2function array getPlayersInEvent()
	if not hasAccess(self.player, self.player, "getplayersinevent") then self:throw("You do not have access", nil) end
	return playersInEvent
end

E2Lib.registerEvent("playerJoinEvent", {
	{ "Player", "e" }
})

E2Lib.registerEvent("playerLeaveEvent", {
	{ "Player", "e" }
})


registerCallback("destruct", function(self)
	for _, ply in pairs(player.GetAll()) do
		if ply.plycore_manipulatedby and ply.plycore_manipulatedby[self] then
			resetPlayerToDefaults(ply)
			
			-- Clean up the tracking
			ply.plycore_manipulatedby[self] = nil
		end
	end
end)

-- Initialize the cache on server start/addon reload
registerCallback("preexecute", function()
	playersInEvent = {}
	-- Populate with any players already in an event
	for _, ply in pairs(player.GetAll()) do
		if ply.exhib_event then
			table.insert(playersInEvent, ply)
		end
	end
end)

-- Hook to update the players in event cache when someone joins
hook.Add("OnPlayerJoinEvent", "PlayerCore_PlayerJoinEvent",function(ply)
	if not table.HasValue(playersInEvent, ply) then
		table.insert(playersInEvent, ply)
	end
	E2Lib.triggerEvent("playerJoinEvent", { ply })
end)

-- Hook to update the players in event cache when someone leaves
hook.Add("OnPlayerLeaveEvent", "PlayerCore_PlayerLeaveEvent", function(ply)
	for i, eventPly in ipairs(playersInEvent) do
		if eventPly == ply then
			table.remove(playersInEvent, i)
			break
		end
	end
	
	-- Also reset any manipulated settings when they leave the event
	if ply.plycore_manipulatedby then
		resetPlayerToDefaults(ply)
		ply.plycore_manipulatedby = nil
	end

	E2Lib.triggerEvent("playerLeaveEvent", { ply })
end)
