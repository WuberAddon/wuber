-- E1-01 (run 2 step 4): Wuber's Settings was opened from the game's Options ("Open Wuber settings"), and the press on
-- Wuber's own X (top right) closed Wuber AND the game's Options. Now the X, while Settings is up over Options, closes
-- Settings back to the page it came from; the Wuber window and the game's Options stay open. The back arrow is as before.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local gameOptions
local function withOptions(env, client)
	T.H.fakeOptionsList(env, client, "new")
	-- the game's own Options window: a dialog Wuber's window comes up over
	gameOptions = H.createFrame(client, "Frame", "FakeGameOptionsWindow", client.env.UIParent)
	gameOptions:SetSize(600, 400)
	gameOptions:SetPoint("CENTER", client.env.UIParent, "CENTER", 0, 0)
	gameOptions:SetFrameStrata("DIALOG")
	gameOptions:EnableMouse(true)
	gameOptions:Show()
end

local function login(prepare)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1024, screenH = 768, prepare = prepare })
	T.settle(w)
	return w, r, r.W.UI, r.W.Mod("UI.Settings.Rows").st
end

-- the player was on Trips, shut Wuber, then pressed "Open Wuber settings" in the game's Options
local function openFromOptions(w, r, UI, st)
	local ui = UI.state
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Trips")
	w:advance(1)
	UI.Toggle(false)
	w:advance(1)
	r.settingsCats[1].frame:Show()
	r.settingsCats[1].frame.openBtn:Click()
	w:advance(2)
	ok(UI.IsShown() and UI.SettingsShown(), "Wuber is open on Settings")
	eq(ui.win:GetFrameStrata(), "FULLSCREEN_DIALOG", "above the game's Options")
	ok(gameOptions:IsShown(), "the game's Options is open")
end

test("e1 merged 01: the X over Options closes Settings back to the page, Wuber and the game's Options stay", function()
	local w, r, UI, st = login(withOptions)
	local ui = UI.state
	openFromOptions(w, r, UI, st)
	-- what the player pointed at: the frame that takes the mouse at the X's centre
	eq(r:clickOn(ui.close), ui.close, "Wuber's own X takes the press (not the game's Options, not the back arrow)")
	w:advance(2)
	ok(UI.IsShown(), "the Wuber window stays open")
	ok(not UI.SettingsShown(), "Settings is closed")
	eq(ui.settingsOpen, false, "settingsOpen matches")
	eq(ui.tab, "Trips", "back on the page Settings came from")
	ok(H.visible(UI.GetTab("Trips")), "that page shows")
	ok(gameOptions:IsShown(), "the game's Options is still open")
	eq(r.gameOptionsClosed or 0, 0, "the game's own window is never closed")
	-- the X with no Settings up hides Wuber, and still leaves the game's Options alone
	r:clickOn(ui.close)
	w:advance(2)
	ok(not UI.IsShown(), "the X on a page hides Wuber")
	ok(gameOptions:IsShown(), "the game's Options is still open")
	T.clean(w)
end)

-- guard: the unchanged neighbouring path: the back arrow over Options closed Settings back to the page before the E1-01 fix and still does
test("e1 merged 01: the back arrow over Options still closes Settings back to the page, Wuber and the Options stay", function()
	local w, r, UI, st = login(withOptions)
	local ui = UI.state
	openFromOptions(w, r, UI, st)
	eq(r:clickOn(st.back), st.back, "the back arrow takes the press")
	w:advance(2)
	ok(UI.IsShown(), "the Wuber window stays open")
	ok(not UI.SettingsShown(), "Settings is closed")
	eq(ui.tab, "Trips", "back on the page it came from")
	ok(gameOptions:IsShown(), "the game's Options is still open")
	T.clean(w)
end)

-- guard: the unchanged neighbouring path: the X over Settings opened by the cog hid Wuber before the E1-01 fix and still does
test("e1 merged 01: the X with Settings opened by the cog (not from Options) still hides Wuber", function()
	local w, r, UI, st = login(withOptions)
	local ui = UI.state
	UI.Toggle(true)
	w:advance(3)
	r:clickOn(ui.gear)
	w:advance(1)
	ok(UI.SettingsShown(), "Settings is up")
	r:clickOn(ui.close)
	w:advance(2)
	ok(not UI.IsShown(), "the X hides Wuber")
	T.clean(w)
end)
