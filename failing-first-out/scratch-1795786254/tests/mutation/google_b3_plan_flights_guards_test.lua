local T = ...
local test, eq, ok = T.test, T.eq, T.ok

-- guards Wuber/Drive/Plan.lua:305 (callStep asks the same plain summoner twice in one plan)
test("mutation b3 plan flights: callStep asks each plain summoner at most once per plan", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar", class = "MAGE" })
	T.settle(w)
	local DR = d.W.Drive
	local real = {
		RunnerWindow = DR.RunnerWindow, IsPlainSummoner = DR.IsPlainSummoner,
		NextCaster = DR.NextCaster, IsOpen = DR.IsOpen, IsPaused = DR.IsPaused,
		InGroup = d.W.InGroup, SummonPending = DR.SummonPending,
		Here = DR.Here, Online = DR.Online, PlaceStale = DR.PlaceStale,
		Units = DR.Units, IsWarlock = d.W.IsWarlock, LeadFix = DR.LeadFix, Sorted = DR.Sorted,
	}
	DR.IsOpen = function() return true end
	DR.IsPaused = function() return false end
	DR.LeadFix = function() return nil end
	DR.RunnerWindow = function() return true end
	DR.IsPlainSummoner = function(k) return k == "bea jones" end
	DR.NextCaster = function() return "bea jones" end
	DR.SummonPending = function() return false end
	DR.Here = function() return false end
	DR.Online = function() return true end
	DR.PlaceStale = function() return false end
	DR.Units = function() return { ["cal brown"] = "party1", ["dan miller"] = "party2", ["bea jones"] = "party3" } end
	d.W.IsWarlock = function() return false end
	d.W.InGroup = function() return true end
	w:addBot("Bea Jones", { spot = "Orgrimmar", class = "WARLOCK" })
	w:addBot("Cal Brown", { spot = "Undercity" })
	w:addBot("Dan Miller", { spot = "Undercity" })
	w:group({ T.ANITA, "Bea Jones", "Cal Brown", "Dan Miller" })
	w:advance(1)
	DR.customers["cal brown"] = { name = "Cal Brown", key = "cal brown", state = "joined", at = 1, paid = false }
	DR.customers["dan miller"] = { name = "Dan Miller", key = "dan miller", state = "joined", at = 2, paid = false }
	DR.Sorted = function() return { DR.customers["cal brown"], DR.customers["dan miller"] } end
	local p = DR.Plan()
	local calls = 0
	for _, m in ipairs(p.marks or {}) do
		if m.kind == "callsum" and m.summoner == "bea jones" then calls = calls + 1 end
	end
	for k, v in pairs(real) do
		if k == "InGroup" or k == "IsWarlock" then d.W[k] = v else DR[k] = v end
	end
	eq(calls, 1, "plain summoner asked once, not twice")
	T.clean(w)
end)

-- guards Wuber/Drive/Plan.lua:361 (raidHold never schedules Changed timer to clear the hold)
test("mutation b3 plan flights: raidHold schedules re-plan after hold expires", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = d.W.Drive
	local real = {
		Mode = DR.Mode, IsOpen = DR.IsOpen, IsPaused = DR.IsPaused,
		RaidAssign = DR.RaidAssign, Shards = DR.Shards, Changed = DR.Changed,
		SummonPending = DR.SummonPending,
	}
	DR.Mode = function() return "raid" end
	DR.IsOpen = function() return true end
	DR.IsPaused = function() return false end
	DR.Shards = function() return 10 end
	DR.SummonPending = function() return false end
	local row1 = { key = "cal brown", name = "Cal Brown", state = "joined", order = 1 }
	local row2 = { key = "dan miller", name = "Dan Miller", state = "joined", order = 2 }
	DR.RaidAssign = function()
		return {
			{ key = d.W.myKey, row = row1, index = 1 },
			{ key = "bea jones", row = row2, index = 2 },
		}, { row1, row2 }
	end
	local changed = 0
	DR.Changed = function() changed = changed + 1 end
	DR.raidMine = nil
	local p = DR.Plan()
	ok(p.raidHold == row1, "first plan holds for 0.3s")
	w:advance(0.5)
	for k, v in pairs(real) do DR[k] = v end
	ok(changed >= 1, "Changed fired after raidHold timer")
	T.clean(w)
end)

