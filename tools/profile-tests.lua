-- tools/profile-tests.lua: where the suite's time goes (BRIEF21 S3).
--
--   lua5.1 tools/profile-tests.lua "<filter>" [run.lua flags]     (from the repo or a worktree)
--
-- Runs tests/run.lua with the filter (and flags, e.g. --compare-transcript) and writes
-- tests/out/profile.txt (WUBER_PROF=<path> to change it):
--   * phases: CPU seconds in building windows (World:addClient), running the clock (World:advance),
--     the transcript recorder, the collect after each test (each excludes the others it calls)
--   * the files, functions and lines the time went to, sampled: every ~1000 VM instructions the
--     CPU time since the last sample goes to the running Lua function (time in a C function is
--     counted to the Lua function that called it)
--   * the tests, slowest first (CPU seconds)
-- The profile slows the run by about a third; the test results are the run's own. Per-test CPU
-- times without the profiler: any run with --shard 1/1 writes them to tests/out/results.1-of-1.txt.
--
--   lua5.1 tools/profile-tests.lua --screens [--deep] [--top N] [--only id,id]   (job 2749, speed)
--
-- Screen-change mode: no tests. Plays tests/speed/scenes.lua (one Warlock, 40 drivers, 60 trips, 1920x1080) and
-- measures each player-visible change with tests/lib/screenprof.lua: Lua ms of the change and of the 1 s settle after
-- it, KB allocated, widgets created (frames, font strings, textures), SetPoint/SetText/SetSize/string-measure/Show/Hide
-- calls, OnUpdate scripts still running each frame afterwards and animations still playing. Prints every step, then the
-- worst N (default 15) by ms; --deep runs the scene a second time with a call hook and lists the addon functions each
-- change called most (and the calls to *layout* functions: the layout passes). Writes tests/out/speed.txt
-- (WUBER_PROF=<path> to change it). The fake's own checks are in the ms: compare runs, don't quote them as game ms.
local here = (arg and arg[0] or "tools/profile-tests.lua"):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
local runpath = here .. "/../tests/run.lua"
local outpath = os.getenv("WUBER_PROF") or (here .. "/../tests/out/profile.txt")
local newarg = { [0] = runpath }
for i = 1, #arg do newarg[i] = arg[i] end
arg = newarg

