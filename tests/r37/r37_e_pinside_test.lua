-- Round 37 e: the pin keeps to the rider's side. On the folded booking card with the dial showing, the route header's box
-- is wide (x 18 to about 201) and the rider's dot sits inside it at x 180; a destination south or south-west of the
-- rider had its pin pushed right past the whole header (up to 200 px) and ended on the east side of the dot, the route
-- line drawn to it. The pin now takes the smaller of the two moves that clear a box (right past it, up over it), so a
-- pin south-west of the dot stays west of it. The back button's box can never be cleared upwards: it still moves right.
local T = ...
local H, test, ok = T.H, T.test, T.ok
local X = dofile(T.dir .. "/layout/extra_screens.lua")

local function booking(spot, dest, flight)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = spot })
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

local function placeAt(w, r, s, x, y)
	local mapID = s.map.artFor
	r.W.ExactPlace = function(name) if name == "Undercity" then return { name = "Undercity", mapID = mapID, x = x, y = y } end end
	r.W.UI.RefreshNow()
	w:advance(0.5)
end

local function meet(a, b) return a and b and a.l < b.r - 0.5 and b.l < a.r - 0.5 and a.t < b.b - 0.5 and b.t < a.b - 0.5 end
local function cx(b) return (b.l + b.r) / 2 end
local function txt(b) return string.format("x %.0f..%.0f y %.0f..%.0f", b.l, b.r, b.t, b.b) end

-- nothing overlaps: the strip's own problems (pin, you dot, sheet, header) and the back button
local function clear(s, ends, what)
	local o = X.stripBoxes(s, ends)
	local bad = X.stripProblems(o)
	if os and os.getenv and os.getenv("WUBER_STRIP_PROBE") then print("STRIP " .. what .. ": " .. X.stripText(o)) end
	ok(#bad == 0, what .. ": " .. (#bad > 0 and table.concat(bad, "; ") or "clear") .. " [" .. X.stripText(o) .. "]")
	local back = X.stripBox(s.map, s.back)
	ok(not meet(o.pin, back), what .. ": the pin is clear of the back button")
	ok(not meet(o.pin, o.you), what .. ": the pin is clear of the you dot")
	return o
end

test("r37 e: the pin keeps to the rider's side - south-west of the dot, with the dial, it stays west of it", function()
	local w, r, s, ends = booking("Orgrimmar", "Ratchet", 1500)
	ok(H.visible(s.dial), "the dial shows")
	local o = clear(s, ends, "Orgrimmar to Ratchet")
	ok(o.pin and o.you, "pin and you dot show")
	ok(cx(o.pin) < cx(o.you), "Orgrimmar to Ratchet: the pin (" .. txt(o.pin) .. ") is left of the you dot (" .. txt(o.you) .. ")")
	T.clean(w)
	local w2, r2, s2, e2 = booking("Orgrimmar", "Undercity", 1500)
	local mp = s2.map
	local p0 = (X.stripBoxes(s2, e2)).you
	placeAt(w2, r2, s2, 0.30, 0.95)
	local o2 = clear(s2, e2, "forced low left")
	ok(o2.pin and cx(o2.pin) < cx(o2.you), "forced low left: the pin (" .. txt(o2.pin) .. ") is left of the you dot (" .. txt(o2.you) .. ")")
	T.clean(w2)
end)

test("r37 e: a destination south-east (right of the header, low) keeps the pin right of the dot", function()
	local w, r, s, ends = booking("Orgrimmar", "Undercity", 1500)
	placeAt(w, r, s, 0.97, 0.95)
	local o = clear(s, ends, "south-east")
	ok(o.pin and cx(o.pin) > cx(o.you), "south-east: the pin (" .. txt(o.pin) .. ") is right of the you dot (" .. txt(o.you) .. ")")
	T.clean(w)
end)

test("r37 e: a destination straight below the dot - nothing overlaps", function()
	local w, r, s, ends = booking("Orgrimmar", "Undercity", 1500)
	local o0 = X.stripBoxes(s, ends)
	local mp = s.map
	local _, _, _, ox, up = mp.canvas:GetPoint()
	local cw, ch = mp.canvas:GetWidth(), mp.canvas:GetHeight()
	local fx = (cx(o0.you) - ox) / cw
	placeAt(w, r, s, fx, 0.95)
	local o = clear(s, ends, "straight below")
	ok(o.pin ~= nil, "the pin shows")
	if o.pin then ok(true, "straight below: the pin lands at " .. txt(o.pin) .. ", the dot at " .. txt(o.you)) end
	T.clean(w)
end)

test("r37 e: control - a destination under the back button (no dial) still goes right past it", function()
	local w, r, s, ends = booking("Orgrimmar", "Undercity", nil)
	ok(not H.visible(s.dial), "no dial")
	placeAt(w, r, s, 0.05, 0.5)
	local o = clear(s, ends, "under the back button")
	local halfW = 23 -- the pin is 46 wide
	local back = s.map.avoid[1]
	local want = back.r + 6 + halfW
	ok(o.pin and math.abs(cx(o.pin) - want) < 1.5, "under the back button: the pin's centre x " .. (o.pin and string.format("%.1f", cx(o.pin)) or "nil") .. " is the old rule's " .. want .. " (back.r + 6 + halfW)")
	T.clean(w)
end)
