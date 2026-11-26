-- Tests of the module registry (Core: W.Module, W.Mod, W.modules, W.CheckModules), REFACTOR-MAP
-- section 3.2. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list

-- a fresh client's W (the whole addon loaded, logged in)
local function freshW()
	local w = T.newWorld()
	local r = T.rider(w)
	return r.W, w, r
end

test("registry: W.Module returns the module's table, W.Mod the same one; W.modules lists it in load order", function()
	local W, w = freshW()
	eq(type(W.Module), "function", "W.Module")
	eq(type(W.Mod), "function", "W.Mod")
	eq(type(W.CheckModules), "function", "W.CheckModules")
	local before = 0
	for _ in pairs(W.modules) do before = before + 1 end
	local early = W.Mod("Test.B") -- a late ref: asked for before it is defined
	local a = W.Module("Test.A")
	local b = W.Module("Test.B", { "Test.A" }, { standalone = true })
	ok(type(a) == "table" and a ~= b, "a module's own table")
	ok(W.Mod("Test.A") == a, "W.Mod gives the module's table")
	ok(early == b, "a late ref is the table the module fills later")
	eq(W.modules["Test.A"].seq, before + 1, "Test.A's place")
	eq(W.modules["Test.B"].seq, before + 2, "Test.B's place")
	eq(list(W.modules["Test.B"].deps), "Test.A", "Test.B's deps")
	eq(W.modules["Test.B"].opts.standalone, true, "opts kept")
	eq(#W.modules["Test.A"].deps, 0, "no deps: an empty list")
	eq(#W.CheckModules(), 0, "nothing to report: " .. list(W.CheckModules()))
	T.clean(w)
end)

test("registry: a module defined twice is an error at load", function()
	local W, w = freshW()
	W.Module("Test.Twice")
	local okd, err = pcall(W.Module, "Test.Twice")
	ok(not okd, "the second W.Module raised")
	ok(tostring(err):find("module Test.Twice is defined twice", 1, true), "the message: " .. tostring(err))
	T.clean(w)
end)

test("registry: W.CheckModules reports a missing dependency, a dependency loaded later, and a W.Mod nobody defines", function()
	local W, w = freshW()
	W.Module("Test.Early", { "Test.Late" })
	W.Module("Test.Late")
	W.Module("Test.Needy", { "Test.Nowhere" })
	W.Mod("Test.Ghost")
	local problems = W.CheckModules()
	eq(list(problems), "Test.Early loads before its dependency Test.Late; Test.Needy needs Test.Nowhere, which is not loaded; "
		.. "no module named Test.Ghost", "the problems, sorted")
	ok(W.lastError and W.lastError:find("^modules: "), "reported through W.Error (fails clean): " .. tostring(W.lastError))
	-- W.partialLoad (the harness loading only a module's dependencies): unknown W.Mod targets are skipped
	W.partialLoad = true
	eq(list(W.CheckModules()), "Test.Early loads before its dependency Test.Late; Test.Needy needs Test.Nowhere, which is not loaded",
		"partial load: deps still checked, W.Mod targets not")
	W.partialLoad = nil
	W.lastError = nil
	T.clean(w)
end)

test("registry: W.CheckModules runs at PLAYER_LOGIN (a module with a missing dependency is reported)", function()
	local w = T.newWorld()
	local probe = T.dir .. "/fixtures/addons/WuberProbe"
	local c = w:addClient(T.TESTCHAR, { spot = "Orgrimmar", class = "MAGE", addons = { "Wuber", "WuberProbe" },
		addonDirs = { WuberProbe = probe } })
	eq(#w.errors, 0, "no load errors: " .. list(w.errors, "\n"))
	ok(c.W.modules["Probe.Main"], "the probe's module is registered")
	ok(c.W.lastError and c.W.lastError:find("^modules: "), "reported at login (W.lastError): " .. tostring(c.W.lastError))
	local said = table.concat(c.chatLines, "\n")
	ok(said:find("Probe.Main needs Probe.Missing, which is not loaded", 1, true), "the missing dependency, in chat: " .. said)
	ok(said:find("no module named Probe.Ghost", 1, true), "the unknown W.Mod target, in chat: " .. said)
	ok(c.W.loggedIn, "the rest of login still ran")
	-- and Wuber alone (today: no module files yet) logs in with nothing to report
	local r = T.rider(w, "Ana Smith")
	eq(r.W.lastError, nil, "Wuber alone: no registry problems")
	eq(#r.W.CheckModules(), 0, "Wuber alone: CheckModules is clean")
	c.W.lastError = nil
	T.clean(w)
end)
