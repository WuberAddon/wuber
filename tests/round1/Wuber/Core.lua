-- Wuber: a free "call a summon" network for WoW Forever.
-- Core: the namespace every file shares, saved settings, events, timers, and the small
-- helpers for values the 1.60.1 client may keep secret. Nothing here draws or talks.

local ADDON, W = ...
W.ADDON = ADDON
Wuber = W -- the one global (also read by tests and by /dump)

W.VERSION = "1.0.0"
W.PREFIX = "WUBER"      -- addon message prefix (registered at login)
W.CHANNEL = "WuberNet"  -- the hidden chat channel the network runs on
W.PROTO = 1             -- protocol version carried in every message
W.MIN_PRICE = 5000      -- 50s: the lowest fare on the network (drivers' time is worth it).
                        -- Riders never see a driver beaconing less; drivers can't set less.

---------------------------------------------------------------------------
-- Values the client may keep secret
---------------------------------------------------------------------------
-- Asked before anything else is done with a value: even comparing a secret is an error.

local function secret(v)
	if not issecretvalue then return false end
	local ok, is = pcall(issecretvalue, v)
	return not ok or is == true
end

function W.Plain(v)
	if secret(v) then return nil end
	return v
end

function W.Str(v)
	v = W.Plain(v)
	if type(v) == "string" and v ~= "" then return v end
	return nil
end

function W.Num(v)
	v = W.Plain(v)
	if type(v) == "number" and v == v then return v end
	return nil
end

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------

W.DEFAULTS = {
	-- buyer
	minimapAngle = 215,
	minimapHidden = false,
	pos = nil,              -- the window's place: { point, relPoint, x, y }
	scale = nil,            -- nil: fits the screen (W.AutoScale)
	sound = true,
	mapPins = true,         -- drivers on the world map
	lastDest = nil,         -- the destination picked last time
	rides = {},             -- the rider's trip history, newest last, at most 100 (W.AddTrip)
	chars = {},             -- per character (W.Char()): driver settings
}

-- Driver mode settings belong to one character (logging in on another Warlock must not
-- put it online by itself).
W.CHAR_DEFAULTS = {
	drive = false,          -- online as a driver
	price = 5000,           -- copper
	service = "",           -- the name riders see; "" = the character's name
	team = 1,               -- Warlocks summoning together (1..3); riders bring 3 - team helpers
}

local function fill(db, defaults)
	for k, v in pairs(defaults) do
		if db[k] == nil then
			if type(v) == "table" then
				local copy = {}
				for kk, vv in pairs(v) do copy[kk] = vv end
				db[k] = copy
			else
				db[k] = v
			end
		end
	end
end

function W.InitDB()
	if type(WuberDB) ~= "table" then WuberDB = {} end
	fill(WuberDB, W.DEFAULTS)
	if type(WuberDB.chars) ~= "table" then WuberDB.chars = {} end
	if type(WuberDB.rides) ~= "table" then WuberDB.rides = {} end
	W.db = WuberDB
	return W.db
end

-- This character's driver settings (W.CHAR_DEFAULTS), created on first use.
function W.Char()
	local db = W.db or W.InitDB()
	local key = W.myKey or "?"
	local c = db.chars[key]
	if type(c) ~= "table" then
		c = {}
		db.chars[key] = c
	end
	fill(c, W.CHAR_DEFAULTS)
	return c
end

-- Saves a finished trip: { at = time(), driver, dest, price, stars }. Keeps the last 100.
function W.AddTrip(trip)
	local list = (W.db or W.InitDB()).rides
	list[#list + 1] = trip
	while #list > 100 do table.remove(list, 1) end
end

---------------------------------------------------------------------------
-- Chat output and errors
---------------------------------------------------------------------------

function W.Print(...)
	local parts = { ... }
	for i = 1, #parts do parts[i] = tostring(parts[i]) end
	local text = "|cffffffffWuber|r: " .. table.concat(parts, " ")
	local f = DEFAULT_CHAT_FRAME
	if f and f.AddMessage then f:AddMessage(text) else print(text) end
end

local seenErrors, errorCount = {}, 0
function W.Error(where, err)
	err = tostring(err)
	W.lastError = tostring(where) .. ": " .. err
	if seenErrors[err] or errorCount >= 5 then return end
	seenErrors[err] = true
	errorCount = errorCount + 1
	W.Print("|cffff5050error|r in " .. tostring(where) .. ": " .. err)
end

-- Runs fn(...) and reports an error instead of raising it. Returns ok, results.
local function report(where, ok, ...)
	if not ok then W.Error(where, (...)) end
	return ok, ...
end
function W.Safe(where, fn, ...)
	return report(where, pcall(fn, ...))
end

---------------------------------------------------------------------------
-- Timers
---------------------------------------------------------------------------

function W.After(delay, fn)
	C_Timer.After(delay, function()
		local ok, err = pcall(fn)
		if not ok then W.Error("timer", err) end
	end)
end

-- A repeating timer; returns the ticker (ticker:Cancel() stops it).
function W.Every(delay, fn)
	return C_Timer.NewTicker(delay, function()
		local ok, err = pcall(fn)
		if not ok then W.Error("ticker", err) end
	end)
end

function W.Now() return GetTime() end

---------------------------------------------------------------------------
-- Events: W.On(event, fn(...)) - many handlers per event, each run under pcall
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}
W.frame = frame

function W.On(event, fn)
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
		pcall(frame.RegisterEvent, frame, event) -- an event this client does not know is skipped
	end
	list[#list + 1] = fn
end

frame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then W.Error(event, err) end
	end
end)

-- Internal messages between Wuber's own files: W.Listen(name, fn(...)), W.Fire(name, ...).
-- Names in use (see SPEC.md): "DRIVERS" (the driver list changed), "RIDE" (the buyer's
-- ride changed state), "REQUESTS" (a driver's incoming requests changed), "SETTINGS".
local listeners = {}
function W.Listen(name, fn)
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], fn)
end

