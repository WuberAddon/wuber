-- Wuber 2.4, the word rule on three rider screens: nobody online, waiting for the portal, ride ended unpaid. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- a real ride with the driver, run as far as "in the group" (the same helper as tests/v24/rem_simple_rider_test.lua)
local function rideToGroup(w, d, r)
	local ride = r.W.RequestRide(r.W.Key(d.player.name))
	w:advance(1)
	d.W.AcceptRequest(d.W.incoming[1].id, 5)
	w:advance(2)
	return ride
end

-- three rides with one driver to a place, on three days at the same hour (their usual place and usual hours)
local function seedRides(r, driverName, dest, n)
	local key = r.W.Key(driverName)
	local nowTs = r.env.time()
	local list = {}
	for i = 1, n or 6 do
		list[i] = { dest = dest, driver = driverName, driverKey = key, at = nowTs - i * 86400, price = 5000, saved = 540, stars = 5 }
	end
	r.W.db.rides = list
	r.W.db.totals = nil
end

-- what a tooltip on a frame says: its title and its body (as the game would show them)
local function tipOf(f)
	local tip = f and f.wuberTip
	if not tip then return nil, nil end
	local title, body = tip.title, tip.text
	if type(title) == "function" then title = title(f) end
	if type(body) == "function" then body = body(f) end
	return title, body
end

local function any(r, text)
	return #r:findText(text, false, true) > 0
end

