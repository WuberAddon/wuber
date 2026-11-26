-- Fix round 2.4, group k2: two layout bugs of the booking widgets (Booking.lua)
local T = ...
local test, ok, eq = T.test, T.ok, T.eq

-- a and b share no height (a above b)
local function above(a, b) return a:GetBottom() + 0.01 >= b:GetTop() end

test("fr.k2: HUNT-132 a narrow route header puts the tag on its own row, nothing cut", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local Mod = r.W.Mod("UI.Rider.Booking")
	local h = Mod.RouteHeader(r.env.UIParent, 204) -- the finding screen's width beside the level chip
	h:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 10, -10)
	h:Set("Undercity", "Ratchet", "zeppelin")
	ok(h.from:IsTruncated() ~= true, "the origin is whole")
	ok(h.to:IsTruncated() ~= true, "the destination is whole")
	eq(h.from.wuberText or h.from:GetText(), "Undercity", "the origin's words")
	ok(h.via:IsShown(), "the tag is shown")
	ok(h.viaBelow, "on a row of its own")
	eq(h:GetHeight(), 56, "the pill grew by the tag's row")
	ok(h:GetWidth() <= 204, "no wider than its room: " .. h:GetWidth())
	-- (the origin's own box is the row's height, its words are in the middle of it)
	local fromInk = (h.from:GetTop() + h.from:GetBottom()) / 2 - 8
	ok(fromInk + 0.01 >= h.via:GetTop() and above(h.to, h.via), "the tag is under the route's words")
	ok(h.via:GetBottom() >= h:GetBottom() and h.via:GetRight() <= h:GetRight() and h.via:GetLeft() >= h:GetLeft(), "the tag is inside the pill")
	ok(h.from:GetRight() <= h.to:GetLeft() and h.to:GetRight() <= h:GetRight(), "origin, then destination, inside the pill")
	-- the same trip in a header with room keeps one row
	h:SetMaxWidth(278)
	h:Set("Undercity", "Ratchet", "zeppelin")
	ok(not h.viaBelow, "278 wide: one row")
	eq(h:GetHeight(), 32, "and the pill is 32 high again")
	ok(h.from:IsTruncated() ~= true and h.to:IsTruncated() ~= true, "nothing cut at 278")
	ok(h.via:GetLeft() >= h.to:GetRight(), "the tag beside the destination")
	-- every header width the screens use (204 finding, 278 unfolded Confirm, 324 folded) and those between: never a
	-- cut word, the tag never on the words; a long two-word trip too
	for _, trip in ipairs({ { "Undercity", "Ratchet", "zeppelin" }, { "Stranglethorn Vale", "Thunder Bluff", "boat" } }) do
		for mw = 204, 324, 2 do
			local at = trip[1] .. " at " .. mw
			h:SetMaxWidth(mw)
			h:Set(trip[1], trip[2], trip[3])
			ok(h.from:IsTruncated() ~= true and h.to:IsTruncated() ~= true, "nothing cut: " .. at)
			ok(h:GetWidth() <= mw, "inside its room: " .. at)
			ok(h.via:GetBottom() >= h:GetBottom() - 0.01 and h.via:GetRight() <= h:GetRight() + 0.01, "the tag inside the pill: " .. at)
			if h.viaBelow then ok(above(h.to, h.via), "tag under the words: " .. at) else ok(h.via:GetLeft() >= h.to:GetRight(), "tag beside: " .. at) end
		end
	end
	-- no tag: one row
	h:SetMaxWidth(204)
	h:Set("Undercity", "Ratchet", nil)
	ok(not h.viaBelow and not h.via:IsShown(), "no tag, no second row")
	eq(h:GetHeight(), 32, "32 high without a tag")
	T.clean(w)
end)

test("fr.k2: HUNT-133 the short dial's small line starts under the verdict, not in it", function()
	local w = T.newWorld()
	local r = T.rider(w)
	local Mod = r.W.Mod("UI.Rider.Booking")
	local info = { timeSaved = 180, fare = 5000, flightCost = 2500, flySecs = 240, wait = 30, waitKnown = true, rate = 1,
		line = "Summon is 3 min faster \194\183 Net 25s vs flying" }
	for _, hh in ipairs({ 62, 88, 96 }) do
		local dial = Mod.Dial(r.env.UIParent, 232, hh)
		dial:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 10, -10)
		dial:SetSize(232, hh)
		dial:Set(info)
		ok(dial.line:IsShown(), "the line is shown at " .. hh)
		ok(above(dial.verdict, dial.line), "at " .. hh .. " the line starts under the verdict: verdict bottom " .. dial.verdict:GetBottom() .. ", line top " .. dial.line:GetTop())
		ok(dial.line:GetBottom() >= dial:GetBottom(), "and ends inside the dial at " .. hh)
		dial:Hide()
	end
	T.clean(w)
end)
