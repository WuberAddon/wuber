-- The layout checker's regression cases (tools/layout-check.lua --regress; BRIEF21 S11): this week's real layout
-- bugs, each run on its OLD code (the Wuber folder at the commit before its fix, from git) must fail with its
-- known problem, and today's code (this checkout) must not show it. Needs git and tar on the PATH.
--   lua tools/layout-check.lua --regress [--screen <case id>] [--verbose] [--jobs N]
--   lua tools/layout-check.lua --regress --clean     deletes the cache of old trees, runs nothing
-- Each old Wuber folder is unpacked once into %TEMP%/wuber-layout-old/<commit> and stays there for the next run
-- (a few MB each; --clean removes them). Each run is a whole layout-check, at most 4 at once (--jobs).
-- Exit 0: every case behaves; 1: a case does not; 2: could not run (a run that did not end with its
-- "layout-check: result" line, or ended "result 2", is never read as a verdict).
local R = {}

-- (revisions say ~1, not ^: cmd.exe eats a caret)
-- id, the commit whose Wuber has the bug, the shots to run, what the checker must report there (Lua patterns on
-- a result line: "<shot> | x<scale> | <window> | <frame> | <kind>: <problem>"), and where the bug came from
R.CASES = {
	{ id = "paused_bar", rev = "a35c66b", screen = "login_paused", expect = "login_paused/folded .* Button%.lua:%d+%(Tokens%.lua%) sub .*cut: laid out before its font",
		why = "BRIEF18 00:15: the floating Drive bar while Paused, its sub cut to 'tap Res...' (the font arrived after login)" },
	{ id = "advertise", rev = "a35c66b", screen = "login_drive", expect = "login_drive/folded .*\"Advertise\" | cut:",
		why = "BRIEF18 00:28: 'Advertis...' on the Drive tab's third pill (same cause)" },
	{ id = "trips_cue", rev = "1da7eab~1", screen = "trips", expect = "trips/unfolded .*Trips%.lua.*under: partly under .*Scroll for your trip",
		why = "REPORT19: the Trips scroll cue covered a trip row in unfolded Trips (fixed in 1da7eab)" },
	{ id = "trips_empty", rev = "f1b6e97~1", screen = "trips", expect = "trips/unfolded .*emptycue:",
		why = "BRIEF20 B2: unfolded Trips with no rows under 'Your trips', only blank space and the cue (fixed in f1b6e97)",
		offline = "the bug needs the game's 0 height just after the window widens; the fake game gives the real height at once" },
	{ id = "raid_more", rev = "6287e8d~1", screen = "raid", expect = "raid/folded .*under: partly under .*more below",
		why = "BRIEF19 F1: narrow Raid, a row under the '+N more below' pill (fixed in 6287e8d)" },
	{ id = "pvp_straddle", rev = "0a8e83c~1", screen = "pvp", expect = "pvp/folded .*Rows%.lua.*clipped: cut by its view",
		why = "BRIEF19 F2 / tour 43: narrow Drive with the PvP warning, a rider row sliced by the bottom (fixed in 0a8e83c)" },
	{ id = "earnings_tips", rev = "9011a15~1", screen = "earnings_tips", expect = "earnings_tips/.*\"Try .*clipped: cut by its view .*right by",
		why = "BRIEF18 01:00: the Earnings tip strip 'Try ...' ran past the right edge of the phone (fixed in 9011a15)" },
}
R.CONFIG = "2662x2089@1"

local WINDOWS = package.config:sub(1, 1) == "\\"
-- cmd.exe drops the first and last quote of a command line that starts with one: wrap it once more
local function popen(cmd)
	if WINDOWS and cmd:find('"', 1, true) then cmd = '"' .. cmd .. '"' end
	return io.popen(cmd)
end
local function sh(cmd)
	local p = popen(cmd .. " 2>&1")
	local out = p and p:read("*a") or ""
	if p then p:close() end
	return out
end

local function q(s)
	s = tostring(s):gsub("\\", "/")
	if s:find("[%s\"]") then return '"' .. s .. '"' end
	return s
end

local function tmpdir()
	local t = os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
	return (t:gsub("\\", "/")) .. "/wuber-layout-old"
end

local function rmdir(dir)
	if WINDOWS then os.execute(('if exist "%s" rmdir /s /q "%s"'):format(dir:gsub("/", "\\"), (dir:gsub("/", "\\"))))
	else os.execute(("rm -rf %q"):format(dir)) end
end
local function mkdir(dir)
	if WINDOWS then os.execute(('mkdir "%s" 2>nul'):format((dir:gsub("/", "\\")))) else os.execute(("mkdir -p %q"):format(dir)) end
end
local function exists(path)
	local f = io.open(path, "r")
	if f then f:close() return true end
	return false
end

