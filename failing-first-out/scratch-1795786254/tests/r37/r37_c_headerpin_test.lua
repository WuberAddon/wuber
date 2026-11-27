-- Round 37 c: REV-r37-1, on the booking card (folded) the route header's words ("Tarren Mill > Undercity") sat
-- half over the destination pin once the Fly or summon dial showed (the sheet moves up and the header with it). The
-- pin gives way to the header as it does to the back button: its box and the header's never meet, the dial shown or
-- not, and it stays on the map strip, clear of the back button and the you dot. The route's end follows the pin.
local T = ...
local H, test, ok = T.H, T.test, T.ok

local function meet(a, b)
	return a and b and a.l < b.l + b.w and b.l < a.l + a.w and a.b < b.b + b.h and b.b < a.b + a.h
end
local function box(r) return r and string.format("(%d,%d %dx%d)", r.l, r.b, r.w, r.h) or "nil" end

-- the rider (in Tarren Mill) on the booking card for Mia Runner (to Undercity); flight: seconds of flying (nil: none)
local function booking(flight, opts)
	local w = T.newWorld()
	opts = opts or {}
	opts.spot = opts.spot or "Tarren Mill"
	local r = T.rider(w, T.TESTCHAR, opts)
	w:advance(15)
	local W = r.W
	W.TravelSaved = function() if flight then return flight, "same continent", true end end
	if not flight then W.UI.FlightCostTo = function() return nil end end
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Undercity", price = 5000, state = "open",
		team = 3, queue = 0, service = "Mia's Rides", heard = r.env.GetTime() }
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Show("confirm", "mia runner")
	w:advance(1.5)
	W.UI.RefreshNow()
	w:advance(0.5)
	return w, r, W.UI.state.screens.confirm
end

-- puts Undercity on the strip where the pin's tip lands under the middle of the header's word (region), and redraws
local function aimAt(w, r, s, region)
	local W, m = r.W, s.map
	local mr, rr, e = H.rect(m), H.rect(region), H.effScale(m)
	local px = (rr.l + rr.w / 2 - mr.l) / e
	local py = (mr.b + mr.h - rr.b) / e
	local _, _, _, ox, up = m.canvas:GetPoint()
	local cw, ch = m.canvas:GetWidth(), m.canvas:GetHeight()
	local mapID = r.env.C_Map.GetBestMapForUnit("player")
	local x, y = (px - ox) / cw, (py + up) / ch
	W.ExactPlace = function(name) if name == "Undercity" then return { name = "Undercity", mapID = mapID, x = x, y = y } end end
	W.UI.RefreshNow()
	w:advance(0.5)
end

local function check(s, what)
	local m, pin, route = s.map, s.map.destPin, s.route
	ok(H.visible(pin), what .. ": the pin shows")
	ok(H.visible(route), what .. ": the route header shows")
	local p, to, from, arrow = H.rect(pin), H.rect(route.to), H.rect(route.from), H.rect(route.arrow)
	ok(not meet(p, to), what .. ": the pin " .. box(p) .. " is clear of the header's place " .. box(to))
	ok(not meet(p, from), what .. ": the pin " .. box(p) .. " is clear of the header's from-place " .. box(from))
	ok(not meet(p, arrow), what .. ": the pin is clear of the header's arrow")
	ok(not meet(p, H.rect(route)), what .. ": the pin " .. box(p) .. " is clear of the header " .. box(H.rect(route)))
	local mr = H.rect(m)
	ok(p.l >= mr.l and p.l + p.w <= mr.l + mr.w and p.b + p.h <= mr.b + mr.h and p.b >= mr.b,
		what .. ": the pin " .. box(p) .. " is inside the map strip " .. box(mr))
	ok(not meet(p, H.rect(s.back)), what .. ": the pin " .. box(p) .. " is clear of the back button " .. box(H.rect(s.back)))
	if H.visible(m.me) then ok(not meet(p, H.rect(m.me)), what .. ": the pin is clear of the you dot " .. box(H.rect(m.me))) end
	ok(p.b >= H.rect(s.card).b + H.rect(s.card).h - 1, what .. ": the pin's tip is above the sheet")
