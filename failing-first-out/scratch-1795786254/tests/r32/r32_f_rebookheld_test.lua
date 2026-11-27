local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- AUD-30 (a reviewer C07b-1): a rider who sends a second R (new ride id) while the driver holds their
-- ride (a raincheck, or a summon under way) is answered N busy; the held ride must stay in the
-- driver's W.incoming so the rider's later cancel, paid/done and rating still count.

local function incomingIds(d)
	local t = {}
	for _, r in ipairs(d.W.incoming) do t[#t + 1] = r.id .. ":" .. tostring(r.state) end
	return table.concat(t, ",")
end

local function setup()
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
	return w, r, d, ride
end

test("r32 f: AUD-30 a second R (new id) declined busy while a summon is under way keeps the first ride in W.incoming", function()
	local w, r, d, ride = setup()
	local oldId = ride.id
	local DR = d.W.Drive
	local key = d.W.Key("Wuber TestCharacter")
	local c = DR.customers[key]
	ok(c, "setup: the driver has Wuber's row")
	DR.SetState(c, "summoning")
	w:advance(1)
	local before = incomingIds(d)
	ok(before:find(oldId, 1, true), "control: before the second request the driver's incoming list holds the live ride " .. before)
	-- the rider's app sends a fresh R with a new ride id (what a rebook while summoning sends)
	local rs = w:messages("R", T.TESTCHAR, "WHISPER")
	ok(#rs >= 1, "setup: have an R to copy")
	local f = T.fields(rs[#rs])
	local newId = "ZZ" .. oldId:sub(3)
	if newId == oldId then newId = "QQ" .. oldId:sub(3) end
	f[3] = newId
	w:inject(T.TESTCHAR, table.concat(f, "~"), "WHISPER", d)
	w:advance(1)
	local ns = w:messages("N", T.ANITA, "WHISPER")
	local busy = false
	for _, e in ipairs(ns) do local g = T.fields(e) if g[3] == newId and g[4] == "busy" then busy = true end end
	ok(busy, "control: the second request is answered N busy (the first ride stays on the driver's board)")
	ok(DR.customers[key] and DR.customers[key].state == "summoning", "control: the driver's row for Wuber is still summoning")
	local after = incomingIds(d)
	ok(after:find(oldId, 1, true), "the live ride " .. oldId .. " is gone from the driver's request list after the declined second request (list now: '" .. after .. "'), so its cancel/paid/rating are ignored")
	T.clean(w)
end)

test("r32 f: AUD-30 a raincheck-covered ride whose rider sends a second R: the rider's later cancel of the first ride still counts", function()
	local function prep()
		local w, r, d, ride = setup()
		local DR = d.W.Drive
		local key = d.W.Key("Wuber TestCharacter")
		DR.customers[key].voucher = "Rc0000C1" -- the raincheck covers this ride (held until arrival)
		return w, r, d, ride, DR, key
	end
	-- control: a plain cancel of the raincheck ride drops the row
	do
		local w2, r2, d2, ride2, DR2, k2 = prep()
		w2:inject(T.TESTCHAR, "C~" .. d2.W.PROTO .. "~" .. ride2.id, "WHISPER", d2)
		w2:advance(2)
		ok(not DR2.customers[k2], "control: a plain cancel of the live ride removes Wuber from the board")
	end
	local w, r, d, ride, DR, key = prep()
	local oldId = ride.id
	local f = T.fields(w:messages("R", T.TESTCHAR, "WHISPER")[1])
	f[3] = "ZZ" .. oldId:sub(3)
	w:inject(T.TESTCHAR, table.concat(f, "~"), "WHISPER", d)
	w:advance(1)
	local busy = false
	for _, e in ipairs(w:messages("N", T.ANITA, "WHISPER")) do local g = T.fields(e) if g[3] == f[3] and g[4] == "busy" then busy = true end end
	ok(busy, "control: the second request is answered N busy")
	ok(DR.customers[key], "control: Wuber's row is still on the board")
	w:inject(T.TESTCHAR, "C~" .. d.W.PROTO .. "~" .. oldId, "WHISPER", d)
	w:advance(2)
	ok(not DR.customers[key], "Wuber cancelled his live ride " .. oldId .. " but Anita's board still lists him (state " .. tostring(DR.customers[key] and DR.customers[key].state) .. "): the cancel was ignored after the declined second request")
	T.clean(w)
end)