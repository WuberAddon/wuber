local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- r47 H3 (REV-r47-1): the Home search heading "Drivers to <place>" and its count "N open · M online" share one line.
test("r47 h3: the Home heading for the longest place stops short of its count", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d) w:advance(5)
	for _, dv in pairs(r.W.drivers) do dv.dest = "Feathermoon Stronghold" end -- the longest place
	r.W.UI.Toggle(true) w:advance(2.5)
	r.W.UI.Show("home") w:advance(1)
	r.W.UI.SetSearch("Feathermoon Stronghold") w:advance(1)
	r.W.UI.RefreshNow() w:advance(0.3)
	local head = r:findText("^Drivers to ", true)[1]
	local count = r:findText("^%d+ open · %d+ online$", true)[1]
	ok(head and count, "both the heading and the count are drawn")
	local hl, hw = head:GetLeft(), head:GetStringWidth()
	local cl, cw = count:GetLeft(), count:GetStringWidth()
	local cr = count:GetRight()
	ok(head:GetText() == "Drivers to Feathermoon Stronghold", "heading is [" .. tostring(head:GetText()) .. "]")
	local headRight = hl + math.min(hw, head:GetWidth() > 0 and head:GetWidth() or hw)
	local countLeft = cr - cw
	ok(headRight <= countLeft + 0.5, string.format("the heading ends at %.0f but its count starts at %.0f (they overlap by %.0f px; heading width %.0f, text %.0f)",
		headRight, countLeft, headRight - countLeft, head:GetWidth(), hw))
	T.clean(w)
end)
