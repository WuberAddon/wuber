-- Design round 2, group B: the black pill comes alive (a ride grows it, words in violet and gold, a click opens the ride).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function openWindow()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	T.settle(w)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state
end

local function ride(r, w, t)
	local base = { id = "r1", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = "accepted", at = r.env.GetTime() }
	for k, v in pairs(t or {}) do base[k] = v end
	r.W.ride = base
	r.W.UI.Refresh(true)
	w:advance(2)
end

local function isViolet(fs)
	local a, b, c = fs:GetTextColor()
	return a < 0.75 and a > 0.55 and b > 0.35 and b < 0.55 and c > 0.9
end
local function isGold(fs)
	local a, b, c = fs:GetTextColor()
	return a > 0.9 and b > 0.7 and b < 0.85 and c < 0.35
end

test("d2 b: at rest the pill is 92 wide, shows no words and takes no mouse", function()
	local w, r, ui = openWindow()
	local isl = ui.phone.island
	eq(isl:GetWidth(), 92, "92 wide")
	ok(not isl.words:IsShown(), "no words")
	ok(not isl:IsMouseEnabled(), "no mouse at rest")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d2 b: a ride grows the pill; each stage says its two parts in violet and gold", function()
	local w, r, ui = openWindow()
	local isl = ui.phone.island
	local cases = {
		{ { state = "requesting" }, "Finding a driver", nil },
		{ { state = "accepted" }, "Accepted", nil },
		{ { state = "invited" }, "Invited", nil },
		{ { state = "ingroup" }, "Invited", nil },
		{ { state = "summoning" }, "Summoning", nil },
		{ { state = "portal", ritual = { phase = "h", tapped = 1, need = 2 } }, "Portal opening", "1 of 2" },
		{ { state = "summoning", ritual = { phase = "h", tapped = 1, need = 2 } }, "Portal opening", "1 of 2" },
		{ { state = "summoning", summonUp = true, ritual = { phase = "s", tapped = 2, need = 2 } }, "Portal open", "2 of 2" },
		{ { state = "arrived" }, "Arrived", "50s" },
		{ { state = "paying" }, "Arrived", "50s" },
	}
	for _, c in ipairs(cases) do
		ride(r, w, c[1])
		w:advance(2)
		local what = c[1].state .. ": "
		ok(isl:GetWidth() > 92, what .. "the pill grew (" .. isl:GetWidth() .. ")")
		ok(isl.words:IsShown(), what .. "the words are up")
		eq(isl.state:GetText(), c[2], what .. "the state")
		ok(isViolet(isl.state), what .. "the state is violet")
		if c[3] then
			eq(isl.step:GetText(), c[3], what .. "the step or price")
			ok(isGold(isl.step), what .. "gold")
		else
			ok((isl.step:GetText() or "") == "", what .. "no step")
		end
		ok(not isl:IsMouseEnabled(), what .. "the ride is already on screen: no click to take (#24)")
		ok(isl.live:IsShown(), what .. "the violet dot")
	end
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d2 b: an unknown clicker count is never shown as 0 of 0", function()
	local w, r, ui = openWindow()
	local isl = ui.phone.island
	ride(r, w, { state = "portal" })
	eq(isl.state:GetText(), "Portal open", "state only")
	ok((isl.step:GetText() or "") == "", "no step")
	ride(r, w, { state = "portal", ritual = { phase = "h", tapped = 0, need = 0 } })
	ok(not tostring(isl.step:GetText() or ""):find("0 of 0"), "never 0 of 0")
	ride(r, w, { state = "arrived", price = 0 })
	ok((isl.step:GetText() or "") == "", "no price, no gold part")
	T.clean(w)
end)

test("d2 b: the grown pill holds its words and stays clear of the clock and the signal bars, folded and unfolded", function()
	local w, r, ui = openWindow()
	local ph = ui.phone
	for _, wide in ipairs({ false, true }) do
		r.wide = wide
		r.W.db.fold = (not wide) and { v = 1, pages = {}, narrow = true } or nil
		r.W.UI.Fold.Apply()
		w:advance(1)
		for _, st in ipairs({ { state = "requesting" }, { state = "portal", ritual = { tapped = 1, need = 2 } }, { state = "arrived", price = 123456 } }) do
			ride(r, w, st)
			w:advance(2)
			local isl, clock, sig = H.rect(ph.island), H.rect(ph.clock), H.rect(ph.signal)
			local what = (wide and "unfolded " or "folded ") .. st.state .. ": "
			ok(clock.l + clock.w + 8 <= isl.l + 0.5, what .. "8 clear of the clock")
			ok(sig.l >= isl.l + isl.w + 8 - 0.5, what .. "8 clear of the signal bars")
			local bar = H.rect(ph.status)
			ok(math.abs((isl.l + isl.w / 2) - (bar.l + bar.w / 2)) < 0.5, what .. "centred")
			local need = ph.island.state:GetStringWidth() + (((ph.island.step:GetText() or "") ~= "") and ph.island.step:GetStringWidth() or 0)
			ok(need + 31 <= ph.island:GetWidth(), what .. "the words fit (" .. need .. " in " .. ph.island:GetWidth() .. ")")
			if not wide then ok(ph.island:GetWidth() <= 172, what .. "no wider than the bar allows") end
			if st.state == "portal" then eq(ph.island.step:GetText(), "1 of 2", what .. "both parts fit: the count is not dropped") end
		end
	end
	T.clean(w)
end)

