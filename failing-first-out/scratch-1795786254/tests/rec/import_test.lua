-- Tests of tools/rec/import.lua (saved recorder data -> test fixtures), end to end on a WuberRec.lua
-- written in WoW's SavedVariables format from a recording made here in the fake game. Loaded by
-- tests/run.lua with its helper table T.
local T = ...
local H, test, eq, ok, list = T.H, T.testOutside or T.test, T.eq, T.ok, T.list -- (testOutside: not in the behaviour transcript)

local ADDON = dofile(T.dir .. "/lib/rec_addon.lua") -- where the recorder is, and which version these tests are for
local REC_DIR = ADDON.dir()
local ROOT = T.dir .. "/.."
local IMP = assert(loadfile(ROOT .. "/tools/rec/import.lua"))("--lib")
local SES = IMP.SES
local OUT = T.dir .. "/out/rec/imp"
local ROCKS = "Wuber Rocks"
local OTHER = T.BOB

local function mkdir(path)
	if package.config:sub(1, 1) == "\\" then
		os.execute('if not exist "' .. path:gsub("/", "\\") .. '" mkdir "' .. path:gsub("/", "\\") .. '"')
	else
		os.execute('mkdir -p "' .. path .. '"')
	end
end

local function writeFile(path, text)
	local f = assert(io.open(path, "wb"))
	f:write(text)
	f:close()
end

