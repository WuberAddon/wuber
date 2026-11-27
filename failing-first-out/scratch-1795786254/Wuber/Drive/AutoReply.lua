-- Module: Drive.AutoReply
-- Purpose: Auto-reply whisper for clear public summon requests (Wuber 2.4).
-- API: W.Drive, DR.REPLY_EVERY, DR.REPLY_MAX, DR.ReplyText, DR.ReplyPlace, DR.CanReply, DR.ReplyTurn, DR.TryReply, DR.LastReply,
--   DR.ReplyHeard
-- Internals: (none)
-- Uses: Drive.Places, Drive.Careful (nothing bound at load: DR.AskedPlaces, DR.PlaceEntry, DR.Norm, DR.DestIn,
--   DR.MultiStation and DR.Careful are called at run time; the list keeps this file after them in the TOC)
-- Later: Drive.Core and Drive.Team (DR.char, DR.units, DR.KeyHasApp, DR.UnitClassKey, DR.Send at run time), Drive.Queue (DR.Busy, DR.NeverRider, DR.ServedPlaces, DR.AskedFor, DR.CanInvite, DR.Travelling, DR.Classify,
--   DR.Count, DR.customers, DR.units at run time), Drive.Service (DR.Selling at run time), Drive.Book (DR.ServeHold at run time)
-- Events: (none)
-- Standalone: no
-- Test: tests/v24/autoreply_test.lua
-- From: (new, Wuber 2.4)
--
-- Drive.AutoReply: sends at most one whisper per player per hour when a clear public request
-- names one place this driver serves. Strict on purpose: when in doubt, no whisper.
--
-- THE ONE EXCEPTION TO "no chat from addon code" (the author's rule of 21 Nov 2026; CLAUDE.md, "Secure and
-- hardware-click rules"). sendWhisper below is the only call in Wuber that sends a chat line by itself.
-- tools/check.lua (check 8) and the fake game (tests/harness.lua, H.replyRule) fail any other. The limits are
-- hard rules: one whisper, to one player whose public line the careful gate called a clear request for one
-- place this driver serves, to their full two-part name, at most once per person per hour (remembered in the
-- saved table), never in combat, in a raid, in an instance or while a ride is in progress, never to anyone in
-- the group. Never add a second call and never loosen a limit without the author's yes.

local _, W = ...
local Mod = W.Module("Drive.AutoReply", { "Drive.Places", "Drive.Careful" })

W.Drive = W.Drive or {}
local DR = W.Drive

DR.REPLY_EVERY = 3600
DR.REPLY_MAX = 200
-- (r51 SEC-M2) An overall limit on top of "once an hour per asker": Wuber's own whisper-backs leave at least
-- 8 s apart and at most 30 an hour in all, so a busy channel can never trip the game's spam limit on the driver.
-- 8 s x 30 = 4 minutes of whispering at the full rate; 30 an hour is one stranger every two minutes on average.
DR.REPLY_GAP = 8
DR.REPLY_HOURLY = 30

local sentAt = {} -- W.Now() of each whisper-back sent, oldest first (this session only)

local sessionReplied = {}
local lastReply = nil

local function wallNow()
	local t = type(time) == "function" and time() or 0
	return W.Num(t) or 0
end

local function validRecent(stamp, now)
	local s = W.Num(stamp)
	if not s then return false end
	return math.abs(now - s) < DR.REPLY_EVERY
end

local function repliedDB(create)
	local db = type(DR.db) == "table" and DR.db
		or (type(W.db) == "table" and type(W.db.drive) == "table" and W.db.drive) or nil
	if not db then return nil end
	local r = db.replied
	if type(r) ~= "table" then
		if not create then return nil end
		r = {}
		db.replied = r
	end
	return r
end

local function alreadyReplied(key, now)
	local r = repliedDB(false)
	local stamp = r and r[key]
	if stamp == nil then return false end
	if validRecent(stamp, now) then return true end
	local sess = sessionReplied[key]
	if sess and sess.wall == stamp and W.Now and W.Now() - sess.mono < DR.REPLY_EVERY then
		return true
	end
	return false
end

-- Remembers that key was whispered at now. False when there is nowhere to remember it (then nothing is sent).
local function recordReply(key, now)
	local r = repliedDB(true)
	if not r then return false end
	local count = 0
	for k, v in pairs(r) do
		if not validRecent(v, now) then
			r[k] = nil
		else
			count = count + 1
		end
	end
	if r[key] == nil then
		while count >= DR.REPLY_MAX do
			local oldK, oldT
			for k, v in pairs(r) do
				local tv = W.Num(v) or 0
				if not oldK or tv < oldT or (tv == oldT and tostring(k) < tostring(oldK)) then
					oldK, oldT = k, tv
				end
			end
			if not oldK then break end
			r[oldK] = nil
			count = count - 1
		end
	end
	r[key] = now
	sessionReplied[key] = { wall = now, mono = (W.Now and W.Now()) or 0 }
	return true
end

-- (#72, multibox) A crew window told us it whispered this asker: the same hour holds here, so a sister window never
-- answers the same stranger again, whatever happens to the first one. Nothing is sent. Only the crew's own windows
-- reach this (Drive.Team believes a group fact from a crew member alone).
function DR.ReplyHeard(askerKey)
	local key = W.Str(askerKey)
	if not key or key == "" or #key > 80 then return false end
	return recordReply(key, wallNow())
end

-- Tells the crew's windows that key was whispered, so none of them whispers it again within the hour. Not sent
-- without a crew (a window on its own, or a party of strangers, hears nothing).
local function tellCrew(key)
	if not (DR.Send and DR.char and DR.char().captain ~= nil) then return end
	local ch = DR.char()
	if ch.captain == "" and #(ch.crew or {}) == 0 then return end
	DR.Send("RPL", key)
end

local function replyTarget(sender)
	local clean = W.SplitName and W.SplitName(sender) or W.Str(sender)
	if not clean or clean == "" then return nil, nil end
	local target = W.Tell and W.Tell(clean) or nil
	if type(target) ~= "string" or not target:match("^[^%s%-]+%-[^%s%-]+$") then
		return nil, nil
	end
	return target, clean
end

local function sameKnown(a, b)
	if W.SamePlace and W.SamePlace(a, b) then return true end
	local ea = DR.PlaceEntry and DR.PlaceEntry(a)
	local eb = DR.PlaceEntry and DR.PlaceEntry(b)
	if ea and eb then return ea == eb end
	if DR.Norm then return DR.Norm(a) == DR.Norm(b) end
	return a == b
end

local function servedList()
	if type(DR.ServedPlaces) == "function" then
		local list = DR.ServedPlaces()
		if type(list) == "table" and #list > 0 then return list end
	end
	local d = W.Str(DR.Dest and DR.Dest())
	if d and d ~= "" and d ~= "Unknown" and (not W.ExactPlace or W.ExactPlace(d)) then
		return { d }
	end
	return nil
end

local function sendWhisper(line, target)
	local ci = rawget(_G, "C_ChatInfo")
	if type(ci) ~= "table" then return false end
	ci.SendChatMessage(line, "WHISPER", nil, target)
	return true
end

function DR.ReplyText(place)
	place = W.Str(place)
	if not place or place == "" then return nil end
	return 'Want a summon to ' .. place .. '? Whisper me "summon ' .. place .. '".'
end

function DR.ReplyPlace(text)
	text = W.Str(text)
	if not text or text == "" then return nil, "no text" end
	local served = servedList()
	if not served then return nil, "no served place" end
	local asked = DR.AskedPlaces and DR.AskedPlaces(text) or {}
	if #asked == 0 then return nil, "no place named" end
	local distinct = {}
	for _, p in ipairs(asked) do
		local name = W.Str(p and p.name)
		if name and name ~= "" then
			local seen = false
			for _, d in ipairs(distinct) do
				if sameKnown(d, name) then
					seen = true
					break
				end
			end
			if not seen then distinct[#distinct + 1] = name end
		end
	end
	if #distinct == 0 then return nil, "no place named" end
	if #distinct > 1 then return nil, "more than one place" end
	local want, match = distinct[1], nil
	for _, s in ipairs(served) do
		local name = W.Str(s)
		if name and name ~= "" and sameKnown(want, name) then
			if match and not sameKnown(match, name) then
				return nil, "more than one place"
			end
			match = match or name
		end
	end
	if not match then return nil, "place not served" end
	local back = "summon " .. match
	if not (DR.Careful and DR.Careful(back, "whisper") == "invite") then
		return nil, "whisper back would not invite"
	end
	if DR.Classify and DR.Classify(back) ~= "request" then
		return nil, "whisper back is not a request"
	end
	if DR.AskedFor and DR.AskedFor(back) ~= "match" then
		return nil, "whisper back place check failed"
	end
	if DR.MultiStation and DR.MultiStation() then
		local routed = DR.DestIn and DR.DestIn(back)
		if not (routed and sameKnown(routed, match)) then
			return nil, "whisper back would not route here"
		end
	end
	local line = DR.ReplyText(match)
	if not line or #line > 255 then
		return nil, "reply too long"
	end
	return match
end

-- Is there room under the overall limit right now? (Not recorded against any asker.)
local function underCap()
	local now = W.Now and W.Now() or 0
	local fresh = {}
	for _, t in ipairs(sentAt) do
		if now - t < 3600 then fresh[#fresh + 1] = t end
	end
	sentAt = fresh
	local last = sentAt[#sentAt]
	if last and now - last < DR.REPLY_GAP then
		return false, "too soon after the last whisper back"
	end
	if #sentAt >= DR.REPLY_HOURLY then
		return false, "whisper back limit for the hour reached"
	end
	return true
end

function DR.CanReply(sender)
	if not DR.on or not DR.Role or DR.Role() ~= "driver" then
		return false, "not a driver"
	end
	if not (DR.Selling and DR.Selling()) then
		return false, "not open"
	end
	local opts = DR.opts and DR.opts() or {}
	if opts.autoInvite ~= true then
		return false, "Inviting riders who whisper you or ask in the app is off"
	end
	if opts.watchPublic ~= true then
		return false, "Listing people who ask for a summon in public chat is off"
	end
	if opts.autoReply == false then
		return false, "Whisper back to public requests is off"
	end
	-- "How whispers leave": only the mode that whispers (macro, which "auto" is) replies by itself. Off sends
	-- nothing; Chat box needs the player's own Enter, so an auto-reply sends nothing there.
	if DR.ChatMode and DR.ChatMode() ~= "macro" then
		return false, "whispers are not set to go by themselves"
	end
	if W.IsBlocked and W.IsBlocked("chat") then
		return false, "the game refuses addon chat"
	end
	if W.IsBlocked and W.IsBlocked("invite") then
		return false, "the game refuses addon invites"
	end
	if DR.IsPaused and DR.IsPaused() then
		return false, "paused"
	end
	if DR.Travelling and DR.Travelling() then
		return false, "travelling"
	end
	if DR.CanInvite and not DR.CanInvite() then
		return false, "cannot invite"
	end
	if W.InCombat and W.InCombat() then
		return false, "in combat"
	end
	if DR.InRaid and DR.InRaid() then
		return false, "in a raid"
	end
	if W.InInstance and W.InInstance() then
		return false, "in an instance"
	end
	if DR.Busy and DR.Busy() then
		return false, "a ride is in progress"
	end
	if DR.inviteHold and W.Now and W.Now() < DR.inviteHold then
		return false, "invites paused"
	end
	if DR.GroupSize and DR.MaxGroup and DR.Count then
		local size, pending, maxG = DR.GroupSize(), DR.Count("invited"), DR.MaxGroup()
		if size + pending >= maxG then
			return false, "group is full"
		end
	end
	local target, clean = replyTarget(sender)
	if not target then
		return false, "not a full name"
	end
	local key = W.Key(clean)
	if not key then
		return false, "not a full name"
	end
	if W.myKey and key == W.myKey then
		return false, "yourself"
	end
	if (type(W.InGroupWith) == "function" and W.InGroupWith(key))
		or (type(DR.units) == "table" and DR.units[key] ~= nil) then
		return false, "in your group"
	end
	if type(W.drivers) == "table" and W.drivers[key] then
		return false, "another driver"
	end
	local db = DR.db
	if type(db) == "table" and type(db.blocklist) == "table" and db.blocklist[key] then
		return false, "blocked"
	end
	if type(DR.NeverRider) == "function" and DR.NeverRider(key) then
		return false, "never a rider"
	end
	if type(DR.ServeHold) == "function" and DR.ServeHold(key) then
		return false, "not served again yet" -- the driver's own "don't serve again until" (Drive.Book)
	end
	local c = type(DR.customers) == "table" and DR.customers[key] or nil
	if c and c.state ~= "lead" and c.state ~= "done" then
		return false, "already a rider"
	end
	if alreadyReplied(key, wallNow()) then
		return false, "already whispered within the hour"
	end
	local room, roomWhy = underCap()
	if not room then
		return false, roomWhy
	end
	return true
end

-- (the lead's review) One whisper per asker, however many Wuber drivers hear the line: five drivers open in one
-- city would otherwise each whisper the same person. Every driver works out the same answer by itself from the
-- beacons it already has (no new message): among the open Wuber drivers for this place on 2.4.0 or newer (older
-- ones have no auto-reply and would never answer), the lowest number made from the asker's and the driver's keys
-- has the turn, so askers are spread over the drivers. A driver of the other faction is never in W.drivers. If
-- the driver whose turn it is cannot answer (busy, in combat, switched off), nobody whispers and the asker is a
-- lead for everyone, as before 2.4: when in doubt, no whisper.
local function replyTurnScore(askerKey, driverKey)
	local s = askerKey .. "|" .. driverKey
	local h = 7
	for i = 1, #s do
		h = (h * 31 + s:byte(i)) % 2147483647
	end
	return h
end

-- Keys of the player's own crew Warlocks who run Wuber and stand in my group (Drive.Team and Drive.Core, at run time).
-- Like the beacon drivers above they must be on 2.4.0 or newer (older ones never answer). A crew follows its captain's
-- one place, so no place is compared. A window whose hello has not arrived (DR.apps) is not counted, so it can never
-- hold the turn without being known.
local function crewDrivers()
	local out = {}
	local ch = type(DR.char) == "function" and DR.char() or nil
	if type(ch) ~= "table" or type(DR.units) ~= "table" or type(DR.KeyHasApp) ~= "function" then return out end
	local names = {}
	if type(ch.captain) == "string" and ch.captain ~= "" then names[#names + 1] = ch.captain end
	for _, m in ipairs(type(ch.crew) == "table" and ch.crew or {}) do
		if type(m) == "table" and m.app ~= false and m.name then names[#names + 1] = m.name end
	end
	for _, n in ipairs(names) do
		local k = W.Key(n)
		local app = type(DR.apps) == "table" and k and DR.apps[k] or nil
		if app and k ~= W.myKey and DR.units[k] ~= nil and DR.KeyHasApp(k) and app.role == "L"
			and type(DR.UnitClassKey) == "function" and DR.UnitClassKey(k) == "WARLOCK" then
			-- (a "2.4.2-dev" build counts as 2.4.2)
			local v = tostring(app.version or ""):match("^%d+%.%d+%.%d+")
			local cmp = v and W.CompareVersions and W.CompareVersions(v, "2.4.0")
			if cmp == 0 or cmp == 1 then
				out[#out + 1] = k
			end
		end
	end
	return out
end

function DR.ReplyTurn(askerKey, place)
	local myKey = W.Str(W.myKey)
	if not myKey or myKey == "" then
		return true
	end
	local targetPlace = W.Str(place)
	if not targetPlace or targetPlace == "" then
		return true
	end
	local drivers = W.drivers
	if type(drivers) ~= "table" then
		return true
	end
	local ask = W.Str(askerKey) or ""
	local bestKey = myKey
	local bestScore = replyTurnScore(ask, myKey)
	for k, d in pairs(drivers) do
		local dk = W.Str(k)
		if dk and dk ~= "" and dk ~= myKey and type(d) == "table" and d.state == "open" then
			local dest = W.Str(d.dest)
			local cmp = W.CompareVersions and W.CompareVersions(d.ver, "2.4.0")
			if dest and dest ~= "" and sameKnown(dest, targetPlace) and (cmp == 0 or cmp == 1) then
				local score = replyTurnScore(ask, dk)
				if score < bestScore or (score == bestScore and dk < bestKey) then
					bestScore = score
					bestKey = dk
				end
			end
		end
	end
	-- (#72, multibox) the player's own crew windows in my group are drivers too, whether or not their beacons reached me
	-- (a crew's windows follow the captain's one beacon): the same turn for all of them, so exactly one answers
	for _, dk in ipairs(crewDrivers()) do
		local score = replyTurnScore(ask, dk)
		if score < bestScore or (score == bestScore and dk < bestKey) then
			bestScore = score
			bestKey = dk
		end
	end
	if bestKey ~= myKey then
		return false, "another driver's turn"
	end
	return true
end

function DR.TryReply(sender, text, verdict)
	if verdict ~= "invite" then
		return false, "not a clear request"
	end
	if DR.HasGameLink and DR.HasGameLink(text) then
		return false, "game link"
	end
	local place, why = DR.ReplyPlace(text)
	if not place then
		return false, why
	end
	local can, canWhy = DR.CanReply(sender)
	if not can then
		return false, canWhy
	end
	local target, clean = replyTarget(sender)
	if not target then
		return false, "not a full name"
	end
	local key = W.Key(clean)
	if not key then
		return false, "not a full name"
	end
	local turn, turnWhy = DR.ReplyTurn(key, place)
	if not turn then
		return false, turnWhy
	end
	local line = DR.ReplyText(place)
	if not line or #line > 255 then
		return false, "reply too long"
	end
	local now = wallNow()
	-- (lead review) remembered BEFORE the call, so an error can never whisper the same player twice; a whisper
	-- that cannot be remembered is not sent
	local rdb = repliedDB(false)
	local beforeStamp, beforeSess = rdb and rdb[key], sessionReplied[key]
	if not recordReply(key, now) then
		return false, "nowhere to remember the whisper"
	end
	local ok, sent = W.Try("chat", sendWhisper, line, target)
	if not (ok and sent) then
		-- (prep-242 AU24-11) the game refused: forget it, so the asker is answered next time
		local r = repliedDB(false)
		if r then r[key] = beforeStamp end
		sessionReplied[key] = beforeSess
		return false, (W.IsBlocked and W.IsBlocked("chat")) and "the game refuses addon chat" or "could not send"
	end
	sentAt[#sentAt + 1] = W.Now and W.Now() or 0
	tellCrew(key)
	lastReply = { to = clean, place = place, at = now }
	return true
end

function DR.LastReply()
	if not lastReply then return nil end
	return { to = lastReply.to, place = lastReply.place, at = lastReply.at }
end
