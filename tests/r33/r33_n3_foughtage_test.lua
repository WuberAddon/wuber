local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- HUNT-48: "fought enemy players X min ago" keeps growing after the beacon arrived.

test("r33 n3: the fight age grows with the clock after the beacon came", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	w:advance(15)
	local t0 = r.env.GetTime()
	local d = { danger = 2, dangerSecs = 120, dangerAt = t0 - 120, heard = t0 }
	local _, s1 = r.W.UI.DangerOf(d)
	ok(s1 and s1 >= 120 and s1 <= 122, "at arrival about 120 s: " .. tostring(s1))
	w:advance(180)
	local _, s2 = r.W.UI.DangerOf(d)
	ok(s2 and s2 >= 300 and s2 <= 303, "180 s later about 300 s: " .. tostring(s2))
	local _, line = r.W.UI.DangerLine(2, s2, "Ana")
	ok(line:find("5 min ago", 1, true), line)
	-- only the age as sent (no time of the fight): kept as before
	local _, s3 = r.W.UI.DangerOf({ danger = 2, dangerSecs = 40 })
	eq(s3, 40, "as sent")
end)
