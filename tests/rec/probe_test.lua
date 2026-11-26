-- WuberProbe (the developer-only one-time probe pack): what the fake game learns from a probe fixture (part A, always runs), and the
-- probe addon itself run in the fake game with the importer (part B, needs the addon folder: WUBER_PROBE_DIR). (Job 2861 C.)
--
-- THE FIXTURE HERE IS SYNTHETIC. tests/fixtures/probe/SYNTHETIC-standin.lua is the probe pack run in the fake game set to invented
-- truths (file ids 7000000+, text 7.7% wider than the Inter advances). It is NOT real client data and the harness never loads it by
-- itself. A real session is imported with tools/rec/probe-import.lua --source game: the file tests/fixtures/probe/game-probe-<id>.lua
-- is then loaded by tests/harness.lua in every run (file ids, text widths, key rules, secrets).
local T = ...
local H, test, eq, ok = T.H, T.testOutside or T.test, T.eq, T.ok

local ROOT = T.dir .. "/.."
local IMP = assert(loadfile(ROOT .. "/tools/rec/import.lua"))("--lib")
local PI = assert(loadfile(ROOT .. "/tools/rec/probe-import.lua"))("--lib")
local L = dofile(T.dir .. "/lib/probe_learn.lua")
local FIXTURE = T.dir .. "/fixtures/probe/SYNTHETIC-standin.lua"
local TL = dofile(ROOT .. "/tools/preview/textlayout.lua")
local STRETCH = 1.077 -- the stand-in's text is 7.7% wider than the Inter advances (B10: the real 11 px text was 6.7-8.7% wider)
local function standInId(key) local h = 0 for i = 1, #key do h = (h * 31 + key:byte(i)) % 900000 end return 7000000 + h end

-- a folder (and its parents), quietly, on Windows or elsewhere
local function mkdirp(dir)
	if package.config:sub(1, 1) == "\\" then os.execute('if not exist "' .. dir:gsub("/", "\\") .. '" mkdir "' .. dir:gsub("/", "\\") .. '" >nul 2>&1')
	else os.execute('mkdir -p "' .. dir .. '"') end
end

local function plainClient(w) return w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE", money = 1000 }) end

-- a test that resets or applies puts back what the run had (a real game-*.lua fixture is loaded at start)
local function withLearning(fn)
	local saved, fixture = L.save(H), H.probeFixture
	local ok2, err = pcall(fn)
	L.restore(H, saved)
	H.probeFixture = fixture
	if not ok2 then error(err, 0) end
end

