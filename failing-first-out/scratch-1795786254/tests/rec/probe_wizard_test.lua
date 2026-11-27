-- WuberProbe 1.1 (job 2907, Fable "Probe pack" 1-5, 8-10 and feature B layer 1): the wizard, the write-ahead markers, the frame budget, the cleanup
-- watchdog, completion-based guided steps, the build fingerprint that arms the auto tier by itself, "Save and reload", the importer naming
-- a probe that never finished, and tools/rec/probe-diff.lua. The addon is the developer-only one (lab repo, WuberProbe folder): part B
-- needs it (WUBER_PROBE_DIR or ../WuberProbe), as tests/rec/probe_test.lua does; without it only the diff tool is tested.
-- Every test here fails on the WuberProbe 1.0 addon (no wizard, no markers, no watchdog, no fingerprint) unless it carries a "-- guard:" line.
local T = ...
local H, test, eq, ok = T.H, T.testOutside or T.test, T.eq, T.ok

local ROOT = T.dir .. "/.."
local IMP = assert(loadfile(ROOT .. "/tools/rec/import.lua"))("--lib")
local PI = assert(loadfile(ROOT .. "/tools/rec/probe-import.lua"))("--lib")
local PD = assert(loadfile(ROOT .. "/tools/rec/probe-diff.lua"))("--lib")

