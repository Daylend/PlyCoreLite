-- PlayerCore Testing Module
-- This file contains all testing and mocking functionality for PlayerCore
-- Only loads in development environments

if not (game.SinglePlayer() or GetConVar("developer"):GetBool()) then
	return -- Don't load in production
end

-- Mock Exhibition for testing
local MockExhibitionEnabled = false  -- Controls whether mock is active
local MockExhibition = {
	EventMode = {
		Config = {
			Whitelist = {}
		}
	}
}

-- Override Exhibition global when mock is enabled
local function updateExhibitionGlobal()
	if MockExhibitionEnabled then
		Exhibition = MockExhibition
	else
		Exhibition = nil
	end
end

-- Helper function to get target player from command args
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
	updateExhibitionGlobal()
	print("PlayerCore Test: Exhibition server mode ENABLED (mock)")
end)

concommand.Add("playercore_mock_exhib_off", function(ply, cmd, args)
	MockExhibitionEnabled = false
	updateExhibitionGlobal()
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
	-- Access playersInEvent from main module if available
	if _G.playersInEvent then
		print("Players in event: " .. #_G.playersInEvent)
	end
end)

concommand.Add("playercore_test_leave", function(ply, cmd, args)
	local targetPly = getTargetPlayer(ply, args)
	targetPly.exhib_event = nil
	
	-- Trigger leave event
	hook.Call("OnPlayerLeaveEvent", GAMEMODE, targetPly)
	
	print("PlayerCore Test: " .. targetPly:Nick() .. " left event")
	-- Access playersInEvent from main module if available
	if _G.playersInEvent then
		print("Players in event: " .. #_G.playersInEvent)
	end
end)

-- Status command - needs access to main module functions
concommand.Add("playercore_test_status", function(ply, cmd, args)
	local targetPly = getTargetPlayer(ply, args)
	
	print("=== PlayerCore Test Status ===")
	print("Current map: " .. game.GetMap())
	
	-- Try to access main module functions
	if _G.getSupportedMapConfig then
		print("Map config exists: " .. tostring(_G.getSupportedMapConfig() ~= nil))
	end
	
	print("Exhibition server mode: " .. tostring(Exhibition ~= nil))
	
	if _G.playersInEvent then
		print("Players in event: " .. #_G.playersInEvent)
		for i, p in ipairs(_G.playersInEvent) do
			print("  " .. i .. ": " .. p:Nick())
		end
	end
	
	print("")
	print("Target player: " .. targetPly:Nick())
	print("  SteamID64: " .. targetPly:SteamID64())
	print("  In Event Team whitelist: " .. tostring(MockExhibition.EventMode.Config.Whitelist[targetPly:SteamID64()] == true))
	print("  Event mode enabled: " .. tostring(targetPly:GetNWBool("eventmode", false)))
	
	if _G.inEventMode then
		print("  Has full event access: " .. tostring(_G.inEventMode(targetPly)))
	end
	
	print("  Position: " .. tostring(targetPly:GetPos()))
	
	if _G.isPositionInBounds then
		print("  Position in bounds: " .. tostring(_G.isPositionInBounds(targetPly:GetPos())))
	end
	
	print("  Is superadmin: " .. tostring(targetPly:IsSuperAdmin()))
	
	-- Test access for a sample command
	if _G.hasAccess then
		local hasAccess = _G.hasAccess(targetPly, targetPly, "setpos")
		print("  Would have access to setpos: " .. tostring(hasAccess))
	end
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

print("PlayerCore Test Module loaded. Type 'playercore_test_help' for available commands.")
