-- #233 Wuber under the client's secret rule: every function the client documents as returning a secret
-- (tests/fixtures/secret-api.lua) answers one, and the ordinary driver and rider flows raise no error and break
-- no rule. The API sweep of 26 Nov 2026 judged Wuber safe by reading; this runs it.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function errors(w)
	local e = {}
	for _, x in ipairs(w.errors) do e[#e + 1] = tostring(x):sub(1, 300) end
	return table.concat(e, " | ")
end

test("#233 every flagged function answers a secret: a driver goes online and opens Drive, Ride and Settings, no error", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	d:secret("*")
	T.settle(w)
	local W = d.W
	W.Driver.SetOnline(true) w:advance(3)
	W.UI.Toggle(true) w:advance(1)
	for _, tab in ipairs({ "Drive", "Ride" }) do W.UI.SelectTab(tab) w:advance(1.5) end
	W.UI.OpenSettings() w:advance(1.5)
	eq(#w.errors, 0, "no error: " .. errors(w))
	eq(#w.violations, 0, "no broken rule: " .. table.concat(w.violations, "; "))
	T.clean(w)
end)

test("#233 every flagged function answers a secret: a rider asks a driver for a ride in a group, no error", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local r = T.rider(w, T.BOB, { spot = "Orgrimmar" })
	d:secret("*") r:secret("*")
	T.settle(w)
	d.W.Driver.SetOnline(true) w:advance(3)
	r.W.UI.Toggle(true) w:advance(2)
	w:enterCombat(d) w:advance(1) w:leaveCombat(d) w:advance(1)
	eq(#w.errors, 0, "no error: " .. errors(w))
	eq(#w.violations, 0, "no broken rule: " .. table.concat(w.violations, "; "))
	T.clean(w)
end)
