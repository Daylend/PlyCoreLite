E2Lib.RegisterExtension("playercorelite", true)

-- Cache for players currently in the event
local playersInEvent = {}

-- Commands that don't require boundary checks
local alwaysAllowedCommands = {"resetsettings", "inbounds", "isadminmode", "getplayersinevent"}

-- Mock Exhibition for testing
local MockExhibitionEnabled = false  -- Controls whether mock is active
local MockExhibition = {
	EventMode = {
		Config = {
			Whitelist = {}
		}
	}
}

local function inEventMode(ply)
	-- Check if player is in the Event Team whitelist and has event mode enabled
	local steamID64 = ply:SteamID64()
	local exhibitionSystem = Exhibition or (MockExhibitionEnabled and MockExhibition)
	
	-- If no exhibition system is available, return false
	if not exhibitionSystem then
		return false
	end
	
	local isEventTeam = exhibitionSystem.EventMode.Config.Whitelist[steamID64]
	local hasEventMode = ply:GetNWBool("eventmode", false)
	
	return isEventTeam and hasEventMode
end

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

	-- SITUATION 1: is Exhib MBRP server (or testing with mock)
	if Exhibition or MockExhibitionEnabled then
		-- Event Team members in event mode have access
		if inEventMode(ply) then
			-- If we're on a supported map, restrict e2 commands to only be useable within the boundary box
			if getSupportedMapConfig() then
				if ValidPly(target) then
					-- Add exceptions for harmless commands
					if table.HasValue(alwaysAllowedCommands, command) then
						return true
					end

					-- Prevent commands from running on admins
					if inAdminMode(target) then
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

local function check(v)
	return	-math.huge < v[1] and v[1] < math.huge and
			-math.huge < v[2] and v[2] < math.huge and
			-math.huge < v[3] and v[3] < math.huge
end

-------------------------------------------------------------------------------------------------------------------------------

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
	this:SetHealth(math.Clamp(health, 0, 2^32/2-1))
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
registerCallback("OnPlayerJoinEvent", function(ply)
	if not table.HasValue(playersInEvent, ply) then
		table.insert(playersInEvent, ply)
	end
	E2Lib.triggerEvent("playerJoinEvent", { ply })
end)

-- Hook to update the players in event cache when someone leaves
registerCallback("OnPlayerLeaveEvent", function(ply)
	for i, eventPly in ipairs(playersInEvent) do
		if eventPly == ply then
			table.remove(playersInEvent, i)
			break
		end
	end
	
	-- Also reset any manipulated settings when they leave the event
	if ply.plycore_manipulatedby then
		resetPlayerToDefaults(ply)
		ply.plycore_manipulatedby[self] = nil
	end

	E2Lib.triggerEvent("playerLeaveEvent", { ply })
end)

