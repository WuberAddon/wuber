local T = ...
-- r32 c AUD-16: SummonerMapOK looks at summonedBy (who really cast) before summoner, payee, driver.
local test, eq, ok = T.test, T.eq, T.ok
local BOB, BEA = T.BOB, "Bea Cole"

local function world()
	local w = T.newWorld()
	w:addBot(BOB, { spot = "Orgrimmar", class = "WARLOCK" })  -- the beacon's first summoner (chosen[1]), at another station
	w:addBot(BEA, { spot = "Undercity", class = "WARLOCK" })  -- the Warlock who really casts
	local r = T.rider(w, T.TESTCHAR, { spot = "Ratchet" })
	T.settle(w)
	w:group({ T.TESTCHAR, BOB, BEA })
	w:advance(1)
	return w, r
end

test("r32 c: control: the beacon's summoner is the caster and stands at the destination: no warning", function()
	local w, r = world()
	local ride = { id = "abcdef", state = "portal", driverKey = "bob stone", driver = BOB, dest = "Undercity",
		summoner = BEA, payee = BEA, summonedBy = BEA }
	eq(r.W.SummonerMapOK(ride), true, "control")
	T.clean(w)
end)

test("r32 c: another Warlock of the crew casts (summonedBy) from the destination: the rider is still warned 'Summoner is in Orgrimmar'", function()
	local w, r = world()
	-- beacon summoner = Bob (Orgrimmar); the S message made Bea the payee; CONFIRM_SUMMON says Bea cast it; Bea stands in Undercity
	local ride = { id = "abcdef", state = "portal", driverKey = "bob stone", driver = BOB, dest = "Undercity",
		summoner = BOB, payee = BEA, summonedBy = BEA }
	local good, where = r.W.SummonerMapOK(ride)
	ok(good == true, "the game says Bea cast the summon from the booked place: no warning (result " .. tostring(good) .. ")")
	T.clean(w)
end)
test("r32 c: the caster (summonedBy) stands elsewhere: warned even though the beacon's summoner is at the booked place", function()
	local w, r = world()
	local ride = { id = "abcdef", state = "portal", driverKey = "bob stone", driver = BOB, dest = "Undercity",
		summoner = BEA, payee = BEA, summonedBy = BOB }
	local good = r.W.SummonerMapOK(ride)
	eq(good, false, "Bob cast it from Orgrimmar")
	T.clean(w)
end)
