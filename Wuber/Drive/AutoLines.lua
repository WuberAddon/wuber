-- Module: Drive.AutoLines
-- Purpose: Lines sent by themselves: the greeting, the pay reminder and "You're next" as a whisper to the driver's own
--   rider (Wuber 2.4).
-- API: W.Drive, DR.LINES, DR.LINE_KINDS, DR.LineOn, DR.SetLineOn, DR.LineTakes, DR.CanLine, DR.TryLine, DR.PumpLines,
--   DR.LastLine
-- Internals: sent
-- Uses: Drive.Chat, Drive.Plan (nothing bound at load: DR.Text, DR.MarkSent, DR.ChatMode, DR.ModeNow and DR.Plan are
--   called at run time; the list keeps this file after them in the TOC, and before Drive.Button, so a line that went
--   by itself is already marked sent when the big button works out its next click)
-- Later: Drive.Queue (DR.customers, DR.units, DR.NeverRider, DR.WuberLine, DR.Sorted, DR.PlaceOK, DR.AskOK,
--   DR.IsLeader at run time), Drive.Service (DR.Selling, DR.IsPaused at run time),
--   Drive.Book (DR.ServeHold at run time)
-- Events: listens Listen DRIVE, Listen DRIVE_RITUAL; fires SETTINGS
-- Standalone: no
-- Test: tests/dec/dec_r_lines_test.lua
-- From: (new, Wuber 2.4, the decisions round)
--
-- Drive.AutoLines: with its switch on (Messages, off by default), a line goes out by itself as a whisper, in the
-- driver's own words for that message (DR.Text), and is marked sent (DR.MarkSent). With the switch off nothing here
-- runs. Each line has its own moment, and is tried ONCE at that moment:
--   * the pay reminder ("pay"): when the big button offers it on this window (the rider landed and the reminder is
--     due). When it cannot go by itself it waits for its click, as before;
--   * the greeting ("greet"): when the summon cast for that rider starts (DRIVE_RITUAL phase "c"), in the window
--     the rider asked. With the switch on the big button does not offer the greeting to such a rider (DR.LineTakes,
--     asked by Drive.Plan): the click goes straight to the cast, and a greeting that cannot go at that moment is
--     dropped for that ride. Riders the line never goes to (a public chat buyer, a name added by hand) are greeted
--     by the click, as before;
--   * "You're next" ("next"): only ever sent from here (the big button never offers it). To a rider WITHOUT the
--     app who asked by a whisper and waits in this driver's line for room (queued, not invited, not in the group),
--     when they are first in that line and have waited DR.LINES.wait seconds; once per ride; refused once, it is
--     dropped. A rider with the app gets none: their own screen shows their place in the queue.
--
-- THE SECOND EXCEPTION TO "no chat from addon code" (the author's yes of 21 Nov 2026 22:28, to "more lines sent
-- by themselves"). sendWhisper below is the only call here, and with Drive.AutoReply's the only two in Wuber:
-- tools/check.lua (check 8) and the fake game (tests/harness.lua, H.linesRule) fail any other. The limits are hard
-- rules, each with a test:
--   * a WHISPER only, tried once at the line's own moment (above) and never sent later;
--   * only to this driver's RIDER: on the list, in the group (joined, being summoned, landed), who asked this
--     window by the app or by a whisper the careful gate took as a clear request (c.auto). Never a lead, never someone
--     invited from public chat or added by hand, never a Wuber driver, a crew member, a helper or a blocked player.
--     For "You're next" alone "in the group" is "queued by this driver" (waiting in the line of a driver who
--     invites by themselves, is not paused and leads the group);
--   * never in combat, in a raid, in an instance, in raid mode or with whispers switched off;
--   * the same line never twice to one person within 10 minutes, no two lines to one person within 20 seconds,
--     at most one self-sent whisper every 2 seconds and 8 a minute over all riders;
--   * the pay reminder only after the rider landed, once per ride.
-- Never add a second call, another kind of chat or a line to DR.LINE_KINDS, and never loosen a limit, without the
-- author's yes.

local _, W = ...
local Mod = W.Module("Drive.AutoLines", { "Drive.Chat", "Drive.Plan" })

W.Drive = W.Drive or {}
local DR = W.Drive

-- seconds: the same line to one person, any two lines to one person, any two self-sent whispers; and how many a minute
-- wait: how long a rider has waited in the line before "You're next" goes
DR.LINES = { same = 600, person = 20, gap = 2, minute = 8, wait = 10 }
-- the lines that may go by themselves (message kinds of DR.TEMPLATES), in the order Messages shows them
DR.LINE_KINDS = { "greet", "pay", "next" }

local KIND = { greet = true, pay = true, next = true }
local RIDER_STATES = { joined = true, summoning = true, waiting = true, arrived = true }
local ASKED = { wuber = true, whisper = true } -- c.source: the app's request, or a whisper to this window

local sent = {}      -- { { key, kind, at } }: what went by itself, oldest first (kept for DR.LINES.same seconds)
local tried = setmetatable({}, { __mode = "k" }) -- [customer] = { [kind] = ride }: one try per rider, line and ride
local told = setmetatable({}, { __mode = "k" })  -- [customer] = ride: "You're next" went on that ride
local lastLine = nil
local pumping = false
local waitTimer = false -- a look at the line is booked for when its first rider has waited long enough

local function driveDB()
	local db = W.db
	local d = type(db) == "table" and db.drive or nil
	return type(d) == "table" and d or nil
end

-- Whether the line `kind` goes by itself (saved per account, with the messages; off until switched on).
function DR.LineOn(kind)
	if not KIND[kind] then return false end
	local d = driveDB()
	local l = d and d.lines
	return type(l) == "table" and l[kind] == true
end

-- The switch of one line. Returns whether it is on now.
function DR.SetLineOn(kind, on)
	if not KIND[kind] then return false end
	local d = driveDB()
	if not d then return false end
	if type(d.lines) ~= "table" then
		if on ~= true then return false end
		d.lines = {}
	end
	d.lines[kind] = (on == true) and true or nil
	W.Fire("SETTINGS", "drive.lines." .. kind)
	if DR.Changed then DR.Changed() end
	return on == true
end

-- Why no self-sent whisper may go to `key` right now (pacing), or nil.
local function paced(key, kind, now)
	local L, minute = DR.LINES, 0
	for i = #sent, 1, -1 do
		local s = sent[i]
		local age = math.max(0, now - s.at)
		if age < 60 then minute = minute + 1 end
		if age < L.gap then return "another line went by itself under " .. L.gap .. " seconds ago" end
		if s.key == key then
			if age < L.person then return "another line went to them under " .. L.person .. " seconds ago" end
			if s.kind == kind and age < L.same then return "the same line went to them under 10 minutes ago" end
		end
	end
	if minute >= L.minute then return L.minute .. " lines went by themselves in the last minute" end
	return nil
end

-- Why row c is no rider who asked this window (the app's request, or a whisper taken as a clear request), or nil.
local function notAsked(c)
	if not ASKED[c.source] then return "did not ask you by the app or a whisper" end
	-- a whisper counts only when the careful gate took it as a clear request (c.auto, Drive.Queue) or it is the
	-- app's own request line: someone who whispered anything else and got into the group another way is no rider
	-- who asked
	if c.source == "whisper" and c.auto ~= "whisper" and not (type(DR.WuberLine) == "function" and DR.WuberLine(c.msg)) then
		return "their whisper was not a clear request"
	end
	if c.offer then return "invited from public chat" end
	return nil
end

-- The ride a row is on, as far as this file can tell: one try of each line per ride.
local function rideOf(c) return tostring(c.joinedAt or c.invitedAt or c.at or "") end

-- A rider with the app (as Drive.Book tells them apart): asked by the app, or carries a ride of the network, or
-- whispered the app's own request line.
local function hasApp(c)
	if c.source == "wuber" or W.Str(c.wuberRide) or W.Str(c.wuberVer) or W.Str(c.wuberBuyer) or W.Str(c.rideId) then return true end
	return type(DR.WuberLine) == "function" and DR.WuberLine(c.msg) and true or false
end

-- The rider the next invite goes to (as DR.PumpInvites picks them): the first of the line.
local function firstInLine()
	if type(DR.Sorted) ~= "function" then return nil end
	for _, c in ipairs(DR.Sorted()) do
		if c.state == "queued" and (type(DR.PlaceOK) ~= "function" or DR.PlaceOK(c)) and (type(DR.AskOK) ~= "function" or DR.AskOK(c)) then
			return c
		end
	end
	return nil
end

-- Does the big button leave the line `kind` for customer c to this file? Only the greeting, with its switch on,
-- for a rider who asked this window: it then goes when their summon starts, or not at all on that ride (Drive.Plan).
function DR.LineTakes(kind, c)
	if kind ~= "greet" or type(c) ~= "table" or not DR.LineOn(kind) then return false end
	if W.IsBlocked and W.IsBlocked("chat") then return false end -- the game refuses addon chat: the click greets
	return notAsked(c) == nil
end

-- May the line `kind` go by itself to customer c now? true, or false and why (plain words, for tests).
function DR.CanLine(kind, c)
	if not KIND[kind] then return false, "no such line" end
	if not DR.LineOn(kind) then return false, "switched off" end
	if type(c) ~= "table" then return false, "no rider" end
	if not DR.on or not DR.Role or DR.Role() ~= "driver" then return false, "not a driver" end
	if not (DR.Selling and DR.Selling()) then return false, "not open" end
	if DR.ModeNow and DR.ModeNow() == "raid" then return false, "raid summons" end
	if DR.ChatMode and DR.ChatMode() == "off" then return false, "whispers are off" end
	if W.IsBlocked and W.IsBlocked("chat") then return false, "the game refuses addon chat" end
	if W.InCombat and W.InCombat() then return false, "in combat" end
	if DR.InRaid and DR.InRaid() then return false, "in a raid" end
	if W.InInstance and W.InInstance() then return false, "in an instance" end
	local name = W.Str(c.name)
	local key = name and W.Key(name) or nil
	if not key then return false, "no name" end
	if type(DR.customers) ~= "table" or DR.customers[key] ~= c then return false, "not on your list" end
	if c.state == "lead" then return false, "a lead, not a rider" end
	if kind == "next" then
		if c.state ~= "queued" then return false, "not waiting in your line" end
	elseif not RIDER_STATES[c.state] then
		return false, "not a rider in your group"
	end
	local stranger = notAsked(c)
	if stranger then return false, stranger end
	if W.myKey and key == W.myKey then return false, "yourself" end
	-- in the group; for "You're next" alone: queued by this driver (the state above), and not in the group yet
	if kind == "next" then
		if type(DR.units) ~= "table" or DR.units[key] ~= nil then return false, "already in your group" end
	elseif not (type(DR.units) == "table" and DR.units[key] ~= nil) then
		return false, "not in your group"
	end
	if type(W.drivers) == "table" and W.drivers[key] then return false, "another driver" end
	if type(DR.IsCrewKey) == "function" and DR.IsCrewKey(key) then return false, "a crew member" end
	if type(DR.NeverRider) ~= "function" or DR.NeverRider(key) then return false, "never a rider" end
	if type(DR.ServeHold) == "function" and DR.ServeHold(key) then return false, "not served again yet" end
	local db = DR.db
	if type(db) ~= "table" or type(db.blocklist) ~= "table" or db.blocklist[key] then return false, "blocked" end
	if kind == "pay" then
		if type(DR.opts) == "function" and DR.opts().remindPay == false then return false, "pay reminders are off" end
		if c.state ~= "arrived" then return false, "not landed yet" end
		if c.reminded then return false, "already reminded on this ride" end
	elseif kind == "next" then
		if hasApp(c) then return false, "has the app: their own screen shows their place" end
		-- accepted, and waiting only for room: this driver invites by themselves, is not paused and leads the group
		if not (type(DR.opts) == "function" and DR.opts().autoInvite) then return false, "you invite riders yourself" end
		if type(DR.IsPaused) == "function" and DR.IsPaused() then return false, "paused" end
		if type(DR.IsLeader) ~= "function" or not DR.IsLeader() then return false, "not the group's leader" end
		if firstInLine() ~= c then return false, "not first in your line" end
		if W.Now() - (tonumber(c.at) or W.Now()) < DR.LINES.wait then return false, "in your line under " .. DR.LINES.wait .. " seconds" end
		if told[c] == rideOf(c) then return false, "already told on this ride" end
	elseif c.greeted then
		return false, "already greeted"
	end
	local why = paced(key, kind, W.Now())
	if why then return false, why end
	return true
end

local function sendWhisper(line, target)
	local ci = rawget(_G, "C_ChatInfo")
	if type(ci) ~= "table" then return false end
	ci.SendChatMessage(line, "WHISPER", nil, target)
	return true
end

-- Sends the line `kind` to customer c by itself, if every limit allows it, and marks it sent. true, or false and why.
function DR.TryLine(kind, c)
	local can, why = DR.CanLine(kind, c)
	if not can then return false, why end
	local line = type(DR.Text) == "function" and W.Str(DR.Text(kind, c)) or nil
	if not line or line == "" or #line > 255 then return false, "no words to send" end
	local target = W.Tell(c.name)
	if target == "" then return false, "no name" end
	local now, key = W.Now(), W.Key(c.name)
	-- remembered BEFORE the call, so an error can never send the same line twice
	sent[#sent + 1] = { key = key, kind = kind, at = now }
	while sent[1] and now - sent[1].at >= DR.LINES.same do table.remove(sent, 1) end
	local ok, went = W.Try("chat", sendWhisper, line, target)
	if not (ok and went) then
		return false, (W.IsBlocked and W.IsBlocked("chat")) and "the game refuses addon chat" or "could not send"
	end
	lastLine = { to = c.name, kind = kind, at = now }
	if kind == "next" then
		told[c] = rideOf(c) -- (no mark on the row: the big button never offers this line)
	elseif type(DR.MarkSent) == "function" then
		DR.MarkSent(c, kind)
	end
	return true
end

-- The lines the big button offers on this window right now ({ c, kind }): the whispers in its macro, or the one
-- it would put into the chat box.
local function offered()
	local out = {}
	local plan = DR.Plan()
	if type(plan) ~= "table" then return out end
	for _, m in ipairs(type(plan.marks) == "table" and plan.marks or {}) do
		if type(m) == "table" and KIND[m.kind] and type(m.c) == "table" then out[#out + 1] = m end
	end
	local b = plan.box
	if type(b) == "table" and KIND[b.kind] and type(b.c) == "table" then out[#out + 1] = b end
	return out
end

-- One try of the line `kind` for customer c on this ride: true when this call was that try.
local function once(kind, c)
	local t = tried[c]
	if not t then
		t = {}
		tried[c] = t
	end
	local ride = rideOf(c)
	if t[kind] == ride then return false end
	t[kind] = ride
	DR.TryLine(kind, c)
	return true
end

-- "You're next": the first rider of the line, once they have waited long enough; else a look is booked for then.
local function pumpNext()
	local c = firstInLine()
	if not c then return end
	local left = DR.LINES.wait - (W.Now() - (tonumber(c.at) or W.Now()))
	if left <= 0 then
		-- one try: refused (a rider with the app, combat, a limit), it is dropped for that ride
		once("next", c)
	elseif not waitTimer then
		waitTimer = true
		W.After(left + 0.05, function()
			waitTimer = false
			DR.PumpLines()
		end)
	end
end

local function pump()
	-- the pay reminder: when the big button offers it (the greeting has its own moment: the cast's start, below)
	if DR.LineOn("pay") and type(DR.Plan) == "function" then
		for _, m in ipairs(offered()) do
			-- one try: a reminder that cannot go by itself now (combat, a limit) waits for its click, never sent later
			if m.kind == "pay" then once("pay", m.c) end
		end
	end
	if DR.LineOn("next") then pumpNext() end
end

-- With a switch on: every line the big button offers now is tried once. Run when the drive state changed.
function DR.PumpLines()
	if pumping then return end
	local any = false
	for _, kind in ipairs(DR.LINE_KINDS) do
		if DR.LineOn(kind) then any = true end
	end
	if not any then return end
	if not (DR.Selling and DR.Selling()) then return end
	if DR.ModeNow and DR.ModeNow() == "raid" then return end
	pumping = true
	local ok, err = pcall(pump)
	pumping = false
	if not ok then W.Error("drive lines", err) end
end

-- The last line that went by itself ({ to, kind, at }), or nil.
function DR.LastLine()
	if not lastLine then return nil end
	return { to = lastLine.to, kind = lastLine.kind, at = lastLine.at }
end

W.Listen("DRIVE", function() DR.PumpLines() end)

-- The greeting's moment: the summon cast for a rider starts (phase "c", in every crew window). Only the window the
-- rider asked passes DR.CanLine; one try per ride, and a greeting that cannot go now is dropped (never sent later).
W.Listen("DRIVE_RITUAL", function(_, phase, data)
	if phase ~= "c" or type(data) ~= "table" or not DR.LineOn("greet") then return end
	local c = type(DR.customers) == "table" and data.key and DR.customers[data.key] or nil
	if type(c) ~= "table" then return end
	if not (DR.Selling and DR.Selling()) or (DR.ModeNow and DR.ModeNow() == "raid") then return end
	once("greet", c)
end)

-- for tests: the pacing record
Mod.sent = sent
