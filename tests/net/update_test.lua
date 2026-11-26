-- Tests of Net.Update (round 11): "a newer Wuber is out". Loaded by tests/run.lua with its
-- helper table T. Parsing and comparing versions; who is believed (the founder alone on the founders'
-- ruleset, else two different players; never a name in a payload); the cap on remembered players;
-- the saved field (small, cleared once up to date); the toast (once per session, only when idle,
-- off with the setting); Settings' rows (the toggle, the read-only address) and its search.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local ANITA, TESTCHAR, BOB, BEA, CAL = T.ANITA, T.TESTCHAR, T.BOB, T.BEA, T.CAL

local NOTE = "Wuber 2.3.1 is out. Get it on CurseForge."

-- a driver's beacon over the channel saying version ver (field 11); more = text after it
local function beacon(w, from, ver, service, more)
	w:inject(from, "D~1~Ratchet~1413~500~500~5000~" .. (service or "") .. "~open~1~0~~" .. ver .. (more or ""), "CHANNEL")
	w:advance(0.5)
end

-- a rider (Wuber) on the network, every toast recorded
local function setup(opts)
	opts = opts or {}
	local w = T.newWorld({ realm = T.H.FOUNDER_REALM })
	-- a released build's number (this build says "2.3.2-dev", PLAN-2.3.2: the notice is off for it)
	local r = T.rider(w, TESTCHAR, { saved = opts.saved, version = opts.ver or "2.3.0" })
	if opts.realm then r.realm = opts.realm end
	T.settle(w)
	local toasts = {}
	local UI = r.W.UI
	local real = UI.Toast
	UI.Toast = function(text, kind, fn)
		toasts[#toasts + 1] = { text = text, kind = kind, fn = fn }
		return real(text, kind, fn)
	end
	return w, r, r.W.Mod("Net.Update"), toasts
end

-- nothing Wuber sent carries the versions heard (no new traffic)
local function noneSent(w, what)
	for _, e in ipairs(w.addonLog) do
		if e.from == TESTCHAR then
			ok(not tostring(e.text):find("2.3.1", 1, true) and not tostring(e.text):find("2.4.0", 1, true),
				what .. ": nothing sent about it: " .. tostring(e.text))
		end
	end
end

test("net.update: contract (registered, deps, header, public names); idle: nothing saved or shown", function()
	local W, w, r, Mod = T.contract("Net.Update", "tests/net/update_test.lua", {
		["W.ParseVersion"] = "function", ["W.CompareVersions"] = "function", ["W.HeardVersion"] = "function",
		["W.NewerVersion"] = "function", ["W.UPDATE_URL"] = "string",
		["Mod.count"] = "function", ["Mod.shown"] = "function", ["Mod.tryNotice"] = "function", ["Mod.U"] = "table",
	})
	eq(W.UPDATE_URL, "curseforge.com/wow/addons/wuber", "the address")
	eq(W.NewerVersion(), nil, "nothing newer known")
	eq(W.db.newer, nil, "nothing saved")
	eq(W.db.updateNotes, nil, "the setting: nil = on (no saved default)")
	eq(Mod.shown(), false, "no toast")
	eq(Mod.tryNotice(), false, "nothing to tell")
	T.clean(w)
end)

test("net.update: parsing - three parts of digits, each 0..99; compare is numeric (2.10.0 > 2.9.0)", function()
	local W, w = T.contract("Net.Update", "tests/net/update_test.lua", {})
	for _, g in ipairs({ { "2.3.1", "2.3.1", 20301 }, { "0.0.0", "0.0.0", 0 }, { "99.99.99", "99.99.99", 999999 },
		{ "2.10.0", "2.10.0", 21000 }, { "02.3.01", "2.3.1", 20301 } }) do
		local v, n = W.ParseVersion(g[1])
		eq(v, g[2], "good: " .. g[1])
		eq(n, g[3], "as a number: " .. g[1])
	end
	for _, s in ipairs({ "", "2.3", "2.3.1.4", "2.3.x", "v2.3.1", "2.3.1-beta", " 2.3.1", "2.3.1 ", "100.0.0", "2.300.1",
		"2..1", ".2.3", "2.3.", "-2.3.1", "2,3,1", "2.3.1\n", "1e2.3.1", "2.3.1.", "\239\188\146.3.1", "2.3.1~9.9.9" }) do
		eq(W.ParseVersion(s), nil, "bad: '" .. s .. "'")
	end
	eq(W.ParseVersion(nil), nil, "nil")
	eq(W.ParseVersion({}), nil, "a table")
	eq(W.CompareVersions("2.10.0", "2.9.0"), 1, "2.10.0 > 2.9.0")
	eq(W.CompareVersions("2.9.0", "2.10.0"), -1, "2.9.0 < 2.10.0")
	eq(W.CompareVersions("2.3.0", "2.3.0"), 0, "the same")
	eq(W.CompareVersions("3.0.0", "2.99.99"), 1, "a major beats any minor")
	eq(W.CompareVersions("2.3.1", "junk"), nil, "not a version: no answer")
	eq(W.HeardVersion("bob stone", "junk"), false, "junk is ignored")
	eq(W.HeardVersion("bob stone", "2.3.0"), false, "our own version: not counted")
	eq(W.HeardVersion("bob stone", "2.2.9"), false, "older: not counted")
	eq(W.HeardVersion(W.myKey, "2.4.0"), false, "our own key: never counted")
	eq(W.HeardVersion(nil, "2.4.0"), false, "no sender: not counted")
	eq(W.Mod("Net.Update").count(), 0, "nobody remembered")
	T.clean(w)
end)

test("net.update: the founder's beacon alone is trusted; saved small; one toast; nothing sent", function()
	local w, r, Mod, toasts = setup()
	beacon(w, ANITA, "2.3.1")
	eq(r.W.NewerVersion(), "2.3.1", "trusted from the founder alone")
	local s = r.W.db.newer
	eq(s and s.ver, "2.3.1", "saved")
	ok(s and type(s.at) == "number" and s.at > 0, "with when it was seen")
	local n = 0
	for _ in pairs(s or {}) do n = n + 1 end
	eq(n, 2, "one small table: ver and at")
	eq(Mod.count(), 0, "the founder isn't kept as a reporter")
	w:advance(6)
	eq(#toasts, 1, "one toast")
	eq(toasts[1] and toasts[1].text, NOTE, "its words")
	eq(toasts[1] and toasts[1].kind, "update", "the quiet kind (no sound)")
	ok(#r:findText(NOTE, false, true) > 0, "on screen")
	noneSent(w, "founder")
	-- a click opens Help at the address (Settings diet: the address is at the end of Help)
	toasts[1].fn()
	w:advance(1)
	ok(r.W.UI.HelpShown(), "the toast's click opens Help, where the address is")
	T.clean(w)
end)

test("net.update: Anita Lift's name on another ruleset is just one player", function()
	local w, r, Mod, toasts = setup({ realm = "CAMWOW US2 Realm 1 PvP" })
	beacon(w, ANITA, "2.3.1")
	eq(r.W.NewerVersion(), nil, "not the founder here: one player is not enough")
	eq(Mod.count(), 1, "remembered as one player")
	w:advance(10)
	eq(#toasts, 0, "no toast")
	T.clean(w)
end)

test("net.update: one player is not enough (nor twice); two different players are; older ones don't count", function()
	local w, r, Mod, toasts = setup()
	beacon(w, BOB, "2.3.1")
	eq(r.W.NewerVersion(), nil, "one player: not trusted")
	beacon(w, BOB, "2.4.0")
	eq(r.W.NewerVersion(), nil, "the same player again: still one")
	eq(Mod.count(), 1, "one remembered")
	beacon(w, "Bob Stone-CAMWOW EU4 Realm 5", "2.4.0")
	eq(r.W.NewerVersion(), nil, "the same player with his realm spelled out: still one")
	eq(Mod.count(), 1, "still one remembered")
	beacon(w, BEA, "2.2.9")
	eq(Mod.count(), 1, "an older version isn't remembered")
	eq(r.W.NewerVersion(), nil, "still not trusted")
	w:advance(10)
	eq(#toasts, 0, "no toast yet")
	beacon(w, CAL, "2.3.2")
	eq(r.W.NewerVersion(), "2.3.2", "two players said 2.3.2 or higher: 2.3.2 (not Bob's 2.4.0)")
	eq(r.W.db.newer.ver, "2.3.2", "saved")
	w:advance(6)
	eq(#toasts, 1, "one toast")
	eq(toasts[1] and toasts[1].text, "Wuber 2.3.2 is out. Get it on CurseForge.", "its words")
	noneSent(w, "two players")
	T.clean(w)
end)

test("net.update: a forged founder name in a payload never counts as the founder", function()
	local w, r, Mod = setup()
	-- Bob's beacon names Anita Lift as its service and as its summoner (field 17)
	beacon(w, BOB, "2.3.1", "Anita Lift", "~~~~~~Anita Lift")
	eq(r.W.NewerVersion(), nil, "Bob is one player, whatever his beacon says")
	eq(Mod.count(), 1, "counted once, as Bob")
	-- a request from Bob whose destination is the founder's name
	w:inject(BOB, "R~1~AbCdEf~Anita Lift~5000~0~1~2.3.1", "WHISPER", r)
	w:advance(0.5)
	eq(r.W.NewerVersion(), nil, "still Bob alone")
	eq(Mod.count(), 1, "still one player")
	T.clean(w)
end)

test("net.update: ride requests (R field 6) and crew hellos (HI field 3) count too", function()
	local w = T.newWorld()
	local d = T.driver(w, BOB, { netOnly = true })
	d.W.VERSION = "2.3.0" -- a released build (a "-dev" build hears nothing)
	T.settle(w)
	T.goOnline(d)
	w:inject(CAL, "R~1~AbCdEf~Ratchet~5000~0~1~2.3.1", "WHISPER", d)
	w:advance(0.5)
	eq(d.W.Mod("Net.Update").count(), 1, "R field 6: one player")
	eq(d.W.NewerVersion(), nil, "one is not enough")
	w:inject(BEA, "R~1~XyZxyZ~Ratchet~5000~0~1~2.3.1", "WHISPER", d)
	w:advance(0.5)
	eq(d.W.NewerVersion(), "2.3.1", "two riders said it")
	T.clean(w)
	-- crew: two Warlocks on 2.3.1 in Bob's group say hello
	local w2 = T.newWorld()
	local b = T.driver(w2, BOB)
	local c = T.driver(w2, CAL)
	local e = T.driver(w2, BEA)
	c.W.VERSION, e.W.VERSION = "2.3.1", "2.3.1"
	b.W.VERSION = "2.3.0"
	T.settle(w2)
	w2:group({ BOB, CAL, BEA })
	w2:advance(20)
	eq(b.W.NewerVersion(), "2.3.1", "HI from two crew windows (heard: " .. b.W.Mod("Net.Update").count() .. ")")
	T.clean(w2)
end)

test("net.update: at most 50 players remembered; reports older than 24 h are dropped", function()
	local w, r, Mod = setup()
	local W = r.W
	for i = 1, 60 do W.HeardVersion("player" .. i, "2.3." .. (i % 9 + 1)) end
	eq(Mod.count(), 50, "the cap holds")
	local n = 0
	for _ in pairs(W.db.newer or {}) do n = n + 1 end
	eq(n, 2, "the saved part is still one small table")
	ok(W.NewerVersion() ~= nil, "trusted (many players)")
	-- reports expire (24 h; shortened here)
	Mod.U.KEEP = 5
	w:advance(6)
	W.HeardVersion("someone new", "2.3.1")
	eq(Mod.count(), 1, "the old reports went")
	T.clean(w)
end)

test("net.update: saved across a relog; cleared once this copy is up to date; junk cleared", function()
	local w, r, Mod, toasts = setup({ saved = { Wuber = { newer = { ver = "2.3.1", at = H.EPOCH - 86400 } } } })
	eq(r.W.NewerVersion(), "2.3.1", "kept from the last session")
	w:advance(8) -- 20 s after login
	eq(#toasts, 1, "shown again after the relog")
	eq(toasts[1] and toasts[1].text, NOTE, "its words")
	r.W.VERSION = "2.3.1"
	eq(r.W.NewerVersion(), nil, "updated: nothing newer")
	eq(r.W.db.newer, nil, "the saved field is cleared")
	T.clean(w)
	local w2, r2, _, toasts2 = setup({ saved = { Wuber = { newer = { ver = "2.3.0", at = H.EPOCH } } } })
	eq(r2.W.db.newer, nil, "the same version as ours: cleared at login")
	w2:advance(10)
	eq(#toasts2, 0, "no toast")
	T.clean(w2)
	local w3, r3 = setup({ saved = { Wuber = { newer = "2.9.9" } } })
	eq(r3.W.db.newer, nil, "not a table: cleared")
	eq(r3.W.NewerVersion(), nil, "nothing")
	T.clean(w3)
	local w4, r4 = setup({ saved = { Wuber = { newer = { ver = "2.9.9 beta", at = H.EPOCH } } } })
	eq(r4.W.db.newer, nil, "not a version: cleared")
	T.clean(w4)
	-- not heard again for 15 days: forgotten (a forged version dies out)
	local w5, r5, _, toasts5 = setup({ saved = { Wuber = { newer = { ver = "2.9.9", at = H.EPOCH - 15 * 86400 } } } })
	eq(r5.W.db.newer, nil, "15 days old: cleared")
	w5:advance(10)
	eq(#toasts5, 0, "no toast")
	T.clean(w5)
	-- heard again: kept another 14 days
	local w6, r6 = setup({ saved = { Wuber = { newer = { ver = "2.3.1", at = H.EPOCH - 13 * 86400 } } } })
	eq(r6.W.NewerVersion(), "2.3.1", "13 days old: still kept")
	beacon(w6, ANITA, "2.3.1")
	ok(r6.W.db.newer.at >= H.EPOCH, "the founder said it again: its time is renewed")
	T.clean(w6)
	-- the setting off: a saved version shows no toast at login
	local w7, r7, _, toasts7 = setup({ saved = { Wuber = { updateNotes = false, newer = { ver = "2.3.1", at = H.EPOCH } } } })
	w7:advance(15)
	eq(#toasts7, 0, "off: no toast after the relog")
	eq(r7.W.NewerVersion(), "2.3.1", "still known")
	T.clean(w7)
end)

test("net.update: shown once per session", function()
	local w, r, Mod, toasts = setup()
	r.W.HeardVersion("bob stone", "2.3.1")
	r.W.HeardVersion("bea moon", "2.3.1")
	w:advance(6)
	eq(#toasts, 1, "shown")
	ok(Mod.shown(), "Mod.shown")
	beacon(w, ANITA, "2.3.2")
	eq(r.W.NewerVersion(), "2.3.2", "a newer one is trusted and saved")
	w:advance(30)
	eq(#toasts, 1, "but no second toast this session")
	eq(Mod.tryNotice(), false, "asked again: no")
	T.clean(w)
end)

test("net.update: waits for the end of combat, of a ride, and of summoning", function()
	local w, r, Mod, toasts = setup()
	local W = r.W
	w:enterCombat(r)
	beacon(w, ANITA, "2.3.1")
	w:advance(30)
	eq(#toasts, 0, "not in combat")
	w:leaveCombat(r)
	-- on a ride (asked straight away: a faked ride must not reach the ride's own timers)
	local rideActive = W.RideActive
	W.RideActive = function() return true end
	eq(Mod.tryNotice(), false, "not during a ride")
	W.RideActive = rideActive
	eq(#toasts, 0, "no toast during the ride")
	-- summoning (a driver serving riders)
	local DR = W.Drive
	local busy = DR.Busy
	DR.Busy = function() return true end
	eq(Mod.tryNotice(), false, "not while summoning")
	DR.Busy = busy
	eq(#toasts, 0, "no toast while summoning")
	-- a rider asking (a driver's W.incoming)
	W.incoming[#W.incoming + 1] = { id = "AbCdEf", buyerKey = "bob stone", state = "new", at = W.Now() }
	eq(Mod.tryNotice(), false, "not while a rider is asking")
	table.remove(W.incoming)
	-- another toast on screen
	W.UI.Toast("Something else", "info")
	eq(Mod.tryNotice(), false, "not over another toast")
	eq(#toasts, 1, "only that other toast")
	w:advance(16)
	eq(#toasts, 2, "idle again: shown")
	eq(toasts[2] and toasts[2].text, NOTE, "its words")
	T.clean(w)
end)

test("net.update: a toast that couldn't show (the portal toast stays) is tried again", function()
	local w, r, Mod, toasts = setup()
	local UI = r.W.UI
	local recorder = UI.Toast
	UI.Toast = function(text, kind, fn)
		toasts[#toasts + 1] = { text = text, kind = kind, refused = true }
		return nil
	end
	beacon(w, ANITA, "2.3.1")
	w:advance(6)
	eq(#toasts, 1, "asked once, refused")
	eq(Mod.shown(), false, "not counted as shown")
	UI.Toast = recorder
	w:advance(16)
	eq(#toasts, 2, "tried again")
	eq(toasts[2] and toasts[2].text, NOTE, "and shown")
	ok(Mod.shown(), "now shown")
	T.clean(w)
end)

-- Settings open (folded), on the window's section when where = "window"
local function settings(r, w, where)
	r.W.db.coach = true
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.OpenSettings(where)
	w:advance(1)
	return r.W.UI.settings, r.W.Mod("UI.Settings.Find")
end

test("net.update: the setting off - no toast; /wuber updates off saves it, on turns it back on", function()
	local w, r, Mod, toasts = setup()
	-- (Settings diet) the row left Settings: the typed command is the switch
	r.W.SlashCommand("updates")
	eq(r.W.db.updateNotes, nil, "alone it changes nothing")
	r.W.SlashCommand("updates off")
	eq(r.W.db.updateNotes, false, "off, saved")
	beacon(w, ANITA, "2.3.1")
	w:advance(30)
	eq(#toasts, 0, "no toast while it is off")
	eq(r.W.NewerVersion(), "2.3.1", "still known (Settings says so)")
	r.W.SlashCommand("updates on")
	ok(r.W.db.updateNotes ~= false, "on again")
	w:advance(6)
	eq(#toasts, 1, "turned back on: the toast comes after all (once)")
	T.clean(w)
end)

test("net.update: Settings - the read-only address at the end of Help; the footer line", function()
	local w, r = setup()
	local st = settings(r, w)
	r.W.UI.OpenHelp("settings")
	w:advance(1)
	local f = st.help and st.help.urlBox
	ok(f, "the address box (Help page)")
	eq(f.edit:GetText(), "curseforge.com/wow/addons/wuber", "the address")
	f.edit:SetText("something else")
	f.edit:GetScript("OnTextChanged")(f.edit, true)
	eq(f.edit:GetText(), "curseforge.com/wow/addons/wuber", "typing changes nothing")
	ok(f.edit.wuberTip, "a tooltip on the box")
	ok(not st.about:GetText():find("is out", 1, true), "nothing newer: the usual footer")
	-- a newer version known: the footer says so
	beacon(w, ANITA, "2.3.1")
	r.W.UI.UpdateSettings()
	ok(st.about:GetText():find("Wuber 2.3.1 is out", 1, true), "the footer says so: " .. st.about:GetText())
	T.clean(w)
end)

---------------------------------------------------------------------------
-- PLAN-2.3.2 release rule (BRIEF15, agent A): internal builds say "2.3.2-dev". Every version gate
-- reads it as 2.3.2 (so at least 2.3.0); the update notice's strict a.b.c parse ignores it, ours
-- and a peer's.
---------------------------------------------------------------------------

local DEV = "2.3.2-dev"

test("release rule: this build's W.VERSION is a.b.c or a.b.c-dev, the TOC says the same, and the gates read -dev as its number", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	local W = r.W
	ok(W.VERSION:match("^%d+%.%d+%.%d+$") or W.VERSION:match("^%d+%.%d+%.%d+%-dev$"), "W.VERSION: " .. W.VERSION)
	local toc = T.readFile(T.dir .. "/../Wuber/Wuber.toc") or ""
	eq(toc:match("## Version: ([^\r\n]+)"), W.VERSION, "the TOC's ## Version is W.VERSION")
	eq(W.VerAtLeast(W.VERSION, "2.3.0"), true, "this build passes every 2.3.0 gate")
	for _, g in ipairs({ { DEV, "2.3.0", true }, { DEV, "2.3.2", true }, { DEV, "2.3.3", false }, { "2.3.0-dev", "2.3.0", true },
		{ "2.2.9-dev", "2.3.0", false }, { "2.10.0-dev", "2.9.0", true }, { "2.3.2-rc1", "2.3.0", true }, { "2.3.2-dev.2", "2.3.0", true },
		{ "2.3.2", "2.3.0", true }, { "2.3.0", "2.3.0", true }, { "2.2.3", "2.3.0", false } }) do
		eq(W.VerAtLeast(g[1], g[2]), g[3], g[1] .. " >= " .. g[2])
	end
	for _, bad in ipairs({ "2.3.2-", "-dev", "2.3.x", "2.3.2 dev", "2.3.2-dev-2", "2.3.2-dev~9", "dev", "", "2.3.2-1", "v2.3.2-dev" }) do
		eq(W.VerAtLeast(bad, "2.3.0"), false, "garbled: '" .. bad .. "'")
	end
	eq(W.VerAtLeast(nil, "2.3.0"), false, "nil")
	-- Drive.Kitchen's own parse (the live portal tracker)
	local d = T.driver(w, ANITA, { netOnly = true })
	T.settle(w)
	eq(d.W.Drive.RiderVersionOk(DEV), true, "Kitchen: a 2.3.2-dev rider gets G")
	eq(d.W.Drive.RiderVersionOk("2.2.9-dev"), false, "Kitchen: 2.2.9-dev is too old")
	T.clean(w)
end)

test("release rule: a 2.3.2-dev beacon and a 2.3.2-dev ride request count as 2.3.0 or later; a 2.3.0 driver serves a 2.3.2-dev rider the 2.3.0 way", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { netOnly = true })
	local r = T.rider(w)
	d.W.VERSION, r.W.VERSION = "2.3.0", DEV -- an older released driver, our dev rider
	T.settle(w)
	T.goOnline(d)
	local drv = r.W.drivers["anita lift"]
	ok(drv, "the rider hears the driver")
	local ride = r.W.RequestRide("anita lift")
	ok(ride, "a ride")
	w:advance(1)
	local f = T.fields(T.msgs(w, "R", TESTCHAR)[1])
	eq(f[8], DEV, "R field 6 says 2.3.2-dev")
	eq(d.W.incoming[1].riderVer, "2.3.2", "the driver keeps its number (digits and dots)")
	ok(d.W.AcceptRequest(ride.id, 5), "accepted")
	w:advance(1)
	eq(d.W.SendRitual(ride.id, TESTCHAR, "t", 0, 2, ANITA, 0), true, "the portal tracker's G goes to a 2.3.2-dev rider")
	T.clean(w)
	-- the other way: our 2.3.2-dev driver, a 2.3.0 rider; and our beacon's version field
	local w2 = T.newWorld()
	local d2 = T.driver(w2, ANITA, { netOnly = true })
	local r2 = T.rider(w2)
	d2.W.VERSION, r2.W.VERSION = DEV, "2.3.0"
	T.settle(w2)
	T.goOnline(d2)
	local D = T.msgs(w2, "D", ANITA, "CHANNEL")
	eq(T.fields(D[#D])[13], DEV, "the beacon says 2.3.2-dev")
	local heard = r2.W.drivers["anita lift"]
	eq(heard and heard.ver, "2.3.2", "the rider keeps its number (digits and dots)")
	local ride2 = r2.W.RequestRide("anita lift")
	w2:advance(1)
	ok(d2.W.AcceptRequest(ride2.id, 5), "accepted")
	w2:advance(1)
	eq(d2.W.SendRitual(ride2.id, TESTCHAR, "t", 0, 2, ANITA, 0), true, "a 2.3.0 rider gets G from a 2.3.2-dev driver")
	T.clean(w2)
end)

test("release rule: a suffix after '-' is cut before the digits are kept: a 2.3.3-rc1 beacon and ride request are 2.3.3, never 2.3.31", function()
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { netOnly = true })
	local r = T.rider(w)
	d.W.VERSION, r.W.VERSION = "2.3.3-rc1", "2.3.3-rc1"
	T.settle(w)
	T.goOnline(d)
	local heard = r.W.drivers["anita lift"]
	eq(heard and heard.ver, "2.3.3", "the rider keeps the driver's 2.3.3")
	local ride = r.W.RequestRide("anita lift")
	ok(ride, "a ride")
	w:advance(1)
	eq(d.W.incoming[1] and d.W.incoming[1].riderVer, "2.3.3", "the driver keeps the rider's 2.3.3")
	T.clean(w)
end)

test("release rule: the update notice ignores 2.3.2-dev, a peer's (beacon, R, HI) and our own", function()
	-- a released 2.3.0 window hears the founder and two players say 2.3.2-dev: nothing
	local w, r, Mod, toasts = setup()
	beacon(w, ANITA, DEV)
	eq(r.W.HeardVersion("bob stone", DEV), false, "a peer's -dev: not a version")
	eq(r.W.HeardVersion("bea jones", DEV), false)
	eq(r.W.NewerVersion(), nil, "nothing newer")
	eq(r.W.db.newer, nil, "nothing saved")
	eq(Mod.count(), 0, "nobody remembered")
	w:advance(30)
	eq(#toasts, 0, "no toast")
	noneSent(w, "a -dev peer")
	T.clean(w)
	-- our own window says 2.3.2-dev: the notice is off, whatever others say; nothing breaks
	local w2, r2, Mod2, toasts2 = setup({ ver = DEV, saved = { Wuber = { newer = { ver = "2.3.3", at = H.EPOCH } } } })
	eq(r2.W.ParseVersion(r2.W.VERSION), nil, "our version is not a.b.c")
	eq(r2.W.NewerVersion(), nil, "a saved notice is not shown to a dev build")
	beacon(w2, ANITA, "2.3.3")
	eq(r2.W.HeardVersion("bob stone", "9.9.9"), false, "nothing is counted")
	eq(r2.W.NewerVersion(), nil, "the founder's newer number: nothing")
	eq(Mod2.count(), 0, "nobody remembered")
	w2:advance(30)
	eq(#toasts2, 0, "no toast")
	eq(r2.W.lastError, nil, "no error: " .. tostring(r2.W.lastError))
	T.clean(w2)
	-- a crew HI saying 2.3.2-dev (field 3) to a released window: nothing either
	local w3 = T.newWorld()
	local b = T.driver(w3, BOB)
	local c = T.driver(w3, CAL)
	local e = T.driver(w3, BEA)
	b.W.VERSION, c.W.VERSION, e.W.VERSION = "2.3.0", DEV, DEV
	T.settle(w3)
	w3:group({ BOB, CAL, BEA })
	w3:advance(20)
	eq(b.W.NewerVersion(), nil, "two crew windows on 2.3.2-dev: nothing")
	eq(b.W.Mod("Net.Update").count(), 0)
	T.clean(w3)
end)
