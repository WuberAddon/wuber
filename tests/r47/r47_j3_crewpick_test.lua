local T = ...
-- AUD-194 (Google C59r-2): ticking a Warlock with Wuber who is already in the captain's crew sent a
-- crew card his window drops (it is already in that crew), so he never became a summoner. Now the
-- tick (Pick summoners, and DR.RaidPick) makes him a summoner at once.
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list

local DRU, LEA, CAL = "Dru Oak", "Lea Dorn", T.CAL
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- Dru runs raid summons; Cal is a Warlock with Wuber who is already in Dru's crew (he joined Dru's crew
-- earlier, e.g. while Dru was selling summons: crew membership does not make him a summoner).
local function setup()
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = "Blackrock Mountain", class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = "Blackrock Mountain", class = "DRUID" })
	local cal = w:addClient(CAL, { spot = "Blackrock Mountain", class = "WARLOCK" })
	local names = { LEA, DRU, CAL }
	for i = 1, 5 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	return w, dru, cal
end

test("r47 j3: control: ticking a Warlock who is NOT yet in the crew sends the card and he joins the summoners", function()
	local w, dru, cal = setup()
	local DD = dru.W.Drive
	ok(DD.SetMode("raid"))
	T.openDrive(dru)
	dru.W.Driver.ShowSheet("raidpick") w:advance(1)
	local s = dru.W.UI.drive.screens.raidpick
	local row
	for _, r in ipairs(s.rows.list) do if r:IsShown() and r.p and r.p.key == key(CAL) then row = r end end
	ok(row, "control: Cal is listed in Pick summoners")
	dru:clickOn(row.toggle) w:advance(2)
	ok(cal.W.Drive.pendingOffers[key(DRU)], "control: Cal got a card to say yes")
	cal.W.Drive.AnswerOffer(DRU, true) w:advance(3)
	local found
	for _, k in ipairs(DD.Summoners()) do if k == key(CAL) then found = true end end
	ok(found, "control: Cal now summons for Dru")
	T.clean(w)
end)

test("r47 j3: a Warlock already in the captain's crew is ticked in Pick summoners: he never gets a card and never summons", function()
	local w, dru, cal = setup()
	local DD = dru.W.Drive
	ok(DD.SetMode("raid"))
	ok(DD.OfferCrew(CAL)) w:advance(2)
	cal.W.Drive.AnswerOffer(DRU, true) w:advance(3)
	ok(DD.CrewEntry(key(CAL)), "control: Cal is in Dru's crew")
	eq(cal.W.Drive.CaptainKey(), key(DRU), "control: Cal's captain is Dru")
	DD.RemoveSummoner(CAL) w:advance(1) -- the runner took Cal off the summoners (crew membership stays)
	ok(DD.CrewEntry(key(CAL)), "control: Cal is still in the crew")
	eq(#DD.Summoners(), 0, "control: nobody is picked to summon yet")
	T.openDrive(dru)
	dru.W.Driver.ShowSheet("raidpick") w:advance(1)
	local s = dru.W.UI.drive.screens.raidpick
	local row
	for _, r in ipairs(s.rows.list) do if r:IsShown() and r.p and r.p.key == key(CAL) then row = r end end
	ok(row, "control: Cal is listed")
	dru:clickOn(row.toggle) w:advance(2)
	local sub = row.sub:GetText() or ""
	local found
	for _, k in ipairs(DD.Summoners()) do if k == key(CAL) then found = true end end
	ok(found, "Dru ticked Cal (a Warlock already in the crew); Cal sees no card (" .. tostring(cal.W.Drive.pendingOffers[key(DRU)]) ..
		") and Dru's row stays '" .. sub .. "', Cal is never one of the summoners")
	T.clean(w)
end)
test("r47 j3: DR.RaidPick on a Warlock already in the crew makes him a summoner with no card", function()
	local w, dru, cal = setup()
	local DD = dru.W.Drive
	ok(DD.SetMode("raid"))
	ok(DD.OfferCrew(CAL)) w:advance(2)
	cal.W.Drive.AnswerOffer(DRU, true) w:advance(3)
	DD.RemoveSummoner(CAL) w:advance(1)
	eq(#DD.Summoners(), 0, "control: nobody is picked to summon yet")
	ok(DD.RaidPick(CAL, true), "the pick works")
	w:advance(2)
	local found
	for _, k in ipairs(DD.Summoners()) do if k == key(CAL) then found = true end end
	ok(found, "Cal summons for Dru")
	eq(cal.W.Drive.pendingOffers[key(DRU)], nil, "no card for a crew member")
	ok(DD.CrewEntry(key(CAL)), "Cal is still in the crew")
	T.clean(w)
end)
