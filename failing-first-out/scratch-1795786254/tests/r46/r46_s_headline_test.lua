-- Round 46 group S: REV-r46-1, the booking card's headline for the longest place is never cut: it shrinks, then wraps
-- to a second line, and what sits under it moves down; a short place keeps one line at the old size and place.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local function find(f, text)
	for _, rg in ipairs({ f:GetRegions() }) do
		if rg.GetText and rg:GetText() == text then return rg end
	end
	for _, ch in ipairs({ f:GetChildren() }) do
		local got = find(ch, text)
		if got then return got end
	end
end

local function card(dest, opts)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { screenW = (opts and opts.screenW) or 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["mia runner"] = { name = "Mia Runner", key = "mia runner", dest = dest, price = 5000, state = "open",
		team = 3, service = "Mia's Rides", heard = r.env.GetTime() }
	W.UI.Show("confirm", "mia runner")
	w:advance(2)
	return w, r, W, W.UI.state.screens.confirm
end

test("r46 s: REV-r46-1: the longest place's headline is whole (two lines), and the driver row is under it", function()
	local w, r, W, s = card("Feathermoon Stronghold")
	local fs = s.card.headline
	eq(fs:GetText(), "Summon to Feathermoon Stronghold", "the words are whole")
	ok(fs.wuberWrapped, "it wraps instead of being cut")
	ok(fs:IsTruncated() ~= true, "not truncated")
	local hb = H.rect(fs)
	local rb = H.rect(s.card.row)
	ok(rb.b + rb.h <= hb.b + 0.5, "the driver row starts under the headline: row top " .. (rb.b + rb.h) .. " headline bottom " .. hb.b)
	T.clean(w)
end)

test("r46 s: REV-r46-1: control, a short place keeps one line at the old size and place", function()
	local w, r, W, s = card("Undercity")
	local fs = s.card.headline
	eq(fs:GetText(), "Summon to Undercity")
	ok(not fs.wuberWrapped, "one line")
	local _, y = (function() local p, _, _, x, y = fs:GetPoint(1) return x, y end)()
	eq(y, -28, "the headline's old place")
	local _, _, _, _, ry = s.card.row:GetPoint(1)
	local w2, r2, W2, s2 = card("Feathermoon Stronghold")
	local _, _, _, _, ry2 = s2.card.row:GetPoint(1)
	ok(ry2 < ry, "the long place's row is lower (" .. tostring(ry2) .. " vs " .. tostring(ry) .. ")")
	T.clean(w); T.clean(w2)
end)
