-- Wuber Lab: a developer-only test mode for Wuber and Ritual Rides. NEVER SHIP THIS ADDON.
-- It only watches (wraps functions and calls the originals), logs to WuberLabDB, and offers
-- local test helpers. Wuber and Ritual Rides work exactly the same without it.
--
-- Log.lua: the namespace, the timeline (WuberLabDB.chars[name].lines, at most L.CAP lines per
-- character), safe helpers, the game events worth logging, Lua errors, and the login probes.
--
-- A timeline line: "<epoch.ms>|<character>|<kind>|<text>"
--   epoch.ms: time() with GetTime()'s fraction (the four game windows share one PC clock, so
--   lines from all characters merge by time). kinds: see L.KINDS.

local ADDON, L = ...
ADDON = ADDON or "WuberLab"
WuberLab = L

L.ADDON = ADDON
L.VERSION = "1.2.0"
L.CAP = 6000            -- timeline lines kept per character
L.TEXT_MAX = 300        -- bytes of text per line
L.PENDING_MAX = 800     -- lines held before the character's name is known

-- The tester's four characters (keys: lower case, one space) and what each does in a test
L.CAST = {
	["anita lift"] = "driver",
	["farra way"] = "team",
	["hayley cab"] = "team",
	["wuber rocks"] = "rider",
}

L.KINDS = {
	login = "login and versions", ev = "game event", fire = "Wuber internal event", ride = "rider's ride state",
	ridef = "rider's ride detail", drv = "driver's ride step", ["msg>"] = "addon message out", ["msg<"] = "addon message in",
	rr = "Ritual Rides", api = "WuberAPI call", prov = "provider call", whsp = "whisper", sys = "system line",
	block = "blocked action", err = "Lua error", werr = "Wuber error", perf = "frame rate and memory",
	self = "self-test", mark = "bookmark", fake = "fake driver (local only)", check = "checklist", fx = "effect",
	tool = "lab tool", probe = "client probe", ui = "Wuber window", try = "W.Try", laberr = "lab fault",
}

---------------------------------------------------------------------------
-- Safe helpers (any API return may be secret; any API may be missing)
---------------------------------------------------------------------------

local function secret(v)
	if type(issecretvalue) ~= "function" then return false end
	local ok, is = pcall(issecretvalue, v)
	return not ok or is == true
end
L.IsSecret = secret

function L.plain(v)
	if secret(v) then return nil end
	return v
end

function L.str(v)
	v = L.plain(v)
	if type(v) == "string" and v ~= "" then return v end
	if type(v) == "number" then return tostring(v) end
	return nil
end

function L.num(v)
	v = L.plain(v)
	if type(v) == "number" and v == v then return v end
	return nil
end

-- Calls fn(...) under pcall: its results, or nothing on error / when fn isn't a function.
local function tail(ok, ...)
	if not ok then return nil end
	return ...
end
function L.call(fn, ...)
	if type(fn) ~= "function" then return nil end
	return tail(pcall(fn, ...))
end

-- Shows any value in a log line (secret values as <secret>).
function L.show(v)
	if secret(v) then return "<secret>" end
	if v == nil then return "nil" end
	if type(v) == "table" then return "{table}" end
	if type(v) == "function" then return "{fn}" end
	return tostring(v)
end

function L.W()
	local w = rawget(_G, "Wuber")
	if type(w) == "table" then return w end
	return nil
end

-- (design round 4, job 136) Wuber's tips. The 2.4 Wuber draws them on its own card, the frame "WuberTip" (W.Theme.TipShow /
-- TipHide / TipOwner) and leaves the game's GameTooltip alone; an older Wuber draws them on GameTooltip. Every place of the
-- Lab that reads or dismisses a Wuber tip goes through here, so it works with both.
--   L.Tip.card()          the WuberTip frame, or nil (it is made when the first tip shows)
--   L.Tip.surface()       the frame a tip is showing on now, and "card" or "game"; nil when none
--   L.Tip.lines(f, kind)  its shown lines: { { fs = fontstring, text = words }, ... } (the title first)
--   L.Tip.owner()         the frame whose tip shows now, or nil
--   L.Tip.hide()          puts a Wuber tip away: the card through W.Theme.TipHide, else the game's GameTooltip
L.Tip = {}
local function tm(o, name, ...)
	if type(o) ~= "table" or type(o[name]) ~= "function" then return nil end
	local ok, a = pcall(o[name], o, ...)
	if ok then return a end
	return nil
