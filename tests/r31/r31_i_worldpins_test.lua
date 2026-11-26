local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

-- HUNT-101: in the World view two open drivers at places close together (Ratchet and the Crossroads) each
-- get a pin you can see and click, and a click books the driver whose pin it is.
local function setup()
	local w = T.newWorld()
	local r = T.rider(w, nil, { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	local UI = W.UI
	local Mod = W.Mod("UI.Rider.WorldMap")
	Mod.Reset()
	for k in pairs(Mod.cache.maps) do Mod.cache.maps[k] = nil end
	Mod.cache.last = nil
	UI.Fold.IsUnfolded = function() return true end
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

test("r31.i: World view pins at Ratchet and the Crossroads do not overlap; each click books its own driver", function()
	local w, r, W, Mod, wm = setup()
	eq(wm.pinCount, 2, "two places, two pins")
	local by = pinsOf(wm)
	local bob, cal = by["bob stone"], by["cal cole"]
	ok(bob and cal, "a pin for each driver")
	local rb, rc, v = H.rect(bob), H.rect(cal), H.rect(wm.view)
	ok(not overlap(rb, rc), ("the two pins do not overlap: %.1f,%.1f and %.1f,%.1f"):format(rb.l, rb.b, rc.l, rc.b))
	for _, rr in ipairs({ rb, rc }) do
		ok(rr.l >= v.l - 1 and rr.l + rr.w <= v.l + v.w + 1 and rr.b >= v.b - 1 and rr.b + rr.h <= v.b + v.h + 1, "inside the map")
	end
	local got
	local old = W.UI.Show
	W.UI.Show = function(screen, key) got = { screen, key } end
	for key, p in pairs(by) do
		got = nil
		local hit = r:clickOn(p)
		eq(hit, p, "the click on " .. key .. "'s pin lands on that pin")
		ok(got and got[1] == "confirm" and got[2] == key, "Confirm for " .. key)
	end
	W.UI.Show = old
	T.clean(w)
end)

test("r31.i: the spread pins are stable (the same drivers give the same picture on every redraw)", function()
	local w, r, W, Mod, wm = setup()
	local function spots()
		local out = {}
		for key, p in pairs(pinsOf(wm)) do
			local rr = H.rect(p)
			out[#out + 1] = key .. "@" .. ("%.2f,%.2f"):format(rr.l, rr.b)
		end
		table.sort(out)
		return table.concat(out, " ")
	end
	local first = spots()
	W.Fire("DRIVERS")
	w:advance(1)
	eq(spots(), first, "the same places after a redraw")
	local by = pinsOf(wm)
	ok(not overlap(H.rect(by["bob stone"]), H.rect(by["cal cole"])), "and still apart")
	T.clean(w)
end)
