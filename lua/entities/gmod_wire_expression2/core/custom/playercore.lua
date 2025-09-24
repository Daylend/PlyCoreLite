E2Lib.RegisterExtension("playercorelite", true)

local function ValidPly(ply)
	if not IsValid(ply) or not ply:IsPlayer() then
		return false
	end
	return true
end

local function isOnMBRPExhibMap()
	local mapName = MAP and MAP or game.GetMap()
	return string.find(mapName, "^rp_exhib_border")
end

local function isPositionInBounds(pos)
	if not isOnMBRPExhibMap() then
		return true -- No restrictions on other maps
	end
	
	-- Grass area only
	local minBounds = Vector(6000, 6000, 3000)
	local maxBounds = Vector(-10000, -10000, 11000)
	
	return pos.x >= minBounds.x and pos.x <= maxBounds.x and
	       pos.y >= minBounds.y and pos.y <= maxBounds.y and
	       pos.z >= minBounds.z and pos.z <= maxBounds.z
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

	-- SITUATION 1: Server has event mode and user group, MBRP specific
	if ply.GetEventMode and ply.GetUserGroup then
		-- Event Team members in event mode have access
		if ply:GetUserGroup() == "Event Team" and ply:GetEventMode() then
			-- If we're on the MBRP exhib map, restrict e2 commands to only be useable within the boundary box
			if isOnMBRPExhibMap() then
				if ValidPly(target) then
					-- Add exception for resetting player settings in case they leave the event area
					-- and for convenience functions to prevent crashing chip
					if command == "resetsettings" or command == "inbounds" or command == "isadminmode" then
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
		
		-- Fallback: Allow admins to use commands even if they're not event team/event mode
		return ply:IsAdmin()
	else
		-- SITUATION 2: Not an MBRP server, allow admins to use commands
		return ply:IsAdmin()
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

registerCallback("destruct",function(self)
	for _, ply in pairs(player.GetAll()) do
		if ply.plycore_manipulatedby and ply.plycore_manipulatedby[self] then
			resetPlayerToDefaults(ply)
			
			-- Clean up the tracking
			ply.plycore_manipulatedby[self] = nil
		end
	end
end)

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

-- When combined with plyIsAdminMode, we can avoid crashing the chip if something happens outside the owner's control
e2function number entity:plyInBounds()
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "inbounds") then self:throw("You do not have access", nil) end

	-- Always in bounds on other maps
	if isOnMBRPExhibMap() then
		return isPositionInBounds(this:GetPos()) and 1 or 0
	else
		return 1
	end
end

e2function number entity:plyIsAdminMode()
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "isadminmode") then self:throw("You do not have access", nil) end

	return this:GetAdminmode() and 1 or 0
end