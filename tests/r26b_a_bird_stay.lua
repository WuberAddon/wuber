-- Round 26b, A: the "Skip the bird" card stays until the player or the map ends it (no 10 s hide).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["anita lift"] = { name = "Anita Lift", key = "anita lift", dest = "Orgrimmar", price = 5000, state = "open", team = 3, service = "Wuber", heard = r.env.GetTime() }
	return w, r, W
end

local NODES = { { name = "Thunder Bluff, Mulgore", type = "CURRENT" }, { name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50 } }
local function open(w, r)
	w:openTaxiMap(r, NODES)
	w:advance(0.5)
end

test("r26b bird: still shown 11 s, 60 s and 10 minutes after the map opened", function()
	local w, r, W = setup()
	local Mod = W.Mod("UI.Bird")
	open(w, r)
	local c = Mod.Card()
	ok(c and H.visible(c), "shown")
	for _, t in ipairs({ 10.5, 49, 540 }) do
		w:advance(t)
		ok(H.visible(c), "still shown after " .. t .. " more s")
	end
	T.clean(w)
end)

test("r26b bird: x hides it; Don't show again hides it and turns the tip off", function()
	local w, r, W = setup()
	local Mod = W.Mod("UI.Bird")
	open(w, r)
	local c = Mod.Card()
	c.x:GetScript("OnClick")(c.x)
	w:advance(0.5)
	ok(not H.visible(c), "x hides")
	w:closeTaxiMap(r)
	open(w, r)
	ok(H.visible(c), "back on the next open")
	c.never:GetScript("OnClick")(c.never)
	w:advance(0.5)
	ok(not H.visible(c), "never hides")
	eq(W.db.birdTip, false, "birdTip off")
	T.clean(w)
end)

test("r26b bird: TAXIMAP_CLOSED, a hidden map without the event, and a taken flight hide it; a reopen shows it", function()
	local w, r, W = setup()
	local Mod = W.Mod("UI.Bird")
	open(w, r)
	local c = Mod.Card()
	w:closeTaxiMap(r)
	w:advance(0.5)
	ok(not H.visible(c), "closed map hides")
	open(w, r)
	ok(H.visible(c), "reopen shows it again")
	r.env.TaxiFrame:Hide()
	w:advance(2)
	ok(not H.visible(c), "map hidden without the event: card goes")
	open(w, r)
	ok(H.visible(c), "reopen shows it again")
	T.clean(w)
end)
