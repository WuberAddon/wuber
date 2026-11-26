-- tests/speed/profiler_test.lua (job 2749): the speed profiler (tests/lib/screenprof.lua) counts what a change does and
-- leaves the fake game as it found it. Guard tests for the tool (tools/profile-tests.lua --screens) and the budget tests.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local P = dofile(T.dir .. "/lib/screenprof.lua")(H)

-- guard: infra
test("speed: the profiler counts one client's widgets and calls, then puts the harness's methods back", function()
	ok(P.ok, "the harness's widget classes are found")
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local env = c.env
	local probe = env.CreateFrame("Frame", nil, env.UIParent)
	local before = probe.SetPoint
	local sess = P.session(c)
	ok(probe.SetPoint ~= before, "the session wraps SetPoint")
	local m = sess:measure(function()
		local f = env.CreateFrame("Frame", nil, env.UIParent)
		f:SetPoint("CENTER")
		f:SetSize(10, 10)
		local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetText("one")
		fs:SetText("two")
		f:Hide()
	end, { settle = 0.2 })
	sess:close()
	eq(probe.SetPoint, before, "close() puts SetPoint back")
	eq(m.new.Frame, 1, "one frame made")
	eq(m.new.FontString, 1, "one font string made")
	ok((m.calls.setPoint or 0) >= 1, "SetPoint counted")
	eq(m.calls.setText, 2, "two SetText calls counted")
	ok((m.calls.setSize or 0) >= 1, "SetSize counted")
	ok(m.ms >= 0 and m.kb >= 0, "time and memory measured")
	T.clean(w)
end)

-- guard: infra
test("speed: the profiler's scene plays every screen change with no Lua error", function()
	local Scenes = dofile(T.dir .. "/speed/scenes.lua")
	local out = Scenes.run(H, P, {})
	local bad = {}
	for _, r in ipairs(out) do if r.m.err then bad[#bad + 1] = r.id .. ": " .. r.m.err end end
	eq(#bad, 0, "every step ran: " .. table.concat(bad, "; "))
	eq(#out.errors, 0, "no Lua error in the fake game: " .. table.concat(out.errors, "; "))
	ok(#out >= 40, "the whole scene ran")
end)
