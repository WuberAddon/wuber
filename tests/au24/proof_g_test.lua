-- Proof tests of job 2620 (audit-241), area G: Raid, team, service, driver console, FX.
local T = ...
local test = T.test
local H, eq, ok = T.H, T.eq, T.ok
-- r50 (job 2609): these bugs are fixed in 2.4.1; their proofs now run as normal tests
local FIXED = { ["AU24-01"] = true, ["AU24-02"] = true, ["AU24-03"] = true, ["AU24-06"] = true, ["AU24-09"] = true, ["AU24-10"] = true, ["AU24-12"] = true, ["AU24-13"] = true, ["AU24-15"] = true, ["AU24-17"] = true, ["AU24-18"] = true, ["AU24-19"] = true, ["AU24-20"] = true, ["AU24-21"] = true, ["AU24-22"] = true, ["AU24-26"] = true, ["AU24-27"] = true, ["AU24-28"] = true, ["AU24-29"] = true, ["AU24-31"] = true, ["AU24-33"] = true, ["AU24-34"] = true, ["AU24-35"] = true }
local function proof(id, name, fn)
	if os.getenv("WUBER_AU24_PROOF") or FIXED[id] then
		test(id .. ": " .. name, fn)
	else
		test(id .. " (expected fail until fixed): " .. name, function()
			local okp = pcall(fn)
			assert(not okp, id .. " now passes: the bug looks fixed; make this a normal test")
		end)
	end
end


