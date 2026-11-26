-- Wuber 1.1 (round two, SPEC2.md and its "Advisor fixes, round two") tests.
-- Loaded by run.lua with its helpers in one table; run as part of `lua5.1 tests/run.lua`.

local T = ...local H, S, test, eq, ok, count, list = T.H, T.S, T.test, T.eq, T.ok, T.count, T.list
local newWorld, driver, rider, settle, goOnline, clean, msgs, fields = T.newWorld, T.driver, T.rider, T.settle, T.goOnline, T.clean, T.msgs, T.fields
local needUI, openConfirm, requestVia, openDrive, rideState, whispersTo, readFile = T.needUI, T.openConfirm, T.requestVia, T.openDrive, T.rideState, T.whispersTo, T.readFile
local pins = T.pins
local ANITA, TESTCHAR, BOB, ANA, BEA, CAL = T.ANITA, T.TESTCHAR, T.BOB, T.ANA, T.BEA, T.CAL
local HAVE_UI = T.HAVE_UI

local WDIR = H.ADDONS.Wuber
local ROUND1 = { Wuber = H.ADDONS.Wuber1 }
local F = H.F -- where an old file's code lives now (tests/lib/files.lua)
local HAVE_FX = F.has("FX")
local HAVE_PLATES = F.has("Nameplates")

-- a value SPEC2 promises must be there
local function need(v, what)
	if v == nil then error(what .. " is missing (SPEC2)", 2) end
	return v
end

-- Lua code run as if it were a file of the Wuber addon (so the harness applies addon rules to it)
local function probe(c, code, ...)
	local fn = assert(loadstring(code, "@" .. WDIR .. "/Probe.lua"))
	setfenv(fn, c.env)
	return fn(...)
end

-- how many times W.Fire(name) happened on a client since a mark
local function fired(c, name, since)
	local n = 0
	for _, e in ipairs(c.fired) do if e.name == name and e.at >= (since or -1) then n = n + 1 end end
	return n
end

local function key(name) return H.key(name) end

