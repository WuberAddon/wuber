-- tests/lib/rec_conform.lua: the flight recorder's CONFORMANCE engine (tests/rec/conform_test.lua).
--
-- A recording is a list of facts about the game (how the login runs, what the API has, the flight
-- map's frame, the map art, how a trade closes...). The fake game is asked the same questions the
-- same way: the recorder itself runs in it under a standard set of scenes (CF.scenes), and the two
-- recordings are compared fact by fact.
--
--   local CF = dofile(T.dir .. "/lib/rec_conform.lua")
--   CF.facts(fx or { fx, ... })   -> { { id, v, rule }, ... }  (derived from events and snapshots;
--                                    a fixture's own fx.facts is not used: see CF.crossCheck)
--   CF.scenes(T)                  -> the fake game's recording of the scenes: a list of fx
--   CF.compare(real, sim)         -> { { id, verdict = "same" | "differs" | "real only" | "sim only",
--                                    real, sim, rule }, ... } (real, sim: facts or fx or lists of fx)
--   CF.failures(list, gaps)       -> the "differs" on "equal" and "shape" facts not in gaps
--   CF.summary(list)              -> plain lines for a report
--   CF.crossCheck(fx)             -> the ids both fx.facts (the importer's) and CF.facts give, with
--                                    different values (for the lead; never a failure)
-- Rules: "equal" (must be equal), "shape" (the same type), "info" (identity facts that may differ
-- without the fake being wrong: the character, the build, the screen size, positions; reported only).
-- Facts are made by CF.FACTS: ONE ROW per kind of fact, { name, rule, fn(list, put) }.

local here = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
local RP = dofile(here .. "/rec_replay.lua")

local CF = {}
CF.RP = RP
local num, str, copy = RP.num, RP.str, RP.copy

local function sv(v)
	if v == nil then return "<nil>" end
	if type(v) == "number" then
		if v == math.floor(v) then return tostring(v) end
		return ("%.4g"):format(v)
	end
	return tostring(v)
end

local function join(list, sep)
	local out = {}
	for i, v in ipairs(list) do out[i] = sv(v) end
	return table.concat(out, sep or ",")
end

local function setOf(t)
	local out = {}
	for k in pairs(t) do out[#out + 1] = tostring(k) end
	table.sort(out)
	return table.concat(out, ",")
end

local function snaps(list, id)
	local out = {}
	for _, fx in ipairs(list) do
		for _, s in ipairs(fx.snaps or {}) do
			if s.id == id then out[#out + 1] = s end
		end
	end
	return out
end

local function first(list, id, usable)
	for _, s in ipairs(snaps(list, id)) do
		if not usable or usable(s.d) then return s end
	end
end

local BOOT = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true }
local OURS = { Wuber = true, WuberRec = true, WuberLab = true, WuberLabBar = true }

-- a boot session's kind: the scene the fake ran (fx.scene), else what its PLAYER_ENTERING_WORLD says
local function bootKind(fx)
	if fx.why ~= "boot" then return nil end
	if fx.scene then return fx.scene end
	for _, e in ipairs(fx.events or {}) do
		if e.e == "PLAYER_ENTERING_WORLD" then
			if e.a[2] == true then return "reload" end
			if e.a[1] == true then return "login" end
			return "boot"
		end
	end
	return "boot"
end

-- rows from i on, up to t + secs
local function within(fx, i, secs)
	local out = {}
	local t0 = fx.events[i].t
	for j = i + 1, #fx.events do
		local e = fx.events[j]
		if e.t > t0 + secs then break end
		out[#out + 1] = e
	end
	return out
end

local function has(rows, name)
	for _, e in ipairs(rows) do
		if e.e == name then return e end
	end
end

local NOISE = { CHAT_MSG_ADDON = true, GLOBAL_MOUSE_DOWN = true, BAG_UPDATE_DELAYED = true }
local function noise(e)
	return NOISE[e] or e:find("^CHAT_MSG_") ~= nil or e:find("^UNIT_SPELLCAST_") ~= nil or e:find("^NAME_PLATE_") ~= nil or e:find("^REC_") ~= nil
		or e:find("^CLUB_") ~= nil or e == "CHANNEL_UI_UPDATE"
end

-- the node types the fake's flight map makes (tests/lib/fakes8.lua World:openTaxiMap)
CF.TAXI_TYPES = { CURRENT = true, REACHABLE = true, NONE = true }

local function geomSize(o) return type(o) == "table" and num(o.w) and (sv(o.w) .. " x " .. sv(o.h)) or nil end

-- a boot session's "channels" snapshot at PLAYER_LOGIN, and the first one with channels in it
local function chanAt(fx)
	local at, full
	for _, s in ipairs(fx.snaps or {}) do
		if s.id == "channels" and type(s.d) == "table" and num(s.d.n) then
			if not at and s.why == "PLAYER_LOGIN" then at = s end
			if not full and s.d.n > 0 then full = s end
		end
	end
	return at, full
end

---------------------------------------------------------------------------
-- THE TABLE: one row per kind of fact
---------------------------------------------------------------------------

CF.FACTS = {
	-- the login / reload order: the boot rows, what was there at each, the file-load facts
	{ "boot", "equal", function(list, put)
		for _, fx in ipairs(list) do
			local kind = bootKind(fx)
			if kind then
				local order, others = {}, 0
				for i, e in ipairs(fx.events) do
					if not BOOT[e.e] then break end
					local arg = e.e == "ADDON_LOADED" and tostring(e.a[1]) or nil
					if arg and not OURS[arg] then
						others = others + 1
					else
						local what = e.e .. (arg and (":" .. arg) or "")
						order[#order + 1] = what
						put(kind .. "." .. what .. ".db", e.db)
						put(kind .. "." .. what .. ".wdb", e.wdb)
						put(kind .. "." .. what .. ".li", e.li)
						if e.e == "PLAYER_ENTERING_WORLD" then
							put(kind .. ".PLAYER_ENTERING_WORLD.args", join({ e.a[1], e.a[2] }))
							put(kind .. ".zoneChangedNewArea", has(within(fx, i, 5), "ZONE_CHANGED_NEW_AREA") ~= nil)
						end
					end
				end
				put(kind .. ".order", table.concat(order, ">"))
				put(kind .. ".otherAddons", others, "info")
			end
		end
	end },
	-- what was there when the recorder's own file ran (session.boot: WuberRecDB, WuberDB, Wuber)
	{ "boot:file", "equal", function(list, put)
		for _, fx in ipairs(list) do
			local kind = bootKind(fx)
			if kind then
				for k, v in pairs(type(fx.boot) == "table" and fx.boot or {}) do put(kind .. ".file." .. k, v) end
			end
		end
	end },
	-- the chat channels at a fresh login's PLAYER_LOGIN (the "channels" snapshots), and how many
	-- seconds until the first non-empty list (the real game: about 3 s)
	{ "channels:login", "equal", function(list, put)
		for _, fx in ipairs(list) do
			if bootKind(fx) == "login" then
				local at, full = chanAt(fx)
				if at then
					put("channels.login.count", at.d.n)
					put("channels.login.firstList", full and (math.floor((full.t - at.t) * 10 + 0.5) / 10) or nil, "info")
				end
			end
		end
	end },
	-- the chat channels at a /reload's PLAYER_LOGIN (kept: the real game's five and Wuber's)
	{ "channels:reload", "equal", function(list, put)
		for _, fx in ipairs(list) do
			if bootKind(fx) == "reload" then
				local at = chanAt(fx)
				-- (how many depends on whether Wuber had joined its own channel yet: a count is info, kept or not is the fact)
				if at then
					put("channels.reload.kept", at.d.n > 0)
					put("channels.reload.count", at.d.n, "info")
				end
			end
		end
	end },
	-- a settings snapshot (WuberDB's switches) was taken
	{ "settings:known", "equal", function(list, put)
		put("settings.known", first(list, "settings", function(d) return type(d.db) == "table" end) ~= nil)
	end },
	-- UIParent itself (a frame that only holds protected frames: read like any other); a recording
	-- from before the recorder read it: the screen's size
	{ "screen:ui", "info", function(list, put)
		local s = first(list, "screen", function(d) return d.ui ~= nil end)
		if not s then return end
		local d = s.d
		put("screen.ui.size", geomSize(d.ui) or (sv(d.sw) .. " x " .. sv(d.sh)))
		put("screen.ui.holds", type(d.ui) == "table" and d.ui.holds == true, "equal")
		put("screen.ui.read", geomSize(d.ui) ~= nil, "equal")
	end },
	-- the count of arguments each event came with
	{ "args", "equal", function(list, put)
		local n = {}
		for _, fx in ipairs(list) do
			for _, e in ipairs(fx.events or {}) do
				if not e.e:find("^REC_") then
					n[e.e] = n[e.e] or {}
					n[e.e][e.n] = true
				end
			end
		end
		for e, set in pairs(n) do put("args." .. e, setOf(set)) end
	end },
	-- the events the client did not know (each event Wuber listens to: known or not)
	{ "known", "equal", function(list, put)
		local R = RP.recorder()
		local unknown, names = {}, {}
		for _, fx in ipairs(list) do
			for _, e in ipairs(fx.unknownEvents or {}) do unknown[e], names[e] = true, true end
			for e in pairs(fx.seen or {}) do names[e] = true end
		end
		if #list > 0 then for _, e in ipairs(R.EVENTS or {}) do names[e] = true end end
		for e in pairs(names) do put("known." .. e, not unknown[e]) end
	end },
	-- the client: API presence, game strings, build, UnitName's shape, the realm calls
	{ "client", "equal", function(list, put)
		local s = first(list, "client", function(d) return d.api ~= nil end)
		if not s then return end
		local d = s.d
		for path, t in pairs(d.api or {}) do put("api." .. path, t) end
		for _, path in ipairs(d.missing or {}) do put("api." .. path, "missing") end
		for k, v in pairs(d.gs or {}) do put("gs." .. k, v) end
		put("client.build", join(d.build or {}, "/"), "info")
		put("client.locale", d.locale, "info")
		put("client.loggedIn", d.loggedIn)
		local u = d.unitName or {}
		put("client.unitName", sv(u.n) .. ":" .. join({ u[1], u[2], u[3] }))
		for k, v in pairs(d.realmGot or {}) do
			if type(v) == "table" then
				put("client.realmGot." .. k, sv(v.n) .. ":" .. join({ v[1], v[2], v[3] }))
			else
				put("client.realmGot." .. k, (tostring(v):gsub(":%d+$", "")))
				put("client.realmGot." .. k .. ".len", v, "info")
			end
		end
		for name, v in pairs(d.addons or {}) do put("client.addon." .. name, v, "info") end
		for e, t in pairs(d.enum or {}) do
			for k, v in pairs(t) do put("client.enum." .. e .. "." .. k, v) end
		end
		put("client.sep", d.sep)
	end },
	-- the screen: UIParent's size and scale (identity facts), each game frame Wuber reads
	{ "screen", "info", function(list, put)
		local s = first(list, "screen", function(d) return d.ui ~= nil end)
		if not s then return end
		local d = s.d
		-- (UIParent is protected in both games, so the recorder reads only that and IsShown from it)
		put("screen.ui.protected", type(d.ui) == "table" and d.ui.prot == true, "equal")
		put("screen.ui.scale", type(d.ui) == "table" and d.ui.s or nil)
		put("screen.ui.effectiveScale", type(d.ui) == "table" and d.ui.es or nil)
		put("screen.physical", sv(d.pw) .. " x " .. sv(d.ph))
		put("screen.uiScale", d.uiScale)
		put("screen.useUiScale", d.useUiScale)
		local R = RP.recorder()
		local names = {}
		for _, n in ipairs(R.GAME_FRAMES or {}) do if n ~= "UIParent" then names[n] = true end end
		for n in pairs(d.frames or {}) do names[n] = true end
		for n in pairs(names) do
			local o = (d.frames or {})[n]
			put("frame." .. n .. ".exists", o ~= nil, "equal")
			if type(o) == "table" then
				put("frame." .. n .. ".protected", o.prot == true, "equal")
				put("frame." .. n .. ".forbidden", o.forbidden == true, "equal")
				put("frame." .. n .. ".shown", o.shown == true, "equal")
				put("frame." .. n .. ".size", geomSize(o))
			end
		end
	end },
	-- the flight map's frame: which one, its size, anchor, strata, level; the API it was read with
	{ "taxi.frame", "equal", function(list, put)
		-- the flight map's API while no map is open (a /rec snap away from a flight master)
		local idle
		for _, sn in ipairs(snaps(list, "taxi")) do
			if not idle and sn.why ~= "TAXIMAP_OPENED" then idle = sn end
		end
		if idle then
			for k, v in pairs(idle.d.has or {}) do put("taxi.idle.has." .. k, v) end
		end
		local s
		for _, sn in ipairs(snaps(list, "taxi")) do
			if sn.why == "TAXIMAP_OPENED" and type(sn.d.frames) == "table" then
				s = sn
				break
			end
		end
		if not s then return end
		local d = s.d
		local name, o = "none", nil
		for _, n in ipairs({ "TaxiFrame", "FlightMapFrame" }) do
			local g = d.frames[n]
			if name == "none" and type(g) == "table" and g.shown then name, o = n, g end
		end
		put("taxi.frame", name)
		if o then
			put("taxi.frame.protected", o.prot == true)
			put("taxi.frame.size", geomSize(o))
			put("taxi.frame.anchor", type(o.p) == "table" and join(o.p) or nil)
			put("taxi.frame.strata", o.strata)
			put("taxi.frame.level", o.lvl, "info")
		end
		for k, v in pairs(d.has or {}) do put("taxi.has." .. k, v) end
		local c = first(list, "taxi_closed")
		if c and type(c.d.frames) == "table" and name ~= "none" then
			local g = c.d.frames[name]
			put("taxi.closed.shown", type(g) == "table" and g.shown == true)
		end
	end },
	-- the flight map's nodes (from a map that was open): how many, node types the fake does not make,
	-- positions inside 0..1, what the current node and a reachable one cost
	{ "taxi.nodes", "equal", function(list, put)
		local s = first(list, "taxi", function(d) return type(d.nodes) == "table" and #d.nodes > 0 end)
		if not s then return end
		local d = s.d
		local types, other, inside = {}, {}, true
		local currentCost, freeReach = nil, false
		for _, n in ipairs(d.nodes) do
			local t = tostring(n[2])
			types[t] = true
			if not CF.TAXI_TYPES[t] then other[t] = true end
			if t == "CURRENT" then currentCost = n[3] end
			if t == "REACHABLE" and n[3] == 0 then freeReach = true end
			local x, y = num(n[4]), num(n[5])
			if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then inside = false end
		end
		put("taxi.nodes.n", #d.nodes, "info")
		put("taxi.nodes.types", setOf(types), "info")
		put("taxi.nodes.otherTypes", setOf(other))
		put("taxi.nodes.inside", inside)
		put("taxi.nodes.currentCost", currentCost)
		put("taxi.nodes.freeReachable", freeReach)
		put("taxi.mapID", d.mapID, "info")
		for _, c in ipairs(d.c or {}) do put("taxi.c." .. tostring(c.fn) .. ".n", c.n, "info") end
	end },
	-- the map art, corners in world yards, children and their rects, per map Wuber draws
	{ "atlas", "equal", function(list, put)
		local s = first(list, "atlas", function(d) return d.maps ~= nil end)
		if not s then return end
		for _, m in ipairs(s.d.maps) do
			local p = "atlas." .. tostring(m.id)
			put(p .. ".there", not m.gone)
			put(p .. ".name", m.name)
			put(p .. ".type", m.type)
			put(p .. ".parent", m.parent)
			local a = m.art
			if type(a) == "table" then
				put(p .. ".art.layers", a.layers)
				put(p .. ".art.size", sv(a.w) .. " x " .. sv(a.h))
				put(p .. ".art.tile", sv(a.tw) .. " x " .. sv(a.th))
				put(p .. ".art.tiles", a.tiles)
			else
				put(p .. ".art", "none")
			end
			put(p .. ".c00", type(m.c00) == "table" and join(m.c00) or "none")
			put(p .. ".c11", type(m.c11) == "table" and join(m.c11) or "none")
			put(p .. ".kids", #(m.kids or {}))
			for _, k in ipairs(m.kids or {}) do
				local q = p .. ".kid." .. tostring(k.id)
				put(q .. ".rect", type(k.rect) == "table" and join(k.rect) or "none")
				put(q .. ".type", k.type)
				put(q .. ".c00", type(k.c00) == "table" and join(k.c00) or "none")
				put(q .. ".art", type(k.art) == "table" and join(k.art) or "none")
			end
		end
	end },
	-- the chain of maps above the player's, as types; the world map's own frame (when it was open)
	{ "map", "equal", function(list, put)
		local s = first(list, "map", function(d) return type(d.chain) == "table" and #d.chain > 0 end)
		if s then
			local types, ids = {}, {}
			for i, m in ipairs(s.d.chain) do types[i], ids[i] = m.type, m.id end
			put("map.chain.types", join(types, ">"))
			put("map.chain.ids", join(ids, ">"), "info")
			put("map.world", type(s.d.world) == "table" and "a world position" or "none")
			put("map.instance", type(s.d.instance) == "table" and join(s.d.instance) or nil, "info")
		end
		local w = first(list, "map", function(d) return type(d.wm) == "table" and d.wm.shown end)
		if w then
			put("map.wm.scroll", type(w.d.wm.scroll) == "table" and "there" or "none")
			put("map.wm.canvas", type(w.d.wm.canvas) == "table" and join(w.d.wm.canvas, " x ") or "none", "info")
			put("map.wm.canvasScale", w.d.wm.canvasScale, "info")
			put("map.wm.size", geomSize(w.d.wm), "info")
		end
	end },
	-- how names were spelled in each event argument that carries one
	{ "shape", "equal", function(list, put)
		local all = {}
		for _, fx in ipairs(list) do
			for where, t in pairs(fx.shapes or {}) do
				all[where] = all[where] or {}
				for k in pairs(t) do all[where][k] = true end
			end
		end
		for where, set in pairs(all) do put("shape." .. where, setOf(set)) end
	end },
	-- each trade: how many TRADE_CLOSED rows, and which event said "Trade complete"
	{ "trade", "equal", function(list, put)
		for _, fx in ipairs(list) do
			local ev = fx.events or {}
			for i, e in ipairs(ev) do
				if e.e == "TRADE_SHOW" then
					local closed, line = 0, nil
					for j = i + 1, #ev do
						local x = ev[j]
						if x.e == "TRADE_SHOW" or x.t > e.t + 120 then break end
						if x.e == "TRADE_CLOSED" then closed = closed + 1 end
						for _, a in ipairs({ x.a[1], x.a[2] }) do
							if type(a) == "table" and a.gs == "ERR_TRADE_COMPLETE" and not line then line = x.e end
						end
					end
					local kind = line and "complete" or "cancel"
					put("trade." .. kind .. ".closed", closed)
					if line then put("trade.complete.lineEvent", line) end
				end
			end
		end
	end },
	-- a summon: the events from CONFIRM_SUMMON to the arrival (chat and addon traffic left out)
	{ "summon", "equal", function(list, put)
		for _, fx in ipairs(list) do
			local ev = fx.events or {}
			for i, e in ipairs(ev) do
				if e.e == "CONFIRM_SUMMON" then
					local seq, arrived = { e.e }, nil
					for j = i + 1, #ev do
						local x = ev[j]
						if x.t > e.t + 130 or x.e == "CANCEL_SUMMON" or x.e == "CONFIRM_SUMMON" then break end
						if not noise(x.e) then
							if arrived and x.t > arrived + 1 then break end
							seq[#seq + 1] = x.e
							if not arrived and (x.e == "PLAYER_ENTERING_WORLD" or x.e == "ZONE_CHANGED_NEW_AREA") then arrived = x.t end
							if x.e == "PLAYER_ENTERING_WORLD" then put("summon.PLAYER_ENTERING_WORLD.args", join({ x.a[1], x.a[2] })) end
						end
					end
					if arrived then put("summon.arrival", table.concat(seq, ">")) end
					put("args.CONFIRM_SUMMON.values", join({ e.a[1], e.a[2] }), "info")
				end
			end
		end
	end },
	-- leaving the group while a summon waits: does CANCEL_SUMMON come?
	{ "group", "equal", function(list, put)
		for _, fx in ipairs(list) do
			local pending = false
			local ev = fx.events or {}
			for i, e in ipairs(ev) do
				if e.e == "CONFIRM_SUMMON" then pending = true end
				if e.e == "CANCEL_SUMMON" or e.e == "PLAYER_ENTERING_WORLD" or e.e == "ZONE_CHANGED_NEW_AREA" then pending = false end
				if e.e == "GROUP_LEFT" and pending then
					put("group.leftWhileSummoned.cancelSummon", has(within(fx, i, 5), "CANCEL_SUMMON") ~= nil)
					pending = false
				end
			end
		end
	end },
}

local function isFacts(x) return type(x) == "table" and type(x[1]) == "table" and x[1].id ~= nil and x[1].events == nil end
local function asList(x)
	if type(x) ~= "table" then return {} end
	if x.events or x.snaps then return { x } end
	return x
end

function CF.facts(fx)
	if isFacts(fx) then return fx end
	local list = asList(fx)
	local out, seen = {}, {}
	for _, row in ipairs(CF.FACTS) do
		local rule = row[2]
		local ok, err = pcall(row[3], list, function(id, v, r)
			if v == nil or seen[id] then return end
			seen[id] = true
			out[#out + 1] = { id = id, v = v, rule = r or rule }
		end)
		if not ok then out[#out + 1] = { id = "error." .. row[1], v = tostring(err), rule = "equal" } end
	end
	table.sort(out, function(a, b) return a.id < b.id end)
	return out
end

local function same(rule, a, b)
	if rule == "shape" then return type(a) == type(b) end
	return a == b
end

function CF.compare(real, sim)
	local R, Sm = CF.facts(real), CF.facts(sim)
	local byS = {}
	for _, f in ipairs(Sm) do byS[f.id] = f end
	local out, done = {}, {}
	for _, f in ipairs(R) do
		local s = byS[f.id]
		done[f.id] = true
		if s then
			local rule = f.rule or s.rule
			out[#out + 1] = { id = f.id, verdict = same(rule, f.v, s.v) and "same" or "differs", real = f.v, sim = s.v, rule = rule }
		else
			out[#out + 1] = { id = f.id, verdict = "real only", real = f.v, rule = f.rule }
		end
	end
	for _, s in ipairs(Sm) do
		if not done[s.id] then out[#out + 1] = { id = s.id, verdict = "sim only", sim = s.v, rule = s.rule } end
	end
	return out
end

-- the differences that fail: "differs" on an "equal" or "shape" fact, not listed in gaps
function CF.failures(list, gaps)
	gaps = gaps or {}
	local out = {}
	for _, c in ipairs(list) do
		if c.verdict == "differs" and c.rule ~= "info" and not gaps[c.id] then out[#out + 1] = c end
	end
	return out
end

local function q(v)
	if type(v) == "string" then return '"' .. v .. '"' end
	return tostring(v)
end

function CF.line(c)
	if c.verdict == "differs" then
		return ("%s [%s]: the real game %s, the fake %s"):format(c.id, c.rule, q(c.real), q(c.sim))
	elseif c.verdict == "real only" then
		return ("%s [%s]: only the real game has it: %s"):format(c.id, c.rule, q(c.real))
	elseif c.verdict == "sim only" then
		return ("%s [%s]: only the fake has it: %s"):format(c.id, c.rule, q(c.sim))
	end
	return ("%s [%s]: same: %s"):format(c.id, c.rule, q(c.real))
end

-- plain lines the lead can paste into a report
function CF.summary(list, opts)
	opts = opts or {}
	local max = opts.max or 60
	local n = { same = 0, differs = 0, ["real only"] = 0, ["sim only"] = 0 }
	local hard, info, ronly, sonly = {}, {}, {}, {}
	for _, c in ipairs(list) do
		n[c.verdict] = (n[c.verdict] or 0) + 1
		if c.verdict == "differs" then
			if c.rule == "info" then info[#info + 1] = c else hard[#hard + 1] = c end
		elseif c.verdict == "real only" then ronly[#ronly + 1] = c
		elseif c.verdict == "sim only" then sonly[#sonly + 1] = c end
	end
	local out = {}
	out[#out + 1] = ("%d facts: %d same, %d differ (%d must be equal, %d info), %d only in the real game, %d only in the fake"):format(
		#list, n.same, n.differs, #hard, #info, n["real only"], n["sim only"])
	local function section(title, rows)
		if #rows == 0 then return end
		out[#out + 1] = title
		for i, c in ipairs(rows) do
			if i > max then
				out[#out + 1] = ("  ... and %d more"):format(#rows - max)
				break
			end
			out[#out + 1] = "  " .. CF.line(c)
		end
	end
	section("Differs (the fake must change, or the gap is listed in known-gaps.lua):", hard)
	section("Differs (info: identity facts, never a failure):", info)
	if opts.only ~= false then
		section("Only in the real game (no fake scene asks this yet):", ronly)
		if opts.simOnly then section("Only in the fake:", sonly) end
	end
	return out
end

-- The importer's facts (tools/rec/import.lua: fx.facts = { { id = "<q>:<key>", q, key, v }, ... },
-- values often tables) against ours: CF.CROSS turns one of theirs into ours, ONE ROW per kind
-- (q, fn(key, v, put)); an id we both have is compared (an id of ours style is compared as it is).
local function sortedJoin(v)
	if type(v) ~= "table" then return v end
	local out, seen = {}, {}
	for k, x in pairs(v) do
		local item = type(k) == "number" and x or k
		if not seen[tostring(item)] then
			seen[tostring(item)] = true
			out[#out + 1] = tostring(item)
		end
	end
	table.sort(out)
	return table.concat(out, ",")
end
CF.CROSS = {
	api = function(key, v, put) put("api." .. key, v) end,
	gs = function(key, v, put) put("gs." .. key, v) end,
	event = function(key, v, put)
		local e = key:match("^argc:(.+)$")
		if e then put("args." .. e, sortedJoin(v)) end
	end,
	name = function(key, v, put)
		local where = key:match("^shape:(.+)$")
		if where then put("shape." .. where, sortedJoin(v)) end
	end,
	reload = function(key, v, put)
		if key == "pew" and type(v) == "table" then
			if type(v.a) == "table" then put("reload.PLAYER_ENTERING_WORLD.args", join({ v.a[1], v.a[2] })) end
			if v.zone ~= nil then put("reload.zoneChangedNewArea", v.zone) end
		end
	end,
	channels = function(key, v, put)
		if type(v) ~= "table" then return end
		if key == "login" then
			put("channels.login.count", v.n)
			if num(v.first) then put("channels.login.firstList", math.floor(v.first * 10 + 0.5) / 10) end
		elseif key == "reload" then
			put("channels.reload.count", v.n)
			if num(v.n) then put("channels.reload.kept", v.n > 0) end
		end
	end,
	settings = function(key, v, put) if key == "known" then put("settings.known", v) end end,
	screen = function(key, v, put)
		if key == "ui" and type(v) == "table" then
			if num(v.w) and num(v.h) then put("screen.ui.size", sv(v.w) .. " x " .. sv(v.h)) end
			if v.holds ~= nil then put("screen.ui.holds", v.holds) end
		end
	end,
	taxi = function(key, v, put)
		if type(v) ~= "table" then return end
		if key == "frame" then
			put("taxi.frame", v.name)
			put("taxi.frame.strata", v.strata)
		elseif key == "nodes" then
			if type(v.inside) == "number" and num(v.n) then put("taxi.nodes.inside", v.inside == v.n) else put("taxi.nodes.inside", v.inside) end
			put("taxi.nodes.types", sortedJoin(v.types))
		end
	end,
}

function CF.crossCheck(fx)
	if type(fx.facts) ~= "table" then return {} end
	local theirs = {}
	local function put(id, v) if id ~= nil and v ~= nil and theirs[id] == nil then theirs[id] = v end end
	for k, f in pairs(fx.facts) do
		if type(f) == "table" and f.id ~= nil then
			local v = f.v
			if v == nil then v = f.value end
			local q, key = tostring(f.id):match("^([%w_]+):(.+)$")
			q, key = f.q or q, f.key or key
			if q and CF.CROSS[q] then pcall(CF.CROSS[q], tostring(key), v, put) end
			if type(v) ~= "table" then put(f.id, v) end
		elseif type(k) == "string" and type(f) ~= "table" then
			put(k, f)
		end
	end
	local out = {}
	for _, f in ipairs(CF.facts(fx)) do
		local v = theirs[f.id]
		if v ~= nil and v ~= f.v then out[#out + 1] = { id = f.id, importer = v, ours = f.v } end
	end
	out.compared = 0
	for _, f in ipairs(CF.facts(fx)) do if theirs[f.id] ~= nil then out.compared = out.compared + 1 end end
	return out
end

---------------------------------------------------------------------------
-- The fake game's own recording: the recorder runs in it under the standard scenes
---------------------------------------------------------------------------

CF.ROCKS = "Wuber Rocks"
CF.NODES = { { name = "Thunder Bluff, Mulgore", type = "CURRENT", x = 0.45, y = 0.55 },
	{ name = "Orgrimmar, Durotar", type = "REACHABLE", cost = 50, x = 0.6, y = 0.3 },
	{ name = "Crossroads, The Barrens", type = "REACHABLE", cost = 30, x = 0.5, y = 0.45 } }

-- each scene: { name, fn(w, st) } (st.r the recording client, st.d the driver, st.add, st.opts)
CF.SCENES = {
	{ "a fresh login", function(w, st)
		local saved = w:logout(st.r)
		w:advance(2)
		local o = copy(st.opts)
		o.saved = saved
		st.r = st.add(CF.ROCKS, o)
		st.mark("login")
		w:advance(5)
	end },
	{ "a /reload", function(w, st)
		st.r = w:reload(st.r)
		st.mark("reload")
		w:advance(5)
		st.r:slash("/rec snap") -- every snapshot once, away from a flight master and the world map
		w:advance(1)
	end },
	{ "a flight map open", function(w, st)
		w:openTaxiMap(st.r, CF.NODES)
		w:advance(2)
		w:closeTaxiMap(st.r)
		w:advance(1)
	end },
	{ "a party invite, summon and arrival", function(w, st)
		local r = st.r
		w:invite(st.d, CF.ROCKS)
		w:advance(1)
		if not r.player.group then
			r.env.AcceptGroup()
			w:advance(1)
		end
		w:summon(st.d, CF.ROCKS)
		w:advance(1)
		w.hardware = r
		r.env.C_SummonInfo.ConfirmSummon()
		w.hardware = nil
		w:advance(4)
	end },
	{ "a trade completed", function(w, st)
		local r = st.r
		w:openTrade(st.d, r)
		w:advance(1)
		w:typeTradeMoney(r.player, 0, 50, 0)
		w:advance(1)
		w:tradeAccept(st.d.player)
		w:tradeAccept(r.player)
		w:advance(2)
	end },
	{ "a trade cancelled", function(w, st)
		w:openTrade(st.d, st.r)
		w:advance(1)
		w:tradeCancel(st.d.player)
		w:advance(2)
	end },
	{ "leaving the group while a summon waits", function(w, st)
		local r = st.r
		if not r.player.group then
			w:invite(st.d, CF.ROCKS)
			w:advance(1)
			if not r.player.group then r.env.AcceptGroup() w:advance(1) end
		end
		w:summon(st.d, CF.ROCKS)
		w:advance(1)
		w:leave(CF.ROCKS)
		w:advance(6)
	end },
	{ "the world map open", function(w, st)
		w:openMap(st.r, 1414)
		w:advance(1)
		st.r:slash("/rec snap")
		w:advance(1)
	end },
}

local scenesCache
-- The fake's recording of every scene (a list of fx, oldest first; fx.scene names a boot session's
-- scene: "login" or "reload", since the fake's own login events cannot tell them apart).
function CF.scenes(T)
	if scenesCache then return copy(scenesCache) end
	local marks = {}
	local list, w = RP.record(T, function(w, add)
		local d = T.driver(w, T.ANITA, { spot = "Orgrimmar" })
		local opts = { spot = "Thunder Bluff", class = "MAGE", money = 100000, screenW = 1365, screenH = 768 }
		local st = { d = d, add = add, opts = opts }
		st.r = add(CF.ROCKS, opts)
		st.r:slash("/rec on")
		st.mark = function(scene)
			local db = rawget(st.r.env, "WuberRecDB")
			marks[#db.sessions] = scene
		end
		w:advance(5)
		for _, sc in ipairs(CF.SCENES) do sc[2](w, st) end
		st.r:slash("/rec off")
		return st.r
	end, "sim")
	for i, fx in ipairs(list) do fx.scene = marks[i] end
	CF.errors = {}
	for _, e in ipairs(w.errors) do CF.errors[#CF.errors + 1] = e end
	scenesCache = list
	return copy(list)
end

return CF
