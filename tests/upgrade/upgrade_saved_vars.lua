-- Upgrade tests (F2): saved variables written by OLDER Wuber versions are loaded into the fake game, the
-- player logs in, and the promise is checked: no Lua error, every setting the player had is still set (each one
-- named), new fields get their defaults, and a second login (the upgrade run twice) changes and breaks nothing.
-- The fixtures (tests/fixtures/upgrade/*.lua) are hand-built from those versions' shapes, with neutral names
-- only (no real player data). Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

local function fixture(name)
	local f = assert(loadfile(T.dir .. "/fixtures/upgrade/" .. name))
	local env = {}
	setfenv(f, env)
	f()
	return env.WuberDB
end

local function copy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = copy(x) end
	return out
end

-- every path where two saved tables differ (empty = identical)
local function diff(a, b, path, out)
	out = out or {}
	if type(a) ~= "table" or type(b) ~= "table" then
		if a ~= b then out[#out + 1] = path .. ": " .. tostring(a) .. " -> " .. tostring(b) end
		return out
	end
	for k, v in pairs(a) do diff(v, b[k], path .. "." .. tostring(k), out) end
	for k, v in pairs(b) do if a[k] == nil then diff(nil, v, path .. "." .. tostring(k), out) end end
	return out
end

-- one login: the old data goes in, Wuber runs for a while, the player logs out; returns the world, the saved
-- data as it is after that, and what the addon exposes
local function session(w, saved, class)
	local c = w:addClient(T.TESTCHAR, { spot = "Orgrimmar", class = class or "MAGE", saved = { Wuber = saved }, simple = true, allowMissing = true })
	w:advance(20)
	local W = c.W
	local seen = { db = W.db, scale = W.db and W.db.scale }
	local out = w:logout(c).Wuber
	return out, seen
end

local function noErrors(w, what)
	eq(#w.errors, 0, what .. ": no Lua error (" .. tostring(w.errors[1]) .. ")")
end

-- login twice: the second login must change nothing and break nothing
local function twice(name, class)
	local w = T.newWorld()
	local old = fixture(name)
	local first = session(w, copy(old), class)
	noErrors(w, name .. " first login")
	local snap = copy(first)
	local second = session(w, first, class)
	noErrors(w, name .. " second login")
	local d = diff(snap, second, "WuberDB")
	eq(#d, 0, name .. ": a second login changes nothing (" .. table.concat(d, "; ", 1, math.min(#d, 4)) .. ")")
	return first, old
end

test("upgrade: Wuber 2.2 rider data keeps every setting the player had, and fills the new ones", function()
	local s, old = twice("wuber_22_rider.lua", "MAGE")
	-- the player's own settings, by name
	eq(s.minimapAngle, 90, "minimapAngle")
	eq(s.minimapHidden, true, "minimapHidden")
	eq(s.sound, false, "sound")
	eq(s.mapPins, false, "mapPins")
	eq(s.lastDest, "Undercity", "lastDest")
	eq(s.fx, "light", "fx")
	eq(s.plates, false, "plates")
	eq(s.timeValue, 250000, "timeValue")
	eq(s.coach, true, "coach")
	eq(s.tipsOn, false, "tipsOn")
	eq(s.autoAccept, false, "autoAccept")
	eq(s.autoLeave, false, "autoLeave")
	eq(s.advertOnline, false, "advertOnline")
	eq(s.openMapHint, true, "openMapHint")
	eq(s.reduceMotion, true, "reduceMotion")
	eq(s.favs.driverone, true, "favourite driver")
	eq(s.watch["thunder bluff"], true, "watched destination")
	eq(s.hidden.driverthree, true, "hidden driver")
	eq(s.milestones.first_ride, 1762000000, "earned milestone")
	eq(s.tipsSeen.welcome, true, "tip already seen")
	eq(#s.rides, 3, "all three saved trips")
	eq(s.rides[2].dest, "Thunder Bluff", "trip history intact")
	eq(s.chars["wuber testcharacter"].price, 7500, "driver price of the character")
	eq(s.chars["wuber testcharacter"].service, "Riderone Rides", "service name of the character")
	eq(s.chars["wuber testcharacter"].dest, "Undercity", "driver place of the character")
	eq(s.chars["wuber testcharacter"].paused, true, "paused of the character")
	eq(s.drive.opts.adEvery, 30, "driver option adEvery")
	eq(s.drive.opts.lowShards, 6, "driver option lowShards")
	eq(s.drive.opts.whisperMode, "macro", "driver option whisperMode")
	eq(s.drive.opts.maxGroup, 12, "driver option maxGroup")
	eq(s.drive.stats.rides, 12, "driver lifetime rides")
	eq(s.flights["H|undercity|tarren mill"].c, 1500, "a saved flight price")
	-- the migrations that are meant to happen
	eq(s.scale, 1.15, "the old usual size 1.0 becomes 1.15 (once)")
	eq(s.scaleV, 2, "scale migration marked")
	eq(s.flights["H|orgrimmar|ratchet"].tsrc, "own", "Enhanced Flight Map time kept, as own")
	eq(s.flights["H|orgrimmar|ratchet"].t, 260, "the seconds of that flight kept")
	eq(s.flightsV, 3, "flight migration marked")
	eq(s.drive.opts.autoPublic, false, "public-invite switch is off after 2.3.2 (documented one-time reset)")
	eq(s.drive.publicV, 1, "public switch migration marked")
	-- new fields get their defaults
	eq(s.advanced, false, "Simple mode is the start")
	eq(s.simpleNote, true, "an older player is told once")
	eq(s.progressReady, true, "progress marked ready")
	eq(s.totals.rides, 2, "lifetime totals built from the trips (the unpaid one counts for nothing)")
	eq(s.totals.spent, 8000, "lifetime spent")
	eq(s.drive.opts.autoReply, true, "new driver option autoReply defaults on")
	eq(s.drive.opts.raidsum, true, "new driver option raidsum defaults on")
	eq(s.drive.opts.inviteCap, 8, "new driver option inviteCap defaults")
	eq(type(s.drive.button), "table", "driver button block created")
	eq(old.advanced, nil, "(fixture really lacks the new field)")
end)

test("upgrade: Wuber 2.3.1 driver data keeps every option the driver had, and new options get defaults", function()
	local s = twice("wuber_231_driver.lua", "WARLOCK")
	eq(s.advanced, true, "Advanced mode kept")
	eq(s.simpleNote, nil, "no 'now Simple' note for a player who chose")
	eq(s.scale, 1.4, "scale (not 1.0, so untouched)")
	eq(s.fx, "off", "fx")
	eq(s.timeValue, 40000, "timeValue")
	eq(s.favs.riderone, true, "favourite")
	eq(#s.rides, 1, "trip history")
	eq(s.totals.rides, 1, "totals kept, not rebuilt twice")
	eq(s.totals.spent, 9000, "totals spent")
	eq(s.flights["H|orgrimmar|ratchet"].t, 250, "flight time")
	local ch = s.chars["wuber testcharacter"]
	eq(ch.price, 12000, "character price")
	eq(ch.service, "Driverone Lifts", "character service")
	eq(ch.dest, "Stormwind", "character place")
	eq(ch.destWords, "sw, stormy", "character 'also called'")
	eq(ch.caster, "Drivertwo", "character caster")
	eq(ch.wizard, true, "crew wizard marked finished")
	local o = s.drive.opts
	eq(o.watchPublic, false, "watchPublic")
	eq(o.autoInvite, false, "autoInvite")
	eq(o.adEvery, 45, "adEvery")
	eq(o.lowShards, 8, "lowShards")
	eq(o.inviteCap, 5, "inviteCap")
	eq(o.adChannels, "trade", "adChannels")
	eq(o.helpSeen, "ab", "helpSeen")
	eq(o.autoPublic, false, "public invites reset by the 2.3.2 migration")
	eq(o.autoReply, true, "new option autoReply defaults on")
	eq(o.raidsum, true, "new option raidsum defaults on")
	eq(o.awayGuard, true, "new option awayGuard defaults on")
	eq(s.drive.blocklist.pestone.name, "Pestone", "block list entry")
	eq(s.drive.stats.rides, 40, "driver lifetime rides")
	eq(s.drive.bell.service, "Driverone Lifts", "bell service")
	eq(s.drive.button.locked, true, "button locked")
	eq(s.drive.button.scale, 1.3, "button scale")
end)

-- guard: the one-time reset must not take away a choice the player made after the warning
test("upgrade: a player who chose public invites after the warning keeps them through the upgrade", function()
	local old = fixture("wuber_231_driver.lua")
	old.drive.publicChosen = true
	local w = T.newWorld()
	local first = session(w, old, "WARLOCK")
	eq(first.drive.opts.autoPublic, true, "autoPublic stays on when the player chose it")
	local second = session(w, first, "WARLOCK")
	eq(second.drive.opts.autoPublic, true, "and on the second login")
	noErrors(w, "chosen")
end)

-- guard: broken or empty saved data must still load, twice
test("upgrade: an empty or half-broken saved table starts cleanly and twice", function()
	for _, bad in ipairs({ {}, { rides = "x", favs = 5, chars = false, fx = "weird", timeValue = "NaN", scale = "big", drive = 3, flights = "x" } }) do
		local w = T.newWorld()
		local first = session(w, copy(bad), "MAGE")
		noErrors(w, "broken data")
		local snap = copy(first)
		local second = session(w, first, "MAGE")
		noErrors(w, "broken data again")
		eq(#diff(snap, second, "WuberDB"), 0, "broken data: second login changes nothing")
		eq(first.fx, "full", "fx back to the default")
		eq(type(first.rides), "table", "rides is a table")
	end
end)
