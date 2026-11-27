-- Fix round 2.4, group m3: HR-1 (/wuber drive and the minimap's Drive click stay on Drive, the login tip waits for the
-- next open), HUNT-141 (Show me points at something visible), HUNT-144 (Advanced on and off keeps the saved place).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function login(w, saved)
	local c = T.rider(w, T.TESTCHAR, { saved = saved or { Wuber = { coach = true } }, screenW = 1365, screenH = 768 })
	w:advance(3)
	local Fold = c.W.UI and c.W.UI.Fold
	if Fold then Fold.Fits = function() return true end end
	return c, c.W
end

local function up(card) return card and H.visible(card) and card or nil end

test("fr m3 HR-1: the minimap's Drive click stays on Drive; the login tip comes at the next open", function()
	local w = T.newWorld()
	local c, W = login(w)
	local Mod = W.Mod("UI.Tips")
	local ui = W.UI.state
	W.UI.Show("drive")
	w:advance(6)
	eq(ui.tab, "Drive", "it stays on Drive")
	ok(not up(Mod.Card()), "no tip card over Drive")
	eq(Mod.state.armed, true, "the tip still waits")
	W.UI.Toggle(false)
	w:advance(3)
	W.UI.Toggle(true)
	w:advance(6)
	ok(up(Mod.Card()), "the tip shows at the next open")
	eq(ui.tab, "Ride", "on Ride, as before")
	T.clean(w)
end)

test("fr m3 HR-1: /wuber drive stays on Drive too", function()
	local w = T.newWorld()
	local c, W = login(w)
	local Mod = W.Mod("UI.Tips")
	local ui = W.UI.state
	W.UI.ShowDrive("console")
	w:advance(6)
	eq(ui.tab, "Drive", "it stays on Drive")
	ok(not up(Mod.Card()), "no tip card over Drive")
	T.clean(w)
end)

test("fr m3 HR-1: another first open on the Drive tab keeps today's way (to Ride, with the tip)", function()
	local w = T.newWorld()
	local c, W = login(w)
	local Mod = W.Mod("UI.Tips")
	local ui = W.UI.state
	W.UI.Toggle(true)
	W.UI.SelectTab("Drive")
	W.UI.Toggle(false)
	w:advance(3)
	W.UI.Toggle(true)
	w:advance(6)
	eq(ui.tab, "Ride", "moved to Ride")
	ok(up(Mod.Card()), "tip shows")
	T.clean(w)
end)

test("fr m3 HR-1: first open on Drive then tapping Trips stays on Trips without flipping to Ride", function()
	local w = T.newWorld()
	local c, W = login(w)
	local Mod = W.Mod("UI.Tips")
	local ui = W.UI.state
	W.UI.Show("drive")
	w:advance(0.3)
	local tripsBtn
	for _, tab in ipairs(ui.tabs or {}) do
		if tab.name == "Trips" then tripsBtn = tab.button break end
	end
	ok(tripsBtn, "Trips tab button exists")
	c:clickOn(tripsBtn)
	w:advance(3)
	eq(ui.tab, "Trips", "stays on Trips")
	ok(not up(Mod.Card()), "no tip card over Trips")
	eq(Mod.state.armed, true, "the tip still waits")
	T.clean(w)
end)

test("fr m3 HR-1: first open on Drive then SelectTab Trips stays on Trips too", function()
	local w = T.newWorld()
	local _, W = login(w)
	local Mod = W.Mod("UI.Tips")
	local ui = W.UI.state
	W.UI.Show("drive")
	w:advance(0.3)
	W.UI.SelectTab("Trips")
	w:advance(3)
	eq(ui.tab, "Trips", "stays on Trips")
	ok(not up(Mod.Card()), "no tip card over Trips")
	T.clean(w)
end)

test("fr m3 HUNT-141: Show me on the passphrase, Skip the bird and Check my game tips rings something visible", function()
	local w = T.newWorld()
	local c, W = login(w)
	local TT = W.Mod("UI.TipTexts")
	for _, id in ipairs({ "passphrase", "skip_the_bird", "check_game" }) do
		W.UI.state.win:Hide()
		w:advance(1)
		TT.Show(id)
		w:advance(1)
		local f = TT.Target(id)
		ok(f ~= nil, id .. ": a target")
		ok(f and f:IsVisible(), id .. ": it is visible")
	end
	T.clean(w)
end)

test("fr m3 HUNT-144: unfolding the wide pane then folding it leaves the saved place as it was", function()
	local w = T.newWorld()
	local c, W = login(w, { Wuber = { coach = true, pos = { "TOPLEFT", "TOPLEFT", 1100, -44 } } })
	W.UI.Toggle(true)
	w:advance(4)
	local Fold = W.UI.Fold
	local function key() local p = W.db.pos return p and (p[1] .. "," .. p[2] .. "," .. p[3] .. "," .. p[4]) end
	if Fold.IsUnfolded() then Fold.Toggle() w:advance(2) end
	eq(key(), "TOPLEFT,TOPLEFT,1100,-44", "folded: the player's place")
	ok(Fold.Toggle(), "setup: unfold")
	w:advance(3)
	ok(Fold.IsUnfolded(), "setup: wide")
	Fold.Toggle()
	w:advance(3)
	ok(not Fold.IsUnfolded(), "folded again")
	eq(key(), "TOPLEFT,TOPLEFT,1100,-44", "the saved place is as it was")
	T.clean(w)
end)
