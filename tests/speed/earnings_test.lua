-- tests/speed/earnings_test.lua (job 2749, speed-earnings): opening the driver's Earnings page again, with nothing changed,
-- makes no widgets and does not walk the whole page asking the layout for every text's edges (the lift for the "Scroll for more" strip
-- was recomputed on every open: ~55 MB and ~230 ms in the fake game).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local P = dofile(T.dir .. "/lib/screenprof.lua")(H)
local Scenes = dofile(T.dir .. "/speed/scenes.lua")

local function drv(c) return c.W.Driver end
local function steps(c, w, ids)
	for _, st in ipairs(Scenes.STEPS) do
		if ids[st[1]] then st[3](c, w) end
		if st[1] == ids.last then break end
	end
end
-- the page's totals line ("12 rides · 3g 20s · 4h open"), as the player reads it
local function statsText(c)
	local found
	for _, wd in ipairs(c.widgets) do
		local ok2, t = pcall(function() return wd.GetText and wd:IsShown() and wd:GetText() end)
		if ok2 and type(t) == "string" and t:find("open$") and t:find("rides?") then found = t end
	end
	return found
end

test("speed: opening Earnings again with nothing changed makes no widgets and allocates under its budget", function()
	local w, c = Scenes.world(H, {})
	local sess = P.session(c)
	local all = {}
	for _, st in ipairs(Scenes.STEPS) do all[st[1]] = st end
	local seq = { "open1", "close1", "open2", "trips1", "ride1", "drive1", "earn1", "earn_back", "earn2" }
	local m2
	for _, id in ipairs(seq) do
		local st = all[id]
		if st then
			local m = sess:measure(function() st[3](c, w) end, { settle = 0.2 })
			if id == "earn2" then m2 = m end
		end
	end
	sess:close()
	ok(m2, "earn2 ran")
	eq(m2.err, nil, "no error")
	eq(m2.newTotal, 0, "no new widgets the second time")
	ok(m2.kb < 2000, "second open of Earnings allocates under 2000 KB (was about 55000): " .. math.floor(m2.kb))
	T.clean(w)
end)

-- guard: the cached lift must not go stale: a ride logged between two opens shows in the totals the second time
test("speed: Earnings shows the new ride after one is logged between two opens", function()
	local w, c = Scenes.world(H, {})
	local D = drv(c)
	for _, id in ipairs({ "open1", "trips1", "drive1" }) do
		for _, st in ipairs(Scenes.STEPS) do if st[1] == id then st[3](c, w) end end
	end
	D.ShowScreen("earnings")
	local before = statsText(c)
	D.ShowScreen("console")
	c.W.Drive.LogRide(123456, "Newcomer", "t", 100000)
	w:advance(1)
	D.ShowScreen("earnings")
	local after = statsText(c)
	ok(before and after, "the totals line is on the page: " .. tostring(before) .. " / " .. tostring(after))
	ok(before ~= after, "the totals changed after a new ride: " .. tostring(before) .. " / " .. tostring(after))
	local tot = c.W.Drive.LogTotals(0, "me")
	ok(tot.rides >= 1, "the ride is in the log")
	T.clean(w)
end)
