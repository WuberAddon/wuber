-- Round 26 item 1 (group A): the login tip card survives a /reload before the first open, shows on the
-- first open whichever tab the phone opens on (it moves to Home for it), comes back on the next open when
-- tips are turned on again, Show me rings the thing the tip is about, and ShowAgain (the Help row,
-- /wuber tips) brings the tip back in the same session. Uses the real tip texts (UI.TipTexts).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- a reload in the game: PLAYER_ENTERING_WORLD(false, true) (the harness's new client says true, false)
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
	return c, c.W, c.W.Mod("UI.Tips")
end

-- opens the phone; tab: the tab it opens on (selected before the tip's first look)
local function open(w, W, tab)
	W.UI.Toggle(true)
	if tab then W.UI.SelectTab(tab) end
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

local function count(t)
	local n = 0
	for _ in pairs(t or {}) do n = n + 1 end
	return n
end

local function onHome(W)
	local ui = W.Mod("UI.Kit").ui
	return ui.tab == "Ride" and ui.screen == "home"
end

test("r26 A: a Warlock reloads before the first open, the phone opens on Drive: the tip shows, on Home", function()
	local w = T.newWorld()
	local c, W = login(w, nil, { class = "WARLOCK" })
	eq(W.db.tipsPending, true, "a real login saves a tip as pending")
	local saved = w:logout(c) -- the /reload (60 s after the login, before Wuber was opened)
	local c2, W2, Mod2 = login(w, saved, { class = "WARLOCK", prepare = asReload })
	eq(Mod2.state.armed, true, "the reload keeps the pending tip")
	open(w, W2, "Drive")
	local card = cardUp(Mod2)
	ok(card, "the card shows on the first open")
	ok(onHome(W2), "the first open moved to the Ride tab's Home")
	eq(card.text:GetText(), W2.Mod("UI.TipTexts").list[1].text, "the first tip")
	eq(count(W2.db.tipsSeen), 1, "exactly one tip seen")
	eq(W2.db.tipsPending, nil, "showing it clears the pending flag")
	-- a reload after it showed: no second tip
	saved = w:logout(c2)
	local _, W3, Mod3 = login(w, saved, { class = "WARLOCK", prepare = asReload })
	open(w, W3)
	ok(not cardUp(Mod3), "a reload after the tip showed: none")
	T.clean(w)
end)

test("r26 A: a second open in the same session shows nothing new, on Home or Drive", function()
	local w = T.newWorld()
	local _, W, Mod = login(w, nil, { class = "WARLOCK" })
	open(w, W)
	ok(cardUp(Mod), "first open: the tip")
	eq(count(W.db.tipsSeen), 1, "one seen")
	shut(w, W)
	open(w, W, "Drive")
	ok(not cardUp(Mod), "second open: nothing")
	eq(W.Mod("UI.Kit").ui.tab, "Drive", "and the phone stays on the tab it opened on")
	shut(w, W)
	open(w, W)
	ok(not cardUp(Mod), "third open on Home: nothing")
	eq(count(W.db.tipsSeen), 1, "still one seen")
	T.clean(w)
end)

test("r26 A: tips off then on: the next open shows a tip (on Home and from Drive)", function()
	for _, tab in ipairs({ false, "Drive" }) do
		local w = T.newWorld()
		local _, W, Mod = login(w, { Wuber = { coach = true, tipsOn = false } }, { class = "WARLOCK" })
		open(w, W)
		ok(not cardUp(Mod), "tips off: none")
		Mod.SetOn(false)
		Mod.SetOn(true)
		eq(Mod.IsOn(), true, "on")
		w:advance(2)
		ok(not cardUp(Mod), "not on the open the switch was flipped in")
		shut(w, W)
		open(w, W, tab or nil)
		local card = cardUp(Mod)
		ok(card, "the next open shows a tip" .. (tab and " (opened on Drive)" or ""))
		ok(onHome(W), "on Home")
		T.clean(w)
	end
end)

test("r26 A: Show me rings the tip's target for about 3 s; ShowAgain brings the same tip back", function()
	local w = T.newWorld()
	local c, W, Mod = login(w)
	open(w, W)
	local card = cardUp(Mod)
	ok(card, "card")
	local id = Mod.state.current.id
	eq(id, "fly_or_summon", "the first tip (Home)")
	local target = W.Mod("UI.TipTexts").Target(id)
	ok(target and H.visible(target), "its target shows")
	card.show:Click()
	ok(not H.visible(card), "Show me closes the card")
	w:advance(1)
	ok(onHome(W), "on the tip's screen")
	local ring = Mod.state.ring
	ok(ring and H.visible(ring) and ring:GetAlpha() > 0, "a gold ring shows")
	local rr, tr = H.rect(ring), H.rect(target)
	ok(rr.l <= tr.l and rr.b <= tr.b and rr.l + rr.w >= tr.l + tr.w and rr.b + rr.h >= tr.b + tr.h, "round the target")
	w:advance(4)
	ok(not H.visible(ring), "gone after about 3 s")
	ok(Mod.ShowAgain(), "ShowAgain")
	w:advance(1)
	card = cardUp(Mod)
	ok(card, "the card is back")
	eq(Mod.state.current.id, id, "the same tip again")
	-- /wuber tips (tips on) brings it back too
	card.close:Click()
	w:advance(1)
	ok(not cardUp(Mod), "closed")
	W.SlashCommand("tips")
	w:advance(1)
	ok(cardUp(Mod), "/wuber tips brings it back")
	eq(Mod.state.current.id, id, "the same tip")
	T.clean(w)
end)

test("r26 A: every tip has a Show me target", function()
	local w = T.newWorld()
	local _, W = login(w)
	for _, tip in ipairs(W.Mod("UI.TipTexts").list) do
		ok(type(tip.target) == "string" and tip.target ~= "", "target for " .. tip.id)
	end
	T.clean(w)
end)
