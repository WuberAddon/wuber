-- Group Finder (group D): folded Home, nobody online, the setting on: the search row at the top must not push the empty
-- state's "Pin a bounty" (the usual place's bounty) past the bottom of the page. The layout checker's engine reads the rects.
-- Setting off: no Group Finder element on Home and no C_LFGList call.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local E = assert(loadfile(H.root .. "/tests/layout/engine.lua"))(H)

local function setup(on, tall)
	local untag = E.tag({ Wuber = H.ADDONS.Wuber })
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR, { screenW = 1920, screenH = 1080, saved = { Wuber = { coach = true } } })
	w:advance(15)
	local W, UI = c.W, c.W.UI
	W.Usual = function() return { dest = "Ironforge" } end
	if on then W.db.groupFinder = true end
	if tall then -- the tallest the card gets: the search row with its reason line, and the count line
		W.GroupFinder.Pending = function() return true end
		W.GroupFinder.ExtraCount = function() return 999 end
	end
	UI.Toggle(true)
	w:advance(3)
	W.db.fold = { v = 1, pages = {}, narrow = true }
	UI.Fold.Apply()
	w:advance(2)
	UI.Show("home")
	w:advance(2)
	UI.Refresh(true)
	w:advance(1)
	untag()
	return w, c, W, UI
end

local function rect(f)
	local l, b, wd, ht = f:GetRect()
	return { l = l or 0, b = b or 0, w = wd or 0, h = ht or 0, t = (b or 0) + (ht or 0) }
end

test("gf d-1: folded Home, nobody online, setting on, the tallest card: Pin a bounty lies fully inside the visible page", function()
	local w, c, W, UI = setup(true, true)
	local s = UI.state.screens.home
	ok(H.visible(s.gfSearch), "the search row shows")
	local e = s.empty
	ok(H.visible(e.bountyGo), "Pin a bounty shows")
	local b, clip = rect(e.bountyGo), rect(s.clip)	ok(b.b >= clip.b - 0.5, ("Pin a bounty ends %.1f below the page's bottom"):format(clip.b - b.b))
	ok(b.t <= clip.t + 0.5, "Pin a bounty starts inside the page")
	local g = rect(s.gfRows)
	ok(g.b >= clip.b - (tonumber(UI.state.scrollMax) or 0) - 0.5, "the Group Finder card is reachable by scrolling")
	local bad = {}
	for _, p in ipairs(E.check(c) or {}) do
		local key = tostring(p.key or "") .. " " .. tostring(p.what or "") .. " " .. tostring(p.detail or "")
		if key:find("Home.lua", 1, true) and not key:find("HomeMap.lua:%d+ canvas") then bad[#bad + 1] = tostring(p.kind) .. ": " .. key end
	end
	eq(#bad, 0, "layout problems in Home: " .. table.concat(bad, " | "))
	T.clean(w)
end)

test("gf d-2: setting off: no Group Finder element on Home, no C_LFGList call, Pin a bounty as before", function()
	local w, c, W, UI = setup(false)
	local s = UI.state.screens.home
	eq(s.gfRows, nil, "no Group Finder frames built")
	ok(H.visible(s.empty.bountyGo), "Pin a bounty shows")
	eq(#(w.lfg and w.lfg.calls or {}), 0, "C_LFGList calls")
	T.clean(w)
end)
