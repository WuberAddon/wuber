-- Round 33 group l5 (REV-r32-1): a raid row left 'waiting' with no end time (after a reload or crew sync) goes back to queued after the wait, like the selling list (AUD-19).
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

test("r33 l5: REV-r32-1: a raid row waiting with no end time goes back to queued after the wait", function()
	local w, DD, DC, DY = raid()
	ok(DD.RaidAdd("Raider Ra"), "Ra queued")
	w:advance(3)
	local row = DD.raidRows[key("Raider Ra")]
	ok(row, "Ra is listed")
	row.state, row.endAt, row.claimedBy = "waiting", nil, nil
	row.fails = row.fails or 0
	w:advance(300)
	local r2 = DD.raidRows[key("Raider Ra")]
	ok(not r2 or r2.state ~= "waiting", "300 s on, Ra's row must not still say waiting (state " .. tostring(r2 and r2.state) .. ")")
end)
