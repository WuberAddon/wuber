-- Round 13 (Google's in-game screenshot findings, ITEMS13), agent C (rider and map): I8, I12, I14,
-- I15, I16, I21, I22, I23, I25. Test names start "r13 c:". Loaded by run.lua with the module tests'
-- helpers (as round12_c.lua).
--   I8   no "ritual" in anything a player can see (every string literal in Wuber, the TOC, the
--        rider's ride screens); the spell's own name still reaches the game.
--   I12  Trips: one ride count on the whole page; a milestone whose rule holds shows earned.
--   I14  Confirm by zeppelin or boat: compared against that (free), never "Fly ... 23s".
--   I15  Earnings: the bars, the summary and the heatmap come from one log and agree (Wuber code;
--        the tour's numbers are the lab's).
--   I16  Found: the route and the level chip on a dark bar above the portal; "Orgrimmar" whole.
--   I21  World map: every listed driver has a pin (above the bounty coins); the legend names
--        zeppelins; a band over the art's own lettering.
--   I22  Home chips: every place a driver goes, most drivers first.
--   I23  Bounty: the live price lit; Take down a quiet button.
--   I25  Trips: "TIME SAVED" is a label, not a pill; the milestone glows stay in their cells.

local T = ...
local H, test, eq, ok, list = T.H, T.test, T.eq, T.ok, T.list
local newWorld, clean = T.newWorld, T.clean

local MIA = "Mia Runner"
local function texts(c) return list(c:visibleTexts(), " | ") end
local function has(c, pattern, plain) return #c:findText(pattern, false, plain) > 0 end
local function R(f) return H.rect(f) end
local function inside(a, b, slack)
	slack = slack or 0.5
	return a.l >= b.l - slack and a.l + a.w <= b.l + b.w + slack and a.b >= b.b - slack and a.b + a.h <= b.b + b.h + slack
end
local function apart(a, b)
	return a.l + a.w <= b.l + 0.5 or b.l + b.w <= a.l + 0.5 or a.b + a.h <= b.b + 0.5 or b.b + b.h <= a.b + 0.5
end

local function driverEntry(r, name, dest, state, extra)
	local key = name:lower()
	local e = { name = name, key = key, dest = dest, price = 5000, state = state or "open", team = 3,
		service = name:match("^(%S+)") .. "'s Rides", heard = r.env.GetTime(), queue = 0, ver = "2.3.0" }
	for k, v in pairs(extra or {}) do e[k] = v end
	r.W.drivers[key] = e
	return e
end

-- a rider in Orgrimmar with Mia open to Undercity; folded unless wide
local function riderWorld(wide)
	local w = newWorld()
	local r = T.rider(w, T.TESTCHAR, wide and { screenW = 2560, screenH = 1440 } or { screenW = 1365, screenH = 768 })
	if wide then r.wide = true end
	w:advance(15)
	r.W.drivers = r.W.drivers or {}
	driverEntry(r, MIA, "Undercity")
	if wide then r.W.db.coach = true else r.W.db.fold = { v = 1, pages = {}, narrow = true } end
	return w, r
end

local function withRide(w, r, state, extra)
	local ride = { id = "r13", driver = MIA, driverKey = "mia runner", dest = "Undercity", price = 5000, state = state,
		at = r.env.GetTime(), payee = MIA, payto = "Mia", service = "Mia's Rides" }
	for k, v in pairs(extra or {}) do ride[k] = v end
	r.W.ride = ride
	r.W.Fire("RIDE")
end

local function show(w, r, screen, key)
	r.W.UI.Toggle(true)
	w:advance(3)
	r.W.UI.Show(screen, key)
	w:advance(1.5)
	return r.W.UI.state.screens[screen]
end

---------------------------------------------------------------------------
-- I8. No "ritual" a player can see
---------------------------------------------------------------------------

-- Lua string literals with their line numbers (comments skipped; short and long strings)
local function literals(src)
	local out, i, n, line = {}, 1, #src, 1
	local function count(a, b)
		local _, k = src:sub(a, b):gsub("\n", "")
		line = line + k
	end
	while i <= n do
		local ch = src:sub(i, i)
		if ch == "\n" then
			line = line + 1
			i = i + 1
		elseif ch == "-" and src:sub(i, i + 1) == "--" then
			local long = src:match("^%-%-%[(=*)%[", i)
			local e
			if long then
				_, e = src:find("%]" .. long .. "%]", i + 4 + #long)
			else
				e = (src:find("\n", i, true) or (n + 1)) - 1
			end
			e = e or n
			count(i, e)
			i = e + 1
		elseif ch == '"' or ch == "'" then
			local j, buf = i + 1, {}
			while j <= n do
				local c2 = src:sub(j, j)
				if c2 == "\\" then
					buf[#buf + 1] = src:sub(j, j + 1)
					j = j + 2
				elseif c2 == ch or c2 == "\n" then
					break
				else
					buf[#buf + 1] = c2
					j = j + 1
				end
			end
			out[#out + 1] = { s = table.concat(buf), line = line }
			i = j + 1
		elseif ch == "[" and src:match("^%[=*%[", i) then
			local eq0 = src:match("^%[(=*)%[", i)
			local s0 = i + 2 + #eq0
			local _, e = src:find("%]" .. eq0 .. "%]", s0)
			e = e or n
			out[#out + 1] = { s = src:sub(s0, e - 2 - #eq0), line = line }
			count(i, e)
			i = e + 1
		else
			i = i + 1
		end
	end
	return out
end

-- The only literals with "ritual" in them: the spell's English name handed to the game, the
-- internal names (events, the saved option, the old addon's saved data and globals, its name
-- matched so it is never shown). Each one only on a line that does that (file, literal, line pattern).
local ALLOWED = {
	{ "Drive/Core.lua", "Ritual of Summoning", "^DR%.RITUAL_NAME = " },
	{ "Drive/Cast.lua", "Ritual of Summoning", "^return \"Ritual of Summoning\"$" },
	{ "Drive/Cast.lua", "Ritual", "call%(\"Ritual\"%)" },
	{ "Drive/Commands.lua", "Ritual", "call%(\"Ritual\"%)" },
	{ "Drive/Commands.lua", "ritual", "^setOpt%(\"ritual\"" },
	{ "Drive/Core.lua", "ritual", "\"tellBlocked\", \"ritual\", \"helpSeen\"" },
	{ "Drive/Service.lua", "ritual", "^if key == \"ritual\" then" },
	{ "UI/Settings/Rows.lua", "drive.ritual", "fieldRow%(drive, dy, \"drive%.ritual\"" },
	{ "UI/Settings/Rows.lua", "ritual", "setOpt%(\"ritual\", t%)" },
	{ "*", "RITUAL", "^W%.Fire%(\"RITUAL\"" },
	{ "*", "RITUAL", "^W%.Listen%(\"RITUAL\"" },
	{ "*", "DRIVE_RITUAL", "W%.Fire%(\"DRIVE_RITUAL\"" },
	{ "*", "DRIVE_RITUAL", "^W%.Listen%(\"DRIVE_RITUAL\"" },
	{ "*", "RitualRides", "rawget%(_G, \"RitualRides\"%)" },
	{ "*", "RitualRides", "DisableAddOn, \"RitualRides\"%)" },
	{ "*", "RitualRidesDB", "rawget%(_G, \"RitualRidesDB\"%)" },
	{ "*", "RitualRides_Team", "rawget%(_G, \"RitualRides_Team\"%)" },
	{ "*", "ritual%s*rides", ":find%(\"ritual%%s%*rides\"%)" },
}

local function allowed(file, lit, srcLine)
	local code = srcLine:gsub("^%s+", ""):gsub("%s+$", "")
	for _, a in ipairs(ALLOWED) do
		if (a[1] == "*" or a[1] == file) and a[2] == lit and code:find(a[3]) then return true end
	end
	return false
end

test("r13 c: I8 - no string a player can see says ritual (every literal in Wuber's files and the TOC)", function()
	local root = T.dir .. "/../Wuber/"
	local toc = assert(T.readFile(root .. "Wuber.toc"), "the TOC")
	for l in toc:gmatch("[^\r\n]+") do
		if not l:match("^##%s*SavedVariables") then ok(not l:lower():find("ritual", 1, true), "the TOC: " .. l) end
	end
	local bad, files = {}, 0
	for l in toc:gmatch("[^\r\n]+") do
		local f = l:match("^%s*([^#%s][^\r\n]-%.lua)%s*$")
		if f then
			f = f:gsub("\\", "/")
			local src = T.readFile(root .. f)
			ok(src, "read " .. f)
			files = files + 1
			ok(not f:lower():find("ritual", 1, true), "a file named ritual: " .. f)
			local lines = {}
			for ln in (src .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = ln end
			for _, lit in ipairs(literals(src)) do
				if lit.s:lower():find("ritual", 1, true) and not allowed(f, lit.s, lines[lit.line] or "") then
					bad[#bad + 1] = f .. ":" .. lit.line .. ": \"" .. lit.s .. "\""
				end
			end
		end
	end
	ok(files > 80, "files read: " .. files)
	eq(#bad, 0, "visible ritual:\n" .. table.concat(bad, "\n"))
end)

test("r13 c: I8 - the rider's ride screens never say ritual; the summoning step says 'Your summon is under way'", function()
	local w, r = riderWorld()
	local s
	for _, st in ipairs({ "accepted", "invited", "ingroup", "summoning", "portal", "arrived", "paying" }) do
		withRide(w, r, st, st == "portal" and { portalUp = true } or nil)
		s = s or show(w, r, "found")
		r.W.UI.Refresh(true)
		w:advance(1)
		for _, t in ipairs(r:visibleTexts()) do
			ok(not tostring(t):lower():find("ritual", 1, true), st .. ": " .. tostring(t))
		end
		if st == "summoning" then
			eq(s.title.wuberText, "Your summon is under way", "the summoning title")
			ok(has(r, "^Summon on its way$"), "the button adds to it, not the same words: " .. texts(r))
		end
		if st == "ingroup" then
			ok(has(r, "Stay put", true) and has(r, "Accept the portal when it pops up.", true), "the stay-put line (word rule): " .. texts(r))
		end
	end
	clean(w)
end)

test("r13 c: I8 - the spell's own name still reaches the game (the button's /cast and the spell lookup)", function()
	local w = newWorld()
	local d = T.driver(w, T.ANITA)
	w:advance(15)
	local DR = d.W.Drive
	eq(DR.RITUAL_NAME, "Ritual of Summoning", "the English name handed to the game")
	local spell = DR.Ritual()
	eq(spell, "Ritual of Summoning", "the lookup /cast uses")
	ok(DR.COMMANDS.spell and DR.COMMANDS.spell == DR.COMMANDS.ritual, "/wuber drive spell (the help's word) and ritual (the old one) are one command")
	-- the reasons a crew member can't summon read "summoning spell" / "summon on cooldown"
	local _, why = DR.CanCast("nobody here")
	ok(not tostring(why):lower():find("ritual", 1, true), "why: " .. tostring(why))
	clean(w)
end)

---------------------------------------------------------------------------
-- I12, I25. Trips
---------------------------------------------------------------------------

-- 11 paid rides to 2 places, 1h 50m saved; nothing recorded in W.db.milestones; the tour's level
-- (TierProgress 1, 12, 3, 25: another count)
local function tripsWorld()
	local w, r = riderWorld()
	local W = r.W
	W.db.rides, W.db.milestones, W.db.tierSeen = {}, {}, nil
	local stamp = r.env.time() - 86400 * 20
	for i = 1, 11 do
		W.db.rides[i] = { dest = i % 2 == 0 and "Undercity" or "Ratchet", driver = MIA, driverKey = "mia runner",
			price = 5000, at = stamp + i * 3600 * 30, saved = 600, savedValue = 1500 }
	end
	W.RebuildTotals()
	W.db.milestones = {}
	W.TierProgress = function() return 1, 12, 3, 25 end
	local s = show(w, r, "trips")
	w:advance(3)
	return w, r, W.UI.trips
end

local function cellNamed(tr, name)
	for _, c in ipairs(tr.cells) do
		-- (BRIEF19 F6) a medal below the folded view is hidden by Trips; its state is still the cell's
		if c.m and (c.m.name == name or c.m.id == name) then return c end
	end
end

test("r13 c: I12 - Trips counts the rides once: the line under the time and the level card agree", function()
	local w, r, tr = tripsWorld()
	eq(r.W.Stats().rides, 11, "11 paid rides")
	ok(tr.hero.cap.wuberText:find("11 rides across 2 places", 1, true), "the line under the time: " .. tostring(tr.hero.cap.wuberText))
	eq(tr.level.title.wuberText, "Silver Rider", "11 rides is Silver (from 10)")
	eq(tr.level.sub.wuberText, "11 rides · 14 more to Gold", "the level card from the same number")
	ok(not has(r, "12 rides", true), "no other count: " .. texts(r))
	clean(w)
end)

test("r13 c: I12 - a milestone whose rule holds shows earned (Hour Saver with 1h 50m saved)", function()
	local w, r, tr = tripsWorld()
	local hs = cellNamed(tr, "hoursaver")
	ok(hs, "the Hour Saver cell")
	ok(hs.earned, "Hour Saver earned at 1h 50m")
	ok(not H.visible(hs.lock), "no padlock")
	ok(cellNamed(tr, "rides10").earned and not cellNamed(tr, "rides25").earned, "10 Rides earned, 25 not")
	-- (review) recorded by the recorder, so W.db.milestones is the one source: it stays earned when
	-- the rule stops holding (a streak that ends)
	ok(r.W.db.milestones.hoursaver, "Hour Saver recorded in W.db.milestones")
	local real = r.W.Stats
	r.W.Stats = function() local s = real() s.saved, s.savedValue = 0, 0 return s end
	r.W.UI.UpdateTrips()
	w:advance(1)
	ok(cellNamed(tr, "hoursaver").earned, "still earned once the rule no longer holds")
	r.W.Stats = real
	-- (re-review) the recorder's celebration: a milestone that comes true without a new trip
	-- fires MILESTONE once when Trips draws it; drawing again fires nothing
	r.W.db.milestones.hoursaver = nil
	local fired, fire = {}, r.W.Fire
	r.W.Fire = function(name, ...)
		if name == "MILESTONE" then fired[#fired + 1] = select(2, ...) end
		return fire(name, ...)
	end
	r.W.UI.UpdateTrips()
	w:advance(1)
	eq(#fired, 1, "one MILESTONE")
	ok(type(fired[1]) == "table" and table.concat(fired[1], ","):find("hoursaver", 1, true), "Hour Saver in it")
	r.W.UI.UpdateTrips()
	w:advance(1)
	eq(#fired, 1, "not again")
	r.W.Fire = fire
	clean(w)
end)

test("r13 c: I25 - TIME SAVED is a plain label (no pill); the milestones have no glow", function()
	local w, r, tr = tripsWorld()
	ok(has(r, "^Time saved$"), "the label: " .. texts(r))
	for _, t in ipairs(tr.hero.kicker.fill.parts) do ok(not H.visible(t), "no pill behind TIME SAVED (Wrapped is the button)") end
	-- r50 H24-01: the first medal row hides under the cue at scroll 0, so scroll the folded page a little first
	do
		local M, tv = r.W.Mod("UI.Rider.Trips"), r.W.Mod("UI.Rider.Trips").view()
		local y = math.min(100, tv.scrollMax or 0)
		tv.scroll, tv.scrollTarget = y, y
		tv.content:ClearAllPoints()
		tv.content:SetPoint("TOPLEFT", tv.clip, "TOPLEFT", 0, y)
		M.trimCells()
	end
	local lit = {}
	for _, c in ipairs(tr.cells) do
		if c:IsShown() and c.earned then lit[#lit + 1] = c end
	end
	ok(#lit >= 3, "earned cells: " .. #lit)
	for _, c in ipairs(lit) do
		-- (design 1) no glow: the halo is an empty object, nothing drawn behind an earned cell
		ok(c.halo == nil or next(c.halo) == nil, "no glow on " .. c.m.id)
	end
	clean(w)
end)

---------------------------------------------------------------------------
-- I14. Confirm by zeppelin
---------------------------------------------------------------------------

test("r13 c: I14 - Orgrimmar to Undercity by zeppelin: Confirm compares against the zeppelin (free), not a 23s flight", function()
	local w, r = riderWorld()
	r.W.TravelSaved = function() return 300, "by zeppelin" end
	r.W.FlightCost = function() return 2300, 1 end -- (the photo tour's flight price: no route has one)
	local s = show(w, r, "confirm", "mia runner")
	local dial = s.dial
	ok(H.visible(dial), "the dial: " .. texts(r))
	eq(dial.flyHead.wuberText, "Zeppelin", "the left side is the zeppelin")
	eq(dial.flyText.wuberText, "about 5 min · free", "its time, and free")
	ok(not dial.summonText.wuberText:find("net", 1, true), "no net against a free trip: " .. dial.summonText.wuberText)
	ok(not dial.verdict.wuberText:find("Flying", 1, true), "the verdict: " .. dial.verdict.wuberText)
	ok(not has(r, "vs flying", true), "nothing says vs flying: " .. texts(r))
	ok(not has(r, "^Fly$"), "no Fly head: " .. texts(r))
	-- flights to the port and then the zeppelin (a priced route with the crossing on it)
	r.W.FlightCost = function() return 2300, 1, "table", "boat" end
	r.W.UI.Refresh(true)
	w:advance(1)
	eq(dial.flyHead.wuberText, "Fly + zeppelin", "flights and the zeppelin")
	ok(dial.flyText.wuberText:find("23", 1, true), "the flights' price: " .. dial.flyText.wuberText)
	-- a flight on one continent: as before
	r.W.TravelSaved = function() return 300 end
	r.W.FlightCost = function() return 2300, 1 end
	r.W.UI.Refresh(true)
	w:advance(1)
	eq(dial.flyHead.wuberText, "Fly", "a plain flight")
	clean(w)
end)

---------------------------------------------------------------------------
-- I16. Found: the header bar
---------------------------------------------------------------------------

test("r13 c: I16 - the portal screen's route and level chip sit on a dark bar above the portal; Orgrimmar whole", function()
	local w, r = riderWorld()
	r.W.DestHere = function() return "Orgrimmar", { name = "Orgrimmar", kind = "city" } end
	r.W.TravelSaved = function() return 300, "by zeppelin" end
	r.W.Tier = function() return 2 end
	withRide(w, r, "portal", { portalUp = true })
	local s = show(w, r, "found")
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(s.bar and H.visible(s.bar), "the bar")
	ok(H.visible(s.route), "the route: " .. texts(r))
	eq(s.route.fromShown, "Orgrimmar", "the start whole, not Or...")
	ok(H.visible(s.route.via), "the zeppelin tag")
	ok(inside(R(s.route), R(s.bar), 1), "the route on the bar")
	if H.visible(s.tier) then
		ok(inside(R(s.tier), R(s.bar), 1), "the level chip on the bar")
		ok(apart(R(s.route), R(s.tier)), "the route clear of the chip")
	end
	-- a short route: the chip has room ("Silver rider" on the bar)
	r.W.DestHere = function() return "Brill", { name = "Brill", kind = "town" } end
	r.W.TravelSaved = function() return 300 end
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(H.visible(s.tier), "the chip shows with room: " .. texts(r))
	ok(inside(R(s.tier), R(s.bar), 1) and apart(R(s.route), R(s.tier)), "chip and route side by side on the bar")
	local hero, bar = R(s.hero), R(s.bar)
	ok(hero.b + hero.h <= bar.b + 0.5, "the portal below the bar: " .. (hero.b + hero.h) .. " vs " .. bar.b)
	ok((s.bar:GetFrameLevel() or 0) > (s.hero:GetFrameLevel() or 0) + 2, "the bar above the portal's flipbook")
	ok(apart(R(s.title), hero), "the title clear of the portal")
	-- arrived (the pay look): no bar, the chip back by the title
	withRide(w, r, "arrived")
	r.W.UI.Refresh(true)
	w:advance(1)
	ok(not H.visible(s.bar), "no bar on the pay look")
	clean(w)
end)

---------------------------------------------------------------------------
-- I21. The world map
---------------------------------------------------------------------------

test("r13 c: I21 - world map: a busy driver's pin shows (above a bounty coin there); the legend names zeppelins; the art band", function()
	local w, r = riderWorld(true)
	local W = r.W
	driverEntry(r, "Ivy Express", "Booty Bay", "busy", { price = 7500, queue = 2 })
	W.FlightCost = function() return nil end
	W.Bounty = { Mine = function() return nil end, Demand = function() return { { place = "Booty Bay", riders = 2 } } end }
	W.UI.Toggle(true)
	w:advance(3)
	local Map = W.Mod("UI.Rider.WorldMap")
	local wm = Map.cache.last
	ok(wm and wm.mode == "world" and wm.built, "the world view")
	Map.Refresh()
	w:advance(1)
	eq(wm.pinCount, 2, "two places, two pins (Mia open, Ivy busy)")
	eq(wm.coinCount, 1, "the bounty coin at Booty Bay")
	local coin = wm.coins[1]
	for i = 1, wm.pinCount do
		local p = wm.pins[i]
		ok(H.visible(p), "pin " .. i)
		ok((p:GetFrameLevel() or 0) > (coin:GetFrameLevel() or 0), "pins above coins")
	end
	local legend = {}
	for _, fs in ipairs(wm.legend) do legend[#legend + 1] = fs.wuberText end
	eq(table.concat(legend, ", "), "Flight, Boat or zeppelin, Driver, Bounty", "the legend (Horde)")
	local last = R(wm.legend[#wm.legend])
	ok(last.l + last.w <= R(wm.view).l + R(wm.view).w, "the legend inside the pane")
	for cont, box in pairs(wm.boxes) do
		ok(box.band and #box.band == 2, "the band over the art's lettering, box " .. cont)
		local game = wm.kind ~= "fallback"
		eq(H.visible(box.band[1]) == true, game and true or false, "shown with game art only (" .. tostring(wm.kind) .. ")")
	end
	clean(w)
end)

---------------------------------------------------------------------------
-- I22, I23. Home
---------------------------------------------------------------------------

local function chipLabels(s)
	local out = {}
	for _, c in ipairs(s.chips.list) do
		if H.visible(c) then out[#out + 1] = c.tag.label.wuberText end
	end
	return table.concat(out, ", ")
end

test("r13 c: I22 - Home's chips: every place a driver goes, most drivers first (your own advert counts)", function()
	local w, r = riderWorld()
	local W = r.W
	-- the photo tour: you (driving to Undercity) and Mia to Undercity, Bob to Ratchet, Ivy busy to Booty Bay
	driverEntry(r, "Bob Rides", "Ratchet", "open", { price = 6000, team = 1 })
	driverEntry(r, "Ivy Express", "Booty Bay", "busy", { price = 7500, team = 2, queue = 2 })
	local me = r.W.myKey or (W.Key and W.Key(T.TESTCHAR))
	driverEntry(r, T.TESTCHAR, "Undercity", "open")
	W.drivers[T.TESTCHAR:lower()].key = me
	local s = show(w, r, "home")
	eq(chipLabels(s), "All, Undercity, Booty Bay, Ratchet", "every place, Undercity (two drivers) first")
	for _, c in ipairs(s.chips.list) do
		if H.visible(c) then ok(inside(R(c), R(s.sheet), 1), "chip inside the sheet: " .. c.tag.label.wuberText) end
	end
	clean(w)
end)

test("r13 c: I23 - a live bounty lights its price; Take down is a quiet button", function()
	local w, r = riderWorld()
	local mine = { place = "Gadgetzan", copper = 5000, at = r.env.time() }
	r.W.Bounty = { Mine = function() return mine end, Cancel = function() mine = nil return true end, Demand = function() return {} end,
		Pin = function(place, copper) mine = { place = place, copper = copper, at = r.env.time() } return true end }
	local s = show(w, r, "home")
	r.W.UI.SetSearch("Gadgetzan")
	w:advance(1)
	local bb = s.empty.bounty
	ok(H.visible(bb), "the bounty picks: " .. texts(r))
	eq(bb.picks[1].style, "violet", "50s lit")
	ok(not bb.picks[1].inactive, "lit, not greyed")
	for i = 2, 4 do ok(bb.picks[i].inactive, "the other prices quiet: " .. i) end
	-- (design 2) Take down is a link on your bounty's row (no gold, no x); Pin, the main button, hides while it is up
	ok(not H.visible(bb.pin), "no Pin while the bounty is up")
	ok(H.visible(s.bountyChip) and H.visible(s.bountyChip.close), "your bounty's row and its link: " .. texts(r))
	eq(s.bountyChip.close.label.wuberText, "Take down", "Take down")
	eq(s.bountyChip.close.style, "ghost", "a link, not the gold button")
	-- clicking another price while it is up changes nothing
	bb.picks[2]:Click()
	w:advance(0.5)
	eq(bb.picks[1].style, "violet", "still 50s")
	-- an amount of your own: Custom lit
	mine.copper = 6000
	r.W.UI.Refresh(true)
	w:advance(1)
	eq(bb.picks[4].style, "violet", "Custom lit for 60s")
	ok(not bb.picks[4].inactive, "Custom not greyed")
	-- taken down: Pin is the gold button again
	s.bountyChip.close:Click()
	w:advance(1)
	ok(H.visible(bb.pin), "Pin is back")
	eq(bb.pin.style, "primary", "Pin is gold again")
	clean(w)
end)

---------------------------------------------------------------------------
-- I15. Earnings: one log, three views that agree
---------------------------------------------------------------------------

test("r13 c: I15 - Earnings: the hour bars, the summary and the heatmap agree for Today, 7 days and 30 days", function()
	local w = newWorld()
	local d = T.driver(w, T.ANITA)
	w:advance(15)
	local DR, env = d.W.Drive, d.env
	local l = DR.Log()
	local now = env.time()
	-- rides every 5 hours over 20 days, an hour open around each
	for k = 0, 95 do
		local at = now - k * 5 * 3600 - 600
		l.rides[#l.rides + 1] = table.concat({ at, 5000 + (k % 3) * 1000, "Rider" .. k, "Undercity", "t", 5000 }, ",")
		local hk = env.date("%Y%m%d%H", at)
		l.open[hk] = (l.open[hk] or 0) + 60
	end
	d.W.Fire("DRIVE_LOG")
	for _, days in ipairs({ 1, 7, 30 }) do
		local hours = DR.Hours(days, "me")
		local tot = DR.LogTotals(DR.LogSince(days), "me")
		local c, o, n = 0, 0, 0
		for h = 0, 23 do c, o, n = c + hours[h].copper, o + hours[h].open, n + hours[h].rides end
		eq(c, tot.copper, days .. " days: the bars' gold is the summary's")
		eq(o, tot.open, days .. " days: the bars' open time is the summary's")
		eq(n, tot.rides, days .. " days: the bars' rides are the summary's")
		-- the heatmap (at least 7 days) holds every hour the bars show
		local grid = DR.Heatmap(math.max(days, 7), "me")
		for h = 0, 23 do
			local col = 0
			for wd = 0, 6 do col = col + grid[wd][h].copper end
			ok(col >= hours[h].copper, days .. " days, " .. h .. ":00: heatmap " .. col .. " vs bars " .. hours[h].copper)
			if days >= 7 then eq(col, hours[h].copper, days .. " days, " .. h .. ":00: the same gold") end
		end
	end
	clean(w)
end)

test("r13 c: I15 - Earnings: a tapped heatmap hour stays tapped when the page folds or unfolds; its pill says g/h", function()
	local w = newWorld()
	local d = T.driver(w, T.ANITA, { spot = "Undercity" })
	w:advance(15)
	local W, DR, env = d.W, d.W.Drive, d.env
	d.wide = true -- (as round8_d's console: the harness keeps old tests folded unless they opt in)
	W.db.coach = true
	W.UI.WindowWide(true)
	local l = DR.Log()
	local t = env.time()
	for k = 0, 40 do
		local at = t - k * 5 * 3600 - 600
		l.rides[#l.rides + 1] = table.concat({ at, 5000, "Rider" .. k, "Undercity", "t", 5000 }, ",")
		local hk = env.date("%Y%m%d%H", at)
		l.open[hk] = (l.open[hk] or 0) + 60
	end
	W.Fire("DRIVE_LOG")
	local D, UI = W.Driver, W.UI
	T.openDrive(d)
	D.ShowScreen("earnings")
	w:advance(1)
	eq(UI.Fold.Page(), "earnings", "the earnings page")
	local s = UI.drive.screens.earnings
	ok(UI.Fold.IsUnfolded(), "unfolded to start")
	UI.Fold.Toggle()
	w:advance(1)
	s.update()
	ok(not UI.Fold.IsUnfolded() and H.visible(s.heat), "folded: the heatmap under the numbers: "
		.. tostring(UI.Fold.IsUnfolded()) .. " " .. tostring(s.heat:IsShown()))
	local cell = s.heat.bestCell
	ok(cell, "a square with numbers")
	H.runScript(cell, "OnClick", "LeftButton")
	local said = s.heat.info:GetText()
	-- unfold: the other heatmap shows the same square tapped
	UI.Fold.Toggle()
	w:advance(1)
	s.update()
	ok(UI.Fold.IsUnfolded() and s.heatW and H.visible(s.heatW), "unfolded: the heatmap on the right")
	local p = s.heatW.picked
	ok(p and p.wday == cell.wday and p.hour == cell.hour, "the same hour tapped")
	ok(s.heatW.sel:IsShown(), "its white frame")
	eq(s.heatW.info:GetText(), said, "the same numbers")
	-- tap another there, fold: kept the other way too
	local other
	for _, b in ipairs(s.heatW.cells) do if b.wday ~= cell.wday or b.hour ~= cell.hour then other = b break end end
	H.runScript(other, "OnClick", "LeftButton")
	UI.Fold.Toggle()
	w:advance(1)
	s.update()
	local q = s.heat.picked
	ok(q and q.wday == other.wday and q.hour == other.hour, "folded again: the square tapped last")
	eq(s.heat.info:GetText(), s.heatW.info:GetText(), "the same numbers")
	-- per hour as the chart says it ("target 1g/h"), not "/hr"
	ok(said:find("/h ·", 1, true) and not said:find("/hr", 1, true), "/h, as the chart: " .. said)
	clean(w)
end)

---------------------------------------------------------------------------
-- Review of round 13: the driver's screens (I8) and the pay card (I14)
---------------------------------------------------------------------------

local function tipOf(c, f)
	local gt = c.env.GameTooltip
	H.state[gt].tipLines = {}
	local fn = H.state[f] and H.state[f].scripts and H.state[f].scripts.OnEnter
	ok(fn, "the control has a tooltip")
	if fn then fn(f) end
	local out = {}
	for _, l in ipairs(H.state[gt].tipLines or {}) do out[#out + 1] = type(l) == "table" and tostring(l.text or l[1]) or tostring(l) end
	return table.concat(out, "\n")
end

test("r13 c: I8 - the driver never reads ritual: plan.say, the big button's tooltips (card, slot, floating), /wuber drive spell; /cast still names the spell", function()
	local w = newWorld()
	local a = w:addClient(T.ANITA, { spot = "Undercity", class = "WARLOCK" })
	w:advance(15)
	local W, DR = a.W, a.W.Drive
	ok(DR.SetOpen(true), "open")
	w:addBot("Dan Miller")
	w:botWhisper("Dan Miller", a, "summon pls")
	w:advance(4)
	local p = DR.Plan()
	ok(type(p) == "table" and p.macrotext and p.macrotext:find("/cast Ritual of Summoning", 1, true),
		"the macro casts the spell by its name: " .. tostring(p and p.macrotext))
	ok(p.say and p.say:find("casts the summon", 1, true), "plan.say: " .. tostring(p.say))
	ok(not tostring(p.say):lower():find("ritual", 1, true), "plan.say: " .. tostring(p.say))
	-- the floating button's tooltip (the macro shown with the spell said plainly)
	local b = a.env.WuberDriveButton
	ok(b, "the big button")
	local ft = tipOf(a, b)
	ok(ft:find("casts the summon", 1, true), "floating: " .. ft)
	ok(not ft:lower():find("ritual", 1, true), "floating: " .. ft)
	-- (re-review) the macro built with one name, the spell found by another now: still no name
	local ritual = DR.Ritual
	DR.Ritual = function() return "Summon Circle", true end
	local ft2 = tipOf(a, b)
	ok(ft2:find("/cast the summoning spell", 1, true) and not ft2:lower():find("ritual", 1, true), "another name since: " .. ft2)
	DR.Ritual = ritual
	-- the console's card and slot
	T.openDrive(a)
	W.UI.ShowDrive("console")
	w:advance(1)
	W.Driver.RefreshNow()
	w:advance(1)
	local v = W.Driver.ui.console
	for _, f in ipairs({ v.hero, v.slot }) do
		local t = tipOf(a, f)
		ok(t:find("casts the summon", 1, true), "card/slot: " .. t)
		ok(not t:lower():find("ritual", 1, true), "card/slot: " .. t)
	end
	for _, t in ipairs(a:visibleTexts()) do ok(not t:lower():find("ritual", 1, true), "on screen: " .. t) end
	-- the commands
	local n0 = #a.chatLines
	a:slash("/wuber drive spell")
	a:slash("/wuber drive ritual")
	a:slash("/wuber drive")
	ok(#a.chatLines > n0, "the commands answered")
	for i = n0 + 1, #a.chatLines do ok(not a.chatLines[i]:lower():find("ritual", 1, true), "said: " .. a.chatLines[i]) end
	local said = table.concat(a.chatLines, "\n", n0 + 1)
	ok(said:find("The button casts the summoning spell", 1, true), "said: " .. said)
	-- a name of the player's own is theirs to see
	local n1 = #a.chatLines
	a:slash("/wuber drive spell Beschwörungsritual")
	local own = table.concat(a.chatLines, "\n", n1 + 1)
	ok(own:find("Beschwörungsritual", 1, true), "own name: " .. own)
	clean(w)
end)

test("r13 c: I14 - a ride by zeppelin saves no flight cost: the pay card agrees with Confirm (free)", function()
	for _, via in ipairs({ false, "boat" }) do
		local w, r = riderWorld()
		r.W.FlightCost = function() return 2300, 1, nil, via or nil end
		show(w, r, "home")
		local ride = r.W.RequestRide("mia runner")
		ok(type(ride) == "table", "the ride asked")
		if via then
			eq(r.W.ride.flightCost, 2300, "a priced route with the zeppelin on it keeps its price")
		else
			eq(r.W.ride.flightCost, nil, "by zeppelin: no flight cost")
			r.W.ride.state = "arrived"
			r.W.Fire("RIDE")
			r.W.UI.Show("found")
			w:advance(2)
			ok(not has(r, "Flying here costs", true), "the pay card: " .. texts(r))
		end
		clean(w)
	end
end)
