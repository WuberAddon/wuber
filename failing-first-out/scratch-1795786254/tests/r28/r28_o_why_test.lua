-- Round 28, group O (REC-01 part 2): /wuber why for four surfaces. Each Why function returns nil while
-- its surface shows, else one line naming the first rule that hides it; each rule is checked against
-- the real screen (the surface is not shown AND the line names that rule).
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local clean = T.clean

local MIA = "Mia Runner"

-- a rider on Home (folded), Mia open to Undercity, the rider standing elsewhere
local function riderHome()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = MIA, key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" }
	W.db.fold = { v = 1, pages = {}, narrow = true }
	W.AlreadyAt = function() return nil end
	W.Bounty = { Mine = function() return nil end, Demand = function() return {} end }
	W.UI.Toggle(true)
	w:advance(3)
	W.UI.Show("home")
	w:advance(1.5)
	return w, r, W, W.UI.state.screens.home
end

local function rides(r, n)
	local W = r.W
	W.db.rides = {}
	for i = 1, n do
		W.db.rides[i] = { dest = "Undercity", driver = MIA, driverKey = "mia runner", price = 5000, at = r.env.time() - i * 3600, saved = 600 }
	end
	if W.RebuildTotals then W.RebuildTotals() end
end

local function redraw(w, W)
	W.UI.Refresh(true)
	w:advance(1)
end

test("r28 REC-01: /wuber why says why Your usual is not on Home, rule by rule, and nothing while it shows", function()
	local w, r, W, s = riderHome()
	local Home = W.Mod("UI.Rider.Home")
	ok(type(Home.WhyUsual) == "function", "UI.Rider.Home.WhyUsual")
	-- no rides: no usual
	rides(r, 0)
	redraw(w, W)
	ok(not H.visible(s.usual), "no card without rides")
	eq(Home.WhyUsual(), "Your usual: no rides yet, so no usual place.", "no rides")
	-- rides with Mia, Mia open there: the card shows, nothing to say
	rides(r, 3)
	redraw(w, W)
	ok(H.visible(s.usual), "the card shows")
	eq(Home.WhyUsual(), nil, "shown: nil")
	-- a search hides it
	W.UI.SetSearch("Undercity")
	w:advance(1)
	ok(not H.visible(s.usual), "no card while searching")
	eq(Home.WhyUsual(), "Your usual: hidden while you search.", "searching")
	W.UI.SetSearch("")
	w:advance(1)
	ok(H.visible(s.usual), "back after the search")
	-- Mia paused: named as paused (round 46, REV-r28-4)
	W.drivers["mia runner"].state = "paused"
	redraw(w, W)
	ok(not H.visible(s.usual), "no card while Mia is paused")
	eq(Home.WhyUsual(), "Your usual: Mia Runner is paused right now.", "Mia paused")
	-- Mia open somewhere else: the same
	W.drivers["mia runner"].state, W.drivers["mia runner"].dest = "open", "Orgrimmar"
	redraw(w, W)
	ok(not H.visible(s.usual), "no card while Mia serves Orgrimmar")
	eq(Home.WhyUsual(), "Your usual: nobody is open at Undercity.", "Mia moved")
	-- standing in Undercity: no card and no line
	W.AlreadyAt = function() return "Undercity" end
	redraw(w, W)
	ok(not H.visible(s.usual) and not H.visible(s.usualNote), "no card or line where you stand")
	eq(Home.WhyUsual(), "Your usual: you are already there.", "already there")
	clean(w)
end)

