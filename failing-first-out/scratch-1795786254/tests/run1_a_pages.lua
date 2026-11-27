-- In-game run 1, group a: Settings drawn over a leftover page (screenshot WoWScrnShot_112226_164940: the Trips page
-- over the Settings rows and its back chevron), the Options > AddOns > Wuber "Open Wuber settings" button (it opened
-- Wuber on the Ride screen under the game's Options, and settingsOpen said true while nothing showed), and the
-- back chevron that must return to the screen Settings came from. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function login(prepare)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768, prepare = prepare })
	T.settle(w)
	return w, r, r.W.UI, r.W.Mod("UI.Settings.Rows").st
end

-- from tab name: open Settings with the cog, check the page under it is gone, come back with the chevron; twice
local function roundTrip(w, r, UI, st, name)
	local ui = UI.state
	local body = UI.GetTab(name)
	for round = 1, 2 do
		local at = " (" .. name .. ", round " .. round .. ")"
		ok(H.visible(body), "the " .. name .. " page shows" .. at)
		r:clickOn(ui.gear)
		w:advance(1)
		ok(UI.SettingsShown() and H.visible(st.panel), "Settings shows" .. at)
		eq(ui.settingsOpen, true, "settingsOpen says so" .. at)
		ok(not H.visible(body), "the " .. name .. " page under Settings is hidden" .. at)
		eq(r:clickOn(st.back), st.back, "the back chevron is on top and takes the click" .. at)
		w:advance(1)
		ok(not UI.SettingsShown(), "back leaves Settings" .. at)
		eq(ui.settingsOpen, false, "settingsOpen says so" .. at)
		eq(ui.tab, name, "back returns to " .. name .. at)
		ok(H.visible(body), "the " .. name .. " page shows again" .. at)
		ok(H.visible(ui.gear), "the cog is back" .. at)
	end
end

test("run1 a: Settings from the Trips tab hides Trips; the chevron goes back to Trips, twice", function()
	local w, r, UI, st = login()
	UI.Toggle(true)
	w:advance(3)
	ok(UI.SelectTab("Trips"), "the Trips tab opens")
	w:advance(1)
	roundTrip(w, r, UI, st, "Trips")
	T.clean(w)
end)

test("run1 a: Settings from the Ride tab hides Ride; the chevron goes back to Ride, twice", function()
	local w, r, UI, st = login()
	UI.Toggle(true)
	w:advance(3)
	roundTrip(w, r, UI, st, "Ride")
	T.clean(w)
end)

test("run1 a: Help over Settings hides the tab too; closing both brings the tab back", function()
	local w, r, UI, st = login()
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Trips")
	w:advance(1)
	local body = UI.GetTab("Trips")
	UI.OpenHelp()
	w:advance(1)
	ok(not H.visible(body), "Trips is hidden under Help")
	UI.CloseHelp()
	w:advance(1)
	ok(H.visible(body), "Help shut (no Settings under it): Trips is back")
	T.clean(w)
end)

local function withOptions(env, client) T.H.fakeOptionsList(env, client, "new") end

test("run1 a: Open Wuber settings (Options > AddOns) opens Wuber on Settings, above the game's Options", function()
	local w, r, UI, st = login(withOptions)
	local ui = UI.state
	-- the player was on Trips last time, then shut the window
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Trips")
	w:advance(1)
	UI.Toggle(false)
	w:advance(1)
	ok(not UI.IsShown(), "the window is shut")
	local f = r.settingsCats[1].frame
	f:Show()
	f.openBtn:Click()
	w:advance(1)
	ok(UI.IsShown(), "the window opens")
	ok(UI.SettingsShown() and H.visible(st.panel), "on the Settings page")
	eq(ui.settingsOpen, true, "settingsOpen matches what shows")
	ok(not H.visible(UI.GetTab("Trips")), "the Trips page is not drawn under it")
	eq(ui.win:GetFrameStrata(), "FULLSCREEN_DIALOG", "above the game's Options window (DIALOG and lower)")
	eq(r.gameOptionsClosed or 0, 0, "the game's own window is never closed")
	-- the chevron goes back to the tab, and the cog opens Settings again (it does not make anything vanish)
	r:clickOn(st.back)
	w:advance(1)
	ok(UI.IsShown(), "the window stays")
	ok(not UI.SettingsShown(), "Settings left")
	eq(ui.settingsOpen, false, "settingsOpen matches")
	ok(H.visible(UI.GetTab("Trips")), "back on Trips")
	r:clickOn(ui.gear)
	w:advance(1)
	ok(UI.SettingsShown() and ui.settingsOpen == true, "the cog opens Settings again")
	-- shut and opened the usual way: the usual layer again
	UI.Toggle(false)
	w:advance(1)
	UI.Toggle(true)
	w:advance(3)
	eq(ui.win:GetFrameStrata(), "HIGH", "opened the usual way: the usual layer")
	T.clean(w)
end)

