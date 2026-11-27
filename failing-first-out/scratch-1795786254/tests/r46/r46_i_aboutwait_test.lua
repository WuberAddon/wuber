-- Round 46 i, HUNT-39: the Fly or summon card writes the summon side with "about", never a tilde ("about 30 sec", "about 2 min"),
-- and the longest forms ("about 59 sec", "about 10 min", with or without the "(net ...)" part) are not cut.
local c = ...
local H, test, eq, ok, newWorld, rider, clean = c.H, c.test, c.eq, c.ok, c.newWorld, c.rider, c.clean

local SI = "s" -- (design 1 H: money is letters, "23s", no coin icons)
local function setup()
	local w = newWorld()
	local r = rider(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.Booking")
	return w, r, W, Mod
end

local function show(r, Mod, info, wide)
	local dial = Mod.Dial(r.env.UIParent, 324, wide and 120 or 88)
	dial:SetPoint("CENTER", r.env.UIParent, "CENTER")
	dial:Set(info)
	return dial
end

test("r46 i: the summon side says about, no tilde, for seconds and minutes", function()
	local w, r, W, Mod = setup()
	W.FlightCost = function() return nil end
	W.TravelSaved = function() return 900, "by zeppelin" end
	for _, wide in ipairs({ false, true }) do
		local d = show(r, Mod, Mod.DialInfo({ dest = "Undercity", price = 5000, queue = 0 }, 5000, { wait = 30 }), wide)
		ok(d.summonText.wuberText:find("^30 sec · costing "), "seconds: " .. tostring(d.summonText.wuberText))
		ok(not d.summonText.wuberText:find("~", 1, true), "no tilde")
		ok(not H.truncation(d.summonText), "30 sec not cut")
		d = show(r, Mod, Mod.DialInfo({ dest = "Undercity", price = 5000, queue = 0 }, 5000, { wait = 120 }), wide)
		ok(d.summonText.wuberText:find("^2 min · costing "), "minutes: " .. tostring(d.summonText.wuberText))
		ok(not H.truncation(d.summonText), "2 min not cut")
		d = show(r, Mod, Mod.DialInfo({ dest = "Undercity", price = 5000, queue = 0 }, 5000, { wait = 59 }), wide)
		ok(d.summonText.wuberText:find("^59 sec · costing "), "59: " .. tostring(d.summonText.wuberText))
		ok(not H.truncation(d.summonText), "59 sec not cut")
		d = show(r, Mod, Mod.DialInfo({ dest = "Undercity", price = 5000, queue = 0 }, 5000, { wait = 600 }), wide)
		ok(d.summonText.wuberText:find("^10 min · costing "), "10 min: " .. tostring(d.summonText.wuberText))
		ok(not H.truncation(d.summonText), "10 min not cut")
	end
	clean(w)
end)

test("r46 i: with a flight cost the longest summon side is not cut either", function()
	local w, r, W, Mod = setup()
	W.FlightCost = function() return 2300, 1 end
	W.TravelSaved = function() return 900, "by zeppelin" end
	for _, wide in ipairs({ false, true }) do
		for _, wait in ipairs({ 30, 59, 600 }) do
			local d = show(r, Mod, Mod.DialInfo({ dest = "Undercity", price = 5000, queue = 0 }, 5000, { wait = wait }), wide)
			ok(d.summonText.wuberText:find("^%d+ %a+ · costing "), "the time, then costing (decisions H): " .. tostring(d.summonText.wuberText))
			ok(not H.truncation(d.summonText), "not cut: " .. tostring(d.summonText.wuberText))
		end
	end
	clean(w)
end)
