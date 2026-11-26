-- Design round 3, group F3 (the rider's side): the layouts the new text sizes broke. Each test names the shot it mends.
--   done_paid: the "You saved about 10 min of flying · saved to your trips" line wraps whole and its pill grows
--   16_pay: the line under "You've arrived" never runs over the map's rider dot
--   21_trips: the Wrapped chip's right end is on the cards' edge
--   78_settings_invite: the row title "Group size" stays on one line (its long caption goes under it)
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local MIA = "Mia Runner"
local function R(f) return H.rect(f) end

local function riderWithRide(state, extra)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local ride = { id = "d3f3", driver = MIA, driverKey = "mia runner", dest = "Undercity", price = 5000, state = state,
		at = r.env.GetTime(), payee = MIA, payto = "Mia", service = "Mia's Rides", flightCost = 2300, flightExact = 1 }
	for k, v in pairs(extra or {}) do ride[k] = v end
	r.W.ride = ride
	r.W.db.tipPct = 20
	r.W.Fire("RIDE")
	return w, r
end

test("d3 f3: done: the time-saved line is whole on two lines and its strip grows to hold them", function()
	local w, r = riderWithRide("done", { paid = 6000, saved = 840 })
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("done")
	w:advance(3)
	local s = r.W.UI.state.screens.done
	local fs = s.saved
	eq(fs.wuberText, "You saved about 14 min of flying · saved to your trips", "the words, all of them")
	ok(fs.wuberWrapped == true, "it wraps instead of being cut")
	ok(H.truncation(fs, true) == nil, "nothing cut")
	local p = R(s.savedPill)
	eq(s.savedPill:GetHeight(), 48, "the strip is a line taller")
	local t = R(fs)
	ok(t.l >= p.l - 0.5 and t.l + t.w <= p.l + p.w + 0.5 and t.b >= p.b - 0.5 and t.b + t.h <= p.b + p.h + 0.5, "the words stay inside the strip")
	local f = R(s.flightPill)
	ok(f.b + f.h <= p.b + 0.5 or p.b + p.h <= f.b + 0.5, "the flight strip is clear of it")
	local d = R(s.done)
	ok(f.l + f.w <= d.l + 0.5 or d.l + d.w <= f.l + 0.5 or f.b >= d.b + d.h - 0.5 or d.b >= f.b + f.h - 0.5, "and clear of Done")
	T.clean(w)
end)

test("d3 f3: pay: the long line under the title wraps short of the rider dot, which stays (fix round)", function()
	local w, r = riderWithRide("arrived", {})
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(3)
	local s = r.W.UI.state.screens.found
	eq(s.mode, "pay", "the pay look")
	ok(s.sub:IsShown() and s.sub.wuberText:find("Welcome to Undercity", 1, true), "the line: " .. tostring(s.sub.wuberText))
	eq(s.map.me:GetAlpha(), 1, "the dot stays: the line wraps instead")
	-- the same look with a short line (a place with a short name) keeps the dot
	r.W.ride.dest = "Rut"
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(s.sub.wuberText:find("Welcome to Rut", 1, true), "the short line: " .. tostring(s.sub.wuberText))
	eq(s.map.me:GetAlpha(), 1, "the dot stays under a short line")
	T.clean(w)
end)

test("d3 f3: trips: the Wrapped chip's right end stands on the cards' edge", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.db.rides = {}
	for i = 1, 4 do
		W.db.rides[i] = { at = os.time({ year = 2026, month = 10, day = i, hour = 12, min = 0, sec = 0 }), dest = "Undercity", driver = MIA,
			driverKey = "mia runner", price = 5000, saved = 600 }
	end
	W.RebuildTotals()
	W.UI.Toggle(true)
	w:advance(1)
	W.UI.SelectTab("Trips")
	w:advance(1)
	local tr = W.UI.trips
	local chip = tr.wrapChip
	ok(chip, "the chip exists")
	local c = R(chip:GetParent())
	local k = R(chip)
	local scale = k.w / chip:GetWidth() -- the shot's units per layout unit
	local gap = (c.l + c.w - (k.l + k.w)) / scale	ok(math.abs(gap - W.Mod("UI.Kit").PAD) < 0.5, "the chip ends one page margin from the page's right edge, as the cards do: " .. tostring(gap))
	T.clean(w)
end)

test("d3 f3: settings > driving: the row title 'Group size' stays on one line; its caption goes under it, whole", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("driving")
	w:advance(1)
	local st = d.W.UI.settings
	local sl = st.controls["drive.maxGroup"]
	ok(sl, "the Group size slider")
	local row = sl
	while row and row.titleText ~= "Group size" do row = row.GetParent and row:GetParent() or nil end
	ok(row, "its row")
	eq(row.title.paraLines, 1, "the title is one line")
	eq(row.subText, "auto: 5, or 10 with a crew of 3+", "the caption is whole")
	ok(row.sub and row.sub:IsShown(), "the caption is the row's second line")
	T.clean(w)
end)
