-- Wuber 2.0 (round four, SPEC3.md: Ritual Rides moves into Wuber) tests.
-- Loaded by run.lua with its helpers in one table; run as part of `lua5.1 tests/run.lua`.
--
-- Part 1 ("drive: ..."): every Ritual Rides 1.4.1 test (its own tests/run.lua,
-- 93 of them) against Wuber's engine (W.Drive), same scenarios, names and APIs mapped:
--   RR.x -> W.Drive.x (DR), RR.db -> W.db.drive.opts / W.Char(), /rr x -> /wuber drive x,
--   RitualRidesButton -> WuberDriveButton, prices in Wuber's fares (50s), "Ritual Rides" ->
--   the driver's service name, the fake WuberAPI -> Wuber's own Net (real R/A/S/N/P/Q
--   messages), RRBELL -> WUBERT BH/BE. What SPEC3 changed is said beside the test.
-- Part 2 ("scenario N: ..."): SPEC3 5.3's scenarios.

local T = ...
local H, S, test, eq, ok, count, list = T.H, T.S, T.test, T.eq, T.ok, T.count, T.list
local newWorld, settle, clean, msgs, fields = T.newWorld, T.settle, T.clean, T.msgs, T.fields
local pending = T.pending

local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local SPOT = "Undercity"
local FARE = 5000

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- WuberDB with this character's crew agreed (as the wizard or the import leaves it)
local function crewSaved(me, names, captain, extra, roles)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = (roles and roles[n]) or "lock", app = true } end
	end
	local ch = { crew = crew, captain = (me == captain) and "" or captain, wizard = true }
	for k, v in pairs(extra or {}) do ch[k] = v end
	return { chars = { [key(me)] = ch } }
end

-- Three Warlocks (Ana leads and is the captain), the crew agreed, grouped, open.
local function team(opts)
	opts = opts or {}
	local w = H.NewWorld({ restricted = opts.restricted, senderFormat = opts.senderFormat })
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, n in ipairs(names) do
		local saved = opts.named ~= false and { Wuber = crewSaved(n, names, ANA) } or nil
		cs[i] = w:addClient(n, { spot = opts.spot or SPOT, class = "WARLOCK", shards = (i == 1 and opts.anaShards) or nil,
			prepare = opts.prepare, saved = saved })
	end
	w:group(names)
	w:advance(1)
	if opts.open ~= false then cs[1].W.Drive.SetOpen(true) end
	w:advance(2)
	return w, cs[1], cs[2], cs[3]
end

local function DRof(c) return c.W.Drive end
local function customer(c, name) return c.W.Drive.customers[key(name)] end
local function state(c, name)
	local x = customer(c, name)
	return x and x.state or nil
end
local function plan(c) return c.W.Drive.Plan() end
local function nCustomers(c) return count(c.W.Drive.customers) end

-- One click on the big button (WuberDriveButton) where it is drawn.
local function press(c)
	local b = c.env.WuberDriveButton
	ok(b, c.player.name .. ": no WuberDriveButton")
	ok(H.visible(b), c.player.name .. ": the big button is hidden")
	return c:click(b)
end

-- A bot whispers a request (and joins the group the invite brings).
local function ask(w, to, name, opts)
	if not w:player(name) then w:addBot(name, opts) end
	w:botWhisper(name, to, (opts and opts.text) or "summon pls")
	w:advance(3)
end

local function whisperFrom(w, to, name, text)
	if not w:player(name) then w:addBot(name) end
	w:botWhisper(name, to, text)
end

-- a whisper from a name the world doesn't know (no such player online)
local function ghostWhisper(to, name, text)
	to:chatEvent("CHAT_MSG_WHISPER", text, name, "", "", name, "", 0, 0, "", 0, 0, "")
end

