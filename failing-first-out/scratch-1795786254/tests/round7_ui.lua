-- Wuber 2.2.1 (round seven: the rider screens rebuilt to the author's picked mockups, 01 v2, 02 v3,
-- 03 v1, 04 v1, 05 v3, 07 v2). Loaded by run.lua with the same helpers as round six. Test
-- names start "r7 ui:". The tip buttons' own tests are in round5_ui.lua ("r5 ui: tip buttons").
-- These check the new layouts: what shows, where it sits, and that nothing overlaps or leaves
-- its card. The looks are in tools/preview7_rider.png.

local T = ...
local SI = "s" -- (design 1 H: money is letters, "23s", no coin icons)
local function G(s) return "|cfff9c53e" .. s .. "|r" end -- (design 1 P) an amount beside a time is gold letters
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, clean = T.newWorld, T.clean

local MIA, BEA = "Mia Runner", "Bea Jones"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function texts(c) return list(c:visibleTexts(), " | ") end
local function has(c, pattern, plain) return #c:findText(pattern, false, plain) > 0 end

-- rect helpers: a inside b; a and b apart
local function inside(a, b, slack)
	slack = slack or 0.5
	return a.l >= b.l - slack and a.l + a.w <= b.l + b.w + slack and a.b >= b.b - slack and a.b + a.h <= b.b + b.h + slack
end
local function apart(a, b)
	return a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5
end
local function R(f) return H.rect(f) end

-- every visible text of a screen sits on the phone's screen
local function allOnPhone(r, frame, what)
	local phone = R(r.W.UI.state.phone)
	for _, fs in ipairs(r:findText(".", true)) do
		local ancestor, p = false, fs
		while p do
			if p == frame then ancestor = true break end
			p = p.GetParent and p:GetParent() or nil
		end
		if ancestor and H.visible(fs) then
			local rt = R(fs)
			if rt.w > 0 and rt.h > 0 then
				ok(inside(rt, phone, 1), what .. ": '" .. tostring(fs.wuberText or "") .. "' on the phone")
			end
		end
	end
end

local function riderWithRide(state, extra)
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local ride = { id = "r7", driver = MIA, driverKey = key(MIA), dest = "Undercity", price = 5000, state = state,
		at = r.env.GetTime(), payee = MIA, payto = "Mia", service = "Mia's Rides", flightCost = 2300, flightExact = 1 }
	for k, v in pairs(extra or {}) do ride[k] = v end
	r.W.ride = ride
	r.W.db.tipPct = 20
	r.W.Fire("RIDE")
	return w, r
end

local function withDrivers(r)
	local t0 = r.env.GetTime()
	r.W.drivers = r.W.drivers or {}
	r.W.drivers[key(MIA)] = { name = MIA, key = key(MIA), dest = "Undercity", price = 5000, state = "open", team = 3,
		service = "Mia's Rides", heard = t0 }
	r.W.drivers["bob stone"] = { name = "Bob Stone", key = "bob stone", dest = "Ratchet", price = 6000, state = "open", team = 1,
		service = "Bob's Rides", heard = t0 }
	r.W.FlightCost = function() return 2300, 1 end
end

test("r7 ui: home (01 v2) - the destination chips filter the rows; All brings them back", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	r.W.db.coach = true
	withDrivers(r)
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Show("home")
	w:advance(2)
	local s = r.W.UI.state.screens.home
	for _, chip in ipairs({ "All", "Undercity", "Ratchet" }) do ok(has(r, "^" .. chip .. "$"), chip .. " chip: " .. texts(r)) end
	ok(has(r, "Mia's Rides", true) and has(r, "Bob's Rides", true), "both rows: " .. texts(r))
	-- the chips sit in one row under the search, inside the sheet
	local row = R(s.chips)
	ok(inside(row, R(s.sheet)), "the chips inside the sheet")
	ok(apart(row, R(s.search)), "clear of the search")
	r:clickText("Ratchet")
	w:advance(1)
	ok(has(r, "Bob's Rides", true) and not has(r, "Mia's Rides", true), "Ratchet only: " .. texts(r))
	r:clickText("All")
	w:advance(1)
	ok(has(r, "Mia's Rides", true) and has(r, "Bob's Rides", true), "All again: " .. texts(r))
	allOnPhone(r, s.frame, "home")
	clean(w)
end)

