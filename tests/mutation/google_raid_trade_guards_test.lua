-- Mutation guard tests for Wuber/Drive/Raid.lua and Wuber/Drive/Trade.lua.
-- Loaded by tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok = T.H, T.test, T.eq, T.ok

local DRU, LEA, CAL, RAY = "Dru Oak", "Lea Dorn", T.CAL, "Ray Ash"
local RAIDSPOT = "Blackrock Mountain"

local function key(name) return (name:lower():gsub("[%s%-]+", " ")) end
local function DRof(c) return c.W.Drive end

local function alertsOf(c)
	local DR, out = DRof(c), {}
	local alert = DR.Alert
	DR.Alert = function(text, kind, ...)
		out[#out + 1] = tostring(text)
		return alert(text, kind, ...)
	end
	return out
end

local function makeRaid(opts)
	opts = opts or {}
	local w = H.NewWorld({})
	local lea = opts.leaClient and w:addClient(LEA, { spot = opts.leaSpot or RAIDSPOT, class = "WARRIOR" }) or nil
	if not lea then w:addBot(LEA, { spot = RAIDSPOT, class = "WARRIOR" }) end
	local dru = w:addClient(DRU, { spot = opts.druSpot or RAIDSPOT, class = "DRUID" })
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK" })
	local names = { LEA, DRU, CAL }
	if opts.withRay then
		local ray = T.rider(w, RAY, { spot = "Orgrimmar" })
		names[#names + 1] = RAY
		for i = 1, 4 do
			local n = "Raider R" .. string.char(96 + i)
			w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
			names[#names + 1] = n
		end
		w:group(names)
		w:setAssist(DRU, true)
		T.settle(w)
		return w, dru, cal, ray, lea
	end
	for i = 1, 5 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	return w, dru, cal, nil, lea
end

local function startRaid(w, dru, cal)
	local DD = DRof(dru)
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick(CAL, true))
	w:advance(1)
	DRof(cal).AnswerOffer(DRU, true)
	w:advance(3)
	ok(DD.SetOpen(true), "Start")
	w:advance(2)
end

-- guards Wuber/Drive/Raid.lua:83 (negate if type(roster) == "function" in CanRunRaid)
test("mutation drive.raid: CanRunRaid falls back to GetRaidRosterInfo when officer unit APIs are absent", function()
	local w, dru = makeRaid()
	dru.env.UnitIsGroupAssistant = false
	dru.env.UnitIsRaidOfficer = false
	local allowed = DRof(dru).CanRunRaid()
	eq(allowed, true, "raid assistant allowed via GetRaidRosterInfo fallback")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:167 (return nil instead of true in atSpot when player is on another map)
test("mutation drive.raid: atSpot treats raider on summoner map as arrived when runner is on another map", function()
	local w, dru, cal = makeRaid({ druSpot = "Orgrimmar" })
	startRaid(w, dru, cal)
	ok(DRof(dru).RaidAdd("Raider Ra"), "Ra queued")
	w:advance(3)
	ok(DRof(dru).raidRows[key("Raider Ra")], "Ra is in queue")
	w:move("Raider Ra", RAIDSPOT)
	w:advance(3)
	eq(DRof(dru).raidRows[key("Raider Ra")], nil, "Ra marked arrived even though runner is in Orgrimmar")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:256 (and to or in tie-break stop-summon alert)
test("mutation drive.raid: tie-break winner casting on same raider is not told to stop summon", function()
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = RAIDSPOT, class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = RAIDSPOT, class = "DRUID" })
	local ala = w:addClient("Ala Lock", { spot = RAIDSPOT, class = "WARLOCK" })
	local bea = w:addClient("Bea Lock", { spot = RAIDSPOT, class = "WARLOCK" })
	local names = { LEA, DRU, "Ala Lock", "Bea Lock" }
	for i = 1, 4 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	local DD = DRof(dru)
	ok(DD.SetMode("raid"))
	ok(DD.RaidPick("Ala Lock", true))
	ok(DD.RaidPick("Bea Lock", true))
	w:advance(1)
	DRof(ala).AnswerOffer(DRU, true)
	DRof(bea).AnswerOffer(DRU, true)
	w:advance(3)
	ok(DD.SetOpen(true), "Start")
	w:advance(2)
	ok(DD.RaidAdd("Raider Ra"), "Ra queued")
	w:advance(3)
	local alaAlerts = alertsOf(ala)
	DRof(ala).cast = { name = "Raider Ra", at = ala.env.GetTime() }
	DRof(ala).Do("CAST", "Raider Ra")
	DRof(bea).Do("CAST", "Raider Ra")
	w:advance(2)
	local toldStop = false
	for _, msg in ipairs(alaAlerts) do
		if msg:find("stop your summon", 1, true) then toldStop = true end
	end
	eq(toldStop, false, "tie-break winner is not told to stop summon")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:279 (delete row.fails = row.fails + 1 on failed summon END)
test("mutation drive.raid: two failed summons trigger give-up drop after RAID_GIVE_UP", function()
	local w, dru, cal = makeRaid()
	startRaid(w, dru, cal)
	ok(DRof(dru).RaidAdd("Raider Ra"), "Ra queued")
	w:advance(3)
	for _ = 1, 2 do
		DRof(cal).Do("CAST", "Raider Ra")
		w:advance(1)
		DRof(cal).Do("END", "Raider Ra", "0")
		w:advance(1)
	end
	w:advance(DRof(dru).RAID_GIVE_UP + 3)
	eq(DRof(dru).raidRows[key("Raider Ra")], nil, "row dropped after two failed summons and give-up window")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:296 (or to and in orderKey fallback to LeaderOf)
test("mutation drive.raid: crew window falls back to raid leader as order keeper when captain leaves", function()
	local w, dru, cal, _, lea = makeRaid({ leaClient = true })
	startRaid(w, dru, cal)
	w:leave(DRU)
	w:advance(2)
	eq(DRof(cal).RaidOrderKey(), key(LEA), "order keeper falls back to raid leader")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:307 (return nil instead of true in RaidApply when RA from non-orderKey)
test("mutation drive.raid: RaidApply returns true when handling RA from a non-order-keeper", function()
	local w, dru, cal = makeRaid()
	startRaid(w, dru, cal)
	local handled = DRof(cal).RaidApply("RA", key(CAL), false, "Raider Ra", nil, nil, 100)
	eq(handled, true, "RaidApply claims non-keeper RA")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:410 (return nil instead of free[1] in RaidNext for non-picked caller)
test("mutation drive.raid: RaidNext returns first free raider when caller is not in Summoners", function()
	local w = H.NewWorld({})
	w:addBot(LEA, { spot = RAIDSPOT, class = "WARRIOR" })
	local dru = w:addClient(DRU, { spot = RAIDSPOT, class = "WARLOCK" })
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK" })
	local names = { LEA, DRU, CAL }
	for i = 1, 5 do
		local n = "Raider R" .. string.char(96 + i)
		w:addBot(n, { spot = "Orgrimmar", class = "WARRIOR" })
		names[#names + 1] = n
	end
	w:group(names)
	w:setAssist(DRU, true)
	T.settle(w)
	startRaid(w, dru, cal)
	ok(DRof(dru).RaidAdd("Raider Ra"), "Ra queued")
	w:advance(3)
	local nxt = DRof(dru).RaidNext()
	ok(nxt and nxt.key == key("Raider Ra"), "RaidNext returns first free raider")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:473 (delete DR.raidLostTold = true so lost-lead pause alerts once)
test("mutation drive.raid: runner losing lead or assist is told raid summons paused only once", function()
	local w, dru, cal = makeRaid()
	startRaid(w, dru, cal)
	local druAlerts = alertsOf(dru)
	w:setAssist(DRU, false)
	w:advance(2)
	DRof(dru).SetPaused(false)
	w:advance(2)
	local count = 0
	for _, msg in ipairs(druAlerts) do
		if msg:find("need lead or assist", 1, true) then count = count + 1 end
	end
	eq(count, 1, "lost-lead pause alert shown once")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:523 (return nil instead of true in RaidPick untick)
test("mutation drive.raid: RaidPick returns true when unticking a summoner", function()
	local w, dru, cal = makeRaid()
	startRaid(w, dru, cal)
	eq(DRof(dru).RaidPick(CAL, false), true, "RaidPick(name, false) returns true")
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:600 (delete DR.raidRows[myKey()] = nil in RaidCancel)
test("mutation drive.raid: RaidCancel clears local mirrored row immediately before RN round-trip", function()
	local w, dru, cal, ray = makeRaid({ withRay = true })
	startRaid(w, dru, cal)
	ok(DRof(ray).RaidAsk(), "Ray asks for a summon")
	w:advance(3)
	ok(DRof(ray).RaidHere().queued, "Ray is queued")
	DRof(ray).RaidCancel()
	eq(DRof(ray).RaidHere().queued, false, "local mirrored row cleared immediately")
	w:advance(2)
	T.clean(w)
end)

-- guards Wuber/Drive/Raid.lua:603 (return nil instead of true in RaidCancel)
test("mutation drive.raid: RaidCancel returns true", function()
	local w, dru, cal, ray = makeRaid({ withRay = true })
	startRaid(w, dru, cal)
	ok(DRof(ray).RaidAsk(), "Ray asks for a summon")
	w:advance(3)
	eq(DRof(ray).RaidCancel(), true, "RaidCancel returns true")
	w:advance(2)
	T.clean(w)
end)

-- guards Wuber/Drive/Trade.lua:125 (delete DR.trade = nil on TRADE_SHOW in raid mode)
test("mutation drive.trade: TRADE_SHOW in raid mode clears any stale prior trade", function()
	local w = H.NewWorld({})
	local cal = w:addClient(CAL, { spot = RAIDSPOT, class = "WARLOCK" })
	local ray = T.rider(w, RAY, { spot = RAIDSPOT })
	T.settle(w)
	w:openTrade(cal, ray)
	w:advance(1)
	ok(DRof(cal).trade ~= nil, "sell-mode trade recorded")
	ok(DRof(cal).SetMode("raid"))
	cal:fire("TRADE_SHOW")
	w:advance(1)
	eq(DRof(cal).trade, nil, "stale trade cleared on TRADE_SHOW in raid mode")
	T.clean(w)
end)
