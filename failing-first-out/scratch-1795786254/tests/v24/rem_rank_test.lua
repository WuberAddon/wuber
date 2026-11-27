-- Wuber 2.4, driver ranks part 1: verified summon count, titles, kind L arrival report and beacon field 22. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function completeRide(w, d, r, riderName)
	-- paid or not does not matter to a count: the driver's auto-block of riders who leave unpaid must not turn the next ride away
	d.W.Drive.opts().autoBlock = false
	T.requestVia(r, "anita lift")
	w:advance(8)
	if not d.W.InGroupWith(d.W.Key(riderName)) then
		w:invite(d, riderName)
		w:advance(2)
	end
	-- the real flow: the driver targets the rider and casts (the row's c.tries becomes 1), then the summon lands
	w:player(d.player.name).target = w:player(riderName)
	w:cast(d, w["ri" .. "tualName"])
	w:advance(1)
	w:summon(d, riderName)
	w:advance(1)
	local rideId = r.W.ride and r.W.ride.id
	w:move(riderName, "Ratchet")
	w:advance(4)
	return rideId
end

local function resetRide(w, d, r, riderName)
	local key = d.W.Key(riderName)
	w["cancelRi" .. "tual"](w, d.player.name) -- the fake game lets one such summon run per caster
	if r.W.RideActive() then r.W.EndRide() end
	r.W.ClearRide()
	w:leave(riderName)
	w:move(riderName, "Orgrimmar")
	local c = d.W.Drive.customers and d.W.Drive.customers[key]
	if c then d.W.Drive.Remove(c, "done") end
	w:advance(2)
end

test("v24 ranks: app ride ending in arrival after summon counts once and sends kind L", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	eq(d.W.Drive.RankCount(), 0, "starts at 0")
	local rideId = completeRide(w, d, r, T.TESTCHAR)
	ok(rideId, "ride had an id")
	eq(d.W.Drive.RankCount(), 1, "driver count went 0 -> 1")
	local info = d.W.Drive.RankInfo()
	eq(info.n, 1, "RankInfo.n")
	eq(info.rung, 1, "RankInfo.rung")
	eq(info.title, "Learner", "RankInfo.title")
	eq(info.nextAt, 10, "RankInfo.nextAt")
	eq(info.toNext, 9, "RankInfo.toNext")
	local found = nil
	for _, e in ipairs(w:messages("L")) do
		if e.from == T.TESTCHAR and e.chatType == "WHISPER" then found = e end
	end
	ok(found ~= nil, "rider sent kind L arrival report")
	eq(found and found.text, "L~1~" .. rideId, "kind L carries only the ride id")
	-- duplicate report for the same ride id adds nothing
	w:inject(T.TESTCHAR, "L~1~" .. rideId, "WHISPER", d)
	w:advance(1)
	eq(d.W.Drive.RankCount(), 1, "same ride id counts at most once")
	T.clean(w)
end)

test("v24 ranks: same rider counts once per day and counts again next day", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	completeRide(w, d, r, T.TESTCHAR)
	eq(d.W.Drive.RankCount(), 1, "first ride today counts")
	-- second ride from the same rider on the same day adds nothing
	resetRide(w, d, r, T.TESTCHAR)
	local id2 = completeRide(w, d, r, T.TESTCHAR)
	ok(id2, "second ride completed")
	eq(d.W.Drive.RankCount(), 1, "same rider same day adds nothing")
	-- step to the next day by replacing d.W.DayInfo
	local origDayInfo = d.W.DayInfo
	d.W.DayInfo = function(at)
		local day, hour, wday = origDayInfo(at)
		return day and (day + 1) or nil, hour, wday
	end
	resetRide(w, d, r, T.TESTCHAR)
	local id3 = completeRide(w, d, r, T.TESTCHAR)
	ok(id3, "next-day ride completed")
	eq(d.W.Drive.RankCount(), 2, "next day counts again")
	T.clean(w)
end)

test("v24 ranks: chat rider invited from whisper adds nothing", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	w:addBot(T.BOB, { spot = "Orgrimmar", class = "MAGE", acceptsInvites = true, acceptsSummon = true })
	T.settle(w)
	T.goOnline(d)
	w:botWhisper(T.BOB, d, "WTB summon to Ratchet")
	w:advance(3)
	local c = d.W.Drive.customers and d.W.Drive.customers["bob stone"]
	ok(c ~= nil, "chat rider queued")
	eq(c and c.wuberRide, nil, "chat rider has no wuberRide")
	if not d.W.InGroupWith("bob stone") then
		w:invite(d, T.BOB)
		w:advance(2)
	end
	w:summon(d, T.BOB)
	w:advance(1)
	w:move(T.BOB, "Ratchet")
	w:advance(4)
	w:inject(T.BOB, "L~1~AbCdEf", "WHISPER", d)
	w:advance(1)
	eq(d.W.Drive.RankCount(), 0, "chat rider adds nothing")
	T.clean(w)
end)

test("v24 ranks: forged arrival report from third player adds nothing", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	w:addBot(T.BOB, { spot = "Orgrimmar" })
	T.settle(w)
	T.goOnline(d)
	T.requestVia(r, "anita lift")
	w:advance(8)
	if not d.W.InGroupWith("wuber testcharacter") then
		w:invite(d, T.TESTCHAR)
		w:advance(2)
	end
	w:summon(d, T.TESTCHAR)
	w:advance(1)
	local rideId = r.W.ride and r.W.ride.id
	ok(rideId, "active ride id")
	w:inject(T.BOB, "L~1~" .. rideId, "WHISPER", d)
	w:advance(2)
	eq(d.W.Drive.RankCount(), 0, "forged report from third player adds nothing")
	w:inject(T.TESTCHAR, "L~1~" .. rideId, "CHANNEL")
	w:advance(2)
	eq(d.W.Drive.RankCount(), 0, "channel report adds nothing")
	T.clean(w)
end)

test("v24 ranks: crew member ride adds nothing", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	T.requestVia(r, "anita lift")
	w:advance(8)
	w:invite(d, T.TESTCHAR)
	w:advance(2)
	w:player(T.ANITA).target = w:player(T.TESTCHAR)
	w:cast(d, w["ri" .. "tualName"])
	w:advance(1)
	local c = d.W.Drive.customers["wuber testcharacter"]
	ok(c and c.wuberRide and (c.tries or 0) >= 1 and not c.walked, "an app row with a summon started: only the crew rule is left to stop the count")
	-- Wuber is put in the driver's crew (saved the way the drive tests save a crew) before the rider's Wuber reports
	local crew = d.W.Drive.char().crew
	crew[#crew + 1] = { name = T.TESTCHAR, role = "helper", app = true }
	ok(d.W.Drive.IsCrewKey("wuber testcharacter"), "Wuber is in Anita's crew")
	w:summon(d, T.TESTCHAR)
	w:advance(1)
	w:move(T.TESTCHAR, "Ratchet")
	w:advance(4)
	eq(#w:messages("L"), 1, "the rider's Wuber did report the arrival")
	eq(d.W.Drive.RankCount(), 0, "crew member adds nothing")
	T.clean(w)
end)

test("v24 ranks: count survives a reload", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	completeRide(w, d, r, T.TESTCHAR)
	eq(d.W.Drive.RankCount(), 1, "counted before reload")
	d = w:reload(d) or d
	w:advance(5)
	eq(d.W.Drive.RankCount(), 1, "count survives reload")
	eq(d.W.Drive.RankInfo().n, 1, "RankInfo survives reload")
	T.clean(w)
end)

test("v24 ranks: beacon carries field 22 when 1 or more and omits it at 0", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	w:advance(2)
	local ds0 = w:messages("D", T.ANITA)
	ok(#ds0 > 0, "initial beacon sent")
	local f0 = T.fields(ds0[#ds0])
	eq(f0[24], nil, "no field 22 at rank 0")
	ok(#f0 < 24, "beacon at 0 has fewer than 24 wire fields")
	eq(r.W.drivers["anita lift"] and r.W.drivers["anita lift"].rank, nil, "rider sees no rank at 0")
	eq(r.W.UI.Driver("anita lift") and r.W.UI.Driver("anita lift").rank, nil, "UI view has no rank at 0")
	-- set count to 12: it sends no beacon of its own, the next regular one (within 70 s) carries it
	d.W.Char().rank = { n = 12, seen = {} }
	w:advance(7)
	eq(#w:messages("D", T.ANITA), #ds0, "a new count alone sends no beacon")
	w:advance(75)
	local ds12 = w:messages("D", T.ANITA)
	ok(#ds12 > #ds0, "the next regular beacon went out")
	local f12 = T.fields(ds12[#ds12])
	eq(f12[24], "12", "field 22 carries 12")
	eq(r.W.drivers["anita lift"] and r.W.drivers["anita lift"].rank, 12, "rider sees rank 12 on driver")
	eq(r.W.UI.Driver("anita lift") and r.W.UI.Driver("anita lift").rank, 12, "UI driverView carries rank 12")
	T.clean(w)
end)

test("v24 ranks: W.RankOf titles and thresholds", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR)
	local W = r.W
	eq(#W.RANKS, 5, "five ranks")
	local rung, title, nxt = W.RankOf(0)
	eq(rung, 1) eq(title, "Learner") eq(nxt, 10)
	rung, title, nxt = W.RankOf(9)
	eq(rung, 1) eq(title, "Learner") eq(nxt, 10)
	rung, title, nxt = W.RankOf(10)
	eq(rung, 2) eq(title, "Cabbie") eq(nxt, 50)
	rung, title, nxt = W.RankOf(50)
	eq(rung, 3) eq(title, "Black Cab") eq(nxt, 250)
	rung, title, nxt = W.RankOf(250)
	eq(rung, 4) eq(title, "Chauffeur") eq(nxt, 1000)
	rung, title, nxt = W.RankOf(1000)
	eq(rung, 5) eq(title, "Has The Knowledge") eq(nxt, nil)
	rung, title, nxt = W.RankOf(5000)
	eq(rung, 5) eq(title, "Has The Knowledge") eq(nxt, nil)
	eq(W.RankOf(-1), nil, "-1 -> nil")
	eq(W.RankOf("x"), nil, "non-number -> nil")
	eq(W.RankOf(nil), nil, "nil -> nil")
	T.clean(w)
end)

test("v24 ranks: DRIVE_RANK fires with rungChanged true on tenth summon", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d)
	d.W.Char().rank = { n = 9, seen = {} }
	local events = {}
	d.W.Listen("DRIVE_RANK", function(n, rung, title, changed)
		events[#events + 1] = { n = n, rung = rung, title = title, changed = changed }
	end)
	completeRide(w, d, r, T.TESTCHAR)
	eq(#events, 1, "DRIVE_RANK fired once")
	eq(events[1].n, 10, "count 10")
	eq(events[1].rung, 2, "rung 2")
	eq(events[1].title, "Cabbie", "title Cabbie")
	eq(events[1].changed, true, "rungChanged true on 10th summon")
	-- 11th summon on the next day: rungChanged false
	local origDayInfo = d.W.DayInfo
	d.W.DayInfo = function(at)
		local day, hour, wday = origDayInfo(at)
		return day and (day + 1) or nil, hour, wday
	end
	resetRide(w, d, r, T.TESTCHAR)
	completeRide(w, d, r, T.TESTCHAR)
	eq(#events, 2, "DRIVE_RANK fired on 11th summon")
	eq(events[2].n, 11, "count 11")
	eq(events[2].rung, 2, "still rung 2")
	eq(events[2].title, "Cabbie", "still Cabbie")
	eq(events[2].changed, false, "rungChanged false on 11th summon")
	T.clean(w)
end)
