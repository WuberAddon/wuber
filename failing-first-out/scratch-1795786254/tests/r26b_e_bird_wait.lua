-- Round 26b, E: the Skip the bird card takes off the shared summon time (W.SUMMON_SECS), the same number the Fly or summon card uses.
local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function setup()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Thunder Bluff", screenW = 1365, screenH = 768 })
	w:advance(15)
	local W = r.W
	W.drivers = W.drivers or {}
	W.drivers["anita lift"] = { name = "Anita Lift", key = "anita lift", dest = "Orgrimmar", price = 5000, state = "open", team = 3, service = "Wuber", heard = r.env.GetTime() }
	W.ride = { id = "gJBrSi", state = "done", driver = "anita lift", driverKey = "anita lift", dest = "Orgrimmar", price = 5000 }
	return w, r, W
end

local function open(w, r)
	w:openTaxiMap(r, { { name = "Thunder Bluff, Mulgore", type = "CURRENT" }, { name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50 } })
	w:advance(0.5)
end

test("r26b E bird: real 210 s flight (the estimate at 30 yards a second), back is 210 minus the summon seconds, card says it", function()
	local w, r, W = setup()
	local Mod = W.Mod("UI.Bird")
	open(w, r)
	local d, info = Mod.Pick()
	eq(info.secs, 210, "the real estimate (197 at 32 yards a second)")
	eq(info.back, 210 - W.SUMMON_SECS, "back")
	local c = Mod.Card()
	ok(c and H.visible(c), "card visible")
	eq(c.text.wuberText, "Summon " .. W.SUMMON_SECS .. " sec. Fly about 4 min.", "the card's short line")
	eq(c.sub.wuberText, d.short .. " · " .. d.dest .. " · " .. W.Money(d.price), "the card's second line")
	ok(c.tipBody:find(Mod.Message(d, info), 1, true), "the old sentence is the tooltip's second paragraph")
	T.clean(w)
end)

test("r26b E bird: the card needs a minute back: SUMMON_SECS + 60 shows it, SUMMON_SECS + 59 does not", function()
	local w, r, W = setup()
	local Mod = W.Mod("UI.Bird")
	local real = W.FlightTime
	W.FlightTime = function() return W.SUMMON_SECS + 60, "est" end
	local d, info = Mod.Pick()
	ok(d, "SUMMON_SECS + 60 qualifies")
	eq(info.back, 60, "back 60 s")
	ok(not Mod.Message(d, info):find("under a minute", 1, true), "the sentence never says under a minute: " .. Mod.Message(d, info))
	W.FlightTime = function() return W.SUMMON_SECS + 59, "est" end
	eq(Mod.Pick(), nil, "SUMMON_SECS + 59 does not (under a minute back)")
	W.FlightTime = function() return W.SUMMON_SECS - 5, "est" end
	eq(Mod.Pick(), nil, "a flight shorter than the summon does not")
	W.FlightTime = real
	T.clean(w)
end)

test("r26b E bird: the bird's number equals the Fly or summon card's default wait", function()
	local w, r, W = setup()
	local Mod = W.Mod("UI.Bird")
	local info = W.Mod("UI.Rider.Booking").DialInfo({ dest = "Orgrimmar", price = 5000, queue = 0 }, 5000)
	ok(info and info.wait, "booking gives a wait")
	local real = W.FlightTime
	eq(info.wait, W.SUMMON_SECS, "the booking card's default wait is the shared number")
	W.FlightTime = function() return info.wait + 60, "est" end
	local _, pk = Mod.Pick()
	ok(pk, "a minute over the booking wait qualifies")
	eq(pk.back, 60, "back is the flight minus the booking wait")
	W.FlightTime = function() return info.wait + 59, "est" end
	eq(Mod.Pick(), nil, "59 s over the booking wait does not")
	W.FlightTime = real
	T.clean(w)
end)