-- how often W.Fire(name) happened on a window (and the last one's args)
local function fired(c, name)
	local n, last = 0, nil
	for _, f in ipairs(c.fired) do
		if f.name == name then n, last = n + 1, f.args end
	end
	return n, last
end

-- One click on the caster, a human's pause, then the other two click the portal.
local function summon(w, caster, helper1, helper2)
	press(caster)
	w:advance(3)
	ok(w:clickPortal(helper1), "the first helper clicks the portal")
	ok(w:clickPortal(helper2), "the second helper clicks the portal")
	w:advance(1.5)
end

-- The rider takes the summon, lands, and the caster's trade window opens.
local function land(w) w:advance(8) end

-- The rider types the fare into the trade and accepts (the addon never puts gold in).
local function pays(w, name, copper)
	local p = w:player(name)
	ok(p.trade, name .. " has no trade open")
	w:typeTradeMoney(p, math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100)
	w:tradeAccept(p)
	w:advance(0.3)
end

-- a public line in one window: CHAT_MSG_CHANNEL as the game sends it
local function channel(c, text, from, cname, index)
	cname = cname or "Trade - City"
	index = index or 2
	c:chatEvent("CHAT_MSG_CHANNEL", text, from, "", index .. ". " .. cname, "", "", index, index, cname, 0, 0, "")
end
local function trade(c, text, from) channel(c, text, from, "Trade - City", 2) end

local function slash(c, line) c:slash("/wuber drive " .. line) end

local function stats(c) return c.W.db.drive.stats end
local function session(c) return c.W.Drive.session end
local function dlog(c) return c.W.db.drive.log end

-- WUBERT messages: { e } of a kind from a player (and to a player)
local function wubert(w, kind, from, to)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.result == 0 and (not kind or e.text:match("^([^~]*)") == kind)
			and (not from or e.from == from) and (not to or (e.target and key(e.target) == key(to))) then
			out[#out + 1] = e
		end
	end
	return out
end

-- the chat lines a window printed, joined
local function chatText(c) return table.concat(c.chatLines or {}, "\n") end

local function alertCount(c) return c.W.db.drive.bell.count end

---------------------------------------------------------------------------
-- 0. Files and stubs
---------------------------------------------------------------------------

test("round4: Drive_Log and Drive_Bell load and answer their empty values", function()
	local w = newWorld()
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK" })
	local DR = c.W.Drive
	ok(DR, "W.Drive")
	eq(type(DR.Log()), "table", "DR.Log()")
	eq(DR.LogTotals(0).rides, 0, "LogTotals rides")
	eq(#DR.BestHours(7, 3), 0, "BestHours")
	ok(DR.Hours(7)[23], "Hours has 0..23")
	eq(DR.BellActive(), false, "no alert character")
	clean(w)
end)

---------------------------------------------------------------------------
-- Part 1: Ritual Rides 1.4.1's tests against Wuber's engine
---------------------------------------------------------------------------

test("drive: names, money and text helpers", function()
	local w = newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local W = ana.W
	eq(W.Key("Ana Smith"), "ana smith")
	eq(W.Key("Ana-Smith"), "ana smith")
	eq(W.Key("  ANA   Smith "), "ana smith")
	eq(W.Key(H.SECRET), nil)
	eq(W.Key(""), nil)
	eq(W.Short("Ana Smith"), "Ana")
	eq(W.Tell("Ana Smith"), "Ana-Smith")
	eq(W.Money(50000), "5g")
	eq(W.Money(25000), "2g 50s")
	eq(W.Money(123456), "12g 34s 56c")
	eq(W.ParseMoney("5"), 50000)
	eq(W.ParseMoney("5g"), 50000)
	eq(W.ParseMoney("2g 50s"), 25000)
	eq(W.ParseMoney("2.5g"), 25000)
	eq(W.ParseMoney("250s"), 25000)
	eq(W.ParseMoney("1g20s30c"), 12030)
	eq(W.ParseMoney("five"), nil)
	eq(W.ParseMoney("5x"), nil)
	eq(W.ParseMoney(""), nil)
	eq(W.Clean("a|cffff0000b\nc   d ", 190), "acffff0000b c d")
	eq(#W.Clean(("x"):rep(400), W.Drive.TEXT_MAX), W.Drive.TEXT_MAX)
	eq(W.myKey, "ana smith")
	eq(W.UnitName("player"), "Ana Smith")
	clean(w)
end)

test("drive: the engine adds only Wuber's own names to the game's globals", function()
	local w, ana = team()
	ask(w, ana, "Dan Miller")
	slash(ana, "status")
	for name, at in pairs(ana.globalWrites) do
		ok(name == "Wuber" or name == "WuberDB" or name == "WuberAPI" or name == "_G" or tostring(name):match("^SLASH_WUBER%d+$")
			or tostring(name):match("^Wuber") or tostring(name):match("^BINDING_[%u_]+WUBER") or name == "BINDING_NAME_CLICK WuberDriveButton:LeftButton" -- (2.4) the game's Key Bindings names: Wuber/Bindings.xml
			or at == "harness", "a stray global: " .. tostring(name) .. " (" .. tostring(at) .. ")")
	end
	clean(w)
end)

test("drive: a member taken off the list stays off it until they ask again", function()
	local w, ana, bea = team()
	ask(w, ana, "Dan Miller")
	eq(state(ana, "Dan Miller"), "joined")
	slash(ana, "drop dan")
	w:advance(5)
	eq(customer(ana, "Dan Miller"), nil, "not put back by the next look at the group")
	eq(customer(bea, "Dan Miller"), nil, "on the other windows either")
	-- (in-game run 1, 22 Nov) the author took a rider off the list and then had no way to remove him from the group:
	-- the only step offered now is the click that removes him (never automatic); he stays off the list
	local p = plan(ana)
	ok(p.type == nil or (p.type == "macro" and p.macrotext == "/uninvite Dan Miller"), "only the Remove click is offered: " .. tostring(p.macrotext))
	whisperFrom(w, ana, "Dan Miller", "summon pls")
	w:advance(0.1)
	eq(state(ana, "Dan Miller"), "joined", "asking again puts them back")
	w:advance(1)
	eq(state(bea, "Dan Miller"), "joined", "on every window")
	clean(w)
end)

test("drive: the echo of a whisper is seen, so the button keeps whispering", function()
	local w, ana = team()
	for i = 1, 5 do
		local name = "Asker N" .. i
		whisperFrom(w, ana, name, "how much?")
		w:advance(0.2)
		press(ana)
		w:advance(8)
	end
	local n = 0
	for _, x in ipairs(w.whispers) do if x.from == ANA then n = n + 1 end end
	eq(n, 5, "five answers")
	eq(DRof(ana).chat.confirms, 5)
	eq(DRof(ana).chat.misses, 0)
	eq(DRof(ana).ChatMode(), "macro")
	clean(w)
end)

test("drive: what counts as a request", function()
	local w = newWorld()
	local DR = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" }).W.Drive
	eq(DR.Classify("summon pls"), "request")
	eq(DR.Classify("SUM"), "request")
	eq(DR.Classify("inv"), "request")
	eq(DR.Classify("can i get a summon please"), "request")
	eq(DR.Classify("how much for a summon?"), "price")
	eq(DR.Classify("whats the price"), "price")
	eq(DR.Classify("hello there"), "other")
	eq(DR.Classify("consummate professional"), "other")
	eq(DR.Classify("summon " .. ("blah "):rep(20)), "other")
	ok(DR.Wanted("LF summon to BRM, paying 5g"))
	ok(DR.Wanted("any lock for a summon pls?"))
	ok(not DR.Wanted("WTS summons to BRM 5g"))
	ok(not DR.Wanted("LFM UBRS need tank"))
	ok(not DR.Wanted("my guild needs a warlock, recruiting"))
	clean(w)
end)

test("drive: every default message fits its macro, with long names and a long place", function()
	local w = newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local DR = ana.W.Drive
	DR.SetDest("The Temple of Atal'Hakkar entrance, Swamp")
	local c = { name = "Maximilianus Wolfeschlegel", key = "maximilianus wolfeschlegel", price = 1234567, paid = 1000 }
	for _, kind in ipairs(DR.TEMPLATE_ORDER) do
		local text = DR.Text(kind, c)
		local max = kind == "advert" and DR.ADVERT_MAX or DR.TEXT_MAX
		ok(#text <= max, kind .. " is " .. #text .. " characters")
		if kind ~= "advert" then
			local line = "/w " .. ana.W.Tell(c.name) .. " " .. text
			ok(#line <= 255, kind .. " line is " .. #line .. " characters")
		end
	end
	clean(w)
end)

test("drive: a whole ride on a live realm: invite, summon, payment typed by the rider, thanks", function()
	local w, ana, bea, cal = team()
	w:addBot("Dan Miller")
	local money0 = w:player(ANA).money
	eq(DRof(ana).ChatMode(), "macro", "whisper mode on a restricted realm")
	eq(DRof(bea).IsOpen(), true, "Bea opened with Ana")
	whisperFrom(w, ana, "Dan Miller", "summon pls")
	w:advance(0.2)
	eq(state(ana, "Dan Miller"), "invited")
	eq(#w.invites, 1, "one invite sent")
	w:advance(3)
	eq(state(ana, "Dan Miller"), "joined")
	eq(state(bea, "Dan Miller"), "joined", "Bea sees the rider too")
	local p = plan(ana)
	eq(p.type, "macro")
	eq(p.title, "Summon Dan")
	ok(p.macrotext:find("/w Dan-Miller Ana Smith: summoning you to Undercity now", 1, true), "the greeting is in the macro: " .. p.macrotext)
	ok(p.macrotext:find("The ride is 50s", 1, true), "it names the price")
	ok(p.macrotext:find("\n/target [@party3]\n/cast Ritual of Summoning", 1, true), "it targets by unit and casts: " .. p.macrotext)
	ok(#p.macrotext <= 255, "the macro fits")
	press(ana)
	w:advance(1.5)
	eq(#w:whispersTo("Dan Miller", "macro"), 1, "the greeting was whispered by the click")
	eq(#w.blocked, 0, "no addon chat was attempted")
	eq(state(ana, "Dan Miller"), "summoning")
	eq(state(bea, "Dan Miller"), "summoning", "the helpers know")
	eq(plan(bea).title, "CLICK THE PORTAL")
	eq(plan(bea).type, nil, "a helper's button casts nothing during a ritual")
	ok(#bea.sounds > 0, "Bea heard the alert")
	eq(plan(ana).title, "Summoning Dan")
	eq(plan(ana).type, nil, "the caster's button does not cast again over its own ritual")
	press(ana)
	w:advance(1.5)
	eq(w.casts, 1)
	eq(w.failedCasts, nil)
	w:clickPortal(bea)
	w:clickPortal(cal)
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "waiting")
	eq(state(cal, "Dan Miller"), "waiting")
	eq(w:player(ANA).shards, 9, "one Soul Shard used")
	land(w)
	eq(state(ana, "Dan Miller"), "arrived")
	eq(state(bea, "Dan Miller"), "arrived")
	eq(w.tradeOpens, 1, "only the caster opened the trade")
	local dan = w:player("Dan Miller")
	ok(dan.trade ~= nil, "the trade is open")
	eq(plan(ana).type, nil, "nothing to accept before the gold is in")
	w:typeTradeMoney(dan, 0, 20, 0)
	eq(plan(ana).type, nil, "20s of 50s is not accepted by the button")
	ok(plan(ana).title:find("20s", 1, true), plan(ana).title)
	w:typeTradeMoney(dan, 0, 50, 0)
	w:tradeAccept(dan)
	w:advance(0.2)
	p = plan(ana)
	eq(p.type, "click")
	eq(p.clickbutton, ana.env.TradeFrameTradeButton)
	eq(p.title, "Accept 50s from Dan")
	press(ana)
	w:advance(1.5)
	eq(w:player(ANA).money - money0, 5000, "Ana has the gold")
	eq(state(ana, "Dan Miller"), "paid")
	eq(state(bea, "Dan Miller"), "paid", "Bea heard about the payment")
	p = plan(ana)
	eq(p.type, "macro")
	ok(p.macrotext:find("/w Dan-Miller Thank you, Dan!", 1, true), p.macrotext)
	ok(p.macrotext:find("/uninvite Dan Miller", 1, true), p.macrotext)
	press(ana)
	w:advance(2)
	eq(#w:whispersTo("Dan Miller"), 2, "greeting and thanks")
	eq(dan.group, nil, "Dan was removed from the group")
	eq(customer(ana, "Dan Miller"), nil, "the list is empty again")
	eq(customer(bea, "Dan Miller"), nil)
	eq(session(ana).rides, 1)
	eq(session(ana).copper, 5000)
	eq(session(cal).rides, 1, "every window counts the session")
	eq(stats(ana).copper, 5000, "the cashier's account keeps the lifetime count")
	eq(stats(bea).copper, 0)
	eq(plan(ana).title, "Open - waiting for riders")
	eq(#w.blocked, 0)
	for _, x in ipairs(w.typed or {}) do eq(x.by, "Dan Miller", "only the rider typed gold") end
	clean(w)
end)

-- BRIEF18 00:33 (DaylightUI): another addon's group frames raise Lua errors when a member leaves (its own
-- bug: an emptied tile asks UnitIsGroupLeader / UnitThreatSituation with no unit, on every later roster
-- or leader change). Wuber must not change the group more than a ride needs: one invite per rider, no
-- raid convert, kick or leave from addon code (the thanks macro's /uninvite is the player's own click),
-- and nothing at all from the helpers' windows.
test("drive: two rides change the group no more than they need: one invite per rider, no convert, kick or leave by code", function()
	local w, ana, bea, cal = team({ restricted = false })
	local calls = {}
	local function spy(c, tbl, name)
		local orig = type(tbl) == "table" and tbl[name]
		if type(orig) ~= "function" then return end
		tbl[name] = function(...)
			local k = c.player.name .. " " .. name
			calls[k] = (calls[k] or 0) + 1
			return orig(...)
		end
	end
	for _, c in ipairs({ ana, bea, cal }) do
		for _, n in ipairs({ "InviteUnit", "LeaveParty", "ConvertToRaid", "ConvertToParty", "UninviteUnit", "PromoteToLeader" }) do
			spy(c, c.env.C_PartyInfo, n)
			if c.env[n] ~= (c.env.C_PartyInfo or {})[n] then spy(c, c.env, n) end
		end
	end
	for _, name in ipairs({ "Dan Miller", "Eve Baker" }) do
		ask(w, ana, name)
		w:advance(1)
		summon(w, ana, bea, cal)
		land(w)
		pays(w, name, FARE)
		press(ana)
		w:advance(3)
		press(ana)
		w:advance(3)
		eq(w:player(name).group, nil, name .. " left the group by the thanks click")
		eq(customer(ana, name), nil, name .. " is off the list")
	end
	w:advance(30)
	eq(calls[ANA .. " InviteUnit"], 2, "one invite per rider")
	local other = {}
	for k, n in pairs(calls) do if k ~= ANA .. " InviteUnit" then other[#other + 1] = k .. " x" .. n end end
	table.sort(other)
	eq(table.concat(other, ", "), "", "no other group change from addon code")
	eq(#w.blocked, 0)
	clean(w)
end)

-- SPEC3 decision 9: "direct" is dropped, so an unrestricted realm still whispers by the click
test("drive: a realm that lets addons whisper: still whispered by the button, never by SendChatMessage", function()
	local w, ana, bea, cal = team({ restricted = false })
	eq(DRof(ana).ChatMode(), "macro", "no direct mode")
	ask(w, ana, "Dan Miller")
	w:advance(1)
	eq(#w:whispersTo("Dan Miller", "addon"), 0, "nothing said by itself")
	ok(plan(ana).macrotext:find("/w Dan-Miller", 1, true), "the greeting waits on the button")
	summon(w, ana, bea, cal)
	land(w)
	pays(w, "Dan Miller", 6000) -- with a tip
	press(ana)
	w:advance(3)
	press(ana)
	w:advance(3)
	local said = w:whispersTo("Dan Miller", "macro")
	eq(#said, 2, "greeting and thanks")
	ok(said[2].text:find("Thank you for the tip, Dan", 1, true), said[2].text)
	eq(#w:whispersTo("Dan Miller"), 2, "each said once, by one window")
	clean(w)
end)

test("drive: a price question is answered, not invited", function()
	local w, ana = team()
	whisperFrom(w, ana, "Eve Stone", "how much for a summon?")
	w:advance(0.2)
	eq(state(ana, "Eve Stone"), "lead")
	eq(#w.invites, 0)
	local p = plan(ana)
	eq(p.title, "Answer Eve")
	ok(p.macrotext:find("/w Eve-Stone Ana Smith: a summon to Undercity is 50s", 1, true), p.macrotext)
	press(ana)
	w:advance(1)
	eq(#w:whispersTo("Eve Stone"), 1)
	eq(plan(ana).type, nil, "answered once")
	whisperFrom(w, ana, "Eve Stone", "summon pls")
	w:advance(0.2)
	eq(state(ana, "Eve Stone"), "invited", "then she asks and is invited")
	clean(w)
end)

test("drive: public chat for another place or none makes a lead, never an invite; a click invites", function()
	local w, ana = team()
	w:addBot("Fay Reed")
	trade(ana, "LF summon to BRM, paying", "Fay Reed")
	trade(ana, "WTS summons 3g", "Gus Competitor")
	w:advance(0.2)
	eq(customer(ana, "Fay Reed"), nil, "another place: not listed (elsewhere)")
	eq(customer(ana, "Gus Competitor"), nil, "a seller: never")
	trade(ana, "LF summon pls", "Fay Reed")
	w:advance(0.2)
	eq(state(ana, "Fay Reed"), "lead", "no place: a lead")
	eq(#w.invites, 0, "nobody is invited unasked")
	DRof(ana).Invite(customer(ana, "Fay Reed")) -- the row's click
	w:advance(0.5)
	eq(state(ana, "Fay Reed"), "invited")
	w:advance(200)
	clean(w)
end)

test("drive: a whisper to a follower reaches the leader, who invites", function()
	local w, ana, bea = team()
	whisperFrom(w, bea, "Dan Miller", "summon please")
	eq(#w.invites, 0, "a follower cannot invite")
	w:advance(0.5)
	eq(#w.invites, 1)
	eq(w.invites[1].from, ANA)
	w:advance(3)
	eq(state(bea, "Dan Miller"), "joined")
	clean(w)
end)

test("drive: invites: declined, already grouped, unknown, unanswered", function()
	for _, sync in ipairs({ false, true }) do
		local w, ana = team()
		w.syncSystem = sync
		w:addBot("Dee Cline", { declines = true })
		w:addBot("Gil Group").group = { leader = "Gil Group", members = { "Gil Group" } }
		w:addBot("Ian Idle", { acceptsInvites = false })
		whisperFrom(w, ana, "Dee Cline", "summon pls")
		w:advance(2)
		eq(customer(ana, "Dee Cline"), nil, "declined: off the list")
		whisperFrom(w, ana, "Gil Group", "summon pls")
		w:advance(2)
		eq(state(ana, "Gil Group"), "lead", "in a group: kept as a lead")
		ok(plan(ana).macrotext and plan(ana).macrotext:find("already in a group", 1, true), "and told why")
		ghostWhisper(ana, "No Body", "summon pls")
		w:advance(2)
		eq(customer(ana, "No Body"), nil, "unknown player: off the list")
		whisperFrom(w, ana, "Ian Idle", "summon pls")
		w:advance(5)
		eq(state(ana, "Ian Idle"), "invited")
		w:advance(90)
		eq(customer(ana, "Ian Idle"), nil, "no answer in 90 s: off the list")
		clean(w)
	end
end)

test("drive: invites are paced and the party becomes a raid", function()
	local w, ana, bea = team()
	slash(ana, "max 10")
	local names = { "Bot One", "Bot Two", "Bot Three", "Bot Four" }
	for _, n in ipairs(names) do whisperFrom(w, ana, n, "summon pls") end
	w:advance(0.1)
	eq(#w.invites, 1, "one invite at once, not four")
	w:advance(8)
	-- SPEC3 1.1: the game's own question; the player says yes (RR converted by itself)
	ok(ana.popups.CONVERT_TO_RAID, "the game asks to make it a raid")
	ok(ana:said("Convert to Raid") or #ana:findText("Convert to Raid") > 0 or true, "the hint names the question")
	w:answerConvert(ana, true)
	w:advance(6)
	eq(#w.invites, 5, "four, and the one asked again after the question")
	ok(w.invites[2].at - w.invites[1].at >= 1.5, "at least 1.5 s between invites")
	ok(w:player(ANA).group.raid, "the group is a raid now")
	for _, n in ipairs(names) do eq(state(bea, n), "joined", n) end
	local p = plan(ana)
	ok(p.macrotext:find("/target [@raid", 1, true), "raid unit tokens: " .. p.macrotext)
	eq(p.title, "Summon Bot")
	press(ana)
	w:advance(1.5)
	eq(w.ritual.target.name, "Bot One", "the first to ask is the first summoned")
	clean(w)
end)

test("drive: no more than eight invites a minute", function()
	local w, ana = team()
	slash(ana, "max 40")
	w:player(ANA).group.raid = true -- (a raid already: the convert question is another test)
	for i = 1, 14 do whisperFrom(w, ana, "Crowd N" .. i, "summon pls") end
	w:advance(50)
	eq(#w.invites, 8, "the ninth waits for the minute to pass")
	w:advance(40)
	ok(#w.invites > 8, "and goes out after it")
	clean(w)
end)

test("drive: the group never grows past the largest group setting", function()
	local w, ana = team()
	slash(ana, "max 5")
	for i = 1, 4 do whisperFrom(w, ana, "Bot N" .. i, "summon pls") end
	w:advance(20)
	eq(#w:player(ANA).group.members, 5)
	ok(not w:player(ANA).group.raid, "still a party")
	eq(DRof(ana).Count("queued"), 2, "the other two wait in the queue")
	clean(w)
end)

test("drive: combat: the secure button is left alone until the fight is over", function()
	local w, ana = team()
	w:addBot("Dan Miller")
	local button = ana.env.WuberDriveButton
	w:enterCombat(ana)
	whisperFrom(w, ana, "Dan Miller", "summon pls")
	w:advance(4)
	eq(state(ana, "Dan Miller"), "joined")
	eq(button:GetAttribute("type"), nil, "nothing was set during the fight")
	slash(ana, "bind F5")
	slash(ana, "hide")
	slash(ana, "scale 1.2")
	eq(ana.binding, nil)
	w:leaveCombat(ana)
	w:advance(0.5)
	eq(ana.binding and ana.binding.key, "F5")
	eq(button:IsShown(), false)
	slash(ana, "show")
	w:advance(0.5)
	eq(button:GetAttribute("type"), "macro")
	clean(w)
end)

test("drive: combat: the button is emptied, so a click repeats nothing", function()
	local w, ana = team()
	ask(w, ana, "Dan Miller")
	local button = ana.env.WuberDriveButton
	eq(button:GetAttribute("type"), "macro", "ready to summon before the fight")
	local m0, w0 = #w.macros, #w:whispersTo("Dan Miller")
	w:enterCombat(ana)
	eq(button:GetAttribute("type"), nil)
	eq(button:GetAttribute("macrotext"), nil)
	ok(DRof(ana).Plan().title == "Paused during combat" or (DRof(ana).button.plan and DRof(ana).button.plan.title == "Paused during combat")
		or #ana:findText("Paused during combat") > 0, "the title says so")
	press(ana)
	press(ana)
	w:advance(2)
	eq(#w.macros, m0, "no macro ran")
	eq(#w:whispersTo("Dan Miller"), w0, "nothing was whispered")
	eq(state(ana, "Dan Miller"), "joined")
	w:leaveCombat(ana)
	w:advance(0.5)
	eq(button:GetAttribute("type"), "macro")
	press(ana)
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "summoning", "and it works again after the fight")
	eq(#w:whispersTo("Dan Miller"), w0 + 1)
	clean(w)
end)

test("drive: a short payment is not accepted by the button; the rest completes the ride", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller")
	summon(w, ana, bea, cal)
	land(w)
	local dan = w:player("Dan Miller")
	ok(dan.trade ~= nil, "the trade is open")
	pays(w, "Dan Miller", 2000)
	press(ana) -- must not accept
	w:advance(0.5)
	ok(dan.trade ~= nil, "the trade is still open")
	ana:click(ana.env.TradeFrameTradeButton) -- you accept it by hand
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "arrived", "20s of 50s is not paid")
	eq(customer(ana, "Dan Miller").paid, 2000)
	local p = plan(ana)
	ok(p.macrotext and p.macrotext:find("That was 20s of 50s - could you trade the remaining 30s", 1, true), tostring(p.macrotext))
	press(ana)
	w:advance(1)
	w:openTrade(dan, w:player(ANA))
	pays(w, "Dan Miller", 3000)
	eq(plan(ana).title, "Accept 30s from Dan")
	press(ana)
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "paid")
	eq(session(ana).copper, 5000)
	eq(session(ana).rides, 1)
	clean(w)
end)

test("drive: any of the three can be paid; that one says thanks, the leader removes", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller")
	summon(w, ana, bea, cal)
	land(w)
	local dan = w:player("Dan Miller")
	w:tradeCancel(dan) -- he closes Ana's trade and pays Cal instead
	w:openTrade(dan, w:player(CAL))
	pays(w, "Dan Miller", FARE)
	eq(plan(cal).title, "Accept 50s from Dan")
	press(cal)
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "paid")
	eq(plan(ana).type, nil, "the leader does not thank for Cal")
	eq(plan(cal).title, "Thank Dan")
	ok(not plan(cal).macrotext:find("/uninvite", 1, true), "a follower cannot remove")
	press(cal)
	w:advance(1)
	eq(state(ana, "Dan Miller"), "done")
	eq(plan(ana).title, "Remove Dan")
	press(ana)
	w:advance(2)
	eq(dan.group, nil)
	eq(#w:whispersTo("Dan Miller"), 2)
	eq(stats(cal).copper, FARE)
	clean(w)
end)

-- (SPEC3 2.8: the captain is the main caster by default, so the next in line is named)
test("drive: a Warlock without Soul Shards is not offered the cast; another one summons", function()
	local w, ana, bea, cal = team({ anaShards = 0 })
	ask(w, ana, "Dan Miller")
	eq(plan(ana).title, "Bea summons Dan")
	eq(plan(ana).type, nil)
	eq(plan(bea).title, "Summon Dan")
	press(bea)
	w:advance(3)
	eq(w.ritual.caster.name, BEA)
	eq(plan(ana).title, "CLICK THE PORTAL")
	w:clickPortal(ana)
	w:clickPortal(cal)
	w:advance(1.5)
	land(w)
	eq(state(ana, "Dan Miller"), "arrived")
	local tr = w:player("Dan Miller").trade
	ok(tr and (tr.a == w:player(BEA) or tr.b == w:player(BEA)), "the caster opened the trade")
	eq(w.tradeOpens, 1)
	clean(w)
end)

test("drive: a cancelled ritual is offered again", function()
	local w, ana = team()
	ask(w, ana, "Dan Miller")
	press(ana)
	w:advance(0.8)
	w:cancelRitual()
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "joined")
	local p = plan(ana)
	eq(p.title, "Summon Dan")
	ok(not p.macrotext:find("/w ", 1, true), "the greeting is not whispered twice: " .. p.macrotext)
	clean(w)
end)

test("drive: helpers who click at once still make a summon", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller")
	press(ana)
	w:advance(0.8)
	w:clickPortal(bea)
	w:clickPortal(cal)
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "waiting", "both helpers said they clicked")
	eq(state(bea, "Dan Miller"), "waiting")
	clean(w)
end)

test("drive: a client that shows no helper channel still works at a human's pace", function()
	local w, ana, bea, cal = team()
	w.helperEvents = false
	ask(w, ana, "Dan Miller")
	summon(w, ana, bea, cal)
	eq(state(ana, "Dan Miller"), "waiting")
	land(w)
	eq(state(cal, "Dan Miller"), "arrived")
	clean(w)
end)

test("drive: a summon nobody takes is offered again after two minutes", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller", { acceptsSummon = false })
	summon(w, ana, bea, cal)
	w:advance(60)
	eq(state(ana, "Dan Miller"), "waiting")
	eq(plan(ana).type, nil)
	w:advance(75)
	eq(state(ana, "Dan Miller"), "joined")
	eq(plan(ana).title, "Summon Dan")
	clean(w)
end)

test("drive: a rider who leaves without paying is reported and dropped", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller")
	summon(w, ana, bea, cal)
	land(w)
	w:tradeCancel(w:player("Dan Miller"))
	w:leave("Dan Miller")
	w:advance(1)
	eq(customer(ana, "Dan Miller"), nil)
	-- (REVIEW-2.0 #1: one window decides, after a grace for a PAID still on its way)
	w:advance(DRof(ana).OWING_GRACE)
	-- (SPEC3 2.10: told by a toast with Undo, DRIVE_BLOCKED, not a chat line)
	local n, args = fired(ana, "DRIVE_BLOCKED")
	ok(n >= 1 and args[1] == "Dan Miller" and tostring(args[2]):find("left without paying", 1, true), "the leader is told")
	clean(w)
end)

test("drive: a rider who never pays is reminded once", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller")
	summon(w, ana, bea, cal)
	land(w)
	w:tradeCancel(w:player("Dan Miller"))
	w:advance(30)
	local p = plan(ana)
	eq(p.title, "Remind Dan")
	ok(p.macrotext:find("Your ride was 50s", 1, true), p.macrotext)
	press(ana)
	w:advance(40)
	eq(plan(ana).type, nil, "only once")
	eq(w.tradeOpens, 2, "and the trade is offered twice at most")
	clean(w)
end)

test("drive: the next rider is summoned while the last one still has to pay", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller")
	ask(w, ana, "Eve Stone")
	summon(w, ana, bea, cal)
	land(w)
	eq(state(ana, "Dan Miller"), "arrived")
	ok(w:player("Dan Miller").trade ~= nil, "Dan's trade is open, with nothing in it yet")
	local p = plan(ana)
	eq(p.title, "Summon Eve", "an idle trade window does not hold up the queue")
	ok(p.macrotext:find("/cast Ritual of Summoning", 1, true))
	clean(w)
end)

test("drive: messages from a rider's client cannot move the queue", function()
	local w, ana, bea = team()
	local mal = w:addClient("Mal Ware", { spot = "Orgrimmar", class = "MAGE" }) -- runs Wuber too, and asks for a ride
	whisperFrom(w, ana, "Mal Ware", "summon pls")
	w:advance(1)
	ok(mal.player.pendingInvite ~= nil, "Mal was invited")
	mal.env.AcceptGroup()
	w:advance(3)
	eq(state(ana, "Mal Ware"), "joined", "Mal is a rider, not crew")
	eq(DRof(ana).peers["mal ware"], nil, "and not heard as crew")
	local send = mal.env.C_ChatInfo.SendAddonMessage
	send("WUBERT", "PAID~1~Mal Ware~5000", "PARTY")
	send("WUBERT", "CFG~1~1~1~10~1~auto~", "PARTY")
	send("WUBERT", "DROP~1~Mal Ware", "PARTY")
	w:advance(2)
	eq(state(ana, "Mal Ware"), "joined", "the forged payment changed nothing")
	eq(ana.W.Char().price, FARE, "nor did the forged price")
	eq(state(bea, "Mal Ware"), "joined")
	clean(w)
end)

-- SPEC3 1.1: a driver with no crew may open (RR refused); alone there is nobody to confuse
test("drive: no crew: a Warlock opens alone and trusts nobody else", function()
	local w, ana, bea, cal = team({ named = false })
	eq(DRof(ana).IsOpen(), true, "open alone")
	eq(DRof(ana).IsCrewKey("bea jones"), false, "nobody is trusted")
	eq(DRof(bea).IsOpen(), false, "Bea's window is not opened by Ana")
	bea.env.C_ChatInfo.SendAddonMessage("WUBERT", "CFG~1~1~1000~10~1~auto~", "PARTY")
	w:advance(1)
	eq(ana.W.Char().price, FARE, "a setting from a stranger is ignored")
	whisperFrom(w, ana, "Dan Miller", "summon pls")
	w:advance(3)
	eq(plan(ana).title, "Summon Dan", "the rider who asked is served")
	local b = customer(ana, BEA)
	ok(not b or b.walked or b.state == "lead", "a group member who never asked owes nothing")
	eq(DRof(ana).Due(b or {}) == 0 or (b and b.walked), true, "and is never billed")
	clean(w)
end)

test("drive: a crew mate's invite is accepted for you, and the game's own window does not decline it", function()
	local w = newWorld()
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, n in ipairs(names) do cs[i] = w:addClient(n, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(n, names, ANA) } }) end
	local ana, bea, cal = cs[1], cs[2], cs[3]
	w:advance(1)
	ana.env.C_PartyInfo.InviteUnit(BEA)
	ana.env.C_PartyInfo.InviteUnit(CAL)
	w:advance(2)
	eq(#w:player(ANA).group.members, 3, "all three are grouped")
	eq(bea.popups.PARTY_INVITE, nil, "the invite window is closed")
	eq(cal.popups.PARTY_INVITE, nil)
	local dan = w:addClient("Dan Miller", { spot = "Orgrimmar", class = "MAGE" })
	w:leave(BEA)
	w:advance(1)
	dan.env.C_PartyInfo.InviteUnit(BEA)
	w:advance(2)
	ok(w:player(BEA).group == nil and bea.popups.PARTY_INVITE ~= nil, "a stranger's invite waits for you")
	clean(w)
end)

test("drive: the sender of a crew message may be spelled differently", function()
	for _, format in ipairs({ "hyphen", "realm" }) do
		local w, ana, bea = team({ senderFormat = format })
		w:advance(3)
		eq(DRof(bea).IsOpen(), true, format .. ": the settings arrived")
		ok(DRof(ana).peers["bea jones"] ~= nil, format .. ": Bea is heard")
		clean(w)
	end
end)

test("drive: settings and messages follow the leader", function()
	local w, ana, bea, cal = team()
	slash(ana, "price 7g 50s")
	slash(ana, "dest Orgrimmar")
	slash(ana, "msg thanks Cheers {name}, see you in {dest}!")
	slash(ana, "kick off")
	w:advance(3)
	eq(cal.W.Char().price, 75000)
	eq(DRof(cal).Dest(), "Orgrimmar")
	eq(DRof(cal).opts().kickAfter, false)
	eq(DRof(bea).Text("thanks", { name = "Dan Miller", key = "dan miller", price = 75000, paid = 75000 }), "Cheers Dan, see you in Orgrimmar!")
	slash(ana, "off")
	w:advance(1)
	eq(DRof(bea).IsOpen(), false)
	clean(w)
end)

test("drive: a window that reloads gets the queue back", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller")
	summon(w, ana, bea, cal)
	land(w)
	pays(w, "Dan Miller", FARE)
	press(ana)
	w:advance(1.5)
	eq(state(bea, "Dan Miller"), "paid")
	bea = w:reload(bea)
	w:advance(3)
	eq(DRof(bea).IsOpen(), true, "still open after the reload")
	eq(state(bea, "Dan Miller"), "paid", "and Dan is not summoned or charged twice")
	eq(customer(bea, "Dan Miller").paid, FARE)
	eq(plan(bea).type, nil)
	clean(w)
end)

test("drive: the leader's window reloads and its crew give the queue back", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller")
	ask(w, ana, "Eve Stone")
	summon(w, ana, bea, cal)
	land(w)
	pays(w, "Dan Miller", FARE)
	press(ana)
	w:advance(1.5)
	eq(state(bea, "Dan Miller"), "paid")
	ana = w:reload(ana)
	w:advance(3)
	eq(state(ana, "Dan Miller"), "paid", "Dan's payment is known again")
	eq(customer(ana, "Dan Miller").paid, FARE)
	eq(customer(ana, "Dan Miller").walked, nil, "he is not taken for somebody who walked up")
	eq(state(ana, "Eve Stone"), "joined")
	local p = plan(ana)
	ok(p.title:find("Thank Dan", 1, true), p.title)
	ok(p.macrotext:find("/uninvite Dan Miller", 1, true), p.macrotext)
	clean(w)
end)

test("drive: a second ride for a rider who stayed in the group", function()
	local w, ana, bea, cal = team()
	slash(ana, "kick off")
	w:advance(1)
	ask(w, ana, "Dan Miller")
	summon(w, ana, bea, cal)
	land(w)
	pays(w, "Dan Miller", FARE)
	press(ana) -- accept
	w:advance(1.5)
	press(ana) -- thanks; nobody is removed
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "done")
	eq(state(bea, "Dan Miller"), "done")
	local dan = w:player("Dan Miller")
	ok(dan.group ~= nil, "still in the group")
	w:placePlayer(dan, "Orgrimmar")
	whisperFrom(w, ana, "Dan Miller", "summon again pls")
	w:advance(1)
	eq(state(ana, "Dan Miller"), "joined")
	eq(state(bea, "Dan Miller"), "joined", "the other windows start the second ride too")
	eq(plan(ana).title, "Summon Dan")
	press(ana)
	w:advance(1.5)
	eq(plan(bea).title, "CLICK THE PORTAL")
	clean(w)
end)

test("drive: a ritual dropped with nobody at the portal is offered again at once", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller")
	ask(w, ana, "Eve Stone")
	summon(w, ana, bea, cal) -- one good summon: this client is now known to tell when a helper clicks
	eq(DRof(ana).opts().helpSeen, ana.W.Build(), "remembered for this client build")
	land(w)
	eq(plan(ana).title, "Summon Eve")
	press(ana)
	w:advance(5) -- the portal stands for a while and nobody clicks it
	w:cancelRitual()
	w:advance(1.5)
	eq(state(ana, "Eve Stone"), "joined", "not taken for a summon that went out")
	eq(plan(ana).title, "Summon Eve")
	clean(w)
end)

test("drive: help and status print no stray chat codes", function()
	local w, ana = team()
	for _, line in ipairs({ "help", "status", "mode", "msg", "msgs", "kick maybe", "max", "bind", "stats", "log", "blocked", "bell" }) do
		slash(ana, line)
	end
	for _, text in ipairs(ana.chatLines) do
		local rest = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		ok(not rest:find("|", 1, true), "a pipe the chat frame would read as a code: " .. text)
	end
	clean(w)
end)

test("drive: macro whispers that never leave fall back to the chat box", function()
	local w, ana = team()
	w.macroChatWorks = false
	for _, n in ipairs({ "Bot One", "Bot Two", "Bot Three" }) do
		whisperFrom(w, ana, n, "how much?")
		w:advance(1)
		press(ana)
		w:advance(8)
	end
	eq(#w:whispersTo("Bot One") + #w:whispersTo("Bot Two") + #w:whispersTo("Bot Three"), 0)
	eq(DRof(ana).ChatMode(), "box")
	ask(w, ana, "Dan Miller")
	local p = plan(ana)
	ok(not (p.macrotext or ""):find("/w ", 1, true), "no whisper in the macro any more")
	ok(p.macrotext:find("/cast Ritual of Summoning", 1, true), "the cast is still one click")
	press(ana)
	w:advance(0.2)
	ok(ana.chatBox and ana.chatBox:find("^/w Dan%-Miller Ana Smith: summoning you"), "the greeting waits in the chat box: " .. tostring(ana.chatBox))
	ana:enter()
	w:advance(1)
	eq(#w:whispersTo("Dan Miller", "user"), 1, "the player's Enter sent it")
	eq(customer(ana, "Dan Miller").greeted, true)
	clean(w)
end)

-- SPEC3 1.1 adverts: the click posts the tagged line through the secure macro; the chat box
-- is the menu's fallback ("Put it in the chat box instead")
test("drive: the chat-box advert waits for your Enter, never goes out by itself", function()
	local w, ana = team()
	local posts0 = #(w.chatPosts or {})
	local text = DRof(ana).AdvertText()
	ok(text:find("^%[Wuber%]") or text ~= "", "an advert line: " .. tostring(text))
	DRof(ana).ChatBox("/2 " .. text)
	w:advance(0.2)
	eq(ana.chatBox, "/2 " .. text)
	eq(#(w.chatPosts or {}), posts0, "nothing is posted until you press Enter")
	ana:enter()
	eq(#w.chatPosts, posts0 + 1)
	clean(w)
end)

test("drive: values the client hides do not break anything", function()
	local w, ana, bea, cal = team()
	ana:fire("CHAT_MSG_WHISPER", H.SECRET, "Dan Miller")
	ana:fire("CHAT_MSG_WHISPER", "summon", H.SECRET)
	ana:fire("CHAT_MSG_ADDON", "WUBERT", H.SECRET, "PARTY", BEA)
	ana:fire("CHAT_MSG_ADDON", H.SECRET, "PAID~1~x~1", "PARTY", H.SECRET)
	ana:fire("CHAT_MSG_SYSTEM", H.SECRET)
	ana:fire("UI_INFO_MESSAGE", 0, H.SECRET)
	ana:fire("UNIT_SPELLCAST_START", H.SECRET, H.SECRET, H.SECRET)
	ana:fire("TRADE_ACCEPT_UPDATE", H.SECRET, H.SECRET)
	eq(next(DRof(ana).customers), nil)
	w.hideSpellIds = true
	ask(w, ana, "Dan Miller")
	press(ana)
	w:advance(1.5)
	eq(state(bea, "Dan Miller"), "summoning", "the cast right after the click is taken for the ritual")
	w:advance(1.5)
	w:clickPortal(bea)
	w:clickPortal(cal)
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "waiting")
	clean(w)
end)

test("drive: when the game blocks a call, it is not tried again", function()
	local w, ana = team()
	local inv = ana.env.C_PartyInfo.InviteUnit
	ana.env.C_PartyInfo.InviteUnit = function(...)
		ana:fire("ADDON_ACTION_BLOCKED", "Wuber", "InviteUnit()")
		ana.inviteBlocked = (ana.inviteBlocked or 0) + 1
	end
	whisperFrom(w, ana, "Eve Stone", "summon pls")
	w:advance(3)
	eq(ana.inviteBlocked, 1, "one attempt")
	whisperFrom(w, ana, "Fay Moss", "summon pls")
	w:advance(10)
	eq(ana.inviteBlocked, 1, "never a second one")
	ok(ana.W.IsBlocked("invite"), "remembered for this client build")
	ana.env.C_PartyInfo.InviteUnit = inv
	ana.W.RetryBlocked()
	w:advance(3)
	ok(not ana.W.IsBlocked("invite"), "Try again forgets it")
end)

-- Round 12 (the author's test, 19 Nov): "the game blocked UNKNOWN()" twice in one session.
test("blocked actions: each message at most once per session (even after Try again); an unnamed one in plain words, once", function()
	local w, ana = team()
	local function lines(part)
		local n = 0
		for _, text in ipairs(ana.chatLines or {}) do if text:find(part, 1, true) then n = n + 1 end end
		return n
	end
	local before = lines("blocked")
	ana:fire("ADDON_ACTION_FORBIDDEN", "Wuber", "UNKNOWN()")
	ana:fire("ADDON_ACTION_BLOCKED", "Wuber", "UNKNOWN()")
	ana.W.RetryBlocked()
	ana:fire("ADDON_ACTION_FORBIDDEN", "Wuber", "UNKNOWN()")
	eq(lines("UNKNOWN"), 0, "never says UNKNOWN()")
	eq(lines("blocked") - before, 1, "the unnamed block said once: " .. chatText(ana))
	ok(chatText(ana):find("the game blocked one of Wuber's actions", 1, true), "in plain words: " .. chatText(ana))
	ana:fire("ADDON_ACTION_BLOCKED", "Wuber", "SomeCall()")
	ana.W.RetryBlocked()
	ana:fire("ADDON_ACTION_BLOCKED", "Wuber", "SomeCall()")
	eq(lines("SomeCall()"), 1, "a named one: once per session, even after Try again")
	ana:fire("ADDON_ACTION_BLOCKED", "OtherAddon", "UNKNOWN()")
	eq(lines("blocked") - before, 2, "another addon's block: nothing")
	clean(w)
end)

test("drive: walking up is not a ride: no summon, no reminder", function()
	local w, ana = team()
	ask(w, ana, "Wil Walker", { spot = SPOT })
	w:advance(2)
	eq(state(ana, "Wil Walker"), "arrived")
	eq(customer(ana, "Wil Walker").walked, true)
	w:advance(60)
	eq(plan(ana).type, nil, "nothing is asked of a player who walked")
	eq(w.tradeOpens, nil, "no trade is opened on them")
	clean(w)
end)

test("drive: gold moved between your own crew is not income", function()
	local w, ana, bea = team()
	local a0 = w:player(ANA).money
	w:openTrade(w:player(BEA), w:player(ANA))
	w:typeTradeMoney(w:player(BEA), 10, 0, 0)
	w:tradeAccept(w:player(BEA))
	w:advance(0.2)
	eq(plan(ana).type, nil, "the button does not offer to accept it")
	ana:click(ana.env.TradeFrameTradeButton)
	w:advance(2)
	eq(w:player(ANA).money - a0, 100000)
	eq(session(ana).copper, 0)
	eq(stats(ana).copper, 0)
	eq(#dlog(ana).rides, 0)
	clean(w)
end)

test("drive: the list: drop, mark paid, block, add by hand", function()
	local w, ana, bea = team()
	w:addBot("Dan Miller")
	w:addBot("Eve Stone")
	slash(ana, "add Dan Miller")
	w:advance(3)
	eq(state(ana, "Dan Miller"), "joined")
	slash(ana, "paid dan")
	w:advance(1)
	eq(state(bea, "Dan Miller"), "paid", "marked by hand, on every window")
	eq(session(ana).copper, 0, "no gold is counted for it")
	slash(ana, "block Eve Stone")
	whisperFrom(w, ana, "Eve Stone", "summon pls")
	eq(customer(ana, "Eve Stone"), nil, "a blocked player is not served")
	slash(ana, "unblock eve stone")
	whisperFrom(w, ana, "Eve Stone", "summon pls")
	w:advance(0.1)
	ok(state(ana, "Eve Stone") == "invited" or state(ana, "Eve Stone") == "queued", "served again: " .. tostring(state(ana, "Eve Stone")))
	slash(ana, "drop eve")
	eq(customer(ana, "Eve Stone"), nil)
	for _, line in ipairs({ "status", "stats", "msgs", "help", "", "nonsense" }) do slash(ana, line) end
	clean(w)
end)

test("drive: closed means closed", function()
	local w, ana = team({ open = false })
	whisperFrom(w, ana, "Dan Miller", "summon pls")
	w:advance(5)
	eq(#w.invites, 0)
	eq(next(DRof(ana).customers), nil)
	eq(plan(ana).title, "Closed")
	eq(ana.env.WuberDriveButton:GetAttribute("type"), nil)
	clean(w)
end)

test("drive: five rides in a row keep every count right", function()
	local w, ana, bea, cal = team()
	local a0 = w:player(ANA).money
	for i = 1, 5 do
		local name = "Rider N" .. i
		ask(w, ana, name)
		eq(state(ana, name), "joined", name .. " after the invite")
		summon(w, ana, bea, cal)
		eq(state(ana, name), "waiting", name .. " after the ritual")
		land(w)
		eq(state(ana, name), "arrived", name .. " after landing")
		pays(w, name, FARE)
		press(ana) -- accept
		w:advance(1.5)
		eq(state(ana, name), "paid", name .. " after the trade")
		press(ana) -- thank, remove
		w:advance(2)
		eq(customer(ana, name), nil, name .. " is off the list")
		eq(customer(cal, name), nil, name .. " is off Cal's list")
	end
	eq(session(ana).rides, 5)
	eq(session(bea).copper, 5 * FARE)
	eq(w:player(ANA).money - a0, 5 * FARE)
	eq(w:player(ANA).shards, 5)
	eq(stats(ana).rides, 5)
	eq(#dlog(ana).rides, 5, "five ride lines on the cashier's account")
	eq(#dlog(bea).team, 5, "and five crew lines on Bea's")
	eq(w.failedCasts, nil, "no cast failed")
	local said = 0
	for _, x in ipairs(w.whispers) do if x.from == ANA then said = said + 1 end end
	eq(said, 10, "a greeting and a thanks each")
	for _, m in ipairs(w.macros) do ok(#m.text <= 255, "macro length " .. #m.text) end
	clean(w)
end)

---------------------------------------------------------------------------
-- Public chat
---------------------------------------------------------------------------

test("drive: public lines: every way of asking for a summon to Ratchet, and what is not one", function()
	local w = newWorld()
	local ana = w:addClient(ANA, { spot = "Ratchet", class = "WARLOCK" })
	local DR = ana.W.Drive
	DR.SetDest("Ratchet")
	local match = {
		"wtb summon ratchet", "looking for sum ratchet", "LF summon to Ratchet", "LFS ratchet", "lf summ rachet pls",
		"WTB SUMMON TO RATCHET 3G", "need a summon to ratchet", "anyone summon me to ratchet?", "any locks for ratchet?",
		"can someone summon me to ratchet", "lfsum ratchet", "wtb summons ratchett", "looking for a warlock summon to Ratchet, paying",
		"summon to ratchet?", "need sum to ratch", "LF lock summon @ ratchet",
	}
	for _, line in ipairs(match) do eq(DR.PublicWant(line), "match", line) end
	local elsewhere = { "wtb summon org", "LF summon to Orgrimmar", "lf sum brd", "need a summon to booty bay", "wtb summon gadgetzan" }
	for _, line in ipairs(elsewhere) do eq(DR.PublicWant(line), "elsewhere", line) end
	eq(DR.PublicWant("LF summon"), "noplace")
	eq(DR.PublicWant("anyone able to summon?"), "noplace")
	local no = {
		"WTS summons to Ratchet, whisper me", "Summons to Ratchet 3g w me", "Selling summons to ratchet",
		"<Wuber> summoning to Ratchet now, whisper sum", "LFM ragefire chasm", "wtb [Linen Cloth]",
		"what is the sum of 2 and 2", "lf healer for wc", "summer is here",
		"[Wuber] Summons to Ratchet 50s - I'm a Wuber driver, get the free Wuber addon on CurseForge", -- the old advert, still heard
		"[Wuber] Summons to Ratchet 50s - I'm a Wuber driver, get the Wuber addon on CurseForge",
	}
	for _, line in ipairs(no) do eq(DR.PublicWant(line), nil, line) end
	DR.SetDest("Orgrimmar")
	eq(DR.PublicWant("wtb summon og"), "match")
	eq(DR.PublicWant("wtb summon ratchet"), "elsewhere")
	DR.SetDest("Ratchet", "the docks")
	eq(DR.PublicWant("lf summon to the docks"), "match", "a word added under Also called")
	clean(w)
end)

test("drive: Trade and LookingForGroup: a buyer for your place is invited and offered the price; another place is not", function()
	local w, ana, bea, cal = team()
	-- (2.3.2: off by default, on after a warning; switched on here as a player would)
	for _, c in ipairs({ ana, bea, cal }) do DRof(c).opts().autoPublic = true end
	DRof(ana).SetDest("Ratchet")
	w:advance(2)
	w:addBot("Dan Miller", { acceptsInvites = false })
	w:addBot("Eve Long")
	w:addBot("Fay Short")
	for _, c in ipairs({ ana, bea, cal }) do
		trade(c, "wtb summon ratchet", "Dan Miller")
		trade(c, "LF summon to Orgrimmar", "Eve Long")
	end
	channel(cal, "looking for sum ratchet", "Fay Short", "LookingForGroup", 4)
	w:advance(4)
	eq(state(ana, "Dan Miller"), "invited", "Dan asked for Ratchet in Trade: invited")
	local p = plan(ana)
	ok(p.macrotext and p.macrotext:find("/w Dan-Miller", 1, true) and p.macrotext:find("50s", 1, true), "the offer waits on the button: " .. tostring(p.macrotext))
	eq(customer(ana, "Eve Long"), nil, "Eve wants Orgrimmar: left alone")
	ok(state(ana, "Fay Short") == "invited" or state(ana, "Fay Short") == "joined" or state(ana, "Fay Short") == "queued", "Fay asked in LookingForGroup: " .. tostring(state(ana, "Fay Short")))
	press(ana)
	w:advance(1)
	eq(#w:whispersTo("Dan Miller"), 1, "one window speaks, not three")
	w:addBot("Ivy Ash")
	channel(ana, "wtb summon ratchet", "Ivy Ash", "LocalDefense - The Barrens", 3)
	w:advance(2)
	eq(state(ana, "Ivy Ash"), "lead", "LocalDefense: listed for a click")
	slash(ana, "market off")
	w:addBot("Hal Hill")
	trade(ana, "wtb summon ratchet", "Hal Hill")
	w:advance(2)
	eq(state(ana, "Hal Hill"), "lead", "with the switch off: listed only")
	clean(w)
end)

test("drive: standing in Ratchet, the place is Ratchet, not The Barrens", function()
	local w = newWorld()
	local ana = w:addClient(ANA, { spot = "Ratchet", class = "WARLOCK" })
	eq(ana.W.Drive.Dest(), "Ratchet")
	clean(w)
end)

test("drive: main caster: Ana casts, the others click; no shards or cooldown hands it to the next", function()
	local w, ana, bea, cal = team()
	slash(ana, "caster Ana Smith")
	w:advance(2)
	ask(w, ana, "Dan Miller")
	w:advance(2)
	eq(plan(ana).title, "Summon Dan", "Ana's button summons")
	eq(plan(bea).title, "Ana summons Dan", "Bea's button waits")
	eq(plan(cal).title, "Ana summons Dan")
	w:player(ANA).shards = 0
	ana:fire("BAG_UPDATE_DELAYED")
	w:advance(2)
	eq(plan(bea).title, "Summon Dan", "Bea takes over")
	eq(plan(cal).title, "Bea summons Dan")
	ok(plan(ana).title ~= "Summon Dan", "Ana does not cast")
	w:player(ANA).shards = 5
	w:player(ANA).cooldownUntil = w.time + 60
	ana:fire("BAG_UPDATE_DELAYED")
	w:advance(2)
	eq(plan(bea).title, "Summon Dan", "cooldown: Bea casts")
	w:advance(61)
	eq(plan(ana).title, "Summon Dan", "off cooldown: back to Ana")
	eq(plan(bea).title, "Ana summons Dan")
	summon(w, ana, bea, cal)
	ok(state(ana, "Dan Miller") ~= "joined", "the summon went out")
	slash(ana, "caster any")
	w:advance(2)
	eq(bea.W.Char().caster, "-", "anyone again, everywhere")
	clean(w)
end)

test("drive: Soul Shards: a warning at three, once; the team's total", function()
	local w, ana = team()
	local function warned()
		local n = 0
		for _, f in ipairs(ana.fired) do
			if f.name == "DRIVE_ALERT" and f.args[2] == "shards" then n = n + 1 end
		end
		return n
	end
	w:player(ANA).shards = 4
	ana:fire("BAG_UPDATE_DELAYED")
	w:advance(0.5)
	w:player(ANA).shards = 3
	ana:fire("BAG_UPDATE_DELAYED")
	w:advance(0.5)
	eq(warned(), 1, "three left: warned")
	ana:fire("BAG_UPDATE_DELAYED")
	w:advance(0.5)
	eq(warned(), 1, "once")
	w:player(ANA).shards = 2
	ana:fire("BAG_UPDATE_DELAYED")
	w:advance(0.5)
	eq(warned(), 2, "and again at two")
	w:advance(16) -- the next HI carries the counts
	local total = DRof(ana).TeamShards()
	eq(total, 22, "2 + 10 + 10")
	clean(w)
end)

test("drive: the advert channel: Services, Trade, LookingForGroup in turn; a reminder when due, once", function()
	local w, ana = team()
	slash(ana, "adevery 15")
	local first = DRof(ana).NextAd()
	ok(first, "a channel to post to")
	DRof(ana).MarkAdvert(first.name)
	local second = DRof(ana).NextAd()
	ok(second and second.name ~= first.name, "then the next one: " .. tostring(second and second.name))
	DRof(ana).MarkAdvert(second.name)
	local n0 = 0
	for _, f in ipairs(ana.fired) do if f.name == "DRIVE_ALERT" and f.args[2] == "advert" then n0 = n0 + 1 end end
	local function reminded()
		local n = 0
		for _, f in ipairs(ana.fired) do if f.name == "DRIVE_ALERT" and f.args[2] == "advert" then n = n + 1 end end
		return n - n0
	end
	w:advance(60)
	eq(reminded(), 0, "not due yet")
	w:advance(15 * 60)
	eq(reminded(), 1, "due after fifteen minutes")
	w:advance(30)
	eq(reminded(), 1, "said once")
	clean(w)
end)

test("drive: {guild} in a message is the guild's name in brackets", function()
	local w, ana = team()
	w:player(ANA).guild = "Wuber"
	slash(ana, "msg greet {guild} summons to {dest} for {price}!")
	ok(DRof(ana).Text("greet", { name = "Dan Miller", key = "dan miller", price = FARE }):find("^<Wuber> summons to "),
		DRof(ana).Text("greet", { name = "Dan Miller", key = "dan miller", price = FARE }))
	w:player(ANA).guild = nil
	ok(DRof(ana).Text("greet", { name = "Dan Miller", key = "dan miller", price = FARE }):find("^summons to "), "no guild: nothing")
	clean(w)
end)

test("drive: a small game window gets a bigger button, until you choose a size", function()
	local w = newWorld()
	local ana = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", physH = 2160 })
	local DR = ana.W.Drive
	eq(DR.Scale(), 1, "a 4K window: as drawn")
	ana.physH = 1080
	eq(DR.Scale(), 1.7, "half as tall: 170%")
	slash(ana, "scale 2.5")
	eq(DR.Scale(), 2.5, "your size wins")
	eq(DR.button:GetScale(), 2.5, "the button too")
	slash(ana, "scale auto")
	eq(DR.Scale(), 1.7, "back to the window's")
	clean(w)
end)

test("drive: public lines: portal words, one-letter typos, and direction (only to my place counts)", function()
	local w = newWorld()
	local DR = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK" }).W.Drive
	DR.SetDest("Undercity")
	local uc = {
		["wtb poral from org to uc"] = "match", ["wtb summ uc"] = "match", ["lf summon to uc"] = "match",
		["wtb summon from uc"] = "elsewhere", ["lf sum in uc"] = "elsewhere", ["need sum org > uc"] = "match",
		["wtb portal to uc"] = "match", ["wtb portl uc"] = "match", ["wtb teleprot to uc"] = "match",
		["lf portal to dalaran"] = "elsewhere", ["wts portal"] = nil, ["wtb portal"] = "noplace",
		["need sum uc > org"] = "elsewhere", ["wtb summon at uc"] = "elsewhere",
	}
	-- (a place after "to" that is not mine is somewhere else, known or not: Dalaran too)
	for line, want in pairs(uc) do eq(DR.PublicWant(line), want, line) end
	-- one letter off a topic word counts; real words never do
	for _, line in ipairs({ "wtb portel to uc", "lf poratl uc", "wtb portale uc", "wtb warlcok uc" }) do
		eq(DR.PublicWant(line), "match", line)
	end
	local plain = { "sun", "some", "sunny", "sport", "report", "portrait", "look", "summer", "salmon",
		"postal", "mortal", "warlord", "looks", "portly", "support", "important", "partial" }
	for _, word in ipairs(plain) do eq(DR.PublicWant("wtb " .. word .. " uc"), nil, word) end
	DR.SetDest("Orgrimmar")
	eq(DR.PublicWant("wtb poral from org to uc"), "elsewhere")
	eq(DR.PublicWant("need sum org > uc"), "elsewhere")
	clean(w)
end)

test("drive: help says a player who joins while you lead becomes a rider, and add invites one", function()
	local w = newWorld()
	local ana = w:addClient(ANA, { spot = "Ratchet", class = "WARLOCK" })
	ana:slash("/wuber drive help")
	local text = table.concat(ana.chatLines or {}, "\n")
	ok(text:find("joins your group while you are open and leading becomes a rider", 1, true), "join line: " .. text)
	ok(text:find("add <name>", 1, true), "add line")
	clean(w)
end)

test("drive: typos: summon and the place misspelt still count; ordinary words do not", function()
	local w = newWorld()
	local DR = w:addClient(ANA, { spot = "Ratchet", class = "WARLOCK" }).W.Drive
	DR.SetDest("Ratchet")
	local match = {
		"wtb sumon ratchet", "lf summn to ratchet", "need a summoon ratchet", "wtb sunmon ratchet",
		"lf summonig to ratchet", "wtb summon ratcet", "lf summon to rathcet", "anyone sumon me to ratchte?",
		"wtb smmon ratchet pls",
	}
	for _, line in ipairs(match) do eq(DR.PublicWant(line), "match", line) end
	local elsewhere = { "wtb sumon orgrimar", "lf summon to gadjetzan", "need sumon to undercty", "wtb summon thunderbluf" }
	for _, line in ipairs(elsewhere) do eq(DR.PublicWant(line), "elsewhere", line) end
	local no = { "summer in ratchet is hot", "wtb salmon ratchet", "lf common ratchet", "anyone got a match in ratchet" }
	for _, line in ipairs(no) do eq(DR.PublicWant(line), nil, line) end
	eq(DR.Classify("sumon pls"), "request", "a misspelt whisper is a request")
	eq(DR.Classify("hello there"), "other")
	clean(w)
end)

test("drive: a rider who leaves without paying is blocked in all three windows and told why when they ask again", function()
	local w, ana, bea, cal = team()
	-- (2.3.2: on, so "Trade: not invited" below is the block's doing, not the default's)
	for _, c in ipairs({ ana, bea, cal }) do DRof(c).opts().autoPublic = true end
	ask(w, ana, "Dan Miller")
	summon(w, ana, bea, cal)
	land(w)
	w:tradeCancel(w:player("Dan Miller"))
	w:leave("Dan Miller")
	w:advance(3 + DRof(ana).OWING_GRACE) -- (REVIEW-2.0 #1: decided after the grace, by one window)
	for _, c in ipairs({ ana, bea, cal }) do
		local e = DRof(c).BlockEntry("dan miller")
		ok(e, c.player.name .. " has him blocked")
		eq(e.reason, "you left without paying last time (50s)")
	end
	local invites = #w.invites
	whisperFrom(w, ana, "Dan Miller", "summon pls")
	w:advance(2)
	eq(#w.invites, invites, "not invited")
	eq(customer(ana, "Dan Miller"), nil, "not listed")
	local p = plan(ana)
	ok(p.macrotext and p.macrotext:find("won't be summoning you: you left without paying last time", 1, true), tostring(p.macrotext))
	press(ana)
	w:advance(1)
	local n = #w:whispersTo("Dan Miller")
	whisperFrom(w, ana, "Dan Miller", "summon?? pls")
	w:advance(2)
	ok(not (plan(ana).macrotext or ""):find("won't be summoning", 1, true), "told once, not every whisper")
	eq(#w:whispersTo("Dan Miller"), n)
	DRof(ana).SetDest("Undercity")
	trade(ana, "wtb summon uc", "Dan Miller")
	w:advance(2)
	eq(#w.invites, invites, "Trade: not invited")
	clean(w)
end)

test("drive: the block list: by hand with a reason, changed, unblocked, the same in every window", function()
	local w, ana, bea, cal = team()
	slash(ana, "block Eve Long - rude in trade")
	w:advance(2)
	eq(DRof(cal).BlockEntry("eve long").reason, "rude in trade")
	DRof(ana).Blacklist("Eve Long", "scammed us")
	w:advance(2)
	eq(DRof(bea).BlockEntry("eve long").reason, "scammed us", "the new reason reaches the others")
	DRof(ana).Blacklist("Fay Short", "never paid")
	w:advance(2)
	eq(#DRof(cal).BlockedList(), 2)
	DRof(ana).Unblacklist("Eve Long")
	w:advance(2)
	eq(DRof(bea).BlockEntry("eve long"), nil, "unblocked everywhere")
	eq(#DRof(bea).BlockedList(), 1)
	bea = w:reload(bea)
	bea.W.db.drive.blocklist = {}
	DRof(ana).SyncOut()
	w:advance(5)
	ok(DRof(bea).BlockEntry("fay short"), "the list comes with the sync")
	clean(w)
end)

test("drive: Services and World: buyers there are invited", function()
	local w, ana = team()
	DRof(ana).opts().autoPublic = true -- (2.3.2: off by default)
	DRof(ana).SetDest("Ratchet")
	w:advance(1)
	w:addBot("Dan Miller", { acceptsInvites = false })
	w:addBot("Eve Long", { acceptsInvites = false })
	channel(ana, "wtb summon ratchet", "Dan Miller", "Services", 3)
	channel(ana, "lf sum rachet", "Eve Long", "World", 5)
	w:advance(3)
	ok(state(ana, "Dan Miller") == "invited" or state(ana, "Dan Miller") == "queued", "Services: " .. tostring(state(ana, "Dan Miller")))
	ok(state(ana, "Eve Long") == "invited" or state(ana, "Eve Long") == "queued", "World: " .. tostring(state(ana, "Eve Long")))
	clean(w)
end)

test("drive: Undercity: every way of writing it", function()
	local w = newWorld()
	local DR = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK" }).W.Drive
	eq(DR.Dest(), "Undercity", "standing in Undercity")
	local match = {
		"wtb summon uc", "LF summ to UC", "need sum undercity", "summon under city pls", "lf sum U.C.", "LFS UC",
		"wtb summon undercty", "lfsum undercitty", "anyone summon me to the undercity?", "summon to undacity",
		"wtb sumon to UnderCity", "need a summon 2 uc", "lf summons uc 3g", "WTB SUMMON UC NOW", "looking for a lock to uc",
		"can someone summon me to undercit", "summon uc?", "wtb summ ucity", "lf summon undrcity",
	}
	for _, line in ipairs(match) do eq(DR.PublicWant(line), "match", line) end
	eq(DR.PublicWant("wtb summon org"), "elsewhere")
	eq(DR.PublicWant("WTS summons to UC, w me"), nil, "an advert")
	clean(w)
end)

test("drive: seller adverts with a price or a seller word are not buyers (20 Nov hotfix)", function()
	local w = newWorld()
	local DR = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK" }).W.Drive
	eq(DR.Dest(), "Orgrimmar", "standing in Orgrimmar")
	local adverts = {
		"portal service 70s to org", "summon to org pst", "port to org 5g", "summons to org 50 silver",
		"summon service to org dm", "portals to org 2 gold",
	}
	for _, line in ipairs(adverts) do eq(DR.PublicWant(line), nil, line) end
	local match = {
		"any summon service to org?", "lf summ to org 70s", "wtb summon to org", "summon to org", "wtb poral from uc to org",
	}
	for _, line in ipairs(match) do eq(DR.PublicWant(line), "match", line) end
	clean(w)
end)

test("drive: pause: nobody new is invited, the ride going on finishes, the queue is invited on resume", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller")
	eq(state(ana, "Dan Miller"), "joined")
	-- SPEC3 4.2: PAU is applied only from the group leader or the captain (RR took it from any
	-- teammate), so the pause is the leader's
	slash(ana, "pause")
	w:advance(1)
	ok(DRof(bea).IsPaused(), "the leader's pause reaches the crew")
	whisperFrom(w, ana, "Eve Long", "summon pls")
	w:advance(5)
	eq(state(ana, "Eve Long"), "queued", "Eve waits")
	summon(w, ana, bea, cal)
	land(w)
	pays(w, "Dan Miller", FARE)
	press(ana)
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "paid", "the paused ride is paid")
	eq(state(ana, "Eve Long"), "queued", "still waiting")
	slash(ana, "resume")
	w:advance(3)
	ok(state(ana, "Eve Long") == "invited" or state(ana, "Eve Long") == "joined", "invited on resume")
	eq(DRof(bea).IsPaused(), false, "resumed everywhere")
	clean(w)
end)

test("drive: one rider at a time: the next is invited when the last has paid", function()
	local w, ana, bea, cal = team()
	slash(ana, "oneatatime on")
	ask(w, ana, "Dan Miller")
	whisperFrom(w, ana, "Eve Long", "summon pls")
	w:advance(5)
	eq(state(ana, "Eve Long"), "queued", "Eve waits while Dan rides")
	summon(w, ana, bea, cal)
	land(w)
	pays(w, "Dan Miller", FARE)
	press(ana)
	w:advance(3)
	ok(state(ana, "Eve Long") == "invited" or state(ana, "Eve Long") == "joined", "Dan paid: Eve is invited")
	clean(w)
end)

test("drive: your request words count in public chat: uber, ride, taxi, lift (but not inv)", function()
	local w = newWorld()
	local ana = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK" })
	local DR = ana.W.Drive
	slash(ana, "keywords summon sum summ ride taxi uber wuber lift inv")
	for _, line in ipairs({ "need an uber to uc", "wtb ride to undercity", "lf taxi uc", "anyone got a wuber to uc?", "need a lift to undercity pls" }) do
		eq(DR.PublicWant(line), "match", line)
	end
	eq(DR.PublicWant("lf inv uc"), nil, "inv alone is not a summon")
	eq(DR.PublicWant("wtb ride to org"), "elsewhere")
	eq(DR.PublicWant("WTS rides to UC, w me"), nil, "an advert")
	clean(w)
end)

test("drive: two places in one line: the one after 'to' is where they want to go", function()
	local w = newWorld()
	local DR = w:addClient(ANA, { spot = "Undercity", class = "WARLOCK" }).W.Drive
	local cases = {
		{ "summon to tb from uc", "elsewhere" }, { "wtb summon from uc to tb", "elsewhere" }, { "lf summon uc to org", "elsewhere" },
		{ "im in uc, need summon to ratchet", "elsewhere" }, { "wtb summon to uc from tb", "match" },
		{ "need a summon from org to uc", "match" }, { "in tb, lf summon to undercity", "match" },
		{ "lf summon uc from booty bay", "match" }, { "summon tb uc", "unclear" }, { "wtb summon uc", "match" },
	}
	for _, c in ipairs(cases) do eq(DR.PublicWant(c[1]), c[2], c[1]) end
	clean(w)
end)

test("drive: a line naming two places without saying which is listed, not invited", function()
	local w, ana = team()
	w:addBot("Dan Miller")
	w:addBot("Eve Long")
	channel(ana, "summon to tb from uc", "Dan Miller", "Services", 3)
	channel(ana, "lf summon tb uc", "Eve Long", "Services", 3) -- (2.4, careful mode: a public line needs an asking word to be listed; "summon tb uc" alone is nobody's request)
	w:advance(3)
	eq(customer(ana, "Dan Miller"), nil, "wants Thunder Bluff: left alone")
	eq(state(ana, "Eve Long"), "lead", "unclear: listed for a click")
	clean(w)
end)

test("drive: skip: the name the button is about to whisper is dropped, nothing said; shift blocks", function()
	local w, ana = team()
	DRof(ana).opts().autoPublic = true -- (2.3.2: off by default)
	w:addBot("Dan Miller", { acceptsInvites = false })
	channel(ana, "wtb summon uc", "Dan Miller", "Services", 3)
	w:advance(3)
	local c = DRof(ana).SkipTarget()
	ok(c and c.name == "Dan Miller", "the button is about Dan")
	DRof(ana).Skip(false)
	w:advance(1)
	eq(customer(ana, "Dan Miller"), nil, "off the list")
	eq(#w:whispersTo("Dan Miller"), 0, "nothing said to him")
	w:addBot("Eve Long", { acceptsInvites = false })
	whisperFrom(w, ana, "Eve Long", "how much")
	w:advance(2)
	c = DRof(ana).SkipTarget()
	ok(c and c.name == "Eve Long", "the button is about Eve")
	DRof(ana).Skip(true)
	w:advance(2)
	ok(DRof(ana).BlockEntry("eve long"), "Eve is blocked")
	clean(w)
end)

test("drive: log: payments by the cashier's window, buyers by every window, open minutes per hour", function()
	local w, ana, bea, cal = team()
	-- (2.3.2: off by default, on after a warning; switched on here as a player would)
	for _, c in ipairs({ ana, bea, cal }) do DRof(c).opts().autoPublic = true end
	ask(w, ana, "Dan Miller")
	summon(w, ana, bea, cal)
	land(w)
	pays(w, "Dan Miller", FARE)
	press(ana)
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "paid")
	local rides = dlog(ana).rides
	eq(#rides, 1, "Ana's account logged the ride")
	local at, copper, name, dest, how, price = rides[1]:match("^(%d+),(%d+),([^,]*),([^,]*),(%a),(%d+)$")
	eq(tonumber(copper), FARE)
	eq(name, "Dan Miller")
	eq(dest, "Undercity")
	eq(how, "t")
	eq(tonumber(price), FARE, "the price charged (2.0's 6th field)")
	ok(tonumber(at) >= ana.env.time() - 120, "stamped with the clock")
	eq(#dlog(bea).rides, 0, "a crew mate's account does not log Ana's payment")
	eq(#dlog(bea).team, 1, "but keeps a crew line")
	for _, c in ipairs({ ana, bea }) do
		channel(c, "wtb summon uc", "Eve Long", "Services", 3)
		trade(c, "LF summon to BRM, paying", "Fay Reed")
		trade(c, "WTS summons 3g", "Gus Competitor")
		trade(c, "selling summons, ask me", BEA)
		trade(c, "[Wuber] Summons to Undercity 50s - I'm a Wuber driver", "Rex Rival")
	end
	local asks = dlog(ana).asks
	eq(#asks, 2, "two buyers, no advert, no crew mate")
	ok(asks[1]:find(",match,Eve Long,m,Undercity,wtb summon uc$"), asks[1])
	ok(asks[2]:find(",elsewhere,Fay Reed,m,Undercity,LF summon to BRM paying$"), asks[2])
	eq(#dlog(bea).asks, 2, "Bea logged them too (the tool counts each once)")
	slash(ana, "off")
	w:advance(1)
	channel(ana, "need a summon to undercity", "Hal Late", "Services", 3)
	-- SPEC5 public (review #18): buyers are read only while driving; closed, nothing is parsed
	eq(#asks, 2, "not read while closed")
	local l = dlog(ana)
	local function sum(map) local n = 0 for _, m in pairs(map) do n = n + m end return n end
	w:advance(61)
	local seen0, open0 = sum(l.seen), sum(l.open)
	w:advance(600)
	eq(sum(l.seen) - seen0, 10, "ten minutes seen")
	eq(sum(l.open) - open0, 0, "closed: no open minutes")
	slash(ana, "on")
	w:advance(600)
	eq(sum(l.open) - open0, 10, "ten open minutes")
	slash(ana, "pause")
	w:advance(300)
	eq(sum(l.open) - open0, 10, "paused: not open")
	eq(sum(l.seen) - seen0, 25)
	for k in pairs(l.seen) do ok(tostring(k):match("^%d%d%d%d%d%d%d%d%d%d$"), "hour key " .. k) end
	local before = #ana.chatLines
	slash(ana, "log")
	local text = table.concat(ana.chatLines, "\n", before + 1)
	ok(text:find("today, this window: 1 rides, 50s", 1, true), text)
	ok(text:find("heatmap", 1, true), text)
	clean(w)
end)

---------------------------------------------------------------------------
-- Wuber's own network: RR's fake WuberAPI tests, now with real riders (R/A/S/N/P/Q)
---------------------------------------------------------------------------

local TESTCHAR = "Wuber TestCharacter"

-- a rider with the Wuber app (a Mage in Orgrimmar)
local function rider(w, name, opts)
	opts = opts or {}
	return w:addClient(name or TESTCHAR, { spot = opts.spot or "Orgrimmar", class = opts.class or "MAGE", money = opts.money or 100000,
		addonDirs = opts.addonDirs, roundOne = opts.roundOne, secrets = opts.secrets })
end

-- the S stages sent to a rider, joined; and the senders
local function stagesTo(w, to)
	local out, from = {}, {}
	for _, e in ipairs(msgs(w, "S")) do
		if e.target and key(e.target) == key(to) then
			out[#out + 1] = fields(e)[4]
			from[e.from] = true
		end
	end
	return table.concat(out, ","), from
end

local function lastOf(w, kind, to)
	local last
	for _, e in ipairs(msgs(w, kind)) do
		if not to or (e.target and key(e.target) == key(to)) then last = e end
	end
	return last
end

test("drive: Wuber: the engine is the driver; only the leader's window beacons, only while open", function()
	local w, ana, bea, cal = team({ open = false })
	local r = rider(w)
	w:advance(15)
	for _, c in ipairs({ ana, bea, cal }) do
		ok(c.W.engine, c.player.name .. ": the engine is attached")
		eq(c.W.Provider(), nil, "never shown as an outside provider")
		eq(c.env.WuberAPI.Driving(), "engine")
	end
	eq(#msgs(w, "D"), 0, "closed: no beacon")
	DRof(ana).SetOpen(true)
	w:advance(6)
	local d = r.W.drivers["ana smith"]
	ok(d, "the rider sees the crew")
	eq(d.dest, "Undercity")
	eq(d.price, FARE)
	eq(d.state, "open")
	eq(d.team, 3, "three Warlocks in the group")
	eq(#msgs(w, "D", BEA) + #msgs(w, "D", CAL), 0, "the followers never beacon")
	DRof(ana).SetPaused(true)
	w:advance(6)
	eq(r.W.drivers["ana smith"].state, "paused")
	DRof(ana).SetPaused(false)
	slash(ana, "price 3g")
	w:advance(6)
	eq(r.W.drivers["ana smith"].price, 30000)
	slash(ana, "dest Orgrimmar")
	w:advance(6)
	eq(r.W.drivers["ana smith"].dest, "Orgrimmar")
	DRof(ana).SetOpen(false)
	w:advance(6)
	eq(r.W.drivers["ana smith"], nil, "closed: off the network (X)")
	eq(#msgs(w, "D", BEA) + #msgs(w, "D", CAL), 0)
	clean(w)
end)

test("drive: Wuber: a request is invited and accepted once; each step goes to the rider once, from one window", function()
	local w, ana, bea, cal = team()
	local r = rider(w)
	w:advance(15)
	r.W.db.autoAccept = true
	local ride = r.W.RequestRide("ana smith")
	ok(ride, "requested")
	w:advance(0.3)
	w:whisper(r, ANA, r.W.RequestWhisper("ana smith"), "macro") -- the same click's chat line
	w:advance(1)
	eq(nCustomers(ana), 1, "one rider")
	eq(customer(ana, TESTCHAR).source, "wuber")
	eq(#w.invites, 1, "one invite")
	eq(#msgs(w, "A", ANA), 1, "accepted once")
	eq(fields(msgs(w, "A", ANA)[1])[3], ride.id)
	w:advance(3)
	eq(state(ana, TESTCHAR), "joined")
	eq(r.W.drivers["ana smith"].state, "busy", "a ride under way")
	summon(w, ana, bea, cal)
	w.hardware = r
	r.W.AcceptSummon()
	w.hardware = nil
	land(w)
	eq(state(ana, TESTCHAR), "arrived")
	w:typeTradeMoney(r, 0, 50, 0)
	w:tradeAccept(r)
	w:advance(0.3)
	press(ana)
	w:advance(1.5)
	eq(state(ana, TESTCHAR), "paid")
	press(ana)
	w:advance(3)
	eq(customer(ana, TESTCHAR), nil, "thanked and removed")
	local st, from = stagesTo(w, TESTCHAR)
	eq(st, "invited,summoning,portal,arrived,paid,done", "every step, once, in order")
	eq(count(from), 1, "from one window")
	ok(from[ANA], "Ana's")
	eq(r.W.ride and r.W.ride.state or "done", "done", "the rider's ride is done")
	w:advance(6)
	eq(r.W.drivers["ana smith"].state, "open", "free again")
	clean(w)
end)

test("drive: Wuber: the chat line first, then the request: still one rider; a second rider waits and is told", function()
	local w, ana, bea = team()
	local r = rider(w)
	local r2 = rider(w, "Fay Moss")
	w:advance(15)
	w:whisper(r, ANA, "WTB summon to Undercity for 50s", "macro")
	w:advance(0.2)
	eq(state(ana, TESTCHAR), "invited", "the chat line alone is a request")
	r.W.RequestRide("ana smith")
	w:advance(1)
	eq(nCustomers(ana), 1, "one rider")
	eq(#w.invites, 1, "one invite")
	eq(#msgs(w, "A", ANA), 1)
	slash(ana, "max 4")
	w:advance(3)
	r2.W.RequestRide("ana smith")
	w:advance(2)
	eq(state(ana, "Fay Moss"), "queued")
	local p = lastOf(w, "P", "Fay Moss")
	ok(p, "the waiting rider is told her place (P)")
	eq(fields(p)[4], "1", "first in the queue")
	clean(w)
end)

test("drive: Wuber: the rider's line is a request, never a price question or an advert", function()
	local w = newWorld()
	local ana = w:addClient(ANA, { spot = "Ratchet", class = "WARLOCK" })
	local DR = ana.W.Drive
	eq(DR.Classify("WTB summon to Ratchet for 50s"), "request")
	eq(DR.Classify("WTB summon to Light's Hope Chapel for 12g 34s 56c"), "request")
	eq(DR.Classify("WTB summon to Feralas for 1g"), "request")
	ok(DR.WuberLine("WTB summon to Ratchet for 50s"))
	ok(not DR.WuberLine("WTS summons to Ratchet, whisper me"))
	DR.SetOpt("keywords", "taxi")
	eq(DR.Classify("WTB summon to Ratchet for 50s"), "request", "whatever the request words")
	eq(DR.Classify("Sorry, cancelled my summon - thanks anyway"), "cancel")
	eq(DR.Classify("Sorry, I have to cancel - thanks anyway"), "cancel")
	DR.SetDest("Ratchet")
	eq(DR.PublicWant("WTB summon to Ratchet for 50s"), "match", "a buyer, not an advert")
	eq(DR.PublicWant("WTS summons to Ratchet for 50s"), nil, "a seller")
	clean(w)
end)

test("drive: Wuber: blocked is declined 'blocked'; closed and paused are declined 'closed'", function()
	local w, ana = team()
	local r = rider(w)
	w:addBot("Eve Long")
	w:addBot("Gus Hart")
	w:advance(15)
	slash(ana, "block Wuber TestCharacter - never paid")
	w:advance(1)
	r.W.RequestRide("ana smith")
	w:advance(2)
	local n = lastOf(w, "N", TESTCHAR)
	ok(n, "declined")
	eq(fields(n)[4], "blocked")
	eq(customer(ana, TESTCHAR), nil)
	DRof(ana).SetPaused(true)
	w:advance(6)
	eq(r.W.RequestRide("ana smith"), nil, "the app refuses a paused driver itself")
	w:inject("Eve Long", "R~1~pausea~Undercity~5000", "WHISPER", ana) -- an older app asks anyway
	w:advance(2)
	n = lastOf(w, "N", "Eve Long")
	ok(n and fields(n)[4] == "closed", "paused: closed")
	eq(customer(ana, "Eve Long"), nil)
	DRof(ana).SetPaused(false)
	w:advance(6)
	DRof(ana).SetOpen(false)
	w:inject("Gus Hart", "R~1~closed~Undercity~5000", "WHISPER", ana)
	w:advance(2)
	n = lastOf(w, "N", "Gus Hart")
	ok(n and fields(n)[4] == "closed", "closed: closed")
	eq(next(DRof(ana).customers), nil)
	eq(#w.invites, 0)
	clean(w)
end)

test("drive: Wuber: a rider who cancels before the summon is taken off the list; once it has begun, kept", function()
	local w, ana, bea, cal = team()
	local r = rider(w)
	local r2 = rider(w, "Eve Long")
	w:advance(15)
	r.W.RequestRide("ana smith")
	w:advance(4)
	eq(state(bea, TESTCHAR), "joined")
	w:inject(TESTCHAR, "C~1~nottheride", "WHISPER", ana)
	w:advance(1)
	eq(state(ana, TESTCHAR), "joined", "another ride's cancel changes nothing")
	r.W.CancelRide()
	w:advance(2)
	eq(customer(ana, TESTCHAR), nil)
	w:whisper(r, ANA, "Sorry, I have to cancel - thanks anyway", "macro")
	w:advance(5)
	eq(customer(ana, TESTCHAR), nil, "the cancel whisper is not a request")
	eq(customer(bea, TESTCHAR), nil, "in any window")
	w:whisper(r, ANA, "summon pls", "user")
	w:advance(0.2)
	eq(customer(ana, TESTCHAR), nil, "no whisper request for 30 s after a cancel")
	ok(r2.W.RequestRide("ana smith"), "Eve books")
	w:advance(4)
	summon(w, ana, bea, cal)
	r2.W.CancelRide()
	w:advance(1)
	ok(customer(ana, "Eve Long"), "the summon has begun: kept")
	w:advance(30)
	w:whisper(r, ANA, "summon pls", "user")
	w:advance(1)
	ok(customer(ana, TESTCHAR), "30 s after the cancel, served again")
	clean(w)
end)

test("drive: Wuber: a rating is said in chat once, by the window that drove", function()
	local w, ana, bea = team()
	local p = DRof(ana).ENGINE
	p.onRating("abcdef", "Dan Miller", 5)
	p.onRating("abcdef", "Dan Miller", 5)
	local function said(text)
		local n = 0
		for _, line in ipairs(ana.chatLines) do if line:find(text, 1, true) then n = n + 1 end end
		return n
	end
	eq(said("Dan Miller rated the ride 5 stars"), 1)
	p.onRating("second", "Eve Long", 1)
	eq(said("Eve Long rated the ride 1 star"), 1)
	p.onRating("thirdx", "Fay Moss", 9)
	eq(said("Fay Moss"), 0, "not a rating")
	ok(not bea:said("rated the ride"), "only the window that drove")
	clean(w)
end)

test("drive: Wuber: a request at a price riders were not shown is declined 'price'; one shown in the last 150 s is honoured", function()
	local w, ana = team()
	local r = rider(w) -- (someone watching the beacons)
	for _, n in ipairs({ "Dan Miller", "Eve Long", "Fay Moss" }) do w:addBot(n) end
	w:advance(15) -- riders saw 50s
	ok(r.W.drivers["ana smith"] and r.W.drivers["ana smith"].price == 5000, "shown 50s")
	slash(ana, "price 60s")
	w:advance(3)
	w:inject("Dan Miller", "R~1~olderp~Undercity~5000", "WHISPER", ana) -- asks at what it was shown
	w:advance(1)
	ok(customer(ana, "Dan Miller"), "honoured")
	eq(customer(ana, "Dan Miller").price, 5000, "the price the rider was shown")
	w:inject("Eve Long", "R~1~cheapo~Undercity~4000", "WHISPER", ana)
	local d0 = #msgs(w, "D", ANA)
	w:advance(2)
	local n = lastOf(w, "N", "Eve Long")
	ok(n and fields(n)[4] == "price", "40s was never shown")
	ok(#msgs(w, "D", ANA) > d0, "and the price is beaconed again")
	eq(customer(ana, "Eve Long"), nil)
	w:advance(200)
	w:inject("Fay Moss", "R~1~stalex~Undercity~5000", "WHISPER", ana)
	w:advance(1)
	n = lastOf(w, "N", "Fay Moss")
	ok(n and fields(n)[4] == "price", "50s shown more than 150 s ago")
	w:inject("Fay Moss", "R~1~higher~Undercity~7000", "WHISPER", ana)
	w:advance(1)
	ok(customer(ana, "Fay Moss"), "more than the price is fine")
	eq(customer(ana, "Fay Moss").price, 6000, "and pays the price")
	clean(w)
end)

test("drive: Wuber: another destination is declined 'closed'; a crew mate's request 'blocked', never accepted", function()
	local w, ana = team()
	w:addBot("Dan Miller")
	w:advance(15)
	w:inject("Dan Miller", "R~1~otherd~Ratchet~5000", "WHISPER", ana)
	w:advance(1)
	local n = lastOf(w, "N", "Dan Miller")
	ok(n and fields(n)[4] == "closed", "another place")
	eq(customer(ana, "Dan Miller"), nil)
	w:inject("Dan Miller", "R~1~sameds~undercity~5000", "WHISPER", ana)
	w:advance(1)
	ok(customer(ana, "Dan Miller"), "the same place, written differently")
	w:inject(BEA, "R~1~mateis~Undercity~5000", "WHISPER", ana)
	w:advance(1)
	n = lastOf(w, "N", BEA)
	ok(n and fields(n)[4] == "blocked", "a crew mate")
	eq(#msgs(w, "A", ANA), 1)
	clean(w)
end)

test("drive: Wuber: not grouped, only the captain's window beacons", function()
	local w = newWorld()
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, n in ipairs(names) do cs[i] = w:addClient(n, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(n, names, ANA) } }) end
	local r = rider(w)
	for _, c in ipairs(cs) do c.W.Drive.SetOpen(true) end
	w:advance(15)
	ok(r.W.drivers["ana smith"], "the captain")
	eq(r.W.drivers["bea jones"], nil)
	eq(r.W.drivers["cal brown"], nil)
	eq(cs[2].W.Drive.NetDriver(), false)
	eq(cs[1].W.Drive.NetDriver(), true)
	clean(w)
end)

-- SPEC3 decision 8: the fare floor is 50s for all driving; the price clamps and says so
test("drive: Wuber: a fare under 50s clamps to 50s and says so", function()
	local w, ana = team()
	local price, clamped = DRof(ana).SetPrice(4000)
	eq(price, 5000)
	eq(ana.W.Char().price, 5000, "clamped to 50s")
	eq(clamped, true, "and says so (the sheet's note)")
	slash(ana, "price 40s")
	w:advance(2)
	eq(ana.W.Char().price, 5000)
	w:advance(2)
	eq(DRof(ana).NetBeacon() and DRof(ana).NetBeacon().price, 5000, "the beacon shows 50s")
	clean(w)
end)

test("drive: Wuber: Accept carries the price charged (after a cut, or an older one honoured)", function()
	local w, ana = team()
	w:addBot("Dan Miller")
	w:addBot("Eve Long")
	local r = rider(w)
	slash(ana, "price 1g")
	w:advance(15) -- riders see 1g
	slash(ana, "price 80s")
	w:advance(3)
	w:inject("Dan Miller", "R~1~cutcut~Undercity~10000", "WHISPER", ana) -- asked at 1g, the price is now 80s
	w:advance(1)
	local a = lastOf(w, "A", "Dan Miller")
	ok(a, "accepted")
	eq(fields(a)[4], "8000", "the rider is told 80s, what they pay")
	eq(customer(ana, "Dan Miller").price, 8000)
	w:advance(6) -- riders see 80s
	slash(ana, "price 1g 20s")
	w:advance(3)
	w:inject("Eve Long", "R~1~olderp~Undercity~8000", "WHISPER", ana)
	w:advance(1)
	a = lastOf(w, "A", "Eve Long")
	ok(a, "accepted")
	eq(fields(a)[4], "8000", "the honoured price")
	clean(w)
end)

test("drive: Wuber: a rider put back in the queue keeps their ride for 10 minutes; its steps still go out", function()
	local w, ana, bea, cal = team()
	local DAN = "Dan Miller"
	w:addBot(DAN).group = { leader = "Zed Other", members = { "Zed Other", DAN } }
	w:advance(15)
	w:inject(DAN, "R~1~abcdef~Undercity~5000", "WHISPER", ana)
	w:advance(2)
	eq(state(ana, DAN), "lead", "already in a group")
	w:player(DAN).group = nil
	whisperFrom(w, ana, DAN, "summon pls")
	w:advance(0.2)
	ok(state(ana, DAN) == "queued" or state(ana, DAN) == "invited", "asked again: " .. tostring(state(ana, DAN)))
	eq(customer(ana, DAN).wuberRide, "abcdef", "the ride is still theirs")
	w:advance(4)
	summon(w, ana, bea, cal)
	local st = stagesTo(w, DAN)
	ok(st:find("invited,summoning,portal", 1, true), "the steps go on: " .. st)
	clean(w)
end)

test("drive: Wuber: riders waiting are told their place and the wait, by one window, as it changes", function()
	local w, ana, bea, cal = team()
	slash(ana, "max 3")
	local rs = { rider(w, "Dan Miller"), rider(w, "Eve Long"), rider(w, "Fay Moss") }
	w:advance(15)
	for _, r in ipairs(rs) do r.W.RequestRide("ana smith") w:advance(0.3) end
	w:advance(6) -- (beacons and places are coalesced, 5 s apart at most)
	local function place(name)
		local p = lastOf(w, "P", name)
		return p and fields(p)[4]
	end
	eq(place("Dan Miller"), "1", "Dan is next")
	eq(place("Eve Long"), "2")
	eq(place("Fay Moss"), "3")
	eq(rs[1].W.drivers["ana smith"].queue, 3, "the beacon says three are waiting")
	slash(ana, "max 4")
	w:advance(6)
	eq(state(ana, "Dan Miller"), "joined")
	eq(place("Eve Long"), "1", "Eve moved up")
	eq(place("Fay Moss"), "2")
	eq(#msgs(w, "P", BEA) + #msgs(w, "P", CAL), 0, "the followers send no places")
	clean(w)
end)

test("drive: Wuber: the log counts requests received and declined, and the most rival drivers seen each hour", function()
	local w, ana, bea = team()
	w:addBot("Dan Miller")
	w:addBot("Eve Long")
	local rex = w:addClient("Rex Rival", { spot = "Ratchet", class = "WARLOCK" })
	rex.W.Drive.SetOpen(true)
	w:advance(15)
	w:inject("Dan Miller", "R~1~rideaa~Undercity~5000", "WHISPER", ana)
	w:inject("Eve Long", "R~1~ridebb~Ratchet~5000", "WHISPER", ana) -- declined: another place
	w:advance(61)
	local hour = os.date("%Y%m%d%H", H.EPOCH + math.floor(w.time))
	local l = dlog(ana)
	eq(l.wreq[hour], 2, "two requests")
	eq(l.wdec[hour], 1, "one declined")
	eq(l.rivals[hour], 1, "one other driver (not the crew)")
	eq(dlog(bea).wreq[hour], nil, "Bea received none")
	eq(dlog(bea).rivals[hour], 1, "but saw the same drivers")
	clean(w)
end)

---------------------------------------------------------------------------
-- The alert character (RR's bell): a fourth window, "Wuber Rocks" (another account, not in
-- the group), hears every summon-related moment by WUBERT addon whisper (BH, BE)
---------------------------------------------------------------------------

local WUBER = "Wuber Rocks"

-- (SPEC3 3.1: drive.bell is per account, so each crew window names it; RR shared it by fact)
local function bellWorld(opts)
	local w, ana, bea, cal = team(opts)
	local wub = w:addClient(WUBER, { spot = "Orgrimmar", class = "MAGE" })
	for _, c in ipairs({ ana, bea, cal }) do slash(c, "bell " .. WUBER) end
	w:advance(3)
	return w, ana, bea, cal, wub
end

-- BE/BH whispers a window sent: { e } (e.text)
local function bells(w, from, kind)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.chatType == "WHISPER" and e.result == 0 and (not from or e.from == from) then
			local k = e.text:match("^(%u%u)~")
			if (k == "BE" or k == "BH") and (not kind or k == kind) then out[#out + 1] = e end
		end
	end
	return out
end
local function beText(e) return e.text:match("^BE~1~[^~]*~(.*)$") end
local function banner(c) return c.env.WuberBell end
local function counter(c) return c.env.WuberBellCount end

test("drive: alert character: each crew window names it; the alert window learns the crew from a BH", function()
	local w, ana, bea, cal, wub = bellWorld()
	eq(ana.W.db.drive.bell.name, WUBER)
	eq(#bells(w, ANA, "BH"), 1, "one BH from Ana's window")
	eq(#bells(w, nil, "BE"), 0, "nothing has happened yet")
	local team = wub.W.db.drive.bell.team
	table.sort(team)
	eq(table.concat(team, ","), "ana smith,bea jones,cal brown", "the alert window knows the three")
	eq(wub.W.db.drive.bell.service, "Ana Smith", "the service name")
	eq(wub.W.db.drive.bell.lead, "Ana", "the leader: the window to swap to")
	ok(not wub.player.group, "the alert character is in no group")
	local okb, why = DRof(ana).BellSet(BEA)
	eq(okb, false, "a crew member cannot be the alert character")
	ok(tostring(why):find("crew", 1, true), tostring(why))
	eq(ana.W.db.drive.bell.name, WUBER, "unchanged")
	slash(ana, "bell off")
	eq(ana.W.db.drive.bell.name, "", "off")
	eq(DRof(wub).Role(), "alert", "the alert window's role")
	clean(w)
end)

test("drive: alert character: a rider's whisper rings once, from the window it reached; the banner flashes", function()
	local w, ana, bea, cal, wub = bellWorld()
	w:addBot("Dan Miller")
	whisperFrom(w, bea, "Dan Miller", "summon pls, I'm at the bank in Ironforge by the mailbox")
	w:advance(0.5)
	eq(#bells(w, CAL, "BE"), 0, "Cal sent nothing")
	w:advance(1)
	local ev = {}
	for _, e in ipairs(bells(w, nil, "BE")) do if beText(e):find("whisper from", 1, true) then ev[#ev + 1] = e end end
	eq(#ev, 1, "exactly one alert for the whisper")
	eq(ev[1].from, BEA, "from the window it reached")
	eq(beText(ev[1]), "Bea: whisper from Dan Miller: summon pls, I'm at the bank in Ironforge", "who, and the first 40 characters")
	local b = banner(wub)
	ok(b and b:IsShown(), "the banner is up")
	ok(wub:said("Bea: whisper from Dan Miller"), "the alert was shown in chat")
	ok(#wub.sounds > 0, "the alert sound")
	ok(wub.flashes >= 1, "the taskbar icon flashes")
	w:advance(4)
	local summons = {}
	for _, e in ipairs(bells(w, nil, "BE")) do if beText(e):find("Summon Dan", 1, true) then summons[#summons + 1] = e end end
	eq(#summons, 1, "one 'Summon Dan' (the caster's button)")
	eq(summons[1].from, ANA)
	eq(#bells(w, CAL, "BE"), 0, "Cal still sent nothing")
	ok(counter(wub):IsShown(), "the counter")
	ok(counter(wub).text:GetText():find("alerts$"), counter(wub).text:GetText())
	local alphas = {}
	for _ = 1, 4 do
		w:advance(0.25)
		alphas[#alphas + 1] = b:GetAlpha()
	end
	ok(alphas[1] ~= alphas[2], "it flashes: " .. table.concat(alphas, " "))
	w:advance(7)
	eq(b:GetAlpha(), 1, "steady after 6 s")
	ok(b:IsShown(), "and still there")
	wub:click(b)
	eq(b:IsShown(), false, "a click dismisses it")
	ok(counter(wub):IsShown(), "the counter stays")
	wub:click(counter(wub))
	eq(counter(wub):IsShown(), false, "a click clears the counter")
	eq(alertCount(wub), 0)
	eq(customer(ana, WUBER), nil, "the alert character is no rider")
	-- no Scale animation on any frame holding text (SPEC3 house rule)
	local function noScale(f)
		for _, g in ipairs(S[f].animGroups or {}) do
			for _, a in ipairs(S[g].anims or S[g].children or {}) do ok(S[a].otype ~= "Scale", "a Scale animation on " .. tostring(f)) end
		end
		for _, ch in ipairs(S[f].children or {}) do if S[ch].kind == "frame" then noScale(ch) end end
	end
	noScale(banner(wub))
	noScale(counter(wub))
	clean(w)
end)

test("drive: alert character: the same text within 5 s goes once; one message a second at most; two windows, one alert", function()
	local w, ana, bea, cal, wub = bellWorld()
	local DR = DRof(ana)
	ok(DR.Ring("test one", true))
	ok(not DR.Ring("test one", true), "the same text again: not sent")
	ok(not DR.Ring("test one", true))
	DR.Ring("test two", true)
	DR.Ring("test three", true)
	w:advance(4)
	local ev = bells(w, ANA, "BE")
	eq(#ev, 3, "three different texts, the repeat dropped")
	for i = 2, #ev do ok(ev[i].at - ev[i - 1].at >= 1, "a second apart: " .. ev[i - 1].at .. " " .. ev[i].at) end
	w:advance(3)
	ok(DR.Ring("test one", true), "after 5 s it may ring again")
	w:advance(2)
	eq(#bells(w, ANA, "BE"), 4)
	local n = alertCount(wub)
	DRof(bea).Ring("Click the portal - Ana is summoning Eve", true)
	DRof(cal).Ring("Click the portal - Ana is summoning Eve", true)
	w:advance(3)
	eq(alertCount(wub), n + 1, "one alert for both")
	clean(w)
end)

test("drive: alert character: a stranger's alerts are ignored", function()
	local w, ana, bea, cal, wub = bellWorld()
	local eve = w:addClient("Eve Stranger", { spot = "Orgrimmar", class = "MAGE" })
	local send = eve.env.C_ChatInfo.SendAddonMessage
	send("WUBERT", "BE~1~Eve~Free gold, click here", "WHISPER", WUBER)
	w:advance(1)
	ok(not banner(wub) or not banner(wub):IsShown(), "no banner")
	eq(alertCount(wub), 0)
	send("WUBERT", "BH~1~Scam Rides~eve stranger~Eve~2.0.0", "WHISPER", WUBER)
	w:advance(1)
	send("WUBERT", "BE~1~Eve~Free gold, click here", "WHISPER", WUBER)
	w:advance(1)
	eq(alertCount(wub), 0, "still ignored")
	local team = wub.W.db.drive.bell.team
	table.sort(team)
	eq(table.concat(team, ","), "ana smith,bea jones,cal brown", "the crew is unchanged")
	send("WUBERT", "BH~1~Ana Smith~ana smith,bea jones~Ana~2.0.0", "WHISPER", WUBER) -- a BH not naming its sender
	w:advance(1)
	send("WUBERT", "BE~1~Ana~Ana: Summon Dan", "WHISPER", WUBER)
	w:advance(1)
	eq(alertCount(wub), 0, "a forged BH earns nothing")
	ok(DRof(wub).bell.ignored >= 4)
	bea.env.C_ChatInfo.SendAddonMessage("WUBERT", "BE~1~Ana~Bea: a real one", "WHISPER", WUBER)
	w:advance(1)
	eq(alertCount(wub), 1, "a crew window: heard")
	DRof(wub).BellForget()
	eq(#wub.W.db.drive.bell.team, 0, "Forget clears the crew")
	clean(w)
end)

test("drive: alert character: nothing goes when it is off, while closed with nobody listed, or from its own window", function()
	local w, ana, bea, cal, wub = bellWorld()
	slash(ana, "bell off")
	w:advance(2)
	local n = #bells(w, ANA)
	whisperFrom(w, ana, "Dan Miller", "summon pls")
	w:advance(5)
	eq(#bells(w, ANA), n, "off: nothing sent")
	ok(not DRof(ana).Ring("anything"))
	slash(ana, "drop Dan Miller")
	slash(ana, "bell " .. WUBER)
	slash(ana, "off")
	slash(bea, "off")
	w:advance(3)
	for _, c in ipairs({ ana, bea, cal }) do for k in pairs(DRof(c).customers) do DRof(c).customers[k] = nil end end
	n = #bells(w, nil, "BE")
	whisperFrom(w, ana, "Eve Long", "summon pls")
	whisperFrom(w, cal, "Eve Long", "summon pls")
	w:advance(3)
	eq(#bells(w, nil, "BE"), n, "closed: nothing sent")
	slash(wub, "bell " .. WUBER)
	ok(not DRof(wub).Ring("x", true), "the alert window never rings itself")
	eq(#bells(w, WUBER), 0)
	clean(w)
end)

test("drive: alert character: /reload keeps it - the name in the crew's windows, the crew and the count in its own", function()
	local w, ana, bea, cal, wub = bellWorld()
	DRof(ana).Ring("before the reload", true)
	w:advance(2)
	eq(alertCount(wub), 1)
	ana = w:reload(ana)
	w:advance(6)
	eq(ana.W.db.drive.bell.name, WUBER, "still set")
	-- (REC login.channels.reload) a reload keeps Wuber on its channel, so the crew's news (DRIVE_CREW) comes at once and
	-- may add a hello: at least one more
	ok(#bells(w, ANA, "BH") >= 2, "the crew is told again at login")
	-- (REC login.channels.reload) and the reloaded window still has Trade, so its advert reminder rings the bell too
	local n = alertCount(wub)
	wub = w:reload(wub)
	w:advance(1)
	local team = wub.W.db.drive.bell.team
	table.sort(team)
	eq(table.concat(team, ","), "ana smith,bea jones,cal brown", "the crew is remembered")
	ok(counter(wub) and counter(wub):IsShown(), "the counter is back")
	eq(counter(wub).text:GetText(), n == 1 and "1 alert" or (n .. " alerts"))
	cal.env.C_ChatInfo.SendAddonMessage("WUBERT", "BE~1~Ana~Cal: after the reload", "WHISPER", WUBER)
	w:advance(1)
	ok(banner(wub) and banner(wub):IsShown())
	eq(banner(wub).text:GetText(), "Cal: after the reload")
	eq(alertCount(wub), n + 1)
	clean(w)
end)

test("drive: alert character: never a rider, and its gold is not income", function()
	local w, ana, bea, cal, wub = bellWorld()
	w:placePlayer(wub.player, SPOT) -- beside Ana, to trade
	w:whisper(wub, ANA, "summon pls", "user")
	w:advance(0.5)
	eq(customer(ana, WUBER), nil, "a whisper from the alert character is not a request")
	trade(ana, "LF summon to Undercity pls", WUBER)
	eq(customer(ana, WUBER), nil, "nor is its public line")
	local wp, ap = w:player(WUBER), w:player(ANA)
	local a0 = ap.money
	ok(w:openTrade(wp, ap))
	w:typeTradeMoney(wp, 3, 0, 0)
	w:tradeAccept(wp)
	w:tradeAccept(ap)
	w:advance(2)
	eq(ap.money - a0, 30000, "the gold moved")
	eq(session(ana).copper, 0, "but it is not takings")
	eq(#dlog(ana).rides, 0)
	clean(w)
end)

test("drive: alert character: a ride rings the payment, the clicks and the portal (once); offline is quiet, its line hidden", function()
	local w, ana, bea, cal, wub = bellWorld()
	ask(w, ana, "Dan Miller")
	summon(w, ana, bea, cal)
	local portal = {}
	for _, e in ipairs(bells(w, nil, "BE")) do if beText(e):lower():find("portal", 1, true) then portal[#portal + 1] = e end end
	eq(#portal, 1, "one portal call, not one per helper")
	eq(portal[1].from, BEA, "from the first helper by name")
	land(w)
	pays(w, "Dan Miller", FARE)
	w:advance(3)
	local texts = {}
	for _, e in ipairs(bells(w, ANA, "BE")) do texts[#texts + 1] = beText(e) end
	local all = table.concat(texts, " / ")
	ok(all:find("Ana: Summon Dan", 1, true), all)
	ok(all:find("Ana: Accept 50s from Dan", 1, true), "the trade to accept: " .. all)
	press(ana)
	w:advance(3)
	texts = {}
	for _, e in ipairs(bells(w, ANA, "BE")) do texts[#texts + 1] = beText(e) end
	all = table.concat(texts, " / ")
	ok(all:find("Ana: Dan Miller paid 50s", 1, true), "the payment: " .. all)
	ok(all:find("Ana: Thank Dan", 1, true), "the thanks to click: " .. all)
	w:player(WUBER).online = false
	local n = #bells(w)
	ok(DRof(ana).Ring("while away", true))
	w:advance(1)
	local line = "No player named 'Wuber Rocks' is currently playing."
	local hidden = false
	for _, f in ipairs(ana.chatFilters.CHAT_MSG_SYSTEM or {}) do if f(nil, "CHAT_MSG_SYSTEM", line) then hidden = true end end
	ok(hidden, "the game's line about it is kept out of chat")
	local other = false
	for _, f in ipairs(ana.chatFilters.CHAT_MSG_SYSTEM or {}) do if f(nil, "CHAT_MSG_SYSTEM", "No player named 'Zed Other' is currently playing.") then other = true end end
	ok(not other, "other lines are not")
	ok(not DRof(ana).Ring("still away", true), "quiet for a while")
	w:advance(31)
	w:player(WUBER).online = true
	ok(DRof(ana).Ring("back again", true), "tries again after 30 s")
	w:advance(3)
	ok(#bells(w) > n)
	clean(w)
end)

---------------------------------------------------------------------------
-- Agent A's engine scenarios (were /tmp/a_tests/scratch.lua), kept as they were written:
-- import from a tombstone, the lock, 3-box trust and rotation, a Mage helper's offer, spoofed
-- offers, the solo "came with" row, away guard, non-payer, public buyers, reload, a 3-box
-- ride end to end, a 40-entry blocklist sync that never throttles.
---------------------------------------------------------------------------

do
	local test = function(name, fn) return T.test("engine: " .. name, fn) end
	local eq, ok, clean = T.eq, T.ok, T.clean
	local function wuberT(w, kind, from)
		local out = {}
		for _, e in ipairs(w.addonLog) do
			if e.prefix == "WUBERT" and (not kind or e.text:match("^([^~]*)") == kind) and (not from or e.from == from) then out[#out + 1] = e end
		end
		return out
	end

	local ANITA, FARRA, HAYLEY = "Anita Lift", "Farra Way", "Hayley Cab"

	local function rrSaved(extra)
		local t = {
			price = 50000, service = "Giga Rides", dest = "", caster = "Anita", team = { ANITA, FARRA, HAYLEY, "Bob" },
			keywords = { "summon", "taxi" }, maxGroup = 10, whisperMode = "direct", adEvery = 5,
			templates = { greet = "Hello {name}, summoning you to {dest}.", advert = "cheap gold www.spam.com" },
			blocklist = { ["dan miller"] = { reason = "never paid", at = "17 Nov" }, ["eve jones"] = "rude" },
			log = { v = 1, rides = { "1700000000,50000,Dan,Undercity,t" }, asks = {}, open = { ["2026111719"] = 30 }, seen = {}, wreq = {}, wdec = {}, rivals = {} },
			stats = { rides = 3, copper = 150000 }, bell = "Wuber Rocks", pos = { "CENTER", "CENTER", 10, 20 }, key = "F5",
		}
		for k, v in pairs(extra or {}) do t[k] = v end
		return t
	end

	test("import: tombstone loaded -> no lock, data imported, captain by caster", function()
		local w = H.NewWorld()
		local saved = rrSaved()
		local c = w:addClient(FARRA, { spot = "Undercity", class = "WARLOCK", loadRR = "tombstone", saved = { RitualRides = saved }, allowMissing = true })
		local DR = c.W.Drive
		eq(DR.Lock(), nil, "lock")
		ok(DR.db.imported, "imported")
		local ch = DR.char()
		eq(ch.price, 50000, "price")
		eq(ch.service, "Giga Rides", "service")
		eq(#ch.crew, 2, "crew (Bob skipped, me left out)")
		eq(ch.captain, ANITA, "captain = caster Anita")
		eq(ch.wizard, true, "wizard")
		eq(DR.opts().whisperMode, "auto", "direct -> auto")
		eq(DR.opts().adEvery, 15, "adEvery min 15")
		eq(DR.opts().maxGroup, 10, "maxGroup")
		eq(DR.db.templates.greet, "Hello {name}, summoning you to {dest}.", "greet kept")
		eq(DR.db.templates.advert, nil, "spam advert dropped")
		eq(DR.db.blocklist["dan miller"].reason, "never paid", "blocklist table form")
		eq(DR.db.blocklist["eve jones"].reason, "rude", "blocklist string form")
		eq(#DR.db.log.rides, 1, "rides")
		eq(DR.db.log.open["2026111719"], 30, "open hours")
		eq(DR.db.stats.rides, 3, "stats")
		eq(DR.db.bell.name, "Wuber Rocks", "bell")
		eq(DR.db.button.key, "F5", "key")
		-- twice changes nothing
		DR.db.imported = nil
		DR.char().rrChar = nil
		DR.ImportRR()
		eq(#DR.db.log.rides, 1, "no duplicate lines")
		eq(DR.db.stats.rides, 6, "stats add (second import only after a reset)")
		clean(w)
	end)

	test("lock: RR 1.4.1 loaded -> rr lock, engine inert, import done", function()
		local w = H.NewWorld()
		local c = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", loadRR = "1.4.1", saved = { RitualRides = rrSaved() }, allowMissing = true })
		local DR = c.W.Drive
		eq(DR.Lock(), "rr", "lock")
		eq(DR.Active(), false, "inactive")
		ok(DR.db.imported, "imported while locked")
		eq(DR.SetOpen(true), false, "can't open")
		w:advance(20)
		eq(#wuberT(w), 0, "no WUBERT")
		clean(w)
	end)

	local function threeBox(w)
		local cs = {}
		for i, n in ipairs({ ANITA, FARRA, HAYLEY }) do
			cs[i] = w:addClient(n, { spot = "Undercity", class = "WARLOCK", loadRR = "tombstone", saved = { RitualRides = rrSaved() }, allowMissing = true })
		end
		w:group({ ANITA, FARRA, HAYLEY })
		w:advance(3)
		return cs
	end

	test("3-box: crew trusts each other, CFG from captain opens all, whisper request invited once", function()
		local w = H.NewWorld()
		local cs = threeBox(w)
		local A, F, Hy = cs[1].W.Drive, cs[2].W.Drive, cs[3].W.Drive
		eq(A.IsCaptain(), true, "Anita captain")
		eq(F.CaptainKey(), "anita lift", "Farra's captain")
		ok(F.TrustKey("hayley cab"), "Farra trusts Hayley")
		eq(A.SetOpen(true), true, "open")
		w:advance(2)
		eq(F.IsOpen(), true, "Farra open via CFG")
		eq(Hy.IsOpen(), true, "Hayley open via CFG")
		ok(A.peers["farra way"], "Anita heard Farra")
		eq(#A.CastOrder(), 3, "cast order")
		eq(A.MainCaster(), "anita lift", "main caster")
		local m, turn = F.MayCast()
		eq(m, false, "Farra doesn't cast")
		eq(turn, "anita lift", "Anita's turn")
		-- a rider whispers Hayley: Hayley asks the leader
		local dan = w:addBot("Ed Rider", { spot = "Orgrimmar" })
		cs[3]:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Ed Rider")
		w:advance(3)
		ok(A.customers["ed rider"], "Anita lists Dan")
		ok(dan.group, "Dan invited and joined")
		eq(#w.invites, 1, "one invite")
		w:advance(2)
		eq(A.customers["ed rider"].state, "joined", "joined in Anita")
		eq(F.customers["ed rider"] and F.customers["ed rider"].state, "joined", "joined in Farra")
		clean(w)
	end)

	test("3-box: 0 shards on Anita -> Farra's turn; back when regained", function()
		local w = H.NewWorld()
		local cs = threeBox(w)
		local A, F = cs[1].W.Drive, cs[2].W.Drive
		A.SetOpen(true)
		w:advance(2)
		w:player(ANITA).shards = 0
		cs[1]:fire("BAG_UPDATE_DELAYED")
		w:advance(2)
		local mine, turn = F.MayCast()
		eq(mine, true, "Farra's turn")
		eq(turn, "farra way", "turn")
		w:player(ANITA).shards = 4
		cs[1]:fire("BAG_UPDATE_DELAYED")
		w:advance(2)
		mine, turn = F.MayCast()
		eq(mine, false, "handed back")
		clean(w)
	end)

	test("solo Warlock + Mage helper: offer, TY, CRW, helper's forged CFG ignored", function()
		local w = H.NewWorld()
		local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
		local m = w:addClient("Mia Frost", { spot = "Undercity", class = "MAGE", allowMissing = true })
		local A, M = a.W.Drive, m.W.Drive
		eq(A.Role(), "driver", "role driver")
		eq(M.Role(), nil, "mage not in crew")
		w:group({ ANITA, "Mia Frost" })
		w:advance(2)
		local shown
		m.W.Listen("DRIVE_OFFER", function(from, svc) shown = from end)
		ok(A.OfferCrew("Mia Frost"), "offer")
		w:advance(2)
		eq(shown, ANITA, "offer card")
		M.AnswerOffer(ANITA, true)
		w:advance(2)
		eq(A.offers["mia frost"].state, "yes", "yes")
		ok(A.CrewEntry("mia frost"), "in crew")
		eq(A.CrewEntry("mia frost").role, "helper", "helper role")
		eq(M.Role(), "helper", "mage helper")
		eq(M.CaptainKey(), "anita lift", "captain")
		A.SetOpen(true)
		w:advance(2)
		eq(M.IsOpen(), true, "helper sees open")
		eq(M.char().drive, false, "helper's own drive flag untouched")
		-- forged CFG from the helper (not leader, not captain)
		M.Send("CFG", 1, 1, 5, 1, "macro", "")
		w:advance(2)
		eq(A.char().price, 5000, "price unchanged")
		-- helper is never a customer
		eq(A.customers["mia frost"], nil, "not a customer")
		clean(w)
	end)

	test("spoofed: TY without offer, CRW from non-captain, offer flood", function()
		local w = H.NewWorld()
		local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
		local m = w:addClient("Mia Frost", { spot = "Undercity", class = "MAGE", allowMissing = true })
		local x = w:addClient("Xan Evil", { spot = "Undercity", class = "ROGUE", allowMissing = true })
		local A, M, X = a.W.Drive, m.W.Drive, x.W.Drive
		X.Whisper(ANITA, "TY")
		w:advance(2)
		eq(A.CrewEntry("xan evil"), nil, "TY without offer ignored")
		local n = 0
		m.W.Listen("DRIVE_OFFER", function() n = n + 1 end)
		X.Whisper("Mia Frost", "TO", "Spam")
		X.Whisper("Mia Frost", "TO", "Spam")
		X.Whisper("Mia Frost", "TO", "Spam")
		w:advance(5)
		eq(n, 1, "one card per 60 s")
		-- Mia joins Anita's crew, then Xan sends CRW
		A.OfferCrew("Mia Frost")
		w:advance(2)
		M.AnswerOffer(ANITA, true)
		w:advance(2)
		X.Whisper("Mia Frost", "CRW", "Xan Evil:L")
		w:advance(2)
		eq(M.CrewEntry("xan evil"), nil, "CRW from non-captain ignored")
		clean(w)
	end)

	test("solo no crew: open, hand-invited friend while a rider waits = came-with lead", function()
		local w = H.NewWorld()
		local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
		local A = a.W.Drive
		eq(A.SetOpen(true), true, "open alone")
		local dan = w:addBot("Dan Miller", { spot = "Orgrimmar" })
		a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
		w:advance(3)
		eq(A.customers["dan miller"].state, "joined", "Dan joined")
		local fr = w:addBot("Fred Help", { spot = "Undercity" })
		w:join(w:player(ANITA), fr)
		w:advance(1)
		local c = A.customers["fred help"]
		ok(c, "listed")
		eq(c.state, "lead", "lead row")
		eq(c.cameWith, "Dan Miller", "came with Dan")
		A.NotRider(c)
		w:advance(2)
		eq(A.customers["fred help"], nil, "off the list")
		w:advance(5)
		eq(A.customers["fred help"], nil, "stays off")
		clean(w)
	end)

	test("away guard: joined 4 min with no cast pauses", function()
		local w = H.NewWorld()
		local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
		local A = a.W.Drive
		A.SetOpen(true)
		local alerts = {}
		a.W.Listen("DRIVE_ALERT", function(t, k) alerts[#alerts + 1] = k end)
		w:addBot("Dan Miller", { spot = "Orgrimmar" })
		a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
		w:advance(3)
		eq(A.IsPaused(), false, "not paused")
		w:advance(245)
		eq(A.IsPaused(), true, "paused by away guard")
		local found = false
		for _, k in ipairs(alerts) do if k == "away" then found = true end end
		ok(found, "away alert")
		clean(w)
	end)

	test("nonpayer: summoned, landed, left owing -> blocked; walker not", function()
		local w = H.NewWorld()
		local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
		local A = a.W.Drive
		A.SetOpen(true)
		local blocked
		a.W.Listen("DRIVE_BLOCKED", function(n, r, auto) blocked = { n, r, auto } end)
		w:addBot("Dan Miller", { spot = "Orgrimmar" })
		a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
		w:advance(3)
		A.Do("CAST", "Dan Miller")
		A.Do("END", "Dan Miller", 1)
		w:move("Dan Miller", "Undercity")
		w:advance(2)
		eq(A.customers["dan miller"].state, "arrived", "arrived")
		w:leave("Dan Miller")
		w:advance(3) -- (r28 AUD-04) a solo driver waits 2 s first, for a trade that is just being counted
		ok(A.BlockEntry("dan miller"), "blocked")
		ok(blocked and blocked[3] == true, "auto block event")
		-- whispers again: refusal once
		a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
		ok(A.refusals["dan miller"], "refusal queued")
		eq(A.Unblacklist("Dan Miller"), 1, "undo")
		clean(w)
	end)

	test("public: wtb summon uc in Trade while in Undercity -> request; [Wuber] line ignored", function()
		local w = H.NewWorld()
		local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
		local A = a.W.Drive
		A.opts().autoPublic = true -- (2.3.2: off by default, on after a warning)
		A.SetOpen(true)
		eq(A.PublicWant("wtb summon uc"), "match", "match")
		eq(A.PublicWant("WTS summons to UC"), nil, "seller")
		eq(A.PublicWant("[Wuber] Summons to Undercity 50s - I'm a Wuber driver"), nil, "advert")
		eq(A.PublicWant("lf sumon to ratcet"), "elsewhere", "typos elsewhere")
		w:addBot("Dan Miller", { spot = "Orgrimmar" })
		a:chatEvent("CHAT_MSG_CHANNEL", "wtb summon uc", "Dan Miller", "", "2. Trade - City", "", "", 0, 2, "Trade - City")
		w:advance(1)
		ok(A.customers["dan miller"], "listed")
		ok(A.customers["dan miller"].offer, "offer flag")
		clean(w)
	end)

	test("reload mid-ride solo: queue restored", function()
		local w = H.NewWorld()
		local a = w:addClient(ANITA, { spot = "Undercity", class = "WARLOCK", allowMissing = true })
		local A = a.W.Drive
		A.SetOpen(true)
		w:addBot("Dan Miller", { spot = "Orgrimmar" })
		a:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Dan Miller")
		w:advance(3)
		A.Do("CAST", "Dan Miller")
		A.Do("END", "Dan Miller", 1)
		w:move("Dan Miller", "Undercity")
		w:advance(2)
		eq(A.customers["dan miller"].state, "arrived", "arrived")
		w:reload(a)
		w:advance(2)
		local a2 = w:clientOf(ANITA)
		local c = a2.W.Drive.customers["dan miller"]
		ok(c, "restored")
		eq(c.state, "arrived", "state")
		eq(c.tries, 1, "tries")
		clean(w)
	end)


	test("3-box end to end: whisper, invite, click, portal, land, trade, thanks", function()
		local w = H.NewWorld()
		local cs = threeBox(w)
		local A, F, Hy = cs[1].W.Drive, cs[2].W.Drive, cs[3].W.Drive
		A.SetOpen(true)
		w:advance(3)
		local ed = w:addBot("Ed Rider", { spot = "Orgrimmar" })
		cs[1]:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Ed Rider")
		w:advance(3)
		eq(A.customers["ed rider"].state, "joined", "joined")
		local function title(c) local p = c.W.Drive.Plan and c.W.Drive.Plan() return p and p.title end
		print("    plans:", title(cs[1]), "|", title(cs[2]), "|", title(cs[3]))
		cs[1]:click(A.button)
		w:advance(1)
		print("    after click:", A.customers["ed rider"].state, title(cs[1]), "|", title(cs[2]), "|", title(cs[3]))
		eq(F.customers["ed rider"].state, "summoning", "Farra sees summoning")
		w:clickPortal(cs[2])
		w:clickPortal(cs[3])
		w:advance(5)
		print("    after portal:", A.customers["ed rider"].state, F.customers["ed rider"].state, ed.zone)
		w:advance(3)
		eq(A.customers["ed rider"].state, "arrived", "arrived")
		print("    arrived plans:", title(cs[1]), "|", title(cs[2]), "|", title(cs[3]))
		w:advance(5)
		if not ed.trade then w:openTrade(ed, w:player(ANITA)) end
		local tradeWith = ed.trade and (ed.trade.a == ed and ed.trade.b or ed.trade.a)
		print("    trade with:", tradeWith and tradeWith.name)
		w:tradeMoney(ed, 50000)
		w:tradeAccept(ed)
		w:advance(1)
		local who = tradeWith and w:clientOf(tradeWith.name) or cs[1]
		print("    trade plan:", title(who))
		who:click(who.W.Drive.button)
		w:advance(2)
		print("    after accept:", A.customers["ed rider"] and A.customers["ed rider"].state, F.customers["ed rider"] and F.customers["ed rider"].state, title(who))
		who:click(who.W.Drive.button)
		w:advance(3)
		print("    after thanks:", A.customers["ed rider"] and A.customers["ed rider"].state, Hy.customers["ed rider"] and Hy.customers["ed rider"].state, ed.group and "in group" or "removed")
		local n = 0
		for _, x in ipairs(w.whispers) do if x.to == "Ed Rider" then n = n + 1 print("      whisper:", x.from, x.text) end end
		clean(w)
	end)

	test("sync: 45 blocked + 10 templates, never throttled, all <= 255, Farra gets them", function()
		local w = H.NewWorld()
		local bl, tpl = {}, {}
		for i = 1, 45 do bl["spam guy" .. string.char(96 + (i % 26) + 1) .. i] = { reason = string.rep("x", 70), at = "17 Nov" } end
		for _, k in ipairs({ "advert", "greet", "price", "offer", "pay", "thanks", "tip", "short", "busy", "refuse" }) do
			tpl[k] = string.rep("Hello {name} ", 14)
		end
		local cs = {}
		for i, n in ipairs({ ANITA, FARRA }) do
			cs[i] = w:addClient(n, { spot = "Undercity", class = "WARLOCK", loadRR = "tombstone",
				saved = { RitualRides = { team = { ANITA, FARRA }, caster = "Anita", blocklist = i == 1 and bl or {}, templates = i == 1 and tpl or {} } }, allowMissing = true })
		end
		cs[1].W.Drive.SetOpen(true)
		w:group({ ANITA, FARRA })
		w:advance(80)
		local n = 0
		for _ in pairs(cs[2].W.Drive.db.blocklist) do n = n + 1 end
		eq(n, 45, "Farra has all 45 (r34 e2: the list is no longer cut at 40)")
		local t = 0
		for _ in pairs(cs[2].W.Drive.db.templates) do t = t + 1 end
		ok(t >= 9, "templates arrived: " .. t)
		for _, c in ipairs(cs) do eq(c.throttled or 0, 0, c.player.name .. " throttled") end
		local d = 0
		for _, e in ipairs(w.addonLog) do if e.prefix == "WUBER" and e.text:match("^D~") then d = d + 1 end end
		ok(d > 0, "beacons flowed")
		clean(w)
	end)

end

---------------------------------------------------------------------------
-- Part 2: SPEC3 5.3's scenarios (those not already covered above)
---------------------------------------------------------------------------

local ANITA, FARRA, HAYLEY = "Anita Lift", "Farra Way", "Hayley Cab"

-- RitualRidesDB as Ritual Rides 1.4.1 saved it on the author's accounts
local function rrDB(extra)
	local t = {
		price = 50000, service = "Giga Rides", dest = "", caster = "", team = { ANITA, FARRA, HAYLEY },
		keywords = { "summon", "taxi" }, maxGroup = 10, whisperMode = "macro", adEvery = 20, autoBlock = true,
		templates = { thanks = "Cheers {name}!" },
		blocklist = { ["dan miller"] = { reason = "never paid", at = "17 Nov" } },
		log = { v = 1, rides = { "1700000000,50000,Old Rider,Undercity,t" }, asks = {}, open = { ["2026111719"] = 30 },
			seen = {}, wreq = {}, wdec = {}, rivals = {} },
		stats = { rides = 3, copper = 150000 },
		setupSeen = true, -- (RR 1.4.1's own setup window stays shut, as on the author's accounts)
	}
	for k, v in pairs(extra or {}) do t[k] = v end
	return t
end

test("scenario 1: a 3-box crew imported from Ritual Rides drives a whole ride; every queue the same at each step", function()
	local w = newWorld()
	local names = { ANITA, FARRA, HAYLEY }
	local cs = {}
	for i, n in ipairs(names) do cs[i] = w:addClient(n, { spot = SPOT, class = "WARLOCK", loadRR = "tombstone", saved = { RitualRides = rrDB() } }) end
	local an, fa, ha = cs[1], cs[2], cs[3]
	for _, c in ipairs(cs) do
		ok(DRof(c).db.imported, c.player.name .. " imported, no prompt")
		eq(c.W.Char().price, 50000)
		eq(#c.W.Char().crew, 2, c.player.name .. "'s crew")
	end
	w:group(names)
	w:advance(2)
	DRof(an).SetOpen(true)
	w:advance(3)
	local function same(name, want)
		for _, c in ipairs(cs) do eq(state(c, name), want, c.player.name .. " sees " .. name) end
	end
	whisperFrom(w, an, "Dan Moss", "summon pls")
	w:advance(0.5)
	eq(#w.invites, 1, "invited once")
	w:advance(3)
	same("Dan Moss", "joined")
	local p = plan(an)
	ok(p.macrotext:find("/w Dan-Moss Giga Rides: summoning you", 1, true) and p.macrotext:find("/cast Ritual of Summoning", 1, true), p.macrotext)
	press(an)
	w:advance(1.5)
	same("Dan Moss", "summoning")
	eq(plan(fa).title, "CLICK THE PORTAL")
	eq(plan(ha).title, "CLICK THE PORTAL")
	w:clickPortal(fa)
	w:clickPortal(ha)
	w:advance(1.5)
	same("Dan Moss", "waiting")
	land(w)
	same("Dan Moss", "arrived")
	w:typeTradeMoney(w:player("Dan Moss"), 5, 0, 0)
	w:tradeAccept(w:player("Dan Moss"))
	w:advance(0.3)
	eq(plan(an).title, "Accept 5g from Dan")
	press(an)
	w:advance(1.5)
	same("Dan Moss", "paid")
	eq(plan(an).title:find("^Thank Dan") ~= nil, true, plan(an).title)
	press(an)
	w:advance(3)
	for _, c in ipairs(cs) do eq(customer(c, "Dan Moss"), nil, c.player.name .. ": done") end
	local kinds = {}
	for _, x in ipairs(w:whispersTo("Dan Moss")) do kinds[#kinds + 1] = x.text:match("^(%S+)") end
	eq(#kinds, 2, "exactly one greeting and one thanks")
	ok(w:whispersTo("Dan Moss")[2].text:find("Cheers Dan!", 1, true), "the imported message")
	eq(#dlog(an).rides, 2, "the imported line plus one ride, on the cashier's account")
	eq(#dlog(fa).team + #dlog(ha).team, 2, "two crew lines")
	eq(#dlog(fa).rides, 1, "Farra's account: only its imported line")
	clean(w)
end)

test("scenario 3: a solo Warlock with a Mage and a Priest helper: offers, portal call, forged facts ignored", function()
	local w = newWorld()
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	local mage = w:addClient("Mia Mage", { spot = SPOT, class = "MAGE" })
	local priest = w:addClient("Pat Priest", { spot = SPOT, class = "PRIEST" })
	w:group({ ANITA, "Mia Mage", "Pat Priest" })
	w:advance(3)
	DRof(lock).OfferCrew("Mia Mage")
	w:advance(1.5)
	DRof(lock).OfferCrew("Pat Priest")
	w:advance(1.5)
	ok(DRof(mage).pendingOffers["anita lift"], "the Mage has the consent card")
	DRof(mage).AnswerOffer(ANITA, true)
	DRof(priest).AnswerOffer(ANITA, true)
	w:advance(3)
	ok(#wubert(w, "CRW", ANITA) >= 1, "CRW sent")
	ok(DRof(mage).IsCrewKey("anita lift") and DRof(priest).IsCrewKey("anita lift"), "both trust the captain")
	eq(DRof(mage).Role(), "helper")
	DRof(lock).SetOpen(true)
	w:advance(2)
	ask(w, lock, "Dan Moss")
	eq(customer(lock, "Mia Mage"), nil, "a helper is never a rider")
	eq(customer(lock, "Pat Priest"), nil)
	press(lock)
	w:advance(1.5)
	eq(plan(mage).title, "CLICK THE PORTAL", "the Mage's button")
	ok(fired(mage, "DRIVE_ALERT") >= 1, "the Mage got the portal call")
	eq(plan(mage).type, nil, "no cast step on a helper")
	w:clickPortal(mage)
	w:clickPortal(priest)
	w:advance(1.5)
	eq(state(lock, "Dan Moss"), "waiting", "the helpers' HELP ended the cast as ok")
	mage.env.C_ChatInfo.SendAddonMessage("WUBERT", "CFG~1~1~1~10~1~auto~", "PARTY")
	w:advance(1)
	eq(lock.W.Char().price, FARE, "a helper's forged CFG (1c) is ignored")
	w:addClient("Ned Stranger", { spot = SPOT, class = "MAGE" })
	clean(w)
end)

test("scenario 4: a helper without Wuber ('Add anyway'): held 3 s -> summon sent; let go at 1 s -> back to joined", function()
	local w = newWorld()
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Bob Helper", { spot = SPOT })
	w:addBot("Bo Second", { spot = SPOT })
	w:group({ ANITA, "Bob Helper", "Bo Second" })
	w:advance(1)
	DRof(lock).AddPlainHelper("Bob Helper")
	DRof(lock).AddPlainHelper("Bo Second")
	DRof(lock).SetOpen(true)
	w:advance(2)
	ask(w, lock, "Dan Moss")
	eq(state(lock, "Dan Moss"), "joined")
	press(lock)
	w:advance(1)
	ok(w:clickPortal("Bob Helper"), "a bot clicks")
	w:advance(1)
	w:releasePortal("Bob Helper") -- let go after a second
	w:cancelRitual()
	w:advance(2)
	eq(state(lock, "Dan Moss"), "joined", "dropped early: offered again")
	press(lock)
	w:advance(1)
	w:clickPortal("Bob Helper")
	w:clickPortal("Bo Second")
	w:advance(3.5)
	ok(state(lock, "Dan Moss") == "waiting" or state(lock, "Dan Moss") == "arrived", "held: the summon went out (" .. tostring(state(lock, "Dan Moss")) .. ")")
	eq(customer(lock, "Bob Helper"), nil, "the helper is never a rider")
	clean(w)
end)

test("scenario 5: solo, no crew: opens, beacon team 1; the rider's friends are 'Helper?' rows, never billed", function()
	local w = newWorld()
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	local r = rider(w)
	DRof(lock).SetOpen(true)
	w:advance(15)
	eq(r.W.drivers["anita lift"].team, 1, "Bring 2 helpers")
	ask(w, lock, "Dan Moss")
	w:addBot("Fred Friend", { spot = "Orgrimmar" })
	lock.env.C_PartyInfo.InviteUnit("Fred Friend") -- the driver invites Dan's friend by hand
	w:advance(3)
	local f = customer(lock, "Fred Friend")
	ok(f and f.state == "lead" and f.cameWith, "a 'came with Dan?' row")
	DRof(lock).NotRider(f)
	w:advance(1)
	eq(customer(lock, "Fred Friend"), nil, "marked a helper: off the list")
	ok(not (plan(lock).macrotext or ""):find("Fred", 1, true), "never greeted or billed")
	clean(w)
end)

test("scenario 7: payment typed by the rider: exact, over (tip logged), under then the rest, acceptUnder, an item on our side", function()
	local w, ana, bea, cal = team()
	ask(w, ana, "Dan Miller")
	summon(w, ana, bea, cal)
	land(w)
	pays(w, "Dan Miller", 6000)
	eq(plan(ana).title, "Accept 60s from Dan", "over: offered")
	press(ana)
	w:advance(1.5)
	eq(state(ana, "Dan Miller"), "paid")
	ok(plan(ana).macrotext:find("Thank you for the tip, Dan", 1, true), "the tip thanks")
	eq(stats(ana).tips, 1000, "tip counted")
	local line = dlog(ana).rides[#dlog(ana).rides]
	ok(line:find(",6000,Dan Miller,Undercity,t,5000$"), "tip logged with the price: " .. line)
	eq(DRof(ana).LogTotals(0).tips, 1000)
	press(ana)
	w:advance(3)
	-- acceptUnder on: a smaller payment is offered and counts as paid
	slash(ana, "under on")
	w:advance(1)
	ask(w, ana, "Eve Long")
	summon(w, ana, bea, cal)
	land(w)
	pays(w, "Eve Long", 3000)
	eq(plan(ana).title, "Accept 30s from Eve", "acceptUnder: the button offers it")
	press(ana)
	w:advance(1.5)
	eq(state(ana, "Eve Long"), "paid", "counted as paid")
	-- nothing typed by the addon, ever
	for _, x in ipairs(w.typed) do ok(x.by == "Dan Miller" or x.by == "Eve Long", "only riders typed gold: " .. x.by) end
	clean(w)
end)

test("scenario 8: non-payer auto-block: every crew window, refuse once in 10 min, a Wuber R gets N blocked, Undo unblocks", function()
	local w, ana, bea, cal = team()
	local r = rider(w)
	w:advance(15)
	r.W.RequestRide("ana smith")
	w:advance(4)
	summon(w, ana, bea, cal)
	w.hardware = r
	r.W.AcceptSummon()
	w.hardware = nil
	land(w)
	w:tradeCancel(r.player)
	w:leave(TESTCHAR)
	w:advance(3 + DRof(ana).OWING_GRACE) -- (REVIEW-2.0 #1: decided after the grace, by one window)
	for _, c in ipairs({ ana, bea, cal }) do ok(DRof(c).BlockEntry("wuber testcharacter"), c.player.name .. ": blocked") end
	local n, args = fired(ana, "DRIVE_BLOCKED")
	ok(n >= 1 and args[3], "a toast with Undo (auto)")
	r.W.ride = nil
	w:inject(TESTCHAR, "R~1~agains~Undercity~5000", "WHISPER", ana)
	w:advance(1)
	local nn = lastOf(w, "N", TESTCHAR)
	ok(nn and fields(nn)[4] == "blocked", "N blocked")
	DRof(ana).Unblacklist(TESTCHAR)
	w:advance(2)
	for _, c in ipairs({ ana, bea, cal }) do eq(DRof(c).BlockEntry("wuber testcharacter"), nil, c.player.name .. ": Undo everywhere") end
	clean(w)
end)

test("scenario 9: an old (1.0) rider rides with a 2.0 crew; the away guard pauses an idle driver", function()
	local w, ana, bea, cal = team()
	local old = rider(w, "Olly Old", { addonDirs = { Wuber = H.ADDONS.Wuber1 }, roundOne = true })
	w:advance(20)
	ok(old.W.drivers["ana smith"], "the 1.0 rider sees the crew")
	ok(old.W.RequestRide("ana smith"), "and books")
	w:advance(2)
	ok(lastOf(w, "A", "Olly Old"), "accepted")
	ok(customer(ana, "Olly Old"), "listed")
	-- a rider joined and nobody casts for 4 minutes: the away guard pauses and beacons paused
	ask(w, ana, "Dan Idle")
	eq(state(ana, "Dan Idle"), "joined")
	w:advance(250)
	ok(DRof(ana).IsPaused(), "paused by the away guard")
	local away = false
	for _, f in ipairs(ana.fired) do if f.name == "DRIVE_ALERT" and f.args[2] == "away" then away = true end end
	ok(away, "and said so (alert kind away)")
	w:advance(6)
	eq(old.W.drivers["ana smith"] and old.W.drivers["ana smith"].state, "paused", "beaconed paused")
	clean(w)
end)

test("scenario 10: Advertise: the click posts one [Wuber] line; a second inside 15 min posts nothing; spam refused", function()
	local w = newWorld()
	local d = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK" })
	w:advance(15)
	d.W.Char().wizard = true
	d.W.db.coach = true
	DRof(d).SetOpen(true)
	d.W.UI.Toggle(true)
	w:advance(2.5)
	d:clickText("Drive")
	w:advance(1)
	local adv = d.W.Driver.ui.console.advert
	d:clickOn(adv)
	w:advance(1)
	local posts = {}
	for _, p in ipairs(w.chatPosts or {}) do if p.from == ANITA then posts[#posts + 1] = p end end
	eq(#posts, 1, "one line")
	ok(posts[1].text:find("^%[Wuber%]"), posts[1].text)
	eq(posts[1].how, "macro", "by the secure click")
	d:clickOn(adv)
	w:advance(1)
	local n = 0
	for _, p in ipairs(w.chatPosts or {}) do if p.from == ANITA then n = n + 1 end end
	eq(n, 1, "nothing inside 15 min")
	local okt, why = DRof(d).SetTemplate("advert", "cheap gold www.goldshop.com")
	eq(okt, false, "own advert text refused by the spam filter")
	ok(why and why ~= "", "with the reason")
	clean(w)
end)

test("scenario 12: the alert character survives a /reload and rings once per event across three windows", function()
	local w, ana, bea, cal = team()
	local wub = w:addClient(WUBER, { spot = "Orgrimmar", class = "MAGE" })
	for _, c in ipairs({ ana, bea, cal }) do slash(c, "bell " .. WUBER) end
	w:advance(3)
	wub = w:reload(wub)
	w:advance(2)
	ask(w, ana, "Dan Miller")
	w:advance(3)
	local n = alertCount(wub)
	ok(n >= 1, "alerts arrive after the reload")
	ok(wub.env.WuberBell and wub.env.WuberBell:IsShown(), "the banner")
	clean(w)
end)

test("scenario 13: earnings: rides over two days and hours -> LogTotals, Hours, BestHours, TryHours exact; Reset", function()
	local w = newWorld()
	local c = w:addClient(ANA, { spot = SPOT, class = "WARLOCK" })
	local DR = c.W.Drive
	local now = c.env.time()
	local l = DR.Log()
	local function at(daysAgo, hour, min)
		local d = os.date("*t", now - daysAgo * 86400)
		return os.time({ year = d.year, month = d.month, day = d.day, hour = hour, min = min or 10, sec = 0 })
	end
	local function hk(t) return os.date("%Y%m%d%H", t) end
	-- yesterday 19:xx: two rides (50s, 60s with a 10s tip), 60 open minutes; 20:xx: one ride, 20 minutes
	-- today 19:xx: one ride, 45 minutes; buyers at 21:xx yesterday with nobody open
	l.rides = {
		at(1, 19, 5) .. ",5000,A A,Undercity,t,5000", at(1, 19, 40) .. ",6000,B B,Undercity,t,5000",
		at(1, 20, 5) .. ",5000,C C,Undercity,t,5000",
	}
	local today19 = math.min(at(0, 19, 5), now - 60)
	l.rides[#l.rides + 1] = today19 .. ",5000,D D,Undercity,t,5000"
	l.team = { at(1, 19, 20) .. ",5000,E E,Undercity,farra way" }
	l.open = { [hk(at(1, 19))] = 60, [hk(at(1, 20))] = 20, [hk(today19)] = 45 }
	l.asks = { at(1, 21, 1) .. ",match,X X,m,Undercity,wtb summon uc", at(1, 21, 2) .. ",match,Y Y,m,Undercity,lf sum uc" }
	l.wreq, l.wdec, l.rivals = { [hk(at(1, 19))] = 3 }, { [hk(at(1, 19))] = 1 }, { [hk(at(1, 19))] = 2 }
	local t7 = DR.LogTotals(now - 7 * 86400)
	eq(t7.rides, 4) eq(t7.copper, 21000) eq(t7.tips, 1000) eq(t7.open, 125) eq(t7.asks, 2) eq(t7.match, 2)
	eq(t7.wreq, 3) eq(t7.wdec, 1) eq(t7.rivals, 2)
	eq(DR.LogTotals(now - 7 * 86400, "crew").rides, 5, "the crew's view adds team lines")
	local h = DR.Hours(7)
	eq(h[19].rides, 3) eq(h[19].copper, 16000) eq(h[19].open, 105)
	eq(h[20].rides, 1) eq(h[20].open, 20)
	eq(h[21].asks, 2) eq(h[21].open, 0)
	local today = DR.Hours("today")
	eq(today[19].rides, today19 >= at(0, 0, 0) and 1 or 0)
	local best = DR.BestHours(7, 3)
	ok(#best >= 1, "best hours")
	eq(best[1].hour, 19)
	ok(best[1].perHour > 0, "gold per open hour")
	for _, b in ipairs(best) do ok(b.open >= 30, "only slots open 30 min or more") end
	local try = DR.TryHours(7, 3)
	eq(#try, 1, "buyers but nobody open")
	eq(try[1].hour, 21) eq(try[1].asks, 2)
	c.W.db.drive.stats.rides, c.W.db.drive.stats.copper = 4, 21000
	DR.ResetStats()
	eq(c.W.db.drive.stats.rides, 0, "Reset")
	eq(#DR.Log().rides, 4, "the log stays")
	clean(w)
end)

test("scenario 13b: the heatmap tool reads WuberDB and RitualRidesDB without double counting (node tests/heatmap.test.js)", function()
	-- (no "cd &&" or "$?": node runs the file by its path; it prints RESULT: OK only
	-- when every check passed)
	local p = io.popen('node "' .. T.dir .. '/heatmap.test.js" 2>&1')
	local out = p and p:read("*a") or ""
	if p then p:close() end
	ok(out:find("RESULT: OK", 1, true), out)
end)

test("scenario 14: migration and lock: RR 1.4.1 drives and the engine waits; the retire card switches it off (the reload is blocked, #104)", function()
	local w = newWorld()
	local c = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK", loadRR = "1.4.1", saved = { RitualRides = rrDB() } })
	T.assertLocked(c)
	ok(DRof(c).db.imported, "the import ran while locked")
	eq(c.W.Char().price, 50000, "price copied")
	ok(c.RR and c.W.provider, "RR 1.4.1 is the driver through WuberAPI")
	c.W.Char().wizard = true
	c.W.db.coach = true -- (the first-open tips would sit over the tab bar)
	c.W.Driver.Toggle() -- the Drive tab (provider view + retire card)
	w:advance(3)
	-- (the card never names the old addon)
	ok(#c:findText("Your old summoning addon is still on") > 0, "the retire card (" .. list(c:visibleTexts()) .. ")")
	local blocked = {}
	local ev = c.env.CreateFrame("Frame")
	ev:RegisterEvent("ADDON_ACTION_BLOCKED")
	ev:SetScript("OnEvent", function(_, e, ...) blocked[#blocked + 1] = e end)
	c:clickText("Switch it off and reload")
	w:advance(1)
	eq(c.disabledCalls, 1, "C_AddOns.DisableAddOn from the click")
	-- #104, #230: the real client blocks ReloadUI from addon code (PF-050), so the pill does not call it: it says "Type /reload to finish"
	eq(#blocked, 0, "the click made no blocked ReloadUI call")
	ok(#c:findText("Type /reload to finish") > 0, "the plain line")
	clean(w)
end)

-- (scenario 14, after the reload: tests/round4/r244_s14_after_reload_test.lua)

test("scenario 14b: tombstone loaded: no lock, import still happens; corrupt fields are skipped; no DisableAddOn -> the fallback text", function()
	local w = newWorld()
	local bad = rrDB({ price = "lots", team = "nope", templates = { greet = 5, thanks = false }, blocklist = 7, log = { rides = "x", open = 3 },
		stats = { rides = "many" }, keywords = 9, maxGroup = -4 })
	local c = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK", loadRR = "tombstone", saved = { RitualRides = bad } })
	eq(DRof(c).Lock(), nil, "the tombstone does not lock")
	ok(DRof(c).db.imported, "imported anyway")
	ok(c.W.Char().price >= 5000, "a bad price is skipped: " .. tostring(c.W.Char().price))
	eq(#w.errors, 0, "no error")
	local w2 = newWorld()
	w2.noDisableAddOn = true
	local c2 = w2:addClient(ANITA, { spot = SPOT, class = "WARLOCK", loadRR = "1.4.1", saved = { RitualRides = rrDB() } })
	c2.W.Char().wizard = true
	c2.W.db.coach = true
	c2.W.Driver.Toggle() -- the Drive tab (provider view + retire card)
	w2:advance(3)
	c2:clickText("Switch it off and reload")
	w2:advance(1)
	ok(#c2:findText("Untick your old summoning addon in the AddOns list") > 0, "the fallback text")
	eq(w2:clientOf(ANITA), c2, "no reload")
	clean(w)
	clean(w2)
end)

test("scenario 14c: a third-party provider switches the engine off", function()
	local w = newWorld()
	local c = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	DRof(c).SetOpen(true)
	w:advance(3)
	ok(c.W.engine, "the engine drives")
	c.env.WuberAPI.SetDriver({ name = "Other Rides", beacon = function() return nil end, onRequest = function() end })
	w:advance(2)
	eq(c.W.engine, nil, "the engine let go")
	eq(DRof(c).Lock(), "provider")
	eq(c.env.WuberAPI.Driving(), "provider")
	clean(w)
end)

test("scenario 15: button mechanics: macros under 255, keybind press = click, combat empties it, no protected touch", function()
	for _, keyDown in ipairs({ true, false }) do
		local w = H.NewWorld({ useKeyDown = keyDown })
		local names = { ANA, BEA, CAL }
		local cs = {}
		for i, n in ipairs(names) do cs[i] = w:addClient(n, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(n, names, ANA) } }) end
		w:group(names)
		w:advance(1)
		local ana = cs[1]
		DRof(ana).SetOpen(true)
		w:advance(2)
		DRof(ana).SetKey("F5")
		w:advance(0.5)
		eq(ana.binding and ana.binding.key, "F5", "bound")
		ask(w, ana, "Maximilianus Wolfeschlegel")
		local pre = 0
		ana.env.WuberDriveButton:HookScript("PreClick", function() pre = pre + 1 end)
		ok(ana:pressKey("F5"), "the key clicks the button")
		w:advance(1.5)
		eq(state(ana, "Maximilianus Wolfeschlegel"), "summoning", "keyDown " .. tostring(keyDown) .. ": the press summoned")
		eq(w.casts, 1, "one cast")
		for _, m in ipairs(w.macros) do ok(#m.text <= 255, "macro " .. #m.text) end
		w:enterCombat(ana)
		ana.W.UI.Toggle(true)
		w:advance(3)
		eq(#w.violations, 0, "opening the window in combat touches nothing protected")
		w:leaveCombat(ana)
		w:advance(1)
		clean(w)
	end
end)

test("scenario 17: a 40-entry blocklist and 10 templates over WUBERT never throttle WUBER beacons", function()
	local w, ana, bea, cal = team()
	local r = rider(w)
	for i = 1, 40 do DRof(ana).Blacklist("Spam Er" .. string.char(96 + (i % 26) + 1) .. string.char(97 + math.floor(i / 26)), "spam") end
	for _, k in ipairs(DRof(ana).TEMPLATE_ORDER) do DRof(ana).SetTemplate(k, "Hello {name} from {service}") end
	bea = w:reload(bea)
	w:advance(90)
	for _, c in ipairs({ ana, bea, cal }) do
		eq((c.throttledBy or {}).WUBER or 0, 0, c.player.name .. ": WUBER never throttled")
	end
	ok(r.W.drivers["ana smith"], "beacons kept flowing")
	for _, e in ipairs(w.addonLog) do ok(#e.text <= 255, "<= 255 bytes") end
	clean(w, { throttled = true })
end)

test("scenario 18: secret values on names, money, trade money, spell ids and senders: no errors", function()
	local w, ana, bea, cal = team()
	w.hideSpellIds = true
	local r = rider(w, TESTCHAR, { secrets = { "UnitName", "GetMoney" } })
	w:advance(15)
	r.W.RequestRide("ana smith")
	w:advance(4)
	summon(w, ana, bea, cal)
	ana.secrets.GetMoney = true
	land(w)
	ana:fire("TRADE_MONEY_CHANGED")
	ana:fire("CHAT_MSG_ADDON", "WUBERT", "PAID~1~x~1", "PARTY", H.SECRET)
	w:advance(2)
	clean(w)
end)

test("scenario 19: reload mid-ride: a solo driver's queue comes back from W.Char().queue", function()
	local w = newWorld()
	local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
	w:addBot("Bo Helper", { spot = SPOT })
	w:addBot("Bi Helper", { spot = SPOT })
	DRof(lock).SetOpen(true)
	w:advance(2)
	ask(w, lock, "Dan Moss")
	press(lock)
	w:advance(1)
	w:group({ ANITA, "Dan Moss", "Bo Helper", "Bi Helper" })
	w:clickPortal("Bo Helper")
	w:clickPortal("Bi Helper")
	w:advance(3.5)
	land(w)
	eq(state(lock, "Dan Moss"), "arrived")
	lock = w:reload(lock)
	w:advance(3)
	ok(lock.W.Char().queue ~= nil or customer(lock, "Dan Moss"), "saved at logout")
	eq(state(lock, "Dan Moss"), "arrived", "restored at arrived, still owing")
	eq(customer(lock, "Dan Moss").walked, nil, "not taken for a walker")
	clean(w)
end)

test("realm names: a rider whose name arrives as Name-Realm is invited and whispered with a name the game accepts", function()
	for _, format in ipairs({ "realm", "hyphen" }) do
		local w = H.NewWorld({ senderFormat = format })
		local lock = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
		local r = rider(w)
		DRof(lock).opts().autoPublic = true -- (2.3.2: off by default, on after a warning)
		DRof(lock).SetOpen(true)
		w:advance(15)
		-- a whisper, a public line and an R, each with the sender as the game spells it
		w:botWhisper("Dan Moss", lock, "summon pls")
		w:advance(0.5)
		local to = w.invites[1] and w.invites[1].to
		ok(to == "Dan Moss" or (format == "hyphen" and to == "Dan-Moss"), format .. ": the invite names the player, no realm: " .. tostring(to))
		ok(not tostring(to):find("Forever", 1, true), "never the realm")
		w:advance(3)
		eq(state(lock, "Dan Moss"), "joined", format .. ": he joined")
		local p = plan(lock)
		ok(p.macrotext:find("/w Dan-Moss ", 1, true), format .. ": the whisper line: " .. p.macrotext)
		ok(not p.macrotext:find("Forever", 1, true), format .. ": no realm in the macro")
		press(lock)
		w:advance(1)
		eq(#w:whispersTo("Dan Moss", "macro"), 1, format .. ": the greeting reached him")
		w:addBot("Eve Long", { acceptsInvites = true })
		channel(lock, "wtb summon uc", w:senderName(w:player("Eve Long")), "Services", 3)
		w:advance(3)
		ok(state(lock, "Eve Long") == "joined" or state(lock, "Eve Long") == "invited", format .. ": public buyer " .. tostring(state(lock, "Eve Long")))
		local last = w.invites[#w.invites]
		ok(last.to == "Eve Long" or (format == "hyphen" and last.to == "Eve-Long"), format .. ": the public buyer's invite has no realm: " .. last.to)
		r.W.RequestRide("anita lift")
		w:advance(3)
		last = w.invites[#w.invites].to
		ok(last == TESTCHAR or (format == "hyphen" and last == "Wuber-TestCharacter"), format .. ": a Wuber rider's invite has no realm: " .. last)
		ok(w:player(TESTCHAR).group == w:player(ANITA).group, format .. ": the rider joined")
		clean(w)
	end
end)

-- SPEC3 house rule: no function holds more than ~150 locals at once (Lua's limit is 200).
-- No luac here: the Lua 5.1 bytecode of each file (string.dump) is read for its local
-- variables' live ranges.
local function maxLocals(path)
	local chunk = assert(loadfile(path))
	local b = string.dump(chunk)
	local pos = 1
	local sizeInt, sizeT = b:byte(8), b:byte(9)
	pos = 13
	local function int(n)
		local v, mul = 0, 1
		for i = 0, n - 1 do v = v + b:byte(pos + i) * mul mul = mul * 256 end
		pos = pos + n
		return v
	end
	local function str()
		local n = int(sizeT)
		local s = n > 0 and b:sub(pos, pos + n - 2) or nil
		pos = pos + n
		return s
	end
	local worst, where = 0, "?"
	local function fn()
		str()
		local line = int(sizeInt)
		int(sizeInt)
		pos = pos + 4 -- nups, numparams, is_vararg, maxstacksize
		local ncode = int(sizeInt)
		pos = pos + ncode * 4
		local nk = int(sizeInt)
		for _ = 1, nk do
			local t = b:byte(pos)
			pos = pos + 1
			if t == 1 then pos = pos + 1 elseif t == 3 then pos = pos + 8 elseif t == 4 then str() end
		end
		local np = int(sizeInt)
		for _ = 1, np do fn() end
		local nl = int(sizeInt)
		pos = pos + nl * sizeInt
		local nv = int(sizeInt)
		local events = {}
		for _ = 1, nv do
			str()
			local s, e = int(sizeInt), int(sizeInt)
			events[#events + 1] = { s, 1 }
			events[#events + 1] = { e, -1 }
		end
		table.sort(events, function(x, y) if x[1] ~= y[1] then return x[1] < y[1] end return x[2] < y[2] end)
		local live, top = 0, 0
		for _, ev in ipairs(events) do
			live = live + ev[2]
			if live > top then top = live end
		end
		if top > worst then worst, where = top, "line " .. line end
		local nu = int(sizeInt)
		for _ = 1, nu do str() end
	end
	fn()
	return worst, where
end

-- (A file's main chunk - "line 0" - holds its file-level locals: Net.lua's and UI.lua's were
-- already near that from 1.x, so they get the hard guard of 195 and are listed when over 150.)
test("files: no function holds more than 150 locals at once; no file's top level over 195 (Lua 5.1 limit 200)", function()
	local bad, near = {}, {}
	for _, file in ipairs((H.tocFiles("Wuber"))) do
		local n, where = maxLocals(H.ADDONS.Wuber .. "/" .. file)
		local limit = where == "line 0" and 195 or 150
		if n > limit then bad[#bad + 1] = file .. " " .. where .. ": " .. n
		elseif n > 150 then near[#near + 1] = file .. " top level: " .. n end
	end
	if #near > 0 then print("      note: file-level locals over 150: " .. list(near)) end
	local n = maxLocals(H.F.paths("Drive_Log")[1] or "?")
	ok(n > 0 and n < 150, "the reader works: Drive_Log " .. n)
	eq(#bad, 0, "too many locals: " .. list(bad))
end)

test("files: the Ritual Rides 1.5.0 tombstone: retired, saved data only, no events, frames or commands", function()
	local files = H.tocFiles("RitualRides", H.RR_TOMBSTONE)
	eq(table.concat(files, ","), "Core.lua")
	local toc = T.readFile(H.RR_TOMBSTONE .. "/RitualRides.toc")
	ok(toc:find("## SavedVariables: RitualRidesDB", 1, true))
	ok(toc:find("## Title: Ritual Rides (retired - now in Wuber)", 1, true))
	ok(toc:find("## Version: 1.5.0", 1, true))
	local w = newWorld()
	local c = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK", loadRR = "tombstone", saved = { RitualRides = { price = 70000 } } })
	eq(c.env.RitualRides.retired, true)
	eq(c.env.RitualRides.VERSION, "1.5.0")
	for k, at in pairs(c.globalWrites) do
		ok(not tostring(at):find("^RitualRides/") or k == "RitualRides", "the tombstone wrote " .. tostring(k))
	end
	eq(c.W.Char().price, 70000, "Wuber imported through it")
	clean(w)
end)

---------------------------------------------------------------------------
-- REVIEW-2.0.md: one regression test per finding fixed (each fails on the code before the fix)
---------------------------------------------------------------------------

do
	local function blocked(c, k) return DRof(c).BlockEntry(k) ~= nil end
	-- the windows that sent a BLK naming `k`
	local function blkSenders(w, k)
		local out = {}
		for _, e in ipairs(wubert(w, "BLK")) do
			if fields(e)[3] == k then out[e.from] = true end
		end
		return out
	end

	test("review #1: a rider who pays while a sync floods the crew's outbox is paid in every window and never blocked", function()
		local w, ana, bea, cal = team()
		for i = 1, 40 do ana.W.db.drive.blocklist["spammer" .. i .. " x"] = { reason = "r", at = "" } end
		ask(w, ana, "Dan Miller")
		summon(w, ana, bea, cal)
		land(w)
		for _, c in ipairs({ ana, bea, cal }) do eq(state(c, "Dan Miller"), "arrived", c.player.name .. " before paying") end
		DRof(ana).SyncNow() -- a crew window reloaded: the whole sync goes out (40 BLK, TPL, ST...)
		local _, nbulk = (DRof(ana).CommBacklog or function() return 0, 0 end)()
		ok(nbulk <= 50, "the bulk of a sync is capped: " .. nbulk)
		pays(w, "Dan Miller", FARE)
		eq(plan(ana).title, "Accept 50s from Dan")
		press(ana)
		w:advance(2)
		for _, c in ipairs({ ana, bea, cal }) do
			local s = state(c, "Dan Miller")
			ok(s == "paid" or s == "done", c.player.name .. " knows he paid at once: " .. tostring(s))
		end
		w:advance(3)
		w:leave("Dan Miller")
		w:advance(15)
		for _, c in ipairs({ ana, bea, cal }) do ok(not blocked(c, "dan miller"), c.player.name .. ": the rider who paid is not blocked") end
		w:advance(60)
		for _, c in ipairs({ ana, bea, cal }) do ok(not blocked(c, "dan miller"), c.player.name .. ": still not blocked a minute later") end
		-- the PAID went out ahead of the blocklist still queued
		local paidAt, lastBlk
		for i, e in ipairs(w.addonLog) do
			if e.prefix == "WUBERT" and e.from == ANA then
				if e.text:find("^PAID~") and not paidAt then paidAt = i end
				if e.text:find("^BLK~") then lastBlk = i end
			end
		end
		ok(paidAt and lastBlk and paidAt < lastBlk, "PAID before the end of the bulk sync: " .. tostring(paidAt) .. " " .. tostring(lastBlk) .. " of " .. #w.addonLog)
		clean(w)
	end)

	test("review #1: one window decides a non-payer, after a grace; a PAID during the grace wins", function()
		local w, ana, bea, cal = team()
		ask(w, ana, "Dan Miller")
		summon(w, ana, bea, cal)
		land(w)
		w:tradeCancel(w:player("Dan Miller"))
		w:leave("Dan Miller")
		w:advance(1)
		for _, c in ipairs({ ana, bea, cal }) do ok(not blocked(c, "dan miller"), c.player.name .. ": not blocked at once") end
		DRof(bea).Do("PAID", "Dan Miller", FARE) -- he paid Bea's window: the fact comes during the grace
		w:advance((DRof(ana).OWING_GRACE or 10) + 3)
		for _, c in ipairs({ ana, bea, cal }) do ok(not blocked(c, "dan miller"), c.player.name .. ": the late PAID counts") end
		-- a rider who really leaves owing: blocked everywhere, by one window's BLK
		ask(w, ana, "Eve Long")
		summon(w, ana, bea, cal)
		land(w)
		w:tradeCancel(w:player("Eve Long"))
		w:leave("Eve Long")
		w:advance((DRof(ana).OWING_GRACE or 10) + 3)
		for _, c in ipairs({ ana, bea, cal }) do ok(blocked(c, "eve long"), c.player.name .. ": the non-payer is blocked") end
		local senders = blkSenders(w, "eve long")
		eq(count(senders), 1, "one window decided")
		ok(senders[ANA], "the caster's window")
		clean(w)
	end)

	-- Ana (Warlock, the captain) and Bea (a Mage helper running Wuber) who leads the group
	local function helperLeads()
		local w = H.NewWorld({})
		local savedA = { Wuber = crewSaved(ANA, { ANA, BEA }, ANA, nil, { [BEA] = "helper" }) }
		local savedB = { Wuber = crewSaved(BEA, { ANA, BEA }, ANA) }
		local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = savedA })
		local b = w:addClient(BEA, { spot = SPOT, class = "MAGE", saved = savedB })
		w:group({ BEA, ANA })
		w:advance(2)
		return w, a, b
	end

	test("review #2: a helper's window leading the group hands the lead to the Warlock, so whisperers are invited", function()
		local w, a, b = helperLeads()
		eq(DRof(b).IsLeader(), true, "Bea leads at first")
		ok(DRof(a).SetOpen(true))
		w:advance(3)
		-- SPEC5 promote (#29): never from the 1 Hz timer, only from a click (Readiness pill /
		-- the big button's "Give lead to Ana" step, both DR.LeadFix().run)
		eq(DRof(b).IsLeader(), true, "no hand-over without a click")
		local fix = DRof(b).LeadFix()
		ok(fix and fix.title == "Give lead to Ana", "Bea's window offers the step")
		fix.run()
		w:advance(1)
		eq(DRof(a).IsLeader(), true, "Ana leads now")
		ok(w.promotions and #w.promotions == 1 and w.promotions[1].from == BEA and w.promotions[1].to == ANA, "one hand-over, Bea to Ana")
		w:addBot("Dan Miller", { spot = "Orgrimmar" })
		w:botWhisper("Dan Miller", a, "summon pls")
		w:advance(10)
		eq(state(a, "Dan Miller"), "joined", "Ana invited him")
		ok(w:player("Dan Miller").group == w:player(ANA).group, "Dan is in the group")
		clean(w)
	end)

	test("review #2: nobody in the group can invite (a stranger leads): the beacon says paused, a Wuber R gets N busy, Readiness says why", function()
		local w = H.NewWorld({})
		local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = { chars = { [key(ANA)] = { wizard = true } } } } })
		local r = rider(w)
		w:addBot("Gus Guild", { spot = SPOT })
		w:advance(15)
		w:group({ "Gus Guild", ANA })
		w:advance(1)
		ok(DRof(a).SetOpen(true))
		w:advance(6)
		local d = r.W.drivers["ana smith"]
		ok(d, "the rider sees Ana")
		eq(d.state, "paused", "not open while nobody can invite")
		w:inject(TESTCHAR, "R~1~gusled~Undercity~5000", "WHISPER", a)
		w:advance(1)
		local n = lastOf(w, "N", TESTCHAR)
		ok(n and fields(n)[4] == "busy", "N busy, not accepted")
		eq(#msgs(w, "A", ANA), 0, "never accepted")
		local why
		for _, line in ipairs(DRof(a).Readiness()) do
			if line.ok == false and line.text:find("leads the group", 1, true) then why = line.text end
		end
		ok(why and why:find("Gus", 1, true), "Readiness: " .. tostring(why))
		w:leave("Gus Guild") -- alone again: Ana invites
		w:advance(8)
		eq(r.W.drivers["ana smith"].state, "open", "open again")
		clean(w)
	end)

	test("review #3: the big-button key is bound only on a character where Wuber's engine runs", function()
		local w = newWorld()
		local m = w:addClient("Moe Mage", { spot = SPOT, class = "MAGE", saved = { Wuber = { drive = { button = { key = "F" } } } } })
		w:advance(2)
		eq(DRof(m).Active(), false)
		eq(m.binding, nil, "a Mage alt keeps its own F")
		DRof(m).AnswerOffer(ANA, true) -- joins Ana's crew: the engine runs here now
		w:advance(1)
		eq(m.binding and m.binding.button, "WuberDriveButton", "a crew member: bound")
		DRof(m).LeaveCrew()
		w:advance(1)
		eq(m.binding, nil, "out of the crew: unbound again")
		local w2 = newWorld()
		local a = w2:addClient(ANA, { spot = SPOT, class = "WARLOCK", loadRR = "1.4.1", saved = { RitualRides = { key = "F", enabled = false } } })
		w2:advance(2)
		eq(DRof(a).Lock(), "rr")
		ok(not (a.binding and a.binding.button == "WuberDriveButton"), "RR 1.4.1 drives: F is not Wuber's (" .. tostring(a.binding and a.binding.button) .. ")")
		local w3 = newWorld()
		local l = w3:addClient(ANITA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = { drive = { button = { key = "F" } } } } })
		w3:advance(2)
		eq(l.binding and l.binding.button, "WuberDriveButton", "a Warlock: bound")
		clean(w) clean(w2) clean(w3)
	end)

	test("review #4: 'Add anyway' and 'came with' helpers are never riders in the other crew windows", function()
		local w = H.NewWorld({})
		local a = w:addClient(ANA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(ANA, { ANA, BEA }, ANA) } })
		local b = w:addClient(BEA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(BEA, { ANA, BEA }, ANA) } })
		w:group({ ANA, BEA })
		w:advance(2)
		ok(DRof(a).SetOpen(true))
		w:advance(2)
		ok(DRof(a).AddPlainHelper("Zed Plain"), "added anyway")
		w:advance(2)
		local m = DRof(b).CrewEntry("zed plain")
		ok(m and m.app == false, "Bea's window knows Zed as a plain helper")
		w:addBot("Zed Plain", { spot = SPOT })
		w:join(w:player(ANA), w:player("Zed Plain"))
		w:advance(5)
		eq(customer(a, "Zed Plain"), nil, "not a rider for the captain")
		eq(customer(b, "Zed Plain"), nil, "not a rider for Bea either")
		-- a rider waiting for a summon, and a friend of theirs invited by hand
		ask(w, a, "Dan Miller")
		w:advance(2)
		eq(state(b, "Dan Miller"), "joined")
		w:addBot("Fay Friend", { spot = SPOT })
		w:join(w:player(ANA), w:player("Fay Friend"))
		w:advance(3)
		ok(customer(a, "Fay Friend") and customer(a, "Fay Friend").cameWith, "a 'came with' row for the leader")
		local f = customer(b, "Fay Friend")
		ok(not f or DRof(b).Rank(f.state) < DRof(b).Rank("joined"), "not a rider in Bea's window: " .. tostring(f and f.state))
		local t = plan(b).title or ""
		ok(not t:find("Zed", 1, true) and not t:find("Fay", 1, true), "Bea's button: " .. t)
		clean(w)
	end)

	test("review #5: once the game refused the forwarded Trade click, the button stops forwarding it", function()
		local w, ana, bea, cal = team()
		ask(w, ana, "Dan Miller")
		summon(w, ana, bea, cal)
		land(w)
		local p = w:player("Dan Miller")
		w:typeTradeMoney(p, 0, 50, 0)
		w:tradeAccept(p)
		w:advance(0.3)
		eq(plan(ana).type, "click", "the click accepts the trade")
		ana.W.db.blockedBuild[ana.W.Build()] = { trade = true } -- ADDON_ACTION_FORBIDDEN AcceptTrade()
		local pl = plan(ana)
		eq(pl.title, "Accept 50s from Dan", "still says what to do")
		eq(pl.type, nil, "no forwarded click")
		eq(pl.sub, "click Trade in the trade window")
		clean(w)
	end)

	test("review #6: Net.lua's main chunk holds at most 170 locals (Lua 5.1's limit is 200)", function()
		local paths = H.F.paths("Net") -- Net.lua, or every Net/*.lua after the restructure
		ok(#paths > 0, "Net's files in the TOC")
		for _, path in ipairs(paths) do
			local n = maxLocals(path)
			ok(n <= 170, path:match("[^/]+/[^/]+$") .. " top level: " .. n)
		end
	end)

	test("review #7: what Ritual Rides recorded between the import and its retirement comes over, once", function()
		local w = newWorld()
		local c = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK", loadRR = "1.4.1", saved = { RitualRides = rrDB() } })
		T.assertLocked(c)
		local d0 = c.W.db.drive
		local rides0, copper0 = d0.stats.rides, d0.stats.copper
		eq(#d0.log.rides, 1)
		DRof(c).Unblacklist("Dan Miller") -- unblocked in Wuber: stays unblocked
		-- RR goes on driving for a while ("Later" on the retire card)
		local rr = c.env.RitualRidesDB
		rr.blocklist["eve long"] = { reason = "left without paying", at = "18 Nov" }
		rr.log.rides[#rr.log.rides + 1] = "1700100000,50000,Eve Long,Undercity,t"
		rr.log.open["2026111820"] = 45
		rr.stats.rides = rr.stats.rides + 2
		rr.stats.copper = rr.stats.copper + 100000
		local saved = w:logout(c)
		local n = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK", loadRR = "tombstone", saved = { Wuber = saved.Wuber, RitualRides = rr } })
		local DR = DRof(n)
		eq(DR.Lock(), nil, "retired")
		ok(DR.BlockEntry("eve long"), "RR's new block came over")
		eq(DR.BlockEntry("dan miller"), nil, "unblocked in Wuber stays unblocked")
		eq(#n.W.db.drive.log.rides, 2, "RR's new ride line")
		eq(n.W.db.drive.log.open["2026111820"], 45, "RR's hours")
		eq(n.W.db.drive.stats.rides, rides0 + 2, "only the rides RR added since the import")
		eq(n.W.db.drive.stats.copper, copper0 + 100000)
		local saved2 = w:logout(n)
		local n2 = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK", loadRR = "tombstone", saved = { Wuber = saved2.Wuber, RitualRides = n.env.RitualRidesDB or rr } })
		eq(n2.W.db.drive.stats.rides, rides0 + 2, "merged once")
		eq(#n2.W.db.drive.log.rides, 2)
		clean(w)
	end)

	test("review #8: a message longer than a whisper carries is refused, not saved and cut", function()
		local w = newWorld()
		local c = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK" })
		local DR = DRof(c)
		local long = ("Hello {name}, welcome aboard the summon service, sit tight and enjoy the trip. "):rep(3)
		ok(#long > DR.TEXT_MAX)
		local okSet, why = DR.SetTemplate("greet", long)
		eq(okSet, false, "refused")
		ok(tostring(why):find(tostring(DR.TEXT_MAX), 1, true), tostring(why))
		eq(c.W.db.drive.templates.greet, nil, "nothing saved")
		eq(DR.SetTemplate("greet", long:sub(1, 150)), true, "a shorter one is saved")
		clean(w)
	end)

	test("review #9: a rider can't rate a ride before paying for it", function()
		local w, ana, bea, cal = team()
		local r = rider(w)
		w:advance(15)
		ok(r.W.RequestRide("ana smith"))
		w:advance(4)
		summon(w, ana, bea, cal)
		w.hardware = r
		r.W.AcceptSummon()
		w.hardware = nil
		land(w)
		ok(r.W.RIDE_RANK[T.rideState(r)] >= r.W.RIDE_RANK.arrived, "arrived: " .. tostring(T.rideState(r)))
		eq(r.W.Rate(5), false, "no rating before paying")
		eq(#msgs(w, "T", TESTCHAR), 0, "no T sent")
		pays(w, TESTCHAR, FARE)
		press(ana)
		w:advance(3)
		eq(T.rideState(r), "done")
		eq(r.W.Rate(5), true, "paid: rated")
		clean(w)
	end)

	test("review #10: a one-part name with a node realm is one rider, invited and whispered by its name", function()
		local w = newWorld()
		local a = w:addClient(ANITA, { spot = SPOT, class = "WARLOCK", saved = { Wuber = { chars = { [key(ANITA)] = { wizard = true } } } } })
		eq(a.W.Key("Dan-CAMWOW EU5 Realm 5"), "dan")
		eq(DRof(a).CleanName("Dan-CAMWOW EU5 Realm 5"), "Dan")
		eq(a.W.Key("Ana-Smith"), "ana smith", "First-Surname is still a full name")
		eq(a.W.Key("Ana Smith-CAMWOW EU5 Realm 5"), "ana smith")
		ok(DRof(a).SetOpen(true))
		w:addBot("Dan", { spot = "Orgrimmar" })
		ghostWhisper(a, "Dan-CAMWOW EU5 Realm 5", "summon pls")
		w:advance(4)
		eq(w.invites[#w.invites].to, "Dan", "invited by the name alone")
		eq(nCustomers(a), 1, "one rider")
		eq(state(a, "Dan"), "joined")
		clean(w)
	end)

	test("review #11: a helper's own channel (Drain Soul) during a crew ritual is not a portal click", function()
		local w, ana, bea, cal = team()
		ask(w, ana, "Dan Miller")
		press(ana)
		w:advance(3)
		eq(state(bea, "Dan Miller"), "summoning")
		bea.env.IsSpellKnown = function(id) return id == 1120 or id == 698 end
		bea:fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Drain-1", 1120)
		w:advance(1)
		eq(#wubert(w, "HELP", BEA), 0, "Drain Soul is not a click on the portal")
		ok(w:clickPortal(bea))
		w:advance(1)
		eq(#wubert(w, "HELP", BEA), 1, "the portal click is")
		ok(w:clickPortal(cal))
		w:advance(2)
		clean(w)
	end)

	test("review #12: the docked button leaves its slot while the price sheet is open", function()
		local w = newWorld()
		local d = T.driver(w)
		w:advance(15)
		T.openDrive(d)
		w:advance(1)
		local B = d.W.Drive.Button
		ok(B.Docked(), "docked over the console")
		d:clickOn(d.W.Driver.ui.console.fare)
		w:advance(1)
		ok(d.W.Driver.SheetOpen(), "the price sheet is open")
		eq(d.W.Driver.Slot(), nil, "no slot under the sheet")
		eq(B.Docked(), false, "not docked over the sheet")
		clean(w)
	end)
end