function W.Fire(name, ...)
	local list = listeners[name]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then W.Error(name, err) end
	end
end

---------------------------------------------------------------------------
-- Names (WoW Forever: "First Surname"; other spellings "First-Surname", "-Realm")
---------------------------------------------------------------------------

function W.Sep()
	local c = Constants and Constants.CharacterNameSeparatorConsts
	local sep = c and c.CHARACTERNAME_SURNAME_SEPARATOR
	if type(sep) == "string" and sep ~= "" then return sep end
	return " "
end

-- Our own realm, lower case without spaces ("" when unknown).
local function ownRealm()
	local r
	if type(GetNormalizedRealmName) == "function" then r = W.Str(GetNormalizedRealmName()) end
	if not r and type(GetRealmName) == "function" then r = W.Str(GetRealmName()) end
	return r and r:lower():gsub("[%s%-']", "") or ""
end

-- One spelling per player, whatever the game hands over: "Ana Smith", "Ana-Smith" and
-- "Ana Smith-OurRealm" are all "ana smith". (A player on another realm keeps the realm.)
function W.Key(name)
	name = W.Str(name)
	if not name then return nil end
	local k = name:lower()
	local realm = ownRealm()
	if realm ~= "" then
		local base, tail = k:match("^(.-)%-([^%-]+)$")
		if base and base ~= "" and tail:gsub("[%s']", "") == realm then k = base end
	end
	k = k:gsub("[%s%-]+", " "):gsub("^ ", ""):gsub(" $", "")
	if k == "" then return nil end
	return k
end

