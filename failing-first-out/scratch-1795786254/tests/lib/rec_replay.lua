-- tests/lib/rec_replay.lua: the flight recorder's REPLAY engine (tests/rec/replay_test.lua).
--
-- A recorded session (tools/rec/session.lua's fixture table, fx) is fed to Wuber in the fake game
-- (tests/harness.lua), and what Wuber shows is compared with what it showed when it was recorded.
--
--   local RP = dofile(T.dir .. "/lib/rec_replay.lua")
--   local rep = RP.replay(T, fx, opts)     -- opts: saved (WuberDB to start with), lead (seconds from
--                                          -- login to the session's start), extra = "deliver", name
--   rep.ok, rep.total, rep.matched, rep.mismatches, rep.unknownEvents, rep.cannot, rep.names, RP.lines(rep)
--   rep.kind ("on", "login", "reload", "boot"), rep.channels (RP.channelPlan), rep.settings (RP.applySettings),
--   rep.delivered[event] (how many times each event reached Wuber once the replay began)
--
-- How it plays:
--   * ONE client for fx.char (class, faction from the fixture; the screen from the first "screen"
--     snapshot: UIParent size, scale, physical size; the place from the first "map" snapshot), with
--     addons { "Wuber" } only (the recorder is not loaded) and empty saved variables unless opts.saved.
--   * Time: the client logs in at w.time 1000; a session started by /rec on begins opts.lead seconds
--     later (fx.sinceLoad when the recorder writes it; else 0, noted in rep.cannot); a boot session
--     (fx.why == "boot") begins at the login itself, and its recorded ADDON_LOADED / PLAYER_LOGIN /
--     PLAYER_ENTERING_WORLD rows REPLACE the fake's own login events (so a /reload replays with the
--     arguments the real game gave, and with no ZONE_CHANGED_NEW_AREA when the recording has none).
--   * Each event row: the clock is advanced to its time, the world is put into the state the
--     recording shows (RP.STATE: one row per event name), and the event is fired with its arguments
--     rebuilt (RP.rebuild). An event the fake does not know (not in H.KNOWN_EVENTS) is not fired:
--     it is counted in rep.unknownEvents (a gap of the fake game, not of the replay).
--   * What the fake world makes by itself (the client's own channel echo, a system line, a timer)
--     is matched against the recording (the same event and the same arguments as the recorder would
--     have kept them, within RP.WINDOW seconds): a match is delivered once; a fake event the
--     recording does not have is held back and listed in rep.extra (opts.extra = "deliver" lets it
--     through). Events the recorder never keeps (not on its list, filtered, in combat, rate-capped)
--     always pass.
--   * The world as the session began: every player the recording names is a bot from the start, the
--     group of the first group snapshot, the place of the first map snapshot, the screen; the chat
--     channels from the "channels" snapshots (RP.channelPlan: how many of the game's own, and when
--     they came). The client starts the way the session did (RP.bootKind): a /reload boot session
--     as a reload (PLAYER_ENTERING_WORLD(false, true), its channels kept, no late zone event); a
--     fresh-login one as a login (no channels, then the game's channels and the zone event
--     loginDelay s later, the delay the recording shows); a /rec on session sinceLoad s after a
--     login (with the channels at once when the recording had them sooner than the fake would).
--   * Wuber's settings: the switches of the "settings" snapshot (booleans and short lower-case
--     choices of WuberDB that Wuber already has, of the same type) are put into W.db once Wuber's
--     own login has run (RP.applySettings; numbers, tables and long strings are left alone).
--   * The player's own clicks are not in the recording: when a "wuber" snapshot shows the phone
--     opened or closed, another tab, Settings or Help, or a ride begun (RP.INPUTS), the replay does
--     that through Wuber (UI.Toggle, UI.SelectTab, UI.OpenSettings, UI.OpenHelp, W.RequestRide) just
--     after the snapshot before it (listed in rep.inputs). Everything else is Wuber's own doing.
--     Wuber makes its ride ids itself: the recorded id (the "wuber" snapshots' ride.id; else an id
--     of the same length) in the answers becomes the replay's (rep.ids).
--   * A recording made in the fake game ("sim") gives the fake's clock (its id or epoch is
--     H.EPOCH + w.time), so it replays at the very same times. RP.replayChain(T, list) replays
--     sessions of one character in a row: a boot session right after another starts with that
--     replay's saved variables, ride ids and clock (a real /reload keeps WuberDB; the recording
--     does not carry it).
--   * The recorder's own rows (REC_MARK) are listed in rep.marks, not fired.
--   * Every "wuber" snapshot is an expectation: RP.FIELDS are read from the fake client at the same
--     time and compared; a mismatch has id "replay:<field>".
-- Names: other players are P1, P2... in a recording. Each becomes a bot of that ONE-WORD name
-- ("P3"): W.Key folds it to "p3", the same key the P-number inside Wuber's own messages folds to
-- (the recorder writes "P3" for every spelling of the name it replaced), so sender, group member and
-- message text name the same player. The author's characters keep their names.

local RP = {}
RP.WINDOW = 5         -- seconds within which a fake-made event and a recorded row are the same one
RP.DEFAULT_LEAD = 0   -- seconds from login to /rec on when the recording does not say
RP.NIL, RP.SECRET, RP.DROPPED = "<nil>", "<secret>", "<->"

local function copy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = copy(x) end
	return out
end
RP.copy = copy

local function num(v)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return nil
end
local function str(v)
	if type(v) == "string" and v ~= "" and not v:find("^<.*>$") then return v end
	return nil
end
RP.num, RP.str = num, str

-- when a session began (seconds, the game's time()): fx.epoch, else its id ("20261117-191655", the
-- recorder's date("%Y%m%d-%H%M%S") of the same clock)
function RP.epochOf(fx)
	if num(fx.epoch) then return fx.epoch end
	local y, mo, d, h, mi, s = tostring(fx.id or ""):match("^(%d%d%d%d)(%d%d)(%d%d)%-(%d%d)(%d%d)(%d%d)")
	if not y then return nil end
	return os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = tonumber(s) })
end

---------------------------------------------------------------------------
-- The recorder's own tables (its policy, event list, game strings, frames), read from its files
---------------------------------------------------------------------------

-- tests/lib/rec_addon.lua (beside this file) knows where the addon is and which version the tests are for
local ADDON
do
	local here = (debug.getinfo(1, "S").source or ""):gsub("^@", ""):gsub("\\", "/"):match("^(.*)/[^/]*$") or "tests/lib"
	ADDON = dofile(here .. "/rec_addon.lua")
end
RP.ADDON = ADDON

function RP.recDir() return ADDON.dir() end

-- the recorder is there AND is the version these tests are for
function RP.haveRecorder() return ADDON.have() end

