-- Tests of the "forbidden in this client" list (PLAN-2.3.2 item 4; round 15, agent E).
-- tools/forbidden.lua is the one list; the fake client (tests/harness.lua, H.applyForbidden) raises
-- ADDON_ACTION_FORBIDDEN like the game when Wuber or any other addon touches an entry, and run.lua
-- fails the test even when the addon swallowed the error (T.runOne is the suite's own judge).
-- The sandbox: the fixture addon tests/fixtures/addons/ForbidProbe, in a world of its own.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list

local PROBE = T.dir .. "/fixtures/addons/ForbidProbe"
local SHIPPED = H.FORBIDDEN

-- a world with Wuber and the probe addon; hits are attributed by file, so the probe gets its name
local function probeWorld()
	local w = T.newWorld({ clubs = true })
	local c = w:addClient("Ana Smith", { spot = "Orgrimmar", class = "MAGE", addons = { "Wuber", "ForbidProbe" },
		addonDirs = { ForbidProbe = PROBE } })
	local seen = {}
	local f = c.env.CreateFrame("Frame")
	f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
	f:SetScript("OnEvent", function(_, _, addon, fn) seen[#seen + 1] = tostring(addon) .. " " .. tostring(fn) end)
	return w, c, seen
end

-- runs body (a test of its own) with the probe's name known to the harness; puts everything back
local function sandbox(body)
	local before = H.ADDONS.ForbidProbe
	H.ADDONS.ForbidProbe = PROBE
	local okc, a, b = pcall(body)
	H.ADDONS.ForbidProbe = before
	H.applyForbidden(SHIPPED)
	if not okc then error(a, 0) end
	return a, b
end

test("forbidden list (sandbox): an addon that swallows the error still fails its test; Wuber's own code too", function()
	local inner
	local passed, why = sandbox(function()
		return T.runOne(function()
			local w, c, seen = probeWorld()
			inner = { w = w, c = c, seen = seen }
			c.env.ForbidProbeGo()
			-- no clean(w), no error: the addon caught every one itself
		end)
	end)
	eq(passed, false, "the test fails")
	for _, n in ipairs({ "RegisterEvent(\"COMBAT_LOG_EVENT_UNFILTERED\")", "UnregisterEvent(\"COMBAT_LOG_EVENT_UNFILTERED\")",
		"CombatLogGetCurrentEventInfo()", "C_Club.SendCharacterInvitation()", "RegisterAllEvents()" }) do
		ok(tostring(why):find(n, 1, true), n .. " in the failure: " .. tostring(why))
	end
	local log = inner.c.env.ForbidProbeLog
	eq(#log, 5, "five tries")
	for _, e in ipairs(log) do
		eq(e.ok, false, e.what .. " raised")
		ok(e.err:find("ADDON_ACTION_FORBIDDEN", 1, true), e.what .. ": " .. e.err)
	end
	eq(#inner.seen, 5, "ADDON_ACTION_FORBIDDEN each time: " .. list(inner.seen))
	eq(inner.seen[1], "ForbidProbe UNKNOWN()", "named for the addon whose code did it, function UNKNOWN() as in the game")
	eq(inner.c.env.CombatLogGetCurrentEventInfo == nil, false, "the API is there (it raises when called)")
	inner.w.violations = {}

	-- Wuber's own code, under W.Safe (its pcall): the same
	local passedW, whyW = sandbox(function()
		return T.runOne(function()
			local w, c, seen = probeWorld()
			inner = { w = w, c = c, seen = seen }
			c.W.Safe("sandbox", function()
				local f = c.env.CreateFrame("Frame")
				f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			end)
		end)
	end)
	eq(passedW, false, "Wuber's swallowed hit fails the test")
	ok(tostring(whyW):find("COMBAT_LOG_EVENT_UNFILTERED", 1, true), tostring(whyW))
	eq(inner.seen[1], "Wuber UNKNOWN()", "named for Wuber")
	inner.w.violations = {}

	-- a test that expects the hit clears it on purpose, and then passes; so does a clean one
	local passedC = sandbox(function()
		return T.runOne(function()
			local w, c = probeWorld()
			c.env.ForbidProbeGo()
			w.violations = {}
		end)
	end)
	eq(passedC, true, "cleared on purpose: passes")
	eq(sandbox(function() return T.runOne(function() probeWorld() end) end), true, "nothing forbidden: passes")
end)

test("forbidden list (sandbox): a new restriction is one line in tools/forbidden.lua (event, api, method), for the harness and check.lua", function()
	local longer = {}
	for _, f in ipairs(SHIPPED) do longer[#longer + 1] = f end
	local EXTRA = {
		{ name = "PLAYER_STARTED_MOVING", kind = "event", why = "test" },
		{ name = "DoSomethingForbidden", kind = "api", path = { "DoSomethingForbidden" }, why = "test (an API the fake never had)" },
		{ name = "SetPassThroughButtons", kind = "method", why = "test (a method the fake never had)" },
		{ name = "EnableMouseWheel", kind = "method", why = "test (a method the fake has)" },
	}
	for _, f in ipairs(EXTRA) do longer[#longer + 1] = f end
	local inner
	local passed, why = sandbox(function()
		H.applyForbidden(longer)
		return T.runOne(function()
			local w, c, seen = probeWorld()
			inner = { w = w, c = c, seen = seen }
			c.env.ForbidProbeGo(EXTRA)
		end)
	end)
	eq(passed, false, "the test fails")
	for _, n in ipairs({ "RegisterEvent(\"PLAYER_STARTED_MOVING\")", "DoSomethingForbidden()", "SetPassThroughButtons()", "EnableMouseWheel()" }) do
		ok(tostring(why):find(n, 1, true), n .. " in the failure: " .. tostring(why))
	end
	eq(#inner.seen, 9, "ADDON_ACTION_FORBIDDEN for the five shipped and the four new: " .. list(inner.seen))
	inner.w.violations = {}
	-- the shipped list is back: the new ones are fine again, the old ones still raise
	local w, c = probeWorld()
	local f = c.env.CreateFrame("Frame")
	ok(pcall(f.RegisterEvent, f, "PLAYER_STARTED_MOVING"), "the event is allowed again")
	ok(pcall(f.EnableMouseWheel, f, true), "the method is itself again")
	eq(f.SetPassThroughButtons, nil, "the made-up method is gone")
	eq((pcall(f.RegisterAllEvents, f)), false, "RegisterAllEvents still raises")
	w.violations = {}
	-- check.lua reads the same list: one more line, one more name it fails on
	local src = "local _, W = ...\nlocal f = CreateFrame('Frame')\nf:SetPassThroughButtons('LeftButton')\nDoSomethingForbidden()\n"
	local hits = T.CHECK.scanForbidden(src, longer)
	local names = {}
	for _, h in ipairs(hits) do names[#names + 1] = h.name .. ":" .. h.line end
	eq(table.concat(names, " "), "SetPassThroughButtons:3 DoSomethingForbidden:4", "check.lua's scan")
	eq(#T.CHECK.scanForbidden(src, SHIPPED), 0, "not on the shipped list")
	T.clean(w)
end)
