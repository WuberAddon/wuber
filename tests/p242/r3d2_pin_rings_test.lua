-- r3 D2: on the flight map no driver pin's ring overlaps another pin's ring, whatever the spacing of neighbouring
-- flight points; every pin stays on its flight point. Real = a player sees two rings drawn into each other.
-- Rule: a ring that would meet a neighbour's is drawn smaller to fit, or not drawn when too small; well-spaced pins keep the full ring.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function overlaps(a, b)
	return not (a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5)
end

local function setup(price, count)
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	T.settle(w)
	local names = { "Orgrimmar", "Crossroads", "Ratchet" }
	r.W.drivers = r.W.drivers or {}
	for i, n in ipairs(names) do
		if count and i > count then break end
		r.W.drivers["drv" .. i] = { name = "Drv" .. i, key = "drv" .. i, dest = n, price = price, state = "open", team = 3, heard = r.env.GetTime() }
	end
	w:openTaxiMap(r, H.realTaxi("Kalimdor", "Thunder Bluff", { known = names }))
	w:advance(0.5)
	return w, r, r.W.Mod("UI.FlightPins")
end

local function crowd(r, w, gap)
	local real = r.env.TaxiNodePosition
	r.env.TaxiNodePosition = function(i)
		local x, y = real(i)
		if not x then return x, y end
		return 0.8 + (x - 0.5) * gap, 0.25 + (y - 0.5) * gap
	end
	for i = 1, 40 do
		local b = r.env["TaxiButton" .. i]
		if b and b.Hide then b:Hide() end
	end
	w:advance(1.1)
end

local function rings(Mod)
	local list = {}
	for _, p in ipairs(Mod.Pins()) do
		local a = p.marker and p.marker.aura
		if a and a.frame and H.visible(a.frame) then list[#list + 1] = { box = H.rect(a.frame), marker = p.marker } end
	end
	return list
end

test("r3 d2: with the flight points crowded, no pin's ring overlaps another's, at three spacings and two prices", function()
	local seen = 0
	for _, price in ipairs({ 5000, 25000 }) do
		for _, gap in ipairs({ 1.0, 1.6, 2.4 }) do
			local w, r, Mod = setup(price)
			crowd(r, w, gap)
			Mod.Refresh()
			local list = rings(Mod)
			seen = seen + #list
			for i = 1, #list do
				for j = i + 1, #list do
					ok(not overlaps(list[i].box, list[j].box), "price " .. price .. " gap " .. gap .. ": rings " .. i .. " and " .. j .. " are apart")
				end
			end
			T.clean(w)
		end
	end
	ok(seen >= 1, "control: some ring showed (" .. seen .. ")")
end)

-- guard: well-spaced pins keep the full ring (38 x 38)
test("r3 d2 guard: well-spaced pins keep their full ring", function()
	local w, r, Mod = setup(5000, 1)
	Mod.Refresh()
	local list = rings(Mod)
	ok(#list >= 1, "a ring shows")
	for i, e in ipairs(list) do ok(e.box.w >= 37.5, "ring " .. i .. " is full size (" .. e.box.w .. ")") end
	T.clean(w)
end)
