-- Tests of Drive.Raid (raid summons engine). Loaded by tests/run.lua with its helper table T.
-- Round 17 (BRIEF17 C2): a raider's own window (not crew) follows the runner's queue as a mirror:
-- it is never told "Click the summoning portal" (that alert is for the crew's windows), and a
-- mirrored queue is forgotten when the player leaves the group.
local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list

local DRU, LEA, CAL, BEA = "Dru Oak", "Lea Dorn", T.CAL, T.BEA
local RAY = "Ray Ash"
local RAIDSPOT = "Blackrock Mountain"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function DRof(c) return c.W.Drive end

test("drive.raid: contract (registered, deps, header, public names)", function()
	local W, w, r, Mod = T.contract("Drive.Raid", "tests/drive/raid_test.lua", {
		["DR.raidRows"] = "table", ["DR.RaidApply"] = "function", ["DR.RaidMirror"] = "function",
		["DR.RaidHere"] = "function", ["DR.RaidTick"] = "function", ["DR.NotHere"] = "function",
	})
	ok(Mod, "W.Mod(\"Drive.Raid\")")
	T.clean(w)
end)

-- A raid at Blackrock: Dru (Druid, assist) runs raid summons, Cal (Warlock, Wuber) summons; Ray
-- (a rider with Wuber, not crew) and Raider Ra-Rd wait in Orgrimmar. Ray's window mirrors the queue.
local function raidWithRay()
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
	local ray = T.rider(w, RAY, { spot = "Orgrimmar" })
	w:group(names) -- eight: a raid
	w:setAssist(DRU, true)
	T.settle(w)
	local DD = DRof(dru)
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick(CAL, true))
	w:advance(1)
	cal.W.Drive.AnswerOffer(DRU, true)
	w:advance(3)
	ok(DD.SetOpen(true), "Start")
	w:advance(20)
	ok(DRof(ray).RaidHere(), "Ray's window sees raid summons")
	return w, dru, cal, ray
end

local function alertsOf(c)
	local DR, out = DRof(c), {}
	local alert = DR.Alert
	DR.Alert = function(text, kind, ...)
		out[#out + 1] = tostring(text)
		return alert(text, kind, ...)
	end
	return out
end

test("drive.raid: C2 a summon cast tells the crew's windows to click the portal, never a raider's own (mirror) window", function()
	local w, dru, cal, ray = raidWithRay()
	ok(DRof(dru).RaidAdd("Raider Ra"), "Ra queued")
	w:advance(3)
	ok(DRof(ray).raidRows[key("Raider Ra")], "Ray's window mirrors the queue")
	local rayAlerts, druAlerts = alertsOf(ray), alertsOf(dru)
	DRof(cal).Do("CAST", "Raider Ra")
	w:advance(2)
	eq(DRof(ray).raidRows[key("Raider Ra")].state, "summoning", "the mirror follows the claim")
	ok(not list(rayAlerts):find("Click the summoning portal", 1, true), "Ray is not told to click: " .. list(rayAlerts))
	ok(list(druAlerts):find("Click the summoning portal", 1, true), "the runner at the spot is: " .. list(druAlerts))
	T.clean(w)
end)

test("drive.raid: C2 leaving the group forgets a mirrored raid queue (no stale rows in the next raid); GROUP_LEFT while still in a group keeps it", function()
	local w, dru, cal, ray = raidWithRay()
	ok(DRof(ray).RaidAsk(), "Ray asks for a summon")
	ok(DRof(dru).RaidAdd("Raider Ra"), "Ra queued")
	w:advance(3)
	local DR = DRof(ray)
	ok(DR.raidRows[key(RAY)], "Ray's own row is mirrored")
	ok(DR.raidRows[key("Raider Ra")], "and Ra's")
	-- GROUP_LEFT from an instance group (a battleground) while still in the home raid: rows kept
	ok(ray.W.InGroup(), "Ray is still in the raid")
	ray:fire("GROUP_LEFT")
	w:advance(1)
	ok(DR.raidRows[key(RAY)] and DR.raidRows[key("Raider Ra")], "still in a group: the mirrored rows stay")
	w:leave(RAY)
	w:advance(2)
	eq(next(DR.raidRows), nil, "no raid rows left after leaving: " .. list((function()
		local ks = {}
		for k in pairs(DR.raidRows) do ks[#ks + 1] = k end
		return ks
	end)()))
	eq(DR.RaidHere(), nil, "no raid card")
	-- the runner's own window keeps its queue (it still runs raid summons)
	ok(DRof(dru).raidRows[key("Raider Ra")], "Dru's queue keeps Ra")
	T.clean(w)
end)
