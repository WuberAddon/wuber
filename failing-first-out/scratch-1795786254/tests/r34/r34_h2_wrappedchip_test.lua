local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

test("r34 h2: the Wrapped chip's first right-click opens the month before, as its tooltip says", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = 1365, screenH = 768 })
	w:advance(15)
	local Mod = r.W.Mod("UI.Rider.Wrapped")
	local UIParent = r.env.UIParent
	local months = { { year = 2026, month = 10 }, { year = 2026, month = 9 }, { year = 2026, month = 8 } }
	local oldM, oldO = Mod.Months, Mod.Open
	local opened = {}
	Mod.Months = function() return months end
	Mod.Open = function(y, m) opened[#opened + 1] = y .. "-" .. m end
	local chip = Mod.Chip(UIParent)
	local click = chip:GetScript("OnClick")
	click(chip, "RightButton")
	click(chip, "RightButton")
	click(chip, "RightButton")
	click(chip, "RightButton")
	click(chip, "LeftButton")
	click(chip, "RightButton")
	eq(table.concat(opened, ","), "2026-9,2026-8,2026-10,2026-9,2026-10,2026-9", "right-click goes back a month each time, wraps, left resets")
	-- one month only: right-click still opens it
	months = { { year = 2026, month = 10 } }
	opened = {}
	local c2 = Mod.Chip(UIParent)
	c2:GetScript("OnClick")(c2, "RightButton")
	eq(opened[1], "2026-10", "a single month")
	Mod.Months, Mod.Open = oldM, oldO
	T.clean(w)
end)