end
local function themeOf()
	local w = L.W()
	return type(w) == "table" and type(w.Theme) == "table" and w.Theme or nil
end
function L.Tip.card()
	local c = rawget(_G, "WuberTip")
	if type(c) == "table" then return c end
	return nil
end
function L.Tip.surface()
	local c = L.Tip.card()
	if c and tm(c, "IsShown") == true then return c, "card" end
	local gt = rawget(_G, "GameTooltip")
	if type(gt) == "table" and tm(gt, "IsShown") == true then return gt, "game" end
	return nil
end
function L.Tip.lines(f, kind)
	local out = {}
	if type(f) ~= "table" then return out end
	if kind == "card" then
		for _, fs in ipairs(type(f.shown) == "table" and f.shown or {}) do
			local t = tm(fs, "GetText")
			if type(t) == "string" and t ~= "" and tm(fs, "IsShown") ~= false then out[#out + 1] = { fs = fs, text = t } end
		end
		return out
	end
	local name = tm(f, "GetName") or "GameTooltip"
	for i = 1, tm(f, "NumLines") or 0 do
		for _, side in ipairs({ "Left", "Right" }) do
			local fs = rawget(_G, name .. "Text" .. side .. i)
			if type(fs) == "table" and tm(fs, "IsShown") ~= false then
				local t = tm(fs, "GetText")
				if type(t) == "string" then out[#out + 1] = { fs = fs, text = t } end
			end
		end
	end
	return out
end
function L.Tip.owner()
	local c = L.Tip.card()
	if c and tm(c, "IsShown") == true then
		local T = themeOf()
		if T and type(T.TipOwner) == "function" then return L.call(T.TipOwner) end
		return c.owner
	end
	local gt = rawget(_G, "GameTooltip")
	if type(gt) == "table" and tm(gt, "IsShown") == true then return tm(gt, "GetOwner") end
	return nil
end
function L.Tip.hide()
	local T = themeOf()
	local c = L.Tip.card()
	if T and type(T.TipHide) == "function" then
		pcall(T.TipHide)
	elseif c then
		pcall(c.Hide, c)
	end
	if not (T and type(T.TipHide) == "function") then
		local gt = rawget(_G, "GameTooltip")
		if type(gt) == "table" then pcall(gt.Hide, gt) end
	end
end

function L.RR()
	local r = rawget(_G, "RitualRides")
	if type(r) == "table" then return r end
	return nil
end

-- "Anita Lift", "Anita-Lift", "Anita Lift-Realm" -> "anita lift"
function L.Key(name)
	name = L.str(name)
	if not name then return nil end
	local W = L.W()
	if W and type(W.Key) == "function" then
		local k = L.call(W.Key, name)
		if type(k) == "string" then return k end
	end
	local k = name:lower():gsub("[%s%-]+", " "):gsub("^ ", ""):gsub(" $", "")
	if k == "" then return nil end
	return k
end

-- A short internal fault of the lab itself: logged, never raised.
local faults = 0
function L.Bug(where, err)
	faults = faults + 1
	if faults > 200 then return end
	pcall(L.Log, "laberr", tostring(where) .. ": " .. tostring(err))
end

function L.Safe(where, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then L.Bug(where, err) end
	return ok
end

function L.Now()
	return L.num(L.call(GetTime)) or 0
end

function L.InCombat()
	return type(InCombatLockdown) == "function" and L.plain(L.call(InCombatLockdown)) == true
end

---------------------------------------------------------------------------
-- The clock: time() with GetTime()'s milliseconds
---------------------------------------------------------------------------
-- time() is whole seconds of the PC's clock; GetTime() has milliseconds. The offset between
-- them is narrowed each call so the result never strays outside the second time() reports.

local offset
function L.Epoch()
	local t = L.num(L.call(time))
	local g = L.num(L.call(GetTime))
	if not t then return g or 0 end
	if not g then return t end
	if not offset then offset = t - g end
	local est = offset + g
	if est < t then
		offset = t - g
	elseif est >= t + 1 then
		offset = t + 0.999 - g
	end
	return offset + g
end

---------------------------------------------------------------------------
-- The timeline
---------------------------------------------------------------------------

local pending = {}  -- { epoch, kind, text } before the character is known
L.me = nil           -- "Wuber Rocks"
L.myKey = nil        -- "wuber rocks"

local function cleanText(text)
	text = L.show(text)
	text = text:gsub("[\r\n\t]+", " "):gsub("|", "/")
	if #text > L.TEXT_MAX then text = text:sub(1, L.TEXT_MAX - 3) .. "..." end
	return text
end

local function line(at, who, kind, text)
	return string.format("%.3f|%s|%s|%s", at, who, kind, text)
end

-- This character's saved table: { lines, dropped, checks, selftest, role, roleOverride, ... }
function L.Char()
	local db = L.db
	if not db or not L.me then return nil end
	local c = db.chars[L.me]
	if type(c) ~= "table" then
		c = {}
		db.chars[L.me] = c
	end
	if type(c.lines) ~= "table" then c.lines = {} end
	if type(c.checks) ~= "table" then c.checks = {} end
	c.dropped = tonumber(c.dropped) or 0
	return c
end

local function push(c, text)
	local lines = c.lines
	if #lines >= L.CAP then
		-- drop the oldest so the newest L.CAP - 250 stay (one rebuild per 250 lines)
		local keep = L.CAP - 250
		local from = #lines - keep + 1
		local out = {}
		for i = from, #lines do out[#out + 1] = lines[i] end
		c.dropped = c.dropped + (from - 1)
		c.lines = out
		lines = out
	end
	lines[#lines + 1] = text
end

-- L.Log(kind, text): one timeline line. Listeners (the panel's live view, the checklist) hear it.
L.listeners = {}
function L.Log(kind, text)
	local at = L.Epoch()
	kind = tostring(kind or "?")
	text = cleanText(text)
	local c = L.Char()
	if c then
		push(c, line(at, L.me, kind, text))
	else
		if #pending >= L.PENDING_MAX then table.remove(pending, 1) end
		pending[#pending + 1] = { at, kind, text }
	end
	for i = 1, #L.listeners do
		local ok = pcall(L.listeners[i], kind, text, at)
		if not ok then -- a broken listener is dropped, not repeated for every line
			table.remove(L.listeners, i)
			break
		end
	end
end

function L.Logf(kind, fmt, ...)
	local ok, text = pcall(string.format, fmt, ...)
	L.Log(kind, ok and text or fmt)
end

local function flush()
	local c = L.Char()
	if not c then return end
	for _, p in ipairs(pending) do push(c, line(p[1], L.me, p[2], p[3])) end
	pending = {}
end

-- The last n lines of this character's timeline (oldest first).
function L.Tail(n)
	local c = L.Char()
	local out = {}
	if not c then
		for i = math.max(1, #pending - n + 1), #pending do
			local p = pending[i]
			out[#out + 1] = line(p[1], "?", p[2], p[3])
		end
		return out
	end
	for i = math.max(1, #c.lines - n + 1), #c.lines do out[#out + 1] = c.lines[i] end
	return out
end

---------------------------------------------------------------------------
-- Events and timers
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
L.frame = frame
local handlers = {}

function L.On(event, fn)
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
		pcall(frame.RegisterEvent, frame, event) -- an event this client lacks is skipped
	end
	list[#list + 1] = fn
end

frame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then L.Bug(event, err) end
	end
end)

function L.After(delay, fn)
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then return end
	pcall(C_Timer.After, delay, function()
		local ok, err = pcall(fn)
		if not ok then L.Bug("timer", err) end
	end)
end

function L.Every(delay, fn)
	if type(C_Timer) ~= "table" or type(C_Timer.NewTicker) ~= "function" then return nil end
	local ok, ticker = pcall(C_Timer.NewTicker, delay, function()
		local ok2, err = pcall(fn)
		if not ok2 then L.Bug("ticker", err) end
	end)
	return ok and ticker or nil
end

---------------------------------------------------------------------------
-- Wrapping other addons' functions (always calling the original)
---------------------------------------------------------------------------

local function pack(...) return { n = select("#", ...), ... } end

local function afterCall(after, args, ...)
	local ok, err = pcall(after, args, ...)
	if not ok then L.Bug("after hook", err) end
	return ...
end

L.wrapped = {} -- [table][name] = original

-- Replaces tbl[name] with a wrapper that runs before(...) (under pcall), then the original
-- with the same arguments, then after(args, results...) (under pcall), and returns exactly
-- the original's results. An error in the original is raised as before. Once per tbl/name.
function L.Wrap(tbl, name, before, after)
	if type(tbl) ~= "table" then return false end
	local orig = tbl[name]
	if type(orig) ~= "function" then return false end
	L.wrapped[tbl] = L.wrapped[tbl] or {}
	if L.wrapped[tbl][name] then return false end
	L.wrapped[tbl][name] = orig
	tbl[name] = function(...)
		if before then
			local ok, err = pcall(before, ...)
			if not ok then L.Bug("before " .. tostring(name), err) end
		end
		if not after then return orig(...) end
		return afterCall(after, pack(...), orig(...))
	end
	return true
end

-- hooksecurefunc, guarded: a post-hook on a Blizzard function (global name or table field).
function L.Hook(a, b, c)
	if type(hooksecurefunc) ~= "function" then return false end
	local isGlobal = type(a) == "string"
	local t, name, fn = a, b, c
	if isGlobal then t, name, fn = _G, a, b end
	if type(t) ~= "table" or type(name) ~= "string" or type(t[name]) ~= "function" or type(fn) ~= "function" then return false end
	local function post(...)
		local ok2, err = pcall(fn, ...)
		if not ok2 then L.Bug("hook " .. name, err) end
	end
	if isGlobal then return (pcall(hooksecurefunc, name, post)) end
	return (pcall(hooksecurefunc, t, name, post))
end

---------------------------------------------------------------------------
-- Signals: the checklist (Checklist.lua) listens; anything may send one
---------------------------------------------------------------------------

L.signalFns = {}
function L.Signal(name, info)
	for i = 1, #L.signalFns do
		local ok, err = pcall(L.signalFns[i], name, info)
		if not ok then L.Bug("signal " .. tostring(name), err) end
	end
end

---------------------------------------------------------------------------
-- Lua errors: the game's error handler, wrapped and kept working; BugGrabber too
---------------------------------------------------------------------------

-- Which addon a Lua error came from: the first Interface\AddOns\<name>\ in its own text (the
-- game cuts long paths to "...nterface/AddOns/..."), else in its stack, skipping the lab's own
-- handler (WuberLab/Log.lua is in every stack it catches). nil when no path names one.
local ADDON_PATH = "[Aa][Dd][Dd][Oo][Nn][Ss][/\\]+([^/\\:%s%]]+)[/\\]"
function L.ErrorAddon(text)
	local own = text:match("^(.-) @ ") or text
	local name = own:match(ADDON_PATH)
	if name then return name end
	for n in text:gmatch(ADDON_PATH) do
		if n ~= "WuberLab" then return n end
	end
	return nil
end

local recentErr, recentCount = {}, 0 -- [message] = when: the same error within 2 s is logged once
function L.LuaError(msg, source)
	msg = L.show(msg)
	local t = L.Now()
	if recentErr[msg] and t - recentErr[msg] < 2 then return end
	if recentCount > 50 then
		recentErr, recentCount = {}, 0
	end
	if not recentErr[msg] then recentCount = recentCount + 1 end
	recentErr[msg] = t
	local stack = ""
	if source == "handler" and type(debugstack) == "function" then
		local s = L.call(debugstack, 3, 3, 0)
		if type(s) == "string" then stack = " @ " .. s:gsub("[\r\n]+", " / "):sub(1, 160) end
	end
	L.Log("err", "[" .. tostring(source) .. "] " .. msg:sub(1, 220) .. stack)
	L.Signal("lua_error", msg)
end

function L.InstallErrorHandler()
	if L.errorHandler then return true end
	if type(geterrorhandler) ~= "function" or type(seterrorhandler) ~= "function" then return false end
	local prev = L.call(geterrorhandler)
	if type(prev) ~= "function" then return false end
	local function handler(msg, ...)
		pcall(L.LuaError, msg, "handler")
		return prev(msg, ...)
	end
	if not pcall(seterrorhandler, handler) then return false end
	L.errorHandler, L.prevErrorHandler = handler, prev
	return true
end

local bugGrabbed = false
function L.HookBugGrabber()
	if bugGrabbed then return true end
	local bg = rawget(_G, "BugGrabber")
	if type(bg) ~= "table" or type(bg.RegisterCallback) ~= "function" then return false end
	local ok = pcall(bg.RegisterCallback, L, "BugGrabber_BugGrabbed", function(_, e)
		local m = type(e) == "table" and e.message or e
		pcall(L.LuaError, m, "BugGrabber")
	end)
	bugGrabbed = ok
	return ok
end

L.InstallErrorHandler()
L.HookBugGrabber()

---------------------------------------------------------------------------
-- Who is this, and versions
---------------------------------------------------------------------------

local function myName()
	local W = L.W()
	if W and type(W.UnitName) == "function" then
		local n = L.call(W.UnitName, "player")
		if L.str(n) then return n end
	end
	local a, b = L.call(UnitName, "player")
	a, b = L.str(a), L.str(b)
	if not a or a == "Unknown" then return nil end
	if b then return a .. " " .. b end
	return a
end

local function learnName()
	if L.me then return true end
	local n = myName()
	if not n then return false end
	L.me = n
	L.myKey = L.Key(n)
	flush()
	return true
end
L.LearnName = learnName

function L.AddonInfo(name)
	local A = type(C_AddOns) == "table" and C_AddOns or nil
	local isLoaded = (A and A.IsAddOnLoaded) or IsAddOnLoaded
	local meta = (A and A.GetAddOnMetadata) or GetAddOnMetadata
	local loaded = L.plain(L.call(isLoaded, name)) and true or false
	local ver = L.str(L.call(meta, name, "Version"))
	return loaded, ver
end

-- The role of this window: "rider", "driver" or "team" (an override wins), else "other".
function L.Role()
	local c = L.Char()
	if c and (c.roleOverride == "rider" or c.roleOverride == "driver" or c.roleOverride == "team") then return c.roleOverride end
	return L.CAST[L.myKey or ""] or "other"
end

local function channelCount()
	if type(GetChannelList) ~= "function" then return nil end
	local res = pack(pcall(GetChannelList))
	if not res[1] then return nil end
	return math.floor((res.n - 1) / 3)
end
L.ChannelCount = channelCount

local function loginInfo()
	local build = pack(L.call(GetBuildInfo))
	local realm = L.str(L.call(GetRealmName)) or "?"
	local parts = { "char=" .. tostring(L.me), "realm=" .. realm, "role=" .. L.Role(),
		"build=" .. table.concat({ L.show(build[1]), L.show(build[2]), L.show(build[3]), L.show(build[4]) }, "/"),
		"lab=" .. L.VERSION }
	for _, name in ipairs({ "Wuber", "RitualRides", "OpenMap", "Moo", "!BugGrabber", "BugSack" }) do
		local loaded, ver = L.AddonInfo(name)
		parts[#parts + 1] = name .. "=" .. (loaded and (ver or "?") or "off")
	end
	local W, RR = L.W(), L.RR()
	if W then parts[#parts + 1] = "W.VERSION=" .. L.show(W.VERSION) end
	if RR then parts[#parts + 1] = "RR.VERSION=" .. L.show(RR.VERSION) end
	parts[#parts + 1] = "channels=" .. L.show(channelCount())
	parts[#parts + 1] = "errhandler=" .. (L.errorHandler and (L.call(geterrorhandler) == L.errorHandler and "chained" or "replaced later") or "not set")
	parts[#parts + 1] = "buggrabber=" .. (bugGrabbed and "hooked" or "no")
	L.Log("login", table.concat(parts, " "))
	local c = L.Char()
	if c then
		c.realm = realm
		c.lastLogin = L.Epoch()
		c.sessions = (tonumber(c.sessions) or 0) + 1
		c.versions = { wuber = select(2, L.AddonInfo("Wuber")), rr = select(2, L.AddonInfo("RitualRides")), lab = L.VERSION }
	end
end

---------------------------------------------------------------------------
-- Saved variables and start-up
---------------------------------------------------------------------------

function L.InitDB()
	if L.dbLoadedEmpty == nil then -- (what came off disk: the login check "saved settings survived a restart")
		local d = rawget(_G, "WuberLabDB")
		L.dbLoadedEmpty = type(d) ~= "table" or type(d.chars) ~= "table" or next(d.chars) == nil
	end
	if type(WuberLabDB) ~= "table" then WuberLabDB = {} end
	local db = WuberLabDB
	db.v = 1
	if type(db.chars) ~= "table" then db.chars = {} end
	L.db = db
	return db
end

L.loginFns = {}
function L.OnLogin(fn) L.loginFns[#L.loginFns + 1] = fn end

L.On("ADDON_LOADED", function(name)
	if L.plain(name) ~= ADDON then return end
	L.InitDB()
	if L.me then flush() end
end)

L.On("PLAYER_LOGIN", function()
	if not L.db then L.InitDB() end
	learnName()
	L.HookBugGrabber()
	loginInfo()
	for i = 1, #L.loginFns do
		local ok, err = pcall(L.loginFns[i])
		if not ok then L.Bug("login", err) end
	end
	L.loggedIn = true
end)

L.On("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
	if not L.me and learnName() then loginInfo() end
	L.Log("ev", "PLAYER_ENTERING_WORLD login=" .. L.show(isLogin) .. " reload=" .. L.show(isReload))
end)

L.On("PLAYER_LOGOUT", function()
	L.Log("ev", "PLAYER_LOGOUT")
end)
