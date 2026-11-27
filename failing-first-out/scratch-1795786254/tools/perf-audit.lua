-- tools/perf-audit.lua: what Wuber costs a player in the fake game (job 2879, 26 Nov 2026).
--   lua5.1 tools/perf-audit.lua [--role driver|rider|control] [--minutes N] [--profile] [--out path]
-- Plays N simulated minutes (default 60) of a busy session and writes a key=value report to --out (default tests/out/perf-<role>.txt):
--   driver: a Warlock driver online with 6 riders asking, a map open, 200 chat lines a minute in Trade.
--   rider:  a rider with the window open on Home, a driver online, a booking, the map open, chat as above.
-- Numbers: Lua KB after a full collect (login, then every 5 min), garbage KB a minute (GC stopped for one simulated
-- minute), per-module load KB (each file's main chunk), the timers and OnUpdate scripts that run (how often, ms a call),
-- and with --profile a sampled CPU and allocation share per Wuber file (debug.sethook every 1000 instructions).
-- The fake's own work is in the numbers: compare runs, do not quote them as game ms.
local here = (arg and arg[0] or "tools/perf-audit.lua"):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
local root = here .. "/.."
local role, minutes, profile, outpath, byFunc = "driver", 60, false, nil, false
do
	local i = 1
	while arg[i] do
		if arg[i] == "--role" then role = arg[i + 1] i = i + 1
		elseif arg[i] == "--minutes" then minutes = tonumber(arg[i + 1]) or minutes i = i + 1
		elseif arg[i] == "--profile" then profile = true
		elseif arg[i] == "--funcs" then profile, byFunc = true, true -- profile by function (file:line it starts) instead of by file
		elseif arg[i] == "--out" then outpath = arg[i + 1] i = i + 1
		elseif arg[i] == "--help" or arg[i] == "-h" then print("usage: lua5.1 tools/perf-audit.lua [--role driver|rider] [--minutes N] [--profile|--funcs] [--out path]") os.exit(0)
		end
		i = i + 1
	end
end
outpath = outpath or (root .. "/tests/out/perf-" .. role .. (profile and "-prof" or "") .. ".txt")
package.path = root .. "/tests/?.lua;" .. package.path
arg[0] = root .. "/tests/run.lua" -- the harness finds the repository from the running script's path
local innerOf = setmetatable({}, { __mode = "k" })
local realSetfenv = setfenv
setfenv = function(f, env) -- the harness gives the chunk its window's environment: the wrapper passes it on
	if innerOf[f] then realSetfenv(innerOf[f], env) end
	return realSetfenv(f, env)
end
local H = require("harness")
local out = {}
local function emit(k, v) out[#out + 1] = k .. "=" .. tostring(v) end
local function kb() return collectgarbage("count") end
local function full() collectgarbage("collect") collectgarbage("collect") return kb() end

-- per-file load cost: each Wuber file's main chunk, KB allocated with the collector stopped
local loadKB = {}
local function gcStop() collectgarbage("stop") end
local function gcRestart() collectgarbage("restart") end
local realCompiled = H.compiled
H.compiled = function(path)
	local chunk, err = realCompiled(path)
	if not chunk or not path:find("/Wuber/", 1, true) then return chunk, err end
	local short = path:match("/Wuber/(.*)$") or path
	local wrapper
	wrapper = function(...)
		gcStop() -- (no globals here: the harness gives this wrapper the game window's environment)
		local before = kb()
		local r = chunk(...)
		loadKB[short] = (loadKB[short] or 0) + (kb() - before)
		gcRestart()
		return r
	end
	innerOf[wrapper] = chunk
	return wrapper, err
end


-- timers: every callback fired through the world's H.protect (C_Timer.After/NewTicker/NewTimer): count and CPU by creation site
local timerStat = {}
local realProtect = H.protect
local function siteOf(fn)
	local info = type(fn) == "function" and debug.getinfo(fn, "S")
	-- the fake's wrapper and W.After / W.Every (Core/Runtime.lua) wrap the addon's function: it is their upvalue "fn"
	local cur = fn
	for _ = 1, 3 do
		local src = info and info.short_src or ""
		if not (src:find("harness.lua", 1, true) or src:find("Core/Runtime.lua", 1, true)) then break end
		local nxt
		for i = 1, 8 do
			local n, v = debug.getupvalue(cur, i)
			if not n then break end
			if n == "fn" and type(v) == "function" then nxt = v break end
		end
		if not nxt then break end
		cur, info = nxt, debug.getinfo(nxt, "S")
	end
	return info and ((info.short_src or "?"):gsub("^.*/Wuber/", "") .. ":" .. (info.linedefined or 0)) or "?"
end
H.protect = function(world, client, where, fn, ...)
	if type(fn) ~= "function" or not tostring(where):find("C_Timer", 1, true) then return realProtect(world, client, where, fn, ...) end
	local site = siteOf(fn)
	local st = timerStat[site]
	if not st then st = { n = 0, cpu = 0, kind = where } timerStat[site] = st end
	local c0 = os.clock()
	local a, b, c = realProtect(world, client, where, fn, ...)
	st.n = st.n + 1
	st.cpu = st.cpu + (os.clock() - c0)
	return a, b, c
end

local lastWorld
local realNew = H.NewWorld
H.NewWorld = function(...) lastWorld = realNew(...) return lastWorld end
local Scenes = dofile(root .. "/tests/speed/scenes.lua")
local PLACES = { "Undercity", "Ratchet", "Thunder Bluff", "Crossroads", "Booty Bay", "Gadgetzan", "Tarren Mill", "Orgrimmar" }
local LINES = {
	"LFM Mara need tank and healer", "WTS [Linen Cloth] x20 cheap", "anyone summon to Orgrimmar?", "lf1m ZG pst",
	"WTB Thorium Bar pm me", "LFG Deadmines", "wuber to Ratchet 5g", "guild recruiting casual raiders", "LF enchanter pst",
	"selling Netherweb Lining, fair prices", "need a lock for summon at Stonetalon", "free port to Undercity",
}
-- the fake game's own weight: a world with one client and no addon
local baselineKB
do
	local bw = H.NewWorld({})
	bw:addClient("Base Line", { spot = "Orgrimmar", class = "WARLOCK", screenW = 1920, screenH = 1080 })
	bw:advance(5)
	baselineKB = full()
	bw = nil
	H.release()
end
local w, c, riders
local collect0 = nil
local t0clock = os.clock()
local okW, w0, c0 = pcall(Scenes.world, H, { drivers = 0, trips = 30, name = "Anita Lift" })
if not okW then
	for i, e in ipairs(lastWorld.errors) do print(tostring(e):sub(1, 600)) if i > 3 then break end end
	error(w0)
end
if role == "control" then -- the fake game alone: one client with no addon and the same chat
	w = H.NewWorld({})
	c = w:addClient("Anita Lift", { spot = "Orgrimmar", class = "WARLOCK", screenW = 1920, screenH = 1080, addons = {} })
	c.W = {}
	riders = {}
elseif role == "driver" then
	w, c = Scenes.world(H, { drivers = 0, trips = 30, name = "Anita Lift" })
	local D = c.W.Driver
	if D and D.SetOnline then pcall(D.SetOnline, true) end
	riders = {}
	for i = 1, 6 do
		riders[i] = "Rider" .. string.char(64 + i) .. "x"
		w:addBot(riders[i], { spot = PLACES[(i % #PLACES) + 1] })
		w:inject(riders[i], c.W.Encode("Q", "0"), "WHISPER", c)
		w:advance(1)
	end
	c.W.UI.Toggle(true)
	pcall(function() c.W.UI.SelectTab("Drive") end)
else
	w, c = Scenes.world(H, { drivers = 12, trips = 30, name = "Plain Rider" })
	c.W.UI.Toggle(true)
	local d = w:addClient("Drvaa Lift", { spot = "Orgrimmar", class = "WARLOCK", addons = { "Wuber" } })
	w:advance(10)
	pcall(function() d.W.Driver.SetOnline(true) end)
	w:advance(20)
	riders = {}
end
-- the map open (a player with the map up while the rest runs)
if role ~= "control" then
	pcall(function() if c.env.WorldMapFrame then c.env.WorldMapFrame:Show() end end)
	pcall(function() c.W.UI.Map.Open() end)
end
w:advance(5)
emit("role", role)
emit("kb_baseline_fake_game_no_addon", string.format("%.0f", baselineKB))
emit("minutes", minutes)
emit("kb_login", string.format("%.0f", full()))
local nTimersLogin = #w.timers
emit("timers_pending_at_login", nTimersLogin)

-- what each module of the addon holds in tables and strings (retained data, an estimate: 56 B a table, 16 B an array slot,
-- 40 B a hash slot, 24 B + length a string; a table reached from two modules counts for the first, so read it as a ranking).
-- The fake game's widget state is not in it. Closures and code are not either (see loadkb_ for the code).
local function census(ns)
	local seen, out2 = {}, {}
	local strs = {}
	local function walk(v, acc)
		local tv = type(v)
		if tv == "string" then
			if not strs[v] then strs[v] = true acc.b = acc.b + 24 + #v end
		elseif tv == "table" then
			if seen[v] or H.state[v] then return end
			seen[v] = true
			acc.t = acc.t + 1
			local n = 0
			for _ in pairs(v) do n = n + 1 end
			acc.b = acc.b + 56 + 32 * n
			for k, x in pairs(v) do
				if type(k) == "table" then walk(k, acc) end
				walk(x, acc)
			end
		end
	end
	local keys = {}
	for k, v in pairs(ns) do if type(v) == "table" and type(k) == "string" then keys[#keys + 1] = k end end
	table.sort(keys, function(a, b) return (a == "db") ~= (b == "db") and a == "db" or a < b end)
	for _, k in ipairs(keys) do
		local acc = { t = 0, b = 0 }
		walk(ns[k], acc)
		out2[k] = acc
	end
	return out2
end
local census0 = census(c.W)
-- which tables of the addon gain entries: entries per table path (depth 4) at login and at the end
local function entries(ns)
	local out2, seen = {}, {}
	local function walk(v, path, depth)
		if type(v) ~= "table" or seen[v] or depth > 4 or H.state[v] then return end
		seen[v] = true
		local n = 0
		for _ in pairs(v) do n = n + 1 end
		out2[path] = n
		for k, x in pairs(v) do if type(x) == "table" then walk(x, path .. "." .. tostring(k), depth + 1) end end
	end
	for k, v in pairs(ns) do if type(k) == "string" then walk(v, "W." .. k, 0) end end
	return out2
end
local entries0 = entries(c.W)
local function widgetCount_()
	return 0
end
-- per-client widget count (the fake game keeps frames alive: this is the addon's frame count, not just Lua tables)
local function widgetCount() local n = 0 for _ in pairs(c.widgets or {}) do n = n + 1 end return n end
emit("widgets_login", widgetCount())

-- profile hook: CPU and allocation by the Wuber file on the stack
local prof = { cpu = {}, alloc = {}, own = {} }
local function wuberFile()
	local path, n = nil, 0
	local running = debug.getinfo(3, "S")
	local mine = running and ((running.short_src or ""):find("/Wuber/", 1, true) ~= nil)
	for lvl = 3, 40 do
		local info = debug.getinfo(lvl, "S")
		if not info then break end
		local src = info.short_src or info.source or ""
		local f = src:match("/Wuber/(.*)$") or src:match("^Wuber/(.*)$")
		if f then
			if not byFunc then return f end
			path = (path and (path .. " < ") or "") .. f .. ":" .. (info.linedefined or 0)
			n = n + 1
			if n >= 4 then break end -- --funcs: the first four Wuber functions up the stack (who called the helper)
		end
	end
	return path, mine
end
local lastC, lastK
local function startProf()
	if not profile then return end
	lastC, lastK = os.clock(), kb()
	debug.sethook(function()
		local nc, nk = os.clock(), kb()
		local f, mine = wuberFile()
		f = f or "(fake game)"
		prof.cpu[f] = (prof.cpu[f] or 0) + (nc - lastC)
		local dk = nk - lastK
		if dk > 0 then
			prof.alloc[f] = (prof.alloc[f] or 0) + dk
			if mine then prof.own[f] = (prof.own[f] or 0) + dk end -- made by the addon's own code, not inside a fake game call it made
		end
		lastC, lastK = nc, kb()
	end, "", 1000)
end
startProf()

local lineNo, tradeSeq = 0, 0
local memSeries, garbage = {}, {}
local function playMinute(m)
	-- 200 chat lines a minute: one every 0.3 s, from 40 different speakers, all in Trade
	local step = 0.3
	local stepsLeft = math.floor(60 / step)
	for s = 1, stepsLeft do
		lineNo = lineNo + 1
		w:chatFrom("Talker" .. (lineNo % 40), LINES[(lineNo % #LINES) + 1] .. " " .. lineNo, "CHANNEL", "Trade")
		w:advance(step)
	end
	-- riders pinging the driver now and then (driver role): a fresh question each minute from one of the six
	if role == "driver" and #riders > 0 then
		w:inject(riders[(m % #riders) + 1], c.W.Encode("Q", "0"), "WHISPER", c)
	end
end

local garbageEvery = 1 -- every minute runs with the collector stopped (a collector step inside a timer would be counted as the timer's time)
for m = 1, minutes do
	local measure = (m % garbageEvery == 0) and not profile
	if profile then collectgarbage("collect") collectgarbage("stop") lastK = kb() end -- allocation is counted with the collector stopped; one collect a minute
	if measure then collectgarbage("collect") collectgarbage("stop") end
	local k0 = kb()
	playMinute(m)
	if measure then
		garbage[#garbage + 1] = kb() - k0
		collectgarbage("restart")
	end
	if m % 5 == 0 then
		if not profile then
			memSeries[#memSeries + 1] = { m, full() }
		end
	end
end
debug.sethook()
if profile then collectgarbage("restart") end
local kbEnd = full()
emit("kb_end", string.format("%.0f", kbEnd))
for _, p in ipairs(memSeries) do emit(("kb_at_%03dmin"):format(p[1]), string.format("%.0f", p[2])) end
do
	local sum = 0 for _, g in ipairs(garbage) do sum = sum + g end
	emit("garbage_kb_per_minute_avg", #garbage > 0 and string.format("%.0f", sum / #garbage) or "n/a")
end
emit("widgets_end", widgetCount())
do
	local census1 = census(c.W)
	local rowsC = {}
	for k, a1 in pairs(census1) do
		local a0 = census0[k] or { t = 0, b = 0 }
		rowsC[#rowsC + 1] = { k, a0.b, a1.b, a1.t - a0.t }
	end
	table.sort(rowsC, function(x, y) return x[3] > y[3] end)
	local totalB0, totalB1 = 0, 0
	for _, r in ipairs(rowsC) do totalB0, totalB1 = totalB0 + r[2], totalB1 + r[3] end
	local e1, gr = entries(c.W), {}
	for path, n in pairs(e1) do gr[#gr + 1] = { path, entries0[path] or 0, n } end
	table.sort(gr, function(x, y) return x[3] - x[2] > y[3] - y[2] end)
	for i = 1, math.min(#gr, 8) do emit(("grows_%02d"):format(i), string.format("%s | entries login=%d end=%d", gr[i][1], gr[i][2], gr[i][3])) end
	emit("tables_kb_login", string.format("%.0f", totalB0 / 1024))
	emit("tables_kb_end", string.format("%.0f", totalB1 / 1024))
	for i = 1, math.min(#rowsC, 14) do
		emit(("module_%02d"):format(i), string.format("W.%s | login_kb=%.0f | end_kb=%.0f | growth_kb=%.0f | new_tables=%d", rowsC[i][1], rowsC[i][2] / 1024, rowsC[i][3] / 1024, (rowsC[i][3] - rowsC[i][2]) / 1024, rowsC[i][4]))
	end
end
emit("timers_pending_at_end", #w.timers)
emit("cpu_seconds_total", string.format("%.1f", os.clock() - t0clock))

-- ticker / timer census: how often (per simulated minute) and ms a call
local rows = {}
for site, st in pairs(timerStat) do rows[#rows + 1] = { site = site, n = st.n, cpu = st.cpu, kind = st.kind } end
table.sort(rows, function(a, b) return a.cpu > b.cpu end)
for i = 1, math.min(#rows, 40) do
	local r = rows[i]
	emit(("timer_%02d"):format(i), string.format("%s | %s | calls/min=%.1f | ms/call=%.3f | cpu_ms/min=%.1f", r.site, r.kind, r.n / minutes, r.cpu / math.max(1, r.n) * 1000, r.cpu * 1000 / minutes))
end

-- OnUpdate scripts: every frame that has one on this client, shown or not: ms a call and how many run each frame
local ups = {}
for _, f in ipairs(c.updaters or {}) do
	local s = H.state and H.state[f]
	local script = s and s.scripts and s.scripts.OnUpdate
	if script then
		local vis = false
		pcall(function() vis = f:IsVisible() end)
		local n, c0 = 200, os.clock()
		for _ = 1, n do pcall(script, f, 0.016) end
		local ms = (os.clock() - c0) / n * 1000
		local info = debug.getinfo(script, "S")
		ups[#ups + 1] = { src = (info.short_src or "?"):gsub("^.*/Wuber/", "") .. ":" .. info.linedefined, vis = vis, ms = ms }
	end
end
table.sort(ups, function(a, b) return a.ms * (a.vis and 1 or 0) > b.ms * (b.vis and 1 or 0) end)
local running = 0
for _, u in ipairs(ups) do if u.vis then running = running + 1 end end
emit("onupdate_scripts_total", #ups)
emit("onupdate_scripts_visible_now", running)
for i = 1, math.min(#ups, 25) do
	local u = ups[i]
	emit(("onupdate_%02d"):format(i), string.format("%s | visible=%s | ms/call=%.4f | ms/s at 60fps=%.2f", u.src, tostring(u.vis), u.ms, u.vis and u.ms * 60 or 0))
end

-- chat cost per line: 200 more lines, time and KB each, with the collector stopped
do
	collectgarbage("collect") collectgarbage("stop")
	local k0, c0 = kb(), os.clock()
	local fnHits = {}
	debug.sethook(function() -- where the instructions go: the addon function running (or the one that called the fake game)
		for lvl = 2, 30 do
			local info = debug.getinfo(lvl, "S")
			if not info then break end
			local f = (info.short_src or ""):match("/Wuber/(.*)$")
			if f then
				local k = f .. ":" .. (info.linedefined or 0)
				fnHits[k] = (fnHits[k] or 0) + 1
				break
			end
		end
	end, "", 100)
	for i = 1, 200 do w:chatFrom("Talker" .. (i % 40), LINES[(i % #LINES) + 1] .. " " .. i, "CHANNEL", "Trade") end
	debug.sethook()
	do
		local hs, total = {}, 0
		for k, v in pairs(fnHits) do hs[#hs + 1] = { k, v } total = total + v end
		table.sort(hs, function(x, y) return x[2] > y[2] end)
		for i = 1, math.min(#hs, 8) do emit(("chatfn_%02d"):format(i), string.format("%s | %.1f%% of the instructions a chat line runs in the addon | %.0f instructions a line", hs[i][1], hs[i][2] / total * 100, hs[i][2] * 100 / 200)) end
	end
	emit("chat_line_cpu_ms", string.format("%.3f", (os.clock() - c0) * 1000 / 200))
	emit("chat_line_kb", string.format("%.2f", (kb() - k0) / 200))
	collectgarbage("restart")
end

-- files: load KB, and with --profile the CPU and allocation per file
local fl = {}
for f, v in pairs(loadKB) do fl[#fl + 1] = { f, v } end
table.sort(fl, function(a, b) return a[2] > b[2] end)
for i = 1, math.min(#fl, 30) do emit(("loadkb_%02d"):format(i), fl[i][1] .. " | " .. string.format("%.0f", fl[i][2])) end
local totalLoad = 0 for _, v in pairs(loadKB) do totalLoad = totalLoad + v end
emit("loadkb_total", string.format("%.0f", totalLoad))
if profile then
	local pr, tot = {}, 0
	for f, v in pairs(prof.cpu) do tot = tot + v pr[#pr + 1] = { f, v, prof.alloc[f] or 0, prof.own[f] or 0 } end
	table.sort(pr, function(a, b) return a[2] > b[2] end)
	emit("prof_cpu_total_s", string.format("%.1f", tot))
	for i = 1, math.min(#pr, 40) do
		emit(("prof_%02d"):format(i), string.format("%s | cpu_ms/min=%.1f (%.1f%%) | alloc_kb/min=%.0f (of it the addon's own code: %.0f)", pr[i][1], pr[i][2] * 1000 / minutes, pr[i][2] / math.max(tot, 1e-9) * 100, pr[i][3] / minutes, pr[i][4] / minutes))
	end
end
local errs = {}
for _, e in ipairs(w.errors or {}) do errs[#errs + 1] = tostring(e):match("^[^\n]*") end
emit("fake_game_errors", #errs)
for i = 1, math.min(#errs, 5) do emit("error_" .. i, errs[i]) end

local f = assert(io.open(outpath, "w"))
f:write(table.concat(out, "\n"), "\n")
f:close()
print("perf-audit: wrote " .. outpath)
