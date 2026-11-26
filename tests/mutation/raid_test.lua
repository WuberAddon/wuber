-- Tests from the mutation run (job 2765) for Drive.Raid (raid summon coordination): each guards a line that no
-- other test noticed when it was broken.
local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list

local DRU, LEA, CAL, BEA, RAY = "Dru Oak", "Lea Dorn", T.CAL, T.BEA, "Ray Ash"
local RAIDSPOT = "Blackrock Mountain"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function DRof(c) return c.W.Drive end

-- A raid at Blackrock: Lea (a bot) leads, Dru (Druid, assist) runs raid summons, Cal (Warlock) summons, Bea (Warlock)
-- too when `second`; Raider Ra-Rf wait in Orgrimmar.
local function raidWorld(second)
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = RAIDSPOT, class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = RAIDSPOT, class = "DRUID" })
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK" })
	local bea = second and w:addClient(BEA, { spot = RAIDSPOT, class = "WARLOCK" }) or nil
	local names = { LEA, DRU, CAL }
	if bea then names[#names + 1] = BEA end
	for i = 1, 6 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	local DD = DRof(dru)
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
	w:advance(5)
	return w, dru, cal, bea
end

local function queue(w, dru, others, ...)
	for _, n in ipairs({ ... }) do ok(DRof(dru).RaidAdd(n), "queued " .. n) end
	w:advance(3)
	for _, n in ipairs({ ... }) do
		for _, c in ipairs(others) do ok(DRof(c).raidRows[key(n)], n .. " listed on " .. c.player.name) end
	end
end

local function nextName(c)
	local r = DRof(c).RaidNext()
	return r and r.name or "nobody"
end

local function count(w, kind, pattern)
	local n = 0
	for _, e in ipairs(w.addonLog) do
		if e.prefix == "WUBERT" and e.result == 0 and not e.dropped and e.text:match("^([^~]*)") == kind
			and (not pattern or e.text:find(pattern, 1, true)) then n = n + 1 end
	end
	return n
end

-- Cal casts on the raider and the summon fails (his END 0): the real path to a failed try.
local function failTry(w, cal, name)
	DRof(cal).Do("CAST", name)
	w:advance(2)
	DRof(cal).Do("END", name, 0)
	w:advance(2)
end

-- guards Wuber/Drive/Raid.lua:407 (mutation run 2765, mutant 15929: cmp ==->~=)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation raid: with two summoners free, the second one's button offers the second raider, not the first summoner's", function()
	local w, dru, cal, bea = raidWorld(true)
	queue(w, dru, { cal, bea }, "Raider Ra", "Raider Rb", "Raider Rc")
	eq(nextName(cal), "Raider Ra", "Cal (first summoner) takes the first raider")
	eq(nextName(bea), "Raider Rb", "Bea (second summoner) takes the second raider")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:404 and :408 (mutation run 2765, mutants 16341: cmp ==->~=, 32476: swap and->or)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation raid: a summoner who is busy with a raider is skipped, so the next summoner's button offers the first free raider", function()
	local w, dru, cal, bea = raidWorld(true)
	queue(w, dru, { cal, bea }, "Raider Ra", "Raider Rb", "Raider Rc")
	DRof(cal).Do("CAST", "Raider Ra")
	w:advance(2)
	eq(DRof(bea).raidRows[key("Raider Ra")].state, "summoning", "Bea's window sees Cal's claim")
	eq(nextName(bea), "Raider Rb", "Bea gets Rb (Cal is busy with Ra), not Rc")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:306 (mutation run 2765, mutant 9369: swap and->or)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation raid: a crew window that is not the order keeper never lists a raider's request itself", function()
	local w, dru, cal = raidWorld()
	local C = DRof(cal)
	eq(DRof(dru).RaidOrderKey(), key(DRU), "control: the runner keeps the queue")
	eq(C.RaidOrderKey(), key(DRU), "control: Cal's window knows that")
	local before = count(w, "RA")
	C.RaidApply("RA", key("Raider Rd"), false, "Raider Rd", nil, nil, 100)
	w:advance(3)
	eq(count(w, "RA"), before, "Cal's window sends no queue line for a request the keeper has not listed")
	eq(DRof(dru).raidRows[key("Raider Rd")], nil, "so nothing was listed from Cal's window")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:437 (mutation run 2765, mutant 19070: cmp ==->~=)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation raid: when the order keeper gives up on a raider, it tells every window the raider is dropped", function()
	local w, dru, cal = raidWorld()
	queue(w, dru, { cal }, "Raider Ra")
	failTry(w, cal, "Raider Ra")
	failTry(w, cal, "Raider Ra")
	local row = DRof(dru).raidRows[key("Raider Ra")]
	ok(row and row.failedAt, "control: the second failed summon starts the give-up clock")
	local before = count(w, "RD", "gaveup")
	DRof(dru).RaidTick(row.failedAt + DRof(dru).RAID_GIVE_UP + 1)
	w:advance(3)
	eq(DRof(dru).raidRows[key("Raider Ra")], nil, "dropped on the keeper's window")
	eq(count(w, "RD", "gaveup"), before + 1, "the keeper sent one gaveup fact")
	eq(DRof(cal).raidRows[key("Raider Ra")], nil, "dropped on Cal's window too")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:333 (mutation run 2765, mutant 23974: swap and->or)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation raid: a reloaded window is told the claim only of raiders being summoned or waiting, never of a queued one", function()
	local w, dru, cal = raidWorld()
	queue(w, dru, { cal }, "Raider Ra", "Raider Rb")
	DRof(cal).Do("CAST", "Raider Ra")
	w:advance(2)
	local D = DRof(dru)
	-- Rb is back in the queue: a leftover claim name must not be re-sent
	local rb = D.raidRows[key("Raider Rb")]
	rb.state, rb.claimedBy = "queued", key(CAL)
	local before = count(w, "CAST")
	D.RaidSync()
	w:advance(10)
	eq(count(w, "CAST") - before, 1, "one CAST line: for Ra only")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:280 (mutation run 2765, mutant 346: cmp >=-><)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation raid: a raider whose summon failed once stays queued; after the second failure the raider is dropped after the give-up time", function()
	local w, dru, cal = raidWorld()
	queue(w, dru, { cal }, "Raider Ra")
	local D = DRof(dru)
	local k = key("Raider Ra")
	failTry(w, cal, "Raider Ra")
	local t1 = dru.env.GetTime()
	eq(D.raidRows[k].fails, 1, "one failure counted")
	D.RaidTick(t1 + D.RAID_GIVE_UP + 1)
	ok(D.raidRows[k], "after one failure the raider is still queued long after the give-up time")
	failTry(w, cal, "Raider Ra")
	local t2 = D.raidRows[k].failedAt
	eq(D.raidRows[k].fails, 2, "two failures counted")
	D.RaidTick(t2 + D.RAID_GIVE_UP - 1)
	ok(D.raidRows[k], "after two failures he is kept until the give-up time")
	D.RaidTick(t2 + D.RAID_GIVE_UP + 1)
	eq(D.raidRows[k], nil, "then dropped")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:454 (mutation run 2765, mutant 9798: cmp >=-><)
-- guard: passes on main by design; proven to fail with the line broken
test("mutation raid: a crew window keeps raid summons running for a few seconds after the runner leaves, then stops them", function()
	local w, dru, cal = raidWorld()
	local C = DRof(cal)
	local told = 0
	local alert = C.Alert
	C.Alert = function(text, kind, ...)
		if tostring(text):find("Raid summons stopped: the runner left", 1, true) then told = told + 1 end
		return alert(text, kind, ...)
	end
	ok(C.RaidOn(), "control: raid summons run on Cal's window")
	w:leave(DRU)
	local gone = C.RAID_KEEPER_GONE
	for _ = 1, gone - 2 do w:advance(1) end
	ok(C.RaidOn(), "before the keeper-gone time has passed: not stopped yet")
	eq(told, 0, "nothing said yet")
	for _ = 1, gone + 3 do w:advance(1) end
	ok(not C.RaidOn(), "later: stopped")
	eq(told, 1, "told once")
	T.clean(w)
end)
