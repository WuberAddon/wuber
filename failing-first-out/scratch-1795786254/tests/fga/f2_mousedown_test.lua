-- fga f2: a real click (GLOBAL_MOUSE_DOWN on the press, OnClick on the release, as the client does) against Wuber's two
-- mouse-down handlers: the splash ends at any click (UI/Window.lua) and the card menu closes at a press outside it
-- (UI/Rider/Cards.lua). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

-- the raid card's one main button (as in v24 simple rider 7): counts its clicks
local function raidRider(w, opts)
	local r = T.rider(w, T.TESTCHAR, opts or {})
	T.settle(w)
	local asked = { n = 0 }
	local info = { runner = T.BOB, place = "Molten Core", summoners = { T.BOB }, queued = false }
	r.W.UI.RaidHere = function() return info end
	r.W.Drive.RaidAsk = function() asked.n = asked.n + 1 info.queued = true return true end
	return r, asked
end

local function button(r, text)
	local fs = r:findText(text, false, true)[1]
	return fs and r:clickable(fs)
end

test("fga f2: a click during the first-open splash ends it on the press and the button still takes the click", function()
	local w = T.newWorld()
	local r, asked = raidRider(w)
	r.W.UI.Toggle(true)
	w:advance(1) -- the splash lasts 1.2 s
	ok(#r:findText("Summons, on demand", false, true) > 0, "control: the splash is up")
	r:click(button(r, "Request a summon"))
	eq(asked.n, 1, "the button under the splash still takes the click (the press ended the splash, the release clicked)")
	w:advance(0.5)
	eq(#r:findText("Summons, on demand", false, true), 0, "the splash is gone")
	T.clean(w)
end)

-- guard: the unchanged neighbouring path: with mouseEvents = false the splash keeps its own timer, as before
test("fga f2: control: a world without mouse events keeps the splash until its own timer", function()
	local w = T.newWorld({ mouseEvents = false })
	local r, asked = raidRider(w)
	r.W.UI.Toggle(true)
	w:advance(1)
	r:click(button(r, "Request a summon"))
	eq(asked.n, 1, "the click lands")
	ok(#r:findText("Summons, on demand", false, true) > 0, "no GLOBAL_MOUSE_DOWN: the splash is still up")
	w:advance(1)
	eq(#r:findText("Summons, on demand", false, true), 0, "its timer ends it")
	T.clean(w)
end)

test("fga f2: the first-open guide comes 0.6 s after a click ends the splash and sits over Home", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR, { simple = true, spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	r.W.UI.Toggle(true)
	w:advance(1)
	r:click(r.env.WuberFrame)
	w:advance(0.7)
	ok(#r:findText("Tip 1 of 4", false, true) > 0, "the guide is up (by design: it takes the clicks over Home until Got it or Skip tips)")
	T.clean(w)
end)

test("fga f2: the card menu: a press on its own button keeps it for the click; a press outside closes it", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	r.W.db.coach = true
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(15)
	r.W.UI.Toggle(true)
	w:advance(3)
	local key = r.W.Key(d.player.name)
	local fs = r:findText("Anita Lift", false, true)[1]
	local card = fs and fs:GetParent()
	while card and card.key ~= key do card = card.GetParent and card:GetParent() or nil end
	ok(card ~= nil, "control: Anita's card is listed")
	r:click(card, "RightButton")
	w:advance(0.6)
	local hide = r:findText("Hide this driver", false, true)[1]
	ok(hide and H.visible(hide), "a right click opens the card menu (the press came before the menu was up)")
	r:click(r.env.WuberFrame)
	ok(not H.visible(hide), "a press outside the menu closes it")
	r:click(card, "RightButton")
	w:advance(0.6)
	ok(H.visible(hide), "control: open again")
	ok(not r.W.UI.IsFav(key), "control: not a favourite yet")
	r:click(button(r, "Favourite"))
	ok(r.W.UI.IsFav(key), "the menu's own button took the click: Anita is a favourite")
	T.clean(w)
end)
