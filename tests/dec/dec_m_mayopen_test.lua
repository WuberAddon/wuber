-- Decisions round, group M: one rule for everything that opens by itself (UI.MayOpen in UI.Kit: not in combat, not in
-- a cinematic, a couple of seconds after login, one self-opening thing at a time), used by the login tip, the first-open
-- guide, Skip the bird and the What's new card; a card the game closed is not seen; AUD-233 (the guide's /wuber why line
-- while the tip card holds it back). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local FAKE = {
	{ id = "fly_or_summon", text = "Fly or summon? Wuber shows what flying costs and how long, before you book.", driver = false, screen = "home" },
	{ id = "passphrase", text = "Drivers can show a two-word passphrase, so you know you've got the right Warlock.", driver = false, screen = "ride" },
}

local function login(w, saved)
	local c = T.rider(w, T.TESTCHAR, { saved = saved or { Wuber = { coach = true } }, screenW = 1365, screenH = 768 })
	w:advance(3)
	local m = c.W.Mod("UI.TipTexts")
	m.list = FAKE
	m.Show = function() return true end
	local Fold = c.W.UI and c.W.UI.Fold
	if Fold then Fold.Fits = function() return true end end
	return c, c.W
end

local function up(card) return card and H.visible(card) and card or nil end

local function whyLines(c)
	local out = {}
	local W = c.W
	local orig = W.Print
	W.Print = function(...) out[#out + 1] = table.concat({ ... }, " ") end
	c.env.SlashCmdList.WUBER("why")
	W.Print = orig
	return table.concat(out, " | ")
end

-- a cinematic plays: the game's own frame shows (the first), or its in-cinematic call says so (the second)
local function cinematic(c, on, how)
	if how == "call" then
		c.env.InCinematic = function() return on end
	else
		c.env.CinematicFrame = { IsShown = function() return on end }
	end
end

test("dec m: UI.MayOpen answers the common rules once: login delay, combat, a cinematic or movie, one thing at a time", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true } } })
	local W, UI = c.W, c.W.UI
	eq(type(UI.MayOpen), "function", "UI.MayOpen is there")
	local okNow, why = UI.MayOpen("news")
	eq(okNow, false, "nothing opens in the first moments after login")
	eq(why, "login", "the reason is the login delay")
	w:advance(3)
	eq(UI.MayOpen("news"), true, "a couple of seconds later it may")
	w:enterCombat(c)
	okNow, why = UI.MayOpen("tip")
	eq(okNow, false, "not in combat")
	eq(why, "combat", "reason combat")
	w:leaveCombat(c)
	cinematic(c, true)
	okNow, why = UI.MayOpen("bird")
	eq(okNow, false, "not while CinematicFrame shows")
	eq(why, "cinematic", "reason cinematic")
	cinematic(c, false)
	c.env.MovieFrame = { IsShown = function() return true end }
	eq(select(2, UI.MayOpen("coach")), "cinematic", "a movie counts too")
	c.env.MovieFrame = nil
	cinematic(c, true, "call")
	eq(select(2, UI.MayOpen("news")), "cinematic", "the game's in-cinematic call counts too")
	cinematic(c, false, "call")
	eq(UI.MayOpen("coach"), true, "and after it, it may again")
	-- one at a time, in the order they give way: the tip card up holds the guide and What's new, never Skip the bird
	UI.Toggle(true)
	W.Mod("UI.Tips").ShowNow()
	w:advance(3)
	ok(up(c.env.WuberTipCard), "setup: the tip card is up")
	local okC, whyC, who = UI.MayOpen("coach")
	eq(okC, false, "the guide waits for the tip card")
	eq(whyC, "other", "reason other")
	eq(who, "tip", "and it names the tip card")
	eq(select(2, UI.MayOpen("news")), "other", "What's new waits for it too")
	eq(UI.MayOpen("bird"), true, "Skip the bird stands before the tip card")
	eq(UI.MayOpen("tip"), true, "a thing never waits for itself")
	T.clean(w)
end)

test("dec m: AUD-233: /wuber why says the first-open guide waits for the tip card", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local Coach = r.W.Mod("UI.Coach")
	local ui = r.W.UI.state
	ok(type(Coach.Why()) == "string" and Coach.Why():find("shows when you open"), "control: window shut, Why says: " .. tostring(Coach.Why()))
	r.W.Mod("UI.Tips").ShowNow()
	w:advance(3)
	ok(up(rawget(r.env, "WuberTipCard")), "setup: the login tip card is up")
	ok(not ui.coaching, "setup: the guide is not running (held back by the card)")
	eq(Coach.Why(), "First-open guide: waiting for the tip card to close.", "the guide's reason")
	ok(whyLines(r):find("First-open guide: waiting for the tip card to close.", 1, true), "/wuber why prints it")
	T.clean(w)
end)