-- the old Wuber folder for a commit (cached by its hash): <tmp>/<sha>/Wuber. Unpacked into <sha>.tmp and renamed
-- once whole, so a run stopped halfway never leaves a cache entry that looks done.
local function oldTree(root, rev)
	local sha = sh(("git -C %s rev-parse %s"):format(q(root), rev)):match("^(%x+)")
	if not sha then return nil, "git rev-parse " .. rev .. " failed" end
	local dir = tmpdir() .. "/" .. sha:sub(1, 12)
	if exists(dir .. "/Wuber/Wuber.toc") then return dir .. "/Wuber" end
	local part = dir .. ".tmp"
	rmdir(part)
	rmdir(dir)
	mkdir(part)
	local out = sh(("git -C %s archive --format=tar %s Wuber | tar -x -C %s"):format(q(root), sha, q(part)))
	if not exists(part .. "/Wuber/Wuber.toc") then return nil, "could not unpack " .. rev .. ": " .. out end
	local ok, err = os.rename(part, dir)
	if not ok then return nil, "could not rename " .. part .. ": " .. tostring(err) end
	return dir .. "/Wuber"
end

-- a layout-check run's verdict: its last line "layout-check: result <n>"; nil when it never got there
local function verdict(text)
	local code
	for n in text:gmatch("layout%-check: result (%d)") do code = tonumber(n) end
	return code
end


function R.main(o)
	if o.clean then
		rmdir(tmpdir())
		print("layout-check --regress: deleted " .. tmpdir())
		return 0
	end
	local cases = {}
	for _, c in ipairs(R.CASES) do
		local keep = not o.only
		for _, x in ipairs(o.only or {}) do if x == c.id then keep = true end end
		if keep then cases[#cases + 1] = c end
	end
	-- each case on its old code (--all: an allowed line still shows the bug was seen), and each shot list on
	-- today's (no --all: an allowed or known line is not a failure today); at most o.jobs (4) at once
	local runs, today, todayList = {}, {}, {}
	for _, c in ipairs(cases) do
		local dir, err = oldTree(o.root, c.rev)
		if not dir then io.stderr:write("layout-check --regress: " .. c.id .. ": " .. tostring(err) .. "\n") return 2 end
		local base = ("%s %s --config %s --screen %s --lab %s --jobs 1"):format(q(o.lua), q(o.script), R.CONFIG, c.screen, q(o.lab))
		runs[#runs + 1] = { case = c, cmd = base .. " --all --wuber " .. q(dir) .. " 2>&1" }
		if not today[c.screen] then
			today[c.screen] = { cmd = base .. " 2>&1", screen = c.screen }
			todayList[#todayList + 1] = today[c.screen]
		end
	end
	local queue = {}
	for _, r in ipairs(runs) do queue[#queue + 1] = r end
	for _, t in ipairs(todayList) do queue[#queue + 1] = t end
	local live = {}
	local function start()
		local r = table.remove(queue, 1)
		if not r then return end
		r.p = popen(r.cmd)
		live[#live + 1] = r
	end
	for _ = 1, o.jobs or 4 do start() end
	while #live > 0 do
		local r = table.remove(live, 1)
		r.text = r.p and r.p:read("*a") or ""
		if r.p then r.p:close() end
		start()
	end
	-- a run without its result line, or one that could not run, is no verdict
	local broken = 0
	local function check(text, what)
		local v = verdict(text)
		if v == nil or v == 2 then
			broken = broken + 1
			io.stderr:write(("layout-check --regress: %s could not run (%s):\n%s\n"):format(what, v and "result 2" or "no result line", text:sub(-1200)))
			return false
		end
		return true
	end
	for _, r in ipairs(runs) do r.ran = check(r.text, r.case.id .. " on " .. r.case.rev) end
	for _, t in ipairs(todayList) do t.ran = check(t.text, "today's " .. t.screen) end
	if broken > 0 then return 2 end
	local bad = 0
	local function find(text, pat)
		for line in text:gmatch("[^\r\n]+") do
			-- (an allowed or known line is not the bug: only plain result lines count)
			if line:find(pat) and not line:find("%[known: ") and not line:find("%[allowed: ") then return line end
		end
		return nil
	end
	local function findOld(text, pat)
		for line in text:gmatch("[^\r\n]+") do if line:find(pat) then return line end end
		return nil
	end
	for _, r in ipairs(runs) do
		local c = r.case
		local hit = findOld(r.text, c.expect)
		local now = find(today[c.screen].text, c.expect)
		local status
		if c.offline then
			status = hit and "CAUGHT (although marked offline-only)" or ("NOT REPRODUCIBLE OFFLINE: " .. c.offline)
		elseif hit and not now then status = "ok"
		else
			bad = bad + 1
			status = not hit and "FAIL: the old code passed (the checker misses this bug)" or "FAIL: today's code still shows it"
		end
		print(("%-14s %-9s %s  [%s]"):format(c.id, c.rev, status, c.why))
		if hit and (o.verbose or status ~= "ok") then print("    old:   " .. hit) end
		if now then print("    today: " .. now) end
		if o.verbose and not hit then print("    old run said: " .. r.text:sub(-800)) end
	end
	return bad > 0 and 1 or 0
end

return R