-- The name as a whisper macro line takes it: no spaces ("Anita-Lift"). Blizzard's chat
-- box reads both "First-Surname" and "First Surname"; only the first survives text after it.
function W.Tell(name)
	return (tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", "-"))
end

-- "Ana Smith" -> "Ana"
function W.Short(name)
	if type(name) ~= "string" then return "?" end
	return name:match("^([^%s%-]+)") or name
end

-- A unit's full name. Forever: the player's own UnitName carries both parts in its first
-- return; every other unit returns first name and surname separately.
function W.UnitName(unit)
	if type(UnitName) ~= "function" or not unit then return nil end
	local ok, first, surname = pcall(UnitName, unit)
	if not ok then return nil end
	first, surname = W.Str(first), W.Str(surname)
	if not first then return nil end
	if first == UNKNOWNOBJECT or first == UNKNOWN or first == "Unknown" then return nil end
	if surname then return first .. W.Sep() .. surname end
	return first
end

function W.Me() return W.myName or W.UnitName("player") or "?" end

---------------------------------------------------------------------------
-- Money and text
---------------------------------------------------------------------------

-- A network number: digits only, at most 9 of them, else nil. (tonumber would also take
-- "inf", "nan", "1e9" and "0x10".)
function W.Int(s)
	if type(s) == "number" then
		if s ~= s or s < 0 or s > 999999999 or s % 1 ~= 0 then return nil end
		return s
	end
	if type(s) ~= "string" or not s:match("^%d+$") or #s > 9 then return nil end
	return tonumber(s)
end

-- "a~b~~c" -> { "a", "b", "", "c" } (empty fields kept, nothing extra at the end).
function W.Split(text)
	local out = {}
	if type(text) ~= "string" then return out end
	for field in (text .. "~"):gmatch("(.-)~") do out[#out + 1] = field end
	return out
end

-- 52500 -> "5g 25s"; 5000 -> "50s"
function W.Money(copper)
	copper = math.floor((tonumber(copper) or 0) + 0.5)
	if copper <= 0 then return "free" end
	local g = math.floor(copper / 10000)
	local s = math.floor(copper % 10000 / 100)
	local c = copper % 100
	local out = {}
	if g > 0 then out[#out + 1] = g .. "g" end
	if s > 0 then out[#out + 1] = s .. "s" end
	if c > 0 then out[#out + 1] = c .. "c" end
	return table.concat(out, " ")
end

-- "5" and "5g" are five gold; "50s", "2g 50s", "2.5g" work too. Copper, or nil.
function W.ParseMoney(text)
	if type(text) ~= "string" then return nil end
	local t = text:lower():gsub("%s+", "")
	if t == "" then return nil end
	if t:match("^%d*%.?%d+$") then
		local bare = tonumber(t)
		if not bare or bare > 99999 then return nil end
		return math.floor(bare * 10000 + 0.5)
	end
	if t:gsub("[%d%.]+[gsc]", "") ~= "" then return nil end
	local total, any = 0, false
	for amount, unit in t:gmatch("([%d%.]+)([gsc])") do
		local n = tonumber(amount)
		if not n then return nil end
		total = total + n * (unit == "g" and 10000 or (unit == "s" and 100 or 1))
		any = true
	end
	if not any or total > 999999999 then return nil end
	return math.floor(total + 0.5)
end

-- One line of plain text, no colour or link codes, at most `max` bytes (never splits a
-- UTF-8 letter).
function W.Clean(text, max)
	text = tostring(text or ""):gsub("|", ""):gsub("[\r\n\t~]+", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	max = max or 60
	if #text > max then
		local cut = max
		while cut > 0 do
			local b = text:byte(cut + 1)
			if not b or b < 128 or b >= 192 then break end
			cut = cut - 1
		end
		text = text:sub(1, cut)
	end
	return text
end

-- "just now", "2 min ago"
function W.Ago(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	if seconds < 45 then return "just now" end
	local m = math.floor(seconds / 60 + 0.5)
	if m < 60 then return m .. " min ago" end
	return math.floor(m / 60 + 0.5) .. " h ago"
end

---------------------------------------------------------------------------
-- Sounds
---------------------------------------------------------------------------

-- open/close: the bag sounds; found: the ready check; alert (the summon is up): the raid
-- warning; click: a button.
W.SOUND = { open = 850, close = 851, ping = 3175, found = 8960, alert = 8959, click = 856 }

function W.Sound(which)
	if not (W.db and W.db.sound and PlaySound) then return end
	local id = W.SOUND[which] or which
	pcall(PlaySound, id)
end

---------------------------------------------------------------------------
-- Combat and groups
---------------------------------------------------------------------------

function W.InCombat()
	return type(InCombatLockdown) == "function" and W.Plain(InCombatLockdown()) == true
end

function W.InGroup()
	if type(IsInGroup) == "function" then return W.Plain(IsInGroup()) == true end
	return (W.Num(GetNumGroupMembers and GetNumGroupMembers()) or 0) > 0
end

-- Runs fn now, or as soon as combat ends (secure frames can't change during combat).
local afterCombat = {}
function W.AfterCombat(fn)
	if not W.InCombat() then
		W.Safe("after combat", fn)
		return
	end
	afterCombat[#afterCombat + 1] = fn
end
W.On("PLAYER_REGEN_ENABLED", function()
	local list = afterCombat
	afterCombat = {}
	for i = 1, #list do W.Safe("after combat", list[i]) end
end)

-- What the game refused this addon (ADDON_ACTION_BLOCKED / _FORBIDDEN): W.blocked[func] = true.
W.blocked = {}
local function onBlocked(addon, func)
	if W.Plain(addon) ~= ADDON then return end
	func = tostring(W.Plain(func) or "?")
	if W.blocked[func] then return end
	W.blocked[func] = true
	W.Print("the game blocked " .. func .. ".")
end
W.On("ADDON_ACTION_BLOCKED", onBlocked)
W.On("ADDON_ACTION_FORBIDDEN", onBlocked)

---------------------------------------------------------------------------
-- Start-up order: ADDON_LOADED -> W.InitDB; PLAYER_LOGIN -> every W.OnLogin(fn) in order
---------------------------------------------------------------------------

local loginFns = {}
function W.OnLogin(fn) loginFns[#loginFns + 1] = fn end

W.On("ADDON_LOADED", function(name)
	if W.Plain(name) ~= ADDON then return end
	W.InitDB()
end)

local function learnName()
	local me = W.UnitName("player")
	if me then
		W.myName = me
		W.myKey = W.Key(me) or "?"
	else
		W.myName = W.myName or "?"
		W.myKey = W.myKey or "?"
	end
end

-- The player's name can be unknown at login: asked again once the world is loaded.
W.On("PLAYER_ENTERING_WORLD", function()
	if not W.myName or W.myName == "?" then learnName() end
end)

W.On("PLAYER_LOGIN", function()
	if not W.db then W.InitDB() end
	learnName()
	for i = 1, #loginFns do
		local ok, err = pcall(loginFns[i])
		if not ok then W.Error("login", err) end
	end
	W.loggedIn = true
end)
