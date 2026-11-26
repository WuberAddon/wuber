-- tests/lib/evidence.lua: the evidence ledger's library (job 2882). Rules: tests/fixtures/client/rules.lua. Harness: H.rule("<id>").
--   local E = dofile(T.dir .. "/lib/evidence.lua")      -- one shared instance per process (package.loaded["wuber_evidence"])
--   local rules = E.load("tests/fixtures/client/rules.lua")
--   E.check(rules)                  -> list of problems ("" list = a well-formed ledger): a rule with no evidence, a bad level, a duplicate id ...
--   E.note(fx, label)               -> remember a probe fixture the fake game learned from (tests/lib/probe_learn.lua L.load / L.note call it)
--   E.rows(rules, E.learned, build) -> one row per rule with its EFFECTIVE evidence (see below)
--   E.readHits(path) / E.leaning(rows, hits) / E.guessTests(rows, hits)   -> which tests lean on which rule
--   E.probeBuild(savedVariablesText) -> build, run id (the newest run in a WuberProbe.lua)   E.staleness(fixtureBuild, installedBuild) -> "STALE ..." | "OK ..."
-- Effective evidence of a rule:
--   "measured"      a fixture with source = "game" (and a build) that has the rule's fed_by field non-empty was noted. The fixture's build is kept.
--                   A fixture whose source is "sim", "synthetic", missing or anything else NEVER counts (false-confidence guard).
--   "measured, old" as above, but the build is not the installed client's build (when one is given)
--   otherwise the level written in rules.lua (one-real-case | docs | borrowed | guess). "measured" written there is a problem: it cannot be claimed by hand.
local KEY = "wuber_evidence"
if package.loaded[KEY] then return package.loaded[KEY] end
local E = {}
package.loaded[KEY] = E

E.LEVELS = { "measured", "measured, old", "one-real-case", "docs", "borrowed", "guess" }
local WRITABLE = { ["one-real-case"] = true, docs = true, borrowed = true, guess = true }
E.learned = {} -- { { label, source, build, fx } } in the order noted

