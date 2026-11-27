-- Wuber 2.4 FIX3 group J: the "What's new" card (UI.WhatsNew). Loaded by tests/run.lua with its helper table T.
-- Once per account per version, saved as WuberDB.newsSeen; never on a fresh install; waits for combat, a ride and
-- another card; only the player's own close counts as seen; "2.4.3-dev" counts as 2.4.3.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function login(w, saved)
	local c = T.rider(w, T.TESTCHAR, { saved = saved })
	local W = c.W
	return c, W, W.Mod("UI.WhatsNew")
end

local function up(Mod)
	local c = Mod.Card()
	return c and H.visible(c) and c or nil
end

-- a fresh table each time: the game saves into the one it is given
local function updated() return { Wuber = { coach = true, newsSeen = "2.3.4" } } end

test("v24 whatsnew: an updated player gets the card a few seconds after login, and only their own close counts", function()
	local w = T.newWorld()
	local c, W, Mod = login(w, updated())
	ok(not up(Mod), "not at once")
	w:advance(5)
	local card = up(Mod)
	ok(card, "the card shows after a few seconds")
	eq(card.title:GetText(), "What's new in Wuber 2.4", "the title")
	eq(card:GetParent(), c.env.UIParent, "a card of its own, not inside the phone")
	eq(W.db.newsSeen, "2.3.4", "showing is not seeing")
	-- (the 20 rewrites, W-20) the pop-up is a title and two buttons; [See what's new] opens the lines, [Got it] closes
	eq(card.got.label:GetText(), "See what's new", "the main button opens the list")
	eq(card.notNow.label:GetText(), "Not now", "and the other closes the card")
	card.got:Click()
	w:advance(0.5)
	ok(up(Mod), "the list is the same card")
	eq(W.db.newsSeen, "2.3.4", "opening the list is not seeing")
	eq(card.got.label:GetText(), "Got it", "the list has one button, Got it")
	ok(not H.visible(card.notNow), "Not now is gone from the list")
	card.got:Click()
	w:advance(1)
	ok(not up(Mod), "closed")
	eq(W.db.newsSeen, "2.4.3", "the account has seen 2.4.3")
	local saved = w:logout(c)
	local _, W2, Mod2 = login(w, saved)
	w:advance(30)
	ok(not up(Mod2), "not again on the next login")
	eq(W2.db.newsSeen, "2.4.3", "still saved")
	T.clean(w)
end)

test("v24 whatsnew: the close cross counts as seen too, and a player from before the field (guide done) is updated", function()
	local w = T.newWorld()
	local _, W, Mod = login(w, { Wuber = { coach = true } })
	w:advance(5)
	local card = up(Mod)
	ok(card, "no newsSeen but the guide is done: an update")
	card.close:Click()
	w:advance(1)
	eq(W.db.newsSeen, "2.4.3", "saved")
	T.clean(w)
end)

test("v24 whatsnew: a fresh install never sees it (the version is saved quietly)", function()
	local w = T.newWorld()
	local _, W, Mod = login(w, { Wuber = {} })
	w:advance(30)
	ok(not up(Mod), "no card on a fresh install")
	eq(W.db.newsSeen, "2.4.3", "the current version is saved")
	eq(Mod.Pending(), nil, "nothing pending")
	T.clean(w)
end)

test("v24 whatsnew: a driver who never rode and never did the guide is an updated player too", function()
	local w = T.newWorld()
	local _, W, Mod = login(w, { Wuber = { drive = { log = { rides = { "900,5000,Rider One,Ratchet,t,5000" } } } } })
	w:advance(5)
	ok(up(Mod), "the driving log shows this is no fresh install: the card shows")
	eq(W.db.newsSeen, nil, "and nothing is saved until the player closes it")
	T.clean(w)
end)

test("v24 whatsnew: the same or a newer version already seen shows nothing", function()
	for _, seen in ipairs({ "2.4.3", "2.5.0" }) do
		local w = T.newWorld()
		local _, W, Mod = login(w, { Wuber = { coach = true, newsSeen = seen } })
		w:advance(30)
		ok(not up(Mod), "no card when newsSeen is " .. seen)
		eq(W.db.newsSeen, seen, "unchanged")
		T.clean(w)
	end
end)

test("v24 whatsnew: a version with no entry shows no card; -dev counts as the release", function()
	local w = T.newWorld()
	local c, W, Mod = login(w, updated())
	eq(W.VERSION, "2.4.3-dev", "this branch's version")
	eq(Mod.Version(), "2.4.3", "2.4.3-dev is 2.4.3")
	W.VERSION = "2.4.3"
	eq(Mod.Version(), "2.4.3", "2.4.3 is 2.4.3")
	W.VERSION = "2.4"
	eq(Mod.Version(), nil, "not a version")
	W.VERSION = "2.4.3-dev"
	w:advance(5)
	Mod.Card():Hide()
	T.clean(w)
	w = T.newWorld()
	local saved = { Wuber = { coach = true, newsSeen = "2.3.4" } }
	local c2 = T.rider(w, T.TESTCHAR, { saved = saved })
	local M2 = c2.W.Mod("UI.WhatsNew")
	local notes = M2.NOTES
	M2.NOTES = {}
	c2.W.db.newsSeen = "2.3.4"
	w:advance(30)
	ok(not up(M2), "no entry, no card")
	M2.NOTES = notes
	T.clean(w)
end)

test("v24 whatsnew: it waits for combat and a ride, and a card the game hid is not seen", function()
	local w = T.newWorld()
	local c, W, Mod = login(w, updated())
	w:enterCombat(c)
	w:advance(5)
	ok(not up(Mod), "not in combat")
	eq(Mod.Why(), "What's new card: not in combat.", "why")
	w:leaveCombat(c)
	W.ride = { id = "r1", driver = "Anita Lift", state = "summoning", dest = "Undercity" }
	w:advance(12)
	ok(not up(Mod), "not during a ride")
	eq(Mod.Why(), "What's new card: not during a ride.", "why")
	W.ride = nil
	w:advance(12)
	ok(up(Mod), "it shows once the ride is over")
	w:enterCombat(c)
	w:advance(0.5)
	ok(not up(Mod), "combat hides it")
	eq(W.db.newsSeen, "2.3.4", "a card the game hid is not seen")
	w:leaveCombat(c)
	w:advance(12)
	ok(up(Mod), "and it comes back")
	T.clean(w)
end)

test("v24 whatsnew: it never opens over the login tip card, the guide or a toast", function()
	local w = T.newWorld()
	local c, W, Mod = login(w, updated())
	local tip = W.Mod("UI.Tips").Card()
	ok(tip, "the tip card exists")
	tip:Show()
	w:advance(5)
	ok(not up(Mod), "not over the tip card")
	eq(Mod.Why(), "What's new card: waits for the card or guide on screen to close.", "why")
	tip:Hide()
	local ui = W.Mod("UI.Kit").ui
	ui.coaching = true
	w:advance(12)
	ok(not up(Mod), "not over the first-open guide")
	ui.coaching = false
	local saved = W.UI.ToastShowing
	W.UI.ToastShowing = function() return true end
	w:advance(12)
	ok(not up(Mod), "not while a toast is up")
	W.UI.ToastShowing = saved
	w:advance(12)
	ok(up(Mod), "it shows when all is quiet")
	T.clean(w)
end)

test("v24 whatsnew: the card grows to hold its longest text, whole", function()
	local w = T.newWorld()
	local _, W, Mod = login(w, updated())
	local v, e = Mod.Longest()
	eq(v, "2.4.3", "the longest entry")
	ok(#e >= 1 and #e <= 3, "one to three lines per version")
	w:advance(5)
	local card = up(Mod)
	ok(card, "shown")
	ok(Mod.Expand(), "See what's new opens the list")
	local text = card.text:GetText()
	for _, line in ipairs(e) do ok(text:find(line, 1, true), "the whole line is on the card: " .. line:sub(1, 20)) end
	ok(card:GetHeight() >= 36 + card.text:GetStringHeight() + 40, "the card is as tall as its text plus the button row")
	ok(card.close and card.got, "close controls")
	T.clean(w)
end)

test("v24 whatsnew: /wuber why lists the card", function()
	local w = T.newWorld()
	local c, W, Mod = login(w, updated())
	w:enterCombat(c)
	w:advance(5)
	local out = {}
	local orig = W.Print
	W.Print = function(...) out[#out + 1] = table.concat({ ... }, " ") end
	local env = c.env
	if env.SlashCmdList and env.SlashCmdList.WUBER then env.SlashCmdList.WUBER("why") end
	W.Print = orig
	local hit
	for _, l in ipairs(out) do if tostring(l):find("What's new card: not in combat.", 1, true) then hit = true end end
	ok(hit, "the why list names it: " .. table.concat(out, " | "))
	T.clean(w)
end)

test("v24 whatsnew: the card keeps clear of the floating button and the mini console at the top centre", function()
	local w = T.newWorld()
	local c, W, Mod = login(w, updated())
	local env = c.env
	local sw, sh = env.UIParent:GetWidth(), env.UIParent:GetHeight()
	local function win(name, wd, ht, y)
		local f = env.CreateFrame("Frame", name, env.UIParent)
		f:SetSize(wd, ht)
		f:SetPoint("TOP", env.UIParent, "TOP", 0, y)
		f:Show()
		return f
	end
	local btn = win("WuberDriveButton", 264, 60, -110)
	local mini = win("WuberDriveMini", 300, 102, -180)
	w:advance(5)
	local card = Mod.Card()
	local function apart(a, b)
		return a:GetLeft() >= b:GetRight() or a:GetRight() <= b:GetLeft() or a:GetBottom() >= b:GetTop() or a:GetTop() <= b:GetBottom()
	end
	if up(Mod) then
		ok(apart(card, btn), "the card does not cover the floating button")
		ok(apart(card, mini), "the card does not cover the mini console")
	else
		ok(Mod.Why():find("no room", 1, true), "or it waits: " .. tostring(Mod.Why()))
	end
	T.clean(w)
end)

test("v24 whatsnew: [Not now] closes the pop-up as seen, and a card shown again is a pop-up again", function()
	local w = T.newWorld()
	local c, W, Mod = login(w, updated())
	w:advance(5)
	local card = up(Mod)
	ok(card, "shown")
	ok(Mod.Expand(), "the list")
	card.got:Click()
	w:advance(1)
	ok(not up(Mod), "closed from the list")
	eq(W.db.newsSeen, "2.4.3", "seen")
	W.db.newsSeen = "2.3.4"
	ok(Mod.Show("2.4.3"), "shown again")
	w:advance(1)
	eq(card.got.label:GetText(), "See what's new", "a pop-up again, with its two buttons")
	ok(H.visible(card.notNow), "Not now is back")
	card.notNow:Click()
	w:advance(1)
	ok(not up(Mod), "Not now closes the card")
	eq(W.db.newsSeen, "2.4.3", "and counts as seen, as Got it does")
	T.clean(w)
end)
