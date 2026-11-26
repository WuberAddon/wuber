-- Lab job 2913: a targeted Auto check. The Steps note names the screens a run needs (WuberLabBarSteps.auto); the Auto check
-- walks only those (folded and unfolded), with the same checks, and takes one screenshot per named screen (plus any look).
-- No names (or /lab auto all): every screen as before.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle = T.newWorld, T.settle

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoCheck.lua") then
	test("lab auto targeted: AutoCheck.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local function client(w)
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080 })
	settle(w)
	return c
end

local function run(c, w, opts, stopAfter)
	local L = c.ns.WuberLab
	local taken = 0
	c.env.Screenshot = function() taken = taken + 1 c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	local started, why = L.AutoStart(opts)
	ok(started, "the Auto check started: " .. tostring(why))
	for i = 1, 6000 do
		if not L.AutoRunning() then break end
		if stopAfter and i >= stopAfter then L.AutoStop("test") break end
		w:advance(1)
	end
	ok(not L.AutoRunning(), "the Auto check ended")
	return taken, L.lastAuto or {}
end

local function ids(last)
	local set, n = {}, 0
	for _, s in ipairs(last.screens or {}) do if not set[s.id] then set[s.id] = true n = n + 1 end end
	return set, n
end

test("lab auto targeted: the Steps note's screens are the only ones walked, folded and unfolded", function()
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = client(w)
	c.env.WuberLabBarSteps = { name = "STEPS-T", auto = { "home_bounty", "home_empty", "home" } }
	c.W.UI.Toggle(true)
	w:advance(2)
	local _, last = run(c, w, {})
	local set, n = ids(last)
	ok(last.targeted, "the run says it was targeted")
	ok(n >= 1 and n <= 3, "only the named screens: " .. n)
	for id in pairs(set) do ok(id == "home_bounty" or id == "home_empty" or id == "home", "walked a screen that was not named: " .. id) end
	ok(not set.home_bounty or set.home, "home alone is home, not every home_*") -- exact ids win over prefixes
	ok(#last.screens > n, "folded and unfolded views were both walked: " .. #last.screens .. " views of " .. n)
	ok(last.planSecs and last.planSecs > 0 and last.planSecs < 120, "it said how long the targeted run takes: " .. tostring(last.planSecs))
end)

-- guard: the full walk is unchanged when the note names no screens
test("lab auto targeted: no names, or /lab auto all, is the full walk", function()
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = client(w)
	local L = c.ns.WuberLab
	c.env.WuberLabBarSteps = { name = "STEPS-T" }
	c.W.UI.Toggle(true)
	w:advance(2)
	local _, last = run(c, w, {}, 3)
	ok(not last.targeted and last.subset == nil, "no names: not targeted")
	ok((last.planned or 0) > 50, "a full walk is planned: " .. tostring(last.planned))
	c.env.WuberLabBarSteps = { name = "STEPS-T", auto = { "home" } }
	local _, last2 = run(c, w, { full = true }, 3)
	ok(last2.subset == nil, "full = true walks everything even when the note names screens")
end)

test("lab auto targeted: one screenshot per named screen, none for the rest of the walk", function()
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = client(w)
	c.W.UI.Toggle(true)
	w:advance(2)
	c.env.WuberLabBarSteps = { name = "STEPS-T" }
	local _, first = run(c, w, { words = { "ride" }, shots = true }) -- every ride screen is now "seen"
	local _, nRide = ids(first)
	local taken, last = run(c, w, { words = { "ride" }, shotWords = { "home" } })
	local named = 0
	for _, s in ipairs(last.screens) do if s.id == "home" then named = named + 1 end end
	ok(named >= 1 and taken >= named, "the named screen is shot: " .. taken)
	ok(taken <= named + (last.counts.look or 0), "nothing else is shot (" .. taken .. " shots, " .. named .. " named, " .. (last.counts.look or 0) .. " looks of " .. nRide .. " screens)")
end)
