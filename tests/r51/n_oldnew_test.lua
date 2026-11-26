-- r51 N (REL-4): old and new together. 2.3.2 players and 2.4.2 players share the channel from the first hour of the
-- release, so a 2.3.2 rider books a 2.4.2 driver, and a 2.4.2 rider a 2.3.2 driver, through to paid, with no Lua error on
-- either side (W.PROTO is 1 on both; fields were only added at the end, Net/Base.lua). 2.3.2's code is read from env
-- WUBER_232_DIR (no default). No such folder (a fresh clone on another PC): pending with that
-- reason, never a silent pass. The unchanged neighbouring path (two 2.4.2 clients) is the whole suite, and the third
-- test here. Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local ANITA, TESTCHAR = T.ANITA or "Anita Lift", T.TESTCHAR or "Wuber TestCharacter"
local OLD_DIR = (os.getenv("WUBER_232_DIR") or "rel232/Wuber"):gsub("\\", "/"):gsub("/$", "")
local HAVE_OLD = H.exists(OLD_DIR .. "/Wuber.toc")
local OLD = { Wuber = OLD_DIR }

local function stages(w, from)
	local out = {}
	for _, m in ipairs(w:messages("S", from)) do out[#out + 1] = tostring(m.text or m[1] or m) end
	return table.concat(out, " ")
end

-- one client's version, and nothing skipped while it loaded
local function loaded(c, want)
	ok(c.W, c.player.name .. ": Wuber loaded")
	ok(not c.skipped or #c.skipped == 0, c.player.name .. ": files skipped while loading: " .. table.concat(c.skipped or {}, ", "))
	if want then eq(c.W.VERSION, want, c.player.name .. "'s Wuber version") end
end

-- a whole ride: book, invite, summon, land, trade the fare; the rider ends done and the driver sends S paid
local function wholeRide(oldRider, oldDriver)
	local w = T.newWorld()
	local d = T.driver(w, ANITA, { addonDirs = oldDriver and OLD or nil })
	local r = T.rider(w, TESTCHAR, { addonDirs = oldRider and OLD or nil })
	T.settle(w)
	loaded(d, oldDriver and "2.3.2" or nil)
	loaded(r, oldRider and "2.3.2" or nil)
	ok(d.W.PROTO == 1 and r.W.PROTO == 1, "W.PROTO is 1 on both sides")
	r.W.db.autoAccept = false
	T.goOnline(d)
	w:advance(2)
	local seen = r.W.drivers["anita lift"]
	ok(seen, "the rider lists the driver")
	eq(seen and seen.price, 5000, "the driver's price reads right across versions")
	ok(r.W.RequestRide("anita lift"), "the ride is asked for")
	w:advance(1)
	T.take(d)
	w:advance(1)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	r:clickText("Accept invite")
	w:advance(1)
	ok(r.W.RIDE_RANK[T.rideState(r)] and r.W.RIDE_RANK[T.rideState(r)] >= 2, "invited: " .. tostring(T.rideState(r)))
	w:summon(d, TESTCHAR)
	w:advance(1)
	r:clickText("Accept summon")
	w:advance(4)
	w:openTrade(d, r)
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(2)
	eq(T.rideState(r), "done", "the rider's ride ends done (paid)")
	ok(stages(w, ANITA):find("paid", 1, true), "the driver sent S paid: " .. stages(w, ANITA))
	eq(#w:messages("DROP", ANITA), 0, "no DROP")
	w:advance(5)
	T.clean(w) -- no Lua error, no W.lastError, no violation on either side
end

if not HAVE_OLD then
	T.pending("r51 n: a 2.3.2 rider books a 2.4.2 driver through to paid",
		"no 2.3.2 code at " .. OLD_DIR .. " (set WUBER_232_DIR to an unpacked Wuber 2.3.2 folder)")
	T.pending("r51 n: a 2.4.2 rider books a 2.3.2 driver through to paid",
		"no 2.3.2 code at " .. OLD_DIR .. " (set WUBER_232_DIR to an unpacked Wuber 2.3.2 folder)")
else
	-- guard: release path, 2.3.2 riders meet 2.4.2 drivers from the first hour
	test("r51 n: a 2.3.2 rider books a 2.4.2 driver through to paid", function()
		wholeRide(true, false)
	end)

	-- guard: release path, 2.4.2 riders meet 2.3.2 drivers from the first hour
	test("r51 n: a 2.4.2 rider books a 2.3.2 driver through to paid", function()
		wholeRide(false, true)
	end)
end

-- guard: release path, the unchanged neighbouring path (two 2.4.2 clients) through the same steps
test("r51 n: control: a 2.4.2 rider books a 2.4.2 driver through to paid", function()
	wholeRide(false, false)
end)
