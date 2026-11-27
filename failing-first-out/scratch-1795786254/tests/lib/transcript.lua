-- tests/lib/transcript.lua: the behaviour transcript (REFACTOR-MAP section 4.5).
--
-- While the suite runs, one record per test is written: what every world and client of that
-- test did and how it ended. A restructure that changes no behaviour leaves the transcript
-- byte-identical; `lua5.1 tests/run.lua --compare-transcript` fails on any difference from
-- tests/transcripts/baseline.txt.
--
-- Per test, per world (in creation order):
--   messages  every addon message (all fields, in order), whisper, chat/group post, club invite;
--             counts of failed / lost-macro whispers, invites, summons, trades
--   per client (in creation order):
--     chat     the lines printed to the client's chat frames, in order
--     frames   widget count by type; every named widget: type, parent, shown / visible,
--              strata, level, rect (0.1); every visible text, sorted; a digest of the full
--              state of every widget (creation order, type, name, parent, shown, rect,
--              alpha, text; frames: strata, level, secure)
--     saved    WuberDB (and RitualRidesDB, GigaLocksTeam when present), flattened to sorted
--              `path = value` lines (a list over 12 long: its length, a digest of all of it,
--              its first and last 3); W.ride; W.drivers (key, state, price); W.incoming
--     wiring   events registered on the client's frames (sorted, with counts); W.On handlers and
--              W.Listen listeners per name (counts); W.OnLogin count; W.Fire counts per name;
--              globals the addons wrote (sorted); violations and errors (counts)
-- Deterministic: keys sorted, numbers rounded to 1e-6 (rects 0.1), no table addresses, no
-- file names or line numbers (they change by design in the restructure), no wall-clock time.
-- The build's own version is not in it either (one baseline for master and a release):
-- every string is written with this build's "a.b.c-dev" as <ver> (also inside digests), and when
-- the checkout says a plain "a.b.c" (a stamped release tree) every Wuber window is started as
-- "a.b.c-dev" (the harness's opts.version), so it behaves as master does: a released 2.3.2 beside
-- the tests' "2.3.0" windows would otherwise hear itself as newer (Net.Update: NEWER_VERSION,
-- WuberDB.newer, the "Wuber 2.3.2 is out" toast), which a -dev build never does. Versions a test
-- sets itself ("2.3.0", "2.3.3", "2.3.0-dev") are written as they are.
-- WUBER_TRANSCRIPT_DETAIL=1 writes every widget's line and every list in full (to find what
-- a digest change is).

local TR = {}

local H, S
local out, worlds, seenWorld, counts = nil, {}, {}, {}
local detail = os.getenv("WUBER_TRANSCRIPT_DETAIL") == "1"
local byte, format, concat, sort = string.byte, string.format, table.concat, table.sort
local LONG = 12 -- lists longer than this are written as length + digest + their ends
local VER = { token = "<ver>" } -- this build's version (TR.start): build, dev, pattern

-- W.VERSION as Wuber/Core/Base.lua under root says it (nil: not found)
function TR.buildVersion(root)
	local f = root and io.open(root .. "/Wuber/Core/Base.lua", "rb")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text:match('\nW%.VERSION = "([^"\r\n]*)"')
end

-- the build's -dev version, for the transcript and for the windows of a stamped tree
function TR.versions(build)
	if type(build) ~= "string" or build == "" then return nil end
	local dev = build:match("^%d+%.%d+%.%d+$") and (build .. "-dev") or build
	return { build = build, dev = dev, stamped = dev ~= build, pattern = dev:gsub("%p", "%%%0") }
end

---------------------------------------------------------------------------
-- Values
---------------------------------------------------------------------------

local function num(v, prec)
	if v ~= v then return "nan" end
	if v == math.huge then return "inf" elseif v == -math.huge then return "-inf" end
	if v == math.floor(v) and math.abs(v) < 1e15 then return format("%d", v) end
	local s = format(prec or "%.6f", v):gsub("0+$", ""):gsub("%.$", "")
	if s == "-0" then s = "0" end
	return s