local here = (debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/"):match("^(.*)/[^/]*$")) or "."

function E.load(path)
	local chunk, err = loadfile(path)
	if not chunk then return nil, err end
	local ok, rules = pcall(chunk)
	if not ok then return nil, rules end
	if type(rules) ~= "table" then return nil, path .. " did not return a table" end
	return rules
end

function E.check(rules)
	local bad, seen = {}, {}
	for i, r in ipairs(rules) do
		local id = type(r) == "table" and r.id
		local tag = id and ("rule " .. tostring(id)) or ("rule #" .. i)
		if type(r) ~= "table" then bad[#bad + 1] = tag .. ": not a table"
		else
			if type(id) ~= "string" or id == "" then bad[#bad + 1] = tag .. ": no id"
			elseif seen[id] then bad[#bad + 1] = tag .. ": duplicate id" else seen[id] = true end
			if type(r.what) ~= "string" or r.what == "" then bad[#bad + 1] = tag .. ": no 'what'" end
			if r.evidence == nil then bad[#bad + 1] = tag .. ": no evidence field"
			elseif r.evidence == "measured" then bad[#bad + 1] = tag .. ": evidence = measured written by hand (only a game fixture can make a rule measured)"
			elseif not WRITABLE[r.evidence] then bad[#bad + 1] = tag .. ": evidence '" .. tostring(r.evidence) .. "' is not one-real-case, docs, borrowed or guess" end
			if type(r.source) ~= "string" or r.source == "" then bad[#bad + 1] = tag .. ": no source" end
			if type(r.bug) ~= "string" or r.bug == "" then bad[#bad + 1] = tag .. ": no bug id (use \"-\" for none)" end
			if r.evidence == "one-real-case" and not r.build then bad[#bad + 1] = tag .. ": one-real-case without the build it was seen on" end
			if r.was ~= nil and not WRITABLE[r.was] then bad[#bad + 1] = tag .. ": 'was' is not a level" end
		end
	end
	return bad
end

-- the ids named in H.rule("<id>") calls of a Lua file: id -> number of call sites
function E.hookSites(path)
	local f = io.open(path, "rb")
	if not f then return nil, "cannot read " .. tostring(path) end
	local text = f:read("*a") f:close()
	local sites = {}
	for id in text:gmatch('H%.rule%("([^"]+)"%)') do sites[id] = (sites[id] or 0) + 1 end
	return sites
end

local function nonEmpty(v)
	if type(v) == "table" then return next(v) ~= nil end
	return v ~= nil and v ~= "<nil>" and v ~= false
end
function E.fedBy(fx, path)
	local v = fx
	for part in tostring(path):gmatch("[^%.]+") do
		if type(v) ~= "table" then return false end
		v = v[part]
	end
	return nonEmpty(v)
end

-- a fixture the fake game learned from. Anything is recorded; only source = "game" with a build can measure (see E.rows).
function E.note(fx, label)
	if type(fx) ~= "table" then return end
	for _, l in ipairs(E.learned) do if l.fx == fx then return end end
	E.learned[#E.learned + 1] = { label = label or "?", source = fx.source, build = fx.build, fx = fx }
end

function E.reset() E.learned = {} end

local function newer(a, b) return (tonumber(a) or 0) > (tonumber(b) or 0) end

-- the newest build among the fixtures that can measure (source = "game")
function E.newestGameBuild(learned)
	local best
	for _, l in ipairs(learned or E.learned) do
		if l.source == "game" and l.build and (not best or newer(l.build, best)) then best = l.build end
	end
	return best
end

-- rows: { rule, evidence (effective), build, from (fixture label) } in rules.lua order. installed: the client's build, to mark old ones.
function E.rows(rules, learned, installed)
	local rows = {}
	for _, r in ipairs(rules) do
		local row = { rule = r, evidence = WRITABLE[r.evidence] and r.evidence or "guess", build = r.build }
		if r.fed_by then
			for _, l in ipairs(learned or {}) do
				if l.source == "game" and l.build and E.fedBy(l.fx, r.fed_by) and (row.evidence ~= "measured" or newer(l.build, row.build)) then
					row.evidence, row.build, row.from = "measured", l.build, l.label
				end
			end
			if row.evidence == "measured" and installed and tostring(row.build) ~= tostring(installed) then row.evidence = "measured, old" end
		end
		rows[#rows + 1] = row
	end
	return rows
end

function E.countBy(rows)
	local n = {}
	for _, l in ipairs(E.LEVELS) do n[l] = 0 end
	for _, row in ipairs(rows) do n[row.evidence] = (n[row.evidence] or 0) + 1 end
	return n
end

-- a hits file: lines "<id>\t<test>\t<count>" (tests/run.lua with WUBER_RULE_LOG=<file>); several files or runs add up
function E.readHits(path, into)
	local hits = into or {}
	local f = io.open(path, "rb")
	if not f then return nil, "cannot read " .. tostring(path) end
	for line in f:lines() do
		local id, test, n = line:match("^([^\t]+)\t(.*)\t(%d+)\r?$")
		if id then
			hits[id] = hits[id] or {}
			hits[id][test] = (hits[id][test] or 0) + tonumber(n)
		end
	end
	f:close()
	return hits
end

-- tests per rule: { [id] = sorted list of test names }
function E.leaning(hits)
	local out = {}
	for id, tests in pairs(hits) do
		local list = {}
		for t in pairs(tests) do list[#list + 1] = t end
		table.sort(list)
		out[id] = list
	end
	return out
end

-- the tests that lean on at least one rule whose effective evidence is in the set (default: guess only): a sorted list
function E.testsOn(rows, hits, levels)
	levels = levels or { guess = true }
	local set = {}
	for _, row in ipairs(rows) do
		if levels[row.evidence] and hits[row.rule.id] then
			for t in pairs(hits[row.rule.id]) do set[t] = true end
		end
	end
	local list = {}
	for t in pairs(set) do list[#list + 1] = t end
	table.sort(list)
	return list
end

-- the newest run of a WuberProbe.lua SavedVariables text: build, run id, run epoch (nil, why when there is none)
function E.probeBuild(text)
	local imp = loadfile(here .. "/../../tools/rec/import.lua")
	local IMP = imp and imp("--lib")
	if not IMP then return nil, "tools/rec/import.lua not found next to the tests" end
	local db, why = IMP.loadSaved(text, "WuberProbeDB")
	if not db then return nil, why end
	local best
	for _, run in ipairs(type(db.runs) == "table" and db.runs or {}) do
		if type(run) == "table" and run.build and (not best or (tonumber(run.epoch) or 0) >= (tonumber(best.epoch) or 0)) then best = run end
	end
	if not best then return nil, "no run with a build in it" end
	return tostring(best.build), best.id, best.epoch
end

function E.staleness(fixtureBuild, installedBuild)
	if not fixtureBuild then return "NO GAME FIXTURE: no fixture with source = \"game\" is loaded, so nothing the fake knows is measured" end
	if not installedBuild then return "UNKNOWN: no installed client build to compare with" end
	if tostring(fixtureBuild) == tostring(installedBuild) then
		return ("OK: client facts are for build %s, installed client is %s"):format(fixtureBuild, installedBuild)
	end
	return ("STALE: client facts are for build %s, installed client is %s"):format(fixtureBuild, installedBuild)
end

return E
