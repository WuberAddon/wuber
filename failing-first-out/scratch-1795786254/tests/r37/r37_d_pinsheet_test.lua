-- Round 37 d: REV-r37-2, on the booking card (folded) the Fly or summon dial lifts the sheet (its top from 168 to about
-- 100-114) but the map strip kept laying itself out for a sheet at 168: the destination pin's tip could go down to y 162
-- (under the sheet), the route ended there, and the you dot (y 84-98) sat in the route header (which moves up with the
-- sheet). The strip now takes its visible bottom from Confirm (m.visBottom): nothing it draws for the route (the pin,
-- the route's ends, the you dot) lies under the sheet's top or in the header's box, the dial shown or not, real routes
-- and a destination forced low on the strip; no pin in the header; the pin stays whole on the strip.
local T = ...
local H, test, ok = T.H, T.test, T.ok
local X = dofile(T.dir .. "/layout/extra_screens.lua")

-- the rider at spot on the booking card for Mia Runner (to dest, standing there); flight: seconds of flying (nil: none)
local function booking(spot, dest, flight, opts)
	local w = T.newWorld()
	opts = opts or {}
	opts.spot = spot
	local r = T.rider(w, T.TESTCHAR, opts)
	w:advance(15)
	local W = r.W
	W.TravelSaved = function() if flight then return flight, "same continent", true end end
	if not flight then W.UI.FlightCostTo = function() return nil end end
	local P = W.ExactPlace(dest)
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = dest, price = 5000, state = "open", team = 3,
		queue = 0, service = "Mia's Rides", heard = r.env.GetTime(), mapID = P and P.mapID, x = P and P.x, y = P and P.y }
	local ends = {}
	local route = W.Map.RouteOnPanel
	W.Map.RouteOnPanel = function(m, a, b, o)
		if a then ends.from, ends.to = a, b end
		return route(m, a, b, o)
	end
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Show("confirm", "mia runner")
	w:advance(1.5)
	W.UI.RefreshNow()
	w:advance(0.5)
	return w, r, W.UI.state.screens.confirm, ends
end

local function refresh(w, r)
	r.W.UI.RefreshNow()
	w:advance(0.5)
end

-- the destination at x, y (0..1) of the rider's map, and the card drawn again
local function placeAt(w, r, s, x, y)
	local mapID = s.map.artFor
	r.W.ExactPlace = function(name) if name == "Undercity" then return { name = "Undercity", mapID = mapID, x = x, y = y } end end
	refresh(w, r)
end

local function check(s, ends, what)
	local o = X.stripBoxes(s, ends)
	local bad = X.stripProblems(o)
	ok(#bad == 0, what .. ": " .. (#bad > 0 and table.concat(bad, "; ") or "clear") .. " [" .. X.stripText(o) .. "]")
	local m, p = s.map, o.pin
	if p then
		local w = m.mapW or 360
		ok(p.l >= -0.5 and p.r <= w + 0.5 and p.t >= -0.5, what .. ": the pin is whole on the strip (x " .. math.floor(p.l + 0.5)
			.. ".." .. math.floor(p.r + 0.5) .. " y " .. math.floor(p.t + 0.5) .. ".." .. math.floor(p.b + 0.5) .. ")")
		if o.to then ok(math.abs(o.to.y - p.b) < 1.5 and math.abs(o.to.x - (p.l + p.r) / 2) < 1.5, what .. ": the route ends at the pin's tip") end
	end
	return o
end

-- real pairs: south of the rider (Orgrimmar to Ratchet; Crossroads to Ratchet), a hop inside one zone (Tarren Mill to
-- Southshore), and a ride to another continent (Orgrimmar to Undercity: no pin, the you dot under the header before)
local PAIRS = { { "Orgrimmar", "Ratchet" }, { "Crossroads", "Ratchet" }, { "Tarren Mill", "Southshore" }, { "Orgrimmar", "Undercity" },
	{ "Ratchet", "Crossroads" } }

test("r37 d: REV-r37-2 - folded, the dial showing: real routes keep above the lifted sheet and out of the route header", function()
	for _, pr in ipairs(PAIRS) do
		local w, r, s, ends = booking(pr[1], pr[2], 1500)
		local what = pr[1] .. " to " .. pr[2] .. ", dial"
		ok(H.visible(s.dial), what .. ": the dial shows")
		ok(s.cardTop < 168, what .. ": the sheet moved up (top " .. tostring(s.cardTop) .. ")")
		check(s, ends, what)
		T.clean(w)
	end
end)

test("r37 d: REV-r37-2 - folded, no dial: the same routes, as before", function()
	for _, pr in ipairs(PAIRS) do
		local w, r, s, ends = booking(pr[1], pr[2], nil)
		local what = pr[1] .. " to " .. pr[2] .. ", no dial"
		ok(not H.visible(s.dial), what .. ": no dial")
		check(s, ends, what)
		T.clean(w)
	end
end)

test("r37 d: REV-r37-2 - a destination forced low, left, right and high on the strip, the dial shown and not", function()
	for _, flight in ipairs({ 1500, false }) do
		for _, at in ipairs({ { 0.5, 0.99 }, { 0.02, 0.99 }, { 0.98, 0.99 }, { 0.5, 0.01 }, { 0.98, 0.01 } }) do
			local w, r, s, ends = booking("Orgrimmar", "Undercity", flight or nil)
			placeAt(w, r, s, at[1], at[2])
			local what = (flight and "dial" or "no dial") .. ", the place at " .. at[1] .. ", " .. at[2]
			ok(H.visible(s.map.destPin), what .. ": the pin shows")
			check(s, ends, what)
			T.clean(w)
		end
	end
end)

test("r37 d: REV-r37-2 - the strip follows the sheet when the dial comes and goes, and on unfold and fold", function()
	local w, r, s, ends = booking("Orgrimmar", "Undercity", nil)
	local W = r.W
	placeAt(w, r, s, 0.5, 0.99)
	local before = check(s, ends, "no dial")
	ok(s.cardTop == 168, "no dial: the sheet at 168 (" .. tostring(s.cardTop) .. ")")
	-- (round 37 e) the pin goes up over the header (the shorter move: tip 6 above its top, 122) rather than right past it
	ok(before.pin and before.header and math.abs(before.pin.b - (before.header.t - 6)) < 1, "no dial: the pin's tip 6 above the header's top (" .. tostring(before.pin and before.pin.b) .. ")")
	W.TravelSaved = function() return 1500, "same continent", true end
	W.UI.FlightCostTo = nil
	refresh(w, r)
	ok(H.visible(s.dial), "the dial came")
	check(s, ends, "the dial came")
	if W.UI.Fold and W.UI.Fold.Toggle then
		r.wide = true -- (the harness's room for the wide phone)
		W.UI.Fold.Toggle()
		w:advance(1)
		ok(W.UI.Fold.IsUnfolded(), "unfolded")
		W.UI.Fold.Toggle()
		w:advance(1)
		refresh(w, r)
		ok(not W.UI.Fold.IsUnfolded(), "folded again")
		check(s, ends, "folded again, the dial")
	end
	W.TravelSaved = function() end
	W.UI.FlightCostTo = function() return nil end
	refresh(w, r)
	ok(not H.visible(s.dial), "the dial went")
	local after = check(s, ends, "the dial went")
	ok(after.pin and before.pin and math.abs(after.pin.b - before.pin.b) < 1 and math.abs(after.pin.l - before.pin.l) < 1,
		"the pin is back where it was")
	ok(after.you and before.you and math.abs(after.you.t - before.you.t) < 1, "the you dot is back where it was")
	T.clean(w)
end)
