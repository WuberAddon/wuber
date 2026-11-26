local T = ...
local test, eq, ok = T.test, T.eq, T.ok
-- #19 A driver who pauses and resumes shows as open to riders only 10-11 s later when many drivers are online
-- (net=many: 8 open, 9 online). Promise: a driver who resumes shows to a rider as open within the documented beacon gap
-- (NETK.BEACON_GAP = 5 s, plus the one second the queue takes to send), however many other drivers are online.
-- Cause: Net/Transport.lua put the channel beacon (D) at priority 3 behind whispered Q and K kinds (priority 2), which at
-- NETK.RATE = 1 per second starve it while Discovery talks to the other drivers.
local OTHERS = { "Aldra", "Brenn", "Corva", "Dunn", "Elsin", "Farrow", "Gwen", "Holt" }

local function world(many)
	local w = T.newWorld()
	local rider = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	local zed = T.driver(w, "Zedhale", { spot = "Ratchet" })
	if many then
		for _, n in ipairs(OTHERS) do T.goOnline(T.driver(w, n, { spot = "Ratchet" })) end
	end
	T.settle(w)
	T.goOnline(zed)
	w:advance(20)
	return w, rider, zed
end
local function state(rider)
	local e = rider.W.drivers["zedhale"]
	return e and e.state or "nil"
end

-- the same promise at two advance() step sizes (a state change run from an event and a timer)
local function sweep(many, step)
	local w, rider, zed = world(many)
	zed:slash("/wuber drive pause")
	local t = 0
	while t < 12 and state(rider) == "open" do w:advance(step) t = t + step end
	local paused = state(rider)
	w:advance(8)
	zed:slash("/wuber drive resume")
	if many then
		-- the Discovery round and K gossip to the other drivers (Net/Discovery.lua): one whisper each, a second apart on the wire
		for _, n in ipairs(OTHERS) do zed.W.SendTo(n, "Q") end
		for _, n in ipairs(OTHERS) do zed.W.SendTo(n, "K", "Someone") end
	end
	local waited = 0
	while waited < 6 and state(rider) ~= "open" do w:advance(step) waited = waited + step end
	return w, rider, paused, state(rider), waited
end

-- guard: a beacon whose state is unchanged keeps its place behind the whispers to other drivers (priority 3)
test("#19 a beacon with an unchanged state still waits behind the whispers (one message a second, as before)", function()
	local w, rider, zed = world(true)
	local lastD
	for _, e in ipairs(w.addonLog) do if e.from == zed.player.name and e.text:sub(1, 2) == "D~" then lastD = e.text end end
	ok(lastD, "control: his beacon is on the wire")
	local from = #w.addonLog
	for _, n in ipairs(OTHERS) do zed.W.SendTo(n, "Q") end
	local f = {}
	for x in (lastD .. "~"):gmatch("(.-)~") do f[#f + 1] = x end
	zed.W.SendChannel("D", unpack(f, 2))
	w:advance(20)
	local dAt, qBefore = nil, 0
	for i = from + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.from == zed.player.name then
			if e.text:sub(1, 2) == "D~" and e.chatType == "CHANNEL" and not dAt then dAt = i end
			if e.text:sub(1, 2) == "Q~" and e.chatType == "WHISPER" and not dAt then qBefore = qBefore + 1 end
		end
	end
	ok(dAt, "control: the beacon went out")
	ok(qBefore >= 3, "an unchanged beacon went to the head of the queue: only " .. qBefore .. " whispers went before it")
	T.clean(w, { throttled = true })
end)

-- guard: an urgent beacon still waits behind ride whispers (priority 1), and replaces a stale queued beacon (one D goes out)
test("#19 a changed-state beacon goes behind a ride whisper and replaces the queued beacon (one D)", function()
	local w, rider, zed = world(true)
	local lastD
	for _, e in ipairs(w.addonLog) do if e.from == zed.player.name and e.text:sub(1, 2) == "D~" then lastD = e.text end end
	ok(lastD, "control: his beacon is on the wire")
	local f = {}
	for x in (lastD .. "~"):gmatch("(.-)~") do f[#f + 1] = x end
	local from = #w.addonLog
	-- one whisper a second: hold the queue with Qs, then a ride whisper (priority 1), a stale D, and the changed-state D
	for _, n in ipairs(OTHERS) do zed.W.SendTo(n, "Q") end
	zed.W.SendTo(rider.player.name, "A", "x")
	zed.W.SendChannel("D", unpack(f, 2))
	local g = { unpack(f, 2) }
	g[7] = "paused"
	zed.W.SendChannel("D", unpack(g, 1, #f - 1))
	w:advance(25)
	local dCount, dAt, aAt = 0, nil, nil
	for i = from + 1, #w.addonLog do
		local e = w.addonLog[i]
		if e.from == zed.player.name then
			if e.text:sub(1, 2) == "D~" and e.chatType == "CHANNEL" then
				dCount = dCount + 1
				dAt = dAt or i
			end
			if e.text:sub(1, 2) == "A~" and not aAt then aAt = i end
		end
	end
	ok(dAt, "control: the changed beacon went out")
	eq(dCount, 1, "the stale queued beacon was replaced, not sent as well")
	ok(not aAt or aAt < dAt, "a ride whisper went after the beacon")
	T.clean(w, { throttled = true })
end)

for _, step in ipairs({ 1, 5 }) do
	test("#19 net=many: a driver who resumes shows as open to the rider within 6 s (steps of " .. step .. " s)", function()
		local w, rider, paused, after, waited = sweep(true, step)
		ok(paused ~= "open", "control: the rider saw him stop being open (" .. paused .. ")")
		eq(after, "open", "ten others online: after " .. waited .. " s the rider still sees him as " .. after)
		T.clean(w, { throttled = true })
	end)
	-- guard: with one driver online the beacon went out on time before the fix (net=one timing unchanged)
	test("#19 net=one: a driver who resumes shows as open within 6 s (steps of " .. step .. " s)", function()
		local w, rider, paused, after, waited = sweep(false, step)
		ok(paused ~= "open", "control: the rider saw him stop being open (" .. paused .. ")")
		eq(after, "open", "after " .. waited .. " s the rider sees him as " .. after)
		T.clean(w, { throttled = true })
	end)
end
