-- Wuber 2.2: the fixes for REVIEW-2.2.md (independent review). Loaded by run.lua with the same
-- helpers as the other round-six files. Test names start "r6 review:" and name the finding.

local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local list, clean, settle, rider, driver = T.list, T.clean, T.settle, T.rider, T.driver
local ANITA, TESTCHAR, BOB, ANA, BEA, CAL = T.ANITA, T.TESTCHAR, T.BOB, T.ANA, T.BEA, T.CAL
local REX = "Rex Scam"
local DAN = "Dan Miller"
local SPOT = "Undercity"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function DRof(c) return c.W.Drive end
local function sent(w, from, pattern, prefix)
	local out = {}
	for _, e in ipairs(w.addonLog) do
		if e.from == from and (prefix or "WUBER") == e.prefix and e.result == 0 and e.text:find(pattern) then out[#out + 1] = e end
	end
	return out
end

---------------------------------------------------------------------------
-- #1: only the driver, the payee/summoner or the crew the driver named may take the fare
---------------------------------------------------------------------------

-- Wuber landed with Bob (a driver bot, Bea the summoner to pay); Rex, another rider, is in
-- the same group. opts.tradeOrder: the harness's trade event order.
local function landed(opts)
	opts = opts or {}
	local w = H.NewWorld({ tradeOrder = opts.tradeOrder })
	w:addBot(BOB, { spot = "Orgrimmar", class = "WARLOCK" })
	w:addBot(BEA, { spot = "Orgrimmar", class = "WARLOCK" })
	w:addBot(CAL, { spot = "Orgrimmar", class = "PRIEST" })
	w:addBot(REX, { spot = "Orgrimmar" })
	local r = rider(w, TESTCHAR, { money = 100000 })
	settle(w)
	w:group({ BOB, TESTCHAR, REX, BEA, CAL })
	w:advance(1)
	local t = r.env.GetTime()
	r.W.ride = { id = "abcdef", state = "arrived", driverKey = "bob stone", driver = BOB, addr = BOB, price = opts.fare or 5000,
		at = t, changed = t, startedAt = r.env.time(), dest = "Orgrimmar", wasGrouped = true, payee = BEA, payto = "Bea" }
	return w, r
end

local function payBy(w, r, from, copper)
	ok(w:openTrade(w:player(from), w:player(TESTCHAR)), "a trade opens")
	w:tradeMoney(w:player(TESTCHAR), copper)
	w:tradeAccept(w:player(from))
	w:tradeAccept(w:player(TESTCHAR))
	w:advance(1)
end

test("r6 review #1: a fellow rider in the driver's group is not the driver's side: warned, no pay, never counted", function()
	local w, r = landed()
	local warned
	r.W.Listen("TRADE_STRANGER", function(who) warned = who end)
	ok(w:openTrade(w:player(REX), w:player(TESTCHAR)), "Rex opens trade")
	w:advance(0.5)
	eq(r.W.TradePartnerOK(), false, "Rex is in the group but not the crew")
	eq(warned, REX, "TRADE_STRANGER for a group member")
	local okPay = r.W.PayFare()
	eq(okPay, false, "PayFare refuses Rex's trade")
	w:tradeMoney(w:player(TESTCHAR), 5000)
	w:tradeAccept(w:player(REX))
	w:tradeAccept(w:player(TESTCHAR))
	w:advance(4)
	eq(r.W.ride.state, "arrived", "money to Rex is not the fare")
	eq(r.W.ride.paid, nil)
	-- the payee (Bea) is fine
	payBy(w, r, BEA, 5000)
	eq(r.W.ride.state, "done", "paid to the payee")
	clean(w)
end)

test("r6 review #1: a crew member the driver names in its S may take the fare; the S carries the crew", function()
	local w, r = landed()
	ok(w:openTrade(w:player(CAL), w:player(TESTCHAR)))
	w:advance(0.5)
	eq(r.W.TradePartnerOK(), false, "Cal unknown so far")
	w:tradeCancel(w:player(TESTCHAR))
	w:advance(0.5)
	-- the driver's S: stage, payee, then the rest of the crew
	w:inject(BOB, "S~1~abcdef~arrived~Bea Jones~Cal Brown", "WHISPER", r)
	w:advance(1)
	eq(list(r.W.ride.crew or {}), "cal brown", "the crew kept")
	ok(w:openTrade(w:player(CAL), w:player(TESTCHAR)))
	w:advance(0.5)
	eq(r.W.TradePartnerOK(), true, "Cal is crew now")
	w:tradeCancel(w:player(TESTCHAR))
	w:advance(0.5)
	-- the driver side: W.SendStage puts payee and crew in S (fields 3, 4 on)
	local d = driver(w, ANITA)
	settle(w, 3)
	d.W.incoming = d.W.incoming or {}
	table.insert(d.W.incoming, { id = "ghijkl", buyer = DAN, key = key(DAN), state = "accepted" })
	w:addBot(DAN, { spot = "Orgrimmar" })
	ok(d.W.SendStage("ghijkl", "invited", DAN, BEA, { CAL, ANA }), "S sent")
	w:advance(1)
	eq(#sent(w, ANITA, "^S~1~ghijkl~invited~Bea Jones~Cal Brown~Ana Smith$"), 1, "S with payee and crew")
	ok(d.W.SendStage("ghijkl", "portal", DAN, nil, { CAL }), "S sent")
	w:advance(1)
	eq(#sent(w, ANITA, "^S~1~ghijkl~portal~~Cal Brown$"), 1, "no payee: an empty field, then the crew")
end)

---------------------------------------------------------------------------
-- #2: TRADE_CLOSED before "Trade complete." (the real client's order) still counts the fare
---------------------------------------------------------------------------

test("r6 review #2: real order (close, 'Trade complete.', purse; no 1,1 for the last accepter): the fare counts", function()
	local w, r = landed({ tradeOrder = "real" })
	payBy(w, r, BEA, 5000)
	eq(r.W.ride.state, "done", "paid")
	eq(r.W.ride.paid, 5000)
	clean(w)
end)

test("r6 review #2: close, purse, then 'Trade complete.': the fare counts; part payments add up", function()
	local w, r = landed({ tradeOrder = "closeMoneyLine" })
	payBy(w, r, BEA, 3000)
	ok(r.W.ride.state ~= "done", "part paid")
	eq(r.W.FareLeft(), 2000, "20s left")
	payBy(w, r, BOB, 2000)
	eq(r.W.ride.state, "done", "paid in full over two trades")
	eq(r.W.ride.paid, 5000)
	clean(w)
end)

test("r6 review #2: a cancelled trade in the real order, then a repair: never the fare", function()
	local w, r = landed({ tradeOrder = "real" })
	ok(w:openTrade(w:player(BEA), w:player(TESTCHAR)))
	w:advance(0.5)
	w:tradeCancel(w:player(TESTCHAR))
	w:advance(0.5)
	local p = w:player(TESTCHAR)
	p.money = p.money - 5000 -- a repair
	r:fire("PLAYER_MONEY")
	w:advance(6)
	ok(r.W.ride.state ~= "done", "not paid by a repair")
	eq(r.W.ride.moneyBefore, nil, "forgotten after 5 s")
	clean(w)
end)

---------------------------------------------------------------------------
-- #4 / #5 / #8: raid claims
---------------------------------------------------------------------------

local DRU, LEA = "Dru Oak", "Lea Dorn"
local cal_, bea_ -- the summoners' windows of the last raidTwo
local RAIDSPOT = "Blackrock Mountain"

-- A raid at Blackrock: Dru (Druid, assist) runs raid summons; Cal then Bea (Warlocks, Wuber)
-- summon, in that order; Raider Ra-Rf wait in Orgrimmar.
local function raidTwo()
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = RAIDSPOT, class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = RAIDSPOT, class = "DRUID" })
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK" })
	local bea = w:addClient(BEA, { spot = RAIDSPOT, class = "WARLOCK" })
	local names = { LEA, DRU, CAL, BEA }
	for i = 1, 6 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	settle(w)
	local DD = DRof(dru)
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick(CAL, true))
	w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true)
	w:advance(3)
	ok(DD.RaidPick(BEA, true))
	w:advance(1)
	bea.W.Drive.AnswerOffer(DRU, true)
	w:advance(3)
	eq(list(DD.Summoners()), key(CAL) .. "; " .. key(BEA), "Cal, then Bea")
	ok(DD.SetOpen(true), "Start")
	w:advance(3)
	ok(DRof(cal).RaidOn() and DRof(bea).RaidOn(), "both summoners follow")
	cal_, bea_ = cal, bea
	return w, dru, cal, bea
