local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- HUNT-01: the window's saved place comes back exactly where the player left it, whether it was
-- dragged two panes wide or one pane wide, after closing and opening and after a /reload.

local function ui(c) return c.W.Mod("UI.Kit").ui end

local function open(w, c)
	c.wide = true -- a game window with room for two panes (as tests/ui/fold_test.lua)
	c.W.db.coach = true -- no first-open tips (their page never unfolds)
	c.W.UI.Toggle(true)
	w:advance(2.5)
end

local function shut(w, c)
	c.W.UI.Toggle(false)
	w:advance(1)
end

local function spot(c)
	local win = ui(c).win
	return { l = win:GetLeft(), t = win:GetTop(), w = win:GetWidth() }
end

local function same(a, b) return math.abs(a.l - b.l) <= 1 and math.abs(a.t - b.t) <= 1 end
local function say(s) return ("left %.0f top %.0f width %.0f"):format(s.l, s.t, s.w) end

test("r30 b window place: dragged two panes wide, Wuber opens where it was left after close/open and /reload", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	-- a place chosen before (at the default place a 1920 wide screen keeps it narrow, off the chat)
	r.W.db.pos = { "CENTER", "CENTER", 0, 0 }
	open(w, r)
	ok(r.W.UI.Fold.IsUnfolded(), "control: the Ride page opens two panes wide")
	r:drag(ui(r).top, -140, 70)
	w:advance(0.5)
	local left = spot(r)
	ok(left.w > 700, "control: dragged while two panes wide (" .. say(left) .. ")")
	shut(w, r)
	open(w, r)
	local back = spot(r)
	ok(same(back, left), "close and open: dragged to " .. say(left) .. ", opened at " .. say(back))
	local r2 = w:reload(r)
	w:advance(2)
	open(w, r2)
	local after = spot(r2)
	ok(same(after, left), "after /reload: dragged to " .. say(left) .. ", opened at " .. say(after))
	T.clean(w)
end)

test("r30 b window place: dragged one pane wide (Always narrow), Wuber opens where it was left, and again once wide pages are back on", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	r.W.db.pos = { "CENTER", "CENTER", 0, 0 }
	r.W.UI.WindowWide(false)
	open(w, r)
	ok(not r.W.UI.Fold.IsUnfolded(), "control: one pane wide")
	r:drag(ui(r).top, -140, 70)
	w:advance(0.5)
	local left = spot(r)
	shut(w, r)
	open(w, r)
	local back = spot(r)
	ok(same(back, left), "one pane: dragged to " .. say(left) .. ", opened at " .. say(back))
	-- wide pages on again: it unfolds to the right from the same left edge
	r.W.UI.WindowWide(true)
	shut(w, r)
	open(w, r)
	local wide = spot(r)
	ok(r.W.UI.Fold.IsUnfolded(), "control: two panes wide again")
	ok(same(wide, left), "unfolded: the left edge stays where it was left: " .. say(left) .. ", opened at " .. say(wide))
	T.clean(w)
end)

test("r30 b window place: a place saved before the fix (by the centre) still opens where it did", function()
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	r.W.db.pos = { "CENTER", "CENTER", 40, 70 }
	r.W.UI.WindowWide(false)
	open(w, r)
	local win = ui(r).win
	local P = r.env.UIParent
	local k = win:GetEffectiveScale() / P:GetEffectiveScale()
	local cx = (win:GetLeft() + win:GetRight()) / 2
	ok(math.abs(cx - (P:GetWidth() / k / 2 + 40)) <= 1, "the old centre place is kept: centre x " .. cx)
	ok(win:GetLeft() >= 0 and win:GetRight() * k <= P:GetWidth(), "and it is on the screen")
	T.clean(w)
end)
