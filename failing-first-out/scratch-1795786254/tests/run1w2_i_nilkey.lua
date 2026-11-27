-- Run 1 wave 2 group i: DR.NextSummon records why a rider is not summonable by key; a listed rider with
-- only a name (no .key) must not raise "table index is nil".
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

test("run1w2 i: NextSummon with a listed rider that has no key does not error", function()
	local w = H.NewWorld({})
	local a = w:addClient("Ana Smith", { spot = "Undercity", class = "WARLOCK", shards = 10 })
	w:advance(15)
	local DR = a.W.Drive
	ok(DR.SetOpen(true), "open")
	w:advance(3)
	DR.customers = DR.customers or {}
	DR.customers["bob jones"] = { name = "Bob Jones", state = "lead", elsewhere = true }
	local c = DR.NextSummon()
	eq(c, nil, "nobody to summon")
	ok(tostring(DR.whyNoSummonText):find("Bob Jones", 1, true), "the debug note names him: " .. tostring(DR.whyNoSummonText))
	T.clean(w)
end)
