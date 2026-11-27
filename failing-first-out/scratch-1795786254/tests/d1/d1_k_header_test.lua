-- Design round 1, group K: the fold button's word, a cog that is never gold, the Ride screen's bell as a button
-- with words, and one x on Wrapped. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function openWindow()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	r.wide = true
	T.settle(w)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	return w, r, r.W.UI.state
end

local function near(a, b, x) return math.abs(a - b) <= (x or 0.01) end

local function isGold(g)
	local r, gg, b = g:GetVertexColor()
	local c = type(r) == "number" and { r, gg, b } or { 1, 1, 1 }
	local gold = r and r > 0.85 and gg > 0.6 and gg < 0.9 and b < 0.5
	return gold, c
end

test("d1 k: the fold button says Wide while narrow and Narrow while wide, and still fits the top bar", function()
	local w, r, ui = openWindow()
	local b = ui.phone.fold
	ok(b:IsShown(), "the fold button is up")
	-- the wide screen opens this page wide
	eq(b.word:GetText(), "Narrow", "wide: a click makes it narrow")
	b:Click()
	w:advance(1)
	eq(b.word:GetText(), "Wide", "narrow: a click makes it wide")
	-- (design 2, C) the tabs left the top for the bar at the bottom: none is beside the fold button any more
	for _, tab in ipairs(ui.tabs) do
		ok(tab.button:GetTop() <= b:GetBottom(), "the " .. tab.name .. " tab is below the header's buttons")
	end
	ok(b:GetRight() <= ui.gear:GetLeft(), "and ends before the cog")
	b:Click()
	w:advance(1)
	eq(b.word:GetText(), "Narrow", "and wide again")
	T.clean(w)
end)

test("d1 k: the cog is white, never gold, on a Settings page", function()
	local w, r, ui = openWindow()
	local UI = r.W.UI
	UI.OpenSettings()
	w:advance(1)
	ok(ui.settingsOpen, "Settings is open")
	local gold, c = isGold(ui.gear.glyph)
	ok(not gold, "the cog is not gold while Settings is open")
	ok(near(c[1], c[2], 0.1) and near(c[2], c[3], 0.1) and c[1] > 0.9, "it is white")
	UI.CloseSettings()
	w:advance(1)
	ok(not isGold(ui.gear.glyph), "and not gold after")
	T.clean(w)
end)

test("d1 k: Wrapped shows one x; the window's x comes back", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.db.rides = {}
	for i = 1, 5 do
		W.db.rides[i] = { at = os.time({ year = 2026, month = 10, day = i, hour = 12, min = 0, sec = 0 }), dest = "Undercity", driver = "Mia Runner",
			driverKey = "mia runner", price = 5000, saved = 600 }
	end
	W.RebuildTotals()
	W.UI.Toggle(true) w:advance(1)
	W.UI.SelectTab("Trips") w:advance(1)
	local ui = W.UI.state
	ok(ui.close and H.visible(ui.close), "the window's x shows on Trips")
	local Mod = W.Mod("UI.Rider.Wrapped")
	ok(Mod.Open(2026, 10), "Wrapped opens")
	w:advance(1)
	ok(H.visible(Mod.Story().close), "Wrapped's own x shows")
	ok(not H.visible(ui.close), "the window's x steps aside: one x")
	Mod.Close()
	w:advance(1)
	ok(H.visible(ui.close), "the window's x is back")
	T.clean(w)
end)

test("d1 k: the Ride screen has a button 'Tell me when one opens' and no bell-only round button", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d) w:advance(5)
	for _, dv in pairs(r.W.drivers) do dv.dest = "Feathermoon Stronghold" end
	r.W.UI.Toggle(true) w:advance(2.5)
	r.W.UI.Show("home") w:advance(1)
	r.W.UI.SetSearch("Feathermoon Stronghold") w:advance(1)
	r.W.UI.RefreshNow() w:advance(0.3)
	local label = r:findText("^Tell me when one opens$", true)[1]
	ok(label, "the words are drawn")
	local btn = label:GetParent()
	ok(btn:IsObjectType("Button") and H.visible(btn), "on a visible button")
	ok((btn:GetWidth() or 0) > 60, "wider than a round icon")
	eq(r:findText("^%d+ open · %d+ online$", true)[1] ~= nil, true, "the count line keeps its text")
	local home = r.W.UI.state
	ok(not (home.homeSheet and home.homeSheet.bell and home.homeSheet.bell.glyph), "no bell-only round button")
	local before = btn.watching
	btn:Click() w:advance(0.5)
	r.W.UI.RefreshNow() w:advance(0.3)
	ok(btn.watching ~= before, "a click flips it")
	ok(btn.tick:IsShown() ~= btn.icon:IsShown(), "on shows a tick instead of the bell: not colour alone")
	T.clean(w)
end)
