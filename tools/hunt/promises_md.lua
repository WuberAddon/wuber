-- Writes PROMISES.md at the repo root from the hunt's promise registry (tests/promises/*.lua; tests/hunt/README.md):
-- what Wuber promises the player, grouped by area (Universal first), each promise with its sentence, source (or
-- "inferred"), id, kind, and the dials it needs or is limited by, in plain words from the dials' "about" texts.
--   lua5.1 tools/hunt/promises_md.lua [--out <file>]        (from the repo root; the same registry gives the same file)
-- How "limited by" is found: a promise's when() is asked about the default situation and about each single dial
-- value changed from it (no game is built). A promise with a repro file in tests/hunt/repro (the file name starts with
-- the promise id) is marked "FAILS TODAY: <file>"; the top of the file lists each area with its count and its failing
-- promises. (A repro file stays after its bug is fixed until somebody removes it: the mark is the file's presence.)
-- Nothing here changes addon code.
local here = ((arg and arg[0]) or "tools/hunt/promises_md.lua"):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
local Hunt = dofile(here .. "/../../tests/hunt/lib.lua")

local outPath
do
	local argv, i = arg or {}, 1
	while argv[i] do
		local a = argv[i]
		if a == "--out" then outPath = argv[i + 1] i = i + 1
		elseif a:match("^%-%-out=") then outPath = a:match("^%-%-out=(.*)$")
		elseif a == "--help" or a == "-h" then
			for line in (Hunt.readFile(here .. "/promises_md.lua") or ""):gmatch("[^\n]*") do
				if not line:match("^%-%-") then break end
				print(line)
			end
			os.exit(0)
		else io.stderr:write("unknown option " .. a .. "\n") os.exit(2) end
		i = i + 1
	end
end

local ok, err = pcall(Hunt.init, {})
if not ok then io.stderr:write(tostring(err) .. "\n") os.exit(2) end
outPath = Hunt.norm(outPath or (Hunt.ROOT .. "/PROMISES.md"))
local oneLine = Hunt.oneLine
local BT = string.char(96) -- a backtick (Markdown code)

local function clean(s) return (oneLine(s or "", 600):gsub("|", "/")) end
local function sentence(s)
	s = clean(s)
	s = s:gsub("%s+$", "")
	return s
end

-- "dial = value" in plain words: the value's about, else the dial's about
local function plainValue(dname, vid)
	local d = Hunt.dials[dname]
	if not d then return dname .. " = " .. tostring(vid) end
	local v = d.byId[vid]
	local about = v and v.about
	local text = dname .. " = " .. tostring(vid)
	if about and about ~= "" then return text .. " (" .. clean(about) .. ")" end
	if d.about and d.about ~= "" then return text .. " (" .. clean(d.about) .. ")" end
	return text
end

local function inferred(p)
	return p.source == nil or p.source == "" or tostring(p.source):lower():match("^inferred") ~= nil
end

-- what a promise needs and what limits it (when() probed one dial at a time around the defaults)
local function limits(p)
	local lines = {}
	if p.needs then
		local names = Hunt.sortedKeys(p.needs)
		for _, name in ipairs(names) do
			local want = p.needs[name]
			local list = type(want) == "table" and want or { want }
			local parts = {}
			for _, v in ipairs(list) do parts[#parts + 1] = plainValue(name, v) end
			lines[#lines + 1] = "needs " .. table.concat(parts, " or ")
		end
	end
	if not p.when then
		if #lines == 0 then lines[1] = "everywhere" end
		return lines
	end
	local okb, base = pcall(Hunt.project, p, {})
	local function applies(sit)
		local okp, full = pcall(Hunt.project, p, sit)
		return okp and full ~= nil
	end
	if okb and base then
		local nots = {}
		for _, d in ipairs(Hunt.dialOrder) do
			if not (p.needs and p.needs[d.name]) then
				local bad = {}
				for _, v in ipairs(d.values) do
					if v.id ~= base[d.name] then
						local s = Hunt.copy(base)
						s[d.name] = v.id
						-- an exclusion between dials is not the promise's limit: only when() and needs count
						if Hunt.compatible(Hunt.full(s)) and not applies(s) then bad[#bad + 1] = v.id end
					end
				end
				if #bad > 0 then
					local parts = {}
					for _, vid in ipairs(bad) do parts[#parts + 1] = plainValue(d.name, vid) end
					nots[#nots + 1] = "not when " .. table.concat(parts, ", or ")
				end
			end
		end
		for _, l in ipairs(nots) do lines[#lines + 1] = l end
		if #nots == 0 then lines[#lines + 1] = "limited by its own condition in ways one dial does not show (it applies in the default situation)" end
	else
		local onlys = {}
		for _, d in ipairs(Hunt.dialOrder) do
			if not (p.needs and p.needs[d.name]) then
				local good = {}
				for _, v in ipairs(d.values) do
					if v.id ~= d.default then
						local s = {}
						for name, want in pairs(p.needs or {}) do s[name] = type(want) == "table" and want[1] or want end
						s[d.name] = v.id
						local okf, full = pcall(Hunt.full, s)
						if okf and Hunt.compatible(full) and applies(s) then good[#good + 1] = v.id end
					end
				end
				if #good > 0 then
					local parts = {}
					for _, vid in ipairs(good) do parts[#parts + 1] = plainValue(d.name, vid) end
					onlys[#onlys + 1] = table.concat(parts, ", or ")
				end
			end
		end
		if #onlys > 0 then
			lines[#lines + 1] = "only when " .. table.concat(onlys, "; or when ")
		else
			lines[#lines + 1] = "only in situations where two or more dials are set together (never in the default situation)"
		end
	end
	return lines
end

-- the repro files by promise id: a file is <id>.lua or <id>--<situation>.lua
local reproOf, nFails = {}, 0
local huntIds = Hunt.huntIds() -- repro id -> "HUNT-nn" from the shared bug list (empty when the list is not there)
local huntOf = {}
for _, path in ipairs(Hunt.listLua(Hunt.ROOT .. "/tests/hunt/repro")) do
	local name = path:match("[^/]*$")
	for _, p in ipairs(Hunt.promiseOrder) do
		if name == p.id .. ".lua" or name:sub(1, #p.id + 2) == p.id .. "--" then
			reproOf[p.id] = reproOf[p.id] or {}
			table.insert(reproOf[p.id], name)
			local h = huntIds[name:gsub("%.lua$", "")]
			if h then
				huntOf[p.id] = huntOf[p.id] or {}
				for id in h:gmatch("HUNT%-%d+") do
					local dup = false
					for _, e in ipairs(huntOf[p.id]) do if e == id then dup = true end end
					if not dup then table.insert(huntOf[p.id], id) end
				end
			end
		end
	end
end
for _ in pairs(reproOf) do nFails = nFails + 1 end

-- areas: Universal first, then by name
local byArea, areas = {}, {}
local total, nInferred, nGap, kinds = 0, 0, 0, { scenario = 0, always = 0 }
for _, p in ipairs(Hunt.promiseOrder) do
	local area = p.area or (p.id:match("^([^%.]+)") or "Other"):gsub("^%l", string.upper)
	if not byArea[area] then byArea[area] = {} areas[#areas + 1] = area end
	table.insert(byArea[area], p)
	total = total + 1
	if inferred(p) then nInferred = nInferred + 1 end
	if p.gap then nGap = nGap + 1 end
	kinds[p.kind] = (kinds[p.kind] or 0) + 1
end
table.sort(areas, function(a, b)
	local ua, ub = a:lower() == "universal", b:lower() == "universal"
	if ua ~= ub then return ua end
	return a:lower() < b:lower()
end)

local md = {
	"# What Wuber promises the player",
	"",
	"Generated by " .. BT .. "lua5.1 tools/hunt/promises_md.lua" .. BT .. " from the bug hunt's promise files (tests/promises/*.lua); do not edit by hand.",
	"",
	("**%d promises in %d areas** (%d checked after every step: kind always; %d that act: kind scenario). %d are inferred (from what Wuber shows, not from a brief or report); %d the fake game cannot show fully."):format(
		total, #areas, kinds.always or 0, kinds.scenario or 0, nInferred, nGap),
	"",
	"A promise is one plain sentence a player could check for themselves, with a check that tries it in the offline fake game.",
	"The bug hunt (tests/hunt/README.md) builds thousands of situations from the dials (the saved data, the role, the phone,",
	"the network, the world ...) and checks every promise that applies; a broken promise comes back with a shrunk, one-file",
	"repro test. Kind \"always\" promises only look (they run after every check and after every step of a long session);",
	"kind \"scenario\" promises act (click, wait, reload) on a fresh build.",
	"",
	"Run one promise (from the repo root, Git Bash; " .. BT .. "lua5.1" .. BT .. " is the project's Lua 5.1):",
	"",
	BT .. BT .. BT,
	"lua5.1 tools/hunt/sweep.lua --one \"default\" --promise <id> --verbose             # one situation",
	"lua5.1 tools/hunt/sweep.lua --mode pairs --promise <id> --no-shrink               # its pairwise set",
	"lua5.1 tools/hunt/sweep.lua --list                                                # the dials and their values",
	BT .. BT .. BT,
	"",
	"\"Where\" says which situations a promise applies to: what it needs (dials it sets itself) and what limits it (dial values",
	"where it does not apply), in the dials' own words; \"everywhere\" when nothing does.",
	"",
}
md[#md + 1] = ("Areas (promises, and how many of them FAIL TODAY: have a repro file in tests/hunt/repro; %d in all):"):format(nFails)
md[#md + 1] = ""
for _, area in ipairs(areas) do
	local nf = 0
	for _, p in ipairs(byArea[area]) do if reproOf[p.id] then nf = nf + 1 end end
	md[#md + 1] = ("- %s: %d%s"):format(area, #byArea[area], nf > 0 and (", FAIL TODAY: " .. nf) or "")
end
md[#md + 1] = ""
for _, area in ipairs(areas) do
	local list = byArea[area]
	md[#md + 1] = "## " .. area .. " (" .. #list .. ")"
	md[#md + 1] = ""
	for _, p in ipairs(list) do
		local s = sentence(p.text)
		if p.gap then s = s .. " (the fake game cannot show this: " .. clean(p.gap) .. ")" end
		local fl = reproOf[p.id]
		md[#md + 1] = "- **" .. s .. "**" .. (fl and (" FAILS TODAY" .. (huntOf[p.id] and (" (" .. table.concat(huntOf[p.id], ", ") .. ")") or " (not on the list yet)") .. ": " .. fl[1] .. (#fl > 1 and (" (and " .. (#fl - 1) .. " more repro files)") or "")) or "")
		md[#md + 1] = "  - id " .. BT .. p.id .. BT .. ", kind " .. tostring(p.kind) .. ", source: " .. (inferred(p) and "inferred" or clean(p.source))
		local okl, l = pcall(limits, p)
		if not okl then l = { "(its when() raised: " .. oneLine(l, 200) .. ")" } end
		md[#md + 1] = "  - where: " .. table.concat(l, "; ")
	end
	md[#md + 1] = ""
end
if #Hunt.loadErrors > 0 then
	md[#md + 1] = "## Files that did not load (their promises are missing above)"
	md[#md + 1] = ""
	for _, e in ipairs(Hunt.loadErrors) do md[#md + 1] = "- " .. e.file .. ": " .. clean(e.err:match("^[^\n]*")) end
	md[#md + 1] = ""
end
Hunt.writeFile(outPath, table.concat(md, "\n") .. "\n")
print(("%s: %d promises in %d areas, %d inferred, %d the fake game cannot show"):format(outPath, total, #areas, nInferred, nGap))