test("run1 a: Open Wuber settings while the window is still zooming shut: Settings shows, the window stays", function()
	local w, r, UI, st = login(withOptions)
	local ui = UI.state
	UI.Toggle(true)
	w:advance(3)
	UI.Toggle(false) -- the zoom out runs for a moment
	local f = r.settingsCats[1].frame
	f:Show()
	f.openBtn:Click()
	w:advance(2)
	ok(UI.IsShown(), "the window is open")
	ok(UI.SettingsShown(), "on Settings")
	eq(ui.settingsOpen, UI.SettingsShown(), "settingsOpen matches what shows")
	T.clean(w)
end)

test("run1 a: the cog never closes a Settings page that is not on screen", function()
	local w, r, UI, st = login()
	local ui = UI.state
	UI.Toggle(true)
	w:advance(3)
	-- a stale flag (as seen in game: settingsOpen true with nothing shown)
	ui.settingsOpen = true
	st.panel:Hide()
	if UI.PaintGear then UI.PaintGear(false) end
	ui.settingsOpen = true
	ui.gear:Click()
	w:advance(1)
	ok(UI.SettingsShown(), "the cog opens Settings")
	eq(ui.settingsOpen, true)
	T.clean(w)
end)

test("run1 a: wide (unfolded) window: the Ride page is hidden under Settings and back again after (shot 165909)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	T.settle(w)
	local UI = r.W.UI
	local ui, st = UI.state, r.W.Mod("UI.Settings.Rows").st
	UI.Toggle(true)
	w:advance(3)
	if not UI.Fold.IsUnfolded() then UI.Fold.Toggle() w:advance(1) end
	local body = UI.GetTab("Ride")
	UI.OpenSettings()
	w:advance(1)
	ok(UI.SettingsShown(), "Settings shows (unfolded: " .. tostring(UI.Fold.IsUnfolded()) .. ")")
	ok(not H.visible(body), "the Ride page under it is hidden, whatever its frame levels")
	UI.CloseSettings()
	w:advance(1)
	ok(H.visible(body), "the Ride page is back")
	T.clean(w)
end)

test("run1 a: E1-01: clicking the top-right X on Settings (opened from Options) closes Settings back to the page, keeping Wuber and Options open", function()
	local w, r, UI, st = login(withOptions)
	local ui = UI.state
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Trips")
	w:advance(1)
	UI.Toggle(false)
	w:advance(1)
	local f = r.settingsCats[1].frame
	f:Show()
	f.openBtn:Click()
	w:advance(1)
	ok(UI.IsShown() and UI.SettingsShown(), "Wuber opened on Settings")
	eq(r:clickOn(ui.close), ui.close, "top-right X takes the click")
	w:advance(2)
	ok(UI.IsShown(), "Wuber window stays open")
	ok(not UI.SettingsShown(), "Settings closes")
	eq(ui.settingsOpen, false, "settingsOpen is false")
	ok(H.visible(UI.GetTab("Trips")), "back on Trips")
	eq(ui.win:GetFrameStrata(), "FULLSCREEN_DIALOG", "still above Options")
	eq(r.gameOptionsClosed or 0, 0, "the game's Options stays open")
	-- clicking the top-right X again (now on Trips) closes Wuber
	eq(r:clickOn(ui.close), ui.close, "top-right X on Trips takes the click")
	w:advance(2)
	ok(not UI.IsShown(), "Wuber closes on the second X click")
	T.clean(w)
end)
