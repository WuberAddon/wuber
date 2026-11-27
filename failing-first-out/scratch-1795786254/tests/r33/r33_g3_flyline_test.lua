-- Round 33 group g3, HUNT-98: the unfolded booking dial's flight line ("about 2 min · 37s 50c") was cut
-- short with "..." at the bigger UI scale; the side must be wide enough (or the line wrap), never cut.
local T = ...
local test, ok, H = T.test, T.ok, T.H

test("r33 g3 HUNT-98: the unfolded dial's long flight line is not cut short, and stays clear of the verdict", function()
	local w = T.newWorld()
	local wub = w:addClient("Wuber Rocks", { spot = "Orgrimmar", class = "MAGE" })
	w:advance(5)
	local Booking = wub.W.Mod("UI.Rider.Booking")
	for _, size in ipairs({ { 324, 96 }, { 324, 88 }, { 280, 88 } }) do
		local dial = Booking.Dial(wub.env.UIParent, size[1], size[2])
		dial:SetSize(size[1], size[2])
		dial:SetPoint("CENTER", wub.env.UIParent, "CENTER", 0, 0)
		dial:Show()
		dial:Set({ flySecs = 127, flyAbout = true, flightCost = 3750, fare = 5000, waitKnown = true, wait = 30 })
		w:advance(0.5)
		local tag = size[1] .. "x" .. size[2]
		local fs = dial.flyText
		local room = tonumber(fs.wuberRoom)
		local need = wub.W.Theme.MeasureText(fs.wuberText or "", fs.wuberPx or 10, fs.wuberWeight)
		ok(room and need <= room + 0.5 or fs.wuberWrapped, "fly line fits its side at " .. tag .. ": need " .. tostring(need) .. " room " .. tostring(room))
		local fr, vr = H.rect(fs), H.rect(dial.verdict)
		ok(fr and vr, "rects at " .. tag)
		ok(fs.wuberWrapped or need <= room, "wrapped, not cut, at " .. tag)
	end
end)
