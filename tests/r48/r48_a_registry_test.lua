-- Round 48, group A: BRK-01 (Core.Registry). W.CheckModules reports a module whose dependency did not load
-- first; a module that names ITSELF as a dependency used to pass silently (the same place in the load order
-- is not "later"). Loaded by tests/run.lua with its helper table T (the folder list near its end).
local T = ...
local test, eq, ok, list = T.test, T.eq, T.ok, T.list

test("r48 a: BRK-01 a module that lists itself as a dependency is reported by W.CheckModules", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	eq(#W.CheckModules(), 0, "before: nothing to report: " .. list(W.CheckModules()))
	W.Module("Test.Self", { "Test.Self" })
	W.Module("Test.Fine", { "Test.Self" }) -- an ordinary dependency that loaded first: never reported
	local problems = W.CheckModules()
	eq(list(problems), "Test.Self loads before its dependency Test.Self", "the self-dependency is reported, and only it")
	ok(W.lastError and W.lastError:find("^modules: "), "reported through W.Error: " .. tostring(W.lastError))
	W.lastError = nil
	T.clean(w)
end)

test("r48 a: BRK-01 no shipped module lists itself, and a dependency loaded first still passes", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local W = r.W
	local n = 0
	for name, m in pairs(W.modules) do
		n = n + 1
		for _, dep in ipairs(m.deps) do
			ok(dep ~= name, name .. " does not list itself as a dependency")
			local d = W.modules[dep]
			ok(d and d.seq < m.seq, name .. "'s dependency " .. tostring(dep) .. " loaded before it")
		end
	end
	ok(n > 50, "the whole addon is loaded: " .. n .. " modules")
	W.Module("Test.First")
	W.Module("Test.Second", { "Test.First" })
	eq(#W.CheckModules(), 0, "a dependency that loaded first: nothing to report: " .. list(W.CheckModules()))
	eq(r.W.lastError, nil, "no registry problem at login or now")
	T.clean(w)
end)