-- deep equality of plain values
local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in pairs(a) do if not same(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end

local function quiet()
	local lines = {}
	return function(s) lines[#lines + 1] = tostring(s) end, lines
end

-- a recording made here: the rider with the recorder, another player (a driver) online nearby, a
-- trade opened and closed, a ring small enough to wrap
local recorded
local function record()
	if recorded then return recorded end
	H.ADDONS.WuberRec = REC_DIR
	local w = T.newWorld()
	local d = T.driver(w, OTHER, { spot = "Orgrimmar" })
	local c = w:addClient(ROCKS, { spot = "Orgrimmar", class = "MAGE", money = 100000, addons = { "Wuber", "WuberRec" },
		allowMissing = not T.HAVE_UI })
	w:advance(15)
	c.ns.WuberRec.C.EVENTS = 12
	c:slash("/rec on")
	T.goOnline(d)
	w:advance(20)
	for i = 1, 20 do c:slash("/rec mark row " .. i) end
	w:openTrade(d, c)
	w:advance(1)
	w:tradeCancel(c)
	w:advance(2)
	c:slash("/rec off")
	T.clean(w)
	recorded = { db = c.env.WuberRecDB }
	return recorded
end

local function saveAs(account, db)
	local dir = OUT .. "/WTF/Account/" .. account .. "/SavedVariables"
	mkdir(dir)
	local path = dir .. "/WuberRec.lua"
	writeFile(path, IMP.savedText("WuberRecDB", db))
	return path
end

if not ADDON.have() then
	test("rec: import: the recording tests are skipped (" .. ADDON.why() .. ")", function() end)
end

---------------------------------------------------------------------------

test("rec: import: the writer: sorted keys, rows on one line, numbers and strings read back equal", function()
	local v = { b = 2, a = { 0.1, 1 / 3, -0.5, 1e-300, 123456789012, 2 ^ 53 + 2 }, ["with space"] = "tab\there\nnew \"q\" \\ \1",
		events = { { 1, "X", { k = true } } }, [3] = "three", [1] = "one", nested = { { x = 1, y = { 2, 3 } } }, holes = {} }
	v.holes[1], v.holes[3] = "a", "c"
	local text = IMP.serialize(v)
	ok(not text:find("[ \t]\n"), "no trailing spaces")
	eq(IMP.serialize(v), text, "the same bytes again")
	local back = assert(loadstring(text))()
	ok(same(back, v), "reads back equal")
	ok(text:find('\tevents = {\n\t\t{ 1, "X", { k = true } },\n', 1, true), "an event row on one line: " .. text)
	ok(text:find('\ta = {', 1, true) and text:find('\tb = 2,', 1, true) and text:find('\ta = {', 1, true) < text:find('\tb = 2,', 1, true),
		"sorted keys")
	-- the game's own format reads back too, through the importer's loader
	local db = IMP.loadSaved(IMP.savedText("WuberRecDB", v))
	ok(same(db, v), "SavedVariables format reads back equal")
end)

test("rec: import: a hostile input file (code, not a table) is refused without running it", function()
	local ran = false
	rawset(_G, "REC_IMPORT_RAN", function() ran = true return {} end)
	local bad = {
		"WuberRecDB = REC_IMPORT_RAN()",
		"REC_IMPORT_RAN()",
		"WuberRecDB = REC_IMPORT_RAN { }",
		'WuberRecDB = REC_IMPORT_RAN "x"',
		"WuberRecDB = { a = REC_IMPORT_RAN { } }",
		"WuberRecDB = {} while true do end",
		"WuberRecDB = (function() REC_IMPORT_RAN() return {} end)()",
		"local x = REC_IMPORT_RAN WuberRecDB = {}",
		'WuberRecDB = { [ [[a]] ] = os.exit }',
		"WuberRecDB = 5",
		"WuberRecDB = 'text'",
		"Other = {}",
		"WuberRecDB = {",
	}
	mkdir(OUT .. "/bad")
	for i, text in ipairs(bad) do
		local db, why = IMP.loadSaved(text)
		eq(db, nil, "accepted: " .. text)
		ok(tostring(why):find("refused", 1, true), "why: " .. tostring(why))
		local path = OUT .. "/bad/WuberRec-" .. i .. ".lua"
		writeFile(path, text)
		local done, err = IMP.importFile(path, { out = OUT .. "/bad", source = "game" })
		eq(done, nil, "importFile refused " .. text)
		ok(err, "and said why")
	end
	ok(not ran, "nothing in a file ran")
	rawset(_G, "REC_IMPORT_RAN", nil)
	-- data that builds itself forever is stopped too (plain data cannot loop: a very large file is the case)
	local okBig = IMP.loadSaved("WuberRecDB = { " .. string.rep("1, ", 2000) .. "}")
	ok(type(okBig) == "table" and #okBig == 2000, "a big plain table is fine")
end)

test("rec: import: the tool only reads its input: io.open 'rb' on the input, one 'wb' (its own fixture), no remove or rename", function()
	local src = T.readFile(ROOT .. "/tools/rec/import.lua")
	local code = src:gsub("%-%-[^\n]*", "")
	local modes = {}
	for args in code:gmatch("io%.open(%b())") do modes[#modes + 1] = args end
	eq(#modes, 3, "io.open calls: " .. list(modes))
	local wb = 0
	for _, a in ipairs(modes) do
		if a:find('"wb"', 1, true) then
			wb = wb + 1
			eq(a, '(item.path, "wb")', "the only write is the fixture")
		else
			ok(a:find('"rb"', 1, true), "read as rb: " .. a)
		end
	end
	eq(wb, 1)
	ok(not code:find("os%.remove") and not code:find("os%.rename") and not code:find("os%.execute"), "no remove, rename or shell command")
	ok(code:find("setfenv(chunk, env)", 1, true) and code:find("local env = {}", 1, true), "an empty environment")
end)

if not ADDON.have() then return end

test("rec: import: a recorded WuberRec.lua becomes fixtures; the input is unchanged; --wtf finds every account; --list writes nothing", function()
	local rec = record()
	local path = saveAs("TEST", rec.db)
	saveAs("SECOND", { v = 1, sessions = {} })
	local before = T.readFile(path)
	local outDir = OUT .. "/fixtures"
	mkdir(outDir)
	-- --list: says what is there, writes nothing
	local say, lines = quiet()
	eq(IMP.main({ "--wtf", OUT .. "/WTF", "--out", outDir .. "/none", "--source", "sim", "--list" }, say), 0, list(lines, "\n"))
	ok(list(lines, "\n"):find("TEST/SavedVariables/WuberRec.lua: 1 session(s)", 1, true), list(lines, "\n"))
	ok(list(lines, "\n"):find("SECOND/SavedVariables/WuberRec.lua: 0 session(s)", 1, true), "the second account")
	ok(not H.exists(outDir .. "/none/") and not list(lines, "\n"):find("wrote", 1, true), "nothing written")
	-- the import
	local say2, lines2 = quiet()
	eq(IMP.main({ "--wtf", OUT .. "/WTF", "--out", outDir, "--source", "sim" }, say2), 0, list(lines2, "\n"))
	local all = list(lines2, "\n")
	local name = all:match("(sim%-[%w%-]+%-wuber%-rocks%.lua)")
	ok(name, "a fixture named <source>-<id>-<character>: " .. all)
	ok(all:find("%d+ P%-numbers"), "the P-number count is printed: " .. all)
	ok(not all:find(" 0 P-numbers", 1, true), "the other player is a P-number")
	local fxText = T.readFile(outDir .. "/" .. name)
	ok(fxText and fxText:sub(1, 8) == "return {", "written: " .. name .. " in " .. all)
	local fx = assert(loadstring(fxText))()
	eq(fx.source, "sim")
	eq(fx.char, ROCKS)
	eq(fx.epoch, nil, "sim: no machine time")
	eq(fx.span, 3600, "the hour as a span")
	eq(T.readFile(path), before, "the input file's bytes are unchanged")
	ok(not fxText:find(OTHER, 1, true), "no real name in the fixture")
	-- the same input gives the same bytes
	local again = assert(IMP.importFile(path, { source = "sim", out = outDir, write = false }))
	eq(again[1].text, fxText, "deterministic")
end)

test("rec: import: the ring is unrolled oldest first and the dropped rows are counted", function()
	local rec = record()
	local s = rec.db.sessions[1]
	ok(s.n > 12, "the ring wrapped: " .. s.n)
	eq(#s.events, 12)
	local fx = IMP.convert(s, "sim")
	eq(#fx.events, 12)
	eq(fx.dropped.events, s.n - 12)
	for i = 2, #fx.events do ok(fx.events[i].t >= fx.events[i - 1].t, "in time order") end
	-- the marks among the kept rows are the last ones, in order
	local marks = {}
	for _, e in ipairs(fx.events) do if e.e == "REC_MARK" then marks[#marks + 1] = tonumber(e.a[1]:match("%d+")) end end
	for i = 2, #marks do eq(marks[i], marks[i - 1] + 1, "marks in order") end
	-- and the unroll itself, on a hand-made ring
	local rows, dropped = SES.unroll({ { "e6" }, { "e7" }, { "e3" }, { "e4" }, { "e5" } }, 7, 5)
	local got = {}
	for i, r in ipairs(rows) do got[i] = r[1] end
	eq(table.concat(got, ","), "e3,e4,e5,e6,e7")
	eq(dropped, 2)
end)

test("rec: import: privacy: a denied name refuses the fixture; the recorder's P-numbers pass", function()
	local rec = record()
	mkdir(OUT) -- (the folder may not exist yet when another shard ran the tests that make it)
	local denyPath = OUT .. "/deny.txt"
	writeFile(denyPath, "# names that must never be in a fixture\n" .. OTHER .. "\n")
	local deny = assert(IMP.readDeny(denyPath))
	eq(#deny, 1)
	local good = saveAs("DENYGOOD", rec.db)
	local outDir = OUT .. "/deny"
	mkdir(outDir)
	local done = assert(IMP.importFile(good, { out = outDir, source = "sim", deny = deny }))
	eq(done[1].refused, nil, "the recording has no real name")
	ok(done[1].pn >= 1, "P-numbers: " .. done[1].pn)
	-- a session with the name in it (as a recorder bug would leave it)
	local leaky = SES.copy(rec.db)
	local ss = leaky.sessions[1]
	ss.events[1] = { 1, "CHAT_MSG_ADDON", 4, "WUBER", "D~1~" .. OTHER:lower():gsub(" ", "-"), "CHANNEL", "P1" }
	local bad = saveAs("DENYBAD", leaky)
	local say, lines = quiet()
	eq(IMP.main({ "--file", bad, "--out", outDir, "--source", "sim", "--deny", denyPath }, say), 1, "the tool fails")
	ok(list(lines, "\n"):find("REFUSED", 1, true), list(lines, "\n"))
	local done2 = assert(IMP.importFile(bad, { out = outDir, source = "sim", deny = deny, write = false }))
	ok(done2[1].refused and not done2[1].text, "no text made")
	eq(IMP.privacy({ "x", { "Bob-Stone" } }, deny), OTHER, "a hyphen spelling is caught")
	eq(IMP.privacy({ "x", { "BOBSTONE" } }, deny), OTHER, "no space, upper case")
end)

test("rec: import: facts: every kind is derived from the sample sessions, table-driven", function()
	local files = {}
	for _, p in ipairs(H.listFiles(T.dir .. "/fixtures/rec", "lua")) do
		if p:match("/sim%-[^/]+%.lua$") then files[#files + 1] = p end
	end
	ok(#files >= 2, "the sample fixtures (tests/rec/recorder_test.lua makes them)")
	local ids = {}
	for _, p in ipairs(files) do
		local fx = assert(loadfile(p))()
		-- the facts in the file are what the tool derives now
		local fresh = IMP.facts(fx)
		ok(same(fresh, fx.facts), p .. ": facts are current")
		for i, f in ipairs(fx.facts) do
			ids[f.id] = f
			ok(f.q and f.id and f.v ~= nil, "fact shape")
			if i > 1 then ok(fx.facts[i - 1].id < f.id, "sorted by id") end
		end
	end
	for _, id in ipairs({ "boot:order", "event:argc:CHAT_MSG_ADDON", "event:unknown", "api:C_Map.GetBestMapForUnit", "gs:ERR_TRADE_COMPLETE",
		"build", "unitname:shape", "screen:ui", "frame:Minimap", "taxi:frame", "taxi:nodes", "taxi:has", "map:art:947", "map:world:1414",
		"map:kids:1414", "map:chain", "name:shape:CHAT_MSG_ADDON:4", "trade:closed:count", "summon:arrival", "leave:cancel_summon",
		"reload:pew", "boot:file", "channels:reload", "settings:known" }) do
		ok(ids[id], "fact " .. id)
	end
	eq(ids["taxi:frame"].v.name, "TaxiFrame")
	eq(ids["taxi:nodes"].v.n, 5)
	eq(ids["taxi:nodes"].v.inside, 5)
	eq(list(ids["taxi:nodes"].v.types, ","), "CURRENT,NONE,REACHABLE")
	eq(ids["screen:ui"].v.w, 1920)
	eq(ids["screen:ui"].v.from, "UIParent", "UIParent's own size (it only holds protected frames)")
	eq(ids["screen:ui"].v.holds, true)
	eq(ids["boot:order"].v[1].e, "ADDON_LOADED")
	-- a /reload is not a login (the corrected fake, as the real client): PEW(false, true), no zone event
	eq(ids["reload:pew"].v.zone, false, "no ZONE_CHANGED_NEW_AREA after a /reload")
	eq(list(ids["reload:pew"].v.a, ","), "false,true")
	eq(ids["channels:reload"].v.n, 6, "the reload kept the game's five channels and WuberNet")
	eq(ids["settings:known"].v, true, "a settings snapshot")
	eq(ids["boot:file"].v.wdb, "table", "Wuber's saved data was there when the recorder's file ran")
	eq(ids["api:C_TaxiMap"].v, "t", "the fake has C_TaxiMap, as the real client")
	eq(ids["build"].v[4], 16001)
	-- a fresh login (no sample session has one): the channels at PLAYER_LOGIN and the seconds to the first list
	local login = { why = "boot", boot = { db = "table", wdb = "nil", wuber = "table", li = false }, events = {
		{ t = 0, e = "ADDON_LOADED", n = 1, a = { "Wuber" } }, { t = 0.2, e = "PLAYER_LOGIN", n = 0, a = {} },
		{ t = 0.2, e = "PLAYER_ENTERING_WORLD", n = 2, a = { true, false } }, { t = 3.2, e = "CHANNEL_UI_UPDATE", n = 0, a = {} } },
		snaps = { { t = 0.2, id = "channels", why = "PLAYER_LOGIN", d = { n = 0, list = {} } },
			{ t = 3.2, id = "channels", why = "CHANNEL_UI_UPDATE", d = { n = 5, list = {} } },
			{ t = 1, id = "screen", why = "PLAYER_ENTERING_WORLD", d = { sw = 1365, sh = 768, ui = { prot = true, shown = true } } } } }
	local lf = {}
	for _, f in ipairs(IMP.facts(login)) do lf[f.id] = f.v end
	ok(type(lf["channels:login"]) == "table", "channels:login")
	eq(lf["channels:login"].n, 0, "no channel at PLAYER_LOGIN")
	eq(lf["channels:login"].first, 3, "the first list 3 s after PLAYER_LOGIN")
	eq(lf["channels:reload"], nil, "not a reload")
	eq(lf["settings:known"], false, "no settings snapshot")
	eq(lf["boot:file"].wdb, "nil", "no saved data of Wuber's yet (a first login)")
	eq(lf["screen:ui"].from, "screen", "an older recording (UIParent read as protected): the screen's size")
	eq(lf["screen:ui"].w, 1365)
	-- one row adds a kind
	local n0 = #IMP.facts({ events = {}, snaps = {} })
	table.insert(IMP.FACTS, { "test", function(fx, add) add("test", "rows", #fx.events) end })
	local got = IMP.facts({ events = { {}, {} }, snaps = {} })
	table.remove(IMP.FACTS)
	eq(#got, n0 + 1, "a row adds a fact")
	local t
	for _, f in ipairs(got) do if f.id == "test:rows" then t = f end end
	ok(t and t.v == 2 and t.q == "test" and t.key == "rows", "the new fact")
end)