-- Data.lua, Rec.lua and Snaps.lua run in a sandbox with no game: CreateFrame is missing, so the
-- recorder switches itself off at load and only its tables are left (R.POLICY, R.EVENTS, ...).
local recCache
function RP.recorder()
	if recCache then return recCache end
	local R = {}
	local env = setmetatable({}, { __index = _G })
	env._G = env
	for _, f in ipairs({ "Data.lua", "Rec.lua", "Snaps.lua" }) do
		local chunk = loadfile(RP.recDir() .. "/" .. f)
		if chunk then
			setfenv(chunk, env)
			pcall(chunk, "WuberRec", R)
		end
	end
	R.POLICY = R.POLICY or {}
	R.EVENTS = R.EVENTS or {}
	R.FILTER = R.FILTER or {}
	R.C = R.C or { STR = 120, MSG = 255, ARGS = 8 }
	R.ALWAYS = { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
	R.LISTED = {}
	for _, e in ipairs(R.EVENTS) do R.LISTED[e] = true end
	for _, e in ipairs(R.ALWAYS) do R.LISTED[e] = true end
	recCache = R
	return R
end

-- Records a story in the fake game with the recorder loaded. story(w, add) makes the world's
-- players; add(name, opts) adds a client with { "Wuber", "WuberRec" } (opts as w:addClient's). The
-- story returns the recording client as it is at the end (a /reload or a login makes a new one).
-- Returns the sessions it saved (converted, oldest first) and the world.
function RP.record(T, story, source)
	local H = T.H
	H.ADDONS.WuberRec = RP.recDir()
	local SES = dofile(T.dir .. "/../tools/rec/session.lua")
	local w = T.newWorld()
	local function add(name, opts)
		opts = copy(opts or {})
		opts.addons = opts.addons or { "Wuber", "WuberRec" }
		if opts.allowMissing == nil then opts.allowMissing = not T.HAVE_UI end
		return w:addClient(name, opts)
	end
	local c = story(w, add)
	local db = c and rawget(c.env, "WuberRecDB")
	local out = {}
	for _, s in ipairs(type(db) == "table" and db.sessions or {}) do out[#out + 1] = SES.convert(s, source or "sim") end
	return out, w, c
end

---------------------------------------------------------------------------
-- Values as the recorder keeps them (to compare what the fake made with what was recorded)
---------------------------------------------------------------------------

local function canon(v)
	if v == nil then return RP.NIL end
	if type(v) == "table" then
		if v.gs then
			local a = {}
			for i = 1, 3 do a[i] = tostring(type(v.a) == "table" and v.a[i] or "") end
			return "gs:" .. tostring(v.gs) .. ":" .. table.concat(a, ",")
		end
		if v.len then return "x:" .. tostring(v.len) .. ":" .. tostring(v.w) end
		return "<table>"
	end
	return tostring(v)
end
RP.canon = canon

local function esc(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

-- the game strings as patterns (the recorder's own rule), from this client's strings
local function gsPatterns(cx)
	if cx.gs then return cx.gs end
	local out = {}
	for _, k in ipairs(cx.R.GS or {}) do
		local fmt = rawget(cx.c.env, k) or cx.c.env[k]
		if type(fmt) == "string" and fmt ~= "" then
			local p = esc(fmt)
			local caps = 0
			local function cap(with) return function() caps = caps + 1 return with end end
			p = p:gsub("%%%%%d%%%$s", cap("(.-)")):gsub("%%%%%d%%%$d", cap("(%%-?%%d+)"))
			p = p:gsub("%%%%s", cap("(.-)")):gsub("%%%%d", cap("(%%-?%%d+)"))
			out[#out + 1] = { k, "^" .. p .. "$", caps }
		end
	end
	cx.gs = out
	return out
end

local function chatShape(v)
	if type(v) == "string" and v ~= "" then return { len = #v, w = v:lower():find("wuber", 1, true) ~= nil } end
	return nil
end

-- one argument as the recorder would have kept it (code: its policy letter)
local function encode(cx, code, v)
	local H = cx.H
	if v == H.SECRET then return RP.SECRET end
	if v == nil then return RP.NIL end
	if code == "-" then return RP.DROPPED end
	local t = type(v)
	if t == "number" then return (v ~= v or v == math.huge or v == -math.huge) and "<nan>" or v end
	if t == "boolean" then return v end
	if t ~= "string" then return "<" .. t .. ">" end
	if code == "x" then return chatShape(v) or v end
	if code == "s" then
		for _, g in ipairs(gsPatterns(cx)) do
			local a, b, c = v:match(g[2])
			if a then
				local out = { gs = g[1] }
				if g[3] > 0 then
					out.a = {}
					for i, x in ipairs({ a, b, c }) do out.a[i] = x:match("^%-?%d+$") and tonumber(x) or x end
				end
				return out
			end
		end
		return chatShape(v) or v
	end
	if code == "d" then return { len = #v } end
	if code == "w" then return #v > cx.R.C.MSG and v:sub(1, cx.R.C.MSG) or v end
	return #v > cx.R.C.STR and v:sub(1, cx.R.C.STR) or v
end

local function policyLen(cx, event, n)
	local pol = cx.R.POLICY[event]
	if pol then return math.min(n, #pol), pol end
	return math.min(n, cx.R.C.ARGS or 8), nil
end

-- the signature of an event: its name and its kept arguments (the count is not part of it)
local function sigOf(event, list, m)
	local parts = { event }
	for i = 1, m do parts[#parts + 1] = canon(list[i]) end
	return table.concat(parts, "|")
end

local function fakeSig(cx, event, ...)
	local n = select("#", ...)
	local m, pol = policyLen(cx, event, n)
	local list = {}
	for i = 1, m do list[i] = encode(cx, pol and pol:sub(i, i) or "d", (select(i, ...))) end
	return sigOf(event, list, m)
end

local function rowSig(cx, row)
	local m = policyLen(cx, row.e, row.n)
	return sigOf(row.e, row.a, m)
end
RP.rowSig = rowSig

---------------------------------------------------------------------------
-- Rebuilding a recorded row's arguments for the fake
---------------------------------------------------------------------------

local function guidOf(cx, name) return "Player-1-" .. cx.H.key(tostring(name or "x")) end
local CAST_GUID = "Cast-3-1-1-1-698-0000000001"

-- Dropped arguments ("<->"): a harmless value of the right type, per event and position.
local CHAT_FILL = { [3] = "", [6] = "", [12] = function(cx, a) return guidOf(cx, a[2]) end }
RP.FILL = {
	CHAT_MSG_SAY = CHAT_FILL, CHAT_MSG_YELL = CHAT_FILL, CHAT_MSG_WHISPER = CHAT_FILL, CHAT_MSG_WHISPER_INFORM = CHAT_FILL,
	CHAT_MSG_CHANNEL = CHAT_FILL, CHAT_MSG_PARTY = CHAT_FILL, CHAT_MSG_PARTY_LEADER = CHAT_FILL, CHAT_MSG_RAID = CHAT_FILL,
	CHAT_MSG_RAID_LEADER = CHAT_FILL, CHAT_MSG_CHANNEL_NOTICE = { [3] = "", [6] = "" },
	GROUP_JOINED = { [2] = "Party-1-1" }, GROUP_LEFT = { [2] = "Party-1-1" },
	PARTY_INVITE_REQUEST = { [7] = function(cx, a) return guidOf(cx, a[1]) end },
	UNIT_SPELLCAST_SENT = { [3] = CAST_GUID }, UNIT_SPELLCAST_START = { [2] = CAST_GUID }, UNIT_SPELLCAST_CHANNEL_START = { [2] = CAST_GUID },
	UNIT_SPELLCAST_CHANNEL_STOP = { [2] = CAST_GUID }, UNIT_SPELLCAST_SUCCEEDED = { [2] = CAST_GUID },
	UNIT_SPELLCAST_FAILED = { [2] = CAST_GUID }, UNIT_SPELLCAST_INTERRUPTED = { [2] = CAST_GUID },
	CLUB_INVITATION_ADDED_FOR_SELF = { [1] = function() return {} end },
}

-- Chat text kept as { len, w }: a filler of that length, with "wuber" in it or not (plain letters,
-- so it matches none of the words Wuber looks for in chat).
local function filler(len, w)
	len = math.max(0, math.floor(tonumber(len) or 0))
	if w then
		local s = "wuber" .. ("o"):rep(math.max(0, len - 5))
		return s:sub(1, math.max(len, 5))
	end
	return ("o"):rep(len)
end
RP.filler = filler

-- A game string with the recorded values ("%s", "%d" and "%1$s" forms).
local function formatGS(fmt, a)
	a = type(a) == "table" and a or {}
	local i = 0
	local s = fmt:gsub("%%%%", "\1")
	s = s:gsub("%%(%d)%$[sd]", function(k) local v = a[tonumber(k)] return v == nil and "" or tostring(v) end)
	s = s:gsub("%%[sd]", function()
		i = i + 1
		local v = a[i]
		return v == nil and "" or tostring(v)
	end)
	return (s:gsub("\1", "%%"))
end
RP.formatGS = formatGS

-- the fake player a recorded name stands for (made on demand, once per replay)
function RP.botName(name)
	name = tostring(name)
	if name:find(" ", 1, true) then return (name:gsub("%-.*$", "")) end
	local a, b = name:match("^([^%-]+)%-([^%-]+)")
	if a and b and not name:find("^P%d") then return a .. " " .. b end
	return (name:gsub("%-.*$", ""))
end

local function bot(cx, name)
	if type(name) ~= "string" or name == "" or name:find("^<") then return nil end
	local w = cx.w
	local fake = RP.botName(name)
	local p = w:player(fake)
	if not p then
		p = w:addBot(fake, { faction = cx.fx.faction, acceptsInvites = false, acceptsSummon = false })
		p.mapID, p.x, p.y, p.zone, p.subZone = cx.p.mapID, cx.p.x, cx.p.y, cx.p.zone, cx.p.subZone
		cx.rep.names[name] = fake == name and (fake .. " (a bot; W.Key folds it to \"" .. cx.H.key(fake) .. "\")")
			or (fake .. " (a bot; the recorded spelling was " .. name .. ")")
	end
	return p
end
RP.bot = bot

local function rebuildOne(cx, row, i, a)
	local H = cx.H
	local v = row.a[i]
	local pol = cx.R.POLICY[row.e]
	local code = pol and pol:sub(i, i) or (pol and "" or "d")
	if v == RP.SECRET then
		cx.rep.secretArgs = cx.rep.secretArgs + 1
		return H.SECRET
	end
	if v == RP.DROPPED or (code == "-" and v == nil) then
		cx.rep.droppedArgs = cx.rep.droppedArgs + 1
		local f = RP.FILL[row.e] and RP.FILL[row.e][i]
		if type(f) == "function" then return f(cx, a) end
		if f ~= nil then return f end
		return ""
	end
	if v == "<nan>" then return 0 end
	if type(v) == "string" and v:find("^<%a+>$") then
		cx:cannot("value " .. v, "a " .. v .. " argument of " .. row.e .. " (" .. i .. ") cannot be rebuilt: an empty table is used")
		return {}
	end
	if type(v) == "table" then
		if v.gs then
			local fmt = rawget(cx.c.env, v.gs) or cx.c.env[v.gs]
			if type(fmt) ~= "string" then
				cx:cannot("gs " .. tostring(v.gs), "the fake game has no game string " .. tostring(v.gs) .. ": its name is sent as the text")
				return tostring(v.gs)
			end
			local args = {}
			for k = 1, 3 do
				local x = type(v.a) == "table" and v.a[k] or nil
				if type(x) == "string" and not x:match("^%-?%d+$") then
					local p = bot(cx, x)
					x = p and p.name or x
				end
				args[k] = x
			end
			return formatGS(fmt, args)
		end
		if v.len then return filler(v.len, v.w) end
		return {}
	end
	if code == "n" and type(v) == "string" then
		local p = bot(cx, v)
		return p and p.name or v
	end
	return v
end

-- the arguments of a recorded row, for the fake: a list and its count
function RP.rebuild(cx, row)
	local a = {}
	for i = 1, row.n do a[i] = rebuildOne(cx, row, i, a) end
	return a, row.n
end

---------------------------------------------------------------------------
-- Snapshots near a time
---------------------------------------------------------------------------

local function snapAfter(cx, id, t, within, usable)
	for _, s in ipairs(cx.fx.snaps) do
		if s.id == id and s.t >= t - 0.0005 and s.t <= t + (within or 3) and (not usable or usable(s.d)) then return s end
	end
	return nil
end
local function snapBefore(cx, id, t, usable)
	local best
	for _, s in ipairs(cx.fx.snaps) do
		if s.id == id and s.t <= t + 0.0005 and (not usable or usable(s.d)) then best = s end
	end
	return best
end
RP.snapAfter, RP.snapBefore = snapAfter, snapBefore

local function near(cx, id, row, within, usable)
	return snapAfter(cx, id, row.t, within, usable) or snapBefore(cx, id, row.t, usable)
end

---------------------------------------------------------------------------
-- Putting the world into the recorded state: ONE ROW PER EVENT NAME. A row gets (cx, row, args)
-- and returns true when it fired the event itself (else the event is fired as recorded).
---------------------------------------------------------------------------

local S_ -- H.state (set per replay)

local function setGroup(cx, d)
	local w, p = cx.w, cx.p
	local old = p.group
	if old then
		for _, n in ipairs(old.members) do
			local q = w:player(n)
			if q and q ~= p and q.group == old then q.group = nil end
		end
	end
	if not d.inGroup then
		p.group = nil
		return
	end
	local g = { members = { p.name }, raid = d.inRaid == true }
	local leader = d.lead and p.name or nil
	for _, u in ipairs(d.units or {}) do
		local q = bot(cx, u.name)
		if not q then
			cx:cannot("group member name", "a group member's name was not recorded (" .. tostring(u.name) .. ")")
		elseif q ~= p then
			g.members[#g.members + 1] = q.name
			q.group = g
			if str(u.class) then q.class = u.class end
			q.online = u.on ~= false
		end
		if q and (u.lead or u.rank == 2) then leader = q.name end
	end
	g.leader = leader or g.members[1]
	p.group = g
end

local function groupFrom(cx, row)
	local s = near(cx, "group", row, 1.5)
	if not s then
		cx:cannot("group state", "no group snapshot near " .. row.e .. ": the fake's group is left as it is")
		return
	end
	setGroup(cx, s.d)
end

local function spotFor(cx, d)
	local H = cx.H
	local id = num(d.map)
	if id and H.MAPS[id] then
		return { mapID = id, x = num(d.u) or 0.5, y = num(d.v) or 0.5, zone = str(d.zone) or H.MAPS[id][1], sub = str(d.sub) or "" }
	end
	local zone = str(d.zone)
	for _, s in pairs(H.SPOTS) do
		if zone and s.zone == zone then return s end
	end
	return nil
end

local function placeFrom(cx, row, args)
	local s = near(cx, "map", row, 1.5, function(d) return d.map ~= nil or d.zone ~= nil end)
	local p = cx.p
	if s then
		local spot = spotFor(cx, s.d)
		if spot then
			cx.w:placePlayer(p, spot)
		else
			cx:cannot("map " .. tostring(s.d.map), "map " .. tostring(s.d.map) .. " (" .. tostring(s.d.zone) .. ") is not in the fake's H.MAPS or H.SPOTS: the player stays where the fake had them")
		end
		if s.d.taxi ~= nil then p.onTaxi = s.d.taxi == true end
	end
	-- a loading screen after a summon: the summon is over
	if row.e == "PLAYER_ENTERING_WORLD" and p.pendingSummon and not args[1] and not args[2] then
		p.pendingSummon = nil
		cx.c.popups.CONFIRM_SUMMON = nil
	end
end

local function taxiFlag(cx, row)
	local s = snapAfter(cx, "map", row.t, 1.5)
	if s and s.d.taxi ~= nil then cx.p.onTaxi = s.d.taxi == true end
end

local function geomFrame(cx, name, o)
	local env = cx.c.env
	if rawget(env, name) or type(o) ~= "table" then return end
	if o.prot or not num(o.w) then
		cx:cannot("taxi frame geometry", name .. " was protected or had no size when recorded: the fake's own guess is used")
		return
	end
	local f = cx.H.createFrame(cx.c, "Frame", name, env.UIParent)
	f:SetSize(o.w, o.h)
	f:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", num(o.l) or 0, num(o.b) or 0)
	if str(o.strata) then f:SetFrameStrata(o.strata) end
	if num(o.lvl) then f:SetFrameLevel(o.lvl) end
	S_[f].gameFrame = true
	S_[f].shown = false
end

local function taxiOpen(cx, row)
	local s = snapAfter(cx, "taxi", row.t, 2, function(d) return d.nodes ~= nil end)
	local d = s and s.d or nil
	local nodes = {}
	if d then
		for i, n in ipairs(d.nodes) do
			nodes[i] = { name = str(n[1]) or ("Node " .. i), type = str(n[2]) or "NONE", cost = num(n[3]) or 0, x = num(n[4]) or 0, y = num(n[5]) or 0 }
		end
		cx.lastNodes = nodes
	else
		nodes = cx.lastNodes or {}
		if not cx.lastNodes then cx:cannot("taxi nodes", "no taxi snapshot with nodes for a flight map open: it opens with none") end
	end
	local shot = snapAfter(cx, "taxi", row.t, 2) or s
	local fname = false
	local frames = shot and shot.d.frames or {}
	for _, name in ipairs({ "TaxiFrame", "FlightMapFrame" }) do
		local o = frames[name]
		if not fname and type(o) == "table" and o.shown then
			fname = name
			geomFrame(cx, name, o)
		end
	end
	if not fname and shot then cx:cannot("taxi frame", "no flight map frame showed when recorded: the fake opens one with no frame") end
	cx.w:openTaxiMap(cx.c, nodes, { frame = fname })
	return true
end

local function taxiClose(cx)
	if cx.c.taxi and cx.c.taxi.open then
		cx.w:closeTaxiMap(cx.c)
		return true
	end
end

local function summonFrom(cx, row)
	local s = near(cx, "summon", row, 1.5)
	local d = s and s.d or {}
	local p = cx.p
	local by = bot(cx, d.by)
	if not by then cx:cannot("summoner", "the summoner's name was not recorded") end
	local spot = { mapID = p.mapID, x = p.x, y = p.y, zone = p.zone, sub = p.subZone }
	local area = str(d.area)
	if area then
		local found
		for _, sp in pairs(cx.H.SPOTS) do
			if sp.zone == area or sp.sub == area then found = sp end
		end
		if found then spot = found else cx:cannot("summon area " .. area, "the summon's place (" .. area .. ") is not one of the fake's H.SPOTS") end
	end
	local left = num(d.left) or 120
	p.pendingSummon = { by = by or p, at = cx.w.time - math.max(0, 120 - left), mapID = spot.mapID, x = spot.x, y = spot.y,
		zone = spot.zone, sub = spot.sub or "", shownBy = by and by.name or nil }
	cx.c.popups.CONFIRM_SUMMON = { which = "CONFIRM_SUMMON" }
end

local function summonGone(cx)
	cx.p.pendingSummon = nil
	cx.c.popups.CONFIRM_SUMMON = nil
end

local function tradeFrame(cx, shown)
	local f = rawget(cx.c.env, "TradeFrame") or cx.c.env.TradeFrame
	if f and S_[f] then S_[f].shown = shown end
end

local function tradeFrom(cx, row)
	local s = near(cx, "trade", row, 1)
	local d = s and s.d or {}
	local p = cx.p
	local t = p.trade
	if not t then
		local q = bot(cx, d.with)
		if not q then
			cx:cannot("trade partner", "the trade partner's name was not recorded: no trade is open in the fake")
			return
		end
		q.mapID, q.x, q.y, q.zone, q.subZone = p.mapID, p.x, p.y, p.zone, p.subZone
		t = { money = { [p.name] = 0, [q.name] = 0 }, accepted = { [p.name] = 0, [q.name] = 0 }, a = p, b = q }
		p.trade, q.trade = t, t
	end
	local q = t.a == p and t.b or t.a
	if num(d.mine) then t.money[p.name] = d.mine end
	if num(d.theirs) then t.money[q.name] = d.theirs end
	if num(d.money) then p.money = d.money end
	tradeFrame(cx, true)
end

local function tradeAccept(cx, row, args)
	local t = cx.p.trade
	if not t then return end
	local q = t.a == cx.p and t.b or t.a
	t.accepted[cx.p.name] = num(args[1]) or 0
	t.accepted[q.name] = num(args[2]) or 0
end

local function tradeGone(cx, row)
	local p = cx.p
	local t = p.trade
	if t then
		t.a.trade, t.b.trade = nil, nil
	end
	tradeFrame(cx, false)
	local s = snapAfter(cx, "trade", row.t, 1)
	if s and num(s.d.money) then p.money = s.d.money end
end

local function moneyFrom(cx, row)
	local s = snapAfter(cx, "trade", row.t, 1)
	if s and num(s.d.money) then cx.p.money = s.d.money end
end

local function invited(cx, row, args)
	local q = bot(cx, args[1])
	if q then
		cx.p.pendingInvite = q
		cx.c.popups.PARTY_INVITE = { which = "PARTY_INVITE" }
	end
end

-- Wuber's addon message, as the fake delivers one (World:inject): a channel message carries this
-- client's own number for that channel
-- Ride ids are made by Wuber itself: once the replay's own ride has an id, the recorded one in the
-- messages that answer it becomes the replay's (rep.ids), in every later message too.
local function mapIds(cx, text)
	if type(text) ~= "string" then return text end
	local W = cx.c.W
	local mine = type(W.ride) == "table" and type(W.ride.id) == "string" and W.ride.id or nil
	local id = text:match("^[%w]+~[%w]+~([%w]+)")
	-- the recorded ride ids (the "wuber" snapshots say them); a recording without them: an id of the same length
	local known = next(cx.rideIds) == nil or cx.rideIds[id or ""]
	if mine and id and known and #id == #mine and id ~= mine and not cx.ids[id] and not cx.idsUsed[mine] and (cx.asked or cx.opts.ids) then
		cx.ids[id] = mine
		cx.idsUsed[mine] = true
		cx.rep.ids[id] = mine
	end
	for from, to in pairs(cx.ids) do
		if text:find(from, 1, true) then text = text:gsub("~" .. from .. "~", "~" .. to .. "~"):gsub("~" .. from .. "$", "~" .. to) end
	end
	return text
end

local function addonMsg(cx, row, args)
	args[2] = mapIds(cx, args[2])
	if args[3] == "CHANNEL" and type(args[8]) == "string" then
		for _, ch in ipairs(cx.p.channels or {}) do
			if ch.name:lower() == args[8]:lower() then args[7] = ch.index end
		end
	end
end

local function combatOn(cx) cx.w:enterCombat(cx.c) return true end
local function combatOff(cx) cx.w:leaveCombat(cx.c) return true end

local function screenFrom(cx, row)
	local s = snapAfter(cx, "screen", row.t, 2)
	if s and num(s.d.sw) and num(s.d.sh) then
		local u = S_[cx.c.env.UIParent]
		u.w, u.h = s.d.sw, s.d.sh
	end
end

local function plates(cx, row)
	cx:cannot("nameplate units", "the recording does not say whose nameplate " .. tostring(row.a[1]) .. " is: fired with no player on it")
end

local function castState(cx, row)
	local s = snapAfter(cx, "cast", row.t, 0.5)
	if s and (s.d.cast or s.d.channel) then
		cx:cannot("cast state", "UnitCastingInfo / UnitChannelInfo are not put into the fake (the event is fired as recorded)")
	end
end

local function chatLine(cx, row, args, n)
	cx.c:chatEvent(row.e, unpack(args, 1, n))
	return true
end

RP.STATE = {
	TAXIMAP_OPENED = taxiOpen,
	TAXIMAP_CLOSED = taxiClose,
	GROUP_ROSTER_UPDATE = groupFrom, GROUP_JOINED = groupFrom, GROUP_LEFT = groupFrom, PARTY_LEADER_CHANGED = groupFrom,
	PARTY_INVITE_REQUEST = invited,
	CONFIRM_SUMMON = summonFrom,
	CANCEL_SUMMON = summonGone,
	TRADE_SHOW = tradeFrom, TRADE_MONEY_CHANGED = tradeFrom, PLAYER_TRADE_MONEY = tradeFrom, TRADE_UPDATE = tradeFrom,
	TRADE_ACCEPT_UPDATE = tradeAccept,
	TRADE_CLOSED = tradeGone, TRADE_REQUEST_CANCEL = tradeGone,
	PLAYER_MONEY = moneyFrom,
	PLAYER_ENTERING_WORLD = placeFrom, ZONE_CHANGED = placeFrom, ZONE_CHANGED_NEW_AREA = placeFrom, ZONE_CHANGED_INDOORS = placeFrom,
	PLAYER_CONTROL_LOST = taxiFlag, PLAYER_CONTROL_GAINED = taxiFlag,
	CHAT_MSG_ADDON = addonMsg,
	CHAT_MSG_SAY = chatLine, CHAT_MSG_YELL = chatLine, CHAT_MSG_WHISPER = chatLine, CHAT_MSG_WHISPER_INFORM = chatLine,
	CHAT_MSG_CHANNEL = chatLine, CHAT_MSG_PARTY = chatLine, CHAT_MSG_PARTY_LEADER = chatLine, CHAT_MSG_RAID = chatLine,
	CHAT_MSG_RAID_LEADER = chatLine, CHAT_MSG_SYSTEM = chatLine,
	PLAYER_REGEN_DISABLED = combatOn, PLAYER_REGEN_ENABLED = combatOff,
	UI_SCALE_CHANGED = screenFrom, DISPLAY_SIZE_CHANGED = screenFrom,
	NAME_PLATE_UNIT_ADDED = plates, NAME_PLATE_UNIT_REMOVED = plates,
	UNIT_SPELLCAST_START = castState, UNIT_SPELLCAST_CHANNEL_START = castState,
}

---------------------------------------------------------------------------
-- The expectations: what a "wuber" snapshot read, and the same read from the fake client
---------------------------------------------------------------------------

local function yes(v) return v == true end
local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end

local function shownFrames(cx)
	local env = cx.c.env
	local out = {}
	for _, row in ipairs(cx.R.FRAMES or {}) do
		local f = rawget(env, row[1])
		if type(f) == "table" and type(f.IsShown) == "function" and f:IsShown() then out[#out + 1] = row[1] end
	end
	table.sort(out)
	return table.concat(out, ",")
end

local function recordedFrames(d)
	local out = {}
	for name, o in pairs(d.f or {}) do
		if o ~= 0 then out[#out + 1] = name end
	end
	table.sort(out)
	return table.concat(out, ",")
end

local function birdCard(c)
	local B = c.W and call(c.W.Mod, "UI.Bird")
	return type(B) == "table" and call(B.Card) or nil
end

local function plainRide(v)
	if type(v) ~= "table" then return "none" end
	return tostring(v.state)
end

-- one row per field: { name, from the snapshot (d), from the fake client (cx) }
RP.FIELDS = {
	{ "open", function(d) return yes(d.open) end, function(cx) return yes(call(cx.UI.IsShown)) end },
	{ "tab", function(d) return d.tab end, function(cx) return cx.UI.state and cx.UI.state.tab end },
	{ "screen", function(d) return d.screen end, function(cx) return cx.UI.state and cx.UI.state.screen end },
	{ "settings", function(d) return yes(d.settings) end, function(cx) return yes(call(cx.UI.SettingsShown)) end },
	{ "help", function(d) return yes(d.help) end, function(cx) return yes(call(cx.UI.HelpShown)) end },
	{ "splash", function(d) return yes(d.splash) end, function(cx) return cx.UI.state and cx.UI.state.splashing and true or false end },
	{ "coach", function(d) return yes(d.coach) end, function(cx) return cx.UI.state and cx.UI.state.coaching and true or false end },
	{ "frames", recordedFrames, shownFrames },
	{ "tip", function(d) return d.cards ~= nil and d.cards.tip ~= nil end, function(cx)
		local f = rawget(cx.c.env, "WuberTipCard")
		return type(f) == "table" and f:IsVisible() == true
	end },
	{ "bird", function(d) return d.cards ~= nil and d.cards.bird ~= nil end, function(cx)
		local f = birdCard(cx.c)
		return type(f) == "table" and f:IsVisible() == true
	end },
	{ "ride", function(d) return plainRide(d.ride) end, function(cx) return plainRide(cx.c.W.ride) end },
	{ "dmode", function(d) return d.dmode end, function(cx) return cx.D and call(cx.D.Mode) end },
	{ "dscreen", function(d) return d.dscreen end, function(cx) return cx.D and call(cx.D.CurrentScreen) end },
	{ "sheet", function(d) return yes(d.sheet) end, function(cx) return cx.D and yes(call(cx.D.SheetOpen)) or false end },
	{ "drivers", function(d) return d.drivers end, function(cx)
		local n = 0
		for _ in pairs(type(cx.c.W.drivers) == "table" and cx.c.W.drivers or {}) do n = n + 1 end
		return n
	end },
}

-- The player's own clicks (not in the recording): one row per field, done through Wuber's UI.
-- A row with transition = true acts only on a change seen inside the session (never on its first
-- snapshot: a ride there came from the saved data, not from a click).
RP.INPUTS = {
	{ "ride", function(cx, v, d)
		local who = type(d.ride) == "table" and d.ride.driver
		local W = cx.c.W
		if type(who) ~= "string" or type(W.RequestRide) ~= "function" then
			cx:cannot("ride request", "a ride began but the recording does not say with whom: not asked for")
			return
		end
		cx.asked = true
		W.RequestRide(W.Key(RP.botName(who)))
	end, transition = true, from = "none" },
	{ "open", function(cx, v) cx.UI.Toggle(v) end },
	{ "tab", function(cx, v) if v and cx.UI.SelectTab then cx.UI.SelectTab(v) end end },
	{ "settings", function(cx, v) if v then cx.UI.OpenSettings() elseif cx.UI.CloseSettings then cx.UI.CloseSettings() end end },
	{ "help", function(cx, v) if v then cx.UI.OpenHelp() elseif cx.UI.CloseHelp then cx.UI.CloseHelp() end end },
}

local function fieldRow(name)
	for _, f in ipairs(RP.FIELDS) do
		if f[1] == name then return f end
	end
end

---------------------------------------------------------------------------
-- The replay
---------------------------------------------------------------------------

local Cx = {}
Cx.__index = Cx

function Cx:cannot(what, why)
	if self.cannotSeen[what] then return end
	self.cannotSeen[what] = true
	self.rep.cannot[#self.rep.cannot + 1] = { what = what, why = why, t = self.now }
end

-- an event that reaches Wuber once the replay has begun (rep.delivered[event]: how many times)
function Cx:pass(client, event, ...)
	local d = self.rep.delivered
	d[event] = (d[event] or 0) + 1
	return self.H.Client.fire(client, event, ...)
end

-- the fake world fired an event by itself: match it with the recording (see the header)
function Cx:fakeMade(client, event, ...)
	local R = self.R
	local sig = fakeSig(self, event, ...)
	local t = self.w.time - self.base
	local best, bestD
	for _, row in ipairs(self.byEvent[event] or {}) do
		if not row.merged and row.sig == sig then
			local dt = math.abs(row.t - t)
			if dt <= RP.WINDOW and (not bestD or dt < bestD) then best, bestD = row, dt end
		end
	end
	if best then
		best.merged = true
		self.rep.merged = self.rep.merged + 1
		if best.done then return end -- the recording's copy was delivered already
		best.consumed = true
		return self:pass(client, event, ...)
	end
	local keeps = R.LISTED[event] and not self.unknown[event]
	if keeps and R.FILTER[event] then
		local ok, kept = pcall(R.FILTER[event], ...)
		keeps = ok and kept
	end
	if keeps and (self.p.combat or (self.fx.skip and self.fx.skip[event])) then keeps = false end
	if not keeps or self.opts.extra == "deliver" or not self.started then return self:pass(client, event, ...) end
	local ex = self.rep.extra
	if #ex < 200 then ex[#ex + 1] = { t = t, e = event, sig = sig } end
	self.rep.held = self.rep.held + 1
end

function Cx:advanceTo(t)
	local target = self.base + t
	if target > self.w.time then self.w:advance(target - self.w.time) end
	self.now = t
end

function Cx:deliver(row)
	local H, c = self.H, self.c
	self.recent[#self.recent + 1] = row
	if row.consumed then return end
	if row.e:find("^REC_") then -- the recorder's own rows (/rec mark): not a game event
		self.rep.marks[#self.rep.marks + 1] = { t = row.t, e = row.e, text = row.a[1] }
		row.done = true
		return
	end
	if not H.KNOWN_EVENTS[row.e] then
		local u = self.rep.unknownEvents
		if not u[row.e] then
			u[row.e] = 0
			self.rep.unknownList[#self.rep.unknownList + 1] = row.e
		end
		u[row.e] = u[row.e] + 1
		row.done = true
		return
	end
	local args, n = RP.rebuild(self, row)
	self.replaying = true
	local st = RP.STATE[row.e]
	local ok, fired = true, false
	if st then ok, fired = pcall(st, self, row, args, n) end
	if not ok then
		self.rep.errors[#self.rep.errors + 1] = "state row " .. row.e .. ": " .. tostring(fired)
		fired = false
	end
	if not fired then c:fire(row.e, unpack(args, 1, n)) end
	self.replaying = false
	row.done = true
	self.rep.fired = self.rep.fired + 1
	if self.bootLogin == row then RP.applySettings(self) end -- (Wuber's own login has run)
	if self.bootLast == row and self.H.KNOWN_EVENTS.VARIABLES_LOADED then
		self.replaying = true
		c:fire("VARIABLES_LOADED")
		self.replaying = false
	end
end

function Cx:before(t)
	local out = {}
	for i = #self.recent, 1, -1 do
		local r = self.recent[i]
		if r.t < t - 5 or #out >= 5 then break end
		table.insert(out, 1, ("%.2f %s"):format(r.t, r.e))
	end
	return out
end

function Cx:applyInputs(snap, prev)
	for _, row in ipairs(RP.INPUTS) do
		local f = fieldRow(row[1])
		local want = f[2](snap.d)
		local was = prev and f[2](prev.d)
		local okT = not row.transition or (prev ~= nil and (row.from == nil or (was == row.from and f[3](self) == row.from)))
		if okT and want ~= nil and (not prev or want ~= was) and f[3](self) ~= want then
			local ok, err = pcall(row[2], self, want, snap.d)
			self.rep.inputs[#self.rep.inputs + 1] = { t = self.now, field = row[1], v = want, ok = ok, err = not ok and tostring(err) or nil }
		end
	end
end

function Cx:expect(snap, index)
	local d = snap.d
	if d.loaded == false then return end
	for _, f in ipairs(RP.FIELDS) do
		local okE, want = pcall(f[2], d)
		local okG, got = pcall(f[3], self)
		if not okG then got = "<error: " .. tostring(got) .. ">" end
		if okE and want ~= nil then
			local match = want == got
			local e = { id = "replay:" .. f[1], field = f[1], t = snap.t, why = snap.why, snap = index, expected = want, got = got, match = match }
			self.rep.expectations[#self.rep.expectations + 1] = e
			self.rep.total = self.rep.total + 1
			if match then
				self.rep.matched = self.rep.matched + 1
			else
				e.before = self:before(snap.t)
				self.rep.mismatches[#self.rep.mismatches + 1] = e
			end
		end
	end
end

local BOOT = { ADDON_LOADED = true, PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true }

local function firstSnap(fx, id, usable)
	for _, s in ipairs(fx.snaps or {}) do
		if s.id == id and (not usable or usable(s.d)) then return s end
	end
end

-- A boot session's kind from its recorded login rows: "reload" (PLAYER_ENTERING_WORLD(false, true)),
-- "login" (true, false), "boot" (neither); nil for a session /rec on started.
function RP.bootKind(fx)
	if fx.why ~= "boot" then return nil end
	for _, e in ipairs(fx.events or {}) do
		if not BOOT[e.e] then break end
		if e.e == "PLAYER_ENTERING_WORLD" then
			if e.a[2] == true then return "reload" end
			if e.a[1] == true then return "login" end
			return "boot"
		end
	end
	return "boot"
end

-- The channels Wuber joins itself (not the game's own)
RP.OWN_CHANNELS = { wubernet = true }

-- The chat channels from the recorder's "channels" snapshots (GetChannelList as it was):
-- { first = { t, n } (the first snapshot), full = { t, n } (the first with a list in it and n > 0),
--   all = { { index, name } } (that list), game = how many of them are the game's own } or {}.
function RP.channelPlan(fx)
	local plan = {}
	for _, s in ipairs(fx.snaps or {}) do
		if s.id == "channels" and type(s.d) == "table" then
			local list = type(s.d.list) == "table" and s.d.list or nil
			local n = num(s.d.n) or (list and #list) or nil
			if n and not plan.first then plan.first = { t = s.t, n = n } end
			if n and n > 0 and list and not plan.full then plan.full = { t = s.t, n = n, list = list } end
		end
	end
	if plan.full then
		plan.all, plan.game = {}, 0
		for _, row in ipairs(plan.full.list) do
			local index, name = num(row[1]), str(row[2])
			if index and name then
				plan.all[#plan.all + 1] = { index = index, name = name }
				if not RP.OWN_CHANNELS[name:lower()] then plan.game = plan.game + 1 end
			end
		end
	end
	return plan
end

-- Wuber's switches as the session began (the "settings" snapshot's db scalars) into W.db, once
-- Wuber's own login has run: a boolean, or a short lower-case choice, of a field Wuber already has
-- with a value of the same type. Numbers (times, counts, places), tables and long strings are not
-- touched. rep.settings = { set = fields changed, same = fields already as recorded, skipped = n }.
function RP.applySettings(cx)
	local rep = cx.rep
	if rep.settings then return end
	local s = firstSnap(cx.fx, "settings", function(d) return type(d.db) == "table" end)
	if not s then
		cx:cannot("settings", "no settings snapshot: Wuber starts from its own defaults")
		rep.settings = { set = {}, same = 0, skipped = 0 }
		return
	end
	local W = cx.c.W
	local db = type(W) == "table" and W.db or nil
	rep.settings = { set = {}, same = 0, skipped = 0 }
	if type(db) ~= "table" then return end
	local keys = {}
	for k in pairs(s.d.db) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local v, cur = s.d.db[k], db[k]
		local okType = (type(v) == "boolean" or type(v) == "string") and type(cur) == type(v)
		if not okType then
			rep.settings.skipped = rep.settings.skipped + 1
		elseif cur == v then
			rep.settings.same = rep.settings.same + 1
		else
			db[k] = v
			rep.settings.set[#rep.settings.set + 1] = k
		end
	end
end

function RP.replay(T, fx, opts)
	opts = opts or {}
	local H = T.H
	S_ = H.state
	local R = RP.recorder()
	fx = copy(fx)
	fx.events, fx.snaps = fx.events or {}, fx.snaps or {}
	local rep = { name = opts.name or (tostring(fx.source) .. "-" .. tostring(fx.id) .. "-" .. tostring(fx.char)), expectations = {},
		mismatches = {}, total = 0, matched = 0, unknownEvents = {}, unknownList = {}, cannot = {}, names = {}, inputs = {},
		extra = {}, held = 0, merged = 0, fired = 0, errors = {}, gaps = 0, secretArgs = 0, droppedArgs = 0, ids = {}, marks = {},
		delivered = {} }
	local cx = setmetatable({ T = T, H = H, R = R, fx = fx, opts = opts, rep = rep, cannotSeen = {}, recent = {}, byEvent = {},
		unknown = {}, now = 0, ids = {}, idsUsed = {}, rideIds = {} }, Cx)
	for _, s in ipairs(fx.snaps or {}) do
		if s.id == "wuber" and type(s.d) == "table" and type(s.d.ride) == "table" and type(s.d.ride.id) == "string" then cx.rideIds[s.d.ride.id] = true end
	end
	for from, to in pairs(opts.ids or {}) do
		cx.ids[from], cx.idsUsed[to], rep.ids[from] = to, true, to
	end
	for _, e in ipairs(fx.unknownEvents or {}) do cx.unknown[e] = true end
	for _, row in ipairs(fx.events) do
		row.sig = rowSig(cx, row)
		cx.byEvent[row.e] = cx.byEvent[row.e] or {}
		table.insert(cx.byEvent[row.e], row)
		if row.gap then rep.gaps = rep.gaps + row.gap end
	end
	if rep.gaps > 0 then cx:cannot("rate-capped rows", rep.gaps .. " rows were only counted by the recorder (its rate cap): they cannot be replayed") end
	if (fx.dropped and (fx.dropped.events or 0) > 0) then cx:cannot("ring", fx.dropped.events .. " event rows were overwritten in the recorder's ring") end

	-- the client: as recorded
	local w = H.NewWorld(opts.world)
	cx.w = w
	-- the clock: a recording made in the fake game says (its epoch) when it began on the fake's own
	-- clock (H.EPOCH + w.time); opts.clock (a chain of sessions) sets it too
	local clock = opts.clock
	if not clock and fx.source == "sim" and RP.epochOf(fx) then clock = RP.epochOf(fx) - H.EPOCH end
	if clock and fx.why == "boot" and clock > w.time then w.time, w.lastFrame = clock, clock end
	local me = fx.char or T.TESTCHAR
	local copts = { addons = { "Wuber" }, class = fx.class or "MAGE", faction = fx.faction, allowMissing = not T.HAVE_UI,
		saved = opts.saved and { Wuber = copy(opts.saved) } or nil, money = opts.money }
	local scr = firstSnap(fx, "screen", function(d) return num(d.sw) ~= nil end)
	if scr then
		copts.screenW, copts.screenH, copts.physW, copts.physH = scr.d.sw, scr.d.sh, num(scr.d.pw), num(scr.d.ph)
		local scale = type(scr.d.ui) == "table" and num(scr.d.ui.s) or nil
		if scale and scale ~= 1 then copts.prepare = function(env) env.UIParent:SetScale(scale) end end
	else
		cx:cannot("screen", "no screen snapshot: the fake's 1920 x 1080 is used")
	end
	local mapS = firstSnap(fx, "map", function(d) return d.map ~= nil or d.zone ~= nil end)
	if mapS then
		local spot = spotFor(cx, mapS.d)
		if spot then copts.spot = spot else
			cx:cannot("map " .. tostring(mapS.d.map), "the first map snapshot's place is not in the fake's maps: Orgrimmar is used")
		end
	end
	-- the client's chat channels: how many of the game's own the "channels" snapshots list
	local kind = RP.bootKind(fx)
	local plan = RP.channelPlan(fx)
	rep.kind, rep.channels = kind or "on", plan
	if plan.game then
		copts.channels = math.min(10, plan.game)
	else
		cx:cannot("chat channels", "no channels snapshot with a list: the fake's five game channels are used")
	end
	-- the player and the group they were in when the session began (the first group snapshot)
	local me0 = w:player(me) or w:addBot(me, { faction = fx.faction, class = copts.class, spot = copts.spot })
	if fx.faction then me0.faction = fx.faction end
	cx.p = me0
	local g0 = firstSnap(fx, "group")
	if g0 and g0.t <= 3 and g0.d.inGroup then setGroup(cx, g0.d) end
	-- every player the recording names is online in the fake from the start (as when recorded)
	for _, row in ipairs(fx.events) do
		local pol = R.POLICY[row.e] or ""
		for i = 1, math.min(row.n, #pol) do
			if pol:sub(i, i) == "n" then bot(cx, row.a[i]) end
		end
	end
	for _, s in ipairs(fx.snaps) do
		if s.id == "group" then for _, u in ipairs(s.d.units or {}) do bot(cx, u.name) end end
		if s.id == "trade" then bot(cx, s.d.with) end
		if s.id == "summon" then bot(cx, s.d.by) end
	end
	-- the client starts the way the session did (RP.bootKind, RP.channelPlan)
	local lead
	if kind == "reload" then
		-- a /reload: PLAYER_ENTERING_WORLD(false, true), no zone event, the channels it had, Wuber's too
		copts.reload, copts.keepChannels = true, true
		if plan.first and plan.first.n > 0 and plan.all then
			me0.channels = {}
			for _, ch in ipairs(plan.all) do
				me0.channels[#me0.channels + 1] = { index = ch.index, name = ch.name }
				local key = ch.name:lower()
				if RP.OWN_CHANNELS[key] and not w.channels[key] then w.channels[key] = { name = ch.name, members = {} } end
			end
		end
	elseif kind == "login" then
		-- a fresh login: no channels, then the game's and the zone event, as late as the recording shows
		if plan.first and plan.first.n > 0 then
			copts.channelsArrive = "atOnce"
		elseif plan.full then
			w.loginDelay = math.max(0.05, plan.full.t)
		end
	elseif kind == nil then
		lead = opts.lead or num(fx.sinceLoad)
		if not lead and clock and clock >= w.time and clock - w.time < 3600 then lead = clock - w.time end
		if not lead then
			lead = RP.DEFAULT_LEAD
			cx:cannot("time since login", "the recording does not say how long after login /rec on came: " .. lead .. " s is assumed (opts.lead)")
		end
		-- /rec on soon after a login: the channels were there sooner than the fake's loginDelay, or came later
		if plan.first and plan.first.t <= 0.5 then
			if plan.first.n > 0 and lead < w.loginDelay then
				copts.channelsArrive = "atOnce"
			elseif plan.first.n == 0 and plan.full then
				w.loginDelay = math.max(0.05, lead + plan.full.t)
			end
		end
	end
	local boot = fx.why == "boot"
	local c
	if boot then
		-- the recorded login rows replace the fake's own (fired below at their times)
		local faked = {}
		local real = H.Client.fire
		H.Client.fire = function(_, e, ...)
			local a = {}
			for i = 1, select("#", ...) do a[i] = tostring((select(i, ...))) end
			faked[#faked + 1] = e .. "(" .. table.concat(a, ",") .. ")"
		end
		local ok, res = pcall(w.addClient, w, me, copts)
		H.Client.fire = real
		if not ok then error(res, 0) end
		c = res
		rep.boot = { fake = faked, recorded = {} }
		for _, row in ipairs(fx.events) do
			if not BOOT[row.e] then break end
			local a = {}
			for i = 1, row.n do a[i] = tostring(row.a[i]) end
			rep.boot.recorded[#rep.boot.recorded + 1] = row.e .. "(" .. table.concat(a, ",") .. ")"
			if row.e == "ADDON_LOADED" then cx.bootLast = row end
			if row.e == "PLAYER_LOGIN" then cx.bootLogin = row end
		end
		cx.base = w.time
	else
		c = w:addClient(me, copts)
		cx.c, cx.p = c, c.player
		RP.applySettings(cx) -- (Wuber's login has run)
		if lead > 0 then w:advance(lead) end
		cx.base = w.time
	end
	cx.c, cx.p = c, c.player
	if boot and not opts.saved then
		cx:cannot("saved variables", "a boot session starts from saved data the recording does not carry: empty WuberDB (RP.replayChain carries it from the session before)")
	end
	cx.UI = c.W and c.W.UI or {}
	cx.D = c.W and c.W.Driver or nil
	c.fire = function(self, event, ...)
		if not cx.started then return H.Client.fire(self, event, ...) end
		if cx.replaying then return cx:pass(self, event, ...) end
		return cx:fakeMade(self, event, ...)
	end
	cx.started = true

	-- the timeline: events, then the expectations at the same time. A snapshot taken at once by an
	-- event (delay 0: REC_ON, PLAYER_LOGIN, PLAYER_ENTERING_WORLD) comes right after that event's row
	-- (REC_ON of a boot session: after the recorder's own ADDON_LOADED), before the rows after it.
	local steps = {}
	for i, row in ipairs(fx.events) do steps[#steps + 1] = { t = row.t, k = 1, i = i, row = row } end
	local function anchor(s)
		local found
		for i, row in ipairs(fx.events) do
			if math.abs(row.t - s.t) < 0.0005 then
				if row.e == s.why or (s.why == "REC_ON" and row.e == "ADDON_LOADED" and row.a[1] == "WuberRec") then found = i end
			end
		end
		return found
	end
	local prev
	for i, s in ipairs(fx.snaps) do
		if s.id == "wuber" then
			local at = prev and math.max(prev.t, s.t - 1) + 0.001 or s.t
			if at > s.t then at = s.t end
			local a = anchor(s)
			-- (a snapshot a timer took (later than its event, or the ticker's) comes before the rows
			-- of that same instant: in the fake, timers due at a time run before what is done then)
			-- A snapshot an event took at once: its inputs come right after that event, so what Wuber
			-- does by itself on the event (the phone opening at an arrival) is not taken for a click;
			-- a click earlier than that would have shown in a ticker's snapshot.
			if a then
				steps[#steps + 1] = { t = s.t, k = 1, i = a + 0.4, snap = s, prev = prev, input = true }
			else
				steps[#steps + 1] = { t = at, k = 0, i = 2 * i, snap = s, prev = prev, input = true }
			end
			steps[#steps + 1] = a and { t = s.t, k = 1, i = a + 0.5, snap = s } or { t = s.t, k = 0, i = 2 * i + 1, snap = s }
			prev = s
		end
	end
	table.sort(steps, function(a, b)
		if a.t ~= b.t then return a.t < b.t end
		if a.k ~= b.k then return a.k < b.k end
		return a.i < b.i
	end)
	local okRun, runErr = pcall(function()
		for _, st in ipairs(steps) do
			cx:advanceTo(st.t)
			if st.row then
				cx:deliver(st.row)
			elseif st.input then
				cx:applyInputs(st.snap, st.prev)
			else
				cx:expect(st.snap, st.i)
			end
		end
	end)
	if not okRun then rep.errors[#rep.errors + 1] = "replay: " .. tostring(runErr) end
	for _, e in ipairs(w.errors) do rep.errors[#rep.errors + 1] = e end
	rep.world, rep.client = w, c
	rep.ok = #rep.mismatches == 0 and #rep.errors == 0
	return rep
end

-- A run of sessions of one character (oldest first): a boot session that follows the one before
-- within RP.CHAIN_GAP seconds starts with that replay's saved variables (as the game keeps them), on
-- its clock, with its ride ids. Returns the list of reports.
RP.CHAIN_GAP = 300
function RP.chained(prev, fx)
	if not prev or fx.why ~= "boot" or prev.char ~= fx.char then return false end
	local pe, ne = RP.epochOf(prev), RP.epochOf(fx)
	if not pe or not ne then return false end
	local gap = ne - (pe + (num(prev.ended) or 0))
	return gap >= -2 and gap <= RP.CHAIN_GAP, gap
end

function RP.replayChain(T, list, opts)
	opts = opts or {}
	local out = {}
	local prevFx, prevRep
	for i, fx in ipairs(list) do
		local o = copy(opts)
		o.name = (opts.names and opts.names[i]) or o.name
		local linked, gap = RP.chained(prevFx, fx)
		if linked and prevRep and prevRep.client then
			o.saved = copy(rawget(prevRep.client.env, "WuberDB"))
			o.ids = copy(prevRep.ids)
			if fx.source ~= "sim" then o.clock = prevRep.world.time + math.max(0, gap) end
		end
		local rep = RP.replay(T, fx, o)
		rep.chained = linked
		out[#out + 1] = rep
		prevFx, prevRep = fx, rep
	end
	return out
end

---------------------------------------------------------------------------
-- The report as plain lines
---------------------------------------------------------------------------

local function show(v)
	if type(v) == "string" then return '"' .. v .. '"' end
	return tostring(v)
end

function RP.lines(rep, max)
	max = max or 40
	local out = {}
	out[#out + 1] = ("replay %s: %d of %d expectations match, %d events fired, %d merged with the fake's own, %d fake events held back"):format(
		rep.name, rep.matched, rep.total, rep.fired, rep.merged, rep.held)
	for i, m in ipairs(rep.mismatches) do
		if i > max then
			out[#out + 1] = ("  ... and %d more mismatches"):format(#rep.mismatches - max)
			break
		end
		out[#out + 1] = ("  MISMATCH %s at %.2f (%s): expected %s, got %s; before: %s"):format(m.id, m.t, tostring(m.why), show(m.expected),
			show(m.got), table.concat(m.before or {}, ", "))
	end
	if #rep.unknownList > 0 then out[#out + 1] = "  events the fake does not know: " .. table.concat(rep.unknownList, ", ") end
	for _, c in ipairs(rep.cannot) do out[#out + 1] = "  cannot: " .. c.what .. ": " .. c.why end
	for _, e in ipairs(rep.errors) do out[#out + 1] = "  ERROR " .. e end
	for i, e in ipairs(rep.extra) do
		if i > 10 then break end
		out[#out + 1] = ("  held back (the fake made it, the recording has none): %.2f %s"):format(e.t, e.sig)
	end
	return out
end

return RP
