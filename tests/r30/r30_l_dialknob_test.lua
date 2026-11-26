local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- the gold knob's lowest edge against the verdict's top edge, both in the dial's TOPLEFT space
local function gap(dial)
	local _, _, _, _, ky = dial.knob:GetPoint(1)
	local _, _, _, _, vy = dial.verdict:GetPoint(1)
	return (ky - 9) - vy -- knob bottom (9 = half its 18 size) above the verdict top: >= 0 means clear
end

test("fly or summon dial: the knob never sits on the verdict, at any knob position or dial size", function()
	local w = T.newWorld()
	local wub = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE" })
	w:advance(5)
	local Booking = wub.W.Mod("UI.Rider.Booking")
	for _, size in ipairs({ { 324, 88 }, { 324, 96 }, { 324, 62 }, { 280, 88 } }) do
		local dial = Booking.Dial(wub.env.UIParent, size[1], size[2])
		for _, p in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
			dial.p = p
			dial:SetSize(size[1], size[2])
			ok(gap(dial) >= 0, "knob clear of the verdict, size " .. size[1] .. "x" .. size[2] .. " p=" .. p .. " gap " .. gap(dial))
		end
	end
end)
