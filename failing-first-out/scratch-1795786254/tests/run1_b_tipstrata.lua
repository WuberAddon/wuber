-- In-game run 1, group b (item 2): the tip card, its ring and the coach marks sit in the window's own strata, below
-- Settings' panel, so they never cover the back chevron; Settings closes the card at once (no fade).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function login(w)
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } }, class = "WARLOCK" })
	w:advance(2)
	return c, c.W, c.W.Mod("UI.Tips")
end

test("run1 b: the tip card is in the window's strata and Settings hides it at once", function()
	local w = T.newWorld()
	local _, W, Mod = login(w)
	local ui = W.Mod("UI.Kit").ui
	W.UI.Toggle(true)
	w:advance(5)
	ok(Mod.ShowNow(), "a tip shows")
	w:advance(2)
	local card = Mod.Card()
	ok(H.visible(card), "card up: shown=" .. tostring(card:IsShown()) .. " open=" .. tostring(card.sheet.open) .. " win=" .. tostring(ui.win:IsShown()) .. " why=" .. tostring(Mod.Why and Mod.Why()))
	ok(card:GetFrameStrata() ~= "FULLSCREEN_DIALOG", "not FULLSCREEN_DIALOG: " .. card:GetFrameStrata())
	eq(card:GetFrameStrata(), ui.win:GetFrameStrata(), "the window's strata")
	W.UI.OpenSettings()
	ok(not H.visible(card), "hidden the moment Settings opens (no fade)")
	local st = W.UI.settings
	ok(st.panel:GetFrameStrata() == card:GetFrameStrata(), "panel same strata")
	ok(st.panel:GetFrameLevel() > card:GetFrameLevel(), "panel above the card")
	ok(st.back:GetFrameLevel() > card:GetFrameLevel(), "chevron above the card")
	st.back:Click()
	ok(not ui.settingsOpen, "the chevron click reached the chevron")
	T.clean(w)
end)

test("run1 b: the Spot ring and coach marks use the window's strata", function()
	local w = T.newWorld()
	local _, W, Mod = login(w)
	local ui = W.Mod("UI.Kit").ui
	W.UI.Toggle(true)
	w:advance(3)
	ok(Mod.Spot(ui.win, 3), "ring")
	eq(Mod.state.ring:GetFrameStrata(), ui.win:GetFrameStrata(), "ring")
	W.db.coach = false
	W.UI.CoachStep(1)
	if ui.coach and ui.coach:IsShown() then
		eq(ui.coach:GetFrameStrata(), ui.win:GetFrameStrata(), "coach mark")
		eq(ui.coach.ring:GetFrameStrata(), ui.win:GetFrameStrata(), "coach ring")
	end
	T.clean(w)
end)
