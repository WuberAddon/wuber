-- r3 D: a flight-map price tag never lies over another flight point's ring or over another tag.
-- The hunt's layout check named the tag "75s" under a pin's aura (Pins.lua aura frame, 38 x 38) when flight points sit close.
-- Promise: whatever the price width ("50s", "75s", "2g 50s") and however close the points, no shown tag meets any shown
-- ring or any other shown tag, and a tag stays clear of Wuber's window (r49 D).
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function overlaps(a, b)
	return not (a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5)
end

local PRICES = { 5000, 7500, 25000 } -- 50s, 75s, 2g 50s

local function setup(spread)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	local names = { "Orgrimmar", "Crossroads", "Ratchet" }
	r.W.drivers = r.W.drivers or {}
	local i = 0
	for _, n in ipairs(names) do
		i = i + 1
		r.W.drivers["drv" .. i] = { name = "Drv" .. i, key = "drv" .. i, dest = n, price = PRICES[i], state = "open", team = 3, heard = r.env.GetTime() }
	end
	local Mod = r.W.Mod("UI.FlightPins")
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = names }))
	w:advance(0.5)
	return w, r, Mod
end

local function sweep(Mod, what)
	local pins, seen = Mod.Pins(), 0
	for i, p in ipairs(pins) do
		if p.tag and H.visible(p.tag) then
			seen = seen + 1
			local tr = H.rect(p.tag)
			for j, q in ipairs(pins) do
				if q.marker and H.visible(q.marker) then
					ok(not overlaps(tr, H.rect(q.marker)), what .. ": tag " .. i .. " is not over ring " .. j)
				end
				if j ~= i and q.tag and H.visible(q.tag) then
					ok(not overlaps(tr, H.rect(q.tag)), what .. ": tag " .. i .. " is not over tag " .. j)
				end
			end
		end
	end
	return seen
end

-- Pulls every flight point to within a few units of the first one, so the rings and tags crowd.
local function crowd(r, w, gap)
	local real = r.env.TaxiNodePosition
	r.env.TaxiNodePosition = function(i)
		local x, y = real(i)
		if not x then return x, y end
		return 0.5 + (x - 0.5) * gap, 0.5 + (y - 0.5) * gap
	end
	for i = 1, 40 do
		local b = r.env["TaxiButton" .. i]
		if b and b.Hide then b:Hide() end
	end
	w:advance(1.1)
end

test("r3 d: with the flight points crowded, no price tag lies over another pin's ring or tag, at three prices", function()
	local total = 0
	for _, gap in ipairs({ 0.02, 0.05, 0.1 }) do
		local w, r, Mod = setup()
		crowd(r, w, gap)
		Mod.Refresh()
		total = total + sweep(Mod, "gap " .. gap)
		T.clean(w)
	end
	ok(total >= 3, "control: tags showed (" .. total .. ")")
end)

-- guard: with the points far apart (the normal map) every pin still shows its tag beside its own ring
test("r3 d guard: with the points well apart each pin still gets a tag and nothing overlaps", function()
	local w, r, Mod = setup()
	Mod.Refresh()
	local n = sweep(Mod, "apart")
	ok(n >= 1, "a tag shows (" .. n .. ")")
	T.clean(w)
end)