-- guards Wuber/Drive/Plan.lua:565 (oops in macro mode drops uninvite when whisper + uninvite exceeds macro limit)
test("mutation b3 plan flights: oops in macro mode truncates whisper and keeps uninvite", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = d.W.Drive
	local real = { IsOpen = DR.IsOpen, Text = DR.Text }
	DR.IsOpen = function() return true end
	DR.Text = function(kind)
		if kind == "oops" then return string.rep("x", 240) end
		return ""
	end
	DR.opts().whisperMode = "macro"
	DR.customers["dan miller"] = { name = "Dan Miller", key = "dan miller", state = "joined", oops = true, at = 1 }
	local p = DR.Plan()
	for k, v in pairs(real) do DR[k] = v end
	ok((p.macrotext or ""):find("/uninvite Dan Miller", 1, true), "uninvite line kept: " .. tostring(p.macrotext))
	ok(#(p.macrotext or "") <= DR.MACRO_MAX, "macro within limit")
	T.clean(w)
end)

-- guards Wuber/Drive/Plan.lua:568 (oops in chat box mode skips uninvite)
test("mutation b3 plan flights: oops in chat box mode still uninvites and queues box whisper", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = d.W.Drive
	local realIsOpen = DR.IsOpen
	DR.IsOpen = function() return true end
	DR.opts().whisperMode = "box"
	DR.customers["dan miller"] = { name = "Dan Miller", key = "dan miller", state = "joined", oops = true, at = 1 }
	local p = DR.Plan()
	DR.IsOpen = realIsOpen
	ok((p.macrotext or ""):find("/uninvite Dan Miller", 1, true), "uninvite line present")
	ok(p.box and p.box.kind == "oops", "chat box oops whisper queued")
	T.clean(w)
end)

-- guards Wuber/Drive/Plan.lua:571 (oops in whisper-off mode skips uninvite)
test("mutation b3 plan flights: oops with whispers off still uninvites", function()
	local w = T.newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	T.settle(w)
	local DR = d.W.Drive
	local realIsOpen = DR.IsOpen
	DR.IsOpen = function() return true end
	DR.opts().whisperMode = "off"
	DR.customers["dan miller"] = { name = "Dan Miller", key = "dan miller", state = "joined", oops = true, at = 1 }
	local p = DR.Plan()
	DR.IsOpen = realIsOpen
	ok((p.macrotext or ""):find("/uninvite Dan Miller", 1, true), "uninvite line present")
	T.clean(w)
end)

local function setupFlightsPeer(w)
	local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
	local r = T.rider(w, T.BOB, { spot = "Orgrimmar" })
	T.settle(w)
	local W = d.W
	W.FlyNet.capable[r.W.myKey] = true
	W.FlyNet.sentTo[r.W.myKey] = nil
	W.FlyNet.heardFrom[r.W.myKey] = nil
	W.FlyNet.lastTo[r.W.myKey] = nil
	W.FlyNet.queued[r.W.myKey] = nil
	W.FlyNet.checked[r.W.myKey] = nil
	W.FlyNet.retry[r.W.myKey] = nil
	W.FlyNet.count[r.W.myKey] = 0
	W.FlyNet.sent = {}
	return d, r
end

local function lastF(w, from)
	local last
	for _, e in ipairs(w:messages() or {}) do
		if e.from == from and e.prefix == "WUBER" and e.result == 0 and e.text:find("^F~") then
			last = e.text
		end
	end
	return last
end

-- guards Wuber/Net/Flights.lua:93 (asked-for flight prices ranked last instead of first)
test("mutation b3 plan flights: asked flight entry is ranked first in F message", function()
	local w = T.newWorld()
	local d, r = setupFlightsPeer(w)
	local W = d.W
	local realList = W.FlightShareList
	W.FlightShareList = function()
		return {
			{ k = "a|b", from = "a", to = "b", c = 100, t = 10, at = 100, own = true },
			{ k = "c|d", from = "c", to = "d", c = 200, t = 20, at = 90, own = false },
		}
	end
	W.FlyNet.wants[r.W.myKey] = { ["c|d"] = true }
	local okSend = W.Mod("Net.Community").CX.flyMaybe("Bob-Jones", r.W.myKey)
	w:advance(1)
	W.FlightShareList = realList
	eq(okSend, true, "flyMaybe queued")
	local sentText = lastF(w, T.ANITA)
	ok(sentText and sentText:find("~c:d:200:", 1, true) and sentText:find("~c:d:200:") < sentText:find("~a:b:100:"),
		"asked entry c:d comes before own entry a:b: " .. tostring(sentText))
	T.clean(w)
end)

-- guards Wuber/Net/Flights.lua:105 (rank comparison ~= flipped to == breaks sort order)
test("mutation b3 plan flights: pick sorts higher-ranked wanted entry before lower-ranked newer entry", function()
	local w = T.newWorld()
	local d, r = setupFlightsPeer(w)
	local W = d.W
	local realList = W.FlightShareList
	W.FlightShareList = function()
		return {
			{ k = "e|f", from = "e", to = "f", c = 300, t = 30, at = 200, own = false },
			{ k = "a|b", from = "a", to = "b", c = 100, t = 10, at = 100, own = true },
			{ k = "c|d", from = "c", to = "d", c = 200, t = 20, at = 50, own = false },
		}
	end
	W.FlyNet.wants[r.W.myKey] = { ["c|d"] = true }
	local okSend = W.Mod("Net.Community").CX.flyMaybe("Bob-Jones", r.W.myKey)
	w:advance(1)
	W.FlightShareList = realList
	eq(okSend, true, "flyMaybe queued")
	local sentText = lastF(w, T.ANITA)
	local posC = sentText and sentText:find("~c:d:200:", 1, true)
	local posA = sentText and sentText:find("~a:b:100:", 1, true)
	local posE = sentText and sentText:find("~e:f:300:", 1, true)
	ok(posC and posA and posE and posC < posA and posA < posE,
		"rank 0 (c:d) < rank 2 (a:b) < rank 3 (e:f): " .. tostring(sentText))
	T.clean(w)
end)

-- guards Wuber/Net/Flights.lua:118 (size not incremented, packing F message over 250 bytes)
test("mutation b3 plan flights: pick caps F message at FLY_BYTES", function()
	local w = T.newWorld()
	local d, r = setupFlightsPeer(w)
	local W = d.W
	local realList = W.FlightShareList
	local longFrom = string.rep("x", 50)
	local longTo = string.rep("y", 50)
	local entries = {}
	for i = 1, 6 do
		entries[i] = { k = i .. "|" .. i, from = longFrom .. i, to = longTo .. i, c = 1000, t = 60, at = 100 - i, own = true }
	end
	W.FlightShareList = function() return entries end
	local okSend = W.Mod("Net.Community").CX.flyMaybe("Bob-Jones", r.W.myKey)
	w:advance(1)
	W.FlightShareList = realList
	eq(okSend, true, "flyMaybe queued")
	local sentText = lastF(w, T.ANITA)
	ok(sentText and #sentText <= 250, "F message length within 250 bytes: " .. tostring(sentText and #sentText))
	T.clean(w)
end)

-- guards Wuber/Net/Flights.lua:172 (retry flag not cleared, blocking later cooldown retries)
test("mutation b3 plan flights: retry flag clears after cooldown retry so later wants also retry", function()
	local w = T.newWorld()
	local d, r = setupFlightsPeer(w)
	local W = d.W
	local CX = W.Mod("Net.Community").CX
	local realList = W.FlightShareList
	W.FlightShareList = function()
		return {
			{ k = "a|b", from = "a", to = "b", c = 100, t = 10, at = 100, own = true },
			{ k = "c|d", from = "c", to = "d", c = 200, t = 20, at = 100, own = true },
		}
	end
	-- First cooldown + want -> schedules retry
	W.FlyNet.lastTo[r.W.myKey] = W.Now()
	W.FlyNet.wants[r.W.myKey] = { ["a|b"] = true }
	eq(CX.flyMaybe("Bob Jones", r.W.myKey), false, "first call throttled by gap")
	ok(W.FlyNet.retry[r.W.myKey] == true, "retry scheduled")
	w:advance(62)
	eq(W.FlyNet.retry[r.W.myKey], nil, "retry flag cleared after timer fires")
	-- Second cooldown + want -> must also schedule retry
	W.FlyNet.lastTo[r.W.myKey] = W.Now()
	W.FlyNet.wants[r.W.myKey] = { ["c|d"] = true }
	eq(CX.flyMaybe("Bob Jones", r.W.myKey), false, "second call throttled by gap")
	ok(W.FlyNet.retry[r.W.myKey] == true, "second retry scheduled")
	W.FlightShareList = realList
	T.clean(w)
end)

-- guards Wuber/Net/Flights.lua:173 (cooldown retry timer never calls CX.flyMaybe)
test("mutation b3 plan flights: cooldown retry timer sends wanted flight after gap", function()
	local w = T.newWorld()
	local d, r = setupFlightsPeer(w)
	local W = d.W
	local CX = W.Mod("Net.Community").CX
	local realList = W.FlightShareList
	W.FlightShareList = function()
		return { { k = "a|b", from = "a", to = "b", c = 100, t = 10, at = 100, own = true } }
	end
	W.FlyNet.lastTo[r.W.myKey] = W.Now()
	W.FlyNet.wants[r.W.myKey] = { ["a|b"] = true }
	eq(CX.flyMaybe("Bob Jones", r.W.myKey), false, "throttled during gap")
	local beforeOut = W.FlyNet.out
	w:advance(62)
	W.FlightShareList = realList
	ok(W.FlyNet.out > beforeOut or (W.FlyNet.sentTo[r.W.myKey] and W.FlyNet.sentTo[r.W.myKey]["a|b"]),
		"retry timer sent the wanted flight entry")
	T.clean(w)
end)
