-- Final home: tests/drive/team_test.lua; add it to the per-module list in tests/run.lua.
-- Pins:
--   the crew offer (TO / TY / TN whispers on WUBERT): one card per captain a minute, a blocked captain shows none,
--   a Yes after 5 minutes or from someone never asked is not believed, a "No player named" answer drops a waiting offer;
--   CRW and TL count only from my own captain; CRW keeps 8 at most, never me, never a name twice, never a bad role;
--   group facts count only from my group, protocol 1, 255 bytes, PARTY/RAID; CFG from the captain is believed;
--   the outbox: a newer CFG replaces the queued one, one ST per rider, whispers never merge; bulk dedups, holds 50;
--   pack: empty trailing fields dropped, a ~ in a field never splits it, a long fact is cut on a letter boundary;
--   the crew list wire (captain first, L/H/P/S); own settings put back from damaged saved values are clamped.
-- Why it matters to a player: crew windows that trust the wrong sender, lose a rider's PAID behind a sync, or keep a
--   member in a crew the captain never confirmed would show different queues, prices and summoners on each window.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- every WUBERT (crew prefix) message that left a window (w:messages reads only the WUBER prefix)
local function team(w, kind, from, chatType)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.result == 0 and not e.dropped and (not from or e.from == from)
			and (not chatType or e.chatType == chatType) and (not kind or e.text:match("^([^~]*)") == kind) then
			out[#out + 1] = e
		end
	end
	return out
end

local function lock(w, name) return w:addClient(name, { spot = "Orgrimmar", class = "WARLOCK" }) end

-- Ana (captain) and Bea (Warlock) in one party; Bea took Ana's crew offer (as tests/dec/dec_c_crew_test.lua does).
local function crew()
	local w = T.newWorld()
	local ana, bea = lock(w, T.ANA), lock(w, T.BEA)
	w:group({ T.ANA, T.BEA })
	T.settle(w)
	ok(ana.W.Drive.OfferCrew(T.BEA), "setup: the crew offer")
	w:advance(3)
	bea.W.Drive.AnswerOffer(T.ANA, true)
	w:advance(5)
	ok(bea.W.Drive.char().captain ~= "", "setup: Bea is in Ana's crew")
	return w, ana, bea
end

-- Ana and Bea, not grouped (offers are whispers: they reach a player outside the group)
local function apart()
	local w = T.newWorld()
	local ana, bea = lock(w, T.ANA), lock(w, T.BEA)
	T.settle(w)
	return w, ana, bea
end

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: contract (registered, no deps, header, public names); the crew prefix", function()
	local W, w, r, Mod = T.contract("Drive.Team", "tests/drive/team_test.lua", {
		["DR.TPREFIX"] = "string", ["DR.TPROTO"] = "number", ["DR.comm"] = "table", ["DR.offers"] = "table",
		["DR.pendingOffers"] = "table", ["DR.FlushComm"] = "function", ["DR.CommBacklog"] = "function",
		["DR.Send"] = "function", ["DR.Whisper"] = "function", ["DR.Do"] = "function", ["DR.Hello"] = "function",
		["DR.SyncStates"] = "function", ["DR.StationsWire"] = "function", ["DR.SendConfig"] = "function",
		["DR.SendService"] = "function", ["DR.SendBlocklist"] = "function", ["DR.SendCrew"] = "function",
		["DR.CrewList"] = "function", ["DR.SyncAnswerer"] = "function", ["DR.SyncOut"] = "function",
		["DR.SyncNow"] = "function", ["DR.OfferCrew"] = "function", ["DR.AnswerOffer"] = "function",
		["DR.RemoveCrew"] = "function", ["DR.LeaveCrew"] = "function", ["DR.OnTeamAddon"] = "function",
		["DR.OfferTick"] = "function", ["DR.StartTeam"] = "function", ["DR.SendState"] = "function",
		["DR.SendBulk"] = "function", ["DR.KeepOwnConfig"] = "function", ["DR.RestoreOwnConfig"] = "function",
		["DR.ValidName"] = "function",
	})
	ok(Mod, "W.Mod(\"Drive.Team\")")
	eq(W.Drive.TPREFIX, "WUBERT", "the crew's own addon prefix")
	eq(W.Drive.TPROTO, 1, "protocol 1")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: a name to offer: 2 to 12 letters, an optional realm (an apostrophe allowed); loose: words of 2 to 24", function()
	local w = T.newWorld()
	local d = lock(w, T.ANA)
	T.settle(w)
	local DR = d.W.Drive
	ok(DR.ValidName("Al"), "2 letters")
	ok(DR.ValidName("Abcdefghijkl"), "12 letters")
	ok(not DR.ValidName("A"), "1 letter")
	ok(DR.ValidName("Bob-Quel'Thalas"), "a realm with an apostrophe") -- Team.lua: realm:gsub("'", "")
	ok(not DR.ValidName("Bob-Quel Thalas"), "a realm with a space")
	ok(not DR.ValidName("Bob--Firemaw"), "two dashes")
	ok(DR.ValidName("Ana Smith", true), "loose: two words")
	ok(DR.ValidName("Ana-Smith", true), "loose: a dash inside a word is not a letter, nor a fault")
	ok(not DR.ValidName("A Smith", true), "loose: a one-letter word")
	ok(DR.ValidName(string.rep("a", 24), true), "loose: 24 letters")
	ok(not DR.ValidName(string.rep("a", 25), true), "loose: 25 letters")
	ok(not DR.ValidName("", true), "loose: nothing")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: an offer is refused for my own name, a non-name, or by a member (nothing whispered)", function()
	local w, ana, bea = crew()
	local A, B = ana.W.Drive, bea.W.Drive
	local n0 = #team(w, "TO")
	local okA, why = A.OfferCrew(T.ANA)
	eq(okA, false, "my own name") eq(why, "name")
	okA, why = A.OfferCrew("x1")
	eq(okA, false, "not a name") eq(why, "badname")
	okA, why = B.OfferCrew(T.CAL)
	eq(okA, false, "a member does not offer") eq(why, "member")
	eq(B.offers[key(T.CAL)], nil, "no row on the member's window")
	w:advance(3)
	eq(#team(w, "TO"), n0, "no TO whispered")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: an offer whispers TO out of the group; the invited window shows one card per captain a minute", function()
	local w, ana, bea = apart()
	local A, B = ana.W.Drive, bea.W.Drive
	ok(A.OfferCrew(T.BEA, "raid"), "the offer went")
	local o = A.offers[key(T.BEA)]
	ok(o and o.state == "waiting", "the captain's row waits")
	eq(o.kind, "raid", "a raid pick")
	w:advance(2)
	local to = team(w, "TO", T.ANA, "WHISPER")
	eq(#to, 1, "one TO whisper")
	eq(to[1].target, T.BEA, "to Bea")
	eq(to[1].text, "TO~1~raid", "kind, protocol, the service (a raid pick says raid)")
	local p = B.pendingOffers[key(T.ANA)]
	ok(p, "Bea's window holds Ana's offer")
	eq(p.service, "raid", "the card's service")
	-- a second offer inside a minute: no second card (Team.lua OFFER_SHOWN = 60)
	B.pendingOffers[key(T.ANA)] = nil
	ok(A.OfferCrew(T.BEA, "raid"), "offered again")
	w:advance(2)
	eq(B.pendingOffers[key(T.ANA)], nil, "no second card within a minute")
	w:advance(60)
	ok(A.OfferCrew(T.BEA, "raid"), "offered a minute later")
	w:advance(2)
	ok(B.pendingOffers[key(T.ANA)], "a minute later the card shows again")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: an offer from a captain on my blocked list shows no card", function()
	local w, ana, bea = apart()
	local A, B = ana.W.Drive, bea.W.Drive
	B.db.blocklist[key(T.ANA)] = { reason = "rude", at = "2026-11-24" } -- the shape Drive/Core.lua:928 saves
	ok(A.OfferCrew(T.BEA), "the offer went")
	w:advance(3)
	eq(B.pendingOffers[key(T.ANA)], nil, "no card from a blocked player")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: No answers TN; the captain's row says no, nobody joins", function()
	local w, ana, bea = apart()
	local A, B = ana.W.Drive, bea.W.Drive
	ok(A.OfferCrew(T.BEA), "the offer went")
	w:advance(3)
	ok(B.pendingOffers[key(T.ANA)], "control: the card is there")
	ok(B.AnswerOffer(T.ANA, false), "Bea says No")
	eq(B.pendingOffers[key(T.ANA)], nil, "the card is answered")
	w:advance(3)
	local tn = team(w, "TN", T.BEA, "WHISPER")
	eq(#tn, 1, "one TN") eq(tn[1].text, "TN~1", "TN carries nothing")
	eq(A.offers[key(T.BEA)].state, "no", "the captain's row says no")
	eq(A.CrewEntry(key(T.BEA)), nil, "Bea is not in Ana's crew")
	eq(B.char().captain, "", "Bea's window joined nothing")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: Yes joins: TY says L for a Warlock, the captain lists her as a lock and tells the group (CRW)", function()
	local w, ana, bea = crew()
	local A, B = ana.W.Drive, bea.W.Drive
	local ty = team(w, "TY", T.BEA, "WHISPER")
	eq(#ty, 1, "one TY") eq(ty[1].text, "TY~1~L", "a Warlock answers L")
	local m = A.CrewEntry(key(T.BEA))
	ok(m, "Bea is in Ana's crew")
	eq(m.role, "lock", "as a Warlock")
	eq(A.offers[key(T.BEA)].state, "yes", "the captain's row says yes")
	local crw = team(w, "CRW", T.ANA, "PARTY")
	ok(#crw > 0, "the captain told the group its crew list")
	ok(crw[#crw].text:find("Bea Jones:L", 1, true), "the list names Bea as a lock: " .. crw[#crw].text)
	ok(B.CrewEntry(key(T.ANA)), "Bea's window took the captain's list (the captain is in it)")
	eq(B.CrewEntry(key(T.BEA)), nil, "never herself")
	ok(type(bea.W.Char().crewOwn) == "table", "her own settings are kept aside on joining")
	eq(A.SyncAnswerer(), true, "the captain answers a sync")
	eq(B.SyncAnswerer(), false, "a member whose captain is in the group does not")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: a Yes from someone never asked, or after 5 minutes, is not believed by the captain", function()
	local w, ana, bea = apart()
	local A, B = ana.W.Drive, bea.W.Drive
	A.OnTeamAddon("WUBERT", "TY~1~L", "WHISPER", T.CAL)
	eq(A.CrewEntry(key(T.CAL)), nil, "a TY with no offer adds nobody")
	eq(#A.char().crew, 0, "the crew is still empty")
	ok(A.OfferCrew(T.BEA), "the offer went")
	w:advance(301) -- Team.lua OFFER_TTL = 300
	B.AnswerOffer(T.ANA, true)
	w:advance(3)
	eq(A.CrewEntry(key(T.BEA)), nil, "a Yes after 5 minutes adds nobody")
	-- (Bea's own window now names Ana as captain anyway: see the notes, a suspected bug)
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: no answer in 20 s from a player whose window was never heard: the row says noapp", function()
	local w, ana, bea = apart()
	local A = ana.W.Drive
	ok(A.OfferCrew(T.BEA), "an offer to Bea, who will not answer")
	w:advance(21) -- Team.lua NOAPP_AFTER = 20, then OfferTick (engine tick or the 1 s slow tick)
	eq(A.offers[key(T.BEA)].state, "noapp", "the wizard can offer Add anyway")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: the game saying nobody of that name plays drops a waiting offer, not an answered one", function()
	local w, ana, bea = apart()
	local A, B = ana.W.Drive, bea.W.Drive
	ok(A.OfferCrew("Zed Gone"), "an offer to someone not playing")
	ok(A.offers[key("Zed Gone")], "control: the row waits")
	w:advance(3) -- the fake game answers an addon whisper to nobody with the system line (harness sendAddon)
	eq(A.offers[key("Zed Gone")], nil, "the offer is gone")
	ok(ana:said("Nobody called Zed is online, so that crew offer is gone."), "the captain is told")
	ok(A.OfferCrew(T.BEA), "an offer to Bea")
	w:advance(3)
	B.AnswerOffer(T.ANA, false)
	w:advance(3)
	ana:chatEvent("CHAT_MSG_SYSTEM", "No player named 'Bea Jones' is currently playing.")
	eq(A.offers[key(T.BEA)].state, "no", "an answered row stays") -- Team.lua: only state "waiting" is dropped
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: CRW counts only from my captain: never me, never a name twice, never a bad role, 8 at most", function()
	local w, ana, bea = crew()
	local B = bea.W.Drive
	B.OnTeamAddon("WUBERT", "CRW~1~Ana Smith:L,Mal Ory:H", "WHISPER", T.CAL)
	eq(B.CrewEntry(key("Mal Ory")), nil, "a CRW from someone not my captain changes nothing")
	B.OnTeamAddon("WUBERT", "CRW~1~Ana Smith:L,Bea Jones:L,Cal Brown:H,Cal Brown:L,Zed Pop:X,Wick Lock:S", "WHISPER", T.ANA)
	eq(#B.char().crew, 3, "Ana, Cal and Wick")
	eq(B.CrewEntry(key(T.CAL)).role, "helper", "the first entry for a name counts")
	eq(B.CrewEntry(key("Zed Pop")), nil, "an unknown role is skipped")
	local wick = B.CrewEntry(key("Wick Lock"))
	ok(wick, "S is a summoner without Wuber")
	eq(wick.role, "lock") eq(wick.app, false)
	local names = { "Ana Smith:L" }
	for i = 1, 11 do names[#names + 1] = "Helper H" .. string.char(96 + i) .. ":H" end
	B.OnTeamAddon("WUBERT", "CRW~1~" .. table.concat(names, ","), "WHISPER", T.ANA)
	eq(#B.char().crew, 8, "8 at most")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: a TL from a stranger keeps me in my crew; my captain's TL takes me out and says so", function()
	local w, ana, bea = crew()
	local B = bea.W.Drive
	B.OnTeamAddon("WUBERT", "TL~1", "WHISPER", T.CAL)
	ok(B.char().captain ~= "", "still in Ana's crew")
	B.OnTeamAddon("WUBERT", "TL~1", "WHISPER", T.ANA)
	eq(B.char().captain, "", "out of the crew")
	eq(#B.char().crew, 0, "no crew list")
	eq(bea.W.Char().crewOwn, nil, "her own settings are back")
	ok(bea:said("you are no longer in Ana's crew"), "Bea is told")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: a group fact counts only from my group, protocol 1, at most 255 bytes, on PARTY or RAID", function()
	local w, ana, bea = crew()
	local A, B = ana.W.Drive, bea.W.Drive
	A.SetPrice(20000)
	A.SendConfig()
	w:advance(5)
	eq(bea.W.Char().price, 20000, "control: the captain's price reached Bea")
	local sent = team(w, "CFG", T.ANA, "PARTY")
	ok(#sent > 0, "control: the captain's CFG went to the party")
	local f = T.fields(sent[#sent])
	f[4] = "44444" -- CFG field 2: the price (Team.lua SendConfig)
	local forged = table.concat(f, "~")
	B.OnTeamAddon("WUBERT", forged, "PARTY", "Mal Ory")
	eq(bea.W.Char().price, 20000, "a sender outside my group is not believed")
	B.OnTeamAddon("WUBERT", (forged:gsub("^CFG~1~", "CFG~2~")), "PARTY", T.ANA)
	eq(bea.W.Char().price, 20000, "a newer protocol is not read")
	B.OnTeamAddon("WUBERT", forged .. "~" .. string.rep("x", 260), "PARTY", T.ANA)
	eq(bea.W.Char().price, 20000, "over 255 bytes is not read")
	B.OnTeamAddon("WUBERT", forged, "GUILD", T.ANA)
	eq(bea.W.Char().price, 20000, "a group fact on another channel is not read")
	B.OnTeamAddon("WUBER", forged, "PARTY", T.ANA)
	eq(bea.W.Char().price, 20000, "another prefix is not the crew's")
	B.OnTeamAddon("WUBERT", forged, "PARTY", T.ANA)
	eq(bea.W.Char().price, 44444, "control: the same CFG from the captain is believed")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: while chat is locked a newer CFG replaces the queued one, one ST per rider, whispers never merge", function()
	local w, ana, bea = crew()
	local A = ana.W.Drive
	ana.chatLock = true -- the game refuses every addon send with 11 (harness sendAddon)
	A.SendConfig()
	local n0 = (A.CommBacklog())
	ok(n0 >= 1, "the CFG waits in the outbox")
	A.SendConfig()
	eq((A.CommBacklog()), n0, "the newer CFG took the older one's place")
	A.Send("ST", T.TESTCHAR, "joined")
	eq((A.CommBacklog()), n0 + 1, "a rider's ST queues")
	A.Send("ST", T.TESTCHAR, "summoning")
	eq((A.CommBacklog()), n0 + 1, "the same rider's newer ST replaces it")
	A.Send("ST", T.BOB, "joined")
	eq((A.CommBacklog()), n0 + 2, "another rider's ST queues")
	A.Send("TPL", "thanks", "one")
	A.Send("TPL", "thanks", "one")
	eq((A.CommBacklog()), n0 + 4, "other facts queue in order, never merged")
	A.Whisper(T.BEA, "CRW", "x")
	A.Whisper(T.BEA, "CRW", "x")
	eq((A.CommBacklog()), n0 + 6, "whispers never replace each other")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: the bulk lane takes the same text once and holds 50 at most; the outbox is never cut", function()
	local w, ana, bea = crew()
	local A = ana.W.Drive
	ana.chatLock = true
	A.Send("TPL", "thanks", "held")
	local n0, b0 = A.CommBacklog()
	A.SendBulk("TPL", "greet", "hello")
	A.SendBulk("TPL", "greet", "hello")
	eq(select(2, A.CommBacklog()), b0 + 1, "the same bulk text queues once")
	for i = 1, 60 do A.SendBulk("BLK", "zed pop" .. i, "spam", "") end
	eq(select(2, A.CommBacklog()), 50, "the bulk lane holds 50 at most") -- Team.lua BULK_MAX
	eq((A.CommBacklog()), n0, "nothing left the outbox")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: a fact on the wire: empty trailing fields dropped, a ~ never splits a field, a long one cut on a letter", function()
	local w, ana, bea = crew()
	local A = ana.W.Drive
	local n0 = #team(w, "XX", T.ANA)
	A.Send("XX", "a", "", nil, "") -- XX: no kind any window reads
	A.Send("XX", "a~b|c")
	A.Send("XX", string.rep("\195\169", 150)) -- 150 e-acute: 300 bytes
	w:advance(3)
	local got = team(w, "XX", T.ANA, "PARTY")
	eq(#got, n0 + 3, "three facts went")
	eq(got[n0 + 1].text, "XX~1~a", "no empty fields at the end")
	eq(got[n0 + 2].text, "XX~1~a bc", "a ~ in a field is a space, a | goes") -- W.Clean (Core/Runtime.lua:325)
	local long = got[n0 + 3].text
	eq(#long, 249, "cut under 250 bytes before a letter's first byte") -- field cut to 250, then the text to 249
	eq(long:sub(-2), "\195\169", "the last letter is whole")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: out of a group no fact queues; a whisper with no name queues nothing", function()
	local w = T.newWorld()
	local ana = lock(w, T.ANA)
	T.settle(w)
	local A = ana.W.Drive
	local n0, b0 = A.CommBacklog()
	A.Send("XX", "alone")
	A.SendBulk("XX", "alone")
	A.Whisper(nil, "TL")
	local n1, b1 = A.CommBacklog()
	eq(n1, n0, "no fact, no whisper queued") eq(b1, b0, "no bulk queued")
	w:advance(3)
	eq(#team(w, "XX"), 0, "nothing sent")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: own settings put back from damaged saved values are clamped (price, largest group, whisper mode)", function()
	local w = T.newWorld()
	local bea = lock(w, T.BEA)
	T.settle(w)
	local B = bea.W.Drive
	local ch = B.char()
	ch.crewOwn = { price = 1, maxGroup = 2, whisperMode = "shout", kickAfter = "yes", dest = 42 }
	eq(B.RestoreOwnConfig(), true, "something was kept aside")
	eq(ch.price, bea.W.MIN_PRICE, "a price under the minimum comes back as the minimum")
	eq(tonumber(B.opts().maxGroup) or 0, 0, "a largest group under 3 is automatic")
	ok(B.opts().whisperMode ~= "shout", "an unknown whisper mode is not kept")
	ok(B.opts().kickAfter ~= "yes", "a kick that is not true/false is not kept")
	eq(ch.dest, "", "a place that is not text is no place")
	eq(ch.crewOwn, nil, "nothing aside any more")
	local before = ch.price
	ch.crewOwn = { price = 0 / 0, maxGroup = 99 }
	B.RestoreOwnConfig()
	eq(ch.price, before, "a NaN price leaves the price alone")
	eq(B.opts().maxGroup, 40, "largest group at most 40")
	T.clean(w)
end)

-- guard: coverage, fable-2411 draft adopted in r52
test("drive.team: the crew list on the wire: the captain first, then L, H, P (helper without Wuber), S; 9 pairs at most", function()
	local w = T.newWorld()
	local crewList = {
		{ name = T.BEA, role = "lock", app = true }, { name = T.CAL, role = "helper", app = true },
		{ name = "Dru Oak", role = "helper", app = false }, { name = "Wick Lock", role = "lock", app = false },
	}
	local ana = w:addClient(T.ANA, { spot = "Orgrimmar", class = "WARLOCK",
		saved = { Wuber = { chars = { [key(T.ANA)] = { crew = crewList, captain = "", wizard = true } } } } })
	T.settle(w)
	local A = ana.W.Drive
	eq(A.CrewList(), "Ana Smith:L,Bea Jones:L,Cal Brown:H,Dru Oak:P,Wick Lock:S", "the wire")
	for i = 1, 6 do A.char().crew[#A.char().crew + 1] = { name = "Helper H" .. string.char(96 + i), role = "helper", app = true } end
	local _, commas = A.CrewList():gsub(",", ",")
	eq(commas, 8, "9 pairs at most")
	T.clean(w)
end)
