-- tools/hunt/anonymise.lua: the hunt's saved-data fixtures (tests/hunt/fixtures/saved/*.lua).
-- Reads the four real WuberDB files (read-only), replaces every other player's name with Tester01, Tester02 ...
-- (the same real name always gets the same Tester name in all files; a two-word name stays two words, a
-- "-Realm" suffix is kept), blanks free-typed text (notes, the message of a logged ask), and writes
-- acct1..acct4 plus old1 (acct3 cut back to what an older Wuber saved).
-- Repeatable: same input, same output. Prints only counts, never the names. The real-name -> Tester map
-- lives in memory only and is never written anywhere.
-- Run from the repo root:  lua5.1 tools/hunt/anonymise.lua [WTF Account dir] [output dir]
local WTF = arg[1] or "C:/Program Files (x86)/World of Warcraft/_forever_/WTF/Account"
local OUT = arg[2] or "tests/hunt/fixtures/saved"
-- (account folder -> fixture name). The account folders are found at run time (every folder under WTF that holds
-- SavedVariables/Wuber.lua, sorted by name: acct1, acct2 ...) and are never named here: the account ids never
-- go into this file, a file name or a fixture's content.
local ACCOUNTS = {}
do
	local p = assert(io.popen('dir /b /ad "' .. WTF:gsub("/", "\\") .. '"'), "cannot list " .. WTF)
	local names = {}
	for line in p:lines() do
		line = line:gsub("%s+$", "")
		local f = line ~= "" and io.open(WTF .. "/" .. line .. "/SavedVariables/Wuber.lua", "rb")
		if f then f:close() names[#names + 1] = line end
	end
	p:close()
	table.sort(names)
	for i, name in ipairs(names) do ACCOUNTS[i] = { name, "acct" .. i } end
	assert(#ACCOUNTS > 0, "no account under " .. WTF .. " has SavedVariables/Wuber.lua")
end

-- the author's own characters (W.CREATOR / W.SEED_FOUNDERS in Wuber/Core/Base.lua, the test names) may stay
local KEEP = { ["anita lift"] = true, ["farra way"] = true, ["hayley cab"] = true, ["wuber rocks"] = true,
	["wuber testcharacter"] = true, ["fasf asas"] = true }
local function keepName(n)
	local l = n:lower()
	return KEEP[l] or l:find("labfake", 1, true) ~= nil
end

local function sortedKeys(t)
	local ks = {}
	for k in pairs(t) do ks[#ks + 1] = k end
	table.sort(ks, function(a, b)
		local ta, tb = type(a), type(b)
		if ta ~= tb then return ta == "number" end
		return a < b
	end)
	return ks
end

local function load(path)
	local f = io.open(path, "rb")
	if not f then error("cannot read " .. path) end
	local src = f:read("*a"); f:close()
	local env = {}
	local fn = assert(loadstring(src)); setfenv(fn, env); fn()
	assert(type(env.WuberDB) == "table", "no WuberDB")
	return env.WuberDB
end

-- ---- names -------------------------------------------------------------------------------------
local NAMEFIELDS = { name = 1, addr = 1, driver = 1, driverKey = 1, buyer = 1, key = 1, noteBy = 1, captain = 1,
	caster = 1, lead = 1, who = 1, player = 1, from = 1, by = 1 }
local NAMEMAPS = { peers = 1, seenDrivers = 1, favs = 1, hidden = 1, directory = 1, drivers = 1, list = 1, blocklist = 1 }
local NAMELISTS = { summoners = 1, crew = 1 }
local map, order = {}, {}   -- lowercase real name -> Tester base ; order of first sight (in memory only)
local function looksLikeName(s)
	return #s >= 3 and #s <= 40 and s:find("^[%a\128-\255][%a\128-\255' %-]*$") ~= nil
end
local function consider(s)
	if type(s) ~= "string" or not looksLikeName(s) then return end
	local base = s:gsub("%-[%a\128-\255]+$", "")   -- Name-Realm
	if base == "" or keepName(base) then return end
	local l = base:lower()
	if not map[l] then
		order[#order + 1] = l
		map[l] = { n = #order, two = base:find(" ", 1, true) ~= nil }
	end
end
local function logLine(s)   -- "time,kind,Name,..." (asks, rides, team)
	local nm = s:match("^%d+,[^,]*,([^,]*),")
	if nm then consider(nm) end
end
local function collect(t, path, parent)
	for _, k in ipairs(sortedKeys(t)) do
		local v = t[k]
		local last = type(k) == "string" and k or ""
		if type(k) == "string" and NAMEMAPS[parent or ""] then consider(k) end
		if type(v) == "table" then
			collect(v, path .. "." .. tostring(k), last)
		elseif type(v) == "string" then
			if NAMEFIELDS[last] then consider(v) end
			if NAMELISTS[parent or ""] and type(k) == "number" then consider(v) end
			if path:find("^%.drive%.log") then logLine(v) end
		end
	end
end

-- ---- rewriting ---------------------------------------------------------------------------------
local count
local function tester(l, original)
	local m = map[l]
	local base = string.format("Tester%02d", m.n)
	if m.two then base = base .. " Test" end
	if original == original:lower() then return base:lower() end
	return base
end
local function scrub(s)
	local low = s:lower()
	local best
	-- longest names first so a name that holds another is replaced whole
	local names = {}
	for l in pairs(map) do if low:find(l, 1, true) then names[#names + 1] = l end end
	if #names == 0 then return s end
	table.sort(names, function(a, b) if #a ~= #b then return #a > #b end return a < b end)
	for _, l in ipairs(names) do
		local out, pos = {}, 1
		local lw = s:lower()
		while true do
			local a, b = lw:find(l, pos, true)
			if not a then break end
			out[#out + 1] = s:sub(pos, a - 1)
			out[#out + 1] = tester(l, s:sub(a, b))
			pos = b + 1
			count = count + 1
		end
		out[#out + 1] = s:sub(pos)
		s = table.concat(out)
	end
	return s
end
local function rewrite(v, path, parent)
	if type(v) == "string" then
		if path:find("^%.drive%.log%.asks") then   -- "time,kind,Name,sex,zone,message": the message is free text
			local head = v:match("^(%d+,[^,]*,[^,]*,[^,]*,[^,]*,)")
			if head then return scrub(head) .. "wtb summon" end
		end
		return scrub(v)
	end
	if type(v) ~= "table" then return v end
	local o = {}
	for _, k in ipairs(sortedKeys(v)) do
		local nk = k
		if type(k) == "string" then nk = scrub(k) end
		local last = type(k) == "string" and k or ""
		local nv = rewrite(v[k], path .. "." .. tostring(k), last)
		if last == "note" and type(nv) == "string" and parent ~= nil and path:find("book") then nv = "a note" end
		o[nk] = nv
	end
	return o
end

-- ---- writing -----------------------------------------------------------------------------------
local function ser(v, ind, out)
	local t = type(v)
	if t == "table" then
		local ks = sortedKeys(v)
		if #ks == 0 then out[#out + 1] = "{}"; return end
		out[#out + 1] = "{\n"
		for _, k in ipairs(ks) do
			local kt = type(k) == "number" and ("[" .. string.format("%.17g", k) .. "]") or ("[" .. string.format("%q", k) .. "]")
			out[#out + 1] = ind .. "\t" .. kt .. " = "
			ser(v[k], ind .. "\t", out)
			out[#out + 1] = ",\n"
		end
		out[#out + 1] = ind .. "}"
	elseif t == "string" then out[#out + 1] = string.format("%q", v):gsub("\\\n", "\\n")
	elseif t == "number" then out[#out + 1] = string.format("%.17g", v)
	else out[#out + 1] = tostring(v) end
end
local function size(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function header(db, title, extra)
	local o = { "-- " .. title }
	o[#o + 1] = "-- Made by tools/hunt/anonymise.lua from a real Wuber saved-data file; other players' names are Tester01.. , free text blanked."
	local sc = {}
	for _, k in ipairs(sortedKeys(db)) do
		local v = db[k]
		if type(v) ~= "table" then sc[#sc + 1] = k .. "=" .. tostring(v) end
	end
	o[#o + 1] = "-- Top-level switches and values: " .. table.concat(sc, ", ")
	local ts = 0; for _ in pairs(db.tipsSeen or {}) do ts = ts + 1 end
	o[#o + 1] = string.format("-- tips seen: %d of 14; coach: %s; last tab: not saved by Wuber (the phone opens on its own default)", ts, tostring(db.coach))
	local log = (db.drive or {}).log or {}
	o[#o + 1] = string.format("-- characters: %d; trips (rides): %d; totals.rides: %s; drive log rows: rides %d, team %d, asks %d; blocked builds: %d; peers: %d; seen drivers: %d",
		size(db.chars), size(db.rides), tostring((db.totals or {}).rides), size(log.rides), size(log.team), size(log.asks), size(db.blockedBuild), size(db.peers), size(db.seenDrivers))
	local paid = 0; for _, c in pairs(db.chars or {}) do paid = paid + size((c.queue or {}).paid) end
	o[#o + 1] = string.format("-- earnings rows (paid queue entries over all characters): %d; flights learned: %d; map calibration sets: %d; milestones: %d",
		paid, size(db.flights), size(db.mapCal), size(db.milestones))
	if extra then o[#o + 1] = "-- " .. extra end
	return table.concat(o, "\n") .. "\n"
end
local function write(name, db, title, extra)
	local out = { header(db, title, extra), "return " }
	ser(db, "", out)
	out[#out + 1] = "\n"
	local f = assert(io.open(OUT .. "/" .. name .. ".lua", "wb"))
	f:write(table.concat(out)); f:close()
end

-- what an older Wuber (before the progress totals, the tips, the fold pages and the learned map) had saved
local function older(db)
	for _, k in ipairs({ "progressReady", "scaleV", "totals", "milestones", "fold", "tipsSeen", "tipsOn", "coach", "mapCal",
		"mapView", "uiFlightSaved", "uiFlightQuote", "toastAt", "tierSeen", "flights", "flightNodes", "peers", "openMapHint",
		"community", "msgSeen", "netFinished", "holdTip", "scale", "tipPct", "watch", "favs" }) do db[k] = nil end
	if db.drive then db.drive.v = nil; db.drive.publicV = nil; db.drive.log = nil end
	return db
end

local only = {}
for _, a in ipairs(ACCOUNTS) do
	local db = load(WTF .. "/" .. a[1] .. "/SavedVariables/Wuber.lua")
	collect(db, "", nil)
	only[#only + 1] = { a[2], db }
end
local acct3
for _, e in ipairs(only) do
	count = 0
	local clean = rewrite(e[2], "", nil)
	print(string.format("%s: %d names replaced", e[1], count))
	write(e[1], clean, "fixture " .. e[1] .. ": see the facts below")
	if e[1] == "acct3" then acct3 = clean end
end
count = 0
write("old1", older(rewrite(acct3, "", nil)), "fixture old1: acct3 cut back to what an older Wuber saved (no totals, tips, fold, learned map, drive log)",
	"the addon must upgrade it silently: W.RebuildTotals, UI.MigrateScale, milestones rebuilt without celebration")
print("old1: written; Tester names in use: " .. #order)
