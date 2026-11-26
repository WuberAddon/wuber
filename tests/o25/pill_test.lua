-- Issue #25: the World Map's own "Wuber only" pill is never under Wuber's unfolded window: a covered pill moves to the
-- map's bottom-left corner, and back to the bottom-right when the window folds. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function rectOf(f)
	return { l = f:GetLeft(), r = f:GetRight(), b = f:GetBottom(), t = f:GetTop() }
end

local function overlap(a, b)
	local w = math.min(a.r, b.r) - math.max(a.l, b.l)
	local h = math.min(a.t, b.t) - math.max(a.b, b.b)
	if w > 0 and h > 0 then return w, h end
	return 0, 0
end

local function setup(sz)
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	local c = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar", screenW = sz[1], screenH = sz[2], wide = true })
	c.wide = true
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(5)
	local UI = c.W.UI
	UI.Toggle(true)
	w:advance(3)
	UI.OpenSettings()
	w:advance(2)
	return w, c, UI
end

for _, sz in ipairs({ { 1920, 1080 }, { 1600, 900 }, { 1366, 768 } }) do
	test("o25 pill: unfolded window over the map leaves the Wuber only pill clickable (" .. sz[1] .. ")", function()
		local w, c, UI = setup(sz)
		local W = c.W
		if not UI.Fold.IsUnfolded() then UI.Fold.Toggle() w:advance(2) end
		ok(UI.Fold.IsUnfolded(), "the window is unfolded")
		ok(W.Map.ShowDriver("bob stone"), "the map opens on Bob")
		w:advance(0.5)

		local pill = W.Map.OnlyPill()
		ok(pill and H.visible(pill), "the pill shows")
		local sc = c.env.WorldMapFrame.ScrollContainer
		local win = c.env.WuberFrame
		local ow, oh = overlap(rectOf(pill), rectOf(win))
		eq(ow * oh, 0, "the pill and Wuber's window share no area (" .. ow .. " x " .. oh .. ")")
		ok(pill:GetLeft() >= sc:GetLeft(), "the pill is inside the map on the left")
		ok(pill:GetLeft() < sc:GetLeft() + 40, "the pill is in the bottom-left corner")
		ok(pill:GetBottom() < sc:GetBottom() + 40, "the pill is at the bottom")

		-- the real hit order: a click on the pill's centre lands on the pill
		local r = rectOf(pill)
		eq(c:frameAt((r.l + r.r) / 2, (r.b + r.t) / 2), pill, "the topmost frame at the pill's centre is the pill")
		c:clickOn(pill)
		eq(W.db.mapOnly, true, "clicking it turns Wuber only on")
		c:clickOn(pill)
		eq(W.db.mapOnly, nil, "and off again")

		-- folding the window sends it home to the bottom-right
		UI.Fold.Toggle() w:advance(2)
		ok(not UI.Fold.IsUnfolded(), "folded again")
		w:advance(0.5)
		ok(pill:GetRight() > sc:GetRight() - 40, "folded: the pill is back in the bottom-right corner")
		T.clean(w)
	end)
end

test("o25 pill: a folded window leaves the pill in the bottom-right corner", function()
	local w, c, UI = setup({ 1920, 1080 })
	if UI.Fold.IsUnfolded() then UI.Fold.Toggle() w:advance(2) end
	ok(c.W.Map.ShowDriver("bob stone"), "the map opens on Bob")
	w:advance(0.5)
	local pill = c.W.Map.OnlyPill()
	local sc = c.env.WorldMapFrame.ScrollContainer
	ok(pill:GetRight() > sc:GetRight() - 40, "the pill is in the bottom-right corner")
	T.clean(w)
end)
