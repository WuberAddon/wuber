-- #15: a pin's gold price tag never lies over that same pin's aura frame.
-- Promise: for any pin (world map pin, flight map marker) and any price length (1s .. 999g), net=one or net=many,
-- the shown price tag and the pin's own aura frame do not overlap, and the tag still sits beside its pin and is shown.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function overlaps(a, b)
	return not (a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5)
end

local PRICES = { 100, 5000, 7500, 25000, 120000, 9990000 } -- 1s, 50s, 75s, 2g 50s, 12g, 999g

test("#15 world pin: the price tag is clear of the pin's own aura frame at every price length", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local Mod = r.W.Mod("UI.Map.Pins")
	local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	parent:SetSize(1000, 600)
	parent:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
	parent:Show()
	for _, price in ipairs(PRICES) do
		local pin = Mod.NewPin(parent)
		pin:SetPoint("CENTER", parent, "CENTER", 0, 0)
		pin:Show()
		pin.key, pin.nx, pin.ny = "zed", 0.5, 0.5
		Mod.Paint(pin, { key = "zed", name = "Zed", service = "Z", state = "open", price = price, dest = "Ratchet", team = 1, seats = 4 }, true, 0, false)
		ok(H.visible(pin.auraRing.frame), "control: the aura frame is shown (price " .. price .. ")")
		ok(H.visible(pin.tag), "the tag is shown (price " .. price .. ")")
		local tr, ar, pr = H.rect(pin.tag), H.rect(pin.auraRing.frame), H.rect(pin)
		ok(not overlaps(tr, ar), "price " .. price .. ": the tag is not over the pin's aura frame")
		-- the tag is still beside its pin: its top within 12 px of the aura frame's bottom
		ok(math.abs(tr.b + tr.h - ar.b) <= 12, "price " .. price .. ": the tag stays close to the pin")
	end
	T.clean(w)
end)

-- guard: a pin whose aura ring is hidden (busy driver) keeps its tag under the pin as before
test("#15 world pin guard: a busy chosen pin still shows its tag under the pin", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	local Mod = r.W.Mod("UI.Map.Pins")
	local parent = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	parent:SetSize(1000, 600)
	parent:SetPoint("CENTER", r.env.UIParent, "CENTER", 0, 0)
	parent:Show()
	local pin = Mod.NewPin(parent)
	pin:SetPoint("CENTER", parent, "CENTER", 0, 0)
	pin:Show()
	Mod.Paint(pin, { key = "zed", name = "Zed", service = "Z", state = "busy", price = 5000, dest = "Ratchet", team = 1, seats = 4 }, true, 0, false)
	ok(H.visible(pin.tag), "the tag is shown")
	local tr, pr = H.rect(pin.tag), H.rect(pin)
	ok(tr.b + tr.h <= pr.b + 0.5, "the tag is under the pin")
	ok(pr.b - (tr.b + tr.h) <= 20, "and close to it")
	T.clean(w)
end)

local function flight(n, price)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	local names = { "Orgrimmar", "Crossroads", "Ratchet", "Camp Taurajo", "Gadgetzan", "Everlook" }
	local known = {}
	r.W.drivers = r.W.drivers or {}
	for i = 1, n do
		known[#known + 1] = names[i]
		r.W.drivers["drv" .. i] = { name = "Drv" .. i, key = "drv" .. i, dest = names[i], price = price, state = "open", team = 3, heard = r.env.GetTime() }
	end
	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = known }))
	w:advance(0.5)
	Mod.Refresh()
	return w, r, Mod
end

-- guard: the flight map already keeps its tag clear of its own marker's aura frame (markerHalf = aura frame half); this holds it so
test("#15 flight pin: the price tag is clear of its own marker's aura frame, one driver and many, every price length", function()
	local shown = 0
	for _, n in ipairs({ 1, 3, 6 }) do
		for _, price in ipairs(PRICES) do
			local w, r, Mod = flight(n, price)
			for i, p in ipairs(Mod.Pins()) do
				if p.tag and H.visible(p.tag) and p.marker and p.marker.aura then
					shown = shown + 1
					local tr = H.rect(p.tag)
					if H.visible(p.marker.aura.frame) then
						local ar = H.rect(p.marker.aura.frame)
						ok(not overlaps(tr, ar), "drivers " .. n .. ", price " .. price .. ", pin " .. i .. ": tag not over its aura frame")
						local dx = math.max(ar.l - (tr.l + tr.w), tr.l - (ar.l + ar.w), 0)
						local dy = math.max(ar.b - (tr.b + tr.h), tr.b - (ar.b + ar.h), 0)
						ok(dx + dy <= 40, "drivers " .. n .. ", price " .. price .. ": the tag stays beside its pin")
					end
				end
			end
			T.clean(w)
		end
	end
	ok(shown >= 6, "control: tags showed (" .. shown .. ")")
end)
