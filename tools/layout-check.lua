-- tools/layout-check.lua: the layout checker (BRIEF21 S11). Deterministic, no AI, no pictures.
-- Runs Wuber Lab's photo tour in the fake game (the same screens and demo data as the in-game tour, through
-- tools/preview's real font metrics) at several game windows and Wuber sizes, and at every shot walks the
-- drawn Wuber regions (shown, alpha > 0, on its window) and fails on:
--   cut       a FontString cut short ("..." / IsTruncated), or laid out before its font loaded (drawn cut)
--   overlap   two texts on top of each other
--   under     a text partly under an opaque pill, cue, bar or card drawn above it (a row half under the tab bar)
--   boxes     a pill, card or bar half over another (neither inside the other)
--   clipped   a text partly cut by its scroll view
--   outside   a text outside its window; spill: a text running out of the card or pill it sits in
--   offscreen a text, control or box off the screen;  tooltip: Wuber's tooltip off the screen
--   type      a text drawn at a size that is not one of T.SCALE's seven, or in a font file that is not one of T.FONTS
--             (tests/layout/type.lua; design round 3)
--   emptycue  a "Scroll for ..." / "more below" cue under an empty view (the rows it points at never drew)
--   words     the word rule (tests/layout/words.lua): a picture showing more words than its kind's budget (Card 12,
--             Action 40, Working 70 folded / 120 unfolded, Reading 150, floating big button 40); one hit a shot
--   chrome    (design 2) page content in the place of the header's buttons (the fold button, the cog, the x) or of
--             the tab bar, whatever is drawn on top (a box that holds a whole button is what it lies on: fine)
-- Intended overlaps are allowed in tests/layout/allow.lua, each with a reason.
--
--   lua tools/layout-check.lua                    every shot, 3 windows x 3 sizes (9 runs, 4 at a time)
--   lua tools/layout-check.lua --quick            2 runs: 2662x2089 at 1 and 1920x1080 at 2.2
--   lua tools/layout-check.lua --screen trips     only shots whose id starts with "trips" (an id, a prefix,
--                                                 or several: --screen trips,earnings; side:driver = a side)
--   lua tools/layout-check.lua --files Wuber/UI/Rider/Trips.lua ...   the shots those files draw (all if unsure)
--   lua tools/layout-check.lua --stretch 15       the same sweep with every text 15% wider (30: German runs about 30% longer):
--                                                 the problems listed by screen, a count per screen, a total (tools only; the
--                                                 normal run is unchanged without the flag)
--   lua tools/layout-check.lua --text-rule flat   the first draft's flat "+6% at 12 px and under" instead of the measured ratios (a proof only: it over-flags)
--   lua tools/layout-check.lua --probe tests/fixtures/probe/<fixture>.lua   strings the probe measured in their box are cut or not as the game answered
--                                                 (tests/lib/probe_learn.lua); the others stay on the metric and the run says "N of M current strings unmeasured"
--   lua tools/layout-check.lua --comfort          the small and large end of the window size slider: 0.65, 0.8 and 1.15 on two game windows (6 runs)
--   lua tools/layout-check.lua --selftest         the checker's own rules on small made-up screens (seconds)
--   lua tools/layout-check.lua --regress          the regression cases (tests/layout/regress.lua): old code from
--                                                 git must fail with its known problem, today's must pass.
--                                                 The old trees stay cached in %TEMP%/wuber-layout-old (one per
--                                                 commit); --regress --clean deletes that folder (and runs nothing)
--   Group C (job 211): two more checks, ON by default in the full run:
--   covered   (tests/layout/topmost.lua) a drawn, mouse-enabled Wuber button whose centre has another mouse-taking visible frame drawn
--             above it (higher strata or level; any addon or the game): a click would go there. Reuses tests/lib/topmost.lua.
--   daylight  (tests/layout/daylight.lua) one extra run, 1920x1080 at 1, with the fake Daylight UI pack (tests/lib/fakes_daylight.lua)
--             over the flight map and the in-flight card; its shots are "daylight/..." and its problems are counted as daylight=
--   --no-topmost, --no-daylight, --daylight-only (just that run)
-- The last line of a full run: "GAUNTLET layout result=<pass|fail|error> shots= problems= known= covered= daylight= routes="
-- --words prints a line for EVERY shot, over or not: "WORDS shot N budget M kind" (N = the most words at any size)
-- --routes-only / --no-routes: only the route walks (tests/layout/routes.lua: real moves between pages, one page shown, head visible,
-- back chevron uncovered, the normal kinds after every step; problems "route |"), or none; on in a full run (not with --screen/--files)
-- More: --config 1920x1080@1.5 (one run, repeatable; 1920x1080@1.15,ui0.71 = Wuber size 1.15 at the game's UI scale 0.71), --jobs N (default 4 at once), --wuber <dir> (another copy of the addon),
-- --lab <dir>, --list (the shot ids), --known (also print the known problems), --all (also the allowed ones), --verbose.
-- Known problems (tests/layout/allow.lua, known = ...) are real but reported and not fixed yet: they never fail.
-- Exit: 0 clean, 1 layout failures (one line each: screen | scale | window | frame | problem), 2 could not run:
-- a Lua error in the fake game, the checker threw, the tour did not finish or skipped a wanted screen (other than
-- "doesn't unfold here"), no shot at all. Those are always printed (stderr); the last line is "result <exit>".
local SCRIPT = (arg and arg[0] or "tools/layout-check.lua"):gsub("\\", "/")
-- the checkout: the folder above tools/ (run from the root, from tools/ itself, or by a full path)
local root
do
	local dir = SCRIPT:match("^(.*)/[^/]*$") or "."
	if dir == "tools" then root = "."
	elseif dir:match("/tools$") then root = dir:sub(1, -7)
	else root = dir .. "/.." end
end
local LUA = arg and arg[-1] or "lua5.1"
local args = {}
for i = 1, #arg do args[i] = arg[i] end
package.path = root .. "/tests/?.lua;" .. package.path

local function die(msg)
	io.stderr:write("layout-check: " .. tostring(msg) .. "\n")
	io.stderr:write("layout-check: result 2 (could not run)\n")
	os.exit(2)
end

-- the whole script runs under xpcall: any Lua error of the checker's own is exit 2 (could not run)
local function main()

---------------------------------------------------------------------------
-- What to run
---------------------------------------------------------------------------

-- game windows (pixels) and the game's own UI scale there (UIParent's effective scale: the author's game drew
-- 2.0 pixels per unit at 2662x2089 on 19 Nov; 1.0 = the plain case); Wuber's own sizes: the phone's window
-- size (W.db.scale, Wuber caps it at 2 and at what fits) and the big button's (DR.SetScale, up to 2.2)
local WINDOWS = { { 2662, 2089, 0.7353 }, { 1920, 1080, 1.0 }, { 3840, 2160, 1.0 } }
local SCALES = { 1, 1.5, 2.2 }
local QUICK = { "2662x2089@1", "1920x1080@2.2" }

