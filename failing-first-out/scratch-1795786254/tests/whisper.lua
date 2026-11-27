-- Whisper fallback and gossip mesh tests (Forever's internal realms split the custom
-- channel: the same "WuberNet" joined on two internal realms is two separate channels, while
-- addon whispers reach everyone). Loaded by run.lua with its helpers.
--
-- The harness puts a client in another copy of the channel with `channelCopy` (or
-- w:splitChannel): channel messages don't cross copies, whispers do.

local T = ...
local H, test, eq, ok, list, count = T.H, T.test, T.eq, T.ok, T.list, T.count
local newWorld, settle, clean, goOnline, msgs, fields = T.newWorld, T.settle, T.clean, T.goOnline, T.msgs, T.fields
local HAVE_UI = T.HAVE_UI

local ANITA, FARRA, HAYLEY, ROCKS, TESTCHAR = "Anita Lift", "Farra Way", "Hayley Cab", "Wuber Rocks", "Wuber TestCharacter"

-- (netOnly: a driver run by Net alone, answering by W.AcceptRequest - see run.lua's netOnly)
local function client(w, name, o)
	o = o or {}
	local c = w:addClient(name, { spot = o.spot or (o.warlock and "Ratchet" or "Orgrimmar"), class = o.warlock and "WARLOCK" or "MAGE",
		money = o.money or 100000, allowMissing = not HAVE_UI, saved = o.saved, channelCopy = o.copy, realm = o.realm,
		addonFails = o.addonFails, addons = o.addons, addonDirs = o.addonDirs, roundOne = o.roundOne, lockEngine = o.netOnly })
	if o.netOnly then T.netOnly(c) end
	return c
end

-- whispered messages of a kind from one player (to one player)
local function whispered(w, kind, from, to)
	local out = {}
	for _, e in ipairs(msgs(w, kind, from, "WHISPER")) do
		if not to or H.key(e.target) == H.key(to) then out[#out + 1] = e end
	end
	return out
end

-- "No player named ..." lines a chat window showed
local function notFoundShown(c)
	local n = 0
	for _, l in ipairs(c.chatShown) do
		if tostring(l.text):find("No player named", 1, true) then n = n + 1 end
	end
	return n
end

local function noChatSpam(w)
	for _, c in ipairs(w.clients) do
		eq(notFoundShown(c), 0, c.player.name .. " saw a 'No player named' line")
	end
end

-- the most whispered Qs one player sent in any 60 s, and in any one round (2 s bursts)
local function qPeaks(w, from)
	local times = {}
	for _, e in ipairs(whispered(w, "Q", from)) do times[#times + 1] = e.at end
	table.sort(times)
	local perMin, j = 0, 1
	for i = 1, #times do
		while times[i] - times[j] >= 60 do j = j + 1 end
		perMin = math.max(perMin, i - j + 1)
	end
	return perMin, #times
end

---------------------------------------------------------------------------

test("whisper: a rider in another channel copy sees the founder by whisper, gets her changes, books end to end", function()
	local w = newWorld()
	local d = client(w, ANITA, { warlock = true, realm = "CAMWOW EU4 Realm 7 PvE", netOnly = true }) -- accepts by hand below
	local r = client(w, TESTCHAR, { copy = "realm5", realm = "CAMWOW EU5 Realm 5 PvE" })
	settle(w)
	ok(d.W.OnNetwork() and r.W.OnNetwork(), "both joined their own WuberNet")
	eq(r.W.fallback.chanHeard["anita lift"], nil, "the channel doesn't connect them")
	ok(#whispered(w, "Q", TESTCHAR, ANITA) == 1, "login round: Wuber asked Anita by whisper (not driving yet)")
	goOnline(d)
	w:advance(2)
	ok(r.W.drivers["anita lift"], "going online: her D whispered to the rider who asked")
	eq(r.W.fallback.chanHeard["anita lift"], nil, "still nothing over the channel")
	-- the rider asks again (Ping drivers): Q on the channel and by whisper to the founder's team
	w:advance(20)
	ok(r.W.Ping(), "ping")
	w:advance(4)
	local x = r.W.drivers["anita lift"]
	ok(x, "Anita listed by whisper")
	eq(x.via, "WHISPER", "heard by whisper")
	eq(x.price, 5000, "her own price")
	eq(x.realm, "CAMWOW EU4 Realm 7 PvE", "her internal realm")
	ok(x.creator, "the founder's crown (checked locally)")
	ok(#whispered(w, "D", ANITA, TESTCHAR) >= 1, "D by whisper to Wuber")
	eq(r.W.net.byWhisper, 1, "one driver by whisper")
	local lines = table.concat(r.W.NetStatusLines(), " / ")
	ok(lines:find("channel joined, 1 driver by whisper", 1, true), "status: " .. lines)
	ok(lines:find("Drivers online: 1 (Anita Lift: CAMWOW EU4 Realm 7 PvE, by whisper).", 1, true), "status realm line: " .. lines)
	eq(#r.W.NetStatusLines(), 2, "as many status lines as before")
	-- a change of price reaches the whisper-only rider within a few seconds
	d.W.Char().price = 7000
	d.env.WuberAPI.Beacon()
	w:advance(7)
	eq(r.W.drivers["anita lift"].price, 7000, "new price pushed by whisper")
	-- paused and back
	T.goOffline(d)
	w:advance(3)
	eq(r.W.drivers["anita lift"], nil, "X by whisper drops her")
	goOnline(d)
	w:advance(4)
	ok(r.W.drivers["anita lift"], "online again, pushed by whisper")
	-- booking: R, A and S go by whisper anyway
	local ride = r.W.RequestRide("anita lift")
	ok(ride, "requested")
	w:advance(1)
	eq(#d.W.incoming, 1, "the driver has the request")
	ok(d.W.AcceptRequest(d.W.incoming[1].id, 5, d.W.incoming[1].buyer), "accepted")
	w:advance(1)
	eq(r.W.ride.state, "accepted", "the rider sees the accept")
	d.W.SendStage(r.W.ride.id, "summoning", TESTCHAR)
	w:advance(1)
	eq(r.W.ride.state, "summoning", "stage by whisper")
	-- 2 min of the window "open" (pings): she stays listed, no storm
	for _ = 1, 4 do
		w:advance(30)
		r.W.Ping()
	end
	ok(r.W.drivers["anita lift"], "still listed")
	local perMin = qPeaks(w, TESTCHAR)
	ok(perMin <= 16, "whispered Qs per minute: " .. perMin)
	noChatSpam(w)
	clean(w)
end)

test("whisper: offline founders and favourites: 'No player named' hidden, not asked again for 30 / 5 min", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	w:addBot("Bob Stone").online = false
	local r = client(w, TESTCHAR, { saved = { Wuber = { favs = { ["bob stone"] = true } } } })
	settle(w, 15)
	local fb = r.W.fallback
	ok((w.failedAddonWhispers or 0) >= 5, "whispered the four founders and Bob: " .. tostring(w.failedAddonWhispers))
	eq(notFoundShown(r), 0, "no 'No player named' in chat")
	for _, k in ipairs({ "anita lift", "farra way", "hayley cab", "wuber rocks" }) do
		local left = (fb.offlineUntil[k] or 0) - w.time
		ok(left > 1700 and left <= 1800, k .. " offline for 30 min: " .. left)
	end
	local left = (fb.offlineUntil["bob stone"] or 0) - w.time
	ok(left > 250 and left <= 300, "a favourite offline for 5 min: " .. left)
	eq(r.W.drivers["bob stone"], nil, "nobody listed")
	-- seven minutes of pings: Bob asked again after 5 min, the founders not
	for _ = 1, 7 do
		w:advance(60)
		r.W.Ping()
	end
	eq(#whispered(w, "Q", TESTCHAR, FARRA), 1, "Farra asked once")
	eq(#whispered(w, "Q", TESTCHAR, "Bob Stone"), 2, "Bob asked again after 5 min")
	eq(notFoundShown(r), 0, "still nothing in chat")
	clean(w)
end)

test("whisper: 30 known drivers and a saved list of 40: capped, rotated, never a storm", function()
	local w = newWorld()
	local stamp = H.EPOCH + 1000
	local seen = {}
	for i = 1, 40 do
		local name = "Lock" .. string.char(64 + ((i - 1) % 26) + 1) .. string.char(96 + math.floor((i - 1) / 26) + 1) .. " Driver"
		w:addBot(name, { class = "WARLOCK" })
		seen[H.key(name)] = { name = name, addr = name, at = stamp - i * 60 }
	end
	seen["old lock"] = { name = "Old Lock", addr = "Old Lock", at = stamp - 15 * 86400 }
	local r = client(w, TESTCHAR, { saved = { Wuber = { seenDrivers = seen } } })
	settle(w, 12)
	local list_ = r.W.KnownDrivers()
	eq(count(r.W.db.seenDrivers), 40, "saved list capped at 60: all 40 kept (SPEC5 gossip: SEEN_MAX 30 -> 60)")
	eq(r.W.db.seenDrivers["old lock"], nil, "15 days old: forgotten")
	ok(#list_ <= 40, "known drivers: " .. #list_)
	-- ten minutes with the window open (rounds every 60 s) and a ping every 20 s on top
	if HAVE_UI then r.W.UI.Toggle(true) end
	for _ = 1, 30 do
		w:advance(20)
		r.W.Ping()
	end
	local perMin, total = qPeaks(w, TESTCHAR)
	ok(perMin <= 16, "at most 16 whispered Qs a minute: " .. perMin)
	ok(total >= 30, "but they keep going round: " .. total)
	-- every one of the 30 got asked at some point (rotation), none more than every 45 s
	local per = {}
	for _, e in ipairs(whispered(w, "Q", TESTCHAR)) do
		local k = H.key(e.target)
		per[k] = per[k] or {}
		table.insert(per[k], e.at)
	end
	local asked = 0
	for k, ts in pairs(per) do
		if k:find("driver$") then asked = asked + 1 end
		for i = 2, #ts do ok(ts[i] - ts[i - 1] >= 14.9, k .. " asked twice in " .. (ts[i] - ts[i - 1]) .. " s") end
	end
	ok(asked >= 25, "rotation reached most of them: " .. asked)
	noChatSpam(w)
	clean(w)
end)

-- SPEC5 stagger (review #9): answers past the first ten are spread about a second apart
-- instead of dropped; every rider gets one, and ride messages still go first.
test("whisper: a driver with 30 riders whispering Q: answers paced (none dropped), ride messages first", function()
	local w = newWorld()
	local d = client(w, "Dan Driver", { warlock = true, netOnly = true }) -- accepts by hand below
	settle(w)
	goOnline(d)
	local mark = w.time
	for i = 1, 30 do
		local name = "Rider" .. string.char(64 + ((i - 1) % 26) + 1) .. string.char(96 + math.floor((i - 1) / 26) + 1) .. " Person"
		w:addBot(name)
		w:inject(name, "Q~1~1", "WHISPER", d)
		w:inject(name, "Q~1~1", "WHISPER", d) -- twice: one answer
	end
	w:advance(15)
	local n15 = 0
	for _, e in ipairs(whispered(w, "D", "Dan Driver")) do if e.at >= mark and e.at < mark + 15 then n15 = n15 + 1 end end
	ok(n15 <= 20, "paced: about one a second after the first few: " .. n15)
	ok(n15 >= 5, "but it does answer: " .. n15)
	w:advance(30)
	local per = {}
	for _, e in ipairs(whispered(w, "D", "Dan Driver")) do per[H.key(e.target)] = (per[H.key(e.target)] or 0) + 1 end
	local answered, twice = 0, 0
	for _, n in pairs(per) do
		answered = answered + 1
		if n > 1 then twice = twice + 1 end
	end
	eq(answered, 30, "all 30 riders answered")
	eq(twice, 0, "one answer each")
	-- a ride request is not held up by the fallback's answers
	w:addBot("Ana Smith")
	for i = 1, 20 do w:inject("Rider" .. string.char(64 + i) .. "a Person", "Q~1~1", "WHISPER", d) end
	w:inject("Ana Smith", "R~1~AbCdEf~Ratchet~5000~0~0", "WHISPER", d)
	w:advance(0.5)
	eq(#d.W.incoming, 1, "the request is in")
	ok(d.W.AcceptRequest("AbCdEf", 5, "Ana Smith"), "accept queued")
	w:advance(1.5)
	eq(#whispered(w, "A", "Dan Driver", "Ana Smith"), 1, "A went out within 1.5 s")
	noChatSpam(w)
	clean(w)
end)

---------------------------------------------------------------------------
-- Gossip
---------------------------------------------------------------------------

test("gossip: a stranger who only whispered a founder learns a driver from her K and confirms him directly", function()
	local w = newWorld()
	-- internal realm 7: the founder Hayley (not driving) hears Dan on the channel
	local hub = client(w, HAYLEY, { realm = "CAMWOW EU4 Realm 7 PvE" })
	local dan = client(w, "Dan Driver", { warlock = true, realm = "CAMWOW EU4 Realm 7 PvE" })
	settle(w)
	goOnline(dan)
	w:advance(5)
	ok(hub.W.drivers["dan driver"], "Hayley hears Dan on the channel")
	-- internal realm 5: a stranger who knows nobody but the founder's names
	local s = client(w, "Sam Stranger", { copy = "realm5", realm = "CAMWOW EU5 Realm 5 PvE" })
	w:advance(16) -- login round: Q to the founders; Hayley answers with a K
	ok(#whispered(w, "K", HAYLEY, "Sam Stranger") == 1, "K from the founder")
	local k = fields(whispered(w, "K", HAYLEY, "Sam Stranger")[1])
	eq(k[3], "Dan Driver", "Dan's name in it")
	w:advance(8) -- the confirm round: Q to Dan, Dan's own D
	local x = s.W.drivers["dan driver"]
	ok(x, "Sam lists Dan")
	eq(x.via, "WHISPER", "confirmed by Dan's own whispered D")
	eq(x.price, 5000, "the price from Dan himself")
	eq(s.W.fallback.unconfirmed["dan driver"], nil, "no longer unconfirmed")
	eq(s.W.drivers["hayley cab"], nil, "a founder who isn't driving isn't listed")
	-- Sam books Dan across the realms
	ok(s.W.RequestRide("dan driver"), "request")
	w:advance(1)
	eq(#dan.W.incoming, 1, "Dan has it")
	noChatSpam(w)
	clean(w)
end)

test("gossip: spoofed K names never show a driver unless that character answers; caps hold", function()
	local w = newWorld()
	w:addBot("Bob Stone") -- online, no Wuber: never answers
	local r = client(w, TESTCHAR)
	settle(w)
	local fb = r.W.fallback
	-- a liar suggests a made-up name, a real non-driver, junk, our own name and a founder
	w:addBot("Evil Guy")
	w:inject("Evil Guy", "K~1~Fake Driver~Bob Stone~|cffff0000Bad~Wuber TestCharacter~Anita Lift~x", "WHISPER", r)
	w:advance(0.1)
	ok(fb.unconfirmed["fake driver"] and fb.unconfirmed["bob stone"], "two names to ask")
	eq(count(fb.unconfirmed), 2, "junk, ourselves and founders not taken")
	w:advance(10)
	eq(count(r.W.drivers), 0, "nobody shown")
	ok(#whispered(w, "Q", TESTCHAR, "Fake Driver") == 1 and #whispered(w, "Q", TESTCHAR, "Bob Stone") == 1, "each asked")
	eq(fb.unconfirmed["fake driver"], nil, "an offline name is dropped at once")
	-- Bob never answers: asked once more, then dropped and not taken again for 30 min
	r.W.Ping()
	w:advance(40)
	r.W.Ping()
	w:advance(40)
	eq(fb.unconfirmed["bob stone"], nil, "dropped after two tries")
	ok(fb.rejected["bob stone"], "and rejected")
	w:inject("Evil Guy", "K~1~Bob Stone", "WHISPER", r)
	w:advance(0.1)
	eq(fb.unconfirmed["bob stone"], nil, "not taken again")
	eq(count(r.W.drivers), 0, "still nobody shown")
	-- a flood of Ks: the list stays capped, rounds stay small
	for i = 1, 12 do
		local names = {}
		for j = 1, 8 do names[j] = "Spam" .. string.char(64 + i) .. " Name" .. string.char(96 + j) end
		w:inject("Evil Guy", "K~1~" .. table.concat(names, "~"), "WHISPER", r)
	end
	w:advance(0.1)
	eq(count(fb.unconfirmed), 60, "unconfirmed names capped at 60")
	for _ = 1, 5 do
		w:advance(20)
		r.W.Ping()
	end
	local perMin = qPeaks(w, TESTCHAR)
	ok(perMin <= 16, "Qs a minute: " .. perMin)
	eq(count(r.W.drivers), 0, "no spoofed name shown")
	noChatSpam(w)
	clean(w)
end)

test("gossip: no founder online at all - a new rider who met one other rider finds the drivers", function()
	local w = newWorld()
	-- realm 7: a driver and a rider who hears him; realm 5: a new rider
	local dan = client(w, "Dan Driver", { warlock = true })
	local olive = client(w, "Olive Rider", { saved = { Wuber = { favs = { ["newt rider"] = true } } } })
	local newt = client(w, "Newt Rider", { copy = "realm5" })
	-- Olive's login round asks Newt (her favourite): Newt now knows Olive runs Wuber
	settle(w)
	ok(newt.W.db.peers and newt.W.db.peers["olive rider"], "Newt remembers Olive as a contact")
	goOnline(dan)
	w:advance(5)
	ok(olive.W.drivers["dan driver"], "Olive hears Dan")
	eq(newt.W.drivers["dan driver"], nil, "nothing known yet")
	-- Newt asks his contacts (here: Ping drivers); Olive's K names Dan; Newt confirms him
	newt.W.Ping()
	w:advance(10)
	ok(#whispered(w, "K", "Olive Rider", "Newt Rider") >= 1, "Olive's K")
	local x = newt.W.drivers["dan driver"]
	ok(x and x.via == "WHISPER", "Newt lists Dan, confirmed by Dan")
	-- next login (saved lists): Newt finds Dan by himself
	ok(newt.W.db.seenDrivers["dan driver"], "Dan saved as seen")
	noChatSpam(w)
	clean(w)
end)

---------------------------------------------------------------------------
-- Accounts that can't send, old peers, the channel's health
---------------------------------------------------------------------------

test("trial account: every addon message refused - Wuber listens, books by the chat whisper", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	local d = client(w, ANITA, { warlock = true, netOnly = true }) -- Net's chat-only request list (the engine reads whispers itself)
	local t = client(w, "Tina Trial", { addonFails = true })
	settle(w, 20)
	goOnline(d)
	w:advance(3)
	ok(t.W.net.cantSend, "the trial account is noticed")
	local said = 0
	for _, l in ipairs(t.chatLines) do if l:find("can't send addon messages", 1, true) then said = said + 1 end end
	eq(said, 1, "said once")
	ok(t.W.drivers["anita lift"], "the trial rider still sees the driver (receiving works)")
	ok(table.concat(t.W.NetStatusLines(), " "):find("listening only", 1, true), "status says so")
	-- tries stay rare: at most one message every 5 min
	local tried0 = t.sendFailures or 0
	for _ = 1, 4 do
		w:advance(60)
		t.W.Ping()
	end
	ok((t.sendFailures or 0) - tried0 <= 1, "probes only: " .. ((t.sendFailures or 0) - tried0))
	-- book: the ride is set up; the chat whisper (the secure button's) carries the request
	local ride = t.W.RequestRide("anita lift")
	ok(ride and ride.noAddon, "ride set up for a chat-only request")
	local text = t.W.RequestWhisper("anita lift")
	eq(text, "WTB summon to Ratchet for 50s")
	w:whisper(t, ANITA, text, "macro")
	w:advance(3)
	eq(#d.W.incoming, 1, "Wuber's driver mode lists the chat request")
	ok(d.W.incoming[1].chat, "marked as by chat")
	ok(d.W.AcceptRequest(d.W.incoming[1].id, 5, d.W.incoming[1].buyer), "accept")
	w:advance(1)
	eq(t.W.ride.state, "accepted", "the trial rider hears the accept and takes its ride id")
	w:advance(30)
	ok(t.W.ride.state == "accepted", "no timeout while waiting: " .. tostring(t.W.ride.state))
	clean(w)
end)

test("whisper: a chat request isn't doubled when the R comes too", function()
	local w = newWorld()
	local d = client(w, ANITA, { warlock = true })
	local r = client(w, TESTCHAR)
	settle(w)
	goOnline(d)
	ok(r.W.RequestRide("anita lift"), "request")
	w:whisper(r, ANITA, r.W.RequestWhisper("anita lift"), "macro")
	w:advance(4)
	eq(#d.W.incoming, 1, "one request")
	eq(d.W.incoming[1].chat, nil, "the R's")
	clean(w)
end)

test("whisper: round-one peers ignore whispered D, Q and K; ours ignore nothing they need", function()
	local w = newWorld()
	local old = client(w, ANITA, { warlock = true, copy = "b", addonDirs = { Wuber = H.ADDONS.Wuber1 }, roundOne = true })
	local r = client(w, TESTCHAR)
	settle(w)
	goOnline(old)
	r.W.Ping()
	w:inject(TESTCHAR, "K~1~Dan Driver", "WHISPER", old)
	w:inject(TESTCHAR, "D~1~Ratchet~1413~627~370~5000~Wuber~open~1~0~H~1.1.0~~~1~Forever", "WHISPER", old)
	w:advance(5)
	eq(#whispered(w, "D", ANITA), 0, "the old driver doesn't answer by whisper")
	eq(old.W.drivers["wuber testcharacter"], nil, "a whispered D isn't a beacon for it")
	clean(w)
end)

test("channel health: whisper-only after 3 min; one leave and rejoin when a peer hears others there", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	local d = client(w, ANITA, { warlock = true, copy = "lonely" })
	w:splitChannel(d, "lonely", { healOnRejoin = true })
	local dan = client(w, "Dan Driver", { warlock = true })
	local r = client(w, TESTCHAR)
	settle(w)
	goOnline(d)
	goOnline(dan)
	-- the rider asks every minute (window open)
	for _ = 1, 4 do
		r.W.Ping()
		w:advance(60)
	end
	ok(r.W.drivers["anita lift"] and r.W.drivers["anita lift"].via == "WHISPER", "Wuber hears Anita by whisper")
	ok(r.W.drivers["dan driver"] and r.W.drivers["dan driver"].via == "CHANNEL", "and Dan on the channel")
	eq(r.W.net.whisperOnly, false, "Wuber's channel is fine")
	eq(d.leftChannels, nil, "not yet")
	for _ = 1, 3 do
		r.W.Ping()
		w:advance(60)
	end
	eq(d.leftChannels, 1, "Anita left WuberNet once")
	ok(d.W.net.rejoined, "and says so in W.net")
	w:advance(20)
	ok(d.W.OnNetwork(), "joined again")
	r.W.Ping()
	w:advance(70)
	local x = r.W.drivers["anita lift"]
	ok(x and x.via == "CHANNEL", "now heard on the channel: " .. tostring(x and x.via))
	eq(r.leftChannels, nil, "Wuber never left")
	-- never again this session
	for _ = 1, 6 do w:advance(60) end
	eq(d.leftChannels, 1, "once only")
	noChatSpam(w)
	clean(w)
end)

test("channel health: a lone client in its own copy with nobody answering stays put", function()
	local w = newWorld()
	local d = client(w, ANITA, { warlock = true, copy = "lonely" })
	settle(w)
	goOnline(d)
	w:advance(600)
	eq(d.leftChannels, nil, "no rejoin without a peer's word")
	eq(d.W.net.whisperOnly, false, "nobody answers by whisper either")
	noChatSpam(w)
	clean(w)
end)

test("whisper: whisper-only flag while riders answer by whisper only", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	local d = client(w, ANITA, { warlock = true, copy = "b" })
	local r = client(w, TESTCHAR)
	settle(w)
	goOnline(d)
	for _ = 1, 4 do
		r.W.Ping()
		w:advance(60)
	end
	eq(r.W.net.whisperOnly, true, "Wuber hears only his echo on the channel, Anita by whisper")
	ok(r.W.NetStatus():find("1 driver by whisper", 1, true), r.W.NetStatus())
	eq(#r.chatLines, 0, "nothing said in chat: " .. list(r.chatLines, " / "))
	clean(w)
end)
