-- WuberProbe taint and combat-lockdown probes (job 2908, Fable item 8, feature C): the importer, the sweep-versus-allow-list compare, the list generator,
-- the harness learning its protection rule (H.protectRule) and, when the addon folder is found, the probes run in the fake game (part B as in probe_test.lua).
-- THE FIXTURE HERE IS SYNTHETIC (tests/fixtures/probe/SYNTHETIC-protect.lua): invented answers, never real client data, never "measured".
-- Every test fails on the base commit (no taintSweep / protect in the importer, no protection rule in the harness, no tools) unless it carries a "-- guard:" line.
local T = ...
local H, test, eq, ok = T.H, T.testOutside or T.test, T.eq, T.ok

local ROOT = T.dir .. "/.."
local PI = assert(loadfile(ROOT .. "/tools/rec/probe-import.lua"))("--lib")
local TC = assert(loadfile(ROOT .. "/tools/rec/taint-compare.lua"))("--lib")
local TL = assert(loadfile(ROOT .. "/tools/rec/taint-list.lua"))("--lib")
local L = dofile(T.dir .. "/lib/probe_learn.lua")
local FIX = T.dir .. "/fixtures/probe/SYNTHETIC-protect.lua"
local ALLOW = assert(loadfile(T.dir .. "/fakegame/taint-allow.lua"))()

local function withLearning(fn)
	local saved = L.save(H)
	local ok2, err = pcall(fn)
	L.restore(H, saved)
	if not ok2 then error(err, 0) end
end

---------------------------------------------------------------------------
-- importer
---------------------------------------------------------------------------
test("k4 import: a run's sweep, propagation rows, fight reads and dummy step come out as fixture fields", function()
	local run = { id = "r1", build = "71037", started = {}, ran = {}, blocked = {}, p = {
		sweep = { has = true, n = 2, rows = { UIParent = true, GameTooltip = "Other" } },
		protprop = { built = true, rows = { S = { prot = true, explicit = true }, kid = { prot = true, explicit = false } } },
		dummy = { control = { { op = "S:Show", ok = true } }, fight = { { op = "S:Show", ok = false } }, ended = "10 s", blockedRows = 3 },
	}, k4 = { combat = { { tag = "start", lock = true } } } }
	local fx = assert(PI.convert(run, "sim"))
	eq(fx.taintSweep.n, 2) eq(fx.taintSweep.rows.GameTooltip, "Other")
	eq(fx.protect.kid.prot, true)
	eq(fx.protectCombat[1].tag, "start")
	eq(fx.dummy.fight[1].ok, false) eq(fx.dummy.ended, "10 s")
	run.p.protprop.built = false
	eq(PI.convert(run, "sim").protect, nil, "frames that were never built teach nothing")
end)

