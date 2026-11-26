-- Wuber tests. Run from the repo root:  lua5.1 tests/run.lua [filter] [flags]
--
-- Flags (REFACTOR-MAP 4.5, the behaviour transcript):
--   --compare-transcript  record tests/out/transcript.txt and FAIL on any difference from
--                         tests/transcripts/baseline.txt (filtered: only the tests run)
--   --record-transcript   record tests/out/transcript.txt only
--   --update-transcript   record it and make it the new baseline (a reviewed change)
--   (WUBER_TRANSCRIPT=<path> records to that path instead of tests/out/transcript.txt)
--
-- Several processes at once (tests/lib/shard.lua, tools/suite-par.sh):
--   --shard K/N  run only every N-th test, from the K-th; the transcript (any of the three
--                flags: recorded only) goes to tests/out/transcript.K-of-N.txt, the results
--                to tests/out/results.K-of-N.txt
--   --join N     run no test: join the N shards' files (the same filter and flags) into
--                tests/out/transcript.txt, then compare / update and report as a serial run
--
-- Every scenario plays in the small game of harness.lua: game windows (clients) for drivers
-- and riders, each with the addons loaded from their TOCs into an environment of its own,
-- one shared world (channels, whispers, groups, summons, trades) and a clock.

local dir = (arg and arg[0] or "tests/run.lua"):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
package.path = dir .. "/?.lua;" .. package.path
local H = require("harness")
local S = H.state

local filter, flags, split = nil, {}, {}
do
	local argv, ai = arg or {}, 1
	while argv[ai] do
		local a = argv[ai]
		local name, val = a:match("^%-%-(%a+)=(.*)$")
		if not name and (a == "--shard" or a == "--join") then name, val, ai = a:sub(3), argv[ai + 1], ai + 1 end
		if name == "files" then split.files = val -- --files=a,b: only these test parts (tools/tests-for.lua)
		elseif name == "names" then split.names = val -- --names=<file>: only the tests whose exact name is a line of that file (tools/quick-check.sh)
		elseif name == "shard" or name == "join" then split[name] = val
		elseif a:match("^%-%-") then flags[a:sub(3)] = true elseif not filter then filter = a end
		ai = ai + 1
	end
end
for f in pairs(flags) do
	if f ~= "compare-transcript" and f ~= "record-transcript" and f ~= "update-transcript" then error("unknown flag --" .. f) end
end

-- the behaviour transcript (tests/lib/transcript.lua): one record per test, written at its end
local TRANSCRIPT = os.getenv("WUBER_TRANSCRIPT")
if TRANSCRIPT == "" then TRANSCRIPT = nil end
if flags["compare-transcript"] or flags["record-transcript"] or flags["update-transcript"] then
	TRANSCRIPT = TRANSCRIPT or (dir .. "/out/transcript.txt")
