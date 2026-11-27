-- Wuber 2.1 (round five, SPEC4.md) tests: agent A's part (engine + net). Loaded by run.lua with
-- the same helpers as round four. Test names start "r5 engine:".
--
-- SPEC4 5.2 scenarios 1-6 from the engine's side (roles, summoners, payee, stations and
-- routing, the WUBERT budget, raid summons), plus the harness's raid support and the wire.

local T = ...
local H, test, eq, ok, count, list = T.H, T.test, T.eq, T.ok, T.count, T.list
local clean, settle = T.clean, T.settle

local SPOT = "Undercity"
local MIA, BEA, PIA, CAL = "Mia Stone", "Bea Jones", "Pia Rose", "Cal Brown"
local ANA = "Ana Smith"

test("r5 engine: the file loads", function()
	ok(H ~= nil, "the harness")
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function DRof(c) return c.W.Drive end
local function customer(c, name) return c.W.Drive.customers[key(name)] end
local function state(c, name)
	local x = customer(c, name)
	return x and x.state or nil
end

-- saved data: the runner (captain) with its crew; extra = more W.Char() keys
local function runnerSaved(me, crew, extra)
	local ch = { crew = crew, captain = "", wizard = true }
	for k, v in pairs(extra or {}) do ch[k] = v end
	return { Wuber = { chars = { [key(me)] = ch } } }
end

-- a member of `captain`'s crew; all = every crew name { name, role }
local function memberSaved(me, captain, all)
	local crew = {}
	for _, m in ipairs(all) do
		if m.name ~= me then crew[#crew + 1] = { name = m.name, role = m.role, app = m.app ~= false } end
	end
	return { Wuber = { chars = { [key(me)] = { crew = crew, captain = captain, wizard = true } } } }
end

local function press(c)
	local b = c.env.WuberDriveButton
	ok(b, c.player.name .. ": no WuberDriveButton")
	ok(H.visible(b), c.player.name .. ": the big button is hidden")
	return c:click(b)
end

-- WUBERT messages of a kind (from a player)
local function wubert(w, kind, from)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.result == 0 and (not kind or e.text:match("^([^~]*)") == kind)
			and (not from or e.from == from) then
			out[#out + 1] = e
		end
	end
	return out
end

local function split(text)
	local out = {}
	for f in (text .. "~"):gmatch("(.-)~") do out[#out + 1] = f end
	return out
end

---------------------------------------------------------------------------
-- The harness: raids
---------------------------------------------------------------------------

test("r5 engine: harness raids - assist, raid chat, unit tokens, a bot's cast seen on the raid's windows", function()
	local w = T.newWorld()
	local a = w:addClient(ANA, { spot = SPOT, class = "DRUID" })
	local b = w:addClient(BEA, { spot = SPOT, class = "WARLOCK" })
	local names = { ANA, BEA }
	for i = 1, 10 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = i == 3 and "WARLOCK" or "WARRIOR", shards = 5 })
		names[#names + 1] = n
	end
	w:group(names)
	w:advance(1)
	ok(a.env.IsInRaid(), "a raid")
	eq(a.env.GetNumGroupMembers(), 12)
	eq(a.env.UnitName("raid12"), "Raider")
	eq(b.env.UnitIsGroupAssistant("player"), false)
	w:setAssist(BEA, true)
	eq(b.env.UnitIsGroupAssistant("player"), true, "assist")
	eq(b.env.UnitIsRaidOfficer("player"), true)
	eq(select(2, a.env.GetRaidRosterInfo(2)), 1, "rank 1 = assist")
	eq(select(2, a.env.GetRaidRosterInfo(1)), 2, "rank 2 = leader")
	-- raid chat from a bot reaches every window, from the leader as RAID_LEADER
	local heard = {}
	b.W.On("CHAT_MSG_RAID", function(text, sender) heard[#heard + 1] = text .. "|" .. tostring(sender) end)
	w:groupSay("Raider Rb", "123")
	eq(#heard, 1)
	ok(heard[1]:find("^123|Raider Rb"), heard[1])
	-- a bot Warlock's ritual: the others see raidN's UNIT_SPELLCAST_CHANNEL_START, and its target
	local seen = {}
	b.W.On("UNIT_SPELLCAST_CHANNEL_START", function(unit) seen[#seen + 1] = unit end)
	w:move("Raider Rc", SPOT)
	w:botCast("Raider Rc", "Raider Rd")
	w:advance(1)
	eq(seen[1], "raid5", "the caster's raid token")
	eq(b.env.UnitName("raid5target"), "Raider", "raid5's target")
	ok(w:clickPortal(a), "clicks")
	ok(w:clickPortal(b), "clicks")
	w:advance(10)
	eq(w:player("Raider Rd").zone, "Undercity", "summoned by a bot")
	clean(w)
end)

---------------------------------------------------------------------------
-- Scenario 1 (engine): a Mage runs it, Bea (Warlock, Wuber) summons, Pia (Priest) clicks
---------------------------------------------------------------------------

local function mageCrew(opts)
	opts = opts or {}
	local w = T.newWorld()
	local beaApp = opts.beaApp ~= false
	local all = { { name = MIA, role = "helper" }, { name = BEA, role = "lock", app = beaApp }, { name = PIA, role = "helper" } }
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE", saved = runnerSaved(MIA, {
		{ name = BEA, role = "lock", app = beaApp }, { name = PIA, role = "helper", app = true } },
		{ runner = true, summoners = opts.summoners or { BEA } }) })
	local bea
	if beaApp then
		bea = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", saved = memberSaved(BEA, MIA, all) })
	else
		w:addBot(BEA, { spot = SPOT, class = "WARLOCK", shards = 10 })
		w:player(BEA).knowsRitual = true
	end
	local pia = w:addClient(PIA, { spot = SPOT, class = "PRIEST", saved = memberSaved(PIA, MIA, all) })
	w:group({ MIA, BEA, PIA })
	settle(w)
	return w, mia, bea, pia
end

test("r5 engine: scenario 1 - a Mage runner: role, open, the network driver, 'Summoned by Bea', and the rider pays Bea", function()
	local w, mia, bea, pia = mageCrew()
	local DM, DB = DRof(mia), DRof(bea)
	eq(DM.Role(), "driver", "a Mage who runs the service drives")
	ok(DM.IsRunner(), "the runner")
	eq(DRof(pia).Role(), "helper")
	eq(DB.Role(), "driver")
	eq(list(DM.Summoners()), key(BEA), "Bea summons")
	eq(list(DB.Summoners()), key(BEA), "Bea's window knows (SVC)")
	ok(DM.SetOpen(true), "the Mage opens")
	w:advance(3)
	ok(DM.NetDriver(), "the Mage's window is on the network")
	ok(not DB.NetDriver(), "Bea's is not")
	local D = T.msgs(w, "D", MIA, "CHANNEL")
	ok(#D >= 1, "the Mage beacons")
	eq(split(D[#D].text)[19], BEA, "beacon field 17: the summoner")
	eq(#T.msgs(w, "D", BEA, "CHANNEL"), 0, "Bea never beacons")
	-- a Wuber rider sees "Summoned by Bea"
	local dan = T.rider(w, "Dan Miller", { spot = "Orgrimmar" })
	settle(w)
	local d = dan.W.drivers[key(MIA)]
	ok(d, "the rider lists the Mage")
	eq(d.summoner, BEA, "Summoned by Bea")
	dan.W.RequestRide(key(MIA))
	w:advance(4)
	eq(T.rideState(dan), "ingroup", "invited by the Mage's window")
	eq(dan.W.ride.summoner, BEA)
	eq(DM.Payee("Dan Miller"), key(BEA), "the payee before the cast: who will cast")
	eq(DM.NextCaster("Dan Miller"), key(BEA))
	local mayB, turn = DB.MayCast()
	ok(mayB, "Bea casts")
	eq(turn, key(BEA))
	local mayM, turnM = DM.MayCast()
	ok(not mayM, "the Mage never casts")
	eq(turnM, key(BEA))
	-- Bea's button summons; the Mage and Pia click
	for _ = 1, 3 do
		if state(bea, "Dan Miller") == "summoning" then break end
		press(bea)
		w:advance(2)
	end
	eq(state(mia, "Dan Miller"), "summoning", "CAST reached the runner")
	eq(customer(mia, "Dan Miller").caster, key(BEA), "cast by Bea")
	ok(w:clickPortal(mia), "the Mage clicks")
	ok(w:clickPortal(pia), "Pia clicks")
	w:advance(1)
	local p = w:player("Dan Miller")
	ok(p.pendingSummon, "Dan has the summon")
	w:arrive(p, p.pendingSummon) -- (accepts it)
	w:advance(5)
	eq(dan.W.ride.payee, BEA, "the rider's app: pay Bea (S payee)")
	eq(dan.W.ride.payto, "Bea")
	eq(state(mia, "Dan Miller"), "arrived")
	eq(DM.Payee("Dan Miller"), key(BEA))
	ok(DM.PayeeHasApp("Dan Miller"), "Bea has Wuber: her trade is read")
	clean(w)
end)

---------------------------------------------------------------------------
-- Scenario 2 (engine): Bea has no Wuber
---------------------------------------------------------------------------

test("r5 engine: scenario 2 - a summoner without Wuber: cast order, payee blind, no auto-block when the rider leaves", function()
	local w, mia, _, pia = mageCrew({ beaApp = false })
	local DM = DRof(mia)
	ok(not DM.SummonerHasApp(key(BEA)), "Bea has no Wuber")
	eq(list(DM.CastOrder()), key(BEA), "Bea in the cast order")
	ok(DM.CanCast(key(BEA)), "in the group is enough")
	ok(DM.SetOpen(true))
	-- the crew list carries her as S: never a rider on Pia's window
	w:advance(3)
	local m = DRof(pia).CrewEntry(key(BEA))
	ok(m, "Pia knows Bea")
	eq(m.role, "lock")
	eq(m.app, false)
	ok(DRof(pia).NeverRider(key(BEA)))
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:botWhisper("Dan Miller", mia, "summon pls")
	w:advance(4)
	eq(state(mia, "Dan Miller"), "joined")
	eq(DM.Payee("Dan Miller"), key(BEA))
	ok(not DM.PayeeHasApp("Dan Miller"), "nobody can see Bea's trade")
	-- the runner's window saw Bea's channel (B's watch, or by hand here): CAST name, Bea
	DM.Do("CAST", "Dan Miller", key(BEA))
	w:advance(1)
	eq(customer(mia, "Dan Miller").caster, key(BEA), "c.caster = the summoner without Wuber")
	eq(customer(pia, "Dan Miller").caster, key(BEA), "the same on Pia's window")
	DM.Do("END", "Dan Miller", 1, key(BEA))
	w:player("Dan Miller").zone = SPOT -- (lands)
	w:move("Dan Miller", SPOT)
	w:advance(3)
	eq(state(mia, "Dan Miller"), "arrived")
	-- leaves without anyone seeing a trade: told, never blocked
	w:leave("Dan Miller")
	w:advance(15)
	eq(DM.BlockEntry(key("Dan Miller")), nil, "not blocked: nobody could watch them pay")
	eq(DRof(pia).BlockEntry(key("Dan Miller")), nil)
	local alerts = 0
	for _, f in ipairs(mia.fired) do
		if f.name == "DRIVE_ALERT" and tostring(f.args[1]):find("left without paying", 1, true) then alerts = alerts + 1 end
	end
	eq(alerts, 1, "the runner is told once")
	clean(w)
end)

---------------------------------------------------------------------------
-- Scenario 3: a non-Warlock runner with no summoner
---------------------------------------------------------------------------

test("r5 engine: scenario 3 - a non-Warlock runner with nobody to summon: red, not open, not on the network", function()
	local w = T.newWorld()
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE" })
	settle(w)
	local DM = DRof(mia)
	eq(DM.Role(), nil, "a Mage who never set up driving")
	DM.SetRunner(true)
	eq(DM.Role(), "driver", "set up as a runner")
	local red
	for _, line in ipairs(DM.Readiness()) do
		if line.ok == false and line.text == "Choose who summons" then red = line end
	end
	ok(red, "Readiness: Choose who summons")
	ok(red.fix and red.fix[1] == "Choose", "with a fix")
	ok(not DM.Ready())
	local okOpen, why = DM.SetOpen(true)
	eq(okOpen, false)
	eq(why, "summoner")
	-- even if the flag were on, nothing is beaconed
	mia.W.Char().drive = true
	mia.W.Fire("SETTINGS", "drive")
	w:advance(20)
	eq(DM.NetBeacon(), nil)
	eq(#T.msgs(w, "D", MIA, "CHANNEL"), 0, "no beacon")
	clean(w)
end)

---------------------------------------------------------------------------
-- Scenario 4: a raid of 12, two stations
---------------------------------------------------------------------------

local UCH1, UCH2, OGH1, OGH2 = "Una Helper", "Uli Helper", "Ola Helper", "Oto Helper"

local function twoStations()
	local w = T.newWorld()
	local all = {
		{ name = ANA, role = "lock" }, { name = BEA, role = "lock" },
		{ name = UCH1, role = "helper" }, { name = UCH2, role = "helper" },
		{ name = OGH1, role = "helper" }, { name = OGH2, role = "helper" },
	}
	local crew = {}
	for i = 2, #all do crew[#crew + 1] = { name = all[i].name, role = all[i].role, app = true } end
	local c = {}
	c.ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK", saved = runnerSaved(ANA, crew) })
	c.bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK", saved = memberSaved(BEA, ANA, all) })
	c.u1 = w:addClient(UCH1, { spot = "Undercity", class = "PRIEST", saved = memberSaved(UCH1, ANA, all) })
	c.u2 = w:addClient(UCH2, { spot = "Undercity", class = "MAGE", saved = memberSaved(UCH2, ANA, all) })
	c.o1 = w:addClient(OGH1, { spot = "Orgrimmar", class = "PRIEST", saved = memberSaved(OGH1, ANA, all) })
	c.o2 = w:addClient(OGH2, { spot = "Orgrimmar", class = "MAGE", saved = memberSaved(OGH2, ANA, all) })
	w:group({ ANA, BEA, UCH1, UCH2, OGH1, OGH2 })
	settle(w)
	return w, c
end

test("r5 engine: scenario 4 - two stations: routed by place, each lock plans its own, arrival by map, 'Where to?', refused politely", function()
	local w, c = twoStations()
	local DA, DB = DRof(c.ana), DRof(c.bea)
	ok(c.ana.env.IsInRaid(), "six windows: a raid")
	local st = DA.Stations()
	eq(#st, 2, "two stations")
	eq(st[1].place, "Undercity", "the runner's first")
	eq(st[2].place, "Orgrimmar")
	eq(#st[1].helpers, 2)
	eq(#st[2].helpers, 2)
	ok(st[1].ready and st[2].ready, "both ready")
	ok(DA.MultiStation())
	eq(DA.MaxGroup(), 20, "two stations: 20")
	eq(DA.MyStation(), "Undercity")
	eq(DB.MyStation(), "Orgrimmar")
	ok(DA.SetOpen(true))
	w:advance(2)
	ok(DB.IsOpen(), "Bea's window follows")
	-- riders
	local function asks(name, text)
		w:addBot(name, { spot = "Thunder Bluff" })
		w:botWhisper(name, c.ana, text)
	end
	asks("Dan Miller", "summon to org pls")
	asks("Eve Long", "summon to undercity please")
	asks("Fay Moon", "summon pls")
	asks("Gus Pike", "can i get a summon to stormwind")
	w:advance(1)
	asks("Hal Reed", "summon to orgrimmar")
	asks("Ivy Hart", "uc summon pls")
	w:advance(30)
	eq(customer(c.ana, "Dan Miller").station, "Orgrimmar", "routed to Orgrimmar")
	eq(customer(c.ana, "Eve Long").station, "Undercity")
	eq(customer(c.ana, "Hal Reed").station, "Orgrimmar")
	eq(customer(c.ana, "Ivy Hart").station, "Undercity")
	-- no place: the runner's station, and asked once
	eq(customer(c.ana, "Fay Moon").station, "Undercity")
	ok(customer(c.ana, "Fay Moon").askWhere, "Where to?")
	-- a place nobody summons to: not queued, told where we do
	local gus = customer(c.ana, "Gus Pike")
	eq(gus.state, "lead", "not queued")
	ok(gus.elsewhere, "told 'We summon to ...'")
	eq(DA.StationList(), "Undercity, Orgrimmar")
	-- every window knows the station
	for _, name in ipairs({ "Dan Miller", "Eve Long", "Hal Reed", "Ivy Hart" }) do
		eq(state(c.ana, name), "joined", name .. " joined")
		eq(customer(c.bea, name) and customer(c.bea, name).station, customer(c.ana, name).station, name .. " on Bea's window")
		eq(customer(c.o1, name) and customer(c.o1, name).station, customer(c.ana, name).station, name .. " on Ola's window")
	end
	-- each lock's button only plans its own station
	ok(DB.ForMyStation(customer(c.bea, "Dan Miller")), "Bea plans Dan")
	ok(not DB.ForMyStation(customer(c.bea, "Eve Long")), "not Eve")
	ok(DA.ForMyStation(customer(c.ana, "Eve Long")), "Ana plans Eve")
	ok(not DA.ForMyStation(customer(c.ana, "Hal Reed")), "not Hal")
	local nextB = DB.NextSummon(DB.ButtonStation())
	ok(nextB and nextB.station == "Orgrimmar", "Bea's next is an Orgrimmar rider: " .. tostring(nextB and nextB.name))
	local nextA = DA.NextSummon(DA.ButtonStation())
	ok(nextA and nextA.station == "Undercity", "Ana's next is an Undercity rider: " .. tostring(nextA and nextA.name))
	local mayA = DA.MayCast()
	local mayB = DB.MayCast()
	ok(mayA and mayB, "each lock casts at its own station")
	eq(DA.NextCaster("Dan Miller"), key(BEA), "Dan pays Bea")
	eq(DA.NextCaster("Eve Long"), key(ANA))
	-- the answer to "Where to?" moves Fay to Orgrimmar everywhere
	w:botWhisper("Fay Moon", c.ana, "orgrimmar please")
	w:advance(3)
	eq(customer(c.ana, "Fay Moon").station, "Orgrimmar")
	eq(customer(c.bea, "Fay Moon").station, "Orgrimmar", "Bea's window too")
	-- arrived = the map of the station that summons them (not where the reader stands)
	-- (d4 g) summoned once: a rider who walks up with no summon now leaves the list
	customer(c.ana, "Dan Miller").tries, customer(c.bea, "Dan Miller").tries = 1, 1
	w:move("Dan Miller", "Orgrimmar")
	w:advance(3)
	eq(state(c.ana, "Dan Miller"), "arrived", "on Ana's window (in Undercity)")
	eq(state(c.bea, "Dan Miller"), "arrived")
	w:move("Eve Long", "Orgrimmar")
	w:advance(3)
	eq(state(c.ana, "Eve Long"), "joined", "Eve in Orgrimmar is not at her station")
	-- the portal call only at the station of the cast
	local function portalCalls(cl)
		local n = 0
		for _, f in ipairs(cl.fired) do if f.name == "DRIVE_ALERT" and f.args[2] == "portal" then n = n + 1 end end
		return n
	end
	local u0, o0 = portalCalls(c.u1), portalCalls(c.o1)
	DB.Do("CAST", "Hal Reed")
	w:advance(1)
	eq(portalCalls(c.o1) - o0, 1, "Orgrimmar's helper is called")
	eq(portalCalls(c.u1) - u0, 0, "Undercity's helper is not")
	clean(w)
end)

test("r5 engine: stations - one switched off is not offered; a Wuber request for the other station is taken", function()
	local w, c = twoStations()
	local DA = DRof(c.ana)
	ok(DA.SetOpen(true))
	ok(DA.SetStation("Orgrimmar", false))
	w:advance(2)
	ok(not DA.MultiStation(), "one open station left")
	local st = DRof(c.bea).Stations()
	eq(st[2].open, false, "Bea's window: Orgrimmar off (CFG)")
	ok(DA.SetStation("Orgrimmar", true))
	w:advance(2)
	ok(DRof(c.bea).MultiStation(), "on again everywhere")
	-- a Wuber rider asking for Orgrimmar (not the beacon's place) is taken there
	local dan = T.rider(w, "Dan Miller", { spot = "Thunder Bluff" })
	settle(w)
	ok(dan.W.drivers[key(ANA)], "the rider lists Ana")
	local DR = c.ana.W.Drive
	DR.ENGINE.onRequest({ id = "r1", buyer = "Dan Miller", dest = "Orgrimmar", price = 5000 })
	w:advance(3)
	eq(customer(c.ana, "Dan Miller") and customer(c.ana, "Dan Miller").station, "Orgrimmar")
	clean(w)
end)

---------------------------------------------------------------------------
-- Scenario 5: the WUBERT budget, 8 crew windows in a raid, 10 minutes
---------------------------------------------------------------------------

test("r5 engine: scenario 5 - 8 crew windows in a raid for 10 minutes: no window over the WUBERT allowance", function()
	local w = T.newWorld()
	local names = { ANA, BEA, CAL, "Dee Lock", "Eli Help", "Fin Help", "Gil Help", "Hux Help" }
	local all = {}
	for i, n in ipairs(names) do all[i] = { name = n, role = i <= 4 and "lock" or "helper" } end
	local crew = {}
	for i = 2, #all do crew[#crew + 1] = { name = all[i].name, role = all[i].role, app = true } end
	local cs = {}
	cs[1] = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = runnerSaved(ANA, crew) })
	for i = 2, #names do
		cs[i] = w:addClient(names[i], { spot = i % 2 == 0 and SPOT or "Orgrimmar", class = i <= 4 and "WARLOCK" or "PRIEST",
			saved = memberSaved(names[i], ANA, all) })
	end
	w:group(names)
	w:advance(2)
	DRof(cs[1]).SetOpen(true)
	-- traffic: riders ask, the crew changes things now and then
	for i = 1, 6 do
		w:addBot("Rider R" .. string.char(96 + i), { spot = "Thunder Bluff" })
	end
	local t0 = w.time
	for minute = 1, 10 do
		w:botWhisper("Rider R" .. string.char(96 + (minute % 6) + 1), cs[1], "summon to org pls")
		if minute == 3 then DRof(cs[1]).SetPrice(6000) end
		if minute == 5 then DRof(cs[2]).SetPaused(true) end
		if minute == 6 then DRof(cs[1]).SetPaused(false) end
		w:advance(60)
	end
	local span = w.time - t0
	-- per window: never over the per-prefix allowance (10, +1/s), and at most 1 a second on average
	for _, c in ipairs(cs) do
		eq((c.throttledBy or {}).WUBERT, nil, c.player.name .. ": WUBERT throttled by the game")
		local sends = {}
		for _, e in ipairs(w.addonLog) do
			if e.prefix == "WUBERT" and e.from == c.player.name and e.chatType ~= "WHISPER" and e.at >= t0 then sends[#sends + 1] = e.at end
		end
		local tokens, last = 10, t0
		for _, at in ipairs(sends) do
			tokens = math.min(10, tokens + (at - last))
			last = at
			tokens = tokens - 1
			ok(tokens >= 0, c.player.name .. ": over the allowance at " .. at)
		end
		ok(#sends <= span + 10, c.player.name .. ": " .. #sends .. " sends in " .. span .. " s")
	end
	-- HI every 20 s with 8 crew windows (not 15)
	local his = 0
	for _, e in ipairs(wubert(w, "HI", BEA)) do if e.at >= t0 then his = his + 1 end end
	ok(his <= math.ceil(span / 20) + 4, "Bea's HI: " .. his .. " in " .. span .. " s")
	clean(w)
end)

---------------------------------------------------------------------------
-- Scenario 6: raid summons
---------------------------------------------------------------------------

local DRU = "Dru Oak"

-- A raid of 20 at Blackrock Mountain's entrance... the Druid (assist) runs raid summons; Cal
-- (Warlock, Wuber) and Bea (Warlock, no Wuber) summon from the spot.
local function raid20()
	local w = T.newWorld()
	local lead = "Lea Dorn"
	w:addBot(lead, { spot = "Blackrock Mountain", class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = "Blackrock Mountain", class = "DRUID" })
	local cal = w:addClient(CAL, { spot = "Blackrock Mountain", class = "WARLOCK" })
	w:addBot(BEA, { spot = "Blackrock Mountain", class = "WARLOCK", shards = 10 })
	w:player(BEA).knowsRitual = true
	local names = { lead, DRU, CAL, BEA }
	for i = 1, 16 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = i <= 8 and "Orgrimmar" or "Blackrock Mountain", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	settle(w)
	return w, dru, cal
end

local function rows(c)
	local out = {}
	for _, r in ipairs(c.W.Drive.RaidQueue()) do out[#out + 1] = r.name end
	return table.concat(out, ",")
end

test("r5 engine: scenario 6 - raid summons: a Druid assist runs it, two summoners, requests, drops, claims, no beacon", function()
	local w, dru, cal = raid20()
	local DD, DC = DRof(dru), DRof(cal)
	local invites0 = #w.invites
	ok(DD.CanRunRaid(), "assist may run it")
	ok(DD.SetMode("raid"))
	eq(DD.Role(), "driver", "the Druid runs raid summons")
	-- picks: Cal (Wuber) by the offer, Bea (no Wuber) as a plain summoner
	local locks = DD.RaidWarlocks()
	eq(#locks, 2, "the raid's Warlocks")
	ok(DD.RaidPick(CAL, true))
	w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true)
	w:advance(3)
	ok(DD.RaidPick(BEA, true))
	w:advance(1)
	eq(list(DD.Summoners()), key(CAL) .. "; " .. key(BEA), "picked in order")
	local okStart = DD.SetOpen(true)
	ok(okStart, "Start")
	w:advance(3)
	ok(DD.RaidOn())
	ok(DC.RaidOn(), "Cal's window follows (CFG)")
	eq(DC.Mode(), "raid")
	-- requests
	w:groupSay("Raider Ra", "123")
	w:groupSay("Raider Rb", "summ pls")
	w:groupSay("Raider Rc", "can someone summon me to the entrance please, thanks a lot")
	w:groupSay("Raider Rd", "inv")
	w:botWhisper("Raider Re", cal, "need summon")
	w:groupSay("Raider Rk", "123") -- already at the spot: dropped at once
	w:advance(3)
	eq(rows(dru), "Raider Ra,Raider Rb,Raider Re", "three asked (long lines and 'inv' ignored)")
	eq(rows(cal), rows(dru), "the same queue on Cal's window")
	ok(DD.raidRows[key("Raider Ra")] and DD.raidRows[key("Raider Rb")] and DD.raidRows[key("Raider Re")], "Ra, Rb, Re")
	-- nvm drops; never auto-queued: the + adds by hand
	w:groupSay("Raider Rb", "nvm")
	w:advance(2)
	eq(DD.raidRows[key("Raider Rb")], nil, "nvm drops")
	eq(DC.raidRows[key("Raider Rb")], nil)
	local notHere = DD.NotHere()
	ok(#notHere >= 5, "not here: " .. #notHere)
	ok(DD.RaidAdd("Raider Rf"), "+ by hand")
	w:advance(2)
	ok(DC.raidRows[key("Raider Rf")], "added on Cal's window")
	-- Move to top
	DD.RaidTop("Raider Rf")
	w:advance(1)
	eq(DC.RaidQueue()[1].key, key("Raider Rf"), "moved to top")
	-- claims: Cal claims Rf; the runner claims Ra for Bea; never the same raider
	local nextC = DC.RaidNext()
	ok(nextC, "Cal has a raider to summon")
	DC.Do("CAST", nextC.name)
	DD.Do("CAST", nextC.name, key(BEA)) -- a second claim on the same raider at once
	w:advance(1)
	eq(DD.raidRows[nextC.key].claimedBy, DC.raidRows[nextC.key].claimedBy, "both windows agree on one claimer")
	eq(DD.raidRows[nextC.key].claimedBy, key(BEA), "the lower key keeps it")
	-- Cal's button moves on to another raider
	local other = DC.RaidNext()
	ok(other and other.key ~= nextC.key, "Cal's next is another raider")
	DC.Do("CAST", other.name)
	w:advance(1)
	eq(DD.raidRows[other.key].claimedBy, key(CAL))
	ok(DD.raidRows[other.key].claimedBy ~= DD.raidRows[nextC.key].claimedBy, "two summoners, two raiders")
	-- a claim with no channel start is let go after 40 s
	w:advance(42)
	eq(DD.raidRows[nextC.key].state, "queued", "released")
	eq(DD.raidRows[nextC.key].claimedBy, nil)
	eq(DC.raidRows[nextC.key].claimedBy, nil, "on Cal's window too")
	-- a claim that channels holds; the raider arrives: off the list, counted
	DC.Do("CAST", "Raider Ra")
	DC.Do("CH", "Raider Ra")
	w:advance(45)
	eq(DD.raidRows[key("Raider Ra")].state, "summoning", "channel started: the claim holds")
	DC.Do("END", "Raider Ra", 1)
	w:advance(1)
	eq(DD.raidRows[key("Raider Ra")].state, "waiting")
	local done = 0
	for _, f in ipairs(dru.fired) do if f.name == "DRIVE_RAID_DONE" then done = done + 1 end end
	w:move("Raider Ra", "Blackrock Mountain")
	w:advance(2)
	eq(DD.raidRows[key("Raider Ra")], nil, "arrived: dropped")
	eq(DC.raidRows[key("Raider Ra")], nil)
	local done2 = 0
	for _, f in ipairs(dru.fired) do if f.name == "DRIVE_RAID_DONE" then done2 = done2 + 1 end end
	eq(done2 - done, 1, "DRIVE_RAID_DONE once")
	-- leaving the raid drops
	w:leave("Raider Re")
	w:advance(2)
	eq(DD.raidRows[key("Raider Re")], nil, "left the raid")
	-- no beacon, no invites, no riders, no trade logic
	eq(#T.msgs(w, "D", DRU, "CHANNEL"), 0, "the runner never beacons")
	eq(#T.msgs(w, "D", CAL, "CHANNEL"), 0, "nor the summoner")
	eq(DD.NetBeacon(), nil)
	eq(#w.invites, invites0, "no invites")
	eq(count(DD.customers), 0, "no riders")
	eq(count(DC.customers), 0)
	ok(not DD.Selling() and not DC.Selling(), "not selling")
	-- the runner loses assist: paused, told
	w:setAssist(DRU, false)
	w:advance(3)
	ok(DD.IsPaused(), "paused")
	ok(DC.IsPaused(), "Cal's window too")
	eq(DC.RaidNext(), nil, "no summon while paused")
	clean(w)
end)

test("r5 engine: raid summons - a raider's own Wuber sees the raid summons and asks with one click (RQ)", function()
	local w, dru, cal = raid20()
	local DD = DRof(dru)
	local ray = w:addClient("Ray Ash", { spot = "Orgrimmar", class = "ROGUE" })
	w:join(w:player("Lea Dorn"), w:player("Ray Ash"))
	w:advance(2)
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick(CAL, true))
	w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true)
	w:advance(2)
	ok(DD.SetOpen(true))
	w:advance(20)
	local here = ray.W.Drive.RaidHere()
	ok(here, "the raider's window sees raid summons")
	eq(here.runner, DRU)
	eq(here.queued, false)
	ok(ray.W.Drive.RaidAsk())
	w:advance(3)
	ok(DD.raidRows[key("Ray Ash")], "queued by the click")
	here = ray.W.Drive.RaidHere()
	eq(here.queued, true, "the raider sees they are queued")
	eq(here.position, 1)
	ray.W.Drive.RaidCancel()
	w:advance(3)
	eq(DD.raidRows[key("Ray Ash")], nil, "cancelled")
	-- raid -> sell stops raid summons
	ok(DD.SetMode("sell"))
	w:advance(3)
	ok(not DD.RaidOn())
	ok(not cal.W.Drive.RaidOn(), "Cal's window too")
	clean(w)
end)

test("r5 engine: raid words - requests, cancels, long lines, inv", function()
	local w = T.newWorld()
	local c = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local DR = DRof(c)
	for _, t in ipairs({ "123", "summ", "sum", "summon", "summons", "summ pls", "sum pls", "need summon", "Summon pls!", "sumon plz" }) do
		eq(DR.RaidWords(t), "request", t)
	end
	for _, t in ipairs({ "no", "nvm", "cancel", "walking", "here" }) do eq(DR.RaidWords(t), "cancel", t) end
	for _, t in ipairs({ "inv", "inv pls", "lol", "anyone summoning tonight or should we all just walk there instead" }) do
		eq(DR.RaidWords(t), nil, t)
	end
	clean(w)
end)

test("r5 engine: 2.0 unchanged - a Warlock alone is a driver with no summoners, opens and casts", function()
	local w = T.newWorld()
	local c = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	settle(w)
	local DR = DRof(c)
	eq(DR.Role(), "driver")
	eq(#DR.Summoners(), 0)
	eq(DR.Mode(), "sell")
	ok(DR.SetOpen(true))
	ok(DR.Selling())
	local may, turn = DR.MayCast()
	ok(may)
	eq(turn, key(ANA))
	eq(#DR.Stations(), 1, "one station")
	ok(not DR.MultiStation())
	eq(DR.MaxGroup(), 5)
	clean(w)
end)
