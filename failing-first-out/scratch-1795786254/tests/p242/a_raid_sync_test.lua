-- Group A of prep-242: raid rows survive a reload on either side (AU24-04, AU24-05), and a crew window
-- stops raid summons when the runner left and nobody keeps the queue (AU24-30).
local T = ...
local test = T.test
local H, eq, ok = T.H, T.eq, T.ok

local DRU, LEA, CAL, BEA, RAY = "Dru Oak", "Lea Dorn", T.CAL, T.BEA, "Ray Ash"
local RAIDSPOT = "Blackrock Mountain"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- A raid at Blackrock: Lea (a bot) leads, Dru (Druid, assist) runs raid summons, Cal (Warlock) summons,
-- Bea (Warlock) too when `second`; Raider Ra-Rd wait in Orgrimmar; Ray mirrors the queue.
local function raidWorld(second)
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = RAIDSPOT, class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = RAIDSPOT, class = "DRUID" })
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK" })
	local names = { LEA, DRU, CAL, RAY }
	for i = 1, 4 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	local bea
	if second then
		bea = w:addClient(BEA, { spot = RAIDSPOT, class = "WARLOCK" })
		names[#names + 1] = BEA
	end
	local ray = T.rider(w, RAY, { spot = "Orgrimmar" })
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	local DD = dru.W.Drive
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick(CAL, true))
	w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true)
	w:advance(3)
	if bea then
		ok(DD.RaidPick(BEA, true))
		w:advance(1)
		bea.W.Drive.AnswerOffer(DRU, true)
		w:advance(3)
	end
	ok(DD.SetOpen(true), "Start")
	w:advance(20)
	return w, dru, cal, ray, bea
end

