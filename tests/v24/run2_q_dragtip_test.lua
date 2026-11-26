-- In-game run 1 answers (22 Nov), Q5: the mid-flight card says "Drag to move" on Wuber's own tip card, beside the card
-- (below it by choice), never over the card and never up where Daylight's "Flying to" bar is.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local S = H.state

local UC_TM = {
	{ name = "Undercity, Tirisfal", type = "CURRENT", cost = 0, x = 0.42, y = 0.31 },
	{ name = "Tarren Mill, Hillsbrad", type = "REACHABLE", cost = 330, x = 0.47, y = 0.44 },
}

test("run2 q: the mid-flight card shows the tip 'Drag to move' on the tip card, clear of the card, below it", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Undercity", screenW = 1365, screenH = 768 })
	T.settle(w)
	local W = r.W
	W.db.flights = W.db.flights or {}
	W.db.flights["H|undercity|tarren mill"] = { t = 240, tat = r.env.time(), tsrc = "own" }
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = "Tarren Mill", price = 5000, state = "open",
		team = 3, service = "Mia's Rides", heard = r.env.GetTime() }
	w:openTaxiMap(r, UC_TM)
	w:fly(r, 2, 240, "Tarren Mill")
	w:advance(3)
	local c = r.env.WuberInFlight
	ok(c and H.visible(c), "the card is up")
	ok(c.sheet.wuberTip and c.sheet.wuberTip.title == "Drag to move", "the card's sheet carries the tip 'Drag to move'")
	ok(c.wuberTip and c.wuberTip.title == "Drag to move", "so does the frame that carries the name")
	local f = c.sheet
	local s = S[f]
	ok(s and s.scripts and s.scripts.OnEnter, "the tip is hooked to the mouse")
	s.scripts.OnEnter(f)
	local tip = r.env.WuberTip
	ok(tip and H.visible(tip) and tip.owner == f, "Wuber's own tip card shows")
	eq(tip.title:GetText(), "Drag to move", "the exact words")
	local tr, cr = H.rect(tip), H.rect(c)
	ok(tr.b + tr.h <= cr.b + 0.5 or tr.l >= cr.l + cr.w - 0.5 or tr.l + tr.w <= cr.l + 0.5 or tr.b >= cr.b + cr.h - 0.5,
		"the tip does not cover the card")
	ok(tr.b + tr.h <= cr.b + 0.5, "the tip stands below the card, not up at the top of the screen")
	s.scripts.OnLeave(f)
	ok(not H.visible(tip), "it goes when the mouse leaves")
	eq(#w.errors, 0, "Lua errors (" .. table.concat(w.errors, "; ") .. ")")
	T.clean(w)
end)
