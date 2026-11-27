local T = ...
local test, ok, H = T.test, T.ok, T.H

-- the knob's lowest edge against the verdict's top edge (dial's TOPLEFT space)
local function gap(dial)
	local _, _, _, _, ky = dial.knob:GetPoint(1)
	local _, _, _, _, vy = dial.verdict:GetPoint(1)
	return (ky - 9) - vy
end

test("r30 fc: dial: the knob clears the verdict and the small line ends inside the card, at every size", function()
	local w = T.newWorld()
	local wub = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE" })
	w:advance(5)
	local Booking = wub.W.Mod("UI.Rider.Booking")
	for _, size in ipairs({ { 324, 88 }, { 324, 96 }, { 324, 62 }, { 280, 88 } }) do
		local dial = Booking.Dial(wub.env.UIParent, size[1], size[2])
		dial:SetSize(size[1], size[2])
		dial:SetPoint("CENTER", wub.env.UIParent, "CENTER", 0, 0)
		dial.verdict:SetText("Summon wins by about 4 min")
		dial.line:SetText("about 1 min back")
		dial:Show()
		w:advance(0.5)
		local tag = size[1] .. "x" .. size[2]
		for _, p in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
			dial.p = p
			dial:SetSize(size[1], size[2])
			ok(gap(dial) >= 0, "knob clear of the verdict at " .. tag .. " p=" .. p .. " gap " .. gap(dial))
		end
		local db, lb = H.rect(dial), H.rect(dial.line)
		ok(db and lb, "rects exist at " .. tag)
		ok(lb.b >= db.b - 0.5, "line bottom " .. tostring(lb.b) .. " is below the dial bottom " .. tostring(db.b) .. " at " .. tag)
	end
end)
