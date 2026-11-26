-- tools/quick-select.lua: the tests a quick check runs for a list of changed files (job 2690).
--
--   lua5.1 tools/quick-select.lua --map=<coverage-map.txt> --out=<dir> [--jobs=N] [--times=<test-times.txt>]
--          [--always=<substring>]... <changed Wuber/ file>...                (from the repo root)
--
-- Reads the coverage map (tools/coverage-map.lua: test name TAB the Wuber/ files it ran code of) and writes
-- <dir>/names-1.txt .. names-K.txt (K <= N): the exact names of every test that ran code of a changed file, plus
-- every test whose name holds an --always substring (the cheap whole-repo checks), split into K balanced chunks
-- by the time tests/fixtures/test-times.txt gives each (0.5 s when unknown); tests/run.lua --names=<file> runs one.
-- Prints: "selected N tests (M by --always) for F mapped files, K chunks, about S s" and, when a changed file has
-- no map entry (nothing ever called its code), "unmapped: <file> ..." so the caller falls back to the name-based
-- list (tools/tests-for.lua). Exit 0; exit 4: no map (the caller runs the file-name fallback). Lua 5.1.

local mapPath, out, jobs, timesPath, always, files, layoutScope = nil, nil, 4, nil, {}, {}, false
for _, a in ipairs(arg or {}) do
	if a == "--layout-scope" then layoutScope = true
	elseif a:match("^%-%-map=") then mapPath = a:sub(7)
	elseif a:match("^%-%-out=") then out = a:sub(7)
	elseif a:match("^%-%-jobs=") then jobs = tonumber(a:sub(8)) or jobs
	elseif a:match("^%-%-times=") then timesPath = a:sub(9)
	elseif a:match("^%-%-always=") then always[#always + 1] = a:sub(10):lower()
	else files[#files + 1] = (a:gsub("\\", "/")) end
end
local function slurp(p) local f = io.open(p, "rb") if not f then return nil end local s = f:read("*a") f:close() return s end
-- --layout-scope <files>: "none" (no Wuber file), "narrow" (every file is one tools/layout-check.lua draws a known set of
-- screens for: its FILE_SCREENS table, read from that file so the two cannot drift) or "full <file>" (a shared UI file: Core, Theme,
-- Kit, Window, Fold, Media ...; the whole sweep, as the finish stage runs it)
if layoutScope then
	local lc = slurp("tools/layout-check.lua") or ""
	local prefixes = {}
	for pre in lc:match("local FILE_SCREENS = (%b{})"):gmatch('{ "([^"]+)", {') do prefixes[#prefixes + 1] = pre end
	local any = false
	for _, f in ipairs(files) do
		local rel = f:match("[Ww]uber/(.*)$")
		if rel then
			any = true
			local hit = false
			for _, pre in ipairs(prefixes) do if rel:find(pre, 1, true) == 1 and rel:match("%.lua$") then hit = true break end end
			if not hit then print("full " .. f) os.exit(0) end
		end
	end
	print(any and "narrow" or "none")
	os.exit(0)
end
local map = mapPath and slurp(mapPath)
if not map or not out then print("quick-select: no coverage map") os.exit(4) end

local byFile, names, bootOnly = {}, {}, {}
for line in map:gmatch("[^\r\n]+") do
	local name, fl = line:match("^(.-)\t(.*)$")
	if name then
		names[#names + 1] = name
		if fl == "@boot" then bootOnly[#bootOnly + 1] = name end -- made a world and called nothing after its boot (tools/coverage-map.lua)
		for fn in fl:gmatch("[^,]+") do byFile[fn] = byFile[fn] or {} table.insert(byFile[fn], name) end
	end
end
local times = {}
for line in (timesPath and slurp(timesPath) or ""):gmatch("[^\r\n]+") do
	local t, n = line:match("^([%d%.]+)\t(.*)$")
	if t then times[n] = tonumber(t) end
end

local chosen, order, mapped, unmapped, byAlways = {}, {}, 0, {}, 0
local function add(n) if not chosen[n] then chosen[n] = true order[#order + 1] = n return true end end
for _, f in ipairs(files) do
	local rel = f:match("[Ww]uber/(.*)$")
	if rel and rel:match("%.lua$") then
		if byFile[rel] then
			mapped = mapped + 1
			for _, n in ipairs(byFile[rel]) do add(n) end
		else unmapped[#unmapped + 1] = f end
		-- a test that made a world and called nothing after its boot (the map holds only "@boot": the hook was off, or it reads what the boot
		-- left): taken when its name holds the changed file's module id ("breakit Drive.Button: ..." for Drive/Button.lua); all 771 of
		-- them for any change would cost a minute a run
		local id = rel:gsub("%.lua$", ""):gsub("/", "."):lower()
		for _, n in ipairs(bootOnly) do
			if n:lower():find(id, 1, true) then add(n) end
		end
	end
end
for _, sub in ipairs(always) do
	local hit = false
	for _, n in ipairs(names) do
		if n:lower():find(sub, 1, true) then hit = true if add(n) then byAlways = byAlways + 1 end end
	end
	if not hit then print("nofilter: " .. sub) end
end

-- balanced chunks (longest first onto the lightest chunk)
local total = 0
local items = {}
for _, n in ipairs(order) do local t = times[n] or 0.5 items[#items + 1] = { n = n, t = t } total = total + t end
table.sort(items, function(a, b) if a.t ~= b.t then return a.t > b.t end return a.n < b.n end)
local k = math.max(1, math.min(jobs, math.ceil(total / 3)))
if #items == 0 then k = 0 end
local chunks = {}
for i = 1, k do chunks[i] = { t = 0, n = {} } end
for _, it in ipairs(items) do
	local best = chunks[1]
	for i = 2, k do if chunks[i].t < best.t then best = chunks[i] end end
	best.t = best.t + it.t
	best.n[#best.n + 1] = it.n
end
for i = 1, k do
	local f = assert(io.open(out .. "/names-" .. i .. ".txt", "wb"))
	f:write(table.concat(chunks[i].n, "\n"), "\n")
	f:close()
end
print(("selected %d tests (%d by --always) for %d mapped files, %d chunks, about %.0f s"):format(#order, byAlways, mapped, k, (function() local m = 0 for i = 1, k do m = math.max(m, chunks[i].t) end return m end)()))
if #unmapped > 0 then print("unmapped: " .. table.concat(unmapped, " ")) end
