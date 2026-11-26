-- Group G, break-it guards for the test side of 2.4.1 (job 415). Loaded by tests/run.lua with its helper table T.
-- Each test passes on the real 2.4.1 code and fails when the named line is broken on purpose.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function openWin()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768 })
	T.settle(w)
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state, r.W.UI
end

local function ride(r, w, st)
	r.W.ride = { id = "h24g", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = st,
		at = r.env.GetTime(), service = "Bea's Rides" }
	r.W.Fire("RIDE")
	r.W.UI.RefreshNow()
	w:advance(2)
end

local function raincheck(r, w)
	r.W.Raincheck.Mine = function()
		return { { id = "rc1", state = "offered", driver = "Anita Lift", cover = 5000,
			expires = os.time({ year = 2026, month = 11, day = 19, hour = 12, min = 0, sec = 0 }) + 6 * 86400 } }
	end
	local f = r.W.UI.RaincheckOffer()
	w:advance(1)
	return f
end

local function catchers(f, x, y, out, seen)
	out, seen = out or {}, seen or {}
	if seen[f] then return out end
	seen[f] = true
	if f.IsShown and f:IsShown() then
		local rc = H.rect(f)
		if f.IsMouseEnabled and f:IsMouseEnabled() and rc.l <= x and x <= rc.l + rc.w and rc.b <= y and y <= rc.b + rc.h then
			out[#out + 1] = f
		end
		for _, c in ipairs({ f:GetChildren() }) do catchers(c, x, y, out, seen) end
	end
	return out
end

-- a point of the dim below the header strip, left of the card's content: where a click means "close the sheet"
local function dimPoint(sh, ui, UI)
	local wr = H.rect(ui.win)
	local k = wr.h / ui.win:GetHeight()
	return wr.l + 6, wr.b + wr.h - (UI.HEAD_H + 12) * k
end

-- guard: break-it, Wuber/Theme/Forms.lua:545 sh.catch:EnableMouse(true) -> false (the dim below the header strip stops taking the mouse: a click goes through to the page and no longer closes the sheet)
test("h24 bk g1: the dim below the header strip still takes the click and closes the Report a bug sheet", function()
	local w, r, ui, UI = openWin()
	ok(UI.Bug.Open(), "the report opens")
	w:advance(1)
	local sh = UI.Bug.frame
	local x, y = dimPoint(sh, ui, UI)
	local hits = catchers(sh, x, y)
	ok(#hits >= 1, "something of the sheet takes the mouse on the dim below the header strip")
	local c = hits[1]
	local fn = c and c:GetScript("OnMouseDown")
	ok(fn, "and it closes the sheet on a click")
	if fn then fn(c) end
	w:advance(1)
	ok(not sh.open, "the sheet is closed by the click on its dim")
	T.clean(w)
end)

-- guard: break-it, Wuber/Theme/Forms.lua:545 sh.catch:EnableMouse(true) -> false, same line, on the raincheck sheet
test("h24 bk g2: the dim below the header strip still takes the click and closes the raincheck sheet", function()
	local w, r, ui, UI = openWin()
	local f = raincheck(r, w)
	ok(f and f.dim, "the offer is up")
	local x, y = dimPoint(f, ui, UI)
	local hits = catchers(f, x, y)
	ok(#hits >= 1, "something of the sheet takes the mouse on the dim below the header strip")
	local c = hits[1]
	local fn = c and c:GetScript("OnMouseDown")
	ok(fn, "and it closes the sheet on a click")
	if fn then fn(c) end
	w:advance(1)
	ok(not f.open, "the sheet is closed by the click on its dim")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Bug.lua:449 the OnUpdate line "if f.foot ~= sheetFoot() then place(f) layout(f) end" removed (a ride starts while the report is open: the tab bar goes, the sheet stays 56 above the foot)
test("h24 bk g3: a ride that starts while Report a bug is open takes the sheet down to the phone's foot", function()
	local w, r, ui, UI = openWin()
	ok(not UI.TabsHidden(), "Home: the tab bar shows")
	ok(UI.Bug.Open(), "the report opens")
	w:advance(1)
	local sh = UI.Bug.frame
	ride(r, w, "summoning")
	w:advance(1)
	if not sh.open then
		-- the ride closed the report by itself: nothing left to rest anywhere
		T.clean(w)
		return
	end
	ok(UI.TabsHidden(), "the tab bar is away")
	local cr, wr = H.rect(sh.card), H.rect(ui.win)
	ok(math.abs(cr.b - wr.b) <= 0.6, ("the sheet rests on the foot (card bottom %.1f, window bottom %.1f)"):format(cr.b, wr.b))
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Moments.lua:405 the OnUpdate line "if f.foot ~= sheetFoot() then placeOffer(f) end" removed
test("h24 bk g4: a ride that starts while the raincheck offer is open takes the sheet down to the phone's foot", function()
	local w, r, ui, UI = openWin()
	local f = raincheck(r, w)
	ok(f and f.dim, "the offer is up")
	ride(r, w, "summoning")
	w:advance(1)
	if not f.open then T.clean(w) return end
	ok(UI.TabsHidden(), "the tab bar is away")
	local cr, wr = H.rect(f.card), H.rect(ui.win)
	ok(math.abs(cr.b - wr.b) <= 0.6, ("the sheet rests on the foot (card bottom %.1f, window bottom %.1f)"):format(cr.b, wr.b))
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Bird.lua:394 the TAXIMAP_CLOSED handler's card:Hide() removed (the card then waits for the once-a-second check, so it stays up for up to a second after the flight map is gone: the promise bird.goes_by_itself only looks after time has passed)
local NODES = { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 580, x = 0.47, y = 0.44 } }
-- guard: break-it (the break this test catches is named in the guard comment above)
test("h24 bk g5: Skip the bird goes at once when the flight map closes, not a second later", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime() }
	W.FlightCost = function() return 2300, 1 end
	W.FlightTime = function() return 540, "est" end
	local Mod = W.Mod("UI.Bird")
	w:openTaxiMap(r, NODES) w:advance(0.5)
	ok(Mod.Card() and H.visible(Mod.Card()), "control: the card shows")
	w:advance(5)
	ok(H.visible(Mod.Card()), "and stays while the map is open (no timer hides it)")
	w:closeTaxiMap(r)
	ok(not H.visible(Mod.Card()), "gone at the moment the flight map closes")
	T.clean(w)
end)

-- guard: break-it, Wuber/UI/Bird.lua:41 MIN_BACK 60 -> 59 or Wuber/UI/Bird.lua:79 >= -> > or the comparison >= -> > (the card shows or hides one second off: it is for a flight that beats the summon wait, 30 s, by at least a minute: 90 s shows, 89 s does not)
test("h24 bk g6: Skip the bird shows at a 90 s flight and not at 89 s (the summon takes 30 s, at least a minute back)", function()
	for _, c in ipairs({ { 89, false }, { 90, true } }) do
		local w = T.newWorld()
		local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
		w:advance(15)
		local W = r.W
		W.drivers = W.drivers or {}
		W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = 5000, state = "open", team = 3,
			service = "Mia's Rides", heard = r.env.GetTime() }
		W.FlightCost = function() return 2300, 1 end
		W.FlightTime = function() return c[1], "own" end
		local Mod = W.Mod("UI.Bird")
		eq(W.SUMMON_SECS, 30, "the summon wait this rests on")
		w:openTaxiMap(r, NODES) w:advance(0.5)
		eq(Mod.Card() ~= nil and H.visible(Mod.Card()) or false, c[2], "a " .. c[1] .. " s flight: the card " .. (c[2] and "shows" or "stays away"))
		w:closeTaxiMap(r)
		T.clean(w)
	end
end)
