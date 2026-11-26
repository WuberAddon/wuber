local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok
local ANITA = T.ANITA or "Anita Lift"

local function scene6()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK", allowMissing = true })
	local DR = a.W.Drive
	DR.opts().adEvery = 1
	DR.opts().adChannels = "trade"
	local n = { advert = 0 }
	local real = DR.Alert
	DR.Alert = function(text, kind, ...)
		if kind == "advert" then n.advert = n.advert + 1 end
		return real(text, kind, ...)
	end
	T.settle(w)
	return w, a, DR, n
end

test("r33 n2 AUD-78: control, an open driver whose advert is due is reminded once", function()
	local w, a, DR, n = scene6()
	ok(DR.SetOpen(true), "opens")
	w:advance(120)
	ok(DR.AdvertDue(), "an advert is due")
	ok(n.advert >= 1, "the reminder fired, reminders: " .. n.advert)
	T.clean(w)
end)

test("r33 n2 AUD-78: after a reminder, closing and reopening a later shift never reminds again", function()
	local w, a, DR, n = scene6()
	ok(DR.SetOpen(true), "opens")
	w:advance(120)
	local first = n.advert
	ok(first >= 1, "the first reminder fired")
	DR.SetOpen(false)
	w:advance(3600) -- the shift ends; an hour later
	DR.SetOpen(true)
	w:advance(120)
	ok(DR.AdvertDue(), "an advert is due again in the new shift")
	ok(n.advert > first, "the driver reopened an hour later, nothing was advertised since, but no 'Time to advertise' reminder fired in the new shift (reminders: " .. n.advert .. ", adReminded still " .. tostring(DR.adReminded) .. ")")
	T.clean(w)
end)


local function scene7()
	local w = T.newWorld()
	local a = w:addClient(ANITA, { spot = "Orgrimmar", class = "WARLOCK", allowMissing = true, shards = 5 })
	local DR = a.W.Drive
	local n = { shards = 0 }
	local real = DR.Alert
	DR.Alert = function(text, kind, ...)
		if kind == "shards" then n.shards = n.shards + 1 end
		return real(text, kind, ...)
	end
	T.settle(w)
	DR.SetOpen(true)
	w:advance(3)
	local function setShards(k)
		w:player(ANITA).shards = k
		a:fire("BAG_UPDATE_DELAYED")
		w:advance(1)
	end
	return w, a, DR, n, setShards
end

test("r33 n2 AUD-79: control, the low-shard warning fires when shards fall to 3", function()
	local w, a, DR, n, setShards = scene7()
	eq(DR.Shards(), 5)
	setShards(4) setShards(3)
	eq(n.shards, 1, "one warning at 3 shards")
	T.clean(w)
end)

test("r33 n2 AUD-79: 3 shards (warned), Drain Soul to 4, a summon back to 3: no second warning", function()
	local w, a, DR, n, setShards = scene7()
	setShards(4) setShards(3)
	eq(n.shards, 1, "one warning at 3 shards")
	setShards(4) -- Drain Soul makes one
	setShards(3) -- the next summon spends it
	eq(n.shards, 2, "the Warlock is back at 3 Soul Shards (the low-shard line) but got no second warning (warnings so far: " .. n.shards .. ")")
	T.clean(w)
end)