test("r7 ui: confirm (02 v3) - the fare top-right of the title, the savings pill, the trust line, the secure button", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	withDrivers(r)
	r.W.TravelSaved = function() return 300 end
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("confirm", key(MIA))
	w:advance(2)
	local s = r.W.UI.state.screens.confirm
	local head = r:findText("^Summon to Undercity$")[1]
	local fare = r:findText("^50s$")[1]
	ok(head and fare, "title and fare: " .. texts(r))
	local hr, fr = R(head), R(fare)
	ok(fr.l > hr.l + hr.w - 0.5, "the fare right of the title")
	ok(math.abs((fr.b + fr.h / 2) - (hr.b + hr.h / 2)) < 8, "on the same line")
	-- (round 9, S1) the line under the verdict uses the verdict's number (flying less the wait)
	ok(has(r, "Summon wins by about 5 min", true) and has(r, "5 min faster · Net " .. G("27" .. SI) .. " vs flying", true), "the savings pill: " .. texts(r))
	ok(has(r, "Trade 50s after you arrive", true), "how you pay: " .. texts(r))
	ok(has(r, "Request summon · 50s", true), "the button")
	ok(H.visible(r.env.WuberRequestButton), "the secure button is over it")
	allOnPhone(r, s.frame, "confirm")
	-- no flight data, no time data: no pill at all
	r.W.FlightCost = function() return nil end
	r.W.TravelSaved = function() return nil end
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not has(r, "vs flying", true) and not has(r, "faster", true), "nothing we can't back: " .. texts(r))
	clean(w)
end)

test("r7 ui: portal (03 v1) - the live portal, no instruction box, the driver, the amber card clear of Accept summon", function()
	local w, r = riderWithRide("portal", { summonUp = true })
	r.W.SummonerMapOK = function() return false, "Deadwind Pass" end
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(2)
	local s = r.W.UI.state.screens.found
	ok(H.visible(s.hero), "the portal hero")
	ok(has(r, "^The portal is up$") and has(r, "Ready to teleport to Undercity", true), texts(r))
	ok(not H.visible(s.tip), "no instruction box (the button says it)")
	ok(H.visible(s.card) and has(r, "Mia Runner", true), "the driver card")
	ok(H.visible(s.alert), "the amber card")
	local al, card, act = R(s.alert), R(s.card), R(s.action)
	ok(apart(al, card) and al.b + al.h <= card.b + 0.5, "under the driver card")
	ok(apart(al, act) and al.b >= act.b + act.h - 0.5, "over Accept summon")
	ok(apart(R(s.title), R(s.hero)), "the title clear of the portal")
	allOnPhone(r, s.frame, "portal")
	-- the summoner's name and the payee stay on the card (scenario 7)
	r.W.ride.summoner, r.W.ride.payto = BEA, "Bea"
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(has(r, "Summoned by Bea", true), "Summoned by: " .. texts(r))
	clean(w)
end)

test("r7 ui: pay (04 v1) - the pay card holds its words and buttons; the status pill under it; Summoned by / Pay Bea kept", function()
	local w, r = riderWithRide("arrived", { summoner = BEA, payto = "Bea", payee = BEA })
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(2)
	local s = r.W.UI.state.screens.found
	local pc = R(s.pay)
	ok(H.visible(s.pay), "the pay card")
	for _, x in ipairs({ s.pay.kicker, s.pay.big, s.pay.sub, s.pay.flight }) do ok(inside(R(x), pc), "inside the card: " .. tostring(x.wuberText)) end
	for _, b in ipairs(s.tipKeys) do ok(inside(R(b), pc), "tip button inside the card") end
	ok(apart(R(s.pay.flight), R(s.tipKeys[1])), "the flight line clear of the buttons")
	ok(has(r, "Flying here costs " .. G("23" .. SI) .. " · this summon really costs " .. G("37" .. SI), true), "exact flight line: " .. texts(r))
	ok(apart(pc, R(s.action)) and pc.b >= R(s.action).b + R(s.action).h - 0.5, "the status pill under the card")
	ok(has(r, "Waiting for Bea to trade", true), "waiting for the payee: " .. texts(r))
	ok(has(r, "Pay Bea", true) and has(r, "Summoned by Bea", true), "who to pay, who summoned: " .. texts(r))
	ok(apart(R(s.sub), R(s.prog)), "the line under the title clear of the steps")
	allOnPhone(r, s.frame, "pay")
	-- no flight data: no line, a shorter card
	r.W.ride.flightCost = nil
	r.W.db.uiFlightQuote = nil
	r.W.FlightCost = function() return nil end
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not has(r, "Flying here", true), "hidden without data")
	clean(w)
end)

