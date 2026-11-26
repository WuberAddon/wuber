-- Tests of UI.Minimap (Wuber/UI/Minimap.lua). Loaded by tests/run.lua with its helper table T.
-- Final home: tests/ui/minimap_test.lua; add it to the per-module list in tests/run.lua.
-- Pins: UI.MayPause (a helper may not pause, a driver may, CanPause wins over the role);
-- Pins: the button's clicks (left toggles Wuber, right opens the driver console or says driving is not available,
-- Pins:   shift-right pauses and resumes only while open and only for a driver);
-- Pins: UI.FlashMinimap (magenta by default, a colour kept, off stops it) and UI.RefreshMinimap (the open-driver badge,
-- Pins:   the summon pulse while the window is shut, gold while the big button has a click);
-- Pins: where the button sits (saved angle, default 215 degrees) and that dragging saves a new angle; one button only.
-- Why it matters to a player: the minimap button is how a closed Wuber calls you ("click the portal"). If it broke, the rider
-- would miss the pulsing summon, a helper could pause the crew, and the button could jump or duplicate.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function world()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	return w, r, r.W.UI, r.env.WuberMinimapButton
end

-- every UI.Toast of the rider while fn runs: { text, kind }
local function toasts(r, fn)
	local UI, seen = r.W.UI, {}
	local orig = UI.Toast
	UI.Toast = function(msg, kind, ...) seen[#seen + 1] = { tostring(msg), kind } return orig(msg, kind, ...) end
	fn()
	UI.Toast = orig
	return seen
end

local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.01) end

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.minimap: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("UI.Minimap", "tests/ui/minimap_test.lua", {
		["UI.MayPause"] = "function", ["UI.FlashMinimap"] = "function", ["UI.RefreshMinimap"] = "function",
		["Mod.buildMinimap"] = "function", ["Mod.placeMinimap"] = "function", ["Mod.refreshMinimap"] = "function",
	})
	ok(Mod, "W.Mod(\"UI.Minimap\")")
	ok(r.env.WuberMinimapButton, "the button is built")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.minimap: MayPause - CanPause decides, else only a helper may not", function()
	local w, r, UI = world()
	local D, DR = r.W.Driver, r.W.Drive
	D.CanPause = function() return false end
	eq(UI.MayPause(), false, "CanPause says no") -- Minimap.lua:38-44
	D.CanPause = function() return true end
	eq(UI.MayPause(), true, "CanPause says yes")
	D.CanPause = function() end
	eq(UI.MayPause(), true, "CanPause says nothing: allowed (only an explicit false refuses)")
	D.CanPause = nil
	DR.Role = function() return "helper" end
	eq(UI.MayPause(), false, "no CanPause: a helper may not")
	DR.Role = function() return "driver" end
	eq(UI.MayPause(), true, "no CanPause: a driver may")
	DR.Role = nil
	eq(UI.MayPause(), true, "no role at all: allowed")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.minimap: one button, named WuberMinimapButton; building again keeps it", function()
	local w, r, UI, b = world()
	local ui = r.W.Mod("UI.Kit").ui
	ok(b, "the button")
	eq(ui.minimap, b, "the Kit's minimap is that button") -- Minimap.lua:46-48
	r.W.Mod("UI.Minimap").buildMinimap()
	eq(ui.minimap, b, "still the one button")
	eq(r.env.WuberMinimapButton, b)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.minimap: a left click opens Wuber and the next one closes it", function()
	local w, r, UI, b = world()
	if UI.IsShown() then UI.Toggle(false) w:advance(1.5) end
	ok(not UI.IsShown(), "control: closed")
	r:click(b, "LeftButton")
	w:advance(3)
	ok(UI.IsShown(), "opened") -- Minimap.lua:83
	r:click(b, "LeftButton")
	w:advance(3)
	ok(not UI.IsShown(), "closed again")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.minimap: a right click opens the driver console, or says driving isn't available", function()
	local w, r, UI, b = world()
	r.env.IsShiftKeyDown = function() return false end
	local shown
	UI.Show = function(name) shown = name return true end
	r:click(b, "RightButton")
	eq(shown, "drive", "the Drive screen") -- Minimap.lua:80
	UI.Show = function() return false end
	local seen = toasts(r, function() r:click(b, "RightButton") end)
	eq(#seen, 1, "one toast")
	eq(seen[1][1], "Driving isn't available here")
	eq(seen[1][2], "info")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.minimap: shift-right-click pauses and resumes an open crew; closed or without shift it opens the console", function()
	local w, r, UI, b = world()
	local DR = r.W.Drive
	local calls, open, paused = {}, true, false
	DR.Role = function() return "driver" end
	DR.IsOpen = function() return open end
	DR.IsPaused = function() return paused end
	DR.SetPaused = function(on) calls[#calls + 1] = on return true end
	local shown
	UI.Show = function(name) shown = name return true end
	r.env.IsShiftKeyDown = function() return true end
	local seen = toasts(r, function() r:click(b, "RightButton") end)
	eq(calls[1], true, "paused") -- Minimap.lua:71-78
	eq(seen[1][1], "Paused: no new invites")
	eq(shown, nil, "the console did not open")
	paused = true
	w:advance(3)
	seen = toasts(r, function() r:click(b, "RightButton") end)
	eq(calls[2], false, "resumed")
	eq(seen[1][1], "Resumed: inviting riders again")
	-- not open: nothing to pause, the console opens
	open = false
	w:advance(3)
	r:click(b, "RightButton")
	eq(#calls, 2, "no pause call while closed")
	eq(shown, "drive")
	-- open, but no shift: the console
	open, shown = true, nil
	r.env.IsShiftKeyDown = function() return false end
	r:click(b, "RightButton")
	eq(#calls, 2, "no pause without shift")
	eq(shown, "drive")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.minimap: FlashMinimap pulses in magenta by default, keeps a colour, and off stops it", function()
	local w, r, UI, b = world()
	ok(not b.pulse.running, "control: still")
	UI.FlashMinimap(true)
	ok(b.pulse.running, "pulsing") -- Minimap.lua:130-143
	eq(b.pulseColour, "magenta")
	UI.FlashMinimap(true, "gold")
	ok(b.pulse.running, "still pulsing")
	eq(b.pulseColour, "gold", "colour changed")
	UI.FlashMinimap(false)
	ok(not b.pulse.running, "stopped")
	UI.FlashMinimap(false)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.minimap: RefreshMinimap shows the badge only while a driver is open", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local b = r.env.WuberMinimapButton
	r.W.UI.RefreshMinimap()
	ok(not b.badge:IsShown(), "nobody open: no badge") -- Minimap.lua:145-153
	T.goOnline(d)
	w:advance(5)
	r.W.UI.RefreshMinimap()
	ok(b.badge:IsShown(), "a driver is open: the badge")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.minimap: RefreshMinimap pulses the button while the summon is up and Wuber is shut, and stops when it is open", function()
	local w, r, UI, b = world()
	if UI.IsShown() then UI.Toggle(false) w:advance(1.5) end
	r.W.ride = { id = "r6", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 5000, state = "portal", at = r.env.GetTime() }
	r.W.Fire("RIDE")
	w:advance(1)
	UI.RefreshMinimap()
	ok(b.pulse.running, "the portal is up and Wuber is shut: pulsing") -- Minimap.lua:154-158
	eq(b.pulseColour, "magenta", "summon colour")
	UI.Toggle(true)
	w:advance(3)
	UI.RefreshMinimap()
	ok(not b.pulse.running, "Wuber is open: the pulse stops")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.minimap: RefreshMinimap pulses gold while the big driver button has a click, and stops when it does not", function()
	local w, r, UI, b = world()
	if UI.IsShown() then UI.Toggle(false) w:advance(1.5) end
	local want = true
	UI.DriveWantsClick = function() return want end
	UI.RefreshMinimap()
	ok(b.pulse.running, "a click is waiting") -- Minimap.lua:159-164
	eq(b.pulseColour, "gold")
	want = false
	UI.RefreshMinimap()
	ok(not b.pulse.running, "nothing to click: stopped")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.minimap: the button sits on the minimap ring at the saved angle, 215 degrees when none is saved", function()
	local w, r, UI, b = world()
	local Mod = r.W.Mod("UI.Minimap")
	local rad = (r.env.Minimap:GetWidth() or 140) / 2 + 10
	r.W.db.minimapAngle = nil
	Mod.placeMinimap(b)
	local _, _, _, x, y = b:GetPoint(1)
	ok(near(x, math.cos(math.rad(215)) * rad, 0.1) and near(y, math.sin(math.rad(215)) * rad, 0.1), "default 215: " .. tostring(x) .. "," .. tostring(y)) -- Minimap.lua:30-34
	r.W.db.minimapAngle = 0
	Mod.placeMinimap(b)
	_, _, _, x, y = b:GetPoint(1)
	ok(near(x, rad, 0.1) and near(y, 0, 0.1), "angle 0: right of the minimap, " .. tostring(x) .. "," .. tostring(y))
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("ui.minimap: dragging the button round the minimap saves the angle; letting go stops following the mouse", function()
	local w, r, UI, b = world()
	local mm = r.env.Minimap
	local cx, cy = mm:GetCenter()
	local sc = mm:GetEffectiveScale()
	b:GetScript("OnDragStart")(b)
	r.cursorX, r.cursorY = (cx + 50) * sc, cy * sc -- right of the centre
	b:GetScript("OnUpdate")(b)
	eq(r.W.db.minimapAngle, 0, "to the right = 0 degrees") -- Minimap.lua:86-99
	r.cursorX, r.cursorY = cx * sc, (cy + 50) * sc -- above the centre
	b:GetScript("OnUpdate")(b)
	eq(r.W.db.minimapAngle, 90, "above = 90 degrees")
	local _, _, _, x, y = b:GetPoint(1)
	local rad = (mm:GetWidth() or 140) / 2 + 10
	ok(near(x, 0, 0.1) and near(y, rad, 0.1), "the button followed: " .. tostring(x) .. "," .. tostring(y))
	b:GetScript("OnDragStop")(b)
	eq(b:GetScript("OnUpdate"), nil, "no longer following")
	T.clean(w)
end)

-- NEEDS FAKE-GAME: a saved-variables world that starts with minimapHidden = true (the button must be built hidden, Minimap.lua:125);
-- T.rider's saved option takes a tests/hunt/fixtures/saved table whose layout is not documented for the drafting round.
