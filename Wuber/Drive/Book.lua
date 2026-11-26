-- Module: Drive.Book
-- Purpose: the driver's customer book (round 9, Y1 and Y3): one note per rider, the Gifted stamp and the
--   "Get Wuber" stamp, the facts the earnings log already has (rides, last ride, last place), and the
--   book's sync between this driver's OWN crew windows (addon whispers to trusted crew members only).
-- API: DR.BOOK, DR.BookEntry, DR.SetNote, DR.SetGifted, DR.CustomerFacts, DR.Customers, DR.GetAppState,
--   DR.ServeHold, DR.SetServeHold, DR.OwesFare, DR.HasWuber, DR.AskGetApp, DR.GetAppOwed, DR.GetAppSent, DR.BookShareOn, DR.BookOwn, DR.SetBookOwn, DR.BookPeers,
--   DR.BookHeard, DR.BookTick, DR.BookBacklog
-- Internals: book, ensure, touch, apply, newer, recordMessages, parts, pump (the sync's own paced queue),
--   ask (my open BKQ per crew window), ownList, appHeard (who sent a Wuber addon message this session)
-- Uses: (none)
-- Later: Drive.Mail (DR.MailNote, DR.MailList: DR.Customers lists a rider whose mail was seen; DR.MailRecord: OwesFare)
--   (Drive.Core, Drive.Team, Drive.Chat and Drive.Log load earlier: reached through DR at run
--   time: DR.Crew, DR.TrustKey, DR.peers, DR.Whisper, DR.CommBacklog, DR.ChatMode, DR.Log, DR.Opt,
--   DR.IsCrewKey, DR.WuberLine, DR.TPREFIX)
-- Events: listens On CHAT_MSG_ADDON (round 12: notes who runs Wuber, nothing else), On CHAT_MSG_SYSTEM ("No player named" after a sync whisper; a chat filter added at login
--   hides that line), login; Drive.Ready's DR.Tick calls DR.BookTick once a second; Drive.Team's whisper
--   handler hands BKH / BKQ / BKR to DR.BookHeard; Drive.Chat's DR.Pending / DR.MarkSent call
--   DR.GetAppOwed / DR.GetAppSent; fires (none: DR.Changed after an edit)
-- Standalone: no
-- Test: tests/drive/book_test.lua
-- From: new in Wuber 2.3.0 round 9 (FIXROUND-2.3.0 items 1 and 3)
--
-- The book is the driver's own: W.db.drive.book (made the first time something is written, so a driver
-- without notes saves exactly what 2.3.0 saved). Keyed by W.Key of the rider's full name:
--   book = { v = 1, seq = n, list = { [key] = rec }, seen = { [crew key] = their seq } }
--   rec  = { name, note (at most 200 bytes), noteAt (epoch of the last note edit), gift (epoch of the
--            first Gifted stamp), app (epoch the "Get Wuber" whisper last went), seq (this window's count),
--            wuber (round 12: epoch this window first knew they run Wuber; this window's own, never synced) }
--
-- Who sees it: nobody but this driver and the crew windows it marked "My own account" (a crew can
-- hold friends too, so trust in the crew is not enough). Never in a beacon, a group or channel message,
-- gossip, or anything a rider receives. The marks are this character's (W.Char().bookOwn[key] = true,
-- set on that member's Crew card, on each window for each of the others). The sync goes only by addon
-- WHISPER (prefix WUBERT, through Drive.Team's outbox and token bucket) to a member that is marked
-- here, that DR.TrustKey still trusts (my captain, or a member of my crew that runs Wuber) and that was
-- heard in the last 45 s; anything from anyone else is dropped. Nobody marked: nothing is sent. Off
-- with Settings "Share notes with my own accounts" (DR.Opt("shareNotes"), on by default).
--   BKH~1~top~seenYou[~r]  "my book's counter is at top; of yours I have everything up to seenYou"
--                      (to each marked window when it is first heard or newly marked (round 12: even
--                      with an empty book), then every 5 min; answered with
--                      my own BKH, marked r, when I have more than they have seen; an r is not answered)
--   BKQ~1~since        "send me your records after since" (one open question per window at a time)
--   BKR~1~seq~name~noteAt~gift~app~i/n~text~by[~ans]   one record (the note in up to 4 parts, 250 bytes
--                      each; by = the window that wrote the note; ans = the since of the answer it is part
--                      of, none for a live push: only records marked so count toward that answer)
--   BKE~1~since~upto~n~top   the end of an answer: n records with seq in (since, upto] went out
-- 'seen' (what I have of a window's book) moves only on a BKE whose n records all arrived, so a record
-- lost on the way (a reload, a dropped send, the queue's cap) is asked for again; a live push never
-- moves it. An answer stops at 400 records: the asker asks again from upto at once. A BKH whose top is
-- below what I have seen (their book started again) resets seen and asks from 0.
-- A marked window outside my group that logs off: the first "No player named" line after a sync whisper
-- drops its waiting messages and keeps it off the list until it is heard again (the line is hidden).
-- The queue's cap drops the oldest message to the same window first.
-- A record is sent at once to every marked window when it changes. Merge: per customer the newest note
-- edit wins (an emptied note too; the same second: the writer's key, then the text, so two windows
-- agree); a Gifted stamp is never removed by a sync (the earliest is kept); the newest "Get Wuber" stamp
-- is kept. The sync's queue hands Drive.Team one message a second, only while its outbox is empty (so a
-- rider's PAID, CAST, END or ST never waits behind a sync) and only to a window still online and marked;
-- the windows take turns (the one whispered longest ago first), so no answer waits behind another's.
--
-- "Get Wuber" (Y1): for a rider who came by whisper or public chat (not through the app), the row
-- menu asks for it (DR.AskGetApp). It is then one of the whispers this window owes (DR.Pending): the
-- big button's click sends it (or the chat box and the driver's Enter), never by itself, and at
-- most once a day per customer (the stamp is shared with the crew).
-- Round 12 (TEST-FINDINGS-1119 item 4: it went to an app rider who had whispered by hand): never to
-- anyone Wuber knows runs Wuber (DR.HasWuber): a ride booked through the app (also a crew window's
-- ride id), the Wuber request line or a [Wuber] line, me or my crew, a driver heard, any Wuber addon
-- message from them this session, a saved Wuber contact (W.db.peers, W.db.seenDrivers), a rider who
-- pinged or booked on the network, or a book record marked so (rec.wuber, set the first time one of
-- the others said so while the rider has a record: it outlives a reload).

local _, W = ...
local Mod = W.Module("Drive.Book", {})
W.Drive = W.Drive or {}
local DR = W.Drive

local S = W.Str

local BOOK = {
	NOTE_MAX = 200,    -- bytes in one note
	NAME_MAX = 48,
	PEER_FRESH = 45,   -- a crew window heard (HI) this recently is online: it may be whispered
	HELLO_EVERY = 300, -- BKH again to a crew window this often (it may have reloaded)
	SYNC_MAX = 400,    -- records in one answer to a BKQ
	QUEUE_MAX = 1200,  -- messages waiting in the sync's queue (the oldest go first)
	MAX_BYTES = 250,
	ONE_RIDE = 1800,   -- payments this close together are one ride (as Drive.Log's DR.RideCount)
	FUTURE = 86400,    -- a time from a crew window more than a day ahead of mine is not believed
	HELLO_AGAIN = 10,  -- my BKH in answer to theirs, at most this often per window
	ASK_QUIET = 90,    -- an open BKQ with no answer for this long is given up (asked again on a BKH)
	KINDS = { BKH = true, BKQ = true, BKR = true, BKE = true },
	HEARD_MAX = 2000,  -- players kept in appHeard (then it starts again)
	HOLD_DAYS = 30,    -- "don't serve again until": this many days from the click
}
DR.BOOK = BOOK

local outq = {}    -- { to, key, kind, args }: the sync's messages, one a second
local replyAt = {} -- [crew key] = GetTime() of my last BKH answer to it (kept apart so an own-mark hello never holds it back)
local helloAt = {} -- [crew key] = GetTime() of my last BKH to it (this session)
local pend = {}    -- [sender|name|noteAt] = { n, parts, at }: a note arriving in parts
local sentAt = {}  -- [crew key] = GetTime() of the sync's last whisper to it
local turn, turnN = {}, 0 -- [crew key] = turnN at the sync's last whisper to it (the pump takes turns)
local goneAt = {}  -- [crew key] = GetTime() the game said it is not online (not whispered until heard again)
local ask = {}     -- [crew key] = { since, at, got = { [seq] = true } }: my open BKQ to that window
local newMark = {} -- [crew key] = true: marked "My own account" just now (a BKH goes on the next tick)
local appHeard, appHeardN = {}, 0 -- [key] = true: a Wuber addon message came from them (this session)

local function stamp() return (type(time) == "function" and time()) or 0 end
local function now() return (type(GetTime) == "function" and GetTime()) or 0 end

local function call(name, ...)
	local fn = DR[name]
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		W.Error("drive " .. name, a)
		return nil
	end
	return a, b
end

-- an epoch from the wire or saved data ("1795000000"; W.Int stops at 999999999), or nil
local function epoch(v)
	if type(v) == "number" then return (v == v and v > 0 and v % 1 == 0) and v or nil end
	if type(v) ~= "string" or not v:match("^%d+$") or #v > 10 then return nil end
	local n = tonumber(v)
	return (n and n > 0) and n or nil
end

local function dayOf(t) return (type(date) == "function" and t and date("%Y%m%d", t)) or nil end

-- the saved book; made only for a write (make)
local function book(make)
	local d = W.db and W.db.drive
	if type(d) ~= "table" then return nil end
	local b = d.book
	if type(b) ~= "table" then
		if not make then return nil end
		b = { v = 1, seq = 0, list = {}, seen = {} }
		d.book = b
	end
	if type(b.list) ~= "table" then b.list = {} end
	if type(b.seen) ~= "table" then b.seen = {} end
	b.seq = tonumber(b.seq) or 0
	return b
end

local function keyOf(name)
	name = S(name)
	return name and W.Key(name) or nil
end

-- The record of a rider (by name or key), or nil. Read only.
function DR.BookEntry(name)
	local b, k = book(false), keyOf(name)
	local rec = b and k and b.list[k]
	return type(rec) == "table" and rec or nil
end

local function ensure(b, name)
	local k = keyOf(name)
	if not k then return nil end
	local rec = b.list[k]
	if type(rec) ~= "table" then
		rec = {}
		b.list[k] = rec
	end
	rec.name = W.Clean(S(name) or rec.name or k, BOOK.NAME_MAX)
	return rec, k
end

local function touch(b, rec)
	b.seq = b.seq + 1
	rec.seq = b.seq
end

---------------------------------------------------------------------------
-- The sync's wire (whispers to my own crew windows only)
---------------------------------------------------------------------------

function DR.BookShareOn()
	local v = call("Opt", "shareNotes")
	return v ~= false
end

-- this character's "My own account" marks: { [key] = true } (made only for a mark)
local function ownList(make)
	local ch = type(W.Char) == "function" and W.Char() or nil
	if type(ch) ~= "table" then return nil end
	if type(ch.bookOwn) ~= "table" then
		if not make then return nil end
		ch.bookOwn = {}
	end
	return ch.bookOwn
end

-- Whether this character marked the crew member key as one of the player's own accounts.
function DR.BookOwn(key)
	local l, k = ownList(false), S(key)
	return (l and k and l[k] == true) and true or false
end

-- The Crew card's "My own account" switch. Returns true when it changed.
function DR.SetBookOwn(key, on)
	local k = S(key)
	if not k or k == W.myKey then return false end
	on = on and true or false
	if DR.BookOwn(k) == on then return false end
	local l = ownList(on)
	if not l then return false end
	l[k] = on or nil
	if not on and next(l) == nil then
		local ch = W.Char()
		ch.bookOwn = nil
	end
	helloAt[k], replyAt[k], ask[k] = nil, nil, nil
	-- round 12: newly marked: my BKH on the next tick (even with an empty book), so a window that has
	-- notes for me answers at once instead of at its next 5-minute hello
	newMark[k] = on or nil
	call("Changed")
	return true
end

-- The crew windows I may whisper now: { { key, name } } (marked as my own here, trusted, run Wuber,
-- heard in the last 45 s).
function DR.BookPeers()
	local out = {}
	if not DR.BookShareOn() or not ownList(false) then return out end
	local list = call("Crew")
	local t = now()
	for _, m in ipairs(type(list) == "table" and list or {}) do
		local k = type(m) == "table" and m.key
		local peer = k and DR.peers and DR.peers[k]
		if k and k ~= W.myKey and m.app ~= false and DR.BookOwn(k) and call("TrustKey", k) == true and peer
			and t - (tonumber(peer.at) or -1000) <= BOOK.PEER_FRESH then
			-- in my group but logged off (the game says so at once; "heard" lags 45 s): not whispered
			local unit = DR.units and DR.units[k]
			-- the game said "No player named" after our last whisper, and it was not heard since
			local gone = goneAt[k] and (tonumber(peer.at) or 0) <= goneAt[k]
			if not gone then goneAt[k] = nil end
			if not gone and not (unit and call("Online", unit) == false) then
				out[#out + 1] = { key = k, name = S(peer.name) or S(m.name) or k }
			end
		end
	end
	return out
end

-- full: the oldest message to the same window goes (so one window's backlog never eats another's
-- answer), else the oldest of all
local function queue(to, key, kind, ...)
	if #outq >= BOOK.QUEUE_MAX then
		local drop = 1
		for i, it in ipairs(outq) do
			if it.key == key then
				drop = i
				break
			end
		end
		table.remove(outq, drop)
	end
	outq[#outq + 1] = { to = to, key = key, kind = kind, args = { ... } }
end

-- drops what waits for one window (kinds: { BKR = true, ... }; nil: everything)
local function unqueue(key, kinds)
	for i = #outq, 1, -1 do
		local it = outq[i]
		if it.key == key and (not kinds or kinds[it.kind]) then table.remove(outq, i) end
	end
end

-- (tests) how many sync messages wait
function DR.BookBacklog() return #outq end

-- one message to Drive.Team, only when its own outbox and bulk lane are empty
-- (a window that went offline, or is no longer marked, gets nothing: what waited for it is dropped,
-- so no whisper goes to someone who is not there). Windows take turns (AUD-140): the next message is
-- the oldest one to the window whispered longest ago, so a second window's answer never waits behind
-- a first window's whole book (its open ask would give up after BOOK.ASK_QUIET and ask it all again).
local function pump()
	if #outq == 0 then return end
	local a, b = call("CommBacklog")
	if (tonumber(a) or 0) > 0 or (tonumber(b) or 0) > 0 then return end
	local live = {}
	for _, p in ipairs(DR.BookPeers()) do live[p.key] = true end
	local pick, best
	for i, it in ipairs(outq) do
		if live[it.key] and (not best or (turn[it.key] or 0) < best) then pick, best = i, turn[it.key] or 0 end
	end
	if not pick then
		for i = #outq, 1, -1 do outq[i] = nil end
		return
	end
	local item = outq[pick]
	-- what waited ahead of it for a window that is not there goes (as when it reached the front)
	for i = pick, 1, -1 do
		if i == pick or not live[outq[i].key] then table.remove(outq, i) end
	end
	turnN = turnN + 1
	turn[item.key] = turnN
	sentAt[item.key] = now()
	call("Whisper", item.to, item.kind, unpack(item.args))
end

-- a note cut into parts that fit next to the header: { { text, space } }, never through a UTF-8 letter.
-- W.Clean trims a part's edges, so a part never ends in a space and a space that would start the next
-- part is left out and marked on this one (space = true: "i/n+" on the wire, put back on arrival).
local function parts(text, room)
	local out = {}
	room = math.max(20, room)
	while #text > room do
		local cut = room
		while cut > 1 do
			local b = text:byte(cut + 1)
			if not (b and b >= 128 and b < 192) and text:sub(cut, cut) ~= " " then break end
			cut = cut - 1
		end
		local rest = text:sub(cut + 1)
		local space = rest:sub(1, 1) == " "
		out[#out + 1] = { text:sub(1, cut), space }
		text = space and rest:sub(2) or rest
	end
	out[#out + 1] = { text, false }
	return out
end

-- the BKR messages of one record: { { args } } (ans: the since of the answer they belong to; nil for a
-- live push)
local function recordMessages(rec, ans)
	local seq, name = tostring(rec.seq or 0), W.Clean(rec.name or "", BOOK.NAME_MAX)
	local noteAt, gift, app = tostring(rec.noteAt or ""), tostring(rec.gift or ""), tostring(rec.app or "")
	local by = S(rec.noteBy) or ""
	ans = ans and tostring(ans) or nil
	local head = #("BKR~1~") + #seq + #name + #noteAt + #gift + #app + #by + 7 + 6 + (ans and #ans + 1 or 0)
	local list = parts(rec.note or "", BOOK.MAX_BYTES - head)
	local out = {}
	for i, part in ipairs(list) do
		out[#out + 1] = { seq, name, noteAt, gift, app, i .. "/" .. #list .. (part[2] and "+" or ""), part[1], by, ans }
	end
	return out
end

local function sendRecord(to, key, rec, ans)
	for _, args in ipairs(recordMessages(rec, ans)) do queue(to, key, "BKR", unpack(args, 1, ans and 9 or 8)) end
end

-- a changed record goes to every marked window now
local function pushAll(rec)
	for _, p in ipairs(DR.BookPeers()) do sendRecord(p.name, p.key, rec) end
end

-- whether a note (noteAt, by, text) beats the record's: the later edit; the same second: the
-- writer's key, then the text (both windows compare the same three things, so they agree; a record's
-- seq is not used: each window counts its own)
local function newer(rec, noteAt, by, note)
	local mine = tonumber(rec.noteAt) or 0
	if noteAt ~= mine then return noteAt > mine end
	by, note = by or "", note or ""
	local myBy, myNote = S(rec.noteBy) or "", rec.note or ""
	if by ~= myBy then return by > myBy end
	return note > myNote
end

-- A record from a crew window, merged. Returns whether mine changed.
local function apply(b, name, noteAt, gift, app, note, by)
	local rec = ensure(b, name)
	if not rec then return false end
	local changed = false
	local cap = stamp() + BOOK.FUTURE
	noteAt = (noteAt and noteAt <= cap) and noteAt or nil
	note = W.Clean(note or "", BOOK.NOTE_MAX)
	by = S(by) and W.Key(S(by)) or nil
	if noteAt and newer(rec, noteAt, by, note) then
		rec.note = note ~= "" and note or nil
		rec.noteAt = noteAt
		rec.noteBy = by
		changed = true
	end
	gift = (gift and gift <= cap) and gift or nil
	if gift and (not rec.gift or gift < rec.gift) then
		rec.gift = gift
		changed = true
	end
	app = (app and app <= cap) and app or nil
	if app and app > (tonumber(rec.app) or 0) then
		rec.app = app
		changed = true
	end
	if changed then touch(b, rec) end
	return changed
end

-- BKH / BKQ / BKR from a whisper (Drive.Team): true when it was one of the book's kinds.
function DR.BookHeard(kind, key, sender, p)
	if not BOOK.KINDS[kind] then return false end
	-- only windows marked here as my own accounts (and still trusted crew), only while sharing is on
	if not DR.BookShareOn() or not key or key == W.myKey or not DR.BookOwn(key)
		or call("TrustKey", key) ~= true then return true end
	p = type(p) == "table" and p or {}
	if kind == "BKH" then
		local top, seenYou = epoch(p[3]) or 0, tonumber(p[4]) or 0
		local b = book(false)
		local seen = b and tonumber(b.seen[key]) or 0
		-- their book started again (a new SavedVariables, a wipe): what I have seen of it means nothing
		if b and top < seen then
			b.seen[key] = nil
			seen = 0
			ask[key] = nil
		end
		local open = ask[key]
		if top > seen and not open then
			ask[key] = { since = seen, at = now(), got = {} }
			queue(sender, key, "BKQ", seen)
		end
		-- they have not seen all of mine (a reload, a lost answer): my BKH, so they ask (never an
		-- answer to an answer)
		if p[5] ~= "r" and b and b.seq > seenYou and now() - (replyAt[key] or -1000) >= BOOK.HELLO_AGAIN then
			replyAt[key] = now()
			queue(sender, key, "BKH", b.seq, seen, "r")
		end
	elseif kind == "BKQ" then
		-- one answer at a time: what still waits of an older answer to them is dropped first
		unqueue(key, { BKR = true, BKE = true })
		local b = book(false)
		local since = tonumber(p[3]) or 0
		local list = {}
		for _, rec in pairs(b and b.list or {}) do
			if type(rec) == "table" and (tonumber(rec.seq) or 0) > since then list[#list + 1] = rec end
		end
		table.sort(list, function(x, y) return (x.seq or 0) < (y.seq or 0) end)
		local n = math.min(#list, BOOK.SYNC_MAX)
		for i = 1, n do sendRecord(sender, key, list[i], since) end
		local top = b and b.seq or 0
		local upto = n < #list and (tonumber(list[n].seq) or since) or math.max(since, top)
		queue(sender, key, "BKE", since, upto, n, top)
	elseif kind == "BKE" then
		local a = ask[key]
		local since, upto = tonumber(p[3]), tonumber(p[4])
		local n, top = tonumber(p[5]), tonumber(p[6]) or 0
		if not a or since ~= a.since or not upto or not n then return true end
		ask[key] = nil
		local got = 0
		for s in pairs(a.got) do if s > since and s <= upto then got = got + 1 end end
		if got ~= n then return true end -- something was lost: asked again on their next BKH
		local b = book(n > 0 or upto > since)
		if b and upto > (tonumber(b.seen[key]) or 0) then b.seen[key] = upto end
		if upto < top then
			ask[key] = { since = upto, at = now(), got = {} }
			queue(sender, key, "BKQ", upto)
		end
	else
		local seq, name = epoch(p[3]) or 0, W.Clean(p[4] or "", BOOK.NAME_MAX)
		local noteAt, gift, app = epoch(p[5]), epoch(p[6]), epoch(p[7])
		local i, n, plus = (p[8] or ""):match("^(%d+)/(%d+)(%+?)$")
		i, n = tonumber(i), tonumber(n)
		if not keyOf(name) or not i or not n or n < 1 or n > 4 or i > n then return true end
		local text = (p[9] or "") .. ((plus == "+" and i < n) and " " or "")
		if n > 1 then
			local id = key .. "|" .. name .. "|" .. tostring(noteAt)
			local e = pend[id]
			if not e or e.n ~= n then
				e = { n = n, parts = {}, at = now() }
				pend[id] = e
			end
			e.parts[i] = text
			for j = 1, n do if not e.parts[j] then return true end end
			pend[id] = nil
			text = table.concat(e.parts)
		end
		local b = book(true)
		if not b then return true end
		-- only a record marked as part of the open answer counts toward it (a live push's seq may be stale)
		local a = ask[key]
		if a and p[11] == tostring(a.since) and seq > a.since then
			a.got[seq] = true
			a.at = now()
		end
		if apply(b, name, noteAt, gift, app, text, p[10]) then call("Changed") end
	end
	return true
end

-- Round 12: anyone a Wuber addon message comes from (any prefix of ours, any channel) runs Wuber, so
-- "Get Wuber" is never offered to them. Only the key is kept; the message is not read.
W.On("CHAT_MSG_ADDON", function(prefix, _, _, sender)
	prefix = S(prefix)
	if not prefix or (prefix ~= W.PREFIX and prefix ~= DR.TPREFIX) then return end
	local k = keyOf(sender)
	if not k or k == W.myKey or appHeard[k] then return end
	if appHeardN >= BOOK.HEARD_MAX then appHeard, appHeardN = {}, 0 end
	appHeard[k] = true
	appHeardN = appHeardN + 1
end)

-- "No player named X is currently playing." just after the sync whispered X (a marked window outside my
-- group that logged off): X's waiting messages go, and X is not whispered again until it is heard.
-- Returns X's key when the line is about such a window (the chat filter then hides it).
local function notFound(text)
	local name = type(W.NotFoundName) == "function" and W.NotFoundName(text) or nil
	local k = name and W.Key(name)
	if k and sentAt[k] and now() - sentAt[k] <= 5 then return k end
	return nil
end

W.On("CHAT_MSG_SYSTEM", function(text)
	local k = notFound(text)
	if not k then return end
	goneAt[k] = now()
	unqueue(k)
	ask[k], helloAt[k], replyAt[k] = nil, nil, nil
end)

W.OnLogin(function()
	local add = (type(ChatFrame_AddMessageEventFilter) == "function" and ChatFrame_AddMessageEventFilter)
		or (type(ChatFrameUtil) == "table" and type(ChatFrameUtil.AddMessageEventFilter) == "function"
			and function(event, fn) return ChatFrameUtil.AddMessageEventFilter(event, fn) end) or nil
	if add then
		pcall(add, "CHAT_MSG_SYSTEM", function(_, _, msg)
			local ok, k = pcall(notFound, msg)
			return ok and k ~= nil
		end)
	end
end)

-- Once a second (Drive.Ready's DR.Tick): a BKH to each crew window newly heard (or every 5 min),
-- then one waiting message. Nothing at all while the book is empty.
function DR.BookTick()
	local b = book(false)
	local t = now()
	if next(newMark) then
		for _, p in ipairs(DR.BookPeers()) do
			if newMark[p.key] then
				helloAt[p.key] = t
				queue(p.name, p.key, "BKH", b and b.seq or 0, b and tonumber(b.seen[p.key]) or 0)
				newMark[p.key] = nil -- (2.3.2, C8) kept until that window is heard (not yet grouped: it waits)
			end
		end
	end
	if b and b.seq > 0 then
		local here = {}
		for _, p in ipairs(DR.BookPeers()) do
			here[p.key] = true
			if t - (helloAt[p.key] or -1000) >= BOOK.HELLO_EVERY then
				helloAt[p.key] = t
				queue(p.name, p.key, "BKH", b.seq, tonumber(b.seen[p.key]) or 0)
			end
		end
		-- a crew window that went quiet gets a BKH again as soon as it is back
		for k in pairs(helloAt) do if not here[k] then helloAt[k] = nil end end
		for k in pairs(replyAt) do if not here[k] then replyAt[k] = nil end end
	end
	for id, e in pairs(pend) do
		if t - (e.at or 0) > 60 then pend[id] = nil end
	end
	for k, a in pairs(ask) do
		if t - (a.at or 0) > BOOK.ASK_QUIET then ask[k] = nil end
	end
	pump()
end

---------------------------------------------------------------------------
-- Editing (this window)
---------------------------------------------------------------------------

-- One note per customer (200 bytes; "" or nil clears it). Returns true.
function DR.SetNote(name, text)
	if not keyOf(name) then return false end
	text = W.Clean(S(text) or "", BOOK.NOTE_MAX)
	local old = DR.BookEntry(name)
	if (old and old.note or "") == text then return true end
	local b = book(true)
	if not b then return false end
	local rec = ensure(b, name)
	rec.note = text ~= "" and text or nil
	rec.noteAt = math.max(stamp(), (tonumber(rec.noteAt) or 0) + 1)
	rec.noteBy = W.myKey
	touch(b, rec)
	pushAll(rec)
	call("Changed")
	return true
end

-- "Gifted <date>": once per customer (never removed). Returns true, or false and the date it has.
function DR.SetGifted(name)
	local old = DR.BookEntry(name)
	if old and old.gift then return false, old.gift end
	if not keyOf(name) then return false end
	local b = book(true)
	if not b then return false end
	local rec = ensure(b, name)
	rec.gift = stamp()
	touch(b, rec)
	pushAll(rec)
	call("Changed")
	return true, rec.gift
end

-- Whether this rider left owing (Drive.Mail's list: it goes when they pay, or after 30 days).
function DR.OwesFare(name)
	local rec = call("MailRecord", name)
	return type(rec) == "table" and (tonumber(rec.due) or 0) > 0
end

-- "Don't serve again until <date>" (the driver's own, never sent, never shown to the rider): book.hold[key] =
-- the epoch it ends. It is not in a record, so no note sync, beacon, whisper or line ever carries it. Checked
-- when used: past its date it is gone (and tidied away here), nobody is told.
function DR.ServeHold(name)
	local b, k = book(false), keyOf(name)
	local t = b and k and type(b.hold) == "table" and tonumber(b.hold[k]) or nil
	if not t then return nil end
	if t <= stamp() then
		b.hold[k] = nil
		return nil
	end
	return t
end

-- on: HOLD_DAYS from now (returns the epoch); off: takes it away (returns nil)
function DR.SetServeHold(name, on)
	local k = keyOf(name)
	if not k then return nil end
	local b = book(on == true)
	if not b then return nil end
	if type(b.hold) ~= "table" then
		if on ~= true then return nil end
		b.hold = {}
	end
	b.hold[k] = on == true and (stamp() + BOOK.HOLD_DAYS * 86400) or nil
	call("Changed")
	return b.hold[k]
end

---------------------------------------------------------------------------
-- Facts from the earnings log (nothing new is recorded for them)
---------------------------------------------------------------------------

local index, indexSig = nil, nil

-- [key] = { name, times = { sorted }, last, place }, from the log's rides and the crew's rides
local function logIndex()
	local l = call("Log")
	if type(l) ~= "table" then return {} end
	local rides, team = type(l.rides) == "table" and l.rides or {}, type(l.team) == "table" and l.team or {}
	local sig = #rides .. ":" .. tostring(rides[#rides]) .. ":" .. #team .. ":" .. tostring(team[#team])
	if index and sig == indexSig then return index end
	local idx = {}
	for _, list in ipairs({ rides, team }) do
		for _, line in ipairs(list) do
			local at, _, name, dest = tostring(line):match("^([^,]*),([^,]*),([^,]*),([^,]*)")
			local k = name and name ~= "" and W.Key(name)
			at = tonumber(at)
			if k and at then
				local e = idx[k]
				if not e then
					e = { name = name, times = {} }
					idx[k] = e
				end
				e.times[#e.times + 1] = at
				if not e.last or at >= e.last then
					e.last = at
					e.place = (dest and dest ~= "") and dest or e.place
					e.name = name
				end
			end
		end
	end
	for _, e in pairs(idx) do table.sort(e.times) end
	index, indexSig = idx, sig
	return idx
end

local function rideCount(times)
	local n, last = 0, nil
	for _, at in ipairs(times or {}) do
		if not last or at - last > BOOK.ONE_RIDE then n = n + 1 end
		last = at
	end
	return n
end

-- { rides, last (epoch or nil), place (or nil) } for a customer.
function DR.CustomerFacts(name)
	local k = keyOf(name)
	local e = k and logIndex()[k]
	if not e then return { rides = 0 } end
	return { rides = rideCount(e.times), last = e.last, place = e.place }
end

-- Everyone in the book or the log: { { key, name, rides, last, place, note, gift } }, the latest ride
-- first. filter: part of a name (any case).
function DR.Customers(filter)
	filter = S(filter) and S(filter):lower() or nil
	local out, seen = {}, {}
	local b = book(false)
	local function add(k, name)
		if seen[k] then return end
		if filter and not (tostring(name):lower():find(filter, 1, true) or k:find(filter, 1, true)) then return end
		seen[k] = true
		local f = DR.CustomerFacts(name)
		local rec = b and b.list[k]
		rec = type(rec) == "table" and rec or {}
		-- (payment by mail, Drive.Mail, which loads later) "Mail seen: 5g from Dan, 21 Nov.": listed for that alone too
		local mail = DR.MailNote and DR.MailNote(name) or nil
		if not (f.rides > 0 or rec.note or rec.gift or mail) then return end
		out[#out + 1] = { key = k, name = S(rec.name) or name, rides = f.rides, last = f.last, place = f.place,
			note = rec.note, gift = rec.gift, noteAt = rec.noteAt, mail = mail }
	end
	for k, e in pairs(logIndex()) do add(k, e.name) end
	local owedList = DR.MailList and DR.MailList() or nil
	for k, m in pairs(type(owedList) == "table" and owedList or {}) do
		if type(m) == "table" and S(m.name) then add(k, m.name) end
	end
	if b then
		for k, rec in pairs(b.list) do
			if type(rec) == "table" then add(k, rec.name or k) end
		end
	end
	table.sort(out, function(x, y)
		local a1, b1 = x.last or 0, y.last or 0
		if a1 ~= b1 then return a1 > b1 end
		local n1, n2 = tostring(x.name):lower(), tostring(y.name):lower()
		if n1 ~= n2 then return n1 < n2 end
		return x.key < y.key
	end)
	return out
end

---------------------------------------------------------------------------
-- "Get Wuber" (Y1)
---------------------------------------------------------------------------

local function tbl(t, k) return type(t) == "table" and k and t[k] or nil end

-- Why Wuber knows this rider (a queue customer { name, key, source, msg, ... }, or a name) runs
-- Wuber: "app" (booked through it), "line" (the Wuber request line or a [Wuber] line), "crew" (me or
-- my crew), "driver", "heard" (an addon message or a network ping this session), "contact" (a saved
-- Wuber contact or driver), "book" (their record says so); nil when nothing says so.
function DR.HasWuber(c)
	if type(c) ~= "table" then c = { name = c } end
	if c.source == "wuber" or S(c.wuberRide) or S(c.wuberVer) or S(c.wuberBuyer) or S(c.rideId) then return "app" end
	local msg = S(c.msg)
	if msg and (call("WuberLine", msg) or msg:find("[Wuber]", 1, true)) then return "line" end
	local k = keyOf(c.name) or S(c.key)
	if not k then return nil end
	if k == W.myKey or call("IsCrewKey", k) or tbl(DR.peers, k) then return "crew" end
	if tbl(W.drivers, k) then return "driver" end
	local fb = W.fallback
	if appHeard[k] or tbl(fb and fb.riders, k) or tbl(fb and fb.booked, k) then return "heard" end
	local d = W.db
	if tbl(d and d.peers, k) or tbl(d and d.seenDrivers, k) then return "contact" end
	local b = book(false)
	if tbl(tbl(b and b.list, k), "wuber") then return "book" end
	return nil
end

-- "ok" (may be asked), "queued" (the next click sends it), "sent" (today already), "app" (Wuber
-- knows they run Wuber: DR.HasWuber), "crew", "off" (whispers are off), "raid", or "none".
-- peek = true: the same answer, read only (painting a row or a pane writes nothing; without
-- it an "app" answer stamps the rider's book record, as before).
function DR.GetAppState(c, peek)
	if type(c) ~= "table" or not S(c.name) or S(c.helperOf) or c.iouOnly then return "none" end
	local why = DR.HasWuber(c)
	if why == "crew" then return "crew" end
	if why then
		-- their record (if they have one) remembers it past a reload; this window's own mark
		local rec = not peek and DR.BookEntry(c.name) or nil
		if rec and not rec.wuber then rec.wuber = stamp() end
		return "app"
	end
	if call("ModeNow") == "raid" then return "raid" end
	if call("ChatMode") == "off" then return "off" end
	-- the template turned into nothing (W.Clean of the driver's own text): nothing to send
	local text = call("Template", "getapp")
	if W.Clean(type(text) == "string" and text or "", 255) == "" then return "off" end
	local rec = DR.BookEntry(c.name)
	if rec and rec.app and dayOf(rec.app) == dayOf(stamp()) then return "sent" end
	if c.getapp then return "queued" end
	return "ok"
end

-- The driver's pick in the row menu: owed from now on (on = false: not any more). Returns true
-- when it changed.
function DR.AskGetApp(c, on)
	if on == false then
		if type(c) ~= "table" or not c.getapp then return false end
		c.getapp = nil
	elseif DR.GetAppState(c) == "ok" then
		c.getapp = true
	else
		return false
	end
	call("Changed")
	return true
end

-- (Drive.Chat's DR.Pending) the "Get Wuber" whispers asked for, after the ride's own.
function DR.GetAppOwed(out)
	local list = call("Sorted")
	for _, c in ipairs(type(list) == "table" and list or {}) do
		if type(c) == "table" and c.getapp and DR.GetAppState(c) == "queued" then out[#out + 1] = { c = c, kind = "getapp" } end
	end
	return out
end

-- (Drive.Chat's DR.MarkSent) it went out: stamped for today, shared with the crew.
function DR.GetAppSent(c)
	if type(c) ~= "table" then return end
	c.getapp = nil
	local b = book(true)
	local rec = b and ensure(b, c.name)
	if not rec then return end
	rec.app = stamp()
	touch(b, rec)
	pushAll(rec)
end

-- (tests) my open BKQ to a window, or nil
function Mod.asking(key) return ask[key] end

-- for other modules (REFACTOR-MAP section 2)
Mod.parts = parts
Mod.recordMessages = recordMessages
