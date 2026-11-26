-- Round 25 M2: routes across the sea. The legs split into your side, the crossing and the other side; the arrow
-- "continues by zeppelin/boat" runs from your last leg to the cut edge; it draws without Scale animation.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function mod()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, {})
	return r.W.Mod("UI.Rider.SeaRoute"), r
end

local legs = {
	{ cont = 1, to = 1, kind = "flight", pts = { 10, 10, 40, 30 } },
	{ cont = 1, to = 1, kind = "flight", pts = { 40, 30, 80, 60 } },
	{ cont = 1, to = 0, kind = "zeppelin", pts = { 80, 60, 300, 70 } },
	{ cont = 0, to = 0, kind = "flight", pts = { 300, 70, 330, 90 } },
}

test("r25 M2: Split puts legs on your side, the crossing and the other side", function()
	local M = mod()
	local s = M.Split(legs, 1)
	eq(#s.mine, 2, "two legs on your side")
	eq(s.cross.kind, "zeppelin", "the crossing")
	eq(#s.other, 1, "one leg on the other side")
	eq(s.word, "zeppelin", "word")
	local b = M.Split({ { cont = 0, to = 1, kind = "boat", pts = { 1, 1, 2, 2 } } }, 0)
	eq(b.word, "boat", "boat word")
	eq(#b.mine, 0, "nothing on your side")
	local none = M.Split({ legs[1], legs[2] }, 1)
	eq(none.cross, nil, "no crossing")
	eq(M.Arrow(none, 100), nil, "no arrow without a crossing")
	eq(#M.Split(nil, 1).mine, 0, "bad input")
end)

test("r25 M2: the arrow runs from your last leg to the cut edge, pointing at the other continent", function()
	local M = mod()
	local s = M.Split(legs, 1)
	local a = M.Arrow(s, { x = 200 })
	eq(a.label, "continues by zeppelin", "label")
	eq(a.x1, 80, "from the last leg") eq(a.y1, 60, "y")
	eq(a.x2, 200, "to the edge") eq(a.dir, 1, "pointing right")
	local l = M.Arrow(M.Split(legs, 1), 20)
	eq(l.dir, -1, "pointing left when the edge is left")
	ok(math.abs(l.x2 - l.x1) >= M.GAP, "never shorter than the least length")
	eq(M.Arrow(s, "x"), nil, "no edge, no arrow")
	eq(M.Arrow(M.Split({ { cont = 1, to = 0, kind = "boat", pts = { 5, 5, 9, 9 } } }, 1), 50).label, "continues by boat", "boat label")
end)

test("r25 M2: Draw makes the lines and the label on a frame", function()
	local M, r = mod()
	local env = r.env
	local f = env.CreateFrame("Frame", "WuberSeaTest", env.UIParent)
	f:SetSize(300, 200)
	local a = M.Arrow(M.Split(legs, 1), { x = 200 })
	local o = M.Draw(f, a)
	ok(o and o.label, "label made")
	eq(o.label:GetText(), "continues by zeppelin", "label text")
	ok(o.line and o.head1 and o.head2, "line and head made")
	eq(M.Draw(nil, a), nil, "no parent")
end)

test("r25 M2: the gold route across the sea ends your side with the arrow at the cut edge", function()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Orgrimmar", faction = "Horde" })
	T.settle(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.WorldMap")
	Mod.Reset()
	for k in pairs(Mod.cache.maps) do Mod.cache.maps[k] = nil end
	Mod.cache.last = nil
	W.UI.Fold.IsUnfolded = function() return true end
	local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	holder:SetSize(360, 544)
	holder:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 400, -100)
	Mod.Build(holder)
	Mod.Show("world", { route = { from = "Orgrimmar", to = "Tarren Mill" } })
	local wm
	for _, m in pairs(Mod.cache.maps) do wm = m end
	ok(wm and wm.seaArrow and wm.seaArrow.label, "the arrow was drawn")
	local txt = wm.seaArrow.label:GetText()
	ok(txt == "continues by zeppelin" or txt == "continues by boat", "label: " .. tostring(txt))
	ok(wm.seaArrow.label:IsShown(), "shown")
	-- a route that stays on one continent has no arrow
	Mod.Show("world", { route = { from = "Orgrimmar", to = "Thunder Bluff" } })
	ok(not wm.seaArrow or not wm.seaArrow.label:IsShown(), "no arrow on one continent")
end)
