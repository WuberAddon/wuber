-- Tests of Drive.Queue (BRIEF18 00:50, the author's real bug: he hearthed from Undercity to Orgrimmar
-- while open, two riders who wanted Undercity were in the queue, and after Close/Open Wuber invited
-- both, to be summoned to Orgrimmar). Loaded by tests/run.lua with its helper table T.
-- A rider's request remembers its place (DR.Request: c.forPlace, and c.dest from the words); when the
-- driver's place changes, riders for the old one who were not summoned and are not paying are dropped
-- (DR.PlaceSweep) and the ones already told something are owed a short whisper that only the big
-- button's click sends (DR.moved, Drive.Chat's "moved" kind); the invite, the arrival and the big
-- button refuse them meanwhile; Close/Open (and a new place) clears them at once.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, DAN, EVE = "Ana Smith", "Dan Miller", "Eve Stone"
local SORRY = "Sorry Dan, I've moved to Orgrimmar - no summon to Undercity right now."

local function GetTimeOf(c) return c.env.GetTime() end

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function press(c)
	local b = c.env.WuberDriveButton
	ok(b and H.visible(b), c.player.name .. ": the big button")
	return c:click(b)
end

-- a solo Warlock driver in Undercity, open
local function setup(opts)
	opts = opts or {}
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = opts.spot or "Undercity", class = "WARLOCK", shards = 10 })
	-- (in Ratchet: a rider where the driver lands counts as arrived)
	w:addBot(DAN, { spot = "Ratchet", acceptsInvites = opts.accepts == true })
	w:addBot(EVE, { spot = "Ratchet", acceptsInvites = opts.accepts == true })
	w:advance(15)
	local DR = a.W.Drive
	if opts.noInvite then DR.opts().autoInvite = false end
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	return w, a, DR
end

local function invitesTo(w, name)
	local n = 0
	for _, i in ipairs(w.invites) do if key(i.to) == key(name) then n = n + 1 end end
	return n
end

local function sorryTo(w, name)
	local out = {}
	for _, x in ipairs(w:whispersTo(name)) do if x.text:find("moved to", 1, true) then out[#out + 1] = x end end
	return out
end

local function hearth(a, on)
	if on then
		a.env.UnitCastingInfo = function(unit)
			if unit == "player" then return "Hearthstone", "", 134414, 0, 10000, false, "Cast-1", false, 8690 end
		end
		a:fire("UNIT_SPELLCAST_START", "player", "Cast-1", 8690)
	else
		a.env.UnitCastingInfo = function() return nil end
	end
end

test("Drive.Queue: contract (registered, deps, header, public names)", function()
	local W, w = T.contract("Drive.Queue", "tests/drive/queue_test.lua", {
		["DR.Request"] = "function", ["DR.PumpInvites"] = "function", ["DR.QueueTick"] = "function",
		["DR.ServedPlaces"] = "function", ["DR.PlaceOK"] = "function", ["DR.PlaceStale"] = "function",
		["DR.PlaceSweep"] = "function", ["DR.Travelling"] = "function", ["DR.moved"] = "table",
		["DR.PLACE_SETTLE"] = "number", ["DR.MOVED_TTL"] = "number",
	})
	T.clean(w)
end)

test("drive.queue: BRIEF18 (a) a request remembers its place (and the words' place, which never refuses it)", function()
	local w, a, DR = setup({ noInvite = true })
	w:botWhisper(DAN, a, "WTB summon to Undercity for 50s")
	w:botWhisper(EVE, a, "summon pls")
	w:advance(1)
	local dan, eve = DR.customers[key(DAN)], DR.customers[key(EVE)]
	eq(dan and dan.state, "queued", "Dan queued")
	eq(dan and dan.forPlace, "Undercity", "Dan's request is for Undercity (the place when he asked)")
	eq(dan and dan.dest, "Undercity", "and the place his words named")
	eq(eve and eve.forPlace, "Undercity", "Eve named no place: the place when she asked")
	ok(DR.PlaceOK(dan) and DR.PlaceOK(eve), "both for the place we serve")
	-- the words name where the rider stands, not where they go: still a rider for Undercity
	w:addBot("Fay Wood", { spot = "Ironforge", acceptsInvites = true })
	w:botWhisper("Fay Wood", a, "summon pls, I'm at the bank in Ironforge")
	w:advance(3)
	local fay = DR.customers[key("Fay Wood")]
	eq(fay and fay.forPlace, "Undercity", "Fay's request is for Undercity")
	eq(fay and fay.dest, "Ironforge", "her words named Ironforge (kept)")
	ok(DR.PlaceOK(fay), "not refused for it")
	ok(fay and (fay.state == "queued" or fay.state == "invited"), "Fay is in the queue: " .. tostring(fay and fay.state))
	T.clean(w)
end)

test("drive.queue: BRIEF18 (b) the driver hearths: queued riders for the old place go, untold ones silently", function()
	local w, a, DR = setup({ noInvite = true })
	w:botWhisper(DAN, a, "summon pls")
	w:botWhisper(EVE, a, "summon pls")
	w:advance(1)
	ok(DR.customers[key(DAN)] and DR.customers[key(EVE)], "both queued")
	w:move(ANA, "Orgrimmar")
	w:advance(0.5)
	-- a moment after the zone line: the invite already refuses them
	DR.opts().autoInvite = true
	DR.PumpInvites()
	w:advance(0.2)
	eq(invitesTo(w, DAN) + invitesTo(w, EVE), 0, "no invite while the place settles")
	w:advance(4)
	eq(DR.customers[key(DAN)], nil, "Dan is off the queue")
	eq(DR.customers[key(EVE)], nil, "Eve is off the queue")
	eq(invitesTo(w, DAN) + invitesTo(w, EVE), 0, "nobody was invited to Orgrimmar")
	for _, p in ipairs(DR.Pending()) do ok(p.kind ~= "moved", "queued riders were told nothing: no whisper owed") end
	-- Dan asks again, now for Orgrimmar: a rider again, invited
	w:botWhisper(DAN, a, "summon pls")
	w:advance(2)
	eq(DR.customers[key(DAN)] and DR.customers[key(DAN)].forPlace, "Orgrimmar", "asked again: for Orgrimmar")
	eq(invitesTo(w, DAN), 1, "and invited")
	T.clean(w)
end)

test("drive.queue: BRIEF18 the hearth while a whisper arrives mid-cast: no invite, then dropped after the zone changes", function()
	local w, a, DR = setup({ accepts = true })
	hearth(a, true)
	w:advance(1)
	ok(DR.Travelling(), "the hearth is being cast")
	w:botWhisper(DAN, a, "summon pls")
	w:advance(3)
	local dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "queued", "Dan is queued (asked while still in Undercity)")
	eq(dan and dan.forPlace, "Undercity", "for Undercity")
	eq(invitesTo(w, DAN), 0, "no invite while the hearth is cast")
	-- the hearth lands
	hearth(a, false)
	w:move(ANA, "Orgrimmar")
	w:advance(5)
	eq(DR.customers[key(DAN)], nil, "Dan is off the queue")
	eq(invitesTo(w, DAN), 0, "never invited")
	local plan = DR.Plan()
	ok(not (plan.macrotext or ""):find("Dan", 1, true), "the big button has nothing for Dan: " .. tostring(plan.macrotext))
	-- a hearth cast that is cancelled: invites go on as before
	hearth(a, true)
	w:botWhisper(EVE, a, "summon pls")
	w:advance(2)
	eq(invitesTo(w, EVE), 0, "held while the hearth is cast")
	hearth(a, false)
	w:advance(3)
	eq(invitesTo(w, EVE), 1, "cancelled hearth: Eve is invited")
	T.clean(w)
end)

