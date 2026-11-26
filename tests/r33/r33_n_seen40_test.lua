local T = ...
local test, eq, ok, H = T.test, T.eq, T.ok, T.H

local function qTo(w, r, name)
	local n = 0
	for _, e in ipairs(w:messages("Q", r.player.name, "WHISPER")) do
		if H.key(e.target) == H.key(name) then n = n + 1 end
	end
	return n
end

local function nameFor(i)
	local a, b = i % 26, math.floor(i / 26)
	return "Seen " .. string.char(65 + a) .. "ab" .. string.char(97 + b) .. string.char(97 + a)
end

test("r33 AUD-35: a past driver, named in a K, is never asked once 40 others are known", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	local stamp = r.env.time()
	-- 50 drivers heard lately (they fill the 40 slots) and one driver only in the trip history
	for i = 1, 50 do
		local nm = nameFor(i)
		W.db.seenDrivers[H.key(nm)] = { name = nm, addr = nm, at = stamp - i * 60 }
	end
	W.db.rides[#W.db.rides + 1] = { dest = "Undercity", driver = "Old Trip", driverKey = "old trip", price = 5000, at = stamp - 3 * 86400, saved = 600 }
	local list = W.KnownDrivers()
	eq(#list, 40, "control: at most 40 known drivers are kept")
	-- a peer's K names two drivers: the trip driver and a brand new name
	w:inject("Gossip Pal", W.Encode("K", "Old Trip", "Fresh Name"), "WHISPER", r)
	w:advance(0.1)
	ok(W.fallback.unconfirmed["fresh name"], "control: the new name is queued to be asked")
	ok(W.fallback.unconfirmed["old trip"], "Old Trip is queued from the gossip")
	local fresh, old
	for _, e in ipairs(W.KnownDrivers()) do
		if e.key == "fresh name" then fresh = e end
		if e.key == "old trip" then old = e end
	end
	ok(fresh and fresh.unconfirmed, "control: Fresh Name is on the list of names to whisper")
	ok(old, "Old Trip was named live by a peer but is not on the list of names to whisper, so he is never asked")
	w:advance(15)
	ok(qTo(w, r, "Fresh Name") > 0, "control: Fresh Name got a Q")
	ok(qTo(w, r, "Old Trip") > 0, "Old Trip was never whispered a Q")
	T.clean(w)
end)

test("r33 AUD-36: a driver seen before (past slot 40) who adverts [Wuber] now is never asked", function()
	local w = T.newWorld()
	local r = T.rider(w, T.TESTCHAR, { spot = "Orgrimmar" })
	T.settle(w)
	local W = r.W
	local stamp = r.env.time()
	local oldest
	for i = 1, 55 do
		local nm = nameFor(i)
		W.db.seenDrivers[H.key(nm)] = { name = nm, addr = nm, at = stamp - i * 60 }
		oldest = nm
	end
	eq(#W.KnownDrivers(), 40, "control: 40 known drivers at most")
	local listed = false
	for _, e in ipairs(W.KnownDrivers()) do if e.key == H.key(oldest) then listed = true end end
	ok(not listed, "setup: the oldest seen driver is past slot 40")
	-- a stranger's [Wuber] line gets a Q (control) and so should the old driver's
	w:addBot("Fresh Lock", { spot = "Orgrimmar" })
	w:addBot(oldest, { spot = "Orgrimmar" })
	w:chatFrom("Fresh Lock", "[Wuber] Summons to Ratchet 50s - I'm a Wuber driver", "CHANNEL", "Trade")
	w:chatFrom(oldest, "[Wuber] Summons to Ratchet 50s - I'm a Wuber driver", "CHANNEL", "Trade")
	w:advance(10)
	ok(qTo(w, r, "Fresh Lock") > 0, "control: the new advertiser was whispered a Q")
	ok(qTo(w, r, oldest) > 0, oldest .. " advertised [Wuber] in Trade just now but was never whispered a Q")
	T.clean(w)
end)
