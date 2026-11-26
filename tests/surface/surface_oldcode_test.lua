-- Surface guard: the OLD code shapes the real game refused (B4 AutoKeys.lua:108, B5 ReloadUI from a timer / rawget+pcall) must be caught.
-- With WUBER_SURFACE=1 the guard turns each into a violation, so the clean(w) a normal test ends with FAILS: that is "caught".
-- Without the guard the same code passes silently (the fake game as it was), so the tests are skipped.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
H.ADDONS.WuberFxOld = H.root .. "/tests/fixtures/surface/WuberFxOld"
local function mk()
	local w = T.newWorld()
	local c = w:addClient("Test Pilot", { spot = "Orgrimmar", class = "WARLOCK", addons = { "WuberFxOld" }, allowMissing = true })
	T.settle(w)
	return w, c
end
local GUARD = H.surface ~= nil
local function need(name, fn) test(name .. (GUARD and "" or " (guard off: skipped)"), function() if GUARD then fn() end end) end
-- clean(w) is what ends a normal test: it must fail on the old code, and say why
local function caught(w, text)
	local good, err = pcall(T.clean, w)
	ok(not good, "clean(w) fails: the old code is caught")
	ok(tostring(err):find(text, 1, true), "and says why (" .. text .. "): " .. tostring(err):sub(1, 200))
	for i = #w.violations, 1, -1 do w.violations[i] = nil end -- (this test is done with them)
end
need("surface old B4: AutoKeys.lua:108 comparing IsEventRegistered of a Blizzard frame is caught", function()
	local w, c = mk()
	c.env.WuberFxOld.B4old(c.env.UIParent)
	caught(w, "IsEventRegistered")
end)
need("surface old B5: ReloadUI from a C_Timer callback (WuberLabBar shape) is caught", function()
	local w, c = mk()
	c.env.WuberFxOld.B5timer()
	w:advance(1)
	caught(w, "ReloadUI")
end)
need("surface old B5: ReloadUI by rawget + pcall (GameFacts2 shape) is caught", function()
	local w, c = mk()
	c.env.WuberFxOld.B5gamefacts()
	caught(w, "ReloadUI")
end)
