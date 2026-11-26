-- Tests of the flight recorder's replay engine (tests/lib/rec_replay.lua): a session recorded in the
-- fake game with the recorder loaded, replayed with Wuber alone, shows what it showed when recorded;
-- a changed expectation is caught; odd rows replay without a Lua error; every committed fixture
-- replays (a "sim" one fully, a "game" one against tests/fixtures/rec/known-gaps.lua).
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.testOutside or T.test, T.eq, T.ok, T.H -- (testOutside: not in the behaviour transcript)
local RP = dofile(T.dir .. "/lib/rec_replay.lua")

if not RP.haveRecorder() then
	test("rec: replay skipped (" .. RP.ADDON.why() .. ")", function() end)
	return
end

local ROCKS = "Wuber Rocks"
local NODES = { { name = "Thunder Bluff, Mulgore", type = "CURRENT" }, { name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50 } }

-- The story (on the rider Wuber Rocks): login, /rec on, open Wuber, another tab and back, a driver
-- comes online in Orgrimmar, the flight map opens at Thunder Bluff (the bird card shows: see
-- tests/r26_f_bird_tb.lua), closes, /rec off.
local function story(w, add)
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local r = add(ROCKS, { spot = "Thunder Bluff", class = "MAGE", money = 100000, screenW = 1365, screenH = 768 })
	r:slash("/rec on")
	w:advance(15)
	r:slash("/wuber")
	w:advance(3)
	ok(r.W.UI.SelectTab("Trips"), "the Trips tab")
	w:advance(2)
	ok(r.W.UI.SelectTab("Ride"), "the Ride tab")
	w:advance(2)
	T.goOnline(d)
	w:advance(5)
	w:openTaxiMap(r, NODES)
	w:advance(3)
	w:closeTaxiMap(r)
	w:advance(3)
	r:slash("/rec off")
	T.clean(w)
	return r
end

