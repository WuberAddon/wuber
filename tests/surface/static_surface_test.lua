-- Static surface pass (tools/surface/static-surface.lua): the API surface judged from the SOURCE TEXT, with no test executing the code.
-- The runtime guard (tests/surface-guard.lua) only judges code a test runs: the old AutoKeys.lua:108 compare of a secret answer and the
-- ReloadUI shapes (Sheets.lua:707 in a click, GameFacts2 by name, a timer) reached the real game because no test ran them with the guard on.
-- Nothing below loads a fake game: the pass reads files as text. (Real old files: tests/fixtures/surface/real, cut with git show.)
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local SS = dofile(H.root .. "/tools/surface/static-surface.lua")
local S = dofile(H.root .. "/tests/surface/apisurface.lua")
local FX = H.root .. "/tests/fixtures/surface"

local function slurp(path)
	local f = assert(io.open(path, "rb"))
	local s = f:read("*a")
	f:close()
	return s
end
local function scanText(text, name)
	local found = SS.scanSources({ { name = name or "x.lua", text = text } }, { S = S })
	return found
end
local function scanFile(rel)
	return scanText(slurp(FX .. "/" .. rel), rel)
end
local function pick(found, kind, name)
	local out = {}
	for _, f in ipairs(found) do if f.kind == kind and (not name or f.name == name) then out[#out + 1] = f end end
	return out
end
local function lineOf(text, needle)
	local n = 0
	for l in (text .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		if l:find(needle, 1, true) then return n end
	end
end

-- guard: the lexer is exercised so a comment, a long string or a string never looks like a call (a control: passes on any lexer that is right)
test("static surface: comments, long strings and strings holding ReloadUI() are not calls, and lines stay right", function()
	local text = "--[==[ ReloadUI() ]==]\nlocal s = [[\nReloadUI()\n]]\nlocal t = \"ReloadUI() \\\" CastSpellByName()\"\n-- ReloadUI()\nlocal u = 0x1F + 1e3\nCastSpellByName('x')\n"
	local found = scanText(text)
	eq(#pick(found, "P", "ReloadUI"), 0, "no ReloadUI finding from comments and strings")
	local p = pick(found, "P", "CastSpellByName")
	eq(#p, 1, "the real call is found once")
	eq(p[1].line, 8, "on the right line after a long comment and a long string")
end)

test("static surface: the fixture WuberFxOld gives the B4 and B5 findings with no test executing it", function()
	local text = slurp(FX .. "/WuberFxOld/Old.lua")
	local found = scanText(text, "WuberFxOld/Old.lua")
	-- B4: the compare of the IsEventRegistered answer, on the line "if reg == true" of B4old; B4fixed (issecretvalue first) is clean
	local b4 = pick(found, "B4", "IsEventRegistered")
	eq(#b4, 1, "one B4 finding (B4old; B4fixed is clean)")
	eq(b4[1].line, lineOf(text, "if reg == true then n = n + 1 end"), "on the compare line of B4old")
	ok(b4[1].gate, "B4 gates")
	-- B5: the three ReloadUI shapes: a timer callback, fetched by name (GameFacts2 shape), a click handler
	local ctx = {}
	for _, f in ipairs(pick(found, "P", "ReloadUI")) do ctx[#ctx + 1] = f.ctx end
	table.sort(ctx)
	eq(table.concat(ctx, ","), "onclick,plain,timer", "ReloadUI found in a click handler, by name and in a timer")
	eq(#pick(found, "P", "CastSpellByName"), 1, "a protected call (CastSpellByName)")
	-- the other classes
	eq(#pick(found, "U", "WuberNoSuchApi"), 2, "an undocumented global, twice; the call behind its own type() test is G")
	eq(#pick(found, "G", "WuberNoSuchApi"), 1, "guarded")
	eq(#pick(found, "U", "C_Map.NoSuchThing"), 1, "an undocumented C_ function")
	eq(#pick(found, "H", "InviteUnit"), 2, "the hardware-click name is listed (information)")
end)

test("static surface: the real old AutoKeys.lua (6811c42) is flagged at line 108, the fixed one (3b567c9) is clean", function()
	local old = slurp(FX .. "/real/AutoKeys.old-6811c42.lua")
	local b4 = pick(scanText(old, "AutoKeys.old"), "B4")
	eq(#b4, 1, "one B4 finding in the old file")
	eq(b4[1].line, 108, "at line 108, the shape the real game refused: if callm(c, \"IsEventRegistered\", ...) == true")
	eq(b4[1].name, "IsEventRegistered")
	eq(lineOf(old, "if callm(c, \"IsEventRegistered\""), 108, "(the fixture really has that line at 108)")
	local fixed = scanText(slurp(FX .. "/real/AutoKeys.fixed-3b567c9.lua"), "AutoKeys.fixed")
	eq(#pick(fixed, "B4"), 0, "the fixed file has no B4 finding (the answer goes through isSecret, a local helper around issecretvalue)")
	eq(#pick(fixed, "P"), 0)
end)

test("static surface: the real old ReloadUI shapes are found: Sheets.lua:707 in OnClick (before #230) and GameFacts2 by name (before #220)", function()
	local sheets = scanText(slurp(FX .. "/real/Sheets.old-a619607.lua"), "Sheets.old")
	local p = pick(sheets, "P", "ReloadUI")
	eq(#p, 1, "one ReloadUI in the old Sheets.lua")
	eq(p[1].line, 707, "at line 707")
	eq(p[1].ctx, "onclick", "inside the OnClick handler of the retire card")
	local gf = pick(scanText(slurp(FX .. "/real/GameFacts2.old-bda59bb.lua"), "GameFacts2.old"), "P", "ReloadUI")
	eq(#gf, 1, "gfn(\"ReloadUI\") in the old GameFacts2.lua")
	eq(gf[1].line, 197)
	-- the timer shape (WuberLabBar Bar.lua:247) is not in this repository: the fixture WuberFxOld.B5timer stands for it (checked above, ctx "timer")
end)

test("static surface: the secret-compare peephole tells always-secret, conditional and checked answers apart", function()
	-- always secret (SecretReturns=true): UnitHealth compared -> B4, gating
	local a = scanText("local function f(u)\n\tlocal h = UnitHealth(u)\n\tif h > 5 then return 1 end\nend\n")
	eq(#pick(a, "B4", "UnitHealth"), 1, "UnitHealth compared is B4")
	-- conditionally secret (SecretWhen...): UnitName compared -> B4c, information only
	local c = scanText("local function f(u)\n\tlocal n = UnitName(u)\n\tif n == \"Bob\" then return 1 end\nend\n")
	eq(#pick(c, "B4"), 0, "a conditional secret does not gate")
	eq(#pick(c, "B4c", "UnitName"), 1, "UnitName compared is reported as B4c")
	ok(not pick(c, "B4c")[1].gate, "B4c does not gate")
	-- a conditional answer that is never compared is not reported at all
	eq(#scanText("local function f(u)\n\tlocal n = UnitName(u)\n\treturn n\nend\n"), 0, "UnitName returned, not compared: nothing")
	-- checked first: clean
	local k = scanText("local function f(fr)\n\tlocal r = fr:HasScript(\"OnClick\")\n\tif issecretvalue(r) then return nil end\n\treturn r == true\nend\n")
	eq(#pick(k, "B4"), 0, "issecretvalue before the compare: clean")
	-- checked by a local helper whose body calls issecretvalue (by name, as the Lab does with rawget): clean
	local h = scanText("local function sec(v) local g = rawget(_G, \"issecretvalue\") return g and g(v) end\nlocal function f(fr)\n\tlocal r = fr:IsEventRegistered(\"X\")\n\tif sec(r) then return nil end\n\tif r == true then return 1 end\nend\n")
	eq(#pick(h, "B4"), 0, "a helper that wraps issecretvalue counts as the check")
	-- the same compare with no check before it is flagged, also straight on the call and through pcall / callm
	eq(#pick(scanText("local function f(fr)\n\tif fr:IsEventRegistered(\"X\") == true then return 1 end\nend\n"), "B4"), 1, "direct compare on the call")
	eq(#pick(scanText("local function f(fr)\n\tlocal ok, h = pcall(fr.GetScript, fr, \"OnEvent\")\n\tif h then return 1 end\nend\n"), "B4"), 1, "pcall(fr.GetScript, ...) result tested")
	eq(#pick(scanText("local function f(fr)\n\tlocal r = callm(fr, \"HasScript\", \"OnClick\")\n\tif not r then return 1 end\nend\n"), "B4"), 1, "callm(fr, \"HasScript\") result negated")
	-- the addon's own frame (self, or a local from CreateFrame) is not a game frame
	eq(#pick(scanText("function M:f()\n\treturn self:IsEventRegistered(\"X\") == true\nend\n"), "B4"), 0, "self is the addon's own frame")
	eq(#pick(scanText("local fr = CreateFrame(\"Frame\")\nlocal function f()\n\treturn fr:IsEventRegistered(\"X\") == true\nend\n"), "B4"), 0, "a frame the addon created")
	-- a plain method that is not secret
	ok(not S.methods.GetNumPoints.csa and not S.methods.GetNumPoints.sr, "(GetNumPoints carries no secret flag in the docs)")
	eq(#scanText("local function f(fr)\n\tlocal n = fr:GetNumPoints()\n\tif n == 1 then return 1 end\nend\n"), 0, "a method with no secret flag compared: fine")
	eq(#pick(scanText("local function f(fr)\n\tlocal n = fr:GetName()\n\tif n == \"a\" then return 1 end\nend\n"), "B4c", "GetName"), 1, "GetName is secret per aspect (ObjectName): information")
end)

test("static surface: ReloadUI is P in a click, a timer, by _G and by string, and the words Type /reload are not a call", function()
	eq(#pick(scanText("b:SetScript(\"OnClick\", function() ReloadUI() end)\n"), "P", "ReloadUI"), 1, "in OnClick")
	eq(#pick(scanText("C_Timer.After(1, function() ReloadUI() end)\n"), "P", "ReloadUI"), 1, "in a timer")
	eq(#pick(scanText("local f = _G.ReloadUI\n"), "P", "ReloadUI"), 1, "_G.ReloadUI")
	eq(#pick(scanText("local f = rawget(_G, \"ReloadUI\")\n"), "P", "ReloadUI"), 1, "by string")
	eq(#pick(scanText("C_UI.Reload()\n"), "P", "C_UI.Reload"), 1, "C_UI.Reload")
	eq(#pick(scanText("local text = \"Type /reload to finish\"\n"), "P"), 0, "the words are not a call")
end)

-- guard: the API flags the pass relies on are in apisurface.lua (the generator now writes the secret kinds apart)
test("static surface: apisurface.lua carries the secret kinds the generator used to merge into sr", function()
	eq(S.globals.UnitName.sw, "UnitNameIdentityRestricted", "UnitName: conditional (SecretWhenUnitNameIdentityRestricted)")
	eq(S.methods.GetText.sas, "Text", "GetText: secret for the Text aspect only")
	ok(S.methods.IsShown.sas and S.methods.GetAlpha.sas and S.methods.GetChildren.sas, "IsShown, GetAlpha, GetChildren: per aspect")
	ok(S.methods.IsEventRegistered.csa and S.methods.GetAttribute.csa, "the ConstSecretAccessor methods")
	ok(S.methods.IsEventRegistered.aut, "SecretArguments=AllowedWhenUntainted is recorded")
	ok(S.globals.UnitHealth.sra, "SecretReturns=true is always secret")
	local chat = 0
	local function count(t) for _, d in pairs(t) do if type(d) == "table" and d.scl then chat = chat + 1 end end end
	count(S.globals) count(S.methods)
	for _, ns in pairs(S.ns) do count(ns) end
	ok(chat >= 38, "SecretInChatMessagingLockdown: " .. chat .. " functions (the research counted 38)")
end)

-- guard: current main code stays clean; the allow list is exact (a finding with no entry fails, an entry matching nothing fails)
test("static surface: the whole addon (Wuber + Lab by their TOCs) has no P and no B4 finding left outside tests/surface/allow.lua", function()
	local t0 = os.clock()
	local found, stat = SS.run({ root = H.root })
	ok(found, "the pass ran: " .. tostring(stat))
	local counts, gate = SS.summary(found, stat)
	local bad = {}
	for _, f in ipairs(found) do if f.gate and not f.allowed then bad[#bad + 1] = f.kind .. " " .. f.file .. ":" .. f.line .. " " .. f.name end end
	eq(#bad, 0, "gating findings with no allow entry: " .. table.concat(bad, "; "))
	eq(gate, 0)
	eq(counts.P or 0, 0, "no P")
	local entries = 0
	for _, e in ipairs(dofile(H.root .. "/tests/surface/allow.lua")) do if e[1]:find("^static:") then entries = entries + 1 end end
	eq(stat.allowed, entries, "every static entry of allow.lua matches a finding (no stale entry)")
	ok(stat.files >= 150, "the TOCs gave " .. stat.files .. " files")
	ok(os.clock() - t0 < 30, "the pass is fast: " .. string.format("%.2f", os.clock() - t0) .. " s")
end)
