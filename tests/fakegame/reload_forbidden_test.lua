-- Issue #230: the fake game records every ReloadUI from addon code as forbidden (client.reloadForbidden),
-- so a test can assert none happened. The real client blocks it as tainted (PF-050 L13.blocked).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

test("fake game: ReloadUI from addon code is recorded as forbidden and does not reload", function()
	local w = T.newWorld()
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK" })
	eq(#(c.reloadForbidden or {}), 0, "none yet")
	c.env.ReloadUI()
	w:advance(1)
	eq(#(c.reloadForbidden or {}), 1, "the call is on the forbidden list")
	eq(w:clientOf("Anita Lift"), c, "nothing reloaded")
end)
