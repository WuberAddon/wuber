-- Wuber 2.4 fix round, group I: the "Wuber" page in the game's Options > AddOns list (one line, one button that opens
-- Wuber's own settings). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function login(api)
	local w = T.newWorld()
	local c = T.rider(w, T.ANITA, { prepare = function(env, client) T.H.fakeOptionsList(env, client, api or "none") end })
	T.settle(w)
	return w, c
end

test("v24 f3i: the new Settings API gets one Wuber category with a line and an Open button", function()
	local w, c = login("new")
	local cat = c.settingsCats and c.settingsCats[1]
	ok(cat, "a category is registered in the game's Options > AddOns")
	eq(#c.settingsCats, 1, "registered once")
	eq(cat.name, "Wuber")
	local f = cat.frame
	ok(f and f.wuberOptionsPage, "its frame is Wuber's own page")
	ok(not f:IsShown(), "the page is hidden until the game's list shows it")
	local btn = f.openBtn
	ok(btn and btn.wuberTip, "the button has a tooltip")
	eq(btn.label:GetText(), "Open Wuber settings")
	eq(f.line:GetText(), "Wuber's settings are in Wuber's own window.")
	f:Show()
	btn:Click()
	w:advance(1)
	ok(c.W.UI.SettingsShown(), "the click opens Wuber's own settings")
	eq(c.gameOptionsClosed or 0, 0, "the game's own window is never closed")
end)

test("v24 f3i: in combat the button says so and opens nothing", function()
	local w, c = login("new")
	local f = c.settingsCats[1].frame
	c.player.combat = true
	f.openBtn:Click()
	w:advance(1)
	ok(not c.W.UI.SettingsShown(), "nothing opened in combat")
	eq(f.status:GetText(), "In combat. Try again when it ends.")
end)

test("v24 f3i: the older InterfaceOptions API is used when that is all there is", function()
	local w, c = login("old")
	eq(#(c.optionPanels or {}), 1, "one panel added")
	eq(c.optionPanels[1].name, "Wuber")
end)

test("v24 f3i: no options API at all does nothing and does not fail", function()
	local w, c = login(nil)
	ok(c.W.Mod("UI.Settings.Panel").optionsFrame() == nil, "no page built")
end)
