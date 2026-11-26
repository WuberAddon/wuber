-- Tests of Drive.Cut. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"
local SPOT = "Undercity"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

-- Three Warlocks of one crew (Ana the captain) and riders `extra` (bots), grouped, open.
local function team(extra, ver)
	local w = H.NewWorld({})
	local names = { ANA, BEA, CAL }
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(name, names, ANA) } })
		cs[i].W.VERSION = ver or "2.3.0" -- (the shift log is dormant before the release's version bump)
	end
	local all = { ANA, BEA, CAL }
	for _, n in ipairs(extra or {}) do
		w:addBot(n, { spot = "Orgrimmar" })
		all[#all + 1] = n
	end
	w:group(all)
	w:advance(1)
	cs[1].W.Drive.SetOpen(true)
	w:advance(3)
	return w, cs[1], cs[2], cs[3]
end

-- one summon from facts: the caster's CAST, each helper's HELP, the caster's END ok
local function summon(w, rider, caster, helpers, okEnd)
	caster.W.Drive.Do("CAST", rider)
	w:advance(1)
	for _, h in ipairs(helpers) do h.W.Drive.Do("HELP", rider) end
	w:advance(1)
	caster.W.Drive.Do("END", rider, okEnd == false and 0 or 1)
	w:advance(1)
end

local function rowsOf(c)
	local rows, rule, info = c.W.Drive.Cut()
	local out = {}
	for _, r in ipairs(rows) do out[r.name] = r end
	return out, rule, info, rows
end

test("drive.cut: contract (registered, deps, header, public names); idle: no rows, the default rule", function()
	local W, w, r, Mod = T.contract("Drive.Cut", "tests/drive/cut_test.lua", {
		["DR.Cut"] = "function", ["DR.CutText"] = "function", ["DR.CutSplit"] = "function", ["DR.cut"] = "table",
		["DR.CutTick"] = "function", ["DR.CutLog"] = "function",
	})
	ok(Mod, "W.Mod(\"Drive.Cut\")")
	local rows, rule = W.Drive.Cut()
	eq(#rows, 0, "no rows")
	eq(rule, "clicks", "the default rule")
	eq(W.Drive.CutText(), nil, "nothing to share")
	eq(W.db.drive.opts.cutRule, nil, "the default is never written to saved data")
	T.clean(w)
end)

test("drive.cut: settings: DR.CleanOpt / DR.SetOpt take cutRule, cutCaster (0-100 by 5) and watchBounty; DR.Opt has the defaults", function()
	local W, w = T.contract("Drive.Cut", "tests/drive/cut_test.lua", {})
	local DR = W.Drive
	eq(DR.OPT_LATE.cutRule, "clicks") eq(DR.OPT_LATE.cutCaster, 40) eq(DR.OPT_LATE.watchBounty, true)
	eq(DR.Opt("cutRule"), "clicks") eq(DR.Opt("cutCaster"), 40) eq(DR.Opt("watchBounty"), true, "on by default")
	eq(DR.CleanOpt("cutRule", "equal"), "equal") eq(DR.CleanOpt("cutRule", "clicks"), "clicks")
	eq(DR.CleanOpt("cutRule", "bogus"), "clicks", "anything else: by clicks") eq(DR.CleanOpt("cutRule", nil), "clicks")
	eq(DR.CleanOpt("cutCaster", 35), 35) eq(DR.CleanOpt("cutCaster", 37), 35, "step 5") eq(DR.CleanOpt("cutCaster", 38), 40)
	eq(DR.CleanOpt("cutCaster", -20), 0, "at least 0") eq(DR.CleanOpt("cutCaster", 250), 100, "at most 100")
	eq(DR.CleanOpt("cutCaster", "x"), 40, "junk: the default") eq(DR.CleanOpt("cutCaster", "60"), 60)
	eq(DR.CleanOpt("watchBounty", false), false) eq(DR.CleanOpt("watchBounty", true), true)
	eq(DR.CleanOpt("watchBounty", "no"), true, "not a boolean: the default")
	eq(DR.SetOpt("cutCaster", 63), 65) eq(W.db.drive.opts.cutCaster, 65) eq(DR.Opt("cutCaster"), 65)
	eq(DR.SetOpt("watchBounty", false), false)
	eq(W.db.drive.opts.watchBounty, false, "saved as false (Net.Bounty and Demand read opts.watchBounty == false)")
	eq(DR.Opt("watchBounty"), false)
	eq(DR.SetOpt("cutRule", "equal"), "equal") eq(DR.Opt("cutRule"), "equal")
	DR.InitDB()
	eq(W.db.drive.opts.cutCaster, 65, "InitDB keeps them") eq(W.db.drive.opts.cutRule, "equal")
	T.clean(w)
end)

test("drive.cut: rule maths: 40 % of 5g to the caster, the rest by 9/8 clicks; silver flooring, remainder to the runner", function()
	local W, w = T.contract("Drive.Cut", "tests/drive/cut_test.lua", {})
	local split = W.Drive.CutSplit
	local s = split(50000, { a = 5 }, { b = 9, c = 8 }, "clicks", 40, "r")
	eq(s.a, 20000, "40 % of 5g")
	eq(s.b, 15800, "9/17 of 3g, floored to silver")
	eq(s.c, 14100, "8/17 of 3g, floored to silver")
	eq(s.r, 100, "the runner gets what flooring left")
	s = split(50000, { a = 5 }, { b = 9, c = 8 }, "clicks", 40, "a")
	eq(s.a, 20100, "the runner who cast keeps the remainder too")
	-- two casters share theirs by casts
	s = split(100000, { a = 3, b = 1 }, { c = 4 }, "clicks", 40, "a")
	eq(s.a, 30000) eq(s.b, 10000) eq(s.c, 60000)
	-- nobody clicked: all of it by casts; nobody cast: all by clicks; nothing at all: the runner
	s = split(10000, { a = 1 }, {}, "clicks", 40, "r")
	eq(s.a, 10000)
	s = split(10000, {}, { b = 1 }, "clicks", 40, "r")
	eq(s.b, 10000)
	s = split(10000, {}, {}, "clicks", 40, "r")
	eq(s.r, 10000)
	-- equal: everyone with a cast or a click the same
	s = split(50000, { a = 4 }, { b = 1, c = 9 }, "equal", 40, "a")
	eq(s.b, 16600) eq(s.c, 16600) eq(s.a, 16800, "16600 + the 200 left over")
	s = split(10000, { a = 1 }, { b = 0 }, "equal", 40, "r")
	eq(s.a, 10000, "a zero tally is nobody")
	eq(s.b, nil)
	-- 0 % and 100 % to the casters
	s = split(10000, { a = 1 }, { b = 1 }, "clicks", 0, "r")
	eq(s.a or 0, 0) eq(s.b, 10000)
	s = split(10000, { a = 1 }, { b = 1 }, "clicks", 100, "r")
	eq(s.a, 10000) eq(s.b or 0, 0)
	T.clean(w)
end)

test("drive.cut: a 3-window crew, 5 summons: casts, clicks and gold the same in every window; the split and the log", function()
	local w, ana, bea, cal = team({ "Dan Miller", "Eve Moss" })
	-- Ana casts 3, Bea 2; the other two click each time; one summon fails (no cast counted)
	summon(w, "Dan Miller", ana, { bea, cal })
	summon(w, "Eve Moss", ana, { bea, cal })
	summon(w, "Dan Miller", bea, { ana, cal })
	summon(w, "Eve Moss", bea, { ana, cal })
	summon(w, "Dan Miller", ana, { bea, cal })
	summon(w, "Eve Moss", ana, { bea, cal }, false)
	ana.W.Drive.Do("PAID", "Dan Miller", 30000)
	bea.W.Drive.Do("PAID", "Eve Moss", 20000)
	w:advance(1)
	for _, c in ipairs({ ana, bea, cal }) do
		local rows, rule, info = rowsOf(c)
		local who = c.player.name .. ": "
		eq(rule, "clicks", who .. "rule")
		eq(info.gold, 50000, who .. "the crew's takings")
		eq(rows[ANA].casts, 3, who .. "Ana's casts (the failed one doesn't count)")
		eq(rows[BEA].casts, 2, who .. "Bea's casts")
		eq(rows[CAL].casts, 0, who .. "Cal never cast")
		eq(rows[ANA].clicks, 2, who .. "Ana's clicks")
		eq(rows[BEA].clicks, 4, who .. "Bea's clicks")
		eq(rows[CAL].clicks, 6, who .. "Cal's clicks")
		-- 40 % = 2g by casts 3:2 (12000, 8000); 3g by clicks 2:4:6 (5000, 10000, 15000)
		eq(rows[ANA].share, 17000, who .. "Ana's share")
		eq(rows[BEA].share, 18000, who .. "Bea's share")
		eq(rows[CAL].share, 15000, who .. "Cal's share")
	end
	local text = ana.W.Drive.CutText()
	eq(text, "Shift split: Bea 1g 80s, Ana 1g 70s, Cal 1g 50s")
	eq(ana.W.SpamReason(text), nil, "passes the spam check")
	ok(not text:lower():find("gold"), "never the word")
	-- equal
	ana.W.Drive.SetOpt("cutRule", "equal")
	local rows = rowsOf(ana)
	eq(rows[ANA].share + rows[BEA].share + rows[CAL].share, 50000)
	eq(rows[CAL].share, 16600, "a third, floored")
	eq(rows[ANA].share, 16800, "the runner takes the remainder")
	ana.W.Drive.SetOpt("cutRule", "clicks")
	-- closing logs the shift once in every window
	ana.W.Drive.SetOpen(false)
	w:advance(3)
	for _, c in ipairs({ ana, bea, cal }) do
		local log = c.W.Drive.CutLog()
		eq(#log, 1, c.player.name .. ": one cut line")
		local e = log[1]
		eq(e.gold, 50000)
		eq(e.casts[ANA], 3) eq(e.clicks[CAL], 6)
		eq(e.rule, "clicks") eq(e.pct, 40)
	end
	-- after closing the card still shows the shift that ended
	eq(rowsOf(ana)[ANA].casts, 3)
	-- a new shift starts from zero
	w:advance(5)
	ana.W.Drive.SetOpen(true)
	w:advance(3)
	local _, _, _, list = rowsOf(ana)
	eq(#list, 0, "a new shift: nothing yet")
	T.clean(w)
end)

test("drive.cut: before the 2.3.0 version bump the shift log is dormant: the tallies count, nothing is saved", function()
	local w, ana, bea, cal = team({ "Dan Miller" }, "2.2.3")
	summon(w, "Dan Miller", ana, { bea, cal })
	local rows = rowsOf(ana)
	eq(rows[ANA] and rows[ANA].casts, 1, "the live tally counts")
	ana.W.Drive.SetOpen(false)
	w:advance(3)
	for _, c in ipairs({ ana, bea, cal }) do eq(c.W.db.drive.log.cut, nil, c.player.name .. ": no cut log saved") end
	T.clean(w)
end)

test("drive.cut: HELP outside a summon, twice in one summon, or from the caster counts nothing; an old HELP counts the sender", function()
	local w, ana, bea, cal = team({ "Dan Miller" })
	bea.W.Drive.Do("HELP", "Dan Miller") -- no summon running
	w:advance(1)
	ana.W.Drive.Do("CAST", "Dan Miller")
	w:advance(1)
	bea.W.Drive.Do("HELP", "Dan Miller")
	bea.W.Drive.Do("HELP", "Dan Miller")
	ana.W.Drive.Do("HELP", "Dan Miller") -- the caster itself
	w:advance(1)
	-- a pre-2.3 HELP (no field 2) from a crew window still counts its sender
	cal.W.Drive.Send("HELP", "Dan Miller")
	w:advance(1)
	for _, c in ipairs({ ana, bea }) do
		local rows = rowsOf(c)
		eq(rows[BEA].clicks, 1, c.player.name .. ": Bea once")
		eq(rows[ANA] and rows[ANA].clicks or 0, 0, c.player.name .. ": the caster's own click is no click")
	end
	eq(rowsOf(ana)[CAL].clicks, 1, "Cal's old-style HELP")
	T.clean(w)
end)

test("drive.cut: a helper without Wuber: the caster's window names them (HELP field 2), every window counts them", function()
	local w, ana, bea, cal = team({ "Dan Miller", "Bob Helper" })
	local dr = ana.W.Drive
	-- a rider in the group is summoned: Ana's own click casts
	dr.Do("ADD", "Dan Miller")
	w:advance(1)
	w:player(ANA).target = w:player("Dan Miller")
	w:cast(ana, w.ritualName)
	w:advance(1)
	eq(dr.customers[key("Dan Miller")].state, "summoning")
	ok(dr.cast and dr.cast.channel, "Ana channels")
	-- Bob (no Wuber) clicks: Ana's window sees his party unit channel and holds 2 s
	local bob = w:player("Bob Helper")
	w:unitEvent(bob, "UNIT_SPELLCAST_CHANNEL_START", "Help-Bob", 698)
	w:advance(2.5)
	w:unitEvent(bob, "UNIT_SPELLCAST_CHANNEL_STOP", "Help-Bob", 698)
	w:advance(1)
	local help
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.from == ANA and e.text:match("^HELP~") then help = e.text end
	end
	eq(help, "HELP~1~Dan Miller~Bob Helper", "HELP names the helper")
	ok(#help <= 60, "HELP <= 60 bytes")
	for _, c in ipairs({ ana, bea, cal }) do
		eq(rowsOf(c)["Bob Helper"] and rowsOf(c)["Bob Helper"].clicks, 1, c.player.name .. ": Bob's click")
	end
	-- a short tap (under 2 s) is no click; a crew Warlock's channel is never a helper
	bea.W.Drive.Do("END", "Dan Miller", 0)
	w:advance(1)
	T.clean(w)
end)

test("drive.cut: HELP field 2 believed only from the caster's window, for a group member, during the summon", function()
	local w, ana, bea, cal = team({ "Dan Miller", "Bob Helper" })
	ana.W.Drive.Do("CAST", "Dan Miller")
	w:advance(1)
	-- Bea is not the caster (nor the leader): her named helper is ignored
	bea.W.Drive.Do("HELP", "Dan Miller", "Bob Helper")
	-- a name outside the group is ignored even from the caster
	ana.W.Drive.Do("HELP", "Dan Miller", "Zed Stranger")
	-- the rider can't help their own summon
	ana.W.Drive.Do("HELP", "Dan Miller", "Dan Miller")
	w:advance(1)
	for _, c in ipairs({ ana, cal }) do
		local rows = rowsOf(c)
		eq(rows["Bob Helper"], nil, c.player.name .. ": no Bob")
		eq(rows["Zed Stranger"], nil, c.player.name .. ": no stranger")
		eq(rows["Dan Miller"], nil, c.player.name .. ": the rider isn't a helper")
	end
	ana.W.Drive.Do("HELP", "Dan Miller", "Bob Helper")
	w:advance(1)
	eq(rowsOf(cal)["Bob Helper"].clicks, 1, "from the caster: counted")
	eq(rowsOf(cal)["Bob Helper"].casts, 0, "a helper never adds casts")
	T.clean(w)
end)

test("drive.cut: the share line stays within 240 characters", function()
	local W, w = T.contract("Drive.Cut", "tests/drive/cut_test.lua", {})
	local DR = W.Drive
	DR.Do = function() end
	local cut = DR.cut
	-- a forced shift with eight long names
	local l = W.db.drive.log
	l.shift = { start = 1, seen = 1 }
	DR.Selling = function() return true end
	DR.ShiftCheck = function() end
	DR.CutTick()
	for i = 1, 8 do
		local k = "helper" .. i
		cut.names[k] = "Abcdefghijklmnopqrstuvwx" .. i .. " Surname"
		cut.clicks[k] = i
	end
	cut.gold = 99999999
	local text = DR.CutText()
	ok(text and #text <= 240, "at most 240: " .. tostring(text and #text))
	ok(text:find("^Shift split: "), text)
	T.clean(w)
end)
