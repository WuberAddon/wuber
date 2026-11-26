-- Tests of the flight recorder's conformance engine (tests/lib/rec_conform.lua): a recording made in
-- the fake game conforms to the fake game's own recording of the standard scenes; changed facts are
-- reported exactly; every committed real-game fixture is compared with the fake (differences not in
-- tests/fixtures/rec/known-gaps.lua fail); the summary is plain lines.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.testOutside or T.test, T.eq, T.ok, T.H -- (testOutside: not in the behaviour transcript)
local CF = dofile(T.dir .. "/lib/rec_conform.lua")
local RP = CF.RP

if not RP.haveRecorder() then
	test("rec: conformance skipped (" .. RP.ADDON.why() .. ")", function() end)
	return
end

local DEBUG = os.getenv("WUBER_REC_DEBUG")

local function byId(list)
	local out = {}
	for _, c in ipairs(list) do out[c.id] = c end
	return out
end

local function scenes()
	local list = CF.scenes(T)
	eq(#(CF.errors or {}), 0, "Lua errors in the scenes: " .. table.concat(CF.errors or {}, "\n"))
	return list
end

-- another story, recorded on its own: login, /rec on, the flight map, a trade, a /reload
local function otherStory(w, add)
	local d = T.driver(w, T.ANITA, { spot = "Thunder Bluff" })
	local r = add(CF.ROCKS, { spot = "Thunder Bluff", class = "MAGE", money = 50000, screenW = 1600, screenH = 900 })
	w:advance(3)
	r:slash("/rec on")
	w:advance(4)
	w:openTaxiMap(r, CF.NODES)
	w:advance(1.5)
	w:closeTaxiMap(r)
	w:advance(1)
	w:openTrade(d, r)
	w:advance(1)
	w:typeTradeMoney(r.player, 0, 20, 0)
	w:tradeAccept(d.player)
	w:tradeAccept(r.player)
	w:advance(2)
	r = w:reload(r)
	w:advance(4)
	r:slash("/rec off")
	return r
end

test("rec: conformance of a recording made in the fake game (every equal fact the same)", function()
	local sim = scenes()
	ok(#sim >= 3, "the scenes made three sessions or more: " .. #sim)
	local facts = CF.facts(sim)
	ok(#facts >= 300, "facts from the scenes: " .. #facts)
	local ids = byId(CF.compare(facts, facts))
	for _, id in ipairs({ "login.order", "reload.PLAYER_ENTERING_WORLD.args", "reload.zoneChangedNewArea", "args.CHAT_MSG_ADDON",
		"known.GLOBAL_MOUSE_DOWN", "api.C_Map.GetBestMapForUnit", "gs.ERR_TRADE_COMPLETE", "client.unitName", "screen.ui.size",
		"frame.ChatFrame1.exists", "taxi.frame", "taxi.frame.size", "taxi.nodes.otherTypes", "taxi.idle.has.NumTaxiNodes", "atlas.1414.art.size", "map.chain.types",
		"shape.CHAT_MSG_ADDON:4", "trade.complete.closed", "trade.cancel.closed", "summon.arrival",
		"group.leftWhileSummoned.cancelSummon", "map.wm.scroll", "channels.login.count", "channels.login.firstList",
		"channels.reload.count", "channels.reload.kept", "settings.known", "screen.ui.holds", "screen.ui.read", "reload.file.wdb" }) do
		ok(ids[id], "the scenes give the fact " .. id)
	end
	-- the corrected fake: a fresh login has no channel at PLAYER_LOGIN and the game's five 3 s later;
	-- a /reload keeps what it had; UIParent is read (it only holds protected frames)
	eq(ids["channels.login.count"].real, 0, "no channel at a fresh login")
	eq(ids["channels.login.firstList"].real, 3, "the channels 3 s after the login")
	eq(ids["channels.reload.kept"].real, true, "a reload keeps its channels")
	eq(ids["channels.reload.count"].real, 5, "the game's five (5 s after the login Wuber has not joined its own yet)")
	eq(ids["settings.known"].real, true)
	eq(ids["screen.ui.holds"].real, true)
	eq(ids["screen.ui.size"].real, "1365 x 768", "UIParent's own size")
	local list, w = RP.record(T, otherStory, "sim")
	eq(#w.errors, 0, "Lua errors: " .. table.concat(w.errors, "\n"))
	ok(#list == 2, "two sessions (on, then boot): " .. #list)
	local cmp = CF.compare(list, sim)
	local bad = CF.failures(cmp, {})
	if DEBUG then print(table.concat(CF.summary(cmp, { simOnly = true }), "\n")) end
	ok(#bad == 0, table.concat(CF.summary(bad), "\n"))
	local n = 0
	for _, c in ipairs(cmp) do if c.verdict == "same" and c.rule == "equal" then n = n + 1 end end
	ok(n >= 200, "equal facts both recordings have: " .. n)
	-- and every committed fixture recorded in the fake game
	for _, path in ipairs(H.listFiles(T.dir .. "/fixtures/rec", "lua")) do
		local okL, fx = pcall(dofile, path)
		if okL and type(fx) == "table" and fx.kind == "rec" and fx.source == "sim" then
			local bad2 = CF.failures(CF.compare(fx, sim), {})
			ok(#bad2 == 0, path .. " does not conform to the fake game:\n" .. table.concat(CF.summary(bad2), "\n"))
		end
	end
end)

test("rec: conformance reports exactly the facts changed in a copy", function()
	local sim = scenes()
	local fx = RP.copy(sim)
	-- 1. the reload's PLAYER_ENTERING_WORLD arguments: the old fake's (true, false), a login's, where the
	-- fake (and the real game) now give (false, true)
	local reload
	for _, s in ipairs(fx) do if s.scene == "reload" then reload = s end end
	ok(reload, "the reload session")
	local pew
	for _, e in ipairs(reload.events) do if not pew and e.e == "PLAYER_ENTERING_WORLD" then pew = e end end
	eq(tostring(pew.a[1]) .. "," .. tostring(pew.a[2]), "false,true", "the fake reloads as the real game does")
	pew.a[1], pew.a[2] = true, false
	-- 2. an API marked missing
	local client
	for _, s in ipairs(fx) do
		for _, sn in ipairs(s.snaps) do if not client and sn.id == "client" and sn.d.api then client = sn.d end end
	end
	ok(client.api["C_Map.GetMapArtLayers"], "the fake has C_Map.GetMapArtLayers")
	client.api["C_Map.GetMapArtLayers"] = nil
	client.missing[#client.missing + 1] = "C_Map.GetMapArtLayers"
	-- 3. the taxi frame's size
	local taxi
	for _, s in ipairs(fx) do
		for _, sn in ipairs(s.snaps) do
			if not taxi and sn.id == "taxi" and type(sn.d.frames) == "table" and sn.d.frames.TaxiFrame and sn.d.frames.TaxiFrame.shown then taxi = sn.d.frames.TaxiFrame end
		end
	end
	ok(taxi, "a taxi snapshot with TaxiFrame")
	taxi.w = taxi.w + 16
	-- 4. one more TRADE_CLOSED in the completed trade
	local done
	for _, s in ipairs(fx) do
		for i, e in ipairs(s.events) do
			if not done and e.e == "TRADE_CLOSED" then
				local closedCompleted = false
				for j = i + 1, math.min(#s.events, i + 4) do
					local x = s.events[j]
					if type(x.a[2]) == "table" and x.a[2].gs == "ERR_TRADE_COMPLETE" then closedCompleted = true end
				end
				for j = math.max(1, i - 3), i - 1 do
					local x = s.events[j]
					if type(x.a[2]) == "table" and x.a[2].gs == "ERR_TRADE_COMPLETE" then closedCompleted = true end
				end
				if closedCompleted then
					table.insert(s.events, i + 1, RP.copy(e))
					done = true
				end
			end
		end
	end
	ok(done, "the completed trade's TRADE_CLOSED")
	local cmp = CF.compare(fx, sim)
	local changed = {}
	for _, c in ipairs(cmp) do
		if c.verdict ~= "same" then changed[#changed + 1] = c.id end
	end
	table.sort(changed)
	eq(table.concat(changed, " "), "api.C_Map.GetMapArtLayers reload.PLAYER_ENTERING_WORLD.args taxi.frame.size trade.complete.closed",
		table.concat(CF.summary(cmp), "\n"))
	local by = byId(cmp)
	eq(by["reload.PLAYER_ENTERING_WORLD.args"].real, "true,false")
	eq(by["reload.PLAYER_ENTERING_WORLD.args"].sim, "false,true")
	eq(by["api.C_Map.GetMapArtLayers"].real, "missing")
	eq(by["api.C_Map.GetMapArtLayers"].sim, "f")
	eq(by["trade.complete.closed"].real, 3, "one more than the two the real game (and the fake) send")
	eq(by["trade.complete.closed"].sim, 2)
	eq(#CF.failures(cmp, { ["taxi.frame.size"] = "a test reason" }), 3, "a listed gap is not a failure")
end)

-- every committed real-game fixture against the fake's recording of the scenes
local function gameFixtures()
	local out = {}
	for _, path in ipairs(H.listFiles(T.dir .. "/fixtures/rec", "lua")) do
		local base = path:gsub("\\", "/"):match("([^/]+)%.lua$")
		if base ~= "known-gaps" then
			local okL, fx = pcall(dofile, path)
			if okL and type(fx) == "table" and fx.kind == "rec" and fx.source == "game" then out[#out + 1] = { base = base, fx = fx } end
		end
	end
	return out
end

-- the differences of a real-game fixture that known-gaps.lua does not list, as messages
local function gameProblems(base, fx, sim, gaps, quiet)
	local cmp = CF.compare(fx, sim)
	if not quiet then
		for _, line in ipairs(CF.summary(cmp, { max = 25 })) do print("      " .. base .. ": " .. line) end
	end
	local out = {}
	for _, c in ipairs(CF.failures(cmp, gaps)) do
		out[#out + 1] = base .. ": " .. CF.line(c) .. " -- correct the fake game, or list it in tests/fixtures/rec/known-gaps.lua as ["
			.. ("%q"):format(c.id) .. "] = \"why the fake differs and what is planned\""
	end
	return out
end

test("rec: conformance of a real-game fixture: a difference not in known-gaps.lua fails and says what to do", function()
	local sim = scenes()
	local fx
	for _, s in ipairs(sim) do if s.scene == "reload" then fx = RP.copy(s) end end
	fx.source, fx.scene = "game", nil
	-- the fake now reloads as the real game does (lab-real-facts.lua, login.pew.reload: PEW(false, true), no
	-- zone event), so the copy as it is has no difference at all
	eq(#gameProblems("game-reload", fx, sim, {}, true), 0, "a reload recorded in the fake matches the fake")
	-- two synthetic differences: a zone event 0.5 s after the PEW (as the old fake sent it) and a
	-- PLAYER_ENTERING_WORLD with a third argument
	local zone
	for _, s in ipairs(sim) do
		for _, e in ipairs(s.events) do if not zone and e.e == "ZONE_CHANGED_NEW_AREA" then zone = RP.copy(e) end end
	end
	ok(zone, "a recorded ZONE_CHANGED_NEW_AREA row to copy")
	local keep = {}
	for _, e in ipairs(fx.events) do
		keep[#keep + 1] = e
		if e.e == "PLAYER_ENTERING_WORLD" and not fx.changed then
			eq(tostring(e.a[1]) .. "," .. tostring(e.a[2]), "false,true", "the fake's reload arguments")
			e.n = 3
			e.a[3] = false
			zone.t = e.t + 0.5
			keep[#keep + 1] = zone
			fx.changed = true
		end
	end
	fx.events = keep
	local p = gameProblems("game-reload", fx, sim, {}, true)
	eq(#p, 2, table.concat(p, "\n"))
	local text = table.concat(p, "\n")
	ok(text:find('args.PLAYER_ENTERING_WORLD [equal]: the real game "2,3", the fake "2"', 1, true), text)
	ok(text:find("reload.zoneChangedNewArea [equal]: the real game true, the fake false", 1, true), text)
	ok(text:find('known-gaps.lua as ["reload.zoneChangedNewArea"]', 1, true), text)
	eq(#gameProblems("game-reload", fx, sim, { ["args.PLAYER_ENTERING_WORLD"] = "a synthetic third argument", ["reload.zoneChangedNewArea"] = "a synthetic zone event" }, true), 0,
		"listed gaps do not fail")
	-- and it replays without a Lua error, its login rows replacing the fake's
	local rep = RP.replay(T, fx, { name = "game-reload" })
	eq(#rep.errors, 0, table.concat(rep.errors, "\n"))
	ok(rep.boot and rep.boot.recorded[#rep.boot.recorded] == "PLAYER_ENTERING_WORLD(false,true,false)", "the recorded reload arguments were fired: " .. tostring(rep.boot and rep.boot.recorded[#rep.boot.recorded]))
end)

test("rec: conformance of every committed real-game fixture (differences only as known gaps)", function()
	local gaps = dofile(T.dir .. "/fixtures/rec/known-gaps.lua")
	ok(type(gaps) == "table", "known-gaps.lua returns a table")
	for id, why in pairs(gaps) do
		ok(type(id) == "string" and type(why) == "string" and #why >= 10, "a known gap needs a reason: " .. tostring(id))
	end
	local list = gameFixtures()
	if #list == 0 then
		print("      (no real-game fixture yet: tests/fixtures/rec/game-*.lua)")
		return
	end
	local sim = scenes()
	local problems = {}
	for _, f in ipairs(list) do
		for _, line in ipairs(gameProblems(f.base, f.fx, sim, gaps)) do problems[#problems + 1] = line end
	end
	ok(#problems == 0, #problems .. " facts differ from the real game:\n" .. table.concat(problems, "\n"))
end)

test("rec: conformance cross-check with the importer's facts (notes for the lead, never a failure)", function()
	local n = 0
	for _, path in ipairs(H.listFiles(T.dir .. "/fixtures/rec", "lua")) do
		local base = path:gsub("\\", "/"):match("([^/]+)%.lua$")
		local okL, fx = pcall(dofile, path)
		if base ~= "known-gaps" and okL and type(fx) == "table" and fx.kind == "rec" and type(fx.facts) == "table" then
			n = n + 1
			local cc = CF.crossCheck(fx)
			print(("      %s: %d facts compared with the importer's, %d differ"):format(base, cc.compared or 0, #cc))
			for _, d in ipairs(cc) do
				print(("      NOTE for the lead: %s: fact %s is %s in fx.facts (the importer) but %s here"):format(base, d.id, tostring(d.importer), tostring(d.ours)))
			end
		end
	end
	if n == 0 then print("      (no committed fixture carries fx.facts yet)") end
end)

test("rec: conformance summary is plain lines", function()
	local real = { { id = "a.same", v = 1, rule = "equal" }, { id = "b.differs", v = "x", rule = "equal" }, { id = "c.info", v = 1920, rule = "info" },
		{ id = "d.real", v = true, rule = "equal" }, { id = "f.shape", v = "1.60.1", rule = "shape" } }
	local sim = { { id = "a.same", v = 1, rule = "equal" }, { id = "b.differs", v = "y", rule = "equal" }, { id = "c.info", v = 1365, rule = "info" },
		{ id = "e.sim", v = false, rule = "equal" }, { id = "f.shape", v = "1.61.0", rule = "shape" } }
	local cmp = CF.compare(real, sim)
	local by = byId(cmp)
	eq(by["a.same"].verdict, "same")
	eq(by["b.differs"].verdict, "differs")
	eq(by["c.info"].verdict, "differs")
	eq(by["d.real"].verdict, "real only")
	eq(by["e.sim"].verdict, "sim only")
	eq(by["f.shape"].verdict, "same", "a shape fact: the same type")
	local bad = CF.failures(cmp)
	eq(#bad, 1, "only the equal fact that differs fails")
	eq(bad[1].id, "b.differs")
	local lines = CF.summary(cmp, { simOnly = true })
	ok(type(lines) == "table" and #lines >= 5, "lines")
	for _, l in ipairs(lines) do ok(type(l) == "string" and not l:find("\n"), "one plain line each") end
	eq(lines[1], "6 facts: 2 same, 2 differ (1 must be equal, 1 info), 1 only in the real game, 1 only in the fake")
	local text = table.concat(lines, "\n")
	ok(text:find('b.differs [equal]: the real game "x", the fake "y"', 1, true), text)
	ok(text:find("c.info [info]", 1, true), text)
	ok(text:find("e.sim", 1, true), text)
	-- the importer's facts are cross-checked, never failed on
	local fx = { kind = "rec", events = {}, snaps = {}, shapes = { ["CHAT_MSG_ADDON:4"] = { space = 3 } },
		facts = { { id = "shape.CHAT_MSG_ADDON:4", v = "hyphen" }, { id = "not.ours", v = 1 } } }
	local cc = CF.crossCheck(fx)
	eq(#cc, 1)
	local fx2 = RP.copy(fx)
	fx2.facts = { { id = "name:shape:CHAT_MSG_ADDON:4", q = "name", key = "shape:CHAT_MSG_ADDON:4", v = { space = 2 } } }
	eq(#CF.crossCheck(fx2), 0, "the importer's own id style is translated")
	eq(CF.crossCheck(fx2).compared, 1)
	eq(cc[1].id, "shape.CHAT_MSG_ADDON:4")
	eq(cc[1].ours, "space")
end)