---------------------------------------------------------------------------
-- Part A: the fake game learns from a fixture
---------------------------------------------------------------------------
-- what the fake game answers now: the ids of some Wuber media and the widths of some texts, against the stand-in's truth
local TEXTS = { "Settings", "Wuber Rocks", "Pickup at dawn in Orgrimmar", "1,234g 56s", "Paused during combat" }
local FONTS = { "Interface\\AddOns\\Wuber\\Media\\fonts\\Inter-Regular.ttf", "Interface\\AddOns\\Wuber\\Media\\fonts\\Inter-Bold.ttf" }
local function disagreements(fx)
	local w = T.newWorld()
	local c = plainClient(w)
	local f = c.env.CreateFrame("Frame")
	local out = {}
	local n = 0
	for path in pairs(fx.fileIds) do
		n = n + 1
		if n <= 12 then
			local t = f:CreateTexture()
			t:SetTexture(path)
			if t:GetTexture() ~= standInId(path) then out[#out + 1] = "id " .. path end
		end
	end
	local fs = f:CreateFontString()
	local oldStretch, oldRatio = TL.STRETCH, TL.ratio
	-- the stand-in's truth: the Inter advances stretched by STRETCH and nothing else (the fixture was made before TL.ratio's measured
	-- size ratios of #238 existed, so the comparison turns them off)
	TL.STRETCH, TL.ratio = STRETCH, function() return 1 end
	for _, font in ipairs(FONTS) do
		for _, size in ipairs({ 9, 11, 13, 17, 22 }) do
			for _, text in ipairs(TEXTS) do
				fs:SetFont(font, size, "")
				fs:SetText(text)
				local want = TL.width(font, size, text)
				if math.abs(fs:GetUnboundedStringWidth() - want) > 0.01 then out[#out + 1] = ("width %s %d %q got %s want %s"):format(font:match("[^\\]+$"), size, text, tostring(fs:GetUnboundedStringWidth()), tostring(want)) end
			end
		end
	end
	TL.STRETCH, TL.ratio = oldStretch, oldRatio
	T.clean(w)
	return out
end

test("wprobe: learn: BEFORE learning the fake game disagrees with the fixture (file ids and text widths)", function()
	withLearning(function()
		L.reset(H)
		local fx = assert(L.load(FIXTURE))
		local bad = disagreements(fx)
		ok(#bad > 0, "the unlearned fake should differ from the stand-in client")
		local ids, widths = 0, 0
		for _, b in ipairs(bad) do if b:sub(1, 2) == "id" then ids = ids + 1 else widths = widths + 1 end end
		ok(ids > 0 and widths > 0, "ids " .. ids .. " widths " .. widths)
	end)
end)

test("wprobe: learn: AFTER learning (L.apply) the fake game answers the fixture's file ids and text widths", function()
	withLearning(function()
		L.reset(H)
		local fx = assert(L.load(FIXTURE))
		L.apply(H, fx)
		local bad = disagreements(fx)
		eq(#bad, 0, "disagreements after learning: " .. table.concat(bad, "; "))
	end)
end)

test("wprobe: learn: the hooks are nil by default and the fake keeps its own ids and widths", function()
	withLearning(function()
		L.reset(H)
		eq(H.fileIds, nil) eq(H.fileIdFn, nil) eq(H.measuredWidths, nil) eq(H.keyRules, nil) eq(H.secretApi, nil) eq(H.secretAccessors, nil)
		local w = T.newWorld()
		local c = plainClient(w)
		local t = c.env.CreateFrame("Frame"):CreateTexture()
		t:SetTexture("Interface\\AddOns\\Wuber\\Media\\back.tga")
		ok(t:GetTexture() < 0, "an invented negative id, as before the probe pack")
		T.clean(w)
	end)
end)

-- guard: a pure learner function in tests/lib/probe_learn.lua: it does not touch the fake game
test("wprobe: learn: widths of sizes nobody measured scale from the nearest measured size", function()
	local fx = assert(L.load(FIXTURE))
	local fn = L.widthFn(fx)
	local f = "Interface\\AddOns\\Wuber\\Media\\fonts\\Inter-Regular.ttf"
	ok(math.abs(fn(f, 11, "Settings") * 2 - fn(f, 22, "Settings")) < 0.05, "22 = 2 x 11")
	ok(math.abs(fn(f, 30, "Settings") - fn(f, 22, "Settings") * 30 / 22) < 0.01, "30 px scaled from 22")
	eq(fn("Fonts\\Unknown.ttf", 12, "x"), nil, "a font nobody measured is left to the harness")
	eq(fn(f, 12, "|Tx:12|t"), nil, "an inline texture is left to the harness")
end)

test("wprobe: learn: the learned fake still passes a Wuber test that reads texture ids (back arrow)", function()
	withLearning(function()
		local fx = assert(L.load(FIXTURE))
		L.apply(H, fx)
		local w = T.newWorld()
		local c = plainClient(w)
		local t = c.env.CreateFrame("Frame"):CreateTexture()
		t:SetTexture("Interface\\AddOns\\Wuber\\Media\\back.tga")
		local id = t:GetTexture()
		eq(type(id), "number", "an id, never the path (B1)")
		eq(id, fx.fileIds["interface\\addons\\wuber\\media\\back.tga"], "the fixture's id")
		eq(t:GetTextureFileID(), id)
		T.clean(w)
	end)
end)

-- guard: a reader of the fixture file only: it does not touch the fake game
test("wprobe: events and env facts come out of the fixture", function()
	local fx = assert(L.load(FIXTURE))
	local e = L.envFacts(fx)
	eq(e.build, "71037") eq(e.project, 18)
	eq(fx.fileIdsAre, "number")
	ok(fx.note and fx.note:find("SYNTHETIC", 1, true), "the stand-in says it is synthetic")
	eq(fx.source, "sim")
end)

---------------------------------------------------------------------------
-- keys: IsKeyboardEnabled / IsMouseEnabled / GetPropagateKeyboardInput follow the probe's keysAuto answers
---------------------------------------------------------------------------
-- the frame of a keys case, made the way the probe made it (the calls of L.KEY_CASES, in order)
local function caseFrame(env, case)
	local f = env.CreateFrame(case[1])
	for _, op in ipairs(case[2]) do
		local kind, v = op:match("^(%a+):(%a+)$")
		if kind == "kb" then f:EnableKeyboard(v == "true")
		elseif kind == "mouse" then f:EnableMouse(v == "true")
		elseif kind == "prop" then f:SetPropagateKeyboardInput(v == "true")
		else f:SetScript(op, function() end) end
	end
	return f
end

test("wprobe: keys: every case the probe asks about is found again by the harness (the call names agree)", function()
	withLearning(function()
		local fx = assert(L.load(FIXTURE))
		L.apply(H, fx)
		ok(H.keyRules, "rules built from the fixture's keys")
		local w = T.newWorld()
		local c = plainClient(w)
		local n = 0
		for name, case in pairs(L.KEY_CASES) do
			local f = caseFrame(c.env, case)
			ok(H.keyRule(f), "the harness found no rule for " .. name)
			local want = fx.keys[name]
			eq(f:IsKeyboardEnabled(), want.kb, name .. " kb") eq(f:IsMouseEnabled(), want.mouse, name .. " mouse") eq(f:GetPropagateKeyboardInput(), want.prop, name .. " prop")
			n = n + 1
		end
		eq(n, 14, "14 cases")
		T.clean(w)
	end)
end)

test("wprobe: keys: a real client that answers differently from the fake (B3) changes what the fake answers; nothing else", function()
	withLearning(function()
		L.reset(H)
		local w = T.newWorld()
		local c = plainClient(w)
		local f1 = caseFrame(c.env, L.KEY_CASES.keyDownAfterDisable)
		eq(f1:IsKeyboardEnabled(), true, "the fake's own rule: a key script turns the keyboard on")
		local fx = { keys = { keyDownAfterDisable = { kb = false, mouse = false, prop = false } } }
		L.apply(H, fx)
		local f2 = caseFrame(c.env, L.KEY_CASES.keyDownAfterDisable)
		eq(f2:IsKeyboardEnabled(), false, "the probe's answer")
		local f3 = caseFrame(c.env, L.KEY_CASES.keyUp)
		eq(f3:IsKeyboardEnabled(), true, "a case the fixture has no row for keeps the fake's rule")
		local f4 = c.env.CreateFrame("Frame") f4:SetScript("OnKeyDown", function() end) f4:SetScript("OnUpdate", function() end) f4:Show()
		eq(f4:IsKeyboardEnabled(), true, "a frame with more calls than the probe's sequence keeps the fake's rule")
		T.clean(w)
	end)
end)

---------------------------------------------------------------------------
-- secrets: the probe's answers about which accessors and calls hand out secret values
---------------------------------------------------------------------------
test("wprobe: secrets: an accessor the real client hides on a named frame answers a secret value in the fake", function()
	withLearning(function()
		local w = T.newWorld()
		local c = plainClient(w)
		local env = c.env
		local hidden = env.CreateFrame("Frame", "WuberProbeTestPlate1") hidden:SetSize(40, 10)
		local other = env.CreateFrame("Frame", "WuberProbeTestOther") other:SetSize(40, 10)
		L.reset(H)
		ok(not env.issecretvalue(hidden:GetWidth()), "plain before")
		L.apply(H, { secretAccessors = { GetWidth = { "WuberProbeTestPlate1" } } })
		ok(env.issecretvalue(hidden:GetWidth()), "secret on the named frame")
		eq(other:GetWidth(), 40, "another frame is untouched")
		eq(hidden:GetHeight(), 10, "another accessor is untouched")
		L.reset(H)
		eq(hidden:GetWidth(), 40, "back to plain")
		T.clean(w)
	end)
end)

test("wprobe: secrets: a call the real client answers with a secret starts secret in a new fake client", function()
	withLearning(function()
		L.reset(H)
		local w = T.newWorld()
		local c1 = plainClient(w)
		ok(not c1.env.issecretvalue(c1.env.GetRealmName()), "plain before")
		L.apply(H, { secretApi = { GetRealmName = true, UnitName = true } })
		local c2 = w:addClient("Wuber Second", { spot = "Orgrimmar", class = "MAGE", money = 1000 })
		ok(c2.env.issecretvalue(c2.env.GetRealmName()), "GetRealmName is secret (the harness's realm kind)")
		ok(c2.env.issecretvalue((c2.env.UnitName("player"))), "UnitName is secret")
		ok(c2.secrets.realm and c2.secrets.UnitName, "the harness's own secret model carries it")
		L.reset(H)
		local c3 = w:addClient("Wuber Third", { spot = "Orgrimmar", class = "MAGE", money = 1000 })
		ok(not c3.env.issecretvalue(c3.env.GetRealmName()), "plain again")
		T.clean(w)
	end)
end)

---------------------------------------------------------------------------
-- the harness loads a real fixture by itself
---------------------------------------------------------------------------
test("wprobe: autoload: a game-*.lua fixture is loaded; the synthetic stand-in and sim files are not", function()
	withLearning(function()
		L.reset(H)
		local function put(dir, name, text) local fh = assert(io.open(dir .. "/" .. name, "wb")) fh:write(text) fh:close() end
		local none, real = T.dir .. "/out/probe/autoload-none", T.dir .. "/out/probe/autoload-real"
		mkdirp(none) mkdirp(real)
		local fx = assert(L.load(FIXTURE))
		put(none, "SYNTHETIC-standin.lua", IMP.serialize(fx))
		put(none, "sim-probe-x.lua", IMP.serialize(fx))
		eq(H.loadProbeFixture(none), nil, "nothing real in the folder")
		eq(H.fileIds, nil, "nothing applied")
		fx.source = "game" fx.id = "unit-test"
		put(real, PI.fileName(fx, "game"), IMP.serialize(fx))
		local got, path = H.loadProbeFixture(real)
		ok(got and path:find("game%-probe%-unit%-test.lua$"), "the real file was found: " .. tostring(path))
		ok(H.fileIds and next(H.fileIds), "its file ids are in the harness")
		ok(H.measuredWidths, "its widths are in the harness")
		ok(H.keyRules, "its key rules are in the harness")
	end)
end)

-- guard: no real fixture exists yet, so a plain run has nothing loaded; this keeps that true and checks it once one is added
test("wprobe: autoload: the harness loads tests/fixtures/probe at start (a real fixture, once there, reaches every test)", function()
	local files = H.listFiles(T.dir .. "/fixtures/probe", "lua")
	local real = 0
	for _, f in ipairs(files) do if f:match("/game%-[^/]*%.lua$") then real = real + 1 end end
	if real == 0 then eq(H.probeFixture, nil, "no real fixture, none loaded") else ok(H.probeFixture, "a real fixture is in the folder and loaded") end
end)

---------------------------------------------------------------------------
-- Part B: the probe addon itself, run in the fake game (needs the WuberProbe folder: WUBER_PROBE_DIR, or ../WuberProbe)
---------------------------------------------------------------------------
local function exists(p) local f = io.open(p .. "/WuberProbe.toc", "rb") if f then f:close() return true end end
local PROBE_DIR
for _, d in ipairs({ os.getenv("WUBER_PROBE_DIR"), T.dir .. "/../../WuberProbe", T.dir .. "/../WuberProbe" }) do
	if d and d ~= "" and exists(d) then PROBE_DIR = d break end
end
if not PROBE_DIR then
	test("wprobe: part B skipped (the WuberProbe addon folder was not found; set WUBER_PROBE_DIR)", function() end)
	return
end
H.ADDONS.WuberProbe = PROBE_DIR

local function probeClient(w)
	return w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE", money = 1000, addons = { "WuberProbe" }, allowMissing = true })
end
local function dbOf(c) return c.env.WuberProbeDB end

-- plays: /probe on, /probe run auto, time passes until done. Returns the client and the saved run
local function playAuto(w)
	local c = probeClient(w)
	c:slash("/probe on")
	c:slash("/probe run auto")
	for _ = 1, 160 do w:advance(0.25) end
	w.missingFiles = {} -- the probe asks for a missing path on purpose (the fake game flags it, the real one just answers)
	return c, dbOf(c).runs[#dbOf(c).runs]
end
T.probePlayAuto = playAuto

-- guard: the probe addon is new and developer-only (nothing in Wuber/ or the fake game changes for it); this proves the addon, so it passes on any fake game
test("wprobe: off by default: nothing recorded and no run without /probe on", function()
	local w = T.newWorld()
	local c = probeClient(w)
	c:slash("/probe run auto")
	eq(#dbOf(c).runs, 0, "no run")
	eq(dbOf(c).on, false, "off")
	T.clean(w)
end)

-- guard: the probe addon is new and developer-only (nothing in Wuber/ or the fake game changes for it); this proves the addon, so it passes on any fake game
test("wprobe: /probe run auto runs every automatic probe, each under pcall, none errors", function()
	local w = T.newWorld()
	local c, run = playAuto(w)
	local names = { "env", "tex", "atlas", "events", "secrets", "fontw", "keysAuto", "timing" }
	for _, n in ipairs(names) do
		ok(run.ran[n], "ran " .. n)
		eq(run.ran[n] and run.ran[n].err, nil, n .. " error")
		ok(run.p[n] and next(run.p[n]), n .. " has data")
	end
	ok(run.p.tex.files["Interface\\AddOns\\Wuber\\Media\\back.tga"], "the back arrow texture was read")
	ok(run.p.fontw.fonts[next(run.p.fontw.fonts)][11], "11 px measured")
	T.clean(w)
end)

-- guard: the probe addon is new and developer-only (nothing in Wuber/ or the fake game changes for it); this proves the addon, so it passes on any fake game
test("wprobe: the saved table is plain data and probe-import accepts it", function()
	local w = T.newWorld()
	local c, run = playAuto(w)
	local text = IMP.savedText("WuberProbeDB", dbOf(c))
	local db, why = IMP.loadSaved(text, "WuberProbeDB")
	ok(db, "plain data: " .. tostring(why))
	local fx, err = PI.convert(db.runs[#db.runs], "sim")
	ok(fx, tostring(err))
	eq(fx.kind, "probe")
	ok(next(fx.fileIds), "file id map")
	ok(next(fx.widths), "width table")
	T.clean(w)
end)

-- A stand-in "real client": ids from standInId (positive numbers, as an addon file's id may well be) and text from the
-- shipped fonts' advances, 7.7% wider. The probe pack runs in it and the result is the SYNTHETIC fixture. (No real run exists yet:
-- when one does, tools/rec/probe-import.lua --source game writes the same kind of file, named game-probe-<id>.lua.)
local function standInFixture()
	local w = T.newWorld()
	local oldTM, oldStretch = H.textMetrics, TL.STRETCH
	local saved = L.save(H)
	L.reset(H) -- the stand-in is made from the fake's own answers, not from a real fixture that may be loaded
	H.fileIdFn, H.textMetrics, TL.STRETCH = standInId, TL, STRETCH
	local c, run = playAuto(w)
	H.fileIdFn, H.textMetrics, TL.STRETCH = nil, oldTM, oldStretch
	L.restore(H, saved)
	local fx = assert(PI.convert(run, "sim"))
	fx.labels = nil -- (job 2893) the labels part is tested on its own (tests/rec/probe_z_labels_test.lua) and would make this file huge
	fx.id = "standin"
	fx.note = "SYNTHETIC: the probe pack run in a fake game set to invented truths (ids 7000000+, text 7.7% wider). Not real client data."
	T.clean(w)
	return fx
end
T.probeStandInFixture = standInFixture

test("wprobe: learn: the synthetic stand-in fixture on disk is what the probe pack makes in the stand-in client (not stale)", function()
	local fx = standInFixture()
	local disk = T.readFile(FIXTURE)
	if os.getenv("WUBER_PROBE_WRITE") == "1" then
		mkdirp(T.dir .. "/fixtures/probe")
		local fh = assert(io.open(FIXTURE, "wb")) fh:write(IMP.serialize(fx)) fh:close()
		disk = T.readFile(FIXTURE)
	end
	ok(disk, "fixture missing: run once with WUBER_PROBE_WRITE=1")
	eq(disk, IMP.serialize(fx), "fixture bytes")
end)

---------------------------------------------------------------------------
-- Guided probes in the fake game, the importer's command line, the safety rules
---------------------------------------------------------------------------
-- guard: the probe addon is new and developer-only (nothing in Wuber/ or the fake game changes for it); this proves the addon, so it passes on any fake game
test("wprobe: hit: sweeping the mouse over every cell records the winners; the B7 overlap is the strip", function()
	local w = T.newWorld()
	local c = probeClient(w)
	c:slash("/probe on")
	c:slash("/probe run hit")
	w:advance(0.2)
	local run = dbOf(c).runs[#dbOf(c).runs]
	local d = run.p.hit
	local P = c.ns.WuberProbe
	for _, sc in ipairs(P.HIT) do
		local b = d.scenarios[sc.id].box
		for row = 0, P.HIT_ROWS - 1 do
			for col = 0, P.HIT_COLS - 1 do
				c:moveMouse(b[1] + (col + 0.5) / P.HIT_COLS * b[3], b[2] + (row + 0.5) / P.HIT_ROWS * b[4])
				w:advance(0.11)
			end
		end
	end
	w:advance(10)
	ok(run.ran.hit and run.ran.hit.ms, "the hit probe finished")
	local fx = assert(PI.convert(run, "sim"))
	eq(fx.hitCoverage.cells, fx.hitCoverage.of, "every cell seen")
	-- B7 (tests/fixtures/rec/focus-run3-back.lua): the strip took a click inside the arrow where both lie. Cell (col 1, row 2): strip rect y .55-1, arrow y .45-.75, x .1-.4
	eq(fx.hit.b7[2 * 6 + 1 + 1], "strip", "the strip wins over the clipped arrow")
	eq(fx.hit.levels[0 * 6 + 5 + 1], "B", "level 5 beats level 1")
	eq(#L.hitRules(fx), 12 * 24, "one rule per cell")
	w.missingFiles = {}
	T.clean(w)
end)

-- guard: the probe addon is new and developer-only (nothing in Wuber/ or the fake game changes for it); this proves the addon, so it passes on any fake game
test("wprobe: blocked actions are logged by name only, never provoked", function()
	local w = T.newWorld()
	local c = probeClient(w)
	c:slash("/probe on")
	c:fire("ADDON_ACTION_BLOCKED", "SomeTestAddon", "ReloadUI()")
	c:fire("ADDON_ACTION_FORBIDDEN", "SomeAddon", "Frame:Show()")
	local run = dbOf(c).runs[#dbOf(c).runs]
	eq(run.blockedN, 2)
	eq(run.blocked[1].addon, "SomeTestAddon")
	eq(run.blocked[2].e, "ADDON_ACTION_FORBIDDEN")
	T.clean(w)
end)

-- guard: the probe addon is new and developer-only (nothing in Wuber/ or the fake game changes for it); this proves the addon, so it passes on any fake game
test("wprobe: keys probe runs, logs rows, and closes its panel", function()
	local w = T.newWorld()
	local c = probeClient(w)
	c:slash("/probe on")
	c:slash("/probe run keys")
	w:advance(1)
	c:fire("GLOBAL_MOUSE_DOWN", "LeftButton")
	w:advance(45)
	local run = dbOf(c).runs[#dbOf(c).runs]
	ok(run.ran.keys and run.ran.keys.ms, "finished")
	ok(#run.p.keys.rows >= 1, "a click row")
	T.clean(w)
end)

-- guard: the probe addon is new and developer-only (nothing in Wuber/ or the fake game changes for it); this proves the addon, so it passes on any fake game
test("wprobe: watch counts events without arguments", function()
	local w = T.newWorld()
	local c = probeClient(w)
	c:slash("/probe on")
	c:slash("/probe run watch")
	w:advance(1)
	c:fire("GROUP_ROSTER_UPDATE")
	c:fire("GROUP_ROSTER_UPDATE")
	w:advance(125)
	local run = dbOf(c).runs[#dbOf(c).runs]
	eq(run.p.watch.fired.GROUP_ROSTER_UPDATE, 2)
	local fx = assert(PI.convert(run, "sim"))
	T.clean(w)
end)

-- guard: the probe addon is new and developer-only (nothing in Wuber/ or the fake game changes for it); this proves the addon, so it passes on any fake game
test("wprobe: probe-import's command line reads a WTF-shaped folder and writes a fixture", function()
	local w = T.newWorld()
	local c, run = playAuto(w)
	local dir = T.dir .. "/out/probe/WTF"
	mkdirp(dir .. "/Account/SIM/SavedVariables")
	local file = dir .. "/Account/SIM/SavedVariables/WuberProbe.lua"
	local fh = assert(io.open(file, "wb")) fh:write(IMP.savedText("WuberProbeDB", dbOf(c))) fh:close()
	local out = T.dir .. "/out/probe/fixtures"
	mkdirp(out)
	local said = {}
	eq(PI.main({ "--wtf", dir, "--out", out, "--source", "sim" }, function(l) said[#said + 1] = l end), 0, table.concat(said, "\n"))
	ok(said[2] and said[2]:find("file ids"), tostring(said[2]))
	local fx = assert(L.load(out .. "/sim-probe-" .. run.id .. ".lua"))
	eq(fx.kind, "probe")
	-- a deny list refuses a fixture with a name in it
	local dn = T.dir .. "/out/probe/deny.txt"
	fh = assert(io.open(dn, "wb")) fh:write("Orgrimmar\n") fh:close()
	local code = PI.main({ "--file", file, "--out", out, "--deny", dn }, function() end)
	eq(code, 1, "refused")
	w.missingFiles = {}
	T.clean(w)
end)

-- guard: a source check of the new developer-only addon: it passes on any fake game
test("wprobe: safety: the addon's source never hooks, sends, sets a cvar or calls a protected function (but the typed taint test)", function()
	local src = assert(T.readFile(PROBE_DIR .. "/Probe.lua"))
	local code = src:gsub("%-%-[^\n]*", ""):gsub('"[^"\n]*"', '""') -- comments and string texts out
	for _, bad in ipairs({ "hooksecurefunc", "HookScript", "SendChatMessage", "SendAddonMessage", "SetCVar", "RunMacro", "SecureCmdOptionParse", "UninviteUnit", "InviteUnit", "CastSpell", "TargetUnit", "SetBinding", "CreateMacro" }) do
		ok(not code:find(bad, 1, true), "uses " .. bad)
	end
	local n = 0
	for _ in code:gmatch("ReloadUI") do n = n + 1 end
	eq(n, 1, "ReloadUI appears once: the typed '/probe taint reload' test")
	local toc = assert(T.readFile(PROBE_DIR .. "/WuberProbe.toc"))
	ok(toc:find("SavedVariables: WuberProbeDB", 1, true))
end)
