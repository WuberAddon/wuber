local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- Follow-up to HUNT-101: the pin of the place in focus (a booking there) does not move; the other pin of
-- the close pair moves the whole overlap. So the ring, the gold route's end and the booked pin agree.
local function setup()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.WorldMap")
	Mod.Reset()
	for k in pairs(Mod.cache.maps) do Mod.cache.maps[k] = nil end
	Mod.cache.last = nil
	W.UI.Fold.IsUnfolded = function() return true end
	local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	holder:SetSize(360, 544)
	holder:SetPoint("TOPLEFT", r.env.UIParent, "TOPLEFT", 400, -100)
	local t0 = r.env.GetTime()
	local function drv(key, name, dest, price)
		W.drivers[key] = { name = name, key = key, dest = dest, price = price, state = "open", team = 3,
			service = "Rides", heard = t0 }
	end
	drv("bob stone", T.BOB, "Ratchet", 5000)
	drv("cal cole", "Cal Cole", "The Crossroads", 6000)
	W.Bounty.Demand = function() return {} end
	Mod.Build(holder)
	Mod.Show("world")
	return w, r, W, Mod, Mod.cache.maps[holder]
end

local function pinsOf(wm)
	local by = {}
	for i = 1, wm.pinCount do by[wm.pins[i].key] = wm.pins[i] end
	return by
end

local function overlap(a, b)
	return a.l < b.l + b.w and b.l < a.l + a.w and a.b < b.b + b.h and b.b < a.b + a.h
end

local function check(place, key, other)
	local w, r, W, Mod, wm = setup()
	wm.focus = place
	Mod.Refresh()
	w:advance(1)
	ok(wm.focusRing:IsShown(), "ring shown")
	local by = pinsOf(wm)
	local pin, away = by[key], by[other]
	ok(pin and away, "a pin for each driver")
	local a, b = H.rect(wm.focusRing), H.rect(pin)
	local dx = (a.l + a.w / 2) - (b.l + b.w / 2)
	local dy = (a.b + a.h / 2) - (b.b + b.h / 2)
	ok(math.abs(dx) <= 1 and math.abs(dy) <= 1, ("ring centre is off the %s pin by %.1f, %.1f"):format(place, dx, dy))
	ok(not overlap(b, H.rect(away)), "the two pins do not overlap")
	local got
	local old = W.UI.Show
	W.UI.Show = function(screen, k) got = { screen, k } end
	for k, p in pairs(by) do
		got = nil
		eq(r:clickOn(p), p, "the click on " .. k .. "'s pin lands on that pin")
		ok(got and got[1] == "confirm" and got[2] == k, "Confirm for " .. k)
	end
	W.UI.Show = old
	T.clean(w)
end

test("r31.o: with Ratchet in focus its pin stays on the place under the ring; the Crossroads pin moves clear", function()
	check("Ratchet", "bob stone", "cal cole")
end)

test("r31.o: with the Crossroads in focus its pin stays on the place under the ring; the Ratchet pin moves clear", function()
	check("The Crossroads", "cal cole", "bob stone")
end)
