-- Proof tests of job 2620 (audit-241), area C: Rides, rainchecks, mail, trade, settings rows.
local T = ...
local test = T.test
-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["AU24-01"] = true, ["AU24-02"] = true, ["AU24-03"] = true, ["AU24-06"] = true, ["AU24-09"] = true, ["AU24-10"] = true, ["AU24-12"] = true, ["AU24-13"] = true, ["AU24-15"] = true, ["AU24-17"] = true, ["AU24-18"] = true, ["AU24-19"] = true, ["AU24-20"] = true, ["AU24-21"] = true, ["AU24-22"] = true, ["AU24-26"] = true, ["AU24-27"] = true, ["AU24-28"] = true, ["AU24-29"] = true, ["AU24-31"] = true, ["AU24-33"] = true, ["AU24-34"] = true, ["AU24-35"] = true }
local function proof(id, name, fn)
	if os.getenv("WUBER_AU24_PROOF") or FIXED[id] then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end

proof("AU24-26", "Settings: the shard warning slider reads '1 shard', never '1 shards'", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("driving")
	w:advance(1)
	local st = d.W.UI.settings
	local sl = st.controls["drive.lowShards"]
	assert(sl, "no lowShards slider")
	d.W.Drive.SetOpt("lowShards", 1)
	d.W.UI.UpdateSettings()
	w:advance(1)
	local text = sl.label:GetText()
	assert(text and not text:find("1 shards", 1, true), "the slider reads: " .. tostring(text))
	T.clean(w)
end)

-- the W copper messages the rider sent over the channel
local function copperOf(w, from)
	local out = {}
	for _, e in ipairs(T.msgs(w, "W", from, "CHANNEL")) do
		if e.target == nil or type(e.target) == "number" then out[#out + 1] = T.fields(e)[4] end
	end
	return out
end

proof("AU24-13", "Bounty: a cancel still waiting for its minute is sent after a /reload (drivers stop showing the demand)", function()
	do -- control: without the reload the cancel does go
		local w0 = T.newWorld()
		local r0 = T.rider(w0)
		T.settle(w0)
		r0.W.Bounty.Pin("Gadgetzan", 6000)
		w0:advance(10)
		r0.W.Bounty.Cancel()
		w0:advance(135)
		local g0 = copperOf(w0, T.TESTCHAR)
		assert(g0[#g0] == "0", "control broken: " .. table.concat(g0, ","))
		T.clean(w0)
	end
	local w = T.newWorld()
	local r = T.rider(w)
	T.settle(w)
	assert(r.W.Bounty.Pin("Gadgetzan", 6000), "pinned")
	w:advance(10)
	assert(#copperOf(w, T.TESTCHAR) == 1, "the first W went")
	assert(r.W.Bounty.Cancel(), "cancelled")
	w:advance(1)
	assert(#copperOf(w, T.TESTCHAR) == 1, "the cancel waits for the minute")
	local r2 = w:reload(r)
	w:advance(5)
	w:advance(130)
	local got = copperOf(w, T.TESTCHAR)
	assert(got[#got] == "0", "drivers never heard the cancel; sent copper: " .. table.concat(got, ","))
	T.clean(w)
end)

-- Anita takes Wuber's ride, Wuber pays the whole fare by a completed trade, then cancels before arriving
local function paidFailedRide()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { netOnly = true })
	local r = T.rider(w, T.TESTCHAR, { money = 100000 })
	r.W.VERSION = "2.3.0"
	T.settle(w)
	T.goOnline(d)
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	assert(d.W.AcceptRequest(ride.id, 5), "accepted")
	w:group({ T.ANITA, T.TESTCHAR })
	w:advance(1)
	w:move(T.ANITA, "Orgrimmar")
	w:advance(1)
	assert(w:openTrade(w:player(T.ANITA), w:player(T.TESTCHAR)), "a trade opens")
	w:tradeMoney(w:player(T.TESTCHAR), ride.price)
	w:tradeAccept(w:player(T.ANITA))
	w:tradeAccept(w:player(T.TESTCHAR))
	w:advance(6)
	assert(r.W.CancelRide(), "the ride ends before arrival")
	w:advance(1)
	return w, d, r, ride
end

test("AU24-07: Raincheck: a driver's give reaches a rider whose paid ride failed, also after the rider left the failed-ride screen", function()
	local w, d, r, ride = paidFailedRide()
	-- control: the offer reaches a rider still on the failed ride
	d.W.Raincheck.Give(ride.id, T.TESTCHAR, "Rc000001", d.env.time() + 7 * 86400, 5000, "Anita Lift")
	w:advance(1)
	assert(#r.W.Raincheck.Mine() == 1, "control broken: the offer did not arrive")
	T.clean(w)
	-- the same, but the rider pressed away (W.ClearRide: 'Try another driver') before the driver gave
	local w2, d2, r2, ride2 = paidFailedRide()
	r2.W.ClearRide()
	d2.W.Raincheck.Give(ride2.id, T.TESTCHAR, "Rc000002", d2.env.time() + 7 * 86400, 5000, "Anita Lift")
	w2:advance(1)
	assert(#r2.W.Raincheck.Mine() == 1, "the offer never reached the rider: " .. #r2.W.Raincheck.Mine() .. " rainchecks held")
	T.clean(w2)
end)

test("AU24-16: Settings: the tooltip of 'Do nothing' (riders who leave without paying) does not say the rider is blocked", function()
	local w = T.newWorld()
	local d = T.driver(w, T.BOB)
	T.settle(w)
	d.W.db.coach = true
	d.W.UI.Toggle(true)
	w:advance(3)
	d.W.UI.OpenSettings("driving")
	w:advance(1)
	local seg = d.W.UI.settings.controls["drive.leavers"]
	assert(seg and seg.buttons and seg.buttons[3], "no 'Do nothing' button")
	local b = seg.buttons[3]
	local tip = b.wuberTip
	assert(tip, "the button has no tooltip")
	local text = tip.text
	if type(text) == "function" then text = text(b) end
	if type(text) == "table" then text = table.concat(text, " ") end
	assert(type(text) == "string" and text ~= "", "empty tooltip")
	assert(not text:find("is blocked", 1, true) and not text:find("gets one whisper", 1, true),
		"'Do nothing' says: " .. text)
	T.clean(w)
end)