test("r28 REC-01: /wuber why says why no bounty is offered on Home, rule by rule, and nothing while one shows", function()
	local w, r, W, s = riderHome()
	local Home = W.Mod("UI.Rider.Home")
	local e = s.empty
	ok(type(Home.WhyBounty) == "function", "UI.Rider.Home.WhyBounty")
	rides(r, 3)
	-- Mia online: no empty state, no offer
	redraw(w, W)
	ok(not H.visible(e.bountyGo), "no bounty pill with a driver online")
	eq(Home.WhyBounty(), "Bounty offers: drivers are online right now.", "drivers online")
	-- nobody online: the pill for the usual place shows
	W.drivers = {}
	redraw(w, W)
	ok(H.visible(e.bountyGo), "the bounty pill for Undercity")
	eq(Home.WhyBounty(), nil, "shown: nil")
	-- one pinned already
	W.Bounty.Mine = function() return { place = "Gadgetzan", copper = 5000, at = 0, sends = 0, left = 600 } end
	redraw(w, W)
	ok(not H.visible(e.bountyGo), "no pill with one pinned")
	eq(Home.WhyBounty(), "Bounty offers: you already have one pinned.", "pinned")
	W.Bounty.Mine = function() return nil end
	-- open as a driver yourself
	local beacon = W.DriverBeacon
	W.DriverBeacon = function()
		return { dest = "Orgrimmar", mapID = 1454, price = 5000, service = "Wuber's Rides", state = "open", team = 1, seats = 1, queue = 0 }
	end
	redraw(w, W)
	ok(not H.visible(e.bountyGo), "no pill while you are open")
	eq(Home.WhyBounty(), "Bounty offers: you are an open driver.", "own beacon")
	W.DriverBeacon = beacon
	-- standing in the usual place
	W.AlreadyAt = function() return "Undercity" end
	redraw(w, W)
	ok(not H.visible(e.bountyGo), "no pill where you stand")
	eq(Home.WhyBounty(), "Bounty offers: you are already there.", "already there")
	W.AlreadyAt = function() return nil end
	redraw(w, W)
	ok(H.visible(e.bountyGo), "the pill again")
	-- a search for a place a driver serves: listed, no bounty card
	W.drivers["mia runner"] = { name = MIA, key = "mia runner", dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" }
	W.UI.SetSearch("Undercity")
	w:advance(1)
	ok(not H.visible(e.bounty), "no bounty card for a served place")
	eq(Home.WhyBounty(), "Bounty offers: a driver already serves that place.", "served")
	W.UI.SetSearch("")
	w:advance(1)
	clean(w)
end)

test("r28 REC-01: /wuber why says the driver's bounties are off in Settings; a rider who is not open never hears it", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	local Demand, Home = W.Mod("UI.Driver.Demand"), W.Mod("UI.Rider.Home")
	DR.Sorted = function() return {} end
	W.Bounty.Demand = function() return { { place = "Gadgetzan", riders = 2, low = 5000, high = 5000, newest = 30 } } end
	DR.IsOpen = function() return true end
	ok(#Demand.List() > 0, "control: the console lists what riders want")
	ok(Home.WhyBounty() ~= "Bounties (driving): off in Settings.", "on: no driving line")
	DR.opts().watchBounty = false
	eq(#Demand.List(), 0, "off: the console lists nothing")
	eq(Home.WhyBounty(), "Bounties (driving): off in Settings.", "off: the line")
	DR.IsOpen = function() return false end
	ok(Home.WhyBounty() ~= "Bounties (driving): off in Settings.", "not driving: not this line")
	clean(w)
end)

test("r28 REC-01: /wuber why says why a milestone card is held back; nothing when none waits", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local W = r.W
	local Mom = W.Mod("UI.Moments")
	ok(type(Mom.WhyMilestone) == "function", "UI.Moments.WhyMilestone")
	eq(Mom.WhyMilestone(), nil, "nothing waits")
	local fight = true
	W.InCombat = function() return fight end
	W.UI.Celebrate("firstRide", { "firstRide" })
	w:advance(1)
	eq(Mom.popCount(), 1, "the card waits")
	ok(not (W.UI.state.pop and H.visible(W.UI.state.pop)), "no card in combat")
	eq(Mom.WhyMilestone(), "Milestone card: waits until combat ends.", "combat")
	fight = false
	W.ride = { id = "r28", driver = MIA, driverKey = "mia runner", dest = "Undercity", price = 5000, state = "accepted",
		at = r.env.GetTime(), payee = MIA, payto = "Mia", service = "Mia's Rides" }
	w:advance(4)
	eq(Mom.popCount(), 1, "still waits during the ride")
	ok(not (W.UI.state.pop and H.visible(W.UI.state.pop)), "no card during the ride")
	eq(Mom.WhyMilestone(), "Milestone card: waits until your ride ends.", "ride")
	W.ride = nil
	w:advance(4)
	eq(Mom.popCount(), 0, "shown once allowed")
	ok(W.UI.state.pop and H.visible(W.UI.state.pop), "the card is up")
	eq(Mom.WhyMilestone(), nil, "shown: nil")
	W.UI.Celebrate("firstRide", { "firstRide" })
	eq(Mom.WhyMilestone(), "Milestone card: waits until the card on screen closes.", "another card up")
	clean(w)
end)

-- a driver on the unfolded Customers pane, Dan in the queue (a whisper lead), Eve a past customer
local DAN, EVE = "Dan Rider", "Eve Night"
local function customersPane()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	local dan = { name = DAN, key = DAN:lower(), state = "lead", source = "whisper", at = 0, price = 5000, paid = 0 }
	DR.Sorted = function() return { dan } end
	DR.customers = { [dan.key] = dan }
	DR.IsOpen = function() return true end
	a.wide = true
	W.db.coach = true
	W.UI.WindowWide(true)
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(2)
	local t0 = a.env.time()
	local l = DR.Log()
	l.rides[#l.rides + 1] = table.concat({ t0 - 90000, 5000, EVE, "Orgrimmar", "t", 5000 }, ",")
	l.rides[#l.rides + 1] = table.concat({ t0 - 600, 5000, DAN, "Undercity", "t", 5000 }, ",")
	W.Driver.ShowScreen("customers")
	w:advance(2)
	return w, a, W, DR, dan
end
local function invitePill(a)
	for _, f in ipairs(a.frames) do
		if f.label and f.label.GetText and f.label:GetText() == "Invite to Wuber" and H.visible(f) then return f end
	end
	return nil
end
local function repaint(w, W)
	W.Driver.RefreshNow()
	w:advance(1)
end

test("r28 REC-01: /wuber why says why the Customers pane has no Invite to Wuber pill, rule by rule", function()
	local w, a, W, DR, dan = customersPane()
	local Cust = W.Mod("UI.Driver.Customers")
	ok(type(Cust.WhyInvite) == "function", "UI.Driver.Customers.WhyInvite")
	local s = W.Driver.ui.subs.customers
	eq(s.picked, DAN, "Dan picked (newest first)")
	ok(invitePill(a), "the pill shows for Dan")
	eq(Cust.WhyInvite(), nil, "shown: nil")
	local function hidden(what, line)
		repaint(w, W)
		ok(not invitePill(a), "no pill: " .. what)
		eq(Cust.WhyInvite(), line, what)
	end
	-- the Get Wuber text cleans to nothing
	W.db.drive.templates.getapp = "||"
	hidden("empty text", "Invite to Wuber: your whisper text is empty.")
	W.db.drive.templates.getapp = nil
	repaint(w, W)
	ok(invitePill(a), "back with its text")
	-- whispers off
	local chat = DR.ChatMode
	DR.ChatMode = function() return "off" end
	hidden("whispers off", "Invite to Wuber: whispers to customers are off.")
	DR.ChatMode = chat
	-- raid mode
	local mode = DR.ModeNow
	DR.ModeNow = function() return "raid" end
	hidden("raid", "Invite to Wuber: not in raid mode.")
	DR.ModeNow = mode
	-- already has Wuber
	local has = DR.HasWuber
	DR.HasWuber = function() return "heard" end
	hidden("has Wuber", "Invite to Wuber: this rider already has Wuber.")
	DR.HasWuber = function() return "crew" end
	hidden("crew", "Invite to Wuber: this rider is one of your crew.")
	DR.HasWuber = has
	repaint(w, W)
	ok(invitePill(a), "the pill once more")
	-- sent today
	DR.GetAppSent(dan)
	hidden("sent today", "Invite to Wuber: already sent today.")
	-- a past customer, not in the queue
	a:click(s.pool.list[2])
	w:advance(1)
	eq(s.picked, EVE, "Eve picked")
	ok(not invitePill(a), "no pill for a past customer")
	eq(Cust.WhyInvite(), "Invite to Wuber: only for a rider in your queue now.", "not in the queue")
	-- folded: no pane, nothing to say
	W.UI.Fold.Toggle()
	w:advance(2)
	eq(Cust.WhyInvite(), nil, "folded: nil")
	clean(w)
end)
