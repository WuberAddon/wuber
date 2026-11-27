-- Wuber 2.2 (round six, SPEC5.md) tests: agent A's part (engine + net). Loaded by run.lua with the
-- same helpers as round five. Test names start "r6 engine:".

local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

test("r6 engine: the file loads", function()
	ok(H ~= nil, "the harness")
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local count, list, clean, settle, rider, driver = T.count, T.list, T.clean, T.settle, T.rider, T.driver
local fields, msgs = T.fields, T.msgs
local ANITA, TESTCHAR, BOB, ANA, BEA, CAL = T.ANITA, T.TESTCHAR, T.BOB, T.ANA, T.BEA, T.CAL
local SPOT = "Undercity"
local DAN = "Dan Miller"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function DRof(c) return c.W.Drive end
local function customer(c, name) return c.W.Drive.customers[key(name)] end
local function sent(w, from, pattern, prefix)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.from == from and (prefix or "WUBER") == e.prefix and e.result == 0 and e.text:find(pattern) then out[#out + 1] = e end
	end
	return out
end

---------------------------------------------------------------------------
-- outbox (#5): a full queue drops its lowest priority, never the ride message at the head
---------------------------------------------------------------------------

test("r6 engine: outbox (#5): full queue: the lowest-priority item goes, never the ride message at its head", function()
	local w = H.NewWorld({})
	local r = rider(w)
	settle(w)
	local W = r.W
	for i = 1, 4 do W.SendTo(BOB, "T", "fill" .. i, 5) end -- the burst goes at once
	W.SendTo(BOB, "A", "headid", 5, 1) -- now the head of the queue
	for i = 1, 39 do W.SendTo(BOB, "T", "pad" .. i, 5) end
	eq(W.QueueLength(), 40, "the queue is full")
	ok(W.OnNetwork(), "on the network")
	W.SendChannel("Q", "x") -- a channel item (lowest priority) into the full queue
	w:advance(90)
	eq(#sent(w, TESTCHAR, "^A~1~headid"), 1, "the ride's A went out")
	eq(#sent(w, TESTCHAR, "^T~1~pad39~"), 1, "the last ride message went out too")
end)

---------------------------------------------------------------------------
-- realms (#8): realm suffixes without spaces and hyphenated names
---------------------------------------------------------------------------

test("r6 engine: realms (#8): space-less realm suffixes and hyphenated names parse in keys, names, Short", function()
	local w = H.NewWorld({})
	local d = driver(w, ANITA)
	settle(w)
	local W, DR = d.W, d.W.Drive
	-- a one-part name with a normalised realm of another node
	eq(W.Key("Dan-CAMWOWEU4Realm7PvE"), "dan", "key: realm dropped")
	eq(W.Key("Dan-CAMWOW EU4 Realm 7"), "dan", "key: realm with spaces dropped")
	eq(W.Key("Dan Miller-CAMWOWEU4Realm7PvE"), "dan miller")
	eq(W.Key("Ana-Smith"), "ana smith", "the hyphen spelling of two parts")
	-- hyphenated first names keep their hyphen
	eq(W.Key("Jean-Luc Picard"), "jean-luc picard", "key of a hyphenated name")
	eq(W.Key("Jean-Luc-Picard"), "jean-luc picard", "its whisper-macro spelling")
	eq(W.Key("Jean-Luc Picard-CAMWOWEU4Realm7PvE"), "jean-luc picard", "with a realm")
	eq(W.Short("Jean-Luc Picard"), "Jean-Luc")
	eq(W.Short("Ana Smith"), "Ana")
	eq(W.Short("Ana-Smith"), "Ana")
	eq(W.Short("Dan-CAMWOWEU4Realm7PvE"), "Dan")
	eq(W.CleanName("Dan-CAMWOWEU4Realm7PvE"), "Dan", "clean name: realm dropped")
	eq(W.CleanName("Jean-Luc Picard"), "Jean-Luc Picard")
	eq(W.CleanName("Jean-Luc-Picard"), "Jean-Luc Picard")
	eq(DR.CleanName("Dan-CAMWOWEU4Realm7PvE"), "Dan", "drive: realm dropped")
	eq(DR.CleanName("Jean-Luc Picard"), "Jean-Luc Picard", "drive: hyphenated name kept whole")
	eq(W.NameFromKey("jean-luc picard"), "Jean-Luc Picard")
	ok(W.IsRealmTail("CAMWOWEU4Realm7PvE") and W.IsRealmTail("CAMWOW EU4 Realm 7") and not W.IsRealmTail("Smith")
		and not W.IsRealmTail("Luc Picard"), "realm tails")
end)

test("r6 engine: realms (#8): a one-word rider from another node whispering with a space-less realm is one customer, blocklist applies", function()
	local w = H.NewWorld({})
	local a = driver(w, ANITA, { spot = SPOT })
	w:addBot("Dan", { spot = "Orgrimmar" })
	settle(w)
	DRof(a).Blacklist("Dan-CAMWOWEU4Realm7PvE", "test")
	ok(DRof(a).BlockEntry("dan"), "blocked under the plain name")
	DRof(a).Unblacklist("Dan")
	eq(DRof(a).BlockEntry("dan"), nil, "unblocked")
	ok(DRof(a).SetOpen(true))
	w:advance(2)
	a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan-CAMWOWEU4Realm7PvE")
	w:advance(1)
	local c = customer(a, "Dan")
	ok(c, "the rider is listed as dan")
	eq(c.name, "Dan", "his name without the realm")
	clean(w, { allow = true })
end)

---------------------------------------------------------------------------
-- founder (#1): the community invitation is trusted only on the founders' ruleset
---------------------------------------------------------------------------

test("r6 engine: founder (#1): an invitation from 'Anita Lift' on another ruleset is not the founder's", function()
	for _, case in ipairs({ { realm = "CAMWOW US2 Realm 1 PvE", want = false }, { realm = "CAMWOW EU5 Realm 5 PvP", want = false },
		{ realm = "CAMWOW EU5 Realm 5 PvE", want = true } }) do
		local w = H.NewWorld({ clubs = true })
		w:addClub({ id = 77, name = "Wuber", members = { [ANITA] = 1 } })
		local d = w:addClient(BOB, { spot = "Ratchet", class = "WARLOCK", realm = case.realm })
		settle(w)
		w:clubInvite(w:club(77), ANITA, BOB)
		w:advance(1)
		local id = d.W.CommunityInvite()
		eq(id ~= nil, case.want, case.realm .. ": invitation trusted")
		clean(w)
	end
end)

---------------------------------------------------------------------------
-- finished / reload (#25)
---------------------------------------------------------------------------

local function ratings(c)
	local got = {}
	c.W.Listen("RATING", function(id, name, stars) got[#got + 1] = { id = id, name = name, stars = stars } end)
	return got
end

test("r6 engine: finished (#25): a declined, blocked or cancelled request can never be rated", function()
	local w = H.NewWorld({})
	local a = driver(w, ANITA, { spot = SPOT })
	w:addBot("Gus Hart", { spot = "Orgrimmar" })
	w:addBot("Eve Long", { spot = "Orgrimmar" })
	settle(w)
	ok(DRof(a).SetOpen(true))
	w:advance(3)
	local got = ratings(a)
	DRof(a).Blacklist("Gus Hart", "test")
	w:inject("Gus Hart", "R~1~blocky~Undercity~5000", "WHISPER", a)
	w:advance(1)
	w:inject("Gus Hart", "T~1~blocky~5", "WHISPER", a)
	w:inject("Eve Long", "R~1~cheapo~Undercity~4000", "WHISPER", a) -- declined: price
	w:advance(1)
	w:inject("Eve Long", "T~1~cheapo~1", "WHISPER", a)
	w:advance(1)
	eq(#got, 0, "no rating from a declined request")
	clean(w)
end)

test("r6 engine: reload (#25): after the driver's /reload a paid ride's rating and an accepted ride's cancel still count", function()
	local w = H.NewWorld({})
	local a = driver(w, ANITA, { spot = SPOT })
	w:addBot(DAN, { spot = "Orgrimmar" })
	w:addBot(TESTCHAR, { spot = "Orgrimmar" })
	settle(w)
	ok(DRof(a).SetOpen(true))
	w:advance(3)
	-- a paid ride (the S paid went out): its id is finished
	w:inject(TESTCHAR, "R~1~paidid~Undercity~5000", "WHISPER", a)
	w:advance(1)
	a.W.SendStage("paidid", "paid", TESTCHAR)
	-- an accepted one, in the group
	w:inject(DAN, "R~1~danrid~Undercity~5000", "WHISPER", a)
	w:advance(6)
	ok(customer(a, DAN) and customer(a, DAN).wuberRide == "danrid", "Dan's Wuber ride")
	ok(a.W.Drive.Rank(customer(a, DAN).state) >= a.W.Drive.Rank("joined"), "Dan joined: " .. tostring(customer(a, DAN).state))
	a = w:reload(a)
	w:advance(3)
	local got = ratings(a)
	w:inject(TESTCHAR, "T~1~paidid~5", "WHISPER", a)
	w:advance(1)
	eq(#got, 1, "the rating counts after the /reload")
	local inc
	for _, r in ipairs(a.W.incoming) do if r.id == "danrid" then inc = r end end
	ok(inc, "Dan's request is back in W.incoming")
	w:inject(DAN, "C~1~danrid", "WHISPER", a)
	w:advance(1)
	eq(customer(a, DAN), nil, "Dan's cancel took him off the queue")
	clean(w)
end)

test("r6 engine: reload (#25): the queue snapshot keeps wuberLabel (not the dead wuberStage), dest and station", function()
	local src = H.F.read("Drive_Core") -- Drive_Core.lua, or Drive/Core.lua after the restructure
	ok(src, "Drive_Core's code")
	ok(not src:find('"wuberStage"', 1, true), "no wuberStage")
	ok(src:find('"wuberLabel"', 1, true) and src:find('"station"', 1, true), "wuberLabel and station kept")
end)

---------------------------------------------------------------------------
-- farelock (#6): the fare is locked when the rider asks; every crew window bills it
---------------------------------------------------------------------------

local function crewSaved(me, captain, crew, extra)
	local ch = { crew = crew, captain = captain, wizard = true }
	for k, v in pairs(extra or {}) do ch[k] = v end
	return { Wuber = { chars = { [key(me)] = ch } } }
end

-- Ana (captain, leads) and Bea, both Warlocks with Wuber, at Undercity
local function twoLocks(opts)
	opts = opts or {}
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", shards = 10,
		saved = crewSaved(ANA, "", { { name = BEA, role = "lock", app = true } }) })
	local b = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", shards = 10,
		saved = crewSaved(BEA, ANA, { { name = ANA, role = "lock", app = true } }) })
	w:group({ ANA, BEA })
	settle(w)
	return w, a, b
end

test("r6 engine: farelock (#6): a Wuber rider at today's price keeps it when the driver raises the price before the join", function()
	local w = H.NewWorld({})
	local a = driver(w, ANITA, { spot = SPOT })
	w:addBot(DAN, { spot = "Orgrimmar", acceptsInvites = false }) -- (away a moment: the invite waits)
	settle(w)
	DRof(a).SetPrice(5000)
	ok(DRof(a).SetOpen(true))
	w:advance(5)
	w:inject(DAN, "R~1~danrid~Undercity~5000", "WHISPER", a)
	w:advance(2)
	local c = customer(a, DAN)
	ok(c and c.wuberRide == "danrid", "Dan's Wuber ride")
	eq(c.price, 5000, "the fare asked")
	DRof(a).SetPrice(50000)
	w:group({ ANITA, DAN })
	w:advance(3)
	c = customer(a, DAN)
	ok(c and DRof(a).Rank(c.state) >= DRof(a).Rank("joined"), "joined")
	eq(c.price, 5000, "still the fare locked when they asked")
	clean(w)
end)

test("r6 engine: farelock (#6): ASK and ST carry the locked fare to every crew window", function()
	local w, a, b = twoLocks()
	DRof(a).SetPrice(5000)
	ok(DRof(a).SetOpen(true))
	w:advance(3)
	eq(DRof(b).char().price, 5000, "Bea has the price (CFG)")
	w:addBot(DAN, { spot = "Orgrimmar", acceptsInvites = false })
	w:botWhisper(DAN, a, "summon pls")
	w:advance(2)
	ok(customer(a, DAN), "queued with Ana")
	ok(customer(b, DAN), "queued with Bea (ASK)")
	DRof(a).SetPrice(20000)
	w:advance(2)
	eq(DRof(b).char().price, 20000, "the new price reached Bea")
	w:group({ ANA, BEA, DAN })
	w:advance(3)
	eq(customer(a, DAN).price, 5000, "Ana bills the locked fare")
	eq(customer(b, DAN).price, 5000, "Bea bills the same")
	-- a later ST from Ana (a sync) carries it too: Bea's copy forced off is put right
	customer(b, DAN).price = 20000
	DRof(a).SyncStates()
	w:advance(3)
	eq(customer(b, DAN).price, 5000, "ST put Bea's fare right")
	clean(w)
end)

---------------------------------------------------------------------------
-- rrsnapshot / rrname / rrmentions (#4)
---------------------------------------------------------------------------

local FARRA, HAYLEY = "Farra Way", "Hayley Cab"
local function oldDB(extra)
	local t = {
		price = 50000, service = "Ritual Rides", dest = "", caster = "", team = { ANITA, FARRA, HAYLEY },
		blocklist = {}, log = { v = 1, rides = {}, asks = {}, open = {}, seen = {}, wreq = {}, wdec = {}, rivals = {} },
		stats = { rides = 0, copper = 0 }, setupSeen = true,
	}
	for k, v in pairs(extra or {}) do t[k] = v end
	return t
end

test("r6 engine: rrname (#4): the old addon's default service name is never imported", function()
	local w = H.NewWorld({})
	local c = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK", loadRR = "tombstone", saved = { RitualRides = oldDB() } })
	settle(w)
	ok(DRof(c).db.imported, "imported")
	eq(c.W.Char().price, 50000, "the price came over")
	ok(not tostring(c.W.Char().service or ""):lower():find("ritual"), "service: " .. tostring(c.W.Char().service))
	clean(w)
end)

test("r6 engine: rrsnapshot (#4): a Warlock alt that first logs in after the old addon is off still gets its settings and crew", function()
	local w = H.NewWorld({})
	local a = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK", loadRR = "tombstone",
		saved = { RitualRides = oldDB({ service = "Giga Rides" }) } })
	settle(w)
	ok(DRof(a).db.imported and DRof(a).db.imported.charSeed, "the seed is kept in WuberDB")
	local saved = w:logout(a)
	-- the old addon is switched off now: Farra logs in for the first time
	local f = w:addClient(FARRA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = saved.Wuber } })
	settle(w)
	eq(f.env.RitualRidesDB, nil, "the old addon's data isn't loaded")
	eq(f.W.Char().price, 50000, "Farra's price")
	eq(f.W.Char().service, "Giga Rides", "Farra's service")
	eq(#(f.W.Char().crew or {}), 2, "Farra's crew: Anita and Hayley")
	clean(w)
end)

-- the TOC has no load-order tie to the old addon; Wuber reads its data at
-- PLAYER_LOGIN (DR.Lock is read live before that), so the load order doesn't matter
test("r6 engine: rrmentions (#4): no OptionalDeps on the old addon; the lock and import still work (read at login)", function()
	local toc = T.readFile(T.dir .. "/../Wuber/Wuber.toc")
	ok(not toc:lower():find("ritual"), "the TOC never names it")
	local w = H.NewWorld({})
	local c = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK", loadRR = "1.4.1", saved = { RitualRides = oldDB() } })
	settle(w)
	eq(DRof(c).Lock(), "rr", "the old addon drives: the engine waits")
	ok(DRof(c).db.imported, "imported at login")
	clean(w)
end)

test("r6 engine: curse (#29): TOC metadata: Author Anita Lift, Category, X-Category, the live X-Curse-Project-ID (2.3.0)", function()
	local toc = T.readFile(T.dir .. "/../Wuber/Wuber.toc")
	ok(toc:find("\n## Author: Anita Lift\n", 1, true), "author")
	ok(toc:find("\n## Category: ", 1, true) and toc:find("\n## X-Category: ", 1, true), "categories")
	ok(toc:find("\n## X-Curse-Project-ID: 1813140\n", 1, true), "the CurseForge project id (18 Nov)")
	ok(not toc:find("\n# ## X-Curse-Project-ID", 1, true), "no commented placeholder left")
end)

test("r6 engine: guild (#25): DR.Guild is no longer defined in Drive_Service (one copy, in Drive_Chat)", function()
	local src = H.F.read("Drive_Service") -- Drive_Service.lua, or Drive/Service+Ready+Raid.lua
	ok(src, "Drive_Service's code")
	ok(not src:find("function DR.Guild", 1, true), "Drive_Service's copy is gone")
end)

---------------------------------------------------------------------------
-- paths / pending (#30)
---------------------------------------------------------------------------

test("r6 engine: pending (#30): a Wuber rider's level reaches the driver's queue row (c.wuberLabel)", function()
	local w = H.NewWorld({})
	local a = driver(w, ANITA, { spot = SPOT })
	w:addBot(DAN, { spot = "Orgrimmar" })
	settle(w)
	ok(DRof(a).SetOpen(true))
	w:advance(3)
	w:inject(DAN, "R~1~labels~Undercity~5000~2~12", "WHISPER", a)
	w:advance(2)
	local c = customer(a, DAN)
	ok(c, "listed")
	eq(c.wuberLabel, "Silver rider \194\183 12 rides", "the label")
	clean(w)
end)

test("r6 engine: paths (#30): no /home/claude paths or Unix-only shell calls in the suite's code; no pending tests", function()
	local bad = {}
	for _, f in ipairs({ "harness.lua", "run.lua", "round2.lua", "round3.lua", "round4.lua", "whisper.lua", "community.lua",
		"discovery.lua", "round5_engine.lua", "round6_engine.lua" }) do
		local src = T.readFile(T.dir .. "/" .. f) or ""
		local n = 0
		for line in (src .. "\n"):gmatch("([^\n]*)\n") do
			n = n + 1
			local code = line:gsub("^%s+", "")
			if not code:find("^%-%-") and f ~= "round6_engine.lua" then
				if code:find("/home/claude", 1, true) then bad[#bad + 1] = f .. ":" .. n .. " path" end
				if code:find("io.popen", 1, true) and f ~= "harness.lua" and not code:find("node ", 1, true) then
					bad[#bad + 1] = f .. ":" .. n .. " popen"
				end
				if code:find("^pending%(") or code:find("^T%.pending%(") then bad[#bad + 1] = f .. ":" .. n .. " pending" end
			end
		end
	end
	eq(#bad, 0, list(bad))
	ok(H.exists(H.RR_TOMBSTONE .. "/RitualRides.toc"), "the tombstone, repo-relative")
	ok(#H.listFiles(H.ADDONS.Wuber .. "/Media", "tga") > 10, "H.listFiles lists Media")
	local js = T.readFile(T.dir .. "/heatmap.test.js") or ""
	ok(js:find("rmSync(dir", 1, true), "the heatmap tests remove their temp folders")
end)

---------------------------------------------------------------------------
-- community (#7): no community channel; its online members are whisper seeds
---------------------------------------------------------------------------

test("r6 engine: community (#7): no stream channel, nothing sent there; online members (Warlocks first) are whisper seeds", function()
	local w = H.NewWorld({ clubs = true })
	w:addClub({ id = 77, name = "Wuber", members = { [ANITA] = 1, [BOB] = 4, [TESTCHAR] = 4, [CAL] = 4, [ANA] = 4 } })
	local d = w:addClient(BOB, { spot = "Ratchet", class = "WARLOCK", realm = "CAMWOW EU4 Realm 7 PvE" })
	local r = w:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE", channelCopy = "realm5" })
	w:addBot(CAL, { spot = "Orgrimmar", class = "WARRIOR" }) -- online, not a Warlock
	w:addBot(ANA, { spot = "Orgrimmar", class = "WARLOCK" })
	w:player(ANA).online = false                                -- offline: never a seed
	settle(w, 25)
	d.W.Char().price = 5000
	T.goOnline(d)
	for _, c in ipairs({ d, r }) do
		eq(c.W.community.state, "member", c.player.name .. " is in the community")
		eq(c.clubChannelAdds, nil, c.player.name .. ": no stream channel added (one of the 10 chat slots)")
		eq(c.W.CommunityIndex(), nil, "no community channel")
	end
	local seeds = r.W.CommunitySeeds()
	eq(#seeds, 2, "Bob and Cal: " .. list((function() local o = {} for _, e in ipairs(seeds) do o[#o + 1] = e.name end return o end)()))
	eq(seeds[1].name, BOB, "the Warlock first")
	-- Wuber is on another copy of WuberNet: the roster's whisper reaches Bob
	r.W.WhisperRound("full", true)
	w:advance(6)
	local x = r.W.drivers["bob stone"]
	ok(x, "the rider finds Bob through the community's roster")
	eq(x.via, "WHISPER", "by whisper")
	w:advance(120)
	for _, c in ipairs({ d, r }) do eq(c.commSends, nil, c.player.name .. ": nothing sent on a community channel") end
	clean(w)
end)

---------------------------------------------------------------------------
-- stagger (#9), firstround / gossip (#13)
---------------------------------------------------------------------------

local function whisperedTo(w, kind, from, to)
	local out = {}
	for _, e in ipairs(msgs(w, kind, from, "WHISPER")) do
		if H.key(e.target) == H.key(to) then out[#out + 1] = e end
	end
	return out
end

test("r6 engine: stagger (#9): 30 riders asking at once all get one answer (none dropped), a booked rider none", function()
	local w = H.NewWorld({})
	local a = driver(w, ANITA, { spot = SPOT })
	local riders = {}
	for i = 1, 30 do
		local n = "Rider R" .. string.char(96 + math.ceil(i / 26)) .. string.char(96 + ((i - 1) % 26) + 1)
		riders[i] = n
		w:addBot(n, { spot = "Orgrimmar" })
	end
	w:addBot(DAN, { spot = "Orgrimmar" })
	settle(w)
	ok(DRof(a).SetOpen(true))
	w:advance(5)
	-- Dan books (R, accepted), then asks again with a Q: no answer to him
	w:inject(DAN, "R~1~danrid~Undercity~5000", "WHISPER", a)
	w:advance(12) -- (he joins: the beacon's seats change before the riders ask)
	ok(customer(a, DAN), "Dan booked")
	local before = #whisperedTo(w, "D", ANITA, DAN)
	for _, n in ipairs(riders) do w:inject(n, "Q~1~1", "WHISPER", a) end
	w:inject(DAN, "Q~1~1", "WHISPER", a)
	w:advance(45)
	local missing, twice = {}, {}
	for _, n in ipairs(riders) do
		local got = #whisperedTo(w, "D", ANITA, n)
		if got == 0 then missing[#missing + 1] = n elseif got > 1 then twice[#twice + 1] = n end
	end
	eq(a.W.net.dropped, 0, "nothing dropped from the outbox")
	eq(#missing, 0, "every rider answered: missing " .. list(missing))
	eq(#twice, 0, "one answer each: " .. list(twice))
	eq(#whisperedTo(w, "D", ANITA, DAN), before, "no answer to the rider who booked")
	-- the price changes: the push goes to the riders who asked, never to the booked one
	DRof(a).SetPrice(6000)
	w:advance(10)
	eq(#whisperedTo(w, "D", ANITA, DAN), before, "no push to the booked rider either")
	eq(#whisperedTo(w, "D", ANITA, riders[1]), 2, "a rider who asked got the change")
	clean(w)
end)

test("r6 engine: stagger (#9): a rider whose ride is under way sends no whispered Qs", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { saved = { Wuber = { favs = { ["bob stone"] = true } } } })
	w:addBot(BOB, { spot = "Ratchet", class = "WARLOCK" })
	settle(w, 20)
	r.W.ride = { id = "abcdef", state = "accepted", driverKey = "anita lift", driver = ANITA, addr = ANITA, at = 0, changed = 0 }
	local n0 = #whisperedTo(w, "Q", TESTCHAR, BOB)
	eq(r.W.WhisperRound("full", true), 0, "no round while riding")
	w:advance(5)
	eq(#whisperedTo(w, "Q", TESTCHAR, BOB), n0, "no Q")
	r.W.ride = nil
end)

test("r6 engine: firstround (#13): with Wuber opened right after login the first whisper round goes at once", function()
	local w = H.NewWorld({})
	w:addBot(BOB, { spot = "Ratchet", class = "WARLOCK" })
	local r = rider(w, TESTCHAR, { saved = { Wuber = { favs = { ["bob stone"] = true } } } })
	w:advance(1)
	ok(r.W.UI and r.W.UI.Toggle, "the UI")
	r.W.UI.Toggle(true)
	w:advance(2)
	ok(#msgs(w, "Q", TESTCHAR, "WHISPER") >= 1, "the round began within 3 s of login (not 10)")
	ok(r.W.fallback.qAt["bob stone"], "Bob is in it")
end)

test("r6 engine: gossip (#13): few drivers live: recently seen ones are passed on with their age; fresh before stale", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR)
	w:addBot(BOB, { spot = "Orgrimmar" })
	settle(w)
	local stamp = r.env.time()
	r.W.db.seenDrivers = {
		["eve long"] = { name = "Eve Long", addr = "Eve Long", at = stamp - 600 },
		["gus hart"] = { name = "Gus Hart", addr = "Gus Hart", at = stamp - 7200 },
		["old timer"] = { name = "Old Timer", addr = "Old Timer", at = stamp - 3 * 86400 }, -- too old
	}
	w:inject(BOB, "Q~1~1", "WHISPER", r) -- a peer asks: we gossip back
	w:advance(5)
	local k = msgs(w, "K", TESTCHAR, "WHISPER")
	ok(#k >= 1, "a K went out")
	local text = k[#k].text
	ok(text:find("Eve Long:1%d") and text:find("Gus Hart:12%d"), "names with minutes since seen: " .. text)
	ok(not text:find("Old Timer", 1, true), "not one seen days ago")
	-- the other side: aged names are unconfirmed, fresh ones first
	local c = rider(w, CAL)
	settle(w)
	w:inject(TESTCHAR, "K~1~Zed Old:600~Amy New", "WHISPER", c)
	w:advance(1)
	local un = {}
	for _, e in ipairs(c.W.KnownDrivers()) do if e.unconfirmed then un[#un + 1] = e.name end end
	eq(un[1], "Amy New", "fresh first: " .. list(un))
	eq(un[2], "Zed Old")
	eq(c.W.fallback.unconfirmed["zed old"].age, 600)
end)

---------------------------------------------------------------------------
-- redraws (#10): one DRIVERS for a burst of beacons; a Q right after our beacon waits
---------------------------------------------------------------------------

test("r6 engine: redraws (#10): 20 beacons at once fire DRIVERS once, not 20", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR)
	settle(w)
	local fires = 0
	r.W.Listen("DRIVERS", function() fires = fires + 1 end)
	for i = 1, 20 do
		w:inject("Lock L" .. string.char(96 + i), "D~1~Ratchet~1413~500~500~5000~Rides~open~1~1~H~2.2.0", "CHANNEL")
	end
	w:advance(1)
	ok(r.W.drivers["lock la"] and r.W.drivers["lock lt"], "all listed")
	ok(fires >= 1 and fires <= 2, "DRIVERS fired " .. fires .. " times")
end)

test("r6 engine: redraws (#10): a Q right after our unchanged channel beacon is answered later (1.5-7 s)", function()
	local w = H.NewWorld({})
	local a = driver(w, ANITA, { spot = SPOT })
	settle(w)
	ok(DRof(a).SetOpen(true))
	w:advance(3)
	for round = 1, 5 do
		local n0 = #msgs(w, "D", ANITA, "CHANNEL")
		ok(n0 >= 1, "beaconed")
		w:inject(TESTCHAR, "Q~1~1", "CHANNEL")
		w:advance(1.4)
		eq(#msgs(w, "D", ANITA, "CHANNEL"), n0, round .. ": not within 1.4 s")
		w:advance(7)
		eq(#msgs(w, "D", ANITA, "CHANNEL"), n0 + 1, round .. ": answered once")
		w:advance(8)
	end
end)

---------------------------------------------------------------------------
-- advert (#13): Wuber's line by default; the spam check skips the guild name and prices
---------------------------------------------------------------------------

test("r6 engine: advert (#13): the default advert is W.AdvertText; a guild with 'gold' in it or a 1000g fare is not spam", function()
	local w = H.NewWorld({})
	local a = driver(w, ANITA, { spot = SPOT })
	settle(w)
	DRof(a).SetPrice(5000)
	eq(DRof(a).AdvertText(), a.W.AdvertText(SPOT, 5000), "Wuber's own line, with where to get Wuber")
	ok(DRof(a).AdvertText():find("Wuber addon", 1, true), "mentions the addon")
	w:player(ANITA).guild = "Gold Diggers"
	local line, why = a.W.AdvertOwnText("<Gold Diggers> summons to Undercity for 1000g, whisper me")
	ok(line, "a guild named Gold and a 4-digit fare pass: " .. tostring(why))
	ok(not a.W.AdvertOwnText("WTS cheap gold, www.x"), "real spam still refused")
	ok(not a.W.AdvertOwnText("summons 5000 for gold"), "the driver's own words are still checked")
	clean(w)
end)

---------------------------------------------------------------------------
-- public (#18): buyers parsed only while driving; place lookups without allocation
---------------------------------------------------------------------------

test("r6 engine: public (#18): a closed driver never parses buyers; [Wuber] adverts still give driver hints", function()
	local w = H.NewWorld({})
	local a = driver(w, ANITA, { spot = SPOT })
	settle(w)
	local DR = DRof(a)
	DR.opts().autoPublic = true -- (2.3.2: off by default, on after a warning)
	local calls = 0
	local real = DR.PublicWant
	DR.PublicWant = function(...) calls = calls + 1 return real(...) end
	w:chatFrom("Eve Long", "wtb summon uc", "CHANNEL", "Trade")
	w:chatFrom("Rex Rival", "[Wuber] Summons to Ratchet 50s - I'm a Wuber driver", "CHANNEL", "Trade")
	w:advance(1)
	eq(calls, 0, "closed: no buyer parsing")
	ok(a.W.fallback.unconfirmed["rex rival"] or a.W.fallback.advertHeard["rex rival"], "the advert is a driver hint")
	ok(DR.SetOpen(true))
	w:advance(2)
	w:chatFrom("Eve Long", "wtb summon uc", "CHANNEL", "Trade")
	w:advance(1)
	eq(calls, 1, "open: parsed")
	DR.PublicWant = real
	clean(w)
end)

test("r6 engine: public (#18): place lookups are a hash; the typo distance makes no tables", function()
	local w = H.NewWorld({})
	local a = driver(w, ANITA, { spot = SPOT })
	settle(w)
	local DR = DRof(a)
	eq(DR.PlaceEntry("uc")[1], "Undercity")
	eq(DR.PlaceEntry("booty bay")[1], "Booty Bay")
	eq(DR.PlaceIn(DR.Norm("wtb summon to the undercity pls"))[1], "Undercity", "the longest name in a line")
	eq(DR.PlaceIn(DR.Norm("lf sum ratchett"))[1], "Ratchet")
	eq(DR.Distance("ratchet", "rachet", 2), 1)
	eq(DR.Distance("summon", "sumomn", 2), 1, "a swap")
	collectgarbage("collect")
	collectgarbage("stop")
	local before = collectgarbage("count")
	for _ = 1, 2000 do DR.Distance("undercity", "undercty", 2) end
	local grew = collectgarbage("count") - before
	collectgarbage("restart")
	ok(grew < 20, ("distance() allocated %.0f KB over 2000 calls"):format(grew))
end)

---------------------------------------------------------------------------
-- resume / helperpause / roles (#17)
---------------------------------------------------------------------------

local function wubert6(w, kind, from)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.result == 0 and e.text:match("^([^~]*)") == kind and (not from or e.from == from) then
			out[#out + 1] = e
		end
	end
	return out
end

test("r6 engine: resume (#17): a crew mate's Resume clears the away marks, invites the queue and tells the screens", function()
	local w, a, b = twoLocks()
	ok(DRof(a).SetOpen(true))
	w:advance(2)
	ok(DRof(b).SetPaused(true))
	w:advance(2)
	ok(DRof(a).IsPaused(), "Ana paused by Bea")
	w:addBot(DAN, { spot = "Orgrimmar" })
	w:botWhisper(DAN, a, "summon pls")
	w:advance(3)
	local c = customer(a, DAN)
	ok(c and c.state == "queued", "queued while paused: " .. tostring(c and c.state))
	c.awayAt = 123
	local heard = 0
	a.W.Listen("SETTINGS", function(what) if what == "paused" then heard = heard + 1 end end)
	ok(DRof(b).SetPaused(false))
	w:advance(0.5)
	eq(heard, 1, "SETTINGS paused on Ana's screen")
	eq(customer(a, DAN).awayAt, nil, "the away mark cleared")
	ok(customer(a, DAN).state ~= "queued", "invited at once: " .. tostring(customer(a, DAN).state))
	clean(w)
end)

test("r6 engine: helperpause (#17): a helper's window can't pause (mini button, minimap, /wuber drive pause all end here)", function()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = crewSaved(ANA, "", { { name = PIA or "Pia Rose", role = "helper", app = true } }) })
	local p = w:addClient("Pia Rose", { spot = SPOT, class = "PRIEST", saved = crewSaved("Pia Rose", ANA, { { name = ANA, role = "lock", app = true } }) })
	w:group({ ANA, "Pia Rose" })
	settle(w)
	eq(DRof(p).Role(), "helper")
	local okP, why = DRof(p).SetPaused(true)
	eq(okP, false, "refused")
	eq(why, "helper")
	ok(not DRof(p).IsPaused(), "not paused")
	eq(#wubert6(w, "PAU", "Pia Rose"), 0, "nothing sent")
	clean(w)
end)

test("r6 engine: roles (#17): a Warlock who says Yes out of the group is a Warlock in the crew at once (TY carries L)", function()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = crewSaved(ANA, "", {}) })
	local b = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK" })
	settle(w)
	ok(DRof(a).OfferCrew(BEA))
	w:advance(1)
	ok(DRof(b).pendingOffers[key(ANA)], "Bea has the offer")
	DRof(b).AnswerOffer(ANA, true)
	w:advance(1)
	local m = DRof(a).CrewEntry(key(BEA))
	ok(m, "Bea is in Ana's crew")
	eq(m.role, "lock", "as a Warlock, before any HI")
	clean(w)
end)

test("r6 engine: roles (#17): a captain that doesn't lead never sends its pause over the leading Warlock's in a sync", function()
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = crewSaved(ANA, "", { { name = BEA, role = "lock", app = true } }) })
	local b = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", saved = crewSaved(BEA, ANA, { { name = ANA, role = "lock", app = true } }) })
	w:group({ BEA, ANA }) -- Bea leads
	settle(w)
	ok(DRof(b).IsLeader() and not DRof(a).IsLeader(), "Bea leads")
	local n0 = #wubert6(w, "PAU", ANA)
	DRof(a).SyncNow()
	w:advance(5)
	eq(#wubert6(w, "PAU", ANA), n0, "no PAU from the captain")
	clean(w)
end)

---------------------------------------------------------------------------
-- full / complete / tradecheck (#3), rider side
---------------------------------------------------------------------------

-- Wuber landed with Bob (a driver bot) and owes `fare`
local function landed(fare)
	local w = H.NewWorld({})
	w:addBot(BOB, { spot = "Orgrimmar", class = "WARLOCK" })
	w:addBot("Rex Scam", { spot = "Orgrimmar" })
	local r = rider(w, TESTCHAR, { money = 100000 })
	settle(w)
	w:group({ BOB, TESTCHAR })
	w:advance(1)
	local t = r.env.GetTime()
	r.W.ride = { id = "abcdef", state = "arrived", driverKey = "bob stone", driver = BOB, addr = BOB, price = fare or 5000,
		at = t, changed = t, startedAt = r.env.time(), dest = "Orgrimmar", wasGrouped = true }
	return w, r
end

local function spend(w, r, copper)
	local p = w:player(TESTCHAR)
	p.money = p.money - copper
	r:fire("PLAYER_MONEY")
end

local function payBy(w, r, from, copper)
	ok(w:openTrade(w:player(from), w:player(TESTCHAR)), "a trade opens")
	w:tradeMoney(w:player(TESTCHAR), copper)
	w:tradeAccept(w:player(from))
	w:tradeAccept(w:player(TESTCHAR))
	w:advance(1)
end

test("r6 engine: tradecheck (#3): a stranger's trade is never the fare; the rider is warned", function()
	local w, r = landed()
	local warned
	r.W.Listen("TRADE_STRANGER", function(who) warned = who end)
	ok(w:openTrade(w:player("Rex Scam"), w:player(TESTCHAR)))
	w:advance(0.5)
	eq(r.W.TradePartnerOK(), false, "not our driver")
	eq(warned, "Rex Scam", "TRADE_STRANGER")
	eq(r.W.ride.state, "arrived", "not paying a stranger")
	w:tradeMoney(w:player(TESTCHAR), 5000)
	w:tradeAccept(w:player("Rex Scam"))
	w:tradeAccept(w:player(TESTCHAR))
	w:advance(1)
	eq(r.W.ride.state, "arrived", "money to a stranger is not the fare")
end)

test("r6 engine: complete (#3): a cancelled trade, then a repair: never taken for the fare", function()
	local w, r = landed()
	ok(w:openTrade(w:player(BOB), w:player(TESTCHAR)))
	w:advance(0.5)
	eq(r.W.ride.state, "paying")
	w:tradeCancel(w:player(TESTCHAR))
	w:advance(1)
	spend(w, r, 5000) -- a repair bill (no "Trade complete." came)
	w:advance(1)
	ok(r.W.ride.state ~= "done", "not paid by a repair: " .. tostring(r.W.ride.state))
	w:advance(5)
	eq(r.W.ride.moneyBefore, nil, "the purse it saw is forgotten (5 s without 'Trade complete.')")
end)

test("r6 engine: full (#3): 90% is not paid; part payments add up to the whole fare", function()
	local w, r = landed(5000)
	payBy(w, r, BOB, 4500)
	ok(r.W.ride.state ~= "done", "45s of 50s is not paid")
	eq(r.W.FareLeft(), 500, "5s left")
	payBy(w, r, BOB, 500)
	eq(r.W.ride.state, "done", "paid in full over two trades")
	eq(r.W.ride.paid, 5000)
end)

---------------------------------------------------------------------------
-- flight costs (SPEC5, the author: "money saved vs flight paths")
---------------------------------------------------------------------------

test("r6 engine: flight costs: what a flight master showed, else the game's own list price (2.2.1), never a guess", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	local W = r.W
	-- the author: never show a number we can't back. Nothing learned yet: the game's own list price
	-- (2.2.1: TaxiPath, Ratchet > Crossroads 1s 10c + Crossroads > Gadgetzan 7s 30c)
	local c, ex, src = W.FlightCost(nil, "Gadgetzan")
	eq(c, 840, "the game's list price before a flight master was opened")
	eq(src, "table")
	eq(W.FlightCost("Ratchet", "Booty Bay"), nil, "the boat is free: no flight to pay for")
	eq(W.FlightInfo("Gadgetzan").source, "table")
	-- nothing known: nil (the line is hidden)
	eq(W.FlightCost(nil, "Some Nowhere"), nil, "not a place")
	eq(W.FlightCost(nil, "Ratchet"), nil, "already there")
	eq(W.FlightCost(nil, "The Barrens"), nil, "a whole zone has no flight cost")
	-- the flight master's map: exact costs from here to every node it reaches
	w:openTaxi(r, {
		{ name = "Ratchet, The Barrens", type = "CURRENT", cost = 0 },
		{ name = "Gadgetzan, Tanaris", type = "REACHABLE", cost = 2345 },
		{ name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 610 },
		{ name = "Everlook, Winterspring", type = "NONE", cost = 0 },
	})
	-- the author (2.2.1): always the full list price; a seen price (maybe discounted) never replaces it
	c, ex, src = W.FlightCost(nil, "Gadgetzan")
	eq(c, 840, "the table's full price still")
	eq(ex, 1)
	eq(src, "table")
	eq(W.FlightSeen(nil, "Gadgetzan"), 2345, "what the flight master showed is kept")
	eq(W.FlightSeen("Ratchet", "Orgrimmar"), 610)
	eq(select(3, W.FlightCost("Ratchet", "Everlook")), "table", "a node this map can't reach: the game's list price")
	ok(W.db.flights["H|ratchet|gadgetzan"], "account-wide in WuberDB, per faction (review 2.2 #11)")
	local info = W.FlightInfo("Gadgetzan")
	ok(info and info.cost == 840 and info.exact == 1 and info.from == "Ratchet", "W.FlightInfo")
	-- a trip the table can't route (e.g. after a patch): the seen price
	W.TAXI = nil
	W.FLY.TaxiReset()
	c, ex, src = W.FlightCost(nil, "Gadgetzan")
	eq(c, 2345) eq(src, "own")
	clean(w)
end)

test("r6 engine: flight costs: the ride carries the quote; paid trips add up on Trips, exact costs only", function()
	local w = H.NewWorld({})
	local d = driver(w, ANITA, { spot = "Gadgetzan" })
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	w:openTaxi(r, {
		{ name = "Ratchet, The Barrens", type = "CURRENT", cost = 0 },
		{ name = "Gadgetzan, Tanaris", type = "REACHABLE", cost = 2345 },
	})
	ok(DRof(d).SetOpen(true))
	w:advance(5)
	local ride = r.W.RequestRide(key(ANITA))
	ok(ride, "requested")
	eq(ride.flightCost, 840, "the quote at request time (the game's full list price, 2.2.1)")
	eq(ride.flightExact, 1)
	-- two finished trips: one paid with an exact cost, one unpaid
	r.W.ride = nil
	r.W.AddTrip({ at = 1, driver = ANITA, driverKey = "anita lift", dest = "Gadgetzan", price = 5000, flightCost = 2345, flightExact = 1 })
	r.W.AddTrip({ at = 2, driver = ANITA, driverKey = "anita lift", dest = "Gadgetzan", price = 5000, flightCost = 2000, flightExact = 0, unpaid = true })
	local st = r.W.Stats()
	eq(st.flightSaved, 2345, "only the paid trip counts")
	eq(st.flightRides, 1)
	eq(st.flightAbout, false, "exact")
	r.W.AddTrip({ at = 3, driver = ANITA, driverKey = "anita lift", dest = "Everlook", price = 5000, flightCost = 5500, flightExact = 0 })
	st = r.W.Stats()
	eq(st.flightSaved, 2345, "a cost no flight master showed is left out (review 2.2 #10)")
	eq(st.flightAbout, false, "never 'about'")
end)

---------------------------------------------------------------------------
-- mapcheck (#26)
---------------------------------------------------------------------------

test("r6 engine: mapcheck (#26): the summoner's real map against the ride's place: true, false (where), nil", function()
	local w = H.NewWorld({})
	w:addBot(BOB, { spot = "Ratchet", class = "WARLOCK" })
	local r = rider(w, TESTCHAR, { spot = "Orgrimmar" })
	settle(w)
	local ride = { id = "abcdef", state = "portal", driverKey = "bob stone", driver = BOB, dest = "Ratchet" }
	eq(r.W.SummonerMapOK(ride), nil, "not grouped: can't tell")
	w:group({ BOB, TESTCHAR })
	w:advance(1)
	eq(r.W.SummonerMapOK(ride), true, "Bob stands in The Barrens: Ratchet is right")
	ride.dest = "Undercity" -- the beacon said Undercity
	local good, where = r.W.SummonerMapOK(ride)
	eq(good, false, "nobody of the group is there")
	eq(where, "The Barrens", "where Bob really is")
	clean(w)
end)

---------------------------------------------------------------------------
-- 2.1 on the real client
---------------------------------------------------------------------------

test("r6 engine: 2.1 sanity: raid assist read from GetRaidRosterInfo's rank when UnitIsGroupAssistant/UnitIsRaidOfficer are missing", function()
	local w = H.NewWorld({})
	local names = { ANA, BEA }
	local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local b = w:addClient(BEA, { spot = SPOT, class = "DRUID" })
	for i = 1, 5 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = SPOT })
		names[#names + 1] = n
	end
	w:group(names)
	settle(w)
	b.env.UnitIsGroupAssistant, b.env.UnitIsRaidOfficer = nil, nil
	eq(DRof(b).CanRunRaid(), false, "not assist")
	w:setAssist(BEA, true)
	eq(DRof(b).CanRunRaid(), true, "assist, from the roster's rank")
	clean(w)
end)

test("r6 engine: 2.1 sanity: a /reload keeps each rider's station and place (queue snapshot)", function()
	local w = H.NewWorld({})
	local a = driver(w, ANITA, { spot = SPOT })
	w:addBot(DAN, { spot = "Orgrimmar" })
	settle(w)
	ok(DRof(a).SetOpen(true))
	w:advance(2)
	w:inject(DAN, "R~1~danrid~Undercity~5000~1~3", "WHISPER", a)
	w:advance(6)
	local c = customer(a, DAN)
	ok(c and DRof(a).Rank(c.state) >= DRof(a).Rank("joined"), "Dan joined")
	c.station, c.dest = SPOT, SPOT
	a = w:reload(a)
	w:advance(3)
	local c2 = customer(a, DAN)
	ok(c2, "back after the /reload")
	eq(c2.station, SPOT, "station kept")
	eq(c2.wuberLabel, "Bronze rider \194\183 3 rides", "the rider's label kept (not the dead wuberStage)")
	clean(w)
end)
