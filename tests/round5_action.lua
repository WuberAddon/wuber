-- Wuber 2.1 (round five, SPEC4.md) tests: B (ACTION)'s part. Loaded by run.lua with the same
-- helpers as round four (T.H, T.test, T.eq, T.ok, T.newWorld, ...). Test names start "r5 action:".
--
-- Part 1: the button, the messages, the trade and the log on their own (A's 2.1 calls set by
-- the test where the scenario needs a given answer).
-- Part 2: SPEC4 5.2 scenarios 1, 2, 4 and 6 end to end, from the action side.

local T = ...
local H, test, eq, ok, count, list = T.H, T.test, T.eq, T.ok, T.count, T.list
local clean = T.clean

local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local SPOT = "Undercity"

test("r5 action: the file loads", function()
	ok(H ~= nil, "the harness")
	eq(type(T.newWorld), "function")
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
local function plan(c) return c.W.Drive.Plan() end

local function press(c)
	local b = c.env.WuberDriveButton
	ok(b, c.player.name .. ": no WuberDriveButton")
	ok(H.visible(b), c.player.name .. ": the big button is hidden")
	return c:click(b)
end

-- party/raid lines posted (w.groupPosts), optionally from one player and of one kind
local function posts(w, from, kind)
	local out = {}
	for _, p in ipairs(w.groupPosts or {}) do
		if (not from or p.from == from) and (not kind or p.kind == kind) then out[#out + 1] = p end
	end
	return out
end

-- whispers a player got: { text }
local function whispered(w, to)
	local out = {}
	for _, x in ipairs(w.whispers or {}) do
		if key(x.to or "") == key(to) then out[#out + 1] = x end
	end
	return out
end

-- this character's crew as saved (as the wizard leaves it); roles[name] = "lock"|"helper",
-- apps[name] = false for "Add anyway" members
local function saved(me, names, extra, roles, apps)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = (roles and roles[n]) or "lock", app = not (apps and apps[n] == false) } end
	end
	local ch = { crew = crew, captain = "", wizard = true }
	for k, v in pairs(extra or {}) do ch[k] = v end
	return { chars = { [key(me)] = ch } }
end

-- the member side of a crew (captain = runner)
local function member(me, captain, names, roles)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = (roles and roles[n]) or "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = captain, wizard = true } } }
end

---------------------------------------------------------------------------
-- Part 1: messages
---------------------------------------------------------------------------

test("r5 action: the new messages pass the spam check and fit a macro, with long names", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local DR = DRof(ana)
	DR.SetDest("The Temple of Atal'Hakkar entrance, Swamp")
	for _, kind in ipairs({ "where", "callsum", "raidsum", "raidclick" }) do
		ok(DR.TEMPLATES[kind], kind .. " has a default")
		eq(DR.TemplateSpam(DR.TEMPLATES[kind]), nil, kind .. " passes the spam filter")
		local found = false
		for _, k in ipairs(DR.TEMPLATE_ORDER) do found = found or k == kind end
		ok(found, kind .. " is in the Messages list")
	end
	for kind, t in pairs(DR.PAYTO_TEMPLATES) do
		eq(DR.TemplateSpam(t), nil, kind .. " (payee) passes the spam filter")
		ok(t:find("{payto}", 1, true), kind .. " names {payto}")
	end
	local long = "Maximilianus Wolfeschlegel"
	local c = { name = long, key = key(long), price = 1234567, paid = 1000, caster = "bartholomew longername", summoner = "bartholomew longername" }
	for _, kind in ipairs(DR.TEMPLATE_ORDER) do
		local text = DR.Text(kind, c)
		local max = kind == "advert" and DR.ADVERT_MAX or DR.TEXT_MAX
		ok(#text <= max, kind .. " is " .. #text .. " bytes")
		ok(#("/w " .. ana.W.Tell(long) .. " " .. text) <= 255, kind .. " whisper line fits")
		ok(#("/ra " .. text) <= 255, kind .. " raid line fits")
		ok(not text:find("{", 1, true), kind .. " has no placeholder left: " .. text)
	end
	for kind, t in pairs(DR.PAYTO_TEMPLATES) do
		local text = DR.Text(kind, c, t)
		ok(#text <= DR.TEXT_MAX, kind .. " (payee) is " .. #text .. " bytes")
	end
	eq(DR.Text("callsum", { name = "Dan Miller", summoner = "bea jones" }), "Bea: please summon Dan")
	eq(DR.Text("raidclick", { name = "Dan Miller" }), "Summoning Dan - click the portal please")
	eq(DR.Text("raidsum", { name = "Dan Miller", caster = "bea jones" }), "Summon coming from Bea - accept it when it pops")
	-- a message the driver writes may use the new placeholders
	ok(DR.SetTemplate("pay", "Pay {payto} {price} please, {name}!"), "saved")
	eq(DR.Text("pay", { name = "Dan Miller", price = 5000, caster = "bea jones" }), "Pay Bea 50s please, Dan!")
	ok(DR.SetTemplate("pay", nil), "reset")
	clean(w)
end)

test("r5 action: {payto} - riders are told to trade the summoner who casts them; thanks names who got the gold", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local DR = DRof(ana)
	-- Ana casts: 2.0's words ("any of us") stay
	local mine = { name = "Dan Miller", key = "dan miller", price = 5000, caster = "ana smith" }
	ok(DR.Text("greet", mine):find("just open trade with any of us when you land", 1, true), DR.Text("greet", mine))
	ok(DR.Text("thanks", mine):find("^Thank you, Dan! Enjoy"), DR.Text("thanks", mine))
	-- Bea casts: trade Bea
	local beas = { name = "Dan Miller", key = "dan miller", price = 5000, paid = 5000, caster = "bea jones", cashier = "bea jones" }
	ok(DR.Text("greet", beas):find("please open a trade with Bea when you land", 1, true), DR.Text("greet", beas))
	eq(DR.Text("pay", beas), "Thanks for riding Ana Smith! Please open a trade with Bea and type 50s.")
	ok(DR.Text("offer", beas):find("paid to Bea by trade", 1, true), DR.Text("offer", beas))
	ok(DR.Text("thanks", beas):find("Thank you, Dan! Bea got your 50s", 1, true), DR.Text("thanks", beas))
	-- a rider who traded Cal instead of Bea: the thanks names Cal (who has the gold)
	beas.cashier = "cal brown"
	ok(DR.Text("thanks", beas):find("Cal got your 50s", 1, true), DR.Text("thanks", beas))
	-- the runner marked it paid for Bea (no Wuber there): the thanks names Bea
	beas.cashier = "ana smith"
	DR.SummonerHasApp = function(k) return k ~= "bea jones" end
	ok(DR.Text("thanks", beas):find("Bea got your 50s", 1, true), DR.Text("thanks", beas))
	eq(DR.PayeeBlind(beas), true, "nobody can watch Bea's trades")
	eq(DR.KeyHasApp("ana smith"), true)
	clean(w)
end)

test("r5 action: where to? - asked once, by the window the rider whispered", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local DR = DRof(ana)
	DR.Stations = function()
		return { { place = "Undercity", open = true, summoners = { "ana smith" } }, { place = "Orgrimmar", open = true, summoners = { "bea jones" } },
			{ place = "Thunder Bluff", open = false, summoners = { "cal brown" } } }
	end
	eq(DR.PlacesText(), "Undercity and Orgrimmar")
	eq(DR.Text("where", { name = "Dan Miller" }), "Ana Smith: we summon to Undercity and Orgrimmar. Where would you like to go? Whisper me the place.")
	local c = { name = "Dan Miller", key = "dan miller", state = "lead", heardBy = "ana smith", askWhere = true, at = 0 }
	local c2 = { name = "Eve Long", key = "eve long", state = "lead", heardBy = "bea jones", noStation = true, at = 0 }
	DR.Sorted = function() return { c, c2 } end
	local p = DR.Pending()
	eq(#p, 1, "Ana answers her own whisperer only")
	eq(p[1].kind, "where")
	DR.MarkSent(c, "where")
	eq(c.whereTold, true)
	eq(#DR.Pending(), 0, "once")
	clean(w)
end)

---------------------------------------------------------------------------
-- Part 1: the button (A's answers set by the test)
---------------------------------------------------------------------------

-- A raid of `names` (clients for `clients`, bots for the rest), grouped; returns w and clients by name.
local function raid(names, clients, opts)
	opts = opts or {}
	local w = T.newWorld()
	local cs = {}
	for _, n in ipairs(names) do
		local spec = clients[n]
		if spec then
			cs[n] = w:addClient(n, { spot = spec.spot or SPOT, class = spec.class or "WARLOCK", saved = spec.saved, shards = spec.shards })
		else
			local class = (opts.botClass and opts.botClass[n]) or "MAGE"
			w:addBot(n, { spot = (opts.botSpot and opts.botSpot[n]) or "Orgrimmar", class = class, shards = class == "WARLOCK" and 10 or nil })
		end
	end
	w:group(names)
	w:advance(1)
	return w, cs
end

-- A's raid answers on one window: mode raid, running, this queue and these summoners.
local function raidMode(c, rows, summoners, extra)
	local DR = DRof(c)
	extra = extra or {}
	DR.Mode = function() return "raid" end
	DR.IsOpen = function() return extra.open ~= false end
	DR.IsPaused = function() return extra.paused == true end
	DR.RaidQueue = function() return rows end
	DR.Summoners = function() return summoners end
	DR.SummonerHasApp = function(k) return not (extra.noApp and extra.noApp[k]) end
	if extra.runner ~= nil then DR.IsRunner = function() return extra.runner end end
	DR.Changed()
	c.W.Drive.Button.Refresh()
end

local function row(name, st, by) return { name = name, key = key(name), asked = 0, state = st or "queued", claimedBy = by, tries = 0 } end

test("r5 action: raid mode - the Warlock summons the next raider by name, with the raid's click line and the raider's whisper", function()
	local names = { ANA, BEA, "Dan Miller", "Eve Long", "Fay Moon", "Gus Hill" }
	local w, cs = raid(names, { [ANA] = {}, [BEA] = {} })
	-- (REVIEW-2.2 #8: with two summoners a freshly planned raider waits a moment on the button)
	local function plan(c)
		c.W.Drive.Plan()
		w:advance(0.7)
		return c.W.Drive.Plan()
	end
	local ana, bea = cs[ANA], cs[BEA]
	local rows = { row("Dan Miller"), row("Eve Long") }
	raidMode(ana, rows, { "ana smith", "bea jones" })
	raidMode(bea, rows, { "ana smith", "bea jones" })
	local p = plan(ana)
	eq(p.type, "macro")
	eq(p.title, "Summon Dan")
	ok(p.macrotext:find("/target Dan Miller\n/cast Ritual of Summoning", 1, true), "targets by name: " .. p.macrotext)
	ok(not p.macrotext:find("[@", 1, true), "never a unit token in a raid")
	ok(p.macrotext:find("/ra Summoning Dan - click the portal please", 1, true), "the click line: " .. p.macrotext)
	ok(p.macrotext:find("/w Dan-Miller Summon coming from Ana - accept it when it pops", 1, true), "the whisper: " .. p.macrotext)
	ok(#p.macrotext <= 255, "fits")
	local q = plan(bea)
	eq(q.title, "Summon Eve", "the second summoner takes the second raider")
	-- one raider, two summoners: only the first plans them
	rows[2] = nil
	eq(plan(ana).title, "Summon Dan")
	eq(plan(bea).summon, nil, "Bea never plans the raider Ana takes")
	-- Ana's claim (CAST) on Dan: Bea is free, Ana busy - Bea takes the next one
	rows[1].claimedBy, rows[1].state = "ana smith", "summoning"
	rows[2] = row("Fay Moon")
	eq(plan(bea).title, "Summon Fay", "Bea takes the next free raider")
	eq(plan(ana).summon, nil, "Ana holds a claim: nothing new for her")
	-- toggles off: target and cast only
	DRof(ana).opts().raidsum, DRof(ana).opts().raidclick = false, false
	rows[1].claimedBy, rows[1].state = nil, "queued"
	eq(plan(ana).macrotext, "/target Dan Miller\n/cast Ritual of Summoning")
	-- a raid never trades, kicks or whispers anything else
	eq(#DRof(ana).Pending(), 0)
	clean(w)
end)

test("r5 action: raid mode - a long raider's whisper waits for the next click; the cast and click line come first", function()
	local long = "Maximilianus Wolfeschlegelsteinhausen"
	local names = { ANA, long, "Eve Long", "Fay Moon", "Gus Hill", "Hal Ray" }
	local w, cs = raid(names, { [ANA] = {} })
	local ana = cs[ANA]
	local DR = DRof(ana)
	ok(DR.SetTemplate("raidsum", "Summon coming from {caster} - accept it when it pops! It is free, from your raid, and the portal is up at the entrance now: please accept quickly."), "a long whisper")
	ok(DR.SetTemplate("raidclick", "Summoning {name} - everyone at the entrance please right-click the portal so the summon goes through, thanks!"), "a long line")
	local rows = { row(long) }
	raidMode(ana, rows, {})
	local p = plan(ana)
	ok(#p.macrotext <= 255, "fits: " .. #p.macrotext)
	ok(p.macrotext:find("/cast Ritual of Summoning", 1, true), "casts")
	ok(p.macrotext:find("/ra Summoning Maximilianus", 1, true), "the click line kept")
	ok(not p.macrotext:find("/w ", 1, true), "the whisper did not fit")
	-- the cast went: the whisper is the next click
	rows[1].claimedBy, rows[1].state = "ana smith", "summoning"
	DR.cast = { name = long, at = w.time }
	local q = plan(ana)
	ok(q.macrotext and q.macrotext:find("^/w Maximilianus%-Wolfeschlegelsteinhausen Summon coming from Ana"), "whisper next: " .. tostring(q.macrotext))
	press(ana)
	w:advance(0.5)
	eq(plan(ana).type, nil, "told once")
	DR.cast = nil
	clean(w)
end)

test("r5 action: raid mode - the runner (any class) calls a summoner without Wuber in raid chat; that call is the claim", function()
	local DRUID = "Dru Oak"
	local names = { DRUID, BEA, "Dan Miller", "Eve Long", "Fay Moon", "Gus Hill" }
	local w, cs = raid(names, { [DRUID] = { class = "DRUID", saved = { Wuber = saved(DRUID, { DRUID, BEA }, { runner = true, summoners = { BEA } },
		nil, { [BEA] = false }) } } }, { botClass = { [BEA] = "WARLOCK" }, botSpot = { [BEA] = SPOT } })
	local dru = cs[DRUID]
	local DR = DRof(dru)
	local rows = { row("Dan Miller"), row("Eve Long") }
	raidMode(dru, rows, { "bea jones" }, { noApp = { ["bea jones"] = true }, runner = true })
	local sent = {}
	DR.Do = function(kind, a, b, c3) sent[#sent + 1] = table.concat({ kind, tostring(a), tostring(b), tostring(c3) }, "~") end
	local p = plan(dru)
	eq(p.title, "Ask Bea to summon Dan")
	eq(p.macrotext, "/ra Bea: please summon Dan")
	press(dru)
	w:advance(0.2)
	eq(#posts(w, DRUID, "RAID"), 1, "one raid line")
	eq(posts(w, DRUID, "RAID")[1].text, "Bea: please summon Dan")
	eq(sent[1], "CAST~Dan Miller~bea jones~nil", "the call is Bea's claim on Dan")
	rows[1].claimedBy, rows[1].state = "bea jones", "summoning"
	-- Bea casts on Dan: the runner's window sees her raid unit channel (CH), and the end (END 1)
	w:move("Dan Miller", "Orgrimmar")
	w:botCast(BEA, "Dan Miller")
	w:advance(1)
	ok(DR.watching["bea jones"], "Bea's ritual is watched")
	eq(sent[#sent], "CH~Dan Miller~bea jones~nil", "channel start: " .. list(sent, ", "))
	eq(plan(dru).title, "CLICK THE PORTAL", "the runner stands at the spot: click")
	w:advance(3)
	w:clickPortal(dru)
	w:clickPortal("Gus Hill")
	w:advance(1.5)
	eq(sent[#sent], "END~Dan Miller~1~bea jones", "summon sent: " .. list(sent, ", "))
	-- no whisper, no trade, no invite in a raid
	eq(#whispered(w, "Dan Miller"), 0)
	eq(w.tradeOpens or 0, 0)
	clean(w)
end)

test("r5 action: two stations - each Warlock's button plans only the riders of its own station", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK" })
	local bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK" })
	w:addBot("Dan Miller", { spot = "Thunder Bluff" })
	w:addBot("Eve Long", { spot = "Thunder Bluff" })
	w:group({ ANA, BEA, "Dan Miller", "Eve Long" })
	w:advance(1)
	for _, c in ipairs({ ana, bea }) do
		local DR = DRof(c)
		DR.IsOpen = function() return true end
		DR.Stations = function() return { { place = "Undercity", open = true }, { place = "Orgrimmar", open = true } } end
		DR.MyStation = function() return c == ana and "Undercity" or "Orgrimmar" end
		DR.StationOf = function(name) return key(name) == "dan miller" and "Orgrimmar" or "Undercity" end
		DR.MayCast = function() return true, c.W.myKey end
		DR.customers["dan miller"] = { name = "Dan Miller", key = "dan miller", state = "joined", at = 0, price = 5000, greeted = true }
		DR.customers["eve long"] = { name = "Eve Long", key = "eve long", state = "joined", at = 1, price = 5000, greeted = true }
		DR.Sorted = function() return { DR.customers["dan miller"], DR.customers["eve long"] } end
	end
	eq(plan(ana).title, "Summon Eve", "Undercity's Warlock: Eve")
	eq(plan(bea).title, "Summon Dan", "Orgrimmar's Warlock: Dan")
	-- Bea's ritual for Dan does not stop Ana, nor call her to Orgrimmar's portal
	DRof(ana).customers["dan miller"].state, DRof(ana).customers["dan miller"].caster = "summoning", "bea jones"
	eq(plan(ana).title, "Summon Eve", "another station's portal is not Ana's")
	DRof(ana).customers["eve long"].state = "arrived"
	DRof(ana).customers["eve long"].tries = 1
	ok(plan(ana).title ~= "CLICK THE PORTAL", "no portal call from another station: " .. plan(ana).title)
	clean(w)
end)

---------------------------------------------------------------------------
-- Part 1: the log
---------------------------------------------------------------------------

test("r5 action: the log - a crew ride carries the payee; a runner's mark-paid for a summoner is the summoner's; raid count", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "MAGE" })
	local DR = DRof(ana)
	local W = ana.W
	DR.customers["dan miller"] = { name = "Dan Miller", key = "dan miller", state = "arrived", price = 5000, caster = "bea jones", at = 0 }
	DR.SummonerHasApp = function(k) return k ~= "bea jones" end
	W.Fire("DRIVE_PAID", "Dan Miller", 5000, 0, "cal brown", false, "t", 5000)
	local l = DR.Log()
	ok(l.team[#l.team]:find(",Dan Miller,.*,cal brown,bea jones$"), "team line with the payee: " .. tostring(l.team[#l.team]))
	local rides = #l.rides
	W.Fire("DRIVE_PAID", "Dan Miller", 5000, 0, "ana smith", true, "m", 5000)
	eq(#l.rides, rides, "not the runner's own ride")
	ok(l.team[#l.team]:find(",bea jones,bea jones$"), "Bea's ride on the runner's crew view: " .. tostring(l.team[#l.team]))
	eq(DR.LogTotals(0, "crew").rides, 2, "Earnings' Crew view counts both")
	eq(DR.RaidCount(), 0)
	W.Fire("DRIVE_RAID_DONE", "Eve Long", "bea jones")
	W.Fire("DRIVE_RAID_DONE", "Eve Long", "bea jones")
	W.Fire("DRIVE_RAID_DONE", "Fay Moon", "ana smith")
	eq(DR.RaidCount(), 2, "two raiders tonight (a raider counted once)")
	clean(w)
end)

---------------------------------------------------------------------------
-- Part 2: SPEC4 5.2 scenarios (action side)
---------------------------------------------------------------------------

local MIA, PAT = "Mia Frost", "Pat Priest"

-- The rider types the fare into the open trade and accepts.
local function pays(w, name, copper)
	local p = w:player(name)
	ok(p.trade, name .. " has no trade open")
	w:typeTradeMoney(p, math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100)
	w:tradeAccept(p)
	w:advance(0.3)
end

local function lastWhisper(w, to)
	local l = whispered(w, to)
	return l[#l] and l[#l].text or ""
end

test("r5 action: scenario 1 - Mage runner, Warlock summoner with Wuber, Priest helper: trade the Warlock, thanks name her, the Mage's Crew earnings", function()
	local w = T.newWorld()
	local names = { MIA, BEA, PAT }
	local roles = { [BEA] = "lock", [PAT] = "helper" }
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE", saved = { Wuber = saved(MIA, names, { runner = true, summoners = { BEA } }, roles) } })
	local bea = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = member(BEA, MIA, names, roles) } })
	local pat = w:addClient(PAT, { spot = SPOT, class = "PRIEST", saved = { Wuber = member(PAT, MIA, names, roles) } })
	w:group(names)
	w:advance(2)
	eq(DRof(mia).Role(), "driver", "a Mage runs the service")
	local okOpen, why = DRof(mia).SetOpen(true)
	ok(okOpen, "the Mage opens: " .. tostring(why))
	w:advance(3)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:botWhisper("Dan Miller", mia, "summon pls")
	w:advance(4)
	eq(state(mia, "Dan Miller"), "joined")
	eq(state(bea, "Dan Miller"), "joined")
	-- the Mage's button never casts; the Warlock's does, and tells the rider whom to trade
	local pm = plan(mia)
	ok(not (pm.macrotext or ""):find("/cast", 1, true), "no cast step for a Mage")
	eq(pm.title, "Bea summons Dan")
	local pb = plan(bea)
	eq(pb.title, "Summon Dan")
	ok(pb.macrotext:find("please open a trade with me when you land", 1, true), "trade the Warlock: " .. pb.macrotext)
	press(bea)
	w:advance(1.5)
	eq(state(mia, "Dan Miller"), "summoning")
	eq(customer(mia, "Dan Miller").caster, "bea jones")
	eq(plan(pat).title, "CLICK THE PORTAL")
	eq(plan(mia).title, "CLICK THE PORTAL")
	w:clickPortal(mia)
	w:clickPortal(pat)
	w:advance(10)
	eq(state(bea, "Dan Miller"), "arrived")
	eq(w.tradeOpens, 1, "the Warlock (the payee) opens the trade")
	ok(w:player("Dan Miller").trade, "with Dan")
	pays(w, "Dan Miller", 5000)
	eq(plan(bea).title, "Accept 50s from Dan", "the Warlock's trade is read")
	press(bea)
	w:advance(2)
	eq(state(bea, "Dan Miller"), "paid")
	eq(state(mia, "Dan Miller"), "paid", "every window knows")
	local thanker = (plan(bea).title == "Thank Dan") and bea or mia
	eq(plan(thanker).title, "Thank Dan")
	press(thanker)
	w:advance(1)
	ok(lastWhisper(w, "Dan Miller"):find("Bea got your 50s", 1, true), "the thanks names the Warlock: " .. lastWhisper(w, "Dan Miller"))
	-- the Mage's earnings: the ride in the Crew view, Bea's gold in Bea's log
	eq(DRof(mia).LogTotals(0, "crew").rides, 1, "Mage's Crew view")
	eq(DRof(mia).LogTotals(0).rides, 0, "not the Mage's own gold")
	eq(DRof(bea).LogTotals(0).copper, 5000, "Bea's own log has the gold")
	clean(w)
end)

test("r5 action: scenario 2 - Mage runner, Warlock friend without Wuber: the call line, the cast seen from her party unit, Mark as paid, no auto-block", function()
	local w = T.newWorld()
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE",
		saved = { Wuber = saved(MIA, { MIA, BEA }, { runner = true, summoners = { BEA } }, { [BEA] = "lock" }, { [BEA] = false }) } })
	w:addBot(BEA, { spot = SPOT, class = "WARLOCK", shards = 10 })
	w:addBot(PAT, { spot = SPOT, class = "PRIEST" })
	w:group({ MIA, BEA, PAT })
	w:advance(2)
	local DR = DRof(mia)
	DR.SetOpt("autoBlock", true)
	local okOpen, why = DR.SetOpen(true)
	ok(okOpen, "the Mage opens: " .. tostring(why))
	w:advance(2)
	w:addBot("Dan Miller", { spot = "Orgrimmar" })
	w:botWhisper("Dan Miller", mia, "summon pls")
	w:advance(4)
	eq(state(mia, "Dan Miller"), "joined")
	local p = plan(mia)
	eq(p.title, "Ask Bea to summon Dan")
	ok(p.macrotext:find("/p Bea: please summon Dan", 1, true), "the call line: " .. p.macrotext)
	ok(p.macrotext:find("/w Dan-Miller ", 1, true) and p.macrotext:find("please open a trade with Bea", 1, true), "the greeting names Bea: " .. p.macrotext)
	ok(not p.macrotext:find("/cast", 1, true), "never a cast")
	press(mia)
	w:advance(1)
	eq(#posts(w, MIA, "PARTY"), 1, "said once in party chat")
	eq(posts(w, MIA, "PARTY")[1].text, "Bea: please summon Dan")
	eq(plan(mia).title, "Bea summons Dan", "asked: waiting for her")
	eq(plan(mia).type, nil)
	-- Bea casts: seen from her party unit (spell 698)
	w:botCast(BEA, "Dan Miller")
	w:advance(1)
	eq(state(mia, "Dan Miller"), "summoning")
	eq(customer(mia, "Dan Miller").caster, "bea jones", "Bea is the caster (and the payee)")
	eq(plan(mia).title, "CLICK THE PORTAL")
	w:advance(2)
	w:clickPortal(mia)
	w:clickPortal(PAT)
	w:advance(10)
	eq(state(mia, "Dan Miller"), "arrived")
	eq(w.tradeOpens or 0, 0, "nobody opens a trade for Bea")
	eq(DR.PayeeBlind(customer(mia, "Dan Miller")), true)
	w:advance(30)
	local r = plan(mia)
	eq(r.title, "Remind Dan")
	ok(r.macrotext:find("Please open a trade with Bea and type 50s", 1, true), "the reminder names Bea: " .. r.macrotext)
	press(mia)
	w:advance(1)
	-- Bea says Dan paid: the runner marks it
	mia:slash("/wuber drive paid dan")
	w:advance(1)
	eq(state(mia, "Dan Miller"), "paid")
	press(mia)
	w:advance(1)
	ok(lastWhisper(w, "Dan Miller"):find("Bea got your 50s", 1, true), "thanks name Bea: " .. lastWhisper(w, "Dan Miller"))
	local l = DR.Log()
	ok((l.team[#l.team] or ""):find("^%d+,5000,Dan Miller,.*,bea jones,bea jones$"), "Bea's ride in the Mage's Crew log: " .. tostring(l.team[#l.team]))
	-- a rider who leaves without a word is not auto-blocked: nobody could watch them pay Bea
	w:addBot("Eve Long", { spot = "Orgrimmar" })
	w:botWhisper("Eve Long", mia, "summon pls")
	w:advance(4)
	press(mia)
	w:advance(1)
	w:botCast(BEA, "Eve Long")
	w:advance(3)
	w:clickPortal(mia)
	w:clickPortal(PAT)
	w:advance(10)
	eq(state(mia, "Eve Long"), "arrived")
	w:leave("Eve Long")
	w:advance(20)
	eq(DR.BlockEntry("eve long"), nil, "not blocked")
	clean(w)
end)

-- crew entries for a runner: Bea a Wuber summoner, the rest plain helpers (no Wuber)
local function stationCrew(me, lockNames, helperNames, extra)
	local crew = {}
	for _, n in ipairs(lockNames) do if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end end
	for _, n in ipairs(helperNames) do crew[#crew + 1] = { name = n, role = "helper", app = false } end
	local ch = { crew = crew, captain = "", wizard = true }
	for k, v in pairs(extra or {}) do ch[k] = v end
	return { chars = { [key(me)] = ch } }
end

test("r5 action: scenario 4 - a raid with two stations: riders routed, each Warlock's button plans its own, Where to?, a place we don't serve", function()
	local w = T.newWorld()
	local UC1, UC2, OG1, OG2 = "Uma One", "Ubi Two", "Oda One", "Obi Two"
	local helpers = { UC1, UC2, OG1, OG2 }
	local ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK",
		saved = { Wuber = stationCrew(ANA, { BEA }, helpers, { summoners = { ANA, BEA }, runner = true }) } })
	local bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = member(BEA, ANA, { ANA }) } })
	w:addBot(UC1, { spot = "Undercity" })
	w:addBot(UC2, { spot = "Undercity" })
	w:addBot(OG1, { spot = "Orgrimmar" })
	w:addBot(OG2, { spot = "Orgrimmar" })
	w:group({ ANA, BEA, UC1, UC2, OG1, OG2 })
	w:advance(20)
	local DA, DB = DRof(ana), DRof(bea)
	local okOpen, why = DA.SetOpen(true)
	ok(okOpen, "open: " .. tostring(why))
	w:advance(20)
	eq(#DA.Stations(), 2, "two stations")
	eq(DA.MultiStation(), true)
	local function rider(name, text)
		w:addBot(name, { spot = "Thunder Bluff" })
		w:botWhisper(name, ana, text)
	end
	rider("Dan Miller", "summon to org pls")
	rider("Eve Long", "summon to uc pls")
	rider("Fay Moon", "summon pls")
	rider("Gus Hill", "summon to ratchet pls")
	w:advance(8)
	eq(state(ana, "Dan Miller"), "joined")
	eq(state(ana, "Eve Long"), "joined")
	eq(state(ana, "Fay Moon"), "joined", "no place named: queued at the runner's station")
	ok(state(ana, "Gus Hill") ~= "joined" and state(ana, "Gus Hill") ~= "invited", "Ratchet: not queued")
	local invitedGus = false
	for _, i in ipairs(w.invites) do invitedGus = invitedGus or key(i.to) == "gus hill" end
	eq(invitedGus, false, "nobody invites Gus")
	-- Ana's click answers Fay (Where to?) and Gus (where we summon to), and summons her own station's rider
	local pa = plan(ana)
	ok(pa.macrotext:find("/w Fay-Moon Ana Smith: we summon to ", 1, true), "Fay is asked: " .. pa.macrotext)
	ok(pa.macrotext:find("/w Gus-Hill Ana Smith: we summon to ", 1, true), "Gus is told: " .. pa.macrotext)
	press(ana)
	w:advance(1)
	pa = plan(ana)
	eq(pa.title, "Summon Eve", "Undercity's Warlock summons Undercity's rider")
	local pb = plan(bea)
	eq(pb.title, "Summon Dan", "Orgrimmar's Warlock summons Orgrimmar's rider")
	ok(pb.macrotext:find("summoning you to Orgrimmar now", 1, true), "the greeting names Bea's station: " .. pb.macrotext)
	-- both cast at once
	press(bea)
	press(ana)
	w:advance(3)
	eq(state(ana, "Dan Miller"), "summoning")
	eq(state(ana, "Eve Long"), "summoning")
	w:clickPortal(OG1)
	w:clickPortal(OG2)
	w:clickPortal(UC1)
	w:clickPortal(UC2)
	w:advance(10)
	eq(w:player("Dan Miller").zone, "Orgrimmar")
	eq(state(bea, "Dan Miller"), "arrived", "arrived = on the map of the station that summoned him")
	eq(state(ana, "Eve Long"), "arrived")
	eq(#whispered(w, "Fay Moon") >= 1 and 1 or 0, 1)
	eq(#whispered(w, "Gus Hill"), 1, "told once")
	clean(w)
end)

test("r5 action: scenario 6 - raid summons: a Druid with assist runs it, two Warlocks (one without Wuber); claims never clash; no trade, no invites, no beacon", function()
	local w = T.newWorld()
	local DRU = "Dru Oak"
	local names = { "Rex Lead", DRU, ANA, BEA }
	local dru = w:addClient(DRU, { spot = SPOT, class = "DRUID",
		saved = { Wuber = saved(DRU, { DRU, ANA, BEA }, { runner = true, summoners = { ANA, BEA } }, nil, { [BEA] = false }) } })
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = member(ANA, DRU, { DRU }) } })
	w:addBot("Rex Lead", { spot = SPOT, class = "WARRIOR" })
	w:addBot(BEA, { spot = SPOT, class = "WARLOCK", shards = 10 })
	w:addBot("Cid Click", { spot = SPOT })
	names[#names + 1] = "Cid Click"
	for i = 1, 15 do
		local n = "R" .. string.char(96 + i) .. " Raider"
		w:addBot(n, { spot = "Orgrimmar" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	w:advance(5)
	local D = DRof(dru)
	local okM, whyM = D.SetMode("raid")
	ok(okM ~= false, "raid mode: " .. tostring(whyM))
	local okS, whyS = D.SetOpen(true)
	ok(okS ~= false, "start: " .. tostring(whyS))
	w:advance(5)
	eq(DRof(ana).Mode(), "raid", "the summoner follows")
	w:groupSay("Ra Raider", "123")
	w:groupSay("Rb Raider", "summ pls")
	w:groupSay("Rc Raider", "can someone please summon me to the raid, I am stuck in Orgrimmar at the bank sorry")
	w:advance(3)
	eq(#D.RaidQueue(), 2, "two raiders asked (the long line is ignored)")
	-- Ana takes the first raider, the runner calls Bea (no Wuber) for the second
	local pa, pd = plan(ana), plan(dru)
	eq(pa.title, "Summon Ra")
	ok(pa.macrotext:find("/target Ra Raider\n/cast Ritual of Summoning", 1, true), pa.macrotext)
	eq(pd.title, "Ask Bea to summon Rb")
	press(dru)
	press(ana)
	w:advance(2)
	local q = D.RaidQueue()
	local by = {}
	for _, r in ipairs(q) do by[key(r.name)] = r.claimedBy end
	eq(by["ra raider"], "ana smith")
	eq(by["rb raider"], "bea jones", "the call is Bea's claim")
	ok(by["ra raider"] ~= by["rb raider"], "two summoners never claim the same raider")
	ok(posts(w, DRU, "RAID")[1] and posts(w, DRU, "RAID")[1].text == "Bea: please summon Rb", "the call line")
	ok(posts(w, ANA, "RAID")[1] and posts(w, ANA, "RAID")[1].text == "Summoning Ra - click the portal please", "the click line")
	eq(#whispered(w, "Ra Raider"), 1, "raidsum")
	ok(whispered(w, "Ra Raider")[1].text:find("^Summon coming from Ana"), "raidsum text")
	-- Ana's portal first, then Bea's (the harness gives a click to any ritual in reach)
	ok(w:clickPortal(dru), "Dru clicks Ana's portal")
	ok(w:clickPortal("Cid Click"), "Cid clicks Ana's portal")
	w:advance(12)
	eq(w:player("Ra Raider").zone, SPOT, "Ra is here")
	w:botCast(BEA, "Rb Raider")
	w:advance(3)
	ok(w:clickPortal(dru), "Dru clicks Bea's portal")
	ok(w:clickPortal("Rex Lead"), "Rex clicks Bea's portal")
	w:advance(12)
	eq(w:player("Rb Raider").zone, SPOT, "Rb is here")
	eq(#D.RaidQueue(), 0, "both arrived: off the queue")
	-- "nvm" drops a raider
	w:groupSay("Rd Raider", "123")
	w:advance(2)
	w:groupSay("Rd Raider", "nvm")
	w:advance(2)
	for _, r in ipairs(D.RaidQueue()) do ok(key(r.name) ~= "rd raider", "Rd dropped") end
	-- no trade, no invites, no beacon, whispers only raidsum
	eq(w.tradeOpens or 0, 0, "no trade")
	eq(#w.invites, 0, "no invites")
	for _, x in ipairs(w.whispers) do
		if x.from == ANA or x.from == DRU then ok(x.text:find("^Summon coming from"), "only raidsum: " .. x.text) end
	end
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBER" and (e.from == DRU or e.from == ANA) then ok(not e.text:match("^D~"), "no beacon: " .. e.text) end
	end
	ok(D.RaidCount() >= 1, "Summoned tonight counts")
	-- the runner loses assist: paused
	w:setAssist(DRU, false)
	w:advance(3)
	ok(plan(dru).title:find("Paused") or plan(dru).title:find("stopped"), "paused: " .. plan(dru).title)
	clean(w)
end)

---------------------------------------------------------------------------
-- Commands, README, file budgets
---------------------------------------------------------------------------

test("r5 action: /wuber drive raid, sell, summoners, stations, raidsum/raidclick switches", function()
	local w = T.newWorld()
	local mia = w:addClient(MIA, { spot = SPOT, class = "MAGE", saved = { Wuber = saved(MIA, { MIA, BEA }, { runner = true }, { [BEA] = "lock" }, { [BEA] = false }) } })
	w:addBot(BEA, { spot = SPOT, class = "WARLOCK", shards = 10 })
	w:group({ MIA, BEA })
	w:advance(2)
	local DR = DRof(mia)
	mia:slash("/wuber drive summoners Bea Jones")
	eq(DR.Summoners()[1], "bea jones", "Bea summons")
	local text = table.concat(mia.chatLines or {}, "\n")
	ok(text:find("Summoners, in order: Bea (no Wuber", 1, true), "said, with the no-Wuber note: " .. text)
	mia:slash("/wuber drive raidclick off")
	eq(DR.opts().raidclick, false)
	mia:slash("/wuber drive raidclick on")
	eq(DR.opts().raidclick, true)
	mia:slash("/wuber drive stations")
	mia:slash("/wuber drive help")
	ok(table.concat(mia.chatLines or {}, "\n"):find("summoners Bea Jones, Cal Brown", 1, true), "help lists the 2.1 commands")
	mia:slash("/wuber drive sell")
	eq(DR.Mode(), "sell")
	mia:slash("/wuber drive summoners clear")
	eq(#DR.Summoners(), 0)
	clean(w)
end)

test("r5 action: B's files keep their top level under 170 locals", function()
	for _, f in ipairs({ "Drive_Button", "Drive_Chat", "Drive_Trade", "Drive_Log", "Drive_Bell", "Drive_Commands", "Commands" }) do
		local paths = H.F.paths(f) -- the old file, or the modules its code moved to (tests/lib/files.lua)
		ok(#paths > 0, f .. "'s files in the TOC")
		for _, path in ipairs(paths) do
			local src = T.readFile(path)
			local lo, hi = 0, 200
			while lo < hi do
				local mid = math.floor((lo + hi + 1) / 2)
				local extra = {}
				for i = 1, mid do extra[i] = "local __x" .. i end
				if loadstring(src .. "\n" .. table.concat(extra, " ")) then lo = mid else hi = mid - 1 end
			end
			ok(200 - lo <= 170, path:sub(#H.ADDONS.Wuber + 2) .. " top level holds " .. (200 - lo) .. " locals")
		end
	end
end)
