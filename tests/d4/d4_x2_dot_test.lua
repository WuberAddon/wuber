-- Design round 4, group X2: the rider's "you" dot on the live ride page stands clear of the taller header bar.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function look(state, extra)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	r.W.ride = { id = "d4x2", driver = "Mia Runner", driverKey = "mia runner", dest = "Rut",
		price = 5000, state = state, at = r.env.GetTime(), payee = "Mia Runner", payto = "Mia", service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(3)
	return w, r, r.W.UI.state.screens.found
end

-- never half under the bar: either the whole dot is below its lower edge, or it is not shown
local function whole(s, what)
	local me = s.map.me
	if me:IsShown() and me:GetAlpha() > 0.01 then
		ok(me:GetTop() <= s.bar:GetBottom() + 0.01 or not s.bar:IsShown() and me:GetTop() <= s.bar:GetBottom() + 0.01, what .. ": the dot is not partly under the bar")
	end
end

test("d4 x2: pay look: the dot shows, at least 4 under the header bar's lower edge", function()
	local w, r, s = look("arrived")
	eq(s.mode, "pay", "the pay look")
	eq(s.map.me:GetAlpha(), 1, "the dot shows")
	local gap = s.bar:GetBottom() - s.map.me:GetTop()
	ok(gap >= 4, "clear of the bar by " .. tostring(gap))
	T.clean(w)
end)

test("d4 x2: the dot is never partly under the bar in any live state", function()
	for _, st in ipairs({ "arrived", "paying", "portal", "summoning", "invited", "accepted" }) do
		local w, r, s = look(st)
		whole(s, st)
		T.clean(w)
	end
end)

-- (E1-03) on the live ride page with the portal picture up, the "you" dot is hidden (replaces the earlier keep-the-dot choice)
test("d4 x2: live ride page hides the dot when the portal picture is up", function()
	for _, st in ipairs({ "portal", "summoning", "invited", "accepted" }) do
		local w, r, s = look(st)
		local me, art = s.map.me, s.hero and s.hero.art
		ok(art and art:IsShown(), st .. ": the portal picture is up")
		ok(not (me:IsShown() and me:GetAlpha() > 0.01), st .. ": the dot is hidden")
		T.clean(w)
	end
end)
