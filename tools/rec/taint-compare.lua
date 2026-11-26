-- tools/rec/taint-compare.lua (job 2908, Fable item 8): the probe's issecurevariable sweep next to tests/fakegame/taint-allow.lua.
--
--   lua5.1 tools/rec/taint-compare.lua --fixture tests/fixtures/probe/<file>.lua [--allow tests/fakegame/taint-allow.lua]
--   local TC = loadfile("tools/rec/taint-compare.lua")("--lib")     TC.compare(sweepRows, allow) -> { risks, unneeded, unmeasured, tainted, secure }
--
-- sweepRows = fixture.taintSweep.rows: [name] = true (the game's own value is secure) | "<who tainted it>" | "<nil>" (no such value on this client).
--   risks      names the sweep found tainted that the allow list does not mention (something touched a game value and nobody wrote down why)
--   unneeded   allow entries whose game value measured secure (the entry may be removable: nothing tainted it in the probe session)
--   unmeasured allow entries the sweep never asked about or that do not exist on this client
-- A fixture made by the simulator (source ~= "game") is reported as NOT MEASURED: it proves the tool, never the game.
local TC = {}

local function allowNames(allow)
	local set = {}
	for n in pairs(allow.tables or {}) do set[n] = "tables" end
	for n in pairs(allow.globals or {}) do set[n] = "globals" end
	for n in pairs(allow.parents or {}) do set[n] = "parents" end
	for k in pairs(allow.fields or {}) do set[k] = "fields" end
	return set
end

function TC.compare(rows, allow)
	rows = rows or {}
	local listed = allowNames(allow or {})
	local r = { risks = {}, unneeded = {}, unmeasured = {}, tainted = 0, secure = 0 }
	for name, v in pairs(rows) do
		if v == true then r.secure = r.secure + 1
		elseif v ~= "<nil>" then
			r.tainted = r.tainted + 1
			local base = name:match("^([^.]+)")
			if not listed[name] and not listed[base] then r.risks[#r.risks + 1] = { name = name, by = v } end
		end
	end
	for name, kind in pairs(listed) do
		local v = rows[name]
		if v == nil or v == "<nil>" then r.unmeasured[#r.unmeasured + 1] = name
		elseif v == true then r.unneeded[#r.unneeded + 1] = name end
	end
	table.sort(r.risks, function(a, b) return a.name < b.name end)
	table.sort(r.unneeded) table.sort(r.unmeasured)
	return r
end

function TC.report(fx, allow)
	local lines = {}
	local sweep = fx.taintSweep
	if type(sweep) ~= "table" then return { "no taint sweep in this fixture (WuberProbe Taint.lua was not part of the run)" } end
	if sweep.has == false then return { "issecurevariable does not exist on this client: nothing to compare" } end
	if fx.source ~= "game" then lines[#lines + 1] = "NOT MEASURED: source = " .. tostring(fx.source) .. " (a simulator or stand-in fixture proves the tool, never the game)" end
	local r = TC.compare(sweep.rows, allow)
	lines[#lines + 1] = ("%d names asked: %d secure, %d tainted"):format(sweep.n or 0, r.secure, r.tainted)
	for _, x in ipairs(r.risks) do lines[#lines + 1] = ("risk: %s tainted by %s and not in taint-allow.lua"):format(x.name, tostring(x.by)) end
	for _, n in ipairs(r.unneeded) do lines[#lines + 1] = "allow entry measured secure (maybe removable): " .. n end
	for _, n in ipairs(r.unmeasured) do lines[#lines + 1] = "allow entry not measured (absent or not asked): " .. n end
	return lines
end

function TC.main(args, out)
	out = out or print
	local fixture, allowPath = nil, "tests/fakegame/taint-allow.lua"
	local i = 1
	while args[i] do
		if args[i] == "--fixture" then fixture = args[i + 1] i = i + 2
		elseif args[i] == "--allow" then allowPath = args[i + 1] i = i + 2
		elseif args[i] == "--help" then out("taint-compare.lua --fixture <probe fixture> [--allow taint-allow.lua]: the probe sweep against the taint allow list") return 0
		else out("unknown argument " .. tostring(args[i])) return 1 end
	end
	if not fixture then out("--fixture is required (see --help)") return 1 end
	local fc, e1 = loadfile(fixture)
	if not fc then out(tostring(e1)) return 1 end
	local ac, e2 = loadfile(allowPath)
	if not ac then out(tostring(e2)) return 1 end
	for _, l in ipairs(TC.report(fc(), ac())) do out(l) end
	return 0
end

if (...) == "--lib" then return TC end
os.exit(TC.main(arg or {}))