end
-- (WUBER_BASELINE names another baseline file: the baseline itself is about 110 MB, so it is not stored in the repository)
local BASELINE = os.getenv("WUBER_BASELINE")
if BASELINE == "" then BASELINE = nil end
BASELINE = BASELINE or (dir .. "/transcripts/baseline.txt")
-- split runs (tests/lib/shard.lua): a shard records its own part and compares nothing; the join
-- records nothing and compares the joined file
local SH = dofile(dir .. "/lib/shard.lua").new(dir, H, split.shard, split.join, filter)
if SH and not SH.joining and TRANSCRIPT then TRANSCRIPT = SH.transcript end
local TR = TRANSCRIPT and dofile(dir .. "/lib/transcript.lua")
if TR and not (SH and SH.joining) then TR.start(H, TRANSCRIPT) end
local passed, failed, failures, skipped = 0, 0, {}, 0
-- --files=a,b (in-round runs, tools/tests-for.lua): only the test parts named (e.g. ui/fold_test, round2;
-- "run" = the tests written in this file); every other part loads as an empty chunk. Never for the final run.
local ONLY, inPart
if split.files then
	if flags["update-transcript"] then error("--files with --update-transcript would make a partial baseline: refused") end
	ONLY = {}
	for part in split.files:gmatch("[^,]+") do ONLY[part:gsub("\\", "/"):gsub("%.lua$", "")] = true end
	local realLoad = loadfile
	loadfile = function(path, ...)
		local part = tostring(path):gsub("\\", "/")
		local rel = part:sub(1, #dir + 1) == dir .. "/" and part:sub(#dir + 2):gsub("%.lua$", "")
		-- only the parts run.lua itself loads are stubbed; whatever a part, the harness or the old peer
		-- (tests/round1) loads through loadfile is real
		local from = debug.getinfo(2, "S")
		local byRun = from and tostring(from.source):gsub("\\", "/"):find("tests/run%.lua$")
		if byRun and rel and not ONLY[rel] and rel:find("^[%w_/]+$") and not rel:find("^lib/") then return function() end end
		local chunk, err = realLoad(path, ...)
		if not chunk or not rel or not ONLY[rel] then return chunk, err end
		return function(...) inPart = true local ok2, e = pcall(chunk, ...) inPart = false if not ok2 then error(e, 0) end end
	end
end
-- --names=<file> (in-round runs, tools/quick-check.sh): every part loads, only the tests named, one exact name a line, run
local NAMES
if split.names then
	if flags["update-transcript"] then error("--names with --update-transcript would make a partial baseline: refused") end
	NAMES = {}
	local nf = assert(io.open(split.names, "rb"))
	for line in nf:read("*a"):gmatch("[^\r\n]+") do NAMES[line] = true end
	nf:close()
end
local results = {}
local pendings = {}

-- A test whose behaviour SPEC3 (Wuber 2.0) dropped: listed, not run, with the round4 test
-- that replaces it. (fn is kept so the old scenario can still be read.)
local function pending(name, pointer, fn)
	if filter and not name:lower():find(filter:lower(), 1, true) then skipped = skipped + 1 return end
	pendings[#pendings + 1] = { name = name, pointer = pointer }
	print("PEND  " .. name .. "\n      -> " .. pointer)
end

-- One test's body as the suite judges it: ok, or false and why. Round 15: anything on
-- tools/forbidden.lua that addon code touched (and the test did not clear on purpose) fails the test,
-- even when the addon swallowed the error under pcall and the test never ran clean(w).
-- (Event 1 merge, from the other side's E1-17) The fake game's process-global text settings (preview mode, tools/preview): the flat
-- measure, whole-pixel glyphs and the alpha hold are at their load values at the start of EVERY test. A check that turns them on
-- (the layout checks, the bug hunt's worlds, a test of Inter's widths) must not leave them on for whatever test shares its process
-- next: which tests share one depends on --shard and the times file, and a late-font probe (FONT_READY) or a widget digest then
-- differs between two identical runs.
local BASE_TEXT = { metrics = H.textMetrics, pixels = H.TEXT_PIXELS, hold = H.ALPHA_HOLD }

local function runOne(fn)
	local ok, err = xpcall(fn, function(e) return debug.traceback(tostring(e), 2) end)
	local left = H.forbiddenLeft()
	if ok and #left > 0 then
		ok, err = false, "forbidden in this client (tools/forbidden.lua), raised during the test:\n" .. table.concat(left, "\n")
	end
	return ok, err
end

-- [test name] = true: the test runs and counts, but leaves no record in the behaviour transcript
local noTranscript = {}

local GC_EVERY = tonumber(os.getenv("WUBER_GC_EVERY") or "") or 4
local gcTick = 0

local function test(name, fn)
	if filter and not name:lower():find(filter:lower(), 1, true) then skipped = skipped + 1 return end
	if ONLY and not inPart and not ONLY.run then skipped = skipped + 1 return end
	if NAMES and not NAMES[name] then skipped = skipped + 1 return end
	if SH and SH.skip(name, TR) then return end -- another shard's test (the join runs none)
	H.textMetrics, H.TEXT_PIXELS, H.ALPHA_HOLD = BASE_TEXT.metrics, BASE_TEXT.pixels, BASE_TEXT.hold
	H.testName = name -- (the click audit names the test: tests/harness.lua Client:click)
	if H.onTestStart then H.onTestStart(name) end -- tools/coverage-map.lua: which test is running
	local ok, err = runOne(fn)
	H.textMetrics, H.TEXT_PIXELS, H.ALPHA_HOLD = BASE_TEXT.metrics, BASE_TEXT.pixels, BASE_TEXT.hold
	local okr = false
	if TR and noTranscript[name] then
		pcall(TR.skip, name) -- (run and counted, but not in the behaviour transcript: see testOutside)
	elseif TR then
		local rerr
		okr, rerr = pcall(TR.record, name, ok)
		if not okr and ok then ok, err = false, "transcript recorder: " .. tostring(rerr) end
	end
	H.release()
	-- each test's world goes (dozens of clients over the suite): a full collect every 4th test (tools/suite-par.sh
	-- shards spend about 11% of their time in it); WUBER_GC_EVERY=1 collects after every test as before
	gcTick = gcTick + 1
	if gcTick >= GC_EVERY then gcTick = 0 collectgarbage("collect") end
	if os.getenv("WUBER_MEM") then print(("      mem %.0f MB"):format(collectgarbage("count") / 1024)) end
	results[#results + 1] = { name = name, ok = ok }
	if ok then
		passed = passed + 1
		print("PASS  " .. name)
	else
		failed = failed + 1
		failures[#failures + 1] = name
		print("FAIL  " .. name .. "\n      " .. tostring(err):gsub("\n", "\n      "))
	end
	if SH then SH.done(name, ok, err, okr) end
end

-- A test of something that lives OUTSIDE this repo (the flight recorder addon, tests/lib/rec_addon.lua):
-- it runs and counts like any test, but is not written into the behaviour transcript, so the baseline
-- never depends on a folder another branch or PC may not have, or may have in another version.
local function testOutside(name, fn)
	noTranscript[name] = true
	return test(name, fn)
end

local function eq(got, want, what)
	if got ~= want then error((what or "value") .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end

local function ok(cond, what)
	if not cond then error(what or "condition is false", 2) end
end

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local function list(t, sep)
	local out = {}
	for _, v in ipairs(t) do out[#out + 1] = tostring(v) end
	return table.concat(out, sep or "; ")
end

---------------------------------------------------------------------------
-- The cast
---------------------------------------------------------------------------

local ANITA, TESTCHAR, BOB = "Anita Lift", "Wuber TestCharacter", "Bob Stone"
local ANA, BEA, CAL = "Ana Smith", "Bea Jones", "Cal Brown"

-- The rider UI (old UI.lua; UI/*.lua after the restructure): its files are in Wuber's TOC
-- and exist (tests/lib/files.lua). Wuber always ships it, so the test "HAVE_UI is true"
-- below FAILS the suite when it is missing or does not load: the tests that check
-- `if HAVE_UI` must never skip silently (REFACTOR-MAP fact 3).
local F = H.F
local HAVE_UI = F.has("UI")
local HAVE_RR = H.exists(H.ADDONS.RitualRides .. "/RitualRides.toc") -- the stand-in in tests/fixtures/addons/OldDriver

local function newWorld(opts) return H.NewWorld(opts) end

local netOnly -- (below)

-- A Warlock driving with Wuber's own driver mode (Driver.lua), at Ratchet.
local function driver(w, name, opts)
	opts = opts or {}
	local c = w:addClient(name or ANITA, { spot = opts.spot or "Ratchet", class = "WARLOCK", channels = opts.channels,
		secrets = opts.secrets, openMap = opts.openMap, allowMissing = not HAVE_UI or opts.addonDirs ~= nil, addonDirs = opts.addonDirs,
		roundOne = opts.roundOne, mooLoaded = opts.mooLoaded, saved = opts.saved, faction = opts.faction, prepare = opts.prepare,
		lockEngine = opts.netOnly or opts.lockEngine, loadRR = opts.loadRR, shards = opts.shards, simple = opts.simple })
	if opts.netOnly then netOnly(c) end
	return c
end

local function rider(w, name, opts)
	opts = opts or {}
	return w:addClient(name or TESTCHAR, { spot = opts.spot or "Orgrimmar", class = opts.class or "MAGE", channels = opts.channels,
		money = opts.money or 100000, secrets = opts.secrets, openMap = opts.openMap, screenW = opts.screenW, screenH = opts.screenH,
		physH = opts.physH, allowMissing = not HAVE_UI or opts.addonDirs ~= nil, addonDirs = opts.addonDirs, roundOne = opts.roundOne,
		mooLoaded = opts.mooLoaded, saved = opts.saved, faction = opts.faction, prepare = opts.prepare, version = opts.version, simple = opts.simple })
end

-- the network comes up (channel joins wait for the game's own channels)
local function settle(w, s) w:advance(s or 15) end

-- A driver run by Net alone (Wuber 1.x's driver mode): requests wait in W.incoming for
-- W.AcceptRequest. Wuber 2.0's engine takes riders by itself (SPEC3 decision 2), so the tests
-- of Net's own request / accept / whisper protocol lock the engine off (client option
-- lockEngine) and give Net a plain beacon, as Driver.lua 1.x did.
netOnly = function(c)
	c.netOnly = true
	local W, env = c.W, c.env
	ok(c.lockEngine, "netOnly needs the client made with lockEngine = true")
	W.SetLocalDriver(function()
		if W.Char().drive ~= true then return nil end
		local m = env.C_Map.GetBestMapForUnit("player")
		local pos = m and env.C_Map.GetPlayerMapPosition(m, "player")
		local sub = env.GetSubZoneText()
		return { dest = (sub ~= "" and sub) or env.GetZoneText(), mapID = m, x = pos and pos.x, y = pos and pos.y,
			price = W.Char().price or W.MIN_PRICE, service = W.Char().service or W.Me(), state = "open", team = 1, seats = 4 }
	end)
	return c
end

local function goOffline(c)
	if c.netOnly then c.W.SetDriving(false) else c.W.Driver.SetOnline(false) end
end

local function goOnline(c, opts)
	opts = opts or {}
	local W = c.W
	if opts.price then W.Char().price = opts.price end
	if opts.service then W.Char().service = opts.service end
	if c.netOnly then
		ok(W.SetDriving(true) ~= false, "the Net-only driver could not go online")
		c.world:advance(opts.wait or 3)
		return
	end
	local okc = W.Driver.SetOnline(true)
	ok(okc ~= false, "the driver could not go online")
	c.world:advance(opts.wait or 3)
end

-- Nothing the game forbids happened, no Lua error was raised or swallowed.
local SAVED = { WuberDB = true, RitualRidesDB = true, GigaLocksTeam = true }
local function clean(w, opts)
	opts = opts or {}
	if H.taint then for _, c in ipairs(w.clients) do H.taint.scan(c) end end -- the taint guard (tests/fakegame/taint-allow.lua)
	-- (decisions K) a blocked action handed to the game's error handler (at most once in 30 s) is not a Lua error
	local errs = {}
	for _, e in ipairs(w.errors) do
		if not tostring(e):find("errorhandler: Wuber: the game blocked ", 1, true) then errs[#errs + 1] = e end
	end
	eq(#errs, 0, "Lua errors (" .. list(errs, "\n") .. ")")
	if not opts.violations then eq(#w.violations, 0, "violations (" .. list(w.violations, "\n") .. ")") end
	for path, kind in pairs(w.missingFiles) do error("a " .. kind .. " file that doesn't exist: " .. path) end
	for _, c in ipairs(w.clients) do
		if c.W then
			eq(c.W.lastError, nil, c.player.name .. " W.lastError")
		end
		if c.RR then eq(c.RR.lastError, nil, c.player.name .. " RR.lastError") end
		if not opts.throttled then eq(c.throttled or 0, 0, c.player.name .. " addon messages throttled by the game") end
	end
	for _, e in ipairs(w.addonLog) do
		ok(#e.text <= 255, "addon message over 255 bytes")
	end
end

-- every message of a kind (Wuber's) from a player
local function msgs(w, kind, from, chat) return w:messages(kind, from, chat) end

local function fields(e)
	local out = {}
	for f in (e.text .. "~"):gmatch("(.-)~") do out[#out + 1] = f end
	return out
end

---------------------------------------------------------------------------
-- UI helpers (agent UI's window; tests that need it fail with a clear message without it)
---------------------------------------------------------------------------

local function needUI(c)
	ok(HAVE_UI, "Wuber's UI files (UI.lua or UI/*.lua) are not in the TOC")
	ok(c.W.UI and type(c.W.UI.Show) == "function", "W.UI.Show is missing")
end

-- the visible secure buttons of a client and their macro texts
local function secureShown(c)
	local out = {}
	for _, f in ipairs(c:secureButtons()) do
		if H.visible(f) then out[#out + 1] = f end
	end
	return out
end

-- Rider: open Confirm for the driver and click Request where it is drawn.
local function openConfirm(r, key)
	needUI(r)
	r.W.UI.Show("confirm", key)
	r.world:advance(2.5) -- the first open plays a splash (about 1.8 s) over the window
end

-- Clicks the Request pill where it is drawn. If its label is wrong (see the label test),
-- clicks where the pill is anyway, so the rest of the flow is still tested.
local function clickRequest(r)
	if #r:findText("^Request") > 0 then return r:clickText("^Request", { pattern = true }) end
	r.requestLabelWrong = true
	local b = r.env.WuberRequestButton
	ok(b and H.visible(b), "no Request pill and no WuberRequestButton (" .. list(r:visibleTexts()) .. ")")
	return r:clickOn(b)
end

local function requestVia(r, key)
	openConfirm(r, key)
	return clickRequest(r)
end

-- Driver (Driver.lua): the request card's Accept, clicked; falls back to nothing.
-- (SPEC3 2.1: a Warlock who never set up driving sees a welcome; the 1.x tests want the
-- console, so the wizard counts as done)
local function openDrive(d)
	local D = d.W.Driver
	if d.W.Char and d.W.Drive then d.W.Char().wizard = true end
	if d.W.UI and type(d.W.UI.Toggle) == "function" and HAVE_UI then
		d.W.UI.Toggle(true)
		d.world:advance(2.5)
		d:clickText("Drive")
	else
		if not (D.window and D.window:IsShown()) then D.Toggle() end
	end
	d.world:advance(1)
end

-- GO ONLINE is the console's Open / Close pill; a click where it is drawn (the
-- secure WuberGoButton lies over it while going online also posts the advert)
local function clickGo(d)
	local ui = d.W.Driver and d.W.Driver.ui
	local pill = ui and ui.console and ui.console.open
	ok(pill and H.visible(pill), "the console's Open pill (" .. list(d:visibleTexts()) .. ")")
	return d:clickOn(pill)
end

local function driverAccept(d)
	openDrive(d)
	d:clickText("Accept")
	d.world:advance(1)
end

-- The driver takes the first (or i-th) request. Wuber 2.0's engine takes riders by itself
-- (SPEC3 decision 2: no Accept card); before it is active, Driver.Accept (1.x) or Net's own
-- W.AcceptRequest plus an invite do it.
local function take(d, i)
	local W = d.W
	local inc = W.incoming and W.incoming[i or 1]
	if type(i) == "string" then
		inc = nil
		for _, x in ipairs(W.incoming or {}) do if x.buyerKey == i then inc = x end end
	end
	if W.engine then d.world:advance(2) return inc end
	if not inc then return nil end
	if W.Driver and type(W.Driver.Accept) == "function" then
		W.Driver.Accept(inc.id)
	else
		W.AcceptRequest(inc.id, 5, W.Str(inc.buyer))
		d.world:invite(d, W.Str(inc.buyer))
	end
	return inc
end

local function rideState(r) return r.W.ride and r.W.ride.state end

local function whispersTo(w, name, how)
	return w:whispersTo(name, how)
end

---------------------------------------------------------------------------
-- 1. Files
---------------------------------------------------------------------------

local function readFile(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local t = f:read("*a")
	f:close()
	return t
end

-- (REFACTOR-MAP fact 3) the UI is expected: a missing or unloadable UI fails here instead of
-- quietly skipping every `if HAVE_UI` check and letting clients load with files missing
test("HAVE_UI is true: the UI's files are in the TOC, exist, and the UI loads (W.UI)", function()
	ok(F.expected("UI"), "Wuber's TOC lists no UI file (UI.lua or UI/*.lua)")
	ok(HAVE_UI, "a UI file the TOC lists does not exist: " .. list(F.sources("UI")))
	local w = newWorld()
	local r = rider(w)
	ok(not r.skipped, "files skipped while loading: " .. list(r.skipped or {}))
	ok(r.W.UI and type(r.W.UI.Show) == "function" and type(r.W.UI.Toggle) == "function", "W.UI (Show, Toggle) did not load")
	if r.W.modules then
		for name in pairs(r.W.modules) do
			if name:match("^UI%.") and not name:match("^UI%.Driver%.") then ok(r.W.modules["UI.Window"], "UI modules loaded but not UI.Window") break end
		end
	end
	clean(w)
end)

-- every file in the TOC holds the code of exactly one old file (or is one the restructure
-- added), so F.sources / F.read / F.has see all of it: a module file missing from
-- tests/lib/files.lua would make the structural tests read less than they should
test("tests/lib/files.lua accounts for every Wuber TOC file", function()
	local owner, added = {}, {}
	for _, f in ipairs(F.ADDED) do added[f] = true end
	local olds = {}
	for old in pairs(F.NEW) do olds[#olds + 1] = old end
	table.sort(olds)
	eq(#olds, 25, "old files in F.NEW")
	for _, old in ipairs(olds) do
		ok(F.expected(old), "no TOC file holds " .. old .. "'s code")
		for _, f in ipairs(F.sources(old)) do
			ok(not owner[f], f .. " is a source of both " .. tostring(owner[f]) .. " and " .. old)
			owner[f] = old
		end
	end
	local stray = {}
	for _, f in ipairs(H.tocFiles("Wuber")) do
		if not owner[f] and not added[f] then stray[#stray + 1] = f end
	end
	eq(#stray, 0, "TOC files tests/lib/files.lua does not know: " .. list(stray))
	ok(F.has("Net") and F.has("UI") and F.has("Drive_Log"), "F.has")
	ok(F.read("Drive_Log") and F.read("Drive_Log"):find("DR", 1, true), "F.read")
end)

test("every TOC file exists and parses (Lua 5.1)", function()
	for _, addon in ipairs({ "Wuber", "RitualRides" }) do
		local files, d = H.tocFiles(addon)
		ok(files, "no TOC for " .. addon)
		for _, file in ipairs(files) do
			local path = d .. "/" .. file
			ok(H.exists(path), "missing: " .. path)
			local chunk, err = loadfile(path)
			ok(chunk, "parse error: " .. tostring(err))
		end
	end
end)

-- SPEC5 rrmentions (the author: "no mentions of it anywhere"): no string a player can see names the
-- old summoning addon, in any of Wuber's files, nor the TOC. Code identifiers and saved-variable
-- names ("RitualRides", "RitualRidesDB") may stay, and comments are not shown to anyone.
-- (Files are listed from the TOC in pure Lua: review #30 - the old check scanned
-- nothing when the path was relative.)
local function luaStrings(src)
	local out, i, n = {}, 1, #src
	while i <= n do
		local ch = src:sub(i, i)
		if ch == "-" and src:sub(i, i + 1) == "--" then
			local long = src:match("^%-%-%[(=*)%[", i)
			if long then
				local _, e = src:find("%]" .. long .. "%]", i + 4 + #long)
				i = (e or n) + 1
			else
				local e = src:find("\n", i, true)
				i = (e or n) + 1
			end
		elseif ch == '"' or ch == "'" then
			local j, buf = i + 1, {}
			while j <= n do
				local c2 = src:sub(j, j)
				if c2 == "\\" then
					buf[#buf + 1] = src:sub(j, j + 1)
					j = j + 2
				elseif c2 == ch then
					break
				else
					buf[#buf + 1] = c2
					j = j + 1
				end
			end
			out[#out + 1] = table.concat(buf)
			i = j + 1
		elseif ch == "[" and src:match("^%[=*%[", i) then
			local eq = src:match("^%[(=*)%[", i)
			local s0 = i + 2 + #eq
			local _, e = src:find("%]" .. eq .. "%]", s0)
			out[#out + 1] = src:sub(s0, (e or n + 1) - 2 - #eq)
			i = (e or n) + 1
		else
			i = i + 1
		end
	end
	return out
end

-- tools/check.lua (REFACTOR-MAP 6.2): the static checks every restructure step must pass
local CHECK = assert(loadfile(dir .. "/../tools/check.lua"))("--lib")

test("tools/check.lua passes: parse, locals, globals, load-time calls, module sizes and deps", function()
	local res = CHECK.run(dir .. "/..")
	eq(#res.fails, 0, "tools/check.lua:\n" .. table.concat(res.fails, "\n"))
	ok(res.info.files >= 25, "files checked: " .. tostring(res.info.files))
end)

-- tools/map.lua (REFACTOR-MAP 6.3): generates ARCHITECTURE.md from the TOC and the module headers
local MAP = assert(loadfile(dir .. "/../tools/map.lua"))("--lib")

test("tools/map.lua lists every TOC module in TOC order, each with its name, size and purpose", function()
	local root = dir .. "/.."
	local mods = MAP.modules(root)
	-- the expected modules are the Lua files of Wuber/Wuber.toc (every one is a module); no count is typed in
	local tocFiles = H.tocFiles("Wuber")
	local want = {}
	for i, f in ipairs(tocFiles) do want[i] = (f:gsub("/", "."):gsub("%.lua$", "")) end
	ok(#want > 0, "the TOC lists files")
	eq(#mods, #want, "modules found")
	for i, m in ipairs(mods) do eq(m.name, want[i], "module " .. i .. " in TOC order") end
	for i, m in ipairs(mods) do
		ok(m.name ~= "?", m.file .. ": no W.Module line")
		eq(m.file:gsub("/", "."):gsub("%.lua$", ""), m.name, "module name of " .. m.file)
		ok(m.lines > 0 and m.h.Purpose and m.h.API, m.file .. ": header or size missing")
	end
	local text = MAP.build(root)
	local n = 0
	for _ in text:gmatch("\n#### %d+%. ") do n = n + 1 end
	eq(n, #want, "module sections in the generated text")
	ok(text:find("#### 1. " .. want[1], 1, true) and text:find("#### " .. #want .. ". " .. want[#want], 1, true), "first and last module")
	eq(MAP.build(root), text, "deterministic output")
end)

test("tools/check.lua catches each kind of problem (synthetic files)", function()
	local HEAD = "local _, W = ...\n"
	local function many(n, prefix)
		local t = {}
		for i = 1, n do t[i] = "local " .. prefix .. i .. " = " .. i end
		return table.concat(t, "\n") .. "\n"
	end
	local src = {
		["Old.lua"] = HEAD .. "local helper = 1\nfunction W.Thing() return helper end\nW.On('X', function() W.Thing() end)\n",
		["Big.lua"] = HEAD .. many(170, "v"), -- 172 declared: the last is never live at an instruction
		["Warm.lua"] = HEAD .. "local function f()\n" .. many(152, "u") .. "end\nreturn f\n",
		["Glob.lua"] = HEAD .. "local x = NewThing\nlocal y = helper\nOtherGlobal = 1\nprint(x, y)\n",
		["Load.lua"] = HEAD .. "W.Thing()\nlocal function boot() return W.Thing() end\nboot()\nlocal function later() W.Thing() end\n",
		["Broken.lua"] = HEAD .. "local = 1\n",
		["Net/Base.lua"] = HEAD .. "local Mod = W.Module(\"Net.Base\")\nlocal L = W.Mod(\"Net.Later\")\n",
		["Net/Wrong.lua"] = HEAD .. "local Mod = W.Module(\"Net.Right\", { \"Net.Base\", \"Net.After\", \"Net.None\" })\n",
		["Net/After.lua"] = HEAD .. "local Mod = W.Module(\"Net.After\")\n",
		["Net/Bare.lua"] = HEAD .. "-- local Mod = W.Module(\"Net.Bare\") (a comment is not a declaration)\n",
		["Net/Huge.lua"] = HEAD .. "local Mod = W.Module(\"Net.Huge\")\n" .. string.rep("\n", 2010),
		["Legacy.lua"] = HEAD .. string.rep("\n", 1300),
		["Ghost.lua"] = nil,
	}
	local files = { "Old.lua", "Big.lua", "Warm.lua", "Glob.lua", "Load.lua", "Broken.lua", "Net/Base.lua", "Net/Wrong.lua",
		"Net/After.lua", "Net/Bare.lua", "Net/Huge.lua", "Legacy.lua", "Ghost.lua" }
	local globals = { read = { print = true }, write = {} }
	local function run(allow)
		return CHECK.check({ files = files, read = function(p) return src[p] end, globals = globals, owner = { ["Load.lua"] = "Load" },
			legacy = { ["Old.lua"] = true, ["Big.lua"] = true, ["Warm.lua"] = true, ["Glob.lua"] = true, ["Load.lua"] = true,
				["Broken.lua"] = true, ["Legacy.lua"] = true, ["Ghost.lua"] = true }, allow = allow or {} })
	end
	local res = run()
	local all = table.concat(res.fails, "\n") .. "\n" .. table.concat(res.warns, "\n")
	local function has(pattern, what) ok(all:find(pattern, 1, true), what .. " (" .. pattern .. ") in:\n" .. all) end
	local function hasNot(pattern, what) ok(not all:find(pattern, 1, true), what .. " (" .. pattern .. ") in:\n" .. all) end
	has("FAIL Ghost.lua:0 the TOC lists it but it does not exist", "a missing file")
	has("FAIL Broken.lua:2 does not compile", "a parse error")
	has("FAIL Big.lua:0 the top level holds 171 locals at once", "171 top-level locals")
	has("WARN Warm.lua:2 a function holds 151 locals at once", "151 locals in a function: a warning")
	hasNot("FAIL Warm.lua", "151 locals is not a failure")
	has("FAIL Glob.lua:2 reads a new global `NewThing`", "a new global read")
	has("FAIL Glob.lua:3 reads global `helper`: a lost local (a top-level local of Old.lua)", "a lost local")
	has("FAIL Glob.lua:4 writes a new global `OtherGlobal`", "a new global write")
	has("FAIL Load.lua:2 load-time call of W.Thing (defined in Old.lua)", "a direct load-time call into another file")
	has("FAIL Load.lua:4 load-time call of boot(), which reaches W.Thing (Old.lua)", "one through a local function")
	hasNot("Load.lua:5", "a call inside a function body is not at load time")
	hasNot("FAIL Old.lua", "W.On at load and a file's own functions are fine")
	has("FAIL Net/Wrong.lua:0 W.Module(\"Net.Right\") should be named \"Net.Wrong\"", "the module name is its path")
	has("FAIL Net/Wrong.lua:0 Net.Right loads before its dependency Net.After (TOC order)", "a dependency later in the TOC")
	has("FAIL Net/Wrong.lua:0 Net.Right depends on Net.None, which no TOC file defines", "a missing dependency")
	has("FAIL Net/Base.lua:3 W.Mod(\"Net.Later\"): no module of that name in the TOC", "W.Mod of an unknown module")
	has("FAIL Net/Bare.lua:0 a module file needs exactly one W.Module(\"Net.Bare\"", "a module file without W.Module")
	has("FAIL Net/Huge.lua:0 2013 lines (a module's cap is 2000)", "a module over 2,000 lines")
	hasNot("Legacy.lua", "an old (legacy) file has no size cap")
	-- the allow-list: an existing load-time call stays allowed for the old file's code
	local allowed = run({ { old = "Load", call = "W.Thing" }, { old = "Load", call = "boot" } })
	local fails = table.concat(allowed.fails, "\n")
	ok(not fails:find("Load.lua", 1, true), "allow-listed load-time calls: " .. fails)
end)

test("tools/check.lua fails on what this client forbids (tools/forbidden.lua) in Wuber and the lab addon; comments are fine", function()
	local list = CHECK.readForbidden(dir .. "/..")
	ok(type(list) == "table" and #list >= 3, "tools/forbidden.lua lists them")
	local names = {}
	for _, f in ipairs(list) do names[f.name] = true end
	for _, n in ipairs({ "COMBAT_LOG_EVENT_UNFILTERED", "CombatLogGetCurrentEventInfo", "SendCharacterInvitation", "RegisterAllEvents" }) do
		ok(names[n], n .. " is on the list")
	end
	local HEAD = "local _, W = ...\n"
	local src = {
		["Reg.lua"] = HEAD .. "local f = CreateFrame('Frame')\nf:RegisterEvent(\"COMBAT_LOG_EVENT_UNFILTERED\")\n",
		["Info.lua"] = HEAD .. "local function g() return CombatLogGetCurrentEventInfo() end\nreturn g\n",
		["Club.lua"] = HEAD .. "local function g(id, n) return C_Club.SendCharacterInvitation(id, n) end\nreturn g\n",
		["Fine.lua"] = HEAD .. "-- no COMBAT_LOG_EVENT_UNFILTERED here, nor CombatLogGetCurrentEventInfo\n--[[ SendCharacterInvitation ]]\n"
			.. "local SendCharacterInvitationX = 1\nlocal s = \"x\" -- RegisterAllEvents\nreturn SendCharacterInvitationX, s\n",
		["All.lua"] = HEAD .. "local f = CreateFrame('Frame')\nf:RegisterAllEvents()\n",
		-- "--" inside a string is no comment: what follows it on the line is still code
		["Str.lua"] = HEAD .. "local f = CreateFrame('Frame')\nlocal s = \"--\" f:RegisterEvent(\"COMBAT_LOG_EVENT_UNFILTERED\")\n"
			.. "local u = 'a\\'--' .. CombatLogGetCurrentEventInfo()\nlocal v = [[--]] .. C_Club.SendCharacterInvitation(1, 'x')\n",
	}
	local files = { "Reg.lua", "Info.lua", "Club.lua", "Fine.lua", "All.lua", "Str.lua" }
	local res = CHECK.check({ files = files, read = function(p) return src[p] end, globals = nil, owner = {},
		legacy = { ["Reg.lua"] = true, ["Info.lua"] = true, ["Club.lua"] = true, ["Fine.lua"] = true, ["All.lua"] = true,
			["Str.lua"] = true }, allow = {}, forbidden = list })
	local all = table.concat(res.fails, "\n")
	ok(all:find("FAIL Reg.lua:3 names COMBAT_LOG_EVENT_UNFILTERED", 1, true), "a registration: " .. all)
	ok(all:find("FAIL Info.lua:2 names CombatLogGetCurrentEventInfo", 1, true), "a call: " .. all)
	ok(all:find("FAIL Club.lua:2 names SendCharacterInvitation", 1, true), "a C_Club call: " .. all)
	ok(not all:find("Fine.lua", 1, true), "comments and longer names are fine: " .. all)
	ok(all:find("FAIL All.lua:3 names RegisterAllEvents", 1, true), "RegisterAllEvents (it pulls in the combat log): " .. all)
	ok(all:find("FAIL Str.lua:3 names COMBAT_LOG_EVENT_UNFILTERED", 1, true), "after a string holding --: " .. all)
	ok(all:find("FAIL Str.lua:4 names CombatLogGetCurrentEventInfo", 1, true), "after an escaped quote and --: " .. all)
	ok(all:find("FAIL Str.lua:5 names SendCharacterInvitation", 1, true), "after a long string holding --: " .. all)
	-- the lab addon: its TOC's Lua files; a missing folder is skipped quietly
	local lab = { ["L/WuberLab.toc"] = "## Title: x\nProbes.lua\nClean.lua\n",
		["L/Probes.lua"] = "local x = 1\nL.On(\"COMBAT_LOG_EVENT_UNFILTERED\", f)\n", ["L/Clean.lua"] = "-- CombatLogGetCurrentEventInfo\n" }
	local fails, n = CHECK.checkLab("L", list, function(p) return lab[p] end)
	eq(n, 2, "lab files scanned")
	eq(#fails, 1, "one lab failure: " .. table.concat(fails, "\n"))
	ok(fails[1] and fails[1]:find("Probes.lua:2 names COMBAT_LOG_EVENT_UNFILTERED", 1, true), tostring(fails[1]))
	local none, n0 = CHECK.checkLab("Nowhere", list, function() return nil end)
	eq(#none, 0, "no lab here: nothing")
	eq(n0, 0)
	ok(type(CHECK.labDir()) == "string", "the lab folder: WUBER_LAB_DIR or the default")
	-- WUBER_LAB_DIR set but missing fails; unset with no default folder is skipped quietly
	local function env(v) return function(k) if k == "WUBER_LAB_DIR" then return v end end end
	local lf, ln = CHECK.scanLab(list, env("Missing"), function() return nil end)
	eq(ln, 0)
	ok(lf[1] and lf[1]:find("^FAIL lab ") and lf[1]:find("WUBER_LAB_DIR", 1, true), "an explicit folder that is missing: " .. tostring(lf[1]))
	local qf, qn = CHECK.scanLab(list, env(nil), function() return nil end)
	eq(#qf, 0, "unset and no default folder: quiet")
	eq(qn, 0)
	local sf, sn = CHECK.scanLab(list, env("L"), function(p) return lab[p] end)
	eq(sn, 2, "WUBER_LAB_DIR read")
	eq(#sf, 1, "its failure")
	-- the summary says how many lab files were scanned
	local report = table.concat(CHECK.report({ fails = {}, warns = {}, info = { files = 1, modules = {}, labFiles = 3 } }, {}), "\n")
	ok(report:find("lab: 3 files scanned", 1, true), report)
end)

test("Wuber never names the old summoning addon where a player could see it (SPEC5 rrmentions)", function()
	local files = H.tocFiles("Wuber")
	ok(files and #files > 20, "the TOC's files")
	local hits, scanned = {}, 0
	for _, file in ipairs(files) do
		local t = readFile(H.ADDONS.Wuber .. "/" .. file)
		ok(t, "read " .. file)
		scanned = scanned + 1
		for _, s in ipairs(luaStrings(t)) do
			if s:lower():find("ritual%s*rides") and not s:match("^RitualRides[%w_]*$") then
				hits[#hits + 1] = file .. ': "' .. s:sub(1, 60) .. '"'
			end
		end
	end
	ok(scanned == #files, "every file scanned")
	local toc = readFile(H.ADDONS.Wuber .. "/Wuber.toc") or ""
	if toc:lower():find("ritual") then hits[#hits + 1] = "Wuber.toc" end
	-- the scanner works (a check that can't scan proves nothing)
	local probe = luaStrings('local a = "Ritual Rides" -- "not this"\nlocal b = [[x]]')
	ok(probe[1] == "Ritual Rides" and probe[2] == "x" and #probe == 2, "the string scanner")
	eq(#hits, 0, "strings naming the old addon: " .. list(hits))
end)

-- review of round 12: a header's hook slot must still be set by the module it names
test("module headers: every hook slot a header says another module sets is set there", function()
	local files = H.tocFiles("Wuber")
	ok(files and #files > 20, "the TOC's files")
	local bad, seen = {}, 0
	for _, file in ipairs(files) do
		local t = readFile(H.ADDONS.Wuber .. "/" .. file) or ""
		local head = {}
		for line in (t .. "\n"):gmatch("([^\n]*)\n") do
			if not line:match("^%-%-") then break end
			head[#head + 1] = (line:gsub("^%-%-%s*", ""))
		end
		local internals = table.concat(head, " "):match("Internals:(.-)Uses:") or ""
		for name, setter in internals:gmatch("([%w_]+)%s*%(%s*s?e?t?%s*b?y?%s*([A-Z]%a+%.[A-Z][%w]+)%)") do
			seen = seen + 1
			local src = readFile(H.ADDONS.Wuber .. "/" .. setter:gsub("%.", "/") .. ".lua") or ""
			if not src:find("%." .. name .. "%s*=") then bad[#bad + 1] = file .. ": " .. name .. " (" .. setter .. ")" end
		end
	end
	ok(seen >= 3, "hook slots found in headers: " .. seen)
	eq(#bad, 0, "hook slots nothing sets: " .. list(bad))
end)

-- Wuber never mentions the separate network test addon, not even in a comment
test("Wuber never mentions the lab, not even in comments", function()
	local hits = {}
	for _, file in ipairs((H.tocFiles("Wuber"))) do
		local n = 0
		for line in ((readFile(H.ADDONS.Wuber .. "/" .. file) or "") .. "\n"):gmatch("([^\n]*)\n") do
			n = n + 1
			local l = line:lower()
			if l:find("%f[%a]lab%f[%A]") or l:find("%f[%a]wuberlab%f[%A]") then hits[#hits + 1] = file .. ":" .. n end
		end
	end
	eq(#hits, 0, "lines naming the lab: " .. list(hits))
end)

test("every Media texture the Lua names exists as Media/<name>.tga, and the TOC icon", function()
	ok(H.exists(H.ADDONS.Wuber .. "/Media/icon.tga"), "Media/icon.tga (the TOC's IconTexture)")
	local missing = {}
	for _, file in ipairs((H.tocFiles("Wuber"))) do
		local t = readFile(H.ADDONS.Wuber .. "/" .. file) or ""
		for name in t:gmatch("Media\\\\([%w_]+)\"") do
			if not H.exists(H.ADDONS.Wuber .. "/Media/" .. name .. ".tga") then missing[#missing + 1] = file .. ": " .. name end
		end
		for name in t:gmatch("MEDIA%s*%.%.%s*\"([%w_]+)\"") do
			if not H.exists(H.ADDONS.Wuber .. "/Media/" .. name .. ".tga") then missing[#missing + 1] = file .. ": " .. name end
		end
	end
	eq(#missing, 0, "missing media: " .. list(missing))
end)

test("TGA files are uncompressed 32-bit with power-of-two sizes", function()
	local bad, n = {}, 0
	for _, path in ipairs(H.listFiles(H.ADDONS.Wuber .. "/Media", "tga")) do -- (no ls)
		n = n + 1
		local t = readFile(path)
		local imgType, w, h, bpp = t:byte(3), t:byte(13) + t:byte(14) * 256, t:byte(15) + t:byte(16) * 256, t:byte(17)
		local function pow2(x) return x > 0 and x <= 4096 and (x - math.floor(x / 2) * 2 == 0 or x == 1) and math.log(x) / math.log(2) % 1 == 0 end
		if imgType ~= 2 or bpp ~= 32 or not pow2(w) or not pow2(h) then
			bad[#bad + 1] = path:match("[^/]+$") .. " type " .. imgType .. " " .. w .. "x" .. h .. " " .. bpp .. "bit"
		end
	end
	ok(n > 0, "no TGA files")
	eq(#bad, 0, "bad TGA: " .. list(bad))
end)

test("no stray globals: only Wuber, WuberDB, WuberAPI, SLASH_WUBER*, frames named Wuber*", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	if HAVE_UI then r.W.UI.Toggle() w:advance(2) r.W.UI.Toggle() end
	r:slash("/wuber")
	w:advance(2)
	for _, c in ipairs({ d, r }) do
		for k in pairs(c.env) do
			local allowed = k == "_G" or k == "Wuber" or k == "WuberDB" or k == "WuberAPI"
				or k == "BINDING_HEADER_WUBER" or k == "BINDING_NAME_WUBER_TOGGLE" or k == "BINDING_NAME_CLICK WuberDriveButton:LeftButton" -- (2.4) the game's Key Bindings names: Wuber/Bindings.xml
				or (type(k) == "string" and (k:match("^SLASH_WUBER%d+$") or (k:match("^Wuber") and (H.state[c.env[k]] ~= nil or H.fonts[c.env[k]]))))
			ok(allowed, c.player.name .. ": a stray global: " .. tostring(k) .. " (written at " .. tostring(c.globalWrites[k]) .. ")")
		end
		for k, at in pairs(c.globalWrites) do
			ok(k == "Wuber" or k == "WuberDB" or k == "WuberAPI" or k == "_G" or tostring(k):match("^SLASH_WUBER%d+$") or k == "BINDING_HEADER_WUBER" or k == "BINDING_NAME_WUBER_TOGGLE" or k == "BINDING_NAME_CLICK WuberDriveButton:LeftButton" or at == "harness",
				"global write " .. tostring(k) .. " at " .. tostring(at))
		end
		-- slash commands: /wuber and /ride only (never /w)
		local i = 1
		while rawget(c.env, "SLASH_WUBER" .. i) do
			local cmd = rawget(c.env, "SLASH_WUBER" .. i):lower()
			ok(cmd == "/wuber" or cmd == "/ride", "slash command " .. cmd)
			i = i + 1
		end
	end
	clean(w)
end)

---------------------------------------------------------------------------
-- 2. Drivers online, riders see them
---------------------------------------------------------------------------

test("a driver goes online (Driver.lua) and a rider sees the driver", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	ok(d.W.OnNetwork() and r.W.OnNetwork(), "both on the network")
	-- the channel was hidden from the chat windows
	ok(d.removedChannels and #d.removedChannels > 0, "WuberNet hidden from chat windows")
	eq(count(r.W.drivers), 0, "no drivers before going online")
	goOnline(d)
	local x = r.W.drivers["anita lift"]
	ok(x, "the rider knows Anita")
	eq(x.dest, "Ratchet", "dest")
	eq(x.price, 5000, "price")
	eq(x.state, "open", "state")
	eq(x.mapID, 1413, "mapID")
	ok(math.abs(x.x - 0.627) < 0.002 and math.abs(x.y - 0.370) < 0.002, "position")
	eq(x.team, 1, "team")
	local D = msgs(w, "D", ANITA, "CHANNEL")
	ok(#D >= 1, "a D beacon on the channel")
	local f = fields(D[#D])
	eq(f[1], "D") eq(f[2], "1")
	eq(f[12], "H", "faction field") eq(f[13], r.W.VERSION, "version field (this build's W.VERSION)")
	ok(f[13]:match("^%d+%.%d+%.%d+$") or f[13]:match("^%d+%.%d+%.%d+%-dev$"), "a.b.c or, for an internal build, a.b.c-dev")
	-- the list API
	local list_ = r.env.WuberAPI.Drivers()
	eq(#list_, 1, "WuberAPI.Drivers")
	eq(r.env.WuberAPI.IsOnNetwork(), true)
	clean(w)
end)

test("rider's window shows the driver card (name, Ratchet, 50s)", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	needUI(r)
	r.W.UI.Show("home")
	w:advance(2)
	ok(#r:findText("Anita") > 0, "Anita on a card (" .. list(r:visibleTexts()) .. ")")
	ok(#r:findText("Ratchet") > 0, "Ratchet on a card")
	ok(#r:findText("50s", false, true) > 0, "50s on a card")
	clean(w)
end)

test("a driver of the other faction is not shown", function()
	local w = newWorld()
	local d = driver(w)
	w:player(ANITA).faction = "Alliance"
	local r = rider(w)
	settle(w)
	goOnline(d)
	eq(r.W.drivers["anita lift"], nil, "Alliance driver hidden from a Horde rider")
	clean(w)
end)

test("going offline sends X and the rider drops the driver", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	ok(r.W.drivers["anita lift"], "seen")
	d.W.Driver.SetOnline(false)
	w:advance(3)
	eq(#msgs(w, "X", ANITA, "CHANNEL"), 1, "one X on the channel")
	eq(r.W.drivers["anita lift"], nil, "dropped on X")
	clean(w)
end)

test("beacon expiry: a driver silent for 150 s is dropped, not before", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	w:closeClient(d) -- the game crashed: no X
	w:advance(140)
	ok(r.W.drivers["anita lift"], "still listed after 140 s")
	w:advance(15)
	eq(r.W.drivers["anita lift"], nil, "dropped after 150 s")
	clean(w)
end)

test("beacons: once a minute or so, not on movement alone, at most one per 5 s", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	local n0 = #msgs(w, "D", ANITA, "CHANNEL")
	-- moving inside Ratchet is not a change
	w:player(ANITA).x = 0.629
	w:advance(20)
	eq(#msgs(w, "D", ANITA, "CHANNEL"), n0, "no beacon for a small move")
	w:advance(60)
	local n1 = #msgs(w, "D", ANITA, "CHANNEL")
	ok(n1 >= n0 + 1 and n1 <= n0 + 2, "one more beacon within 80 s (" .. n0 .. " -> " .. n1 .. ")")
	-- five price changes in a second: at most two beacons in the next 6 s
	local before = #msgs(w, "D", ANITA, "CHANNEL")
	for i = 1, 5 do
		d.W.Char().price = 5000 + i * 100
		d.env.WuberAPI.Beacon()
		w:advance(0.2)
	end
	w:advance(6)
	local after = #msgs(w, "D", ANITA, "CHANNEL")
	ok(after - before >= 1 and after - before <= 2, "coalesced beacons: " .. (after - before))
	eq(r.W.drivers["anita lift"].price, 5500, "the last price reached the rider")
	clean(w)
end)

---------------------------------------------------------------------------
-- 3. Ritual Rides as the provider
---------------------------------------------------------------------------

-- SPEC3 3.3: with Ritual Rides 1.4.1 loaded, Wuber 2.0's engine stays locked off and RR drives
-- through the provider API as before: no engine, no big button, no crew messages.
local function assertLocked(c)
	local W = c.W
	local DR = W.Drive
	ok(DR, c.player.name .. ": W.Drive missing")
	if type(DR.Lock) == "function" then eq(DR.Lock(), "rr", c.player.name .. " DR.Lock()") end
	if type(DR.Active) == "function" then eq(DR.Active() and true or false, false, c.player.name .. " DR.Active() while RR 1.4.1 is loaded") end
	eq(W.engine, nil, c.player.name .. ": W.engine set while RR 1.4.1 drives")
	local b = rawget(c.env, "WuberDriveButton")
	ok(not (b and H.visible(b)), c.player.name .. ": WuberDriveButton shown while locked")
	for _, e in ipairs(c.world.addonLog) do
		ok(not (e.prefix == "WUBERT" and e.from == c.player.name), c.player.name .. " sent a WUBERT message while locked: " .. e.text)
	end
end

local function rrTeam(w, opts)
	opts = opts or {}
	local cs = {}
	for i, n in ipairs({ ANA, BEA, CAL }) do
		cs[i] = w:addClient(n, { spot = opts.spot or "Ratchet", class = "WARLOCK", loadRR = "1.4.1", allowMissing = not HAVE_UI })
	end
	for _, c in ipairs(cs) do assertLocked(c) end
	if opts.grouped ~= false then w:group({ ANA, BEA, CAL }) end
	w:advance(1)
	if opts.named ~= false then for _, c in ipairs(cs) do c:slash("/rr team") end end
	w:advance(1)
	if opts.open ~= false then cs[1]:slash("/rr on") end
	return cs
end

local function rrNeeded() ok(HAVE_RR, "Ritual Rides 1.4.0 (RitualRides/Wuber.lua) not found") end

---------------------------------------------------------------------------
-- 4. Requesting
---------------------------------------------------------------------------

-- the request button: what the rider's secure buttons look like
local function checkSecure(c)
	for _, f in ipairs(c:secureButtons()) do
		local s = S[f]
		local parent = s.parent
		ok(parent == c.env.UIParent, "a secure button must be parented to UIParent (" .. tostring(f) .. ")")
		ok(s.clicks and not s.clicks.AnyDown and not s.clicks.LeftButtonDown, "a secure button registered for down clicks fires twice")
		eq(s.attrs.useOnKeyDown, false, "useOnKeyDown attribute on " .. tostring(f))
		for _, p in ipairs(s.points) do
			local rel = p.rel
			while rel do
				ok(rel == c.env.UIParent or S[rel].parent == nil or S[rel].isUIParent or not (S[rel].name == "WuberFrame"),
					"a secure button anchored to the Wuber window")
				rel = nil
			end
		end
	end
end

test("Request button: whispers exactly 'WTB summon to Ratchet for 50s' and sends R", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	openConfirm(r, "anita lift")
	ok(#r:findText("^Request") > 0, "the pill reads Request (" .. list(r:visibleTexts()) .. ")")
	clickRequest(r)
	w:advance(1)
	local ws = whispersTo(w, ANITA, "macro")
	eq(#ws, 1, "one chat whisper to Anita")
	eq(ws[1].text, "WTB summon to Ratchet for 50s", "the whisper")
	eq(ws[1].from, TESTCHAR)
	local R = msgs(w, "R", TESTCHAR, "WHISPER")
	eq(#R, 1, "one R")
	local f = fields(R[1])
	ok(f[3]:match("^%a%a%a%a%a%a$"), "ride id: 6 letters")
	eq(f[4], "Ratchet") eq(f[5], "5000")
	eq(R[1].target:gsub("%-", " "), ANITA, "R goes to Anita")
	-- (SPEC3 decision 2: the engine takes the ride at once, so it may be past "requesting")
	ok(({ requesting = 1, accepted = 1, invited = 1, ingroup = 1 })[rideState(r) or ""], "the ride is on: " .. tostring(rideState(r)))
	eq(#d.W.incoming, 1, "the driver has the request")
	checkSecure(r)
	clean(w)
end)

for _, mode in ipairs({ { "modern, key-down on", "modern", true }, { "modern, key-down off", "modern", false }, { "legacy client", "legacy", true } }) do
	test("Request click sends one whisper and one R (" .. mode[1] .. ")", function()
		local w = newWorld({ clickMode = mode[2], useKeyDown = mode[3] })
		local d = driver(w)
		local r = rider(w)
		settle(w)
		goOnline(d)
		requestVia(r, "anita lift")
		w:advance(2)
		eq(#whispersTo(w, ANITA, "macro"), 1, "chat whispers")
		eq(#msgs(w, "R", TESTCHAR), 1, "R messages")
		clean(w)
	end)
end

-- () deleted, superseded by the 2.0 engine: "full ride (Driver.lua): accept, invite, summon, arrive, pay, rate"
--   covered by round4 "drive: Wuber: a request is invited and accepted once; each step goes to the rider once, from one window"

-- () deleted, superseded by the 2.0 engine: "decline: the rider is told and can try another driver"
--   covered by round4 "drive: Wuber: blocked is declined 'blocked'; closed and paused are declined 'closed'"

-- () deleted, superseded by the 2.0 engine: "driver's own mode: no answer in 30 s -> N busy"
--   covered by round4 "scenario 9: an old (1.0) rider rides with a 2.0 crew; the away guard pauses an idle driver" (no ACCEPT_WINDOW with the engine)

test("timeout: no answer at all -> R resent once at 8 s, timeout at 40 s, C sent", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	w.drop = { R = 2 } -- both R lost on the way
	r.W.RequestRide("anita lift")
	w:advance(7)
	eq(#w:messages("R", TESTCHAR) + 0, 0, "R lost") -- (dropped ones don't count)
	w:advance(2)
	local sentR = 0
	for _, e in ipairs(w.addonLog) do if e.from == TESTCHAR and e.text:match("^R~") then sentR = sentR + 1 end end
	eq(sentR, 2, "R sent twice")
	w:advance(32)
	eq(rideState(r), "timeout")
	eq(#msgs(w, "C", TESTCHAR), 1, "C sent on timeout")
	clean(w)
end)

test("a lost A: R resent after 8 s, the driver sends A again", function()
	local w = newWorld()
	local d = driver(w, ANITA, { netOnly = true }) -- Net's own accept (the engine accepts at once)
	local r = rider(w)
	settle(w)
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	w.drop = { A = 1 }
	d.W.AcceptRequest(d.W.incoming[1].id, 5) -- (no invite: only the A tells the rider)
	w:advance(2)
	eq(rideState(r), "requesting", "the A was lost")
	w:advance(8)
	ok((RANK or r.W.RIDE_RANK)[rideState(r)] and r.W.RIDE_RANK[rideState(r)] >= 2, "accepted after the resend: " .. tostring(rideState(r)))
	eq(#d.W.incoming, 1, "still one request")
	clean(w)
end)

test("cancel: ordinary button sends C; the driver's card goes", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	requestVia(r, "anita lift")
	w:advance(2)
	r:clickText("^Cancel", { pattern = true })
	w:advance(2)
	ok(rideState(r) == nil or rideState(r) == "cancelled", "cancelled: " .. tostring(rideState(r)))
	local lines = {}
	for _, x in ipairs(whispersTo(w, ANITA, "macro")) do lines[#lines + 1] = x.text end
	ok(#lines <= 2, "whispers: " .. list(lines))
	if #lines == 2 then eq(lines[2], "Sorry, I have to cancel - thanks anyway", "the cancel whisper") end
	eq(#msgs(w, "C", TESTCHAR, "WHISPER"), 1, "C sent")
	eq(#d.W.incoming, 0, "the driver's request is gone")
	for _, x in ipairs(whispersTo(w, ANITA)) do
		ok(not x.text:lower():find("summon") or x.text:find("^WTB"), "a cancel line must not say summon: " .. x.text)
	end
	ok(r.W.CancelWhisper() == nil or r.W.CancelWhisper() == "Sorry, I have to cancel - thanks anyway", "cancel line")
	clean(w)
end)

test("duplicate request: one entry on the driver, the second R answered with A again", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	local ride = r.W.RequestRide("anita lift")
	eq(r.W.RequestRide("anita lift"), ride, "the same ride (idempotent)")
	w:advance(1)
	take(d)
	w:advance(1)
	-- the same R arrives again
	w:inject(TESTCHAR, "R~1~" .. ride.id .. "~Ratchet~5000", "WHISPER", d)
	w:advance(2)
	eq(#d.W.incoming, 1, "one request")
	eq(#msgs(w, "A", ANITA), 2, "A sent again")
	local again, why = r.W.RequestRide("anita lift")
	eq(again, nil) eq(why, "active", "a second ride while one is active")
	clean(w)
end)

test("requests refused locally: yourself, in another group, paused driver", function()
	local w = newWorld()
	local d = driver(w)
	local d2 = driver(w, BOB, { spot = "Crossroads" })
	local r = rider(w)
	settle(w)
	goOnline(d)
	goOnline(d2)
	local x, why = d.W.RequestRide("anita lift")
	eq(x, nil) ok(why == "self" or why == "gone", "yourself: " .. tostring(why))
	w:addBot("Zed Ox")
	w:group({ "Zed Ox", TESTCHAR })
	w:advance(1)
	x, why = r.W.RequestRide("anita lift")
	eq(x, nil) eq(why, "group")
	clean(w)
end)

---------------------------------------------------------------------------
-- 5. Ritual Rides end to end
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- 6. The network under stress
---------------------------------------------------------------------------

test("Q storm: 12 drivers answer one ping at most once each, spread out", function()
	local w = newWorld()
	local ds = {}
	for i = 1, 12 do ds[i] = driver(w, "Lock" .. string.char(64 + i) .. " Driver") end
	for i = 1, 12 do goOnline(ds[i], { wait = 0 }) end
	settle(w, 30)
	local r = rider(w, TESTCHAR)
	w:advance(20) -- the rider joins and pings
	eq(count(r.W.drivers), 12, "the rider hears all twelve")
	local start = w.time
	w:advance(25)
	r.W.Ping()
	local mark = w.time
	w:advance(5)
	local per = {}
	for _, e in ipairs(msgs(w, "D")) do if e.at >= mark then per[e.from] = (per[e.from] or 0) + 1 end end
	for who, n in pairs(per) do ok(n <= 1, who .. " answered " .. n .. " times") end
	-- a second ping within 20 s is not sent
	local q0 = #msgs(w, "Q", TESTCHAR)
	r.W.Ping() r.W.Ping()
	w:advance(1)
	eq(#msgs(w, "Q", TESTCHAR), q0, "no second Q within 20 s")
	clean(w)
end)

test("throttled (result 3) messages are retried", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	w.forceThrottle = 2
	r.W.RequestRide("anita lift")
	w:advance(5)
	eq(#msgs(w, "R", TESTCHAR), 1, "R got through after the throttle")
	eq(#d.W.incoming, 1, "the driver has it")
	clean(w, { throttled = true })
end)

test("channel limit: the rider says so once and shows network unavailable", function()
	local w = newWorld()
	local r = rider(w, TESTCHAR, { channels = 10 })
	settle(w, 100)
	eq(r.W.OnNetwork(), false)
	local n = 0
	for _, l in ipairs(r.chatLines) do if l:find("Couldn't join") or l:find("network") then n = n + 1 end end
	eq(n, 1, "said once (" .. list(r.chatLines, " / ") .. ")")
	if HAVE_UI then
		r.W.UI.Show("home")
		w:advance(1)
		ok(#r:findText("[Nn]etwork") > 0, "network unavailable shown (" .. list(r:visibleTexts()) .. ")")
	end
	clean(w)
end)

test("channel limit on the driver: requests still work by whisper", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	ok(r.W.drivers["anita lift"], "seen")
	-- a loading screen drops the channel, and now the driver is in 10 channels
	w:dropChannels(d)
	for i = #w:player(ANITA).channels + 1, 10 do table.insert(w:player(ANITA).channels, { index = i, name = "Full" .. i }) end
	w:advance(40)
	eq(d.W.OnNetwork(), false, "the driver is off the channel")
	r.W.RequestRide("anita lift")
	w:advance(1)
	eq(#d.W.incoming, 1, "the request arrived by whisper")
	take(d)
	w:advance(2)
	ok(r.W.RIDE_RANK[rideState(r)] >= 2, "accepted")
	clean(w)
end)

test("the channel is rejoined after a loading screen drops it", function()
	local w = newWorld()
	local d = driver(w)
	settle(w)
	ok(d.W.OnNetwork())
	w:dropChannels(d)
	w:advance(35)
	ok(d.W.OnNetwork(), "back in the channel")
	clean(w)
end)

test("joining waits for the game's channels (General keeps /1)", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	local idx = r.W.ChannelIndex()
	ok(idx and idx > 4, "WuberNet is after the game's channels: " .. tostring(idx))
	clean(w)
end)

test("long service and dest names never make a message over 255 bytes", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	d.W.Char().service = ("Ünïcödé Summons Extraordinaire "):rep(12)
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(2)
	take(d)
	w:advance(3)
	for _, e in ipairs(w.addonLog) do ok(#e.text <= 255, "message of " .. #e.text) end
	local x = r.W.drivers["anita lift"]
	ok(x and #x.service <= 32, "service cut on receipt")
	-- a hostile beacon with 400-byte fields is simply ignored (over 255)
	w:inject("Evil Guy", "D~1~" .. ("x"):rep(400) .. "~1413~1~1~1~y~open~1~1", "CHANNEL")
	w:advance(1)
	eq(r.W.drivers["evil guy"], nil, "an oversized message is ignored")
	clean(w)
end)

test("bad numbers (nan, inf, 1e9, 0x10, -5) and unknown trailing fields", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	for i, v in ipairs({ "nan", "inf", "1e9", "0x10", "-5", "99999999999", "" }) do
		local name = "Bad Num" .. string.char(96 + i)
		w:inject(name, table.concat({ "D", "1", "Ratchet", v, v, v, v, "Svc", "open", v, v, "H", "1.0.0", "extra", "more" }, "~"), "CHANNEL")
	end
	w:advance(1)
	for _, d in pairs(r.W.drivers) do
		for _, k in ipairs({ "price", "team", "seats" }) do
			local n = d[k]
			ok(type(n) == "number" and n == n and n ~= math.huge and n >= 0 and n % 1 == 0, d.key .. "." .. k .. " = " .. tostring(n))
		end
		ok(d.price <= 99999999, "price clamped")
		ok(d.team >= 1 and d.team <= 3, "team clamped")
		ok(d.x == nil or (d.x >= 0 and d.x <= 1), "x in range")
	end
	-- a higher protocol version or an unknown kind is ignored
	w:inject("Future Guy", "D~2~Ratchet~1413~1~1~1~y~open~1~1", "CHANNEL")
	w:inject("Future Guy", "Z~1~whatever", "CHANNEL")
	w:advance(1)
	eq(r.W.drivers["future guy"], nil, "proto 2 ignored")
	clean(w)
end)

test("trust: D by whisper, R on the channel, A from a stranger, X for someone else", function()
	local w = newWorld()
	local d = driver(w, ANITA, { netOnly = true }) -- the ride must stay "requesting" (the engine accepts at once)
	local r = rider(w)
	settle(w)
	goOnline(d)
	w:inject("Fake Lock", "D~1~Ratchet~1413~500~500~100~Fake~open~1~1~H~1.0.0", "WHISPER", r)
	w:advance(1)
	eq(r.W.drivers["fake lock"], nil, "D by whisper ignored")
	w:inject("Evil Guy", "X~1", "CHANNEL")
	w:advance(1)
	ok(r.W.drivers["anita lift"], "X from someone else removes nothing")
	local ride = r.W.RequestRide("anita lift")
	w:advance(1)
	w:inject("Evil Guy", "A~1~" .. ride.id .. "~1~0", "WHISPER", r)
	w:inject("Evil Guy", "S~1~" .. ride.id .. "~done", "WHISPER", r)
	w:advance(1)
	eq(rideState(r), "requesting", "A/S from a stranger ignored")
	w:inject(TESTCHAR, "R~1~ABCDEF~Ratchet~5000", "CHANNEL")
	w:inject("Evil Guy", "C~1~" .. ride.id, "WHISPER", d)
	w:advance(1)
	eq(#d.W.incoming, 1, "R on the channel ignored; C from a stranger ignored")
	clean(w)
end)

test("macro injection: a hostile dest never reaches a macro", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	w:inject("Evil Lock", "D~1~x\n/run print(1)|cff~1413~500~500~5000~Evil|r\n/script x~open~1~1~H~1.0.0", "CHANNEL")
	w:inject("Evil Lock", "D~1~Ratchet /run DoEvil()~1413~500~500~5000~Evil~open~1~1~H~1.0.0", "CHANNEL")
	w:advance(1)
	local d = r.W.drivers["evil lock"]
	ok(d, "the second beacon is heard (cleaned)")
	do
		ok(not d.dest:find("[\n|/]"), "dest cleaned: " .. d.dest)
		local m = r.W.RequestMacro("evil lock")
		ok(m, "a macro")
		ok(not m:find("\n") and not m:find("|") and not m:find("/run") and not m:find("/script"), "macro: " .. m)
		ok(m:match("^/w Evil%-Lock "), "whisper target from the sender: " .. m)
		if HAVE_UI then
			requestVia(r, "evil lock")
			w:advance(1)
			for _, mm in ipairs(w.macros) do ok(not mm.text:find("\n") and not mm.text:find("/run"), "macro run: " .. mm.text) end
		end
	end
	clean(w)
end)

test("sender names with -Realm: the whole ride still works", function()
	local w = newWorld({ senderFormat = "realm" })
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	ok(r.W.drivers["anita lift"], "the key drops our realm (" .. list((function() local t = {} for k in pairs(r.W.drivers) do t[#t + 1] = k end return t end)()) .. ")")
	eq(r.W.drivers["anita lift"].name, ANITA, "shown without the realm")
	local m = r.W.RequestMacro("anita lift")
	eq(m, "/w Anita-Lift WTB summon to Ratchet for 50s", "the macro")
	r.W.RequestRide("anita lift")
	w:advance(1)
	eq(#d.W.incoming, 1, "R arrived")
	take(d)
	w:advance(2)
	ok(r.W.RIDE_RANK[rideState(r)] >= 2, "accepted")
	clean(w)
end)

---------------------------------------------------------------------------
-- 7. Secret values and combat
---------------------------------------------------------------------------

test("secret values: UnitName, C_Map, GetMoney, zone text, UnitClass -> no errors", function()
	local w = newWorld()
	local d = driver(w, ANITA, { secrets = { "C_Map", "GetMoney", "zone" } })
	local r = rider(w, TESTCHAR, { secrets = { "UnitName", "C_Map", "GetMoney", "zone", "UnitClass" } })
	settle(w)
	goOnline(d)
	if HAVE_UI then r.W.UI.Show("home") w:advance(2) end
	r.W.RequestRide("anita lift")
	w:advance(2)
	take(d)
	w:advance(5)
	if HAVE_UI then r.W.UI.Toggle() w:advance(1) end
	w:openMap(r, 1413)
	w:advance(1)
	for _, e in ipairs(w.addonLog) do ok(not e.text:find("<secret>"), "secret in a message") end
	clean(w)
end)

test("secret sender in CHAT_MSG_ADDON is ignored without errors", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w, TESTCHAR, { secrets = { "sender" } })
	settle(w)
	goOnline(d)
	eq(count(r.W.drivers), 0, "nothing usable heard")
	clean(w)
end)

-- (round two, lead's ruling: "book while busy" - in combat the request still goes as R, without the whisper)
test("combat: the Request pill still books (R), no whisper, nothing protected touched, no secure overlay shown", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	openConfirm(r, "anita lift")
	w:enterCombat(r)
	w:advance(1)
	-- the window itself can still be closed and opened (no secure child inside it)
	r.W.UI.Toggle()
	w:advance(0.5)
	r.W.UI.Show("confirm", "anita lift")
	w:advance(1)
	local hits = r:findText("[Ii]n combat")
	ok(#hits > 0, "the pill says in combat (" .. list(r:visibleTexts()) .. ")")
	for _, f in ipairs(secureShown(r)) do
		local mt = S[f].attrs.macrotext
		ok(mt == nil or mt == "", "no live macro on a shown secure button in combat")
	end
	eq(#secureShown(r), 0, "no secure overlay shown in combat")
	local hit = r:clickOn(hits[1])
	ok(not S[hit].secure, "the click lands on an ordinary button")
	w:advance(1)
	eq(#whispersTo(w, ANITA, "macro"), 0, "no whisper in combat")
	eq(#msgs(w, "R", TESTCHAR), 1, "R sent in combat")
	-- (SPEC3 decision 2: the engine takes the ride at once, so it may be past "requesting")
	ok(({ requesting = 1, accepted = 1, invited = 1, ingroup = 1 })[rideState(r) or ""], "the ride is on: " .. tostring(rideState(r)))
	eq(#d.W.incoming, 1, "the driver has it")
	w:leaveCombat(r)
	w:advance(2)
	eq(#whispersTo(w, ANITA, "macro"), 0, "no whisper sent later by itself")
	clean(w)
end)

test("combat: after the fight the Request pill whispers again", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	openConfirm(r, "anita lift")
	w:enterCombat(r)
	w:advance(1)
	w:leaveCombat(r)
	w:advance(2)
	clickRequest(r)
	w:advance(1)
	eq(#whispersTo(w, ANITA, "macro"), 1, "works again after combat")
	eq(#msgs(w, "R", TESTCHAR), 1)
	clean(w)
end)

test("protected-frame rule: a frame with a secure child is protected in combat (harness self-check)", function()
	local w = newWorld()
	local r = rider(w)
	settle(w)
	local env = r.env
	local box = env.CreateFrame("Frame", nil, env.UIParent)
	local b = env.CreateFrame("Button", nil, box, "SecureActionButtonTemplate")
	w:enterCombat(r)
	box:Hide()
	eq(#w.violations, 1, "hiding the parent of a secure button in combat is blocked")
	local okc = pcall(b.SetAttribute, b, "macrotext", "/w x y")
	eq(okc, false, "SetAttribute in combat raises")
	w:leaveCombat(r)
	w.violations = {}
	clean(w)
end)

---------------------------------------------------------------------------
-- 8. Map pins
---------------------------------------------------------------------------

local function pins(c)
	local out = {}
	local canvas = c.mapCanvas
	for _, f in ipairs(c.frames) do
		if S[f].parent == canvas and rawget(f, "key") and H.visible(f) then out[#out + 1] = f end
	end
	return out
end

local function pinAt(c, pin)
	local canvas = c.mapCanvas
	local cr, pr = H.rect(canvas), H.rect(pin)
	return (pr.l + pr.w / 2 - cr.l) / cr.w, (cr.b + cr.h - (pr.b + pr.h / 2)) / cr.h
end

test("map pins: driver's map, parent map, unrelated map, closed map", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	w:openMap(r, 1413)
	w:advance(0.5)
	local p = pins(r)
	eq(#p, 1, "one pin on The Barrens")
	local x, y = pinAt(r, p[1])
	ok(math.abs(x - 0.627) < 0.01 and math.abs(y - 0.370) < 0.01, ("pin at %.3f, %.3f"):format(x, y))
	eq(rawget(p[1], "key"), "anita lift")
	-- zoomed in: the pin keeps its size and place (a creator's pin is drawn bigger: compare with itself)
	local scale1 = H.effScale(p[1])
	ok(scale1 >= 0.99 and scale1 <= 1.6, "pin scale at zoom 1: " .. scale1)
	r.canvasScale = 2
	S[r.mapCanvas].scale = 2
	w:advance(0.5)
	p = pins(r)
	eq(#p, 1, "pin while zoomed")
	x, y = pinAt(r, p[1])
	ok(math.abs(x - 0.627) < 0.01 and math.abs(y - 0.370) < 0.01, ("zoomed pin at %.3f, %.3f"):format(x, y))
	ok(math.abs(H.effScale(p[1]) - scale1) < 0.01, "constant size on screen (scale " .. H.effScale(p[1]) .. " vs " .. scale1 .. ")")
	r.canvasScale = 1
	S[r.mapCanvas].scale = 1
	-- Kalimdor: a parent map
	r.env.WorldMapFrame:SetMapID(1414)
	w:advance(0.5)
	p = pins(r)
	eq(#p, 1, "pin on Kalimdor")
	local cont, wx, wy = H.toWorld(1413, 0.627, 0.370)
	local ex, ey = H.fromWorld(cont, wx, wy, 1414)
	x, y = pinAt(r, p[1])
	ok(math.abs(x - ex) < 0.01 and math.abs(y - ey) < 0.01, ("Kalimdor pin at %.3f, %.3f, expected %.3f, %.3f"):format(x, y, ex, ey))
	-- the Eastern Kingdoms: no pin
	r.env.WorldMapFrame:SetMapID(1415)
	w:advance(0.5)
	eq(#pins(r), 0, "no pin on the Eastern Kingdoms")
	-- Azeroth without OpenMap: no pin
	r.env.WorldMapFrame:SetMapID(947)
	w:advance(0.5)
	eq(#pins(r), 0, "no pin on Azeroth without OpenMap")
	-- closed
	r.env.WorldMapFrame:SetMapID(1413)
	r.env.WorldMapFrame:Hide()
	w:advance(0.5)
	eq(#pins(r), 0, "no pins while the map is closed")
	clean(w)
end)

test("map pins: on the driver's own map too, and off with the setting", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	w:openMap(r, 1413)
	w:advance(0.5)
	eq(#pins(r), 1)
	r.W.Map.SetShown(false)
	w:advance(0.5)
	eq(#pins(r), 0, "pins off")
	eq(r.W.db.mapPins, false)
	r.W.Map.SetShown(true)
	w:advance(0.5)
	eq(#pins(r), 1, "pins on again")
	-- the driver goes away: the pin goes
	d.W.Driver.SetOnline(false)
	w:advance(3)
	eq(#pins(r), 0, "no pin after X")
	clean(w)
end)

test("map pins: OpenMap stitched (Azeroth), its callbacks and menu toggle", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w, TESTCHAR, { openMap = { stitched = true } })
	settle(w)
	goOnline(d)
	w:openMap(r, 947)
	w:advance(0.5)
	local p = pins(r)
	eq(#p, 1, "a pin on the stitched world")
	local u, v = r.env.OpenMapAPI.WorldFromMap(1413, 0.627, 0.370)
	local x, y = pinAt(r, p[1])
	ok(math.abs(x - u) < 0.01 and math.abs(y - v) < 0.01, ("stitched pin at %.3f, %.3f, expected %.3f, %.3f"):format(x, y, u, v))
	ok(S[p[1]].level == nil or p[1]:GetFrameLevel() > 500, "above OpenMap's art (level " .. p[1]:GetFrameLevel() .. ")")
	ok(r.openMap.toggles["Wuber.drivers"], "menu toggle registered")
	local tog = r.openMap.toggles["Wuber.drivers"]
	tog.set(false)
	w:advance(0.5)
	eq(#pins(r), 0, "toggled off from OpenMap's menu")
	eq(tog.get(), false)
	tog.set(true)
	w:advance(0.5)
	-- callbacks get the event name first
	w:openMapFire(r, "OpenMap_ViewChanged", 0.3, 0.4, 2)
	w:openMapFire(r, "OpenMap_StitchedChanged", false)
	r.openMap.stitched = false
	w:openMapFire(r, "OpenMap_StitchedChanged", false)
	w:advance(0.5)
	eq(#pins(r), 0, "no pin on Azeroth once OpenMap is not stitched")
	-- Show on map glides OpenMap there
	r.openMap.stitched = true
	r.W.Map.ShowDriver("anita lift")
	w:advance(0.5)
	ok(#r.openMap.shown >= 1, "ShowWorld called")
	clean(w)
end)

test("map pins: OpenMap without RegisterCallback (no CallbackHandler)", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w, TESTCHAR, { openMap = { stitched = true } })
	settle(w)
	goOnline(d)
	clean(w)
	-- a second rider whose OpenMap lacks callbacks
	local w2 = newWorld()
	local d2 = driver(w2)
	local r2 = w2:addClient(TESTCHAR, { spot = "Orgrimmar", class = "MAGE", openMap = { stitched = true }, allowMissing = not HAVE_UI,
		prepare = function(env) env.OpenMapAPI.RegisterCallback = nil end })
	eq(r2.env.OpenMapAPI.RegisterCallback, nil, "no RegisterCallback")
	settle(w2)
	goOnline(d2)
	w2:openMap(r2, 1413)
	w2:advance(1)
	clean(w2)
end)

test("a pin click opens the Wuber window on Confirm for that driver", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	needUI(r)
	w:openMap(r, 1413)
	w:advance(0.5)
	local p = pins(r)
	eq(#p, 1)
	r:click(p[1])
	w:advance(1.5)
	ok(#r:findText("Request") > 0, "Confirm screen with Request (" .. list(r:visibleTexts()) .. ")")
	clean(w)
end)

---------------------------------------------------------------------------
-- 9. The window
---------------------------------------------------------------------------

test("the window: toggles, Escape closes it, scales for a small window", function()
	local w = newWorld()
	local r = rider(w, TESTCHAR, { physH = 1080 })
	settle(w)
	needUI(r)
	r.W.UI.Toggle()
	w:advance(1)
	local f = r.env.WuberFrame
	ok(f, "the window is named WuberFrame")
	ok(f:IsVisible(), "shown")
	local found = false
	for _, n in ipairs(r.env.UISpecialFrames) do if n == "WuberFrame" then found = true end end
	ok(found, "WuberFrame in UISpecialFrames")
	ok(r:pressEscape(), "Escape closes it")
	w:advance(1)
	ok(not f:IsVisible(), "closed")
	clean(w)
end)

test("the window: empty state and Ping drivers", function()
	local w = newWorld()
	local r = rider(w)
	settle(w, 40)
	needUI(r)
	r.W.UI.Show("home")
	w:advance(2.5)
	ok(#r:findText("No drivers online") > 0, "empty state (" .. list(r:visibleTexts()) .. ")")
	local q0 = #msgs(w, "Q", TESTCHAR)
	r:clickText("Ping drivers")
	w:advance(1)
	eq(#msgs(w, "Q", TESTCHAR), q0 + 1, "Q sent")
	clean(w)
end)

-- SPEC4 1.1 (2.1): any class may run the service; the "Only Warlocks can drive" view is gone
test("Drive tab: a Mage is not turned away; GO ONLINE button works", function()
	local w = newWorld()
	local m = rider(w, BOB, { class = "MAGE" })
	local d = driver(w)
	settle(w)
	openDrive(m)
	ok(#m:findText("Only Warlocks can drive") == 0, "no 'only Warlocks' (" .. list(m:visibleTexts()) .. ")")
	openDrive(d)
	clickGo(d)
	w:advance(3)
	eq(d.W.Char().drive, true, "online by the button")
	ok(#msgs(w, "D", ANITA) >= 1, "beaconing")
	clean(w)
end)

test("/reload during a ride: the ride is picked up again", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	take(d)
	w:advance(2)
	local id = r.W.ride.id
	local r2 = w:reload(r)
	w:advance(3)
	ok(r2.W.ride, "the ride is back")
	eq(r2.W.ride.id, id)
	ok(r2.W.RIDE_RANK[r2.W.ride.state] >= 2, "still accepted or later: " .. tostring(r2.W.ride.state))
	clean(w)
end)


---------------------------------------------------------------------------
-- 10. More
---------------------------------------------------------------------------

test("harness self-check: hiding the invite box without inviteAccepted declines the invite", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	d.env.C_PartyInfo.InviteUnit(TESTCHAR)
	w:advance(0.5)
	ok(r.popups.PARTY_INVITE, "invite box up")
	r.env.StaticPopup_Hide("PARTY_INVITE")
	w:advance(1)
	eq(w:player(TESTCHAR).group, nil, "declined")
	eq(r.declinedGroup, 1)
	eq(#w.violations, 1, "recorded")
end)

test("harness self-check: a secure button registered for down and up whispers twice (legacy)", function()
	local w = newWorld({ clickMode = "legacy" })
	local d = driver(w)
	local r = rider(w)
	settle(w)
	local b = r.env.CreateFrame("Button", nil, r.env.UIParent, "SecureActionButtonTemplate")
	b:SetSize(50, 20) b:SetPoint("CENTER")
	b:RegisterForClicks("AnyUp", "AnyDown")
	b:SetAttribute("type", "macro")
	b:SetAttribute("macrotext", "/w Anita-Lift hi")
	r:click(b)
	eq(#whispersTo(w, ANITA), 2, "two whispers from one click")
	local w2 = newWorld({ clickMode = "modern" })
	driver(w2)
	local r2 = rider(w2)
	local b2 = r2.env.CreateFrame("Button", nil, r2.env.UIParent, "SecureActionButtonTemplate")
	b2:SetSize(50, 20) b2:SetPoint("CENTER")
	b2:RegisterForClicks("AnyUp", "AnyDown")
	b2:SetAttribute("type", "macro")
	b2:SetAttribute("macrotext", "/w Anita-Lift hi")
	local pre = 0
	b2:SetScript("PreClick", function() pre = pre + 1 end)
	r2:click(b2)
	eq(#whispersTo(w2, ANITA), 1, "modern: one whisper")
	eq(pre, 2, "modern: PreClick twice")
end)

test("W.Driver.Toggle (minimap right-click, /wuber drive) shows the Drive screen", function()
	local w = newWorld()
	local d = driver(w)
	settle(w)
	d.W.Char().wizard = true
	d.W.Driver.Toggle()
	w:advance(2.5)
	local pill = d.W.Driver.ui and d.W.Driver.ui.console and d.W.Driver.ui.console.open
	ok(pill and H.visible(pill), "the Open pill visible (" .. list(d:visibleTexts()) .. ")")
	clean(w)
end)

test("minimap button: left click opens the window, right click the Drive screen", function()
	local w = newWorld()
	local d = driver(w)
	settle(w)
	d.W.Char().wizard = true
	local b = d.env.WuberMinimapButton
	ok(b and H.visible(b), "WuberMinimapButton shown")
	d:click(b, "LeftButton")
	w:advance(2.5)
	ok(d.env.WuberFrame:IsVisible(), "window open")
	d:click(b, "LeftButton")
	w:advance(1)
	ok(not d.env.WuberFrame:IsVisible(), "window closed")
	d:click(b, "RightButton")
	w:advance(2.5)
	local pill = d.W.Driver.ui and d.W.Driver.ui.console and d.W.Driver.ui.console.open
	ok(pill and H.visible(pill), "the Drive console (" .. list(d:visibleTexts()) .. ")")
	ok(#d:findText("isn't available") == 0, "no 'Driving isn't available' toast")
	clean(w)
end)

test("slash commands: /wuber, /ride, drive, price, ping, map, minimap, status, help", function()
	local w = newWorld()
	local d = driver(w)
	settle(w)
	for _, line in ipairs({ "/wuber", "/wuber", "/ride", "/ride", "/wuber drive", "/wuber price 2g 50s", "/wuber ping",
		"/wuber map", "/wuber map", "/wuber minimap", "/wuber minimap", "/wuber status", "/wuber help", "/wuber drive off" }) do
		d:slash(line)
		w:advance(1)
	end
	eq(d.W.Char().price, 25000, "/wuber price 2g 50s")
	clean(w)
end)

test("Drive tab: price typed in the box", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	-- SPEC3 2.3: the price lives in the bottom sheet, opened by tapping the fare
	openDrive(d)
	d:clickOn(d.W.Driver.ui.console.fare)
	w:advance(1)
	local price = d.W.UI.drive.screens.sheet.price.edit
	ok(price and H.visible(price), "the sheet's price field")
	ok((price:GetText() or ""):find("50s"), "the price box shows 50s (" .. tostring(price:GetText()) .. ")")
	d:type(price, "1g")
	w:advance(1)
	eq(d.W.Char().price, 10000, "price saved")
	eq(price:HasFocus(), false, "focus let go after Enter")
	if H.visible(price) then d:pressEscape() w:advance(0.5) end
	clickGo(d)
	w:advance(6)
	eq(r.W.drivers["anita lift"] and r.W.drivers["anita lift"].price, 10000, "riders see 1g")
	clean(w)
end)

test("search box: typing a place filters, Escape and hiding clear focus", function()
	local w = newWorld()
	local d = driver(w)
	local d2 = driver(w, BOB, { spot = "Crossroads" })
	local r = rider(w)
	settle(w)
	goOnline(d)
	goOnline(d2)
	needUI(r)
	r.W.UI.Show("home")
	w:advance(2.5)
	local box
	for _, f in ipairs(r.frames) do if S[f].otype == "EditBox" and H.visible(f) then box = f end end
	ok(box, "a search box")
	eq(box:HasFocus(), false, "no autofocus (the keyboard stays with the game)")
	r:type(box, "ratchet")
	w:advance(1)
	ok(#r:findText("Bob") == 0 or #r:findText("Ratchet") > 0, "filtered")
	r:pressEscape()
	w:advance(1)
	eq(box:HasFocus(), false, "focus cleared")
	clean(w)
end)

test("minimum fare 50s: a 1c cheater is invisible, its price drop removes it, low R refused", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	w:inject("Cheap Lock", "D~1~Ratchet~1413~627~370~1~Cheap~open~1~1~H~1.0.0", "CHANNEL")
	w:inject("Free Lock", "D~1~Ratchet~1413~627~370~0~Free~open~1~1~H~1.0.0", "CHANNEL")
	w:advance(1)
	eq(r.W.drivers["cheap lock"], nil, "a 1c driver is not listed")
	eq(r.W.drivers["free lock"], nil, "a free driver is not listed")
	-- a listed driver that drops below 50s goes
	w:inject("Fair Lock", "D~1~Ratchet~1413~627~370~5000~Fair~open~1~1~H~1.0.0", "CHANNEL")
	w:advance(1)
	ok(r.W.drivers["fair lock"], "a 50s driver is listed")
	w:inject("Fair Lock", "D~1~Ratchet~1413~627~370~4999~Fair~open~1~1~H~1.0.0", "CHANNEL")
	w:advance(1)
	eq(r.W.drivers["fair lock"], nil, "dropped below 50s: removed")
	if HAVE_UI then
		r.W.UI.Show("home")
		w:advance(2.5)
		ok(#r:findText("Cheap") == 0 and #r:findText("Fair") == 0, "no card for them")
	end
	-- our own driver can't beacon under 50s
	goOnline(d)
	d.W.Char().price = 100
	eq(d.W.DriverBeacon().price, 5000, "own beacon clamped to 50s")
	-- a 1c request is refused with N price
	w:addBot("Cheap Rider")
	w:inject("Cheap Rider", "R~1~ABCDEF~Ratchet~1", "WHISPER", d)
	w:advance(2)
	local N = msgs(w, "N", ANITA)
	eq(#N, 1, "N for a 1c request")
	eq(fields(N[1])[4], "price")
	eq(#d.W.incoming, 0, "not listed on the driver")
	clean(w)
end)

test("minimum fare 50s: /wuber price and the Drive price box refuse less", function()
	local w = newWorld()
	local d = driver(w)
	settle(w)
	d:slash("/wuber price 10s")
	ok(d:said("lowest fare on Wuber is 50s"), "told")
	eq(d.W.Char().price, 5000, "price unchanged")
	d:slash("/wuber price 1g")
	eq(d.W.Char().price, 10000, "1g taken")
	openDrive(d)
	d:clickOn(d.W.Driver.ui.console.fare)
	w:advance(1)
	local price = d.W.UI.drive.screens.sheet.price.edit
	ok(price and H.visible(price) and (price:GetText() or ""):find("1g"), "the price box")
	d:type(price, "5c")
	w:advance(1)
	-- SPEC3 2.3: the field clamps to 50s and says so (1.x refused and kept 1g)
	ok(d.W.Char().price == 10000 or d.W.Char().price == 5000, "5c refused: " .. tostring(d.W.Char().price))
	ok(d.W.Char().price >= 5000, "never under 50s")
	clean(w)
end)

test("summon: accepting in combat is refused, an expired summon goes back to waiting", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	r.W.db.autoAccept = false -- this test clicks Wuber's Accept invite button
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	take(d)
	w:advance(1)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	r:clickText("Accept invite")
	w:advance(1)
	eq(rideState(r), "ingroup")
	w:summon(d, TESTCHAR)
	w:advance(1)
	eq(rideState(r), "portal")
	-- it runs out
	w:advance(121)
	eq(rideState(r), "ingroup", "an expired summon: back to waiting")
	-- again, now in combat
	w:summon(d, TESTCHAR)
	w:advance(1)
	w:enterCombat(r)
	w:advance(0.5)
	if #r:findText("Accept summon") > 0 then r:clickText("Accept summon") end
	w:advance(2)
	eq(r.confirmedSummons, nil, "no ConfirmSummon in combat")
	eq(w:player(TESTCHAR).zone, "Orgrimmar", "still in Orgrimmar")
	w:leaveCombat(r)
	w:advance(1)
	r:clickText("Accept summon")
	w:advance(3)
	eq(w:player(TESTCHAR).subZone, "Ratchet", "summoned after the fight")
	eq(rideState(r), "arrived")
	clean(w)
end)

test("lost S messages: the rider still follows the ride from the game's own events", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	r.W.db.autoAccept = false -- this test clicks Wuber's Accept invite button
	goOnline(d)
	w.drop = { S = 100 }
	r.W.RequestRide("anita lift")
	w:advance(1)
	take(d)
	w:advance(1)
	eq(rideState(r), "invited", "invited from PARTY_INVITE_REQUEST")
	r.W.UI.Toggle(true)
	w:advance(2.5)
	r:clickText("Accept invite")
	w:advance(1)
	eq(rideState(r), "ingroup", "from GROUP_ROSTER_UPDATE")
	w:summon(d, TESTCHAR)
	w:advance(1)
	eq(rideState(r), "portal", "from CONFIRM_SUMMON")
	r:clickText("Accept summon")
	w:advance(3)
	eq(rideState(r), "arrived", "from the zone change")
	w:openTrade(d, r)
	w:advance(0.5)
	eq(rideState(r), "paying", "from TRADE_SHOW")
	w:tradeMoney(r, 5000)
	w:tradeAccept(d)
	w:tradeAccept(r)
	w:advance(1)
	eq(rideState(r), "done", "from PLAYER_MONEY")
	clean(w)
end)

test("a trade from another of the driver's Warlocks still counts as paying", function()
	local w = newWorld()
	local d = driver(w)
	local helper = driver(w, BOB)
	local r = rider(w)
	settle(w)
	r.W.db.autoAccept = false -- this test clicks Wuber's Accept invite button
	goOnline(d)
	r.W.RequestRide("anita lift")
	w:advance(1)
	take(d)
	w:advance(1)
	r.W.UI.Toggle(true)
	w:advance(2.5)
	r:clickText("Accept invite")
	w:advance(1)
	-- (review 2.2 #1: only the driver, the payee or crew it names, or the
	-- Warlock whose summon the rider accepted counts - not just anyone in the group)
	w:join(w:player(ANITA), w:player(BOB))
	w:advance(1)
	-- (d4 x4) Bob is not on a crew list here, so his CAST is not heard: the driver's list counts the summon as hers
	d.W.Drive.customers["wuber testcharacter"].tries = 1
	w:summon(helper, TESTCHAR) -- Bob casts the summon
	w:advance(1)
	eq(rideState(r), "portal", "a summon from a teammate")
	r:clickText("Accept summon")
	w:advance(3)
	w:openTrade(helper, r)
	w:tradeMoney(r, 5000)
	w:tradeAccept(helper)
	w:tradeAccept(r)
	w:advance(1)
	eq(rideState(r), "done")
	clean(w)
end)

test("toasts: the rider hears when the driver accepts", function()
	local w = newWorld()
	local d = driver(w, ANITA, { netOnly = true }) -- the accept alone (the engine invites at once too)
	local r = rider(w)
	settle(w)
	goOnline(d)
	needUI(r)
	r.W.RequestRide("anita lift")
	w:advance(1)
	d.W.AcceptRequest(d.W.incoming[1].id, 5)
	w:advance(0.5)
	ok(#r:findText("accepted") > 0, "a toast says accepted (" .. list(r:visibleTexts()) .. ")")
	ok(#r.sounds > 0, "with a sound")
	clean(w)
end)

for _, size in ipairs({ { 1024, 520 }, { 1920, 1080, 1.5 }, { 1920, 1080, 0.6 } }) do
	test("the Request overlay sits on the pill when the window is scaled (" .. size[1] .. "x" .. size[2] .. ", scale " .. tostring(size[3] or "auto") .. ")", function()
		local w = newWorld()
		local d = driver(w)
		local r = rider(w, TESTCHAR, { screenW = size[1], screenH = size[2] })
		settle(w)
		goOnline(d)
		if size[3] then r.W.db.scale = size[3] end
		openConfirm(r, "anita lift")
		local scale = H.effScale(r.env.WuberFrame)
		ok(math.abs(scale - 1) > 0.05, "the window is scaled: " .. scale)
		-- move the window, as a player would, then ask again
		local hits = r:findText("^Request")
		ok(#hits == 1, "one Request pill (" .. list(r:visibleTexts()) .. ")")
		local hit = r:clickOn(hits[1])
		ok(S[hit].secure, ("the click on the pill lands on the secure button (window scale %.2f, hit %s)"):format(scale, tostring(hit)))
		w:advance(1)
		eq(#whispersTo(w, ANITA, "macro"), 1, "whisper")
		clean(w)
	end)
end

test("the Request overlay follows the window when it is dragged", function()
	local w = newWorld()
	local d = driver(w)
	local r = rider(w)
	settle(w)
	goOnline(d)
	openConfirm(r, "anita lift")
	local win = r.env.WuberFrame
	local before = H.rect(win).l
	local bar
	for _, f in ipairs(r.frames) do
		local st_ = S[f]
		if st_.drag and #st_.drag > 0 and st_.scripts.OnDragStart and H.visible(f) then
			local p = f
			while p and p ~= win do p = S[p].parent end
			if p == win then bar = bar or f end
		end
	end
	ok(bar, "something in the window drags it")
	r:drag(bar, -200, 50)
	-- the harness drags by the window's own units (the window is scaled: 1.15 by default)
	local moved = 200 * H.effScale(win) / H.effScale(r.env.UIParent)
	ok(math.abs(H.rect(win).l - (before - moved)) < 1, "the window moved: " .. before .. " -> " .. H.rect(win).l)
	w:advance(1.5)
	local hits = r:findText("^Request")
	local hit = r:clickOn(hits[1])
	ok(S[hit].secure, "after a drag the click still lands on the secure button (hit " .. tostring(hit) .. ")")
	clean(w)
end)

-- () deleted, superseded by the 2.0 engine: "secret UnitName and GetMoney on the rider: the full ride still ends (driver's S messages)"
--   covered by round4 "scenario 18: secret values on names, money, trade money, spell ids and senders: no errors"

-- () deleted, superseded by the 2.0 engine: "two riders at once: the driver takes one, shows busy, the other is declined"
--   covered by round4 "drive: Wuber: the chat line first, then the request: still one rider; a second rider waits and is told"

---------------------------------------------------------------------------
-- Round two (tests/round2.lua): the same helpers, handed over in one table
---------------------------------------------------------------------------

do
	local chunk = assert(loadfile(dir .. "/round2.lua"))
	chunk({
		H = H, S = S, test = test, pending = pending, take = take, clickGo = clickGo, netOnly = netOnly, goOffline = goOffline, eq = eq, ok = ok, count = count, list = list, newWorld = newWorld, driver = driver, rider = rider,
		settle = settle, goOnline = goOnline, clean = clean, msgs = msgs, fields = fields, needUI = needUI, openConfirm = openConfirm,
		clickRequest = clickRequest, requestVia = requestVia, openDrive = openDrive, driverAccept = driverAccept, take = take, pending = pending, rideState = rideState,
		whispersTo = whispersTo, readFile = readFile, HAVE_UI = HAVE_UI, HAVE_RR = HAVE_RR, rrTeam = rrTeam, rrNeeded = rrNeeded, assertLocked = assertLocked,
		pins = pins, pinAt = pinAt, ANITA = ANITA, TESTCHAR = TESTCHAR, BOB = BOB, ANA = ANA, BEA = BEA, CAL = CAL, dir = dir,
	})
end

-- The whisper fallback and gossip mesh (tests/whisper.lua)
do
	local chunk = assert(loadfile(dir .. "/whisper.lua"))
	chunk({ H = H, test = test, pending = pending, take = take, clickGo = clickGo, netOnly = netOnly, goOffline = goOffline, eq = eq, ok = ok, list = list, count = count, newWorld = newWorld, settle = settle,
		clean = clean, goOnline = goOnline, msgs = msgs, fields = fields, HAVE_UI = HAVE_UI, HAVE_RR = HAVE_RR })
end

-- The Wuber community transport, the founder's invites, and ending a ride after arriving
-- (tests/community.lua)
do
	local chunk = assert(loadfile(dir .. "/community.lua"))
	chunk({ H = H, test = test, pending = pending, take = take, clickGo = clickGo, netOnly = netOnly, goOffline = goOffline, eq = eq, ok = ok, list = list, newWorld = newWorld, settle = settle, clean = clean,
		goOnline = goOnline, msgs = msgs, fields = fields, openDrive = openDrive, rideState = rideState,
		openConfirm = openConfirm, HAVE_UI = HAVE_UI })
end

-- Discovery (tests/discovery.lua): adverts in chat, rulesets and seeds, announces, the
-- founders' directory, the "How Wuber finds drivers" page, the OpenMap hint
do
	local chunk = assert(loadfile(dir .. "/discovery.lua"))
	chunk({ H = H, test = test, pending = pending, take = take, clickGo = clickGo, netOnly = netOnly, goOffline = goOffline, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider,
		settle = settle, goOnline = goOnline, clean = clean, msgs = msgs, fields = fields, needUI = needUI,
		openDrive = openDrive, HAVE_UI = HAVE_UI })
end

-- Round three (tests/round3.lua): the phone
do
	local chunk = assert(loadfile(dir .. "/round3.lua"))
	chunk({
		H = H, S = S, test = test, pending = pending, take = take, clickGo = clickGo, netOnly = netOnly, goOffline = goOffline, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider,
		settle = settle, goOnline = goOnline, clean = clean, needUI = needUI, openConfirm = openConfirm,
		secureShown = secureShown, TESTCHAR = TESTCHAR,
	})
end

-- Round four (tests/round4.lua): Wuber 2.0, Ritual Rides moved into Wuber (SPEC3.md)
do
	local chunk = assert(loadfile(dir .. "/round4.lua"))
	chunk({
		H = H, S = S, test = test, pending = pending, take = take, clickGo = clickGo, netOnly = netOnly, goOffline = goOffline, eq = eq, ok = ok, count = count, list = list,
		newWorld = newWorld, driver = driver, rider = rider, settle = settle, goOnline = goOnline, clean = clean, msgs = msgs,
		fields = fields, needUI = needUI, openConfirm = openConfirm, requestVia = requestVia, openDrive = openDrive,
		rideState = rideState, whispersTo = whispersTo, readFile = readFile, secureShown = secureShown, rrTeam = rrTeam,
		assertLocked = assertLocked, HAVE_UI = HAVE_UI, HAVE_RR = HAVE_RR, ANITA = ANITA, TESTCHAR = TESTCHAR, BOB = BOB, ANA = ANA,
		BEA = BEA, CAL = CAL, dir = dir,
	})
end

-- Pending tests that round6 keeps out of round4.lua (tests/round4_pending.lua)
do
	local chunk = assert(loadfile(dir .. "/round4_pending.lua"))
	chunk({ H = H, test = test, pending = pending, eq = eq, ok = ok, newWorld = newWorld, clean = clean, ANITA = ANITA })
end

-- Round five (SPEC4.md, Wuber 2.1: any class runs it, raid summons, stations): one file per
-- agent (engine A, action B, UI C), each loaded with the same helpers as round four
for _, part in ipairs({ "round5_engine", "round5_action", "round5_ui" }) do
	local chunk = assert(loadfile(dir .. "/" .. part .. ".lua"))
	chunk({
		H = H, S = S, test = test, pending = pending, take = take, clickGo = clickGo, netOnly = netOnly, goOffline = goOffline, eq = eq, ok = ok, count = count, list = list,
		newWorld = newWorld, driver = driver, rider = rider, settle = settle, goOnline = goOnline, clean = clean, msgs = msgs,
		fields = fields, needUI = needUI, openConfirm = openConfirm, requestVia = requestVia, openDrive = openDrive,
		rideState = rideState, whispersTo = whispersTo, readFile = readFile, secureShown = secureShown,
		HAVE_UI = HAVE_UI, ANITA = ANITA, TESTCHAR = TESTCHAR, BOB = BOB, ANA = ANA, BEA = BEA, CAL = CAL, dir = dir,
	})
end

-- Round six (SPEC5.md, Wuber 2.2: the an outside review fixes, flight-cost savings): one file per
-- agent (engine A, action B, UI C), loaded with the same helpers as round five
for _, part in ipairs({ "round6_engine", "round6_action", "round6_ui", "round6_review", "round6_flights" }) do
	local chunk = assert(loadfile(dir .. "/" .. part .. ".lua"))
	chunk({
		H = H, S = S, test = test, pending = pending, take = take, clickGo = clickGo, netOnly = netOnly, goOffline = goOffline, eq = eq, ok = ok, count = count, list = list,
		newWorld = newWorld, driver = driver, rider = rider, settle = settle, goOnline = goOnline, clean = clean, msgs = msgs,
		fields = fields, needUI = needUI, openConfirm = openConfirm, requestVia = requestVia, openDrive = openDrive,
		rideState = rideState, whispersTo = whispersTo, readFile = readFile, secureShown = secureShown,
		HAVE_UI = HAVE_UI, ANITA = ANITA, TESTCHAR = TESTCHAR, BOB = BOB, ANA = ANA, BEA = BEA, CAL = CAL, dir = dir,
	})
end

-- Round seven (the author's picked mockups): the rider screens (round7_ui) and the driver screens
-- (round7_driver), each loaded when it is there, with the same helpers as round six
for _, part in ipairs({ "round7_ui", "round7_driver" }) do
	local chunk = loadfile(dir .. "/" .. part .. ".lua")
	if chunk then
		chunk({
			H = H, S = S, test = test, pending = pending, take = take, clickGo = clickGo, netOnly = netOnly, goOffline = goOffline, eq = eq, ok = ok, count = count, list = list,
			newWorld = newWorld, driver = driver, rider = rider, settle = settle, goOnline = goOnline, clean = clean, msgs = msgs,
			fields = fields, needUI = needUI, openConfirm = openConfirm, requestVia = requestVia, openDrive = openDrive,
			rideState = rideState, whispersTo = whispersTo, readFile = readFile, secureShown = secureShown,
			HAVE_UI = HAVE_UI, ANITA = ANITA, TESTCHAR = TESTCHAR, BOB = BOB, ANA = ANA, BEA = BEA, CAL = CAL, dir = dir,
		})
	end
end

-- Per-module tests (REFACTOR-MAP 4.2): tests/<area>/<module>_test.lua, each given the same
-- helpers. Step 0 has the registry's; the restructure adds one per module. Round 8 (SPEC7
-- section 1) adds one per new module, in TOC order; each starts with T.contract
-- (tests/lib/contract.lua: registered, deps = header Uses, public names and their types).
local contract = dofile(dir .. "/lib/contract.lua")({ newWorld = newWorld, rider = rider, eq = eq, ok = ok, list = list,
	readFile = readFile, dir = dir })
for _, part in ipairs({ "core/registry_test", "core/base_test",
	"core/flightpaths_test", "core/flighttimes_test", "core/wrapped_test",
	"net/portal_test", "net/raincheck_test", "net/bounty_test", "net/update_test",
	"round8_e",
	"ui/rider/worldmap_test", "ui/rider/booking_test", "ui/fold_test", "ui/share_test", "ui/rider/wrapped_test", "ui/rider/trips_test", "ui/bird_test", "ui/commands_test",
	"ui/bug_test", "ui/window_test", "ui/alpha_test",
	"ui/settings/find_test", "ui/settings/pages_test", "ui/settings/panel_test", "ui/settings/rows_test", "ui/phone_test", "ui/moments_test", "ui/driver/messages_test",
	"drive/danger_test", "drive/plan_test", "drive/kitchen_test", "drive/cut_test", "drive/raincheck_test", "drive/book_test", "drive/raid_test", "drive/queue_test",
	"ui/driver/demand_test", "ui/driver/customers_test", "ui/driver/draw_test", "ui/driver/build_test", "ui/driver/rows_test", "ui/driver/sheets_test", "ui/accessibility_esc_test", "ui/accessibility_enter_test", "ui/driver/raid_test", "ui/driver/mini_test", "ui/driver/earnings_test", "fx/gold_test", "fx/emblem_test", "fx/badge_test",
	"theme/tokens_test", "theme/widgets_test", "theme/noglow_test", "theme/segmented_test", "harness_draw", "theme/forms_test", "ui/lists_test", "drive/button_test",
	"drive/button_seen_test", "drive/blocked_toast_test", "ui/chatclear_test", "ui/crewoffer_clear_test", "run1_h_removal",
	"upgrade/upgrade_saved_vars", -- F2: saved data of older versions upgrades cleanly
	"r24_d_hold", -- BRIEF24 F1 (group D): the alpha hold covers a texture's SetAlpha
	"r24_e_proof", -- BRIEF24 F2 (group E): SetAlpha held during A.SlideIn / A.ZoomIn
	"round8_d",
	"round9_d",
	"round8_f",
	"round8_review_adv" }) do
	local chunk = assert(loadfile(dir .. "/" .. part .. ".lua"))
	chunk({ contract = contract,
		H = H, S = S, test = test, pending = pending, take = take, clickGo = clickGo, netOnly = netOnly, goOffline = goOffline, eq = eq, ok = ok, count = count, list = list,
		newWorld = newWorld, driver = driver, rider = rider, settle = settle, goOnline = goOnline, clean = clean, msgs = msgs,
		fields = fields, needUI = needUI, openConfirm = openConfirm, requestVia = requestVia, openDrive = openDrive,
		rideState = rideState, whispersTo = whispersTo, readFile = readFile, secureShown = secureShown,
		HAVE_UI = HAVE_UI, ANITA = ANITA, TESTCHAR = TESTCHAR, BOB = BOB, ANA = ANA, BEA = BEA, CAL = CAL, dir = dir,
	})
end

do local c = loadfile(dir .. "/round8_c.lua") if c then c({ H = H, S = S, test = test, pending = pending, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, msgs = msgs, fields = fields, TESTCHAR = TESTCHAR, ANITA = ANITA, dir = dir }) end end -- round 8, agent C
do local c = loadfile(dir .. "/round9_c.lua") if c then c({ contract = contract, H = H, S = S, test = test, pending = pending, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, msgs = msgs, fields = fields, openDrive = openDrive, TESTCHAR = TESTCHAR, ANITA = ANITA, dir = dir }) end end -- round 9, agent C (driver)
do local c = loadfile(dir .. "/round12_c.lua") if c then c({ contract = contract, H = H, S = S, test = test, pending = pending, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, msgs = msgs, fields = fields, TESTCHAR = TESTCHAR, ANITA = ANITA, dir = dir }) end end -- round 12, agent C (rider)
do local c = loadfile(dir .. "/round15_a.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, goOnline = goOnline, openDrive = openDrive, clean = clean, msgs = msgs, fields = fields, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, CAL = CAL, dir = dir }) end end -- round 15, agent A (Pioneers)
do local c = loadfile(dir .. "/r24_a_public.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, settle = settle, clean = clean, BOB = BOB, dir = dir }) end end -- round 24, group A (public chat switch)
do local c = loadfile(dir .. "/r25_e_searoute.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, dir = dir }) end end -- round 25, M2 (sea route arrow)
do local c = loadfile(dir .. "/r24_b_bird.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 24, B1 (bird card layout)
do local c = loadfile(dir .. "/r25_f_bird.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 25, B1 (bird card message)
do local c = loadfile(dir .. "/r25_f2_bird.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 25, F2 (bird message length)
do local c = loadfile(dir .. "/fixbird_wording.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- FIX-BIRD (bird card full wording)
do local c = loadfile(dir .. "/r26_f_bird_tb.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 26, F (bird card, Thunder Bluff)
do local c = loadfile(dir .. "/r26b_a_bird_stay.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 26b, A (bird card stays up)
do local c = loadfile(dir .. "/r26b_e_bird_wait.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 26b, E (bird card takes off W.SUMMON_SECS)
do local c = loadfile(dir .. "/run1_m_recfake.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- run 1, m (the fake matches the recording)
do local c = loadfile(dir .. "/r26b_c_worldgap.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 26b, C (World view: no gap between the continents)
do local c = loadfile(dir .. "/r26b_b_summon_secs.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 26b, B (summon seconds)
do local c = loadfile(dir .. "/r25_c_tiptexts.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 25, T3 (tip texts)
do local c = loadfile(dir .. "/r25_d_worldmap.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 25, M1 (a clearer world map)
do local c = loadfile(dir .. "/r25_d2_worldmap.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 25, D2 (world map: crop folds you in, tags keep clear)
do local c = loadfile(dir .. "/r26_d_worldmap_fit.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 26, D (world view: whole land, one scale)
do local c = loadfile(dir .. "/run1_f_taxishow.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- run 1, group f (flight map OnShow without TAXIMAP_OPENED)
do local c = loadfile(dir .. "/run1_i_redrop.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- run 1, group i (dropped rider asks again)
do local c = loadfile(dir .. "/run1w2_i_nilkey.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- run 1 wave 2, group i (nil key)
do local c = loadfile(dir .. "/r25_i_folded.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 25, I (folded Check my game)
do local c = loadfile(dir .. "/r25_a_tips.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 25, T1 (login tips card)
do local c = loadfile(dir .. "/r25_a2_tips.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 25, T1 follow-up (tip card placement)
do local c = loadfile(dir .. "/run1_d_wide_settings.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, goOnline = goOnline, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- in-game run 1, d (wide Settings)
do local c = loadfile(dir .. "/run1_o_polish.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, openDrive = openDrive, dir = dir }) end end -- run 1, group o (Lab tour polish)
do local c = loadfile(dir .. "/r26_c_seaword.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 26, item 4 (sea crossing word)
do local c = loadfile(dir .. "/r26_a_tips.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 26, A (tip card: reload, any tab, Show me, ShowAgain)
do local c = loadfile(dir .. "/run1_a_pages.lua") if c then c({ H = H, test = test, eq = eq, ok = ok, newWorld = newWorld, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA }) end end -- in-game run 1, group a (Settings over a leftover page, the Options button, the chevron)
do local c = loadfile(dir .. "/r26_i_helptip2.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 26, I (Help tip button end to end)
do local c = loadfile(dir .. "/r26_j_tips_fresh.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, dir = dir }) end end -- round 26, J (tip card: the move to Home happens once)
do local c = loadfile(dir .. "/run1_b_tipstrata.lua") if c then c({ H = H, S = S, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, rider = rider, settle = settle, clean = clean, TESTCHAR = TESTCHAR, dir = dir }) end end -- in-game run 1, b (tip card strata under Settings)
do local c = loadfile(dir .. "/round13_c.lua") if c then c({ contract = contract, H = H, S = S, test = test, pending = pending, eq = eq, ok = ok, list = list, newWorld = newWorld, driver = driver, rider = rider, settle = settle, openDrive = openDrive, clean = clean, msgs = msgs, fields = fields, readFile = readFile, TESTCHAR = TESTCHAR, ANITA = ANITA, dir = dir }) end end -- round 13, agent C (rider and map)
do local c = loadfile(dir .. "/preview_text.lua") if c then c({ H = H, test = test, eq = eq, ok = ok, dir = dir }) end end -- round 14: the screen renderer's text rules
-- The harness's round-8 game fakes (tests/lib/fakes8.lua): tests/fakes8.lua
do
	local chunk = assert(loadfile(dir .. "/fakes8.lua"))
	chunk({ H = H, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, rider = rider, settle = settle, clean = clean })
end

-- Round 15 (agent E): the forbidden list, the taint.log reader and the release checklist (tests/tools/)
for _, part in ipairs({ "tools/forbidden_test", "tools/taint_test", "tools/known_bugs_check_test", "tools/checklist_test", "tools/shard_test", "tools/known_test", "tools/sweep_known_test", "tools/sweep_own_repro_test", "tools/transcript_test", "layout/engine_test", "r24_c_layout", "r25_b_tipsettings", "r25_g_layout", "r26_b_helptip", "r26_e_layout_world", "r13_d4c_scenes", "j2935_a_pay_trade" }) do
	local chunk = loadfile(dir .. "/" .. part .. ".lua")
	if chunk then
		chunk({ H = H, test = test, runOne = runOne, eq = eq, ok = ok, list = list, newWorld = newWorld, rider = rider,
			clean = clean, readFile = readFile, CHECK = CHECK, dir = dir })
	end
end

-- Wuber Lab (the developer-only test mode, never shipped): tests/lab.lua, if it is there
do
	local chunk = loadfile(dir .. "/lab.lua")
	if chunk then
		chunk({ H = H, test = test, pending = pending, take = take, clickGo = clickGo, netOnly = netOnly, goOffline = goOffline, eq = eq, ok = ok, list = list, newWorld = newWorld, settle = settle, clean = clean,
			rideState = rideState, requestVia = requestVia, openDrive = openDrive, HAVE_UI = HAVE_UI, HAVE_RR = HAVE_RR })
	end
end

-- Wuber Lab's Pioneer emblem check (developer only, never shipped): tests/lab_emblem.lua (BRIEF15 agent B)
do
	local chunk = loadfile(dir .. "/lab_emblem.lua")
	if chunk then chunk({ H = H, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, settle = settle, clean = clean, HAVE_UI = HAVE_UI }) end
end

-- Wuber Lab's photo tour and Snap (developer only, never shipped): tests/lab_photo.lua, if it is there
do
	local chunk = loadfile(dir .. "/lab_photo.lua")
	if chunk then
		chunk({ H = H, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, settle = settle, clean = clean, HAVE_UI = HAVE_UI })
	end
end

-- Wuber Lab's passive play (developer only, never shipped): tests/lab_passive.lua, if it is there
do
	local chunk = loadfile(dir .. "/lab_passive.lua")
	if chunk then
		chunk({ H = H, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, settle = settle, clean = clean, HAVE_UI = HAVE_UI })
	end
end

-- Wuber Lab's Auto check passes "Back on every page" and "Click every safe local button": tests/lab_buttons.lua, if it is there
do
	local chunk = loadfile(dir .. "/lab_buttons.lua")
	if chunk then
		chunk({ H = H, test = test, eq = eq, ok = ok, list = list, newWorld = newWorld, settle = settle, clean = clean, HAVE_UI = HAVE_UI })
	end
end

-- The flight recorder (tools/rec; its in-game addon is developer only, never shipped): every
-- tests/rec/*_test.lua in name order, so a new test file there needs no line here
do
	local T = { H = H, S = S, test = test, testOutside = testOutside, pending = pending, runOne = runOne, eq = eq, ok = ok, count = count, list = list,
		newWorld = newWorld, driver = driver, rider = rider, settle = settle, goOnline = goOnline, clean = clean, msgs = msgs,
		fields = fields, openDrive = openDrive, openConfirm = openConfirm, requestVia = requestVia, rideState = rideState,
		readFile = readFile, CHECK = CHECK, HAVE_UI = HAVE_UI, HAVE_RR = HAVE_RR, ANITA = ANITA, TESTCHAR = TESTCHAR, BOB = BOB, ANA = ANA,
		BEA = BEA, CAL = CAL, dir = dir }
	for _, path in ipairs(H.listFiles(dir .. "/rec", "lua")) do
		if path:match("_test%.lua$") then assert(loadfile(path))(T) end
	end
end

-- Round 27 onwards (the 2.3.4 fix rounds): every tests/r27/*_test.lua in name order, so a group's new test
-- file needs no line here (one file per group, no merge clashes). T is the table of helpers a proof test gets
-- (the old tools/google-review/proof.lua, now in tools/_retired-google/), so a proof moves in unchanged.
do
	local T = { H = H, S = S, test = test, pending = pending, runOne = runOne, eq = eq, ok = ok, count = count, list = list,
		newWorld = newWorld, driver = driver, rider = rider, settle = settle, clean = clean, netOnly = netOnly,
		goOnline = goOnline, goOffline = goOffline, msgs = msgs, fields = fields, needUI = needUI, secureShown = secureShown,
		openConfirm = openConfirm, clickRequest = clickRequest, requestVia = requestVia, openDrive = openDrive, clickGo = clickGo,
		driverAccept = driverAccept, take = take, rideState = rideState, whispersTo = whispersTo, readFile = readFile,
		CHECK = CHECK, HAVE_UI = HAVE_UI, HAVE_RR = HAVE_RR, dir = dir, contract = contract,
		TESTCHAR = TESTCHAR, ANITA = ANITA, BOB = BOB, ANA = ANA, BEA = BEA, CAL = CAL }
	-- Every folder of tests/ is found here, sorted by name, so a new test folder needs no line (the old folder
	-- list was the one line every pull request edited: the biggest merge-conflict hotspot). Folders whose files
	-- are loaded by name above, or that hold helpers and results, not tests, are skipped: NOT_AUTO is closed
	-- (a new folder is never in it).
	local NOT_AUTO = { core = true, drive = true, fx = true, fixtures = true, layout = true, lib = true, net = true, out = true,
		preview = true, rec = true, round1 = true, theme = true, tools = true, ui = true }
	local folders = {}
	-- (H.listFiles with no extension lists every entry of tests/, files and folders, sorted; a folder has no "." in its name)
	for _, path in ipairs(H.listFiles(dir)) do
		local name = path:match("([^/\\]+)$")
		if not NOT_AUTO[name] and not name:find("^[._]") and not name:find("%.") then folders[#folders + 1] = name end
	end
	H.autoFolders, H.notAutoFolders = folders, NOT_AUTO -- (tests/autodiscover/folders_test.lua checks them)
	for _, folder in ipairs(folders) do
		for _, path in ipairs(H.listFiles(dir .. "/" .. folder, "lua")) do
			if path:match("_test%.lua$") then assert(loadfile(path))(T) end
		end
	end
end

---------------------------------------------------------------------------
-- Report
---------------------------------------------------------------------------

-- a split run: a shard closes its files (its part is compared by the join, not here); the
-- join takes the shards' results, writes the transcript in test order and goes on as a serial run
if SH and not SH.joining then
	SH.finish(passed, failed)
	print(("\nshard %d/%d: %d passed, %d failed (results %s)"):format(SH.k, SH.n, passed, failed, SH.resultsPath))
	if os.getenv("WUBER_RULE_LOG") and H.ruleDump then H.ruleDump(os.getenv("WUBER_RULE_LOG")) end -- (evidence ledger: tools/evidence-report.lua)
	os.exit(failed == 0 and 0 or 1)
elseif SH then
	local j = SH.join(SH, dir, H, TRANSCRIPT)
	passed, failed = j.passed, j.failed
	for _, name in ipairs(j.failures) do failures[#failures + 1] = name end
	local cpu = {}
	for k, s in ipairs(j.cpu) do cpu[k] = ("%d: %.0f s"):format(k, s) end
	print("\njoined " .. SH.n .. " shards (test CPU time " .. table.concat(cpu, ", ") .. ")")
	for _, p in ipairs(j.problems) do print("JOIN PROBLEM: " .. p) end
	if #j.problems > 0 then
		failed = failed + 1
		failures[#failures + 1] = "the shards' results do not join (" .. #j.problems .. " problems)"
	end
end

-- the transcript: written; compared with the baseline, or made the baseline
if TR then
	TR.finish()
	print("\ntranscript: " .. TRANSCRIPT)
	if flags["update-transcript"] then
		if failed > 0 or filter or ONLY or NAMES then
			print("transcript NOT made the baseline: " .. ((filter or ONLY or NAMES) and "a filtered run" or "tests failed"))
			failed = failed + 1
		else
			local src = assert(io.open(TRANSCRIPT, "rb"))
			local text = src:read("*a")
			src:close()
			local dst = assert(io.open(BASELINE, "wb"))
			dst:write(text)
			dst:close()
			print("transcript is the new baseline: " .. BASELINE)
		end
	end
	local noBase = false
	if flags["compare-transcript"] then
		local bf = io.open(BASELINE, "rb")
		if bf then bf:close() else noBase = true end
	end
	if noBase then
		-- the baseline (about 110 MB) is not stored in the repository: a missing file is not a behaviour change
		print("transcript: NO BASELINE at " .. BASELINE .. " (nothing was compared). To make one: run the whole suite on a fresh clone with --update-transcript"
			.. " (bash tools/fresh-suite.sh), or point WUBER_BASELINE at a baseline file.")
	elseif flags["compare-transcript"] then
		local diffs = TR.compare(TRANSCRIPT, BASELINE, (filter or ONLY or NAMES) ~= nil)
		if diffs.added and #diffs.added > 0 then
			print("transcript: " .. #diffs.added .. " test(s) not in the baseline (new; --update-transcript adds them): "
				.. table.concat(diffs.added, "; "))
		end
		local nrec = 0
		local tf = io.open(TRANSCRIPT, "rb")
		if tf then for line in tf:lines() do if line:find("^=== ") then nrec = nrec + 1 end end tf:close() end
		local compared = nrec - (diffs.added and #diffs.added or 0)
		if #diffs == 0 and compared <= 0 then
			print("transcript: compared 0 records (nothing to compare)")
		elseif #diffs == 0 then
			print("transcript: identical to the baseline" .. ((filter or ONLY or NAMES) and " (the tests run)" or ""))
		else
			print("transcript: DIFFERS from the baseline (" .. (diffs.total or #diffs) .. "):")
			for _, d in ipairs(diffs) do print("  " .. d) end
			failed = failed + 1
			failures[#failures + 1] = "behaviour transcript differs from " .. BASELINE
		end
	end
end

print(("\n%d passed, %d failed, %d pending%s"):format(passed, failed, #pendings, skipped > 0 and (", " .. skipped .. " skipped") or ""))
if #failures > 0 then print("failed: " .. table.concat(failures, "; ")) end

local function sorted(t)
	local out = {}
	for k, v in pairs(t) do out[#out + 1] = { k, v } end
	table.sort(out, function(a, b) return a[1] < b[1] end)
	return out
end

local unproven = {}
for _, kv in ipairs(sorted(H.used.method)) do
	if not H.proven[kv[1]] then unproven[#unproven + 1] = "  :" .. kv[1] .. "  (" .. kv[2] .. ")" end
end
for _, kv in ipairs(sorted(H.used.api)) do
	local leaf = kv[1]:match("([%w_]+)$")
	if not (H.proven[kv[1]] or (H.proven[leaf] and (not kv[1]:find("%.") or H.proven[kv[1]:match("^([%w_]+)")]))) then
		unproven[#unproven + 1] = "  " .. kv[1] .. "  (" .. kv[2] .. ")"
	end
end
if os.getenv("WUBER_REPORT") or not (filter or ONLY or NAMES) then
	print("\nWidget methods and APIs used that Ritual Rides 1.3.0, WuberTest and SPEC's Client facts never used (unproven in game):")
	for _, l in ipairs(unproven) do print(l) end
	print("\nWidget methods looked up that the harness lacks (nil in the fake):")
	for _, kv in ipairs(sorted(H.unknown)) do print("  " .. kv[1] .. "  (" .. tostring(kv[2]) .. ")") end
	print("\nGlobals read that the harness doesn't define:")
	for _, kv in ipairs(sorted(H.missingGlobals)) do
		if not SAVED[kv[1]] then print("  " .. kv[1] .. "  (" .. tostring(kv[2]) .. ")") end
	end
	print("\nMethods whose signature/version differs between clients:")
	for _, kv in ipairs(sorted(H.uncertain)) do print("  " .. kv[1] .. "  " .. kv[2]) end
end

if os.getenv("WUBER_RULE_LOG") and H.ruleDump then H.ruleDump(os.getenv("WUBER_RULE_LOG")) end -- (evidence ledger: tools/evidence-report.lua)
os.exit(failed == 0 and 0 or 1)
