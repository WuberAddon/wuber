-- Wuber 2.3.0 round nine, agent D (driver features, BRIEF9 "D"): the ride passphrase setting (off by
-- default), the "Get Wuber" reply (Y1), the customer book (Y3) and its sync between the driver's own crew
-- windows. Loaded by run.lua with the round-six helpers. Test names start "r9 driver:".

local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, clean = T.newWorld, T.clean

local ANA, BEA, CAL, TESTCHAR = "Ana Smith", "Bea Jones", "Cal Brown", "Wuber TestCharacter"
local SPOT = "Undercity"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- saved data for one window of a crew (captain: the first name)
local function crewSaved(me, names, captain)
	local crew = {}
	for _, n in ipairs(names) do
		if n ~= me then crew[#crew + 1] = { name = n, role = "lock", app = true } end
	end
	return { chars = { [key(me)] = { crew = crew, captain = (me == captain) and "" or captain, wizard = true } } }
end

-- a crew of Warlocks in one group (the first is the captain)
local function crew(names, o)
	o = o or {}
	local w = o.world or newWorld()
	local cs = {}
	for i, name in ipairs(names) do
		cs[i] = w:addClient(name, { spot = SPOT, class = "WARLOCK", saved = { Wuber = crewSaved(name, names, names[1]) } })
	end
	if o.group ~= false then w:group(names) end
	w:advance(15)
	return w, cs
end

-- the last addon message of a kind from a player (on any channel)
local function last(w, prefix, from, pat)
	local found
	for _, e in ipairs(w.addonLog) do
		if e.prefix == prefix and e.from == from and e.text:match(pat) then found = e end
	end
	return found
end

local function lastD(w)
	local list = T.msgs(w, "D", ANA, "CHANNEL")
	return list[#list]
end

---------------------------------------------------------------------------
-- The ride passphrase: off by default (the author), D field 19, the captain's CFG field 12
---------------------------------------------------------------------------

test("r9 driver: passphrase - off by default: no D field 19, riders' entry has no showPass", function()
	local w = newWorld()
	local d = T.driver(w, ANA, { spot = SPOT })
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	w:advance(6)
	local W, DR = d.W, d.W.Drive
	eq(W.PassphraseOn(), false, "off by default")
	eq(W.db.drive.opts.showPass, nil, "nothing saved until the driver changes it")
	local e = lastD(w)
	ok(e, "a D beacon")
	local f = T.fields(e)
	eq(f[21], nil, "no field 19 (" .. e.text .. ")")
	local dr = r.W.drivers[key(ANA)]
	ok(dr, "the rider lists the driver")
	eq(dr and dr.showPass, nil, "showPass off")
	-- on: the beacon carries "1" in field 19, the rider's entry says showPass
	DR.SetOpt("showPass", true)
	eq(W.PassphraseOn(), true, "on")
	w:advance(8)
	e = lastD(w)
	f = T.fields(e)
	eq(f[21], "1", "field 19 = 1 (" .. e.text .. ")")
	ok(#e.text <= 250, "the beacon fits")
	eq(r.W.drivers[key(ANA)].showPass, true, "the rider's entry: showPass")
	-- off again: the next beacon has no field 19
	DR.SetOpt("showPass", false)
	w:advance(8)
	e = lastD(w)
	eq(T.fields(e)[21], nil, "off: no field 19")
	eq(r.W.drivers[key(ANA)].showPass, nil, "the rider's entry: off again")
	clean(w)
end)

test("r9 driver: passphrase - an old driver's beacon (no field 19) is off; garbage is off", function()
	local w = newWorld()
	local d = T.driver(w, ANA, { spot = SPOT })
	local r = T.rider(w, TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	w:advance(6)
	local DR = d.W.Drive
	DR.SetOpt("showPass", true)
	w:advance(8)
	eq(r.W.drivers[key(ANA)].showPass, true, "on")
	-- a field 19 that isn't "1" is off
	d.W.Drive.NetBeacon = (function(nb) return function() local b = nb() if b then b.showPass = "yes" end return b end end)(d.W.Drive.NetBeacon)
	w:advance(8)
	eq(r.W.drivers[key(ANA)].showPass, nil, "a showPass that isn't true is not sent")
	clean(w)
end)

test("r9 driver: passphrase - crew windows follow the captain's setting (CFG field 12), only the captain's", function()
	local w, cs = crew({ ANA, BEA, CAL })
	local ana, bea, cal = cs[1], cs[2], cs[3]
	eq(bea.W.PassphraseOn(), false, "off by default on a member")
	local cfg = last(w, "WUBERT", ANA, "^CFG~")
	if cfg then eq(T.fields(cfg)[14], nil, "an off CFG is as before (no field 12)") end
	-- a member's own setting is not what counts
	bea.W.Drive.SetOpt("showPass", true)
	w:advance(2)
	eq(bea.W.PassphraseOn(), false, "a member follows its captain, not its own setting")
	eq(cal.W.PassphraseOn(), false, "a CFG field 12 from a member (not the captain) is ignored")
	-- the captain turns it on: every window follows
	ana.W.Drive.SetOpt("showPass", true)
	w:advance(3)
	cfg = last(w, "WUBERT", ANA, "^CFG~")
	ok(cfg, "the captain's CFG")
	eq(T.fields(cfg)[14], "1", "CFG field 12 = 1 (" .. cfg.text .. ")")
	eq(ana.W.PassphraseOn(), true, "captain on")
	eq(bea.W.PassphraseOn(), true, "Bea follows")
	eq(cal.W.PassphraseOn(), true, "Cal follows")
	ana.W.Drive.SetOpt("showPass", false)
	w:advance(3)
	eq(bea.W.PassphraseOn(), false, "Bea follows off")
	eq(cal.W.PassphraseOn(), false, "Cal follows off")
	clean(w)
end)

test("r9 driver: passphrase - a crew window's switch is greyed, says it follows the captain, and a click changes nothing", function()
	local w, cs = crew({ ANA, BEA })
	local ana, bea = cs[1], cs[2]
	ana.W.Drive.SetOpt("showPass", true)
	w:advance(10)
	eq(bea.W.PassphraseOn(), true, "Bea follows Ana")
	bea.W.UI.Toggle(true)
	w:advance(2)
	bea.W.UI.OpenSettings("driving")
	w:advance(2)
	local st = bea.W.Mod("UI.Settings.Rows").st
	local t = st.controls["drive.showPass"]
	ok(t, "the switch")
	eq(t.on, true, "shows the captain's setting")
	ok(t:GetAlpha() < 0.5, "greyed")
	ok(t.row.desc:GetText():find("captain", 1, true), "says it follows the captain: " .. tostring(t.row.desc:GetText()))
	-- the player scrolls the settings list to the switch first
	ok(bea:scrollIntoView(t), "the switch scrolls into view")
	bea:click(t)
	w:advance(1)
	eq(bea.W.Drive.Opt("showPass"), false, "a crew window's own setting is not changed")
	eq(t.on, true, "the switch snaps back to the captain's")
	w:advance(1)
	eq(t.pos, 1, "and so does its knob (the click's slide is turned back, not left running)")
	-- the captain's own switch is live
	ana.W.UI.Toggle(true)
	w:advance(2)
	ana.W.UI.OpenSettings("driving")
	w:advance(2)
	local ta = ana.W.Mod("UI.Settings.Rows").st.controls["drive.showPass"]
	eq(ta:GetAlpha(), 1, "the captain's is not greyed")
	ok(ana:scrollIntoView(ta), "the captain's switch scrolls into view")
	ana:click(ta)
	w:advance(1)
	eq(ana.W.Drive.Opt("showPass"), false, "the captain turns it off")
	clean(w)
end)
