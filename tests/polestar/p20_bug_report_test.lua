-- Polestar lesson 20: the bug report lists the CHANGED settings only and the other addons, and nothing personal.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function world()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	return w, r
end

-- a test-local stand-in for the game's addon list (the fake game has no list of other addons)
local function stubAddons(r, list)
	local C = r.env.C_AddOns
	C.GetNumAddOns = function() return #list end
	C.GetAddOnInfo = function(i) local a = list[i]; return a.name, a.name, nil, a.loaded end
	C.IsAddOnLoaded = function(n)
		for _, a in ipairs(list) do if a.name == n then return a.loaded end end
		return false
	end
end

test("polestar p20: the report lists only the changed settings and nothing personal", function()
	local w, r = world()
	local W = r.W
	W.db.sound = true
	W.db.fx = "off"
	local c = W.Char()
	c.price = 7000
	c.service = "Farra Way Rides"
	c.dest = "Farra Way"
	c.destWords = "Farra Way home"
	c.caster = "Farra Way"
	c.captain = "Farra Way"
	c.crew = { { name = "Farra Way", role = "lock" } }
	W.db.lastDest = "Farra Way"
	local text = r.W.UI.Bug.Report("x")
	ok(text:find("Changed settings:", 1, true), "has the section")
	ok(text:find("fx = off", 1, true), "a changed setting is listed")
	ok(text:find("price = 7000", 1, true), "a changed driver setting is listed")
	ok(not text:find("sound =", 1, true), "an unchanged setting is not listed")
	ok(not text:find("Farra", 1, true), "no name leaks into the report")
	ok(not text:find("crew =", 1, true), "tables are skipped")
end)

test("polestar p20: nothing changed says none", function()
	local w, r = world()
	r.W.db.advanced = nil
	local text = r.W.UI.Bug.Report("x")
	local sec = text:match("Changed settings:\n([^\n]*)")
	ok(sec, "has the section")
	ok(sec:find("none", 1, true), "none when nothing differs, got: " .. tostring(sec))
end)

test("polestar p20: the report names the other addons", function()
	local w, r = world()
	stubAddons(r, {
		{ name = "Wuber", loaded = true }, { name = "Bagnon", loaded = true },
		{ name = "Details", loaded = true }, { name = "Sleeper", loaded = false },
	})
	local text = r.W.UI.Bug.Report("x")
	ok(text:find("Other addons: 2 loaded", 1, true), "count of the others, not Wuber, not unloaded")
	ok(text:find("Bagnon", 1, true) and text:find("Details", 1, true), "folder names listed")
	ok(not text:find("Sleeper", 1, true), "an addon that is not loaded is not listed")
end)

test("polestar p20: no addon list says unknown, not 0", function()
	local w, r = world()
	r.env.C_AddOns.GetNumAddOns = nil
	r.env.C_AddOns.GetAddOnInfo = nil
	local text = r.W.UI.Bug.Report("x")
	ok(text:find("Other addons: unknown", 1, true), "unknown when the list cannot be read")
	ok(not text:find("Other addons: 0", 1, true), "never a false 0")
end)

test("polestar p20: the report has the class file and level, no name, right after Role", function()
	local w, r = world()
	local text = r.W.UI.Bug.Report("x")
	local role, ch = text:match("\n(Role:[^\n]*)\n([^\n]*)")
	ok(role and ch and ch:find("^Character: %u+ level %d+$"), "a Character line follows Role, got: " .. tostring(ch))
	ok(not ch:find(T.TESTCHAR:match("^%a+"), 1, true), "no name on the line")
end)

test("polestar p20: class and level unknown when the game gives none", function()
	local w, r = world()
	r.env.UnitClass = nil
	r.env.UnitLevel = function() error("boom") end
	local text = r.W.UI.Bug.Report("x")
	ok(text:find("\nCharacter: unknown\n", 1, true), "unknown, no error")
end)
