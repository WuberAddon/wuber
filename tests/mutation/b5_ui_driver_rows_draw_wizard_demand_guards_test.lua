-- Mutation run guards for Wuber/UI/Driver/{Rows,Draw,Wizard,Demand}.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function tipText(a, region)
	local enter = region and region:GetScript("OnEnter")
	if enter then enter(region) end
	local gt = a.env.GameTooltip
	local lines = gt and H and H.state[gt] and H.state[gt].tipLines or {}
	local out = table.concat(lines, "\n")
	local leave = region and region:GetScript("OnLeave")
	if leave then leave(region) end
	return out
end

local function setupDriver(opts)
	opts = opts or {}
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = opts.spot or "Orgrimmar", class = opts.class or "WARLOCK" })
	T.settle(w)
	T.openDrive(a)
	a.W.UI.ShowDrive("console")
	a.W.Driver.RefreshNow()
	local lastToast
	local origToast = a.W.UI.Toast
	a.W.UI.Toast = function(msg, kind, onClick)
		lastToast = msg
		if origToast then return origToast(msg, kind, onClick) end
	end
	return w, a, a.W, a.W.Driver, a.W.Drive, function() return lastToast end
end

---------------------------------------------------------------------------
-- Wuber/UI/Driver/Rows.lua guards
---------------------------------------------------------------------------