-- a beacon as the network would carry it (13 fields round one, 15 round two)
local function D(t)
	local parts = { "D", "1", t.dest or "Ratchet", t.mapID or 1413, t.x or 627, t.y or 370, t.price or 5000, t.service or "Svc",
		t.state or "open", t.team or 1, t.seats or 1, t.faction or "H", t.ver or "1.1.0" }
	if t.badge or t.queue then parts[#parts + 1] = t.badge or "" parts[#parts + 1] = t.queue or 0 end
	for i, v in ipairs(parts) do parts[i] = tostring(v) end
	return table.concat(parts, "~")
end

local function texts(c) return list(c:visibleTexts(), " | ") end

-- every frame (and region) under a frame
local function descendants(f, out)
	out = out or {}
	for _, ch in ipairs(S[f].children) do
		out[#out + 1] = ch
		descendants(ch, out)
	end
	return out
end

-- the textures of an addon that show a file whose path contains `part`
local function texturesWith(c, part, visibleOnly)
	local out = {}
	for _, o in ipairs(c.widgets) do
		local s = S[o]
		if s.otype == "Texture" and type(s.texture) == "string" and s.texture:lower():find(part:lower(), 1, true)
			and (not visibleOnly or H.visible(o)) then
			out[#out + 1] = o
		end
	end
	return out
end

local function badgeIds(W)
	local ids = {}
	for k, v in pairs(W.BADGES or {}) do
		if type(k) == "number" then
			local id = type(v) == "table" and (v.id or v[1]) or v
			if type(id) == "string" then ids[#ids + 1] = id end
		elseif type(k) == "string" then
			ids[#ids + 1] = k
		end
	end
	table.sort(ids)
	return ids
end

-- fake trips: { { "Anita Lift", "Ratchet", 5000, at offset in days, hour } ... }
-- (through W.AddTrip, which also keeps the lifetime totals)
local function trips(W, rows)
	local now = H.EPOCH
	for _, r in ipairs(rows) do
		local at = now - (r[4] or 0) * 86400 + ((r[5] or 19) - 19) * 3600
		W.AddTrip({ at = at, driver = r[1], driverKey = H.key(r[1]), dest = r[2], price = r[3] or 5000, stars = 5, saved = r[6] or 600 })
	end
end

-- no trips at all (lifetime totals too)
local function noTrips(W)
	W.db.rides, W.db.totals = {}, nil
	W.RebuildTotals()
end

-- visible text, case-insensitive
local function findCI(c, text)
	local pat = text:gsub("%a", function(ch) return "[" .. ch:lower() .. ch:upper() .. "]" end)
	return c:findText(pat)
end

-- the place record of a name
local function place(W, name)
	for _, p in ipairs(W.PLACES) do if p.name == name then return p end end
end

local function worldDist(mapA, xa, ya, mapB, xb, yb)
	local ca, ax, ay = H.toWorld(mapA, xa, ya)
	local cb, bx, by = H.toWorld(mapB, xb, yb)
	if not ca or ca ~= cb then return nil end
	return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

---------------------------------------------------------------------------
-- 11. The harness's new parts check themselves
---------------------------------------------------------------------------

test("harness self-check: nameplates (tokens, reuse, friendly CVar, forbidden, geometry, secret names)", function()
	local w = newWorld()
	local r = rider(w)
	w:addBot(BOB, { spot = "Orgrimmar" })
	w:addBot("Ally Guy", { spot = "Orgrimmar", faction = "Alliance" })
	w:addBot("Zed Ox", { spot = "Orgrimmar" })
	settle(w, 2)
	local seen = {}
	probe(r, [[
		local seen = ...
		local f = CreateFrame("Frame")
		f:RegisterEvent("NAME_PLATE_UNIT_ADDED") f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
		f:SetScript("OnEvent", function(_, e, u) seen[#seen + 1] = e .. " " .. u end)
	]], seen)
	eq(r:showPlate(BOB), nil, "a friendly plate waits for nameplateShowFriends")
	eq(r:showPlate("Ally Guy"), "nameplate1", "an enemy plate shows")
	r.env.SetCVar("nameplateShowFriends", "1")
	eq(r:plateIndexOf(BOB), 2, "Bob's plate came with the CVar")
	eq(r.env.UnitName("nameplate2"), "Bob", "UnitName of a nameplate token")
	local plate = r.env.C_NamePlate.GetNamePlateForUnit("nameplate2")
	ok(plate and S[plate].plate, "GetNamePlateForUnit")
	eq(#r.env.C_NamePlate.GetNamePlates(), 2)
	-- reading a plate's geometry from addon code is a violation (can be secret)
	probe(r, "local p = ... local _ = p:GetWidth()", plate)
	eq(#w.violations, 1, "GetWidth on a plate recorded")
	w.violations = {}
	-- anchoring to it is fine
	probe(r, [[local p = ... local f = CreateFrame("Frame", nil, UIParent) f:SetSize(10, 10) f:SetPoint("BOTTOM", p, "TOP", 0, 4)]], plate)
	eq(#r:onPlate(BOB), 1, "a frame anchored to Bob's plate")
	-- removed: REMOVED fires, the plate frame is reused for the next player on that token
	r:hidePlate(BOB)
	eq(#r:onPlate(BOB), 0)
	eq(r:showPlate("Zed Ox"), "nameplate2", "the token is reused")
	ok(r.env.C_NamePlate.GetNamePlateForUnit("nameplate2") == plate, "and the frame")
	ok(#r:plateFramesShown() == 1, "the stale frame now sits on Zed's plate (an addon must release on REMOVED)")
	-- forbidden: touching it is a violation
	r:hidePlate("Zed Ox")
	local tok = r:showPlate(BOB, { forbidden = true })
	local fp = r.env.C_NamePlate.GetNamePlateForUnit(tok)
	eq(fp:IsForbidden(), true)
	local okc = pcall(probe, r, "local p = ... return p:GetName()", fp)
	eq(okc, false, "a method on a forbidden plate errors")
	ok(#w.violations >= 1, "recorded")
	w.violations = {}
	r:hidePlate(BOB)
	-- a secret name
	tok = r:showPlate(BOB, { secretName = true })
	eq(r.env.issecretvalue(r.env.UnitName(tok)), true, "a secret name")
	-- in combat nameplate CVars are protected
	w:enterCombat(r)
	eq(r.env.SetCVar("nameplateShowFriends", "0"), false)
	eq(#w.violations, 1, "SetCVar in combat recorded")
	w.violations = {}
	w:leaveCombat(r)
	ok(#seen >= 6, "events seen: " .. list(seen))
	eq(r.env.GetCVar("nameplateShowFriendlyPlayers"), nil, "an unknown CVar reads nil")
	clean(w)
end)

for _, style in ipairs({ "processor", "legacy" }) do
	test("harness self-check: tooltip unit hooks (" .. style .. ")", function()
		local w = newWorld({ tooltipStyle = style })
		local r = rider(w)
		w:addBot(BOB, { spot = "Orgrimmar" })
		settle(w, 2)
		probe(r, [[
			local function add(tt) if tt == GameTooltip then tt:AddLine("probe line") end end
			if TooltipDataProcessor then
				TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, add)
			else
				GameTooltip:HookScript("OnTooltipSetUnit", add)
			end
		]])
		local lines = r:hover(BOB)
		eq(lines[1], BOB, "the name line")
		eq(lines[#lines], "probe line", "the hook's line")
		local okc = pcall(r.env.GameTooltip.HookScript, r.env.GameTooltip, "OnTooltipSetUnit", function() end)
		eq(okc, style == "legacy", "OnTooltipSetUnit exists only on the legacy client")
		clean(w)
	end)
end

test("harness self-check: ModelScene and models are guarded no-ops; a client can lack ModelScene", function()
	local w = newWorld()
	local r = rider(w)
	local scene = r.env.CreateFrame("ModelScene", nil, r.env.UIParent)
	local actor = scene:CreateActor()
	actor:SetModelByFileID(123)
	actor:SetSpellVisualKit(1)
	local m = r.env.CreateFrame("PlayerModel", nil, r.env.UIParent)
	m:SetDisplayInfo(1)
	ok(r.modelCalls >= 3, "calls counted")
	local w2 = newWorld({ noModelScene = true })
	local r2 = rider(w2)
	eq(pcall(r2.env.CreateFrame, "ModelScene"), false, "no ModelScene on that client")
	clean(w)
	clean(w2)
end)

test("harness self-check: round-one wire mode strips D/R to round-one fields and sends no P", function()
	local w = newWorld()
	local r = rider(w, TESTCHAR, { roundOne = true })
	settle(w)
	r.env.C_ChatInfo.SendAddonMessage("WUBER", "R~1~ABCDEF~Ratchet~5000~2~12", "WHISPER", "Anita-Lift")
	r.env.C_ChatInfo.SendAddonMessage("WUBER", "P~1~ABCDEF~2~60", "WHISPER", "Anita-Lift")
	local R = msgs(w, "R", TESTCHAR)
	eq(#R, 1)
	eq(R[1].text, "R~1~ABCDEF~Ratchet~5000", "stripped")
	eq(#msgs(w, "P", TESTCHAR), 0, "no P from a round-one client")
	clean(w)
end)

---------------------------------------------------------------------------
-- 12. Files: TOC order, media, no Ritual Rides
---------------------------------------------------------------------------

-- (SPEC3 5: Wuber 2.0 adds the Drive_* files and UI_Drive; the order is the spec's, exactly)
-- (REFACTOR: the expected order is tests/fixtures/toc-order.txt, one TOC line per line, updated
-- in the same commit as every TOC change)
test("TOC order: SPEC3's list (Core ... Map, Drive_*, Driver, UI_Drive, Nameplates, Commands); version 2.2.1", function()
	local files = H.tocFiles("Wuber")
	local want = {}
	for line in (readFile(T.dir .. "/fixtures/toc-order.txt") or ""):gmatch("[^\r\n]+") do
		line = line:gsub("^%s+", ""):gsub("%s+$", "")
		if line ~= "" and not line:match("^#") then want[#want + 1] = (line:gsub("\\", "/")) end
	end
	ok(#want > 20, "tests/fixtures/toc-order.txt")
	eq(table.concat(files, ","), table.concat(want, ","), "TOC order")
	local toc = readFile(WDIR .. "/Wuber.toc")
	-- (the test's name keeps "2.2.1": the behaviour transcript keys on test names)
	-- PLAN-2.3.2 release rule: internal builds say "2.3.3-dev", the CurseForge build "2.3.3"
	-- the version is read, not typed in: the TOC line must be digits.digits.digits (optional -suffix) and match W.VERSION
	local tocVer = toc:match("## Version: (%S+)")
	ok(tocVer and tocVer:match("^%d+%.%d+%.%d+$") or (tocVer and tocVer:match("^%d+%.%d+%.%d+%-%a+%d*$")), "TOC version format: " .. tostring(tocVer))
	-- what the addon reports (W.VERSION in Core/Base.lua), read from the file: no world, so this test's transcript is unchanged
	local addonVer = (readFile(WDIR .. "/Core/Base.lua") or ""):match('\nW%.VERSION = "([^"]+)"')
	eq(addonVer, tocVer, "the addon's W.VERSION (Core/Base.lua) equals the TOC version")
	-- SPEC5 rrmentions: no load-order tie to the old summoning addon (its data is read at login)
	-- SPEC7 4.1 / H11: Enhanced Flight Map support is removed; OpenMap stays optional
	ok(toc:find("## OptionalDeps: OpenMap\n", 1, true), "OptionalDeps: OpenMap only")
	ok(not toc:find("EnhancedFlightMap", 1, true), "no EnhancedFlightMap in the TOC")
end)

test("every Media file the Lua names exists (Media/fx too); every TGA uncompressed 32-bit, power of two, at most 1024", function()
	local missing = {}
	for _, file in ipairs((H.tocFiles("Wuber"))) do
		local t = readFile(WDIR .. "/" .. file) or ""
		for name in t:gmatch("Media\\\\([%w_\\]+)[\"']") do
			local path = name:gsub("\\\\", "/")
			if not (H.exists(WDIR .. "/Media/" .. path .. ".tga") or H.exists(WDIR .. "/Media/" .. path)) then missing[#missing + 1] = file .. ": " .. name end
		end
	end
	eq(#missing, 0, "missing media: " .. list(missing))
	-- (SPEC5 paths: no Unix find; Media and its folders listed through H.listFiles)
	local tgas = H.listFiles(WDIR .. "/Media", "tga")
	for _, sub in ipairs({ "fx", "fonts" }) do
		for _, f in ipairs(H.listFiles(WDIR .. "/Media/" .. sub, "tga")) do tgas[#tgas + 1] = f end
	end
	local bad, n, fxBytes = {}, 0, 0
	for _, path in ipairs(tgas) do
		n = n + 1
		local t = readFile(path)
		local idLen, imgType = t:byte(1), t:byte(3)
		local wd, ht, bpp, desc = t:byte(13) + t:byte(14) * 256, t:byte(15) + t:byte(16) * 256, t:byte(17), t:byte(18)
		local function pow2(x) return x >= 1 and x <= 1024 and math.floor(math.log(x) / math.log(2) + 0.5) == math.log(x) / math.log(2) end
		local whyBad
		if imgType ~= 2 then whyBad = "type " .. imgType .. " (want 2: uncompressed RGB)"
		elseif bpp ~= 32 then whyBad = bpp .. " bit"
		elseif not pow2(wd) or not pow2(ht) then whyBad = wd .. "x" .. ht .. " (power of two, at most 1024)"
		elseif desc % 16 ~= 8 then whyBad = "alpha bits " .. (desc % 16)
		elseif #t < 18 + idLen + wd * ht * 4 then whyBad = "truncated (" .. #t .. " bytes)" end
		if whyBad then bad[#bad + 1] = path:sub(#WDIR + 2) .. ": " .. whyBad end
		if path:find("/Media/fx/", 1, true) then fxBytes = fxBytes + #t end
	end
	ok(n > 0, "no TGA files")
	eq(#bad, 0, "bad TGA: " .. list(bad))
	-- (BRIEF16) + 4 MB: the Pioneer emblem's two 1024x512 atlases (violet and teal), loaded only when one shows
	ok(fxBytes <= 19 * 1024 * 1024, ("Media/fx is %.1f MB (budget about 18 MB: 9 MB violet + 5 MB founder gold + 4 MB Pioneer emblem)"):format(fxBytes / 1048576))
	if HAVE_FX then ok(fxBytes > 0, "FX.lua exists but Media/fx has no TGA sheets") end
end)

---------------------------------------------------------------------------
-- 13. Protocol: D badge/queue, R tier/rides, P; old peers both ways
---------------------------------------------------------------------------

test("D carries badge (12) and queue (13); the rider reads them; unknown badges show nothing", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	local ids = badgeIds(need(d.W.BADGES, "W.BADGES") and d.W)
	ok(#ids >= 4, "a few badges: " .. list(ids))
	d.W.Char().badge = ids[1]
	goOnline(d)
	local Ds = msgs(w, "D", ANITA, "CHANNEL")
	local f = fields(Ds[#Ds])
	eq(#f, 18, "18 fields (whisper fallback: 16 hears others on the channel, 17 internal realm; 18 starter list): " .. Ds[#Ds].text)
	eq(f[12], "H", "faction stays 12th of the wire (index 12)")
	eq(f[14], ids[1], "badge")
	eq(f[15], "0", "queue with nobody waiting")
	local x = r.W.drivers["anita lift"]
	eq(x.badge, ids[1], "the rider reads the badge")
	eq(x.queue, 0, "and the queue")
	-- an unknown or hostile badge shows nothing; a round-one beacon gets the defaults
	w:inject("Odd Lock", D({ badge = "crown", queue = 3 }), "CHANNEL")
	w:inject("Rude Lock", D({ badge = "|cffff0000x", queue = 999 }), "CHANNEL")
	w:inject("Old Lock", D({ ver = "1.0.0" }), "CHANNEL")
	w:advance(1)
	eq(r.W.drivers["odd lock"].badge, "", "\"crown\" is not a badge anyone can send")
	eq(r.W.drivers["odd lock"].queue, 3)
	eq(r.W.drivers["rude lock"].badge, "", "an unknown badge id")
	ok(r.W.drivers["rude lock"].queue <= 40, "queue clamped: " .. tostring(r.W.drivers["rude lock"].queue))
	eq(r.W.drivers["old lock"].badge, "", "round-one beacon: badge \"\"")
	eq(r.W.drivers["old lock"].queue, nil, "round-one beacon: queue nil")
	clean(w)
end)

test("a 15-field D with 32-byte dest and service stays under 255 bytes with every tail field", function()
	local w = newWorld({ realm = H.FOUNDER_REALM }) -- the D carries the internal realm, so the world names one (the game names none since build 71037)
	local d = driver(w)
	local r = rider(w)
	settle(w)
	local ids = badgeIds(need(d.W.BADGES, "W.BADGES") and d.W)
	d.W.Char().badge = ids[#ids]
	d.W.Char().service = ("Ü"):rep(40)
	goOnline(d)
	local f = fields(msgs(w, "D", ANITA)[#msgs(w, "D", ANITA)])
	eq(#f, 18, "every field kept")
	eq(f[18], "1", "starter list flag kept")
	eq(f[17], "CAMWOW EU5 Realm 5 PvE", "internal realm kept")
	eq(f[14], ids[#ids], "badge kept")
	eq(f[13], d.W.VERSION, "version kept")
	clean(w)
end)

test("R carries the rider's tier and rides; the driver clamps them; missing = tier 0", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	local rows = {}
	for i = 1, 12 do rows[i] = { "Bob Stone", "Undercity", 5000, i } end
	trips(r.W, rows)
	eq(need(r.W.Tier, "W.Tier")(), 2, "12 rides: Silver")
	r.W.RequestRide("anita lift")
	w:advance(1)
	local f = fields(msgs(w, "R", TESTCHAR)[1])
	eq(f[6], "2", "tier") eq(f[7], "12", "rides")
	local x = d.W.incoming[1]
	eq(x.tier, 2, "the driver reads the tier") eq(x.rides, 12, "and rides")
	w:addBot("Liar Guy") w:addBot("Old Guy")
	w:inject("Liar Guy", "R~1~ABCDEF~Ratchet~5000~99~123456", "WHISPER", d)
	w:inject("Old Guy", "R~1~GHIJKL~Ratchet~5000", "WHISPER", d)
	w:advance(1)
	for _, it in ipairs(d.W.incoming) do
		if it.buyerKey == "liar guy" then eq(it.tier, 3, "tier clamped") ok(it.rides <= 9999, "rides clamped") end
		if it.buyerKey == "old guy" then eq(it.tier, 0, "no tier: 0") eq(it.rides, nil, "no rides: nil") end
	end
	clean(w)
end)

-- the ride's queue position as the rider holds it (P)
local function position(r) local x = r.W.ride return x and (x.position or x.queuePos or x.place) end

test("P: queue position from the driver, coalesced, only from the ride's driver by whisper", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	d.W.AcceptRequest(d.W.incoming[1].id, 5)
	w:advance(1)
	local p0 = #msgs(w, "P", ANITA)
	local Q = need(d.env.WuberAPI.Queue, "WuberAPI.Queue")
	Q(ride.id, TESTCHAR, 2, 60)
	Q(ride.id, TESTCHAR, 2, 60) -- the same place again: not sent again
	w:advance(2)
	local P = msgs(w, "P", ANITA, "WHISPER")
	eq(#P, p0 + 1, "one P for place 2")
	local f = fields(P[#P])
	eq(f[3], ride.id) eq(f[4], "2") eq(f[5], "60")
	eq(position(r), 2, "the rider holds place 2")
	if HAVE_UI then
		r.W.UI.Show("home")
		w:advance(2.5)
		ok(#r:findText("2nd in line") > 0, "\"You're 2nd in line\" (" .. texts(r) .. ")")
	end
	-- from a stranger, on the channel, or for another ride: ignored
	w:addBot("Evil Guy")
	w:inject("Evil Guy", "P~1~" .. ride.id .. "~1~5", "WHISPER", r)
	w:inject(ANITA, "P~1~" .. ride.id .. "~1~5", "CHANNEL")
	w:inject(ANITA, "P~1~ZZZZZZ~1~5", "WHISPER", r)
	w:advance(1)
	eq(position(r), 2, "P from a non-driver / channel / other ride ignored")
	Q(ride.id, TESTCHAR, 1, 20)
	w:advance(2)
	eq(#msgs(w, "P", ANITA), p0 + 2, "a new place: sent")
	eq(position(r), 1)
	clean(w)
end)

-- (SPEC5 pending, review #30) deleted, superseded by the 2.0 engine: "Driver.lua tells a waiting rider its place with P (the same path as WuberAPI.Queue)"
--   covered by round4 "drive: Wuber: riders waiting are told their place and the wait, by one window, as it changes"

---------------------------------------------------------------------------
-- 14. Old peers (round one, as installed) work both ways
---------------------------------------------------------------------------

test("old peers: a round-one rider (installed 1.0 code) rides with a round-two driver", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w, TESTCHAR, { addonDirs = ROUND1 })
	settle(w)
	eq(r.W.VERSION, "1.0.0", "the round-one code")
	local ids = badgeIds(d.W)
	if ids[1] then d.W.Char().badge = ids[1] end
	goOnline(d)
	ok(r.W.drivers["anita lift"], "the old rider sees the new driver (extra fields ignored)")
	eq(r.W.drivers["anita lift"].price, 5000)
	local ride = r.W.RequestRide("anita lift")
	ok(ride, "requested")
	w:advance(1)
	eq(#d.W.incoming, 1, "the new driver takes a 5-field R")
	eq(d.W.incoming[1].tier, 0, "tier defaults to 0")
	T.take(d)
	w:advance(2)
	ok(r.W.RIDE_RANK[rideState(r)] >= 2, "accepted: " .. tostring(rideState(r)))
	clean(w)
end)

test("old peers: a round-two rider rides with a round-one driver (installed 1.0 code)", function()
	local w = newWorld()
	local d = driver(w, ANITA, { addonDirs = ROUND1 })
	local r = rider(w)
	settle(w)
	goOnline(d)
	local x = r.W.drivers["anita lift"]
	ok(x, "seen")
	eq(x.badge, "", "no badge") eq(x.queue, nil, "no queue")
	r.W.RequestRide("anita lift")
	w:advance(1)
	eq(#d.W.incoming, 1, "the old driver takes a 7-field R")
	T.take(d)
	w:advance(3)
	ok(r.W.RIDE_RANK[rideState(r)] >= 2, "accepted: " .. tostring(rideState(r)))
	eq(position(r), nil, "no P: no position line")
	if HAVE_UI then
		r.W.UI.Show("home")
		w:advance(2.5)
		eq(#r:findText("in line"), 0, "no \"in line\" without P")
	end
	clean(w)
end)

test("old peers: round-one wire (stripped fields) both ways with round-two code", function()
	local w = newWorld()
	local d = driver(w, ANITA, { roundOne = true })
	local r = rider(w, TESTCHAR, { roundOne = true })
	local r2 = rider(w, BOB, { spot = "Undercity" })
	settle(w)
	goOnline(d)
	ok(d.stripped and d.stripped > 0, "the driver's D was stripped")
	ok(r.W.drivers["anita lift"] and r2.W.drivers["anita lift"], "both riders see it")
	r.W.RequestRide("anita lift")
	w:advance(1)
	eq(#d.W.incoming, 1)
	T.take(d)
	w:advance(2)
	ok(r.W.RIDE_RANK[rideState(r)] >= 2, "accepted")
	clean(w)
end)

test("old peers: a round-one driver at a custom spot still gets a ride (destWire in R and the whisper)", function()
	local w = newWorld()
	local d = driver(w, ANITA, { addonDirs = ROUND1 })
	w:placePlayer(w:player(ANITA), { mapID = 1413, x = 0.40, y = 0.80, zone = "Lushwater Oasis", sub = "" })
	local r = rider(w)
	settle(w)
	goOnline(d)
	local beacon = fields(msgs(w, "D", ANITA)[1])
	local wire = beacon[3]
	local x = r.W.drivers["anita lift"]
	ok(x, "seen")
	eq(x.destWire, wire, "destWire is the driver's own dest")
	ok(x.dest ~= nil and x.dest ~= "", "a display dest: " .. tostring(x.dest))
	local ride = r.W.RequestRide("anita lift")
	ok(ride, "requested")
	w:advance(1)
	eq(fields(msgs(w, "R", TESTCHAR)[1])[4], wire, "R carries the wire dest")
	eq(#d.W.incoming, 1)
	T.take(d)
	w:advance(2)
	ok(r.W.RIDE_RANK[rideState(r)] >= 2, "accepted")
	clean(w)
end)

---------------------------------------------------------------------------
-- 15. Anti-spam
---------------------------------------------------------------------------

local SPAM = { "WTS GOLD 1000", "cheap boost", "g o l d", "www goldshop", "http summons", "buy now", "Lock 12345", "Summons dot com",
	"wtb portal", "gold", "usd rates", "best eur price", "sell sell", "Discount Ports", "Port net", "abc org", "x y Lock", "Summon com" }
local CLEAN = { "Orgrimmar Express", "Goldshire Cabs", "Wuber Network", "Anita's Rides", "Fast Lock-Taxi", "Ritual 24", "Wuber" }

test("spam filter: W.SPAM_WORDS, and gold-sellers' services become the driver's name", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	local words = need(r.W.SPAM_WORDS, "W.SPAM_WORDS")
	local have = {}
	for k, v in pairs(words) do have[type(k) == "string" and k:lower() or tostring(v):lower()] = true end
	for _, wd in ipairs({ "gold", "wts", "wtb", "www", "http", "com", "net", "org", "cheap", "sell", "buy", "discount", "boost", "usd", "eur", "dot" }) do
		ok(have[wd], "W.SPAM_WORDS has " .. wd)
	end
	need(r.W.CleanService, "W.CleanService")
	for i, svc in ipairs(SPAM) do
		local name = "Spam Lock" .. string.char(96 + i)
		w:inject(name, D({ service = svc }), "CHANNEL")
	end
	for i, svc in ipairs(CLEAN) do
		w:inject("Good Lock" .. string.char(96 + i), D({ service = svc }), "CHANNEL")
	end
	w:inject("Long Lock", D({ service = "Wonderful Summoning Services Of Azeroth" }), "CHANNEL")
	w:inject("Odd Lock", D({ service = "Fun!Rides #1" }), "CHANNEL")
	w:advance(1)
	for i, svc in ipairs(SPAM) do
		local name = "Spam Lock" .. string.char(96 + i)
		local x = r.W.drivers[key(name)]
		ok(x, name .. " listed")
		eq(x.service, name, "\"" .. svc .. "\" replaced by the driver's full name")
	end
	for i, svc in ipairs(CLEAN) do
		local x = r.W.drivers[key("Good Lock" .. string.char(96 + i))]
		eq(x and x.service, svc, "\"" .. svc .. "\" passes")
	end
	local long = r.W.drivers["long lock"].service
	ok(#long <= 24, "at most 24 characters: " .. long)
	local odd = r.W.drivers["odd lock"].service
	ok(odd:match("^[%w '%-]*$"), "letters, digits, spaces, ' and - only: " .. odd)
	clean(w)
end)

test("dest filter: places, aliases and the driver's zone pass; free text becomes the place there or Unknown", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	need(r.W.ValidDest, "W.ValidDest")
	w:inject("Dest Locka", D({ dest = "Ratchet" }), "CHANNEL")
	w:inject("Dest Lockb", D({ dest = "ratchet docks" }), "CHANNEL")
	w:inject("Dest Lockc", D({ dest = "The Barrens", x = 300, y = 600 }), "CHANNEL")
	w:inject("Dest Lockd", D({ dest = "WTS GOLD cheap www" }), "CHANNEL")
	w:inject("Dest Locke", D({ dest = "Buy my stuff", mapID = 0, x = 0, y = 0 }), "CHANNEL")
	w:advance(1)
	local function dest(n) local x = r.W.drivers[key(n)] return x and x.dest end
	eq(dest("Dest Locka"), "Ratchet")
	eq(dest("Dest Lockb"), "Ratchet", "an alias shows as the place")
	eq(dest("Dest Lockc"), "The Barrens", "the zone of the driver's map")
	eq(dest("Dest Lockd"), "Ratchet", "free text: the place at (1413, 0.627, 0.370)")
	eq(dest("Dest Locke"), "Unknown", "free text, no map: Unknown")
	clean(w)
end)

test("Hide this driver: W.HideDriver keeps them off cards, pins and the list (W.db.hidden)", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	need(r.W.HideDriver, "W.HideDriver")("anita lift")
	eq(r.W.db.hidden["anita lift"], true, "W.db.hidden by key")
	d.env.WuberAPI.Beacon()
	w:advance(70)
	for _, x in ipairs(r.W.DriversSorted()) do ok(x.key ~= "anita lift", "hidden from W.DriversSorted") end
	w:openMap(r, 1413)
	w:advance(0.5)
	eq(#pins(r), 0, "no pin")
	if HAVE_UI then
		r.W.UI.Show("home")
		w:advance(2.5)
		eq(#r:findText("Anita"), 0, "no card (" .. texts(r) .. ")")
	end
	clean(w)
end)

---------------------------------------------------------------------------
-- 16. Creator, prominence and sorting
---------------------------------------------------------------------------

test("creator: only W.CREATOR names, never claimable; W.Prominence and the tie-break in W.DriversSorted", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	local r = rider(w)
	settle(w)
	ok(r.W.IsCreator("Anita Lift") and r.W.IsCreator("Wuber Rocks") and not r.W.IsCreator("Wuber TestCharacter"), "W.IsCreator")
	local prom = need(r.W.Prominence, "W.Prominence")
	w:inject("Aaron Ash", D({ price = 5000, service = "Anita Lift" }), "CHANNEL")
	w:inject(ANITA, D({ price = 5000, service = "Wuber" }), "CHANNEL")
	w:inject(BOB, D({ price = 9000 }), "CHANNEL")
	w:inject("Cal Brown", D({ price = 6000, state = "busy" }), "CHANNEL")
	w:inject("Evil Guy", D({ price = 5000, badge = "crown", service = "Anita Lift" }), "CHANNEL")
	w:advance(1)
	local function P(k) local g, c = prom(r.W.drivers[k]) return g, c end
	local ga, ca = P("anita lift")
	eq(ga, 1, "the creator glows 1.0") eq(ca, true, "isCreator")
	local gAaron, cAaron = P("aaron ash")
	local gBob = P("bob stone")
	local gCal = P("cal brown")
	local _, cEvil = P("evil guy")
	ok(not cAaron and not cEvil, "nobody else is the creator (service or badge claims nothing)")
	ok(gAaron > gBob, ("cheaper glows more: %.2f > %.2f"):format(gAaron, gBob))
	ok(gCal <= 0.7, "a busy driver at most 0.7: " .. gCal)
	for k, x in pairs(r.W.drivers) do
		if k ~= "anita lift" then ok(prom(x) < 1, k .. " below the creator: " .. prom(x)) end
	end
	local order = {}
	for i, x in ipairs(r.W.DriversSorted()) do order[x.key] = i end
	ok(order["anita lift"] < order["aaron ash"], "the creator first among equal price")
	ok(order["aaron ash"] < order["bob stone"], "then cheapest")
	clean(w)
end)

---------------------------------------------------------------------------
-- 17. Travel time saved and its value
---------------------------------------------------------------------------

test("W.TravelSaved: same continent (flight model), cross-continent (zeppelin), nil when unreadable or near", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	local TS = need(r.W.TravelSaved, "W.TravelSaved")
	need(r.W.WorldPos, "W.WorldPos (Places.lua)")
	local pr, po = place(r.W, "Ratchet"), place(r.W, "Orgrimmar")
	local p = w:player(TESTCHAR)
	local dist = worldDist(p.mapID, p.x, p.y, pr.mapID, pr.x, pr.y)
	local want = math.max(60, math.min(2400, dist * 1.35 / 32 + 60))
	local got = TS("Ratchet")
	ok(type(got) == "number", "a number: " .. tostring(got))
	ok(math.abs(got - want) <= want * 0.15 + 15, ("Orgrimmar -> Ratchet: %d s, model %d s"):format(got, want))
	local uc = TS("Undercity")
	ok(type(uc) == "number" and uc >= 240 + 60 and uc <= 2400, "Orgrimmar -> Undercity by zeppelin: " .. tostring(uc))
	ok(TS("Undercity") > 240, "never subtracts across continents")
	-- standing at the place: nothing saved
	w:move(TESTCHAR, "Ratchet")
	w:advance(1)
	eq(TS("Ratchet"), nil, "under ~400 yards / 2 minutes: nil")
	-- in an instance / unreadable
	p.inInstance = true
	eq(TS("Orgrimmar"), nil, "in an instance: nil")
	p.inInstance = nil
	r:secret("C_Map")
	eq(TS("Orgrimmar"), nil, "secret positions: nil")
	r:unsecret()
	eq(TS("Nowhere At All"), nil, "unknown dest: nil")
	clean(w)
end)

test("W.TimeValue: 10g an hour by default (W.db.timeValue), and the setting changes it", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	local TV = need(r.W.TimeValue, "W.TimeValue")
	eq(r.W.db.timeValue, 100000, "default 10g/h")
	eq(TV(3600), 100000)
	ok(math.abs(TV(840) - 23333) <= 100, "14 min = about 2g 33s: " .. TV(840))
	r.W.db.timeValue = 500000
	eq(TV(3600), 500000, "the setting is used")
	clean(w)
end)

test("travel saved is worked out at request time and kept with the ride and the trip", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	r.W.db.autoAccept = false -- this test clicks Wuber's Accept invite button
	goOnline(d)
	local ride = r.W.RequestRide("anita lift")
	ok(type(ride.saved) == "number" and ride.saved > 60, "ride.saved: " .. tostring(ride.saved))
	ok(ride.fromZone, "ride.fromZone")
	eq(r.W.db.ride and r.W.db.ride.saved, ride.saved, "persisted in W.db.ride")
	w:advance(1)
	T.take(d)
	w:advance(1)
	if HAVE_UI then r.W.UI.Toggle(true) w:advance(2.5) end
	r:clickText("Accept invite")
	w:advance(1)
	w:summon(d, TESTCHAR)
	w:advance(1)
	r:clickText("Accept summon")
	w:advance(3)
	w:openTrade(d, r)
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(2)
	eq(rideState(r), "done")
	local trip = r.W.db.rides[#r.W.db.rides]
	eq(trip.saved, ride.saved, "trip.saved")
	ok(type(trip.savedValue) == "number", "trip.savedValue at the rate then")
	ok(trip.fromZone, "trip.fromZone")
	clean(w)
end)

---------------------------------------------------------------------------
-- 18. Stats, milestones and levels
---------------------------------------------------------------------------

test("W.Stats: rides, places, spent, saved, favourite driver, first ride", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	trips(r.W, { { ANITA, "Ratchet", 5000, 3, 19, 600 }, { ANITA, "Undercity", 7000, 2, 19, 900 }, { BOB, "Ratchet", 6000, 0, 19, 300 } })
	local st = need(r.W.Stats, "W.Stats")()
	eq(st.rides, 3) eq(st.places, 2) eq(st.spent, 18000) eq(st.saved, 1800)
	ok(st.savedValue and st.savedValue >= 0, "savedValue")
	ok(st.favouriteDriver == ANITA or st.favouriteDriver == "anita lift", "favourite driver: " .. tostring(st.favouriteDriver))
	eq(st.firstAt, H.EPOCH - 3 * 86400, "first ride")
	ok(type(st.streakDays) == "number", "streakDays")
	clean(w)
end)

test("W.Tier: Bronze from 3 rides, Silver from 10, Gold from 25", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	local tier = need(r.W.Tier, "W.Tier")
	for _, c in ipairs({ { 2, 0 }, { 3, 1 }, { 9, 1 }, { 10, 2 }, { 24, 2 }, { 25, 3 }, { 90, 3 } }) do
		noTrips(r.W)
		local rows = {}
		for i = 1, c[1] do rows[i] = { BOB, "Ratchet", 5000, 0 } end
		trips(r.W, rows)
		eq(tier(), c[2], c[1] .. " rides")
	end
	clean(w)
end)

test("milestones: the list, earned once, MILESTONE fired once; a tier-up on the same ride is one event", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	local M = need(r.W.MILESTONES, "W.MILESTONES")
	local names = {}
	for _, m in ipairs(M) do
		ok(m.id and m.name and type(m.test) == "function", "milestone fields id, name, test")
		names[m.name] = true
	end
	for _, n in ipairs({ "First Ride", "Explorer", "Globetrotter", "World Walker", "Hour Saver", "Day Saver", "Loyal", "Night Owl", "Weekend Warrior" }) do
		ok(names[n], "milestone " .. n .. " (" .. list((function() local t = {} for k in pairs(names) do t[#t + 1] = k end return t end)()) .. ")")
	end
	ok(#M >= 14, "at least 14 milestones: " .. #M)
	local check = need(r.W.CheckMilestones, "W.CheckMilestones")
	local t0 = w.time
	trips(r.W, { { ANITA, "Ratchet", 5000, 0 } })
	check()
	eq(fired(r, "MILESTONE", t0), 1, "First Ride: one MILESTONE")
	eq(count(r.W.db.milestones), 1, "stored")
	check()
	eq(fired(r, "MILESTONE", t0), 1, "not again")
	-- rides 2..9 (5 Rides and Bronze on the way), then the 10th: Silver and 10 Rides together
	local rows = {}
	for i = 2, 9 do rows[#rows + 1] = { ANITA, "Ratchet", 5000, 0 } end
	trips(r.W, rows)
	check()
	local t1 = w.time + 0.001
	w:advance(1)
	trips(r.W, { { ANITA, "Ratchet", 5000, 0 } })
	check()
	eq(fired(r, "MILESTONE", t1), 1, "10th ride: Silver + 10 Rides = one event")
	-- Night Owl (a ride at 02:00) and Weekend Warrior (Sat and Sun: 14 and 15 Nov 2026)
	noTrips(r.W)
	r.W.db.milestones = {}
	r.W.AddTrip({ at = os.time({ year = 2026, month = 11, day = 14, hour = 2 }), driver = ANITA, dest = "Ratchet", price = 5000, stars = 5 })
	r.W.AddTrip({ at = os.time({ year = 2026, month = 11, day = 15, hour = 14 }), driver = ANITA, dest = "Ratchet", price = 5000, stars = 5 })
	check()
	local earned = {}
	for _, m in ipairs(M) do if r.W.db.milestones[m.id] then earned[m.name] = true end end
	ok(earned["Night Owl"], "Night Owl")
	ok(earned["Weekend Warrior"], "Weekend Warrior")
	clean(w)
end)

test("milestones: first load with old trips backfills silently (no MILESTONE, no pop)", function()
	local w = newWorld()
	local rides = {}
	for i = 1, 30 do rides[i] = { at = H.EPOCH - i * 3600, driver = ANITA, dest = (i % 3 == 0) and "Undercity" or "Ratchet", price = 5000, stars = 5 } end
	local r = rider(w, TESTCHAR, { saved = { Wuber = { rides = rides } } })
	settle(w)
	if HAVE_UI then r.W.UI.Toggle(true) w:advance(3) end
	ok(count(r.W.db.milestones or {}) >= 4, "earned ones stored: " .. count(r.W.db.milestones or {}))
	eq(fired(r, "MILESTONE"), 0, "no MILESTONE on the first load")
	clean(w)
end)

---------------------------------------------------------------------------
-- 19. Favourites, watch, toasts, Your usual
---------------------------------------------------------------------------

-- toasts are collected for 4 s, then fired as one event
local TOAST_WAIT = 5

local function toastKeyFor(W, k)
	for what, t in pairs(W.db.toastAt) do if tostring(what):find(k, 1, true) then return what, t end end
end

test("favourites: \"Anita is online\" once per 10 minutes (W.db.toastAt), not in combat", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	r.W.db.favs["anita lift"] = true
	local t0 = w.time
	goOnline(d)
	local seen = false
	for _ = 1, 16 do
		w:advance(0.5)
		if HAVE_UI and #r:findText("Anita.-online") > 0 then seen = true end
	end
	eq(fired(r, "FAV_ONLINE", t0), 1, "a toast event")
	local what, at = toastKeyFor(r.W, "anita lift")
	ok(what, "a W.db.toastAt entry for anita lift")
	ok(at > 1e9, "saved with time(), not GetTime(): " .. tostring(at))
	if HAVE_UI then ok(seen, "the toast reads \"Anita ... online\"") end
	d.W.Driver.SetOnline(false)
	w:advance(60)
	goOnline(d)
	w:advance(TOAST_WAIT)
	eq(fired(r, "FAV_ONLINE", t0), 1, "not again within 10 minutes")
	d.W.Driver.SetOnline(false)
	w:advance(600)
	w:enterCombat(r)
	goOnline(d)
	w:advance(TOAST_WAIT)
	eq(fired(r, "FAV_ONLINE", t0), 1, "none in combat")
	w:leaveCombat(r)
	w:advance(TOAST_WAIT)
	eq(fired(r, "FAV_ONLINE", t0), 2, "after 10 minutes, out of combat (held until combat ends)")
	clean(w)
end)

test("favourites: three online at login make one merged toast (\"3 favourites online\")", function()
	local w = newWorld()
	local ds = { driver(w, ANITA), driver(w, BOB, { spot = "Crossroads" }), driver(w, "Cal Brown", { spot = "Crossroads" }) }
	settle(w)
	for _, d in ipairs(ds) do goOnline(d, { wait = 0 }) end
	w:advance(5)
	local r = rider(w, TESTCHAR, { saved = { Wuber = { favs = { ["anita lift"] = true, ["bob stone"] = true, ["cal brown"] = true } } } })
	local seen, events = false, 0
	for _ = 1, 60 do
		w:advance(0.5)
		if #r:findText("3 favourites") > 0 then seen = true end
	end
	events = fired(r, "FAV_ONLINE")
	ok(events >= 1 and events <= 1, "one merged FAV_ONLINE, got " .. events)
	if HAVE_UI then ok(seen, "\"3 favourites online\" shown") end
	clean(w)
end)

test("favourites: only open drivers of our faction", function()
	local w = newWorld()
	local d = driver(w)
	local d2 = driver(w, "Ally Lock", { faction = "Alliance" })
	local r = rider(w)
	settle(w)
	r.W.db.favs["anita lift"] = true
	r.W.db.favs["ally lock"] = true
	goOnline(d2)
	w:advance(TOAST_WAIT)
	eq(fired(r, "FAV_ONLINE"), 0, "the other faction: no toast")
	w:inject(ANITA, D({ state = "paused" }), "CHANNEL")
	w:advance(TOAST_WAIT)
	eq(fired(r, "FAV_ONLINE"), 0, "paused: no toast")
	clean(w)
end)

test("watch: \"tell me when a driver to X comes online\" (W.db.watch) -> WATCH_HIT once", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	r.W.db.watch[r.W.NormPlace and r.W.NormPlace("Ratchet") or "ratchet"] = true
	goOnline(d)
	w:advance(TOAST_WAIT)
	eq(fired(r, "WATCH_HIT"), 1, "WATCH_HIT")
	d.env.WuberAPI.Beacon()
	w:advance(70)
	eq(fired(r, "WATCH_HIT"), 1, "once")
	clean(w)
end)

test("W.Usual: the most frequent driver and dest; Home's \"Your usual\" only while that driver is online", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	trips(r.W, { { ANITA, "Ratchet", 5000, 3 }, { ANITA, "Ratchet", 5000, 2 }, { ANITA, "Ratchet", 5000, 1 }, { BOB, "Undercity", 5000, 0 } })
	local u = need(r.W.Usual, "W.Usual")()
	ok(type(u) == "table", "a table")
	local found = {}
	for _, v in pairs(u) do found[tostring(v)] = true end
	ok(found["Ratchet"], "dest Ratchet") ok(found["anita lift"] or found[ANITA], "driver Anita")
	if HAVE_UI then
		r.W.UI.Show("home")
		w:advance(2.5)
		eq(#findCI(r, "Ride again"), 0, "no card while Anita is offline")
		-- (word rule) no "Your usual ... nobody's there" line while nobody is listed: the empty screen's own controls say it
		eq(#findCI(r, "Your usual: Ratchet"), 0, "no usual note while nobody is listed (" .. texts(r) .. ")")
		ok(#findCI(r, "Tell me") > 0, "the bell for the usual place shows (" .. texts(r) .. ")")
		do -- "Ping drivers" is the main button at the foot of the page: the lines sit above it
			local p = findCI(r, "Ping drivers")[1]
			local why = findCI(r, "Why?")[1]
			ok(p and why and p:GetTop() <= why:GetBottom(), "Ping drivers is under Why?")
		end
		goOnline(d)
		r.W.UI.Show("home")
		w:advance(2.5)
		ok(#findCI(r, "Ride again") > 0, "Your usual (" .. texts(r) .. ")")
		eq(#findCI(r, "nobody's there right now"), 0, "no note while the card shows")
		-- the driver now serves another place: the card goes, so Ride again can never book the old one
		local rd = r.W.drivers[r.W.Key(ANITA)] or r.W.drivers[ANITA]
		ok(rd, "rider knows the driver")
		if rd then
			local was = rd.dest
			rd.dest = (was == "Orgrimmar") and "Thunder Bluff" or "Orgrimmar"
			r.W.UI.Show("home")
			w:advance(2.5)
			eq(#findCI(r, "Ride again"), 0, "not while the driver serves " .. rd.dest .. " (" .. texts(r) .. ")")
			ok(#findCI(r, "nobody's there right now") > 0, "note instead of the card")
			-- (review) never while the rider is an open driver too
			local realBeacon = r.W.DriverBeacon
			r.W.DriverBeacon = function()
				return { state = "open", dest = "Orgrimmar", price = 5000, service = "summon", team = 1, seats = 1, mapID = 1 }
			end
			r.W.UI.Show("home")
			w:advance(2.5)
			local noted = #findCI(r, "nobody's there right now")
			r.W.DriverBeacon = realBeacon
			eq(noted, 0, "no note while open as a driver (" .. texts(r) .. ")")
		end
	end
	clean(w)
end)

test("E1: the public-chat warning opens centred on the open phone, inside it, in larger text", function()
	local w = newWorld()
	local d = driver(w)
	settle(w)
	if not HAVE_UI then clean(w) return end
	d.W.UI.Show("home")
	w:advance(1)
	local phone = d.env.WuberFrame
	ok(phone and phone:IsShown(), "the phone is open")
	local DR = d.W.Drive
	eq(DR.SetAutoPublic(true, function() end), "asked")
	local dlg = d.env.StaticPopupDialogs[DR.PUBLIC_POPUP]
	ok(type(dlg.OnShow) == "function", "the popup places itself when shown")
	local pop = d.env.CreateFrame("Frame", "WuberTestPopup", d.env.UIParent)
	pop:SetSize(320, 120)
	pop:SetPoint("TOP", d.env.UIParent, "TOP", 0, -100)
	pop.text = pop:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	dlg.OnShow(pop)
	local p, rel, rp = pop:GetPoint(1)
	eq(p, "CENTER", "centred")
	ok(rel == phone and rp == "CENTER", "on the phone, not the top-left of the screen")
	ok(pop:GetWidth() <= phone:GetWidth() - 32, "inside the phone (" .. pop:GetWidth() .. " in " .. phone:GetWidth() .. ")")
	eq(pop.text:GetWidth(), pop:GetWidth() - 40, "text wraps inside the box")
	d.env.StaticPopup_Hide(DR.PUBLIC_POPUP)
	dlg.OnCancel()
	clean(w)
end)

---------------------------------------------------------------------------
-- 20. Settings defaults, self-test, slash commands
---------------------------------------------------------------------------

test("settings defaults (W.DEFAULTS) and SETTINGS events", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	local db = r.W.db
	eq(db.fx, "full") eq(db.plates, true) eq(db.timeValue, 100000) eq(db.coach, false)
	for _, k in ipairs({ "favs", "watch", "hidden", "milestones", "toastAt" }) do eq(type(db[k]), "table", k) end
	eq(db.sound, true, "sound keeps its name") eq(db.mapPins, true, "mapPins keeps its name")
	clean(w)
end)

test("W.SelfTest runs clean and returns results", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	local res = need(r.W.SelfTest, "W.SelfTest")()
	ok(type(res) == "table" and (#res > 0 or next(res) ~= nil), "results")
	clean(w)
end)

test("/wuber and /ride only open and close; /wuber help opens Settings; old subcommands print nothing new", function()
	local w = newWorld()
	local d = driver(w)
	local old = driver(w, BOB, { addonDirs = ROUND1, spot = "Crossroads" })
	settle(w)
	for _, line in ipairs({ "/wuber", "/wuber", "/ride", "/ride" }) do
		local n = #d.chatLines
		d:slash(line)
		w:advance(1)
		eq(#d.chatLines, n, line .. " printed: " .. list(d.chatLines, " / "))
	end
	local n = #d.chatLines
	d:slash("/wuber help")
	w:advance(1)
	eq(#d.chatLines, n, "/wuber help printed: " .. list(d.chatLines, " / "))
	if HAVE_UI then ok(#d:findText("Settings") > 0, "/wuber help opens Settings (" .. texts(d) .. ")") end
	for _, line in ipairs({ "/wuber ping", "/wuber map", "/wuber map", "/wuber minimap", "/wuber minimap", "/wuber status", "/wuber price 1g",
		"/wuber drive", "/wuber drive off", "/wuber nonsense" }) do
		local a, b = #d.chatLines, #old.chatLines
		d:slash(line) old:slash(line)
		w:advance(1)
		ok(#d.chatLines - a <= #old.chatLines - b, line .. " prints more than 1.0 did: " .. list({ unpack(d.chatLines, a + 1) }, " / "))
		for i = a + 1, #d.chatLines do ok(not d.chatLines[i]:find("/wuber %a"), "no command list: " .. d.chatLines[i]) end
	end
	clean(w)
end)

---------------------------------------------------------------------------
-- 21. Effects (FX.lua)
---------------------------------------------------------------------------

local function needFX(c)
	ok(HAVE_FX, "Wuber's FX code (FX.lua or FX/*.lua) is not in the TOC")
	local FX = need(c.W.FX, "W.FX")
	for _, f in ipairs({ "Play", "Fullscreen", "Flipbook", "Crown", "Badge" }) do need(FX[f], "W.FX." .. f) end
	return FX
end

-- visible textures that show an effect sheet (Media\fx\...)
local function fxShown(c, part)
	local out = {}
	for _, t in ipairs(texturesWith(c, "media\\fx\\", true)) do
		if not part or S[t].texture:lower():find(part, 1, true) then out[#out + 1] = t end
	end
	return out
end

-- crowns and badges (cards, pins, plates, the founder's own crown) are not screen moments
local function isToken(t)
	local p = S[t].texture:lower()
	return p:find("fx\\crown", 1, true) or p:find("fx\\badges", 1, true)
end

-- the top frame under UIParent that holds a region
local function topFrame(c, obj)
	local f = obj
	while S[f].parent and S[f].parent ~= c.env.UIParent do f = S[f].parent end
	return f
end

local function underWindow(c, obj)
	local win = c.env.WuberFrame
	local f = obj
	while f do
		if f == win then return true end
		f = S[f].parent
	end
	return false
end

-- textures showing a sheet outside the Wuber window (screen effects)
local function screenFx(c, part)
	local out = {}
	for _, t in ipairs(fxShown(c, part)) do if not underWindow(c, t) and (part or not isToken(t)) then out[#out + 1] = t end end
	-- (nameplate crowns are not screen effects)
	local onPlates = {}
	for _, f in ipairs(c:plateFramesShown()) do for _, d in ipairs(descendants(f)) do onPlates[d] = true end end
	local res = {}
	for _, t in ipairs(out) do if not onPlates[t] then res[#res + 1] = t end end
	return res
end

local function sumTexCoords(list)
	local n = 0
	for _, t in ipairs(list) do n = n + (S[t].texCoordSets or 0) end
	return n
end

test("FX: no effect sheet is loaded before the first play (lazy)", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	needFX(r)
	for path in pairs(r.texturePaths) do
		ok(not path:lower():find("media\\fx\\", 1, true), "an effect sheet set at login: " .. path .. " (first at " .. tostring(r.textureWhere[path]) .. ")")
	end
	clean(w)
end)

-- a playing FlipBook animation on a frame or its children (the client's own page turner)
local function nativeFlipbook(f)
	for _, x in ipairs({ f, unpack(descendants(f)) }) do
		for _, g in ipairs(S[x].animGroups or {}) do
			if g:IsPlaying() then
				for _, a in ipairs(S[g].anims) do if S[a].otype == "FlipBook" then return g, a end end
			end
		end
	end
end

for _, mode in ipairs({ "with the FlipBook animation", "without it (frames stepped by hand)" }) do
	test("FX: a crown flipbook turns pages while shown, not while hidden (" .. mode .. ")", function()
		local native = mode:find("with the") ~= nil
		local w = newWorld({ noFlipBook = not native, frameStep = 0.02 }) -- 50 frames a second
		local r = rider(w)
		settle(w)
		local FX = needFX(r)
		local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
		holder:SetSize(64, 64) holder:SetPoint("CENTER")
		local crown = FX.Crown(holder, 48)
		ok(crown, "W.FX.Crown returns a frame")
		w:advance(0.5)
		local tex = {}
		for _, d in ipairs(descendants(crown)) do if S[d].otype == "Texture" and type(S[d].texture) == "string" then tex[#tex + 1] = d end end
		ok(#tex >= 1, "the crown shows a texture")
		ok(#fxShown(r, "crown") >= 1, "a crown sheet (Media\\fx\\crown)")
		local g, a = nativeFlipbook(crown)
		if native and g then
			ok((S[a].SetFlipBookFrames or 0) >= 16, "FlipBook frames set: " .. tostring(S[a].SetFlipBookFrames))
			ok((S[a].SetFlipBookRows or 0) >= 1 and (S[a].SetFlipBookColumns or 0) >= 1, "rows and columns")
		else
			ok(not native or not g, "")
			local a0 = sumTexCoords(tex)
			w:advance(2)
			local steps = sumTexCoords(tex) - a0
			ok(steps >= 24 and steps <= 44, "frames stepped in 2 s: " .. steps .. " (15-20 fps)")
			holder:Hide()
			w:advance(0.2)
			a0 = sumTexCoords(tex)
			w:advance(2)
			eq(sumTexCoords(tex) - a0, 0, "no stepping while hidden")
			holder:Show()
		end
		eq(native and g ~= nil or not native, true, "with the FlipBook animation available, use it")
		for _, t in ipairs(fxShown(r, "fx\\crown")) do
			eq(t:GetBlendMode(), "BLEND", "the crown sheet blends BLEND (edge-dilated)")
		end
		clean(w)
	end)
end

test("FX: Play/Stop 40 times reuses pooled frames; handles stop", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	local FX = needFX(r)
	local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	holder:SetSize(200, 200) holder:SetPoint("CENTER")
	local h = FX.Play("milestone", holder)
	ok(h and type(h.Stop) == "function", "a handle with :Stop()")
	h:Stop()
	local function burst(n)
		for _ = 1, n do
			local x = FX.Play("milestone", holder)
			w:advance(0.1)
			if x then x:Stop() end
		end
		w:advance(3)
	end
	burst(40)
	local n0 = #r.frames
	burst(40)
	eq(#r.frames - n0, 0, "frames made for 40 more plays (pooled)")
	eq(#fxShown(r, "milestone"), 0, "stopped plays are hidden")
	clean(w)
end)

test("FX: Fullscreen is click-through, below the window, at most 0.7 alpha, short, and never in combat", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	local FX = needFX(r)
	if HAVE_UI then r.W.UI.Toggle(true) w:advance(2.5) end
	FX.Fullscreen("portal_open")
	w:advance(0.2)
	local shown = screenFx(r)
	ok(#shown >= 1, "a screen effect shows")
	local STR = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
	for _, t in ipairs(shown) do
		local f = S[t].parent
		while f and f ~= r.env.UIParent do
			ok(not S[f].mouse, "an effect frame takes the mouse: " .. tostring(f))
			f = S[f].parent
		end
		local top = topFrame(r, t)
		local st = STR[top:GetFrameStrata()]
		ok(st <= 3, "strata LOW/MEDIUM: " .. top:GetFrameStrata())
		if HAVE_UI then
			local ws = STR[r.env.WuberFrame:GetFrameStrata()]
			ok(st < ws or (st == ws and top:GetFrameLevel() < r.env.WuberFrame:GetFrameLevel()), "below WuberFrame")
		end
		ok(t:GetEffectiveAlpha() <= 0.71, "alpha at most 0.7: " .. t:GetEffectiveAlpha())
	end
	w:advance(4)
	eq(#screenFx(r, "portal_open"), 0, "a one-shot hides itself within ~2 s")
	w:enterCombat(r)
	FX.Fullscreen("arrival")
	w:advance(0.3)
	eq(#screenFx(r), 0, "never in combat")
	w:leaveCombat(r)
	clean(w)
end)

test("FX: effects Off and Light (W.db.fx)", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	local FX = needFX(r)
	r.W.db.fx = "off"
	r.W.Fire("SETTINGS", "fx")
	FX.Fullscreen("arrival")
	w:advance(0.3)
	eq(#screenFx(r, "arrival"), 0, "Off: no screen effects")
	local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
	holder:SetSize(64, 64) holder:SetPoint("CENTER")
	local crown = FX.Crown(holder, 48)
	ok(crown and H.visible(crown), "Off: the crown is still there (static)")
	local tex = {}
	for _, d in ipairs(descendants(crown)) do if S[d].otype == "Texture" then tex[#tex + 1] = d end end
	w:advance(0.5)
	local a = sumTexCoords(tex)
	w:advance(2)
	eq(sumTexCoords(tex) - a, 0, "Off: the crown doesn't spin")
	r.W.db.fx = "light"
	r.W.Fire("SETTINGS", "fx")
	FX.Fullscreen("portal_open")
	w:advance(5)
	eq(#screenFx(r, "portal"), 0, "Light: no fullscreen loop after the one-shot")
	clean(w)
end)

test("FX plays the ride's screen moments itself: portal_open once at portal, arrival once at arrived; UI never does", function()
	for _, file in ipairs((H.tocFiles("Wuber"))) do
		if file:match("^UI") then
			local t = readFile(WDIR .. "/" .. file) or ""
			ok(not t:find("portal_open", 1, true), file .. " plays portal_open (FX owns it)")
			ok(not t:find("[\"']arrival[\"']"), file .. " plays arrival (FX owns it)")
		end
	end
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	r.W.db.autoAccept = false -- this test clicks Wuber's Accept invite button
	needFX(r)
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(1)
	if HAVE_UI then r.W.UI.Toggle(true) w:advance(2.5) end
	r:clickText("Accept invite")
	w:advance(1)
	-- watch the screen: rising edges of each effect
	local edges, was = {}, {}
	local function sample()
		for _, part in ipairs({ "portal_open", "arrival" }) do
			local on = #screenFx(r, part) > 0
			if on and not was[part] then edges[part] = (edges[part] or 0) + 1 end
			was[part] = on
		end
	end
	local function run(sec) for _ = 1, sec * 10 do w:advance(0.1) sample() end end
	w:summon(d, TESTCHAR)
	run(2)
	eq(rideState(r), "portal")
	eq(edges.portal_open, 1, "portal_open once when the summon is up")
	r:clickText("Accept summon")
	run(4)
	eq(rideState(r), "arrived")
	eq(edges.arrival, 1, "arrival once on landing")
	eq(edges.portal_open, 1, "portal_open not again")
	-- an expired and re-cast summon is the same ride + state: no second portal_open
	clean(w)
end)

test("FX: the driver's screen gets a burst on Paid and coins for a 5-star rating", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	needFX(d)
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(1)
	r.W.AcceptInvite()
	w:advance(1)
	w:summon(d, TESTCHAR)
	w:advance(1)
	w.hardware = r r.env.C_SummonInfo.ConfirmSummon() w.hardware = nil
	w:advance(3)
	w:openTrade(d, r)
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	local seen = false
	for _ = 1, 20 do w:advance(0.1) if #screenFx(d) > 0 then seen = true end end
	ok(seen, "a burst on the driver's screen when paid")
	w:advance(4)
	r.W.Rate(5)
	seen = false
	for _ = 1, 30 do w:advance(0.1) if #screenFx(d) > 0 then seen = true end end
	ok(seen, "coins for 5 stars")
	clean(w)
end)

test("FX: without ModelScene (an older client) nothing errors", function()
	local w = newWorld({ noModelScene = true })
	local r = rider(w)
	settle(w)
	local FX = needFX(r)
	FX.Fullscreen("portal_open")
	FX.Play("milestone", r.env.UIParent)
	w:advance(3)
	clean(w)
end)

---------------------------------------------------------------------------
-- 22. Nameplates (Nameplates.lua): crowns and badges over heads
---------------------------------------------------------------------------

local function needPlates(c)
	ok(HAVE_PLATES, "Wuber's Nameplates code is not in the TOC")
end

-- a rider who can see friendly plates (the CVar set by the player, not by Wuber)
local function plateRider(w, opts)
	local r = rider(w, TESTCHAR, opts)
	r.cvars.nameplateShowFriends = "1"
	return r
end

test("nameplates: a crown over the creator, nothing over others; one anchor, explicit size, no mouse", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	w:addBot(ANITA, { spot = "Orgrimmar" })
	w:addBot("Zed Ox", { spot = "Orgrimmar" })
	local r = plateRider(w)
	settle(w)
	needPlates(r)
	r:showPlate(ANITA)
	r:showPlate("Zed Ox")
	w:advance(0.5)
	local on = r:onPlate(ANITA)
	eq(#on, 1, "one frame on Anita's plate")
	eq(#r:onPlate("Zed Ox"), 0, "nothing over a non-driver")
	local f = on[1]
	local s = S[f]
	eq(#s.points, 1, "one anchor point")
	eq(s.points[1].point, "BOTTOM") eq(s.points[1].relPoint, "TOP")
	ok(s.w and s.h, "explicit SetSize")
	ok(not s.mouse, "EnableMouse(false)")
	for _, d in ipairs(descendants(f)) do ok(not (S[d].kind == "frame" and S[d].mouse), "a child takes the mouse") end
	ok(#texturesWith(r, "crown", true) >= 1, "a crown texture shows")
	eq(#r.cvarSets, 0, "no CVar touched at login")
	clean(w)
end)

test("nameplates: released on NAME_PLATE_UNIT_REMOVED, recycled tokens, re-ADDED without REMOVED", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	w:addBot(ANITA, { spot = "Orgrimmar" })
	w:addBot("Zed Ox", { spot = "Orgrimmar" })
	w:addBot("Yan Ox", { spot = "Orgrimmar" })
	local r = plateRider(w)
	settle(w)
	needPlates(r)
	eq(r:showPlate(ANITA), "nameplate1")
	w:advance(0.5)
	eq(#r:onPlate(ANITA), 1)
	r:hidePlate(ANITA)
	w:advance(0.1)
	eq(#r:plateFramesShown(), 0, "released on REMOVED")
	eq(r:showPlate("Zed Ox"), "nameplate1", "the token and frame reused")
	w:advance(3)
	eq(#r:onPlate("Zed Ox"), 0, "no stale crown on Zed")
	-- the game re-uses a token without telling us it was removed
	r:hidePlate("Zed Ox")
	r:showPlate(ANITA)
	w:advance(0.5)
	eq(#r:onPlate(ANITA), 1)
	r:showPlate("Yan Ox", { index = r:plateIndexOf(ANITA) })
	w:advance(0.1)
	eq(#r:plateFramesShown(), 0, "re-ADDED on that token: the old frame dropped first")
	clean(w)
end)

test("nameplates: forbidden plates skipped; a secret name makes no error and no frame, the 2 s sweep catches the late name", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	w:addBot(ANITA, { spot = "Orgrimmar" })
	w:addBot("Wuber Rocks", { spot = "Orgrimmar" })
	local r = plateRider(w)
	settle(w)
	needPlates(r)
	r:showPlate(ANITA, { forbidden = true })
	w:advance(3)
	eq(#r:plateFramesShown(), 0, "nothing on a forbidden plate")
	eq(#w.violations, 0, "the forbidden plate was not touched (" .. list(w.violations) .. ")")
	local tok = r:showPlate("Wuber Rocks", { secretName = true })
	w:advance(0.5)
	eq(#r:onPlate("Wuber Rocks"), 0, "a secret name: no frame")
	r.plates[tonumber(tok:match("%d+"))].secretName = false
	w:advance(2.5)
	eq(#r:onPlate("Wuber Rocks"), 1, "the name arrived: the sweep adds the crown")
	clean(w)
end)

test("nameplates: drivers' badges while their beacon is fresh; at most 10 frames", function()
	local w = newWorld()
	local d = driver(w, BOB, { spot = "Orgrimmar" })
	local r = plateRider(w)
	settle(w)
	needPlates(r)
	local ids = badgeIds(d.W)
	d.W.Char().badge = ids[1]
	goOnline(d)
	r:showPlate(BOB)
	w:advance(0.5)
	eq(#r:onPlate(BOB), 1, "a badge over a driver")
	ok(#texturesWith(r, "badge", true) >= 1, "a badge texture")
	w:closeClient(d, false) -- crashed: no X; the beacon expires after 150 s
	w:advance(160)
	eq(#r:onPlate(BOB), 0, "the badge dropped when the beacon expired")
	-- 14 drivers with badges and plates
	for i = 1, 14 do
		local n = "Lock" .. string.char(64 + i) .. " Ox"
		w:addBot(n, { spot = "Orgrimmar" })
		w:inject(n, D({ badge = ids[1 + i % #ids], queue = 0 }), "CHANNEL")
		r:showPlate(n)
	end
	w:advance(3)
	local n = #r:plateFramesShown()
	ok(n >= 1 and n <= 10, "frames on plates: " .. n .. " (cap 10)")
	clean(w)
end)

test("nameplates: \"Crowns and badges over heads\" off hides them (W.db.plates); Moo raises the crown 40 px", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	w:addBot(ANITA, { spot = "Orgrimmar" })
	local r = plateRider(w)
	local m = rider(w, BOB, { mooLoaded = true })
	m.cvars.nameplateShowFriends = "1"
	settle(w)
	needPlates(r)
	r:showPlate(ANITA)
	m:showPlate(ANITA)
	w:advance(0.5)
	local a, b = r:onPlate(ANITA)[1], m:onPlate(ANITA)[1]
	ok(a and b, "crowns on both")
	eq(S[b].points[1].y - S[a].points[1].y, 40, "with Moo the crown sits 40 px higher")
	r.W.db.plates = false
	r.W.Fire("SETTINGS", "plates")
	w:advance(0.5)
	eq(#r:plateFramesShown(), 0, "off")
	r.W.db.plates = true
	r.W.Fire("SETTINGS", "plates")
	w:advance(2.5)
	eq(#r:onPlate(ANITA), 1, "on again")
	clean(w)
end)

for _, style in ipairs({ "processor", "legacy" }) do
	test("tooltip lines: \"Wuber founder\" and \"Wuber driver · 50s to ...\" (" .. style .. ")", function()
		local w = newWorld({ tooltipStyle = style, realm = T.H.FOUNDER_REALM })
		w:addBot(ANITA, { spot = "Orgrimmar" })
		local d = driver(w, BOB, { spot = "Ratchet" })
		w:addBot("Zed Ox", { spot = "Orgrimmar" })
		local r = rider(w)
		settle(w)
		needPlates(r)
		goOnline(d)
		local function has(lines, pat) for _, l in ipairs(lines) do if l:find(pat) then return l end end end
		ok(has(r:hover(ANITA), "Wuber founder"), "founder line: " .. list(r:hover(ANITA)))
		local l = has(r:hover(BOB), "Wuber driver")
		ok(l and l:find("50s") and l:find("Ratchet"), "driver line: " .. tostring(l))
		eq(has(r:hover("Zed Ox"), "Wuber"), nil, "nothing for others")
		-- other tooltips and combat
		r.mouseoverPlayer = w:player(ANITA)
		r.env.ItemRefTooltip:SetOwner(r.env.UIParent, "ANCHOR_NONE")
		r.env.ItemRefTooltip:SetUnit("mouseover")
		eq(has(S[r.env.ItemRefTooltip].tipLines, "Wuber"), nil, "only GameTooltip")
		w:enterCombat(r)
		eq(has(r:hover(ANITA), "Wuber"), nil, "skipped in combat")
		w:leaveCombat(r)
		clean(w)
	end)
end

test("nameplates: the friendly nameplates button sets the CVar once, out of combat only", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	needPlates(r)
	needUI(r)
	eq(#r.cvarSets, 0, "nothing at login")
	r:slash("/wuber help")
	w:advance(2.5)
	ok(r.W.UI.SettingsShown(), "/wuber help opens Settings")
	r.W.UI.OpenSettings("sound") -- (round 9, G1: the button is in the Sound section)
	w:advance(1)
	local b = r:button("Turn on friendly nameplates", { pattern = true })
	ok(b, "the button in Settings (" .. texts(r) .. ")")
	ok(r:scrollIntoView(b), "the player scrolls the button into view")
	w:enterCombat(r)
	r:click(b)
	w:advance(0.5)
	eq(r.cvars.nameplateShowFriends, "0", "not in combat")
	w:leaveCombat(r)
	w:advance(0.5)
	b = r:button("Turn on friendly nameplates", { pattern = true }) or b
	ok(r:scrollIntoView(b), "still in view")
	r:click(b)
	w:advance(0.5)
	eq(r.cvars.nameplateShowFriends, "1", "turned on")
	for _, x in ipairs(r.cvarSets) do ok(x.name:match("^nameplate"), "only nameplate CVars: " .. x.name) end
	clean(w)
end)

---------------------------------------------------------------------------
-- 23. The window: Settings, tooltips, Trips, coach marks, Confirm, cards
---------------------------------------------------------------------------

local function openSettings(c)
	needUI(c)
	local UI = c.W.UI
	if not (c.env.WuberFrame and H.visible(c.env.WuberFrame)) then UI.Toggle(true) c.world:advance(2.5) end
	need(UI.OpenSettings, "W.UI.OpenSettings")()
	c.world:advance(1)
	ok(#c:findText("Settings") > 0, "Settings shown (" .. texts(c) .. ")")
end

-- (round 9, G1: Settings shows its home, then one section at a time) opens the section that
-- shows the label, as the player would, when it isn't on screen
local function showSettingsRow(c, label)
	local function seen() -- drawn, not scrolled out of the clip
		for _, h in ipairs(c:findText(label)) do if c:onScreen(h) then return true end end
	end
	if seen() then return end
	local P = c.W.Mod and c.W.Mod("UI.Settings.Panel")
	if not (P and P.sectionRanges) then return end
	for _, r in ipairs(P.sectionRanges()) do
		c.W.UI.OpenSettings(r.key)
		c.world:advance(0.5)
		if seen() then return end
	end
end

-- the control on the row of a label in Settings (the nearest button / slider at its height)
-- kind: "Slider" or "Button" (a CheckButton counts as one); the control must be of that kind or the test fails loudly
local function control(c, label, kind)
	showSettingsRow(c, label)
	local hits = c:findText(label)
	ok(#hits > 0, "no Settings row \"" .. label .. "\" (" .. texts(c) .. ")")
	local lab = hits[1]
	local _, ly = lab:GetCenter()
	local best, bestD
	local scope = S[lab].parent
	for _ = 1, 3 do
		for _, d in ipairs(descendants(scope)) do
			local s = S[d]
			local isKind = (s.otype == "Button" or s.otype == "CheckButton" or s.otype == "Slider")
			if isKind and kind then isKind = (kind == "Slider") == (s.otype == "Slider") end
			if isKind and H.visible(d) and not s.secure then
				local _, y = d:GetCenter()
				if y and math.abs(y - ly) < 40 and (not bestD or math.abs(y - ly) < bestD) then best, bestD = d, math.abs(y - ly) end
			end
		end
		if best then break end
		scope = S[scope].parent or scope
	end
	ok(best, "no " .. (kind or "control") .. " on the row \"" .. label .. "\"")
	if kind then
		local isSlider = S[best].otype == "Slider"
		ok(isSlider == (kind == "Slider"), "the control on the row \"" .. label .. "\" is a " .. S[best].otype .. ", the step needs a " .. kind)
	end
	return best
end

test("Settings: gear opens it; sections; Driving only for Warlocks; About in the footer", function()
	local w = newWorld()
	local m = rider(w)
	local d = driver(w)
	settle(w)
	openSettings(m)
	for _, sec in ipairs({ "Riding", "Map", "Effects", "Sound" }) do ok(#findCI(m, sec) > 0, "section " .. sec) end
	eq(#findCI(m, "^Driving$"), 0, "no Driving section for a Mage")
	openSettings(d)
	ok(#findCI(d, "^Driving$") > 0, "Driving section for a Warlock (" .. texts(d) .. ")")
	ok(#d:findText(d.W.VERSION, false, true) > 0, "the version in the About footer")
	clean(w)
end)

test("Settings: Check my game runs W.SelfTest in a panel; Hidden drivers: show all again", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	r.W.HideDriver("anita lift")
	openSettings(r)
	r:click(control(r, "Check my game"))
	w:advance(1)
	ok(#r:findText("[Ww]orks") + #r:findText("OK") + #r:findText("✓") + #r:findText("[Pp]roblem") > 0 or #r.W.SelfTest() > 0, "results shown (" .. texts(r) .. ")")
	r:click(control(r, "^Show all"))
	w:advance(1)
	eq(next(r.W.db.hidden), nil, "W.db.hidden cleared")
	clean(w)
end)

test("Settings: every toggle and slider changes what it says", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	openSettings(r)
	local fired0 = fired(r, "SETTINGS")
	-- sounds
	r:click(control(r, "^Sounds$", "Button"))
	w:advance(0.5)
	eq(r.W.db.sound, false, "sounds off")
	-- map pins
	r:click(control(r, "^Drivers on the world map$", "Button"))
	w:advance(0.5)
	eq(r.W.db.mapPins, false, "map pins off")
	-- crowns and badges over heads
	r:click(control(r, "^Badges over heads$", "Button"))
	w:advance(0.5)
	eq(r.W.db.plates, false, "crowns off")
	eq(r.W.db.emblems, false, "the merged switch writes the emblems too")
	-- minimap button
	r:click(control(r, "^Minimap button$", "Button"))
	w:advance(0.5)
	ok(not H.visible(r.env.WuberMinimapButton), "minimap button hidden")
	-- effects: Full / Light / Off
	showSettingsRow(r, "^Effects$")
	r:clickText("Off")
	w:advance(0.5)
	eq(r.W.db.fx, "off", "effects off")
	-- my time is worth (slider)
	local s = control(r, "[Tt]ime is worth", "Slider")
	local lo, hi = s:GetMinMaxValues()
	s:SetValue(hi)
	w:advance(0.5)
	ok(r.W.db.timeValue > 100000, "time value raised: " .. r.W.db.timeValue)
	-- window size (slider)
	local scale0 = H.effScale(r.env.WuberFrame)
	local ws = control(r, "[Ww]indow size", "Slider")
	local lo = ws:GetMinMaxValues()
	ws:SetValue(lo)
	w:advance(0.5)
	eq(r.W.db.scale, lo, "the Window size slider wrote the scale")
	ok(H.effScale(r.env.WuberFrame) < scale0, "window smaller: " .. scale0 .. " -> " .. H.effScale(r.env.WuberFrame))
	ok(fired(r, "SETTINGS") - fired0 >= 6, "SETTINGS fired for each change")
	-- behaviour: no sound on a toast, no pins
	local s0 = #r.sounds
	r.W.RequestRide("anita lift")
	w:advance(1)
	d.W.AcceptRequest(d.W.incoming[1].id, 5)
	w:advance(1)
	eq(#r.sounds, s0, "sounds off: the accept toast is silent")
	w:openMap(r, 1413)
	w:advance(0.5)
	eq(#pins(r), 0, "no pins")
	clean(w)
end)

test("every interactive element has a tooltip (Home, Confirm, Trips, Drive, Settings)", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	needUI(r)
	local missing, checked = {}, 0
	local function sweep(c, where)
		for _, f in ipairs(descendants(c.env.WuberFrame)) do
			local s = S[f]
			if s.kind == "frame" and H.visible(f) and (s.otype == "Button" or s.otype == "CheckButton" or s.otype == "Slider" or s.otype == "EditBox") then
				checked = checked + 1
				local fn = s.scripts.OnEnter
				local tt = c.env.GameTooltip
				S[tt].tipLines = {}
				if fn then H.runScript(f, "OnEnter") end
				local label = ""
				for _, x in ipairs(descendants(f)) do if S[x].otype == "FontString" and S[x].text then label = S[x].text break end end
				if not fn or #(S[tt].tipLines or {}) == 0 then missing[#missing + 1] = where .. ": " .. s.otype .. " \"" .. label .. "\"" end
				if fn then H.runScript(f, "OnLeave") end
			end
		end
	end
	r.W.UI.Show("home") w:advance(2.5) sweep(r, "Home")
	r.W.UI.Show("confirm", "anita lift") w:advance(1) sweep(r, "Confirm")
	r.W.UI.Show("home") w:advance(1)
	if #r:findText("^Trips$") > 0 then r:clickText("Trips") w:advance(1) sweep(r, "Trips") end
	openSettings(r) sweep(r, "Settings")
	openDrive(d) sweep(d, "Drive")
	ok(checked > 10, "elements checked: " .. checked)
	eq(#missing, 0, "without a tooltip: " .. list(missing))
	clean(w)
end)

test("Trips tab (Ride · Trips · Drive): level and progress, stats tiles, milestones grid, history", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	needUI(r)
	trips(r.W, { { ANITA, "Ratchet", 5000, 3 }, { ANITA, "Undercity", 5000, 2 }, { BOB, "Gadgetzan", 5000, 1 }, { ANITA, "Ratchet", 5000, 0 } })
	r.W.CheckMilestones()
	w:advance(3)
	r.W.UI.Show("home")
	w:advance(2.5)
	local tabs = {}
	for _, n in ipairs({ "Ride", "Trips", "Drive" }) do local h = r:findText("^" .. n .. "$") ok(#h > 0, "tab " .. n) tabs[n] = h[1] end
	local x1, x2, x3 = tabs.Ride:GetCenter(), tabs.Trips:GetCenter(), tabs.Drive:GetCenter()
	ok(x1 < x2 and x2 < x3, "Ride · Trips · Drive in that order")
	r:clickText("Trips")
	w:advance(1.5)
	ok(#findCI(r, "Bronze") > 0, "level Bronze (4 rides) (" .. texts(r) .. ")")
	-- r50 H24-01: the first medal row hides under the cue at scroll 0, so scroll a little first
	do
		local tv = r.W.Mod("UI.Rider.Trips").view()
		local y = math.min(100, tv.scrollMax or 0)
		tv.scroll, tv.scrollTarget = y, y
		tv.content:ClearAllPoints()
		tv.content:SetPoint("TOPLEFT", tv.clip, "TOPLEFT", 0, y)
		r.W.Mod("UI.Rider.Trips").trimCells()
	end
	ok(#r:findText("First Ride") > 0, "milestones grid")
	ok(#r:findText("^4$") + #r:findText("4 rides") > 0, "rides tile")
	-- locked milestones say how to earn them
	local tipped = false
	-- (BRIEF19 F6) the folded page leaves out a milestone row its view would slice: walk the page top to end
	-- (DS24-01: the end is now the real end, so the milestones are seen on the way, not only at the end)
	do
		local TM = r.W.Mod("UI.Rider.Trips")
		local tv = TM.view()
		local top = tv.scrollMax or 0
		for y = 0, top + 60, 60 do
			local at = math.min(y, top)
			tv.scroll, tv.scrollTarget = at, at
			TM.trimCells()
			for _, f in ipairs(descendants(r.env.WuberFrame)) do
				if not tipped and S[f].kind == "frame" and H.visible(f) and S[f].scripts.OnEnter then
					S[r.env.GameTooltip].tipLines = {}
					H.runScript(f, "OnEnter")
					for _, l in ipairs(S[r.env.GameTooltip].tipLines or {}) do if l:find("Ride to 20 different places") then tipped = true end end
					H.runScript(f, "OnLeave")
				end
			end
		end
	end
	ok(tipped, "a locked milestone's tooltip says how to earn it")
	clean(w)
end)

test("coach marks: three tips on the first open, skippable, never again, never during a ride", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	needUI(r)
	r.W.UI.Toggle(true)
	w:advance(3)
	local skip = r:button("Skip", { pattern = true }) or r:button("Got it", { pattern = true })
	ok(skip, "coach marks with Skip (" .. texts(r) .. ")")
	r:click(skip)
	w:advance(1)
	eq(r.W.db.coach, true, "W.db.coach")
	r.W.UI.Toggle()
	w:advance(1)
	r.W.UI.Toggle(true)
	w:advance(3)
	ok(not r:button("Skip", { pattern = true }), "not again")
	-- a new player in the middle of a ride: no coach marks
	local w2 = newWorld()
	local d2 = driver(w2)
	local r2 = rider(w2)
	settle(w2)
	goOnline(d2)
	r2.W.RequestRide("anita lift")
	w2:advance(1)
	r2.W.UI.Toggle(true)
	w2:advance(3)
	ok(not r2:button("Skip", { pattern = true }), "no coach marks during a ride")
	clean(w)
	clean(w2)
end)

test("Confirm: the savings pill \"N min faster\"; \"worth about\" only when it beats the fare (02 v3)", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w, TESTCHAR, { spot = "Undercity" })
	settle(w)
	goOnline(d)
	openConfirm(r, "anita lift")
	ok(#r:findText("%d+ min faster") > 0, "time saved (" .. texts(r) .. ")")
	r.W.FlightCost = function() return nil end -- no flight cost: what the time is worth goes in the pill itself
	r.W.db.timeValue = 10000 -- 1g/h: worth less than the 50s fare
	r.W.UI.Show("confirm", "anita lift")
	w:advance(1)
	eq(#findCI(r, "worth about"), 0, "no \"worth\" below the fare")
	r.W.db.timeValue = 1000000
	r.W.UI.Show("confirm", "anita lift")
	w:advance(1)
	ok(#findCI(r, "worth about") > 0, "\"worth about\" above the fare (" .. texts(r) .. ")")
	-- (design 1 H) next to "N min faster" the amount is letters, never a coin icon
	ok(#r:findText("worth about |cff%x%x%x%x%x%x%d+g[ %d]*s?|r of your time") > 0 and #r:findText("|T", 1, true) == 0, "the amount in letters (" .. texts(r) .. ")")
	clean(w)
end)

test("cards: the creator's card has the Founder chip, a crown and the brightest glow; others don't", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	local d = driver(w)
	local b = driver(w, BOB, { spot = "Crossroads" })
	local r = rider(w)
	settle(w)
	b.W.Char().badge = badgeIds(b.W)[1]
	goOnline(d)
	goOnline(b)
	needUI(r)
	r.W.UI.Show("home")
	w:advance(2.5)
	local chips = r:findText("^Founder$")
	local off = r:findText("^Official$")
	eq(#chips + #off, 1, "one Founder/Official chip (" .. texts(r) .. ")")
	-- (design 2) no crown after the name: the Founder badge says it (the crown's words are in the row's tooltip)
	local founder = r.W.UI.state.cards["anita lift"]
	ok(founder and not (founder.crown and founder.crown:IsShown()), "no crown on the founder's row")
	ok(#texturesWith(r, "badge", true) >= 1, "Bob's badge on his card")
	clean(w)
end)

test("a favourite's toast, clicked, opens Confirm for that driver", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	needUI(r)
	r.W.db.favs["anita lift"] = true
	goOnline(d)
	local hit
	for _ = 1, 20 do
		w:advance(0.25)
		hit = r:findText("Anita.-online")[1]
		if hit then break end
	end
	ok(hit, "the toast")
	r:clickOn(hit)
	w:advance(1.5)
	ok(#r:findText("^Request") > 0, "Confirm for Anita (" .. texts(r) .. ")")
	clean(w)
end)

---------------------------------------------------------------------------
-- 24. Map: route line, creator pins, badge picker
---------------------------------------------------------------------------

-- visible textures on the map canvas that are not part of a pin
local function routeDots(c)
	local canvas = c.mapCanvas
	local pinParts = {}
	for _, f in ipairs(c.frames) do
		if S[f].parent == canvas and rawget(f, "key") then
			pinParts[f] = true
			for _, x in ipairs(descendants(f)) do pinParts[x] = true end
		end
	end
	local out = {}
	for _, x in ipairs(descendants(canvas)) do
		if not pinParts[x] and S[x].otype == "Texture" and H.visible(x) and x:GetEffectiveAlpha() > 0 then out[#out + 1] = x end
	end
	return out
end

test("route line: dots from the rider to the destination while a ride is on; hidden otherwise", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	w:openMap(r, 1414)
	w:advance(0.5)
	local base = #routeDots(r)
	r.W.RequestRide("anita lift")
	w:advance(1)
	local n = #routeDots(r) - base
	ok(n >= 3 and n <= 40, "dots on Kalimdor: " .. n)
	-- they flow: positions change
	local first = routeDots(r)
	local before = {}
	for i, t in ipairs(first) do local l, b = H.rect(t).l, H.rect(t).b before[i] = l .. "," .. b end
	w:advance(1)
	local moved = false
	for i, t in ipairs(routeDots(r)) do
		local q = H.rect(t)
		if before[i] ~= q.l .. "," .. q.b then moved = true end
		-- or an animation slides them (the harness doesn't move frames for animations)
		local f = t
		while f and not moved do
			for _, g in ipairs(S[f].animGroups or {}) do if g:IsPlaying() then moved = true end end
			f = S[f].parent
		end
	end
	ok(moved, "the dots move toward the destination (a tick or a playing animation)")
	-- the map of the other continent: nothing
	r.env.WorldMapFrame:SetMapID(1415)
	w:advance(0.5)
	eq(#routeDots(r), 0, "no line on the Eastern Kingdoms")
	-- closed map: nothing drawn
	r.env.WorldMapFrame:SetMapID(1414)
	r.env.WorldMapFrame:Hide()
	w:advance(0.5)
	eq(#routeDots(r), 0, "nothing while the map is closed")
	-- unreadable position: hidden, no errors
	w:openMap(r, 1414)
	r:secret("C_Map")
	w:advance(0.5)
	eq(#routeDots(r) - base, 0, "hidden when the position is unreadable")
	r:unsecret()
	-- the ride ends: gone
	r.W.CancelRide()
	w:advance(1)
	eq(#routeDots(r) - base, 0, "gone when the ride ends")
	clean(w)
end)

test("route line: a small one on Home's mini map too", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	needUI(r)
	r.W.UI.Show("home")
	w:advance(2.5)
	local function count_()
		local n = 0
		for _, x in ipairs(descendants(r.env.WuberFrame)) do
			if S[x].otype == "Texture" and H.visible(x) then n = n + 1 end
		end
		return n
	end
	local a = count_()
	r.W.RequestRide("anita lift")
	w:advance(1)
	r.W.UI.Show("home")
	w:advance(1)
	ok(count_() > a, "more textures with the route drawn")
	clean(w)
end)

test("creator pins: bigger, crowned; other pins plain", function()
	local w = newWorld({ realm = T.H.FOUNDER_REALM })
	local d = driver(w)
	local b = driver(w, BOB, { spot = "Crossroads" })
	local r = rider(w)
	settle(w)
	goOnline(d)
	goOnline(b)
	w:openMap(r, 1413)
	w:advance(0.5)
	local ps = pins(r)
	eq(#ps, 2)
	local pa, pb
	for _, p in ipairs(ps) do if rawget(p, "key") == "anita lift" then pa = p else pb = p end end
	local ra, rb = H.rect(pa), H.rect(pb)
	ok(ra.w > rb.w, ("the creator's pin is bigger: %.1f vs %.1f"):format(ra.w, rb.w))
	local crowned = false
	for _, x in ipairs(descendants(pa)) do if S[x].otype == "Texture" and H.visible(x) and type(S[x].texture) == "string" and S[x].texture:lower():find("crown") then crowned = true end end
	ok(crowned, "a crown on the creator's pin")
	for _, x in ipairs(descendants(pb)) do
		ok(not (S[x].otype == "Texture" and H.visible(x) and type(S[x].texture) == "string" and S[x].texture:lower():find("crown")), "no crown on Bob's pin")
	end
	clean(w)
end)

test("badge picker (Settings, Driving): the chosen badge is beaconed", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	openSettings(d)
	d.W.UI.OpenSettings("driving") -- (round 9, G1: the badge picker is in the Driving section)
	w:advance(1)
	local ids = badgeIds(d.W)
	local name = d.W.BADGES[2].name
	local hits = d:findText("^" .. name .. "$")
	if #hits > 0 then d:clickOn(hits[1]) else
		-- icons only: the picker's buttons carry tooltips with the badge names
		local picked = false
		for _, f in ipairs(descendants(d.env.WuberFrame)) do
			if not picked and S[f].kind == "frame" and H.visible(f) and S[f].scripts.OnEnter and S[f].scripts.OnClick then
				S[d.env.GameTooltip].tipLines = {}
				H.runScript(f, "OnEnter")
				local tl = S[d.env.GameTooltip].tipLines or {}
				H.runScript(f, "OnLeave")
				if tl[1] and tl[1]:find(name, 1, true) then d:click(f) picked = true end
			end
		end
		ok(picked, "a badge button for " .. name)
	end
	w:advance(0.5)
	eq(d.W.Char().badge, ids[1] and d.W.BADGES[2].id, "W.Char().badge")
	goOnline(d)
	eq(r.W.drivers["anita lift"].badge, d.W.BADGES[2].id, "riders see it")
	clean(w)
end)

---------------------------------------------------------------------------
-- 25. Auto-accept, auto-leave, one-click pay (lead's ruling: AcceptGroup / LeaveParty are
--     allowed from events; AcceptTrade stays click-only)
---------------------------------------------------------------------------

-- a ride with Driver.lua's Anita up to "arrived" (auto-accept on unless the test says)
local function rideToArrived(w, d, r)
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(2)
	if not w:player(TESTCHAR).group then
		w.hardware = r
		r.W.AcceptInvite()
		w.hardware = nil
		w:advance(1)
	end
	w:summon(d, TESTCHAR)
	w:advance(1)
	w.hardware = r
	r.W.AcceptSummon()
	w.hardware = nil
	w:advance(3)
	eq(rideState(r), "arrived")
end

test("auto-accept: the booked driver's invite is accepted for the rider (box marked and hidden)", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	eq(r.W.db.autoAccept, true, "on by default")
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(2)
	ok(w:player(TESTCHAR).group and w:player(TESTCHAR).group == w:player(ANITA).group, "in Anita's group without a click")
	eq(r.popups.PARTY_INVITE, nil, "the box hidden (with inviteAccepted)")
	eq(r.declinedGroup, nil, "not declined")
	eq(rideState(r), "ingroup")
	clean(w)
end)

test("auto-accept: a stranger's invite is not accepted (no ride, or before the driver accepted)", function()
	local w = newWorld()
	local d = driver(w, ANITA, { netOnly = true }) -- "no A yet" needs a driver who answers by hand
	local evil = driver(w, "Evil Lock", { spot = "Crossroads" })
	local r = rider(w)
	settle(w)
	evil.env.C_PartyInfo.InviteUnit(TESTCHAR)
	w:advance(2)
	eq(w:player(TESTCHAR).group, nil, "no ride: not accepted")
	ok(r.popups.PARTY_INVITE, "the game's box is left to the player")
	r.popups.PARTY_INVITE = nil
	w:player(TESTCHAR).pendingInvite = nil
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(0.5)
	evil.env.C_PartyInfo.InviteUnit(TESTCHAR)
	w:advance(2)
	eq(w:player(TESTCHAR).group, nil, "requesting (no A yet): a stranger's invite is not accepted")
	clean(w)
end)

test("auto-accept off (W.db.autoAccept = false): the Accept invite button does it", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	r.W.db.autoAccept = false
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(2)
	eq(w:player(TESTCHAR).group, nil, "not accepted by itself")
	eq(rideState(r), "invited")
	if HAVE_UI then
		r.W.UI.Toggle(true)
		w:advance(2.5)
		r:clickText("Accept invite")
		w:advance(1)
		ok(w:player(TESTCHAR).group, "the button accepted")
	end
	clean(w)
end)

test("auto-leave: after a paid ride the rider leaves the driver's group (waits for combat to end)", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	rideToArrived(w, d, r)
	w:openTrade(d, r)
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(1)
	eq(rideState(r), "done")
	w:enterCombat(r)
	w:advance(5)
	ok(w:player(TESTCHAR).group, "not in combat")
	w:leaveCombat(r)
	w:advance(1)
	eq(w:player(TESTCHAR).group, nil, "left after combat")
	clean(w)
end)

test("auto-leave: not when the rider was in that group before the ride", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	w:group({ ANITA, TESTCHAR })
	w:advance(1)
	rideToArrived(w, d, r)
	w:openTrade(d, r)
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(6)
	eq(rideState(r), "done")
	ok(w:player(TESTCHAR).group, "stays in the group it was already in")
	clean(w)
end)

test("pay (W.PayFare): Forever forbids addons gold in trades, so it says what to type and touches nothing; refused without enough gold", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	rideToArrived(w, d, r)
	w:openTrade(d, r)
	w:advance(0.5)
	local okp, line = need(r.W.PayFare, "W.PayFare")
	w.hardware = r
	okp, line = r.W.PayFare()
	w.hardware = nil
	ok(okp, "guided: " .. tostring(line))
	ok(tostring(line):find("50 in silver", 1, true), "says exactly what to type: " .. tostring(line))
	local t = w:player(TESTCHAR).trade
	eq(t.money[TESTCHAR], 0, "nothing put in the trade by the addon")
	-- the rider types it and clicks Trade
	t.money[TESTCHAR] = 5000
	w:tradeAccept(r)
	w:tradeAccept(d)
	w:advance(2)
	eq(rideState(r), "done")
	eq(w:player(TESTCHAR).money, 95000)
	clean(w)
	-- not enough gold
	local w2 = newWorld()
	local d2 = driver(w2)
	local r2 = rider(w2, TESTCHAR, { money = 3000 })
	settle(w2)
	rideToArrived(w2, d2, r2)
	w2:openTrade(d2, r2)
	w2:advance(0.5)
	w2.hardware = r2
	local ok2, line2 = r2.W.PayFare()
	w2.hardware = nil
	eq(ok2, false, "refused")
	ok(tostring(line2):find("need"), "says so: " .. tostring(line2))
	eq(w2:player(TESTCHAR).trade.money[TESTCHAR], 0, "nothing put in the trade")
	clean(w2)
end)

test("auto-accept: a teammate's invite after the driver's A is not accepted for you (the button is)", function()
	local w = newWorld()
	local d = driver(w, ANITA, { netOnly = true }) -- an A without the driver's own invite (the engine invites)
	local mate = driver(w, BOB, { spot = "Ratchet" })
	local r = rider(w)
	settle(w)
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	d.W.AcceptRequest(d.W.incoming[1].id, 5) -- the A only; Bob sends the invite
	w:advance(1)
	mate.env.C_PartyInfo.InviteUnit(TESTCHAR)
	w:advance(2)
	eq(w:player(TESTCHAR).group, nil, "a teammate's invite is not accepted by itself")
	eq(rideState(r), "invited", "but the ride shows it")
	if HAVE_UI then
		r.W.UI.Toggle(true)
		w:advance(2.5)
		r:clickText("Accept invite")
		w:advance(1)
		ok(w:player(TESTCHAR).group == w:player(BOB).group, "the button joins Bob's group")
	end
	clean(w)
end)

---------------------------------------------------------------------------
-- 26. Media sheets FX names; no globals after every round-two feature
---------------------------------------------------------------------------

test("every effect sheet FX.lua names exists in Media/fx", function()
	ok(HAVE_FX, "Wuber's FX code (FX.lua or FX/*.lua) is not in the TOC")
	local t = F.read("FX")
	local names, missing = {}, {}
	for n in t:gmatch("file%s*=%s*\"([%w_]+)\"") do names[n] = true end
	local lone = t:match("local LONE%s*=%s*(%b{})")
	if lone then for n in lone:gmatch("([%w_]+)%s*=%s*true") do names[n] = true end end
	ok(next(names), "no sheet names found in FX.lua")
	for n in pairs(names) do
		if not H.exists(WDIR .. "/Media/fx/" .. n .. ".tga") then missing[#missing + 1] = n end
	end
	eq(#missing, 0, "missing Media/fx sheets: " .. list(missing))
end)

local function checkGlobals(c)
	for k in pairs(c.env) do
		local allowed = k == "_G" or k == "Wuber" or k == "WuberDB" or k == "WuberAPI"
			or k == "BINDING_HEADER_WUBER" or k == "BINDING_NAME_WUBER_TOGGLE" or k == "BINDING_NAME_CLICK WuberDriveButton:LeftButton" -- (2.4) the game's Key Bindings names: Wuber/Bindings.xml
			or (type(k) == "string" and (k:match("^SLASH_WUBER%d+$") or (k:match("^Wuber") and (H.state[c.env[k]] ~= nil or H.fonts[c.env[k]]))))
		ok(allowed, c.player.name .. ": a stray global: " .. tostring(k) .. " (written at " .. tostring(c.globalWrites[k]) .. ")")
	end
	for k, at in pairs(c.globalWrites) do
		ok(k == "Wuber" or k == "WuberDB" or k == "WuberAPI" or k == "_G" or tostring(k):match("^SLASH_WUBER%d+$") or k == "BINDING_HEADER_WUBER" or k == "BINDING_NAME_WUBER_TOGGLE" or k == "BINDING_NAME_CLICK WuberDriveButton:LeftButton"
			or (tostring(k):match("^Wuber") and (H.state[c.env[k]] ~= nil or H.fonts[c.env[k]])) or at == "harness", "global write " .. tostring(k) .. " at " .. tostring(at))
	end
end

test("no stray globals after rides, effects, plates, tooltips, Settings and Trips", function()
	local w = newWorld()
	local d = driver(w)
	local r = plateRider(w)
	settle(w)
	r.W.db.favs["anita lift"] = true
	goOnline(d)
	w:advance(6)
	r:showPlate(ANITA)
	r:hover(ANITA)
	if HAVE_UI then
		r.W.UI.Toggle(true) w:advance(2.5)
		if r.W.UI.OpenSettings then r.W.UI.OpenSettings() w:advance(1) end
		r.W.UI.Show("home") w:advance(1)
		if #r:findText("^Trips$") > 0 then r:clickText("Trips") w:advance(1) end
	end
	if r.W.FX then
		r.W.FX.Fullscreen("portal_open")
		r.W.FX.Play("milestone", r.env.UIParent)
	end
	r.W.RequestRide("anita lift")
	w:advance(1)
	T.take(d)
	w:advance(3)
	w:summon(d, TESTCHAR)
	w:advance(1)
	w.hardware = r r.W.AcceptSummon() w.hardware = nil
	w:advance(4)
	w:openMap(r, 1413)
	w:advance(1)
	checkGlobals(r)
	checkGlobals(d)
	clean(w)
end)

---------------------------------------------------------------------------
-- 27. More round-two details
---------------------------------------------------------------------------

test("a queue change alone does not beat the 5 s beacon coalesce", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	w:advance(20)
	local n0 = #msgs(w, "D", ANITA)
	for i = 1, 4 do
		local n = "Queue Guy" .. string.char(96 + i)
		w:addBot(n)
		w:inject(n, "R~1~ABCDE" .. string.char(64 + i) .. "~Ratchet~5000", "WHISPER", d)
		w:advance(0.5)
	end
	w:advance(3)
	ok(#msgs(w, "D", ANITA) - n0 <= 1, "beacons in 5 s: " .. (#msgs(w, "D", ANITA) - n0))
	clean(w)
end)

-- (SPEC5 pending, review #30) deleted, superseded by the 2.0 engine: "the driver sees the rider's level: 'Silver rider · 12 rides' on the request card"
--   covered by round6_engine "r6 engine: pending (#30): a Wuber rider's level reaches the driver's queue row (c.wuberLabel)"

test("hidden drivers get no favourite toast and no nameplate badge", function()
	local w = newWorld()
	local d = driver(w, BOB, { spot = "Orgrimmar" })
	local r = plateRider(w)
	settle(w)
	r.W.db.favs["bob stone"] = true
	r.W.HideDriver("bob stone")
	d.W.Char().badge = badgeIds(d.W)[1]
	goOnline(d)
	w:advance(6)
	eq(fired(r, "FAV_ONLINE"), 0, "no toast for a hidden favourite")
	r:showPlate(BOB)
	w:advance(2.5)
	eq(#r:onPlate(BOB), 0, "no badge over a hidden driver")
	clean(w)
end)

test("three crowned Warlocks don't spin in sync (W.FX.Crown seed)", function()
	local w = newWorld({ noFlipBook = true, frameStep = 0.05 })
	local r = rider(w)
	settle(w)
	local FX = needFX(r)
	local cells = {}
	for i, seed in ipairs({ "anita lift", "farra way", "hayley cab" }) do
		local holder = r.env.CreateFrame("Frame", nil, r.env.UIParent)
		holder:SetSize(64, 64) holder:SetPoint("CENTER", i * 80, 0)
		local c = FX.Crown(holder, 48, seed)
		w:advance(0.3)
		local t
		for _, d in ipairs(descendants(c)) do
			if S[d].otype == "Texture" and type(S[d].texture) == "string" and S[d].texture:lower():find("fx\\crown", 1, true) then t = d end
		end
		ok(t, "a crown texture for " .. seed)
		cells[i] = t
	end
	w:advance(0.05)
	local a = table.concat({ cells[1]:GetTexCoord() }, ",")
	local b = table.concat({ cells[2]:GetTexCoord() }, ",")
	local c = table.concat({ cells[3]:GetTexCoord() }, ",")
	ok(a ~= b or b ~= c, "different frames at the same moment: " .. a .. " / " .. b .. " / " .. c)
	clean(w)
end)

test("W.TravelSaved for an Alliance rider (Menethil-Theramore / Auberdine boats)", function()
	local w = newWorld()
	local r = rider(w, TESTCHAR, { spot = "Stormwind", faction = "Alliance" })
	settle(w)
	local v = need(r.W.TravelSaved, "W.TravelSaved")("Gadgetzan")
	ok(type(v) == "number" and v >= 300 and v <= 2400, "Stormwind -> Gadgetzan: " .. tostring(v))
	clean(w)
end)

test("secret values everywhere: plates, tooltips, toasts, Trips, Settings, travel saved -> no errors", function()
	local w = newWorld()
	local d = driver(w, ANITA, { spot = "Orgrimmar", secrets = { "C_Map", "GetMoney", "zone" } })
	w:addBot("Wuber Rocks", { spot = "Orgrimmar" })
	local r = rider(w, TESTCHAR, { secrets = { "UnitName", "C_Map", "GetMoney", "zone", "UnitClass" } })
	r.cvars.nameplateShowFriends = "1"
	settle(w)
	r.W.db.favs["anita lift"] = true
	r.W.db.watch["ratchet"] = true
	d.W.Char().badge = badgeIds(d.W)[1]
	goOnline(d)
	w:advance(6)
	r:showPlate(ANITA)
	r:showPlate("Wuber Rocks")
	w:advance(3)
	r:hover(ANITA)
	r:hover("Wuber Rocks")
	if HAVE_UI then
		r.W.UI.Toggle(true) w:advance(2.5)
		if r.W.UI.OpenSettings then r.W.UI.OpenSettings() w:advance(1) end
		r.W.UI.Show("home") w:advance(1)
		if #r:findText("^Trips$") > 0 then r:clickText("Trips") w:advance(1) end
		r.W.UI.Show("confirm", "anita lift") w:advance(1)
	end
	r.W.RequestRide("anita lift")
	w:advance(2)
	T.take(d)
	w:advance(3)
	w:openMap(r, 1454)
	w:advance(1)
	for _, e in ipairs(w.addonLog) do ok(not e.text:find("<secret>"), "secret in a message") end
	clean(w)
end)