---------------------------------------------------------------------------
-- compare with taint-allow.lua
---------------------------------------------------------------------------
test("k4 compare: a tainted name nobody listed is a risk; a listed name that measured secure may go; an unasked entry is unmeasured", function()
	local fx = assert(loadfile(FIX))()
	local r = TC.compare(fx.taintSweep.rows, ALLOW)
	eq(#r.risks, 1) eq(r.risks[1].name, "GameTooltip") eq(r.risks[1].by, "SomeOtherAddon")
	local un = table.concat(r.unneeded, ",")
	ok(un:find("UIParent", 1, true) and un:find("WorldFrame", 1, true), "UIParent and WorldFrame measured secure: " .. un)
	ok(not un:find("TradeFrame", 1, true), "TradeFrame was tainted, so its entry stays")
	local um = table.concat(r.unmeasured, ",")
	ok(um:find("Minimap", 1, true) and um:find("UISpecialFrames", 1, true), "Minimap and UISpecialFrames were never asked: " .. um)
	local said = table.concat(TC.report(fx, ALLOW), "\n")
	ok(said:find("NOT MEASURED", 1, true), "a simulator fixture says it proves the tool only")
	ok(said:find("risk: GameTooltip", 1, true), said)
	local lines = {}
	eq(TC.main({ "--help" }, function(l) lines[#lines + 1] = l end), 0)
	ok(lines[1]:find("taint-compare.lua", 1, true))
end)

---------------------------------------------------------------------------
-- the generated list
---------------------------------------------------------------------------
test("k4 list: windows, C_ tables and their fields come out; the addon's own names and comments do not", function()
	local src = { 'local m = WorldMapFrame.ScrollContainer\nC_Map.GetBestMapForUnit("player")\nlocal f = WuberFrame\n-- TradeFrame2 in a comment\nGameTooltip:Show()' }
	local list = TL.scan(src, { parents = { Minimap = "x" }, fields = { ["StaticPopup1.text"] = "y" } })
	local g = "," .. table.concat(list.globals, ",") .. ","
	for _, n in ipairs({ "WorldMapFrame", "C_Map", "Minimap", "UIParent", "StaticPopup1" }) do ok(g:find("," .. n .. ",", 1, true), n) end
	ok(not g:find("WuberFrame", 1, true) and not g:find("TradeFrame2", 1, true) , g)
	local f = {}
	for _, p in ipairs(list.fields) do f[p[1] .. "." .. p[2]] = true end
	ok(f["WorldMapFrame.ScrollContainer"] and f["C_Map.GetBestMapForUnit"] and f["StaticPopup1.text"], "fields")
	local P = {}
	assert(loadstring(TL.render(list)))(nil, P)
	eq(#P.TAINT.globals, #list.globals) eq(#P.TAINT.fields, #list.fields)
end)

---------------------------------------------------------------------------
-- the harness learns the protection rule
---------------------------------------------------------------------------
test("k4 learn: the stand-in's propagation rows become H.protectRule; reset and restore put the old guess back", function()
	local fx = assert(loadfile(FIX))()
	local r = L.protectRule(fx)
	eq(r.child, true) eq(r.anchored, true) eq(r.parent, true) eq(r.control, false) eq(r.createUnder, true)
	eq(L.protectRule({}), nil, "no rows: nothing learned")
	withLearning(function()
		L.reset(H)
		eq(H.protectRule, nil)
		L.apply(H, fx)
		ok(H.protectRule and H.protectRule.child, "applied")
		local saved = L.save(H)
		L.reset(H)
		eq(H.protectRule, nil, "reset")
		L.restore(H, saved)
		ok(H.protectRule and H.protectRule.anchored, "restored")
		L.reset(H)
	end)
end)

local function secureWorld()
	local w = T.newWorld()
	local c = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE", money = 1000 })
	local CF = c.env.CreateFrame
	local box = CF("Frame", nil, c.env.UIParent)
	local S = CF("Button", nil, box, "SecureActionButtonTemplate")
	S:SetSize(40, 20) S:SetPoint("CENTER")
	local kid = CF("Frame", nil, S) kid:SetSize(10, 10) kid:SetPoint("CENTER")
	local label = kid:CreateFontString(nil, "OVERLAY", "GameFontNormal") label:SetText("Paused during combat")
	local tied = CF("Frame", nil, c.env.UIParent) tied:SetSize(10, 10) tied:SetPoint("TOPLEFT", S, "BOTTOMRIGHT")
	local ctl = CF("Frame", nil, c.env.UIParent) ctl:SetSize(10, 10) ctl:SetPoint("CENTER", c.env.UIParent, "CENTER", 50, 0)
	return w, c, { box = box, S = S, kid = kid, tied = tied, ctl = ctl, label = label }
end

test("k4 learn: B6 class: with the learned rule a plain frame under or anchored to a secure frame is protected in a fight, a loose one is not", function()
	withLearning(function()
		L.apply(H, assert(loadfile(FIX))())
		local w, c, f = secureWorld()
		local a, b = f.kid:IsProtected()
		eq(a, true, "the plain child answers protected") eq(b, false, "implicitly, not explicitly")
		eq(f.tied:IsProtected(), true, "anchored to it")
		eq(f.ctl:IsProtected(), false, "a loose frame")
		f.kid:Hide() f.kid:Show() f.tied:SetPoint("TOPLEFT", f.S, "BOTTOMRIGHT", 2, 0) f.label:SetText("x")
		eq(#w.violations, 0, "out of a fight everything is allowed")
		w:enterCombat(c)
		f.ctl:Hide() f.ctl:Show()
		eq(#w.violations, 0, "the loose frame is free in a fight")
		f.label:SetText("Paused during combat")
		eq(#w.violations, 0, "text of a label is allowed in a fight")
		f.kid:Hide()
		eq(#w.violations, 1, "hiding the plain child of a secure frame in a fight is a protected call")
		ok(w.violations[1]:find("protected frame", 1, true), w.violations[1])
		eq(f.kid:IsShown(), true, "and it did nothing")
		f.tied:SetPoint("TOPLEFT", f.S, "BOTTOMRIGHT", 5, 0)
		eq(#w.violations, 2, "moving the anchored frame is blocked too")
		w.violations = {}
		w:leaveCombat(c)
		T.clean(w)
	end)
end)

test("k4 learn: N25-F: CreateFrame under a protected parent is refused in a fight once the dummy step said so", function()
	withLearning(function()
		L.apply(H, assert(loadfile(FIX))())
		local w, c, f = secureWorld()
		w:enterCombat(c)
		local made, err = pcall(c.env.CreateFrame, "Frame", nil, f.S)
		eq(made, false, "refused") ok(tostring(err):find("ADDON_ACTION_BLOCKED", 1, true), tostring(err))
		eq(#w.violations, 1)
		local fine = pcall(c.env.CreateFrame, "Frame", nil, f.ctl)
		eq(fine, true, "under a loose frame it is fine")
		w.violations = {}
		w:leaveCombat(c)
		eq(pcall(c.env.CreateFrame, "Frame", nil, f.S), true, "after the fight it is fine")
		T.clean(w)
	end)
end)

-- guard: the old guess is what every other test runs on until a real probe run teaches a rule (nothing learned = no change)
test("k4 learn: without a learned rule a plain child of a secure frame is not protected (the old guess), a parent of one is", function()
	withLearning(function()
		L.reset(H)
		local w, c, f = secureWorld()
		eq(f.kid:IsProtected(), false) eq(f.tied:IsProtected(), false) eq(f.box:IsProtected(), true)
		T.clean(w)
	end)
end)

---------------------------------------------------------------------------
-- part B: the probes run in the fake game
---------------------------------------------------------------------------
local function exists(p) local f = io.open(p .. "/WuberProbe.toc", "rb") if f then f:close() return true end end
local PROBE_DIR
for _, d in ipairs({ os.getenv("WUBER_PROBE_DIR"), T.dir .. "/../../WuberProbe", T.dir .. "/../WuberProbe" }) do
	if d and d ~= "" and exists(d) then PROBE_DIR = d break end
end
if not PROBE_DIR then
	test("k4 probe: part B skipped (the WuberProbe addon folder was not found; set WUBER_PROBE_DIR)", function() end)
	return
end
H.ADDONS.WuberProbe = PROBE_DIR
local function probeClient(w) return w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE", money = 1000, addons = { "WuberProbe" }, allowMissing = true }) end

test("k4 probe: /probe run auto adds the sweep and the propagation rows, and the propagation rows read the plain defaults of the fake game", function()
	local w = T.newWorld()
	local c = probeClient(w)
	c:slash("/probe on") c:slash("/probe run auto")
	for _ = 1, 200 do w:advance(0.25) end
	w.missingFiles = {}
	local run = c.env.WuberProbeDB.runs[#c.env.WuberProbeDB.runs]
	for _, n in ipairs({ "sweep", "protprop" }) do
		ok(run.ran[n] and run.ran[n].done, n .. " finished")
		eq(run.ran[n].err, nil, n .. " error")
	end
	eq(run.p.sweep.has, true)
	ok(run.p.sweep.n > 20, "the generated list was swept: " .. tostring(run.p.sweep.n))
	eq(run.p.protprop.built, true)
	eq(run.p.protprop.rows.S.prot, true, "the secure button is protected")
	eq(run.p.protprop.rows.ctl.prot, false, "the loose control is not")
	local fx = assert(PI.convert(run, "sim"))
	ok(fx.protect and fx.protect.S, "the importer carries the rows")
	T.clean(w)
end)

test("k4 probe: a fight with no dummy step: only reads, nothing changes, the protected frames stay as they were, no violation", function()
	local w = T.newWorld()
	local c = probeClient(w)
	c:slash("/probe on") c:slash("/probe run auto")
	for _ = 1, 200 do w:advance(0.25) end
	w.missingFiles = {}
	w:enterCombat(c) w:advance(0.5) w:advance(2.5)
	w:leaveCombat(c) w:advance(0.5)
	local run = c.env.WuberProbeDB.runs[#c.env.WuberProbeDB.runs]
	ok(run.k4 and #run.k4.combat >= 2, "start and end of the fight were read")
	eq(run.k4.combat[1].tag, "start") eq(run.k4.combat[#run.k4.combat].tag, "end")
	eq(run.k4.combat[1].frames.S.prot, true)
	eq(#w.violations, 0, table.concat(w.violations, "; "))
	T.clean(w)
end)

test("k4 probe: the dummy step tries its own secure frame in a fight, the fake game blocks the protected ones, the control passes out of a fight", function()
	local w = T.newWorld()
	local c = probeClient(w)
	c:slash("/probe on")
	c:slash("/probe run dummy")
	w:advance(1)
	w:enterCombat(c)
	for _ = 1, 50 do w:advance(0.25) end -- the fight lasts 12 s
	w:leaveCombat(c) w:advance(1)
	local run = c.env.WuberProbeDB.runs[#c.env.WuberProbeDB.runs]
	local d = run.p.dummy
	ok(d and d.fight and #d.fight >= 12, "the ops were tried in the fight")
	local byOp = {}
	for _, r in ipairs(d.control) do byOp[r.op] = r.ok end
	for _, r in ipairs(d.control) do eq(r.took, true, "out of a fight " .. r.op .. " takes effect") end
	eq(byOp["S:Show"], true, "out of a fight the control passes") eq(byOp["S:SetAttribute"], true)
	local blocked = 0
	for _, r in ipairs(d.fight) do if r.op:find("^S:") and (not r.ok or r.took == false) then blocked = blocked + 1 end end
	ok(blocked >= 5, "the secure frame's own calls were refused in the fight: " .. blocked)
	for _, r in ipairs(d.fight) do if r.op:find("^ctl:") then eq(r.took, true, "the loose control is free in the fight: " .. r.op) end end
	ok(run.ran.dummy and run.ran.dummy.done, "the step finished by itself")
	-- the test world expects the violations the fake game raised for the blocked calls: those ARE the probe's answer
	ok(#w.violations >= 5, "the fake game counted the blocked calls")
	w.violations = {}
	T.clean(w)
end)