end

local function str(s)
	if VER.dev and s:find(VER.dev, 1, true) then s = TR.tokenise(s) end
	return '"' .. s:gsub('[%c"\\]', function(c)
		if c == "\n" then return "\\n" elseif c == "\t" then return "\\t" elseif c == '"' then return '\\"'
		elseif c == "\\" then return "\\\\" end
		return format("\\%03d", byte(c))
	end) .. '"'
end

local function scalar(v)
	local t = type(v)
	if t == "string" then return str(v)
	elseif t == "number" then return num(v)
	elseif t == "boolean" or t == "nil" then return tostring(v)
	elseif t == "table" and S[v] then
		local s = S[v]
		return "<" .. tostring(s.otype) .. (s.name and (" " .. s.name) or "") .. ">"
	end
	return "<" .. t .. ">"
end

local function keyText(k)
	if type(k) == "string" then
		if k:match("^[%a_][%w_]*$") then return "." .. k end
		return "[" .. str(k) .. "]"
	elseif type(k) == "number" then return "[" .. num(k) .. "]"
	elseif type(k) == "boolean" then return "[" .. tostring(k) .. "]" end
	return nil -- tables, functions as keys: no stable name; counted instead
end

-- a digest of many lines (two 31-bit polynomial hashes, so "%x" is the same on every build):
-- a changed frame state or long list is caught without writing thousands of lines
local function digest(lines)
	local h1, h2 = 5381, 52711
	for _, l in ipairs(lines) do
		local n = #l
		for i = 1, n, 8 do
			local a, b, c, d, e, f, g, h = byte(l, i, i + 7)
			h1 = (h1 * 33 + a) % 2147483647 h2 = (h2 * 31 + a) % 2147483629
			if b then h1 = (h1 * 33 + b) % 2147483647 h2 = (h2 * 31 + b) % 2147483629 end
			if c then h1 = (h1 * 33 + c) % 2147483647 h2 = (h2 * 31 + c) % 2147483629 end
			if d then h1 = (h1 * 33 + d) % 2147483647 h2 = (h2 * 31 + d) % 2147483629 end
			if e then h1 = (h1 * 33 + e) % 2147483647 h2 = (h2 * 31 + e) % 2147483629 end
			if f then h1 = (h1 * 33 + f) % 2147483647 h2 = (h2 * 31 + f) % 2147483629 end
			if g then h1 = (h1 * 33 + g) % 2147483647 h2 = (h2 * 31 + g) % 2147483629 end
			if h then h1 = (h1 * 33 + h) % 2147483647 h2 = (h2 * 31 + h) % 2147483629 end
		end
		h1 = (h1 * 33 + 10) % 2147483647 h2 = (h2 * 31 + 10) % 2147483629
	end
	return format("%08x%08x", h1, h2)
end