-- Testing helpers (remove in production)
if game.SinglePlayer() or GetConVar("developer"):GetBool() then
	local function getTargetPlayer(ply, args)
		local targetPly = ply
		if args[1] then
			local targetName = args[1]
			for _, p in pairs(player.GetAll()) do
				if string.find(string.lower(p:Nick()), string.lower(targetName)) then
					targetPly = p
					break
				end
			end
		end
		return targetPly
	end
	
	-- Mock Exhibition server state
	concommand.Add("playercore_mock_exhib_on", function(ply, cmd, args)
		MockExhibitionEnabled = true
		print("PlayerCore Test: Exhibition server mode ENABLED (mock)")
	end)
	
	concommand.Add("playercore_mock_exhib_off", function(ply, cmd, args)
		MockExhibitionEnabled = false
		print("PlayerCore Test: Exhibition server mode DISABLED (regular server)")
	end)
	
	-- Event Team membership controls
	concommand.Add("playercore_mock_eventteam_add", function(ply, cmd, args)
		local targetPly = getTargetPlayer(ply, args)
		MockExhibition.EventMode.Config.Whitelist[targetPly:SteamID64()] = true
		print("PlayerCore Test: " .. targetPly:Nick() .. " added to Event Team whitelist")
	end)
	
	concommand.Add("playercore_mock_eventteam_remove", function(ply, cmd, args)
		local targetPly = getTargetPlayer(ply, args)
		MockExhibition.EventMode.Config.Whitelist[targetPly:SteamID64()] = nil
		print("PlayerCore Test: " .. targetPly:Nick() .. " removed from Event Team whitelist")
	end)
	
	-- Event mode controls
	concommand.Add("playercore_mock_eventmode_on", function(ply, cmd, args)
		local targetPly = getTargetPlayer(ply, args)
		targetPly:SetNWBool("eventmode", true)
		print("PlayerCore Test: " .. targetPly:Nick() .. " event mode ENABLED")
	end)
	
	concommand.Add("playercore_mock_eventmode_off", function(ply, cmd, args)
		local targetPly = getTargetPlayer(ply, args)
		targetPly:SetNWBool("eventmode", false)
		print("PlayerCore Test: " .. targetPly:Nick() .. " event mode DISABLED")
	end)
	
	-- Scenario shortcuts
	concommand.Add("playercore_scenario_regular", function(ply, cmd, args)
		local targetPly = getTargetPlayer(ply, args)
		MockExhibition.EventMode.Config.Whitelist[targetPly:SteamID64()] = nil
		targetPly:SetNWBool("eventmode", false)
		print("PlayerCore Test: " .. targetPly:Nick() .. " set to REGULAR USER (not event team, no event mode)")
	end)
	
	concommand.Add("playercore_scenario_eventteam_inactive", function(ply, cmd, args)
		local targetPly = getTargetPlayer(ply, args)
		MockExhibition.EventMode.Config.Whitelist[targetPly:SteamID64()] = true
		targetPly:SetNWBool("eventmode", false)
		print("PlayerCore Test: " .. targetPly:Nick() .. " set to EVENT TEAM INACTIVE (in event team, event mode OFF)")
	end)
	
	concommand.Add("playercore_scenario_eventteam_active", function(ply, cmd, args)
		local targetPly = getTargetPlayer(ply, args)
		MockExhibition.EventMode.Config.Whitelist[targetPly:SteamID64()] = true
		targetPly:SetNWBool("eventmode", true)
		print("PlayerCore Test: " .. targetPly:Nick() .. " set to EVENT TEAM ACTIVE (in event team, event mode ON)")
	end)
	
	-- Pure join/leave events (no permission changes)
	concommand.Add("playercore_test_join", function(ply, cmd, args)
		local targetPly = getTargetPlayer(ply, args)
		targetPly.exhib_event = true
		
		-- Trigger join event
		hook.Call("OnPlayerJoinEvent", GAMEMODE, targetPly)
		
		print("PlayerCore Test: " .. targetPly:Nick() .. " joined event")
		print("Players in event: " .. #playersInEvent)
	end)
	
	concommand.Add("playercore_test_leave", function(ply, cmd, args)
		local targetPly = getTargetPlayer(ply, args)
		targetPly.exhib_event = nil
		
		-- Trigger leave event
		hook.Call("OnPlayerLeaveEvent", GAMEMODE, targetPly)
		
		print("PlayerCore Test: " .. targetPly:Nick() .. " left event")
		print("Players in event: " .. #playersInEvent)
	end)
	
	concommand.Add("playercore_test_status", function(ply, cmd, args)
		local targetPly = getTargetPlayer(ply, args)
		
		print("=== PlayerCore Test Status ===")
		print("Current map: " .. game.GetMap())
		print("Map config exists: " .. tostring(getSupportedMapConfig() ~= nil))
		print("Exhibition server mode: " .. tostring(Exhibition ~= nil or MockExhibitionEnabled))
		print("Players in event: " .. #playersInEvent)
		for i, p in ipairs(playersInEvent) do
			print("  " .. i .. ": " .. p:Nick())
		end
		print("")
		print("Target player: " .. targetPly:Nick())
		print("  SteamID64: " .. targetPly:SteamID64())
		print("  In Event Team whitelist: " .. tostring(MockExhibition.EventMode.Config.Whitelist[targetPly:SteamID64()] == true))
		print("  Event mode enabled: " .. tostring(targetPly:GetNWBool("eventmode", false)))
		print("  Has full event access: " .. tostring(inEventMode(targetPly)))
		print("  Position: " .. tostring(targetPly:GetPos()))
		print("  Position in bounds: " .. tostring(isPositionInBounds(targetPly:GetPos())))
		print("  Is superadmin: " .. tostring(targetPly:IsSuperAdmin()))
		
		-- Test access for a sample command
		local hasAccess = hasAccess(targetPly, targetPly, "setpos")
		print("  Would have access to setpos: " .. tostring(hasAccess))
	end)
	
	-- Help command
	concommand.Add("playercore_test_help", function(ply, cmd, args)
		print("=== PlayerCore Test Commands ===")
		print("Server State:")
		print("  playercore_mock_exhib_on - Enable Exhibition server mode")
		print("  playercore_mock_exhib_off - Disable Exhibition server mode (regular server)")
		print("")
		print("Event Team Management:")
		print("  playercore_mock_eventteam_add [player] - Add to Event Team whitelist")
		print("  playercore_mock_eventteam_remove [player] - Remove from Event Team whitelist")
		print("")
		print("Event Mode Control:")
		print("  playercore_mock_eventmode_on [player] - Enable event mode")
		print("  playercore_mock_eventmode_off [player] - Disable event mode")
		print("")
		print("Scenario Shortcuts:")
		print("  playercore_scenario_regular [player] - Regular user (no event team, no event mode)")
		print("  playercore_scenario_eventteam_inactive [player] - Event team but event mode OFF")
		print("  playercore_scenario_eventteam_active [player] - Event team with event mode ON")
		print("")
		print("Event Testing:")
		print("  playercore_test_join [player] - Simulate joining an event")
		print("  playercore_test_leave [player] - Simulate leaving an event")
		print("")
		print("Status:")
		print("  playercore_test_status [player] - Show current test status")
		print("  playercore_test_help - Show this help")
		print("")
		print("Note: [player] is optional - if not specified, targets yourself")
	end)
end