test("r7 ui: stranger's trade (04 v2) - the amber card over the title, never over the pay card", function()
	local w, r = riderWithRide("arrived")
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("found")
	w:advance(2)
	w:addBot("Sly Fox", { spot = "Orgrimmar" })
	H.state[r.env.TradeFrame].shown = true
	w:openTrade(w:player("Sly Fox"), r.player)
	w:advance(1)
	r.W.UI.Refresh(true)
	w:advance(1)
	local s = r.W.UI.state.screens.found
	ok(H.visible(s.alert) and has(r, "Sly isn't your driver", true), "the card: " .. texts(r))
	ok(has(r, "Don't pay this trade: pay Mia.", true), texts(r))
	ok(apart(R(s.alert), R(s.pay)), "clear of the pay card")
	ok(apart(R(s.alert), R(s.prog)), "clear of the steps")
	eq(s.title:GetAlpha(), 0, "the title steps aside")
	-- (round 9, S14) the map strip's glowing rider dot (it peeked out under the card) steps aside too
	eq(s.map.me:GetAlpha(), 0, "no glowing dot under the card")
	w:tradeCancel(r.player)
	-- (design 3) the pay look's line "Welcome to Undercity." reaches over the dot at the middle and hides it by itself; a place with a
	-- short name leaves the dot, so this checks the card alone: back once the card goes
	r.W.ride.dest = "Rut"
	w:advance(1)
	r.W.UI.Refresh(true)
	w:advance(1)
	eq(s.map.me:GetAlpha(), 1, "back once the card goes")
	clean(w)
end)

test("r7 ui: done (05 v3) - the top line, the driver's card with five stars, the pills, Done; unpaid: one calm card", function()
	local w, r = riderWithRide("done", { paid = 6000, saved = 840 })
	r.W.UI.Toggle(true)
	w:advance(2)
	r.W.UI.Show("done")
	w:advance(3)
	local s = r.W.UI.state.screens.done
	ok(has(r, "Undercity · Paid 60s to Mia", true), "the top line: " .. texts(r))
	local rate = R(s.rate)
	for i, st in ipairs(s.stars) do ok(H.visible(st) and inside(R(st), rate), "star " .. i .. " in the card") end
	ok(apart(R(s.top), rate), "the top line clear of the card")
	ok(has(r, "You saved about 14 min of flying · saved to your trips", true), "time saved: " .. texts(r)) -- (r28 AUD-27) worked out, not timed: about
	ok(has(r, "Flying: " .. G("23" .. SI) .. " · this summon really cost " .. G("37" .. SI), true), "flight: " .. texts(r))
	local done = R(s.done)
	ok(apart(R(s.savedPill), done) and apart(R(s.flightPill), done), "the pills clear of Done")
	ok(apart(R(s.savedPill), R(s.flightPill)), "the pills apart")
	allOnPhone(r, s.frame, "done")
	r.W.ride.unpaid, r.W.ride.paid = true, nil
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(has(r, "^Ride ended$"), texts(r))
	ok(not H.visible(s.stars[1]) and not H.visible(s.savedPill) and not H.visible(s.flightPill), "no stars, no pills")
	ok(H.visible(s.unpaidText) and inside(R(s.unpaidText), R(s.rate)), "the note inside the card")
	clean(w)
end)

test("r7 ui: trips (07 v2) - TIME SAVED hero counting up, the level card, the chips, the medals kept and unclipped", function()
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	r.W.Stats = function()
		return { rides = 12, places = 5, spent = 64000, saved = 21600, savedValue = 60000, favouriteDriver = MIA,
			favouriteKey = key(MIA), favouriteCount = 5, streakDays = 4, flightSaved = 41200 }
	end
	r.W.UI.Toggle(true)
	w:advance(2)
	r:clickText("Trips")
	w:advance(0.2)
	local early = r:findText("^%d+h %d+m$")[1] or r:findText("^%d+m$")[1]
	ok(early, "the hero number: " .. texts(r))
	w:advance(3)
	ok(has(r, "^Time saved$"), texts(r))
	ok(has(r, "^6h 0m$"), "counted up to 6h 0m: " .. texts(r))
	ok(has(r, "4g 12s saved vs flying · 12 rides across 5 places", true), "the caption: " .. texts(r))
	ok(has(r, "^Go%-to: Mia %(5%)$") and has(r, "^4%-day streak$"), "the chips: " .. texts(r))
	-- r50 H24-01: the first medal row hides under the cue at scroll 0, so scroll the folded page a little first
	do
		local M, tv = r.W.Mod("UI.Rider.Trips"), r.W.Mod("UI.Rider.Trips").view()
		local y = math.min(100, tv.scrollMax or 0)
		tv.scroll, tv.scrollTarget = y, y
		tv.content:ClearAllPoints()
		tv.content:SetPoint("TOPLEFT", tv.clip, "TOPLEFT", 0, y)
		M.trimCells()
	end
	-- (#2) the card is hidden while no medal row shows, so its heading is looked for after the view scrolls
	ok(has(r, "^Milestones$"), "the medals: " .. texts(r))
	ok(has(r, "^First Ride$") and has(r, "^5 Rides$"), "the medal names (unchanged): " .. texts(r))
	clean(w)
end)
