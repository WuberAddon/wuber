-- Lab job 2880: the Auto check takes a screenshot only of a screen that needs a look or is new (WuberLabDB.autoSeen);
-- /lab auto shots takes them all (the old way). The checks run on every screen either way. Times are the fake game's clock.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local newWorld, settle = T.newWorld, T.settle

local LAB_DIR = os.getenv("WUBER_LAB_DIR") or (H.root .. "/lab/WuberLab")
if not H.exists(LAB_DIR .. "/AutoCheck.lua") then
	test("lab auto shots: AutoCheck.lua not found (skipped)", function() end)
	return
end
H.ADDONS.WuberLab = LAB_DIR

local function client(w)
	local c = w:addClient("Anita Lift", { spot = "Undercity", class = "WARLOCK", money = 100000, addons = { "Wuber", "WuberLab" },
		allowMissing = not T.HAVE_UI, screenW = 1920, screenH = 1080 })
	settle(w)
	return c
end

-- one Auto check in the fake game: seconds on the fake clock, the screenshots taken, the saved result
local function run(c, w, opts)
	local L = c.ns.WuberLab
	local taken = 0
	c.env.Screenshot = function() taken = taken + 1 c.env.C_Timer.After(0.2, function() c:fire("SCREENSHOT_SUCCEEDED") end) end
	local t0 = c.env.GetTime()
	local started, why = L.AutoStart(opts)
	ok(started, "the Auto check started: " .. tostring(why))
	for _ = 1, 6000 do
		if not L.AutoRunning() then break end
		w:advance(1)
	end
	ok(not L.AutoRunning(), "the Auto check reached its end")
	return c.env.GetTime() - t0, taken, L.lastAuto or {}
end

local function checksOf(last)
	local out = {}
	for _, r in ipairs(last.results or {}) do if r.status == "look" or r.status == "skip" then out[#out + 1] = r.id .. "|" .. r.view .. "|" .. r.kind .. "|" .. r.status end end
	table.sort(out)
	return table.concat(out, "\n")
end

test("lab auto shots: only new screens and looks get a screenshot; /lab auto shots takes all; the checks are the same", function()
	local w = newWorld()
	w:addClient("Mia Runner", { spot = "Undercity", class = "WARLOCK" })
	local c = client(w)
	local L, W = c.ns.WuberLab, c.W
	c.env.IsInGuild = function() return true end
	W.UI.Toggle(true)
	w:advance(2)
	local words = { "ride" } -- the rider's screens: enough to time, quick to run
	if os.getenv("AUTO_SHOTS_FULL") then words = {} end -- every screen (the report's measurement)
	ok(c.ns.WuberLab.db.autoSeen == nil, "no new-screens list yet")
	local tAll, nAll, lastAll = run(c, w, { words = words, shots = true })
	local screens = #lastAll.screens
	ok(screens > 10, "screens checked: " .. screens)
	eq(nAll, #lastAll.shots, "every shot is in the shot list")
	ok(nAll >= screens - 5, "shots=true photographs the screens: " .. nAll .. " of " .. screens)
	local seen = 0
	for _ in pairs(L.db.autoSeen or {}) do seen = seen + 1 end
	eq(seen, nAll, "every photographed screen is in the new-screens list")
	-- second run, the screens are known: a shot only where a check said look
	local tNew, nNew, lastNew = run(c, w, { words = words })
	local looks = {}
	local nLook = 0
	for _, r in ipairs(lastNew.results or {}) do
		if r.status == "look" and not looks[r.id .. "|" .. r.view] then looks[r.id .. "|" .. r.view] = true nLook = nLook + 1 end
	end
	ok(nNew <= nLook, "shots only where a check said look: " .. nNew .. " shots, " .. nLook .. " screens with a look")
	print(("AUTO-SHOTS-TIMING ride screens=%d: all shots %.0f s (%d shots); new screens/looks only %.0f s (%d shots)"):format(screens, tAll, nAll, tNew, nNew))
	ok(tNew < tAll * 0.7, ("the second run is faster: %.0f s against %.0f s"):format(tNew, tAll))
	eq(checksOf(lastNew), checksOf(lastAll), "the checks gave the same answers with and without the screenshots")
	eq(#lastNew.screens, screens, "every screen was still checked")
	-- a screen not in the list is photographed once, then not again
	local key
	for k in pairs(L.db.autoSeen) do key = k break end
	L.db.autoSeen[key] = nil
	local _, nOne = run(c, w, { words = words })
	ok(nOne >= nNew + 1 and nOne <= nNew + 2, "the forgotten screen was photographed again: " .. nOne .. " vs " .. nNew)
	ok(L.db.autoSeen[key] ~= nil, "and noted again")
	-- /lab auto shots: the slash command's word
	local _, nCmd = (function() c:slash("/lab auto shots ride") for _ = 1, 6000 do if not L.AutoRunning() then break end w:advance(1) end return 0, 0 end)()
	ok(not L.AutoRunning(), "/lab auto shots ran")
end)
