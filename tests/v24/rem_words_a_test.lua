-- Wuber 2.4, words: Skip the bird, non-Warlock wizard step 1, Messages list. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local NODES = {
	{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 580, x = 0.47, y = 0.44 },
}

local function setupBird()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	local t0 = r.env.GetTime()
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = {
		name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = 5000,
		state = "open", team = 3, service = "Mia's Rides", heard = t0,
	}
	W.FlightCost = function() return 2300, 1 end
	W.FlightTime = function() return 540, "est" end
	return w, r, W
end

local function openWizard(w, c)
	local W = c.W
	local UI = W.UI
	W.db.coach = true
	W.Char().wizard = true
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Drive")
	w:advance(1)
	W.Drive.SetMode("sell")
	w:advance(1)
	W.Driver.ShowScreen("wizard")
	w:advance(1)
end

local function openMessages(w, d)
	local W = d.W
	local UI = W.UI
	W.db.coach = true
	W.Char().wizard = true
	UI.Toggle(true)
	w:advance(3)
	UI.SelectTab("Drive")
	w:advance(1)
	W.Drive.SetMode("sell")
	w:advance(1)
	d.wide = false
	W.db.fold = { v = 1, pages = {}, narrow = true }
	UI.Fold.Apply()
	w:advance(1)
	W.Driver.ShowScreen("messages")
	w:advance(1)
end

