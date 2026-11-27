-- Fix round 2.4, group h1: ING-09 (step rings clear of their words), pay look keeps the rider dot, HUNT-138 (flight line wraps)
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function payScreen(extra)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local ride = { id = "frh1", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 5000, state = "arrived",
		at = r.env.GetTime(), payee = "Mia Runner", payto = "Mia", service = "Mia's Rides", flightCost = 2300, flightExact = 1 }
	for k, v in pairs(extra or {}) do ride[k] = v end
	r.W.ride = ride
	r.W.db.tipPct = 20
	r.W.Fire("RIDE")
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(3)
	return w, r, r.W.UI.state.screens.found
end

test("fr h1: the step rings stand clear of the words under them (ING-09)", function()
	local w, r, s = payScreen()
	for i, n in ipairs(s.nodes) do
		local cy = (n:GetTop() + n:GetBottom()) / 2
		local ringBottom = cy - 17 -- the pulse ring is 34 across
		ok(n.label:GetTop() <= ringBottom + 0.01, "step " .. i .. ": words start " .. (ringBottom - n.label:GetTop()) .. " under the ring")
	end
	T.clean(w)
end)

test("fr h1: pay look: the long welcome line wraps and the rider dot stays", function()
	local w, r, s = payScreen()
	ok(s.sub.wuberText:find("Welcome to Undercity", 1, true), "the line")
	eq(s.map.me:GetAlpha(), 1, "the dot stays")
	local rs, rm = H.rect(s.sub), H.rect(s.map.me)
	ok(rs.l + rs.w <= rm.l + 0.5 or rs.b >= rm.b + rm.h - 0.5 or rm.b >= rs.b + rs.h - 0.5, "the words stay clear of the dot")
	ok(H.truncation(s.sub, true) == nil, "nothing cut")
	T.clean(w)
end)

test("fr h1: pay card: the flight line is whole, wrapped not cut (HUNT-138)", function()
	local w, r, s = payScreen()
	local fl = s.payCard and s.payCard.flight
	if not fl then
		for _, v in pairs(s) do if type(v) == "table" and v.flight and v.flight.wuberText then fl = v.flight end end
	end
	ok(fl and fl:IsShown(), "the flight line shows")
	ok(H.truncation(fl, true) == nil, "nothing cut: " .. tostring(fl and fl.wuberText))
	T.clean(w)
end)