if arg[1] == "--screens" then
	local deep, top, only = false, 15, nil
	local i = 2
	while arg[i] do
		if arg[i] == "--deep" then deep = true
		elseif arg[i] == "--top" then top = tonumber(arg[i + 1]) or top i = i + 1
		elseif arg[i] == "--only" then only = {} for s in (arg[i + 1] or ""):gmatch("[^,%s]+") do only[s] = true end i = i + 1
		end
		i = i + 1
	end
	local dir = runpath:match("^(.*)/[^/]*$")
	package.path = dir .. "/?.lua;" .. package.path
	local H = require("harness")
	local P = dofile(dir .. "/lib/screenprof.lua")(H)
	if not P.ok then io.stderr:write("profile: the harness's widget classes were not found\n") os.exit(2) end
	local Scenes = dofile(dir .. "/speed/scenes.lua")
	local out = Scenes.run(H, P, {})
	local deepOut = deep and Scenes.run(H, P, { deep = true }) or nil
	local spath = os.getenv("WUBER_PROF") or (here .. "/../tests/out/speed.txt")
	local lines = {}
	local function emit(s) lines[#lines + 1] = s print(s) end
	local function row(r)
		local m, c = r.m, r.m.calls
		local nf = (m.new.Frame or 0) + (m.new.Button or 0) + (m.new.CheckButton or 0) + (m.new.EditBox or 0) + (m.new.ScrollFrame or 0) + (m.new.Slider or 0) + (m.new.StatusBar or 0)
		return ("| %-15s | %7.1f | %6.1f | %7.0f | %4d | %4d | %4d | %5d | %5d | %5d | %5d | %4d/%-4d | %3d | %3d | %s%s"):format(r.id, m.ms, m.settleMs, m.kb,
			nf, m.new.FontString or 0, m.new.Texture or 0, c.setPoint or 0, c.setText or 0, c.setSize or 0, c.measure or 0, c.show or 0, c.hide or 0,
			m.idleUpdates, m.idleAnims, r.label, m.err and ("  ERROR " .. m.err) or "")
	end
	local head = "| step            |   ms    | settle |   KB    | frm  | fstr | tex  | SetPt | SetTx | SetSz | meas  | show/hide | upd | ani | change"
	emit("speed profile (tests/speed/scenes.lua): Lua ms in the fake game, the 1 s settle after, KB allocated, widgets made,")
	emit("widget calls, OnUpdate scripts running each frame and animations playing after the settle")
	emit("") emit(head)
	for _, r in ipairs(out) do if not only or only[r.id] then emit(row(r)) end end
	local sorted = {}
	for _, r in ipairs(out) do if not only or only[r.id] then sorted[#sorted + 1] = r end end
	table.sort(sorted, function(a, b) return a.m.ms + a.m.settleMs > b.m.ms + b.m.settleMs end)
	emit("") emit(("== the worst %d changes (ms + settle)"):format(top)) emit(head)
	for k = 1, math.min(top, #sorted) do emit(row(sorted[k])) end
	local last = out[#out] and out[#out].m
	for _, r in ipairs(out) do
		if r.id == "idle_open" or r.id == "idle_closed" then emit(("") .. r.id .. " OnUpdate scripts: " .. table.concat(r.m.idleSrc, " ")) end
	end
	if deepOut then
		emit("") emit("== the addon functions each change called most (--deep; calls, file:line, name), layout = calls to *layout* functions")
		for _, r in ipairs(deepOut) do
			if not only or only[r.id] then
				emit(("%s (layout %d)"):format(r.id, r.m.layout or 0))
				for k = 1, math.min(8, #(r.m.hot or {})) do local h = r.m.hot[k] emit(("  %6d  %s  %s"):format(h.calls, h.where, h.name or "")) end
			end
		end
	end
	emit("") emit(("errors in the fake game: %d"):format(#out.errors))
	for k = 1, math.min(10, #out.errors) do emit("  " .. out.errors[k]) end
	local f = io.open(spath, "wb")
	if f then f:write(table.concat(lines, "\n"), "\n") f:close() io.stderr:write("profile: " .. spath .. "\n") end
	os.exit(#out.errors == 0 and 0 or 1)
end

local clock, getinfo = os.clock, debug.getinfo
local T0 = clock()

-- phases (exclusive: a phase's time does not include the phases it calls)
local phase, count, stack = {}, {}, { 0 }
local function wrap(tbl, key, label)
	local f = tbl[key]
	tbl[key] = function(...)
		local t0 = clock()
		stack[#stack + 1] = 0
		local r = { pcall(f, ...) }
		local dt = clock() - t0
		local child = table.remove(stack)
		phase[label] = (phase[label] or 0) + dt - child
		count[label] = (count[label] or 0) + 1
		stack[#stack] = stack[#stack] + dt
		if not r[1] then error(r[2], 0) end
		return unpack(r, 2, table.maxn(r))
	end
end

-- samples
local byFile, byFn, byLine, total, last = {}, {}, {}, 0, clock()
local function hook()
	local now = clock()
	local dt = now - last
	last = now
	if dt == 0 then return end
	local i = getinfo(2, "Sl")
	if not i then return end
	total = total + dt
	local src = (i.short_src or "?"):gsub("^.-tests/%.%./", ""):gsub("^.-/tests/", "tests/")
	byFile[src] = (byFile[src] or 0) + dt
	local fk = src .. ":" .. (i.linedefined or 0)
	byFn[fk] = (byFn[fk] or 0) + dt
	local lk = src .. ":" .. (i.currentline or 0)
	byLine[lk] = (byLine[lk] or 0) + dt
end

-- tests: the time between two PASS/FAIL lines run.lua prints
local tests, testStart = {}, nil
local rawprint = print
print = function(...)
	local s = select("#", ...) > 0 and tostring((...)) or ""
	local name = s:match("^PASS  (.*)$") or s:match("^FAIL  ([^\n]*)")
	if name then
		local now = clock()
		tests[#tests + 1] = { name, now - (testStart or T0) }
		testStart = now
	end
	return rawprint(...)
end

local dir = runpath:match("^(.*)/[^/]*$")
package.path = dir .. "/?.lua;" .. package.path
local H = require("harness")
wrap(H.World, "addClient", "building windows (World:addClient)")
wrap(H.World, "advance", "running the clock (World:advance)")
local rawdofile = dofile
dofile = function(p)
	local r = rawdofile(p)
	if tostring(p):find("transcript.lua", 1, true) and type(r) == "table" and r.record then wrap(r, "record", "transcript recorder") end
	return r
end
local rawcg = collectgarbage
collectgarbage = function(what, ...)
	if what == nil or what == "collect" then
		local t0 = clock()
		stack[#stack + 1] = 0
		local r = rawcg(what, ...)
		local dt = clock() - t0
		local child = table.remove(stack)
		phase["full collect after each test"] = (phase["full collect after each test"] or 0) + dt - child
		count["full collect after each test"] = (count["full collect after each test"] or 0) + 1
		stack[#stack] = stack[#stack] + dt
		return r
	end
	return rawcg(what, ...)
end

local reported = false
local function report()
	if reported then return end
	reported = true
	debug.sethook()
	local all = clock() - T0
	local f = io.open(outpath, "wb")
	if not f then io.stderr:write("profile: cannot write " .. outpath .. "\n") return end
	local function sorted(t)
		local keys = {}
		for k in pairs(t) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return t[a] > t[b] end)
		return keys
	end
	f:write(("profile of tests/run.lua %s: %.1f s CPU, %d tests\n\n== phases\n"):format(table.concat(arg, " "), all, #tests))
	for _, k in ipairs(sorted(phase)) do
		f:write(("%8.2f s %5.1f%%  %s (%d)\n"):format(phase[k], 100 * phase[k] / all, k, count[k]))
	end
	local function dump(title, t, n)
		f:write("\n== ", title, " (sampled)\n")
		local keys = sorted(t)
		for i = 1, math.min(n, #keys) do f:write(("%8.2f s %5.1f%%  %s\n"):format(t[keys[i]], 100 * t[keys[i]] / math.max(total, 1e-9), keys[i])) end
	end
	dump("files", byFile, 25)
	dump("functions (file:line where it starts)", byFn, 40)
	dump("lines", byLine, 30)
	f:write("\n== tests, slowest first\n")
	table.sort(tests, function(a, b) return a[2] > b[2] end)
	for i = 1, math.min(40, #tests) do f:write(("%8.2f s  %s\n"):format(tests[i][2], tests[i][1])) end
	f:close()
	io.stderr:write("profile: " .. outpath .. "\n")
end
local rawexit = os.exit
os.exit = function(...) report() return rawexit(...) end
debug.sethook(hook, "", 1000)
local ok, err = pcall(rawdofile, runpath)
report()
if not ok then error(err, 0) end
