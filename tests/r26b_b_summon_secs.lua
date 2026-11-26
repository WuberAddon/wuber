-- Round 26b, B: the Fly or summon card's default summon time is W.SUMMON_SECS (a ready driver), not 2 minutes.
local c = ...
local H, test, eq, ok, newWorld, rider, clean = c.H, c.test, c.eq, c.ok, c.newWorld, c.rider, c.clean

local SI = "s" -- (design 1 H: money is letters, "23s", no coin icons)
local function G(s) return "|cfff9c53e" .. s .. "|r" end -- (design 1 P) an amount beside a time is gold letters
local function setup()
	local w = newWorld()
	local r = rider(w)
	local W = r.W
	local Mod = W.Mod("UI.Rider.Booking")
	W.FlightCost = function() return nil end
	return w, r, W, Mod
end

test("r26b b: W.SUMMON_SECS is under a minute and is the card's default wait", function()
	local w, r, W, Mod = setup()
	ok(type(W.SUMMON_SECS) == "number" and W.SUMMON_SECS > 0 and W.SUMMON_SECS < 60, "under a minute: " .. tostring(W.SUMMON_SECS))
	W.TravelSaved = function() return 540, "by zeppelin" end
	local info = Mod.DialInfo({ dest = "Undercity", price = 5000, queue = 0 }, 5000)
	eq(info.wait, W.SUMMON_SECS, "an empty queue: the shared number")
	ok(info.waitKnown, "known")
	eq(info.timeSaved, 540 - W.SUMMON_SECS, "timeSaved takes the shared number off the flight")
	clean(w)
end)

test("r26b b: a known opts.wait still wins; a busy queue shows no wait", function()
	local w, r, W, Mod = setup()
	W.TravelSaved = function() return 540, "by zeppelin" end
	local info = Mod.DialInfo({ dest = "Undercity", price = 5000, queue = 0 }, 5000, { wait = 200 })
	eq(info.wait, 200, "the ride's own eta")
	eq(info.timeSaved, 340, "uses it")
	local busy = Mod.DialInfo({ dest = "Undercity", price = 5000, queue = 2 }, 5000)
	ok(not busy.waitKnown and busy.wait == nil, "a queue: no known wait")
	clean(w)
end)

test("r26b b: the author's case (Thunder Bluff to Undercity by zeppelin, about 9 min, 50s): the card's words", function()
	local w, r, W, Mod = setup()
	W.TravelSaved = function() return 540, "by zeppelin" end
	local info = Mod.DialInfo({ dest = "Undercity", price = 5000, queue = 0 }, 5000)
	local dial = Mod.Dial(r.env.UIParent, 324, 88)
	dial:SetPoint("CENTER", r.env.UIParent, "CENTER")
	dial:Set(info)
	eq(dial.summonText.wuberText, "30 sec · costing " .. G("50" .. SI), "summon side (duration() would say \"under a minute\", too wide for a side)")
	ok(dial.flyText.wuberText:find("^about 9 min"), "fly side: " .. tostring(dial.flyText.wuberText))
	eq(dial.verdict.wuberText, "Summon wins by about 9 min", "headline")
	ok(not H.truncation(dial.summonText), "not cut")
	clean(w)
end)
