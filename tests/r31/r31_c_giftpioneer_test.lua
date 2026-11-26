local T = ...
-- Round 31 group C (HUNT-04): on a queue row for a Pioneer rider you have gifted, the gold gift
-- mark and the Pioneer badge sat on top of each other at the ring's top-left. They are apart now,
-- and neither covers the initial or the name.
local test, eq, ok = T.test, T.eq, T.ok

local function box(f)
	local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
	return { l = l, r = r, t = t, b = b }
end
local function overlap(a, b)
	return a.l < b.r - 0.5 and b.l < a.r - 0.5 and a.b < b.t - 0.5 and b.b < a.t - 0.5
end

test("r31 C HUNT-04: a gifted Pioneer rider's row: gift mark and Pioneer badge do not overlap, nor cover the initial or name", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	local D, DR = W.Driver, W.Drive
	local DAN = "Dan Miller"
	W.Ruleset = function() return "EU-PvE" end
	W.PIONEERS.riders["EU-PvE"] = { DAN }
	ok(W.IsPioneer(DAN, "rider"), "Dan is on the shipped Pioneer list")
	ok(DR.SetGifted(DAN), "gifted")
	local parent = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	parent:SetSize(400, 200)
	parent:SetPoint("CENTER")
	parent:Show()
	local r = D.Row(parent, 340)
	r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	D.PaintRow(r, { name = DAN, state = "queued", at = 1000 }, 1000)
	ok(r.giftMark and r.giftMark:IsShown(), "the gift mark shows")
	ok(r.pioneer and r.pioneer:IsShown(), "the Pioneer badge shows")
	local g, p = box(r.giftMark), box(r.pioneer)
	ok(g.l and p.l, "the marks have a place")
	ok(not overlap(g, p), "gift mark and Pioneer badge overlap")
	local ini, nm = box(r.initial), box(r.name)
	ok(not overlap(g, ini), "gift mark covers the initial")
	ok(not overlap(p, ini), "Pioneer badge covers the initial")
	ok(not overlap(g, nm), "gift mark covers the name")
	ok(not overlap(p, nm), "Pioneer badge covers the name")
	T.clean(w)
end)