test("dec m: a cinematic holds the What's new card back, with its own why line, and the card comes after it", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true, newsSeen = "2.3.4" } } })
	local W = c.W
	local Mod = W.Mod("UI.WhatsNew")
	cinematic(c, true)
	w:advance(5)
	ok(not up(Mod.Card()), "not during a cinematic")
	eq(Mod.Block(), "cinematic", "Block names the rule")
	eq(Mod.Why(), "What's new card: not during a cinematic.", "why")
	ok(whyLines(c):find("What's new card: not during a cinematic.", 1, true), "/wuber why prints it")
	eq(W.db.newsSeen, "2.3.4", "not seen")
	cinematic(c, false)
	w:advance(12)
	ok(up(Mod.Card()), "it shows once the cinematic is over")
	T.clean(w)
end)

test("dec m: a login tip the game closed (combat) is not seen: the same tip comes back; the player's own x is seen", function()
	local w = T.newWorld()
	local c, W = login(w)
	local Mod = W.Mod("UI.Tips")
	W.UI.Toggle(true)
	w:advance(5)
	local card = up(Mod.Card())
	ok(card, "setup: the tip shows on the first open")
	eq(card.kicker:GetText(), "Tip 1 of 2", "setup: the first tip")
	eq(W.db.tipsSeen.fly_or_summon, true, "setup: marked when it shows")
	w:enterCombat(c)
	w:advance(0.5)
	ok(not up(Mod.Card()), "combat hides it")
	eq(W.db.tipsSeen.fly_or_summon, nil, "a tip the game closed is not seen")
	eq(Mod.Why(), "Login tip: not in combat.", "why keeps its words")
	w:leaveCombat(c)
	w:advance(3)
	if not (W.UI.state.win and W.UI.state.win:IsShown()) then W.UI.Toggle(true) w:advance(5) end
	card = up(Mod.Card())
	ok(card, "it comes back when the fight is over")
	eq(card.kicker:GetText(), "Tip 1 of 2", "the same tip, not the next one")
	card.close:Click()
	w:advance(1)
	ok(not up(Mod.Card()), "the x closes it")
	eq(W.db.tipsSeen.fly_or_summon, true, "the player's own close is seen")
	w:advance(5)
	ok(not up(Mod.Card()), "and it stays away")
	T.clean(w)
end)

test("dec m: the login tip and the guide wait for a cinematic, each with a why line", function()
	local w = T.newWorld()
	local c, W = login(w)
	local Mod = W.Mod("UI.Tips")
	cinematic(c, true, "call")
	W.UI.Toggle(true)
	w:advance(5)
	ok(not up(Mod.Card()), "no tip during a cinematic")
	eq(W.db.tipsSeen and W.db.tipsSeen.fly_or_summon, nil, "nothing seen")
	eq(Mod.Why(), "Login tip: not during a cinematic.", "the tip's why")
	cinematic(c, false, "call")
	w:advance(3)
	ok(up(Mod.Card()), "the tip shows by itself once the cinematic is over")
	T.clean(w)
	-- the guide
	w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local ui = r.W.UI.state
	local Coach = r.W.Mod("UI.Coach")
	cinematic(r, true)
	r.W.UI.Toggle(true)
	w:advance(5)
	if not ui.splashing then
		ok(not ui.coaching, "no guide during a cinematic")
		eq(Coach.Why(), "First-open guide: not during a cinematic.", "the guide's why")
	end
	cinematic(r, false)
	w:advance(5)
	ok(ui.coaching, "the guide starts by itself once the cinematic is over")
	eq(r.W.db.coach ~= true, true, "and is not done until Got it or Skip tips")
	T.clean(w)
end)

test("dec m: the guide does not start in combat and says why", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local ui = r.W.UI.state
	r.W.UI.Toggle(true)
	w:advance(0.1)
	w:enterCombat(r)
	w:advance(5)
	if ui.win and ui.win:IsShown() and ui.tab == "Ride" and ui.screen == "home" and not ui.splashing then
		ok(not ui.coaching, "no guide in combat")
		eq(r.W.Mod("UI.Coach").Why(), "First-open guide: not in combat.", "why")
	end
	T.clean(w)
end)

local NODES = { { name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 580, x = 0.47, y = 0.44 } }

test("dec m: Skip the bird waits for a cinematic, says why, and shows for the same open once it is over", function()
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
	cinematic(r, true)
	w:openTaxiMap(r, NODES)
	w:advance(0.5)
	ok(not up(Mod.Card()), "no card during a cinematic")
	eq(Mod.Why(), "Skip the bird: not during a cinematic.", "why")
	cinematic(r, false)
	w:advance(2)
	ok(up(Mod.Card()), "the card shows for the same open once the cinematic is over")
	T.clean(w)
end)
