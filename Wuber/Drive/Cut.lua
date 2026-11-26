-- Module: Drive.Cut
-- Purpose: the clicker cut ledger: each crew member's casts and clicks this shift (the same reducer
--   in every crew window), the fair split at shift end and the shift log's cut entries.
-- API: DR.cut, DR.Cut, DR.CutText, DR.CutSplit, DR.CutTick, DR.CutLog, DR.CUT_LOG_MAX
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: listens Listen DRIVE_RITUAL, Listen DRIVE_PAID; fires DRIVE_CUT
-- Standalone: no
-- Test: tests/drive/cut_test.lua
-- From: new in Wuber 2.3.0 (SPEC7 section 5.5; owner F)
--
-- The tallies are also saved in W.db.drive.log.shift.cut (tagged with the shift's start), so a /reload keeps them.
-- The ledger follows the shift Drive.Log keeps (W.db.drive.log.shift: open to close). Every crew
-- window hears the same facts, so every window's tallies agree:
--   casts   DRIVE_RITUAL "s" (END ok): one for the caster
--   clicks  DRIVE_RITUAL "h" (a HELP believed during that rider's summon): one per helper per summon
--           (a helper without Wuber counts when the caster's window names them, HELP field 2)
--   gold    DRIVE_PAID during the shift: the crew's takings, tips included
-- The split (Settings > Driving, DR.Opt "cutRule"): "clicks" (default) = casters share cutCaster %
-- (default 40) by casts, the rest is shared by clicks; "equal" = everyone with a cast or a click gets
-- the same. Shares are floored to whole silver; what is left goes to the runner (the captain).
-- Wuber never moves gold: this is a suggestion the players pay by trade themselves.
--
--   DR.Cut() -> rows { { name, key, casts, clicks, share }, ... } (largest share first), rule,
--     { gold, pct, since, stop } -- this shift (after closing: the shift that just ended)
--   DR.CutText() -> "Shift split: Anita 2g 10s, Farra 1g 40s" (<= 240) or nil
--   DR.CutSplit(gold, casts, clicks, rule, pct, runner) -> { [key] = copper } (pure, for tests)
--   W.db.drive.log.cut (only once W.VERSION is 2.3.0): at shift end, { at, gold, casts = { [name] = n }, clicks = {...}, rule, pct }
--     (the last DR.CUT_LOG_MAX shifts)

local _, W = ...
local Mod = W.Module("Drive.Cut", {})
W.Drive = W.Drive or {}
local DR = W.Drive

DR.CUT_LOG_MAX = 60
local TEXT_MAX = 240

-- this shift's tallies (saved with the shift, see saveTally) (keyed by crew key) and names
local cut = { since = nil, stop = nil, casts = {}, clicks = {}, names = {}, gold = 0, logged = false }
DR.cut = cut

local function call(name, ...)
	local fn = DR[name]
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		W.Error("drive " .. name, a)
		return nil
	end
	return a, b
end

local function logDB()
	local d = W.db and W.db.drive
	return type(d) == "table" and type(d.log) == "table" and d.log or nil
end

local function ruleNow()
	local rule = call("Opt", "cutRule")
	local pct = tonumber((call("Opt", "cutCaster"))) or 40
	return rule == "equal" and "equal" or "clicks", math.max(0, math.min(100, pct))
end

local function nameOf(key)
	if cut.names[key] then return cut.names[key] end
	if key == W.myKey then return W.myName or W.Me() end
	local n = call("NameOf", key)
	if type(n) == "string" and n ~= "" then return n end
	local unit = DR.units and DR.units[key]
	return (unit and W.UnitName(unit)) or key
end

local function changed()
	W.Fire("DRIVE_CUT")
	call("Changed")
end

-- The log entry of a finished shift (names, not keys: they outlive the session).
local function writeLog()
	local l = logDB()
	if not l or cut.logged or not cut.since then return end
	cut.logged = true
	local any = cut.gold > 0
	local casts, clicks = {}, {}
	for k, n in pairs(cut.casts) do casts[nameOf(k)] = n any = true end
	for k, n in pairs(cut.clicks) do clicks[nameOf(k)] = n any = true end
	if not any then return end
	-- dormant until the release's version bump (as Net's R field 6): until W.VERSION is 2.3.0 the saved
	-- data of a 2.2-style shift stays exactly as it was (the live tallies still work)
	if not (W.VerAtLeast and W.VerAtLeast(W.VERSION, "2.3.0")) then return end
	if type(l.cut) ~= "table" then l.cut = {} end
	local rule, pct = ruleNow()
	l.cut[#l.cut + 1] = { at = cut.stop or cut.since, gold = cut.gold, casts = casts, clicks = clicks, rule = rule, pct = pct }
	while #l.cut > DR.CUT_LOG_MAX do table.remove(l.cut, 1) end
end

-- The tallies ride along in the saved shift (l.shift.cut, tagged with the shift's start), so a /reload or a short
-- disconnect in the middle of a shift keeps them; a different shift start ignores them.
local function copyTally(t)
	local o = {}
	if type(t) == "table" then
		for k, n in pairs(t) do if type(k) == "string" and type(n) == "number" then o[k] = n end end
	end
	return o
end

local function saveTally()
	local l = logDB()
	local sh = l and l.shift
	if type(sh) ~= "table" or not cut.since or sh.start ~= cut.since or sh.stop then return end
	sh.cut = { since = cut.since, gold = cut.gold, casts = copyTally(cut.casts), clicks = copyTally(cut.clicks), names = copyTally(nil) }
	for k, n in pairs(cut.names) do if type(n) == "string" then sh.cut.names[k] = n end end
end

-- Follows Drive.Log's shift: a new shift clears the tallies, a closed one is logged once.
local function sync()
	local l = logDB()
	if not l then return false end
	-- (read only: Drive.Log keeps the shift; its tick and SETTINGS update it, so reading the cut
	-- from a screen never writes saved data)
	local sh = type(l.shift) == "table" and l.shift or {}
	if sh.start and not sh.stop then
		if cut.since ~= sh.start then
			-- (r52 #10) a shift the game left open (a gap over 2 minutes: Drive.Log starts a new one without
			-- a stop) still gets its Fair split written: from the tally in memory, or after a reload from the
			-- one saved with the old shift
			local sv0 = sh.cut
			if not cut.since and type(sv0) == "table" and tonumber(sv0.since) and sv0.since ~= sh.start then
				cut.since, cut.stop, cut.logged, cut.gold = sv0.since, nil, false, math.max(0, tonumber(sv0.gold) or 0)
				cut.casts, cut.clicks, cut.names = copyTally(sv0.casts), copyTally(sv0.clicks), {}
				if type(sv0.names) == "table" then
					for k, n in pairs(sv0.names) do if type(k) == "string" and type(n) == "string" then cut.names[k] = n end end
				end
			end
			if cut.since and not cut.logged then writeLog() end
			cut.since, cut.stop, cut.logged, cut.gold = sh.start, nil, false, 0
			cut.casts, cut.clicks, cut.names = {}, {}, {}
			local sv = sh.cut
			if type(sv) == "table" and sv.since == sh.start then
				cut.gold = math.max(0, tonumber(sv.gold) or 0)
				cut.casts, cut.clicks = copyTally(sv.casts), copyTally(sv.clicks)
				if type(sv.names) == "table" then
					for k, n in pairs(sv.names) do if type(k) == "string" and type(n) == "string" then cut.names[k] = n end end
				end
			end
			changed()
		end
		return true
	end
	if cut.since and sh.start == cut.since and sh.stop and not cut.logged then
		cut.stop = sh.stop
		writeLog()
		changed()
	end
	return false
end

function DR.CutTick() sync() end

-- DRIVE_RITUAL: casts on "s", clicks on "h" (once per helper per summon: Drive.Queue fires "h"
-- only for a helper new to that summon)
W.Listen("DRIVE_RITUAL", function(name, phase, data)
	if (phase ~= "s" and phase ~= "h") or type(data) ~= "table" then return end
	if not sync() then return end
	if phase == "s" then
		local k = data.caster
		if not k then return end
		cut.casts[k] = (cut.casts[k] or 0) + 1
	else
		local k = data.helper
		if not k or k == data.caster then return end
		if data.helperName then cut.names[k] = data.helperName end
		cut.clicks[k] = (cut.clicks[k] or 0) + 1
	end
	saveTally()
	changed()
end)

-- DRIVE_PAID: name, copper, tip, cashierKey, mine, how, price
W.Listen("DRIVE_PAID", function(name, copper)
	copper = tonumber(copper) or 0
	if copper <= 0 or not sync() then return end
	cut.gold = cut.gold + math.floor(copper)
	saveTally()
	changed()
end)

local function silver(v) return math.floor(v / 100) * 100 end

-- The split: { [key] = copper }. Shares floored to whole silver, the rest to the runner.
function DR.CutSplit(gold, casts, clicks, rule, pct, runner)
	gold = math.max(0, math.floor(tonumber(gold) or 0))
	casts, clicks = casts or {}, clicks or {}
	local raw, people = {}, {}
	for k in pairs(casts) do people[k] = true end
	for k in pairs(clicks) do people[k] = true end
	if rule == "equal" then
		local n = 0
		for k in pairs(people) do
			if (casts[k] or 0) + (clicks[k] or 0) > 0 then n = n + 1 end
		end
		for k in pairs(people) do
			if n > 0 and (casts[k] or 0) + (clicks[k] or 0) > 0 then raw[k] = gold / n end
		end
	else
		local nCasts, nClicks = 0, 0
		for _, v in pairs(casts) do nCasts = nCasts + v end
		for _, v in pairs(clicks) do nClicks = nClicks + v end
		local pool = gold * math.max(0, math.min(100, tonumber(pct) or 40)) / 100
		if nClicks == 0 then pool = gold end
		if nCasts == 0 then pool = 0 end
		for k, v in pairs(casts) do
			if nCasts > 0 then raw[k] = (raw[k] or 0) + pool * v / nCasts end
		end
		for k, v in pairs(clicks) do
			if nClicks > 0 then raw[k] = (raw[k] or 0) + (gold - pool) * v / nClicks end
		end
	end
	local out, given = {}, 0
	for k, v in pairs(raw) do
		out[k] = silver(v + 1e-6)
		given = given + out[k]
	end
	local rest = gold - given
	if rest > 0 and runner then out[runner] = (out[runner] or 0) + rest end
	return out
end

-- this shift's split, one row per crew member, and the rule used
function DR.Cut()
	sync()
	local rule, pct = ruleNow()
	local runner = call("CaptainKey") or W.myKey
	local shares = DR.CutSplit(cut.gold, cut.casts, cut.clicks, rule, pct, runner)
	local rows, seen = {}, {}
	local function add(k)
		if seen[k] then return end
		seen[k] = true
		rows[#rows + 1] = { key = k, name = nameOf(k), casts = cut.casts[k] or 0, clicks = cut.clicks[k] or 0, share = shares[k] or 0 }
	end
	for k in pairs(cut.casts) do add(k) end
	for k in pairs(cut.clicks) do add(k) end
	for k, v in pairs(shares) do if v > 0 then add(k) end end
	table.sort(rows, function(a, b)
		if a.share ~= b.share then return a.share > b.share end
		return tostring(a.name) < tostring(b.name)
	end)
	return rows, rule, { gold = cut.gold, pct = pct, since = cut.since, stop = cut.stop }
end

-- the line "Post to party" shares (no price for a service, no link, never the word for the coin)
function DR.CutText()
	local rows = DR.Cut()
	local parts = {}
	for _, r in ipairs(rows) do
		if r.share > 0 then parts[#parts + 1] = W.Short(r.name) .. " " .. W.Money(r.share) end
	end
	if #parts == 0 then return nil end
	local text = "Shift split: " .. parts[1]
	for i = 2, #parts do
		local nextText = text .. ", " .. parts[i]
		if #nextText > TEXT_MAX then break end
		text = nextText
	end
	return W.Clean(text, TEXT_MAX)
end

-- (tests, Earnings) the shift log's cut entries, newest last
function DR.CutLog()
	local l = logDB()
	return l and type(l.cut) == "table" and l.cut or {}
end
