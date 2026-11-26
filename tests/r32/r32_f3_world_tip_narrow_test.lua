local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- HUNT-32: a window that cannot show the World view (Always narrow, or no room) is not given the
-- "Tap World" tip; it comes back when the window is wide.
local FAKE = {
	{ id = "fly_or_summon", text = "Fly or summon? Wuber shows what flying costs and how long, before you book.", driver = false, screen = "home" },
	{ id = "world_view", text = "Tap World to see every driver on the whole map, with flight routes and boats.", driver = false, screen = "world" },
	{ id = "bounty", text = "No driver going your way? Pin a bounty and Warlocks see where riders want to go.", driver = false, screen = "bounty" },
}

local function ids(Tips)
	local out = {}
	for _, tip in ipairs(Tips.Eligible()) do out[#out + 1] = tip.id end
	return table.concat(out, ",")
end

test("r32 f3: Always narrow skips the World tip", function()
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { saved = { Wuber = { coach = true, fold = { v = 1, pages = {}, narrow = true } } } })
	w:advance(2)
	local W = c.W
	W.Mod("UI.TipTexts").list = FAKE
	local Tips = W.Mod("UI.Tips")
	eq(ids(Tips), "fly_or_summon,bounty", "narrow window: no World tip")
	W.UI.WindowWide(true)
	local Fold = W.UI.Fold
	local real = Fold.Fits
	Fold.Fits = function() return true end
	eq(ids(Tips), "fly_or_summon,world_view,bounty", "wide window: World tip back")
	Fold.Fits = function() return false, "small" end
	eq(ids(Tips), "fly_or_summon,bounty", "no room: no World tip")
	Fold.Fits = function() return false, "combat" end
	ok(ids(Tips):find("world_view", 1, true), "in combat is only for now: still eligible")
	Fold.Fits = real
end)
