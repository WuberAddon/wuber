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

test("a raider who has landed is no longer shown as on the summon list on their own Ride tab", function()
	local w, dru, cal = raid20()
	local ray = w:addClient("Ray Ash", { spot = "Orgrimmar", class = "ROGUE" })
	w:join(w:player("Lea Dorn"), w:player("Ray Ash"))
	w:advance(2)
	local DD, DC = startRun(w, dru, cal)
	w:advance(15)
	local RD = ray.W.Drive
	ok(RD.RaidHere(), "control: Ray's window sees raid summons")
	ok(RD.RaidAsk()) w:advance(3)
	ok(DD.raidRows[key("Ray Ash")] and DC.raidRows[key("Ray Ash")], "control: Ray queued on the runner's and Cal's windows")
	eq(RD.RaidHere().queued, true, "control: Ray sees he is queued")
	-- he is summoned: lands at the entrance
	w:move("Ray Ash", "Blackrock Mountain")
	w:advance(5)
	eq(DD.raidRows[key("Ray Ash")], nil, "control: the runner's window dropped Ray on arrival")
	eq(DC.raidRows[key("Ray Ash")], nil, "control: Cal's window dropped Ray on arrival")
	local here = RD.RaidHere()
	ok(here and here.queued == false,
		"Ray has landed at the entrance but his own Ride tab still says he is on the summon list (queued=" .. tostring(here and here.queued) .. ", state=" .. tostring(here and here.state) .. ")")
	T.clean(w)
end)

test("a summoner in the runner's crew is not offered Request a summon on her own Ride tab", function()
	local w, dru, cal = raid20()
	local DD, DC = startRun(w, dru, cal)
	w:advance(15)
	ok(DC.RaidOn(), "control: Cal is one of the runner's summoners")
	cal.W.UI.Toggle(true) w:advance(2.5)
	local shown = T.list(cal:visibleTexts())
	ok(#cal:findText("Request a summon") == 0,
		"Cal is the runner's own summoner but her Ride tab offers 'Request a summon' (screen: " .. shown:sub(1, 160) .. ")")
	T.clean(w)
end)

