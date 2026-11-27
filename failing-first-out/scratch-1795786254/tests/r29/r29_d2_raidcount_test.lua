local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H
local DRU, CAL, BEA = "Dru Oak", "Cal Brown", "Bea Jones"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function raid20()
	local w = T.newWorld()
	w:addBot("Lea Dorn", { spot = "Blackrock Mountain", class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = "Blackrock Mountain", class = "DRUID" })
	local cal = w:addClient(CAL, { spot = "Blackrock Mountain", class = "WARLOCK" })
	w:addBot(BEA, { spot = "Blackrock Mountain", class = "WARLOCK", shards = 10 })
	w:player(BEA).knowsRitual = true
	local names = { "Lea Dorn", DRU, CAL, BEA }
	for i = 1, 16 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = i <= 8 and "Orgrimmar" or "Blackrock Mountain", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	return w, dru, cal
end
local function startRun(w, dru, cal)
	local DD = dru.W.Drive
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick(CAL, true)) w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true) w:advance(3)
	ok(DD.SetOpen(true)) w:advance(3)
	ok(DD.RaidOn() and cal.W.Drive.RaidOn(), "raid summons run on both windows")
	return DD, cal.W.Drive
end

local function crewCount(DC, name, why, cast)
	local k = key(name)
	DC.raidRows[k] = nil
	local now = 100
	local d = DC.RaidApply("RA", key(DRU), nil, name, nil, nil, now)
	ok(DC.raidRows[k], "control: the row is on the crew window")
	if cast then ok(DC.RaidApply("CAST", key(CAL), nil, name, key(CAL), nil, now)) end
	local before = DC.RaidCount()
	DC.RaidApply("RD", key(DRU), nil, name, why, nil, now)
	eq(DC.raidRows[k], nil, "the row is dropped")
	return DC.RaidCount() - before
end

test("a crew window that casts still counts the summon when the order keeper's raider-here fact reaches it before its own tick", function()
	local w, dru, cal = raid20()
	local DD, DC = startRun(w, dru, cal)
	w:advance(15)
	eq(crewCount(DC, "Raider Ra", "here", true), 1, "Summoned tonight goes up by one on the second crew window")
	T.clean(w)
end)

test("a raider dropped by hand, cancel or given up on is not counted as summoned tonight", function()
	local w, dru, cal = raid20()
	local DD, DC = startRun(w, dru, cal)
	w:advance(15)
	eq(crewCount(DC, "Raider Rb", "hand", true), 0, "hand")
	eq(crewCount(DC, "Raider Rc", "gaveup", true), 0, "gaveup")
	eq(crewCount(DC, "Raider Rd", "here", false), 0, "never cast on: not counted")
	T.clean(w)
end)
