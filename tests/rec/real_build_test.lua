-- Flight recorder, lane B1: the client build the fake game reports, checked against the real client (WoW Forever,
-- 17-21 Nov 2026; fact build.number in tests/fixtures/rec/lab-real-facts.lua).
local T = ...
local test, eq = T.test, T.eq

-- build.number: "Wuber Rocks 21 Nov 00:06 login 'build=1.60.1/71037/Nov 18 2026/16001'" (9 logins from 20 Nov
-- 23:54 on; 70959 before, 70938 on 18 Nov). Wuber keys its blocked actions by the build (W.Build).
test("rec: real: GetBuildInfo is the current build, 1.60.1 / 71037 / Nov 18 2026 / 16001 (build.number)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local v, b, d, i = r.env.GetBuildInfo()
	eq(v, "1.60.1", "version")
	eq(b, "71037", "build")
	eq(d, "Nov 18 2026", "date")
	eq(i, 16001, "interface")
	eq(r.W.Build(), "71037", "Wuber's build key")
	T.clean(w)
end)

-- build.number: WuberDB.blockedBuild[70938] = { trade = true } was in the real saved variables: a refusal on an
-- older build does not count on the new one, so Wuber tries again there.
test("rec: real: a refusal saved on build 70938 does not block on 71037 (build.number)", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { saved = { Wuber = { blockedBuild = { ["70938"] = { trade = true } } } } })
	eq(r.W.IsBlocked("trade"), false, "the new build tries again")
	r.W.db.blockedBuild["71037"] = { trade = true }
	eq(r.W.IsBlocked("trade"), true, "a refusal on this build counts")
	T.clean(w)
end)
