-- The Auto check's new timing row a_pulse_ring: the Waiting for riders ring starts about every 3 seconds, one ring.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoCheck.lua") then
	test("playtest pulse ring: Wuber Lab not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local function newLab()
	local w = T.newWorld()
	local c = w:addClient("Watcher", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080 })
	T.settle(w)
	c.env.Screenshot = function() c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	return w, c, c.ns.WuberLab
end

test("playtest pulse ring: the Auto check has the ring row and it is a screen", function()
	local w, c, L = newLab()
	local have
	for _, s in ipairs(L.AutoScreens()) do if s.id == "a_pulse_ring" then have = s end end
	ok(have, "a_pulse_ring is an Auto check screen")
	ok(have and type(have.ready) == "function" and type(have.verify) == "function", "it waits and judges")
end)

test("playtest pulse ring: run in the fake game the row passes or is skipped, never a look", function()
	local w, c, L = newLab()
	ok(L.AutoStart({ words = { "a_pulse_ring" } }), "started")
	for _ = 1, 1800 do
		if not L.AutoRunning() then break end
		w:advance(1)
	end
	ok(not L.AutoRunning(), "ended")
	local auto = L.lastAuto
	local rows = {}
	for _, r in ipairs(auto and auto.results or {}) do
		if r.id == "a_pulse_ring" then rows[#rows + 1] = r.status .. ": " .. tostring(r.detail) end
	end
	ok(#rows > 0, "the row reported something")
	for _, r in ipairs(rows) do ok(not r:find("^look"), r) end
end)
