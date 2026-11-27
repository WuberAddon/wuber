-- Conformance (the flight recorder, lane B2): the fake game's API against what the real client has.
-- Facts from tests/fixtures/rec/lab-real-facts.lua (mined from the test addon's logs, 17-21 Nov 2026).
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local FACTS = dofile(T.dir .. "/fixtures/rec/lab-real-facts.lua")
local function fact(id)
	for _, f in ipairs(FACTS) do if f.id == id then return f end end
end

-- api.getzonepvpinfo: the test addon's PvP check on the real client failed with
-- "GetZonePVPInfo is missing" (one recorded run, 19 Nov 21:40; Drive/Danger.lua's header says the same).
test("rec: real: GetZonePVPInfo does not exist (api.getzonepvpinfo)", function()
	ok(fact("api.getzonepvpinfo"), "the fact is in the fixture")
	local w = T.newWorld()
	local r = T.rider(w)
	eq(r.env.GetZonePVPInfo, nil, "no GetZonePVPInfo in a default world")
	w:setZonePvp("Orgrimmar", "hostile", "Alliance")
	eq(r.env.GetZonePVPInfo, nil, "setZonePvp does not bring it back")
	T.clean(w)
	local w2 = T.newWorld({ zonePvpInfo = true })
	local r2 = T.rider(w2)
	eq(type(r2.env.GetZonePVPInfo), "function", "the old fake one on request")
	T.clean(w2)
end)

test("rec: real: the driver's danger level works without GetZonePVPInfo (api.getzonepvpinfo)", function()
	local w = T.newWorld()
	local ana = T.driver(w, T.ANITA)
	local DR = ana.W.Drive
	w:advance(1)
	DR.SetOpen(true)
	w:advance(2)
	w:addBot("Ally Foe", { faction = "Alliance", spot = "Orgrimmar" })
	w:advance(1)
	ana:showPlate("Ally Foe")
	eq((DR.DangerLevel()), 1, "an enemy player's plate still counts")
	eq(#w.errors, 0, "no Lua error: " .. tostring(w.errors[1]))
	T.clean(w)
end)
