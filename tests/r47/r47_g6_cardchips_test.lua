local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local function mkcard(r, extra)
	local CM = r.W.Mod("UI.Rider.Cards")
	local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	local c = CM.buildCard(parent)
	local d = { name = "Farra Way", key = "farra way", dest = "Ratchet", price = 5000, state = "open", team = 3,
		service = "Farra's Rides", heard = r.env.GetTime() }
	for k, v in pairs(extra or {}) do d[k] = v end
	c.view = d
	CM.fillCard(c, d)
	return c, d, parent
end

test("r47 g6: the PvP shield on a driver card passes hover and clicks to the card", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:advance(15)
	local c = mkcard(r, { danger = 2 })
	local sh = c.shield
	ok(sh and sh:IsShown(), "control: a hot-drop driver card shows the shield")
	ok(sh.wuberTip, "control: the shield carries its tooltip")
	local clicks = {}
	r.mouseOver = sh
	c:ClearAllPoints() c:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0) c:SetSize(324, 64)
	c:SetScript("OnClick", function(_, b) clicks[#clicks + 1] = b end)
	local seen = {}
	c:SetScript("OnEnter", function() seen[#seen + 1] = "enter" end)
	local up = sh:GetScript("OnMouseUp")
	if up then up(sh, "LeftButton") end
	eq(#clicks, 1, "a click on the shield does not book or open the card menu (same as the Founder chip does)")
	local en = sh:GetScript("OnEnter")
	-- the shield's tooltip hook may run; the card must also see the hover
	if en then en(sh) end
	eq(table.concat(seen, ","), "enter", "hovering the shield: the card loses its hover highlight")
	T.clean(w)
end)

test("r47 g6: pressing the Founder chip and releasing off the card is not a click", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:advance(15)
	local c, d, parent = mkcard(r, { creator = true, summoner = "Farra Way" })
	parent:SetSize(324, 64)
	parent:ClearAllPoints()
	parent:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
	c:ClearAllPoints() c:SetAllPoints(parent)
	local chip = c.royal and c.royal.chip
	ok(chip, "control: the founder chip exists")
	local clicks = {}
	c:SetScript("OnClick", function(_, b) clicks[#clicks + 1] = b end)
	-- cursor on the card: a release there is a click (control)
	r.mouseOver = chip
	ok(c:IsMouseOver(), "control: the cursor is over the card")
	chip:GetScript("OnMouseDown")(chip, "LeftButton")
	chip:GetScript("OnMouseUp")(chip, "LeftButton")
	eq(#clicks, 1, "control: press and release on the chip is one click on the card")
	-- the player drags off the card to cancel, then lets go (the game still sends OnMouseUp to the chip)
	r.mouseOver = nil
	ok(not c:IsMouseOver(), "the cursor is now off the card")
	chip:GetScript("OnMouseDown")(chip, "LeftButton")
	chip:GetScript("OnMouseUp")(chip, "LeftButton")
	eq(#clicks, 1, "the player pressed the chip, dragged off the card and let go, and the card still took it as a click (booking)")
	T.clean(w)
end)