end

local function queue(w, dru, ...)
	for _, n in ipairs({ ... }) do ok(DRof(dru).RaidAdd(n), "queued " .. n) end
	w:advance(2)
	for _, n in ipairs({ ... }) do
		for _ = 1, 10 do
			if DRof(cal_).raidRows[key(n)] and DRof(bea_).raidRows[key(n)] then break end
			w:advance(1)
		end
		ok(DRof(cal_).raidRows[key(n)] and DRof(bea_).raidRows[key(n)], n .. " on every window")
	end
end

test("r6 review #4: a raid claim by a summoner who left the raid goes back to the queue at once", function()
	local w, dru, cal, bea = raidTwo()
	queue(w, dru, "Raider Ra")
	DRof(cal).Do("CAST", "Raider Ra")
	DRof(cal).Do("CH", "Raider Ra")
	w:advance(2)
	local row = DRof(dru).raidRows[key("Raider Ra")]
	eq(row.state, "summoning", "Cal's claim, channelling")
	eq(row.claimedBy, key(CAL))
	w:leave(CAL)
	w:advance(3)
	eq(DRof(dru).raidRows[key("Raider Ra")].state, "queued", "released on the runner's window")
	eq(DRof(dru).raidRows[key("Raider Ra")].claimedBy, nil)
	eq(DRof(bea).raidRows[key("Raider Ra")].state, "queued", "and Bea's: she can take Ra now")
end)