-- The raid queue as a window shows it: "name:state:claimer" in queue order.
local function queueOf(c)
	local out = {}
	for _, row in ipairs(c.W.Drive.RaidQueue()) do
		out[#out + 1] = row.key .. ":" .. tostring(row.state) .. ":" .. tostring(row.claimedBy or "-")
	end
	return table.concat(out, ",")
end

local function alertsOf(c)
	local DR, out = c.W.Drive, {}
	local alert = DR.Alert
	DR.Alert = function(text, kind, ...)
		out[#out + 1] = tostring(text)
		return alert(text, kind, ...)
	end
	return out
end

test("p242 A AU24-04: a crew window that reloads mid-raid lists the runner's raiders again, in the same order, claims kept", function()
	local w, dru, cal, ray, bea = raidWorld(true)
	local D = dru.W.Drive
	ok(D.RaidAdd("Raider Ra"), "Ra queued")
	w:advance(1)
	ok(D.RaidAdd("Raider Rb"), "Rb queued")
	w:advance(1)
	ok(D.RaidAdd("Raider Rc"), "Rc queued")
	w:advance(1)
	ok(D.RaidTop("Raider Rc"), "Rc moved to the top")
	w:advance(1)
	-- Bea claims Rb (her button's cast: the CAST fact)
	bea.W.Drive.Do("CAST", "Raider Rb")
	w:advance(3)
	local before = queueOf(dru)
	eq(queueOf(cal), before, "before the reload Cal's window and the runner's agree")
	local triesBefore = D.raidRows[key("Raider Rb")].tries
	cal = w:reload(cal)
	w:advance(20)
	ok(cal.W.Drive.RaidOn(), "Cal's window knows raid summons run")
	eq(queueOf(cal), before, "after the reload Cal's window lists the runner's raiders, same order and claim")
	eq(queueOf(dru), before, "the runner's queue did not change")
	eq(queueOf(bea), before, "Bea's queue did not change")
	eq(D.raidRows[key("Raider Rb")].tries, triesBefore, "the sync's copy of Bea's claim is not counted as another try")
	T.clean(w)
end)

-- The same queue reached the other way: a raider asking after the reload (no sync involved).
-- guard: a 123 after a crew window's reload already reached every window before the sync existed
test("p242 A AU24-04 guard: after a crew window's reload a new 123 is listed once, on every window", function()
	local w, dru, cal = raidWorld()
	ok(dru.W.Drive.RaidAdd("Raider Ra"), "Ra queued")
	w:advance(3)
	cal = w:reload(cal)
	w:advance(20)
	w:botWhisper("Raider Rb", cal, "123")
	w:advance(5)
	ok(cal.W.Drive.raidRows[key("Raider Rb")] and dru.W.Drive.raidRows[key("Raider Rb")], "Rb is listed on both")
	T.clean(w)
end)

test("p242 A AU24-05: the runner reloads mid-raid: its window gets the raiders back from the crew, same order and claim", function()
	local w, dru, cal, ray = raidWorld()
	local D = dru.W.Drive
	ok(D.RaidAdd("Raider Ra"), "Ra queued")
	w:advance(1)
	ok(D.RaidAdd("Raider Rb"), "Rb queued")
	w:advance(1)
	cal.W.Drive.Do("CAST", "Raider Ra")
	w:advance(3)
	local before = queueOf(cal)
	eq(queueOf(dru), before, "before the reload both agree")
	dru = w:reload(dru)
	w:advance(20)
	ok(dru.W.Drive.RaidOn(), "raid summons still run on the runner's window")
	eq(queueOf(dru), before, "after the reload the runner's window lists the crew's raiders, same order and claim")
	eq(queueOf(cal), before, "Cal's queue did not change")
	ok(ray.W.Drive.raidRows[key("Raider Ra")] and ray.W.Drive.raidRows[key("Raider Rb")], "Ray's mirror still lists both")
	T.clean(w)
end)

-- AU24-30 at two step sizes: the stop comes from the crew window's once-a-second raid tick.
for _, step in ipairs({ 1, 5 }) do
	test("p242 A AU24-30: the runner left the group and nobody keeps the queue: the crew window says raid summons stopped (step " .. step .. " s)", function()
		local w, dru, cal = raidWorld()
		local C = cal.W.Drive
		local said = alertsOf(cal)
		ok(C.RaidAdd("Raider Ra"), "Ra queued")
		w:advance(3)
		ok(C.RaidOn(), "Cal's window runs raid summons before the runner leaves")
		w:leave(DRU)
		for _ = 1, math.ceil(20 / step) do w:advance(step) end
		ok(not C.RaidOn(), "the runner left and Lea (no Wuber) leads: Cal's window no longer says raid summons run")
		ok(next(C.raidRows) == nil, "Cal's window lists nobody: no window keeps that queue")
		local told = 0
		for _, t in ipairs(said) do if t:find("Raid summons stopped: the raid leader left", 1, true) then told = told + 1 end end
		eq(told, 1, "Cal is told once that raid summons stopped")
		w:botWhisper("Raider Rb", cal, "123")
		w:advance(5)
		ok(next(C.raidRows) == nil and not C.RaidOn(), "a later 123 is not promised a summon")
		T.clean(w)
	end)
end

-- guard (the neighbouring path): the runner left, but Cal's own window leads: Cal keeps the queue, so raid
-- summons go on there and a raider's 123 is listed.
-- guard: a leading crew window kept raid summons running before the fix; the stop must not touch it
test("p242 A AU24-30 guard: the runner left and the crew window leads: raid summons go on and a 123 is listed", function()
	local w, dru, cal = raidWorld()
	local C = cal.W.Drive
	local g = w:player(LEA).group
	g.leader = CAL
	w:rosterChanged(g)
	w:advance(3)
	w:leave(DRU)
	w:advance(20)
	ok(C.RaidOn(), "Cal leads: raid summons still run on Cal's window")
	w:botWhisper("Raider Rb", cal, "123")
	w:advance(5)
	ok(C.raidRows[key("Raider Rb")], "Rb's 123 is listed on Cal's window")
	T.clean(w)
end)

-- The runner is still in the group: a crew window never stops on its own.
-- guard: nothing stopped raid summons on a crew window before the fix; the new stop must not start here
test("p242 A AU24-30 guard: while the runner is in the group the crew window keeps raid summons running", function()
	local w, dru, cal = raidWorld()
	w:advance(30)
	ok(cal.W.Drive.RaidOn(), "raid summons still run on Cal's window")
	T.clean(w)
end)