-- `prefix.path = value` lines for a table, sorted by path; cycles as <cycle>
local function flatten(v, prefix, lines, path)
	lines = lines or {}
	path = path or {}
	if type(v) ~= "table" or S[v] then
		lines[#lines + 1] = prefix .. " = " .. scalar(v)
		return lines
	end
	if path[v] then
		lines[#lines + 1] = prefix .. " = <cycle>"
		return lines
	end
	path[v] = true
	local keys, odd = {}, 0
	for k in pairs(v) do
		local kt = keyText(k)
		if kt then keys[#keys + 1] = { kt, k } else odd = odd + 1 end
	end
	if #keys == 0 and odd == 0 then lines[#lines + 1] = prefix .. " = {}" end
	sort(keys, function(a, b) return a[1] < b[1] end)
	local n = #v
	if n > LONG and #keys == n and not detail then
		-- a long list (a ride log a test seeded with hundreds of rides): its length, a digest
		-- of every element, and the first and last few written out
		local all = {}
		for i = 1, n do flatten(v[i], "[" .. i .. "]", all, path) end
		lines[#lines + 1] = prefix .. " #" .. n .. " digest " .. digest(all)
		for i = 1, n do
			if i <= 3 or i > n - 3 then flatten(v[i], prefix .. "[" .. i .. "]", lines, path) end
		end
		path[v] = nil
		return lines
	end
	for _, kk in ipairs(keys) do flatten(v[kk[2]], prefix .. kk[1], lines, path) end
	if odd > 0 then lines[#lines + 1] = prefix .. " <" .. odd .. " keys that are tables or functions>" end
	path[v] = nil
	return lines
end

-- one line for a flat record (a log entry): its fields, sorted
local function entry(e)
	if type(e) ~= "table" then return scalar(e) end
	local keys = {}
	for k in pairs(e) do if type(k) == "string" then keys[#keys + 1] = k end end
	sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do
		local v = e[k]
		if type(v) == "table" and not S[v] then
			local sub = {}
			for i, x in ipairs(v) do sub[i] = scalar(x) end
			v = "{" .. concat(sub, ",") .. "}"
		else
			v = scalar(v)
		end
		parts[#parts + 1] = k .. "=" .. v
	end
	return concat(parts, " ")
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

local function strata(s)
	while s do
		if s.strata then return s.strata end
		if not s.parent then break end
		s = S[s.parent]
	end
	return "MEDIUM"
end

local function level(s, depth)
	depth = depth or 0
	if s.level or depth > 60 then return s.level or 0 end
	local p = s.parent and S[s.parent]
	return p and (level(p, depth + 1) + 1) or 0
end

local function rectText(obj)
	local okr, r = pcall(H.rect, obj)
	if not okr then return "err" end
	if not r then return "-" end
	local ok2, t = pcall(function()
		return num(r.l, "%.1f") .. "," .. num(r.b, "%.1f") .. "," .. num(r.w, "%.1f") .. "," .. num(r.h, "%.1f")
	end)
	return ok2 and t or "secret"
end

local function textOf(s)
	local t = s.text
	if t == nil then return "" end
	if type(t) ~= "string" then return scalar(t) end
	return str(t)
end

local function frames(c, emit)
	local index = {}
	for i, obj in ipairs(c.widgets or {}) do index[obj] = i end
	local all, kinds = {}, {}
	for i, obj in ipairs(c.widgets or {}) do
		local s = S[obj]
		if s then
			kinds[s.otype] = (kinds[s.otype] or 0) + 1
			local parent = s.parent and (index[s.parent] or (S[s.parent] and S[s.parent].name) or "game") or "-"
			local vis = H.visible(obj)
			local line = i .. " " .. tostring(s.otype) .. " " .. (s.name or "") .. " ^" .. tostring(parent)
				.. " " .. (s.shown and "shown" or "hidden") .. (vis and "+vis" or "")
			local full = line .. " " .. rectText(obj) .. " a" .. num(s.alpha or 1, "%.3f") .. " " .. textOf(s)
			if s.kind == "frame" then full = full .. " " .. strata(s) .. ":" .. level(s) .. (s.secure and " secure" or "") end
			all[#all + 1] = full
			if detail then emit("    w " .. full)
			elseif s.name then emit("    f " .. full) end
		end
	end
	local ks = {}
	for k, n in pairs(kinds) do ks[#ks + 1] = k .. "=" .. n end
	sort(ks)
	emit("    widgets " .. #all .. " (" .. concat(ks, " ") .. ") digest " .. digest(all))
	local okv, texts = pcall(c.visibleTexts, c)
	if okv then
		local tt = {}
		for i, t in ipairs(texts) do tt[i] = type(t) == "string" and str(t) or scalar(t) end
		sort(tt)
		for _, t in ipairs(tt) do emit("    text " .. t) end
	end
end

---------------------------------------------------------------------------
-- Wiring (the addon's own event tables, read through the upvalues of W.On / W.Listen)
---------------------------------------------------------------------------

local function upvalue(fn, name, depth)
	depth = depth or 0
	if type(fn) ~= "function" or depth > 3 then return nil end
	for i = 1, 60 do
		local n, v = debug.getupvalue(fn, i)
		if not n then break end
		if n == name then return v end
	end
	for i = 1, 60 do -- a wrapper (the harness's W.Fire recorder; a test's patch): look inside
		local n, v = debug.getupvalue(fn, i)
		if not n then break end
		if type(v) == "function" then
			local found = upvalue(v, name, depth + 1)
			if found ~= nil then return found end
		end
	end
	return nil
end

local function countsOf(t)
	if type(t) ~= "table" then return "?" end
	local out = {}
	for k, v in pairs(t) do
		if type(k) == "string" then out[#out + 1] = k .. "=" .. (type(v) == "table" and #v or scalar(v)) end
	end
	sort(out)
	return concat(out, " ")
end

local function wiring(c, emit)
	local events = {}
	for _, obj in ipairs(c.widgets or {}) do
		local s = S[obj]
		for ev, on in pairs(s and s.events or {}) do
			if on and type(ev) == "string" then events[ev] = (events[ev] or 0) + 1 end
		end
	end
	emit("    registered " .. countsOf(events))
	local W = c.W
	if type(W) == "table" then
		emit("    W.On " .. countsOf(upvalue(rawget(W, "On"), "handlers")))
		emit("    W.Listen " .. countsOf(upvalue(rawget(W, "Listen"), "listeners")))
		local logins = upvalue(rawget(W, "OnLogin"), "loginFns")
		emit("    W.OnLogin " .. (type(logins) == "table" and #logins or "?"))
	end
	local fired = {}
	for _, f in ipairs(c.fired or {}) do
		local n = tostring(f.name)
		fired[n] = (fired[n] or 0) + 1
	end
	emit("    fired " .. countsOf(fired))
	local gw = {}
	for k in pairs(c.globalWrites or {}) do gw[#gw + 1] = tostring(k) end
	sort(gw)
	emit("    globals " .. concat(gw, " "))
end

---------------------------------------------------------------------------
-- Saved data and live state
---------------------------------------------------------------------------

local SAVED = { "WuberDB", "RitualRidesDB", "GigaLocksTeam" }

local function saved(c, emit)
	local env = c.env or {}
	for _, name in ipairs(SAVED) do
		local v = rawget(env, name)
		if v ~= nil then
			for _, l in ipairs(flatten(v, name)) do emit("    sv " .. l) end
		end
	end
	local W = c.W
	if type(W) ~= "table" then return end
	for _, l in ipairs(flatten(rawget(W, "ride"), "W.ride")) do emit("    st " .. l) end
	local drivers = rawget(W, "drivers")
	if type(drivers) == "table" then
		local keys = {}
		for k, d in pairs(drivers) do
			if type(k) == "string" then
				keys[#keys + 1] = k .. " state=" .. scalar(type(d) == "table" and d.state or d) .. " price="
					.. scalar(type(d) == "table" and d.price or nil)
			end
		end
		sort(keys)
		for _, k in ipairs(keys) do emit("    st W.drivers " .. k) end
	end
	local inc = rawget(W, "incoming")
	if type(inc) == "table" then
		for i, x in ipairs(inc) do
			emit("    st W.incoming[" .. i .. "] id=" .. scalar(type(x) == "table" and x.id or x) .. " buyer="
				.. scalar(type(x) == "table" and x.buyerKey or nil) .. " state=" .. scalar(type(x) == "table" and x.state or nil))
		end
	end
end

---------------------------------------------------------------------------
-- A test's record
---------------------------------------------------------------------------

local function world(wi, w, emit)
	emit("  world " .. wi .. " time " .. num(w.time or 0, "%.3f") .. " clients " .. #(w.clients or {}))
	for _, e in ipairs(w.addonLog or {}) do emit("  addon " .. entry(e)) end
	for _, e in ipairs(w.whispers or {}) do emit("  whisper " .. entry(e)) end
	for _, e in ipairs(w.chatPosts or {}) do emit("  chat " .. entry(e)) end
	for _, e in ipairs(w.clubInvitesSent or {}) do emit("  clubinvite " .. entry(e)) end
	emit("  counts failedWhispers=" .. (w.failedWhispers or 0) .. " lostMacroWhispers=" .. (w.lostMacroWhispers or 0)
		.. " invites=" .. #(w.invites or {}) .. " summons=" .. #(w.summons or {}) .. " casts=" .. tostring(w.casts or 0)
		.. " trades=" .. tostring(w.trades or 0) .. " violations=" .. #(w.violations or {}) .. " errors=" .. #(w.errors or {}))
	for ci, c in ipairs(w.clients or {}) do
		emit("  client " .. ci .. " " .. tostring(c.player and c.player.name) .. (c.alive == false and " (gone)" or ""))
		for _, l in ipairs(c.chatLines or {}) do emit("    print " .. str(tostring(l))) end
		frames(c, emit)
		saved(c, emit)
		wiring(c, emit)
	end
end

-- The build's version: its -dev form is written as <ver> from now on. Returns TR.versions(build).
function TR.useVersion(build)
	local v = TR.versions(build)
	VER.dev, VER.pattern = v and v.dev, v and v.pattern
	return v
end

-- the build's -dev version as <ver>, only where it stands alone: not inside a longer number (a digit,
-- or a dot and a digit, right before or after it: "12.3.2-dev", "1.2.3.2-dev", "2.3.2-dev2", "2.3.2-dev.2")
local function digitAt(s, i) local b = i >= 1 and byte(s, i) or nil return b ~= nil and b >= 48 and b <= 57 end
function TR.tokenise(s)
	local dev = VER.dev
	if not dev then return s end
	local out, pos = {}, 1
	while true do
		local a, b = s:find(dev, pos, true)
		if not a then break end
		local before = digitAt(s, a - 1) or (a > 1 and byte(s, a - 1) == 46 and digitAt(s, a - 2))
		local after = digitAt(s, b + 1) or (byte(s, b + 1) == 46 and digitAt(s, b + 2))
		out[#out + 1] = s:sub(pos, a - 1)
		out[#out + 1] = (before or after) and dev or VER.token
		pos = b + 1
	end
	out[#out + 1] = s:sub(pos)
	return concat(out)
end

-- A string as the transcript writes it (quoted, escaped, the build's version as <ver>)
function TR.str(s) return str(s) end

-- A stamped tree: every window World:addClient makes runs as `dev` (the harness's opts.version, set
-- after the files load and before ADDON_LOADED); a test's own opts.version still wins, and the
-- caller's opts table is left as it was.
function TR.devWindows(World, dev)
	if type(World) ~= "table" or type(World.addClient) ~= "function" then return false end
	local addClient = World.addClient
	World.addClient = function(self, name, opts)
		opts = opts or {}
		if opts.version ~= nil then return addClient(self, name, opts) end
		opts.version = dev
		local c = addClient(self, name, opts)
		opts.version = nil
		return c
	end
	return true
end

-- Starts recording into `path` (the file is replaced).
function TR.start(harness, path)
	H, S = harness, harness.state
	local v = TR.useVersion(TR.buildVersion(H.root))
	if v and v.stamped then TR.devWindows(H.World, v.dev) end
	out = io.open(path, "wb")
	if not out then -- its folder (tests/out) is made on first use, on Windows or elsewhere
		local folder = path:match("^(.*)[/\\][^/\\]*$")
		if folder then
			if package.config:sub(1, 1) == "\\" then os.execute('mkdir "' .. folder:gsub("/", "\\") .. '" 2>nul')
			else os.execute('mkdir -p "' .. folder .. '"') end
		end
		out = assert(io.open(path, "wb"))
	end
	local newWorld = H.NewWorld
	H.NewWorld = function(...)
		local w = newWorld(...)
		if not seenWorld[w] then
			seenWorld[w] = true
			worlds[#worlds + 1] = w
		end
		return w
	end
	return TR
end

function TR.active() return out ~= nil end

-- One test ended (before H.release): its record. Test names may repeat: "name #2".
function TR.record(name, passed)
	if not out then return end
	counts[name] = (counts[name] or 0) + 1
	local id = counts[name] > 1 and (name .. " #" .. counts[name]) or name
	local buf = {}
	local function emit(l) buf[#buf + 1] = l end
	emit("=== " .. id .. (passed and "" or " (FAILED)"))
	for _, c in ipairs(H.made or {}) do -- a world made some other way: still recorded
		local w = c.world
		if w and not seenWorld[w] then
			seenWorld[w] = true
			worlds[#worlds + 1] = w
		end
	end
	for wi, w in ipairs(worlds) do world(wi, w, emit) end
	local text = concat(buf, "\n")
	-- never file names, line numbers or addresses (an error text or a tostring(table) that
	-- reached a message): the restructure moves code between files by design
	text = text:gsub("[%w_%.%-/\\]*%.lua:%d+", "<src>"):gsub("(%a+): 0x%x+", "%1: <addr>")
	out:write(text, "\n")
	worlds, seenWorld = {}, {}
end

-- A test another process runs (run.lua --shard): its name still counts for "name #2", and the
-- worlds made for it (before it, outside any test) are its own, not the next test's.
function TR.skip(name)
	if not out then return end
	counts[name] = (counts[name] or 0) + 1
	worlds, seenWorld = {}, {}
end

function TR.finish()
	if out then out:close() out = nil end
end

---------------------------------------------------------------------------
-- Comparing two transcripts
---------------------------------------------------------------------------

local function records(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local recs, order, cur = {}, {}, nil
	for line in f:lines() do
		local id = line:match("^=== (.*)$")
		if id then
			id = id:gsub(" %(FAILED%)$", "")
			cur = {}
			recs[id] = cur
			order[#order + 1] = id
		elseif cur then
			cur[#cur + 1] = line
		end
	end
	f:close()
	return recs, order
end

-- Differences between the run (`got`) and the baseline (`want`). `partial`: the run was
-- filtered, so only the tests it ran are compared. Returns a list of messages (empty = same);
-- .added lists tests the baseline does not have (new tests: shown, not a difference).
function TR.compare(got, want, partial, maxShown)
	maxShown = maxShown or 10
	local g, gorder = records(got)
	local b, border = records(want)
	if not g then return { "no transcript at " .. got } end
	if not b then return { "no baseline at " .. want .. " (run with --update-transcript to make one)" } end
	local diffs, added = {}, {}
	local function note(msg)
		diffs[#diffs + 1] = msg
	end
	for _, id in ipairs(gorder) do
		local x, y = g[id], b[id]
		if not y then
			added[#added + 1] = id -- a new test: nothing to compare it with (not a difference)
		else
			local n = math.max(#x, #y)
			for i = 1, n do
				if x[i] ~= y[i] then
					local msg = "differs: " .. id .. "\n      line " .. i .. " baseline: " .. tostring(y[i])
						.. "\n      line " .. i .. " now:      " .. tostring(x[i])
					if #x ~= #y then msg = msg .. "\n      (" .. #y .. " lines in the baseline, " .. #x .. " now)" end
					note(msg)
					break
				end
			end
		end
	end
	if not partial then
		for _, id in ipairs(border) do
			if not g[id] then note("test in the baseline but not run: " .. id) end
		end
	end
	if #diffs > maxShown then
		local more = #diffs - maxShown
		local cut = {}
		for i = 1, maxShown do cut[i] = diffs[i] end
		cut[#cut + 1] = "... and " .. more .. " more"
		cut.total = #diffs
		cut.added = added
		return cut
	end
	diffs.total = #diffs
	diffs.added = added
	return diffs
end

return TR
