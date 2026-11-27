local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local DRU, LEA, CAL = "Dru Oak", "Lea Dorn", T.CAL
local RAIDSPOT = "Blackrock Mountain"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

local function raid()
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
	ok(DD.SetOpen(true), "Start")
	w:advance(20)
	return w, dru, cal
end

test("r33 AUD-85: a raider who says nvm while raid summons are paused is dropped", function()
	local w, dru, cal = raid()
	local DD = dru.W.Drive
	ok(DD.RaidAdd("Raider Ra"), "Ra queued")
	ok(DD.RaidAdd("Raider Rb"), "Rb queued")
	w:advance(2)
	-- control: not paused, a cancel whisper takes the raider off the queue
	w:botWhisper("Raider Rb", dru, "nvm")
	w:advance(2)
	ok(not DD.raidRows[key("Raider Rb")], "control: Rb's cancel while running should drop Rb")
	-- the bug: paused, Ra changes their mind
	ok(DD.SetPaused(true), "paused")
	w:advance(2)
	ok(DD.raidRows[key("Raider Ra")], "Ra still queued while paused")
	w:botWhisper("Raider Ra", dru, "nvm")
	w:advance(2)
	DD.SetPaused(false)
	w:advance(3)
	ok(not DD.raidRows[key("Raider Ra")],
		"Raider Ra said 'nvm' during the pause but is still on the queue after resume (row state=" .. tostring(DD.raidRows[key("Raider Ra")] and DD.raidRows[key("Raider Ra")].state) .. "): they will be summoned anyway")
	T.clean(w)
end)

test("r33 AUD-80: nvm summon cancels, no summon does not queue, summon here still asks", function()
	local w, dru = raid()
	local DD = dru.W.Drive
	ok(DD.RaidAdd("Raider Ra"), "Ra queued")
	w:advance(2)
	w:botWhisper("Raider Ra", dru, "nvm summon")
	w:advance(2)
	ok(not DD.raidRows[key("Raider Ra")], "nvm summon drops Ra")
	w:botWhisper("Raider Rc", dru, "no summon")
	w:advance(2)
	ok(not DD.raidRows[key("Raider Rc")], "no summon does not queue Rc")
	w:botWhisper("Raider Rd", dru, "summon here")
	w:advance(2)
	ok(DD.raidRows[key("Raider Rd")], "summon here still queues Rd")
	eq(DD.RaidWords("summon here"), "request")
	eq(DD.RaidWords("cancel summon"), "cancel")
	-- (lead) a "no" about something else does not cancel a request; "no" before the summon word does
	eq(DD.RaidWords("need a summon, no flying"), "request")
	eq(DD.RaidWords("summon pls no mount"), "request")
	eq(DD.RaidWords("no summon needed"), "cancel")
	eq(DD.RaidWords("no sum"), "cancel")
	eq(DD.RaidWords("no"), "cancel")
	eq(DD.RaidWords("walking, no summon"), "cancel")
	T.clean(w)
end)