-- guards Wuber/UI/Driver/Rows.lua:56 (return -> nil: due() returns nil instead of remaining fare)
-- guards Wuber/UI/Driver/Rows.lua:191 (if cond negated: RowAction 'next' skips DR.SetPriority)
-- guards Wuber/UI/Driver/Rows.lua:198 (cmp ==->~=: RowAction 'paid' skips DR.MarkPaid)
-- guards Wuber/UI/Driver/Rows.lua:205 (drop statement: RowAction 'block' omits blocked toast)
-- guards Wuber/UI/Driver/Rows.lua:209 (return false->true: RowAction returns true for unknown action)
-- guards Wuber/UI/Driver/Rows.lua:211 (drop statement: RowAction omits DR.Changed)
test("mutation b5 ui driver rows: Due and RowAction handle next, paid, block, and unknown actions", function()
	local w, a, W, D, DR, getToast = setupDriver()
	local origDue = DR.Due
	DR.Due = nil
	local _, right = D.Describe({ state = "arrived", price = 5000, paid = 2000 })
	DR.Due = origDue
	eq(right, "owes 30s", "Describe uses due() for remaining fare")
	local c = { name = "Dan Miller", key = "dan miller", state = "joined" }
	DR.customers = DR.customers or {}
	DR.customers[c.key] = c
	eq(D.RowAction(c, "bogus"), false, "unknown RowAction returns false")
	local prioCalled, paidCalled, changedCalled = false, false, false
	local origPrio, origPaid, origChanged = DR.SetPriority, DR.MarkPaid, DR.Changed
	local origBlack = DR.Blacklist
	DR.SetPriority = nil
	ok(D.RowAction(c, "next"), "RowAction next succeeds without SetPriority")
	eq(c.priority, true, "else branch sets c.priority when SetPriority is nil")
	local blockReason
	DR.SetPriority = function() prioCalled = true end
	DR.MarkPaid = function() paidCalled = true end
	DR.Changed = function() changedCalled = true end
	DR.Blacklist = function(_, why)
		blockReason = why
		return "dan miller"
	end
	ok(D.RowAction(c, "next"), "RowAction next succeeds")
	eq(prioCalled, true, "SetPriority called")
	eq(changedCalled, true, "DR.Changed called")
	ok(D.RowAction(c, "paid"), "RowAction paid succeeds")
	eq(paidCalled, true, "MarkPaid called")
	ok(D.RowAction(c, "block"), "RowAction block succeeds")
	eq(blockReason, "blocked by hand", "default block reason passed")
	ok(getToast() and tostring(getToast()):find("won't be served again", 1, true) ~= nil, "block toast shown")
	DR.SetPriority, DR.MarkPaid, DR.Changed, DR.Blacklist = origPrio, origPaid, origChanged, origBlack
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Rows.lua:229 (cmp ==->~=: RowClick skips invite for queued rider when ClickInvites is true)
test("mutation b5 ui driver rows: RowClick invites queued rider when ClickInvites is true", function()
	local w, a, W, D, DR = setupDriver()
	local c = { name = "Dan Miller", key = "dan miller", state = "queued" }
	DR.customers = DR.customers or {}
	DR.customers[c.key] = c
	local origClickInv, origInv = DR.ClickInvites, DR.Invite
	local invited = false
	DR.ClickInvites = function() return true end
	DR.Invite = function() invited = true end
	ok(D.RowClick(c, "LeftButton"), "RowClick returns true")
	eq(invited, true, "queued rider invited")
	DR.ClickInvites, DR.Invite = origClickInv, origInv
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Rows.lua:250 (drop statement: GiveRaincheck omits ineligible toast)
-- guards Wuber/UI/Driver/Rows.lua:251 (return false->true: GiveRaincheck returns true when ineligible)
-- guards Wuber/UI/Driver/Rows.lua:255 (return -> nil: GiveRaincheck returns nil when DR.GiveRaincheck fails)
-- guards Wuber/UI/Driver/Rows.lua:274 (return -> nil: ToggleGetApp returns nil instead of boolean)
-- guards Wuber/UI/Driver/Rows.lua:306 (return -> nil: RaidAction returns nil instead of true)
test("mutation b5 ui driver rows: GiveRaincheck, ToggleGetApp, and RaidAction return expected booleans and toasts", function()
	local w, a, W, D, DR, getToast = setupDriver()
	local c = { name = "Dan Miller", key = "dan miller", state = "joined", wuberRide = "abcdef" }
	DR.customers = DR.customers or {}
	DR.customers[c.key] = c
	local origElig, origGive = DR.RaincheckEligible, DR.GiveRaincheck
	DR.RaincheckEligible = function() return false, "not paid" end
	eq(D.GiveRaincheck(c), false, "ineligible GiveRaincheck returns false")
	ok(getToast() and tostring(getToast()):find("No raincheck for this ride", 1, true) ~= nil, "ineligible toast shown")
	DR.RaincheckEligible = function() return true end
	DR.GiveRaincheck = function() return false end
	eq(D.GiveRaincheck(c), false, "failed GiveRaincheck returns false (not nil)")
	DR.GiveRaincheck = function() return true end
	eq(D.GiveRaincheck(c), true, "successful GiveRaincheck returns true (not nil)")
	DR.RaincheckEligible, DR.GiveRaincheck = origElig, origGive

	local origAsk = DR.AskGetApp
	DR.AskGetApp = function() return false end
	eq(D.ToggleGetApp(c), false, "ToggleGetApp returns false when unchanged")
	DR.AskGetApp = origAsk

	local origTop = DR.RaidTop
	DR.RaidTop = function() end
	eq(D.RaidAction({ name = "Dan Miller" }, "top"), true, "RaidAction returns true")
	DR.RaidTop = origTop
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Wuber/UI/Driver/Draw.lua guards
---------------------------------------------------------------------------

-- guards Wuber/UI/Driver/Draw.lua:365 (drop statement: readiness line lacks Fix pill)
-- guards Wuber/UI/Driver/Draw.lua:429 (swap and->or: PvP level 2 tooltip omits minutes ago)
-- guards Wuber/UI/Driver/Draw.lua:552 (drop statement: empty queue when closed omits "You're closed" text)
test("mutation b5 ui driver draw: console shows Fix pill, closed empty text, and PvP level 2 tooltip", function()
	local w, a, W, D, DR = setupDriver()
	local v = D.ui.console
	local origDanger = DR.DangerLevel
	DR.DangerLevel = function() return 2, 120 end
	local ch = W.Char()
	if ch then
		ch.wizard = false
		ch.welcomed = true
	end
	D.RefreshNow()
	eq(v.empty.text:GetText(), "You're closed", "closed empty heading shown")
	ok(v.ready and v.ready.lines[1] and v.ready.lines[1].fix ~= nil, "Fix pill created on readiness line")
	ok(v.pvp and v.pvp:IsShown(), "PvP chip shown")
	local txt = tipText(a, v.pvp)
	ok(txt:find("2 min ago", 1, true) ~= nil, "PvP level 2 tooltip includes minutes ago")
	DR.DangerLevel = origDanger
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Draw.lua:459 (drop statement: clicking station filter chip does not refresh)
-- guards Wuber/UI/Driver/Draw.lua:489 (drop statement: filter chip missing .place/.ready)
-- guards Wuber/UI/Driver/Draw.lua:490 (cmp ==->~=: active filter chip highlight inverted)
test("mutation b5 ui driver draw: station filter chip sets filter, refreshes, and highlights active chip", function()
	local w, a, W, D, DR = setupDriver()
	local origStations, origReady = DR.Stations, D.StationReady
	DR.Stations = function()
		return {
			{ place = "Orgrimmar", open = true, ready = true },
			{ place = "Ratchet", open = true, ready = true },
		}
	end
	D.StationReady = function() return true end
	D.RefreshNow()
	local v = D.ui.console
	local chip2 = v.fchips and v.fchips[2]
	ok(chip2 and chip2:IsShown(), "Orgrimmar filter chip shown")
	eq(chip2.place, "Orgrimmar", "chip2.place set")
	local rBefore = chip2.label:GetTextColor()
	a:clickOn(chip2)
	eq(v.stationFilter, "Orgrimmar", "clicking chip sets stationFilter")
	eq(v.fchips[1].place, nil, "All chip has nil place")
	w:advance(0.3)
	-- Active chip2 has ink text (dark) and inactive chip1 has white text (bright)
	local r1 = v.fchips[1].label:GetTextColor()
	local r2 = chip2.label:GetTextColor()
	eq(rBefore ~= r2, true, "clicking chip refreshes chip highlight")
	ok(r2 < 0.5 and r1 > 0.8, "active chip highlighted dark ink while inactive is white")
	DR.Stations, D.StationReady = origStations, origReady
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Draw.lua:759 (cmp ==->~=: Join button fails to accept community invite)
test("mutation b5 ui driver draw: clicking Join on community card accepts invite and hides Join", function()
	local w, a, W, D, DR = setupDriver()
	local origAvail, origMem, origInv, origAccept = W.CommunityAvailable, W.CommunityMember, W.CommunityInvite, W.CommunityAccept
	W.CommunityAvailable = function() return true end
	W.CommunityMember = function() return false end
	W.CommunityInvite = function() return 42 end
	local acceptedId
	W.CommunityAccept = function(id)
		acceptedId = id
		return true
	end
	D.RefreshNow()
	local card = D.ui.console.comm
	ok(card and card.join and card.join:IsShown(), "community Join pill shown")
	a:clickOn(card.join)
	eq(acceptedId, 42, "CommunityAccept called with clubId")
	eq(card.failed, false, "card.failed is false when CommunityAccept returns true")
	W.CommunityAvailable, W.CommunityMember, W.CommunityInvite, W.CommunityAccept = origAvail, origMem, origInv, origAccept
	T.clean(w)
end)

-- guards Wuber/UI/Driver/Draw.lua:915 (drop statement: rr lock view omits old addon title)
test("mutation b5 ui driver draw: rr lock view shows old addon title", function()
	local w, a, W, D, DR = setupDriver()
	local origLock, origRetire, origDretire = DR.Lock, D.screens.retire, D.retire
	DR.Lock = function() return "rr" end
	D.retire = nil
	D.screens.retire = function() error({ update = function() return false end }) end
	D.RefreshNow()
	local pv = D.ui.provider
	ok(pv and pv:IsShown(), "provider view shown")
	eq(pv.title:GetText(), "Your old addon is driving", "rr lock title shown")
	eq(D.retire, nil, "D.retire stays nil when retire builder errors with table")
	DR.Lock, D.screens.retire, D.retire = origLock, origRetire, origDretire
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Wuber/UI/Driver/Wizard.lua guards
---------------------------------------------------------------------------

-- guards Wuber/UI/Driver/Wizard.lua:227 (drop statement: Send offers failure omits toast)
-- guards Wuber/UI/Driver/Wizard.lua:451 (local value -> nil: step 3 ignores DR.Summoners order)
-- guards Wuber/UI/Driver/Wizard.lua:805 (swap and->or: Done tooltip warns Warlock with 0 summoners)
-- guards Wuber/UI/Driver/Wizard.lua:825 (swap and->or: Send offers keeps ghost style on step 3/before sent)
-- guards Wuber/UI/Driver/Wizard.lua:827 (drop statement: Send offers stays primary style after sent)
test("mutation b5 ui driver wizard: wizard step 2 send failure toast, ghost style, and step 3 summoners/tooltip", function()
	local w, a, W, D, DR, getToast = setupDriver()
	local origOffer, origSum, origRoster, origCrew, origUnitClass = DR.OfferCrew, DR.Summoners, DR.Roster, DR.Crew, a.env.UnitClass
	DR.OfferCrew = function() return false end
	DR.Summoners = function() return { "bea jones", "anita lift" } end
	a.env.UnitClass = function(u)
		if u == "party1" then return "Warlock", "WARLOCK" end
		return origUnitClass(u)
	end
	DR.Roster = function() return { { name = "Bea Jones", key = "bea jones", unit = "party1" } } end
	D.ShowScreen("wizard")
	w:advance(1)
	local ws = D.ui.subs and D.ui.subs.wizard
	ok(ws ~= nil, "wizard screen built")
	-- Step 1 -> Step 2
	a:clickOn(ws.choices[2])
	a:clickOn(ws.next)
	w:advance(1)
	eq(ws.step, 2, "moved to step 2")
	-- Pick candidate on step 2 (class resolved via unitClass) and click Send offers
	eq(ws.people.list[1].person.class, "WARLOCK", "rosterNotCrew resolves class via unitClass")
	eq(ws.send.style, "primary", "send stays primary before sent")
	a:clickOn(ws.people.list[1])
	a:clickOn(ws.send)
	ok(getToast() and tostring(getToast()):find("Couldn't send the offer", 1, true) ~= nil, "failed offer toast shown")
	eq(ws.sent, true, "ws.sent set after send")
	eq(ws.send.style, "ghost", "send switches to ghost style after sent")
	-- Advance to step 3 via Next: DR.Summoners order is loaded
	DR.Crew = function() return { { name = "Bea Jones", key = "bea jones", role = "lock", class = "WARLOCK" } } end
	a:clickOn(ws.next)
	w:advance(1)
	eq(ws.step, 3, "moved to step 3")
	eq(ws.order[1], "bea jones", "step 3 loaded DR.Summoners order")
	-- Clear order on Warlock: Done tooltip should NOT warn about non-Warlock missing summoner
	ws.order = {}
	local txt = tipText(a, ws.next)
	eq(txt:find("Nobody is ticked to summon yet", 1, true), nil, "Warlock with 0 summoners does not get non-Warlock warning")
	DR.OfferCrew, DR.Summoners, DR.Roster, DR.Crew, a.env.UnitClass = origOffer, origSum, origRoster, origCrew, origUnitClass
	T.clean(w)
end)

---------------------------------------------------------------------------
-- Wuber/UI/Driver/Demand.lua guards
---------------------------------------------------------------------------

-- guards Wuber/UI/Driver/Demand.lua:64 (return -> nil: Demand list breaks alphabetical tie when riders and newest match)
-- guards Wuber/UI/Driver/Demand.lua:94 (cmp ==->~=: Here() skips W.SamePlace)
-- guards Wuber/UI/Driver/Demand.lua:110 (drop statement: Serve it when away omits toast)
-- guards Wuber/UI/Driver/Demand.lua:111 (return -> nil: Serve it when away returns nil instead of false)
-- guards Wuber/UI/Driver/Demand.lua:113 (return -> nil: Serve it when here returns nil)
-- guards Wuber/UI/Driver/Demand.lua:139 (swap and->or: Serve it tooltip omits go-there hint when away)
-- guards Wuber/UI/Driver/Demand.lua:140 (swap and->or: Serve it tooltip breaks when here)
-- guards Wuber/UI/Driver/Demand.lua:144 (return -> nil: Demand row tooltip body is nil)
-- guards Wuber/UI/Driver/Demand.lua:214 (drop statement: Demand sheet note text omitted)
-- guards Wuber/UI/Driver/Demand.lua:237 (cmp ==->~=: Demand empty note offset wrong)
-- guards Wuber/UI/Driver/Demand.lua:243 (drop statement: Demand sheet subtitle omitted)
test("mutation b5 ui driver demand: Demand sheet sorts ties, sets title/note, and Serve it checks Here", function()
	local w, a, W, D, DR, getToast = setupDriver({ spot = "Orgrimmar" })
	local origBounty, origRole, origMode, origSame, origHere = W.Bounty, DR.Role, DR.Mode, W.SamePlace, W.DestHere
	local demandList = {}
	W.Bounty = { Demand = function() return demandList end }
	DR.Role = function() return "driver" end
	DR.Mode = function() return "sell" end
	W.DestHere = function() return "HereAlias" end
	W.SamePlace = function(h, p) return h == "HereAlias" and p == "Orgrimmar" end
	if DR.opts then DR.opts().watchBounty = true end
	-- 1. Empty demand list
	D.ShowSheet("demand")
	local ds = D.ui.sheets and D.ui.sheets.demand
	ok(ds ~= nil, "demand sheet built")
	eq(ds.note:GetText(), "A bounty is a wish, not a payment: riders still pay your fare. Wuber never moves gold.", "demand note text set")
	eq(ds.frame.sub:GetText(), "Places nobody summons to right now", "demand subtitle set")
	local emptyNoteTop = select(5, ds.note:GetPoint(1))
	eq(emptyNoteTop, -36, "empty note offset includes +30")
	-- 2. Populated list with 6 equal-rider places (MAX_PLACES=5 keeps top 5 alphabetically)
	demandList = {
		{ place = "Zul'Farrak", riders = 1 },
		{ place = "Ratchet", riders = 1 },
		{ place = "Ashenvale", riders = 1 },
		{ place = "Orgrimmar", riders = 1 },
		{ place = "Booty Bay", riders = 1 },
		{ place = "Desolace", riders = 1 },
	}
	D.ShowSheet("demand")
	w:advance(1)
	eq(ds.rows[1].e.place, "Ashenvale", "sorted alphabetically 1")
	eq(ds.rows[5].e.place, "Ratchet", "sorted alphabetically 5")
	-- Check row tooltip (line 144) and Serve it tooltip when away (line 139) vs here (line 140)
	local rTip = tipText(a, ds.rows[1])
	ok(rTip:find("A bounty is a wish", 1, true) ~= nil, "demand row tooltip set")
	local awayServe = ds.rows[1].serve
	local sTip = tipText(a, awayServe)
	ok(sTip:find("Go there to serve them", 1, true) ~= nil, "away Serve it tooltip explains Go there")
	-- Click Serve it on away row -> toast and stays on demand sheet; Mod.serve returns false (not nil)
	eq(W.Mod("UI.Driver.Demand").serve("Ashenvale"), false, "Mod.serve returns false when away")
	a:clickOn(awayServe)
	ok(getToast() and tostring(getToast()):find("Go to Ashenvale to serve them", 1, true) ~= nil, "away Serve it toast shown")
	-- Click Serve it on Orgrimmar row (index 4) -> opens price/place sheet
	local hereRow = ds.rows[4]
	eq(hereRow.e.place, "Orgrimmar", "Orgrimmar row at index 4")
	local hTip = tipText(a, hereRow.serve)
	ok(hTip:find("Opens your price and place with Orgrimmar chosen", 1, true) ~= nil, "here Serve it tooltip names place")
	a:clickOn(hereRow.serve)
	ok(D.ui.sheets.sheet and D.ui.sheets.sheet.frame:IsShown(), "Serve it at current place opens sheet")
	W.SamePlace = nil
	W.DestHere = function() return "Orgrimmar" end
	eq(W.Mod("UI.Driver.Demand").Here("orgrimmar"), true, "Here falls back to case-insensitive match without SamePlace")
	W.Bounty, DR.Role, DR.Mode, W.SamePlace, W.DestHere = origBounty, origRole, origMode, origSame, origHere
	T.clean(w)
end)
