local T = ...
local test, eq, ok = T.test, T.eq, T.ok
test("r32 d: equal summon and flight cost never reads 'saves free of gold'", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local Mod = r.W.Mod("UI.Bird")
	local d = { short = "Mia", dest = "Tarren Mill", price = 5000 }
	local s0 = Mod.Message(d, { cost = 9000, secs = 600, about = false })
	ok(s0:find("The summon saves 40s of gold", 1, true), "cheaper summon: " .. s0)
	local s1 = Mod.Message(d, { cost = 3000, secs = 600, about = false })
	ok(s1:find("really 20s", 1, true), "dearer summon: " .. s1)
	local s = Mod.Message(d, { cost = 5000, secs = 600, about = true })
	ok(not s:find("saves", 1, true) and not s:find("free", 1, true), "equal price: " .. s)
	ok(s:find("costs the same as flying, and about", 1, true), "equal price wording: " .. s)
	T.clean(w)
end)
