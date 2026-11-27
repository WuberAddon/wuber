local T = ...
local test, eq, ok, settle = T.test, T.eq, T.ok, T.settle
local ANA, BEA, PIA, CAL = "Ana Smith", "Bea Jones", "Pia Rose", "Cal Brown"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- Promise (r52 #7): an open driver always has some window that sends the beacon; a crew
-- leader without Wuber never silences it.
test("r52 e7: a Warlock crew leader without Wuber leaves the captain's window on the network", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = { chars = { [key(ANA)] = {
		crew = { { name = BEA, role = "lock", app = false }, { name = PIA, role = "helper", app = true } },
		captain = "", wizard = true } } } } })
	local bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK" })
	local pia = w:addClient(PIA, { spot = "Orgrimmar", class = "PRIEST" })
	w:group({ BEA, ANA, PIA }) -- Bea (no Wuber) leads
	settle(w)
	local DM = ana.W.Drive
	ok(DM.SetOpen(true), "the captain opens")
	w:advance(3)
	ok(DM.IsCrewKey(key(BEA)), "control: Bea is crew")
	eq(DM.NetDriver(), true, "the leader runs no Wuber: the captain's window is the one on the network")
	T.clean(w)
end)

-- guard: the same crew with Bea running Wuber keeps the leader's window the one on the network
test("r52 e7 guard: a Warlock crew leader with Wuber still gets the network window", function()
	local w = T.newWorld()
	local ana = w:addClient(ANA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = { chars = { [key(ANA)] = {
		crew = { { name = BEA, role = "lock", app = true }, { name = PIA, role = "helper", app = true } },
		captain = "", wizard = true } } } } })
	local bea = w:addClient(BEA, { spot = "Orgrimmar", class = "WARLOCK", saved = { Wuber = { chars = { [key(BEA)] = {
		crew = { { name = ANA, role = "lock", app = true }, { name = PIA, role = "helper", app = true } },
		captain = ANA, wizard = true } } } } })
	local pia = w:addClient(PIA, { spot = "Orgrimmar", class = "PRIEST" })
	w:group({ BEA, ANA, PIA })
	settle(w)
	ana.W.Drive.SetOpen(true)
	bea.W.Drive.SetOpen(true)
	w:advance(3)
	eq(ana.W.Drive.NetDriver(), false, "Bea (Wuber) leads: her window drives")
	eq(bea.W.Drive.NetDriver(), true)
	T.clean(w)
end)

-- Promise (r52 #8): a rebook with a new ride id never inherits "paid" from the old ride.
local function rebookWith(ver)
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Ratchet" })
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	r.W.db.autoAccept = true
	T.goOnline(d)
	w:advance(5)
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(6)
	local DR = d.W.Drive
	local key = d.W.Key("Wuber TestCharacter")
	local c = DR.customers[key]
	ok(c, "setup: the driver has Wuber's row")
	DR.SetState(c, "paid")
	local rs = w:messages("R", T.TESTCHAR, "WHISPER")
	local f = T.fields(rs[#rs])
	local newId = "ZZ" .. ride.id:sub(3)
	if newId == ride.id then newId = "QQ" .. ride.id:sub(3) end
	f[3] = newId
	f[8] = ver
	w:inject(T.TESTCHAR, table.concat(f, "~"), "WHISPER", d)
	return w, d, DR, key, newId
end

test("r52 e8: a pre-2.3.0 rider's rebook (new ride id) over a paid row does not start paid", function()
	local w, d, DR, key, newId = rebookWith("2.2.9")
	local c = DR.customers[key]
	ok(c and c.wuberRide == newId, "the row follows the new ride")
	ok(c and c.state ~= "paid", "the new ride is not paid at once (state " .. tostring(c and c.state) .. ")")
	for _, e in ipairs(w:messages("S", T.ANITA, "WHISPER")) do
		local g = T.fields(e)
		ok(not (g[3] == newId and g[4] == "paid"), "no 'paid' stage is sent for the new ride")
	end
	T.clean(w)
end)

-- guard: a 2.3.0 rider's rebook over a paid row starts fresh the same way
test("r52 e8 guard: a 2.3.0 rider's rebook over a paid row does not start paid", function()
	local w, d, DR, key, newId = rebookWith("2.4.2")
	local c = DR.customers[key]
	ok(c and c.wuberRide == newId, "the row follows the new ride")
	ok(c and c.state ~= "paid", "the new ride is not paid at once (state " .. tostring(c and c.state) .. ")")
	for _, e in ipairs(w:messages("S", T.ANITA, "WHISPER")) do
		local g = T.fields(e)
		ok(not (g[3] == newId and g[4] == "paid"), "no 'paid' stage is sent for the new ride")
	end
	T.clean(w)
end)