---------------------------------------------------------------------------
-- A raid at Blackrock (as tests/drive/raid_test.lua): Dru runs raid summons, Cal (Warlock, Wuber) is a summoner.
local DRU, LEA, CAL, RAY = "Dru Oak", "Lea Dorn", T.CAL, "Ray Ash"
local RAIDSPOT = "Blackrock Mountain"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
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
		bea = w:addClient(second, { spot = RAIDSPOT, class = "WARLOCK" })
		names[#names + 1] = second
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
		ok(DD.RaidPick(second, true))
		w:advance(1)
		bea.W.Drive.AnswerOffer(DRU, true)
		w:advance(3)
	end
	ok(DD.SetOpen(true), "Start")
	w:advance(20)
	return w, dru, cal, ray, bea
end

-- AU24-21: Add anyway on the Crew screen toasts "X added as a helper" although the crew is full and X was not added.
proof("AU24-21", "a full crew (8 beside the captain) never toasts that a ninth person was added as a helper", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	local extra = "Ninth Guy"
	w:addBot(extra, { spot = "Undercity", class = "WARRIOR" })
	w:group({ T.ANITA, extra })
	w:advance(15)
	local W = a.W
	local DR = W.Drive
	T.openDrive(a)
	for i = 1, DR.CREW_MAX do
		ok(DR.AddPlainHelper("Helper " .. string.char(96 + i) .. "x", nil), "helper " .. i .. " fits")
	end
	eq(#DR.char().crew, DR.CREW_MAX, "the crew is full")
	local key = W.Key(extra)
	DR.offers[key] = { name = extra, at = a.env.GetTime(), state = "noapp" }
	local seen = {}
	local orig = W.UI.Toast
	W.UI.Toast = function(text, kind, onClick)
		seen[#seen + 1] = tostring(text)
		return orig(text, kind, onClick)
	end
	W.Driver.ShowScreen("crew")
	w:advance(1)
	local s = W.Mod("UI.Driver.Screens").st.screens.crew
	s.update()
	local row
	for i = 1, 12 do
		local r = s.others.get(i)
		if r and H.visible(r) and r.person and W.Key(r.person.name) == key then row = r break end
	end
	ok(row and row.anyway, "the ninth person shows with an Add anyway button")
	ok(a:scrollIntoView(row.btn), "the player scrolls the Add anyway button into view")
	a:clickOn(row.btn)
	w:advance(1)
	local inCrew = false
	for _, m in ipairs(DR.char().crew) do if W.Key(m.name) == key then inCrew = true end end
	local said = false
	for _, t in ipairs(seen) do if t:find("added as a helper", 1, true) then said = t end end
	ok(inCrew or not said, "toast said '" .. tostring(said) .. "' but the crew (" .. #DR.char().crew .. ") does not hold " .. extra)
	T.clean(w)
end)

-- AU24-21b: the same click in the set-up wizard's "Pick your crew" step (Wizard.lua).
proof("AU24-21", "the wizard's Add anyway never toasts that a ninth person was added when the crew is full", function()
	local w = T.newWorld()
	local a = T.driver(w, T.ANITA, { spot = "Undercity" })
	local extra = "Ninth Guy"
	w:addBot(extra, { spot = "Undercity", class = "WARRIOR" })
	w:group({ T.ANITA, extra })
	w:advance(15)
	local W = a.W
	local DR = W.Drive
	T.openDrive(a)
	for i = 1, DR.CREW_MAX do DR.AddPlainHelper("Helper " .. string.char(96 + i) .. "x", nil) end
	local key = W.Key(extra)
	DR.offers[key] = { name = extra, at = a.env.GetTime(), state = "noapp" }
	local seen = {}
	local orig = W.UI.Toast
	W.UI.Toast = function(text, kind, onClick) seen[#seen + 1] = tostring(text) return orig(text, kind, onClick) end
	W.Driver.ShowScreen("wizard")
	w:advance(1)
	local wz = W.Mod("UI.Driver.Screens").st.wizard
	wz.choice = "friends"
	wz.step = 2
	wz.paint()
	w:advance(1)
	local row
	for _, r in ipairs(wz.people.list) do
		if H.visible(r) and r.person and W.Key(r.person.name) == key then row = r end
	end
	ok(row and row.anyway, "the ninth person shows with Add anyway")
	row.btn:GetScript("OnClick")(row.btn)
	w:advance(1)
	local inCrew = false
	for _, m in ipairs(DR.char().crew) do if W.Key(m.name) == key then inCrew = true end end
	local said
	for _, t in ipairs(seen) do if t:find("added as a helper", 1, true) then said = t end end
	ok(inCrew or not said, "toast said '" .. tostring(said) .. "' but the crew does not hold " .. extra)
	T.clean(w)
end)

-- AU24-04: a crew Warlock whose window reloads in the middle of raid summons gets no queue.
test("AU24-04: a crew Warlock's window that reloads mid-raid shows the runner's waiting raiders again", function()
	local w, dru, cal = raidWorld()
	ok(dru.W.Drive.RaidAdd("Raider Ra"), "Ra queued on the runner")
	ok(dru.W.Drive.RaidAdd("Raider Rb"), "Rb queued on the runner")
	w:advance(3)
	ok(cal.W.Drive.raidRows[key("Raider Ra")], "before the reload Cal's window lists Ra")
	cal = w:reload(cal)
	w:advance(20)
	ok(dru.W.Drive.raidRows[key("Raider Ra")], "the runner still has Ra queued")
	ok(cal.W.Drive.RaidOn(), "Cal's window knows raid summons run")
	ok(cal.W.Drive.raidRows[key("Raider Ra")] and cal.W.Drive.raidRows[key("Raider Rb")],
		"after the reload Cal's window lists no raiders, though two are waiting on the runner's window")
	T.clean(w)
end)

-- AU24-05: the runner's own reload empties the queue on the runner's window while the crew windows still list the raiders.
test("AU24-05: after the runner reloads mid-raid the runner's window and the crew's windows list the same raiders", function()
	local w, dru, cal = raidWorld()
	ok(dru.W.Drive.RaidAdd("Raider Ra"), "Ra queued")
	w:advance(3)
	ok(cal.W.Drive.raidRows[key("Raider Ra")], "Cal lists Ra")
	dru = w:reload(dru)
	w:advance(20)
	ok(dru.W.Drive.RaidOn(), "raid summons still run on the runner's window")
	local mine = dru.W.Drive.raidRows[key("Raider Ra")] ~= nil
	local crew = cal.W.Drive.raidRows[key("Raider Ra")] ~= nil
	ok(mine and crew, "after the reload the runner's window lists Ra: " .. tostring(mine) .. ", the crew's window lists Ra: " .. tostring(crew))
	T.clean(w)
end)


