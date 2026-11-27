-- Module: Drive.Bell
-- Purpose: The alert character (was Drive_Bell.lua).
-- API: W.Drive, DR.bell, DR.BellCanSend, DR.BellActive, DR.BellHello, DR.Ring, DR.BellAlert,
--   DR.BellDismiss, DR.BellClear, DR.BellSet, DR.BellTest, DR.BellForget,
--   DR.AlertWindow, DR.SetAlertWindow
-- Internals: (none)
-- Uses: (none)
-- Later: (none)
-- Events: listens On CHAT_MSG_WHISPER, Listen DRIVE_STATE, Listen DRIVE_PAID, Listen DRIVE_ALERT,
--   Listen DRIVE, Listen BLOCKED, Listen DRIVE_CREW, On CHAT_MSG_SYSTEM, On CHAT_MSG_ADDON, login;
--   fires SETTINGS
-- Standalone: no
-- Test: tests/drive/bell_test.lua
-- From: Drive_Bell.lua 1-717 (Wuber 2.2.1)
--
-- Wuber 2.0 · Drive_Bell.lua (agent D): the alert character.
--
-- A character on another account (W.db.drive.bell.name; Settings > Driving "Alert
-- character") is told the moment anything summon-related happens, so you can swap to the
-- crew's window. Messages are addon whispers on the crew prefix WUBERT:
--
--   BH~1~service~key,key,key~lead~version   who the crew is (on set, at login, every 10 min)
--   BE~1~lead~text                          one alert: "Anita: whisper from Dan Miller: summon pls"
--
-- Crew side (any crew window while open or with anybody on the list) - what rings: a
-- rider's whisper (the window it reached), a public buyer invited (the leader's), a Wuber
-- request (the window on the network), the big button having a click for you (that window;
-- a summon only from the first Warlock by name who can cast, unless a main caster is set),
-- the portal call (the first helper by name only), a payment (the window that took it),
-- every other DRIVE_ALERT, a call the game refused. The same text twice within 5 s goes
-- once; one alert whisper a second at most. Nothing goes when no alert character is set,
-- when this window is it, or for 30 s after the game says it is not online (that "No
-- player named ..." line is kept out of chat).
--
-- Alert side: only from keys learned from a BH (kept in drive.bell.team, so a /reload keeps
-- them). A BH from a stranger is taken only while it knows nobody, or when it names a key it
-- knows. Then a banner across the top of the screen (alpha flashes only: no Scale animation
-- on text), the alert sound, the taskbar icon flashing, and a counter that stays until
-- clicked. Nothing here is protected: no secure frames, no hardware events.

local ADDON, W = ...
local Mod = W.Module("Drive.Bell", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local PREFIX = "WUBERT"
local SAME = 5 -- seconds: the same text again goes (or shows) only once
local GAP = 1 -- seconds between two alert whispers, at least
local HELLO_EVERY = 600 -- seconds: the crew is told again this often, with the next alert
local AWAY = 30 -- seconds of quiet after the game says the alert character is not online
local QUEUE_MAX = 8
local FLASH = 6 -- seconds the banner flashes
local SHOWN = 60 -- seconds it then stays, unless clicked
local MAX_TEAM = 8 -- keys an alert window remembers

local VIOLET = { 0x88 / 255, 0x3F / 255, 0xDA / 255 }
local GOLD = { 0xF9 / 255, 0xC5 / 255, 0x3E / 255 }

DR.bell = DR.bell or { sent = 0, failed = 0, heard = 0, ignored = 0 }
local stat = DR.bell

local function myKey() return W.Key(W.Me()) end
local function me() return W.Short(W.Me()) end

local function clean(text, max)
	text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return W.Clean(text, max or 200)
end

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then return nil end
	return a, b
end

local function locked() return call(DR.Lock) ~= nil end

-- drive.bell, with every field there
local function cfg()
	local db = W.db
	if type(db) ~= "table" then return nil end
	if type(db.drive) ~= "table" then
		if DR.InitDB then call(DR.InitDB) end
		if type(db.drive) ~= "table" then return nil end
	end
	local b = db.drive.bell
	if type(b) ~= "table" then
		b = {}
		db.drive.bell = b
	end
	if type(b.name) ~= "string" then b.name = "" end
	if type(b.team) ~= "table" then b.team = {} end
	if type(b.lead) ~= "string" then b.lead = "" end
	if type(b.service) ~= "string" then b.service = "" end
	b.count = tonumber(b.count) or 0
	return b
end

local function bellName()
	local b = cfg()
	if b and b.name ~= "" then return b.name end
	return nil
end

local function isCrewKey(k) return k ~= nil and call(DR.IsCrewKey, k) == true end
local function isOwnDriver(k) return k ~= nil and (isCrewKey(k) or call(DR.BookOwn, k) == true) end

---------------------------------------------------------------------------
-- Crew side: sending
---------------------------------------------------------------------------

local queue, recent = {}, {}
local lastSentAt, helloAt, awayAt
local pumpDue, inError = false, false

-- May this window whisper the alert character at all?
local function canSend()
	if locked() then return false end
	if type(DR.Active) == "function" and call(DR.Active) ~= true then return false end -- not a driver or crew
	local name = bellName()
	local mk = myKey()
	if not name or not mk then return false end
	local key = W.Key(name)
	if not key or key == mk then return false end -- this window is the alert character
	if W.IsBlocked and W.IsBlocked("bell") then return false end
	-- DR.Whisper (the paced outbox) drops everything while the game refuses addon messages
	if type(DR.Whisper) == "function" and W.IsBlocked and W.IsBlocked("comm") then return false end
	if awayAt and GetTime() - awayAt < AWAY then return false end
	return C_ChatInfo ~= nil and type(C_ChatInfo.SendAddonMessage) == "function"
end
DR.BellCanSend = canSend

-- On duty: open, or anybody on the list.
function DR.BellActive()
	if locked() then return false end
	if call(DR.IsOpen) == true then return true end
	return type(DR.customers) == "table" and next(DR.customers) ~= nil
end

local pump

local function schedule(delay)
	if pumpDue then return end
	pumpDue = true
	W.After(delay, function()
		pumpDue = false
		pump()
	end)
end

pump = function()
	if #queue == 0 then return end
	if not canSend() then
		queue = {}
		return
	end
	local t = GetTime()
	if lastSentAt and t - lastSentAt < GAP then
		schedule(GAP - (t - lastSentAt) + 0.01)
		return
	end
	local text = table.remove(queue, 1)
	local ok, result
	if type(DR.Whisper) == "function" then
		-- A's paced WUBERT outbox (fields after "KIND~1~")
		local parts = W.Split(text)
		ok, result = pcall(DR.Whisper, bellName(), parts[1], unpack(parts, 3))
		if ok and result == false then ok = false end
		if ok then result = 0 end
	else
		ok, result = W.Try("bell", C_ChatInfo.SendAddonMessage, PREFIX, text, "WHISPER", bellName())
	end
	if ok and W.Plain(result) == 3 then
		table.insert(queue, 1, text) -- "too fast": again in a moment
		schedule(GAP + 0.01)
		return
	end
	lastSentAt = t
	if ok and (W.Plain(result) == 0 or W.Plain(result) == nil or W.Plain(result) == true) then
		stat.sent = stat.sent + 1
	else
		stat.failed = stat.failed + 1
	end
	if #queue > 0 then schedule(GAP + 0.01) end
end

local function push(text, front)
	if #text > 250 then text = text:sub(1, 250) end
	if #queue >= QUEUE_MAX then table.remove(queue, front and #queue or 1) end
	if front then table.insert(queue, 1, text) else queue[#queue + 1] = text end
	pump()
end

-- The crew window the alert character should swap to: the group's leader, else this one.
local function leadName()
	if call(DR.IsLeader) == true then return me() end
	local roster = call(DR.Roster)
	if type(roster) == "table" and type(UnitIsGroupLeader) == "function" then
		for _, m in ipairs(roster) do
			if type(m) == "table" and m.unit and isCrewKey(m.key or W.Key(m.name)) then
				local ok, is = pcall(UnitIsGroupLeader, m.unit)
				if ok and W.Plain(is) == true then return W.Short(m.name) end
			end
		end
	end
	return me()
end

-- the crew's keys: me first, then the crew by name (6 at most)
local function crewKeys()
	local mk = myKey()
	local keys, seen = { mk }, { [mk] = true }
	local others = {}
	local crew = call(DR.Crew)
	if type(crew) == "table" then
		for _, m in ipairs(crew) do
			local k = type(m) == "table" and (m.key or W.Key(m.name))
			if k and not seen[k] then
				seen[k] = true
				others[#others + 1] = k
			end
		end
	end
	local cap = call(DR.Captain)
	if type(cap) == "string" and cap ~= "" and not seen[cap] then others[#others + 1] = cap end
	table.sort(others)
	for _, k in ipairs(others) do if #keys < 6 then keys[#keys + 1] = k end end
	return keys
end

-- the crew's service name: this character's own, else the captain's name (the same answer
-- in every crew window, so the alert window shows one name)
local function service()
	local c = W.Char and W.Char()
	local s = c and type(c.service) == "string" and c.service or ""
	if s == "" then
		local crew = call(DR.Crew)
		if type(crew) == "table" then
			for _, m in ipairs(crew) do
				if type(m) == "table" and m.captain and m.name then s = m.name end
			end
		end
	end
	if s == "" then s = W.Me() end
	return clean(s, 30)
end

local function sendHello()
	if not canSend() then return false end
	helloAt = GetTime()
	push(table.concat({ "BH", "1", service(), table.concat(crewKeys(), ","), clean(leadName(), 24), clean(W.VERSION, 12) }, "~"), true)
	return true
end
DR.BellHello = sendHello

-- One alert to the alert character. `force`: even while closed with nobody listed (Test).
function DR.Ring(text, force)
	if not canSend() then return false end
	if not force and not DR.BellActive() then return false end
	text = clean(text, 200)
	if text == "" then return false end
	local t = GetTime()
	if recent[text] and t - recent[text] < SAME then return false end
	recent[text] = t
	local n = 0
	for k, at in pairs(recent) do
		n = n + 1
		if t - at >= SAME and n > 20 then recent[k] = nil end
	end
	if not helloAt or t - helloAt > HELLO_EVERY then sendHello() end
	push("BE~1~" .. clean(leadName(), 24) .. "~" .. text)
	return true
end

local function safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not inError then
		inError = true
		W.Error("alert character", err)
		inError = false
	end
end

local function first(keys)
	table.sort(keys)
	return keys[1]
end

-- (r32 AUD-108) with `station` (several open stations), crew standing somewhere else do not count
local function atStation(key, station)
	if not station then return true end
	local place = call(DR.PlaceOf, key == myKey() and "player" or key)
	return place == nil or W.SamePlace(place, station) == true
end

-- crew in this group who would click the portal for `caster` (me included)
local function helpers(caster, station)
	local mk = myKey()
	local keys = {}
	if mk ~= caster and atStation(mk, station) then keys[1] = mk end
	local crew = call(DR.Crew)
	if type(crew) == "table" then
		for _, m in ipairs(crew) do
			local k = type(m) == "table" and (m.key or W.Key(m.name))
			if k and k ~= caster and k ~= mk and m.here ~= false and m.app ~= false and atStation(k, station) then
				keys[#keys + 1] = k
			end
		end
	end
	return keys
end

-- With anyone allowed to cast, every Warlock's button offers the cast: only the first by
-- name who can cast rings for it.
local function ringsForCast()
	if call(DR.MainCaster) then return true end
	local order = call(DR.CastOrder)
	if type(order) ~= "table" then return true end
	local can = {}
	for _, key in ipairs(order) do
		if call(DR.CanCast, key) == true then can[#can + 1] = key end
	end
	if #can == 0 then return true end
	return first(can) == myKey()
end

---------------------------------------------------------------------------
-- Crew side: what rings
---------------------------------------------------------------------------

-- A rider's whisper, in the window it reached (looked at after the queue listed them).
W.On("CHAT_MSG_WHISPER", function(text, sender)
	if locked() then return end
	text, sender = W.Str(text), W.Str(sender)
	if not text or not sender then return end
	W.After(0, function()
		local key = W.Key(sender)
		if not key or isCrewKey(key) or call(DR.IsBellKey, key) == true then return end
		local c = call(DR.Find, sender)
		if type(c) ~= "table" then return end -- not on the list: closed, or not about a summon
		if call(DR.BlockEntry, key) then return end
		DR.Ring(me() .. ": whisper from " .. (c.name or sender) .. ": " .. clean(text, 40))
	end)
end)

local rungWuber = setmetatable({}, { __mode = "k" })
W.Listen("DRIVE_STATE", function(c, was)
	if type(c) ~= "table" or locked() then return end
	safe(function()
		if c.state == "invited" and was ~= "invited" and c.source == "public" and call(DR.IsLeader) == true then
			DR.Ring(me() .. " invited " .. tostring(c.name) .. " from public chat: " .. clean(c.msg or "", 40))
		end
		if c.source == "wuber" and not rungWuber[c] and (was == nil or was == "lead") then
			rungWuber[c] = true
			local netDriver = DR.NetDriver and call(DR.NetDriver)
			if netDriver == nil then netDriver = call(DR.IsLeader) ~= false end
			if netDriver then DR.Ring(me() .. ": Wuber ride request from " .. tostring(c.name)) end
		end
	end)
end)

-- DRIVE_PAID: name, copper, tip, cashierKey, mine, how ("t" traded | "m" by hand), price
W.Listen("DRIVE_PAID", function(name, copper, tip, cashierKey, mine, how)
	if not mine or how == "m" or locked() then return end
	safe(function() DR.Ring(me() .. ": " .. tostring(name) .. " paid " .. W.Money(tonumber(copper) or 0)) end)
end)

W.Listen("DRIVE_ALERT", function(text, kind)
	if locked() then return end
	safe(function()
		if kind == "portal" then
			-- every crew window hears the portal call: the first helper by name rings it (with
			-- several stations, the first at the station the summon is cast at)
			local station = call(DR.MultiStation) == true and W.Str((call(DR.MyStation))) or nil
			local _, casterKey = call(DR.RitualBusy, station and station:lower()) -- Drive.Cast: lower case
			if first(helpers(casterKey, station)) ~= myKey() then return end
		end
		local t = clean(text, 200)
		local mine = me()
		if t:sub(1, #mine + 1) ~= mine .. ":" then t = mine .. ": " .. t end
		DR.Ring(t)
	end)
end)

-- The big button has a click for you: what it says, once per new action.
local lastPlan
local function planRing()
	local b = DR.button
	local plan = type(b) == "table" and b.plan or nil
	if type(plan) ~= "table" or (W.InCombat and W.InCombat()) then return end
	if plan.type ~= "macro" and plan.type ~= "click" then
		lastPlan = nil
		return
	end
	for _, m in ipairs(type(plan.marks) == "table" and plan.marks or {}) do
		if type(m) == "table" and m.kind == "cast" and not ringsForCast() then return end
	end
	local text = me() .. ": " .. clean(plan.title, 120)
	if text == lastPlan then return end
	lastPlan = text
	DR.Ring(text)
end
W.Listen("DRIVE", function() if not locked() then safe(planRing) end end)

-- A call the game refused (not the bell's own).
W.Listen("BLOCKED", function(cap)
	if not cap or cap == "bell" or locked() then return end
	safe(function() DR.Ring(me() .. ": the game blocked " .. tostring(cap) .. " - see chat", true) end)
end)

-- The crew changed: the alert character hears it with the next alert (or at once).
local helloDue = false
W.Listen("DRIVE_CREW", function()
	helloAt = nil
	if bellName() and not helloDue and not locked() then
		helloDue = true
		W.After(1, function()
			helloDue = false
			sendHello()
		end)
	end
end)

---------------------------------------------------------------------------
-- The alert character is not online: quiet for a while, its "No player named" line hidden
---------------------------------------------------------------------------

local notFoundPattern
local function bellNotFound(text)
	text = W.Str(text)
	if not text or not lastSentAt or GetTime() - lastSentAt > 5 or not bellName() then return false end
	if not notFoundPattern then
		local fmt = ERR_CHAT_PLAYER_NOT_FOUND_S
		if type(fmt) ~= "string" or fmt == "" then fmt = "No player named '%s' is currently playing." end
		local p = fmt:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
		p = p:gsub("%%%d+%%%$s", "(.+)"):gsub("%%s", "(.+)")
		notFoundPattern = "^" .. p .. "$"
	end
	local who = text:match(notFoundPattern)
	return who ~= nil and W.Key(who) == W.Key(bellName())
end

W.On("CHAT_MSG_SYSTEM", function(text)
	if not bellNotFound(text) then return end
	if not awayAt or GetTime() - awayAt >= AWAY then
		W.Print("alert character: " .. (bellName() or "?") .. " is not online - quiet for " .. AWAY .. " s.")
	end
	awayAt, helloAt, queue = GetTime(), nil, {}
end)

---------------------------------------------------------------------------
-- Alert side: hearing
---------------------------------------------------------------------------

local function known(key)
	local b = cfg()
	if not b then return false end
	for _, k in ipairs(b.team) do if key == k then return true end end
	return false
end

local strangerHint = {}
local function ignore(sender, why)
	stat.ignored = stat.ignored + 1
	if why and not strangerHint[sender] then
		strangerHint[sender] = true
		W.Print("alert character: ignored " .. sender .. " (" .. why .. ").")
	end
end

local function heardHello(key, sender, p)
	local b = cfg()
	if not b then return end
	local svc = clean(p[3] or "", 30)
	local keys, matches = {}, false
	for part in tostring(p[4] or ""):gmatch("[^,]+") do
		local k = W.Key(part)
		if k and #keys < 6 then
			keys[#keys + 1] = k
			if key == k then matches = true end
		end
	end
	if svc == "" or #keys == 0 or not matches then
		ignore(sender)
		return
	end
	if #b.team == 0 and DR.AlertWindow() and not isOwnDriver(key) then
		ignore(sender)
		return
	end
	if not known(key) and #b.team > 0 then
		local overlap = false
		for _, k in ipairs(keys) do if known(k) then overlap = true end end
		if not overlap then
			ignore(sender, "not one of your crew - Settings > Driving > Alert character > Forget, then Test from a crew window, trusts a new crew")
			return
		end
	end
	local added = {}
	for _, k in ipairs(keys) do if not known(k) then added[#added + 1] = k end end
	if #b.team + #added > MAX_TEAM then
		b.team = {}
		added = keys
	end
	for _, k in ipairs(added) do b.team[#b.team + 1] = k end
	b.service = svc
	local lead = clean(p[5] or "", 24)
	if lead ~= "" then b.lead = lead end
	if #added > 0 then
		local names = {}
		for _, k in ipairs(b.team) do names[#names + 1] = (k:gsub("(%a)(%a*)", function(x, y) return x:upper() .. y end)) end
		W.Print("alert character: this window flashes for " .. svc .. " (" .. table.concat(names, ", ") .. ").")
	end
end

W.On("CHAT_MSG_ADDON", function(prefix, text, ch, sender)
	prefix, text, ch, sender = W.Plain(prefix), W.Plain(text), W.Plain(ch), W.Plain(sender)
	if prefix ~= PREFIX or ch ~= "WHISPER" or type(text) ~= "string" or type(sender) ~= "string" then return end
	if locked() or not cfg() then return end
	local kind = text:match("^(%u%u)~")
	if kind ~= "BH" and kind ~= "BE" then return end
	local key = W.Key(sender)
	if not key or key == myKey() then return end
	local p = W.Split(text)
	if p[2] ~= "1" then return end
	if kind == "BH" then
		heardHello(key, sender, p)
	else
		if not known(key) then
			ignore(sender)
			return
		end
		stat.heard = stat.heard + 1
		local lead = clean(p[3] or "", 24)
		if lead ~= "" then cfg().lead = lead end
		DR.BellAlert(p[4] or "")
	end
end)

---------------------------------------------------------------------------
-- Alert side: the banner and the counter
---------------------------------------------------------------------------

local banner, counter
local gen = 0
local shownAt = {}

local function edge(f, point)
	local t = f:CreateTexture(nil, "BORDER")
	t:SetColorTexture(VIOLET[1], VIOLET[2], VIOLET[3], 1)
	t:SetPoint(point .. "LEFT", f, point .. "LEFT", 0, 0)
	t:SetPoint(point .. "RIGHT", f, point .. "RIGHT", 0, 0)
	t:SetHeight(4)
	return t
end

local function font(fs, size)
	if fs.SetFont then pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, "OUTLINE") end
end
-- (design round 1) the alert's words in Wuber's own font (T.SetFont) at the size they had, with the soft shadow of
-- text over the game world (T.WorldText). Without the theme: the game's font, as before.
-- no theme: the game's own fonts need the numbers the alert always had
local FALLBACK_PX = { display = 30, title = 20, heading = 16, caption = 10 }
local function label(f, size, weight, template, big)
	local T = W.Theme
	if T and T.SetFont and T.WorldText then
		local fs = f:CreateFontString(nil, "OVERLAY")
		if pcall(T.SetFont, fs, size, weight) then return T.WorldText(fs) end
	end
	local fs = f:CreateFontString(nil, "OVERLAY", template)
	if big then font(fs, FALLBACK_PX[size] or size) end
	return fs
end

-- A long alert wraps inside side margins; the banner grows 36 for each extra line (the text stays
-- 16 above its middle, the "Swap to" line moves down with the growth) and the counter sits under it.
local MARGIN = 24
local LINE = 28 -- the banner text's size (T.SIZE.display): a further line adds this and the line spacing (8), 36 in all
local bannerExtra = 0
local function fitBanner(f)
	local uw = UIParent and UIParent.GetWidth and W.Num(UIParent:GetWidth(), 0) or 0
	local fs = f.text
	-- the width the text would take on one line; a client without that call gets an estimate from the
	-- letter count (GetStringWidth is no help here: between two side points it never exceeds the room)
	local need = W.Num(fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or 0
	if need <= 0 then need = #(W.Str(fs:GetText()) or "") * 15 end
	local lines = 1
	if uw > 2 * MARGIN and need and need > 0 then lines = math.max(1, math.ceil(need * 1.08 / (uw - 2 * MARGIN))) end
	-- each further line adds the text's own step: its size and line spacing (36 where it has no spacing)
	local gap = W.Num(fs.GetSpacing and fs:GetSpacing(), 0) or 0
	local extra = (gap > 0 and LINE + gap or 36) * (lines - 1)
	bannerExtra = extra
	f:SetHeight(120 + extra)
	f.sub:ClearAllPoints()
	f.sub:SetPoint("CENTER", f, "CENTER", 0, -24 - extra / 2)
end

-- The counter sits under the banner while a tall one is up, and back in its usual place once it is gone.
local function placeCounter()
	if not counter then return end
	local extra = (banner and banner:IsShown()) and bannerExtra or 0
	counter:ClearAllPoints()
	counter:SetPoint("TOP", UIParent, "TOP", 0, -126 - extra)
end

local function buildBanner()
	if banner then return banner end
	local f = CreateFrame("Button", "WuberBell", UIParent)
	banner = f
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(100)
	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
	f:SetHeight(120)
	f:EnableMouse(true)
	f:RegisterForClicks("AnyUp")
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(f)
	bg:SetColorTexture(0.05, 0.04, 0.09, 0.95)
	edge(f, "TOP")
	edge(f, "BOTTOM")
	f.text = label(f, "display", "bold", "GameFontNormalHuge", true)
	f.text:SetPoint("LEFT", f, "LEFT", MARGIN, 16)
	f.text:SetPoint("RIGHT", f, "RIGHT", -MARGIN, 16)
	f.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	f.text:SetJustifyH("CENTER")
	f.text:SetWordWrap(true)
	f.sub = label(f, "title", "medium", "GameFontHighlightLarge", true)
	f.sub:SetPoint("CENTER", f, "CENTER", 0, -24)
	f.sub:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	f.sub:SetJustifyH("CENTER")
	f.hint = label(f, "caption", "regular", "GameFontDisableSmall")
	f.hint:SetTextColor(0.5, 0.5, 0.5) -- the grey the game's small disabled font gave it
	f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 8)
	f.hint:SetText("Wuber - click to dismiss")
	f:SetScript("OnClick", function() W.Safe("alert character", DR.BellDismiss) end)
	if W.Theme and W.Theme.Tip then W.Theme.Tip(f, "Alert", "Click to hide this banner. The alert count stays until you click it.") end
	f:Hide()
	return f
end

local function buildCounter()
	if counter then return counter end
	local f = CreateFrame("Button", "WuberBellCount", UIParent)
	counter = f
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(99)
	f:SetSize(150, 32)
	f:SetPoint("TOP", UIParent, "TOP", 0, -126)
	f:EnableMouse(true)
	f:RegisterForClicks("AnyUp")
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(f)
	bg:SetColorTexture(0.05, 0.04, 0.09, 0.95)
	edge(f, "TOP")
	edge(f, "BOTTOM")
	f.text = label(f, "heading", "medium", "GameFontNormalLarge")
	f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	f:SetScript("OnClick", function() W.Safe("alert character", DR.BellClear) end)
	if W.Theme and W.Theme.Tip then W.Theme.Tip(f, "Alerts", "Click to clear the alert count and close this box.") end
	f:Hide()
	return f
end

local function showCount()
	local b = cfg()
	local n = b and b.count or 0
	if n <= 0 then
		if counter then counter:Hide() end
		return
	end
	local f = buildCounter()
	f.text:SetText(n .. (n == 1 and " alert" or " alerts"))
	f:Show()
end

local function flash(g, step)
	if g ~= gen or not banner or not banner:IsShown() then return end
	if step >= FLASH * 4 then
		banner:SetAlpha(1)
		return
	end
	banner:SetAlpha(step % 2 == 0 and 1 or 0.35)
	W.After(0.25, function() flash(g, step + 1) end)
end

-- An alert on this (the alert character's) window.
function DR.BellAlert(text)
	local b = cfg()
	text = clean(text, 200)
	if text == "" or not b then return false end
	local t = GetTime()
	if shownAt[text] and t - shownAt[text] < SAME then return false end -- two windows, one event
	shownAt[text] = t
	b.count = b.count + 1
	local f = buildBanner()
	f.text:SetText(text)
	fitBanner(f)
	f.sub:SetText("Swap to " .. (b.lead ~= "" and b.lead or "your crew"))
	f.lastText = text
	f:SetAlpha(1)
	f:Show()
	gen = gen + 1
	local g = gen
	flash(g, 0)
	W.After(SHOWN, function() if g == gen and banner then banner:Hide() placeCounter() end end)
	showCount()
	placeCounter()
	if W.Sound then W.Sound("alert") end
	if type(FlashClientIcon) == "function" then pcall(FlashClientIcon) end
	W.Print("|cfff9c53ealert|r: " .. text)
	return true
end

function DR.BellDismiss()
	gen = gen + 1
	if banner then banner:Hide() end
	placeCounter()
end

function DR.BellClear()
	local b = cfg()
	if b then b.count = 0 end
	showCount()
end

---------------------------------------------------------------------------
-- Settings: set, test, forget
---------------------------------------------------------------------------

-- Names the alert character ("" or nil: off). Returns ok, why.
function DR.BellSet(name)
	local b = cfg()
	if not b then return false, "not ready" end
	name = clean(name or "", 40)
	if name == "" or name:lower() == "off" or name:lower() == "none" then
		b.name = ""
		queue = {}
		W.Fire("SETTINGS", "bell")
		return true
	end
	local key = W.Key(name)
	if not key then return false, "no such name" end
	if key ~= myKey() and isCrewKey(key) then
		return false, W.Short(name) .. " is in your crew - the alert character is a character on another account"
	end
	b.name = name
	queue, helloAt, awayAt = {}, nil, nil
	if key ~= myKey() then sendHello() end
	W.Fire("SETTINGS", "bell")
	return true
end

-- Test: from a crew window a test alert goes out; on the alert character's own window the
-- banner shows here. Returns ok, what happened.
function DR.BellTest()
	local name = bellName()
	if not name then return false, "no alert character set" end
	if W.Key(name) == myKey() then
		DR.BellAlert("Test - the alert works")
		return true, "here"
	end
	if not canSend() then return false, "can't reach " .. name .. " right now (offline, or the game refused it)" end
	sendHello()
	DR.Ring("Test from " .. me() .. " - the alert works", true)
	return true, "sent"
end

function DR.BellForget()
	local b = cfg()
	if not b then return false end
	b.team, b.service = {}, ""
	stat.ignored = 0
	strangerHint = {}
	return true
end

function DR.AlertWindow()
	local c = call(DR.char) or (W.Char and call(W.Char))
	return type(c) == "table" and c.alertWindow == true
end

function DR.SetAlertWindow(on)
	local c = call(DR.char) or (W.Char and call(W.Char))
	if type(c) ~= "table" then return false end
	c.alertWindow = on and true or false
	W.Fire("SETTINGS", "alertWindow")
	return true
end

---------------------------------------------------------------------------
-- Login
---------------------------------------------------------------------------

W.OnLogin(function()
	if locked() then return end
	if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
		pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
	end
	local addFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
	if type(addFilter) == "function" then
		pcall(addFilter, "CHAT_MSG_SYSTEM", function(_, _, msg)
			local ok, hide = pcall(bellNotFound, msg)
			return ok and hide == true
		end)
	end
	local setAtLogin = bellName() ~= nil
	W.After(4, function()
		if setAtLogin and bellName() and not helloAt then sendHello() end
	end)
	showCount()
end)
