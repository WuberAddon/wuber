-- Round 25 T1 (group A): the login tips card (UI.Tips). One tip on the first open after a real login
-- (not a /reload), only once the coach marks were done before that login, the next unseen eligible tip
-- in order, each once; Show me / Next tip / Don't show again; never in combat or during a ride; inside
-- the phone's primary pane, folded and unfolded, at several UI scales. The tip texts are group C's
-- (UI.TipTexts): these tests put a fake list in its table so they run with or without it.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local FAKE = {
	{ id = "fly_or_summon", text = "Fly or summon? Wuber shows what flying costs and how long, before you book.", driver = false, screen = "home" },
	{ id = "world_view", text = "Tap World to see every driver on the whole map, with flight routes and boats.", driver = false, screen = "world" },
	{ id = "drive_open", text = "Press Open and riders come to you. The big button always says the next click.", driver = true, screen = "drive" },
	{ id = "passphrase", text = "Drivers can show a two-word passphrase, so you know you've got the right Warlock, and so on and on.", driver = false, screen = "ride" },
}

local function fake(W)
	local m = W.Mod("UI.TipTexts")
	m.list = FAKE
	-- (round 32) the World tip waits for a window that can open the World view: these tests are about the order
	local Fold = W.UI and W.UI.Fold
	if Fold then Fold.RealFits = Fold.RealFits or Fold.Fits Fold.Fits = function() return true end end
	local shown = {}
	m.Show = function(tip) shown[#shown + 1] = tip.id return true end
	return shown
end

-- a reload in the game: PLAYER_ENTERING_WORLD(false, true) (the harness's reload says true, false)
local function asReload(_, client)
	local orig = client.fire
	client.fire = function(self, ev, ...)
		if ev == "PLAYER_ENTERING_WORLD" then return orig(self, ev, false, true) end
		return orig(self, ev, ...)
	end
end

local function login(w, saved, opts)
	opts = opts or {}
	local c = T.rider(w, T.TESTCHAR, { saved = saved or { Wuber = { coach = true } }, class = opts.class, prepare = opts.prepare })
	w:advance(2)
	local shown = fake(c.W)
	if opts.realFits and c.W.UI and c.W.UI.Fold then c.W.UI.Fold.Fits = c.W.UI.Fold.RealFits end
	return c, c.W, c.W.Mod("UI.Tips"), shown
end

local function open(w, W)
	W.UI.Toggle(true)
	w:advance(5)
end

local function shut(w, W)
	W.UI.Toggle(false)
	w:advance(1)
end

local function cardUp(Mod)
	local c = Mod.Card()
	return c and H.visible(c) and c or nil
end

local function relog(w, c)
	local saved = w:logout(c)
	return saved
end

test("r25 T1: first open after a login shows the first tip, once per login", function()
	local w = T.newWorld()
	local c, W, Mod = login(w)
	eq(W.db.tipsOn, true, "tips on by default")
	eq(type(W.db.tipsSeen), "table", "tipsSeen saved")
	open(w, W)
	local card = cardUp(Mod)
	ok(card, "the card shows on the first open")
	eq(card.text:GetText(), FAKE[1].text, "the first tip")
	eq(W.db.tipsSeen.fly_or_summon, true, "marked seen when shown")
	eq(card:GetParent(), c.env.WuberFrame, "inside the phone")
	shut(w, W)
	ok(not H.visible(card), "hidden with the window")
	open(w, W)
	ok(not H.visible(card), "not again in the same session")
	T.clean(w)
end)

test("r25 T1: the next login shows the next unseen tip; driver tips only for drivers; then no more", function()
	local w = T.newWorld()
	local c, W, Mod = login(w)
	local got = {}
	for _ = 1, 4 do
		open(w, W)
		local card = cardUp(Mod)
		got[#got + 1] = card and card.text:GetText() or "-"
		local saved = relog(w, c)
		c, W, Mod = login(w, saved)
	end
	eq(got[1], FAKE[1].text, "login 1")
	eq(got[2], FAKE[2].text, "login 2")
	eq(got[3], FAKE[4].text, "login 3 skips the driver tip (a Mage who never used Drive)")
	eq(got[4], "-", "every tip seen: no more")
	T.clean(w)
end)

test("r25 T1: Warlocks and players who used Drive get the driver tips", function()
	local w = T.newWorld()
	local _, W, Mod = login(w, { Wuber = { coach = true, tipsSeen = { fly_or_summon = true, world_view = true } } }, { class = "WARLOCK" })
	open(w, W)
	local card = cardUp(Mod)
	ok(card and card.text:GetText() == FAKE[3].text, "a Warlock gets the driver tip")
	T.clean(w)
	w = T.newWorld()
	local _, W2, Mod2 = login(w, { Wuber = { coach = true, tipsSeen = { fly_or_summon = true, world_view = true },
		chars = { ["someone else"] = { wizard = true } } } })
	eq(Mod2.UsedDrive(), true, "the Drive setup was finished on this account")
	open(w, W2)
	card = cardUp(Mod2)
	ok(card and card.text:GetText() == FAKE[3].text, "a player who used Drive gets the driver tip")
	T.clean(w)
end)

test("r25 T1: no tip after a /reload, nor in a session whose login came before the coach marks were done", function()
	local w = T.newWorld()
	local _, W, Mod = login(w, nil, { prepare = asReload })
	open(w, W)
	ok(not cardUp(Mod), "a reload shows no tip")
	T.clean(w)
	w = T.newWorld()
	local _, W2, Mod2 = login(w, { Wuber = {} })
	W2.db.coach = true -- the coach marks done during this session
	open(w, W2)
	ok(not cardUp(Mod2), "tips start from the next login")
	eq(W2.db.tipsSeen.fly_or_summon, nil, "nothing marked seen")
	T.clean(w)
end)

test("r25 T1: never in combat, during a ride, or with tips off", function()
	local w = T.newWorld()
	local c, W, Mod = login(w)
	w:enterCombat(c)
	open(w, W)
	ok(not cardUp(Mod), "not in combat")
	shut(w, W)
	w:leaveCombat(c)
	W.ride = { id = "r1", driver = "Anita Lift", state = "summoning", dest = "Undercity" }
	open(w, W)
	ok(not cardUp(Mod), "not during a ride")
	eq(W.db.tipsSeen.fly_or_summon, nil, "nothing seen yet")
	shut(w, W)
	W.ride = nil
	open(w, W)
	ok(cardUp(Mod), "the tip waits for a good moment in the same session")
	w:enterCombat(c)
	w:advance(0.5)
	ok(not cardUp(Mod), "combat hides it")
	T.clean(w)
	w = T.newWorld()
	local _, W2, Mod2 = login(w, { Wuber = { coach = true, tipsOn = false } })
	open(w, W2)
	ok(not cardUp(Mod2), "tips off: no card")
	eq(Mod2.IsOn(), false, "IsOn")
	T.clean(w)
end)

test("r25 T1: Show me, Next tip and Don't show again", function()
	local w = T.newWorld()
	local _, W, Mod, shown = login(w)
	open(w, W)
	local card = cardUp(Mod)
	ok(card, "card")
	card.next:Click()
	eq(card.text:GetText(), FAKE[2].text, "Next tip shows the next one now")
	eq(W.db.tipsSeen.world_view, true, "and marks it seen")
	card.show:Click()
	eq(shown[1], "world_view", "Show me opens that tip's screen (UI.TipTexts.Show)")
	ok(not H.visible(card), "and closes the card")
	Mod.ShowNow()
	card = cardUp(Mod)
	ok(card, "ShowNow")
	eq(card.text:GetText(), FAKE[4].text, "the next unseen")
	card.never:Click()
	eq(W.db.tipsOn, false, "Don't show again turns tips off")
	eq(card.text:GetText(), Mod.OFF_LINE, "and says where to turn them back on")
	ok(card.text:GetText():find("Settings > Riding > Tips", 1, true) and card.text:GetText():find("/wuber tips", 1, true), "the line names both ways")
	ok(not H.visible(card.show) and not H.visible(card.next) and not H.visible(card.never), "no buttons on the off line")
	w:advance(9)
	ok(not H.visible(card), "the line closes by itself")
	T.clean(w)
end)

test("r25 T1: SetOn and ShowNow (the switch and /wuber tips)", function()
	local w = T.newWorld()
	local _, W, Mod = login(w, { Wuber = { coach = true, tipsOn = false, tipsSeen = { fly_or_summon = true } } })
	Mod.SetOn(true)
	eq(W.db.tipsOn, true, "on")
	eq(W.db.tipsSeen.fly_or_summon, true, "turning on keeps what was seen")
	W.db.tipsSeen = { fly_or_summon = true, world_view = true, passphrase = true }
	Mod.SetOn(false)
	Mod.SetOn(true)
	eq(next(W.db.tipsSeen), nil, "every tip seen: on again starts from the first")
	ok(not W.UI.IsShown(), "window shut")
	ok(Mod.ShowNow(), "ShowNow opens the phone")
	w:advance(5)
	local card = cardUp(Mod)
	ok(W.UI.IsShown() and card, "phone open with the card")
	eq(card.text:GetText(), FAKE[1].text, "the first unseen")
	Mod.SetOn(false)
	ok(not H.visible(card), "off hides the card")
	ok(Mod.ShowNow(Mod.Longest().id), "a given tip (the sweep's longest)")
	eq(card.text:GetText(), FAKE[4].text, "the longest")
	T.clean(w)
end)

local function inside(a, b, what)
	ok(a.l >= b.l - 0.5 and a.b >= b.b - 0.5 and a.l + a.w <= b.l + b.w + 0.5 and a.b + a.h <= b.b + b.h + 0.5, what)
end

-- (Design 2) the tip is a sheet: the host is the primary pane, the sheet card sits at its foot and the three buttons
-- are stacked (Show me, Next tip, Don't show again); the page behind dims, so nothing needs to be clear of it
test("r25 T1: the tip sheet sits in the phone's primary pane, folded and unfolded, at every UI scale", function()
	for _, sc in ipairs({ 0.64, 1, 1.4 }) do
		for _, wide in ipairs({ false, true }) do
			local w = T.newWorld()
			local c, W, Mod = login(w, nil, { realFits = true })
			c.wide = wide
			W.db.scale = sc
			open(w, W)
			if wide and not W.UI.Fold.IsUnfolded() then W.UI.Fold.Toggle() w:advance(2) end
			local tag = " at " .. sc .. (wide and " unfolded" or " folded")
			eq(W.UI.Fold.IsUnfolded(), wide, "fold state" .. tag)
			local card = cardUp(Mod)
			ok(card, "card" .. tag)
			local wr = H.rect(c.env.WuberFrame)
			local cr = H.rect(card.sheet.card)
			inside(cr, wr, "inside the window" .. tag)
			local s = card:GetEffectiveScale() / c.env.UIParent:GetEffectiveScale()
			ok(cr.l + cr.w <= wr.l + 360 * s + 0.5, "inside the primary pane" .. tag)
			-- (design 2) the tabs are a bar at the foot of the phone and stay free while a tip shows: the sheet rests on it
			local bar = H.rect(W.UI.state.tabbar)
			ok(math.abs(cr.b - (bar.b + bar.h)) < 0.5, "the sheet rests on the tab bar" .. tag)
			ok(bar.b + bar.h > wr.b + 40 * s, "and the tab bar is the 56-high strip at the foot of the phone" .. tag)
			for _, b in ipairs({ card.show, card.next, card.never, card.close }) do inside(H.rect(b), cr, "button inside the card" .. tag) end
			local a, b2, n = H.rect(card.show), H.rect(card.next), H.rect(card.never)
			ok(a.b >= b2.b + b2.h - 0.5 and b2.b >= n.b + n.h - 0.5, "buttons stacked, apart: Show me, Next tip, Don't show again" .. tag)
			T.clean(w)
		end
	end
end)