end

test("r37 c: REV-r37-1 - folded, with a flight time known (the dial shows), the pin is clear of the route header", function()
	for _, size in ipairs({ { 1920, 1080 }, { 1365, 768 }, { 3840, 2160 } }) do
		local w, r, s = booking(1500, { screenW = size[1], screenH = size[2] })
		ok(H.visible(s.dial), size[1] .. ": the Fly or summon dial shows")
		ok(s.cardTop < 168, size[1] .. ": the sheet moved up for the dial (top " .. tostring(s.cardTop) .. ")")
		aimAt(w, r, s, s.route.to)
		check(s, "dial, on the place, " .. size[1] .. " x " .. size[2])
		aimAt(w, r, s, s.route.from)
		check(s, "dial, on the from-place, " .. size[1] .. " x " .. size[2])
		T.clean(w)
	end
end)

test("r37 c: REV-r37-1 - folded, no flight time (no dial), the pin is still clear of the route header", function()
	local w, r, s = booking(nil)
	ok(not H.visible(s.dial), "no dial without a flight time")
	aimAt(w, r, s, s.route.to)
	check(s, "no dial, on the place")
	aimAt(w, r, s, s.route.from)
	check(s, "no dial, on the from-place")
	T.clean(w)
end)

test("r37 c: REV-r37-1 - the pin follows the header when the card restacks and the header changes", function()
	local w, r, s = booking(nil)
	local W = r.W
	aimAt(w, r, s, s.route.to)
	check(s, "no dial")
	-- the dial comes: the sheet moves up, the header with it, and the pin is aimed at the header's new place
	W.TravelSaved = function() return 1500, "same continent", true end
	W.UI.RefreshNow()
	w:advance(0.5)
	ok(H.visible(s.dial), "the dial shows now")
	aimAt(w, r, s, s.route.to)
	check(s, "the dial after a refresh")
	-- a longer from-place: the header grows to the right over the pin's old place
	local Booking = W.Mod("UI.Rider.Booking")
	Booking.RouteFrom = function() return "Hillsbrad Foothills" end
	W.UI.RefreshNow()
	w:advance(0.5)
	check(s, "a longer from-place")
	-- the dial goes again: the header goes back down
	W.TravelSaved = function() end
	W.UI.FlightCostTo = function() return nil end
	W.UI.RefreshNow()
	w:advance(0.5)
	ok(not H.visible(s.dial), "the dial is gone again")
	aimAt(w, r, s, s.route.to)
	check(s, "the dial gone again")
	T.clean(w)
end)

test("r37 c: REV-r37-1 - a header as wide as the card (a long from-place and a crossing): the pin goes up over it", function()
	for _, flight in ipairs({ 1500, false }) do
		local w, r, s = booking(flight or nil)
		local W = r.W
		local Booking = W.Mod("UI.Rider.Booking")
		Booking.RouteFrom = function() return "Hillsbrad Foothills, by the old mill" end
		Booking.Via = function() return "zeppelin" end
		W.UI.RefreshNow()
		w:advance(0.5)
		local what = flight and "dial" or "no dial"
		ok(H.visible(s.route.via), what .. ": the crossing shows in the header")
		for _, part in ipairs({ "from", "arrow", "to", "via" }) do
			aimAt(w, r, s, s.route[part])
			check(s, what .. ", wide header, on its " .. part)
		end
		T.clean(w)
	end
end)

test("r37 c: REV-r37-1 - no route header (standing in the driver's place): no pin, nothing to avoid", function()
	local w, r, s = booking(1500)
	local W = r.W
	W.AlreadyAt = function() return "Undercity" end
	W.UI.RefreshNow()
	w:advance(0.5)
	ok(not H.visible(s.route), "no route header in the driver's place")
	ok(not H.visible(s.map.destPin), "no portal pin in the driver's place")
	T.clean(w)
end)
