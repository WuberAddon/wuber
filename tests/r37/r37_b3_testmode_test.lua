-- Round 37 b3: the test addon's test mode (DR.SimHooks set) gives no summon sample: the cast and the
-- arrival are stood in for, so a pretend ride must not reach the average riders see.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok
local ANITA, TESTCHAR, BOB = T.ANITA, T.TESTCHAR, T.BOB

local function samples(d)
	local db = d.W.db and d.W.db.drive
	return (type(db) == "table" and type(db.summons) == "table") and db.summons or {}
end

-- put n saved samples of { total, cast } in the driver's data
local function seed(d, list)
	d.W.db.drive = d.W.db.drive or {}
	local s = {}
	for i, v in ipairs(list) do s[i] = { total = v[1], cast = v[2] } end
	d.W.db.drive.summons = s
end

local function online(opts)
	local w = T.newWorld()
	local d = T.driver(w, ANITA, opts)
	for _, n in ipairs({ "Dan Miller", "Eve Stone", "Fay Bell" }) do w:addBot(n, { spot = "Orgrimmar", class = "MAGE" }) end
	T.settle(w) T.goOnline(d) w:advance(5)
	return w, d
end

local function clock(d) return d.env.GetTime() end

-- A ride the engine's own way, with the markers it sets (DR.Create / DR.SetState, c.castAt, c.arrivedAt):
-- asked, wait a, cast, b to the summon, c more to arrival; paid by trade unless o.byHand.
local function fakeRide(w, d, name, a, b, c, o)
	o = o or {}
	local W, DR = d.W, d.W.Drive
	local r
	if o.leadFor then
		r = DR.Create(name, "lead", "whisper")
		w:advance(o.leadFor)
		DR.ResetRide(r)
		DR.SetState(r, "queued")
	else
		r = DR.Create(name, "queued", "whisper")
	end
	w:advance(a)
	DR.SetState(r, "invited")
	DR.SetState(r, "joined")
	r.castAt, r.tries = clock(d), 1
	DR.SetState(r, "summoning")
	w:advance(b)
	r.endAt = clock(d)
	DR.SetState(r, "waiting")
	w:advance(c)
	if o.walked then r.walked, r.tries = true, 0 end
	if o.crewArrival then
		DR.SetState(r, "arrived") -- a crew window's ST: arrived, no arrival this window saw
		r.arrivedAt = r.arrivedAt or clock(d)
	else
		r.arrivedAt = clock(d)
		DR.SetState(r, "arrived")
	end
	w:advance(1)
	if o.before then o.before(r) end
	W.Fire("DRIVE_PAID", r.name, r.price or 5000, 0, W.myKey, true, o.byHand and "m" or "t", r.price or 5000)
	DR.SetState(r, "paid")
	w:advance(1)
	return r
end


-- run f with DR.SimHooks set to v, and put the old value back even when f fails
local function withHooks(DR, v, f)
	local old = DR.SimHooks
	DR.SimHooks = v
	local okk, err = pcall(f)
	DR.SimHooks = old
	if not okk then error(err, 0) end
end

test("r37 b3: a whole ride in the test mode gives no sample; control: the same ride in normal play gives one", function()
	local w, d = online()
	local DR = d.W.Drive
	seed(d, {})
	fakeRide(w, d, "Dan Miller", 4, 20, 6)
	eq(#samples(d), 1, "control: normal play, one sample")
	seed(d, {})
	DR.Remove(DR.customers["dan miller"], "done")
	withHooks(DR, {}, function()
		fakeRide(w, d, "Dan Miller", 4, 20, 6)
	end)
	eq(#samples(d), 0, "test mode: no sample")
	T.clean(w)
end)

test("r37 b3: asked in normal play, paid in the test mode: no sample", function()
	local w, d = online()
	local DR = d.W.Drive
	seed(d, {})
	withHooks(DR, nil, function()
		fakeRide(w, d, "Dan Miller", 4, 20, 6, { before = function() DR.SimHooks = {} end })
	end)
	eq(#samples(d), 0, "mode switched on during the ride: no sample")
	T.clean(w)
end)

test("r37 b3: asked in the test mode, paid after it is off: no sample", function()
	local w, d = online()
	local DR = d.W.Drive
	seed(d, {})
	withHooks(DR, {}, function()
		fakeRide(w, d, "Dan Miller", 4, 20, 6, { before = function() DR.SimHooks = nil end })
	end)
	eq(#samples(d), 0, "mode switched off during the ride: no sample")
	T.clean(w)
end)

test("r37 b3: control: after the test mode is off, the next whole ride gives one sample", function()
	local w, d = online()
	local DR = d.W.Drive
	seed(d, {})
	withHooks(DR, {}, function()
		fakeRide(w, d, "Dan Miller", 4, 20, 6)
	end)
	eq(#samples(d), 0, "test mode: none")
	DR.Remove(DR.customers["dan miller"], "done")
	fakeRide(w, d, "Eve Stone", 4, 20, 6)
	eq(#samples(d), 1, "normal play again: one sample")
	T.clean(w)
end)
