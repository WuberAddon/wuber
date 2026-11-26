-- Round 29 group G (AUD-76, Google C44b-1): when the runner stops raid summons, the crew Warlock's
-- window and a raider's own (mirror) window forget the old queue, so a restart lists only the new run.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local DRU, CAL, BEA, LEA, RAY = "Dru Oak", "Cal Brown", "Bea Jones", "Lea Dorn", "Ray Ash"
local RAIDSPOT = "Blackrock Mountain"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function names(rows)
	local out = {}
	for _, r in ipairs(rows) do out[#out + 1] = r.name end
	return table.concat(out, ", ")
end

-- A raid at Blackrock: Dru (Druid, assist) runs raid summons, Cal (Warlock) summons for Dru;
-- Ray (a rider with Wuber, not crew) and Raider Ra-Rh wait in Orgrimmar.
local function raid()
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = RAIDSPOT, class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = RAIDSPOT, class = "DRUID" })
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK" })
	w:addBot(BEA, { spot = RAIDSPOT, class = "WARLOCK", shards = 10 })
	local list = { LEA, DRU, CAL, BEA, RAY }
	for i = 1, 8 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		list[#list + 1] = n
	end
	local ray = T.rider(w, RAY, { spot = "Orgrimmar" })
	w:group(list)
	w:setAssist(DRU, true)
	T.settle(w)
	local DD = dru.W.Drive
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick(CAL, true))
	w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true)
	w:advance(3)
	ok(DD.SetOpen(true), "Start")
	w:advance(20)
	ok(DD.RaidOn() and cal.W.Drive.RaidOn(), "control: raid summons run on the runner's and Cal's windows")
	ok(ray.W.Drive.RaidHere(), "control: Ray's window sees raid summons")
	return w, DD, cal.W.Drive, ray.W.Drive
end

local function firstRun(w, DD, DC, DY)
	ok(DD.RaidAdd("Raider Ra"), "Ra queued")
	ok(DD.RaidAdd("Raider Rb"), "Rb queued")
	w:advance(3)
	ok(DC.raidRows[key("Raider Ra")] and DY.raidRows[key("Raider Ra")], "control: Ra listed on Cal's and Ray's windows")
end

local function stopAndRestart(w, DD, DC, DY)
	ok(DD.SetOpen(false), "the runner stops")
	w:advance(3)
	ok(not DD.RaidOn() and not DC.RaidOn(), "control: raid summons off on the runner's and Cal's windows")
	eq(next(DD.raidRows), nil, "control: the runner's own list is cleared on stop")
	ok(DD.SetOpen(true), "the runner starts again")
	w:advance(5)
	ok(DD.RaidOn() and DC.RaidOn(), "control: running again on both")
	eq(#DD.RaidQueue(), 0, "control: the runner's new queue is empty")
end

test("r29 AUD-76: after the runner stops and restarts raid summons, a crew Warlock's console lists only the new run", function()
	local w, DD, DC, DY = raid()
	firstRun(w, DD, DC, DY)
	stopAndRestart(w, DD, DC, DY)
	local q = DC.RaidQueue()
	eq(#q, 0, "Cal's console lists nobody from the previous run: " .. names(q))
	eq(DC.RaidNext(), nil, "Cal's button offers nobody from the previous run")
	ok(DD.RaidAdd("Raider Rc"), "Rc asks in the new run")
	w:advance(3)
	q = DC.RaidQueue()
	eq(names(q), "Raider Rc", "Cal's console shows the new run's raider")
	local nxt = DC.RaidNext()
	eq(nxt and nxt.name, "Raider Rc", "Cal's button offers the new run's raider")
	T.clean(w)
end)

test("r29 AUD-76: after the runner stops and restarts raid summons, a raider's own window follows only the new run", function()
	local w, DD, DC, DY = raid()
	firstRun(w, DD, DC, DY)
	ok(DY.RaidAsk(), "Ray asks in the first run")
	w:advance(3)
	ok(DY.raidRows[key(RAY)], "control: Ray's own row is mirrored")
	stopAndRestart(w, DD, DC, DY)
	eq(next(DY.raidRows), nil, "Ray's window keeps no row from the previous run")
	local here = DY.RaidHere()
	ok(here and not here.queued, "Ray is not shown as queued in the new run")
	ok(DD.RaidAdd("Raider Rc"), "Rc asks in the new run")
	ok(DY.RaidAsk(), "Ray asks in the new run")
	w:advance(3)
	ok(DY.raidRows[key("Raider Rc")], "Ray's window mirrors the new run's raider")
	here = DY.RaidHere()
	ok(here and here.queued, "Ray is shown as queued in the new run")
	T.clean(w)
end)

test("r29 AUD-76: a repeat of the runner's running state (a sync) or a pause keeps the live queue on crew and raider windows", function()
	local w, DD, DC, DY = raid()
	firstRun(w, DD, DC, DY)
	DD.SendConfig()
	DD.SyncNow()
	w:advance(3)
	ok(DC.raidRows[key("Raider Ra")] and DC.raidRows[key("Raider Rb")], "Cal's console keeps Ra and Rb after a sync")
	ok(DY.raidRows[key("Raider Ra")] and DY.raidRows[key("Raider Rb")], "Ray's window keeps Ra and Rb after a sync")
	ok(DD.SetPaused(true), "the runner pauses")
	w:advance(3)
	ok(DD.SetPaused(false), "the runner resumes")
	w:advance(3)
	ok(DC.raidRows[key("Raider Ra")], "Cal's console keeps Ra over a pause")
	ok(DY.raidRows[key("Raider Ra")], "Ray's window keeps Ra over a pause")
	T.clean(w)
end)
