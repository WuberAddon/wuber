-- Group K of r51 (SEC-M5): a group member outside the crew says "raid summons run" in its own HI
-- (field 12 = "R") and then sends raid facts (RA, RD, RT, CAST, END). Promise: only the runner and the
-- crew's own windows put a raider in the raid queue or take one out; a raider's own window still mirrors
-- the real runner's queue (display only).
local T = ...
local test = T.test
local H, eq, ok = T.H, T.eq, T.ok

local DRU, LEA, CAL, RAY, ZED = "Dru Oak", "Lea Dorn", T.CAL, "Ray Ash", "Zed Fox"
local RAIDSPOT = "Blackrock Mountain"
local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end

-- Lea (a bot) leads, Dru (assist) runs raid summons, Cal (Warlock) summons; Raider Ra-Rd wait in
-- Orgrimmar; Ray mirrors the queue; Zed (Wuber, not crew) is the stranger.
local function raidWorld()
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = RAIDSPOT, class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = RAIDSPOT, class = "DRUID" })
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK" })
	local names = { LEA, DRU, CAL, RAY, ZED }
	for i = 1, 4 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	local ray = T.rider(w, RAY, { spot = "Orgrimmar" })
	local zed = T.rider(w, ZED, { spot = "Orgrimmar" })
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
	return w, dru, cal, ray, zed
end

local function queueOf(c)
	local out = {}
	for _, row in ipairs(c.W.Drive.RaidQueue()) do
		out[#out + 1] = row.key .. ":" .. tostring(row.state) .. ":" .. tostring(row.claimedBy or "-")
	end
	return table.concat(out, ",")
end

local function say(c, text) c.env.C_ChatInfo.SendAddonMessage("WUBERT", text, "RAID") end

local function strangerSpeaks(step)
	local w, dru, cal, ray, zed = raidWorld()
	ok(dru.W.Drive.RaidAdd("Raider Ra"), "Ra queued")
	w:advance(1)
	ok(dru.W.Drive.RaidAdd("Raider Rb"), "Rb queued")
	w:advance(3)
	local before = queueOf(dru)
	eq(queueOf(cal), before, "the crew windows agree before the stranger speaks")
	ok(not zed.W.Drive.TrustKey(key(DRU)) and not dru.W.Drive.TrustKey(key(ZED)), "Zed is not crew")
	say(zed, "HI~1~" .. tostring(zed.W.VERSION) .. "~-1~0~0~0~H~MAGE~~~R")
	for _ = 1, math.ceil(4 / step) do w:advance(step) end
	say(zed, "RA~1~Raider Rd")
	say(zed, "RA~1~" .. ZED)
	say(zed, "RD~1~Raider Ra~hand")
	say(zed, "RT~1~Raider Rb")
	say(zed, "CAST~1~Raider Rb~" .. CAL .. "~s")
	say(zed, "END~1~Raider Rb~1~" .. CAL)
	for _ = 1, math.ceil(10 / step) do w:advance(step) end
	eq(queueOf(dru), before, "the runner's queue did not change")
	eq(queueOf(cal), before, "the crew Warlock's queue did not change")
	for _, c in ipairs({ dru, cal }) do
		ok(not c.W.Drive.raidRows[key("Raider Rd")] and not c.W.Drive.raidRows[key(ZED)], "no row from the stranger")
	end
	T.clean(w)
end

test("r51 K SEC-M5: a stranger's HI \"R\" and raid facts change no crew window's raid queue (step 1 s)", function() strangerSpeaks(1) end)
test("r51 K SEC-M5: a stranger's HI \"R\" and raid facts change no crew window's raid queue (step 5 s)", function() strangerSpeaks(5) end)

-- guard: the crew's own path to the queue was never through the mirror (the runner's + and a crew drop)
test("r51 K SEC-M5 guard: the runner adds and the crew Warlock drops: every crew window and Ray's mirror follow", function()
	local w, dru, cal, ray = raidWorld()
	ok(dru.W.Drive.RaidAdd("Raider Ra"), "Ra queued")
	w:advance(1)
	ok(cal.W.Drive.RaidAdd("Raider Rb"), "Rb asked by the crew Warlock")
	w:advance(4)
	ok(dru.W.Drive.raidRows[key("Raider Rb")] and cal.W.Drive.raidRows[key("Raider Rb")], "Rb listed on both crew windows")
	ok(ray.W.Drive.raidRows[key("Raider Ra")] and ray.W.Drive.raidRows[key("Raider Rb")], "Ray's mirror lists both")
	ok(cal.W.Drive.RaidDrop("Raider Ra"), "Cal drops Ra")
	w:advance(4)
	ok(not dru.W.Drive.raidRows[key("Raider Ra")] and not cal.W.Drive.raidRows[key("Raider Ra")], "Ra gone on both crew windows")
	ok(not ray.W.Drive.raidRows[key("Raider Ra")], "and from Ray's mirror")
	T.clean(w)
end)
