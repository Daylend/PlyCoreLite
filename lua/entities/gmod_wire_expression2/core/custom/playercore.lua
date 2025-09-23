E2Lib.RegisterExtension("playercorelite", true)

local function ValidPly(ply)
	if not IsValid(ply) or not ply:IsPlayer() then
		return false
	end

	return true
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
			local mapName = MAP and MAP or game.GetMap()
			if string.find(mapName, "^rp_exhib_border") then
				if IsValid(target) then
					local targetPos = target:GetPos()
					-- Grass area only
					local minBounds = Vector(6000, 6000, 3000)
					local maxBounds = Vector(-10000, -10000, 11000)
					
					if targetPos.x >= minBounds.x and targetPos.x <= maxBounds.x and
					   targetPos.y >= minBounds.y and targetPos.y <= maxBounds.y and
					   targetPos.z >= minBounds.z and targetPos.z <= maxBounds.z then
						return true -- Target within boundary
					else
						-- Add exception for resetting player settings in case they leave the event area
						if command == "resetsettings" then
							return true -- 
						end

						return false -- Target outside boundary
					end
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

	this:SetPos(Vector(math.Clamp(pos[1],-16000,16000), math.Clamp(pos[2],-16000,16000), math.Clamp(pos[3],-16000,16000)))
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

	this:SetHealth(math.Clamp(health, 0, 2^32/2-1))
end

--- Sets the armor of the player.
e2function void entity:plySetArmor(number armor)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "setarmor") then self:throw("You do not have access", nil) end

	this:SetArmor(math.Clamp(armor, 0, 2^32/2-1))
end

--- Sets the jump power, eg. the velocity the player will applied to when he jumps. default 200 
e2function void entity:plySetJumpPower(number jumpPower)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "setjumppower") then self:throw("You do not have access", nil) end

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

	this:SetWalkSpeed(math.Clamp(speed, 1, 10000))
	this:SetRunSpeed(math.Clamp(speed*2, 1, 10000))
end

--- Sets the walk speed of the player. default 200
e2function void entity:plySetWalkSpeed(number speed)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "setwalkspeed") then self:throw("You do not have access", nil) end

	this:SetWalkSpeed(math.Clamp(speed, 1, 10000))
end

--- Sets the run speed of the player. default 400
e2function void entity:plySetRunSpeed(number speed)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "setrunspeed") then self:throw("You do not have access", nil) end

	this:SetRunSpeed(math.Clamp(speed, 1, 10000))
end

--- Resets the settings of the player.
e2function void entity:plyResetSettings()
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "resetsettings") then self:throw("You do not have access", nil) end

	-- Only adjust HP and armor down, otherwise leave as is to prevent abuse
	if this:Health() > 100 then
		this:SetHealth(100)
	end
	if this:Armor() > 100 then
		this:SetArmor(100)
	end
	this:SetJumpPower(200)
	this:SetGravity(1)
	this:SetWalkSpeed(200)
	this:SetRunSpeed(400)
	this:Freeze(false)
end

--- Returns the walk speed of the player.
e2function number entity:plyGetSpeed()
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "getspeed") then self:throw("You do not have access", nil) end

	return this:GetWalkSpeed()
end

-- Freeze functionality
registerCallback("destruct",function(self)
	for _, ply in pairs(player.GetAll()) do
		if ply.plycore_freezeby == self then
			ply:Freeze(false)
		end
	end
end)

--- Freezes the player.
e2function void entity:plyFreeze(number freeze)
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "freeze") then self:throw("You do not have access", nil) end

	this.plycore_freezeby = self
	this:Freeze(freeze == 1)
end

--- Returns 1 if the player is frozen, 0 otherwise.
e2function number entity:plyIsFrozen()
	if not ValidPly(this) then return self:throw("Invalid player", nil) end
	if not hasAccess(self.player, this, "isfrozen") then self:throw("You do not have access", nil) end

	return this:IsFlagSet(FL_FROZEN) and 1 or 0
end