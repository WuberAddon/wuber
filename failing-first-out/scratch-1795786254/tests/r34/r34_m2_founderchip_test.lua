-- r34 m2: the Founder chip and crown on a founder's driver card take the mouse, so their tooltips show.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
test("r34 m2: the Founder chip and crown on a founder's driver card take the mouse", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	w:advance(15)
	local W = r.W
	local CM = W.Mod("UI.Rider.Cards")
	local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	local c = CM.buildCard(parent)
	local d = { name = "Farra Way", key = "farra way", dest = "Ratchet", price = 5000, state = "open", team = 3,
		service = "Farra's Rides", heard = r.env.GetTime(), summoner = "Farra Way", creator = true }
	CM.fillCard(c, d)
	local chip = c.royal and c.royal.chip
	ok(chip and chip.wuberTip and chip.wuberTip.title == "Wuber founder", "control: the Founder chip carries its tooltip")
	-- (design 2) the crown after the name is gone (its words are in the row's tooltip): the Founder badge is the one mark
	ok(not (c.crown and c.crown:IsShown()), "no crown after the name")
	ok(chip:IsMouseEnabled(), "the Founder chip has a tooltip but takes no mouse, so hovering it shows nothing")
	-- a chip that takes the mouse would swallow the click: it is passed on to the card
	-- (a release counts as a click only while the cursor is still over the card)
	parent:SetSize(324, 64)
	parent:ClearAllPoints()
	parent:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
	r.mouseOver = chip
	local clicks = {}
	c:SetScript("OnClick", function(_, button) clicks[#clicks + 1] = button end)
	chip:GetScript("OnMouseUp")(chip, "LeftButton")
	chip:GetScript("OnMouseUp")(chip, "RightButton")
	eq(#clicks, 2, "a click on the Founder chip is still a click on the card")
	eq(clicks[1], "LeftButton", "the chip passes the left click on")
	eq(clicks[2], "RightButton", "the chip passes the right click on")
	-- no other button is passed on (the card would read a middle click as a booking)
	chip:GetScript("OnMouseUp")(chip, "MiddleButton")
	eq(#clicks, 2, "a middle click on the chip is not a click on the card")
	-- the card keeps its hover and its press while the mouse is on the chip
	local seen = {}
	c:SetScript("OnEnter", function() seen[#seen + 1] = "enter" end)
	c:SetScript("OnLeave", function() seen[#seen + 1] = "leave" end)
	c:SetScript("OnMouseDown", function() seen[#seen + 1] = "down" end)
	chip:GetScript("OnEnter")(chip)
	chip:GetScript("OnMouseDown")(chip, "LeftButton")
	chip:GetScript("OnLeave")(chip)
	eq(table.concat(seen, " "), "enter down leave", "hover and press on the chip reach the card")
	T.clean(w)
end)
