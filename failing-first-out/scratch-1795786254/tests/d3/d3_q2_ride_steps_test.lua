-- Design round 3, group Q2: on the Ride screen's live look the steps row keeps 8 under the title, with or without a second line.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, ok = T.test, T.ok
local H = T.H

local function stateOf(state)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	r.W.ride = { id = "q2", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 5000, state = state,
		at = r.env.GetTime(), payee = "Mia Runner", payto = "Mia", service = "Mia's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(3)
	return w, r, r.W.UI.state.screens.found
end

test("d3 q2: the steps row sits at least 8 under the title, in states with and without a second line", function()
	for _, st in ipairs({ "accepted", "invited", "ingroup", "summoning", "portal" }) do
		local w, r, s = stateOf(st)
		if s.mode == "live" then
			local t, p = H.rect(s.title), H.rect(s.prog)
			ok((t.b) - (p.b + p.h) >= 8 - 0.5, st .. " (second line " .. tostring(s.sub:IsShown()) .. "): the title's bottom is " .. t.b
				.. ", the steps' top is " .. (p.b + p.h))
		end
		T.clean(w)
	end
end)