test("d2 b: a click on the pill opens the ride from another tab and from Settings", function()
	local w, r, ui = openWindow()
	local UI = r.W.UI
	ride(r, w, { state = "invited" })
	ok(ui.tab == "Ride", "on the Ride tab")
	UI.SelectTab(ui.tabs[#ui.tabs].name)
	w:advance(1)
	ok(ui.tab ~= "Ride", "another tab is up")
	ui.phone.island:Click()
	w:advance(1)
	eq(ui.tab, "Ride", "the click opens the Ride tab")
	UI.OpenSettings()
	w:advance(1)
	ok(ui.settingsOpen, "Settings is open")
	ui.phone.island:Click()
	w:advance(1)
	ok(not ui.settingsOpen, "the click leaves Settings")
	eq(ui.tab, "Ride", "on the Ride tab")
	eq(ui.screen, "found", "on the ride's own screen")
	local tip = ui.phone.island.wuberTip
	eq(tip and tip.title, "Your ride", "tooltip title")
	eq(tip and tip.text, "Click to open your ride.", "tooltip body")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- Issue 24: the pill (Arrived + the fare) took clicks while the ride was already on screen, and the click did nothing visible.
-- The promise: the pill takes a click only where the click shows something new.
test("#24: the pill takes a click only when the click changes what is on screen", function()
	local w, r, ui = openWindow()
	local UI = r.W.UI
	local isl = ui.phone.island
	ride(r, w, { state = "arrived" })
	ok(ui.tab == "Ride" and not ui.settingsOpen, "the ride is on screen")
	ok(not isl:IsMouseEnabled(), "already on the ride: the pill takes no click")
	UI.SelectTab(ui.tabs[#ui.tabs].name)
	w:advance(1)
	ok(ui.tab ~= "Ride", "another tab is up")
	ok(isl:IsMouseEnabled(), "on another tab the pill takes the click")
	isl:Click()
	w:advance(1)
	eq(ui.tab, "Ride", "the click shows the ride")
	ok(not isl:IsMouseEnabled(), "back on the ride: no click again")
	UI.OpenSettings()
	w:advance(1)
	ok(isl:IsMouseEnabled(), "over Settings the pill takes the click")
	isl:Click()
	w:advance(1)
	ok(not ui.settingsOpen and not isl:IsMouseEnabled(), "Settings left, the ride shown, no click again")
	UI.Show("home")
	w:advance(1)
	ok(isl:IsMouseEnabled(), "a look at Home during the ride: the pill takes the click")
	isl:Click()
	w:advance(1)
	ok(not isl:IsMouseEnabled(), "the click went back to the ride")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

-- The rule itself, checked right after each change with no waiting: whenever the pill takes a click the click changes what is
-- on screen, and whenever it does not, a click would have changed nothing.
test("#24: the pill's click is on exactly when it would change the screen (no wait after the change)", function()
	local w, r, ui = openWindow()
	local UI = r.W.UI
	local PhoneMod = r.W.Mod("UI.Phone")
	local isl = ui.phone.island
	local function view() return table.concat({ tostring(ui.tab), tostring(ui.screen), tostring(ui.settingsOpen), tostring(ui.peek) }, "|") end
	local function judge(what)
		local before = view()
		local on = isl:IsMouseEnabled()
		PhoneMod.openRide()
		local changed = view() ~= before
		eq(on, changed, what .. ": the pill takes a click exactly when the click shows something new (" .. before .. " -> " .. view() .. ")")
	end
	for _, st in ipairs({ "accepted", "invited", "summoning", "arrived", "paying" }) do
		ride(r, w, { state = st })
		judge(st .. " on the ride")
		UI.SelectTab(ui.tabs[#ui.tabs].name)
		judge(st .. " on another tab")
		UI.OpenSettings()
		judge(st .. " over Settings")
		UI.Show("home")
		judge(st .. " a look at Home")
		judge(st .. " after the click")
	end
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d2 b: the pill shrinks back when the ride ends", function()
	local w, r, ui = openWindow()
	local isl = ui.phone.island
	ride(r, w, { state = "summoning" })
	w:advance(2)
	ok(isl:GetWidth() > 92, "grown")
	ride(r, w, { state = "done" })
	w:advance(2)
	eq(isl:GetWidth(), 92, "back to 92")
	ok(not isl.words:IsShown(), "no words")
	ok(not isl:IsMouseEnabled(), "no mouse")
	T.clean(w)
end)

test("d2 b: reduce motion sets the width at once", function()
	local w, r, ui = openWindow()
	local isl = ui.phone.island
	r.W.Theme.ReduceMotion = function() return true end
	ride(r, w, { state = "accepted" })
	local grown = isl:GetWidth()
	ok(grown > 92, "grown with no time passing")
	ride(r, w, { state = "done" })
	eq(isl:GetWidth(), 92, "and back at once")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)

test("d2 b: with motion the pill grows over several frames, not at once", function()
	local w, r, ui = openWindow()
	local isl = ui.phone.island
	r.W.db.reduceMotion = false -- with motion (T.ReduceMotion is the theme's own function now: it reads this)
	r.W.ride = { id = "r1", driver = "Bea Jones", driverKey = "bea jones", dest = "Undercity", price = 5000, state = "accepted", at = r.env.GetTime() }
	r.W.UI.UpdateStatusBar()
	ok(isl:GetWidth() < 150, "not full width on the first frame (" .. isl:GetWidth() .. ")")
	w:advance(1)
	ok(isl:GetWidth() > 92, "grown after a moment")
	T.clean(w)
end)
