-- Tests of Net.Portal. Loaded by tests/run.lua with its helper table T.
-- Kind G (the live portal tracker's wire), the passphrase, the founder's gold portal check.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA, TESTCHAR, BOB = T.ANITA, T.TESTCHAR, T.BOB

test("net.portal: contract (registered, deps, header, public names); idle with no ride", function()
	local W, w, r, Mod = T.contract("Net.Portal", "tests/net/portal_test.lua", {
		["W.FounderSummon"] = "function",
		["W.Passphrase"] = "function",
		["W.SendRitual"] = "function",
		["W.PASS_WORDS"] = "table",
		["Mod.heard"] = "function",
	})
	ok(Mod, "W.Mod(\"Net.Portal\")")
	local sent = #w.addonLog
	eq(W.SendRitual("rIdAbc", "Wuber TestCharacter", "c", 0, 2, "Anita Lift", 0), false, "no 2.3.0 R from them: nothing sent")
	eq(#w.addonLog, sent, "no addon message")
	eq(W.FounderSummon(nil), false, "no ride: violet")
	eq(W.FounderSummon({ driverKey = "anita lift" }), false, "not in my group: violet")
	eq(W.ride, nil, "no ride")
	T.clean(w)
end)

-- a Net-only driver (Anita), a rider (Wuber) on `ver`, a ride requested and accepted
local function rideUp(ver, opts)
	opts = opts or {}
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { netOnly = true })
	local r = T.rider(w)
	if ver then r.W.VERSION = ver end
	T.settle(w)
	T.goOnline(d)
	local ride = r.W.RequestRide("anita lift")
	ok(ride, "a ride")
	w:advance(1)
	if not opts.noAccept then
		ok(d.W.AcceptRequest(ride.id, 5), "accepted")
		w:advance(1)
	end
	return w, d, r, ride
end

local function gs(w)
	local out = {}
	for _, e in ipairs(T.msgs(w, "G", ANITA)) do out[#out + 1] = e.text end
	return out
end

test("net.portal: G end to end: R field 6 from a 2.3.0 rider, phases believed, RITUAL fired", function()
	local w, d, r, ride = rideUp("2.3.0")
	local R = T.msgs(w, "R", TESTCHAR)[1]
	local f = T.fields(R)
	eq(f[8], "2.3.0", "R field 6 = the rider's version")
	eq(f[9], nil, "no raincheck: field 7 absent")
	eq(d.W.incoming[1].riderVer, "2.3.0", "the driver keeps the rider's version")
	local heard = {}
	r.W.Listen("RITUAL", function(rit, rr) heard[#heard + 1] = rit.phase .. ":" .. tostring(rr == r.W.ride) end)
	eq(d.W.SendRitual(ride.id, TESTCHAR, "t", 0, 2, ANITA, 0), true, "t sent")
	w:advance(1)
	eq(#gs(w), 1, "one G")
	eq(gs(w)[1], "G~1~" .. ride.id .. "~t~0~2~Anita Lift~0", "the G's fields")
	eq(r.W.ride.ritual.phase, "t", "the rider's W.ride.ritual")
	eq(r.W.ride.ritual.need, 2, "need")
	eq(r.W.ride.ritual.casterKey, "anita lift", "caster")
	eq(heard[1], "t:true", "RITUAL(ritual, ride)")
	-- unchanged: nothing sent
	w:advance(2)
	eq(d.W.SendRitual(ride.id, TESTCHAR, "t", 0, 2, ANITA, 0), false, "no change, no G")
	-- 1.5 s apart: c then h at once -> h waits and replaces c
	eq(d.W.SendRitual(ride.id, TESTCHAR, "c", 0, 2, ANITA, 1), true, "c sent")
	eq(d.W.SendRitual(ride.id, TESTCHAR, "c", 1, 2, ANITA, 1), true, "c 1/2 waits")
	eq(d.W.SendRitual(ride.id, TESTCHAR, "h", 1, 2, ANITA, 1), true, "h replaces it")
	w:advance(0.5)
	eq(#gs(w), 2, "the second waits for its 1.5 s")
	w:advance(1.5)
	eq(#gs(w), 3, "then one more")
	ok(gs(w)[3]:find("~h~1~2~Anita Lift~1$"), "the newest went: " .. gs(w)[3])
	eq(r.W.ride.ritual.danger, 1, "danger carried")
	-- s goes at once even within 1.5 s
	eq(d.W.SendRitual(ride.id, TESTCHAR, "s", 2, 2, ANITA, 1), true, "s at once")
	w:advance(0.2)
	eq(#gs(w), 4, "s is never held back")
	eq(r.W.ride.ritual.phase, "s", "summon sent")
	eq(#heard, 4, "RITUAL per G")
	T.clean(w)
end)

test("net.portal: G caps: 15 per ride; a 24-byte caster keeps G under 45 bytes", function()
	local w, d, r, ride = rideUp("2.3.0")
	local n = 0
	for i = 1, 20 do
		if d.W.SendRitual(ride.id, TESTCHAR, (i % 2 == 0) and "c" or "f", i % 10, 2, "Bartholomewsy Longsurnamex", 2) then n = n + 1 end
		w:advance(2)
	end
	eq(#gs(w), 15, "at most 15 G per ride")
	eq(n, 15, "the 16th and later refused")
	for _, t in ipairs(gs(w)) do ok(#t <= 45, "G <= 45 bytes: " .. #t .. " " .. t) end
	T.clean(w)
end)

test("net.portal: no G to an old rider (no R field 6) or a 2.2 one; the R of a 2.2.3 rider is unchanged", function()
	local w, d, r, ride = rideUp(nil) -- this build's W.VERSION (2.2.3 until the release)
	local f = T.fields(T.msgs(w, "R", TESTCHAR)[1])
	if not r.W.VerAtLeast(r.W.VERSION, "2.3.0") then
		eq(#f, 7, "R as before: id, dest, price, tier, rides")
		eq(d.W.SendRitual(ride.id, TESTCHAR, "c", 0, 2, ANITA, 0), false, "an old rider gets no G")
		w:advance(2)
		eq(#gs(w), 0, "no G sent")
	end
	-- a rider saying 2.2.9 in field 6
	w:inject(BOB, "R~1~AbCdEf~Ratchet~5000~0~1~2.2.9", "WHISPER", d)
	w:advance(1)
	eq(d.W.SendRitual("AbCdEf", BOB, "c", 0, 2, ANITA, 0), false, "2.2.9: no G")
	-- a 2.3.1 rider: yes
	w:inject(T.CAL, "R~1~XyZxyZ~Ratchet~5000~0~1~2.3.1", "WHISPER", d)
	w:advance(1)
	eq(d.W.SendRitual("XyZxyZ", T.CAL, "c", 0, 2, ANITA, 0), true, "2.3.1: G")
	eq(d.W.SendRitual("XyZxyZ", BOB, "c", 0, 2, ANITA, 0), false, "never to another rider under that ride id")
	T.clean(w)
end)

test("net.portal: the rider believes G only from its driver, with its ride id, after the A", function()
	local w, d, r, ride = rideUp("2.3.0", { noAccept = true })
	w:inject(ANITA, "G~1~" .. ride.id .. "~c~0~2~Anita Lift~0", "WHISPER", r)
	eq(r.W.ride.ritual, nil, "before the A: ignored")
	d.W.AcceptRequest(ride.id, 5)
	w:advance(1)
	w:inject(BOB, "G~1~" .. ride.id .. "~c~0~2~Bob Stone~0", "WHISPER", r)
	eq(r.W.ride.ritual, nil, "a stranger's G: ignored")
	w:inject(ANITA, "G~1~ZZZZZZ~c~0~2~Anita Lift~0", "WHISPER", r)
	eq(r.W.ride.ritual, nil, "another ride id: ignored")
	w:inject(ANITA, "G~1~" .. ride.id .. "~x~0~2~Anita Lift~0", "WHISPER", r)
	eq(r.W.ride.ritual, nil, "a phase that doesn't exist: ignored")
	w:inject(ANITA, "G~1~" .. ride.id .. "~c~0~2~Anita Lift~0", "CHANNEL")
	eq(r.W.ride.ritual, nil, "over the channel: ignored")
	w:inject(ANITA, "G~1~" .. ride.id .. "~h~99~77~Anita Lift~9", "WHISPER", r)
	ok(r.W.ride.ritual, "the driver's G")
	eq(r.W.ride.ritual.tapped, 9, "tapped clamped")
	eq(r.W.ride.ritual.need, 9, "need clamped")
	eq(r.W.ride.ritual.danger, 2, "danger clamped")
	ok(r.W.db.ride and r.W.db.ride.ritual == nil, "never saved (session only)")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- The passphrase
---------------------------------------------------------------------------

-- the spec's hash, written again here
local function words(PW, id, key)
	local s, h = id .. "|" .. key, 0
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
	return PW.adj[h % 64 + 1] .. " " .. PW.noun[math.floor(h / 64) % 64 + 1]
end

test("net.portal: passphrase: the spec's hash; the same words both sides for 100 ids; riders differ", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA)
	local r = T.rider(w)
	local PW = r.W.PASS_WORDS
	local same, differ = 0, 0
	math.randomseed(7)
	for i = 1, 100 do
		local id = r.W.NewRideId()
		local a = r.W.Passphrase(id, "Wuber TestCharacter")
		eq(d.W.Passphrase(id, "wuber testcharacter"), a, "both sides: " .. id)
		eq(a, words(PW, id, "wuber testcharacter"), "the hash in SPEC7 5.7")
		if a == r.W.Passphrase(id, "Wuber TestCharacter") then same = same + 1 end
		if r.W.Passphrase(id, "Ana Smith") ~= a then differ = differ + 1 end
	end
	eq(same, 100, "stable")
	ok(differ >= 95, "different riders get different words: " .. differ)
	eq(r.W.Passphrase("AbCdEf", "Wuber TestCharacter"), words(PW, "AbCdEf", "wuber testcharacter"), "a fixed id")
	eq(r.W.Passphrase(nil, "Wuber TestCharacter"), nil, "no ride id")
	eq(r.W.Passphrase("AbCdEf", nil), nil, "no rider")
	-- D's rows key the rider by W.Key(c.wuberBuyer or c.name), the rider by W.myKey: every
	-- spelling of one player (a realm, a hyphen, capitals) gives the same words
	local mine = r.W.Passphrase("AbCdEf", r.W.myKey)
	eq(r.W.myKey, "wuber testcharacter", "the rider's key")
	for _, who in ipairs({ "Wuber TestCharacter", "Wuber-TestCharacter", "WUBER TESTCHARACTER", "Wuber TestCharacter-CAMWOW EU4 Realm 5", r.W.Key("Wuber TestCharacter") }) do
		eq(d.W.Passphrase("AbCdEf", d.W.Key(who)), mine, "driver side, " .. who)
		eq(d.W.Passphrase("AbCdEf", who), mine, "driver side (a name), " .. who)
	end
	T.clean(w)
end)

test("net.portal: passphrase words: 64 + 64, unique, friendly (every pair passes SpamReason and the banned list)", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local PW = W.PASS_WORDS
	eq(#PW.adj, 64, "64 adjectives")
	eq(#PW.noun, 64, "64 nouns")
	local seen = {}
	for _, list in ipairs({ PW.adj, PW.noun }) do
		for _, x in ipairs(list) do
			ok(x:match("^%u%l+$"), "one capitalised word: " .. x)
			ok(not seen[x:lower()], "unique: " .. x)
			seen[x:lower()] = true
		end
	end
	local banned = { "ritual", "ass", "tit", "cock", "booby", "pussy", "beaver", "muff", "wiener", "nut", "hot", "moist",
		"naughty", "sexy", "dead", "kill", "nazi", "slave", "fat", "ugly", "gold" }
	for _, a in ipairs(PW.adj) do
		for _, n in ipairs(PW.noun) do
			local pair = a .. " " .. n
			eq(W.SpamReason(pair), nil, "SpamReason: " .. pair)
			for _, b in ipairs(banned) do
				for word in pair:lower():gmatch("%a+") do ok(word ~= b, "banned word in " .. pair) end
			end
			ok(#pair <= 24, "short: " .. pair)
		end
	end
	T.clean(w)
end)

---------------------------------------------------------------------------
-- The founder's gold portal
---------------------------------------------------------------------------

-- a rider in a group with these players; a ride from Anita
local function founderRide(opts)
	opts = opts or {}
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local d = T.driver(w, opts.driver or ANITA)
	local r = T.rider(w, TESTCHAR, { prepare = opts.prepare })
	if opts.realm then r.realm = opts.realm end
	local names = { opts.driver or ANITA, TESTCHAR }
	if opts.with then names[#names + 1] = opts.with end
	if opts.with then w:addBot(opts.with, { spot = "Ratchet" }) end
	if opts.grouped ~= false then w:group(names) end
	local ride = { id = "AbCdEf", driverKey = (opts.driver or ANITA):lower(), driver = opts.driver or ANITA, state = "portal" }
	return w, d, r, ride
end

test("net.portal: FounderSummon: a genuine founder's ride is gold; arrival needs the game's own summoner", function()
	local w, d, r, ride = founderRide()
	local W = r.W
	eq(W.FounderSummon(ride), true, "Anita, a founder, in my group, on the founders' ruleset")
	eq(W.FounderSummon(ride, "arrival"), false, "arrival: the game hasn't named the summoner yet")
	ride.summonedBy = "anita lift"
	eq(W.FounderSummon(ride, "arrival"), true, "arrival: the game named Anita")
	ride.summonedBy = "bob stone"
	eq(W.FounderSummon(ride), false, "the game named someone else: violet")
	eq(W.FounderSummon(ride, "arrival"), false, "arrival too")
	T.clean(w)
end)

test("net.portal: FounderSummon: forged or doubtful founders stay violet", function()
	-- a non-founder driver
	local w, d, r, ride = founderRide({ driver = BOB })
	eq(r.W.FounderSummon(ride), false, "Bob is no founder")
	-- Bob's ride claims Anita as payee / G caster: Anita isn't in the group
	ride.payee = ANITA
	eq(r.W.FounderSummon(ride), false, "payee Anita, not in my group: violet")
	ride.payee = nil
	ride.ritual = { casterKey = "anita lift", phase = "c" }
	eq(r.W.FounderSummon(ride), false, "G caster Anita, not in my group: violet")
	T.clean(w)
	-- Anita Lift's name on another ruleset
	local w2, d2, r2, ride2 = founderRide({ realm = "CAMWOW US2 Realm 1 PvP" })
	eq(r2.W.FounderSummon(ride2), false, "Anita Lift on a non-founder ruleset: violet")
	T.clean(w2)
	-- not grouped
	local w3, d3, r3, ride3 = founderRide({ grouped = false })
	eq(r3.W.FounderSummon(ride3), false, "Anita not in my group: violet")
	T.clean(w3)
	-- the G caster and the S payee disagree
	local w4, d4, r4, ride4 = founderRide({ with = T.BEA })
	ride4.payee = T.BEA
	eq(r4.W.FounderSummon(ride4), false, "payee Bea (no founder): violet")
	ride4.ritual = { casterKey = "anita lift" }
	eq(r4.W.FounderSummon(ride4), false, "caster Anita but payee Bea: doubt, violet")
	ride4.payee = ANITA
	eq(r4.W.FounderSummon(ride4), true, "both Anita: gold")
	T.clean(w4)
end)

test("net.portal: FounderSummon: G's short caster name (Drive.Kitchen's W.Short) counts only for the ride's payee or driver", function()
	local w, d, r, ride = founderRide()
	local W = r.W
	ride.ritual = { caster = "Anita", casterKey = "anita", phase = "c" }
	eq(W.FounderSummon(ride), true, "\"Anita\" = the first word of the driver Anita Lift: gold")
	ride.summonedBy = "anita lift"
	eq(W.FounderSummon(ride, "arrival"), true, "arrival: the game named Anita Lift")
	ride.summonedBy = nil
	ride.payee = ANITA
	eq(W.FounderSummon(ride), true, "the payee Anita Lift too: gold")
	ride.ritual = { caster = "Anita Lift", casterKey = "anita lift" }
	eq(W.FounderSummon(ride), true, "a full name still counts")
	-- mismatch: a short name that is neither the payee nor the driver is doubt, even on a founder's ride
	ride.payee = nil
	ride.ritual = { caster = "Bea", casterKey = "bea" }
	eq(W.FounderSummon(ride), false, "\"Bea\" on Anita's ride: doubt, violet")
	ride.ritual = { caster = "Ani", casterKey = "ani" }
	eq(W.FounderSummon(ride), false, "a part of a word is no match")
	ride.ritual = { caster = "Lift", casterKey = "lift" }
	eq(W.FounderSummon(ride), false, "the surname alone is no match")
	T.clean(w)
	-- forged: Bob's ride names "Anita" as its caster
	local w2, d2, r2, ride2 = founderRide({ driver = BOB })
	ride2.ritual = { caster = "Anita", casterKey = "anita" }
	eq(r2.W.FounderSummon(ride2), false, "Bob's ride, caster \"Anita\": violet")
	ride2.payee = ANITA
	eq(r2.W.FounderSummon(ride2), false, "payee Anita Lift, but she isn't in my group: violet")
	T.clean(w2)
end)

test("net.portal: FounderSummon: the founder's own cast; a CONFIRM_SUMMON fills W.ride.summonedBy", function()
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local d = T.driver(w, ANITA)
	local r = T.rider(w)
	eq(d.W.FounderSummon({ own = true }), true, "Anita's own screen")
	eq(d.W.FounderSummon({ own = true, caster = BOB }), false, "someone else's cast on my screen")
	eq(r.W.FounderSummon({ own = true }), false, "Wuber is no founder")
	T.clean(w)
	-- the game's own summoner, read at CONFIRM_SUMMON
	local w2 = T.newWorld({ realm = T.H.FOUNDER_REALM })
	local d2 = T.driver(w2, ANITA)
	local r2 = T.rider(w2)
	T.settle(w2)
	T.goOnline(d2)
	T.requestVia(r2, "anita lift")
	w2:advance(8)
	w2:summon(d2, TESTCHAR)
	w2:advance(1)
	eq(r2.W.ride and r2.W.ride.state, "portal", "the summon is up")
	do
		eq(r2.W.ride.summonedBy, "anita lift", "W.ride.summonedBy from the game's summon box")
		eq(r2.W.FounderSummon(r2.W.ride, "arrival"), true, "a real summon by Anita: gold")
	end
	T.clean(w2)
end)
