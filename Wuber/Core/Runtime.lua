-- Module: Core.Runtime
-- Purpose: Print/Error/Safe/Debug, timers, the event bus (W.On, W.Listen, W.Fire, W.OnLogin), names, money
--   and text helpers, sounds, combat/group facts, the blocked-action guard, and start-up (ADDON_LOADED ->
--   InitDB, PLAYER_LOGIN -> W.CheckModules, then the login functions).
-- API: W.Print, W.Error, W.Safe, W.errorLog, W.eventLog, W.debugLog, W.Debug, W.After, W.Every, W.Now, W.frame, W.On, W.Listen,
--   W.Fire, W.Sep, W.IsRealmTail, W.SplitName, W.Key, W.Tell, W.Short, W.UnitName, W.Me, W.Int, W.Split,
--   W.Money, W.MoneyIcons, W.ParseMoney, W.Clean, W.Ago, W.SOUND, W.Sound, W.InCombat, W.InGroup, W.AfterCombat,
--   W.InInstance, W.blocked, W.blockedAt, W.crumbs, W.Crumb, W.Build, W.IsBlocked, W.Try, W.RetryBlocked, W.OnLogin, W.GamepadUI
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: listens On PLAYER_REGEN_ENABLED, On ADDON_ACTION_BLOCKED, On ADDON_ACTION_FORBIDDEN, On
--   ADDON_LOADED, On PLAYER_ENTERING_WORLD, On PLAYER_LOGIN; fires BLOCKED
-- Standalone: no
-- Test: tests/core/runtime_test.lua
-- From: Core.lua 530-984 (Wuber 2.2.1 + restructure step 0's W.CheckModules line)
--
local ADDON, W = ...
local Mod = W.Module("Core.Runtime", {})

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
-- (2.3.2, R3) the last 10 errors, for /wuber bug (UI.Bug): { at, where, text, n }, oldest
-- first; the same error again only counts (n) and moves its time. Session only, never sent.
W.errorLog = W.errorLog or {}
local function remember(log, cap, same, entry)
	local last = log[#log]
	if last and same(last, entry) then
		last.n, last.at = (last.n or 1) + 1, entry.at
		return
	end
	log[#log + 1] = entry
	while #log > cap do table.remove(log, 1) end
end
local function sameError(a, b) return a.where == b.where and a.text == b.text end
function W.Error(where, err)
	err = tostring(err)
	W.lastError = tostring(where) .. ": " .. err
	remember(W.errorLog, 10, sameError, { at = type(GetTime) == "function" and GetTime() or 0, where = tostring(where), text = err, n = 1 })
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

-- Developer notes that never reach chat: W.Debug(kind, text) keeps the last 40 in
-- W.debugLog ({ at, kind, text }). the test addon hooks this to log them.
W.debugLog = W.debugLog or {}
function W.Debug(kind, text)
	local log = W.debugLog
	log[#log + 1] = { at = type(GetTime) == "function" and GetTime() or 0, kind = tostring(kind), text = tostring(text) }
	while #log > 40 do table.remove(log, 1) end
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
-- (2.3.2, R3) the last 20 internal messages, by name only (never their values), for /wuber bug:
-- W.eventLog { at, name, n }, oldest first; a run of the same name only counts (n).
W.eventLog = W.eventLog or {}
local function sameEvent(a, b) return a.name == b.name end
function W.Listen(name, fn)
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], fn)
end

function W.Fire(name, ...)
	-- a repeat only counts: no new table (no garbage per event)
	local log, key, at = W.eventLog, tostring(name), type(GetTime) == "function" and GetTime() or 0
	local last = log[#log]
	if last and last.name == key then
		last.n, last.at = (last.n or 1) + 1, at
	else
		remember(log, 20, sameEvent, { at = at, name = key, n = 1 })
	end
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

-- Whether the text after a name's last "-" is a realm (SPEC5 realms, review #8): our own
-- realm; or a Forever server node, which always carries digits or starts "CAMWOW", with or
-- without spaces ("CAMWOW EU4 Realm 7", "CAMWOWEU4Realm7PvE"). Name parts never hold digits.
function W.IsRealmTail(tail)
	tail = W.Str(tail)
	if not tail or tail == "" then return false end
	local low = tail:lower()
	local realm = ownRealm()
	if realm ~= "" and low:gsub("[%s%-']", "") == realm then return true end
	return low:find("%d") ~= nil or low:find("^camwow") ~= nil
end

-- A name without its realm and in "First Surname" form, as typed: "Dan-CAMWOWEU4Realm7PvE"
-- -> "Dan"; "Ana-Smith" -> "Ana Smith"; "Jean-Luc Picard" stays; "Jean-Luc-Picard" (the
-- macro spelling) -> "Jean-Luc Picard" (the last "-" of a name without spaces parts it).
function W.SplitName(name)
	name = W.Str(name)
	if not name then return nil end
	local person = name:match("^(%S+ %S+)%-.+$")
	if person then return person end
	local base, tail = name:match("^(.-)%-([^%-]+)$")
	if base and base ~= "" and W.IsRealmTail(tail) then name = base end
	if not name:find(" ", 1, true) then
		local first, last = name:match("^(.+)%-([^%-]+)$")
		if first and first ~= "" then name = first .. " " .. last end
	end
	return name
end

-- One spelling per player, whatever the game hands over: "Ana Smith", "Ana-Smith" and
-- "Ana Smith-OurRealm" are all "ana smith". On WoW Forever the realm is the server node
-- ("CAMWOW EU4 Realm 5"), which differs between characters who can still whisper each other
-- by name, so any realm is dropped. A hyphen inside a name part stays ("jean-luc picard").
function W.Key(name)
	name = W.SplitName(name)
	if not name then return nil end
	local k = name:lower():gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	k = k:gsub("%-+", "-"):gsub(" %-", " "):gsub("%- ", " "):gsub("^%-", ""):gsub("%-$", "")
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
	local n = W.SplitName(name) or name
	return n:match("^(%S+) ") or n
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

-- (round 9, S18) Money with the game's coin icons, as the game's own money text shows it: "23" and
-- a silver coin, "1" gold coin "20" silver coin. For where an amount sits next to a time, so "23s"
-- can't read as 23 seconds; everywhere else W.Money's "23s" stays. 0 or less: "0" and a gold coin.
local COINS = {
	g = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t",
	s = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
	c = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t",
}
function W.MoneyIcons(copper)
	copper = math.floor((tonumber(copper) or 0) + 0.5)
	if copper <= 0 then return "0" .. COINS.g end
	local g = math.floor(copper / 10000)
	local s = math.floor(copper % 10000 / 100)
	local c = copper % 100
	local out = {}
	if g > 0 then out[#out + 1] = g .. COINS.g end
	if s > 0 then out[#out + 1] = s .. COINS.s end
	if c > 0 then out[#out + 1] = c .. COINS.c end
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

function W.InInstance()
	if type(IsInInstance) ~= "function" then return false end
	local ok, inside = pcall(IsInInstance)
	return ok and W.Plain(inside) == true
end

-- What the game refused this addon (ADDON_ACTION_BLOCKED / _FORBIDDEN): W.blocked[func] = true.
W.blocked = {}

-- Calls the game may refuse, run through W.Try under a name ("cap"). A refusal is kept per
-- client build in W.db.blockedBuild[build][cap], so the same call is never tried again on
-- that build; the player gets the button instead (no message for these quiet ones).
-- cap names: "accept" (AcceptGroup), "trade" (AcceptTrade / SetTradeMoney), "leave" (LeaveParty);
-- 2.0's driver engine adds "invite" (InviteUnit), "chat" (SendChatMessage), "comm" (the
-- crew's addon messages), "bell" (the alert character's whispers) and "trade-open"
-- (InitiateTrade).
local CAP_OF = { { "AcceptGroup", "accept" }, { "AcceptTrade", "trade" }, { "SetTradeMoney", "trade" },
	{ "LeaveParty", "leave" }, { "InitiateTrade", "trade-open" }, { "InviteUnit", "invite" },
	{ "SendChatMessage", "chat" } }
local QUIET = { accept = true, leave = true }
local guard, lastTry = nil, nil
local saidBlocked = {} -- session only: the blocked-action messages already printed

-- The client build ("?" when unknown).
function W.Build()
	if type(GetBuildInfo) ~= "function" then return "?" end
	local ok, _, build = pcall(GetBuildInfo)
	build = ok and W.Plain(build) or nil
	return build ~= nil and tostring(build) or "?"
end

-- Whether the game refused `cap` on this build.
function W.IsBlocked(cap)
	local db = W.db
	local b = db and type(db.blockedBuild) == "table" and db.blockedBuild[W.Build()]
	return type(b) == "table" and b[cap] == true
end

local function block(cap, func)
	local db = W.db or W.InitDB()
	local build = W.Build()
	if type(db.blockedBuild[build]) ~= "table" then db.blockedBuild[build] = {} end
	if db.blockedBuild[build][cap] then return end
	db.blockedBuild[build][cap] = true
	W.Fire("BLOCKED", cap, func)
end

-- Runs fn(...) under the name `cap`. Returns true and fn's first result, or false (refused
-- before, refused now, or an error).
function W.Try(cap, fn, ...)
	if type(fn) ~= "function" or W.IsBlocked(cap) then return false end
	W.Crumb(cap)
	local g = { cap = cap }
	guard = g
	local ok, result = pcall(fn, ...)
	guard = nil
	lastTry = { cap = cap, at = W.Now() }
	if g.blocked then
		block(cap, g.blocked)
		return false
	end
	if not ok then return false end
	return true, result
end

-- "Retry blocked actions" (Settings; /wuber drive retry): forgets this build's
-- refusals, so every capability is tried once more.
function W.RetryBlocked()
	local db = W.db or W.InitDB()
	db.blockedBuild[W.Build()] = nil
	W.blocked = {}
	W.Fire("BLOCKED", nil, nil)
	return true
end

-- (Polestar idea 12) where a blocked action came from: the first frame of Wuber's OWN code in the call stack
-- (debugstack), as "Folder/File.lua:line" and nothing else (no player data). The last five are kept in
-- W.blockedAt = { { at, func, where, n } } (oldest first, session only) for the bug report; the same block
-- again only counts. Frames of this file (the event dispatch) are skipped. nil when the stack has none.
W.blockedAt = {}
local BLOCK_KEEP, HANDLER_GAP = 5, 30
local lastHandled
local function ownLine()
	if type(debugstack) ~= "function" then return nil end
	local ok, st = pcall(debugstack)
	if not ok or type(st) ~= "string" then return nil end
	for line in st:gmatch("[^\n]+") do
		-- the first "<path>.lua:<line>" on the line (relative "Wuber/UI/X.lua:5", absolute with "/" or "\\", or inside
		-- [string "@..."]); the addon's own part is what follows the LAST "Wuber" folder in that path, so a folder above
		-- the addon that is also called Wuber (a copy in a test run, say) is not taken for the addon's own
		local path, n = line:match("([%w_/\\%.%-]+%.lua)[\"%]]*:(%d+)")
		local file, pos = nil, 1
		while path do
			local s, e = path:find("Wuber[/\\]", pos)
			if not s then break end
			if s == 1 or path:sub(s - 1, s - 1):find("[/\\]") then file = path:sub(e + 1) end
			pos = e + 1
		end
		if file and not file:find("Runtime.lua", 1, true) then return (file:gsub("\\", "/")) .. ":" .. n end
	end
	return nil
end

-- Breadcrumbs: W.Crumb(tag) is called just before Wuber code does something the game may refuse (W.Try, a secure
-- button click, a secure attribute change). It keeps the last 5 as W.crumbs = { { at, tag, where, n } } (oldest first,
-- session only), where = the Wuber file:line of the caller. The game names a block "UNKNOWN()" and the event arrives
-- with no Wuber frame in the stack, so the breadcrumb is the only trace of who asked. Work happens only when an
-- action actually runs; nothing is sent anywhere.
W.crumbs = {}
local CRUMB_KEEP, CRUMB_NEAR = 5, 0.5
function W.Crumb(tag)
	local ok, where = pcall(ownLine)
	where = ok and where or nil
	local list, at = W.crumbs, W.Now()
	tag = tostring(tag or "?")
	local last = list[#list]
	if last and last.tag == tag and last.where == where then
		last.n, last.at = (last.n or 1) + 1, at
		return
	end
	list[#list + 1] = { at = at, tag = tag, where = where, n = 1 }
	while #list > CRUMB_KEEP do table.remove(list, 1) end
end

local function noteBlocked(func)
	local ok, where = pcall(ownLine)
	where = ok and where or nil
	local list, at = W.blockedAt, W.Now()
	local guess
	if not where then
		local c = W.crumbs[#W.crumbs]
		if c and c.where and at - c.at <= CRUMB_NEAR then where, guess = c.where, true end
	end
	local last = list[#list]
	if last and last.func == func and last.where == where and last.guess == guess then
		last.n, last.at = (last.n or 1) + 1, at
	else
		list[#list + 1] = { at = at, func = func, where = where, n = 1, guess = guess }
		while #list > BLOCK_KEEP do table.remove(list, 1) end
	end
	-- the same blocked action to the game's error handler (error-catching addons see it): at most once in 30 s
	if lastHandled and at - lastHandled < HANDLER_GAP then return end
	lastHandled = at
	local gh = type(geterrorhandler) == "function" and geterrorhandler() or nil
	if type(gh) == "function" then
		pcall(gh, "Wuber: the game blocked " .. func .. (where and (" (from " .. where .. ")") or ""))
	end
end

local function onBlocked(addon, func)
	if W.Plain(addon) ~= ADDON then return end
	func = tostring(W.Plain(func) or "?")
	pcall(noteBlocked, func)
	local cap
	if guard then
		guard.blocked = func
		cap = guard.cap
	else
		for _, pair in ipairs(CAP_OF) do
			if func:find(pair[1], 1, true) then cap = pair[2] break end
		end
		if not cap and lastTry and W.Now() - lastTry.at < 0.5 and func:find("UNKNOWN", 1, true) then cap = lastTry.cap end
		if cap then block(cap, func) end
	end
	if W.blocked[func] then return end
	W.blocked[func] = true
	if cap and QUIET[cap] then return end
	-- each message at most once per session, even after Try again (W.RetryBlocked clears
	-- W.blocked, not this); a block the game doesn't name ("UNKNOWN()") in plain words
	local text = func:find("UNKNOWN", 1, true) and "the game blocked one of Wuber's actions."
		or ("the game blocked " .. func .. ".")
	if saidBlocked[text] then return end
	saidBlocked[text] = true
	W.Print(text)
end
W.On("ADDON_ACTION_BLOCKED", onBlocked)
W.On("ADDON_ACTION_FORBIDDEN", onBlocked)

---------------------------------------------------------------------------
-- Is the game's Gamepad UI on? Read once (first call) and kept; false when this client has no such call.
---------------------------------------------------------------------------
local gamepadUI
function W.GamepadUI()
	if gamepadUI == nil then
		local on = false
		local pad = type(Enum) == "table" and type(Enum.InputDeviceInterfaceType) == "table" and Enum.InputDeviceInterfaceType.GamePad
		if pad ~= nil and type(C_InputInterfaceStyle) == "table" and type(C_InputInterfaceStyle.GetCurrentStyle) == "function" then
			local ok, style = pcall(C_InputInterfaceStyle.GetCurrentStyle)
			on = ok and style ~= nil and style == pad
		end
		gamepadUI = on
	end
	return gamepadUI
end

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
	if W.CheckModules then W.Safe("modules", W.CheckModules) end
	for i = 1, #loginFns do
		local ok, err = pcall(loginFns[i])
		if not ok then W.Error("login", err) end
	end
	W.loggedIn = true
end)