test("v24 words: Skip the bird card shows two short lines, Book pill, and old sentence in tooltip", function()
	local w, r, W = setupBird()
	local Mod = W.Mod("UI.Bird")
	w:openTaxiMap(r, NODES)
	w:advance(0.5)
	local c = Mod.Card()
	ok(c and H.visible(c), "the bird card shows")
	ok(#r:findText("^Summon 30 sec%. Fly about") > 0, "line 1 shows Summon 30 sec. Fly about")
	ok(#r:findText("Mia · Tarren Mill · 50s", nil, true) > 0, "line 2 shows Mia · Tarren Mill · 50s")
	ok(r:button("Book") ~= nil, "pill reads Book")
	eq(#r:findText("really", nil, true), 0, "no visible text contains really")
	eq(#r:findText("Skip the bird:", nil, true), 0, "no visible text contains Skip the bird:")
	local d, info = Mod.Pick()
	local oldMsg = Mod.Message(d, info)
	ok(oldMsg:find("Skip the bird:", 1, true) ~= nil, "Mod.Message keeps the old sentence")
	local S = H.state
	local gt = r.env.GameTooltip
	S[c].scripts.OnEnter(c)
	ok(H.visible(gt), "card tooltip shows")
	ok((c.tipBody or ""):find("A Wuber driver summons there faster than the flight. Click to book.", 1, true) ~= nil, "tooltip keeps lead paragraph")
	ok((c.tipBody or ""):find(oldMsg, 1, true) ~= nil, "tooltip second paragraph is Mod.Message")
	S[c].scripts.OnLeave(c)
	eq(#w.errors, 0, "no Lua errors")
	T.clean(w)
end)

test("v24 words: Skip the bird card writes a 75 s summon wait as Summon about 1 min.", function()
	local w, r, W = setupBird()
	W.UI.SummonWait = function() return 75 end
	w:openTaxiMap(r, NODES)
	w:advance(0.5)
	ok(#r:findText("^Summon about 1 min%.") > 0, "line 1 starts Summon about 1 min.")
	eq(#w.errors, 0, "no Lua errors")
	T.clean(w)
end)

test("v24 words: Don't show again toast names Flight offers, not Flight master tip", function()
	local w, r, W = setupBird()
	w:openTaxiMap(r, NODES)
	w:advance(0.5)
	r:clickText("Don't show again")
	w:advance(0.2)
	ok(#r:findText("Flight offers", nil, true) > 0, "toast names Flight offers")
	eq(#r:findText("Flight master tip", nil, true), 0, "toast does not name Flight master tip")
	eq(W.db.birdTip, false, "birdTip turned off")
	eq(#w.errors, 0, "no Lua errors")
	T.clean(w)
end)

test("v24 words: non-Warlock wizard step 1 shows short wording; Warlock keeps its own", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local d = T.driver(w, T.BOB)
	T.settle(w)
	openWizard(w, r)
	ok(#r:findText("Who casts?", nil, true) > 0, "non-Warlock question")
	ok(#r:findText("One Warlock casts. Two more click the portal.", nil, true) > 0, "non-Warlock sub line")
	ok(#r:findText("Just me", nil, true) > 0, "card 1 title")
	ok(#r:findText("A Warlock friend", nil, true) > 0, "card 2 title")
	ok(#r:findText("You invite and take the gold.", nil, true) > 0, "card 2 second line")
	ok(#r:findText("My other account", nil, true) > 0, "card 3 title")
	ok(#r:findText("Each window says yes once.", nil, true) > 0, "card 3 second line")
	eq(#r:findText("Who summons for you?", nil, true), 0, "old question gone")
	eq(#r:findText("You need a Warlock to cast", nil, true), 0, "card 1 old second line gone")
	eq(#r:findText("A Warlock friend in your group casts", nil, true), 0, "card 2 old second line gone")
	eq(#r:findText("Your own Warlock in another window casts", nil, true), 0, "card 3 old second line gone")
	openWizard(w, d)
	ok(#d:findText("Who summons with you?", nil, true) > 0, "Warlock still sees Who summons with you?")
	eq(#w.errors, 0, "no Lua errors")
	T.clean(w)
end)

test("v24 words: Messages list shows titles and short whens without body text; tapping Greeting opens editor", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	openMessages(w, d)
	ok(#d:findText("Your whispers. Tap one to change it.", nil, true) > 0, "intro line")
	local titles = {
		"Greeting", "Price", "Offer", "You're next", "Welcome, please pay", "Thanks",
		"Thanks for the tip", "Paid too little", "Already in a group", "Blocked",
		"Oops, wrong invite", "My advert line", "Where to?", "Get Wuber",
		"Ask a summoner", "Raid: summon coming", "Raid: click the portal",
	}
	for _, title in ipairs(titles) do
		ok(#d:findText(title, nil, true) > 0, "shows title " .. title)
	end
	ok(#d:findText("when someone asks", nil, true) > 0, "Price shows short when")
	eq(#d:findText("when someone asks what it costs", nil, true), 0, "Price long when hidden on list")
	ok(#d:findText("to a buyer in public chat", nil, true) > 0, "Offer shows short when")
	eq(#d:findText("when they pay more than your price", nil, true), 0, "Thanks for the tip has no when on list")
	eq(#d:findText("when the trade is short", nil, true), 0, "Paid too little has no when on list")
	eq(#d:findText("please accept the summon", nil, true), 0, "no message body text on list")
	d:clickText("Greeting")
	w:advance(0.5)
	local s = (d.W.Driver.ui.subs and d.W.Driver.ui.subs.messages) or d.W.UI.drive.screens.messages
	ok(s and s.editor and H.visible(s.editor), "tapping Greeting opens the editor")
	ok(#d:findText("please accept the summon", nil, true) > 0, "editor shows Greeting message text")
	eq(#w.errors, 0, "no Lua errors")
	T.clean(w)
end)

test("v24 words: Messages list 17 cards total height is under 17 x 50", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	openMessages(w, d)
	local s = (d.W.Driver.ui.subs and d.W.Driver.ui.subs.messages) or d.W.UI.drive.screens.messages
	eq(#s.rows, 17, "17 cards")
	local total = 0
	for _, r in ipairs(s.rows) do
		total = total + r:GetHeight()
	end
	ok(total < 17 * 50, "17 cards total height (" .. total .. ") is under 17 x 50")
	eq(#w.errors, 0, "no Lua errors")
	T.clean(w)
end)
