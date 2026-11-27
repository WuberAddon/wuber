-- Wuber 2.4 fix round 3, group L (stage B, surface 5): a settings row takes its height from its small text
-- and pushes the rows below it down.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local TWO = "Wuber keeps the window where you put it, even after a relog." -- a real-sized two line text
-- about twice the longest real line
local LONG = "Wuber keeps the window where you put it, even after you log out and in again, and when the game window changes size. "
	.. "It also remembers which side of the screen it was on, and it never moves while you are in a fight or on a ride."

local function rectOf(f) return { l = f:GetLeft(), r = f:GetRight(), t = f:GetTop(), b = f:GetBottom() } end

local function build(desc, label)
	local w = T.newWorld()
	local c = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local Rows = c.W.Mod("UI.Settings.Rows")
	local host = CreateFrame and nil
	local parent = c.env.CreateFrame("Frame", nil, c.env.UIParent)
	parent:SetSize(400, 800)
	parent:SetPoint("TOPLEFT", c.env.UIParent, "TOPLEFT", 20, -20)
	local y1, b, r1 = Rows.buttonRow(parent, 10, "f3l.one", label or "Window position", desc, "tip", "Reset", function() end)
	local y2, b2, r2 = Rows.buttonRow(parent, y1, "f3l.two", "Next row", "short", "tip", "Go", function() end)
	return w, c, parent, r1, r2, y1, y2
end

test("v24 f3l: a settings row with twice the longest small text shows it whole and pushes the next row down", function()
	local w, c, parent, r1, r2, y1 = build(LONG)
	ok(r1.desc:GetText() == LONG, "the text is whole")
	ok(H.truncation(r1.desc, true) == nil, "the text is not cut")
	local _, size = r1.desc:GetFont()
	ok(size and size >= 10, "no shrunk text: " .. tostring(size))
	local d, a, b = rectOf(r1.desc), rectOf(r1), rectOf(r2)
	ok(d.b >= a.b - 0.5, "the text is inside its row: text bottom " .. d.b .. ", row bottom " .. a.b)
	ok(b.t <= a.b + 0.5, "the next row starts below it: next top " .. b.t .. ", row bottom " .. a.b)
	ok(y1 >= 10 + (a.t - a.b), "the next y is past the grown row")
	T.clean(w)
end)

test("v24 f3l: a real two line settings row keeps its height", function()
	local w, c, parent, r1 = build(TWO)
	local _, _, base = (function() local w2, c2, p, rr = build("short") return w2, c2, rr:GetHeight() end)()
	ok(r1:GetHeight() <= base + 20, "at most one extra line: " .. r1:GetHeight() .. " vs " .. base)
	T.clean(w)
end)