local recorded
local function recording()
	if not recorded then
		local list = RP.record(T, story, "sim")
		eq(#list, 1, "one session")
		recorded = list[1]
	end
	return RP.copy(recorded)
end

local function report(rep)
	return table.concat(RP.lines(rep), "\n")
end

local function wuberSnaps(fx)
	local out = {}
	for _, s in ipairs(fx.snaps) do
		if s.id == "wuber" then out[#out + 1] = s end
	end
	return out
end

local function taxiTimes(fx)
	local open, close
	for _, e in ipairs(fx.events) do
		if e.e == "TAXIMAP_OPENED" then open = e.t end
		if e.e == "TAXIMAP_CLOSED" then close = e.t end
	end
	return open, close
end

test("rec: replay of a session recorded in the fake game matches every expectation", function()
	local fx = recording()
	eq(fx.kind, "rec")
	eq(fx.char, ROCKS)
	local rep = RP.replay(T, fx, { name = "story" })
	if os.getenv("WUBER_REC_DEBUG") then print(report(rep)) end
	ok(rep.total >= 100, "expectations: " .. rep.total)
	ok(rep.ok, report(rep))
	eq(#rep.errors, 0, "Lua errors")
	eq(rep.held, 0, "the fake made nothing the recording lacks")
	-- the phone opened and its tab, as the player did (inputs: open, Trips, Ride)
	local opened, trips = false, false
	for _, e in ipairs(rep.expectations) do
		if e.field == "open" and e.expected == true then opened = true end
		if e.field == "tab" and e.expected == "Trips" then trips = true end
	end
	ok(opened and trips, "the phone opened and showed Trips")
	local did = {}
	for _, i in ipairs(rep.inputs) do did[#did + 1] = i.field .. "=" .. tostring(i.v) end
	eq(table.concat(did, " "), "open=true tab=Trips tab=Ride", "the player's clicks done by the replay")
	-- the bird card: shown while the flight map is open, hidden after it closed
	local open, close = taxiTimes(fx)
	ok(open and close, "the flight map opened and closed")
	local during, after = 0, 0
	for _, e in ipairs(rep.expectations) do
		if e.field == "bird" and e.match then
			if e.t > open and e.t < close and e.got == true then during = during + 1 end
			if e.t > close and e.got == false then after = after + 1 end
		end
	end
	ok(during >= 1, "the bird card showed at the flight map")
	ok(after >= 1, "the bird card was hidden after it closed")
	-- the driver was heard from the recorded adverts alone (no driver window in the replay)
	eq(#rep.world.clients, 1, "one client")
	ok(rep.names[T.ANITA] ~= nil, "the driver is a bot of the same name")
	ok(rep.merged > 0, "the client's own channel echo was matched with the recording")
end)

test("rec: replay reports a changed expectation as a mismatch", function()
	local fx = recording()
	local open, close = taxiTimes(fx)
	local changed
	for _, s in ipairs(wuberSnaps(fx)) do
		if not changed and s.t > open and s.t < close and s.d.cards and s.d.cards.bird then
			s.d.cards.bird = nil -- "the card did not show"
			changed = s
		end
	end
	ok(changed, "a snapshot with the bird card")
	local rep = RP.replay(T, fx, { name = "changed" })
	eq(#rep.mismatches, 1, report(rep))
	local m = rep.mismatches[1]
	eq(m.id, "replay:bird")
	eq(m.t, changed.t)
	eq(m.expected, false)
	eq(m.got, true)
	ok(#m.before > 0 and m.before[#m.before]:find("TAXIMAP_OPENED", 1, true), "the events before it: " .. table.concat(m.before, ", "))
	ok(report(rep):find("MISMATCH replay:bird", 1, true), "in the report lines")
end)

test("rec: replay of unknown events, secret and dropped arguments", function()
	local fx = recording()
	local open = taxiTimes(fx)
	local t = open - 1
	local rows = {
		{ t = t, e = "FGA_UNKNOWN_TEST_EVENT", n = 1, a = { "LeftButton" } }, -- (fga) GLOBAL_MOUSE_DOWN is known to the fake now: a made-up name stands for an unknown event
		{ t = t, e = "REC_MARK", n = 1, a = { "a mark" } },
		{ t = t, e = "CHAT_MSG_SAY", n = 17, a = { { len = 14, w = false }, "P7", "<->", "", "P7", "<->", 0, 0, "", 0, 77, "<->" } },
		{ t = t, e = "CHAT_MSG_WHISPER", n = 17, a = { { len = 30, w = true }, "<secret>", "<->", "", "<secret>", "<->", 0, 0, "", 0, 78, "<->" } },
		{ t = t, e = "CHAT_MSG_SYSTEM", n = 1, a = { { gs = "ERR_CHAT_PLAYER_NOT_FOUND_S", a = { "P8" } } } },
		{ t = t, e = "CHAT_MSG_SYSTEM", n = 1, a = { { gs = "NO_SUCH_GAME_STRING", a = {} } } },
		{ t = t, e = "UNIT_SPELLCAST_SUCCEEDED", n = 3, a = { "player", "<->", 698 } },
		{ t = t, e = "GROUP_JOINED", n = 2, a = { 1, "<->" } },
		{ t = t, e = "CHAT_MSG_ADDON", n = 9, a = { "WUBER", "Q~1", "WHISPER", "<secret>", ROCKS, 0, 0, "", 0 } },
	}
	for _, r in ipairs(rows) do table.insert(fx.events, r) end
	table.sort(fx.events, function(a, b) return a.t < b.t end)
	local rep = RP.replay(T, fx, { name = "odd" })
	eq(#rep.errors, 0, "no Lua error: " .. table.concat(rep.errors, "\n"))
	eq(rep.unknownEvents.FGA_UNKNOWN_TEST_EVENT, 1, "an event the fake does not know is reported, not fired")
	eq(rep.unknownEvents.REC_MARK, nil, "the recorder's own mark row is not a game event")
	eq(#rep.marks, 1, "it is listed as a mark")
	ok(rep.secretArgs >= 3, "secret arguments: " .. tostring(rep.secretArgs))
	ok(rep.droppedArgs >= 6, "dropped arguments: " .. tostring(rep.droppedArgs))
	ok(rep.names.P7 and rep.names.P8, "P-numbers became bots")
	local nogs
	for _, c in ipairs(rep.cannot) do if c.what == "gs NO_SUCH_GAME_STRING" then nogs = c end end
	ok(nogs, "a game string the fake lacks is listed")
	-- the system line was the fake's own game string with the bot's name in it
	local seen
	for _, l in ipairs(rep.client.chatShown) do
		if l.event == "CHAT_MSG_SYSTEM" and tostring(l.text):find("P8", 1, true) then seen = l.text end
	end
	eq(seen, "No player named 'P8' is currently playing.", "the rebuilt system line")
	ok(rep.ok, report(rep))
	ok(table.concat(RP.lines(rep), "\n"):find("FGA_UNKNOWN_TEST_EVENT", 1, true), "in the report lines")
end)

test("rec: replay of the conformance scenes (login, reload, group, summon, trades) matches", function()
	local CF = dofile(T.dir .. "/lib/rec_conform.lua")
	local list = CF.scenes(T)
	ok(#list >= 3, "sessions: " .. #list)
	local boots, rows = 0, 0
	local kinds = {}
	-- the events the corrected fake makes more of by itself (a trade's two TRADE_CLOSED, CANCEL_SUMMON on
	-- leaving, a summon's zone-only or loading-screen arrival, the login's late channels and zone): each
	-- recorded row reaches Wuber exactly once, and nothing the recording lacks
	local ONCE = { "TRADE_CLOSED", "CANCEL_SUMMON", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "CHANNEL_UI_UPDATE",
		"GROUP_LEFT", "GROUP_JOINED", "PLAYER_MONEY", "CHAT_MSG_SYSTEM", "CHAT_MSG_CHANNEL_NOTICE" }
	for i, fx in ipairs(list) do
		local rep = RP.replay(T, fx, { name = "scene session " .. i })
		ok(rep.ok, report(rep))
		eq(rep.held, 0, "the fake made nothing the recording lacks: " .. report(rep))
		kinds[#kinds + 1] = rep.kind
		for _, c in ipairs(rep.cannot) do
			ok(c.what ~= "chat channels", "the channels come from the recorder's snapshot: " .. c.why)
			ok(c.what ~= "settings", "a settings snapshot in every session: " .. c.why)
		end
		ok(rep.channels.game == 5, "the game's five channels from the channels snapshot (" .. tostring(rep.channels.game) .. ")")
		ok(rep.settings and #rep.settings.set == 0 and rep.settings.same > 0,
			"the recorded settings are Wuber's own in the fake (nothing to change, " .. tostring(rep.settings and rep.settings.same) .. " the same)")
		local recorded = {}
		for _, e in ipairs(fx.events) do recorded[e.e] = (recorded[e.e] or 0) + 1 end
		for _, e in ipairs(ONCE) do
			eq(rep.delivered[e] or 0, recorded[e] or 0, "session " .. i .. " (" .. rep.kind .. "): " .. e .. " reached Wuber once per recorded row")
		end
		if rep.boot then
			boots = boots + 1
			ok(#rep.boot.recorded >= 3 and rep.boot.recorded[#rep.boot.recorded]:find("^PLAYER_ENTERING_WORLD"), "the recorded login rows")
			-- the fake client started the way the recorded session did: a reload as a reload, a login as a login
			local want = rep.kind == "reload" and "PLAYER_ENTERING_WORLD(false,true)" or "PLAYER_ENTERING_WORLD(true,false)"
			eq(rep.boot.fake[#rep.boot.fake], want, "the fake's own login rows (" .. rep.kind .. ")")
			eq(rep.boot.recorded[#rep.boot.recorded], want, "the recorded login rows (" .. rep.kind .. ")")
		end
		rows = rows + rep.fired
	end
	eq(table.concat(kinds, ","), "on,login,reload", "a /rec on session, then a login, then a reload")
	eq(boots, 2, "a login and a reload replayed from their recorded rows")
	ok(rows >= 30, "events fired: " .. rows)
end)

-- Every committed fixture (tests/fixtures/rec/*.lua whose table has kind == "rec") replays.
local GAPS_PATH = T.dir .. "/fixtures/rec/known-gaps.lua"
local function fixtures()
	local out = {}
	for _, path in ipairs(H.listFiles(T.dir .. "/fixtures/rec", "lua")) do
		local base = path:gsub("\\", "/"):match("([^/]+)%.lua$")
		if base ~= "known-gaps" then
			local okL, fx = pcall(dofile, path)
			if okL and type(fx) == "table" and fx.kind == "rec" then out[#out + 1] = { base = base, path = path, fx = fx } end
		end
	end
	return out
end

-- the mismatches of a real-game fixture's replay that known-gaps.lua does not list, as messages
local function gameProblems(base, rep, gaps)
	local out = {}
	for _, m in ipairs(rep.mismatches) do
		local long = "replay:" .. base .. ":" .. m.field
		if not gaps[m.id] and not gaps[long] then
			out[#out + 1] = ("%s: %s at %.2f s: the real game showed %s, the fake shows %s (events before: %s). Correct the fake game (tests/harness.lua, tests/lib) so it does what the recording shows, or list the gap in tests/fixtures/rec/known-gaps.lua as [%q] = \"why the fake differs and what is planned\""):format(
				base, m.id, m.t, tostring(m.expected), tostring(m.got), table.concat(m.before or {}, ", "), long)
		end
	end
	return out
end

test("rec: replay of a real-game fixture: a mismatch not in known-gaps.lua fails and says what to do", function()
	local fx = recording()
	fx.source = "game"
	local open, close = taxiTimes(fx)
	for _, s in ipairs(wuberSnaps(fx)) do
		if s.t > open and s.t < close and s.d.cards then s.d.cards.bird = nil end
	end
	local rep = RP.replay(T, fx, { name = "game-test" })
	eq(#rep.errors, 0, "no Lua error")
	local p = gameProblems("game-test", rep, {})
	ok(#p >= 1, "the bird card's mismatches fail")
	ok(p[1]:find("known-gaps.lua", 1, true) and p[1]:find('"replay:game-test:bird"', 1, true) and p[1]:find("Correct the fake game", 1, true), p[1])
	eq(#gameProblems("game-test", rep, { ["replay:bird"] = "a reason for every fixture" }), 0, "listed for every fixture")
	eq(#gameProblems("game-test", rep, { ["replay:game-test:bird"] = "a reason for this fixture" }), 0, "listed for this fixture")
end)

test("rec: replay of every committed fixture (sim: all match; game: known gaps only)", function()
	local gaps = dofile(GAPS_PATH)
	ok(type(gaps) == "table", "known-gaps.lua returns a table")
	local problems, n = {}, 0
	-- sessions of one character that follow each other replay as a chain (saved data carried)
	local list = fixtures()
	table.sort(list, function(a, b)
		if tostring(a.fx.char) ~= tostring(b.fx.char) then return tostring(a.fx.char) < tostring(b.fx.char) end
		return (tonumber(a.fx.epoch) or 0) < (tonumber(b.fx.epoch) or 0)
	end)
	local fxs, names = {}, {}
	for i, f in ipairs(list) do fxs[i], names[i] = f.fx, f.base end
	local reps = RP.replayChain(T, fxs, { names = names })
	for i, f in ipairs(list) do
		n = n + 1
		local rep = reps[i]
		for _, e in ipairs(rep.errors) do problems[#problems + 1] = f.base .. ": Lua error in the replay: " .. e end
		if f.fx.source == "sim" then
			if #rep.mismatches > 0 then
				problems[#problems + 1] = f.base .. " (recorded in the fake game) must replay fully:\n" .. report(rep)
			end
		else
			for _, line in ipairs(gameProblems(f.base, rep, gaps)) do problems[#problems + 1] = line end
			for _, line in ipairs(RP.lines(rep, 0)) do print("      " .. line) end
		end
		print(("      %s: %d of %d match, unknown events: %s, cannot: %d"):format(f.base, rep.matched, rep.total,
			table.concat(rep.unknownList, ","), #rep.cannot))
	end
	if n == 0 then print("      (no committed fixture of kind rec yet)") end
	ok(#problems == 0, table.concat(problems, "\n"))
end)
