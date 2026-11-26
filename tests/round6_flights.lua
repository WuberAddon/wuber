-- Wuber 2.2.1 tests: shared flight prices (every Wuber user who opens a flight map adds its real
-- prices to a pool that spreads peer to peer) and measured flight times (2.2: read from Enhanced
-- Flight Map; 2.3.0, SPEC7 4: the player's own flights, Core.FlightTimes, and 2.2's EFM times kept
-- as own by the login migration).
-- Loaded by run.lua with the round-six helpers. Test names start "r6 flights:".

local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local clean, settle, rider, driver, list = T.clean, T.settle, T.rider, T.driver, T.list
local ANITA, TESTCHAR, BOB = T.ANITA, T.TESTCHAR, T.BOB

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function texts(c) return list(c:visibleTexts(), " | ") end
local function has(c, pattern, plain) return #c:findText(pattern, false, plain) > 0 end

-- addon messages of a kind sent by `from` (that the game took)
local function sent(w, from, pattern)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.from == from and e.prefix == "WUBER" and e.result == 0 and e.text:find(pattern) then out[#out + 1] = e end
	end
	return out
end

-- A flight master at Ratchet (Horde side): Gadgetzan, Orgrimmar, Crossroads, Everlook.
local RATCHET = {
	{ name = "Ratchet, The Barrens", type = "CURRENT", cost = 0 },
	{ name = "Gadgetzan, Tanaris", type = "REACHABLE", cost = 2345 },
	{ name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 610 },
	{ name = "Crossroads, The Barrens", type = "REACHABLE", cost = 150 },
	{ name = "Everlook, Winterspring", type = "REACHABLE", cost = 3800 },
}

-- The flight map's node ids (C_TaxiMap), on one window.
local NODES = {
	{ nodeID = 80, name = "Ratchet, The Barrens", faction = 1 },
	{ nodeID = 40, name = "Gadgetzan, Tanaris", faction = 1 },
	{ nodeID = 23, name = "Orgrimmar, Durotar", faction = 1 },
	{ nodeID = 25, name = "Crossroads, The Barrens", faction = 1 },
	{ nodeID = 39, name = "Gadgetzan, Tanaris", faction = 2 }, -- the Alliance's node: never ours
}
-- A trip the game's own table can't route (a route it lacks, e.g. after a patch): only then
-- do prices seen at a flight master (own, then shared) show (the author: always the full list price).
local function noTable(c)
	c.W.TAXI = nil
	c.W.FLY.TaxiReset()
end

local function taxiMap(env)
	env.GetTaxiMapID = function() return 1414 end
	env.C_TaxiMap = { GetAllTaxiNodes = function(mapID) if mapID == 1414 then return NODES end return {} end }
end

---------------------------------------------------------------------------
-- The pool spreads: B never saw a flight master and gets A's real price on Confirm
---------------------------------------------------------------------------

test("r6 flights: A reads prices at a flight master; B (no flight paths) gets the real price over the network and sees it on Confirm", function()
	if not T.HAVE_UI then return end
	local w = H.NewWorld({})
	-- A flew Ratchet > Gadgetzan in 2.2 (Enhanced Flight Map measured it; 2.3 keeps it as own)
	local a = driver(w, ANITA, { spot = "Gadgetzan", prepare = function(env) taxiMap(env) end,
		saved = { Wuber = { flights = { ["H|ratchet|gadgetzan"] = { t = 312, tat = H.EPOCH + 1015, tsrc = "efm" } } } } })
	local b = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	noTable(a)
	noTable(b)
	w:openTaxi(a, RATCHET) -- A once stood at Ratchet's flight master
	eq(a.W.FlightCost("Ratchet", "Gadgetzan"), 2345, "A's own price")
	eq(a.W.FlightTime("Ratchet", "Gadgetzan"), 312, "A's measured flight (2.2's EFM time, now own)")
	eq(select(2, a.W.FlightTime("Ratchet", "Gadgetzan")), "own")
	eq(a.W.db.flightsV, 3, "migrated once")
	ok(a.W.Drive.SetOpen(true))
	w:advance(5)
	local d = b.W.drivers[key(ANITA)]
	ok(d and b.W.VerAtLeast(d.ver, "2.3.0"), "B hears A, a 2.3.0 (or later) driver")
	eq(b.W.FlightCost(nil, "Gadgetzan"), nil, "B never opened a flight map and the table lacks the route: nothing yet")
	ok(not b.W.db.flights or next(b.W.db.flights) == nil, "B's pool is empty")
	-- B opens Confirm: asks A; A answers with the real price (the asked flight first)
	b.W.db.tipPct = 0
	T.openConfirm(b, key(ANITA))
	w:advance(5)
	eq(#sent(w, TESTCHAR, "^F~1~H~%?~ratchet:gadgetzan$"), 1, "B asked A once")
	local answer = sent(w, ANITA, "^F~1~H~")
	ok(#answer >= 1, "A answered")
	ok(answer[1].text:find("~ratchet:gadgetzan:2345:%d+:312", 1) ~= nil, "the asked flight first: " .. answer[1].text)
	local c, ex, src = b.W.FlightCost(nil, "Gadgetzan")
	eq(c, 2345, "B has A's real price")
	eq(ex, 1, "shown as a real price")
	eq(src, "shared")
	local info = b.W.FlightInfo("Gadgetzan")
	ok(info and info.shared == true and info.cost == 2345, "FlightInfo says shared")
	ok(has(b, "vs flying", true), "Confirm's savings pill uses it: " .. texts(b))
	ok(not has(b, "about 23s", true), "never 'about'")
	-- the measured time came along: B's time saved uses it (60 s to the flight master + 312 s)
	local secs, how, measured = b.W.TravelSaved("Gadgetzan")
	eq(secs, 372, "measured time beats the speed model")
	eq(measured, true)
	eq(b.W.FlightTime(nil, "Gadgetzan"), 312)
	-- every F fits, proto 1
	for _, e in ipairs(w.addonLog) do
		if e.text:find("^F~") then ok(#e.text <= 250 and e.text:find("^F~1~") ~= nil, "F fits: " .. e.text) end
	end
	clean(w)
end)

test("r6 flights: a rider with prices passes them to a 2.2.1 driver it hears; never to an older client", function()
	local w = H.NewWorld({})
	local a = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	w:openTaxi(a, RATCHET)
	w:addBot("Old Lock", { spot = "Gadgetzan" })
	w:addBot("New Lock", { spot = "Gadgetzan" })
	w:inject("Old Lock", "D~1~Gadgetzan~1446~515~285~5000~Rides~open~1~1~H~2.2.0", "CHANNEL")
	w:inject("New Lock", "D~1~Gadgetzan~1446~515~285~5000~Rides~open~1~1~H~2.2.1", "CHANNEL")
	w:advance(10)
	eq(#sent(w, TESTCHAR, "^F~"), 1, "one F")
	local f = sent(w, TESTCHAR, "^F~")[1]
	eq(f.target, "New Lock", "to the 2.2.1 driver only")
	ok(f.text:find("~ratchet:gadgetzan:2345:0:", 1, true), "the flight to where he drives first: " .. f.text)
	-- nothing new for him: nothing more, however often he beacons
	for _ = 1, 5 do
		w:inject("New Lock", "D~1~Gadgetzan~1446~515~285~5000~Rides~open~1~1~H~2.2.1", "CHANNEL")
		w:advance(70)
	end
	eq(#sent(w, TESTCHAR, "^F~"), 1, "each entry once per peer and session")
	clean(w)
end)

---------------------------------------------------------------------------
-- What goes in the pool
---------------------------------------------------------------------------

test("r6 flights: own beats shared; a shared price is replaced only by a newer one or one more peers report", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	noTable(r)
	local W = r.W
	local now = r.env.time()
	ok(W.FlightMerge("H", "ratchet", "gadgetzan", 2000, nil, now - 3600, "p one"), "a shared price goes in")
	local c, _, src = W.FlightCost(nil, "Gadgetzan")
	eq(c, 2000) eq(src, "shared")
	ok(not W.FlightMerge("H", "ratchet", "gadgetzan", 2100, nil, now - 7200, "p two"), "older, one peer: kept")
	eq((W.FlightCost(nil, "Gadgetzan")), 2000)
	ok(W.FlightMerge("H", "ratchet", "gadgetzan", 2200, nil, now - 60, "p three"), "newer: replaces")
	eq((W.FlightCost(nil, "Gadgetzan")), 2200)
	W.FlightMerge("H", "ratchet", "gadgetzan", 2200, nil, now - 60, "p five")
	eq(W.db.flights["H|ratchet|gadgetzan"].n, 2, "two peers report 2200")
	-- an older value reported by more peers than the current one
	W.FlightMerge("H", "ratchet", "gadgetzan", 2100, nil, now - 9000, "p four")
	eq((W.FlightCost(nil, "Gadgetzan")), 2200, "two peers for 2100 vs two for 2200: kept")
	W.FlightMerge("H", "ratchet", "gadgetzan", 2100, nil, now - 9000, "p six")
	eq((W.FlightCost(nil, "Gadgetzan")), 2100, "three peers for 2100: confirmed by more")
	eq(W.db.flights["H|ratchet|gadgetzan"].n, 3)
	ok(not W.FlightMerge("H", "ratchet", "gadgetzan", 2100, nil, now - 9000, "p six"), "the same peer counts once")
	-- own learned always wins, and stays
	w:openTaxi(r, RATCHET)
	c, _, src = W.FlightCost(nil, "Gadgetzan")
	eq(c, 2345) eq(src, "own")
	ok(not W.FlightMerge("H", "ratchet", "gadgetzan", 999, nil, now, "p five"), "shared never beats own")
	for i = 1, 5 do W.FlightMerge("H", "ratchet", "gadgetzan", 999, nil, now, "q" .. i) end
	eq((W.FlightCost(nil, "Gadgetzan")), 2345, "however many peers")
	-- times: EFM's own beats shared too
	ok(W.FlightMerge("H", "ratchet", "orgrimmar", nil, 250, now, "p one"), "a shared time")
	eq(W.FlightTime(nil, "Orgrimmar"), 250)
	eq((W.FlightCost(nil, "Orgrimmar")), 610, "the own price beside it stays")
	clean(w)
end)

test("r6 flights: implausible, unknown-place and wrong-faction values are refused (direct and over the wire)", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	noTable(r)
	local W = r.W
	local now = r.env.time()
	local function no(what, ...) ok(not W.FlightMerge(...), what) end
	no("0 copper", "H", "ratchet", "gadgetzan", 0, nil, now, "p")
	no("over 100g", "H", "ratchet", "gadgetzan", 1000001, nil, now, "p")
	no("fractions", "H", "ratchet", "gadgetzan", 12.5, nil, now, "p")
	no("an unknown place", "H", "ratchet", "narnia", 500, nil, now, "p")
	no("a whole zone", "H", "ratchet", "the barrens", 500, nil, now, "p")
	no("a dungeon", "H", "ratchet", "zulfarrak", 500, nil, now, "p")
	no("the same place", "H", "ratchet", "ratchet", 500, nil, now, "p")
	no("the other side's town", "H", "ratchet", "theramore", 500, nil, now, "p")
	no("the other side's entry", "A", "ratchet", "gadgetzan", 500, nil, now, "p")
	no("from the future", "H", "ratchet", "gadgetzan", 500, nil, now + 3600, "p")
	no("too old", "H", "ratchet", "gadgetzan", 500, nil, now - 91 * 86400, "p")
	no("a 4 s flight", "H", "ratchet", "gadgetzan", nil, 4, now, "p")
	no("a 2 h flight", "H", "ratchet", "gadgetzan", nil, 7200, now, "p")
	eq(next(W.db.flights), nil, "nothing stored")
	-- over the wire
	w:addBot("Bad Peer", { spot = "Ratchet" })
	w:inject("Bad Peer", "F~1~A~ratchet:gadgetzan:500:0:", "WHISPER", r)
	w:advance(1)
	w:inject("Bad Peer", "F~1~H~ratchet:stormwind:500:0:~ratchet:gadgetzan:0:0:~ratchet:everlook:99999999:0:"
		.. "~ratchet:nowhere:500:0:~ratchet:gadgetzan:abc:0:~garbage", "WHISPER", r)
	w:advance(1)
	eq(next(W.db.flights), nil, "nothing stored from the wire either")
	w:inject("Bad Peer", "F~1~H~ratchet:gadgetzan:500:3:", "WHISPER", r)
	eq((W.FlightCost(nil, "Gadgetzan")), 500, "a good one is taken")
	-- a flood: 3 Fs a peer a minute are read, the rest dropped
	w:addBot("Flood Peer", { spot = "Ratchet" })
	local heard = W.FlyNet.heard
	for i = 1, 6 do w:inject("Flood Peer", "F~1~H~ratchet:orgrimmar:" .. (100 + i) .. ":0:", "WHISPER", r) end
	eq(W.FlyNet.heard - heard, 3, "3 of the flood read")
	eq((W.FlightCost(nil, "Orgrimmar")), 101, "the first stays (the others are no newer, nor reported by more)")
	clean(w)
end)

test("r6 flights: the store keeps 2000 entries; the oldest shared go first, own never", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	local W = r.W
	eq(W.FLY.MAX, 2000, "the cap")
	W.FLY.MAX = 20 -- (two sides' towns make fewer than 2000 pairs: the cap is shrunk to test it)
	w:openTaxi(r, RATCHET) -- 4 own
	local towns = { "orgrimmar", "undercity", "thunder bluff", "crossroads", "camp mojache", "brackenwall village",
		"splintertree post", "sun rock retreat", "shadowprey village", "freewind post", "valormok", "gromgol",
		"tarren mill", "kargath", "stonard", "hammerfall", "revantusk village", "booty bay", "everlook", "gadgetzan" }
	local now = r.env.time()
	for i, t in ipairs(towns) do W.FlightMerge("H", "booty bay" == t and "everlook" or "booty bay", t, 1000 + i, nil, now - 10000 + i * 10, "p") end
	local n = 0
	for _ in pairs(W.db.flights) do n = n + 1 end
	eq(n, 20, "capped")
	for _, k in ipairs({ "H|ratchet|gadgetzan", "H|ratchet|orgrimmar", "H|ratchet|crossroads", "H|ratchet|everlook" }) do
		ok(W.db.flights[k], "own kept: " .. k)
	end
	eq(W.db.flights["H|booty bay|orgrimmar"], nil, "the oldest shared went")
	ok(W.db.flights["H|booty bay|gadgetzan"], "the newest shared stayed")
	W.FLY.MAX = 2000
	clean(w)
end)

test("r6 flights: /reload keeps the pool (and the node ids)", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Ratchet", prepare = taxiMap })
	settle(w)
	ok(r.W.FlightMerge("H", "ratchet", "gadgetzan", 2345, 300, r.env.time() - 120, "p"))
	w:openTaxi(r, { { name = "Ratchet, The Barrens", type = "CURRENT", cost = 0 } })
	local r2 = w:reload(r)
	settle(w, 5)
	local c, src = r2.W.FlightSeen(nil, "Gadgetzan")
	eq(c, 2345, "after /reload") eq(src, "shared")
	eq(r2.W.FlightTime(nil, "Gadgetzan"), 300)
	eq(r2.W.db.flightNodes.H[80], "ratchet", "node ids kept")
	clean(w)
end)

---------------------------------------------------------------------------
-- Limits: never more than one F a peer a minute, four a minute in all; never ahead of a ride
---------------------------------------------------------------------------

test("r6 flights: over 10 minutes with 8 peers: at most one F a peer a minute, 4 a minute in all, 10 a peer", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	local W = r.W
	-- plenty to share: our own prices from Ratchet, and shared ones from Booty Bay
	w:openTaxi(r, RATCHET)
	local now = r.env.time()
	for i, t in ipairs({ "orgrimmar", "undercity", "thunder bluff", "crossroads", "camp mojache", "brackenwall village",
		"splintertree post", "sun rock retreat", "shadowprey village", "freewind post", "valormok", "gromgol",
		"tarren mill", "kargath", "stonard", "hammerfall", "revantusk village", "everlook", "gadgetzan" }) do
		W.FlightMerge("H", "booty bay", t, 500 + i, nil, now - i * 60, "p")
		W.FlightMerge("H", t, "booty bay", 600 + i, 120 + i, now - i * 60, "p")
	end
	local peers = {}
	for i = 1, 8 do
		peers[i] = "Peer " .. string.char(64 + i) .. "son"
		w:addBot(peers[i], { spot = "Ratchet" })
	end
	-- 10 minutes of chatter: every peer whispers (an ask, then Qs) every 5 s
	for step = 1, 120 do
		for i, p in ipairs(peers) do
			if step == 1 then
				w:inject(p, "F~1~H~?~ratchet:gadgetzan", "WHISPER", r)
			else
				w:inject(p, "Q~1~1", "WHISPER", r)
			end
		end
		w:advance(5)
	end
	local all = sent(w, TESTCHAR, "^F~")
	ok(#all >= 8, "it spread: " .. #all)
	local per = {}
	for _, e in ipairs(all) do
		per[e.target] = per[e.target] or {}
		table.insert(per[e.target], e.at)
		ok(#e.text <= 250, "fits")
	end
	for p, times in pairs(per) do
		ok(#times <= 10, p .. ": at most 10 a session")
		for i = 2, #times do ok(times[i] - times[i - 1] >= 60 - 1e-6, p .. ": a minute apart (" .. times[i - 1] .. ", " .. times[i] .. ")") end
	end
	for i = 1, #all do
		local n = 0
		for j = i, #all do if all[j].at - all[i].at < 60 then n = n + 1 end end
		ok(n <= 4, "at most 4 in any minute (" .. n .. " from " .. all[i].at .. ")")
	end
	ok(#all <= 4 * 11, "at most 4 a minute over 10 min: " .. #all)
	clean(w)
end)

test("r6 flights: ride messages are never delayed by flight-price traffic (lowest outbox priority)", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	local W = r.W
	w:openTaxi(r, RATCHET)
	local peers = { "Peer Ason", "Peer Bson", "Peer Cson" }
	for _, p in ipairs(peers) do w:addBot(p, { spot = "Ratchet" }) end
	w:advance(10)
	-- three Fs go to the outbox at once, then a burst of ride messages
	for _, p in ipairs(peers) do w:inject(p, "F~1~H~?~ratchet:orgrimmar", "WHISPER", r) end
	local t0 = w.time
	for i = 1, 3 do W.SendTo(BOB, "T", "ride" .. i, 5) end
	local rides = sent(w, TESTCHAR, "^T~1~ride")
	eq(#rides, 3, "every ride message went at once")
	for _, e in ipairs(rides) do eq(e.at, t0, "not delayed") end
	-- the outbox drained by ride messages: a waiting F never goes before the next ride message
	for i = 4, 7 do W.SendTo(BOB, "T", "ride" .. i, 5) end
	local fBefore = #sent(w, TESTCHAR, "^F~")
	W.SendTo(BOB, "A", "abcdef", 5, 1)
	eq(#sent(w, TESTCHAR, "^F~"), fBefore, "no F while ride messages wait")
	w:advance(30)
	local log = {}
	for _, e in ipairs(w.addonLog) do if e.from == TESTCHAR and e.at > t0 then log[#log + 1] = e.text:sub(1, 1) end end
	ok(table.concat(log):find("^TTTTAF+$") ~= nil, "ride messages first, Fs after: " .. table.concat(log, ","))
	eq(#sent(w, TESTCHAR, "^F~"), 3, "the Fs went once the outbox was idle")
	clean(w)
end)

---------------------------------------------------------------------------
-- Old clients
---------------------------------------------------------------------------

test("r6 flights: a 1.x client drops F; W.PROTO stays 1", function()
	local w = H.NewWorld({})
	local old = rider(w, BOB, { addonDirs = { Wuber = H.ADDONS.Wuber1 }, roundOne = true })
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	eq(r.W.PROTO, 1)
	w:inject(TESTCHAR, "F~1~H~ratchet:gadgetzan:2345:0:", "WHISPER", old)
	w:inject(TESTCHAR, "F~1~H~?~ratchet:gadgetzan", "WHISPER", old)
	w:advance(5)
	eq(#sent(w, BOB, "."), #sent(w, BOB, "^[DXQ]"), "the old client answers nothing to F")
	clean(w)
end)

---------------------------------------------------------------------------
-- Enhanced Flight Map's measured flight times
---------------------------------------------------------------------------

test("r6 flights: own measured times (2.2's EFM times migrated) are shown as time saved; Enhanced Flight Map is never read", function()
	if not T.HAVE_UI then return end
	local w = H.NewWorld({})
	local at = H.EPOCH + 900
	local r = rider(w, TESTCHAR, { spot = "Ratchet", prepare = function(env)
		taxiMap(env)
		env.EnhancedFlightMapDB = { flightTimes = { ["n80>n40"] = 100, ["n80>n23"] = 50 } } -- never read
	end, saved = { Wuber = { flightNodes = { H = { [80] = "ratchet", [40] = "gadgetzan", [23] = "orgrimmar", [25] = "crossroads" } },
		flights = {
			["H|ratchet|gadgetzan"] = { t = 300, tat = at, tsrc = "own" },
			["H|orgrimmar|ratchet"] = { t = 260, tat = at, tsrc = "efm" }, -- 2.2's EFM time: kept, as own
			["H|crossroads|ratchet"] = { t = 4, tat = at, tsrc = "own" },  -- under 5 s: ignored
		} } } })
	settle(w)
	local W = r.W
	eq(W.FlightTime(nil, "Gadgetzan"), 300, "the measured flight")
	eq(select(2, W.FlightTime(nil, "Gadgetzan")), "own")
	eq(W.FlightTime("Orgrimmar", "Ratchet"), 260, "2.2's EFM time")
	eq(select(2, W.FlightTime("Orgrimmar", "Ratchet")), "own", "migrated to own")
	eq(W.db.flightsV, 3)
	eq(select(2, W.FlightTime(nil, "Orgrimmar")), "est", "EFM's 50 s is never read: the estimate")
	eq(select(2, W.FlightTime("Crossroads", "Ratchet")), "est", "under 5 s: not a time")
	eq(select(3, W.FlightCost(nil, "Gadgetzan")), "table", "only the game's list price")
	local secs, _, measured = W.TravelSaved("Gadgetzan")
	eq(secs, 360, "60 s to the flight master + the measured 300 s")
	eq(measured, true)
	-- the Confirm screen's time-saved line uses it
	r.W.drivers[key(ANITA)] = { name = ANITA, key = key(ANITA), dest = "Gadgetzan", price = 5000, state = "open", team = 3,
		service = "Anita's Rides", heard = r.env.GetTime() }
	T.openConfirm(r, key(ANITA))
	ok(has(r, "6 min faster", true) and has(r, "Summon wins by 6 min", true), "measured (round 9, S1: the verdict's number): " .. texts(r))
	-- node ids come from the flight map (the other side's node is left out)
	r.W.db.flightNodes = nil
	w:openTaxi(r, RATCHET)
	eq(r.W.db.flightNodes.H[80], "ratchet")
	eq(r.W.db.flightNodes.H[40], "gadgetzan")
	eq(r.W.db.flightNodes.H[39], nil, "the Alliance's node")
	clean(w)
end)

test("r6 flights: no Enhanced Flight Map, no C_TaxiMap: time saved is the speed model, unchanged", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	local W = r.W
	eq(W.ReadEFM, nil, "2.3.0: Enhanced Flight Map is not read")
	eq(W.LearnFlightNodes(), 0, "no node ids")
	eq(select(2, W.FlightTime(nil, "Gadgetzan")), "est", "only the estimate")
	local secs, how, measured = W.TravelSaved("Gadgetzan")
	ok(secs and secs > 0, "the model's time")
	eq(how, "same continent", "the estimate is used only once the player's own flights calibrated it")
	eq(measured, nil, "not measured")
	-- EFM data changes nothing
	r.env.EnhancedFlightMapDB = { flightTimes = "nope" }
	r.env.EnhancedFlightMapDB = "nope"
	eq((W.TravelSaved("Gadgetzan")), secs, "unchanged")
	clean(w)
end)

---------------------------------------------------------------------------
-- The game's own flight table (W.TAXI, tools/build-flights.js): full list prices first
---------------------------------------------------------------------------

local function leg(W, a, b)
	local L = W.TAXI.legs
	for i = 1, #L - 2, 3 do if L[i] == a and L[i + 1] == b then return L[i + 2] end end
	return nil
end

test("r6 flights: table: Undercity > Tarren Mill 330; a two-leg route sums; Thunder Bluff > Moonglade 1710", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Undercity" })
	settle(w)
	local W = r.W
	local c, ex, src = W.FlightCost(nil, "Tarren Mill")
	eq(c, 330, "Undercity > Tarren Mill") eq(ex, 1) eq(src, "table")
	ok(W.FlightInfo("Tarren Mill") and W.FlightInfo("Tarren Mill").cost == 330, "shown as a real price")
	-- Ratchet > Gadgetzan (Horde): Ratchet > Crossroads + Crossroads > Gadgetzan
	eq(leg(W, 80, 25), 110) eq(leg(W, 25, 40), 730)
	eq(W.FlightCost("Ratchet", "Gadgetzan"), 840, "two legs, summed")
	-- the author's check: Thunder Bluff > Orgrimmar 50 + Orgrimmar > Bloodvenom Post 830 + Bloodvenom Post > Moonglade 830
	eq(W.FlightCost("Thunder Bluff", "Nighthaven"), 1710, "Thunder Bluff > Moonglade")
	eq(W.FLY.Cheapest({ 22 }, { 69 }, "H"), 1710)
	clean(w)
end)

test("r6 flights: table: the full list price beats a (maybe discounted) price seen at a flight master", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	local W = r.W
	w:openTaxi(r, { { name = "Ratchet, The Barrens", type = "CURRENT", cost = 0 },
		{ name = "Gadgetzan, Tanaris", type = "REACHABLE", cost = 672 } }) -- 20% off (Exalted)
	eq(W.FlightSeen(nil, "Gadgetzan"), 672, "seen and kept")
	local c, _, src = W.FlightCost(nil, "Gadgetzan")
	eq(c, 840, "never lower than the table") eq(src, "table")
	ok(W.FlightMerge("H", "ratchet", "orgrimmar", 9000, nil, r.env.time(), "p"), "a shared price")
	eq(select(3, W.FlightCost(nil, "Orgrimmar")), "table", "the table still first")
	clean(w)
end)

test("r6 flights: table: each side's own flight points only; junk nodes are not in the table", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	local W = r.W
	eq(W.FLY.Cheapest({ 80 }, { 32 }, "A"), 630, "Ratchet > Theramore for the Alliance")
	eq(W.FLY.Cheapest({ 80 }, { 32 }, "H"), false, "Theramore's flight point is the Alliance's")
	eq(W.FLY.Cheapest({ 22 }, { 2 }, "H"), false, "Stormwind: never for the Horde")
	eq(W.FLY.Cheapest({ 80 }, { 39 }, "H"), false, "the Alliance's Gadgetzan node")
	for id, n in pairs(W.TAXI.nodes) do
		local name = n[1]
		ok(not (name:find("^Quest Path") or name:find("^Transport") or name:find("^Generic") or name:find("^zzOLD")
			or name:find("^Programmer Isle")), "junk node " .. id .. " " .. name)
		ok(n[5] == "H" or n[5] == "A" or n[5] == "HA", "a side: " .. id)
	end
	for _, id in ipairs({ 3, 24, 34, 35, 36, 47, 63, 62, 2913, 3206, 3260 }) do eq(W.TAXI.nodes[id], nil, "dropped: " .. id) end
	local L = W.TAXI.legs
	for i = 1, #L - 2, 3 do
		ok(W.TAXI.nodes[L[i]] and W.TAXI.nodes[L[i + 1]], "a leg between kept nodes: " .. L[i] .. ">" .. L[i + 1])
	end
	-- every summon town and city has a flight point of its own (dungeons use the nearest)
	local missing = {}
	for _, p in ipairs(W.PLACES) do
		if (p.kind == "town" or p.kind == "city") and not W.FLY.TaxiData().at[W.NormPlace(p.name)] then missing[#missing + 1] = p.name end
	end
	eq(table.concat(missing, ", "), "", "towns and cities without a flight point")
	clean(w)
end)

test("r6 flights: table: Undercity > Ratchet by zeppelin and flights; an Alliance rider over the Menethil boat", function()
	local w = H.NewWorld({})
	local h = rider(w, TESTCHAR, { spot = "Undercity" })
	local a = rider(w, BOB, { spot = "Ironforge", faction = "Alliance" })
	settle(w)
	local c, _, src, via = h.W.FlightCost(nil, "Ratchet")
	eq(src, "table")
	eq(via, "boat", "a zeppelin on the way")
	eq(c, h.W.FLY.Cheapest({ 23 }, { 80 }, "H"), "the zeppelin is free: Orgrimmar > Ratchet's flights")
	ok(c > 0, "flights to pay for")
	eq(h.W.FlightInfo("Ratchet").via, "boat")
	-- Ironforge > Menethil Harbor (flight) > Theramore (boat)
	c, _, src, via = a.W.FlightCost(nil, "Theramore")
	eq(src, "table") eq(via, "boat")
	eq(c, a.W.FLY.Cheapest({ 6 }, { 7 }, "A"), "the flight to Menethil, then the free boat")
	ok(c > 0)
	eq(h.W.FLY.Cheapest({ 11 }, { 32 }, "H"), false, "no Alliance boat for the Horde")
	clean(w)
end)

test("r6 flights: table: a destination without a flight point uses the nearest one; no connection at all: hidden", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	local W = r.W
	-- Zul'Farrak's entrance in world coordinates (Tanaris, Kalimdor): the nearest Horde flight
	-- point is Gadgetzan's
	local orig = W.PlaceWorld
	W.PlaceWorld = function(p)
		if p and p.name == "Zul'Farrak" then return 1, -6800, -2900 end
		return orig(p)
	end
	eq(W.FlightCost(nil, "Zul'Farrak"), 840, "Ratchet > Gadgetzan, the nearest flight point")
	-- the rider out in the Barrens: the nearest flight point to where they stand
	w:move(TESTCHAR, "Barrens")
	local wp = W.WorldPos
	W.WorldPos = function(mapID, x, y)
		if mapID == 1413 then return 1, -500, -2650 end -- near the Crossroads
		return wp(mapID, x, y)
	end
	eq(W.FlightCost(nil, "Gadgetzan"), 730, "from the Crossroads, the nearest flight point")
	-- a position that can't be read: nothing connects, the line stays hidden
	W.WorldPos = function() return nil end
	eq(W.FlightCost(nil, "Gadgetzan"), nil, "hidden")
	eq(W.FlightInfo("Gadgetzan"), nil)
	W.WorldPos, W.PlaceWorld = wp, orig
	clean(w)
end)
