-- Wuber Lab (developer only, never ship): the photo tour's demo driving log, the one source for every
-- driver number the tour shows (round 13, I33: the shots must add up).
--
--   L.PhotoDemoLog(t) -> log, info: a whole W.db.drive.log (Wuber's own line formats, Drive.Log's
--     header) for "now" = t: six evenings in the last week and a shift that ended five minutes ago.
--     The tour puts it in place of the real log (put back afterwards with WuberDB), so Wuber's own
--     functions work out Earnings (summary, bars, heatmap, best and missed hours), Customers, the
--     queue's "11th ride with you", today's takings and the shift card from the same rides.
--     info = { shift = { start, stop }, casts = { [key] = n }, clicks = { [key] = n }, crew = { [key] = name } }
--   Rules kept: every hour has at least as many buyers asking as rides; each ride of the shift is one
--   cast (yours or Vex's); two clicks per summon by the other two; a rider's rides are hours apart.
--   L.PhotoDemoCut(W, log, info) -> rows, rule, pct: the shift's fair split by Wuber's own rule
--     (W.Drive.CutSplit) over everything the crew took in the shift: the shares add up to it.

local _, L = ...

local num, call = L.num, L.call

local PRICE = 5000
local ME = "*me*" -- the tour's own character (W.myKey at run time)
L.PHOTO_CREW = { ["vex ember"] = "Vex Ember", ["nyla frost"] = "Nyla Frost" }

-- past days: { day offset, { hour, open minutes, rides, buyers who asked and got no ride } }
local DAYS = {
	{ 1, { { 17, 60, 2, 1 }, { 18, 60, 3, 1 }, { 19, 60, 4, 2 }, { 20, 60, 3, 0 }, { 22, 0, 0, 2 } } },
	{ 2, { { 19, 60, 3, 1 }, { 20, 60, 5, 1 }, { 21, 45, 2, 0 } } },
	{ 3, { { 20, 0, 0, 1 } } }, -- a night off: somebody asked anyway
	{ 4, { { 13, 60, 1, 1 }, { 14, 30, 1, 0 }, { 18, 60, 3, 0 }, { 19, 60, 4, 1 }, { 20, 60, 4, 2 } } },
	{ 5, { { 17, 60, 2, 0 }, { 18, 60, 3, 1 }, { 19, 60, 4, 0 }, { 20, 60, 4, 1 }, { 21, 60, 2, 1 } } },
	{ 6, { { 18, 60, 3, 1 }, { 19, 60, 3, 2 }, { 20, 45, 2, 0 }, { 23, 0, 0, 2 } } },
}

-- the shift (ended 5 min ago, two hours open): minutes from its start; who cast; Vex's two are the crew's
local SHIFT_LEN, SHIFT_END = 120, 5
local SHIFT = {
	{ 8, ME, "Dan Rider" }, { 21, ME, "Kai Brook" }, { 34, ME, "Eve Night" }, { 40, "vex ember", "Lou Fern" },
	{ 52, ME, "Max Dune" }, { 67, ME, "Ora Pike" }, { 88, ME, "Pip Gale" }, { 96, "vex ember", "Rae Holt" },
	{ 110, ME, "Sam Wick" },
}
-- tips (copper on top of the fare), by ride number in the shift
local SHIFT_TIP = { [3] = 1000, [7] = 2000 }

-- the riders of the past days, in turn (Eve rides often; a rider never twice within the hour)
local CYCLE = { "Eve Night", "Tess Ward", "Uma Reed", "Vic Lane", "Kai Brook", "Wyn Ash", "Lou Fern", "Eve Night",
	"Max Dune", "Ned Vale", "Ora Pike", "Pip Gale", "Rae Holt", "Sam Wick", "Eve Night", "Zoe Marsh", "Bo Quill",
	"Cy Thorn", "Jo Brand", "Tess Ward", "Uma Reed", "Eve Night", "Kai Brook", "Liv Hart", "Mo Clay", "Ned Vale",
	"Ora Pike", "Pip Gale" }
-- a few riders named on purpose: Fay (a note in the book), Gus (asks for a ride in the queue), Dan's
-- first ride (he always goes to Orgrimmar)
local NAMED = { [6] = "Fay Storm", [14] = "Gus Hill", [30] = "Dan Rider" }
local PLACES = { "Undercity", "Orgrimmar", "Thunder Bluff", "Undercity", "Orgrimmar" }
local HOME = { ["Dan Rider"] = "Orgrimmar", ["Fay Storm"] = "Thunder Bluff", ["Gus Hill"] = "Undercity", ["Eve Night"] = "Undercity" }

local function hourKey(at) return call(date, "%Y%m%d%H", at) end

local function ask(l, at, name, dest)
	l.asks[#l.asks + 1] = ("%d,match,%s,m,%s,summon to %s?"):format(at, name, dest, dest:lower())
end

-- the epoch time of day offset d, hour h, minute m (local time), or nil
local function timeOf(base, d, h, m)
	local ok, v = pcall(time, { year = base.year, month = base.month, day = base.day - d, hour = h, min = m, sec = 0 })
	return ok and num(v) or nil
end

function L.PhotoDemoLog(t, myKey)
	t = num(t) or num(call(time)) or 0
	myKey = myKey or "anita lift"
	local l = { v = 1, rides = {}, team = {}, asks = {}, open = {}, seen = {}, wreq = {}, wdec = {}, rivals = {}, raid = {} }
	local base = call(date, "*t", t)
	if type(base) ~= "table" then return l, nil end
	local n = 0
	-- the past evenings (oldest first, so the lines are in time order)
	for di = #DAYS, 1, -1 do
		local d, hours = DAYS[di][1], DAYS[di][2]
		for _, e in ipairs(hours) do
			local h, open, rides, extra = e[1], e[2], e[3], e[4]
			local at0 = timeOf(base, d, h, 0)
			if at0 then
				if open > 0 then
					local k = hourKey(at0)
					l.open[k], l.seen[k] = open, open
				end
				for r = 1, rides do
					n = n + 1
					local name = NAMED[n] or CYCLE[(n - 1) % #CYCLE + 1]
					local dest = HOME[name] or PLACES[(n - 1) % #PLACES + 1]
					local at = at0 + math.floor((r - 0.5) * open * 60 / rides)
					local tip = (n % 4 == 0) and 1000 or ((n % 7 == 0) and 2000 or 0)
					l.rides[#l.rides + 1] = ("%d,%d,%s,%s,t,%d"):format(at, PRICE + tip, name, dest, PRICE)
					ask(l, at, name, dest)
				end
				for x = 1, extra do ask(l, at0 + 50 * 60 + x * 60, "Someone Else", "Ratchet") end
			end
		end
	end
	-- the shift that ended five minutes ago
	local stop = t - SHIFT_END * 60
	local start = stop - SHIFT_LEN * 60
	local info = { shift = { start = start, stop = stop }, casts = {}, clicks = {}, crew = {} }
	local others = { myKey, "vex ember", "nyla frost" }
	for i, e in ipairs(SHIFT) do
		local at = start + e[1] * 60
		local caster = e[2] == ME and myKey or e[2]
		local name = e[3]
		local dest = HOME[name] or PLACES[i % #PLACES + 1]
		if caster == myKey then
			l.rides[#l.rides + 1] = ("%d,%d,%s,%s,t,%d"):format(at, PRICE + (SHIFT_TIP[i] or 0), name, dest, PRICE)
		else
			l.team[#l.team + 1] = ("%d,%d,%s,%s,%s,%s"):format(at, PRICE, name, dest, caster, caster)
			info.crew[caster] = L.PHOTO_CREW[caster]
		end
		ask(l, at, name, dest) -- (the same second: the same hour as the ride)
		info.casts[caster] = (info.casts[caster] or 0) + 1
		-- the other two click the portal
		for _, k in ipairs(others) do
			if k ~= caster then info.clicks[k] = (info.clicks[k] or 0) + 1 end
		end
	end
	for k in pairs(info.clicks) do if L.PHOTO_CREW[k] then info.crew[k] = L.PHOTO_CREW[k] end end
	-- its open minutes, by the hours it covers
	local m = start
	while m < stop do
		local k = hourKey(m)
		l.open[k] = (l.open[k] or 0) + 1
		l.seen[k] = (l.seen[k] or 0) + 1
		m = m + 60
	end
	l.shift = { start = start, stop = stop, seen = stop }
	return l, info
end

-- (BRIEF20 B9) a driver with just a little history, for the "Open a few hours to find your best ones" tip:
-- last evening he was open 25 and 20 minutes (two rides; under an hour in any three, so no top window) and
-- two buyers asked at an hour he was shut (the "Try ..." tip). No shift. Same line formats as above.
function L.PhotoSparseLog(t)
	t = num(t) or num(call(time)) or 0
	local l = { v = 1, rides = {}, team = {}, asks = {}, open = {}, seen = {}, wreq = {}, wdec = {}, rivals = {}, raid = {} }
	local base = call(date, "*t", t)
	if type(base) ~= "table" then return l end
	local function put(h, open, riders)
		local at0 = timeOf(base, 1, h, 0)
		if not at0 then return end
		if open > 0 then
			local k = hourKey(at0)
			l.open[k], l.seen[k] = open, open
		end
		for i, name in ipairs(riders or {}) do
			local dest = HOME[name] or "Undercity"
			local at = at0 + (i * 8) * 60
			l.rides[#l.rides + 1] = ("%d,%d,%s,%s,t,%d"):format(at, PRICE, name, dest, PRICE)
			ask(l, at, name, dest)
		end
	end
	put(20, 25, { "Eve Night" })
	put(21, 20, { "Dan Rider" })
	-- two buyers asked at an hour he was shut
	local at22 = timeOf(base, 1, 22, 0)
	if at22 then
		for x = 1, 2 do ask(l, at22 + x * 60, "Someone Else", "Ratchet") end
	end
	return l
end

-- the shift's split by Wuber's own rule: rows { name, key, casts, clicks, share }, largest share first
function L.PhotoDemoCut(W, l, info, myName)
	local DR = W.Drive
	if type(info) ~= "table" or type(DR) ~= "table" or type(DR.CutSplit) ~= "function" then return {}, "clicks", 40 end
	local gold = 0
	for _, list in ipairs({ l.rides, l.team }) do
		for _, line in ipairs(list) do
			local at, copper = tostring(line):match("^(%d+),(%d+),")
			at, copper = tonumber(at), tonumber(copper)
			if at and at >= info.shift.start and at <= info.shift.stop then gold = gold + copper end
		end
	end
	local me = W.myKey or "anita lift"
	local shares = DR.CutSplit(gold, info.casts, info.clicks, "clicks", 40, me)
	local rows = {}
	local seen = {}
	local function add(k)
		if seen[k] then return end
		seen[k] = true
		rows[#rows + 1] = { key = k, name = k == me and (myName or "Mia Runner") or info.crew[k] or k, casts = info.casts[k] or 0,
			clicks = info.clicks[k] or 0, share = shares[k] or 0 }
	end
	for k in pairs(info.casts) do add(k) end
	for k in pairs(info.clicks) do add(k) end
	table.sort(rows, function(a, b)
		if a.share ~= b.share then return a.share > b.share end
		return tostring(a.name) < tostring(b.name)
	end)
	return rows, "clicks", 40, gold
end
