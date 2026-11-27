local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function C23_C23r_3_failedMap(W)
	local bad = {}
	for _, c in ipairs(W.SelfTest()) do
		if not c.ok and (tostring(c.name):find("map") or tostring(c.name):find("Distances") or tostring(c.name):find("C_Map")) then
			bad[#bad + 1] = c.name
		end
	end
	return bad
end

test("r47 c4: Check my game reports the map as broken inside a dungeon", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	eq(#C23_C23r_3_failedMap(r.W), 0, "control: in the open world every map check passes")
	r.player.inInstance = true -- inside a dungeon the real game answers nil for the map calls
	local oldIn = r.env.IsInInstance
	r.env.IsInInstance = function() return true, "party" end
	w:advance(1)
	local bad = C23_C23r_3_failedMap(r.W)
	r.env.IsInInstance = oldIn
	ok(#bad == 0, "in a dungeon /wuber test lists the map as not working although the game is fine: " .. table.concat(bad, "; "))
	r:slash("/wuber test")
	T.clean(w)
end)


local function C23_C23r_4_row(W, name)
	for _, c in ipairs(W.SelfTest()) do if c.name == name then return c end end
end

test("r47 c4: Check my game says LeaveParty is missing when the game refused it", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local c = C23_C23r_4_row(r.W, "Leave the group after the ride")
	ok(c and c.ok == true, "control: with LeaveParty allowed the row passes")
	r.W.db.blockedBuild = { [r.W.Build()] = { leave = true } } -- the game refused LeaveParty on this build
	c = C23_C23r_4_row(r.W, "Leave the group after the ride")
	ok(c and c.ok == false, "the row fails when the game refused it")
	ok(c.detail and c.detail:find("refused"), "the player is told '" .. tostring(c.detail) .. "' (as if the call were missing) instead of that the game refused it on this version")
	T.clean(w)
end)


local function C23_C23r_7_has(list, n) for _, x in ipairs(list) do if x == n then return true end end return false end

test("r47 c4: a missing Drive/Button.lua is not noticed by MissingParts", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = r.W.Drive
	eq(#r.W.MissingParts(), 0, "control: a full load misses nothing")
	-- Drive/Button.lua not loaded: everything it defines is absent (DR.Plan comes from Drive/Plan.lua, loaded before it)
	DR.BuildButton = nil DR.SkipTarget = nil DR.Skip = nil DR.ResetPosition = nil
	ok(C23_C23r_7_has(r.W.MissingParts(), "Drive_Button"), "Button.lua is gone but the player gets no 'Restart the game to finish updating Wuber' toast: " .. table.concat(r.W.MissingParts(), ","))
	T.clean(w)
end)

test("r47 c4: a missing Drive/Service.lua is noticed by MissingParts", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = r.W.Drive
	local saved = DR.IsOpen
	DR.IsOpen = nil
	local miss = r.W.MissingParts()
	DR.IsOpen = saved
	local found = false
	for _, x in ipairs(miss) do if x == "Drive_Service" then found = true end end
	ok(found, "Service.lua is gone but no restart toast: " .. table.concat(miss, ","))
	T.clean(w)
end)
