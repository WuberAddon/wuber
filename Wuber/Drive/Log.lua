-- Module: Drive.Log
-- Purpose: Earnings log and stats (was Drive_Log.lua).
-- API: W.Drive, DR.Log, DR.LogRide, DR.LogTeamRide, DR.LogRaid, DR.RaidCount, DR.LogAsk, DR.LogNet,
--   DR.LogRivals, DR.Rivals, DR.LogTick, DR.ResetStats, DR.RestoreStats, DR.Stats, DR.LogSince, DR.LogTotals, DR.Hours,
--   DR.BestHours, DR.TryHours, DR.WDAYS, DR.Heatmap, DR.RideCount, DR.ShiftCheck, DR.ShiftSummary,
--   DR.LogReport, DR.LogPrune, DR.SummonAvg (FEAT-01: the mean summon time of the last 20 whole rides),
--   DR.CountAuto, DR.CountWrong, DR.AutoRecord, DR.AutoRecordText
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: listens Listen DRIVE_RAID_DONE, Listen DRIVE_PAID, Listen DRIVE_STATE, Listen DRIVE_PAID,
--   Listen DRIVE_STATE, Listen DRIVE_LOG, Listen DRIVE_STATE, Listen SETTINGS, login; fires DRIVE_LOG
-- Standalone: no
-- Test: tests/drive/log_test.lua
-- From: Drive_Log.lua 1-754 (Wuber 2.2.1)
--
-- Wuber 2.0 · Drive_Log.lua (agent D): the driver's earnings log and stats.
--
-- Kept in W.db.drive.log (account-wide: one account = one game window for a multiboxer),
-- written to disk at logout or /reload. The line formats are the old summon log's, so
-- tools\heatmap.js reads both:
--   rides   one line per payment this window took:    "time,copper,name,dest,how,price"
--           (how: t = traded, m = marked paid by hand; price: the fare charged - 2.0 adds it,
--           so a tip is copper - price)
--   team    one line per payment a crew mate took:     "time,copper,name,dest,cashier,payee"
--           (for the in-game crew view only; the tool reads each account's own rides; 2.1 adds
--           payee = the summoner the rider was to pay, and logs here the rides a runner marks
--           paid for a summoner without Wuber)
--   raid    raiders summoned in raid mode (free), by local hour
--   asks    one line per buyer seen in public chat:    "time,want,name,where,dest,text"
--           (want: match, noplace, unclear, elsewhere; where: m = market channels, o = other)
--   open    minutes open (open and not paused), by local hour "2026111719"
--   seen    minutes the game ran with the engine active, by local hour
--   wreq    Wuber ride requests this window received, by local hour
--   wdec    ... and of those, the ones it declined
--   rivals  the most other Wuber drivers (not the crew) online at once, by local hour
-- Beside the log: W.db.drive.summons, the summon times of the last 20 whole rides (DR.SummonAvg).
-- Each window logs only what it saw or took; the tool adds payments, takes the longest open
-- time of any window per hour and counts a buyer several windows saw once.
--
-- Stats: W.db.drive.stats (lifetime, this account's payments) and DR.session (this session,
-- the whole crew), kept from DRIVE_PAID and DRIVE_STATE (A's Apply never touches them).

local ADDON, W = ...
local Mod = W.Module("Drive.Log", {})
W.Drive = W.Drive or {}
local DR = W.Drive

-- Caps (2.2, review #27: a smaller WuberDB, so logout and /reload stay quick): rides keep the
-- earnings history; crew lines and public asks are only for the recent views. The hourly maps
-- keep 120 days.
local MAX_LINES = { rides = 10000, team = 2500, asks = 2500 }
local MAX_DAYS = 120
local MAX_HOURS = 24 * MAX_DAYS
DR.LOG_MAX_LINES, DR.LOG_MAX_DAYS = MAX_LINES, MAX_DAYS
local LISTS = { "rides", "team", "asks" }
local MAPS = { "open", "seen", "wreq", "wdec", "rivals", "raid" }
local MINUTE = 60

local function now()
	if type(time) == "function" then
		local ok, t = pcall(time)
		if ok and type(t) == "number" then return t end
	end
	return math.floor(GetTime())
end

local function hourKey(t) return date("%Y%m%d%H", t) end

-- epoch seconds of an hour key ("2026111719" -> 19:00 that day, local time)
local function keyTime(k)
	local y, mo, d, h = tostring(k):match("^(%d%d%d%d)(%d%d)(%d%d)(%d%d)$")
	if not y then return nil end
	local ok, t = pcall(time, { year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = 0, sec = 0 })
	if ok and type(t) == "number" then return t end
	return nil
end

local function driveDB()
	local db = W.db
	if type(db) ~= "table" then return nil end
	if type(db.drive) ~= "table" then
		if DR.InitDB then
			local ok = pcall(DR.InitDB)
			if not ok or type(db.drive) ~= "table" then return nil end
		else
			db.drive = { v = 1 }
		end
	end
	return db.drive
end

local function log()
	local d = driveDB()
	if not d then return nil end
	local l = d.log
	if type(l) ~= "table" then
		l = {}
		d.log = l
	end
	l.v = 1
	for _, k in ipairs(LISTS) do if type(l[k]) ~= "table" then l[k] = {} end end
	for _, k in ipairs(MAPS) do if type(l[k]) ~= "table" then l[k] = {} end end
	return l
end

local function stats()
	local d = driveDB()
	if not d then return nil end
	local s = d.stats
	if type(s) ~= "table" then
		s = {}
		d.stats = s
	end
	for _, k in ipairs({ "rides", "copper", "tips" }) do s[k] = tonumber(s[k]) or 0 end
	return s
end

local function session()
	DR.session = type(DR.session) == "table" and DR.session or {}
	local s = DR.session
	for _, k in ipairs({ "rides", "copper", "tips" }) do s[k] = tonumber(s[k]) or 0 end
	return s
end

function DR.Log()
	return log() or { v = 1, rides = {}, team = {}, asks = {}, open = {}, seen = {}, wreq = {}, wdec = {}, rivals = {}, raid = {} }
end

-- No commas, bars or line breaks inside a field.
local function field(v, max)
	v = tostring(v or ""):gsub("[,\r\n|]", " "):gsub("%s+", " ")
	v = v:gsub("^ ", ""):gsub(" $", "")
	if max and #v > max then v = v:sub(1, max) end
	return v
end

local function trim(list, max)
	local over = #list - max
	if over <= 0 then return end
	-- one move, not one table.remove per line (each of those shifts the whole list)
	local n = #list
	for i = 1, n - over do list[i] = list[i + over] end
	for i = n - over + 1, n do list[i] = nil end
end

local function push(list, line, max)
	list[#list + 1] = line
	trim(list, max or MAX_LINES.rides)
end

local function destNow()
	if DR.Dest then
		local ok, d = pcall(DR.Dest)
		if ok and type(d) == "string" and d ~= "" then return d end
	end
	if W.DestHere then
		local ok, d = pcall(W.DestHere)
		if ok and type(d) == "table" then d = d.name end
		if ok and type(d) == "string" then return d end
	end
	return ""
end

local function copperOf(v) return math.max(0, math.floor(tonumber(v) or 0)) end

local function changed() W.Fire("DRIVE_LOG") end

---------------------------------------------------------------------------
-- Writing
---------------------------------------------------------------------------

function DR.LogRide(copper, name, how, price)
	local l = log()
	if not l then return end
	copper = copperOf(copper)
	price = copperOf(price)
	push(l.rides, table.concat({ now(), copper, field(name, 40), field(destNow(), 40), how == "m" and "m" or "t", price }, ","), MAX_LINES.rides)
	changed()
end

function DR.LogTeamRide(copper, name, cashierKey, payeeKey)
	local l = log()
	if not l then return end
	push(l.team, table.concat({ now(), copperOf(copper), field(name, 40), field(destNow(), 40), field(cashierKey, 40),
		field(payeeKey or cashierKey, 40) }, ","), MAX_LINES.team)
	changed()
end

-- Raid mode (2.1): one raider summoned (free). Counted once per raider per 10 minutes.
local raidSeen = {}
function DR.LogRaid(name)
	local l = log()
	local k = W.Key(name)
	if not l or not k then return end
	local t = now()
	if raidSeen[k] and t - raidSeen[k] < 600 then return end
	raidSeen[k] = t
	local hk = hourKey(t)
	l.raid[hk] = (tonumber(l.raid[hk]) or 0) + 1
	changed()
end

-- Raiders summoned since `since` (epoch seconds; default: the last 6 hours, "tonight", as the console says).
function DR.RaidCount(since)
	local l = log()
	if not l then return 0 end
	since = tonumber(since) or (now() - 6 * 3600)
	local from, n = hourKey(since), 0
	for hk, m in pairs(l.raid) do
		if tostring(hk) >= from then n = n + (tonumber(m) or 0) end
	end
	return n
end

-- A raider landed after a summon (A fires it in every window; the caster's window also counts
-- its own END in raid mode, in case the event never comes).
W.Listen("DRIVE_RAID_DONE", function(name) DR.LogRaid(name) end)

local WANTS = { match = true, noplace = true, unclear = true, elsewhere = true }
function DR.LogAsk(want, name, text, inMarket)
	local l = log()
	if not l or not WANTS[want] then return end
	push(l.asks, table.concat({ now(), want, field(name, 40), inMarket and "m" or "o", field(destNow(), 40), field(text, 100) }, ","), MAX_LINES.asks)
	changed()
end

-- A Wuber request this window received ("wreq") or declined ("wdec"), this hour.
function DR.LogNet(kind)
	local l = log()
	if not l or (kind ~= "wreq" and kind ~= "wdec") then return end
	local k = hourKey(now())
	l[kind][k] = (tonumber(l[kind][k]) or 0) + 1
end

-- Other Wuber drivers online right now: the most seen this hour is kept.
function DR.LogRivals(n)
	local l = log()
	n = tonumber(n)
	if not l or not n then return end
	local k = hourKey(now())
	l.rivals[k] = math.max(tonumber(l.rivals[k]) or 0, math.max(0, math.floor(n)))
end

---------------------------------------------------------------------------
-- The minute: seen, open, rivals
---------------------------------------------------------------------------

local function locked()
	if not DR.Lock then return false end
	local ok, why = pcall(DR.Lock)
	return ok and why ~= nil
end

local function active()
	if locked() then return false end
	if DR.Active then
		local ok, on = pcall(DR.Active)
		return ok and on == true
	end
	return false
end

local function isOpen()
	-- selling only: raid summons (free) are not open hours in the heatmap
	local open = DR.Selling or DR.IsOpen
	if open then
		local ok, on = pcall(open)
		if ok then on = on == true else on = false end
		if not on then return false end
	else
		local c = W.Char and W.Char()
		if not (c and c.drive == true) then return false end
	end
	if DR.IsPaused then
		local ok, p = pcall(DR.IsPaused)
		if ok and p then return false end
	else
		local c = W.Char and W.Char()
		if c and c.paused then return false end
	end
	return true
end

local function isCrewKey(k)
	if not DR.IsCrewKey then return false end
	local ok, yes = pcall(DR.IsCrewKey, k)
	return ok and yes == true
end

-- How many drivers other than me and my crew are on Wuber now.
function DR.Rivals()
	local n = 0
	local me = W.Key(W.Me())
	for key, d in pairs(W.drivers or {}) do
		if type(d) == "table" and key ~= me and not isCrewKey(key) then n = n + 1 end
	end
	return n
end

local lastMinute -- GetTime() of the last minute counted

local function minute()
	local l = log()
	if not l then return end
	local k = hourKey(now())
	l.seen[k] = (tonumber(l.seen[k]) or 0) + 1
	if isOpen() then l.open[k] = (tonumber(l.open[k]) or 0) + 1 end
	DR.LogRivals(DR.Rivals())
	changed()
end

-- Called once a second by DR.Tick (and every few seconds by our own ticker, in case the
-- engine's tick isn't running): a minute is counted once 60 s have passed.
function DR.LogTick()
	-- (the engine's tick and our own ticker both call this; a minute is counted once)
	if DR.ShiftCheck then DR.ShiftCheck() end
	if not active() then
		lastMinute = nil
		return
	end
	local t = GetTime()
	if not lastMinute then
		lastMinute = t
		return
	end
	if t - lastMinute < MINUTE then return end
	lastMinute = lastMinute + MINUTE
	if t - lastMinute >= MINUTE then lastMinute = t end -- a long freeze: one minute, not many
	minute()
end

---------------------------------------------------------------------------
-- Stats from the engine's events
---------------------------------------------------------------------------

local function findCustomer(name)
	if not (DR.Find and name) then return nil end
	local ok, c = pcall(DR.Find, name)
	if ok and type(c) == "table" then return c end
	return nil
end

-- gold counted from a hand mark, per ride row, still to be covered by a later trade (HUNT-45)
local handPaid = setmetatable({}, { __mode = "k" })

-- DRIVE_PAID: name, copper, tip, cashierKey, mine, how ("t" traded | "m" by hand), price
-- (A keeps DR.session; D keeps the lifetime stats and the log lines)
W.Listen("DRIVE_PAID", function(name, copper, tip, cashierKey, mine, how, price)
	if locked() then return end
	copper = copperOf(copper)
	tip = copperOf(tip)
	local c = findCustomer(name)
	if price == nil and c then price = c.price end
	local byHand = how == "m"
	local payee = c and DR.PayeeKey and DR.PayeeKey(c) or nil
	local me = W.myKey or W.Key(W.Me())
	-- marked paid for the summoner who got the gold (no Wuber there): their ride and their gold, not mine
	local theirs = mine and byHand and payee and payee ~= me
	local st = stats()
	if mine and st and not theirs then
		-- a ride marked paid by hand counts its gold too; a later trade for the same ride only counts
		-- what the hand mark did not already cover (HUNT-45)
		local credit = copper
		if c and byHand then
			handPaid[c] = (handPaid[c] or 0) + copper
		elseif c and handPaid[c] then
			local cover = math.min(handPaid[c], copper)
			handPaid[c] = handPaid[c] - cover
			credit = copper - cover
			if handPaid[c] <= 0 then handPaid[c] = nil end
		end
		st.copper = st.copper + credit
		if not byHand then st.tips = st.tips + tip end
	end
	if theirs then
		DR.LogTeamRide(copper > 0 and copper or copperOf(price), (c and c.name) or name, payee, payee)
	elseif mine then
		DR.LogRide(copper, (c and c.name) or name, byHand and "m" or "t", price)
	else
		DR.LogTeamRide(copper, (c and c.name) or name, cashierKey, payee)
	end
end)

-- a ride counts once, when its rider reaches "paid" (on the cashier's account for the lifetime)
local counted = setmetatable({}, { __mode = "k" })
W.Listen("DRIVE_STATE", function(c, was)
	if type(c) ~= "table" then return end
	-- the same row back below paid is a new ride (a repeat rider; BRIEF17 C6): it counts again
	if counted[c] and DR.Rank and DR.Rank(c.state) < DR.Rank("paid") then counted[c] = nil handPaid[c] = nil end
	if c.state ~= "paid" or counted[c] or locked() then return end
	counted[c] = true
	local me = W.Key(W.Me())
	local cashier = c.cashier and W.Key(c.cashier)
	if cashier == nil or cashier == me then
		local st = stats()
		if st then st.rides = st.rides + 1 end
	end
	changed()
end)

-- "Reset counts" (Earnings): the lifetime and session counts, not the log.
-- (decisions N) Returns what it took away, { ever = { rides, copper, tips }, session = { ... }, n = how many of the six
-- were not zero }, for DR.RestoreStats (Earnings' Undo).
function DR.ResetStats()
	local st = stats()
	local s = session()
	local removed = { ever = { rides = 0, copper = 0, tips = 0 }, session = { rides = s.rides, copper = s.copper, tips = s.tips }, n = 0 }
	if st then
		removed.ever = { rides = st.rides, copper = st.copper, tips = st.tips }
		st.rides, st.copper, st.tips = 0, 0, 0
	end
	for _, part in ipairs({ removed.ever, removed.session }) do
		for _, k in ipairs({ "rides", "copper", "tips" }) do if part[k] ~= 0 then removed.n = removed.n + 1 end end
	end
	s.rides, s.copper, s.tips = 0, 0, 0
	changed()
	return removed
end

-- (decisions N) Undo of DR.ResetStats: adds back exactly what it took away (a ride counted since stays counted).
function DR.RestoreStats(removed)
	if type(removed) ~= "table" then return false end
	local st, s = stats(), session()
	for _, k in ipairs({ "rides", "copper", "tips" }) do
		if st and type(removed.ever) == "table" then st[k] = st[k] + (tonumber(removed.ever[k]) or 0) end
		if type(removed.session) == "table" then s[k] = s[k] + (tonumber(removed.session[k]) or 0) end
	end
	changed()
	return true
end

function DR.Stats()
	local st, s = stats() or { rides = 0, copper = 0, tips = 0 }, session()
	return { rides = st.rides, copper = st.copper, tips = st.tips }, { rides = s.rides, copper = s.copper, tips = s.tips }
end

---------------------------------------------------------------------------
-- The summon time (FEAT-01): how long a ready driver's summon takes, request to arrival
---------------------------------------------------------------------------
-- W.db.drive.summons = { { total = s, cast = s }, ... }, newest last, at most 20: whole seconds from
-- the rider's request to their arrival, and from the cast start to the arrival, of a ride this window
-- saw whole. The markers on the rider's row: c.sumAt = GetTime() at the DRIVE_STATE to "queued" (the
-- moment they asked; a lead listed earlier counts from then), set only while the driver was ready
-- (selling, not paused, no ride under way, nobody queued ahead); c.castAt (the CAST fact); c.sumArr =
-- c.arrivedAt when this window saw them arrive (DR.QueueTick sets it before the state; a crew window's
-- ST has none yet); c.sumHand = a payment marked by hand. A ride counts once, at "paid", when request
-- <= cast <= arrival, it was summoned (tries, not walked), paid by trade and still selling (raid
-- summons are no rides). A row back after a /reload has no c.sumAt (never saved): it gives nothing.
-- While the test addon's test mode is on (DR.SimHooks is set) the cast and the arrival are stood in
-- for: no request is marked and nothing is added, so a ride that crosses the mode gives nothing too.
local SUMMON = { KEEP = 20, MIN = 3, MAX = 900 }

local function summonReady(c)
	if DR.SimHooks ~= nil then return false end
	if not (DR.Selling and DR.Selling()) or type(DR.Busy) ~= "function" then return false end
	if DR.IsPaused and DR.IsPaused() then return false end
	if DR.Busy() then return false end
	for _, other in pairs(DR.customers or {}) do
		if other ~= c and other.state == "queued" then return false end
	end
	return true
end

local function addSummon(total, cast)
	total, cast = math.floor(total + 0.5), math.floor(cast + 0.5)
	if total < 1 or total > SUMMON.MAX or cast < 0 or cast > total then return end
	local d = driveDB()
	if not d then return end
	if type(d.summons) ~= "table" then d.summons = {} end
	local list = d.summons
	list[#list + 1] = { total = total, cast = cast }
	while #list > SUMMON.KEEP do table.remove(list, 1) end
	changed()
end

W.Listen("DRIVE_PAID", function(name, copper, tip, cashierKey, mine, how)
	if how ~= "m" then return end
	local c = findCustomer(name)
	if c then c.sumHand = true end
end)

W.Listen("DRIVE_STATE", function(c, was)
	if type(c) ~= "table" or not DR.Rank then return end
	local rank, wasRank, paid = DR.Rank(c.state), DR.Rank(was), DR.Rank("paid")
	-- a new row, a lead, or the row back for another ride: no marks from before
	if was == nil or was == "lead" or was == "done" or (wasRank >= paid and rank < paid) then
		c.sumAt, c.sumArr, c.sumHand = nil, nil, nil
	end
	if c.state == "queued" then
		c.sumAt, c.sumArr, c.sumHand = nil, nil, nil
		if W.loggedIn and not locked() and summonReady(c) then c.sumAt = GetTime() end
	elseif c.state == "arrived" then
		local at = tonumber(c.arrivedAt)
		c.sumArr = (at and not c.walked and wasRank < rank) and at or nil
	elseif c.state == "paid" and c.sumAt then
		local req, cast, arr = c.sumAt, tonumber(c.castAt), c.sumArr
		c.sumAt = nil
		if DR.SimHooks ~= nil then return end
		if not (cast and arr) or c.sumHand or c.walked or (tonumber(c.tries) or 0) < 1 then return end
		if req > cast or cast > arr or locked() or not (DR.Selling and DR.Selling()) then return end
		addSummon(arr - req, arr - cast)
	end
end)

-- The mean of the kept rides (the last 20), whole seconds: total (request to arrival), cast (cast
-- start to arrival), count; total and cast are nil until there are 3. Never a made-up number.
function DR.SummonAvg()
	local d = driveDB()
	local list = (d and type(d.summons) == "table") and d.summons or {}
	local n, sumT, sumC = 0, 0, 0
	for i = math.max(1, #list - SUMMON.KEEP + 1), #list do
		local s = list[i]
		local t = type(s) == "table" and tonumber(s.total) or nil
		local k = type(s) == "table" and tonumber(s.cast) or nil
		if t and k and t >= 1 and t <= SUMMON.MAX and k >= 0 and k <= t then
			n, sumT, sumC = n + 1, sumT + t, sumC + k
		end
	end
	if n < SUMMON.MIN then return nil, nil, n end
	return math.floor(sumT / n + 0.5), math.floor(sumC / n + 0.5), n
end

---------------------------------------------------------------------------
-- The careful record (2.4, p2): auto-invites sent and those marked wrong
---------------------------------------------------------------------------

local function careful(write)
	local d = driveDB()
	if not d then return nil end
	local k = d.careful
	if type(k) ~= "table" then
		if not write then return nil end
		k = { auto = 0, wrong = 0 }
		d.careful = k
	end
	local a = math.max(0, math.floor(tonumber(k.auto) or 0))
	local w = math.max(0, math.floor(tonumber(k.wrong) or 0))
	if write then k.auto, k.wrong = a, w end
	return k, a, w
end

local function bumpCareful(field)
	if DR.SimHooks ~= nil then return end -- the test addon's pretend rides are no part of the record
	local k = careful(true)
	if not k then return end
	k[field] = k[field] + 1
	changed()
end

function DR.CountAuto(c) bumpCareful("auto") end
function DR.CountWrong(c) bumpCareful("wrong") end

function DR.AutoRecord()
	local k, a, w = careful(false)
	if not k then return 0, 0 end
	return a, w
end

function DR.AutoRecordText()
	local auto, wrong = DR.AutoRecord()
	if auto <= 0 then return nil end
	local noun = auto == 1 and "auto-invite" or "auto-invites"
	return ("%d %s · %d wrong"):format(auto, noun, wrong)
end

---------------------------------------------------------------------------
-- Reading
---------------------------------------------------------------------------

-- local midnight of today
local function midnight(t)
	local d = date("*t", t)
	return t - (d.hour * 3600 + d.min * 60 + d.sec)
end

-- `days`: "today" (or 0, or 1) = since local midnight; else the last N days.
local function sinceOf(days)
	local t = now()
	if days == nil or days == "today" or tonumber(days) == nil or tonumber(days) <= 1 then return midnight(t) end
	return t - math.floor(tonumber(days)) * 86400
end
DR.LogSince = sinceOf

-- each ride line: at, copper, name, dest, how, price (price 0 when an old line has none)
local function eachRide(list, since, fn)
	for _, line in ipairs(list) do
		local at, copper, rest = tostring(line):match("^(%d+),(%d+),(.*)$")
		at = tonumber(at)
		if at and at >= since then
			local parts = {}
			for f in (rest .. ","):gmatch("([^,]*),") do parts[#parts + 1] = f end
			fn(at, tonumber(copper) or 0, parts)
		end
	end
end

local function tipOf(copper, parts)
	local price = tonumber(parts[4] or "")
	if not price or price <= 0 then return 0 end
	return math.max(0, copper - price)
end

-- Totals since `since` (epoch seconds). scope "me" (default): this account's payments;
-- "crew": the crew's payments too (team lines).
function DR.LogTotals(since, scope)
	local l = log()
	local t = { copper = 0, tips = 0, rides = 0, asks = 0, match = 0, open = 0, wreq = 0, wdec = 0, rivals = 0 }
	if not l then return t end
	since = tonumber(since) or 0
	eachRide(l.rides, since, function(_, copper, parts)
		t.copper, t.rides = t.copper + copper, t.rides + 1
		t.tips = t.tips + tipOf(copper, parts)
	end)
	if scope == "crew" then
		eachRide(l.team, since, function(_, copper)
			t.copper, t.rides = t.copper + copper, t.rides + 1
		end)
	end
	for _, line in ipairs(l.asks) do
		local at, want = tostring(line):match("^(%d+),(%a+),")
		if at and tonumber(at) >= since then
			t.asks = t.asks + 1
			if want == "match" then t.match = t.match + 1 end
		end
	end
	local from = hourKey(since)
	for _, k in ipairs({ "open", "wreq", "wdec" }) do
		for hk, m in pairs(l[k]) do
			if tostring(hk) >= from then t[k] = t[k] + (tonumber(m) or 0) end
		end
	end
	for hk, m in pairs(l.rivals) do
		if tostring(hk) >= from then t.rivals = math.max(t.rivals, tonumber(m) or 0) end
	end
	return t
end

local function hourOf(at) return tonumber(date("%H", at)) end
local function wdayOf(at) return tonumber(date("%w", at)) end -- 0 = Sunday

-- By hour of day (0..23, local) over the period: gold, rides, open minutes, asks.
function DR.Hours(days, scope)
	local out = {}
	for h = 0, 23 do out[h] = { copper = 0, rides = 0, open = 0, asks = 0 } end
	local l = log()
	if not l then return out end
	local since = sinceOf(days)
	local function ride(at, copper)
		local b = out[hourOf(at)]
		b.copper, b.rides = b.copper + copper, b.rides + 1
	end
	eachRide(l.rides, since, ride)
	if scope == "crew" then eachRide(l.team, since, ride) end
	for _, line in ipairs(l.asks) do
		local at = tonumber(tostring(line):match("^(%d+),"))
		if at and at >= since then
			local b = out[hourOf(at)]
			b.asks = b.asks + 1
		end
	end
	local from = hourKey(since)
	for hk, m in pairs(l.open) do
		hk = tostring(hk)
		if hk >= from then
			local h = tonumber(hk:sub(9, 10))
			if out[h] then out[h].open = out[h].open + (tonumber(m) or 0) end
		end
	end
	return out
end

-- weekday+hour slots over the period: { [wday*24+hour] = { wday, hour, copper, rides, open, asks } }
local function slots(days, scope)
	local l = log()
	local out = {}
	if not l then return out end
	local since = sinceOf(days)
	local function slot(wday, hour)
		local i = wday * 24 + hour
		local s = out[i]
		if not s then
			s = { wday = wday, hour = hour, copper = 0, rides = 0, open = 0, asks = 0, closedAsks = 0 }
			out[i] = s
		end
		return s
	end
	local function ride(at, copper)
		local s = slot(wdayOf(at), hourOf(at))
		s.copper, s.rides = s.copper + copper, s.rides + 1
	end
	eachRide(l.rides, since, ride)
	if scope == "crew" then eachRide(l.team, since, ride) end
	for _, line in ipairs(l.asks) do
		local at = tonumber(tostring(line):match("^(%d+),"))
		if at and at >= since then
			local s = slot(wdayOf(at), hourOf(at))
			s.asks = s.asks + 1
			if (tonumber(l.open[hourKey(at)]) or 0) <= 0 then s.closedAsks = s.closedAsks + 1 end -- nobody open that hour
		end
	end
	local from = hourKey(since)
	for hk, m in pairs(l.open) do
		local at = tostring(hk) >= from and keyTime(hk)
		if at then
			local s = slot(wdayOf(at), hourOf(at))
			s.open = s.open + (tonumber(m) or 0)
		end
	end
	return out
end

local ENOUGH = 30 -- open minutes a slot needs before its rate means anything

-- The best weekday+hour slots by gold per open hour (at least 30 open minutes):
-- { { wday, hour, perHour, rides, open } }, best first.
function DR.BestHours(days, n)
	local list = {}
	for _, s in pairs(slots(days)) do
		if s.open >= ENOUGH then
			list[#list + 1] = { wday = s.wday, hour = s.hour, perHour = math.floor(s.copper / (s.open / 60) + 0.5), rides = s.rides, open = s.open }
		end
	end
	table.sort(list, function(a, b)
		if a.perHour ~= b.perHour then return a.perHour > b.perHour end
		if a.wday ~= b.wday then return a.wday < b.wday end
		return a.hour < b.hour
	end)
	local out = {}
	for i = 1, math.min(n or 3, #list) do out[i] = list[i] end
	return out
end

-- Slots where buyers asked while you were closed (asks in an hour with no open minutes) and
-- you were open under 30 minutes in all ("try these"): { { wday, hour, asks, open } }, most asks first.
function DR.TryHours(days, n)
	local list = {}
	for _, s in pairs(slots(days)) do
		if s.closedAsks > 0 and s.open < ENOUGH then
			list[#list + 1] = { wday = s.wday, hour = s.hour, asks = s.closedAsks, open = s.open, perHour = 0, rides = s.rides }
		end
	end
	table.sort(list, function(a, b)
		if a.asks ~= b.asks then return a.asks > b.asks end
		if a.wday ~= b.wday then return a.wday < b.wday end
		return a.hour < b.hour
	end)
	local out = {}
	for i = 1, math.min(n or 3, #list) do out[i] = list[i] end
	return out
end

DR.WDAYS = { [0] = "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

-- The in-game heatmap (2.2, review #28): a 7 x 24 grid over the last `days` days (default 28,
-- at most the 120 the log keeps). grid[wday][hour] (wday 0 = Sunday as DR.WDAYS, hour 0..23,
-- local time) = { wday, hour, copper, rides, open (minutes), asks, perHour (copper per open
-- hour, nil under 30 open minutes) }. Also grid.max (the best perHour), grid.days, grid.copper.
-- scope "crew" adds the crew's payments (team lines).
function DR.Heatmap(days, scope)
	days = math.max(1, math.min(MAX_DAYS, math.floor(tonumber(days) or 28)))
	local grid = { days = days, max = 0, copper = 0, rides = 0 }
	for wd = 0, 6 do
		grid[wd] = {}
		for h = 0, 23 do grid[wd][h] = { wday = wd, hour = h, copper = 0, rides = 0, open = 0, asks = 0 } end
	end
	for _, sl in pairs(slots(days, scope)) do
		local cell = grid[sl.wday] and grid[sl.wday][sl.hour]
		if cell then
			cell.copper, cell.rides, cell.open, cell.asks = sl.copper, sl.rides, sl.open, sl.asks
			grid.copper, grid.rides = grid.copper + sl.copper, grid.rides + sl.rides
			if sl.open >= ENOUGH then
				cell.perHour = math.floor(sl.copper / (sl.open / 60) + 0.5)
				if cell.perHour > grid.max then grid.max = cell.perHour end
			end
		end
	end
	return grid
end

-- How many rides `name` took with this window before (2.2, review #19: the queue row's "3rd
-- ride with you"). Paid rides in the log (this window's and, with a crew, the crew's lines),
-- by key; two payments of one ride (a short trade, then the rest) are one ride. The ride going
-- on now is not counted: lines from after the rider joined this queue are left out.
local rideIndex -- [key] = { sorted times }; rebuilt after the log changes
W.Listen("DRIVE_LOG", function() rideIndex = nil end)

local function indexRides()
	local l = log()
	local idx = {}
	if not l then return idx end
	for _, list in ipairs({ l.rides, l.team }) do
		for _, line in ipairs(list) do
			local at, name = tostring(line):match("^(%d+),%d+,([^,]*)")
			local k = name and name ~= "" and W.Key(name)
			if k then
				local t = idx[k]
				if not t then
					t = {}
					idx[k] = t
				end
				t[#t + 1] = tonumber(at)
			end
		end
	end
	for _, t in pairs(idx) do table.sort(t) end
	return idx
end

local ONE_RIDE = 1800 -- payments this close together are one ride

function DR.RideCount(name)
	local k = type(name) == "string" and W.Key(name)
	if not k then return 0 end
	rideIndex = rideIndex or indexRides()
	local times = rideIndex[k]
	if not times then return 0 end
	local c = DR.customers and DR.customers[k]
	local before = c and tonumber(c.since) or nil
	if c and not before then before = now() - ONE_RIDE end -- (restored after a /reload)
	local n, last = 0, nil
	for _, at in ipairs(times) do
		if before and at >= before then break end
		if not last or at - last > ONE_RIDE then n = n + 1 end
		last = at
	end
	return n, last
end

-- A rider's first sight in this window, in log time (RideCount leaves their ride out).
W.Listen("DRIVE_STATE", function(c, was)
	-- (not while logging in: a customer restored then keeps no stamp, so the /reload fallback applies)
	if type(c) == "table" and was == nil and not c.since and W.loggedIn then c.since = now() end
end)

-- The shift: from opening (selling) to closing. DR.ShiftSummary() (2.2, review #20: the
-- card when the driver closes) -> { start, stop, open (seconds), rides, copper, tips,
-- crewRides, crewCopper, bestHour (0..23 or nil), bestCopper }, or nil before any shift.
-- After closing it describes the shift that just ended; while open, the shift so far.
local function shiftDB()
	local l = log()
	if not l then return nil end
	if type(l.shift) ~= "table" then l.shift = {} end
	return l.shift
end

local function selling()
	local fn = DR.Selling or DR.IsOpen
	if not fn then return false end
	local ok, on = pcall(fn)
	return ok and on == true
end

local function pausedNow()
	local fn = DR.IsPaused
	if not fn then return false end
	local ok, p = pcall(fn)
	return ok and p == true
end

local function shiftCheck()
	local sh = shiftDB()
	if not sh or locked() then return end
	local on, t = selling(), now()
	if on and not (sh.start and not sh.stop) then
		sh.start, sh.stop, sh.seen = t, nil, t
		sh.pausedSecs, sh.pauseAt = 0, nil
	elseif on and t - (tonumber(sh.seen) or sh.start) > 120 then
		-- the game was shut while open and this is hours later: the old shift ended when it was
		-- last seen open; a fresh one starts now (the offline hours are not open time)
		sh.start, sh.stop, sh.seen = t, nil, t
		sh.pausedSecs, sh.pauseAt = 0, nil
	elseif on then
		sh.seen = t
		-- time spent paused inside the shift does not count as open
		if pausedNow() then
			sh.pauseAt = sh.pauseAt or t
		elseif sh.pauseAt then
			sh.pausedSecs = (tonumber(sh.pausedSecs) or 0) + math.max(0, t - sh.pauseAt)
			sh.pauseAt = nil
		end
	elseif sh.start and not sh.stop then
		-- closed: now, or when it was last seen open (the game was shut while open)
		local seen = tonumber(sh.seen) or sh.start
		sh.stop = (t - seen > 120) and seen or t
	end
end
DR.ShiftCheck = shiftCheck
W.Listen("SETTINGS", function(what)
	if what == nil or what == "drive" or what == "paused" then shiftCheck() end
end)

function DR.ShiftSummary()
	shiftCheck()
	local sh = shiftDB()
	local l = log()
	if not (sh and l and sh.start) then return nil end
	local start, stop = sh.start, sh.stop or now()
	local out = { start = start, stop = stop, open = 0, rides = 0, copper = 0, tips = 0,
		crewRides = 0, crewCopper = 0, bestCopper = 0 }
	local paused = tonumber(sh.pausedSecs) or 0
	if sh.pauseAt then paused = paused + math.max(0, stop - sh.pauseAt) end
	out.open = math.max(0, stop - start - paused)
	local byHour = {}
	local function inShift(at) return at >= start and at <= stop end
	eachRide(l.rides, start, function(at, copper, parts)
		if inShift(at) then
			out.rides, out.copper = out.rides + 1, out.copper + copper
			out.tips = out.tips + tipOf(copper, parts)
			local h = hourOf(at)
			byHour[h] = (byHour[h] or 0) + copper
		end
	end)
	eachRide(l.team, start, function(at, copper)
		if inShift(at) then
			out.crewRides, out.crewCopper = out.crewRides + 1, out.crewCopper + copper
			local h = hourOf(at)
			byHour[h] = (byHour[h] or 0) + copper
		end
	end)
	for h, copper in pairs(byHour) do
		if copper > out.bestCopper or (copper == out.bestCopper and out.bestHour and h < out.bestHour) then
			out.bestHour, out.bestCopper = h, copper
		end
	end
	return out
end

-- /wuber drive log: this account's takings today and over seven days.
function DR.LogReport()
	for _, row in ipairs({ { "today", "today" }, { "last 7 days", 7 } }) do
		local s = DR.LogTotals(sinceOf(row[2]))
		local hours = s.open / 60
		-- no takings read 0c, never W.Money's "free"
		local function pay(c) return math.floor((tonumber(c) or 0) + 0.5) > 0 and W.Money(c) or "0c" end
		local rate = hours >= 0.1 and (" = " .. pay(s.copper / hours) .. " per open hour") or ""
		W.Print(("%s, this window: %d rides, %s in %.1f open hours%s; %d buyers seen (%d for %s)."):format(row[1], s.rides,
			pay(s.copper), hours, rate, s.asks, s.match, destNow() ~= "" and destNow() or "your place"))
	end
	W.Print("The heatmap (gold per open hour, by weekday and hour) is in the Drive tab: Earnings.")
end

---------------------------------------------------------------------------
-- Login: prune, and a ticker in case the engine's own tick isn't running
---------------------------------------------------------------------------

-- An hourly map keeps its last MAX_DAYS days, and never more than MAX_HOURS keys.
local function prune(map)
	local oldest = hourKey(now() - MAX_DAYS * 86400)
	local keys = {}
	for k in pairs(map) do
		local hk = tostring(k)
		if hk < oldest or not hk:match("^%d%d%d%d%d%d%d%d%d%d$") then map[k] = nil else keys[#keys + 1] = hk end
	end
	if #keys <= MAX_HOURS then return end
	table.sort(keys)
	for i = 1, #keys - MAX_HOURS do map[keys[i]] = nil end
end

-- What login does to the log (also for tests): old hours and lines over the caps go.
function DR.LogPrune()
	local l = log()
	if not l then return end
	for _, k in ipairs(MAPS) do prune(l[k]) end
	for _, k in ipairs(LISTS) do trim(l[k], MAX_LINES[k]) end
end

W.OnLogin(function()
	DR.LogPrune()
	W.Every(5, DR.LogTick)
end)