---------------------------------------------------------------------------
-- probe-diff (tool test)
---------------------------------------------------------------------------
-- guard: infra (a tool test: the diff tool is new)
test("wprobe diff: a short fact diff: file ids, width per font and size, events, newly secret accessors", function()
	local old = { env = { build = { "1.60.1", "71037" } }, fileIds = { ["a\\x.tga"] = 1, ["a\\y.tga"] = 2, ["a\\z.tga"] = 3 },
		widths = { ["inter-regular.ttf"] = { [11] = { strings = { A = 100, B = 50 } }, [14] = { strings = { A = 100 } } } },
		events = { TAXIMAP_OPENED = { valid = true, reg = true }, FOO = { valid = true } },
		secretAccessors = { IsShown = { "F1" } }, secretApi = {} }
	local new = { env = { build = { "1.60.1", "71200" } }, fileIds = { ["a\\x.tga"] = 1, ["a\\y.tga"] = 20, ["a\\z.tga"] = 30 },
		widths = { ["inter-regular.ttf"] = { [11] = { strings = { A = 100.4, B = 50.2 } }, [14] = { strings = { A = 100 } } } },
		events = { TAXIMAP_OPENED = { valid = false, reg = true }, FOO = { valid = true } },
		secretAccessors = { IsShown = { "F1", "F2", "F3", "F4", "F5" }, GetAlpha = { "F1" } }, secretApi = { UnitGUID = true } }
	local lines = PD.diff(old, new)
	local text = table.concat(lines, "\n")
	ok(text:find("build 71037 -> 71200", 1, true), text)
	ok(text:find("2 file ids changed", 1, true), text)
	ok(text:find("11 px inter%-regular %+0.4%% %(2 strings%)"), text)
	ok(not text:find("14 px", 1, true), "an unchanged size is not listed")
	ok(text:find("event TAXIMAP_OPENED no longer valid", 1, true), text)
	ok(text:find("accessor IsShown now secret on 4 frames", 1, true), text)
	ok(text:find("accessor GetAlpha now secret on 1 frame", 1, true), text)
	ok(text:find("call UnitGUID now answers a secret", 1, true), text)
	eq(#PD.diff(old, old), 0, "the same fixture has no facts")
	local said = {}
	eq(PD.main({ "--help" }, function(l) said[#said + 1] = l end), 0)
	ok(said[1]:find("probe-diff.lua", 1, true))
end)

-- guard: infra (the importer names a probe that was started and never finished; the marker is data the importer reads, no addon needed)
test("wprobe markers: the importer names a probe that never finished, an errored one and an aborted one, and not a finished one", function()
	local run = { id = "x", p = { env = {} }, ran = { env = { done = true }, keys = {}, hit = { err = "boom" }, watch = { aborted = "combat" }, tex = { done = true } },
		started = { env = 1, keys = 2, hit = 3, watch = 4, tex = 5 }, at = "keys:armed" }
	local list = PI.unfinished(run)
	local by = {}
	for _, u in ipairs(list) do by[u.name] = u end
	eq(#list, 3)
	eq(by.keys.why, "never finished") eq(by.keys.at, "keys:armed", "the last checkpoint is named")
	eq(by.hit.why, "error")
	eq(by.watch.why, "aborted (combat)")
	local fx = assert(PI.convert(run, "sim"))
	eq(#fx.unfinished, 3)
	eq(#PI.unfinished({ p = {}, ran = {} }), 0, "an old run with no markers lists nothing")
end)

---------------------------------------------------------------------------
-- Part B: the addon in the fake game
---------------------------------------------------------------------------
local function exists(p) local f = io.open(p .. "/WuberProbe.toc", "rb") if f then f:close() return true end end
local PROBE_DIR
for _, d in ipairs({ os.getenv("WUBER_PROBE_DIR"), T.dir .. "/../../WuberProbe", T.dir .. "/../WuberProbe" }) do
	if d and d ~= "" and exists(d) then PROBE_DIR = d break end
end
if not PROBE_DIR then
	test("wprobe wizard: part B skipped (the WuberProbe addon folder was not found; set WUBER_PROBE_DIR)", function() end)
	return
end
H.ADDONS.WuberProbe = PROBE_DIR

local function probeClient(w, opts)
	opts = opts or {}
	opts.addons, opts.allowMissing = { "WuberProbe" }, true
	opts.spot, opts.class, opts.money = "Orgrimmar", "MAGE", 1000
	return w:addClient("Wuber Rocks", opts)
end
local function dbOf(c) return c.env.WuberProbeDB end
local function api(c) return c.env.WuberProbeAPI end
local function lastRun(c) return dbOf(c).runs[#dbOf(c).runs] end
local function cleanWorld(w) w.missingFiles = {} T.clean(w) end

-- every probe frame is hidden, unfocused and has its keyboard off
local function leftOver(c)
	local bad = {}
	local P = api(c)
	for i, f in ipairs(P.own) do
		if f:IsShown() and f.GetObjectType and f:GetObjectType() ~= "Texture" and f:GetWidth() > 1 and f ~= c.env.UIParent then bad[#bad + 1] = i .. " shown" end
		if f.HasFocus and f:HasFocus() then bad[#bad + 1] = i .. " focused" end
		if f.IsKeyboardEnabled and f:IsKeyboardEnabled() then bad[#bad + 1] = i .. " keyboard" end
	end
	return bad
end

-- (item 5) past hazard B2/B3: a probe that stops half-way must not leave a focused box eating the keys or a frame with the keyboard on
test("wprobe wizard: an error in the middle of the keys probe leaves nothing shown, focused or keyboard-enabled", function()
	local w = T.newWorld()
	local c = probeClient(w)
	c:slash("/probe on")
	api(c).onCheckpoint = function(tag) if tag == "keys.armed" then error("injected fault") end end
	c:slash("/probe run keys")
	w:advance(1)
	local run = lastRun(c)
	ok(run.ran.keys.err and run.ran.keys.err:find("injected fault", 1, true), "the error is kept in the probe's row: " .. tostring(run.ran.keys.err))
	eq(table.concat(leftOver(c), ", "), "", "nothing shown, focused or keyboard-enabled")
	api(c).onCheckpoint = nil
	cleanWorld(w)
end)

test("wprobe wizard: PLAYER_REGEN_DISABLED in the middle of a guided probe cleans up and stops the queue", function()
	local w = T.newWorld()
	local c = probeClient(w)
	c:slash("/probe on")
	c:slash("/probe run keys")
	w:advance(1)
	ok(#leftOver(c) > 0, "the keys panel is up (the test would prove nothing otherwise)")
	c:fire("PLAYER_REGEN_DISABLED")
	eq(table.concat(leftOver(c), ", "), "", "cleaned at once")
	ok(not api(c).running, "the queue stopped")
	eq(lastRun(c).ran.keys.aborted, "combat")
	cleanWorld(w)
end)

-- (item 3) write-ahead: a probe that never finishes is named
test("wprobe wizard: run.started is written before a probe and ran.done after it; a probe left unfinished is named by the importer", function()
	local w = T.newWorld()
	local c = probeClient(w)
	c:slash("/probe on")
	c:slash("/probe run keys")
	w:advance(1)
	local run = lastRun(c)
	ok(run.started and run.started.keys, "the marker is there while the probe runs")
	ok(not run.ran.keys.done, "not done yet")
	eq(run.at, "keys:keys.armed", "the last checkpoint is named")
	local list = PI.unfinished(run)
	eq(#list, 1) eq(list[1].name, "keys") eq(list[1].why, "never finished")
	api(c).skipRequested = true
	w:advance(1)
	ok(run.ran.keys.done, "done once it ended")
	eq(#PI.unfinished(run), 0)
	cleanWorld(w)
end)

-- (item 4) the auto tier gives the frame back: with every clock read costing 1 ms, one frame cannot hold the whole tier
test("wprobe wizard: the auto tier is spread over frames (about 5 ms each) and still finishes with no error", function()
	local w = T.newWorld()
	local c = probeClient(w)
	local clock = 0
	c.env.debugprofilestop = function() clock = clock + 1 return clock end
	c:slash("/probe on")
	c:slash("/probe run auto")
	local run = lastRun(c)
	eq(run.ran.atlas, nil, "nothing has run inside the slash command")
	w:advance(0.02)
	ok(not run.ran.atlas, "one frame did not run the whole tier")
	ok(api(c).running, "still going after one frame")
	for _ = 1, 400 do w:advance(0.25) end
	w.missingFiles = {}
	for _, n in ipairs({ "env", "tex", "atlas", "events", "secrets", "fontw", "keysAuto", "timing" }) do
		ok(run.ran[n] and run.ran[n].done, n .. " finished")
		eq(run.ran[n].err, nil, n .. " error")
	end
	ok(not api(c).running)
	cleanWorld(w)
end)

-- (items 1, 2) one click, then the steps; Skip ends a guided step; nothing typed
test("wprobe wizard: one click on the Probe button and Start runs the auto tier and the three guided steps; Skip ends each; the last button saves", function()
	local w = T.newWorld()
	local c = probeClient(w)
	local P = api(c)
	local Wz = P.wizard
	ok(Wz and c.env.WuberProbeButton, "the small button and the wizard exist")
	c:clickOn(c.env.WuberProbeButton)
	ok(Wz.panel:IsShown(), "the button opens the wizard")
	c:clickOn(Wz.mainBtn) -- Start
	ok(dbOf(c).on, "Start switched the probe on by itself: no /probe on")
	for _ = 1, 400 do w:advance(0.25) if Wz.stage >= 2 then break end end
	eq(Wz.stage, 2, "the automatic tier is done: now the keys step")
	w.missingFiles = {}
	for _, step in ipairs({ "keys", "hit", "watch" }) do
		w:advance(0.5)
		eq(Wz.running, step, "step " .. step)
		ok(Wz.skipBtn:IsShown(), "a Skip button on a guided step")
		c:clickOn(Wz.skipBtn)
		w:advance(0.5)
	end
	eq(Wz.stage, 5, "all four steps done")
	eq(Wz.mainBtn.label:GetText(), "Save and reload", "the last button")
	local run = lastRun(c)
	for _, n in ipairs({ "keys", "hit", "watch" }) do ok(run.ran[n].done and run.ran[n].skipped == "user", n .. " ended on Skip") end
	ok(not (dbOf(c).last), "no full run recorded before the player saves")
	c:clickOn(Wz.mainBtn)
	ok(dbOf(c).last and dbOf(c).last.fp, "the full run's fingerprint is saved")
	ok(dbOf(c).reload and dbOf(c).reload.how == "click", "the marker is written first")
	cleanWorld(w)
end)

-- (item 9, the B5 measurement) the real client blocks ReloadUI from addon code: the fake does too (rule reload.from-addon-code)
test("wprobe wizard: Save and reload, blocked: the marker says blocked and the wizard says to log out", function()
	local w = T.newWorld()
	local c = probeClient(w)
	local P = api(c)
	c:slash("/probe on")
	P.wizard.stage = 5
	c:clickOn(c.env.WuberProbeButton)
	c:clickOn(P.wizard.mainBtn)
	w:advance(0.3)
	eq(dbOf(c).reload.result, "blocked")
	ok(P.wizard.status:GetText():find("log out", 1, true), tostring(P.wizard.status:GetText()))
	cleanWorld(w)
end)

test("wprobe wizard: Save and reload, allowed: the marker is found on the next load with no blocked row and reads allowed", function()
	local w = T.newWorld()
	w.reloadAllowed = true
	local c = probeClient(w)
	local P = api(c)
	c:slash("/probe on")
	P.wizard.stage = 5
	c:clickOn(c.env.WuberProbeButton)
	c:clickOn(P.wizard.mainBtn)
	ok(dbOf(c).reload and dbOf(c).reload.result == nil, "marker, no answer yet")
	w:advance(0.5)
	local c2 = w:clientOf("Wuber Rocks")
	ok(c2 and c2 ~= c, "the game reloaded")
	eq(dbOf(c2).reload.result, "allowed")
	w.reloadAllowed = false
	cleanWorld(w)
end)

-- (item 7) the build fingerprint: a changed GetBuildInfo arms the auto tier by itself, 5 s after PLAYER_ENTERING_WORLD, no command
test("wprobe wizard: a changed GetBuildInfo runs the auto tier by itself 5 s after loading in, and lights the Lab bar's flag; an unchanged build does not", function()
	local w = T.newWorld()
	local first = probeClient(w)
	local fp = api(first).fingerprint()
	w:logout(first)
	w:advance(1)
	local saved = { WuberProbe = { v = 1, on = false, runs = {}, last = { fp = fp, epoch = 1, id = "old" } } }
	-- the same build: nothing happens
	local same = probeClient(w, { saved = saved })
	w:advance(30)
	eq(#dbOf(same).runs, 0, "an unchanged client runs nothing")
	eq(dbOf(same).due, nil)
	w:logout(same)
	w:advance(1)
	-- a new build
	local c = probeClient(w, { saved = { WuberProbe = { v = 1, on = false, runs = {}, last = { fp = fp, epoch = 1, id = "old" } } }, buildInfo = { "1.60.2", "71200", "Dec 02 2026", 16001, "1.60.2", "release" } })
	w:advance(4)
	eq(#dbOf(c).runs, 0, "not before 5 s")
	w:advance(2)
	ok(api(c).running, "the auto tier started by itself")
	for _ = 1, 200 do w:advance(0.25) end
	w.missingFiles = {}
	local run = lastRun(c)
	eq(run.why, "on")
	ok(run.ran.env and run.ran.env.done and run.ran.timing and run.ran.timing.done, "the whole auto tier ran")
	eq(run.ran.keys, nil, "the guided steps are left to the maintainer's click")
	ok(dbOf(c).due and dbOf(c).due.to:find("71200", 1, true), "the Lab bar's flag is set: a guided probe is due")
	eq(dbOf(c).due.from, fp)
	eq(dbOf(c).armedFor, api(c).fingerprint(), "it will not arm again for this build")
	cleanWorld(w)
end)

test("wprobe wizard: the auto-arm switch off keeps it quiet on a changed client", function()
	local w = T.newWorld()
	local c = probeClient(w, { saved = { WuberProbe = { v = 1, on = false, runs = {}, autoArm = false, last = { fp = "old|1|1|enGB|1" } } } })
	w:advance(20)
	eq(#dbOf(c).runs, 0)
	eq(dbOf(c).due, nil)
	cleanWorld(w)
end)

-- (item 2) a guided step ends on completion: the watch step ticks off the flight map, map, trade and group by reading IsShown
test("wprobe wizard: the watch step ends by itself once the flight map, map, trade window and group are seen", function()
	local w = T.newWorld()
	local c = probeClient(w)
	local E = c.env
	for _, n in ipairs({ "TaxiFrame", "WorldMapFrame", "TradeFrame" }) do E[n] = E[n] or E.CreateFrame("Frame", n) E[n]:Hide() end
	local members = 1
	E.GetNumGroupMembers = function() return members end
	c:slash("/probe on")
	c:slash("/probe run watch")
	w:advance(1)
	local run = lastRun(c)
	eq(api(c).progress.done, 0, "nothing ticked yet")
	E.TaxiFrame:Show() w:advance(0.5) E.TaxiFrame:Hide()
	E.WorldMapFrame:Show() w:advance(0.5) E.WorldMapFrame:Hide()
	eq(api(c).progress.done, 2, "two ticked")
	ok(not run.ran.watch.done, "not finished with two of four")
	E.TradeFrame:Show() w:advance(0.5) E.TradeFrame:Hide()
	members = 3
	w:advance(1)
	ok(run.ran.watch.done, "finished by itself")
	eq(run.p.watch.ended, "complete")
	ok(run.p.watch.ticked.flight and run.p.watch.ticked.map and run.p.watch.ticked.trade and run.p.watch.ticked.group)
	cleanWorld(w)
end)

-- (item 8) the hit scenarios: one per never-sampled case, three equal-level pairs, each with a ledger rule id the ledger really has
test("wprobe wizard: every hit scenario with a rule id names a rule the evidence ledger has, and the eight new cases are there", function()
	local w = T.newWorld()
	local c = probeClient(w)
	local P = api(c)
	local ledger = assert(loadfile(T.dir .. "/fixtures/client/rules.lua"))()
	local known = {}
	for _, r in ipairs(ledger) do known[r.id] = true end
	local byId = {}
	for _, sc in ipairs(P.HIT) do
		byId[sc.id] = sc
		if sc.rule then ok(known[sc.rule], sc.id .. " names rule " .. sc.rule .. " which the ledger does not have") else ok(sc.control, sc.id .. " has neither a rule nor control = true") end
	end
	for _, id in ipairs({ "scrollclip", "insets", "disabled", "alpha0", "propagate", "tie-ab", "tie-ba", "tie-clip" }) do ok(byId[id] and byId[id].rule, id .. " has a rule id") end
	eq(byId.scrollclip.rule, "hit.scrollframe-rect-clip")
	eq(byId["tie-ab"].rule, "hit.equal-level-tie")
	cleanWorld(w)
end)
