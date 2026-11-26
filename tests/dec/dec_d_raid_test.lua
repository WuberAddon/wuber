-- Decisions round, group D: raid summons "here" means in sight of the summoner (FAB-04); the + on a Not here raider
-- is dimmed until Start (AUD-173). Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

test("dec d: FAB-04 a raider at the Crossroads stays queued when the Warlock stands in Ratchet (same zone, a long ride apart)", function()
	local w = H.NewWorld({})
	local d = w:addClient(T.ANITA, { spot = "Ratchet", class = "WARLOCK" })
	w:addBot("Raider Ra", { spot = "Crossroads", class = "WARRIOR" })
	w:addBot("Raider Rb", { spot = "Orgrimmar", class = "WARRIOR" })
	w:addBot("Raider Rc", { spot = "Ratchet", class = "WARRIOR" })
	w:group({ T.ANITA, "Raider Ra", "Raider Rb", "Raider Rc" })
	T.settle(w)
	local DR = d.W.Drive
	-- sight: the harness sees everyone in the same zone; the real game does not see a raider a long ride away
	local seeing = d.env.UnitIsVisible
	d.env.UnitIsVisible = function(unit)
		if unit == DR.units[key("Raider Ra")] then return false end
		return seeing(unit)
	end
	ok(DR.SetMode("raid"), "setup: raid mode")
	local okOpen, why = DR.SetOpen(true)
	ok(okOpen, "setup: Start (" .. tostring(why) .. ")")
	w:advance(3)
	ok(DR.RaidAdd("Raider Rb"), "setup: Rb asked")
	ok(DR.RaidAdd("Raider Ra"), "setup: Ra asked")
	ok(DR.RaidAdd("Raider Rc"), "setup: Rc asked")
	w:advance(4)
	ok(DR.raidRows[key("Raider Rb")], "control: Rb (in Orgrimmar) stays in the queue")
	ok(not DR.raidRows[key("Raider Rc")], "control: Rc is in sight at Ratchet, so he is here and off the queue")
	ok(DR.raidRows[key("Raider Ra")], "Raider Ra stands at the Crossroads and asked for a summon to Ratchet, but was taken off the queue as 'here' (same zone map)")
	T.clean(w)
end)
-- AUD-173: adapted from the audit's C55_C55r-6 test
local DRU, LEA, CAL = "Dru Oak", "Lea Dorn", T.CAL
local RAIDSPOT = "Blackrock Mountain"

local function raid(start)
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = RAIDSPOT, class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = RAIDSPOT, class = "DRUID" })
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK" })
	local names = { LEA, DRU, CAL }
	for i = 1, 5 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	local DD = dru.W.Drive
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick(CAL, true))
	w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true)
	w:advance(3)
	if start then ok(DD.SetOpen(true), "Start") end
	w:advance(5)
	return w, dru
end

local function plusClick(w, dru)
	local W = dru.W
	T.openDrive(dru)
	W.UI.ShowDrive("console")
	w:advance(1)
	local R = W.Driver.ui.console.raid
	ok(R, "the raid page is built")
	R.open = true
	W.Driver.RefreshNow()
	w:advance(1)
	local row = R.nh[1]
	ok(row and H.visible(row), "the first Not here row shows")
	local who = row.who
	local alpha = row.add:GetAlpha()
	dru:click(row.add)
	w:advance(1)
	return who, W, alpha, row
end

test("dec d: AUD-173 the + on a Not here raider is dimmed before Start, queues nobody and toasts nothing; after Start it works", function()
	local w, dru = raid(true)
	ok(dru.W.Drive.RaidOn(), "control: raid summons are running")
	local who, W, alpha = plusClick(w, dru)
	ok(alpha == 1, "control: after Start the + is not dimmed (" .. tostring(alpha) .. ")")
	ok(W.Drive.raidRows[who:lower():gsub("[%s%-]+", " ")] ~= nil, "control: after Start, + queues " .. who)
	local w2, dru2 = raid(false)
	ok(not dru2.W.Drive.RaidOn(), "raid summons are not started")
	local who2, W2, alpha2, row2 = plusClick(w2, dru2)
	ok(alpha2 < 1, "the + is dimmed before Start (" .. tostring(alpha2) .. ")")
	ok(W2.Drive.raidRows[who2:lower():gsub("[%s%-]+", " ")] == nil, "nobody is queued")
	eq(#dru2:findText("is in the queue"), 0, "no toast says anyone is in the queue")
	ok(row2.add:IsMouseEnabled() ~= false, "the dimmed + still takes the mouse, so its tooltip shows")
	T.clean(w2)
end)