-- which shots a Wuber file draws (a Lua pattern on the path -> shot id prefixes; side:<x> = the lab's side).
-- Unknown files (Core, Theme, Kit, Window, Fold...) map to every shot.
local FILE_SCREENS = {
	{ "UI/Rider/Home", { "home", "chat_home" } }, { "UI/Rider/HomeMap", { "home", "worldmap" } },
	{ "UI/Rider/Cards", { "home", "confirm" } }, { "UI/Rider/Booking", { "confirm" } }, { "UI/Rider/Confirm", { "confirm" } },
	{ "UI/Rider/Ride", { "portal", "tracker", "pay", "stranger", "raincheck" } },
	{ "UI/Rider/Pay", { "pay", "stranger", "raincheck" } }, { "UI/Rider/Done", { "done_", "raincheck" } },
	{ "UI/Rider/Trips", { "trips" } }, { "UI/Rider/Wrapped", { "wrapped" } }, { "UI/Rider/WorldMap", { "worldmap" } }, { "UI/Rider/SeaRoute", { "worldmap" } }, { "UI/Tips", { "tipcard" } },
	{ "UI/Map/", { "worldmap", "home" } },
	{ "UI/Driver/Earnings", { "earnings", "shift" } }, { "UI/Driver/Customers", { "customers", "note" } },
	{ "UI/Driver/Crew", { "crew" } }, { "UI/Driver/Demand", { "demand", "pvp" } },
	{ "UI/Driver/Raid", { "raid", "float_raid" } }, { "UI/Driver/Messages", { "messages" } },
	{ "UI/Driver/Mini", { "float_", "chat_float", "login_" } },
	{ "Drive/Button", { "float_", "button_", "console_", "chat_float", "login_" } },
	{ "Drive/Cast", { "float_", "button_", "chat_float" } }, { "Drive/Plan", { "float_", "button_", "console_" } },
	{ "UI/Driver/", { "side:driver", "login_" } }, { "Drive/", { "side:driver" } },
	{ "UI/Settings/", { "side:settings" } }, { "UI/Bug", { "bug_window", "settings_bug", "help_bug" } },
	{ "UI/Bird", { "bird" } }, { "UI/Coach", { "side:rider", "side:driver" } },
}

local opt = { configs = {}, files = nil, screens = nil }
do
	local i = 1
	while args[i] do
		local a = args[i]
		if a == "--quick" then opt.quick = true
		elseif a == "--screen" then opt.screens = opt.screens or {} for s in (args[i + 1] or ""):gmatch("[^,%s]+") do opt.screens[#opt.screens + 1] = s end i = i + 1
		elseif a == "--files" then
			opt.files = opt.files or {}
			while args[i + 1] and not args[i + 1]:match("^%-%-") do opt.files[#opt.files + 1] = args[i + 1] i = i + 1 end
		elseif a == "--config" then opt.configs[#opt.configs + 1] = args[i + 1] i = i + 1
		elseif a == "--comfort" then -- (#306) the small and large end of the window size slider (60% to 160%)
			for _, win in ipairs({ "1920x1080", "2662x2089" }) do
				for _, sc in ipairs({ "0.65", "0.8", "1.15" }) do opt.configs[#opt.configs + 1] = win .. "@" .. sc end
			end
		elseif a == "--stretch" then opt.stretch = tonumber(args[i + 1]) i = i + 1
			if not opt.stretch or opt.stretch <= 0 then die("--stretch N (percent wider, e.g. 15 or 30)") end
		elseif a == "--text-rule" then opt.textRule = args[i + 1] i = i + 1
			if opt.textRule ~= "flat" and opt.textRule ~= "measured" then die("--text-rule flat|measured") end
			if opt.textRule == "measured" then opt.textRule = nil end
		elseif a == "--collect-labels" then opt.labelsOut = args[i + 1] i = i + 1
		elseif a == "--probe" then opt.probe = (args[i + 1] or ""):gsub("\\", "/") i = i + 1
		elseif a == "--child" then opt.child = args[i + 1] i = i + 1
		elseif a == "--jobs" then opt.jobs = tonumber(args[i + 1]) i = i + 1
		elseif a == "--wuber" then opt.wuber = args[i + 1] i = i + 1
		elseif a == "--lab" then opt.lab = args[i + 1] i = i + 1
		elseif a == "--regress" then opt.regress = true
		elseif a == "--selftest" then opt.selftest = true
		elseif a == "--list" then opt.list = true
		elseif a == "--all" then opt.all = true
		elseif a == "--known" then opt.known = true
		elseif a == "--words" then opt.words = true
		elseif a == "--verbose" then opt.verbose = true
		elseif a == "--no-scenes" then opt.noScenes = true
		elseif a == "--no-topmost" then opt.noTopmost = true
		elseif a == "--no-daylight" then opt.noDaylight = true
		elseif a == "--daylight-only" then opt.daylightOnly = true
		elseif a == "--daylight-child" then opt.daylightChild = true
		elseif a == "--routes-only" then opt.routesOnly = true
		elseif a == "--no-routes" then opt.noRoutes = true
		elseif a == "--routes-child" then opt.routesChild = true
		elseif a == "--clean" then opt.clean = true
		elseif a == "--help" or a == "-h" then
			for line in io.lines(SCRIPT) do
				if not line:match("^%-%-") then break end
				print((line:gsub("^%-%- ?", "")))
			end
			os.exit(0)
		else die("unknown argument " .. a .. " (--help)") end
		i = i + 1
	end
end
opt.lab = (opt.lab or os.getenv("WUBER_LAB_DIR") or (root .. "/lab/WuberLab")):gsub("\\", "/")
if not io.open(root .. "/tests/harness.lua", "r") then die("can't find the checkout (no " .. root .. "/tests/harness.lua)") end

local function parseConfig(s)
	local w, h, sc, uis = tostring(s):match("^(%d+)x(%d+)@([%d.]+),?u?i?([%d.]*)$")
	if not w then die("--config WxH@scale[,uiN], e.g. 1920x1080@1.5 or 1920x1080@1.15,ui0.71 (" .. tostring(s) .. ")") end
	w, h, sc = tonumber(w), tonumber(h), tonumber(sc)
	local ui = 1.0
	for _, win in ipairs(WINDOWS) do if win[1] == w and win[2] == h then ui = win[3] end end
	if tonumber(uis) then ui = tonumber(uis) end -- (job 2885) the game's UI scale given on the command line (1920x1080@1.15,ui0.71)
	return { w = w, h = h, ui = ui, scale = sc, id = s }
end

-- the screens a list of changed files draws: a list of selectors, or nil = every shot
local function screensForFiles(files)
	local sel, any, all = {}, false, false
	for _, f in ipairs(files) do
		local p = f:gsub("\\", "/")
		local rel = p:match("Wuber/(.*)$")
		if rel and p:match("%.lua$") or (rel and (p:match("%.toc$") or p:match("%.xml$"))) then
			any = true
			local hit = false
			for _, m in ipairs(FILE_SCREENS) do
				if rel:find(m[1], 1, true) == 1 then
					for _, s in ipairs(m[2]) do sel[#sel + 1] = s end
					hit = true
					break
				end
			end
			if not hit then all = true end
		elseif rel then
			any = true -- a Media file: what draws it is not known
			all = true
		end
	end
	if not any then return false end
	if all then return nil end
	return sel
end

---------------------------------------------------------------------------
-- One run (a window and a size): the tour, then the late-font scenes
---------------------------------------------------------------------------

local function runChild(cfgText)
	local cfg = parseConfig(cfgText)
	arg = { [0] = root .. "/tests/run.lua" }
	local H = require("harness")
	if opt.wuber then H.ADDONS.Wuber = opt.wuber:gsub("\\", "/") end
	if not H.exists(opt.lab .. "/Photo.lua") then die("Wuber Lab's Photo.lua not found at " .. opt.lab .. " (WUBER_LAB_DIR)") end
	H.ADDONS.WuberLab = opt.lab
	local E = assert(loadfile(root .. "/tests/layout/engine.lua"))(H)
	-- (group C) the covered kind: E.check also lists the buttons covered at their centre
	if not opt.noTopmost then dofile(root .. "/tests/layout/topmost.lua").wrap(H, E) end
	if opt.daylightChild then return assert(loadfile(root .. "/tests/layout/daylight.lua"))(H, E, root).config(cfg, {}) end
	local Run = assert(loadfile(root .. "/tests/layout/run.lua"))(H, E, root)
	local res = Run.config(cfg, { screens = opt.screens, scenes = not opt.noScenes, verbose = opt.verbose, stretch = opt.stretch, textRule = opt.textRule, probe = opt.probe, labels = opt.labelsOut ~= nil })
	if res.probeNote then res.notes[#res.notes + 1] = res.probeNote end
	return res
end

-- the lines a child prints for its parent (tab-separated; a child's whole output at its end)
local function emit(res)
	local out = {}
	for _, h in ipairs(res.hits) do
		out[#out + 1] = table.concat({ "HIT", h.shot, h.kind, h.key, h.what, h.detail, h.allowed or "", h.known and "known" or "" }, "\t")
	end
	local function lit(v)
		if type(v) == "table" then
			local parts = {}
			for k, x in pairs(v) do parts[#parts + 1] = "[" .. lit(k) .. "]=" .. lit(x) end
			return "{" .. table.concat(parts, ",") .. "}"
		elseif type(v) == "string" then return (("%q"):format(v):gsub("\\\n", "\\n"):gsub("\t", "\\t"):gsub("\r", "\\r"))
		else return tostring(v) end
	end
	for _, row in pairs(res.labels or {}) do out[#out + 1] = "LABEL\t" .. lit(row) end
	for _, x in ipairs(res.words or {}) do out[#out + 1] = table.concat({ "WORDS", x.shot, x.n, x.budget, x.kind }, "\t") end
	for _, e in ipairs(res.errors) do out[#out + 1] = "ERR\t" .. tostring(e):gsub("[\r\n]+", " / ") end
	for _, b in ipairs(res.broken) do out[#out + 1] = "BROKEN\t" .. tostring(b):gsub("[\r\n]+", " / ") end
	for _, n in ipairs(res.notes) do out[#out + 1] = "NOTE\t" .. tostring(n):gsub("[\r\n]+", " / ") end
	out[#out + 1] = ("DONE\t%d\t%.1f"):format(res.shots, res.secs)
	io.write(table.concat(out, "\n") .. "\n")
end

if opt.routesChild then -- (job 211, D: tests/layout/routes.lua) the route walks, in this process
	local ok, res = pcall(function() return dofile(root .. "/tests/layout/routes.lua").child({ root = root, wuber = opt.wuber }) end)
	io.write((ok and res or ("RERR\t-\t" .. tostring(res):gsub("[\r\n]+", " / "))) .. "\n")
	os.exit(ok and 0 or 2)
end

if opt.child then
	local ok, res = pcall(runChild, opt.child)
	if not ok then io.write("FAIL\t" .. tostring(res):gsub("[\r\n]+", " / ") .. "\n") os.exit(2) end
	emit(res)
	os.exit(0)
end

if opt.list then
	arg = { [0] = root .. "/tests/run.lua" }
	local H = require("harness")
	H.ADDONS.WuberLab = opt.lab
	local E = assert(loadfile(root .. "/tests/layout/engine.lua"))(H)
	local Run = assert(loadfile(root .. "/tests/layout/run.lua"))(H, E, root)
	for _, s in ipairs(Run.shotList()) do print(s.id .. "\t" .. s.side .. "\t" .. s.views .. "\t" .. s.title) end
	os.exit(0)
end

-- the engine's own tests (tests/layout/engine_test.lua), without the suite's runner
if opt.selftest then
	arg = { [0] = root .. "/tests/run.lua" }
	local H = require("harness")
	local n, failed = 0, 0
	local T = { H = H, root = root, newWorld = function(o) return H.NewWorld(o) end }
	local cur
	function T.ok(v, msg) if not v then error("not ok: " .. tostring(msg), 2) end end
	function T.eq(a, b, msg) if a ~= b then error(("%s: got %s, want %s"):format(tostring(msg), tostring(a), tostring(b)), 2) end end
	function T.test(name, fn)
		n = n + 1
		local okRun, err = pcall(fn)
		if okRun then print("ok   " .. name) else failed = failed + 1 print("FAIL " .. name .. "\n     " .. tostring(err)) end
	end
	assert(loadfile(root .. "/tests/layout/engine_test.lua"))(T)
	assert(loadfile(root .. "/tests/layout/topmost_test.lua"))(T)
	print(("%d tests, %d failed"):format(n, failed))
	os.exit(failed > 0 and 1 or 0)
end

if opt.regress then
	local R = dofile(root .. "/tests/layout/regress.lua")
	os.exit(R.main({ root = root, lua = LUA, script = SCRIPT, lab = opt.lab, verbose = opt.verbose, only = opt.screens,
		jobs = opt.jobs, clean = opt.clean }))
end

---------------------------------------------------------------------------
-- The parent: a child per run, all at once; the lines merged
---------------------------------------------------------------------------

if opt.files then
	local sel = screensForFiles(opt.files)
	if sel == false then
		print("layout-check: no Wuber files among those given: nothing to check")
		os.exit(0)
	end
	if sel then opt.screens = opt.screens or {} for _, s in ipairs(sel) do opt.screens[#opt.screens + 1] = s end end
end

local configs = {}
if #opt.configs > 0 then configs = opt.configs
elseif opt.quick then configs = QUICK
else
	for _, win in ipairs(WINDOWS) do
		for _, sc in ipairs(SCALES) do configs[#configs + 1] = ("%dx%d@%s"):format(win[1], win[2], tostring(sc)) end
	end
end
for _, c in ipairs(configs) do parseConfig(c) end
-- (group C) the Daylight pass: one more run, unless a filter narrows the sweep (--screen, --files, --stretch) or it is off
local DAYLIGHT_CFG = "1920x1080@1"
if opt.daylightOnly then configs = {} end
local runDaylight = opt.daylightOnly or (not opt.noDaylight and not opt.screens and not opt.stretch)

local t0 = os.time()
local clock0 = os.clock()
local function q(s) s = tostring(s):gsub("\\", "/") if s:find("[%s\"]") then return '"' .. s .. '"' end return s end
local function childCmd(cfg)
	local isDay = cfg:sub(1, 9) == "daylight:"
	if isDay then cfg = cfg:sub(10) end
	local parts = { q(LUA), q(SCRIPT), "--child", cfg }
	if isDay then parts[#parts + 1] = "--daylight-child" end
	if opt.screens then parts[#parts + 1] = "--screen" parts[#parts + 1] = q(table.concat(opt.screens, ",")) end
	if opt.wuber then parts[#parts + 1] = "--wuber" parts[#parts + 1] = q(opt.wuber) end
	parts[#parts + 1] = "--lab" parts[#parts + 1] = q(opt.lab)
	if opt.noScenes then parts[#parts + 1] = "--no-scenes" end
	if opt.noTopmost then parts[#parts + 1] = "--no-topmost" end
	if opt.stretch then parts[#parts + 1] = "--stretch" parts[#parts + 1] = tostring(opt.stretch) end
	if opt.labelsOut then parts[#parts + 1] = "--collect-labels" parts[#parts + 1] = "1" end
	if opt.textRule then parts[#parts + 1] = "--text-rule" parts[#parts + 1] = opt.textRule end
	if opt.probe then parts[#parts + 1] = "--probe" parts[#parts + 1] = q(opt.probe) end
	return table.concat(parts, " ") .. " 2>&1"
end

-- (job 211, D) the route walks (tests/layout/routes.lua): on in a full run; --routes-only / --no-routes. routeBad = their problems.
local routeBad, routeCouldNot = 0, false
if not opt.noRoutes and not opt.daylightOnly and not opt.screens and not opt.files then
	local Routes = dofile(root .. "/tests/layout/routes.lua")
	local rc = Routes.main({ root = root, lua = LUA, script = SCRIPT, wuber = opt.wuber, lab = opt.lab })
	routeBad = Routes.bad
	if opt.routesOnly then
		io.stderr:write(("layout-check: result %d (%s)\n"):format(rc, rc == 0 and "clean" or rc == 1 and "layout failures" or "could not run"))
		os.exit(rc)
	end
	routeCouldNot = rc == 2
end

local results = {}
-- (the PC is shared: 4 runs at once unless --jobs says more)
local pending = {}
for i, c in ipairs(configs) do pending[i] = c end
if runDaylight then pending[#pending + 1] = "daylight:" .. DAYLIGHT_CFG end
local jobs = opt.jobs or math.min(#pending, 4)
local running = {}
local function startNext()
	local c = table.remove(pending, 1)
	if not c then return false end
	local cmd = childCmd(c)
	-- cmd.exe drops the first and last quote of a command line that starts with one: wrap it once more
	if package.config:sub(1, 1) == "\\" and cmd:find('"', 1, true) then cmd = '"' .. cmd .. '"' end
	local p = io.popen(cmd, "r")
	if not p then die("could not start a run for " .. c) end
	running[#running + 1] = { cfg = c, p = p }
	return true
end
for _ = 1, jobs do if not startNext() then break end end
while #running > 0 do
	local r = table.remove(running, 1)
	local text = r.p:read("*a") or ""
	r.p:close()
	results[#results + 1] = { cfg = r.cfg, text = text }
	startNext()
end

-- merge: one line per screen, frame and problem; its sizes and windows listed
local merged, order = {}, {}
local labelRows = {} -- (job 2893) --collect-labels: every string a run drew with a box
local errors, broken, notes, failed, shots = {}, {}, {}, {}, 0
local allowedN, knownN, knownSeen = 0, 0, {}
local wordsOf, wordsOrder = {}, {}
for _, r in ipairs(results) do
	local cfg = parseConfig((r.cfg:gsub("^daylight:", "")))
	local done, gone = false, false
	for line in r.text:gmatch("[^\r\n]+") do
		local f = {}
		for x in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = x end
		if f[1] == "HIT" then
			local shot, kind, key, what, detail, allowed, known = f[2], f[3], f[4], f[5], f[6], f[7], f[8] == "known"
			-- (a row or cell of a list is one problem: rows.3 and rows.4 merge)
			local kk = key:gsub("%.%d+", ".#")
			if known then
				if not knownSeen[kk] then knownSeen[kk] = true knownN = knownN + 1 end
			elseif allowed ~= "" then
				allowedN = allowedN + 1
			end
			if allowed == "" or opt.all or (known and opt.known) then
				local k = shot .. "|" .. kk .. "|" .. kind .. "|" .. (known and "known" or allowed)
				local m = merged[k]
				if not m then
					m = { shot = shot, kind = kind, what = what, detail = detail, scales = {}, wins = {}, allowed = allowed, known = known, n = 0 }
					merged[k] = m
					order[#order + 1] = k
				end
				m.n = m.n + 1
				m.scales[tostring(cfg.scale)] = true
				m.wins[cfg.w .. "x" .. cfg.h] = true
			end
		elseif f[1] == "WORDS" then
			local m = wordsOf[f[2]]
			if not m then m = { shot = f[2], n = 0, budget = tonumber(f[4]) or 0, kind = f[5] } wordsOf[f[2]] = m wordsOrder[#wordsOrder + 1] = f[2] end
			m.n = math.max(m.n, tonumber(f[3]) or 0)
		elseif f[1] == "LABEL" then
			local chunk = (loadstring or load)("return " .. tostring(f[2]))
			local row = chunk and chunk()
			if type(row) == "table" then labelRows[#labelRows + 1] = row end
		elseif f[1] == "ERR" then errors[#errors + 1] = r.cfg .. ": " .. tostring(f[2])
		elseif f[1] == "BROKEN" then broken[#broken + 1] = r.cfg .. ": " .. tostring(f[2])
		elseif f[1] == "NOTE" then notes[f[2]] = true
		elseif f[1] == "DONE" then done = true shots = shots + (tonumber(f[2]) or 0)
		elseif f[1] == "FAIL" then failed[#failed + 1] = r.cfg .. ": " .. tostring(f[2]) gone = true
		end
	end
	if not done and not gone then failed[#failed + 1] = r.cfg .. ": the run ended early: " .. r.text:sub(-600) end
end

local function keys(t)
	local out = {}
	for k in pairs(t) do out[#out + 1] = k end
	table.sort(out, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) or (tonumber(a) == tonumber(b) and a < b) end)
	return table.concat(out, ",")
end
-- (job 2893) --collect-labels <file>: the distinct strings (text, font, size, box, maxLines, wrap) with the effective scales they were drawn at;
-- tools/rec/probe-labels.lua turns the file into the probe's label list
if opt.labelsOut then
	local PL = dofile(root .. "/tests/lib/probe_learn.lua")
	local byKey, keyList = {}, {}
	for _, row in ipairs(labelRows) do
		local k = PL.labelKey(row.font, row.size, row.text, row.box, row.maxLines, row.wrap)
		local m = byKey[k]
		if not m then m = { text = row.text, font = row.font, size = row.size, box = row.box, maxLines = row.maxLines, wrap = row.wrap, effs = {} } byKey[k] = m keyList[#keyList + 1] = k end
		for e in pairs(row.effs or {}) do m.effs[e] = true end
	end
	table.sort(keyList)
	local fh = assert(io.open(opt.labelsOut, "wb"))
	fh:write("-- layout-check --collect-labels: strings drawn with a box (generated)\nreturn {\n")
	for _, k in ipairs(keyList) do
		local m = byKey[k]
		local effs = {}
		for e in pairs(m.effs) do effs[#effs + 1] = e end
		table.sort(effs)
		fh:write(("\t{ text = %q, font = %q, size = %s, box = %s, maxLines = %s, wrap = %s, effs = { %s } },\n"):format(m.text, m.font, tostring(m.size), tostring(m.box),
			tostring(m.maxLines or 0), tostring(m.wrap ~= false), table.concat(effs, ", ")))
	end
	fh:write("}\n")
	fh:close()
	print(("collected %d strings into %s"):format(#keyList, opt.labelsOut))
end
local bad = routeBad
local printed = {}
if opt.stretch then
	-- --stretch: the problems grouped by screen (shot id), a count each, a total
	local byShot, shotOrder = {}, {}
	for _, k in ipairs(order) do
		local m = merged[k]
		if m.allowed == "" then
			if not byShot[m.shot] then byShot[m.shot] = {} shotOrder[#shotOrder + 1] = m.shot end
			local g = byShot[m.shot]
			g[#g + 1] = ("  %s | %s: %s"):format(m.what, m.kind, m.detail)
		end
	end
	table.sort(shotOrder)
	print(("stretch %s%%: every text measured %s%% wider"):format(tostring(opt.stretch), tostring(opt.stretch)))
	local total = 0
	for _, shot in ipairs(shotOrder) do
		local g = byShot[shot]
		table.sort(g)
		print(("== %s: %d"):format(shot, #g))
		for _, l in ipairs(g) do print(l) end
		total = total + #g
	end
	print(("total: %d problems on %d screens"):format(total, #shotOrder))
	bad = total
	order = {} -- (the normal lines are not printed again)
end
for _, k in ipairs(order) do
	local m = merged[k]
	if m.allowed == "" then bad = bad + 1 end
	local line = (("%s | x%s | %s | %s | %s: %s%s"):format(m.shot, keys(m.scales), keys(m.wins), m.what, m.kind, m.detail,
		m.allowed ~= "" and ("   [" .. (m.known and "known: " or "allowed: ") .. m.allowed .. "]") or ""))
	if not printed[line] then printed[line] = true print(line) end
end
if opt.words then
	table.sort(wordsOrder)
	for _, s in ipairs(wordsOrder) do
		local m = wordsOf[s]
		print(("WORDS %s %d budget %d %s"):format(m.shot, m.n, m.budget, m.kind))
	end
end
for n in pairs(notes) do if opt.verbose or n:find("^probe labels:") then print("note: " .. n) end end -- (job 2893) the learner's unmeasured count always shows
-- (a run that went wrong is never a verdict: always shown, exit 2)
for _, e in ipairs(errors) do io.stderr:write("layout-check: Lua error in the fake game: " .. e .. "\n") end
for _, b in ipairs(broken) do io.stderr:write("layout-check: broken run: " .. b .. "\n") end
local secs = os.time() - t0
-- (group C) the problems per kind (the ones that fail, not the allowed or known): covered, and daylight = the Daylight run's
local kindCount, coveredN, daylightN = {}, 0, 0
for _, k in ipairs(order) do
	local m = merged[k]
	if m.allowed == "" then
		kindCount[m.kind] = (kindCount[m.kind] or 0) + 1
		if m.kind == "covered" then coveredN = coveredN + 1 end
		if m.shot:find("^daylight/") then daylightN = daylightN + 1 end
	end
end
do
	local kinds = {}
	for kd, n in pairs(kindCount) do kinds[#kinds + 1] = kd .. "=" .. n end
	table.sort(kinds)
	io.stderr:write("layout-check: problems per kind: " .. (#kinds > 0 and table.concat(kinds, " ") or "none") .. "\n")
end
io.stderr:write(("layout-check: %d runs (%s), %d shots, %d problems, %d known (reported, not failing: --known), %d allowed, %d Lua errors in the fake game, %d broken, %d s%s\n")
	:format(#configs, table.concat(configs, " "), shots, bad, knownN, allowedN, #errors, #broken, secs, opt.screens and (", screens " .. table.concat(opt.screens, ",")) or ""))
for _, f in ipairs(failed) do io.stderr:write("layout-check: could not run " .. f .. "\n") end
if shots == 0 and #failed == 0 then
	io.stderr:write("layout-check: no shot was taken (--screen " .. table.concat(opt.screens or {}, ",") .. " matches none? --list shows the ids)\n")
end
-- the last line, always (--regress reads it): result 0 clean, 1 layout failures, 2 could not run
local code = (routeCouldNot or #failed > 0 or #errors > 0 or #broken > 0 or shots == 0) and 2 or (bad > 0 and 1 or 0)
io.stderr:write(("layout-check: result %d (%s)\n"):format(code, code == 0 and "clean" or code == 1 and "layout failures" or "could not run"))
-- the gauntlet line, last (stdout and stderr both, so either capture ends on it)
do
	local line = ("GAUNTLET layout result=%s shots=%d problems=%d known=%d covered=%d daylight=%d routes=%d"):format(
		code == 0 and "pass" or code == 1 and "fail" or "error", shots, bad, knownN, coveredN, daylightN, routeBad)
	io.stdout:write(line .. "\n") io.stdout:flush()
	io.stderr:write(line .. "\n")
end
os.exit(code)
end

local okMain, errMain = xpcall(main, debug.traceback)
if not okMain then die("the checker itself failed: " .. tostring(errMain)) end
os.exit(0)
