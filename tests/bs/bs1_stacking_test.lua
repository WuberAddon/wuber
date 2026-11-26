-- Blind-spot check BS1 (job 206): screens stack cleanly and nothing is drawn over the Settings back chevron.
-- Run 1 items 1, 2, 12.1, 12.2. Loaded by tests/run.lua with its helper table T.
-- The page-stacking half overlaps tests/run1_a_pages.lua (201b); what is new here is the generic topmost check
-- (tests/lib/topmost.lua: any visible frame drawn above the button's centre, taking the mouse or not) and the real
-- flows with a login tip or a coach mark up when Settings opens. Names start with "bs1".
local T = ...
local H = T.H
local test, eq, ok = T.test, T.eq, T.ok
local topmost0 = dofile(H.root .. "/tests/lib/topmost.lua")
-- only frames that take the mouse count: a see-through container with no mouse (the Settings panel itself) hides nothing
local topmost = { assertTopmost = function(H_, c, btn, label) return topmost0.assertTopmost(H_, c, btn, label, { mouseOnly = true }) end }

local function openApp(w, c)
	c.W.UI.Toggle(true)
	w:advance(3)
end

-- the pages that show now (a Wuber tab body, Settings, Help)
local function shownPages(c)
	local UI, out = c.W.UI, {}
	for _, name in ipairs({ "Ride", "Trips", "Drive" }) do
		local body = UI.GetTab(name)
		if body and H.visible(body) then out[#out + 1] = "tab:" .. name end
	end
	if UI.SettingsShown() then out[#out + 1] = "settings" end
	return out
end

local function onlyPage(c, want, ctx)
	local shown = shownPages(c)
	if #shown ~= 1 or shown[1] ~= want then
		error(ctx .. ": expected only {" .. want .. "}, got {" .. table.concat(shown, ", ") .. "}", 2)
	end
end

local function chevron(c) return c.W.Mod("UI.Settings.Rows").st.back end

test("bs1 a: Trips -> Settings -> Back: one page at a time, nothing over the chevron, Trips comes back", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	T.settle(w)
	openApp(w, c)
	ok(c.W.UI.SelectTab("Trips"), "the Trips tab opens")
	w:advance(1)
	onlyPage(c, "tab:Trips", "on Trips")
	c:clickOn(c.W.UI.state.gear)
	w:advance(1)
	onlyPage(c, "settings", "Trips -> Settings")
	local back = chevron(c)
	topmost.assertTopmost(H, c, back, "the back chevron on Settings opened from Trips")
	eq(c:clickOn(back), back, "the click lands on the chevron")
	w:advance(1)
	onlyPage(c, "tab:Trips", "after back")
end)

test("bs1 b: Options > AddOns > Open Wuber settings: Settings only, the chevron above the game's Options window", function()
	local w = T.newWorld()
	local optPanel
	local c = T.rider(w, T.ANITA, {
		prepare = function(env, client)
			H.fakeOptionsList(env, client, "new")
			-- the game's own Options window: a full-screen DIALOG-strata frame that takes the mouse
			optPanel = env.CreateFrame("Frame", "SettingsPanel", env.UIParent)
			optPanel:SetFrameStrata("DIALOG")
			optPanel:SetAllPoints(env.UIParent)
			optPanel:EnableMouse(true)
			optPanel:Hide()
		end,
	})
	T.settle(w)
	openApp(w, c)
	c.W.UI.SelectTab("Trips") -- the screen it was left on, which must not show under Settings
	w:advance(1)
	c.W.UI.Toggle(false)
	w:advance(1)
	local cat = c.settingsCats[1]
	ok(cat and cat.frame, "the Wuber Options category is registered")
	optPanel:Show()
	cat.frame:Show()
	cat.frame.openBtn:Click()
	w:advance(1)
	ok(c.W.UI.IsShown(), "the window opens")
	ok(c.W.UI.SettingsShown(), "on Settings")
	onlyPage(c, "settings", "Options -> Open Wuber settings")
	local back = chevron(c)
	topmost.assertTopmost(H, c, back, "the back chevron with the game's Options window open")
	eq(c:clickOn(back), back, "the click lands on the chevron, not on the Options window")
	w:advance(1)
	ok(c.W.UI.IsShown(), "back leaves Settings and Wuber stays")
	onlyPage(c, "tab:Trips", "after back")
	c:clickOn(c.W.UI.state.gear)
	w:advance(1)
	ok(c.W.UI.IsShown() and c.W.UI.SettingsShown(), "the cog opens Settings again; nothing vanishes")
end)

test("bs1 c: unfold and fold on Settings (wide and narrow): one page, the chevron on top both ways", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080 })
	T.settle(w)
	openApp(w, c)
	local Fold = c.W.UI.Fold
	if not Fold.IsUnfolded() then Fold.Toggle() w:advance(1) end
	c.W.UI.OpenSettings()
	w:advance(1)
	ok(c.W.UI.SettingsShown(), "Settings shows (unfolded: " .. tostring(Fold.IsUnfolded()) .. ")")
	onlyPage(c, "settings", "unfolded Settings")
	topmost.assertTopmost(H, c, chevron(c), "the back chevron unfolded")
	Fold.Toggle()
	w:advance(1)
	onlyPage(c, "settings", "folded Settings")
	topmost.assertTopmost(H, c, chevron(c), "the back chevron folded")
	Fold.Toggle()
	w:advance(1)
	onlyPage(c, "settings", "unfolded again")
	topmost.assertTopmost(H, c, chevron(c), "the back chevron unfolded again")
end)

test("bs1 d: a login tip that is up when Settings opens (the cog): nothing of it covers the back chevron", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	T.settle(w)
	local Tips = c.W.Mod("UI.Tips")
	openApp(w, c)
	Tips.ShowNow()
	w:advance(2)
	local tipUp = H.visible(Tips.Card())
	c:clickOn(c.W.UI.state.gear)
	w:advance(2)
	ok(c.W.UI.SettingsShown(), "Settings shows (tip was up first: " .. tostring(tipUp) .. ")")
	topmost.assertTopmost(H, c, chevron(c), "the back chevron with a tip card in play")
	eq(c:clickOn(chevron(c)), chevron(c), "the click lands on the chevron")
end)

test("bs1 e: the first-open coach mark that is up when Settings opens: nothing of it covers the back chevron", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local UI = c.W.UI
	UI.Toggle(true)
	for _ = 1, 400 do
		if UI.state.coach and UI.state.coaching then break end
		w:advance(0.05)
	end
	w:advance(1)
	ok(UI.state.coach and H.visible(UI.state.coach), "the coach mark shows")
	UI.OpenSettings()
	w:advance(2)
	if UI.SettingsShown() then
		topmost.assertTopmost(H, c, chevron(c), "the back chevron with the coach in play")
	end
end)

-- the tool itself: a card at FULLSCREEN_DIALOG over the chevron must be named, and the chevron's own children must not count
test("bs1 f: the topmost check names a frame drawn over the back chevron (and not the chevron's own child)", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	T.settle(w)
	openApp(w, c)
	c.W.UI.OpenSettings()
	w:advance(1)
	local back = chevron(c)
	local res = topmost0.checkButton(H, c, back, { mouseOnly = true })
	ok(res.ok, "nothing covers it to start with: " .. tostring(res.reason))
	local child = c.env.CreateFrame("Frame", nil, back)
	child:SetAllPoints(back)
	child:EnableMouse(true)
	ok(topmost0.checkButton(H, c, back, { mouseOnly = true }).ok, "its own child does not count")
	local card = c.env.CreateFrame("Frame", nil, c.env.UIParent)
	card:SetFrameStrata("FULLSCREEN_DIALOG")
	card:SetAllPoints(c.W.UI.state.win)
	card:EnableMouse(true)
	local res2 = topmost0.checkButton(H, c, back, { mouseOnly = true })
	ok(not res2.ok and res2.topBlocker == card, "the covering card is named: " .. tostring(res2.reason))
	card:Hide()
	ok(topmost0.checkButton(H, c, back, { mouseOnly = true }).ok, "a hidden card covers nothing")
end)