test("v24 words b: 1 nobody online reads No drivers online, Usually here <hours>, Ping drivers, Tell me and Why?", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	seedRides(r, T.ANITA, "Ratchet", 6)
	r.W.UI.Toggle(true)
	w:advance(1)
	r.W.UI.Refresh(true)
	w:advance(1)
	local e = r.W.UI.state.screens.home.empty
	eq(e.title.wuberText, "No drivers online", "the title")
	ok(not any(r, "No drivers online right now"), "the old title is gone")
	local hours = tostring(e.sub.wuberText):match("^Usually here (.+)$")
	ok(hours and hours:find("%d"), "the sub line is Usually here <hours>: " .. tostring(e.sub.wuberText))
	ok(any(r, "Usually here " .. hours), "and it shows")
	ok(not any(r, "You've mostly seen drivers around"), "the long sentence is not on the screen")
	ok(T.H.visible(e.subHit), "a frame over the line takes the mouse")
	local title, body = tipOf(e.subHit)
	eq(title, "Usually here " .. hours, "its tooltip title is the short line")
	eq(body, "You've mostly seen drivers around " .. hours .. " (local time). They appear here as soon as they open.", "its tooltip body is the old sentence")
	ok(any(r, "Ping drivers"), "the ping button")
	ok(#r:findText("Tell me", false, true) > 0 and e.watch.label:GetText() == "Tell me", "the watch button reads Tell me")
	ok(not any(r, "Tell me when one"), "no long watch label")
	local wt = tipOf(e.watch)
	eq(wt, "Tell me when a driver comes online", "the watch tooltip keeps its title")
	local whys = r:findText("Why?", false, true)
	ok(#whys > 0, "the link reads Why?")
	ok(not any(r, "Why can't I see anyone?"), "the old link words are gone")
	eq((tipOf(e.why)), "Why can't I see anyone?", "the link's tooltip title is unchanged")
	T.clean(w)
end)

test("v24 words b: 2 the usual-place note is not shown with nobody online, and shows as before with a driver listed elsewhere", function()
	local w = T.newWorld()
	local bob = T.driver(w, T.BOB, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	seedRides(r, T.ANITA, "Undercity", 6)
	r.W.UI.Toggle(true)
	w:advance(1)
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(any(r, "No drivers online"), "control: the empty state is up")
	ok(not any(r, "nobody's there right now"), "no note while nobody is listed: " .. T.list(r:visibleTexts()):sub(1, 300))
	T.goOnline(bob)
	w:advance(3)
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(any(r, "Bob"), "control: Bob is listed")
	ok(any(r, "Your usual: Undercity - nobody's there right now"), "the note shows with a driver listed: " .. T.list(r:visibleTexts()):sub(1, 300))
	T.clean(w)
end)

test("v24 words b: 3 Advanced, nobody online, a usual place nobody serves: the button reads Pin a bounty, its tooltip names the place", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { advanced = true, spot = "Orgrimmar" })
	T.settle(w)
	r.W.SetAdvanced(true)
	seedRides(r, T.ANITA, "Ratchet", 6)
	r.W.UI.Toggle(true)
	w:advance(1)
	r.W.UI.Refresh(true)
	w:advance(1)
	local e = r.W.UI.state.screens.home.empty
	eq(e.bountyGo.label:GetText(), "Pin a bounty", "the label")
	ok(#r:findText("Pin a bounty", false, true) > 0, "it shows")
	ok(not any(r, "Want a summon?") and not any(r, "Pin a bounty for"), "no older label")
	local title, body = tipOf(e.bountyGo)
	eq(title, "Pin a bounty", "tooltip title")
	ok(body and body:find("Pin a bounty for Ratchet", 1, true) == 1, "the tooltip begins with the place: " .. tostring(body))
	ok(body:find("drivers nearby see it for 30 minutes", 1, true), "and keeps today's words: " .. tostring(body))
	T.clean(w)
end)

test("v24 words b: 4 waiting for the portal: no sub line, one short step text, nothing overlapping", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	r.W.UI.Toggle(true)
	w:advance(1)
	rideToGroup(w, d, r)
	r.W.UI.Toggle(true)
	w:advance(2)
	ok(any(r, "You're in the group"), "the title: " .. T.list(r:visibleTexts()):sub(1, 400))
	ok(any(r, "Stay put"), "the step title: " .. T.list(r:visibleTexts()):sub(1, 900))
	ok(any(r, "Accept the portal when it pops up."), "the step text")
	ok(any(r, "Waiting for the portal"), "the button")
	ok(not any(r, "is getting the portal ready"), "no sub sentence")
	ok(not any(r, "The Warlocks start the summon soon"), "no old step text")
	local title = r:findText("You're in the group", false, true)[1]
	local step = r:findText("Accept the portal when it pops up.", false, true)[1]
	local card = step:GetParent()
	local fs = r:findText("Stay put", false, true)[1]
	ok(fs:GetTop() < title:GetBottom(), "the step title is under the title: " .. tostring(fs:GetTop()) .. " vs " .. tostring(title:GetBottom()))
	ok(card:GetTop() < title:GetBottom() + 0.5, "the step card's top is below the title's bottom")
	T.clean(w)
end)

test("v24 words b: 5 the passphrase line is short and its tooltip carries the rest", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	r.W.UI.Toggle(true)
	w:advance(1)
	rideToGroup(w, d, r)
	r.W.Passphrase = function() return "Violet Otter" end
	r.W.ride.showPass = true
	r.W.UI.Toggle(true)
	w:advance(1)
	r.W.UI.Refresh(true)
	w:advance(1)
	local hits = r:findText("Passphrase: ", false, true)
	ok(#hits > 0, "the line shows: " .. T.list(r:visibleTexts()):sub(1, 400))
	local line = hits[1].wuberText
	eq((line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), "Passphrase: Violet Otter", "the words, and nothing after them")
	ok(not line:find(" - your driver sees", 1, true) and not any(r, "your driver sees"), "no long tail")
	local passHit = r.W.UI.state.screens.found.passHit
	ok(T.H.visible(passHit), "a frame over the line takes the mouse")
	local title, body = tipOf(passHit)
	eq(title, "Passphrase", "tooltip title")
	eq(body, "Your driver sees the same words.", "tooltip body")
	T.clean(w)
end)

test("v24 words b: 6 ride ended unpaid: the two short sentences, and the mail line still follows", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = 1024, screenH = 768 })
	T.settle(w)
	T.goOnline(d) w:advance(5)
	r.W.UI.Toggle(true) w:advance(2.5)
	local function ride(extra)
		local x = { id = "wb6", driver = "Mia Runner", driverKey = "mia runner", dest = "Undercity", price = 50000, state = "done",
			at = r.env.GetTime(), service = "Mia's Rides", arrivedAt = r.env.time() }
		for k, v in pairs(extra or {}) do x[k] = v end
		return x
	end
	r.W.ride = ride({ unpaid = true })
	r.W.Fire("RIDE")
	w:advance(1)
	r.W.UI.Show("done") w:advance(3)
	local scr = r.W.UI.state.screens.done
	ok(T.H.visible(scr.unpaidText), "the unpaid card's words show")
	ok(any(r, "Not paid, so no level progress."), "the first sentence: " .. T.list(r:visibleTexts()):sub(1, 400))
	ok(any(r, "Drivers can block riders who don't pay."), "the second sentence")
	ok(not any(r, "Not paid through Wuber"), "the old sentence is gone")
	ok(not any(r, "leave without paying"), "and the old warning")
	local text = scr.unpaidText:GetText() or ""
	local a = text:find("Not paid, so no level progress.", 1, true)
	local b = text:find("Drivers can block riders who don't pay.", 1, true)
	local c = text:find("Still owe the fare? Send 5g to Mia Runner by mail, subject Wuber.", 1, true)
	ok(a and b and c and a < b and b < c, "the mail line follows the two sentences: " .. text)
	r.W.ride = ride({ unpaid = true, price = 0 })
	r.W.Fire("RIDE")
	w:advance(1)
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not any(r, "Still owe the fare?"), "no mail line when nothing is owed")
	eq(#w.errors, 0, table.concat(w.errors, "\n"))
	T.clean(w)
end)
