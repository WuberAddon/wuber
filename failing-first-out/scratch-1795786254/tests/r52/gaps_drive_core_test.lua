-- Final home: tests/drive/core_test.lua; add it to the per-module list in tests/run.lua.
-- Pins:
--   saved options and a character's saved settings are made sane (DR.CleanOpt, DR.InitDB, DR.char)
--   who runs the engine (DR.Role, DR.Active, DR.SetRunner, DR.Lock) and who counts as crew (IsCrewKey, TrustKey)
--   the crew list: at most 8, a rider who joins it leaves the queue, the crew rows the UI draws (DR.Crew)
--   the ritual: known, not known, and a spellbook not read yet just after login; the cooldown without the GCD
--   "Invite public chat buyers": off at once, on only through the warning, two askers share one warning
--   a /reload mid-ride brings joined riders back; an old or future snapshot is dropped
--   the old Ritual Rides settings seed reaches a new character only while fresh (90 days)
-- Why it matters to a player: broken saved data must never break the driver screen or invite a whole raid;
--   a helper without Wuber must never steer the crew; a /reload mid-ride must not forget who is owed a summon;
--   and public Trade buyers are never invited without the player saying yes to the warning.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, BEA, CAL, DAN = "Ana Smith", "Bea Jones", "Cal Brown", "Dan Miller"
local SPOT = "Undercity"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function firedOf(c, name)
	local out = {}
	for _, f in ipairs(c.fired) do if f.name == name then out[#out + 1] = f end end
	return out
end

-- a solo Warlock driver in Undercity with bots (not grouped), open when asked
local function setup(opts)
	opts = opts or {}
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", shards = opts.shards or 10, saved = opts.saved })
	for _, n in ipairs(opts.bots or {}) do w:addBot(n, { spot = "Ratchet", acceptsInvites = opts.accepts == true }) end
	w:advance(15)
	local DR = a.W.Drive
	if opts.open then
		if opts.noInvite then DR.opts().autoInvite = false end
		ok(DR.SetOpen(true), "open")
		w:advance(3)
	end
	return w, a, DR
end

-- guard: coverage, fable-2411 draft adopted in r52
test("Drive.Core: contract (registered, deps, header, public names)", function()
	local W, w = T.contract("Drive.Core", "tests/drive/core_test.lua", {
		["DR.SHARD_ITEM"] = "number", ["DR.RITUAL_ID"] = "number", ["DR.RITUAL_NAME"] = "string",
		["DR.MACRO_MAX"] = "number", ["DR.TEXT_MAX"] = "number", ["DR.CREW_MAX"] = "number",
		["DR.customers"] = "table", ["DR.units"] = "table", ["DR.peers"] = "table", ["DR.apps"] = "table",
		["DR.session"] = "table", ["DR.ignored"] = "table", ["DR.helpers"] = "table", ["DR.comm"] = "table",
		["DR.KEYWORDS"] = "table", ["DR.OPT_DEFAULTS"] = "table", ["DR.OPT_LATE"] = "table", ["DR.CHAR_KEYS"] = "table",
		["DR.PUBLIC_POPUP"] = "string", ["DR.PUBLIC_WARNING"] = "string", ["DR.on"] = "boolean",
		["DR.Opt"] = "function", ["DR.CleanOpt"] = "function", ["DR.InitDB"] = "function", ["DR.opts"] = "function",
		["DR.char"] = "function", ["DR.Changed"] = "function", ["DR.Alert"] = "function",
		["DR.SetAutoPublic"] = "function", ["DR.PlacePublicWarning"] = "function", ["DR.RestorePublicWarning"] = "function",
		["DR.Lock"] = "function", ["DR.Class"] = "function", ["DR.IsWarlock"] = "function", ["DR.InCrew"] = "function",
		["DR.Role"] = "function", ["DR.Active"] = "function", ["DR.SetRunner"] = "function", ["DR.IsRunner"] = "function",
		["DR.CaptainKey"] = "function", ["DR.Captain"] = "function", ["DR.IsCaptain"] = "function", ["DR.CrewEntry"] = "function",
		["DR.IsCrewKey"] = "function", ["DR.IsCrew"] = "function", ["DR.TrustKey"] = "function", ["DR.IsBellKey"] = "function",
		["DR.Crew"] = "function", ["DR.SetCrewMember"] = "function", ["DR.DropCrewMember"] = "function",
		["DR.AddPlainHelper"] = "function", ["DR.AddPlainSummoner"] = "function", ["DR.SummonerHasApp"] = "function",
		["DR.InRaid"] = "function", ["DR.InGroup"] = "function", ["DR.GroupSize"] = "function", ["DR.IsLeader"] = "function",
		["DR.IsLeaderKey"] = "function", ["DR.Roster"] = "function", ["DR.Visible"] = "function", ["DR.SameMap"] = "function",
		["DR.Here"] = "function", ["DR.Online"] = "function", ["DR.UnitClassKey"] = "function", ["DR.Shards"] = "function",
		["DR.Ritual"] = "function", ["DR.RitualCooldown"] = "function", ["DR.Dest"] = "function", ["DR.MaxGroup"] = "function",
		["DR.MergeRetired"] = "function", ["DR.ImportRR"] = "function", ["DR.Snapshot"] = "function", ["DR.RestoreQueue"] = "function",
	})
	local DR = W.Drive
	eq(DR.Captain, DR.CaptainKey, "DR.Captain is DR.CaptainKey") -- Core.lua:498
	eq(DR.CREW_MAX, 8)
	eq(DR.SHARD_ITEM, 6265, "Soul Shard") eq(DR.RITUAL_ID, 698) eq(DR.RITUAL_NAME, "Ritual of Summoning")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: options are made sane (CleanOpt): ranges, steps, the old 'direct' mode, keywords, junk", function()
	local W, w = T.contract("Drive.Core", "tests/drive/core_test.lua", {})
	local DR = W.Drive
	-- whisper mode: 1.x "direct" is "auto"; anything unknown is "auto"
	eq(DR.CleanOpt("whisperMode", "direct"), "auto") eq(DR.CleanOpt("whisperMode", "macro"), "macro")
	eq(DR.CleanOpt("whisperMode", "box"), "box") eq(DR.CleanOpt("whisperMode", "loud"), "auto")
	-- max group: under 3 (or junk) is "the default" (0); 3..40
	eq(DR.CleanOpt("maxGroup", 2), 0) eq(DR.CleanOpt("maxGroup", "x"), 0) eq(DR.CleanOpt("maxGroup", 3), 3)
	eq(DR.CleanOpt("maxGroup", 41), 40) eq(DR.CleanOpt("maxGroup", 10.4), 10, "rounded")
	-- the advert every 15..60 minutes, or 0 (never)
	eq(DR.CleanOpt("adEvery", 5), 15, "never more often than every 15 min") eq(DR.CleanOpt("adEvery", 0), 0, "0: no advert")
	eq(DR.CleanOpt("adEvery", 61), 60) eq(DR.CleanOpt("adEvery", 20), 20)
	eq(DR.CleanOpt("lowShards", -1), 0) eq(DR.CleanOpt("lowShards", 11), 10) eq(DR.CleanOpt("lowShards", "x"), 3, "junk: the default")
	eq(DR.CleanOpt("lowShards", 0 / 0), 3, "NaN: the default") -- Core.lua:110
	eq(DR.CleanOpt("inviteCap", 0), 1) eq(DR.CleanOpt("inviteCap", 25), 20)
	eq(DR.CleanOpt("inviteTimeout", 10), 30) eq(DR.CleanOpt("inviteTimeout", 1000), 300)
	eq(DR.CleanOpt("target", 5), 10000) eq(DR.CleanOpt("target", 1e9), 500000)
	-- booleans: only a boolean is taken
	eq(DR.CleanOpt("autoInvite", "yes"), true, "not a boolean: the default") eq(DR.CleanOpt("kickAfter", false), false)
	eq(DR.CleanOpt("showPass", "yes"), false, "a late option's default (off)") -- Core.lua:96
	-- strings: one clean line, colour bars and new lines gone
	eq(DR.CleanOpt("watchChannels", "trade|r\nworld"), "trader world") -- W.Clean: "|" dropped, new line a space
	eq(DR.CleanOpt("adChannels", 5), "services, trade, lookingforgroup", "not a string: the default")
	-- keywords: words only, lower case, at most 20 of 20 letters; none: the defaults (a copy)
	local kw = DR.CleanOpt("keywords", "Summon, PORT!! taxi")
	eq(table.concat(kw, ","), "summon,port,taxi")
	kw = DR.CleanOpt("keywords", { "Summ", "two words", 5, "a-b" })
	eq(table.concat(kw, ","), "summ,5", "a table: single words only")
	kw = DR.CleanOpt("keywords", "")
	eq(table.concat(kw, ","), table.concat(DR.KEYWORDS, ","), "none: the defaults")
	ok(kw ~= DR.KEYWORDS, "a copy, never the shared list")
	local many = {}
	for i = 1, 30 do many[i] = "w" .. i end
	eq(#DR.CleanOpt("keywords", many), 20, "at most 20")
	eq(DR.CleanOpt("keywords", { string.rep("a", 30) })[1], string.rep("a", 20), "cut to 20 letters")
	-- not an option
	eq(DR.CleanOpt("bogus", 1), nil)
	-- DR.Opt: a late option not saved reads its default; saved, the saved value
	eq(DR.Opt("shareNotes"), true) eq(W.db.drive.opts.shareNotes, nil, "the default is not written")
	W.db.drive.opts.shareNotes = false
	eq(DR.Opt("shareNotes"), false)
	W.db.drive.opts.shareNotes = nil
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: broken saved driver data is repaired at login; good values stay", function()
	local w, a, DR = setup({ saved = { Wuber = { drive = {
		opts = { maxGroup = 99, adEvery = 1, whisperMode = "direct", keywords = "", autoInvite = "yes", lowShards = 4,
			target = 200000, watchChannels = 5 },
		log = "junk", stats = { rides = "x", copper = 5 }, bell = { name = 7, team = "x" },
		button = { scale = "big", locked = "no" }, blocklist = 3, templates = { greet = "Hi {name}" },
	} } } })
	local d = a.W.db.drive
	eq(d.v, 1)
	eq(d.opts.maxGroup, 40, "99 is 40 at most") -- Core.lua:136-139
	eq(d.opts.adEvery, 15, "every minute is every 15")
	eq(d.opts.whisperMode, "auto", "the old direct mode")
	eq(#d.opts.keywords, #DR.KEYWORDS, "no keywords: the defaults")
	eq(d.opts.autoInvite, true, "a string is no boolean: the default")
	eq(d.opts.lowShards, 4, "a good value stays") eq(d.opts.target, 200000, "a good value stays")
	eq(d.opts.watchChannels, DR.OPT_DEFAULTS.watchChannels, "not a string: the default")
	eq(d.opts.autoReply, true, "a missing option gets its default") -- Core.lua:73
	eq(d.opts.cutRule, nil, "a late option is never written by InitDB") -- Core.lua:96
	eq(type(d.log), "table", "the log is a table again") eq(d.log.v, 1)
	for _, k in ipairs({ "rides", "team", "asks", "open", "seen", "wreq", "wdec", "rivals" }) do eq(type(d.log[k]), "table", "log." .. k) end
	eq(d.stats.rides, 0, "junk count: 0") eq(d.stats.copper, 5, "a number stays") eq(d.stats.tips, 0)
	eq(d.bell.name, "", "a number is no name") eq(type(d.bell.team), "table")
	eq(d.button.scale, 1, "junk scale: 1") eq(d.button.locked, false, "junk: false")
	eq(type(d.blocklist), "table", "the blocklist is a table again")
	eq(d.templates.greet, "Hi {name}", "the templates stay")
	-- the driver screen still works on it
	eq(DR.MaxGroup(), 40, "the repaired setting is the one used")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: a character's saved crew, price and mode are made sane (DR.char)", function()
	local W, w = T.contract("Drive.Core", "tests/drive/core_test.lua", {})
	local DR = W.Drive
	local c = W.Char()
	c.price, c.mode, c.captain, c.summoners, c.stations = 100, "taxi", 7, "x", false
	c.crew = { "junk", { role = "lock" }, { name = BEA, role = "mage", app = "yes" }, { name = CAL, role = "lock", app = false } }
	local ch = DR.char()
	eq(ch.price, W.MIN_PRICE, "under the lowest fare: the lowest fare") -- Core.lua:381
	eq(ch.mode, "sell", "an unknown mode: selling")
	eq(ch.captain, "", "a number is no captain: I lead")
	eq(type(ch.summoners), "table") eq(type(ch.stations), "table")
	eq(#ch.crew, 2, "the entries without a name are dropped")
	eq(ch.crew[1].name, BEA) eq(ch.crew[1].role, "helper", "an unknown role: helper") eq(ch.crew[1].app, true, "app: anything but false")
	eq(ch.crew[2].name, CAL) eq(ch.crew[2].role, "lock") eq(ch.crew[2].app, false, "a plain helper stays one")
	-- more than 8: the first 8 are kept
	local crew = {}
	for i = 1, 10 do crew[i] = { name = "Crew " .. string.char(64 + i) .. "x", role = "lock", app = true } end
	c.crew = crew
	eq(#DR.char().crew, 8, "at most 8 beside the captain") -- Core.lua:362, 372
	eq(DR.char().crew[1].name, "Crew Ax", "in their order")
	c.crew = {}
	eq(DR.Role(), nil, "a Mage with no crew runs nothing")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: who runs the engine: a rider, a helper, a runner, an alert character, a third party", function()
	local W, w = T.contract("Drive.Core", "tests/drive/core_test.lua", {})
	local DR = W.Drive
	eq(DR.IsWarlock(), false, "the contract rider is a Mage")
	eq(DR.Role(), nil) eq(DR.Active(), false) eq(DR.IsRunner(), false) eq(DR.InCrew(), false)
	eq(DR.IsCaptain(), true, "nobody else leads") eq(DR.CaptainKey(), W.myKey)
	-- in someone's crew: a helper, and the engine runs
	DR.char().captain = ANA
	eq(DR.Role(), "helper") eq(DR.Active(), true) eq(DR.InCrew(), true)
	eq(DR.IsCaptain(), false) eq(DR.CaptainKey(), key(ANA)) eq(DR.IsRunner(), false)
	ok(DR.IsCrewKey(key(ANA)), "my captain counts as crew")
	-- runs the service: out of the crew, the captain of its own
	eq(DR.SetRunner(true), true)
	eq(DR.char().captain, "", "running the service leaves the crew") -- Core.lua:475
	eq(DR.Role(), "driver") eq(DR.IsRunner(), true) eq(DR.IsCaptain(), true)
	eq(DR.SetRunner(false), false)
	eq(DR.Role(), nil, "back to a rider")
	-- heard a crew's alert only
	DR.db.bell.team = { key(ANA) }
	eq(DR.Role(), "alert") eq(DR.Active(), false, "an alert character runs no engine") -- Core.lua:458, 466
	DR.db.bell.team = {}
	-- a third-party summoning addon takes the lock
	W.provider = {}
	eq(DR.Lock(), "provider")
	DR.char().captain = ANA
	eq(DR.Active(), false, "locked: never active")
	DR.char().captain = ""
	W.provider = nil
	eq(DR.Lock(), nil)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: an old Ritual Rides still driving locks the engine off; a Warlock is always a driver", function()
	local w = H.NewWorld({})
	local a = T.driver(w, ANA, { spot = SPOT, lockEngine = true })
	T.settle(w)
	local DR = a.W.Drive
	eq(DR.Lock(), "rr", "the old addon drives") -- Core.lua:419-429, 1315
	eq(DR.Role(), "driver", "a Warlock")
	eq(DR.Active(), false, "but the engine does not run")
	eq(DR.on, false, "nothing of the engine started") -- Core.lua:1320
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: crew by full name only; a helper without Wuber is crew but never trusted over the wire", function()
	local w, a, DR = setup({ bots = { BEA, CAL } })
	local me = a.W.myKey
	ok(DR.AddPlainHelper(BEA), "Bea added as a plain helper")
	ok(DR.SetCrewMember(CAL, "lock", true), "Cal added with Wuber")
	eq(DR.CrewEntry(key(BEA)).app, false, "Bea has no Wuber")
	eq(DR.CrewEntry(key(BEA)).role, "helper")
	ok(DR.IsCrewKey(key(BEA)) and DR.IsCrewKey(key(CAL)), "both are crew")
	eq(DR.TrustKey(key(BEA)), false, "Bea's word never counts over the wire") -- Core.lua:523-527
	eq(DR.TrustKey(key(CAL)), true, "Cal's does")
	eq(DR.IsCrewKey("cal"), false, "a first name alone is nobody")
	eq(DR.IsCrew(CAL), true) eq(DR.IsCrew("Cal-Brown"), true, "the other spelling of the name")
	eq(DR.IsCrewKey(me), true, "I am crew") eq(DR.TrustKey(me), false, "but never trusted as a sender")
	eq(DR.IsCrewKey(nil), false) eq(DR.TrustKey(nil), false)
	-- who can be called through the app
	eq(DR.SummonerHasApp(me), true) eq(DR.SummonerHasApp(key(BEA)), false) eq(DR.SummonerHasApp(key(CAL)), true)
	eq(DR.SummonerHasApp(nil), false) eq(DR.SummonerHasApp("zed moss"), false, "not crew, never heard")
	DR.peers["zed moss"] = { name = "Zed Moss", at = a.env.GetTime() }
	eq(DR.SummonerHasApp("zed moss"), true, "heard on the wire: runs Wuber") -- Core.lua:571
	DR.peers["zed moss"] = nil
	-- no name, no helper
	eq(DR.AddPlainHelper(""), nil)
	eq(DR.AddPlainHelper(nil), nil)
	-- dropping
	eq(DR.DropCrewMember(key(BEA)), true)
	eq(DR.CrewEntry(key(BEA)), nil)
	eq(DR.IsCrewKey(key(BEA)), false, "out of the crew")
	eq(DR.DropCrewMember(key(BEA)), false, "a second drop finds nobody")
	T.clean(w)
end)

local EXTRA = { "Eve Stone", "Fay Wood", "Gil Moss", "Hal Reed", "Ivy Lane", "Jon Hart", "Kit Vale", "Lou Park" }

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: a queued rider who joins the crew leaves the queue; the crew holds 8 beside the captain", function()
	local bots = { DAN }
	for _, n in ipairs(EXTRA) do bots[#bots + 1] = n end
	local w, a, DR = setup({ bots = bots, open = true, noInvite = true })
	w:botWhisper(DAN, a, "summon pls")
	w:advance(1)
	local cust = DR.customers[key(DAN)]
	ok(cust, "Dan is queued")
	local before = #firedOf(a, "DRIVE_REMOVED")
	ok(DR.SetCrewMember(DAN, "lock", true), "Dan joins the crew")
	eq(DR.customers[key(DAN)], nil, "a crew member is never a customer") -- Core.lua:620-625
	local rem = firedOf(a, "DRIVE_REMOVED")
	eq(#rem, before + 1, "one DRIVE_REMOVED")
	ok(rem[#rem].args[1] == cust, "about Dan's row")
	eq(rem[#rem].args[2], "crew", "the reason")
	-- 7 more fill the crew to 8
	for i = 1, 7 do ok(DR.SetCrewMember(EXTRA[i], "lock", true), EXTRA[i] .. " added") end
	eq(#DR.char().crew, 8)
	eq(DR.SetCrewMember(EXTRA[8], "lock", true), nil, "a ninth is refused") -- Core.lua:613
	eq(#DR.char().crew, 8)
	eq(DR.CrewEntry(key(EXTRA[8])), nil)
	-- myself: never
	eq(DR.SetCrewMember(ANA, "lock", true), nil)
	-- an update keeps one entry; only "lock" is a summoner
	ok(DR.SetCrewMember(DAN, "L", false), "Dan updated")
	eq(#DR.char().crew, 8, "still 8")
	eq(DR.CrewEntry(key(DAN)).role, "helper", "\"L\" here is no summoner (AddPlainHelper maps it)") -- Core.lua:617
	eq(DR.CrewEntry(key(DAN)).app, false)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: the crew as the UI shows it: me first, who was heard, who went silent, shards only for summoners", function()
	local saved = { Wuber = { chars = { [key(ANA)] = { captain = "", wizard = true,
		crew = { { name = BEA, role = "lock", app = true }, { name = CAL, role = "helper", app = false } } } } } }
	local w, a, DR = setup({ saved = saved, bots = { BEA, CAL }, shards = 10 })
	local now = a.env.GetTime()
	DR.peers[key(BEA)] = { name = BEA, role = "L", shards = 7, at = now }
	local rows = DR.Crew()
	eq(#rows, 3, "me and two")
	local me = rows[1]
	eq(me.me, true) eq(me.key, key(ANA)) eq(me.role, "lock", "a Warlock") eq(me.captain, true)
	eq(me.shards, 10, "my own Soul Shards") eq(me.silent, false) eq(me.here, true)
	local bea, cal = rows[2], rows[3]
	eq(bea.name, BEA) eq(bea.role, "lock") eq(bea.heard, true) eq(bea.silent, false) eq(bea.shards, 7)
	eq(bea.here, false, "not in my group") eq(bea.captain, false) eq(bea.app, true)
	eq(cal.name, CAL) eq(cal.heard, false) eq(cal.silent, true, "never heard: silent") eq(cal.shards, nil, "a helper has no shards shown")
	eq(cal.app, false) eq(cal.role, "helper")
	-- not heard for over 45 s: silent
	DR.peers[key(BEA)].at = now - 46
	eq(DR.Crew()[2].silent, true) -- Core.lua:560
	-- what Bea's window says wins over my list: a helper, no shards shown
	DR.peers[key(BEA)].at, DR.peers[key(BEA)].role = now, "H"
	eq(DR.Crew()[2].role, "helper") eq(DR.Crew()[2].shards, nil)
	-- an unknown count (-1) is not shown
	DR.peers[key(BEA)].role, DR.peers[key(BEA)].shards = "L", -1
	eq(DR.Crew()[2].shards, nil) -- Core.lua:559
	DR.peers[key(BEA)] = nil
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: the group size: a party for a small crew, a raid of 10 from three, the setting wins up to 40", function()
	local w, a, DR = setup({ bots = { BEA, CAL } })
	DR.opts().maxGroup = 0
	eq(DR.MaxGroup(), 5, "alone: a party") -- Core.lua:866
	DR.SetCrewMember(BEA, "lock", true)
	eq(DR.MaxGroup(), 5, "two of us: a party")
	DR.SetCrewMember(CAL, "lock", true)
	eq(DR.MaxGroup(), 10, "three of us: a raid of 10")
	DR.opts().maxGroup = 25
	eq(DR.MaxGroup(), 25, "the player's setting")
	DR.opts().maxGroup = 99
	eq(DR.MaxGroup(), 40, "never over a raid of 40")
	DR.opts().maxGroup = 2
	eq(DR.MaxGroup(), 10, "under 3: the default")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: the ritual: known, a custom name that isn't, and a spellbook not read yet just after login", function()
	local w, a, DR = setup({})
	local name, known, doubt = DR.Ritual()
	eq(name, "Ritual of Summoning") eq(known, true) eq(doubt, nil)
	DR.opts().ritual = "Ritual of Doom"
	name, known = DR.Ritual()
	eq(name, "Ritual of Summoning", "a custom name the book doesn't know: the known spell") eq(known, true)
	DR.opts().ritual = ""
	-- a Warlock who never learnt it, with a readable book: a plain "no"
	local b = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", knowsRitual = false })
	w:advance(1)
	name, known, doubt = b.W.Drive.Ritual()
	eq(name, "Ritual of Summoning") eq(known, false) eq(doubt, nil, "the book reads: the no is believed") -- Core.lua:781-790
	b.W.Drive.opts().ritual = "My Ritual"
	eq((b.W.Drive.Ritual()), "My Ritual", "nothing known: the player's own name for /cast")
	-- a spellbook the game has not loaded yet: "not sure yet" for up to 10 s
	local c = w:addClient(CAL, { spot = SPOT, class = "WARLOCK", spellbookLate = 8 })
	w:advance(1)
	name, known, doubt = c.W.Drive.Ritual()
	eq(known, false) eq(doubt, true, "too early to trust the no") -- Core.lua:806
	w:advance(10)
	name, known, doubt = c.W.Drive.Ritual()
	eq(known, true, "the book is read: known") eq(doubt, nil)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: the ritual cooldown counts the real cooldown, never the global one", function()
	local w, a, DR = setup({})
	local p = w:player(ANA)
	eq(DR.RitualCooldown(), 0, "ready")
	p.cooldownUntil = w.time + 60
	local cd = DR.RitualCooldown()
	ok(cd > 59.5 and cd <= 60, "about a minute: " .. tostring(cd))
	p.cooldownUntil = w.time + 1
	eq(DR.RitualCooldown(), 0, "1.5 s or less is the global cooldown: ready") -- Core.lua:843
	p.cooldownUntil = nil
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: Soul Shards: the bag count; the test mode's hook, and a broken hook falls back to the bag", function()
	local w, a, DR = setup({ shards = 4 })
	eq(DR.Shards(), 4)
	DR.SimHooks = { shards = function() return 99 end }
	eq(DR.Shards(), 99, "the test mode's count")
	DR.SimHooks = { shards = function() error("broken hook") end }
	eq(DR.Shards(), 4, "a hook that errors: the real count") -- Core.lua:744-748
	DR.SimHooks = { shards = function() return "lots" end }
	eq(DR.Shards(), 4, "a hook that gives no number: the real count")
	DR.SimHooks = nil
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: alerts carry their kind (info by default); many changes make one redraw", function()
	local W, w, r = T.contract("Drive.Core", "tests/drive/core_test.lua", {})
	local DR = W.Drive
	DR.Alert("Low on Soul Shards")
	local al = firedOf(r, "DRIVE_ALERT")
	local last = al[#al]
	eq(last.args[1], "Low on Soul Shards") eq(last.args[2], "info", "the default kind") eq(last.args[3], nil)
	DR.Alert("Raincheck owed", "raincheck", { rideId = "r1", name = DAN })
	al = firedOf(r, "DRIVE_ALERT")
	last = al[#al]
	eq(last.args[2], "raincheck") eq(last.args[3] and last.args[3].rideId, "r1", "the data for the toast's click")
	-- three changes in one frame: one DRIVE, a moment later
	w:advance(2)
	local before = #firedOf(r, "DRIVE")
	DR.Changed() DR.Changed() DR.Changed()
	eq(#firedOf(r, "DRIVE"), before, "nothing at once") -- Core.lua:397
	w:advance(0.1)
	eq(#firedOf(r, "DRIVE"), before + 1, "one redraw for three changes")
	T.clean(w)
end)

-- the warning on screen, answered as its buttons do (tests/drive/queue_test.lua, answer)
local function answerWarning(c, yes)
	local which = c.W.Drive.PUBLIC_POPUP
	ok(c.env.StaticPopup_FindVisible(which), "the warning is on screen")
	local dlg = c.env.StaticPopupDialogs[which]
	c.env.StaticPopup_Hide(which)
	if yes then dlg.OnAccept() else dlg.OnCancel() end
end

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: public chat buyers: off at once; two askers share one warning; Cancel and a full popup list leave it off", function()
	local w, a, DR = setup({})
	local heard = {}
	local function cb(tag) return function(v) heard[#heard + 1] = tag .. "=" .. tostring(v) end end
	-- off: at once, and marked the player's own choice
	eq(DR.SetAutoPublic(false, cb("off")), false)
	eq(table.concat(heard, ","), "off=false")
	eq(DR.opts().autoPublic, false) eq(a.W.db.drive.publicChosen, true) -- Core.lua:302
	-- on: the warning; asked again while it is up (Settings, then the slash command): the same question
	heard = {}
	eq(DR.SetAutoPublic(true, cb("settings")), "asked")
	eq(DR.SetAutoPublic(true, cb("slash")), "asked", "the second asker waits on the same warning") -- Core.lua:323-326
	eq(#heard, 0, "nobody told anything before the answer")
	eq(DR.opts().autoPublic, false, "still off while asked")
	answerWarning(a, true)
	eq(table.concat(heard, ","), "settings=true,slash=true", "Yes answers both")
	eq(DR.opts().autoPublic, true)
	-- already on: no warning again
	heard = {}
	eq(DR.SetAutoPublic(true, cb("again")), true)
	eq(table.concat(heard, ","), "again=true")
	ok(not a.env.StaticPopup_FindVisible(DR.PUBLIC_POPUP), "no warning shown")
	-- Cancel: stays off
	DR.SetAutoPublic(false)
	heard = {}
	eq(DR.SetAutoPublic(true, cb("cancel")), "asked")
	answerWarning(a, false)
	eq(table.concat(heard, ","), "cancel=false") eq(DR.opts().autoPublic, false)
	-- every popup slot taken: the game shows nothing and returns nil; it stays off and nobody waits
	local show = a.env.StaticPopup_Show
	a.env.StaticPopup_Show = function() return nil end
	heard = {}
	eq(DR.SetAutoPublic(true, cb("full")), nil, "can't be asked") -- Core.lua:345-346
	eq(DR.opts().autoPublic, false) eq(#heard, 0)
	a.env.StaticPopup_Show = show
	eq(DR.SetAutoPublic(true, cb("later")), "asked", "asked properly the next time")
	answerWarning(a, true)
	eq(table.concat(heard, ","), "later=true", "the refused asker is not told twice")
	DR.SetAutoPublic(false)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: the public warning is left where the game put it without an open phone", function()
	local W, w, r = T.contract("Drive.Core", "tests/drive/core_test.lua", {})
	local DR = W.Drive
	eq(DR.RestorePublicWarning(nil), false) eq(DR.RestorePublicWarning({}), false, "nothing of ours to put back")
	eq(DR.PlacePublicWarning(nil), false)
	local phone = r.env.WuberFrame
	ok(not (phone and phone:IsShown()), "the phone is closed")
	local pop = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	eq(DR.PlacePublicWarning(pop), false, "no phone: not moved") -- Core.lua:256-260
	eq(pop.wuberPublicOrig, nil, "nothing changed on the game's popup")
	T.clean(w)
end)
-- NEEDS FAKE-GAME (check first): a fake FontString with GetFont / SetFont / GetStringHeight on the game's popup,
-- to pin the 2.3.3 H2 fix: with the phone open the warning is centred on it, scaled to the phone's effective
-- scale, fully opaque over its own backdrop, and RestorePublicWarning puts scale, alpha and font back.
-- test("drive.core: the public warning sits on the open phone at the phone's scale, and is put back on hide", function()
-- 	local w, a, DR = setup({})
-- 	T.needUI(a) a.W.UI.Toggle(true) w:advance(2.5)
-- 	local pop = a.env.CreateFrame("Frame", nil, a.env.UIParent)
-- 	pop.text = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
-- 	pop:SetScale(1) pop:SetAlpha(0.6)
-- 	eq(DR.PlacePublicWarning(pop), true)
-- 	eq(pop:GetAlpha(), 1) ok(pop.wuberBack and pop.wuberBack:IsShown())
-- 	eq(DR.RestorePublicWarning(pop), true)
-- 	eq(pop:GetAlpha(), 0.6) eq(pop:GetScale(), 1) ok(not pop.wuberBack:IsShown())
-- 	T.clean(w)
-- end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: a /reload mid-ride brings a joined rider back; a snapshot over 10 minutes old, or from the future, is dropped", function()
	local w, a, DR = setup({ bots = { DAN }, accepts = true, open = true })
	w:botWhisper(DAN, a, "summon pls")
	w:advance(4)
	local dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "joined", "Dan joined the group")
	DR.Snapshot()
	local q = a.W.Char().queue
	ok(q and type(q.list) == "table", "a snapshot is saved")
	local row
	for _, s in ipairs(q.list) do if s.key == key(DAN) then row = s end end
	ok(row and row.state == "joined", "Dan's row is in it")
	-- the /reload (PLAYER_LOGOUT saves it again; the new window reads it at login)
	a = w:reload(a)
	w:advance(3)
	DR = a.W.Drive
	dan = DR.customers[key(DAN)]
	ok(dan, "Dan is on the list again")
	ok(DR.Rank(dan.state) >= DR.Rank("joined"), "still at least joined: " .. tostring(dan and dan.state))
	eq(a.W.Char().queue, nil, "the snapshot is used once") -- Core.lua:1248
	-- a snapshot from the future (the clock went back): dropped
	DR.Snapshot()
	q = a.W.Char().queue
	q.at = q.at + 60
	DR.customers[key(DAN)] = nil
	DR.RestoreQueue()
	eq(DR.customers[key(DAN)], nil, "not restored") -- Core.lua:1252
	eq(a.W.Char().queue, nil, "and gone")
	-- over 10 minutes old: dropped
	DR.customers[key(DAN)] = dan
	DR.Snapshot()
	q = a.W.Char().queue
	q.at = q.at - 601
	DR.customers[key(DAN)] = nil
	DR.RestoreQueue()
	eq(DR.customers[key(DAN)], nil, "too old to trust")
	DR.customers[key(DAN)] = dan
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: the old addon's kept settings reach a character that never imported, only within 90 days", function()
	local function seeded(at, char)
		local s = { Wuber = { drive = { imported = { at = H.EPOCH, from = "1.4.1", retiredMerge = H.EPOCH,
			charSeed = { price = 77777, service = "Giga Rides", team = {}, at = at } } } } }
		if char then s.Wuber.chars = { [key(char.name)] = char.data } end
		return s
	end
	local w = H.NewWorld({})
	local old = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = seeded(H.EPOCH - 91 * 86400) })
	local fresh = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", saved = seeded(H.EPOCH) })
	local done = w:addClient(CAL, { spot = SPOT, class = "WARLOCK", saved = seeded(H.EPOCH, { name = CAL, data = { rrChar = true } }) })
	T.settle(w)
	ok(old.W.Char().price ~= 77777, "a seed over 90 days old is not used") -- Core.lua:1132, 1151
	ok(old.W.Char().rrChar ~= true, "and the character is not marked imported")
	eq(fresh.W.Char().price, 77777, "a fresh seed: the old price")
	eq(fresh.W.Char().service, "Giga Rides", "and the old service name")
	eq(fresh.W.Char().rrChar, true, "imported once")
	eq(done.W.Char().price, 5000, "a character that imported before keeps its own") -- Core.lua:1164
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: the old addon's team: first names are left out with a note; no caster: the first by name leads", function()
	local w = H.NewWorld({})
	local rr = { price = 50000, service = "", dest = "", caster = "", team = { ANA, BEA, "Bob", "Cid" },
		blocklist = {}, log = { v = 1, rides = {}, asks = {}, open = {}, seen = {}, wreq = {}, wdec = {}, rivals = {} },
		stats = { rides = 0, copper = 0 }, setupSeen = true }
	local b = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", loadRR = "tombstone", saved = { RitualRides = rr } })
	T.settle(w)
	local DR = b.W.Drive
	eq(DR.Lock(), nil, "the old addon is retired: no lock")
	local ch = DR.char()
	eq(#ch.crew, 1, "Ana only: me and the first names are left out") -- Core.lua:1009-1011, 1051
	eq(ch.crew[1] and ch.crew[1].name, ANA)
	eq(ch.caster, "-", "the old \"anyone\" caster is Wuber's \"-\"") -- Core.lua:1040
	eq(ch.captain, ANA, "no caster: the first of us by name (ana < bea) leads") -- Core.lua:1079-1083
	eq(ch.wizard, true)
	local note = false
	for _, t in ipairs(b.chatLines or {}) do
		if tostring(t):find("had 2 first names only: left out.", 1, true) then note = true end
	end
	ok(note, "the player is told about the 2 first names") -- Core.lua:1054
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.core: the place said, and the crew's alert character", function()
	local W, w = T.contract("Drive.Core", "tests/drive/core_test.lua", {})
	local DR = W.Drive
	DR.char().dest = "Booty Bay"
	eq(DR.Dest(), "Booty Bay", "the set place")
	DR.char().dest = ""
	local here = DR.Dest()
	ok(type(here) == "string" and here ~= "", "no set place: where I stand (or \"our spot\"): " .. tostring(here)) -- Core.lua:852-858
	DR.db.bell.name = "Wuber Rocks"
	eq(DR.IsBellKey("wuber rocks"), true) eq(DR.IsBellKey("wuber"), false) eq(DR.IsBellKey(nil), false)
	DR.db.bell.name = ""
	eq(DR.IsBellKey(""), false, "no alert character set")
	T.clean(w)
end)
