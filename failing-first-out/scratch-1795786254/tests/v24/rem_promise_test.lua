-- Wuber 2.4, the Simple/Advanced switch is a promise: switching it back and forth ends nothing, changes no saved value but "advanced", and does nothing to a secure frame in a fight. Loaded by tests/run.lua with its helper table T.
local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- a real ride with the driver, run as far as the stage ("ingroup": waiting for the portal)
local function rideStart(w, d, r)
	local ride = r.W.RequestRide(r.W.Key(d.player.name))
	w:advance(1)
	d.W.AcceptRequest(d.W.incoming[1].id, 5)
	w:advance(2)
	return ride
end

-- the rest of the ride: the summon, the accept, the trade and the payment by trade
local function rideFinish(w, d, r)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	w:summon(d, r.player.name)
	w:advance(1)
	r:clickText("Accept summon")
	w:advance(3)
	w:openTrade(d, r)
	w:advance(0.5)
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(1)
end

-- the plain kind of screen the rider's window is on: the one of the Ride tab's screens that shows
local function screenKind(r)
	local st = r.W.UI.state
	local kinds = {}
	for name, s in pairs(type(st.screens) == "table" and st.screens or {}) do
		local f = type(s) == "table" and (s.frame or s.root or s.holder)
		if type(f) == "table" and f.IsVisible and f:IsVisible() then kinds[#kinds + 1] = name end
	end
	table.sort(kinds)
	return table.concat(kinds, ",")
end

-- a deep copy of a saved table
local function copy(v, seen)
	if type(v) ~= "table" then return v end
	seen = seen or {}
	if seen[v] then return seen[v] end
	local c = {}
	seen[v] = c
	for k, x in pairs(v) do c[k] = copy(x, seen) end
	return c
end

local STAMPS = { at = true, heard = true, last = true, seen = true, ts = true, time = true, stamp = true, lastSeen = true,
	since = true, when = true, updated = true, t = true }

-- every difference between two saved tables, as "path: a -> b" (skip(path): a key not compared; the clock's stamps are told apart by their key names, STAMPS)
local function diff(a, b, path, out, skip)
	if type(a) ~= type(b) then
		out[#out + 1] = path .. ": " .. tostring(a) .. " -> " .. tostring(b)
	elseif type(a) == "table" then
		local keys = {}
		for k in pairs(a) do keys[k] = true end
		for k in pairs(b) do keys[k] = true end
		for k in pairs(keys) do
			local p = path .. "." .. tostring(k)
			if not skip(p) then diff(a[k], b[k], p, out, skip) end
		end
	elseif a ~= b then
		-- a number the clock moves (a time stamp: its key says so) is not a changed setting
		local last = path:match("([^.]*)$")
		if not (type(a) == "number" and type(b) == "number" and STAMPS[last]) then
			out[#out + 1] = path .. ": " .. tostring(a) .. " -> " .. tostring(b)
		end
	end
end

-- the secure frames: shown, and where
local function secureSnap(c)
	local out = {}
	for i, f in ipairs(c:secureButtons()) do
		local p, _, rp, x, y = f:GetPoint(1)
		out[i] = ("%s|%s|%s|%s|%.1f|%.1f|%.1f|%.1f|%s"):format(tostring(f:GetName()), tostring(f:IsShown()), tostring(p), tostring(rp), x or 0, y or 0, f:GetWidth(), f:GetHeight(), tostring(f:GetAttribute("macrotext")))
	end
	return table.concat(out, "\n")
end

test("v24 simple promise: 1 the switch in the middle of a ride: the ride goes on, the same state and screen, and it completes and pays", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA)
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	local ride = rideStart(w, d, r)
	r.W.UI.Toggle(true)
	w:advance(1)
	eq(T.rideState(r), "ingroup", "in the group, waiting for the portal")
	local id, kind = r.W.ride.id, screenKind(r)
	ok(kind ~= "", "a screen shows: " .. kind)
	for i, on in ipairs({ true, false, true, false }) do
		r.W.SetAdvanced(on)
		w:advance(1)
		eq(r.W.Advanced(), on, i .. ": the mode is " .. tostring(on))
		ok(r.W.ride ~= nil, i .. ": the ride goes on")
		eq(r.W.ride.id, id, i .. ": the same ride")
		eq(T.rideState(r), "ingroup", i .. ": the same state")
		eq(screenKind(r), kind, i .. ": the same screen")
		eq(#r:findText("Finding your driver", false, true), 0, i .. ": not back on Finding")
	end
	-- and once more in Advanced during the summon, then Simple for the trade
	r.W.SetAdvanced(true)
	w:advance(0.5)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	w:summon(d, r.player.name)
	w:advance(1)
	r.W.SetAdvanced(false)
	w:advance(0.5)
	eq(r.W.ride and r.W.ride.id, id, "the same ride after the summon")
	r:clickText("Accept summon")
	w:advance(3)
	r.W.SetAdvanced(true)
	w:advance(0.5)
	eq(r.W.ride and r.W.ride.id, id, "the same ride after the accept")
	w:openTrade(d, r)
	w:advance(0.5)
	r.W.SetAdvanced(false)
	w:advance(0.5)
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(1)
	eq(T.rideState(r), "done", "it completes")
	eq(r.W.ride.paid, 5000, "and it pays: 50s")
	ok(ride ~= nil, "the ride was real")
	T.clean(w)
end)

test("v24 simple promise: 2 the switch on an open driver: stays open, the list keeps the rider and its state, the big button says the same", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { simple = true })
	local r = T.rider(w, T.TESTCHAR)
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	local ride = r.W.RequestRide(r.W.Key(d.player.name))
	w:advance(1)
	ok(#d.W.incoming > 0, "the driver has the request")
	d.W.AcceptRequest(d.W.incoming[1].id, 5)
	w:advance(2)
	local DR = d.W.Drive
	ok(DR.IsOpen(), "the driver is open")
	local function list()
		local out = {}
		for _, c in ipairs(DR.Sorted()) do out[#out + 1] = c.key .. "=" .. tostring(c.state) end
		return table.concat(out, ",")
	end
	local function words()
		local p = DR.Plan()
		return tostring(p.title) .. " / " .. tostring(p.sub) .. " / " .. tostring(p.color)
	end
	local listed, big = list(), words()
	ok(listed:find("testchar rider", 1, true) or listed:find(d.W.Key(r.player.name), 1, true), "the rider is in the list: " .. listed)
	T.openDrive(d)
	w:advance(1)
	for i, on in ipairs({ true, false, true, false }) do
		d.W.SetAdvanced(on)
		w:advance(1)
		d.W.Driver.RefreshNow()
		w:advance(0.5)
		ok(DR.IsOpen(), i .. ": still open")
		eq(list(), listed, i .. ": the list keeps the rider, the same state")
		eq(words(), big, i .. ": the big button says the same")
		ok(d.W.Driver.ui and d.W.Driver.ui.console, i .. ": the console is still built")
	end
	ok(ride ~= nil, "the ride was real")
	T.clean(w)
end)

test("v24 simple promise: 3 the switch changes no saved value except advanced", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { simple = true })
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	rideStart(w, d, r)
	r.W.UI.Toggle(true)
	d.W.UI.Toggle(true)
	w:advance(2)
	for _, side in ipairs({ r, d }) do
		local before = copy(side.W.db)
		local keyBefore = copy(side.W.Char())
		for _, on in ipairs({ true, false, true }) do
			side.W.SetAdvanced(on)
			w:advance(0.2)
		end
		side.W.SetAdvanced(false) -- where it began (before had advanced == false)
		w:advance(0.2)
		local out = {}
		diff({ db = before }, { db = copy(side.W.db) }, "", out, function(p) return p == ".db.advanced" end)
		diff({ db = keyBefore }, { db = copy(side.W.Char()) }, "", out, function() return false end)
		eq(table.concat(out, "\n"), "", "no saved value changed (" .. tostring(side.player.name) .. ")")
		eq(side.W.db.advanced, false, "advanced is where it began")
		side.W.SetAdvanced(true)
		eq(side.W.db.advanced, true, "and only that key moves")
		side.W.SetAdvanced(false)
	end
	T.clean(w)
end)

test("v24 simple promise: 4 the switch in a fight: no error, no secure frame shown, hidden or moved, and the screens catch up after it", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { simple = true })
	local r = T.rider(w, T.TESTCHAR, { simple = true })
	T.settle(w)
	T.goOnline(d, { price = 5000 })
	w:advance(2)
	rideStart(w, d, r)
	r.W.UI.Toggle(true)
	T.openDrive(d)
	w:advance(2)
	d.W.Driver.RefreshNow()
	local errs = #w.errors
	for _, side in ipairs({ d, r }) do
		local before = secureSnap(side)
		w:enterCombat(side)
		w:advance(1.5)
		local during = secureSnap(side)
		side.W.SetAdvanced(true)
		w:advance(1)
		side.W.UI.Refresh(true)
		w:advance(1)
		eq(secureSnap(side), during, side.player.name .. ": no secure frame shown, hidden or moved by the switch in the fight")
		side.W.SetAdvanced(false)
		w:advance(1)
		side.W.SetAdvanced(true)
		w:advance(1)
		eq(secureSnap(side), during, side.player.name .. ": still none after switching back and forth")
		w:leaveCombat(side)
		w:advance(2)
		eq(side.W.Advanced(), true, side.player.name .. ": the mode is what was asked in the fight")
		ok(before ~= nil, "(a snapshot was taken before the fight)")
		side.W.SetAdvanced(false)
	end
	eq(#w.errors, errs, "no error in the fake game: " .. tostring(w.errors[errs + 1]))
	-- the screens catch up after the fight: a switch made in combat shows once it is over
	d.W.SetAdvanced(false)
	w:advance(1)
	w:enterCombat(d)
	d.W.SetAdvanced(true)
	w:advance(2)
	w:leaveCombat(d)
	w:advance(2)
	d.W.Driver.RefreshNow()
	w:advance(1)
	local ui = d.W.Driver.ui.console
	ok(ui and ui.modeBar and T.H.visible(ui.modeBar), "the screen caught up after the fight: Advanced shows the Sell / Raid bar")
	d.W.SetAdvanced(false)
	w:advance(1)
	ok(not T.H.visible(ui.modeBar), "and Simple takes it away again")
	eq(#w.errors, errs, "still no error")
	T.clean(w)
end)
