local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- Round 32, group B wave 2 (AUD-28, Google C41b-3): a group member whose name reads "Unknown" for a moment
-- (loading screen, party-to-raid) is not gone. The driver's row for them used to be dropped (DRIVE_REMOVED,
-- "left") and rebuilt from scratch when the name came back, losing price, tries and state.

local function joinedRider()
	local w = T.newWorld()
	local d = T.driver(w, "Anita Lift", { spot = "Ratchet" })
	T.goOnline(d) w:advance(5)
	local bot = w:addBot("Ed Rider", { spot = "Ratchet" })
	local DR = d.W.Drive
	local removed = {}
	d.W.On("DRIVE_REMOVED", function(c, why) removed[#removed + 1] = tostring(c and c.key) .. ":" .. tostring(why) end)
	d:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Ed Rider")
	w:advance(5)
	return w, d, bot, DR, removed
end

local function unknownName(d, unitToHide)
	local real = d.env.UnitName
	d.env.UnitName = function(unit)
		if unit == unitToHide then return "Unknown", nil end
		return real(unit)
	end
	return function() d.env.UnitName = real end
end

test("r32 b2: a joined rider whose name reads Unknown for a moment keeps their row", function()
	local w, d, bot, DR, removed = joinedRider()
	local before = DR.customers["ed rider"]
	ok(before, "setup: rider listed")
	ok(DR.Rank(before.state) >= DR.Rank("joined"), "control: rider is in the group (" .. tostring(before.state) .. ")")
	before.tries = 2
	local restore = unknownName(d, "party1")
	d:fire("GROUP_ROSTER_UPDATE")
	w:advance(1)
	ok(DR.customers["ed rider"] == before, "the row stays while the name reads Unknown")
	restore()
	d:fire("GROUP_ROSTER_UPDATE") w:advance(2)
	ok(bot.group, "Ed never left the group")
	ok(DR.customers["ed rider"] == before,
		"the driver's row for Ed was thrown away when his name read Unknown and rebuilt afterwards (now "
		.. tostring(DR.customers["ed rider"] and DR.customers["ed rider"].state) .. ")")
	eq(before.tries, 2, "tries kept")
	eq(#removed, 0, "no DRIVE_REMOVED: " .. table.concat(removed, ", "))
	T.clean(w)
end)

test("r32 b2: a rider who really leaves is still dropped, even if their name read Unknown first", function()
	local w, d, bot, DR, removed = joinedRider()
	ok(DR.customers["ed rider"], "setup: rider listed")
	local restore = unknownName(d, "party1")
	d:fire("GROUP_ROSTER_UPDATE")
	w:advance(1)
	restore()
	w:leave("Ed Rider")
	w:advance(5)
	ok(not DR.customers["ed rider"], "Ed's row is gone once he left")
	T.clean(w)
end)

test("r32 b2: a rider who leaves while another member's name reads Unknown is dropped once names come back", function()
	local w, d, bot, DR, removed = joinedRider()
	local bo = w:addBot("Bo Rider", { spot = "Ratchet" })
	d:chatEvent("CHAT_MSG_WHISPER", "summon pls", "Bo Rider")
	w:advance(5)
	ok(DR.customers["ed rider"] and DR.customers["bo rider"], "setup: both riders listed")
	ok(DR.Rank(DR.customers["bo rider"].state) >= DR.Rank("joined"), "control: Bo is in the group")
	local boUnit
	for i = 1, 4 do if d.W.UnitName("party" .. i) == "Bo Rider" then boUnit = "party" .. i end end
	ok(boUnit, "setup: Bo has a party unit")
	local restore = unknownName(d, boUnit)
	w:leave("Ed Rider")
	w:advance(1)
	ok(DR.customers["bo rider"], "Bo's row stays while his name reads Unknown")
	restore() -- the name comes back with no roster event of its own
	w:advance(10)
	ok(not DR.customers["ed rider"], "Ed's row is gone once the names are back")
	ok(DR.customers["bo rider"], "Bo is still listed")
	T.clean(w)
end)