test("r6 review #4: a claim by a Wuber summoner whose window went silent is released after 45 s, not 330 s", function()
	local w, dru, cal = raidTwo()
	queue(w, dru, "Raider Ra")
	DRof(cal).Do("CAST", "Raider Ra")
	DRof(cal).Do("CH", "Raider Ra")
	w:advance(2)
	w:closeClient(cal) -- disconnected: still in the raid, silent
	w:advance(30)
	eq(DRof(dru).raidRows[key("Raider Ra")].state, "summoning", "not at 30 s")
	w:advance(30)
	eq(DRof(dru).raidRows[key("Raider Ra")].state, "queued", "released after 45 s of silence")
	-- sell mode: a customer whose caster left the group goes back to waiting for a summon
	local DR = DRof(dru)
	eq(DR.ClaimGone("nobody here", 0), true, "not in the group")
	eq(DR.ClaimGone(dru.W.myKey, 0), false, "never my own")
end)

test("r6 review #5: an END from a summoner who lost the claim leaves the claimer's raider alone; the loser is told to stop", function()
	local w, dru, cal, bea = raidTwo()
	queue(w, dru, "Raider Ra")
	local DC = DRof(cal)
	local alerts = {}
	local alert = DC.Alert
	DC.Alert = function(text, kind, ...) alerts[#alerts + 1] = tostring(text) return alert(text, kind, ...) end
	DC.cast = { name = "Raider Ra", at = cal.env.GetTime() } -- Cal's own ritual on Ra
	DC.Do("CAST", "Raider Ra")
	DRof(bea).Do("CAST", "Raider Ra")
	w:advance(1)
	for _, c in ipairs({ dru, cal, bea }) do
		eq(DRof(c).raidRows[key("Raider Ra")].claimedBy, key(BEA), c.player.name .. ": the lower key (Bea) keeps Ra")
	end
	ok(list(alerts):find("Bea has Raider: stop your summon.", 1, true), "Cal told to stop: " .. list(alerts))
	ok(not list(alerts):find("Click the summoning portal", 1, true), "not also told to click the portal: " .. list(alerts))
	DC.cast = nil
	DC.Do("END", "Raider Ra", 0) -- Cal cancels
	w:advance(1)
	local row = DRof(dru).raidRows[key("Raider Ra")]
	eq(row.state, "summoning", "Bea still has Ra")
	eq(row.claimedBy, key(BEA))
	eq(row.fails, 0, "no failure counted")
	DC.Do("END", "Raider Ra", 1)
	w:advance(1)
	eq(DRof(dru).raidRows[key("Raider Ra")].state, "summoning", "a loser's END 1 doesn't settle it either")
	DRof(bea).Do("END", "Raider Ra", 1)
	w:advance(1)
	eq(DRof(dru).raidRows[key("Raider Ra")].state, "waiting", "Bea's own END does")
end)

test("r6 review #8: a summoner whose view is newer (an END not yet heard elsewhere) holds the raider a moment; never two on one", function()
	local w, dru, cal, bea = raidTwo()
	queue(w, dru, "Raider Ra", "Raider Rb", "Raider Rc")
	local DC, DB = DRof(cal), DRof(bea)
	DC.Do("CAST", "Raider Ra")
	DC.Do("CH", "Raider Ra")
	w:advance(2)
	local pb = DB.Plan()
	eq(pb.summon and pb.summon.name, "Raider Rb", "Bea (Cal busy) plans Rb")
	-- Cal's ritual ends; its END reaches only Cal's own window so far
	local t = cal.env.GetTime()
	DC.RaidApply("END", key(CAL), true, "Raider Ra", "1", nil, t)
	local pc = DC.Plan()
	ok(pc.summon == nil or pc.summon.name ~= "Raider Rb", "Cal never plans Bea's Rb at once: " .. tostring(pc.title))
	-- the END reaches Bea; both settle on different raiders
	DB.RaidApply("END", key(CAL), false, "Raider Ra", "1", nil, bea.env.GetTime())
	w:advance(1)
	local a, b = DC.Plan(), DB.Plan()
	ok(a.summon and b.summon, "both plan a raider: " .. tostring(a.title) .. " / " .. tostring(b.title))
	ok(a.summon.name ~= b.summon.name, "two different raiders: " .. a.summon.name .. " / " .. b.summon.name)
	-- DR.RaidNext never falls back to another summoner's raider
	queue(w, dru)
	DB.Do("CAST", b.summon.name)
	DC.Do("CAST", a.summon.name)
	w:advance(1)
	for _, n in ipairs({ "Raider Rb", "Raider Rc" }) do if DRof(dru).raidRows[key(n)] then DRof(dru).RaidDrop(n) end end
	w:advance(1)
	eq(DB.RaidNext(), nil, "Bea holds a claim: nothing new")
end)

---------------------------------------------------------------------------
-- #6: raid mode never asks a leading helper to give the lead away
---------------------------------------------------------------------------

test("r6 review #6: raid summons: a crew helper who leads the raid is never told to 'Give lead' (sell mode still is)", function()
	local w = H.NewWorld({})
	local PIA = "Pia Helper"
	local function saved(me, captain, crew)
		return { Wuber = { chars = { [key(me)] = { crew = crew, captain = captain, wizard = true } } } }
	end
	local pia = w:addClient(PIA, { spot = RAIDSPOT, class = "PRIEST", saved = saved(PIA, CAL, { { name = CAL, role = "lock", app = true } }) })
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK", saved = saved(CAL, "", { { name = PIA, role = "helper", app = true } }) })
	local names = { PIA, CAL }
	for i = 1, 6 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(CAL, true)
	settle(w)
	local DP, DC = DRof(pia), DRof(cal)
	eq(DP.Role(), "helper", "Pia helps")
	ok(DP.IsLeader(), "and leads the raid")
	-- selling: the lead goes to the Warlock so riders get invites
	ok(DC.SetOpen(true), "open (sell)")
	w:advance(4)
	local _, to = DP.LeadTarget()
	eq(to, CAL, "sell mode: give lead to Cal")
	ok(DC.SetOpen(false) ~= nil)
	w:advance(2)
	-- raid summons: never
	ok(DC.SetMode("raid"))
	w:advance(2)
	ok(DC.SetOpen(true), "Start raid summons")
	w:advance(4)
	eq(DP.Mode(), "raid", "Pia's window follows")
	eq(DP.LeadTarget(), nil, "no lead target in raid mode")
	local p = DP.Plan()
	ok(not tostring(p.title):find("Give lead", 1, true), "the button never says Give lead: " .. tostring(p.title))
	for _, r in ipairs(DP.Readiness()) do
		ok(not tostring(r.text):find("You lead the group", 1, true), "no lead line in Readiness")
	end
	ok(DP.IsLeader(), "Pia still leads")
end)

---------------------------------------------------------------------------
-- #7: the map check uses the summoner's map, not the runner's
---------------------------------------------------------------------------

test("r6 review #7: the runner in Orgrimmar first in the group, the summoner in Undercity: the Undercity ride is right", function()
	local w = H.NewWorld({})
	w:addBot(BOB, { spot = "Orgrimmar", class = "MAGE" }) -- the runner (the driver of the ride)
	w:addBot(BEA, { spot = "Undercity", class = "WARLOCK" }) -- the summoner
	local r = rider(w, TESTCHAR, { spot = "Ratchet" })
	settle(w)
	w:group({ TESTCHAR, BOB, BEA }) -- Bob's unit comes first
	w:advance(1)
	local ride = { id = "abcdef", state = "portal", driverKey = "bob stone", driver = BOB, dest = "Undercity", summoner = BEA, payee = BEA }
	local good, where = r.W.SummonerMapOK(ride)
	eq(good, true, "Bea is in Undercity: right (" .. tostring(where) .. ")")
	ride.summoner, ride.payee = nil, nil
	good, where = r.W.SummonerMapOK(ride)
	eq(good, false, "no summoner known: the driver's map counts")
	clean(w)
end)

---------------------------------------------------------------------------
-- #9: raid summons stop advertising when the runner leaves or pauses
---------------------------------------------------------------------------

test("r6 review #9: paused raid summons say so in HI and hear no requests; leaving the raid stops them for the next party", function()
	local w, dru, cal = raidTwo()
	local ray = rider(w, "Ray Ash", { spot = "Orgrimmar" })
	w:join(w:player(LEA), w:player("Ray Ash"))
	w:advance(20)
	local DD, DR = DRof(dru), DRof(ray)
	ok(DR.RaidHere(), "Ray's window sees raid summons")
	ok(DD.SetPaused(true))
	w:advance(3)
	eq(DR.RaidHere(), nil, "paused: no 'Request a summon' card")
	w:groupSay("Raider Ra", "123")
	w:advance(2)
	eq(DD.raidRows[key("Raider Ra")], nil, "no request queued while paused")
	ok(DD.SetPaused(false))
	w:advance(3)
	ok(DR.RaidHere(), "running again: the card is back")
	-- the runner leaves the raid: stopped (raidRun is saved), not just paused
	w:leave(DRU)
	w:advance(3)
	eq(DD.RaidOn(), false, "raid summons stopped")
	eq(DD.char().raidRun, false, "not saved as running")
	-- a new party with a Wuber user: no raid card, "123" is not queued
	local gus = rider(w, "Gus Hill", { spot = RAIDSPOT })
	w:advance(15)
	w:group({ DRU, "Gus Hill" })
	w:advance(20)
	eq(DRof(gus).RaidHere(), nil, "Gus sees no raid summons")
	w:groupSay("Gus Hill", "123")
	w:advance(2)
	eq(DD.raidRows[key("Gus Hill")], nil, "not queued")
end)

---------------------------------------------------------------------------
-- #10: no "estimate" wording anywhere (flight costs are exact only)
---------------------------------------------------------------------------

-- Round 8: flight TIMES may now be estimates, labelled "about" on screen. So the Lua files are checked only
-- for user-visible text (quoted strings) saying "estimate"; comments and code names may use the word, and "about" is
-- allowed in Lua. README keeps the full 2.2 check (no "estimate", no explaining "about").
local function quoted(text)
	local out = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		local from = 1
		while true do -- cut a "--" comment that is not inside a double-quoted string
			local at = line:find("--", from, true)
			if not at then break end
			local _, n = line:sub(1, at - 1):gsub('"', "")
			if n % 2 == 0 then line = line:sub(1, at - 1) break end
			from = at + 2
		end
		for s in line:gmatch('"([^"]*)"') do out[#out + 1] = s end
		for s in line:gmatch("'([^']*)'") do out[#out + 1] = s end
	end
	return table.concat(out, "\n")
end

test("r6 review #10: no 'estimate' or 'about' flight wording in Wuber's files or README; an inexact cost shows nothing", function()
	local root = T.dir .. "/.."
	local files = { "README.md" }
	for _, old in ipairs({ "Core", "Net", "Places", "UI", "UI_Trips", "UI_Drive" }) do
		local src = H.F.sources(old) -- the old file, or the modules its code moved to (tests/lib/files.lua)
		ok(#src > 0, old .. "'s files in the TOC")
		for _, f in ipairs(src) do files[#files + 1] = "Wuber/" .. f end
	end
	files[#files + 1] = "Wuber/Wuber.toc"
	for _, f in ipairs(files) do
		local text = T.readFile(root .. "/" .. f)
		ok(text, f)
		local lua = f:find("%.lua$") ~= nil
		local said = lua and quoted(text or "") or (text or "")
		ok(not said:lower():find("estimat", 1, true), f .. " still says estimate")
		if not lua then
			ok(not text:find("\"about\"", 1, true) and not text:find("\\\"about\\\"", 1, true), f .. " still explains \"about\"")
		end
	end
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR)
	settle(w)
	r.W.FlightCost = function() return 2300, 0 end
	eq(r.W.UI.FlightCostTo("Undercity"), nil, "an inexact cost is never shown")
	eq(r.W.UI.FlightLine("Undercity", false, 5000), nil, "no line")
	clean(w)
end)

---------------------------------------------------------------------------
-- #11: learned flight costs are one faction's
---------------------------------------------------------------------------

test("r6 review #11: an Alliance alt's learned flight cost is never shown to a Horde character (per-faction keys)", function()
	local w = H.NewWorld({})
	local r = rider(w, TESTCHAR, { spot = "Ratchet", faction = "Alliance" })
	settle(w)
	w:openTaxi(r, {
		{ name = "Ratchet, The Barrens", type = "CURRENT", cost = 0 },
		{ name = "Gadgetzan, Tanaris", type = "REACHABLE", cost = 1111 },
	})
	eq(r.W.FlightSeen(nil, "Gadgetzan"), 1111, "the Alliance cost for the Alliance character")
	ok(r.W.db.flights["A|ratchet|gadgetzan"], "kept under A")
	eq(r.W.db.flights["ratchet|gadgetzan"], nil, "never without a faction")
	-- the same account's Horde main
	local saved = r.W.db
	local h = rider(w, BOB, { spot = "Ratchet", faction = "Horde", saved = { WuberDB = saved } })
	settle(w, 3)
	eq(h.W.FlightSeen(nil, "Gadgetzan"), nil, "nothing seen for the Horde: their own flight master hasn't shown it")
	local hc, _, hsrc = h.W.FlightCost(nil, "Gadgetzan")
	ok(hc ~= 1111, "never the Alliance's price for the Horde")
	eq(hsrc, "table", "the game's own Horde list price (2.2.1)")
	w:openTaxi(h, {
		{ name = "Ratchet, The Barrens", type = "CURRENT", cost = 0 },
		{ name = "Gadgetzan, Tanaris", type = "REACHABLE", cost = 2345 },
	})
	eq(h.W.FlightSeen(nil, "Gadgetzan"), 2345, "the Horde's own")
	clean(w)
end)

---------------------------------------------------------------------------
-- #12: the founder crown is not copyable on other rulesets
---------------------------------------------------------------------------

test("r6 review #12: 'Anita Lift' on a US realm gets no crown or top glow from others; the founders' own window keeps it", function()
	for _, case in ipairs({ { realm = "CAMWOW US2 Realm 1 PvE", want = false }, { realm = "CAMWOW EU5 Realm 5 PvE", want = true } }) do
		local w = H.NewWorld({})
		local r = w:addClient(TESTCHAR, { spot = "Ratchet", class = "MAGE", realm = case.realm })
		local a = w:addClient(ANITA, { spot = "Ratchet", class = "WARLOCK", realm = case.realm })
		settle(w)
		eq(r.W.IsCreator(ANITA), case.want, case.realm .. ": another player named Anita Lift")
		eq(r.W.IsCreator("anita lift"), case.want, case.realm .. ": by key")
		eq(a.W.IsCreator(ANITA), true, case.realm .. ": my own character")
		eq(a.W.AmFounder(), true)
		local glow, crowned = r.W.Prominence({ key = "anita lift", name = ANITA, state = "busy" })
		eq(crowned == true, case.want, case.realm .. ": top placement")
		clean(w)
	end
end)

---------------------------------------------------------------------------
-- #13: install.ps1 prints no path that names the old addon's folder
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- #14: a rider who booked tells the other drivers it pinged (B): no more pushes
---------------------------------------------------------------------------

test("r6 review #14: booked with Ana, the rider whispers B to Bob (pinged 1 min ago); Bob stops pushing his D", function()
	local w = H.NewWorld({})
	w:addBot(ANA, { spot = "Ratchet", class = "WARLOCK" })
	w:addBot(CAL, { spot = "Ratchet", class = "WARLOCK" })
	local bob = driver(w, BOB)
	local r = rider(w, TESTCHAR)
	settle(w)
	ok(DRof(bob).SetOpen(true))
	w:advance(3)
	-- Wuber whispered Bob a Q a minute ago (the whisper fallback); Cal 10 min ago
	w:inject(TESTCHAR, "Q~1~0", "WHISPER", bob)
	w:advance(2)
	ok(bob.W.fallback.riders[key(TESTCHAR)], "Bob keeps pushing to Wuber")
	local fb = r.W.fallback
	local t = r.env.GetTime()
	fb.qAt[key(BOB)], fb.qAddr[key(BOB)] = t - 60, BOB
	fb.qAt[key(CAL)], fb.qAddr[key(CAL)] = t - 600, CAL
	fb.qAt[key(ANA)], fb.qAddr[key(ANA)] = t - 30, ANA
	-- Wuber's ride with Ana is accepted
	r.W.ride = { id = "abcdef", state = "requesting", driverKey = key(ANA), driver = ANA, addr = ANA, price = 5000,
		at = t, changed = t, startedAt = r.env.time(), dest = "Ratchet" }
	w:inject(ANA, "A~1~abcdef~5000~5", "WHISPER", r)
	w:advance(2)
	eq(r.W.ride.state, "accepted")
	local bTo = {}
	for _, e in ipairs(w.addonLog) do
		if e.from == TESTCHAR and e.text:match("^B~") then bTo[key(tostring(e.target))] = (bTo[key(tostring(e.target))] or 0) + 1 end
	end
	eq(bTo[key(BOB)], 1, "one B to Bob")
	eq(bTo[key(ANA)], nil, "none to the driver it booked")
	eq(bTo[key(CAL)], nil, "none to a driver pinged 10 min ago")
	ok(bob.W.RiderBooked(key(TESTCHAR)), "Bob: Wuber is booked")
	eq(bob.W.fallback.riders[key(TESTCHAR)], nil, "no more pushes")
	local before = #sent(w, BOB, "^D~")
	local mark = #w.addonLog
	DRof(bob).SetPrice(9000) -- a beacon change
	w:advance(10)
	local toTestchar = 0
	for i = mark + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.from == BOB and e.text:match("^D~") and e.chatType == "WHISPER" and key(tostring(e.target)) == key(TESTCHAR) then toTestchar = toTestchar + 1 end
	end
	eq(toTestchar, 0, "Bob's changed D isn't pushed to Wuber")
	ok(#sent(w, BOB, "^D~") >= before, "(Bob still beacons on the channel)")
	clean(w)
end)