test("drive.queue: BRIEF18 (b) an invite already out: dropped, its late accept is no rider, the sorry whisper waits for the click", function()
	local w, a, DR = setup({ accepts = false })
	w:botWhisper(DAN, a, "summon pls")
	w:advance(3)
	eq(DR.customers[key(DAN)] and DR.customers[key(DAN)].state, "invited", "Dan is invited (he has not answered)")
	w:move(ANA, "Orgrimmar")
	w:advance(5)
	eq(DR.customers[key(DAN)], nil, "Dan is off the list")
	local m = DR.moved[key(DAN)]
	ok(m, "Dan is remembered as moved away")
	eq(m and m.from, "Undercity", "from Undercity") eq(m and m.to, "Orgrimmar", "to Orgrimmar")
	-- the whisper is never sent by itself
	w:advance(10)
	eq(#sorryTo(w, DAN), 0, "nothing sent without a click")
	local owed
	for _, p in ipairs(DR.Pending()) do if p.kind == "moved" then owed = p end end
	ok(owed and owed.c.name == DAN, "Dan is owed the sorry whisper")
	eq(DR.Text("moved", m), SORRY, "the words")
	local plan = DR.Plan()
	ok((plan.macrotext or ""):find(SORRY, 1, true), "the click's macro has it: " .. tostring(plan.macrotext))
	press(a)
	w:advance(2)
	local sent = sorryTo(w, DAN)
	eq(#sent, 1, "one sorry whisper")
	eq(sent[1] and sent[1].how, "macro", "from the secure macro (the click)")
	eq(sent[1] and sent[1].text, SORRY, "what Dan reads")
	for _, p in ipairs(DR.Pending()) do ok(p.kind ~= "moved", "told once") end
	-- the old invite is accepted late: not a rider, never summoned
	w:join(a.player, w:player(DAN))
	w:advance(2)
	eq(DR.customers[key(DAN)], nil, "his late accept made no rider")
	ok(DR.ignored[key(DAN)], "ignored while in the group")
	eq(DR.NextSummon(), nil, "the big button summons nobody")
	ok(not (DR.Plan().macrotext or ""):find("/cast", 1, true), "no cast on the button")
	eq(#sorryTo(w, DAN), 1, "and no second sorry")
	-- Skip on the sorry whisper: not sent, nobody blocked
	DR.moved[key(EVE)] = { name = EVE, key = key(EVE), from = "Undercity", to = "Orgrimmar", movedTo = "Orgrimmar", at = GetTimeOf(a), told = false }
	w:advance(1.5)
	local sc, sk = DR.SkipTarget()
	ok(sc == DR.moved[key(EVE)] and sk == "moved", "the button is about Eve's sorry whisper: " .. tostring(sk))
	DR.Skip()
	ok(DR.moved[key(EVE)].told, "skipped: not owed any more")
	eq(DR.db.blocklist[key(EVE)], nil, "and not blocked")
	for _, p in ipairs(DR.Pending()) do ok(p.kind ~= "moved", "nothing owed") end
	T.clean(w)
end)

test("drive.queue: BRIEF18 (b, c) a joined rider for the old place: the button refuses at once, then dropped and told", function()
	local w, a, DR = setup({ accepts = true })
	w:botWhisper(DAN, a, "summon pls")
	w:advance(4)
	local dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "joined", "Dan joined the group")
	ok(DR.NextSummon() == dan, "ready to summon in Undercity")
	w:move(ANA, "Orgrimmar")
	w:advance(0.3)
	ok(DR.PlaceStale(dan), "Dan's place is not ours any more")
	eq(DR.NextSummon(), nil, "the big button refuses him straight away")
	local plan = DR.Plan()
	ok(not (plan.macrotext or ""):find("/cast", 1, true), "no cast on the button: " .. tostring(plan.macrotext))
	w:advance(5)
	eq(DR.customers[key(DAN)], nil, "dropped")
	ok(DR.ignored[key(DAN)], "still in the group, ignored (never kicked by Wuber)")
	press(a)
	w:advance(2)
	eq(#sorryTo(w, DAN), 1, "told by the click")
	T.clean(w)
end)

test("drive.queue: BRIEF18 never drops a rider being summoned or paying", function()
	local w, a, DR = setup({ accepts = true })
	w:botWhisper(DAN, a, "summon pls")
	w:botWhisper(EVE, a, "summon pls")
	w:advance(6)
	local dan, eve = DR.customers[key(DAN)], DR.customers[key(EVE)]
	ok(dan and eve, "both listed")
	DR.SetState(dan, "summoning")
	dan.tries = 1
	eve.paid, eve.state = 2500, "joined"
	eve.tries = 1
	w:move(ANA, "Orgrimmar")
	w:advance(6)
	ok(DR.customers[key(DAN)] == dan, "Dan (being summoned) stays")
	ok(DR.customers[key(EVE)] == eve, "Eve (summoned before, paying) stays")
	eq(DR.moved[key(DAN)], nil) eq(DR.moved[key(EVE)], nil)
	T.clean(w)
end)

test("drive.queue: BRIEF18 (d) Close/Open in a new place clears the old place's queue at once", function()
	local w, a, DR = setup({ noInvite = true })
	w:botWhisper(DAN, a, "summon pls")
	w:advance(1)
	ok(DR.customers[key(DAN)], "Dan queued in Undercity")
	DR.SetOpen(false)
	w:move(ANA, "Orgrimmar")
	w:advance(1)
	DR.opts().autoInvite = true
	ok(DR.SetOpen(true), "open again")
	eq(DR.customers[key(DAN)], nil, "Open in Orgrimmar: Dan is gone at once")
	w:advance(3)
	eq(invitesTo(w, DAN), 0, "never invited")
	ok(DR.Plan().sub:find("Orgrimmar", 1, true), "the button says Orgrimmar: " .. tostring(DR.Plan().sub))
	-- a new place set by hand does the same
	DR.opts().autoInvite = false
	w:botWhisper(EVE, a, "summon pls")
	w:advance(1)
	ok(DR.customers[key(EVE)], "Eve queued for Orgrimmar")
	DR.SetDest("Undercity")
	eq(DR.customers[key(EVE)], nil, "the place set to Undercity: Eve (for Orgrimmar) is gone")
	T.clean(w)
end)

---------------------------------------------------------------------------
-- BRIEF18 00:53 (the author, serving Orgrimmar: Bauer whispered "do you do UC summ?" and was invited)
-- and 00:55 (no path invites a rider who named a place we don't serve)
---------------------------------------------------------------------------

local BAU = "Bauer Burkhard"

local function alertsOf(a, pattern)
	local out = {}
	for _, f in ipairs(a.fired) do
		if f.name == "DRIVE_ALERT" and tostring(f.args[1]):find(pattern, 1, true) then out[#out + 1] = f.args[1] end
	end
	return out
end

local function inOrg(opts)
	opts = opts or {}
	opts.spot = "Orgrimmar"
	local w, a, DR = setup(opts)
	w:addBot(BAU, { spot = "Durotar", acceptsInvites = opts.accepts == true })
	w:advance(1)
	return w, a, DR
end

test("drive.queue: 00:53 a whisper naming another place is a lead, never invited", function()
	local w, a, DR = inOrg()
	w:botWhisper(BAU, a, "do you do UC summ?")
	w:advance(4)
	local c = DR.customers[key(BAU)]
	eq(c and c.state, "lead", "Bauer is a lead (shown, for the driver to decide)")
	eq(c and c.askedFor, "Undercity", "he asked for Undercity")
	eq(invitesTo(w, BAU), 0, "not invited")
	-- the words read for a whisper
	eq((DR.AskedFor("do you do UC summ?")), "elsewhere")
	eq((DR.AskedFor("do you do summons?")), "noplace", "no place: a request for us")
	eq((DR.AskedFor("summ to org pls")), "match")
	eq((DR.AskedFor("summon pls, I'm in Durotar")), "noplace", "where they stand is no place asked for")
	eq((DR.AskedFor("summon from UC pls")), "noplace", "from Undercity: to us")
	eq((DR.AskedFor("summ uc to org?")), "match", "the place after \"to\" decides")
	eq((DR.AskedFor("summ org to uc?")), "elsewhere")
	eq((DR.AskedFor("summ org or uc?")), "unclear", "ours and another, no \"to\": unclear")
	-- he says "summon pls" next: still the place he asked for, still a lead
	w:botWhisper(BAU, a, "summon pls")
	w:advance(4)
	eq(DR.customers[key(BAU)] and DR.customers[key(BAU)].state, "lead", "still a lead")
	eq(invitesTo(w, BAU), 0, "still not invited")
	-- he settles for Orgrimmar: a request, invited
	w:botWhisper(BAU, a, "ok summ to org then")
	w:advance(4)
	eq(invitesTo(w, BAU), 1, "invited for Orgrimmar")
	T.clean(w)
end)

test("drive.queue: 00:53 whispers without a place, or naming ours, are requests (invited)", function()
	local w, a, DR = inOrg()
	w:botWhisper(DAN, a, "can i get a summon pls") -- (2.4, careful mode: "do you do summons?" is a question about the service, a lead: tests/v24/careful_test.lua)
	w:advance(3)
	w:botWhisper(EVE, a, "summ to org pls")
	w:advance(3)
	w:botWhisper(BAU, a, "summon pls, I'm in Durotar")
	w:advance(3)
	eq(invitesTo(w, DAN), 1, "no place named: invited")
	eq(invitesTo(w, EVE), 1, "Orgrimmar named: invited")
	eq(invitesTo(w, BAU), 1, "only where he stands named: invited")
	eq(DR.customers[key(EVE)] and DR.customers[key(EVE)].askFor, "Orgrimmar", "Eve's request names Orgrimmar")
	-- two places, ours and another, without "to": a lead
	w:addBot("Fay Wood", { spot = "Durotar" })
	w:botWhisper("Fay Wood", a, "need summ org or uc")
	w:advance(3)
	eq(DR.customers[key("Fay Wood")] and DR.customers[key("Fay Wood")].state, "lead", "unclear: a lead")
	eq(invitesTo(w, "Fay Wood"), 0, "not invited")
	T.clean(w)
end)

test("drive.queue: 00:53 public chat and app requests for another place are never invited", function()
	local w, a, DR = inOrg()
	DR.opts().watchPublic, DR.opts().autoPublic = true, true
	DR.PublicLine("WTB summon to UC", BAU, true)
	w:advance(3)
	eq(invitesTo(w, BAU), 0, "public chat for Undercity: not invited")
	DR.PublicLine("WTB summon to org", DAN, true)
	w:advance(3)
	eq(invitesTo(w, DAN), 1, "public chat for Orgrimmar: invited")
	-- the Wuber app's request line, and its addon request
	w:botWhisper(EVE, a, "WTB summon to Undercity for 50s")
	w:advance(3)
	eq(DR.customers[key(EVE)] and DR.customers[key(EVE)].state, "lead", "an app line for Undercity: a lead")
	eq(invitesTo(w, EVE), 0, "not invited")
	w:addBot("Fay Wood", { spot = "Durotar" })
	w:inject("Fay Wood", "R~1~fayrid~Undercity~5000", "WHISPER", a)
	w:advance(3)
	eq(invitesTo(w, "Fay Wood"), 0, "a Wuber ride for Undercity: not invited")
	w:addBot("Gil Moss", { spot = "Durotar" })
	w:inject("Gil Moss", "R~1~gilrid~Orgrimmar~5000", "WHISPER", a)
	w:advance(3)
	eq(invitesTo(w, "Gil Moss"), 1, "a Wuber ride for Orgrimmar: invited")
	T.clean(w)
end)

test("drive.queue: 00:53 the driver's own add (or a lead clicked) is kept, and says the other place", function()
	local w, a, DR = inOrg()
	w:botWhisper(BAU, a, "do you do UC summ?")
	w:advance(3)
	local c = DR.customers[key(BAU)]
	eq(c and c.state, "lead")
	local made = DR.Invite(c) -- the row click
	w:advance(3)
	ok(made and made.state ~= "lead", "the driver's click makes him a rider")
	eq(invitesTo(w, BAU), 1, "invited: the driver chose to")
	eq(made and made.askedFor, "Undercity", "the row keeps what he asked for")
	local said = alertsOf(a, "asked for Undercity")
	eq(#said, 1, "the console says so once")
	eq(said[1], "Bauer asked for Undercity, not Orgrimmar: on your list because you added them.")
	-- /wuber drive add with no words: a plain rider, nothing to say
	DR.Request(DAN, "manual")
	w:advance(3)
	eq(invitesTo(w, DAN), 1, "added by hand: invited")
	eq(#alertsOf(a, "Dan"), 0, "no note for Dan")
	T.clean(w)
end)

test("drive.queue: 00:53 a lead for another place who joins by hand is the driver's choice; nobody is invited", function()
	local w, a, DR = inOrg()
	w:botWhisper(BAU, a, "do you do UC summ?")
	w:advance(20)
	eq(invitesTo(w, BAU), 0, "never invited by Wuber")
	w:join(a.player, w:player(BAU))
	w:advance(2)
	local c = DR.customers[key(BAU)]
	eq(c and c.state, "joined", "invited by hand: a rider")
	eq(#alertsOf(a, "joined, but asked for Undercity"), 1, "the console says what he asked for")
	T.clean(w)
end)

test("drive.queue: 00:53 a request read before the place was known waits, then is a lead for another place", function()
	local w, a, DR = inOrg()
	local real = DR.ServedPlaces
	DR.ServedPlaces = function() return nil end
	local realDest = DR.Dest
	DR.Dest = function() return "our spot" end
	w:botWhisper(BAU, a, "summ to uc pls")
	w:advance(0.2)
	local c = DR.customers[key(BAU)]
	eq(c and c.state, "queued", "queued while we can't tell")
	eq(c and c.askFor, "Undercity", "for Undercity")
	eq(c and c.forPlace, nil, "no place of ours known yet")
	DR.PumpInvites()
	eq(invitesTo(w, BAU), 0, "not invited while we can't tell")
	DR.ServedPlaces, DR.Dest = real, realDest
	w:advance(3)
	c = DR.customers[key(BAU)]
	eq(c and c.state, "lead", "a lead once we know we serve Orgrimmar")
	eq(c and c.askedFor, "Undercity")
	eq(invitesTo(w, BAU), 0, "never invited")
	-- (lead review #7) one who named no place gets the place lazily
	DR.ServedPlaces = function() return nil end
	w:botWhisper(DAN, a, "summon pls")
	w:advance(0.2)
	eq(DR.customers[key(DAN)] and DR.customers[key(DAN)].forPlace, nil, "no place yet")
	DR.ServedPlaces = real
	DR.PlaceSweep()
	eq(DR.customers[key(DAN)] and DR.customers[key(DAN)].forPlace, "Orgrimmar", "filled in when known")
	T.clean(w)
end)

test("drive.queue: 00:53 a crew window that hears a whisper for another place hands nothing to the leader", function()
	local BEA = "Bea Lock"
	local function saved(me, captain, crew)
		return { Wuber = { chars = { [key(me)] = { crew = crew, captain = captain, wizard = true } } } }
	end
	local w = H.NewWorld({})
	local a = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", shards = 10,
		saved = saved(ANA, "", { { name = BEA, role = "lock", app = true } }) })
	local b = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK", shards = 10,
		saved = saved(BEA, ANA, { { name = ANA, role = "lock", app = true } }) })
	w:group({ ANA, BEA })
	w:advance(15)
	local DA, DB = a.W.Drive, b.W.Drive
	ok(DA.SetOpen(true), "open")
	w:advance(3)
	w:addBot(BAU, { spot = "Durotar", acceptsInvites = false })
	w:addBot(DAN, { spot = "Durotar", acceptsInvites = false })
	w:botWhisper(BAU, b, "do you do UC summ?")
	w:advance(3)
	eq(DB.customers[key(BAU)] and DB.customers[key(BAU)].state, "lead", "a lead in Bea's window")
	local atAna = DA.customers[key(BAU)]
	ok(not atAna or atAna.state == "lead", "Ana (the leader) has no request for him")
	eq(invitesTo(w, BAU), 0, "nobody invites him")
	-- a plain request to Bea reaches Ana, who invites
	w:botWhisper(DAN, b, "summon pls")
	w:advance(3)
	ok(DA.customers[key(DAN)], "Dan's request reached Ana (ASK)")
	eq(invitesTo(w, DAN), 1, "and Ana invited him")
	T.clean(w)
end)

test("drive.queue: lead review #1 a Warlock who typed a place and hearths away serves where they stand", function()
	local w, a, DR = setup({ noInvite = true })
	DR.SetDest("Undercity")
	w:advance(1)
	w:botWhisper(DAN, a, "summon pls")
	w:advance(1)
	eq(DR.customers[key(DAN)] and DR.customers[key(DAN)].forPlace, "Undercity")
	w:move(ANA, "Orgrimmar")
	w:advance(6)
	eq(DR.char().dest, "", "the typed place is cleared")
	eq(DR.ServedPlaces()[1], "Orgrimmar", "serves Orgrimmar")
	eq(#alertsOf(a, "You left Undercity"), 1, "the console says so")
	eq(DR.customers[key(DAN)], nil, "Dan (for Undercity) went")
	-- a place typed while standing elsewhere is kept (on the way there)
	DR.SetDest("Undercity")
	w:advance(3)
	eq(DR.char().dest, "Undercity", "kept: never stood there")
	T.clean(w)
end)

test("drive.queue: lead review #3 #6 a moved rider who was never invited can join by hand; a failed summon goes too", function()
	local w, a, DR = setup({ noInvite = true })
	w:botWhisper(DAN, a, "summon pls")
	w:advance(1)
	w:move(ANA, "Orgrimmar")
	w:advance(6)
	ok(DR.moved[key(DAN)] and not DR.moved[key(DAN)].invited, "Dan went while only queued")
	w:join(a.player, w:player(DAN))
	w:advance(2)
	local c = DR.customers[key(DAN)]
	eq(c and c.state, "joined", "invited by hand: a rider all the same")
	ok(not DR.ignored[key(DAN)], "not ignored")
	-- a joined rider whose summon failed, for the place we left, goes too
	w:move(ANA, "Undercity")
	w:advance(6)
	eq(DR.customers[key(DAN)], nil, "Dan (joined in Orgrimmar) went when we left")
	T.clean(w)
end)

test("drive.queue: lead review #6 a joined rider with a failed summon is stale", function()
	local w, a, DR = setup({ accepts = true })
	w:botWhisper(DAN, a, "summon pls")
	w:advance(4)
	local dan = DR.customers[key(DAN)]
	eq(dan and dan.state, "joined")
	dan.tries = 1
	w:move(ANA, "Orgrimmar")
	w:advance(0.3)
	ok(DR.PlaceStale(dan), "stale whatever tries is")
	w:advance(5)
	eq(DR.customers[key(DAN)], nil, "dropped")
	T.clean(w)
end)

test("drive.queue: lead review #4 several stations: the sorry whisper names our stations", function()
	local w, a, DR = setup({ noInvite = true })
	w:botWhisper(DAN, a, "summon pls")
	w:advance(1)
	local dan = DR.customers[key(DAN)]
	dan.station, dan.forPlace = "Ironforge", "Ironforge"
	dan.greeted = true
	DR.MultiStation = function() return true end
	DR.ServedPlaces = function() return { "Undercity", "Orgrimmar" } end
	DR.PlacesText = function() return "Undercity and Orgrimmar" end
	eq(DR.PlaceSweep(true), 1, "Dan went")
	local m = DR.moved[key(DAN)]
	eq(m and m.movedTo, "Undercity and Orgrimmar", "both stations, not one at random")
	T.clean(w)
end)


---------------------------------------------------------------------------
-- inviting public chat buyers is off by default, and on only after a warning
---------------------------------------------------------------------------

local WARNING = "Wuber reads public chat channels (Trade, LookingForGroup, Services, World, General) and invites players who seem to want your place. It can misread messages,"
	.. " so set your place and stations correctly first, and expect the odd wrong invite. Turn it on?"

-- the warning on screen: its text; answers Yes (true) or Cancel (false) as the popup's buttons do
local function answer(c, yes)
	local which = c.W.Drive.PUBLIC_POPUP
	ok(c.env.StaticPopup_FindVisible(which), "the warning is on screen")
	local dlg = c.env.StaticPopupDialogs[which]
	eq(dlg.text, WARNING)
	eq(dlg.button1, "Yes")
	eq(dlg.button2, "Cancel")
	c.env.StaticPopup_Hide(which)
	if yes then dlg.OnAccept() else dlg.OnCancel() end
end

local function warningShown(c) return c.env.StaticPopup_FindVisible(c.W.Drive.PUBLIC_POPUP) ~= nil end

test("drive.queue: R4 a new driver does not invite public chat buyers; they are listed, whispers still invite", function()
	local w, a, DR = inOrg()
	eq(DR.opts().autoPublic, false, "off for a new player")
	eq(a.W.db.drive.publicV, 1, "the migration is marked done")
	eq(DR.PUBLIC_WARNING, WARNING)
	DR.PublicLine("WTB summon to org", DAN, true)
	w:advance(3)
	local c = DR.customers[key(DAN)]
	eq(c and c.state, "lead", "a Trade buyer for our place is listed")
	eq(invitesTo(w, DAN), 0, "and not invited")
	w:botWhisper(EVE, a, "summ to org pls")
	w:advance(3)
	eq(invitesTo(w, EVE), 1, "a whisper for our place is still invited")
	w:botWhisper(BAU, a, "do you do UC summ?")
	w:advance(3)
	eq(invitesTo(w, BAU), 0, "a whisper for another place still is not (round 18)")
	-- the lead's row: one click invites
	local made = DR.Invite(c)
	w:advance(3)
	ok(made and made.state ~= "lead", "the click makes Dan a rider")
	eq(invitesTo(w, DAN), 1, "invited by the click")
	T.clean(w)
end)

test("drive.queue: R4 the one-time migration turns the old stored default off, keeps a chosen on, runs once", function()
	local w = H.NewWorld({})
	-- a 2.3.1 player: InitDB stored the old default (true); no marker of their own choice
	local old = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK",
		saved = { Wuber = { drive = { opts = { autoPublic = true, watchPublic = true } } } } })
	-- a player who chose it after the warning (the marker DR.SetAutoPublic writes)
	local chose = w:addClient("Cal Brown", { spot = "Orgrimmar", class = "WARLOCK",
		saved = { Wuber = { drive = { publicChosen = true, opts = { autoPublic = true } } } } })
	-- a player who had it off (Tester's)
	local off = w:addClient("Bea Jones", { spot = "Orgrimmar", class = "WARLOCK",
		saved = { Wuber = { drive = { opts = { autoPublic = false } } } } })
	w:advance(3)
	eq(old.W.Drive.opts().autoPublic, false, "never changed: off")
	eq(old.W.Drive.opts().watchPublic, true, "listing public buyers is untouched")
	eq(chose.W.Drive.opts().autoPublic, true, "switched on themselves: on")
	eq(off.W.Drive.opts().autoPublic, false, "off stays off")
	for _, c in ipairs({ old, chose, off }) do eq(c.W.db.drive.publicV, 1, c.player.name .. ": marked done") end
	-- runs once: turned on after the warning, it stays on after a reload
	old.W.Drive.SetAutoPublic(true)
	answer(old, true)
	eq(old.W.Drive.opts().autoPublic, true, "on after Yes")
	old = w:reload(old)
	w:advance(3)
	eq(old.W.Drive.opts().autoPublic, true, "the migration does not run again")
	T.clean(w)
end)

test("drive.queue: R4 /wuber drive market on shows the warning; Cancel leaves it off, Yes turns it on", function()
	local w, a, DR = inOrg()
	local function said(part)
		for _, t in ipairs(a.chatLines or {}) do if t:find(part, 1, true) then return true end end
		return false
	end
	a:slash("/wuber drive market on")
	w:advance(1)
	ok(warningShown(a), "the warning first")
	eq(DR.opts().autoPublic, false, "still off while it asks")
	answer(a, false)
	eq(DR.opts().autoPublic, false, "Cancel: off")
	ok(said("name your place: off."), "the answer is said")
	a:slash("/wuber drive market on")
	w:advance(1)
	answer(a, true)
	eq(DR.opts().autoPublic, true, "Yes: on")
	ok(said("name your place: on."), "said on")
	DR.PublicLine("WTB summon to org", DAN, true)
	w:advance(3)
	eq(invitesTo(w, DAN), 1, "now a Trade buyer for our place is invited")
	a:slash("/wuber drive market off")
	w:advance(1)
	ok(not warningShown(a), "off needs no warning")
	eq(DR.opts().autoPublic, false, "off")
	T.clean(w)
end)


test("drive.queue: R4 review #5 asked twice while the warning is up: one question, both callers hear the answer", function()
	local w, a, DR = inOrg()
	local heard = {}
	eq(DR.SetAutoPublic(true, function(v) heard[#heard + 1] = "first " .. tostring(v) end), "asked")
	local dlg = a.env.StaticPopupDialogs[DR.PUBLIC_POPUP]
	eq(dlg.noCancelOnReuse, 1, "a reused popup never cancels")
	eq(DR.SetAutoPublic(true, function(v) heard[#heard + 1] = "second " .. tostring(v) end), "asked")
	ok(a.env.StaticPopupDialogs[DR.PUBLIC_POPUP] == dlg, "the question on screen is not registered again")
	eq(#heard, 0, "nobody hears an answer before one is given")
	answer(a, true)
	eq(table.concat(heard, ", "), "first true, second true")
	eq(DR.opts().autoPublic, true)
	-- the next question is a new one
	DR.SetAutoPublic(false)
	heard = {}
	eq(DR.SetAutoPublic(true, function(v) heard[#heard + 1] = tostring(v) end), "asked")
	answer(a, false)
	eq(table.concat(heard, ", "), "false", "Cancel: only this caller, off")
	eq(DR.opts().autoPublic, false)
	T.clean(w)
end)


-- (BRIEF22 P1, the author's 13:45 shot: "Any summons to loch modan?" was listed as a rider for an Orgrimmar
-- driver) a place after "to"/"2" that is not mine, known zone or not, is somewhere else: never a buyer
test("drive.queue: P1 a public line asking for another zone (known or not) is elsewhere, never listed", function()
	local w, a, DR = inOrg()
	eq(DR.Dest(), "Orgrimmar", "serving Orgrimmar")
	local elsewhere = {
		"Any summons to loch modan?", "wtb summon to darkshore", "lf summ to hillsbrad pls", "need a summon to stv",
		"any lock summon to the barrens?", "wtb summon to tb", "lf summon to bb", "summon 2 loch modan?",
		"LF summon to Westfall", "wtb summon to duskwood", "any warlock summon to Redridge?", "wtb summon to the wetlands",
		"lf summon to Elwynn", "wtb summon to stranglethorn", "need summon to Dun Morogh", "LFS to ashenvale",
		-- typos of known zones
		"Any summons to loch modn?", "wtb summon to darkshor", "lf summon to hilsbrad", "need summ to the barens",
		"wtb summon to strangelthorn", "lf summon to tanaris pls", "wtb summon to fearlas",
		-- a place-like word nobody knows
		"lf summon to dalaran", "wtb summon to astranaar", "any summons to zanzibar?", "wtb summon to the moonwell",
	}
	for _, line in ipairs(elsewhere) do eq(DR.PublicWant(line), "elsewhere", line) end
	local match = {
		"summon to org", "summon to org pls", "wtb summon to orgrimmar", "lf summ 2 org", "any lock to summon me to org?",
		"need a summon to og asap", "lf summon to orgrimar", "wtb summon to the city of orgrimmar",
		"any summons to org? need to get there", "wtb summon to org, happy to tip",
	}
	for _, line in ipairs(match) do eq(DR.PublicWant(line), "match", line) end
	-- common words after "to" are no place: still a buyer with no place named
	local noplace = {
		"anyone able to summon?", "lf summon, happy to pay", "need a lock to port me", "wtb summon to me",
		"anyone want to summon me?", "lf summon to my group", "wtb summon for 2 ppl", "lf summon to you",
		"need summon to the meeting stone", "lf summon to the instance", "lf sum to go questing", "wtb 2 summons",
		"need a summon too", "lf summon, need to get there fast", "lf summon to orgg",
		-- (review) in-town spots and other generic words after "to": still a buyer
		"lf summon to location", "lf summon to myself", "need a summon to the entrance", "wtb summon to bank",
		"lf summon to arena", "wtb summon to afk", "need summon to rogue trainer", "lf summon to the inn",
		"lf summon to fp", "wtb summon to the mailbox", "lf summon to the auction house", "any summon to my location?",
		"lf summon to the flight master", "need summon to the zeppelin",
	}
	for _, line in ipairs(noplace) do eq(DR.PublicWant(line), "noplace", line) end
	-- the shot's line, through public chat: not listed at all
	DR.opts().watchPublic = true
	DR.PublicLine("Any summons to loch modan?", "Zep Ashrender", true)
	eq(DR.customers[key("Zep Ashrender")], nil, "a buyer for Loch Modan is nobody's rider here")
	DR.PublicLine("Any summons to org?", "Ann Other", true)
	ok(DR.customers[key("Ann Other")] ~= nil, "a buyer for Orgrimmar is listed")
	T.clean(w)
end)

test("drive.queue: P1 a whisper asking for another zone (known or not) is a lead, never invited", function()
	local w, a, DR = inOrg()
	for _, line in ipairs({ "summon to loch modan pls", "can u summ me to darkshore?", "summon to stv", "summ 2 the barrens",
		"summon to tb?", "summon to bb pls", "summon to hilsbrad?", "summon to astranaar pls" }) do
		eq((DR.AskedFor(line)), "elsewhere", line)
	end
	eq(select(2, DR.AskedFor("summon to loch modan pls")), "Loch Modan", "the place asked for")
	eq(select(2, DR.AskedFor("summon to astranaar pls")), "Astranaar", "an unknown place, as written")
	for _, line in ipairs({ "can you summon me to you?", "summon me pls, happy to tip", "need a summon to my group",
		"could you summon me? need to get there", "summon to orgg pls" }) do
		eq((DR.AskedFor(line)), "noplace", line)
	end
	eq((DR.AskedFor("summon to org pls")), "match")
	w:botWhisper(BAU, a, "Any summons to loch modan?")
	w:advance(4)
	local c = DR.customers[key(BAU)]
	eq(c and c.state, "lead", "a lead the driver decides on")
	eq(invitesTo(w, BAU), 0, "not invited")
	T.clean(w)
end)

-- (2.3.3, H2) the warning popup is scaled by UIParent, not the phone: it is scaled to the phone, its
-- text is Wuber's body size, it sits inside the phone, and the shared popup frame is put back
test("drive.queue: H2 the public-invites warning is body-sized at UI scales 0.71, 1 and 1.5, inside the phone", function()
	local w, a, DR = inOrg()
	local env = a.env
	a:slash("/wuber")
	w:advance(2)
	local phone = env.WuberFrame
	ok(phone and phone:IsShown(), "the phone is open")
	local body = a.W.Theme.SIZE.body
	for _, scale in ipairs({ 0.71, 1, 1.5 }) do
		env.UIParent:SetScale(scale)
		local pop = env.CreateFrame("Frame", nil, env.UIParent)
		pop:SetSize(320, 120)
		pop:SetScale(1)
		pop.text = pop:CreateFontString(nil, "ARTWORK")
		pop.text:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
		pop.text:SetText(DR.PUBLIC_WARNING)
		local b1 = env.CreateFrame("Button", nil, pop)
		b1:SetSize(100, 22)
		b1:SetPoint("BOTTOM", pop, "BOTTOM", 0, 16)
		eq(DR.PlacePublicWarning(pop), true, scale .. ": placed")
		local _, size = pop.text:GetFont()
		local pe, ue = phone:GetEffectiveScale(), env.UIParent:GetEffectiveScale()
		eq(size, body, scale .. ": the body size")
		ok(math.abs(size * pop:GetEffectiveScale() - body * pe) < 1e-6, scale .. ": drawn as big as the phone's body text")
		ok(math.abs(pop:GetScale() - pe / ue) < 1e-6, scale .. ": scaled to the phone")
		local pr, r, br = H.rect(phone), H.rect(pop), H.rect(b1)
		ok(r.l >= pr.l - 0.01 and r.l + r.w <= pr.l + pr.w + 0.01, scale .. ": inside the phone's width")
		ok(r.b >= pr.b - 0.01 and r.b + r.h <= pr.b + pr.h + 0.01, scale .. ": inside the phone's height")
		ok(math.abs((r.l + r.w / 2) - (pr.l + pr.w / 2)) < 0.5, scale .. ": centred across")
		ok(br.l >= r.l - 0.01 and br.l + br.w <= r.l + r.w + 0.01, scale .. ": the button is inside the popup")
		ok(DR.RestorePublicWarning(pop), scale .. ": restored")
		local _, size2 = pop.text:GetFont()
		eq(size2, 14, scale .. ": the font is put back")
		eq(pop:GetScale(), 1, scale .. ": the scale is put back")
	end
	env.UIParent:SetScale(1)
	T.clean(w)
end)

---------------------------------------------------------------------------
-- P1 proved for whispers (the author's live test: "any summoon to loch moodan?" whispered to a
-- driver at 16:00 and she did not invite; unknown whether "Invite riders who whisper me" was on).
-- Path: CHAT_MSG_WHISPER -> onWhisper -> DR.Classify -> DR.Request (DR.AskedPlaces) or DR.Lead.
---------------------------------------------------------------------------

-- the row a lead gets in the driver's queue, painted at a console width: its text must fit (P2)
local function leadRowFits(a, c, widths)
	local D, Hh = a.W.Driver, T.H
	local parent = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	parent:SetSize(400, 200)
	parent:SetPoint("CENTER")
	parent:Show()
	for _, wdt in ipairs(widths) do
		local r = D.Row(parent, wdt)
		r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		D.PaintRow(r, c, c.at or 0)
		local text = r.what:GetText() or ""
		ok(Hh.truncation(r.what) == nil, "lead row not cut at " .. wdt .. ": " .. text)
		ok(not r.what:IsTruncated(), "the game says not cut at " .. wdt .. ": " .. text)
		ok(not text:find("...", 1, true), "no dots at " .. wdt .. ": " .. text)
		r:Hide()
	end
end

test("drive.queue: H4 whisper invites ON, driver in Orgrimmar: other zones (typos too) are leads, never invited", function()
	local w, a, DR = inOrg()
	eq(DR.opts().autoInvite, true, "whisper invites are on")
	local lines = {
		{ "Zed One", "any summon to loch modan?", "Loch Modan" },
		{ "Zed Two", "any summoon to loch moodan?", "Loch Modan" },
		{ "Zed Three", "summon to darkshore pls", "Darkshore" },
	}
	for _, l in ipairs(lines) do
		w:addBot(l[1], { spot = "Durotar", acceptsInvites = true })
		w:advance(1)
		w:botWhisper(l[1], a, l[2])
		w:advance(4)
		local c = DR.customers[key(l[1])]
		eq(c and c.state, "lead", l[2] .. ": a lead for the driver to decide")
		eq(invitesTo(w, l[1]), 0, l[2] .. ": not invited (it names another place)")
		eq(c and c.msg, l[2], "the lead keeps the words")
		eq(select(2, DR.AskedFor(l[2])), l[3], "the place read: " .. l[2])
		if c then leadRowFits(a, c, { 340, 284, 260, 240 }) end
	end
	T.clean(w)
end)

test("drive.queue: H4 whisper invites ON, driver in Orgrimmar: 'summon to org' is a request and is invited", function()
	local w, a, DR = inOrg({ accepts = true })
	for _, line in ipairs({ "summon to org", "summon to org pls", "any summon to orgrimmar?" }) do
		eq((DR.AskedFor(line)), "match", line)
		eq(DR.Classify(line), "request", line)
	end
	w:botWhisper(BAU, a, "summon to org")
	w:advance(4)
	local c = DR.customers[key(BAU)]
	ok(c and c.state ~= "lead", "a request, not a lead: " .. tostring(c and c.state))
	eq(c and c.askFor, "Orgrimmar", "it asks for Orgrimmar")
	eq(invitesTo(w, BAU), 1, "invited")
	T.clean(w)
end)

test("drive.queue: H4 whisper invites OFF: a request is queued and waits for the driver; other zones stay leads; nobody is invited", function()
	local w, a, DR = inOrg({ noInvite = true })
	eq(DR.opts().autoInvite, false, "whisper invites are off")
	w:addBot("Zed One", { spot = "Durotar", acceptsInvites = true })
	w:advance(1)
	w:botWhisper("Zed One", a, "any summoon to loch moodan?")
	w:botWhisper(BAU, a, "summon to org")
	w:advance(4)
	local z, b = DR.customers[key("Zed One")], DR.customers[key(BAU)]
	eq(z and z.state, "lead", "another zone: still a lead")
	eq(b and b.state, "queued", "our zone: queued, waiting for the driver's own invite")
	eq(invitesTo(w, "Zed One"), 0, "no invite to the lead")
	eq(invitesTo(w, BAU), 0, "no automatic invite with the setting off")
	if z then leadRowFits(a, z, { 340, 260 }) end
	T.clean(w)
end)

test("drive.queue: H2 the warning's OnHide, a hidden phone and a narrow phone put the popup's scale and font back", function()
	local w, a, DR = inOrg()
	local env = a.env
	a:slash("/wuber")
	w:advance(2)
	local phone = env.WuberFrame
	ok(phone and phone:IsShown(), "the phone is open")
	local function mk()
		local pop = env.CreateFrame("Frame", nil, env.UIParent)
		pop:SetSize(320, 120)
		pop:SetScale(1)
		pop.text = pop:CreateFontString(nil, "ARTWORK")
		pop.text:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
		return pop
	end
	local function same(pop, what)
		local _, size = pop.text:GetFont()
		eq(size, 14, what .. ": font back")
		eq(pop:GetScale(), 1, what .. ": scale back")
	end
	local oldScale, oldW = phone:GetScale(), phone:GetWidth()
	for i, scale in ipairs({ 0.71, 1, 1.5 }) do
		env.UIParent:SetScale(scale)
		phone:SetScale(oldScale * (1 + 0.25 * (i - 1)))
		local pe, ue = phone:GetEffectiveScale(), env.UIParent:GetEffectiveScale()
		DR.SetAutoPublic(true)
		local dlg = env.StaticPopupDialogs[DR.PUBLIC_POPUP]
		local pop = mk()
		eq(DR.PlacePublicWarning(pop), true, scale .. ": placed")
		ok(math.abs(pop:GetScale() - pe / ue) < 1e-6, scale .. ": scaled to the phone")
		dlg.OnHide(pop)
		same(pop, scale .. " OnHide")
		pop = mk()
		DR.PlacePublicWarning(pop)
		phone:Hide()
		eq(DR.PlacePublicWarning(pop), false, scale .. ": no phone: left alone")
		same(pop, scale .. " phone hidden")
		phone:Show()
		pop = mk()
		DR.PlacePublicWarning(pop)
		phone:SetWidth(200)
		eq(DR.PlacePublicWarning(pop), false, scale .. ": narrow phone: left alone")
		same(pop, scale .. " narrow phone")
		phone:SetWidth(oldW)
	end
	phone:SetScale(oldScale)
	env.UIParent:SetScale(1)
	T.clean(w)
end)

test("drive.queue: H4 review: an exact match for another place beats a typo for the driver's own", function()
	-- the harness has no Duskwood spot: a driver whose destination reads Duskwood (alias "darkshire")
	local w, a, DR = setup({ spot = "Orgrimmar" })
	DR.Dest = function() return "Duskwood" end
	local function asked(line)
		local out = {}
		for _, p in ipairs(DR.AskedPlaces(line)) do out[#out + 1] = p.name end
		return out[1] or "", #out
	end
	eq(asked("summon to darkshore"), "Darkshore", "an exact Darkshore beats our 'darkshire' one letter off")
	eq(asked("summon to darkshire"), "Duskwood", "our own alias")
	eq(asked("summon to duskwood"), "Duskwood", "our own name")
	eq(asked("summon to darkshirr"), "Duskwood", "a typo nearer ours")
	local mine, others = DR.Mentions({ "summon", "to", "darkshore" })
	eq(#mine, 0, "not ours")
	eq(#others, 1, "one other place")
	eq(select(2, asked("summon to darkshore")), 1, "and only that one")
	T.clean(w)
end)
