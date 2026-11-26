-- tools/rec/probe-diff.lua: a short FACT diff between two probe fixtures (job 2907, Fable "Probe pack" item 10).
-- A fixture of tools/rec/probe-import.lua is 200+ KB of tables; a diff of that text is unreadable. This prints facts:
--   "3 file ids changed" / "11 px Inter-Regular +0.4% (12 strings)" / "event X no longer valid" / "accessor Y now secret on 4 frames"
--
--   lua5.1 tools/rec/probe-diff.lua <old fixture> <new fixture>        print the facts; exit 0 (no change), 1 (changes), 2 (bad input)
--   lua5.1 tools/rec/probe-diff.lua --help
--   local PD = loadfile("tools/rec/probe-diff.lua")("--lib")           PD.diff(old, new) -> list of lines (tables in, no files)
-- Facts it reports: the build/fingerprint, file ids changed or gone, width change per font and size (mean change of the strings both have,
-- only when it is at least 0.1%), events that stopped being valid or registrable (or became valid), accessors and API calls that are newly
-- secret (or no longer secret), hit-order cells whose winner changed, key answers that changed. It only reads.
local PD = {}

local function keys(t) local o = {} for k in pairs(t or {}) do o[#o + 1] = k end table.sort(o, function(a, b) return tostring(a) < tostring(b) end) return o end
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function plural(n, one, many) return n .. " " .. (n == 1 and one or (many or one .. "s")) end

function PD.diff(old, new)
	local out = {}
	local function say(s) out[#out + 1] = s end
	old, new = old or {}, new or {}
	local ob, nb = old.env and old.env.build, new.env and new.env.build
	if type(ob) == "table" and type(nb) == "table" and ob[2] ~= nb[2] then say(("build %s -> %s"):format(tostring(ob[2]), tostring(nb[2]))) end
	if old.fingerprint ~= new.fingerprint and (old.fingerprint or new.fingerprint) then say(("fingerprint %s -> %s"):format(tostring(old.fingerprint), tostring(new.fingerprint))) end
	-- file ids
	local changed, gone, added = {}, 0, 0
	for p, id in pairs(old.fileIds or {}) do
		local nid = (new.fileIds or {})[p]
		if nid == nil then gone = gone + 1 elseif nid ~= id then changed[#changed + 1] = p end
	end
	for p in pairs(new.fileIds or {}) do if (old.fileIds or {})[p] == nil then added = added + 1 end end
	table.sort(changed)
	if #changed > 0 then say(plural(#changed, "file id") .. " changed" .. (" (e.g. " .. changed[1]:match("[^\\]+$") .. ")")) end
	if gone > 0 then say(plural(gone, "file id") .. " no longer answered") end
	if added > 0 then say(plural(added, "file id") .. " new") end
	-- widths: per font and size the mean relative change of the strings both fixtures measured
	for _, font in ipairs(keys(new.widths)) do
		local osz = (old.widths or {})[font]
		if osz then
			for _, size in ipairs(keys(new.widths[font])) do
				local o, n = osz[size], new.widths[font][size]
				if type(o) == "table" and type(n) == "table" and type(o.strings) == "table" and type(n.strings) == "table" then
					local sum, k = 0, 0
					for text, w in pairs(n.strings) do
						local ow = o.strings[text]
						if type(w) == "number" and type(ow) == "number" and ow > 0 then sum, k = sum + (w - ow) / ow, k + 1 end
					end
					if k > 0 and math.abs(sum / k) >= 0.001 then
						say(("%s px %s %+.1f%% (%s)"):format(tostring(size), (font:gsub("%.%w+$", "")), 100 * sum / k, plural(k, "string")))
					end
				end
			end
		end
	end
	-- events
	for _, e in ipairs(keys(old.events)) do
		local o, n = old.events[e], (new.events or {})[e]
		if type(o) == "table" then
			if n == nil then say("event " .. e .. " no longer listed")
			elseif o.valid == true and n.valid == false then say("event " .. e .. " no longer valid")
			elseif o.valid == false and n.valid == true then say("event " .. e .. " is valid now")
			elseif o.reg == true and n.reg == false then say("event " .. e .. " can no longer be registered")
			elseif o.fired and o.fired > 0 and n.fired == 0 then say("event " .. e .. " no longer fired in the watch run") end
		end
	end
	-- secrets
	local function setOf(l) local s = {} for _, v in ipairs(l or {}) do s[v] = true end return s end
	for _, acc in ipairs(keys(new.secretAccessors)) do
		local before = setOf((old.secretAccessors or {})[acc])
		local fresh = 0
		for _, f in ipairs(new.secretAccessors[acc]) do if not before[f] then fresh = fresh + 1 end end
		if fresh > 0 then say(("accessor %s now secret on %s"):format(acc, plural(fresh, "frame"))) end
	end
	for _, acc in ipairs(keys(old.secretAccessors)) do
		local after = setOf((new.secretAccessors or {})[acc])
		local lost = 0
		for _, f in ipairs(old.secretAccessors[acc]) do if not after[f] then lost = lost + 1 end end
		if lost > 0 then say(("accessor %s no longer secret on %s"):format(acc, plural(lost, "frame"))) end
	end
	for _, name in ipairs(keys(new.secretApi)) do if not (old.secretApi or {})[name] then say("call " .. name .. " now answers a secret") end end
	for _, name in ipairs(keys(old.secretApi)) do if not (new.secretApi or {})[name] then say("call " .. name .. " no longer answers a secret") end end
	-- hit order
	local flips = 0
	for id, cells in pairs(old.hit or {}) do
		for cell, who in pairs(cells) do
			local nw = ((new.hit or {})[id] or {})[cell]
			if nw ~= nil and nw ~= who then flips = flips + 1 end
		end
	end
	if flips > 0 then say(plural(flips, "hit-order cell") .. " changed winner") end
	-- keys
	local kc = {}
	for k, o in pairs(old.keys or {}) do
		local n = (new.keys or {})[k]
		if type(o) == "table" and type(n) == "table" then
			for f, v in pairs(o) do if n[f] ~= v then kc[#kc + 1] = k break end end
		end
	end
	table.sort(kc)
	if #kc > 0 then say("key answers changed: " .. table.concat(kc, ", ")) end
	return out
end

local HELP = [[
probe-diff.lua <old fixture> <new fixture>: a short fact diff of two probe fixtures (tests/fixtures/probe/*.lua).
  prints one line per fact: the build, file ids changed, width change per font and size, events no longer valid,
  accessors newly secret, hit-order cells that changed winner, key answers that changed.
  exit 0 = no difference in these facts, 1 = something changed, 2 = a fixture could not be read.
  --help  this text.]]

local function load(path)
	local chunk, err = loadfile(path)
	if not chunk then return nil, err end
	local ok, fx = pcall(chunk)
	if not ok or type(fx) ~= "table" then return nil, path .. ": not a fixture table" end
	return fx
end

function PD.main(argv, say)
	local out = say or print
	if #argv == 0 or argv[1] == "--help" or argv[1] == "-h" then out(HELP) return #argv == 0 and 2 or 0 end
	if #argv ~= 2 then out(HELP) return 2 end
	local old, e1 = load(argv[1])
	if not old then out(tostring(e1)) return 2 end
	local new, e2 = load(argv[2])
	if not new then out(tostring(e2)) return 2 end
	local lines = PD.diff(old, new)
	if #lines == 0 then out("no difference in the facts") return 0 end
	for _, l in ipairs(lines) do out(l) end
	return 1
end

if (...) == "--lib" then return PD end
os.exit(PD.main({ ... }))
