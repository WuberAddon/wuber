-- Round 33 group i: HUNT-119. In a rider row the right-hand text (the amount paid, the price) and the
-- "Next click sends" pill of the same row must not overlap, even in a narrow row (the mini console).
local T = ...
local H, test, ok = T.H, T.test, T.ok

local DAN = "Alder Rider"

local function overlap(a, b)
	return a.l < b.l + b.w and b.l < a.l + a.w and a.b < b.b + b.h and b.b < a.b + a.h
end

test("r33 i: HUNT-119: the right-hand text and the Next click sends pill of a narrow row do not overlap", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W = a.W
	local D = W.Driver
	local dan = { key = DAN:lower(), name = DAN, state = "paid", price = 5000, paid = 5000, getapp = true, source = "chat", t = 0 }
	local parent = a.env.CreateFrame("Frame", nil, a.env.UIParent)
	parent:SetSize(400, 300)
	parent:SetPoint("CENTER")
	parent:Show()
	local row = D.Row(parent, 220)
	row:SetPoint("TOP", parent, "TOP", 0, 0)
	D.PaintRow(row, dan, a.env.time())
	ok(row.getapp and row.getapp:IsShown(), "the pill shows")
	ok(row.right:GetText() ~= "", "the right text shows")
	local rr, pr = H.rect(row.right), H.rect(row.getapp)
	ok(rr and pr, "both have a place")
	ok(not overlap(rr, pr), string.format("right text l=%d b=%d w=%d h=%d overlaps pill l=%d b=%d w=%d h=%d",
		rr.l, rr.b, rr.w, rr.h, pr.l, pr.b, pr.w, pr.h))
	T.clean(w)
end)
